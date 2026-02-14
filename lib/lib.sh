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
export PHP_VERSION="8.3"

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

  while [[ "$result" != "y" && "$result" != "n" ]]; do
    echo -n "* $prompt [y/N]: "
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

create_db_user() {
  local username="$1"
  local password="$2"
  local host="${3:-localhost}"

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
  local host="${3:-localhost}"

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
  local host="${3:-localhost}"

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

# ------------------ Initial OS Detection ----------------- #

# Detect OS on load
detect_os
