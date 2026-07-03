#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Hydrodactyl Wings Auto-Updater                                                     #
#                                                                                    #
# Advanced auto-updater with cron support, dry-run mode, backups, and notifications  #
#                                                                                    #
# Usage:                                                                             #
#   auto-update-Wings.sh                    # Interactive mode with colors          #
#   auto-update-Wings.sh --cron             # Cron mode (no colors, log to file)    #
#   auto-update-Wings.sh --dry-run          # Check only, don't actually update      #
#   auto-update-Wings.sh --notify-only      # Only send notification if update avail #
#   auto-update-Wings.sh --force            # Force update even if versions match    #
#                                                                                    #
######################################################################################

# ------------------ Configuration ----------------- #

# Load environment file if it exists (for systemd service)
if [ -f /etc/Hydrodactyl/auto-update-Wings.env ]; then
  # shellcheck source=/dev/null
  source /etc/Hydrodactyl/auto-update-Wings.env
fi

# Default config (can be overridden by /etc/Hydrodactyl/auto-update-Wings.env)
WINGS_REPO="${WINGS_REPO:-blueprintframework/wings}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
INSTALL_DIR="${INSTALL_DIR:-/etc/Wings}"
LOG_FILE="${LOG_FILE:-/var/log/Hydrodactyl-Wings-auto-update.log}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/Wings}"
LOCK_FILE="${LOCK_FILE:-/var/run/Hydrodactyl-Wings-update.lock}"
CONFIG_FILE="${CONFIG_FILE:-/etc/Hydrodactyl/auto-update-Wings.env}"
VERSION_FILE="${VERSION_FILE:-/etc/Hydrodactyl/Wings-version}"
KEEP_BACKUPS="${KEEP_BACKUPS:-5}"
AUTO_UPDATE="${AUTO_UPDATE:-true}"
CHECK_INTERVAL="${CHECK_INTERVAL:-3600}"
# Wings is always updated via releases (distributed as binary)
UPDATE_METHOD="releases"
WINGS_REPO_PRIVATE="${WINGS_REPO_PRIVATE:-false}"

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
    COLOR_BLUE_THEME=''
    COLOR_NC=''
  else
    COLOR_GREEN='\033[0;32m'
    COLOR_YELLOW='\033[1;33m'
    COLOR_RED='\033[0;31m'
    COLOR_BLUE='\033[0;34m'
    COLOR_BLUE_THEME='\033[38;5;214m'
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
    log "${COLOR_BLUE_THEME}DEBUG${COLOR_NC}: $1"
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
  # First check version file
  if [ -f "$VERSION_FILE" ]; then
    local version
    version=$(cat "$VERSION_FILE" 2>/dev/null)
    if [ -n "$version" ]; then
      echo "$version"
      return 0
    fi
    # File exists but is empty, continue to fallback
  fi

  # Fall back to binary --version (for backwards compatibility)
  if [ -x "/usr/local/bin/Wings" ]; then
    local binary_version
    binary_version=$(/usr/local/bin/Wings --version 2>/dev/null)
    if [ -n "$binary_version" ] && [ "$binary_version" != "unknown" ]; then
      echo "$binary_version"
      return 0
    fi
  fi

  echo "unknown"
}

save_current_version() {
  local version="$1"
  echo "$version" > "$VERSION_FILE"
  chmod 644 "$VERSION_FILE"
}

get_latest_release() {
  # Ensure jq is available
  if ! command -v jq >/dev/null 2>&1; then
    log "ERROR: jq is required but not installed"
    return 1
  fi

  local curl_opts=("-sL" "--max-time" "30")

  if [ -n "$GITHUB_TOKEN" ]; then
    curl_opts+=("-H" "Authorization: Bearer $GITHUB_TOKEN")
  fi

  local release_json
  release_json=$(curl "${curl_opts[@]}" \
    "https://api.github.com/repos/$WINGS_REPO/releases/latest" 2>/dev/null)

  if [ -z "$release_json" ] || echo "$release_json" | grep -q '"message":"Not Found"'; then
    return 1
  fi

  echo "$release_json" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

get_release_asset_info() {
  local version="$1"
  local curl_opts=("-sL" "--max-time" "30")

  if [ -n "$GITHUB_TOKEN" ]; then
    curl_opts+=("-H" "Authorization: Bearer $GITHUB_TOKEN")
  fi

  # URL-encode version for API path
  local encoded_version
  encoded_version=$(printf '%s' "$version" | jq -sRr @uri 2>/dev/null || echo "$version")

  curl "${curl_opts[@]}" \
    "https://api.github.com/repos/$WINGS_REPO/releases/tags/$encoded_version" 2>/dev/null
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
  local backup_name="Wings-backup-${timestamp}"
  local backup_path="${BACKUP_DIR}/${backup_name}"

  # Backup binary
  debug "Backing up Wings binary..."
  if [ -f "/usr/local/bin/Wings" ]; then
    cp "/usr/local/bin/Wings" "${backup_path}.binary" 2>/dev/null || {
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
Wings version: $(get_current_version)
Backup type: pre-update
EOF

  # Cleanup old backups
  cleanup_old_backups

  success "Backup created: ${backup_name}"
  return 0
}

cleanup_old_backups() {
  debug "Cleaning up old backups (keeping last $KEEP_BACKUPS)"

  ls -t ${BACKUP_DIR}/Wings-backup-*.tar.gz 2>/dev/null | \
    tail -n +$((KEEP_BACKUPS + 1)) | \
    xargs -r rm -f 2>/dev/null || true

  ls -t ${BACKUP_DIR}/Wings-backup-*.binary 2>/dev/null | \
    tail -n +$((KEEP_BACKUPS + 1)) | \
    xargs -r rm -f 2>/dev/null || true

  ls -t ${BACKUP_DIR}/Wings-backup-*.info 2>/dev/null | \
    tail -n +$((KEEP_BACKUPS + 1)) | \
    xargs -r rm -f 2>/dev/null || true
}

# ------------------ Service Functions ----------------- #

stop_Wings() {
  info "Stopping Wings service..."
  if systemctl is-active --quiet Wings 2>/dev/null; then
    systemctl stop Wings
    sleep 2
    success "Wings stopped"
  else
    info "Wings was not running"
  fi
}

start_Wings() {
  info "Starting Wings service..."
  systemctl start Wings
  sleep 3

  if systemctl is-active --quiet Wings; then
    success "Wings started successfully"
    return 0
  else
    error "Wings failed to start"
    return 1
  fi
}

restart_Wings() {
  info "Restarting Wings service..."
  systemctl restart Wings
  sleep 3

  if systemctl is-active --quiet Wings; then
    success "Wings restarted successfully"
    return 0
  else
    error "Wings failed to restart"
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

  local asset_name="Wings_linux_${arch}"

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

  local curl_opts=("-fsSL" "--max-time" "300")
  curl_opts+=("-H" "Accept: application/octet-stream")

  if [ -n "$GITHUB_TOKEN" ]; then
    curl_opts+=("-H" "Authorization: Bearer $GITHUB_TOKEN")
    curl_opts+=("-H" "X-GitHub-Api-Version: 2022-11-28")
  fi

  debug "Downloading from: $asset_url"

  if ! curl "${curl_opts[@]}" -o "$output_file" "$asset_url" 2>/dev/null; then
    error "Failed to download binary"
    return 1
  fi

  return 0
}

verify_binary() {
  local binary_path="$1"

  # Check if binary exists and is non-empty
  if [ ! -s "$binary_path" ]; then
    error "Binary file is empty or does not exist"
    return 1
  fi

  # Check if binary is executable and can show help
  if ! chmod +x "$binary_path" 2>/dev/null; then
    error "Cannot make binary executable"
    return 1
  fi

  # Try --help first, then --version, then just check if it runs
  if "$binary_path" --help >/dev/null 2>&1; then
    return 0
  elif "$binary_path" --version >/dev/null 2>&1; then
    return 0
  elif "$binary_path" -h >/dev/null 2>&1; then
    return 0
  else
    # Last resort: check if it's a valid ELF binary
    if file "$binary_path" 2>/dev/null | grep -q "ELF"; then
      return 0
    fi
    error "Binary does not appear to be valid"
    return 1
  fi
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
  stop_Wings

  # Download new binary
  local temp_file
  temp_file=$(mktemp)

  info "Downloading Wings $new_version..."
  if ! download_binary "$new_version" "$temp_file"; then
    error "Download failed"
    rm -f "$temp_file"
    start_Wings || true
    return $EXIT_DOWNLOAD_FAILED
  fi

  # Verify binary
  info "Verifying binary..."
  if ! verify_binary "$temp_file"; then
    error "Binary verification failed"
    rm -f "$temp_file"
    start_Wings || true
    return $EXIT_DOWNLOAD_FAILED
  fi

  # Install new binary
  info "Installing new binary..."
  if ! mv "$temp_file" "/usr/local/bin/Wings"; then
    error "Failed to install binary"
    rm -f "$temp_file"
    start_Wings || true
    return $EXIT_UPDATE_FAILED
  fi

  chmod +x /usr/local/bin/Wings

  # Start service
  if ! start_Wings; then
    error "Failed to start Wings after update"
    error "Attempting rollback..."

    # Attempt rollback
    local latest_backup
    latest_backup=$(ls -t ${BACKUP_DIR}/Wings-backup-*.binary 2>/dev/null | head -1)

    if [ -n "$latest_backup" ]; then
      info "Restoring from backup: $latest_backup"
      cp "$latest_backup" "/usr/local/bin/Wings"
      chmod +x "/usr/local/bin/Wings"
      restart_Wings || true
    fi

    return $EXIT_UPDATE_FAILED
  fi

  # Run post-update health check with auto-fix
  info "Running post-update health check..."
  if ! post_update_health_check; then
    warning "Health check detected issues, attempting auto-fix..."
    auto_fix_Wings_issues

    # Run second health check after auto-fix
    info "Running second health check after auto-fix..."
    if ! post_update_health_check; then
      error "Auto-fix failed to resolve all issues"

      # Log failure information
      mkdir -p "$INSTALL_DIR"
      cat > "$INSTALL_DIR/update-health-check-failure.log" << EOF
[$(date)] Wings Update Health Check Failed
Version: ${new_version}
Status: Auto-fix applied but issues persist

Failed Checks:
EOF

      # Append specific failed checks to log
      if [ ! -f "/usr/local/bin/Wings" ]; then
        echo "- Wings binary not found" >> "$INSTALL_DIR/update-health-check-failure.log"
      elif [ ! -x "/usr/local/bin/Wings" ]; then
        echo "- Wings binary is not executable" >> "$INSTALL_DIR/update-health-check-failure.log"
      fi

      if [ ! -f "$INSTALL_DIR/config.yml" ]; then
        echo "- Wings config file not found" >> "$INSTALL_DIR/update-health-check-failure.log"
      fi

      for dir in /var/lib/Wings/volumes /var/lib/Wings/archives /var/lib/Wings/backups; do
        if [ ! -d "$dir" ]; then
          echo "- Data directory missing: $dir" >> "$INSTALL_DIR/update-health-check-failure.log"
        fi
      done

      if ! systemctl is-active --quiet docker 2>/dev/null; then
        echo "- Docker is not running" >> "$INSTALL_DIR/update-health-check-failure.log"
      fi

      if ! systemctl is-active --quiet Wings 2>/dev/null; then
        echo "- Wings service is not running" >> "$INSTALL_DIR/update-health-check-failure.log"
      fi

      echo "" >> "$INSTALL_DIR/update-health-check-failure.log"
      echo "Please run the Repair Tool or check manually:" >> "$INSTALL_DIR/update-health-check-failure.log"
      echo "bash <(curl -sSL https://Hydrodactyl-installer.muspelheim.host)" >> "$INSTALL_DIR/update-health-check-failure.log"
      echo "And select option [7] Repair / Fix Common Issues" >> "$INSTALL_DIR/update-health-check-failure.log"

      error "Update completed but health check failed. See: $INSTALL_DIR/update-health-check-failure.log"
      
      # Attempt rollback since health check failed
      error "Attempting rollback..."
      local latest_backup
      latest_backup=$(ls -t ${BACKUP_DIR}/Wings-backup-*.binary 2>/dev/null | head -1)
      if [ -n "$latest_backup" ]; then
        info "Restoring from backup: $latest_backup"
        cp "$latest_backup" "/usr/local/bin/Wings"
        chmod +x "/usr/local/bin/Wings"
        restart_Wings || true
      fi
      
      return $EXIT_UPDATE_FAILED
    fi
  fi

  # Save current version only after successful health check
  save_current_version "$new_version"

  # Log update
  echo "[$(date)] Updated to ${new_version}" >> "${BACKUP_DIR}/update-history.log"

  success "Update to $new_version completed successfully!"
  return 0
}

# ------------------ Post-Update Health Check & Auto-Fix ----------------- #

post_update_health_check() {
  local has_errors=false

  debug "Checking Wings binary..."
  if [ ! -f "/usr/local/bin/Wings" ]; then
    error "Wings binary not found"
    return 1
  fi

  if [ ! -x "/usr/local/bin/Wings" ]; then
    warning "Wings binary is not executable"
    has_errors=true
  fi

  debug "Checking Wings config..."
  if [ ! -f "$INSTALL_DIR/config.yml" ]; then
    warning "Wings config file not found"
    has_errors=true
  fi

  debug "Checking data directories..."
  for dir in /var/lib/Wings/volumes /var/lib/Wings/archives /var/lib/Wings/backups; do
    if [ ! -d "$dir" ]; then
      warning "Data directory missing: $dir"
      has_errors=true
    fi
  done

  debug "Checking Docker status..."
  if ! systemctl is-active --quiet docker 2>/dev/null; then
    warning "Docker is not running"
    has_errors=true
  fi

  debug "Checking Wings service..."
  if ! systemctl is-active --quiet Wings 2>/dev/null; then
    warning "Wings service is not running"
    has_errors=true
  fi

  if [ "$has_errors" == true ]; then
    return 1
  fi

  info "Health check passed"
  return 0
}

auto_fix_Wings_issues() {
  info "Attempting to auto-fix issues..."

  # Fix binary permissions
  if [ -f "/usr/local/bin/Wings" ]; then
    info "Fixing binary permissions..."
    chmod +x /usr/local/bin/Wings
  fi

  # Fix data directory permissions
  info "Fixing data directory permissions..."
  mkdir -p /var/lib/Wings/volumes /var/lib/Wings/archives /var/lib/Wings/backups

  chown -R 8888:8888 /var/lib/Wings/volumes 2>/dev/null || true
  chown -R 8888:8888 /var/lib/Wings/archives 2>/dev/null || true
  chown -R 8888:8888 /var/lib/Wings/backups 2>/dev/null || true
  chown -R 8888:8888 /etc/Wings 2>/dev/null || true

  # Fix permissions
  info "Fixing Wings permissions..."
  
  # Create directories if they don't exist
  mkdir -p /var/lib/Wings/volumes /var/lib/Wings/archives /var/lib/Wings/backups
  
  # Set permissions for containerized game servers
  # Note: 777 is required because game server containers run as arbitrary UIDs
  # and must be able to read/write/execute in these directories
  info "Setting 777 permissions on data directories for container access..."
  # Ensure parent /var/lib/Wings is accessible
  chmod 755 /var/lib/Wings 2>/dev/null || true
  # Ensure the volumes directory itself and all contents have 777
  chmod 777 /var/lib/Wings/volumes 2>/dev/null || true
  chmod -R 777 /var/lib/Wings/volumes/* 2>/dev/null || true
  chmod 777 /var/lib/Wings/archives 2>/dev/null || true
  chmod -R 777 /var/lib/Wings/archives/* 2>/dev/null || true
  chmod 777 /var/lib/Wings/backups 2>/dev/null || true
  chmod -R 777 /var/lib/Wings/backups/* 2>/dev/null || true
  
  # Disable check_permissions_on_boot to prevent Wings from resetting permissions
  if [ -f "/etc/Wings/config.yml" ]; then
    info "Disabling permission checks in Wings config..."
    sed -i 's/check_permissions_on_boot: true/check_permissions_on_boot: false/' /etc/Wings/config.yml 2>/dev/null || true
  fi
  
  # Wings config directory - create if needed and set more restrictive permissions
  mkdir -p /etc/Wings
  find /etc/Wings -type d -exec chmod 755 {} \; 2>/dev/null || true
  # SECURITY: Config contains daemon credentials - restrict to owner-only
  find /etc/Wings -type f -name "config.yml" -exec chmod 600 {} \; 2>/dev/null || true
  find /etc/Wings -type f ! -name "config.yml" -exec chmod 640 {} \; 2>/dev/null || true

  # Restart Wings service
  info "Restarting Wings service..."
  systemctl restart Wings 2>/dev/null || true

  # Verify Wings started
  sleep 3
  if systemctl is-active --quiet Wings 2>/dev/null; then
    success "Wings is now running"
  else
    warning "Wings may still have issues - manual intervention may be required"
  fi

  success "Auto-fix completed"
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
  info "Checking for Wings updates..."
  debug "Repository: $WINGS_REPO"
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
    send_notification "UPDATE_AVAILABLE" "Wings update available: $latest_version"
    return $EXIT_SUCCESS
  fi

  if [ "$AUTO_UPDATE" != true ] && [ "$DRY_RUN" != true ]; then
    warning "Auto-update is disabled. Set AUTO_UPDATE=true to enable."
    return $EXIT_SUCCESS
  fi

  # Perform update
  if perform_update "$latest_version"; then
    send_notification "UPDATE_SUCCESS" "Wings updated to $latest_version"
    return $EXIT_SUCCESS
  else
    send_notification "UPDATE_FAILED" "Failed to update Wings"
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
Hydrodactyl Wings Auto-Updater

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

  # Check if Wings is installed
  if [ ! -f "/usr/local/bin/Wings" ]; then
    error "Wings not found at /usr/local/bin/Wings"
    exit $EXIT_ERROR
  fi

  # Acquire lock
  acquire_lock

  info "Starting Wings auto-update check"
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
