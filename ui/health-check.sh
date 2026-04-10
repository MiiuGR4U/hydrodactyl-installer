#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Pyrodactyl Health Check UI                                                         #
#                                                                                    #
# Health check and diagnostics for Pyrodactyl Panel and Elytra                       #
#                                                                                    #
# Copyright (C) 2025, Muspelheim Hosting                                             #
#                                                                                    #
# https://github.com/Muspelheim-Hosting/pyrodactyl-installer                         #
#                                                                                    #
######################################################################################

# Check if lib is loaded, load if not or fail otherwise.
fn_exists() { declare -F "$1" >/dev/null; }
if ! fn_exists lib_loaded; then
  # Try temp file first (when run through install.sh)
  if [ -f /tmp/pyrodactyl-lib.sh ]; then
    # shellcheck source=/dev/null
    source /tmp/pyrodactyl-lib.sh
  # Fall back to downloading
  else
    # shellcheck source=/dev/null
    source <(curl -sSL "${GITHUB_BASE_URL:-"https://raw.githubusercontent.com/Muspelheim-Hosting/pyrodactyl-installer"}/${GITHUB_SOURCE:-"main"}/lib/lib.sh")
  fi
  ! fn_exists lib_loaded && echo "* ERROR: Could not load lib script" && exit 1
fi

# ------------------ Detection Functions ----------------- #

detect_panel_location() {
  # Check for Pyrodactyl first (install script location)
  if [ -d "/var/www/pyrodactyl" ] && [ -f "/var/www/pyrodactyl/artisan" ]; then
    echo "/var/www/pyrodactyl"
    return 0
  fi

  # Check for Pterodactyl location (might be Pyrodactyl migrated)
  if [ -d "/var/www/pterodactyl" ] && [ -f "/var/www/pterodactyl/artisan" ]; then
    # Verify it's actually Pyrodactyl
    if grep -q "Pyrodactyl" "/var/www/pterodactyl/config/app.php" 2>/dev/null || \
       grep -q "pyrodactyl" "/var/www/pterodactyl/composer.json" 2>/dev/null; then
      echo "/var/www/pterodactyl"
      return 0
    fi
  fi

  # Check if INSTALL_DIR variable is set and valid
  if [ -n "$INSTALL_DIR" ] && [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/artisan" ]; then
    echo "$INSTALL_DIR"
    return 0
  fi

  # Not found
  return 1
}

detect_elytra_binary() {
  if [ -f "/usr/local/bin/elytra" ]; then
    echo "/usr/local/bin/elytra"
    return 0
  fi

  if [ -f "/usr/bin/elytra" ]; then
    echo "/usr/bin/elytra"
    return 0
  fi

  return 1
}

# ------------------ Menu Functions ----------------- #

show_health_menu() {
  local choice=""

  while true; do
    print_header
    print_flame "Health Check & Diagnostics"

    echo ""
    output "${COLOR_ORANGE}What would you like to check?${COLOR_NC}"
    echo ""
    output "[${COLOR_ORANGE}0${COLOR_NC}] Check Panel Health"
    output "[${COLOR_ORANGE}1${COLOR_NC}] Check Elytra Health"
    output "[${COLOR_ORANGE}2${COLOR_NC}] Check Both"
    echo ""
    output "[${COLOR_ORANGE}3${COLOR_NC}] Back to Main Menu"
    echo ""

    echo -n "* Select an option [0-3]: "
    read -r choice

    case "$choice" in
      0)
        local panel_dir
        panel_dir=$(detect_panel_location) || {
          error "Panel installation not found"
          output "Searched: /var/www/pyrodactyl, /var/www/pterodactyl"
          sleep 2
          continue
        }
        check_panel_health "$panel_dir"
        output "Press Enter to return to the menu..."
        read -r
        continue
        ;;
      1)
        local elytra_binary
        elytra_binary=$(detect_elytra_binary) || {
          error "Elytra installation not found"
          sleep 2
          continue
        }
        check_elytra_health
        output "Press Enter to return to the menu..."
        read -r
        continue
        ;;
      2)
        local panel_dir
        local elytra_binary
        local has_panel=false
        local has_elytra=false

        panel_dir=$(detect_panel_location) && has_panel=true
        elytra_binary=$(detect_elytra_binary) && has_elytra=true

        if [ "$has_panel" == false ] && [ "$has_elytra" == false ]; then
          error "Neither Panel nor Elytra installation found"
          sleep 2
          continue
        fi

        if [ "$has_panel" == true ]; then
          check_panel_health "$panel_dir"
        fi

        if [ "$has_elytra" == true ]; then
          check_elytra_health
        fi

        output "Press Enter to return to the menu..."
        read -r
        continue
        ;;
      3)
        return 0
        ;;
      *)
        error "Invalid option. Please select 0-3."
        sleep 1
        ;;
    esac
  done
}

# ------------------ Main ----------------- #

main() {
  show_health_menu
}

# Run main
main "$@"
