#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Pyrodactyl Installer Library                                                       #
#                                                                                    #
# Copyright (C) 2025, Muspelheim Hosting                                             #
#                                                                                    #
# https://github.com/Muspelheim-Hosting/pyrodactyl-installer                         #
#                                                                                    #
######################################################################################

# ------------------ Version Configuration ----------------- #

export GITHUB_SOURCE="${GITHUB_SOURCE:-main}"
export SCRIPT_RELEASE="${SCRIPT_RELEASE:-v1.0.0}"
export GITHUB_BASE_URL="${GITHUB_BASE_URL:-https://raw.githubusercontent.com/Muspelheim-Hosting/pyrodactyl-installer}"
export GITHUB_URL="$GITHUB_BASE_URL/$GITHUB_SOURCE"

# ------------------ Default Repositories ----------------- #

export DEFAULT_PANEL_REPO="pyrodactyl-oss/pyrodactyl"
export DEFAULT_ELYTRA_REPO="pyrohost/elytra"

# ------------------ Path Configuration ----------------- #

export INSTALL_DIR="/var/www/pyrodactyl"
export ELYTRA_DIR="/etc/elytra"
export PANEL_CONFIG_DIR="/etc/pyrodactyl"
export LOG_PATH="/var/log/pyrodactyl-installer.log"

# ------------------ Web Server User ----------------- #

export WEBUSER="www-data"
export WEBGROUP="www-data"
export PHP_VERSION="8.4"

# ------------------ Colors - Orange Gradient ----------------- #

export COLOR_DARK_ORANGE='\033[38;5;208m'
export COLOR_ORANGE='\033[38;5;214m'
export COLOR_LIGHT_ORANGE='\033[38;5;220m'
export COLOR_YELLOW='\033[1;33m'
export COLOR_GREEN='\033[0;32m'
export COLOR_RED='\033[0;31m'
export COLOR_BLUE='\033[0;34m'
export COLOR_CYAN='\033[0;36m'
export COLOR_NC='\033[0m'

# ------------------ Gradient Colors for Header ----------------- #
# Smooth flame gradient from red (top) to yellow (bottom)
# Smooth flame gradient colors (top to bottom) - red to gold
export GRADIENT_1='\033[38;5;196m'   # Deep red
export GRADIENT_2='\033[38;5;202m'   # Red-orange
export GRADIENT_3='\033[38;5;208m'   # Dark orange
export GRADIENT_4='\033[38;5;214m'   # Orange
export GRADIENT_5='\033[38;5;220m'   # Light orange
export GRADIENT_6='\033[38;5;221m'   # Yellow-orange
export GRADIENT_7='\033[38;5;222m'   # Gold
export GRADIENT_8='\033[38;5;226m'   # Yellow-gold
export GRADIENT_9='\033[38;5;227m'   # Bright gold
export GRADIENT_10='\033[38;5;228m'  # Light gold
export GRADIENT_11='\033[38;5;229m'  # Pale gold

# Gradient array for flame effects
GRADIENT_COLORS=(
  '\033[38;5;196m'  # Dark red
  '\033[38;5;202m'  # Red-Orange
  '\033[38;5;208m'  # Orange
  '\033[38;5;214m'  # Light Orange
  '\033[38;5;220m'  # Yellow-Orange
  '\033[38;5;226m'  # Yellow
)

# ------------------ Library Loaded Marker ----------------- #

lib_loaded() {
  return 0
}

# ------------------ Visual Functions ----------------- #

output() {
  echo -e "* $1"
}

success() {
  echo ""
  echo -e "* ${COLOR_GREEN}SUCCESS${COLOR_NC}: $1"
  echo ""
}

error() {
  echo ""
  echo -e "* ${COLOR_RED}ERROR${COLOR_NC}: $1" 1>&2
  echo ""
}

warning() {
  echo ""
  echo -e "* ${COLOR_YELLOW}WARNING${COLOR_NC}: $1"
  echo ""
}

info() {
  echo -e "* ${COLOR_BLUE}INFO${COLOR_NC}: $1"
}

print_brake() {
  local char="${2:-─}"
  for ((n = 0; n < $1; n++)); do
    echo -n "$char"
  done
  echo ""
}

print_header() {
  clear 2>/dev/null || true
  echo ""

  # Flame gradient header - smooth color transition from top to bottom
  echo -e "${GRADIENT_1}    ╔══════════════════════════════════════════════════════════════════════════════════════╗"
  echo -e "${GRADIENT_2}    ║                                                                                      ║"
  echo -e "${GRADIENT_3}    ║  ███╗   ███╗██╗   ██╗███████╗██████╗ ███████╗██╗     ██╗  ██╗███████╗██╗███╗   ███╗  ║"
  echo -e "${GRADIENT_4}    ║  ████╗ ████║██║   ██║██╔════╝██╔══██╗██╔════╝██║     ██║  ██║██╔════╝██║████╗ ████║  ║"
  echo -e "${GRADIENT_5}    ║  ██╔████╔██║██║   ██║███████╗██████╔╝█████╗  ██║     ███████║█████╗  ██║██╔████╔██║  ║"
  echo -e "${GRADIENT_6}    ║  ██║╚██╔╝██║██║   ██║╚════██║██╔═══╝ ██╔══╝  ██║     ██╔══██║██╔══╝  ██║██║╚██╔╝██║  ║"
  echo -e "${GRADIENT_7}    ║  ██║ ╚═╝ ██║╚██████╔╝███████║██║     ███████╗███████╗██║  ██║███████╗██║██║ ╚═╝ ██║  ║"
  echo -e "${GRADIENT_8}    ║  ╚═╝     ╚═╝ ╚═════╝ ╚══════╝╚═╝     ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝╚═╝     ╚═╝  ║"
  echo -e "${GRADIENT_9}    ║                                                                                      ║"
  echo -e "${GRADIENT_10}    ║                            Pyrodactyl Installation Manager                           ║"
  echo -e "${GRADIENT_11}    ╚══════════════════════════════════════════════════════════════════════════════════════╝"
  echo -e "${COLOR_NC}"
  echo -e "    ${COLOR_ORANGE}Version:${COLOR_NC} ${SCRIPT_RELEASE}  ${COLOR_ORANGE}|${COLOR_NC}  ${COLOR_ORANGE}By:${COLOR_NC} Muspelheim Hosting"
  echo ""
}

print_flame() {
  local message="$1"

  echo ""
  echo -e "${COLOR_ORANGE}  $message${COLOR_NC}"
  echo ""
}

hyperlink() {
  echo -e "\e]8;;${1}\a${1}\e]8;;\a"
}

welcome() {
  print_header

  detect_os

  echo -e "  ${COLOR_ORANGE}Operating System:${COLOR_NC} $OS $OS_VER_MAJOR ($ARCH)"
  echo ""

  # Check installed components
  if [ -d "/var/www/pyrodactyl" ]; then
    local panel_version="unknown"
    if [ -f "/var/www/pyrodactyl/config/app.php" ]; then
      panel_version=$(grep "'version'" /var/www/pyrodactyl/config/app.php 2>/dev/null | head -1 | cut -d"'" -f4 || echo "unknown")
    fi
    echo -e "  ${COLOR_GREEN}✓${COLOR_NC} Panel installed${panel_version:+ (v$panel_version)}"
  else
    echo -e "  ${COLOR_RED}✗${COLOR_NC} Panel not installed"
  fi

  if [ -f "/usr/local/bin/elytra" ]; then
    echo -e "  ${COLOR_GREEN}✓${COLOR_NC} Elytra installed"
  else
    echo -e "  ${COLOR_RED}✗${COLOR_NC} Elytra not installed"
  fi

  if systemctl is-enabled --quiet pyrodactyl-panel-auto-update.timer 2>/dev/null; then
    echo -e "  ${COLOR_GREEN}✓${COLOR_NC} Panel auto-updater enabled"
  else
    echo -e "  ${COLOR_RED}✗${COLOR_NC} Panel auto-updater not installed"
  fi

  if systemctl is-enabled --quiet pyrodactyl-elytra-auto-update.timer 2>/dev/null; then
    echo -e "  ${COLOR_GREEN}✓${COLOR_NC} Elytra auto-updater enabled"
  else
    echo -e "  ${COLOR_RED}✗${COLOR_NC} Elytra auto-updater not installed"
  fi

  echo ""
  print_brake 70
  echo ""
}

# ------------------ OS Detection ----------------- #

detect_os() {
  export OS=""
  export OS_VER_MAJOR=""
  export CPU_ARCHITECTURE=""
  export ARCH=""
  export SUPPORTED=false

  CPU_ARCHITECTURE=$(uname -m)

  case "$CPU_ARCHITECTURE" in
    x86_64)
      ARCH=amd64
      ;;
    arm64|aarch64)
      ARCH=arm64
      ;;
    *)
      error "Only x86_64 and arm64 are supported!"
      exit 1
      ;;
  esac

  if [ -f /etc/os-release ]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    OS=$(echo "$ID" | awk '{print tolower($0)}')
    OS_VER=$VERSION_ID
  elif type lsb_release >/dev/null 2>&1; then
    OS=$(lsb_release -si | awk '{print tolower($0)}')
    OS_VER=$(lsb_release -sr)
  elif [ -f /etc/lsb-release ]; then
    # shellcheck source=/dev/null
    source /etc/lsb-release
    OS=$(echo "$DISTRIB_ID" | awk '{print tolower($0)}')
    OS_VER=$DISTRIB_RELEASE
  elif [ -f /etc/debian_version ]; then
    OS="debian"
    OS_VER=$(cat /etc/debian_version)
  else
    OS=$(uname -s)
    OS_VER=$(uname -r)
  fi

  OS=$(echo "$OS" | awk '{print tolower($0)}')
  OS_VER_MAJOR=$(echo "$OS_VER" | cut -d. -f1)

  # Set web user based on OS
  case "$OS" in
    ubuntu|debian)
      WEBUSER="www-data"
      WEBGROUP="www-data"
      ;;
    rocky|almalinux|centos|rhel|fedora)
      WEBUSER="nginx"
      WEBGROUP="nginx"
      ;;
  esac

  # Check supported versions
  case "$OS" in
    ubuntu)
      [ "$OS_VER_MAJOR" == "22" ] && SUPPORTED=true
      [ "$OS_VER_MAJOR" == "24" ] && SUPPORTED=true
      export DEBIAN_FRONTEND=noninteractive
      ;;
    debian)
      [ "$OS_VER_MAJOR" == "11" ] && SUPPORTED=true
      [ "$OS_VER_MAJOR" == "12" ] && SUPPORTED=true
      [ "$OS_VER_MAJOR" == "13" ] && SUPPORTED=true
      export DEBIAN_FRONTEND=noninteractive
      ;;
    rocky|almalinux)
      [ "$OS_VER_MAJOR" == "8" ] && SUPPORTED=true
      [ "$OS_VER_MAJOR" == "9" ] && SUPPORTED=true
      [ "$OS_VER_MAJOR" == "10" ] && SUPPORTED=true
      ;;
    fedora)
      [ "$OS_VER_MAJOR" == "40" ] && SUPPORTED=true
      [ "$OS_VER_MAJOR" == "41" ] && SUPPORTED=true
      [ "$OS_VER_MAJOR" == "42" ] && SUPPORTED=true
      ;;
    rhel)
      [ "$OS_VER_MAJOR" == "9" ] && SUPPORTED=true
      [ "$OS_VER_MAJOR" == "10" ] && SUPPORTED=true
      ;;
    arch)
      SUPPORTED=true
      ;;
  esac

  if [ "$SUPPORTED" != true ]; then
    error "Operating system $OS $OS_VER is not officially supported."
    warning "The installer may still work, but proceed at your own risk."
    echo ""
    local continue_anyway=""
    while [[ "$continue_anyway" != "y" && "$continue_anyway" != "n" ]]; do
      echo -n "* Continue anyway? [y/N]: "
      read -r continue_anyway
      continue_anyway=$(echo "$continue_anyway" | tr '[:upper:]' '[:lower:]')
      [ -z "$continue_anyway" ] && continue_anyway="n"

      if [[ "$continue_anyway" != "y" && "$continue_anyway" != "n" ]]; then
        error "Invalid input. Please enter 'y' or 'n'."
      fi
    done

    if [[ "$continue_anyway" == "n" ]]; then
      exit 1
    fi
  fi
}

# ------------------ Validation Functions ----------------- #

check_fqdn() {
  local fqdn="$1"

  # Must not be empty
  [ -z "$fqdn" ] && return 1

  # Must contain at least one dot
  [[ "$fqdn" =~ \. ]] || return 1

  # Must not be an IP address
  [[ "$fqdn" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && return 1

  # Basic format validation
  [[ "$fqdn" =~ ^[a-zA-Z0-9][-a-zA-Z0-9.]*[a-zA-Z0-9]$ ]] || return 1

  # No consecutive dots
  [[ "$fqdn" =~ \.\. ]] && return 1

  # Not start or end with hyphen
  [[ "$fqdn" =~ ^-|-$ ]] && return 1

  return 0
}

cmd_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Load existing database credentials from previous run
# Usage: load_existing_db_credentials [variable_name]
# Returns 0 if credentials loaded successfully, 1 otherwise
load_existing_db_credentials() {
  local creds_file="/root/.config/pyrodactyl/db-credentials"

  if [ -f "$creds_file" ]; then
    output "Found existing database credentials, loading..."
    local saved_root_pass
    saved_root_pass=$(grep '^root:' "$creds_file" | cut -d':' -f2)

    # Test if saved credentials work
    if mysql -u root -p"${saved_root_pass}" -e "SELECT 1" >/dev/null 2>&1; then
      echo "${saved_root_pass}"
      success "Existing database credentials validated"
      return 0
    else
      error "Saved database credentials don't work!"
      error "MariaDB may have been configured with a different password."
      error "Please set MYSQL_ROOT_PASSWORD environment variable or reset MariaDB"
      exit 1
    fi
  fi
  return 1
}

check_existing_installation() {
  local component="$1"
  local has_existing=false

  if [ "$component" == "panel" ] && [ -d "/var/www/pyrodactyl" ]; then
    warning "Existing panel installation detected at /var/www/pyrodactyl"
    has_existing=true
  elif [ "$component" == "elytra" ] && [ -f "/usr/local/bin/elytra" ]; then
    warning "Existing Elytra installation detected at /usr/local/bin/elytra"
    has_existing=true
  fi

  if [ "$has_existing" == true ]; then
    return 0
  else
    return 1
  fi
}

valid_email() {
  local email="$1"
  local email_regex="^(([A-Za-z0-9]+((\.|\-|\_|\+)?[A-Za-z0-9]?)*[A-Za-z0-9]+)|[A-Za-z0-9]+)@(([A-Za-z0-9]+)+((\.|\-|\_)?([A-Za-z0-9]+)+)*)+\.([A-Za-z]{2,})+$"
  [[ "$email" =~ $email_regex ]]
}

invalid_ip() {
  local ip="$1"
  ip route get "$ip" >/dev/null 2>&1
  echo $?
}

# ------------------ Password Generation ----------------- #

gen_passwd() {
  local length=$1
  local charset='A-Za-z0-9!@#$%^&*()_+'
  tr -dc "$charset" < /dev/urandom | fold -w "$length" | head -n 1
}

# ------------------ GitHub API Functions ----------------- #

get_latest_release() {
  local repo="$1"
  local token="${2:-$GITHUB_TOKEN}"

  local curl_opts="-sL --max-time 30"
  if [ -n "$token" ]; then
    curl_opts="$curl_opts -H \"Authorization: Bearer $token\""
  fi

  local release_json
  release_json=$(eval curl $curl_opts "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null)

  if [ -z "$release_json" ] || echo "$release_json" | grep -q '"message":"Not Found"'; then
    return 1
  fi

  echo "$release_json" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

check_releases_exist() {
  local repo="$1"
  local token="${2:-$GITHUB_TOKEN}"

  local curl_opts="-sL --max-time 30"
  if [ -n "$token" ]; then
    curl_opts="$curl_opts -H \"Authorization: Bearer $token\""
  fi

  local release_json
  release_json=$(eval curl $curl_opts "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null)

  if [ -z "$release_json" ] || echo "$release_json" | grep -q '"message":"Not Found"'; then
    return 1
  fi

  local tag_name
  tag_name=$(echo "$release_json" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

  [ -n "$tag_name" ] && [ "$tag_name" != "null" ]
}

validate_github_token() {
  local token="$1"
  local repo="$2"

  # Validate token format
  if [ -z "$token" ] || [ ${#token} -lt 10 ]; then
    error "Invalid token format"
    return 1
  fi

  # Check if token works by accessing the repo
  local response
  response=$(curl -sL -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$repo" 2>/dev/null)

  if echo "$response" | grep -q '"message":"Bad credentials"'; then
    error "Invalid GitHub token"
    return 1
  fi

  if echo "$response" | grep -q '"message":"Not Found"'; then
    error "Token cannot access repository $repo"
    error "Ensure the token has 'repo' scope for private repositories"
    return 1
  fi

  return 0
}

get_release_asset_url() {
  local repo="$1"
  local asset_name="$2"
  local token="${3:-$GITHUB_TOKEN}"

  # Ensure jq is installed
  if ! cmd_exists jq; then
    error "jq is required but not installed"
    error "Please install jq first"
    return 1
  fi

  local release_json
  if [ -n "$token" ]; then
    release_json=$(curl -sS \
      --header "Accept: application/vnd.github+json" \
      --header "Authorization: Bearer $token" \
      --header "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.github.com/repos/$repo/releases/latest" 2>&1)
  else
    release_json=$(curl -sS \
      --header "Accept: application/vnd.github+json" \
      --header "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.github.com/repos/$repo/releases/latest" 2>&1)
  fi

  if [ -z "$release_json" ]; then
    error "Failed to fetch release info from GitHub API (empty response)"
    return 1
  fi

  if echo "$release_json" | grep -q '"message"'; then
    local error_msg
    error_msg=$(echo "$release_json" | jq -r '.message' 2>/dev/null || echo "$release_json")
    error "GitHub API error: $error_msg"
    return 1
  fi

  echo "$release_json" | jq -r ".assets[] | select(.name == \"$asset_name\") | .url" 2>/dev/null
}

download_release_asset() {
  local repo="$1"
  local asset_name="$2"
  local output_path="$3"
  local token="${4:-$GITHUB_TOKEN}"

  local asset_url
  asset_url=$(get_release_asset_url "$repo" "$asset_name" "$token")

  if [ -z "$asset_url" ] || [ "$asset_url" == "null" ]; then
    error "Could not find asset '$asset_name' in latest release of $repo"
    error "Make sure the release exists and the asset is attached to it."
    return 1
  fi

  # Download using GitHub API asset URL with proper headers
  local curl_exit_code=0
  if [ -n "$token" ]; then
    curl --location --fail --silent --show-error --max-time 300 \
      --header "Accept: application/octet-stream" \
      --header "Authorization: Bearer $token" \
      --header "X-GitHub-Api-Version: 2022-11-28" \
      --output "$output_path" \
      "$asset_url" 2>&1 || curl_exit_code=$?
  else
    curl --location --fail --silent --show-error --max-time 300 \
      --header "Accept: application/octet-stream" \
      --output "$output_path" \
      "$asset_url" 2>&1 || curl_exit_code=$?
  fi

  if [ $curl_exit_code -ne 0 ]; then
    error "Failed to download asset (curl exit code: $curl_exit_code)"
    error "Asset URL: $asset_url"
    if [ -n "$token" ]; then
      error "Make sure your GitHub token has 'repo' scope access to $repo"
    else
      error "If this is a private repository, provide a GitHub token with 'repo' scope"
    fi
    return 1
  fi

  if [ ! -f "$output_path" ] || [ ! -s "$output_path" ]; then
    error "Downloaded file is empty or does not exist: $output_path"
    return 1
  fi

  return 0
}

# ------------------ Input Functions ----------------- #

required_input() {
  local __resultvar=$1
  local prompt="$2"
  local error_msg="${3:-This field is required}"
  local default_value="$4"
  local result=""

  while [ -z "$result" ]; do
    echo -n "* $prompt"
    read -r result

    if [ -z "$result" ]; then
      if [ -n "$default_value" ]; then
        result="$default_value"
      else
        error "$error_msg"
      fi
    fi
  done

  eval "$__resultvar=\"$result\""
}

email_input() {
  local __resultvar=$1
  local prompt="$2"
  local error_msg="${3:-Please enter a valid email address}"
  local result=""

  while ! valid_email "$result"; do
    echo -n "* $prompt"
    read -r result

    if ! valid_email "$result"; then
      error "$error_msg"
    fi
  done

  eval "$__resultvar=\"$result\""
}

password_input() {
  local __resultvar=$1
  local prompt="$2"
  local error_msg="${3:-Password cannot be empty}"
  local default_value="$4"
  local result=""

  while [ -z "$result" ]; do
    echo -n "* $prompt"

    while IFS= read -r -s -n1 char; do
      [[ -z $char ]] && { printf '\n'; break; }

      if [[ $char == $'\x7f' ]]; then
        if [ -n "$result" ]; then
          result=${result%?}
          printf '\b \b'
        fi
      else
        result+=$char
        printf '*'
      fi
    done

    if [ -z "$result" ] && [ -n "$default_value" ]; then
      result="$default_value"
    elif [ -z "$result" ]; then
      error "$error_msg"
    fi
  done

  eval "$__resultvar=\"$result\""
}

bool_input() {
  local __resultvar=$1
  local prompt="$2"
  local default="${3:-n}"
  local result=""
  local prompt_suffix=""

  # Set prompt suffix based on default
  if [ "$default" == "y" ]; then
    prompt_suffix="[Y/n] (default: y)"
  else
    prompt_suffix="[y/N] (default: n)"
  fi

  while [[ "$result" != "y" && "$result" != "n" ]]; do
    echo -n "* $prompt $prompt_suffix: "
    read -r result
    result=$(echo "$result" | tr '[:upper:]' '[:lower:]')
    [ -z "$result" ] && result="$default"
  done

  eval "$__resultvar=\"$result\""
}

array_contains_element() {
  local match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

# ------------------ Package Manager Functions ----------------- #

update_repos() {
  local quiet="${1:-false}"
  local args=""

  [ "$quiet" == true ] && args="-qq"

  case "$OS" in
    ubuntu|debian)
      output "Updating package repositories..."
      apt-get update -y $args || {
        error "Failed to update repositories"
        return 1
      }
      ;;
    rocky|almalinux|fedora|rhel|centos)
      # These distros auto-refresh, but we can manually update if needed
      output "Updating package repositories..."
      dnf check-update -y || true  # Returns 100 if updates available, which is OK
      ;;
    arch)
      output "Updating package database..."
      pacman -Sy --noconfirm || true
      ;;
  esac
}

install_packages() {
  local packages="$1"
  local quiet="${2:-false}"
  local args=""

  if [ "$quiet" == true ]; then
    case "$OS" in
      ubuntu|debian) args="-qq" ;;
      *) args="-q" ;;
    esac
  fi

  case "$OS" in
    ubuntu|debian)
      apt-get install -y $args $packages || {
        error "Failed to install packages: $packages"
        return 1
      }
      ;;
    rocky|almalinux|fedora|rhel|centos)
      dnf install -y $args $packages || {
        error "Failed to install packages: $packages"
        return 1
      }
      ;;
    arch)
      pacman -S --noconfirm $packages || {
        error "Failed to install packages: $packages"
        return 1
      }
      ;;
  esac
}

# ------------------ MySQL/MariaDB Functions ----------------- #

configure_mariadb_tcp() {
  output "Configuring MariaDB for TCP connections..."

  # Create MariaDB configuration file to enable TCP connections
  local mariadb_conf_dir=""
  case "$OS" in
    ubuntu|debian)
      mariadb_conf_dir="/etc/mysql/mariadb.conf.d"
      ;;
    rocky|almalinux|fedora|rhel|centos)
      mariadb_conf_dir="/etc/my.cnf.d"
      ;;
    *)
      mariadb_conf_dir="/etc/mysql/conf.d"
      ;;
  esac

  # Ensure the directory exists
  mkdir -p "$mariadb_conf_dir"

  # Create configuration file
  cat > "${mariadb_conf_dir}/99-pyrodactyl.cnf" <<EOF
[mysqld]
bind-address = 0.0.0.0
port = 3306
max_connections = 1000
innodb_buffer_pool_size = 1G
innodb_log_file_size = 256M
innodb_flush_log_at_trx_commit = 1
innodb_lock_wait_timeout = 50
EOF

  # Restart MariaDB to apply changes
  systemctl restart mariadb || systemctl restart mysql || true

  # Wait for MariaDB to be ready
  local attempts=0
  while ! mysqladmin ping --silent 2>/dev/null; do
    attempts=$((attempts + 1))
    if [ $attempts -gt 30 ]; then
      error "MariaDB failed to start after configuration"
      return 1
    fi
    sleep 1
  done

  success "MariaDB configured for TCP connections"
}

create_db_user() {
  local username="$1"
  local password="$2"
  local host="${3:-127.0.0.1}"

  output "Creating database user '$username'..."

  mysql -u root -e "CREATE USER IF NOT EXISTS '$username'@'$host' IDENTIFIED BY '$password';" || {
    error "Failed to create database user"
    return 1
  }

  mysql -u root -e "FLUSH PRIVILEGES;"
  success "Database user created"
}

grant_all_privileges() {
  local db_name="$1"
  local username="$2"
  local host="${3:-127.0.0.1}"

  output "Granting privileges on '$db_name' to '$username'..."

  mysql -u root -e "GRANT ALL PRIVILEGES ON $db_name.* TO '$username'@'$host' WITH GRANT OPTION;" || {
    error "Failed to grant privileges"
    return 1
  }

  mysql -u root -e "FLUSH PRIVILEGES;"
  success "Privileges granted"
}

create_db() {
  local db_name="$1"
  local username="$2"
  local host="${3:-127.0.0.1}"

  output "Creating database '$db_name'..."

  mysql -u root -e "CREATE DATABASE IF NOT EXISTS $db_name;" || {
    error "Failed to create database"
    return 1
  }

  grant_all_privileges "$db_name" "$username" "$host"
  success "Database created"
}

# ------------------ Firewall Functions ----------------- #

ask_firewall() {
  local __resultvar=$1
  local confirm=""

  case "$OS" in
    ubuntu|debian)
      while [[ "$confirm" != "y" && "$confirm" != "n" ]]; do
        echo -n "* Automatically configure UFW firewall? [y/N]: "
        read -r confirm
        confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]')
        [ -z "$confirm" ] && confirm="n"

        if [[ "$confirm" != "y" && "$confirm" != "n" ]]; then
          error "Invalid input. Please enter 'y' or 'n'."
        fi
      done
      [[ "$confirm" == "y" ]] && eval "$__resultvar=true" || eval "$__resultvar=false"
      ;;
    rocky|almalinux|fedora|rhel|centos)
      while [[ "$confirm" != "y" && "$confirm" != "n" ]]; do
        echo -n "* Automatically configure firewalld? [y/N]: "
        read -r confirm
        confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]')
        [ -z "$confirm" ] && confirm="n"

        if [[ "$confirm" != "y" && "$confirm" != "n" ]]; then
          error "Invalid input. Please enter 'y' or 'n'."
        fi
      done
      [[ "$confirm" == "y" ]] && eval "$__resultvar=true" || eval "$__resultvar=false"
      ;;
    *)
      warning "Automatic firewall configuration not supported for $OS"
      eval "$__resultvar=false"
      ;;
  esac
}

ask_game_ports() {
  local __start_var=$1
  local __end_var=$2
  local start_port=""
  local end_port=""

  echo ""
  output "Configure game server port range"
  output "The following port ranges will be opened for popular games:"
  output "  - Minecraft: 25565-25665"
  output "  - Source Engine (CS:GO, TF2, GMod): 27015-27150"
  output "  - Unreal Engine (ARK, Satisfactory): 7777-8000"
  output "  - Rust: 28015-28025"
  output "  - Valheim: 2456-2466"
  output "  - FiveM/GTA: 30120-30130"
  output "  - General range: 27015-28025"

  # Validate start port
  while true; do
    echo -n "* Start port [27015]: "
    read -r start_port
    start_port=${start_port:-27015}

    if ! [[ "$start_port" =~ ^[0-9]+$ ]]; then
      error "Invalid input. Please enter a numeric port value."
    elif [ "$start_port" -lt 1 ] || [ "$start_port" -gt 65535 ]; then
      error "Invalid port. Port must be between 1 and 65535."
    else
      break
    fi
  done

  # Validate end port
  while true; do
    echo -n "* End port [28025]: "
    read -r end_port
    end_port=${end_port:-28025}

    if ! [[ "$end_port" =~ ^[0-9]+$ ]]; then
      error "Invalid input. Please enter a numeric port value."
    elif [ "$end_port" -lt 1 ] || [ "$end_port" -gt 65535 ]; then
      error "Invalid port. Port must be between 1 and 65535."
    elif [ "$end_port" -le "$start_port" ]; then
      error "End port must be greater than start port ($start_port)."
    else
      break
    fi
  done

  eval "$__start_var=$start_port"
  eval "$__end_var=$end_port"
}

# Comprehensive game port configuration for popular games
configure_game_ports() {
  local start_port="${1:-27015}"

  output "Configuring game server ports starting from $start_port..."

  # Calculate port ranges based on start port
  local minecraft_start=$start_port
  local minecraft_end=$((start_port + 100))
  local source_start=$((minecraft_end + 1))
  local source_end=$((source_start + 135))
  local unreal_start=$((source_end + 1))
  local unreal_end=$((unreal_start + 200))
  local rust_start=$((unreal_end + 1))
  local rust_end=$((rust_start + 10))
  local valheim_start=$((rust_end + 1))
  local valheim_end=$((valheim_start + 10))
  local fivem_start=$((valheim_end + 1))
  local fivem_end=$((fivem_start + 10))

  output "Port allocation:"
  output "  Minecraft: $minecraft_start-$minecraft_end"
  output "  Source Engine: $source_start-$source_end"
  output "  ARK/Satisfactory: $unreal_start-$unreal_end"
  output "  Rust: $rust_start-$rust_end"
  output "  Valheim: $valheim_start-$valheim_end"
  output "  FiveM: $fivem_start-$fivem_end"

  # Return the full range
  GAME_PORT_START=$start_port
  GAME_PORT_END=$fivem_end
}

install_firewall() {
  case "$OS" in
    ubuntu|debian)
      if ! cmd_exists ufw; then
        output "Installing UFW..."
        apt-get install -y ufw
      fi
      ufw --force enable
      success "UFW enabled"
      ;;
    rocky|almalinux|fedora|rhel|centos)
      if ! cmd_exists firewall-cmd; then
        output "Installing firewalld..."
        dnf install -y firewalld
      fi
      systemctl enable --now firewalld
      success "Firewalld enabled"
      ;;
  esac
}

firewall_allow_ports() {
  local ports="$1"

  case "$OS" in
    ubuntu|debian)
      for port in $ports; do
        if [[ "$port" == *":"* ]]; then
          ufw allow "$port/tcp"
          ufw allow "$port/udp"
        else
          ufw allow "$port/tcp"
          ufw allow "$port/udp"
        fi
      done
      ufw --force reload
      ;;
    rocky|almalinux|fedora|rhel|centos)
      for port in $ports; do
        if [[ "$port" == *":"* ]]; then
          firewall-cmd --zone=public --add-port="$port"/tcp --permanent
          firewall-cmd --zone=public --add-port="$port"/udp --permanent
        else
          firewall-cmd --zone=public --add-port="$port"/tcp --permanent
          firewall-cmd --zone=public --add-port="$port"/udp --permanent
        fi
      done
      firewall-cmd --reload
      ;;
  esac
}

configure_firewall_rules() {
  local http="${1:-true}"
  local https="${2:-true}"
  local elytra="${3:-false}"
  local game_start="${4:-0}"
  local game_end="${5:-0}"

  output "Configuring firewall rules..."

  local ports="22"  # SSH is always allowed

  [ "$http" == true ] && ports="$ports 80"
  [ "$https" == true ] && ports="$ports 443"
  [ "$elytra" == true ] && ports="$ports 8080 2022"

  # Always open specific game port ranges for comprehensive game support
  output "Opening game server ports..."
  output "  • 25565-25665 (Minecraft)"
  output "  • 27015-27150 (Source Engine - CS:GO, TF2, GMod)"
  output "  • 7777-8000 (Unreal Engine - ARK, Satisfactory)"
  output "  • 28015-28025 (Rust)"
  output "  • 2456-2466 (Valheim)"
  output "  • 30120-30130 (FiveM/GTA)"

  ports="$ports 25565:25665 27015:27150 7777:8000 28015:28025 2456:2466 30120:30130"

  if [ "$game_start" != "0" ] && [ "$game_end" != "0" ]; then
    ports="$ports ${game_start}:${game_end}"
  fi

  firewall_allow_ports "$ports"
  success "Firewall configured"
}

# ------------------ Virtualization Check ----------------- #

check_virt() {
  output "Checking virtualization..."

  if ! cmd_exists virt-what; then
    install_packages "virt-what" true
  fi

  export PATH="$PATH:/sbin:/usr/sbin"

  local virt_type
  virt_type=$(virt-what 2>/dev/null | head -1)

  case "$virt_type" in
    openvz|lxc)
      warning "Unsupported virtualization detected: $virt_type"
      warning "Docker may not work properly in this environment"
      local confirm=""
      while [[ "$confirm" != "y" && "$confirm" != "n" ]]; do
        echo -n "* Continue anyway? [y/N]: "
        read -r confirm
        confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]')
        [ -z "$confirm" ] && confirm="n"

        if [[ "$confirm" != "y" && "$confirm" != "n" ]]; then
          error "Invalid input. Please enter 'y' or 'n'."
        fi
      done

      if [[ "$confirm" == "n" ]]; then
        exit 1
      fi
      ;;
    *)
      [ -n "$virt_type" ] && info "Virtualization: $virt_type"
      ;;
  esac

  success "Virtualization check complete"
}

# ------------------ PHP Functions ----------------- #

install_composer() {
  if cmd_exists composer; then
    output "Composer is already installed"
    return 0
  fi

  output "Installing Composer..."

  php -r "copy('https://getcomposer.org/installer', '/tmp/composer-setup.php');"
  php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer

  if cmd_exists composer; then
    success "Composer installed"
  else
    error "Failed to install Composer"
    return 1
  fi
}

ensure_php_default() {
  local restart_fpm="${1:-false}"

  output "Ensuring PHP ${PHP_VERSION} is set as default..."
  update-alternatives --set php /usr/bin/php${PHP_VERSION} 2>/dev/null || true
  update-alternatives --set phar /usr/bin/phar${PHP_VERSION} 2>/dev/null || true
  update-alternatives --set phar.phar /usr/bin/phar.phar${PHP_VERSION} 2>/dev/null || true

  if [ "$restart_fpm" == "true" ]; then
    output "Restarting PHP-FPM..."
    systemctl restart php${PHP_VERSION}-fpm 2>/dev/null || systemctl restart php-fpm 2>/dev/null || true
  fi

  success "PHP ${PHP_VERSION} is set as default"
}

install_nodejs() {
  if cmd_exists node; then
    output "Node.js is already installed ($(node --version))"
    return 0
  fi

  output "Installing Node.js..."

  case "$OS" in
    ubuntu|debian)
      curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
      install_packages "nodejs"
      ;;
    rocky|almalinux|fedora|rhel|centos)
      # Install Node.js from NodeSource on RHEL-based systems
      curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
      install_packages "nodejs"
      ;;
    *)
      error "Unsupported OS for Node.js installation"
      return 1
      ;;
  esac

  if cmd_exists node; then
    success "Node.js installed ($(node --version))"
  else
    error "Failed to install Node.js"
    return 1
  fi
}

install_pnpm() {
  if cmd_exists pnpm; then
    output "pnpm is already installed ($(pnpm --version))"
    return 0
  fi

  output "Installing pnpm..."

  # Install pnpm globally using npm
  npm install -g pnpm

  # Ensure npm global bin is in PATH
  export PATH="$PATH:$(npm bin -g 2>/dev/null || echo '/usr/local/bin')"
  export PATH="$PATH:$(npm config get prefix 2>/dev/null)/bin"

  if cmd_exists pnpm; then
    success "pnpm installed ($(pnpm --version))"
  else
    error "Failed to install pnpm"
    return 1
  fi
}

build_panel_assets() {
  local install_dir="${1:-$INSTALL_DIR}"

  if [ -z "$install_dir" ]; then
    error "Install directory not specified for asset building"
    return 1
  fi

  cd "$install_dir" || return 1

  # Install Node.js if needed
  install_nodejs

  # Install pnpm if needed
  install_pnpm

  # Install JavaScript dependencies
  output "Installing JavaScript dependencies..."
  pnpm install

  # Build frontend assets
  output "Building frontend assets..."
  pnpm build

  success "Frontend assets built successfully"
}

install_phpmyadmin() {
  print_flame "Installing phpMyAdmin"

  # Generate random password for phpMyAdmin
  PHPMYADMIN_PASSWORD="${PHPMYADMIN_PASSWORD:-$(gen_passwd 32)}"
  export PHPMYADMIN_PASSWORD

  export DEBIAN_FRONTEND=noninteractive

  # Pre-configure phpMyAdmin debconf settings
  echo 'phpmyadmin phpmyadmin/dbconfig-install boolean true' | debconf-set-selections
  echo "phpmyadmin phpmyadmin/app-password-confirm password ${PHPMYADMIN_PASSWORD}" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/mysql/admin-pass password ${MYSQL_ROOT_PASSWORD}" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/mysql/app-pass password ${PHPMYADMIN_PASSWORD}" | debconf-set-selections
  echo 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect' | debconf-set-selections

  output "Installing phpMyAdmin and PHP extensions..."
  install_packages "phpmyadmin php${PHP_VERSION}-mbstring php${PHP_VERSION}-zip php${PHP_VERSION}-gd php${PHP_VERSION}-curl"

  output "Creating phpMyAdmin database user..."
  mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "
    CREATE USER IF NOT EXISTS 'phpmyadmin'@'localhost' IDENTIFIED BY '${PHPMYADMIN_PASSWORD}';
    CREATE USER IF NOT EXISTS 'phpmyadmin'@'127.0.0.1' IDENTIFIED BY '${PHPMYADMIN_PASSWORD}';
    CREATE USER IF NOT EXISTS 'phpmyadmin'@'%' IDENTIFIED BY '${PHPMYADMIN_PASSWORD}';
    GRANT ALL PRIVILEGES ON *.* TO 'phpmyadmin'@'localhost' WITH GRANT OPTION;
    GRANT ALL PRIVILEGES ON *.* TO 'phpmyadmin'@'127.0.0.1' WITH GRANT OPTION;
    GRANT ALL PRIVILEGES ON *.* TO 'phpmyadmin'@'%' WITH GRANT OPTION;
    FLUSH PRIVILEGES;
  " 2>/dev/null || warning "Could not create phpMyAdmin user (may already exist)"

  # Save credentials to file
  mkdir -p /root/.config/pyrodactyl
  echo "phpmyadmin:${PHPMYADMIN_PASSWORD}" >> /root/.config/pyrodactyl/db-credentials

  output "Setting up phpMyAdmin configuration..."
  cat > /etc/phpmyadmin/conf.d/99-custom.php << 'PHPEOF'
<?php
# Custom phpMyAdmin configuration for Pyrodactyl
$cfg['Servers'][$i]['AllowNoPassword'] = false;
$cfg['Servers'][$i]['auth_type'] = 'cookie';
$cfg['LoginCookieValidity'] = 3600;
$cfg['LoginCookieStore'] = 0;
PHPEOF

  output "Configuring nginx for phpMyAdmin..."

  # Download config from GitHub
  local phpmyadmin_config="/etc/nginx/sites-available/phpmyadmin.conf"
  if ! curl -fsSL -o "$phpmyadmin_config" "${GITHUB_BASE_URL}/${GITHUB_SOURCE}/configs/phpmyadmin.conf" 2>/dev/null; then
    error "Failed to download phpMyAdmin nginx configuration"
    return 1
  fi

  # Replace PHP_VERSION placeholder
  sed -i "s/<PHP_VERSION>/${PHP_VERSION}/g" "$phpmyadmin_config"

  ln -sf /etc/nginx/sites-available/phpmyadmin.conf /etc/nginx/sites-enabled/phpmyadmin.conf

  output "Restarting services..."
  systemctl reload nginx 2>/dev/null || systemctl restart nginx 2>/dev/null || true

  success "phpMyAdmin installed and accessible at http://$(hostname -I | awk '{print $1}'):8081"
}

setup_database_host() {
  local panel_fqdn="${1:-127.0.0.1}"
  local db_host_name="${2:-Local Database Host}"
  local db_host_user="${3:-dbhost}"
  local db_host_pass="${4:-dbhostpassword}"
  local db_host_port="${5:-3306}"

  print_flame "Setting up Database Host"

  # Create database user if it doesn't exist
  output "Creating database host user..."
  mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "
    CREATE USER IF NOT EXISTS '${db_host_user}'@'127.0.0.1' IDENTIFIED BY '${db_host_pass}';
    CREATE USER IF NOT EXISTS '${db_host_user}'@'%' IDENTIFIED BY '${db_host_pass}';
    GRANT ALL PRIVILEGES ON *.* TO '${db_host_user}'@'127.0.0.1' WITH GRANT OPTION;
    GRANT ALL PRIVILEGES ON *.* TO '${db_host_user}'@'%' WITH GRANT OPTION;
    FLUSH PRIVILEGES;
  " 2>/dev/null || warning "Could not create database host user (may already exist)"

  # Use Laravel's HostCreationService to create the database host
  output "Creating database host in panel..."

  cd "$INSTALL_DIR" || return 1

  local tinker_output
  tinker_output=$(php artisan tinker --execute="
use Pterodactyl\\Services\\Databases\\Hosts\\HostCreationService;
try {
    app(HostCreationService::class)->handle([
        'name' => '${db_host_name}',
        'host' => '${panel_fqdn}',
        'port' => ${db_host_port},
        'username' => '${db_host_user}',
        'password' => '${db_host_pass}',
    ]);
    echo 'Database host created successfully';
} catch (\\Exception \$e) {
    echo 'Error: ' . \$e->getMessage();
}
" 2>&1)

  if echo "$tinker_output" | grep -q "Database host created successfully"; then
    success "Database host '${db_host_name}' configured successfully"
  else
    error "Could not create database host"
    output "Error output: $tinker_output"
    warning "You may need to create the database host manually in the panel"
  fi
}

php_fpm_conf() {
  output "Configuring PHP-FPM..."

  local config_file="/etc/php-fpm.d/www-pyrodactyl.conf"

  # Download config from GitHub
  if ! curl -fsSL -o "$config_file" "$GITHUB_URL/configs/www-pyrodactyl.conf" 2>/dev/null; then
    error "Failed to download PHP-FPM configuration"
    exit 1
  fi

  # Replace placeholders in downloaded config
  sed -i "s|<user>|$WEBUSER|g" "$config_file"
  sed -i "s|<group>|$WEBGROUP|g" "$config_file"

  systemctl enable php-fpm
  systemctl restart php-fpm

  success "PHP-FPM configured"
}

get_php_socket() {
  case "$OS" in
    ubuntu|debian)
      echo "/run/php/php${PHP_VERSION}-fpm.sock"
      ;;
    rocky|almalinux|fedora|rhel|centos)
      echo "/run/php-fpm/www-pyrodactyl.sock"
      ;;
    *)
      echo "/run/php/php${PHP_VERSION}-fpm.sock"
      ;;
  esac
}

# ------------------ Nginx Functions ----------------- #

install_nginx_config() {
  local fqdn="$1"
  local php_socket="$2"
  local ssl="${3:-false}"
  local cert_path="${4:-}"
  local key_path="${5:-}"

  output "Installing Nginx configuration..."

  local config_file="/etc/nginx/sites-available/pyrodactyl.conf"

  if [ "$ssl" == true ] && [ -n "$cert_path" ] && [ -n "$key_path" ]; then
    # Download SSL config from GitHub
    if ! curl -fsSL -o "$config_file" "$GITHUB_URL/configs/nginx_ssl.conf" 2>/dev/null; then
      error "Failed to download nginx SSL config"
      exit 1
    fi
    # Replace placeholders
    sed -i "s|<domain>|$fqdn|g" "$config_file"
    sed -i "s|<cert_path>|$cert_path|g" "$config_file"
    sed -i "s|<key_path>|$key_path|g" "$config_file"
    sed -i "s|<php_socket>|$php_socket|g" "$config_file"
  else
    # Download HTTP config from GitHub
    if ! curl -fsSL -o "$config_file" "$GITHUB_URL/configs/nginx.conf" 2>/dev/null; then
      error "Failed to download nginx config"
      exit 1
    fi
    # Replace placeholders
    sed -i "s|<domain>|$fqdn|g" "$config_file"
    sed -i "s|<php_socket>|$php_socket|g" "$config_file"
  fi

  # Enable site
  mkdir -p /etc/nginx/sites-enabled
  ln -sf "$config_file" /etc/nginx/sites-enabled/pyrodactyl.conf

  # Remove default site
  rm -f /etc/nginx/sites-enabled/default

  # Test and reload
  nginx -t && systemctl reload nginx

  success "Nginx configured"
}

install_letsencrypt() {
  local fqdn="$1"
  local email="$2"

  output "Installing Certbot and obtaining SSL certificate..."

  case "$OS" in
    ubuntu|debian)
      install_packages "certbot python3-certbot-nginx"
      ;;
    rocky|almalinux|fedora|rhel|centos)
      install_packages "certbot python3-certbot-nginx"
      ;;
  esac

  certbot --nginx -d "$fqdn" --non-interactive --agree-tos --email "$email" || {
    warning "Certbot failed to obtain certificate"
    return 1
  }

  success "SSL certificate installed"
}

# ------------------ Redis Functions ----------------- #

enable_redis() {
  case "$OS" in
    ubuntu|debian)
      systemctl enable redis-server
      systemctl start redis-server
      ;;
    rocky|almalinux|fedora|rhel|centos|arch)
      systemctl enable redis
      systemctl start redis
      ;;
  esac
}

# ------------------ SELinux Functions ----------------- #

selinux_allow() {
  if cmd_exists setsebool; then
    output "Configuring SELinux..."
    setsebool -P httpd_can_network_connect 1 2>/dev/null || true
    setsebool -P httpd_execmem 1 2>/dev/null || true
    success "SELinux configured"
  fi
}

# ------------------ Cron Functions ----------------- #

insert_cronjob() {
  output "Installing cron job..."

  (crontab -l 2>/dev/null | grep -v "schedule:run"; echo "* * * * * php /var/www/pyrodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -

  success "Cron job installed"
}

# ------------------ Queue Worker Functions ----------------- #

install_pyroq() {
  output "Installing queue worker service..."

  # Download from GitHub
  if ! curl -fsSL -o /etc/systemd/system/pyroq.service "$GITHUB_URL/configs/pyroq.service" 2>/dev/null; then
    error "Failed to download pyroq service file"
    exit 1
  fi

  # Replace placeholder with actual user
  sed -i "s|<user>|$WEBUSER|g" /etc/systemd/system/pyroq.service

  systemctl daemon-reload
  systemctl enable pyroq
  systemctl start pyroq

  success "Queue worker installed"
}

# ------------------ Auto-Updater Functions ----------------- #

install_auto_updater_panel() {
  output "Installing Panel auto-updater..."

  mkdir -p /etc/pyrodactyl

  # Download auto-update script from GitHub installers folder
  if ! curl -fsSL -o /usr/local/bin/pyrodactyl-auto-update-panel.sh "$GITHUB_URL/installers/auto-update-panel.sh" 2>/dev/null; then
    error "Failed to download auto-update script"
    exit 1
  fi
  chmod +x /usr/local/bin/pyrodactyl-auto-update-panel.sh

  # Create config
  echo "PANEL_REPO=\"${PANEL_REPO:-pyrodactyl-oss/pyrodactyl}\"" > /etc/pyrodactyl/auto-update-panel.conf
  echo "GITHUB_TOKEN=\"${GITHUB_TOKEN:-}\"" >> /etc/pyrodactyl/auto-update-panel.conf
  chmod 600 /etc/pyrodactyl/auto-update-panel.conf

  # Download systemd service from configs
  if ! curl -fsSL -o /etc/systemd/system/pyrodactyl-panel-auto-update.service "$GITHUB_URL/configs/auto-update-panel.service" 2>/dev/null; then
    error "Failed to download systemd service file"
    exit 1
  fi

  # Download systemd timer from configs
  if ! curl -fsSL -o /etc/systemd/system/pyrodactyl-panel-auto-update.timer "$GITHUB_URL/configs/auto-update-panel.timer" 2>/dev/null; then
    error "Failed to download systemd timer file"
    exit 1
  fi

  systemctl daemon-reload
  systemctl enable --now pyrodactyl-panel-auto-update.timer

  success "Panel auto-updater installed"
}

install_auto_updater_elytra() {
  output "Installing Elytra auto-updater..."

  mkdir -p /etc/pyrodactyl

  # Download auto-update script from GitHub
  if ! curl -fsSL -o /usr/local/bin/pyrodactyl-auto-update-elytra.sh "$GITHUB_URL/installers/auto-update-elytra.sh" 2>/dev/null; then
    error "Failed to download auto-update script"
    exit 1
  fi
  chmod +x /usr/local/bin/pyrodactyl-auto-update-elytra.sh

  # Create config
  echo "ELYTRA_REPO=\"${ELYTRA_REPO:-pyrohost/elytra}\"" > /etc/pyrodactyl/auto-update-elytra.conf
  echo "GITHUB_TOKEN=\"${GITHUB_TOKEN:-}\"" >> /etc/pyrodactyl/auto-update-elytra.conf
  chmod 600 /etc/pyrodactyl/auto-update-elytra.conf

  # Download systemd service from configs
  if ! curl -fsSL -o /etc/systemd/system/pyrodactyl-elytra-auto-update.service "$GITHUB_URL/configs/auto-update-elytra.service" 2>/dev/null; then
    error "Failed to download systemd service file"
    exit 1
  fi

  # Download systemd timer from configs
  if ! curl -fsSL -o /etc/systemd/system/pyrodactyl-elytra-auto-update.timer "$GITHUB_URL/configs/auto-update-elytra.timer" 2>/dev/null; then
    error "Failed to download systemd timer file"
    exit 1
  fi

  systemctl daemon-reload
  systemctl enable --now pyrodactyl-elytra-auto-update.timer

  success "Elytra auto-updater installed"
}

remove_auto_updater_panel() {
  output "Removing Panel auto-updater..."

  systemctl stop pyrodactyl-panel-auto-update.timer 2>/dev/null || true
  systemctl disable pyrodactyl-panel-auto-update.timer 2>/dev/null || true

  rm -f /etc/systemd/system/pyrodactyl-panel-auto-update.service
  rm -f /etc/systemd/system/pyrodactyl-panel-auto-update.timer
  rm -f /usr/local/bin/pyrodactyl-auto-update-panel.sh
  rm -f /etc/pyrodactyl/auto-update-panel.conf

  systemctl daemon-reload

  success "Panel auto-updater removed"
}

remove_auto_updater_elytra() {
  output "Removing Elytra auto-updater..."

  systemctl stop pyrodactyl-elytra-auto-update.timer 2>/dev/null || true
  systemctl disable pyrodactyl-elytra-auto-update.timer 2>/dev/null || true

  rm -f /etc/systemd/system/pyrodactyl-elytra-auto-update.service
  rm -f /etc/systemd/system/pyrodactyl-elytra-auto-update.timer
  rm -f /usr/local/bin/pyrodactyl-auto-update-elytra.sh
  rm -f /etc/pyrodactyl/auto-update-elytra.conf

  systemctl daemon-reload

  success "Elytra auto-updater removed"
}

# ------------------ Script Execution Functions ----------------- #

run_ui() {
  local script_name="$1"
  bash <(curl -sSL "$GITHUB_URL/ui/$script_name.sh")
}

run_installer() {
  local script_name="$1"
  bash <(curl -sSL "$GITHUB_URL/installers/$script_name.sh")
}

update_lib_source() {
  GITHUB_URL="$GITHUB_BASE_URL/$GITHUB_SOURCE"
  rm -f /tmp/pyrodactyl-lib.sh
  curl -sSL -o /tmp/pyrodactyl-lib.sh "$GITHUB_URL/lib/lib.sh"
  # shellcheck source=/dev/null
  source /tmp/pyrodactyl-lib.sh
}

# ------------------ Docker Functions ----------------- #

install_docker() {
  print_flame "Installing Docker"

  if cmd_exists docker; then
    output "Docker is already installed, skipping..."
    return 0
  fi

  output "Installing Docker CE..."

  case "$OS" in
    ubuntu|debian)
      # Remove old versions
      apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

      # Install prerequisites
      install_packages "apt-transport-https ca-certificates curl gnupg lsb-release"

      # Add Docker GPG key
      mkdir -p /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

      # Add repository
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

      update_repos true
      install_packages "docker-ce docker-ce-cli containerd.io docker-compose-plugin"
      ;;

    rocky|almalinux|fedora|rhel|centos)
      install_packages "yum-utils"
      yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      install_packages "docker-ce docker-ce-cli containerd.io docker-compose-plugin"
      ;;
  esac

  # Start Docker
  systemctl start docker
  systemctl enable docker

  # Check virtualization
  check_virt

  success "Docker installed and started"
}

# ------------------ Rustic Functions ----------------- #

install_rustic() {
  print_flame "Installing Rustic"

  if cmd_exists rustic; then
    output "Rustic is already installed, skipping..."
    return 0
  fi

  output "Installing rustic backup tool..."

  local arch
  arch=$(uname -m)
  [[ $arch == x86_64 ]] && arch=x86_64 || arch=aarch64

  # Fetch latest release version from GitHub
  local rustic_version
  rustic_version=$(curl -sSL "https://api.github.com/repos/rustic-rs/rustic/releases/latest" | jq -r '.tag_name' 2>/dev/null || echo "")

  if [ -z "$rustic_version" ] || [ "$rustic_version" == "null" ]; then
    warning "Could not fetch latest rustic version, falling back to v0.11.0"
    rustic_version="v0.11.0"
  fi

  output "Downloading rustic ${rustic_version}..."
  local rustic_url="https://github.com/rustic-rs/rustic/releases/download/${rustic_version}/rustic-${rustic_version}-${arch}-unknown-linux-musl.tar.gz"

  curl -fsSL -o /tmp/rustic.tar.gz "$rustic_url" || {
    error "Failed to download rustic"
    return 1
  }

  tar -xzf /tmp/rustic.tar.gz -C /usr/local/bin rustic
  chmod +x /usr/local/bin/rustic
  rm -f /tmp/rustic.tar.gz

  success "Rustic installed successfully"
}

# ------------------ System Spec Functions ----------------- #

get_system_memory() {
  # Get total system memory in MB
  local mem_mb
  mem_mb=$(free -m | awk '/^Mem:/{print $2}')
  echo "$mem_mb"
}

get_system_disk() {
  # Get available disk space in MB for /var/lib/pyrodactyl or root
  local disk_mb
  if [ -d "/var/lib/pyrodactyl" ]; then
    disk_mb=$(df -m /var/lib/pyrodactyl | awk 'NR==2 {print $4}')
  else
    disk_mb=$(df -m / | awk 'NR==2 {print $4}')
  fi
  echo "$disk_mb"
}

# ------------------ Minecraft Server Creation ----------------- #

create_minecraft_server() {
  local panel_url="$1"
  local api_key="$2"
  local node_id="${3:-1}"
  local location_id="${4:-1}"
  local allocation_id="$5"

  print_flame "Creating Minecraft Server"

  output "Creating Minecraft server via API..."

  # Build JSON with jq to avoid formatting issues
  local server_json
  if [ -n "$allocation_id" ] && [ "$allocation_id" != "null" ]; then
    # Use specific allocation - don't include deploy section
    server_json=$(jq -n \
      --arg name "Minecraft Vanilla Server" \
      --arg desc "Automatically created Minecraft Vanilla Server" \
      --argjson user 1 \
      --argjson egg 8 \
      --arg docker_image "ghcr.io/pterodactyl/yolks:java_17" \
      --arg startup 'java -Xms128M -Xmx4096M -jar {{SERVER_JARFILE}}' \
      --argjson allocation_id "$allocation_id" \
      '{
        name: $name,
        description: $desc,
        user: $user,
        egg: $egg,
        docker_image: $docker_image,
        startup: $startup,
        environment: {
          SERVER_JARFILE: "server.jar",
          VANILLA_VERSION: "latest"
        },
        limits: {
          memory: 4096,
          swap: 0,
          disk: 32768,
          io: 500,
          cpu: 400
        },
        feature_limits: {
          databases: 0,
          allocations: 1,
          backups: 0
        },
        allocation: {
          default: $allocation_id
        },
        start_on_completion: false,
        skip_scripts: false,
        oom_disabled: false
      }')
  else
    # Auto-deploy to location
    server_json=$(jq -n \
      --arg name "Minecraft Vanilla Server" \
      --arg desc "Automatically created Minecraft Vanilla Server" \
      --argjson user 1 \
      --argjson egg 8 \
      --arg docker_image "ghcr.io/pterodactyl/yolks:java_17" \
      --arg startup 'java -Xms128M -Xmx4096M -jar {{SERVER_JARFILE}}' \
      --argjson location_id "$location_id" \
      '{
        name: $name,
        description: $desc,
        user: $user,
        egg: $egg,
        docker_image: $docker_image,
        startup: $startup,
        environment: {
          SERVER_JARFILE: "server.jar",
          VANILLA_VERSION: "latest"
        },
        limits: {
          memory: 4096,
          swap: 0,
          disk: 32768,
          io: 500,
          cpu: 400
        },
        feature_limits: {
          databases: 0,
          allocations: 1,
          backups: 0
        },
        deploy: {
          locations: [$location_id],
          dedicated_ip: false,
          port_range: []
        },
        start_on_completion: false,
        skip_scripts: false,
        oom_disabled: false
      }')
  fi

  # Wait for API to be ready
  output "Waiting for API to be ready..."
  local api_ready=false
  local attempts=0
  while [ "$api_ready" == false ] && [ $attempts -lt 30 ]; do
    local api_test
    api_test=$(curl -s -H "Authorization: Bearer $api_key" \
      -H "Accept: Application/vnd.pterodactyl.v1+json" \
      "${panel_url}/api/application/users" 2>/dev/null || echo "failed")

    if echo "$api_test" | grep -q '"object":"list"'; then
      api_ready=true
      break
    fi

    attempts=$((attempts + 1))
    sleep 2
  done

  if [ "$api_ready" == false ]; then
    warning "API did not become ready in time, skipping server creation"
    return 1
  fi

  # Create the server
  output "Sending server creation request..."
  
  local server_response
  server_response=$(curl -s -X POST \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json" \
    -H "Accept: Application/vnd.pterodactyl.v1+json" \
    -d "$server_json" \
    "${panel_url}/api/application/servers" 2>/dev/null)

  if echo "$server_response" | grep -q '"object":"server"'; then
    local server_id
    server_id=$(echo "$server_response" | jq -r '.attributes.id' 2>/dev/null)
    local server_uuid
    server_uuid=$(echo "$server_response" | jq -r '.attributes.uuid' 2>/dev/null)
    success "Minecraft server created successfully (ID: $server_id)"
    echo "$server_id|$server_uuid"
    return 0
  else
    warning "Failed to create Minecraft server"
    local error_detail
    error_detail=$(echo "$server_response" | jq -r '.errors[0].detail // .message // "Unknown error"' 2>/dev/null)
    error "API Error: $error_detail"
    error "Raw response: $server_response"
    return 1
  fi
}

# ------------------ API Key Generation ----------------- #

generate_api_key() {
  local install_dir="${1:-$INSTALL_DIR}"

  output "Generating Application API Key..."

  cd "$install_dir" || return 1

  # Use a heredoc for cleaner PHP code without escaping hell
  local api_key_result
  api_key_result=$(php artisan tinker --execute='
    use Pterodactyl\Models\ApiKey;
    use Pterodactyl\Models\User;
    use Pterodactyl\Services\Api\KeyCreationService;
    
    $user = User::first();
    if (!$user) {
        fwrite(STDERR, "No users found in database\n");
        exit(1);
    }
    
    // Delete existing key with same memo
    ApiKey::query()
        ->where("user_id", $user->id)
        ->where("memo", "Installer API Key")
        ->delete();
    
    $service = app(KeyCreationService::class);
    $apiKey = $service->setKeyType(ApiKey::TYPE_APPLICATION)->handle([
        "user_id" => $user->id,
        "memo" => "Installer API Key",
        "allowed_ips" => [],
    ], [
        "r_servers" => 3,
        "r_nodes" => 3,
        "r_allocations" => 3,
        "r_users" => 3,
        "r_locations" => 3,
        "r_nests" => 3,
        "r_eggs" => 3,
        "r_database_hosts" => 3,
        "r_server_databases" => 3,
    ]);
    
    // Output only the key for easy capture
    echo $apiKey->identifier . decrypt($apiKey->token);
  ' 2>&1)

  local exit_code=$?

  if [ $exit_code -ne 0 ]; then
    warning "Failed to generate API key: $api_key_result"
    return 1
  fi

  local api_key
  api_key=$(echo "$api_key_result" | grep -E '^[a-zA-Z0-9_]{30,}$' | tail -1)

  if [ -n "$api_key" ]; then
    success "API Key generated successfully"
    echo "$api_key"
    return 0
  else
    warning "Failed to generate API key"
    return 1
  fi
}

# ------------------ API-Based Node Management ----------------- #

# Get server country code via IP geolocation
get_server_country_code() {
  local country_code=""
  
  # Try ipapi.co first (free, no auth required for basic requests)
  country_code=$(curl -s --max-time 10 "https://ipapi.co/country_code/" 2>/dev/null || echo "")
  
  # If that fails, try ipinfo.io
  if [ -z "$country_code" ] || [ "$country_code" == "null" ]; then
    country_code=$(curl -s --max-time 10 "https://ipinfo.io/country" 2>/dev/null || echo "")
  fi
  
  # If that fails, try ifconfig.co
  if [ -z "$country_code" ] || [ "$country_code" == "null" ]; then
    country_code=$(curl -s --max-time 10 "https://ifconfig.co/country-iso" 2>/dev/null || echo "")
  fi
  
  # Return uppercase country code or default to "XX"
  if [ -n "$country_code" ] && [ "$country_code" != "null" ]; then
    echo "$country_code" | tr '[:lower:]' '[:upper:]'
  else
    echo "XX"
  fi
}

# Get or create location via API
get_or_create_location() {
  local api_key="$1"
  local panel_url="$2"
  local country_code="$3"
  
  output "Checking for existing location with code: ${COLOR_ORANGE}${country_code}${COLOR_NC}"
  
  # Get all locations
  local locations_response
  locations_response=$(curl -s -H "Authorization: Bearer $api_key" \
    -H "Accept: Application/vnd.pterodactyl.v1+json" \
    "${panel_url}/api/application/locations" 2>/dev/null || echo "")
  
  if [ -n "$locations_response" ] && echo "$locations_response" | grep -q '"object":"list"'; then
    # Check if location with this short code exists
    local existing_location
    existing_location=$(echo "$locations_response" | jq -r ".data[] | select(.attributes.short == \"${country_code}\") | .attributes.id" 2>/dev/null | head -1)
    
    if [ -n "$existing_location" ] && [ "$existing_location" != "null" ]; then
      info "Found existing location: ${country_code} (ID: ${existing_location})"
      echo "$existing_location"
      return 0
    fi
  fi
  
  # Location doesn't exist, create it
  output "Creating new location: ${COLOR_ORANGE}${country_code}${COLOR_NC}"
  
  local create_response
  create_response=$(curl -s -X POST \
    -H "Authorization: Bearer $api_key" \
    -H "Accept: Application/vnd.pterodactyl.v1+json" \
    -H "Content-Type: application/json" \
    -d "{\"short\":\"${country_code}\",\"long\":\"${country_code} Region\"}" \
    "${panel_url}/api/application/locations" 2>/dev/null || echo "")
  
  if [ -n "$create_response" ] && echo "$create_response" | grep -q '"object":"location"'; then
    local new_location_id
    new_location_id=$(echo "$create_response" | jq -r '.attributes.id' 2>/dev/null)
    success "Created location: ${country_code} (ID: ${new_location_id})"
    echo "$new_location_id"
    return 0
  else
    error "Failed to create location"
    return 1
  fi
}

# Create node via API
create_node_via_api() {
  local api_key="$1"
  local panel_url="$2"
  local location_id="$3"
  local node_name="$4"
  local memory_mb="$5"
  local disk_mb="$6"
  local behind_proxy="${7:-false}"
  
  output "Creating node: ${COLOR_ORANGE}${node_name}${COLOR_NC}"
  
  # Convert bash boolean to JSON boolean
  local json_behind_proxy="false"
  if [ "$behind_proxy" == "true" ] || [ "$behind_proxy" == "1" ]; then
    json_behind_proxy="true"
  fi
  
  # Detect system specs if not provided
  if [ -z "$memory_mb" ] || [ "$memory_mb" == "0" ]; then
    memory_mb=$(get_system_memory)
    memory_mb=${memory_mb:-8192}
  fi
  
  if [ -z "$disk_mb" ] || [ "$disk_mb" == "0" ]; then
    disk_mb=$(df -m / | awk 'NR==2 {print $2}')
    disk_mb=${disk_mb:-32768}
  fi
  
  # Get server FQDN and sanitize it
  local fqdn
  fqdn=$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo "localhost")
  # Sanitize FQDN - remove quotes and backslashes that would break JSON
  fqdn=$(echo "$fqdn" | sed 's/["\\]//g')
  
  # Build JSON using temp file to avoid shell escaping issues
  local json_file
  json_file=$(mktemp)
  local current_date
  current_date=$(date +%Y-%m-%d)
  
  if cmd_exists jq; then
    # Use jq for proper JSON construction
    jq -n \
      --arg name "$node_name" \
      --arg desc "Elytra node auto-created on $current_date" \
      --argjson location_id "$location_id" \
      --arg fqdn "$fqdn" \
      --argjson behind_proxy "$json_behind_proxy" \
      --argjson memory "$memory_mb" \
      --argjson disk "$disk_mb" \
      '{name: $name, description: $desc, location_id: $location_id, fqdn: $fqdn, scheme: "http", behind_proxy: $behind_proxy, public: true, memory: $memory, memory_overallocate: 0, disk: $disk, disk_overallocate: 0, upload_size: 100, daemon_listen: 8080, daemon_sftp: 2022, maintenance_mode: false}' > "$json_file"
  else
    # Fallback: write JSON directly to file
    printf '{"name":"%s","description":"Elytra node auto-created on %s","location_id":%s,"fqdn":"%s","scheme":"http","behind_proxy":%s,"public":true,"memory":%s,"memory_overallocate":0,"disk":%s,"disk_overallocate":0,"upload_size":100,"daemon_listen":8080,"daemon_sftp":2022,"maintenance_mode":false}' \
      "$node_name" "$current_date" "$location_id" "$fqdn" "$json_behind_proxy" "$memory_mb" "$disk_mb" > "$json_file"
  fi
  
  local create_response
  create_response=$(curl -s -X POST \
    -H "Authorization: Bearer $api_key" \
    -H "Accept: Application/vnd.pterodactyl.v1+json" \
    -H "Content-Type: application/json" \
    -d @"$json_file" \
    "${panel_url}/api/application/nodes" 2>/dev/null)
  
  # Clean up temp file
  rm -f "$json_file"
  
  if [ -n "$create_response" ] && echo "$create_response" | grep -q '"object":"node"'; then
    local node_id
    node_id=$(echo "$create_response" | jq -r '.attributes.id' 2>/dev/null)
    success "Created node: ${node_name} (ID: ${node_id})"
    echo "$node_id"
    return 0
  else
    error "Failed to create node"
    local error_detail
    error_detail=$(echo "$create_response" | jq -r '.errors[0].detail // .message // "Unknown error"' 2>/dev/null || echo "Unknown error")
    error "API Error: ${error_detail}"
    # Debug output
    if [ -n "$create_response" ]; then
      warning "Raw response: $create_response"
    fi
    return 1
  fi
}

# Create allocations for node
create_node_allocations() {
  local api_key="$1"
  local panel_url="$2"
  local node_id="$3"
  local game_port_start="${4:-28015}"
  local game_port_end="${5:-28100}"
  
  output "Creating allocations for node..."
  
  # Get primary IP
  local primary_ip
  primary_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "0.0.0.0")
  
  # Create port ranges (Minecraft, Source Engine, general range)
  local ports_json="[\"25565-25665\",\"27015-27150\",\"${game_port_start}-${game_port_end}\"]"
  
  local create_response
  create_response=$(curl -s -X POST \
    -H "Authorization: Bearer $api_key" \
    -H "Accept: Application/vnd.pterodactyl.v1+json" \
    -H "Content-Type: application/json" \
    -d "{
      \"ip\":\"${primary_ip}\",
      \"ports\":${ports_json}
    }" \
    "${panel_url}/api/application/nodes/${node_id}/allocations" 2>/dev/null || echo "")
  
  if [ -n "$create_response" ] && echo "$create_response" | grep -q '"object":"list"'; then
    local allocation_count
    allocation_count=$(echo "$create_response" | jq -r '.data | length' 2>/dev/null)
    success "Created ${allocation_count} allocations"
    return 0
  else
    warning "Failed to create allocations (node may still work)"
    return 1
  fi
}

# Get node configuration token via API
get_node_configuration() {
  local api_key="$1"
  local panel_url="$2"
  local node_id="$3"
  
  output "Retrieving node configuration..."
  
  local config_response
  config_response=$(curl -s \
    -H "Authorization: Bearer $api_key" \
    -H "Accept: Application/vnd.pterodactyl.v1+json" \
    "${panel_url}/api/application/nodes/${node_id}/configuration" 2>/dev/null || echo "")
  
  if [ -z "$config_response" ] || ! echo "$config_response" | grep -q '"token"'; then
    error "Failed to get node configuration"
    return 1
  fi
  
  # Extract token and UUID
  local node_token
  local node_uuid
  node_token=$(echo "$config_response" | jq -r '.token' 2>/dev/null || echo "")
  node_uuid=$(echo "$config_response" | jq -r '.uuid' 2>/dev/null || echo "")
  
  if [ -z "$node_token" ] || [ "$node_token" == "null" ]; then
    error "Failed to extract node token from configuration"
    return 1
  fi
  
  # Output token and UUID separated by pipe
  echo "${node_token}|${node_uuid}"
  return 0
}

# ------------------ Initial OS Detection ----------------- #

# Detect OS on load
detect_os
