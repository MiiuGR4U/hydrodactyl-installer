#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Pyrodactyl Installer - Pinnacle Edition                                            #
#                                                                                    #
# One-command installer for Pyrodactyl Panel and Elytra Daemon                       #
#                                                                                    #
# Copyright (C) 2025, Muspelheim Hosting                                             #
#                                                                                    #
# https://github.com/Muspelheim-Hosting/pyrodactyl-installer                         #
#                                                                                    #
######################################################################################

export GITHUB_SOURCE="${GITHUB_SOURCE:-main}"
export SCRIPT_RELEASE="${SCRIPT_RELEASE:-v1.0.0}"
export GITHUB_BASE_URL="${GITHUB_BASE_URL:-https://raw.githubusercontent.com/Muspelheim-Hosting/pyrodactyl-installer}"

LOG_PATH="/var/log/pyrodactyl-installer.log"

# ------------------ Utility Functions ----------------- #

# Color definitions - Orange gradient for flame effect
export COLOR_DARK_ORANGE='\033[38;5;208m'
export COLOR_ORANGE='\033[38;5;214m'
export COLOR_LIGHT_ORANGE='\033[38;5;220m'
export COLOR_YELLOW='\033[1;33m'
export COLOR_GREEN='\033[0;32m'
export COLOR_RED='\033[0;31m'
export COLOR_BLUE='\033[0;34m'
export COLOR_CYAN='\033[0;36m'
export COLOR_NC='\033[0m'

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

  # Flame gradient header
  echo -e "${COLOR_DARK_ORANGE}"
  echo '    ╔══════════════════════════════════════════════════════════════════════════════════════╗'
  echo -e "${COLOR_ORANGE}"
  echo '    ║                                                                                      ║'
  echo '    ║  ███╗   ███╗██╗   ██╗███████╗██████╗ ███████╗██╗     ██╗  ██╗███████╗██╗███╗   ███╗  ║'
  echo '    ║  ████╗ ████║██║   ██║██╔════╝██╔══██╗██╔════╝██║     ██║  ██║██╔════╝██║████╗ ████║  ║'
  echo '    ║  ██╔████╔██║██║   ██║███████╗██████╔╝█████╗  ██║     ███████║█████╗  ██║██╔████╔██║  ║'
  echo -e "${COLOR_LIGHT_ORANGE}"
  echo '    ║  ██║╚██╔╝██║██║   ██║╚════██║██╔═══╝ ██╔══╝  ██║     ██╔══██║██╔══╝  ██║██║╚██╔╝██║  ║'
  echo '    ║  ██║ ╚═╝ ██║╚██████╔╝███████║██║     ███████╗███████╗██║  ██║███████╗██║██║ ╚═╝ ██║  ║'
  echo '    ║  ╚═╝     ╚═╝ ╚═════╝ ╚══════╝╚═╝     ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝╚═╝     ╚═╝  ║'
  echo '    ║                                                                                      ║'
  echo -e "${COLOR_ORANGE}"
  echo '    ║                       🔥 Pyrodactyl Installation Manager 🔥                          ║'
  echo -e "${COLOR_DARK_ORANGE}"
  echo '    ╚══════════════════════════════════════════════════════════════════════════════════════╝'
  echo -e "${COLOR_NC}"
  echo -e "    ${COLOR_ORANGE}Version:${COLOR_NC} ${SCRIPT_RELEASE}  ${COLOR_ORANGE}|${COLOR_NC}  ${COLOR_ORANGE}By:${COLOR_NC} Muspelheim Hosting"
  echo ""
}

print_flame() {
  local message="$1"
  local colors=('\033[38;5;196m' '\033[38;5;202m' '\033[38;5;208m' '\033[38;5;214m' '\033[38;5;220m' '\033[38;5;226m')
  local len=${#colors[@]}

  echo ""
  for ((i=0; i<len; i++)); do
    local padding=""
    for ((j=0; j<i; j++)); do
      padding+=" "
    done
    echo -e "${colors[$i]}${padding}🔥${COLOR_NC}"
  done

  echo -e "${COLOR_ORANGE}  $message${COLOR_NC}"
  echo ""
}

# Cleanup function for temporary files
cleanup() {
  rm -f /tmp/pyrodactyl-lib.sh 2>/dev/null || true
  rm -f /tmp/lib.sh 2>/dev/null || true
}

# Set trap to cleanup on exit
trap cleanup EXIT INT TERM

# Check for root
check_root() {
  if [[ $EUID -ne 0 ]]; then
    error "This script must be executed with root privileges."
    exit 1
  fi
}

# Check for curl
check_curl() {
  if ! [ -x "$(command -v curl)" ]; then
    error "curl is required in order for this script to work."
    error "Install using: apt install curl (Debian/Ubuntu) or dnf install curl (RHEL)"
    exit 1
  fi
}

# Download and source library
load_library() {
  # Always remove old lib.sh before downloading
  [ -f /tmp/pyrodactyl-lib.sh ] && rm -rf /tmp/pyrodactyl-lib.sh

  output "Loading installer library..."

  if ! curl -sSL -o /tmp/pyrodactyl-lib.sh "$GITHUB_BASE_URL/$GITHUB_SOURCE/lib/lib.sh"; then
    error "Failed to download installer library."
    error "Please check your internet connection and try again."
    exit 1
  fi

  # shellcheck source=/dev/null
  if ! source /tmp/pyrodactyl-lib.sh; then
    error "Failed to load installer library."
    exit 1
  fi
}

# Log execution
log_execution() {
  echo -e "\n\n* pyrodactyl-installer $(date) \n\n" >> "$LOG_PATH" 2>/dev/null || true
}

# Execute UI script
execute_ui() {
  local script_name="$1"
  local next_script="${2:-}"

  run_ui "$script_name" 2>&1 | tee -a "$LOG_PATH"

  if [[ -n "$next_script" ]]; then
    echo ""
    echo -n "* Installation of $script_name completed. Do you want to proceed to $next_script installation? (y/N): "
    read -r CONFIRM
    if [[ "$CONFIRM" =~ [Yy] ]]; then
      execute_ui "$next_script"
    else
      warning "Installation of $next_script aborted."
      exit 1
    fi
  fi
}

# Show welcome screen
show_welcome() {
  print_header

  # Detect OS if possible
  local os_info="Unknown"
  if [ -f /etc/os-release ]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    os_info="$NAME $VERSION_ID"
  fi

  echo -e "  ${COLOR_ORANGE}Operating System:${COLOR_NC} $os_info"
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

  # Check auto-updaters
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

# Show main menu
show_menu() {
  local choice=""

  while true; do
    echo ""
    output "${COLOR_ORANGE}What would you like to do?${COLOR_NC}"
    echo ""
    output "[${COLOR_ORANGE}0${COLOR_NC}] Install Pyrodactyl Panel"
    output "[${COLOR_ORANGE}1${COLOR_NC}] Install Elytra Daemon"
    output "[${COLOR_ORANGE}2${COLOR_NC}] Install both Panel and Elytra (same machine)"
    echo ""
    output "[${COLOR_ORANGE}3${COLOR_NC}] Update Pyrodactyl Panel"
    output "[${COLOR_ORANGE}4${COLOR_NC}] Update Elytra Daemon"
    output "[${COLOR_ORANGE}5${COLOR_NC}] Update both Panel and Elytra"
    echo ""
    output "[${COLOR_ORANGE}6${COLOR_NC}] Install Auto-Updaters"
    output "[${COLOR_ORANGE}7${COLOR_NC}] Remove Auto-Updaters"
    echo ""
    output "[${COLOR_ORANGE}8${COLOR_NC}] Uninstall Pyrodactyl / Elytra"
    echo ""
    output "[${COLOR_ORANGE}9${COLOR_NC}] Exit"
    echo ""

    echo -n "* Select an option [0-9]: "
    read -r choice

    case "$choice" in
      0)
        execute_ui "panel"
        break
        ;;
      1)
        execute_ui "elytra"
        break
        ;;
      2)
        execute_ui "panel" "elytra"
        break
        ;;
      3)
        execute_ui "update-panel"
        break
        ;;
      4)
        execute_ui "update-elytra"
        break
        ;;
      5)
        execute_ui "update-both"
        break
        ;;
      6)
        execute_ui "auto-updater-menu"
        break
        ;;
      7)
        execute_ui "remove-auto-updaters"
        break
        ;;
      8)
        execute_ui "uninstall"
        break
        ;;
      9)
        output "Exiting..."
        exit 0
        ;;
      *)
        error "Invalid option. Please select 0-9."
        ;;
    esac
  done
}

# Main function
main() {
  check_root
  check_curl
  load_library
  log_execution
  show_welcome
  show_menu

  print_header
  print_flame "Thank you for using Pyrodactyl Installer!"
  output "Installation log saved to: ${COLOR_ORANGE}$LOG_PATH${COLOR_NC}"
  echo ""
}

# Run main
main "$@"
