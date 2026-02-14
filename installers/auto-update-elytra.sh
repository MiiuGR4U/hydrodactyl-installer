#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Pyrodactyl Elytra Auto-Updater                                                     #
#                                                                                    #
# Advanced auto-updater with cron support, dry-run mode, backups, and notifications  #
#                                                                                    #
# Usage:                                                                             #
#   auto-update-elytra.sh                    # Interactive mode with colors          #
#   auto-update-elytra.sh --cron             # Cron mode (no colors, log to file)    #
#   auto-update-elytra.sh --dry-run          # Check only, don't actually update      #
#   auto-update-elytra.sh --notify-only      # Only send notification if update avail #
#   auto-update-elytra.sh --force            # Force update even if versions match    #
#                                                                                    #
######################################################################################

# ------------------ Configuration ----------------- #

# Load environment file if it exists (for systemd service)
if [ -f /etc/pyrodactyl/auto-update-elytra.env ]; then
  # shellcheck source=/dev/null
  source /etc/pyrodactyl/auto-update-elytra.env
fi

# Default config (can be overridden by /etc/pyrodactyl/auto-update-elytra.conf)
ELYTRA_REPO="${ELYTRA_REPO:-pyrohost/elytra}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
INSTALL_DIR="${INSTALL_DIR:-/etc/elytra}"
LOG_FILE="${LOG_FILE:-/var/log/pyrodactyl-elytra-auto-update.log}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/elytra}"
LOCK_FILE="${LOCK_FILE:-/var/run/pyrodactyl-elytra-update.lock}"
CONFIG_FILE="${CONFIG_FILE:-/etc/pyrodactyl/auto-update-elytra.conf}"
KEEP_BACKUPS="${KEEP_BACKUPS:-5}"
AUTO_UPDATE="${AUTO_UPDATE:-true}"
CHECK_INTERVAL="${CHECK_INTERVAL:-3600}"

# ------------------ Runtime Flags ----------------- #

CRON_MODE=false
DRY_RUN=false
NOTIFY_ONLY=false
FORCE_UPDATE=false
VERBOSE=false

# ------------------ Exit Codes ----------------- #

EXIT_SUCCESS=0          # Update successful or no update needed
EXIT_ERROR=1            # General error
EXIT_LOCKED=2           # Another instance is running
EXIT_NO_RELEASE=3       # Could not fetch release info
EXIT_DOWNLOAD_FAILED=4  # Download failed
EXIT_BACKUP_FAILED=5    # Backup failed
EXIT_UPDATE_FAILED=6    # Update failed

# ------------------ Color Setup ----------------- #

setup_colors() {
  if [ "$CRON_MODE" == true ] || [ ! -t 1 ]; then
    COLOR_GREEN=''
    COLOR_YELLOW=''
    COLOR_RED=''
    COLOR_BLUE=''
    COLOR_ORANGE=''
    COLOR_NC=''
  else
    COLOR_GREEN='\033[0;32m'
    COLOR_YELLOW='\033[1;33m'
    COLOR_RED='\033[0;31m'
    COLOR_BLUE='\033[0;34m'
    COLOR_ORANGE='\033[38;5;214m'
    COLOR_NC='\033[0m'
  fi
}

# ------------------ Logging Functions ----------------- #

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo -e "$msg"

  # Log to file if in cron mode or if LOG_TO_FILE is set
  if [[ "$CRON_MODE" == true ]] || [[ "${LOG_TO_FILE:-}" == true ]]; then
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
  fi
}

output() {
  log "* $1"
}

success() {
  log "${COLOR_GREEN}SUCCESS${COLOR_NC}: $1"
}

error() {
  log "${COLOR_RED}ERROR${COLOR_NC}: $1" >&2
}

warning() {
  log "${COLOR_YELLOW}WARNING${COLOR_NC}: $1"
}

info() {
  log "${COLOR_BLUE}INFO${COLOR_NC}: $1"
}

debug() {
  if [ "$VERBOSE" == true ]; then
    log "${COLOR_ORANGE}DEBUG${COLOR_NC}: $1"
  fi
}

# ------------------ Lock Functions ----------------- #

acquire_lock() {
  mkdir -p "$(dirname "$LOCK_FILE")"

  if [ -f "$LOCK_FILE" ]; then
    local pid
    pid=$(cat "$LOCK_FILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      error "Another update process is already running (PID: $pid)"
      exit $EXIT_LOCKED
    else
      warning "Removing stale lock file (PID $pid not running)"
      rm -f "$LOCK_FILE"
    fi
  fi

  echo $$ > "$LOCK_FILE"
}

release_lock() {
  rm -f "$LOCK_FILE"
}

# ------------------ Configuration Loading ----------------- #

load_config() {
  if [ -f "$CONFIG_FILE" ]; then
    debug "Loading configuration from $CONFIG_FILE"
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
  fi
}

# ------------------ Version Functions ----------------- #

get_current_version() {
  if [ -x "/usr/local/bin/elytra" ]; then
    # Try to get version from binary
    /usr/local/bin/elytra --version 2>/dev/null || echo "unknown"
  else
    echo "unknown"
  fi
}

get_latest_release() {
  # Ensure jq is available
  if ! command -v jq >/dev/null 2>&1; then
    log "ERROR: jq is required but not installed"
    return 1
  fi

  local curl_opts="-sL --max-time 30"

  if [ -n "$GITHUB_TOKEN" ]; then
    curl_opts="$curl_opts -H \"Authorization: Bearer $GITHUB_TOKEN\""
  fi

  local release_json
  release_json=$(eval curl $curl_opts \
    "https://api.github.com/repos/$ELYTRA_REPO/releases/latest" 2>/dev/null)

  if [ -z "$release_json" ] || echo "$release_json" | grep -q '"message":"Not Found"'; then
    return 1
  fi

  echo "$release_json" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

get_release_asset_info() {
  local version="$1"
  local curl_opts="-sL --max-time 30"

  if [ -n "$GITHUB_TOKEN" ]; then
    curl_opts="$curl_opts -H \"Authorization: Bearer $GITHUB_TOKEN\""
  fi

  eval curl $curl_opts \
    "https://api.github.com/repos/$ELYTRA_REPO/releases/tags/$version" 2>/dev/null
}

# Version comparison
# Returns 0 if $1 > $2, 1 otherwise
version_gt() {
  test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

# ------------------ Backup Functions ----------------- #

create_backup() {
  info "Creating backup before update..."

  mkdir -p "$BACKUP_DIR"

  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local backup_name="elytra-backup-${timestamp}"
  local backup_path="${BACKUP_DIR}/${backup_name}"

  # Backup binary
  debug "Backing up Elytra binary..."
  if [ -f "/usr/local/bin/elytra" ]; then
    cp "/usr/local/bin/elytra" "${backup_path}.binary" 2>/dev/null || {
      warning "Failed to backup binary"
    }
  fi

  # Backup configuration
  debug "Backing up configuration..."
  if [ -d "$INSTALL_DIR" ]; then
    tar -czf "${backup_path}.tar.gz" -C "$INSTALL_DIR" . 2>/dev/null || {
      warning "Failed to backup configuration"
    }
  fi

  # Create restore info
  cat > "${backup_path}.info" << EOF
Backup created: $(date)
Elytra version: $(get_current_version)
Backup type: pre-update
EOF

  # Cleanup old backups
  cleanup_old_backups

  success "Backup created: ${backup_name}"
  return 0
}

cleanup_old_backups() {
  debug "Cleaning up old backups (keeping last $KEEP_BACKUPS)"

  ls -t ${BACKUP_DIR}/elytra-backup-*.tar.gz 2>/dev/null | \
    tail -n +$((KEEP_BACKUPS + 1)) | \
    xargs -r rm -f 2>/dev/null || true

  ls -t ${BACKUP_DIR}/elytra-backup-*.binary 2>/dev/null | \
    tail -n +$((KEEP_BACKUPS + 1)) | \
    xargs -r rm -f 2>/dev/null || true

  ls -t ${BACKUP_DIR}/elytra-backup-*.info 2>/dev/null | \
    tail -n +$((KEEP_BACKUPS + 1)) | \
    xargs -r rm -f 2>/dev/null || true
}

# ------------------ Service Functions ----------------- #

stop_elytra() {
  info "Stopping Elytra service..."
  if systemctl is-active --quiet elytra 2>/dev/null; then
    systemctl stop elytra
    sleep 2
    success "Elytra stopped"
  else
    info "Elytra was not running"
  fi
}

start_elytra() {
  info "Starting Elytra service..."
  systemctl start elytra
  sleep 3

  if systemctl is-active --quiet elytra; then
    success "Elytra started successfully"
    return 0
  else
    error "Elytra failed to start"
    return 1
  fi
}

restart_elytra() {
  info "Restarting Elytra service..."
  systemctl restart elytra
  sleep 3

  if systemctl is-active --quiet elytra; then
    success "Elytra restarted successfully"
    return 0
  else
    error "Elytra failed to restart"
    return 1
  fi
}

# ------------------ Update Functions ----------------- #

get_download_url() {
  local version="$1"

  # Determine architecture
  local arch
  arch=$(uname -m)
  [[ $arch == x86_64 ]] && arch=amd64 || arch=arm64

  local asset_name="elytra_linux_${arch}"

  # Get asset download URL from GitHub API
  local release_info
  release_info=$(get_release_asset_info "$version")

  if [ -z "$release_info" ]; then
    return 1
  fi

  # Extract asset URL
  local asset_url
  asset_url=$(echo "$release_info" | jq -r ".assets[] | select(.name == \"$asset_name\") | .url" 2>/dev/null)

  if [ -z "$asset_url" ] || [ "$asset_url" == "null" ]; then
    error "Could not find asset '$asset_name' in release $version"
    return 1
  fi

  echo "$asset_url"
}

download_binary() {
  local version="$1"
  local output_file="$2"

  local asset_url
  asset_url=$(get_download_url "$version")

  if [ -z "$asset_url" ]; then
    return 1
  fi

  local curl_opts="-fsSL --max-time 300"
  curl_opts="$curl_opts -H \"Accept: application/octet-stream\""

  if [ -n "$GITHUB_TOKEN" ]; then
    curl_opts="$curl_opts -H \"Authorization: Bearer $GITHUB_TOKEN\""
    curl_opts="$curl_opts -H \"X-GitHub-Api-Version: 2022-11-28\""
  fi

  debug "Downloading from: $asset_url"

  if ! eval curl $curl_opts -o "$output_file" "$asset_url" 2>/dev/null; then
    error "Failed to download binary"
    return 1
  fi

  return 0
}

verify_binary() {
  local binary_path="$1"

  # Check if binary is executable and can show version
  if ! chmod +x "$binary_path" 2>/dev/null; then
    error "Cannot make binary executable"
    return 1
  fi

  if ! "$binary_path" --version >/dev/null 2>&1; then
    error "Binary does not appear to be valid"
    return 1
  fi

  return 0
}

perform_update() {
  local new_version="$1"

  info "Starting update to $new_version..."

  if [ "$DRY_RUN" == true ]; then
    info "DRY RUN: Would update to $new_version"
    return 0
  fi

  # Create backup
  if ! create_backup; then
    error "Backup failed, aborting update"
    return $EXIT_BACKUP_FAILED
  fi

  # Stop service
  stop_elytra

  # Download new binary
  local temp_file
  temp_file=$(mktemp)

  info "Downloading Elytra $new_version..."
  if ! download_binary "$new_version" "$temp_file"; then
    error "Download failed"
    rm -f "$temp_file"
    start_elytra || true
    return $EXIT_DOWNLOAD_FAILED
  fi

  # Verify binary
  info "Verifying binary..."
  if ! verify_binary "$temp_file"; then
    error "Binary verification failed"
    rm -f "$temp_file"
    start_elytra || true
    return $EXIT_DOWNLOAD_FAILED
  fi

  # Install new binary
  info "Installing new binary..."
  if ! mv "$temp_file" "/usr/local/bin/elytra"; then
    error "Failed to install binary"
    rm -f "$temp_file"
    start_elytra || true
    return $EXIT_UPDATE_FAILED
  fi

  chmod +x /usr/local/bin/elytra

  # Start service
  if ! start_elytra; then
    error "Failed to start Elytra after update"
    error "Attempting rollback..."

    # Attempt rollback
    local latest_backup
    latest_backup=$(ls -t ${BACKUP_DIR}/elytra-backup-*.binary 2>/dev/null | head -1)

    if [ -n "$latest_backup" ]; then
      info "Restoring from backup: $latest_backup"
      cp "$latest_backup" "/usr/local/bin/elytra"
      chmod +x "/usr/local/bin/elytra"
      start_elytra || true
    fi

    return $EXIT_UPDATE_FAILED
  fi

  # Log update
  echo "[$(date)] Updated from $(get_current_version) to ${new_version}" >> "${BACKUP_DIR}/update-history.log"

  success "Update to $new_version completed successfully!"
  return 0
}

send_notification() {
  local status="$1"
  local message="$2"

  # TODO: Implement notification methods (email, webhook, etc.)
  # For now, just log
  info "NOTIFICATION [$status]: $message"
}

# ------------------ Main Check Function ----------------- #

check_for_updates() {
  info "Checking for Elytra updates..."
  debug "Repository: $ELYTRA_REPO"
  debug "Install directory: $INSTALL_DIR"

  local current_version
  current_version=$(get_current_version)

  local latest_version
  latest_version=$(get_latest_release)

  if [ -z "$latest_version" ] || [ "$latest_version" == "null" ]; then
    error "Could not fetch latest version"
    return $EXIT_NO_RELEASE
  fi

  info "Current version: $current_version"
  info "Latest version: $latest_version"

  if [ "$current_version" == "$latest_version" ]; then
    info "Already up to date!"
    return $EXIT_SUCCESS
  fi

  if [ "$FORCE_UPDATE" != true ] && ! version_gt "$latest_version" "$current_version"; then
    warning "Current version ($current_version) is newer than latest ($latest_version)"
    warning "This may be a development build"
    return $EXIT_SUCCESS
  fi

  # Update available
  success "Update available: $latest_version"

  if [ "$NOTIFY_ONLY" == true ]; then
    send_notification "UPDATE_AVAILABLE" "Elytra update available: $latest_version"
    return $EXIT_SUCCESS
  fi

  if [ "$AUTO_UPDATE" != true ] && [ "$DRY_RUN" != true ]; then
    warning "Auto-update is disabled. Set AUTO_UPDATE=true to enable."
    return $EXIT_SUCCESS
  fi

  # Perform update
  if perform_update "$latest_version"; then
    send_notification "UPDATE_SUCCESS" "Elytra updated to $latest_version"
    return $EXIT_SUCCESS
  else
    send_notification "UPDATE_FAILED" "Failed to update Elytra"
    return $EXIT_UPDATE_FAILED
  fi
}

# ------------------ Argument Parsing ----------------- #

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --cron)
        CRON_MODE=true
        LOG_TO_FILE=true
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --notify-only)
        NOTIFY_ONLY=true
        shift
        ;;
      --force)
        FORCE_UPDATE=true
        shift
        ;;
      --verbose|-v)
        VERBOSE=true
        shift
        ;;
      --config)
        CONFIG_FILE="$2"
        shift 2
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      *)
        error "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done
}

show_help() {
  cat << EOF
Pyrodactyl Elytra Auto-Updater

Usage: $(basename "$0") [OPTIONS]

Options:
  --cron          Run in cron mode (no colors, log to file)
  --dry-run       Check for updates but don't install
  --notify-only   Only send notification if update is available
  --force         Force update even if versions match
  --verbose, -v   Enable verbose output
  --config FILE   Use alternative config file
  --help, -h      Show this help message

Configuration file: $CONFIG_FILE
Log file: $LOG_FILE
EOF
}

# ------------------ Main ----------------- #

main() {
  parse_arguments "$@"

  # Setup
  setup_colors
  load_config

  # Ensure directories exist
  mkdir -p "$(dirname "$LOG_FILE")"
  mkdir -p "$BACKUP_DIR"

  # Check if running as root
  if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
    exit $EXIT_ERROR
  fi

  # Check if Elytra is installed
  if [ ! -f "/usr/local/bin/elytra" ]; then
    error "Elytra not found at /usr/local/bin/elytra"
    exit $EXIT_ERROR
  fi

  # Acquire lock
  acquire_lock

  info "Starting Elytra auto-update check"
  info "Mode: $([ "$DRY_RUN" == true ] && echo "DRY RUN" || echo "LIVE")"

  local exit_code
  if check_for_updates; then
    exit_code=$EXIT_SUCCESS
  else
    exit_code=$?
    [ $exit_code -eq 0 ] && exit_code=$EXIT_ERROR
  fi

  # Cleanup
  release_lock

  debug "Exit code: $exit_code"
  exit $exit_code
}

# Handle signals
trap release_lock EXIT INT TERM

main "$@"
