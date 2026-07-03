#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Hydrodactyl Repair Tool UI                                                          #
#                                                                                    #
# Repair and fix common issues with Hydrodactyl Panel and Wings                      #
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

detect_Wings_config_dir() {
  if [ -d "/etc/Wings" ] && [ -f "/etc/Wings/config.yml" ]; then
    echo "/etc/Wings"
    return 0
  fi
  
  if [ -n "$Wings_DIR" ] && [ -d "$Wings_DIR" ] && [ -f "$Wings_DIR/config.yml" ]; then
    echo "$Wings_DIR"
    return 0
  fi
  
  # Default fallback
  echo "/etc/Wings"
  return 0
}

# ------------------ Repair Functions ----------------- #

fix_panel_permissions() {
  print_flame "Fixing Panel Permissions"

  local panel_dir
  panel_dir=$(detect_panel_location) || {
    error "Panel installation not found at any standard location"
    output "Searched: /var/www/Hydrodactyl, /var/www/pterodactyl"
    return 1
  }

  output "Found panel at: $panel_dir"

  output "Setting ownership to web server user..."
  chown -R www-data:www-data "$panel_dir" 2>/dev/null || \
  chown -R nginx:nginx "$panel_dir" 2>/dev/null || {
    error "Failed to set ownership"
    return 1
  }

  output "Setting permissions on storage and cache directories..."
  # Apply correct permissions: 755 for directories, 644 for files
  if [ -d "$panel_dir/storage" ]; then
    find "$panel_dir/storage" -type d -exec chmod 755 {} \; 2>/dev/null || true
    find "$panel_dir/storage" -type f -exec chmod 644 {} \; 2>/dev/null || true
  fi
  if [ -d "$panel_dir/bootstrap/cache" ]; then
    find "$panel_dir/bootstrap/cache" -type d -exec chmod 755 {} \; 2>/dev/null || true
    find "$panel_dir/bootstrap/cache" -type f -exec chmod 644 {} \; 2>/dev/null || true
  fi

  success "Panel permissions fixed at $panel_dir"
  return 0
}

fix_Wings_permissions() {
  print_flame "Fixing Wings Permissions"

  local Wings_binary
  local Wings_dir
  
  Wings_binary=$(detect_Wings_binary) || {
    error "Wings binary not found at /usr/local/bin/Wings or /usr/bin/Wings"
    return 1
  }
  
  Wings_dir=$(detect_Wings_config_dir)

  output "Found Wings binary at: $Wings_binary"
  output "Found Wings config at: $Wings_dir"
  
  output "Setting binary permissions..."
  chmod +x "$Wings_binary"

  output "Creating Wings data directories if needed..."
  mkdir -p /var/lib/Wings/volumes /var/lib/Wings/archives /var/lib/Wings/backups
  
  output "Setting ownership on Wings data directories..."
  chown -R 8888:8888 /var/lib/Wings/volumes 2>/dev/null || true
  chown -R 8888:8888 /var/lib/Wings/archives 2>/dev/null || true
  chown -R 8888:8888 /var/lib/Wings/backups 2>/dev/null || true
  chown -R 8888:8888 "$Wings_dir" 2>/dev/null || true

  output "Setting permissions on Wings data directories..."
  # Note: 777 is required for containerized game servers to access these directories
  # Ensure parent /var/lib/Wings is accessible
  chmod 755 /var/lib/Wings 2>/dev/null || true
  # Ensure the volumes directory itself and all contents have 777
  chmod 777 /var/lib/Wings/volumes 2>/dev/null || true
  chmod -R 777 /var/lib/Wings/volumes/* 2>/dev/null || true
  chmod 777 /var/lib/Wings/archives 2>/dev/null || true
  chmod -R 777 /var/lib/Wings/archives/* 2>/dev/null || true
  chmod 777 /var/lib/Wings/backups 2>/dev/null || true
  chmod -R 777 /var/lib/Wings/backups/* 2>/dev/null || true
  chmod -R 755 "$Wings_dir" 2>/dev/null || true
  
  # Disable check_permissions_on_boot to prevent Wings from resetting permissions
  if [ -f "$Wings_dir/config.yml" ]; then
    output "Disabling permission checks in Wings config..."
    sed -i 's/check_permissions_on_boot: true/check_permissions_on_boot: false/' "$Wings_dir/config.yml" 2>/dev/null || true
  fi

  success "Wings permissions fixed"
  return 0
}

clear_caches() {
  print_flame "Clearing Laravel Caches"

  local panel_dir
  panel_dir=$(detect_panel_location) || {
    error "Panel installation not found at any standard location"
    return 1
  }

  output "Found panel at: $panel_dir"
  cd "$panel_dir"

  output "Clearing config cache..."
  php artisan config:clear 2>/dev/null || warning "Failed to clear config cache"

  output "Clearing application cache..."
  php artisan cache:clear 2>/dev/null || warning "Failed to clear application cache"

  output "Clearing view cache..."
  php artisan view:clear 2>/dev/null || warning "Failed to clear view cache"

  output "Clearing route cache..."
  php artisan route:clear 2>/dev/null || warning "Failed to clear route cache"

  success "Caches cleared successfully at $panel_dir"
  return 0
}

restart_services() {
  print_flame "Restarting Services"

  output "Restarting nginx..."
  systemctl restart nginx 2>/dev/null || warning "Failed to restart nginx (may not be installed)"

  output "Restarting PHP-FPM..."
  if systemctl is-active --quiet php8.4-fpm 2>/dev/null; then
    systemctl restart php8.4-fpm 2>/dev/null || warning "Failed to restart php8.4-fpm"
  elif systemctl is-active --quiet php-fpm 2>/dev/null; then
    systemctl restart php-fpm 2>/dev/null || warning "Failed to restart php-fpm"
  else
    warning "PHP-FPM not found or not running"
  fi

  output "Restarting queue worker (pteroq)..."
  systemctl restart pteroq 2>/dev/null || warning "Failed to restart pteroq (may not be installed)"

  output "Restarting Redis..."
  systemctl restart redis-server 2>/dev/null || \
  systemctl restart redis 2>/dev/null || \
  warning "Failed to restart redis (may not be installed)"

  local Wings_binary
  Wings_binary=$(detect_Wings_binary 2>/dev/null)
  if [ -n "$Wings_binary" ]; then
    output "Restarting Wings..."
    systemctl restart Wings 2>/dev/null || warning "Failed to restart Wings (may not be installed)"
  fi

  success "Services restarted"
  return 0
}

setup_swap_menu() {
  print_flame "Setup Swap File"

  local swap_mb=$(free -m 2>/dev/null | awk '/^Swap:/{print $2}' || echo "0")
  
  if [ "$swap_mb" -gt 0 ]; then
    local swap_human=$(free -h 2>/dev/null | awk '/^Swap:/{print $2}' || echo "0")
    info "Swap is already configured: $swap_human"
    output "Current swap size: $swap_human"
    
    echo ""
    output "Would you like to recreate the swap file? [y/N]: "
    read -r recreate_swap
    recreate_swap=$(echo "$recreate_swap" | tr '[:upper:]' '[:lower:]')
    
    if [ "$recreate_swap" != "y" ]; then
      return 0
    fi
    
    # Remove existing swap
    output "Removing existing swap..."
    swapoff /swapfile 2>/dev/null || true
    sed -i '/\/swapfile/d' /etc/fstab
    rm -f /swapfile
  fi

  echo ""
  output "Select swap size:"
  output "[${COLOR_BLUE_THEME}1${COLOR_NC}] 1GB"
  output "[${COLOR_BLUE_THEME}2${COLOR_NC}] 2GB (recommended)"
  output "[${COLOR_BLUE_THEME}3${COLOR_NC}] 4GB"
  output "[${COLOR_BLUE_THEME}4${COLOR_NC}] Custom"
  echo ""
  echo -n "* Select an option [1-4]: "
  read -r swap_choice

  # Calculate recommended swap size based on RAM
  local ram_mb=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}' || echo "0")
  local recommended_swap=""
  local recommended_text=""
  
  if [ "$ram_mb" -lt 2048 ]; then
    # Less than 2GB RAM: 2x RAM
    recommended_swap="$((ram_mb * 2))M"
    recommended_text="2x RAM (current RAM: $(free -h | awk '/^Mem:/{print $2}'))"
  elif [ "$ram_mb" -lt 8192 ]; then
    # 2-8GB RAM: same as RAM
    local ram_gb=$((ram_mb / 1024))
    recommended_swap="${ram_gb}G"
    recommended_text="Same as RAM (${recommended_swap})"
  else
    # More than 8GB RAM: at least 4GB
    recommended_swap="4G"
    recommended_text="4GB (minimum recommended for systems with >8GB RAM)"
  fi
  
  output ""
  output "System RAM: $(free -h 2>/dev/null | awk '/^Mem:/{print $2}')"
  output "Recommended swap: ${recommended_text}"
  output ""

  local swap_size=""
  case "$swap_choice" in
    1) swap_size="1G" ;;
    2) swap_size="2G" ;;
    3) swap_size="4G" ;;
    4) 
      echo -n "* Enter swap size (e.g., 512M, 2G) [recommended: ${recommended_swap}]: "
      read -r swap_size
      if [ -z "$swap_size" ]; then
        swap_size="$recommended_swap"
        output "Using recommended size: ${recommended_swap}"
      fi
      ;;
    *) 
      warning "Invalid option. Using recommended size: ${recommended_swap}"
      swap_size="$recommended_swap"
      ;;
  esac

  # Call the setup function from lib
  setup_swap "$swap_size"
  
  # Show results
  echo ""
  output "Updated swap status:"
  free -h | grep -E "(Mem|Swap):"
  
  output "Press Enter to continue..."
  read -r
}

fix_database_permissions() {
  print_flame "Fixing Database Permissions"

  local db_root_pass=""

  if [ -f /root/.config/Hydrodactyl/db-credentials ]; then
    db_root_pass=$(grep '^root:' /root/.config/Hydrodactyl/db-credentials 2>/dev/null | cut -d':' -f2)
  fi

  if [ -z "$db_root_pass" ]; then
    error "Database root password not found in /root/.config/Hydrodactyl/db-credentials"
    echo ""
    output "Please enter the MySQL/MariaDB root password:"
    read -r -s db_root_pass
    echo ""
  fi

  # Test connection
  if ! mysql -u root -p"${db_root_pass}" -e "SELECT 1" >/dev/null 2>&1; then
    error "Failed to connect to database with provided password"
    return 1
  fi

  # Extract and validate Hydrodactyl password
  local hydro_pass
  hydro_pass=$(grep '^Hydrodactyl:' /root/.config/Hydrodactyl/db-credentials 2>/dev/null | cut -d':' -f2)

  if [ -z "$hydro_pass" ]; then
    error "Hydrodactyl user password not found in credentials file"
    return 1
  fi

  # Escape single quotes in password for SQL (replace ' with '')
  local hydro_pass_escaped="${hydro_pass//\'/''}"

  output "Ensuring Hydrodactyl database user exists..."
  mysql -u root -p"${db_root_pass}" -e "
    GRANT ALL PRIVILEGES ON panel.* TO 'Hydrodactyl'@'127.0.0.1' IDENTIFIED BY '${hydro_pass_escaped}' WITH GRANT OPTION;
    FLUSH PRIVILEGES;
  " 2>/dev/null || warning "Failed to update Hydrodactyl user permissions"

  output "Testing database connectivity..."
  local db_pass
  db_pass=$(grep '^Hydrodactyl:' /root/.config/Hydrodactyl/db-credentials 2>/dev/null | cut -d':' -f2)
  if mysql -u Hydrodactyl -p"${db_pass}" -h 127.0.0.1 -e "SELECT 1" panel >/dev/null 2>&1; then
    success "Database connection successful"
  else
    warning "Database connection test failed"
  fi

  return 0
}

run_all_fixes() {
  print_flame "Running All Fixes"

  local has_errors=false

  echo ""
  warning "This will run all repair operations. Some services may be restarted."
  output "Press Enter to continue or Ctrl+C to cancel..."
  read -r

  fix_panel_permissions || has_errors=true
  echo ""

  fix_Wings_permissions || has_errors=true
  echo ""

  clear_caches || has_errors=true
  echo ""

  restart_services || has_errors=true
  echo ""

  if [ "$has_errors" == true ]; then
    warning "Some fixes completed with warnings. Check the output above."
  else
    success "All fixes completed successfully!"
  fi

  output "Press Enter to return to the menu..."
  read -r
}

# ------------------ Menu Functions ----------------- #

show_repair_menu() {
  local choice=""

  while true; do
    print_header
    print_flame "Repair Tool"

    # Check swap status
    local swap_mb=$(free -m 2>/dev/null | awk '/^Swap:/{print $2}' || echo "0")
    local swap_status=""
    if [ "$swap_mb" -eq 0 ]; then
      swap_status=" ${COLOR_RED}[No swap]${COLOR_NC}"
    fi

    echo ""
    output "${COLOR_BLUE_THEME}What would you like to repair?${COLOR_NC}"
    echo ""
    output "[${COLOR_BLUE_THEME}0${COLOR_NC}] Fix Panel Permissions"
    output "[${COLOR_BLUE_THEME}1${COLOR_NC}] Fix Wings Permissions"
    output "[${COLOR_BLUE_THEME}2${COLOR_NC}] Clear Laravel Caches"
    output "[${COLOR_BLUE_THEME}3${COLOR_NC}] Restart All Services"
    output "[${COLOR_BLUE_THEME}4${COLOR_NC}] Fix Database Permissions"
    output "[${COLOR_BLUE_THEME}5${COLOR_NC}] Run All Fixes (Recommended)"
    output "[${COLOR_BLUE_THEME}6${COLOR_NC}] Setup Swap File${swap_status}"
    echo ""
    output "[${COLOR_BLUE_THEME}7${COLOR_NC}] Back to Main Menu"
    echo ""

    echo -n "* Select an option [0-7]: "
    read -r choice

    case "$choice" in
      0)
        fix_panel_permissions
        output "Press Enter to return to the menu..."
        read -r
        continue
        ;;
      1)
        fix_Wings_permissions
        output "Press Enter to return to the menu..."
        read -r
        continue
        ;;
      2)
        clear_caches
        output "Press Enter to return to the menu..."
        read -r
        continue
        ;;
      3)
        restart_services
        output "Press Enter to return to the menu..."
        read -r
        continue
        ;;
      4)
        fix_database_permissions
        output "Press Enter to return to the menu..."
        read -r
        continue
        ;;
      5)
        run_all_fixes
        continue
        ;;
      6)
        setup_swap_menu
        continue
        ;;
      7)
        return 0
        ;;
      *)
        error "Invalid option. Please select 0-7."
        sleep 1
        ;;
    esac
  done
}

# ------------------ Main ----------------- #

main() {
  show_repair_menu
}

# Run main
main "$@"