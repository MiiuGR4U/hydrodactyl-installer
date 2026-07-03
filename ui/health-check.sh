#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Hydrodactyl Health Check UI                                                         #
#                                                                                    #
# Health check and diagnostics for Hydrodactyl Panel and Wings                       #
#                                                                                    #
# Copyright (C) 2025, Blueprint                                             #
#                                                                                    #
# https://github.com/MiiuGR4U/hydrodactyl-installer                         #
#                                                                                    #
######################################################################################

# Check if lib is loaded, load if not or fail otherwise.
fn_exists() { declare -F "$1" >/dev/null; }
if ! fn_exists lib_loaded; then
  # Try temp file first (when run through install.sh)
  if [ -f /tmp/Hydrodactyl-lib.sh ]; then
    # shellcheck source=/dev/null
    if ! source /tmp/Hydrodactyl-lib.sh 2>/dev/null; then
      # Temp file exists but failed to load (corrupt/invalid) - remove it
      rm -f /tmp/Hydrodactyl-lib.sh
    fi
  fi
  # Fall back to downloading if temp file didn't load or doesn't exist
  if ! fn_exists lib_loaded; then
    # shellcheck source=/dev/null
    source <(curl -sSL "${GITHUB_BASE_URL:-"https://raw.githubusercontent.com/MiiuGR4U/hydrodactyl-installer"}/${GITHUB_SOURCE:-"main"}/lib/lib.sh")
  fi
  ! fn_exists lib_loaded && echo "* ERROR: Could not load lib script" && exit 1
fi

# ------------------ Root Check ----------------- #

check_root() {
  if [[ $EUID -ne 0 ]]; then
    error "This script must be executed with root privileges."
    exit 1
  fi
}

check_root

# ------------------ System Resources Check ----------------- #

check_system_resources_health() {
  echo ""
  output "${COLOR_ORANGE}System Resources Check${COLOR_NC}"
  echo ""
  
  local cpu_cores=$(get_cpu_cores)
  local ram_mb=$(get_ram_mb)
  local disk_gb=$(get_disk_gb)
  local swap_mb=$(get_swap_mb)
  local has_warnings=false
  
  output "CPU Cores:        $cpu_cores"
  if [ "$cpu_cores" -lt "$MIN_CPU_CORES" ]; then
    warning "  CPU cores below minimum ($MIN_CPU_CORES)"
    has_warnings=true
  elif [ "$cpu_cores" -lt "$REC_CPU_CORES" ]; then
    info "  CPU cores below recommended ($REC_CPU_CORES)"
  else
    output "  Ã¢Å“â€œ CPU meets recommended requirements"
  fi
  
  output "RAM:              $(get_ram_human) (${ram_mb}MB)"
  if [ "$ram_mb" -lt "$MIN_RAM_MB" ]; then
    warning "  RAM below minimum (${MIN_RAM_MB}MB / 2GB)"
    has_warnings=true
  elif [ "$ram_mb" -lt "$REC_RAM_MB" ]; then
    info "  RAM below recommended (${REC_RAM_MB}MB / 4GB)"
  else
    output "  Ã¢Å“â€œ RAM meets recommended requirements"
  fi
  
  output "Disk (root):      $(get_disk_human) (${disk_gb}GB)"
  if [ "$disk_gb" -lt "$MIN_DISK_GB" ]; then
    warning "  Disk below minimum (${MIN_DISK_GB}GB)"
    has_warnings=true
  elif [ "$disk_gb" -lt "$REC_DISK_GB" ]; then
    info "  Disk below recommended (${REC_DISK_GB}GB)"
  else
    output "  Ã¢Å“â€œ Disk meets recommended requirements"
  fi
  
  output "Swap:             $(get_swap_human)"
  if [ "$swap_mb" -eq 0 ]; then
    warning "  No swap configured - recommended for system stability"
    has_warnings=true
  else
    output "  Ã¢Å“â€œ Swap is configured"
  fi
  
  # Check Docker compatibility for Wings
  echo ""
  output "Docker Compatibility:"
  if ! check_docker_compatibility; then
    has_warnings=true
  fi
  
  echo ""
  if [ "$has_warnings" == true ]; then
    warning "System resources check completed with warnings"
  else
    success "System resources check passed!"
  fi
  
  return 0
}

# ------------------ Detection Functions ----------------- #

detect_panel_location() {
  # Check for Hydrodactyl first (install script location)
  if [ -d "/var/www/Hydrodactyl" ] && [ -f "/var/www/Hydrodactyl/artisan" ]; then
    echo "/var/www/Hydrodactyl"
    return 0
  fi

  # Check for Pterodactyl location (might be Hydrodactyl migrated)
  if [ -d "/var/www/pterodactyl" ] && [ -f "/var/www/pterodactyl/artisan" ]; then
    # Verify it's actually Hydrodactyl
    if grep -q "Hydrodactyl" "/var/www/pterodactyl/config/app.php" 2>/dev/null || \
       grep -q "Hydrodactyl" "/var/www/pterodactyl/composer.json" 2>/dev/null; then
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

detect_Wings_binary() {
  if [ -f "/usr/local/bin/Wings" ]; then
    echo "/usr/local/bin/Wings"
    return 0
  fi

  if [ -f "/usr/bin/Wings" ]; then
    echo "/usr/bin/Wings"
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
    output "[${COLOR_ORANGE}1${COLOR_NC}] Check Wings Health"
    output "[${COLOR_ORANGE}2${COLOR_NC}] Check Both"
    output "[${COLOR_ORANGE}3${COLOR_NC}] Check System Resources"
    echo ""
    output "[${COLOR_ORANGE}4${COLOR_NC}] Back to Main Menu"
    echo ""

    echo -n "* Select an option [0-4]: "
    read -r choice

    case "$choice" in
      0)
        local panel_dir
        panel_dir=$(detect_panel_location) || {
          error "Panel installation not found"
          output "Searched: /var/www/Hydrodactyl, /var/www/pterodactyl"
          sleep 2
          continue
        }
        check_panel_health "$panel_dir"
        output "Press Enter to return to the menu..."
        read -r
        continue
        ;;
      1)
        local Wings_binary
        Wings_binary=$(detect_Wings_binary) || {
          error "Wings installation not found"
          sleep 2
          continue
        }
        check_Wings_health
        output "Press Enter to return to the menu..."
        read -r
        continue
        ;;
      2)
        local panel_dir
        local Wings_binary
        local has_panel=false
        local has_Wings=false

        panel_dir=$(detect_panel_location) && has_panel=true
        Wings_binary=$(detect_Wings_binary) && has_Wings=true

        if [ "$has_panel" == false ] && [ "$has_Wings" == false ]; then
          error "Neither Panel nor Wings installation found"
          sleep 2
          continue
        fi

        if [ "$has_panel" == true ]; then
          check_panel_health "$panel_dir"
        fi

        if [ "$has_Wings" == true ]; then
          check_Wings_health
        fi

        output "Press Enter to return to the menu..."
        read -r
        continue
        ;;
      3)
        check_system_resources_health
        output "Press Enter to return to the menu..."
        read -r
        continue
        ;;
      4)
        return 0
        ;;
      *)
        error "Invalid option. Please select 0-4."
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
