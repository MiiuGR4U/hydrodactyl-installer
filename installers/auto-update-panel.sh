#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Pyrodactyl Panel Auto-Updater                                                      #
#                                                                                    #
# Advanced auto-updater with cron support, dry-run mode, backups, and notifications  #
#                                                                                    #
# Usage:                                                                             #
#   auto-update-panel.sh                    # Interactive mode with colors           #
#   auto-update-panel.sh --cron             # Cron mode (no colors, log to file)     #
#   auto-update-panel.sh --dry-run          # Check only, don't actually update       #
#   auto-update-panel.sh --notify-only      # Only send notification if update avail  #
#   auto-update-panel.sh --force            # Force update even if versions match     #
#                                                                                    #
######################################################################################

# ------------------ Configuration ----------------- #

# Load environment file if it exists (for systemd service)
if [ -f /etc/pyrodactyl/auto-update-panel.env ]; then
  # shellcheck source=/dev/null
  source /etc/pyrodactyl/auto-update-panel.env
fi

# Default config (can be overridden by /etc/pyrodactyl/auto-update-panel.conf)
PANEL_REPO="${PANEL_REPO:-pyrodactyl-oss/pyrodactyl}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
INSTALL_DIR="${INSTALL_DIR:-/var/www/pyrodactyl}"
LOG_FILE="${LOG_FILE:-/var/log/pyrodactyl-panel-auto-update.log}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/pyrodactyl}"
LOCK_FILE="${LOCK_FILE:-/var/run/pyrodactyl-panel-update.lock}"
CONFIG_FILE="${CONFIG_FILE:-/etc/pyrodactyl/auto-update-panel.conf}"
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
EXIT_BACKUP_FAILED=4    # Backup failed
EXIT_UPDATE_FAILED=5    # Update failed

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
  if [ -f "${INSTALL_DIR}/config/app.php" ]; then
    grep "'version'" "${INSTALL_DIR}/config/app.php" 2>/dev/null | \
      head -1 | \
      sed -E "s/.*'version' => '([^']+)'.*/\1/" || \
      echo "unknown"
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
    "https://api.github.com/repos/$PANEL_REPO/releases/latest" 2>/dev/null)

  if [ -z "$release_json" ] || echo "$release_json" | grep -q '"message":"Not Found"'; then
    return 1
  fi

  echo "$release_json" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

get_release_notes() {
  local version="$1"
  local curl_opts="-sL --max-time 30"

  if [ -n "$GITHUB_TOKEN" ]; then
    curl_opts="$curl_opts -H \"Authorization: Bearer $GITHUB_TOKEN\""
  fi

  eval curl $curl_opts \
    "https://api.github.com/repos/$PANEL_REPO/releases/tags/$version" 2>/dev/null | \
    jq -r '.body' 2>/dev/null | \
    head -20 || \
    echo "No release notes available"
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
  local backup_name="panel-backup-${timestamp}"
  local backup_path="${BACKUP_DIR}/${backup_name}"

  # Backup files
  debug "Backing up panel files..."
  if ! tar -czf "${backup_path}.tar.gz" -C "$INSTALL_DIR" . 2>/dev/null; then
    error "Failed to create file backup"
    return 1
  fi

  # Backup database
  debug "Backing up database..."
  local db_root_pass=""
  if [ -f /root/.config/pyrodactyl/db-credentials ]; then
    db_root_pass=$(grep '^root:' /root/.config/pyrodactyl/db-credentials 2>/dev/null | cut -d':' -f2)
  fi

  if [ -n "$db_root_pass" ]; then
    mysqldump -u root -p"${db_root_pass}" --single-transaction \
      --quick --lock-tables=false panel > "${backup_path}.sql" 2>/dev/null || {
      warning "Database backup failed (this is non-fatal)"
    }
  fi

  # Create restore info
  cat > "${backup_path}.info" << EOF
Backup created: $(date)
Panel version: $(get_current_version)
Backup type: pre-update
EOF

  # Cleanup old backups
  cleanup_old_backups

  success "Backup created: ${backup_name}"
  return 0
}

cleanup_old_backups() {
  debug "Cleaning up old backups (keeping last $KEEP_BACKUPS)"

  # Keep only the most recent backups
  ls -t ${BACKUP_DIR}/panel-backup-*.tar.gz 2>/dev/null | \
    tail -n +$((KEEP_BACKUPS + 1)) | \
    xargs -r rm -f 2>/dev/null || true

  ls -t ${BACKUP_DIR}/panel-backup-*.sql 2>/dev/null | \
    tail -n +$((KEEP_BACKUPS + 1)) | \
    xargs -r rm -f 2>/dev/null || true

  ls -t ${BACKUP_DIR}/panel-backup-*.info 2>/dev/null | \
    tail -n +$((KEEP_BACKUPS + 1)) | \
    xargs -r rm -f 2>/dev/null || true
}

# ------------------ Update Functions ----------------- #

download_release() {
  local version="$1"
  local output_file="$2"

  local download_url="https://github.com/${PANEL_REPO}/releases/download/${version}/panel.tar.gz"
  local curl_opts="-fsSL --max-time 300"

  if [ -n "$GITHUB_TOKEN" ]; then
    curl_opts="$curl_opts -H \"Authorization: Bearer ${GITHUB_TOKEN}\""
  fi

  debug "Downloading from: $download_url"

  if ! eval curl $curl_opts -o "$output_file" "$download_url" 2>/dev/null; then
    error "Failed to download release"
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

  # Put panel in maintenance mode
  info "Enabling maintenance mode..."
  cd "$INSTALL_DIR"
  php artisan down 2>/dev/null || true

  # Download new version
  local temp_dir
  temp_dir=$(mktemp -d)
  local download_file="${temp_dir}/panel-${new_version}.tar.gz"

  info "Downloading panel $new_version..."
  if ! download_release "$new_version" "$download_file"; then
    error "Download failed"
    php artisan up 2>/dev/null || true
    rm -rf "$temp_dir"
    return $EXIT_NO_RELEASE
  fi

  # Extract update
  info "Extracting update..."
  if ! tar -xzf "$download_file" -C "$temp_dir" 2>/dev/null; then
    error "Extraction failed"
    php artisan up 2>/dev/null || true
    rm -rf "$temp_dir"
    return $EXIT_UPDATE_FAILED
  fi

  # Apply update
  info "Applying update..."
  local extract_dir="${temp_dir}"
  if [ -d "${temp_dir}/panel" ]; then
    extract_dir="${temp_dir}/panel"
  fi

  # Preserve .env file
  cp "$INSTALL_DIR/.env" "${temp_dir}/.env.backup" 2>/dev/null || true

  # Copy new files
  rsync -a --exclude='.env' --exclude='storage/*' \
    "$extract_dir/" "$INSTALL_DIR/" 2>/dev/null || \
  cp -r "$extract_dir"/* "$INSTALL_DIR/" 2>/dev/null || {
    error "Failed to copy new files"
    php artisan up 2>/dev/null || true
    rm -rf "$temp_dir"
    return $EXIT_UPDATE_FAILED
  }

  # Restore .env if needed
  if [ -f "${temp_dir}/.env.backup" ]; then
    cp "${temp_dir}/.env.backup" "$INSTALL_DIR/.env"
  fi

  # Set permissions
  chown -R www-data:www-data "$INSTALL_DIR" 2>/dev/null || \
  chown -R nginx:nginx "$INSTALL_DIR" 2>/dev/null || true
  chmod -R 755 "$INSTALL_DIR/storage" "$INSTALL_DIR/bootstrap/cache" 2>/dev/null || true

  # Run migrations
  info "Running database migrations..."
  cd "$INSTALL_DIR"
  if ! php artisan migrate --force 2>/dev/null; then
    warning "Migration may have failed, continuing..."
  fi

  # Clear and rebuild caches
  info "Clearing caches..."
  php artisan config:clear 2>/dev/null || true
  php artisan cache:clear 2>/dev/null || true
  php artisan view:clear 2>/dev/null || true

  info "Rebuilding caches..."
  php artisan config:cache 2>/dev/null || true
  php artisan route:cache 2>/dev/null || true
  php artisan view:cache 2>/dev/null || true

  # Disable maintenance mode
  php artisan up 2>/dev/null || true

  # Cleanup
  rm -rf "$temp_dir"

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
  info "Checking for updates..."
  debug "Repository: $PANEL_REPO"
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
    send_notification "UPDATE_AVAILABLE" "Panel update available: $latest_version"
    return $EXIT_SUCCESS
  fi

  if [ "$AUTO_UPDATE" != true ] && [ "$DRY_RUN" != true ]; then
    warning "Auto-update is disabled. Set AUTO_UPDATE=true to enable."
    return $EXIT_SUCCESS
  fi

  # Perform update
  if perform_update "$latest_version"; then
    send_notification "UPDATE_SUCCESS" "Panel updated to $latest_version"
    return $EXIT_SUCCESS
  else
    send_notification "UPDATE_FAILED" "Failed to update panel"
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
Pyrodactyl Panel Auto-Updater

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

  # Check if panel is installed
  if [ ! -d "$INSTALL_DIR" ]; then
    error "Panel not found at $INSTALL_DIR"
    exit $EXIT_ERROR
  fi

  # Acquire lock
  acquire_lock

  info "Starting panel auto-update check"
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
