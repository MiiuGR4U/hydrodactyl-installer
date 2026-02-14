#!/bin/bash

# Clean up any cached files from previous runs
rm -f /tmp/pyrodactyl-lib.sh /tmp/pyrodactyl-*.sh 2>/dev/null || true

set -e

######################################################################################
#                                                                                    #
# Pyrodactyl Installer                                                               #
#                                                                                    #
# One-command installer for Pyrodactyl Panel and Elytra Daemon                       #
#                                                                                    #
# Copyright (C) 2025, Muspelheim Hosting                                             #
#                                                                                    #
# https://github.com/Muspelheim-Hosting/pyrodactyl-installer                         #
#                                                                                    #
######################################################################################

export GITHUB_SOURCE="${GITHUB_SOURCE:-main}"
export SCRIPT_RELEASE="${SCRIPT_RELEASE:-v1.1.0}"
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

# Smooth flame gradient colors (top to bottom) - red to gold
export GRADIENT_1='\033[38;5;196m'   # Deep red
export GRADIENT_2='\033[38;5;202m'   # Red-orange
export GRADIENT_3='\033[38;5;208m'   # Dark orange
export GRADIENT_4='\033[38;5;214m'   # Orange
export GRADIENT_5='\033[38;5;220m'   # Light orange
export GRADIENT_6='\033[38;5;221m'   # Gold-orange
export GRADIENT_7='\033[38;5;222m'   # Gold
export GRADIENT_8='\033[38;5;226m'   # Yellow-gold
export GRADIENT_9='\033[38;5;227m'   # Bright gold
export GRADIENT_10='\033[38;5;228m'  # Light gold
export GRADIENT_11='\033[38;5;229m'  # Pale gold

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

# Error handler - called when script exits with error
error_handler() {
  local exit_code=$?
  local line_no=$1

  if [ $exit_code -ne 0 ]; then
    echo ""
    echo -e "* ${COLOR_RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_NC}"
    echo -e "* ${COLOR_RED}INSTALLATION FAILED${COLOR_NC}"
    echo -e "* ${COLOR_RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_NC}"
    echo ""
    echo -e "* ${COLOR_YELLOW}Exit code:${COLOR_NC} $exit_code"
    [ -n "$line_no" ] && echo -e "* ${COLOR_YELLOW}Failed at line:${COLOR_NC} $line_no"
    echo ""
    echo -e "* ${COLOR_CYAN}Troubleshooting tips:${COLOR_NC}"
    echo -e "  1. Check the log file: ${COLOR_ORANGE}$LOG_PATH${COLOR_NC}"
    echo -e "  2. Ensure you have a stable internet connection"
    echo -e "  3. Verify your GitHub token has 'repo' scope"
    echo -e "  4. Check that your OS is supported"
    echo ""
    echo -e "* ${COLOR_CYAN}For help, visit:${COLOR_NC} https://github.com/Muspelheim-Hosting/pyrodactyl-installer/issues"
    echo ""
    echo -e "* ${COLOR_RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_NC}"
    echo ""
  fi
}

# Set up error trap
trap 'error_handler $LINENO' ERR

# Cleanup function for temporary files
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
  local exit_code=${PIPESTATUS[0]}

  # Exit if the installation failed
  if [ $exit_code -ne 0 ]; then
    exit $exit_code
  fi

  if [[ -n "$next_script" ]]; then
    echo ""
    local CONFIRM=""
    while [[ "$CONFIRM" != "y" && "$CONFIRM" != "n" ]]; do
      echo -n "* Installation of $script_name completed. Do you want to proceed to $next_script installation? [y/N]: "
      read -r CONFIRM
      CONFIRM=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
      [ -z "$CONFIRM" ] && CONFIRM="n"
      if [[ "$CONFIRM" != "y" && "$CONFIRM" != "n" ]]; then
        error "Invalid input. Please enter 'y' or 'n'."
      fi
    done
    if [[ "$CONFIRM" == "y" ]]; then
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
    output "[${COLOR_ORANGE}6${COLOR_NC}] Auto Updater Management"
    echo ""
    output "[${COLOR_ORANGE}7${COLOR_NC}] Uninstall Pyrodactyl / Elytra"
    echo ""
    output "[${COLOR_ORANGE}8${COLOR_NC}] Exit"
    echo ""

    echo -n "* Select an option [0-8]: "
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
        execute_ui "both"
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
        execute_ui "uninstall"
        break
        ;;
      8)
        output "Exiting..."
        exit 0
        ;;
      *)
        error "Invalid option. Please select 0-8."
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

  # Run menu/installation
  if show_menu; then
    echo ""
    print_flame "Thank you for using Pyrodactyl Installer!"
  fi

  # Always show log location at the end
  echo ""
  output "Installation log saved to: ${COLOR_ORANGE}$LOG_PATH${COLOR_NC}"
  echo ""
}

# Run main
main "$@"
