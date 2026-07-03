#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Hydrodactyl Installation Info Viewer                                                #
#                                                                                    #
# Displays saved installation information for Panel and/or Wings                    #
#                                                                                    #
# Copyright (C) 2025, Blueprint                                             #
#                                                                                    #
# https://github.com/MiiuGR4U/hydrodactyl-installer                         #
#                                                                                    #
######################################################################################

# Check if script is loaded, load if not or fail otherwise.
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

# ------------------ Main Function ----------------- #

main() {
  print_header
  print_flame "Installation Information"

  local has_panel_info=false
  local has_Wings_info=false

  # Check what information is available
  if panel_install_info_exists; then
    has_panel_info=true
  fi

  if Wings_install_info_exists; then
    has_Wings_info=true
  fi

  # Show summary
  echo ""
  if [ "$has_panel_info" == true ] && [ "$has_Wings_info" == true ]; then
    output "Both Panel and Wings installation information found."
  elif [ "$has_panel_info" == true ]; then
    output "Panel installation information found."
  elif [ "$has_Wings_info" == true ]; then
    output "Wings installation information found."
  else
    warning "No installation information found."
    echo ""
    output "Installation information is saved when you:"
    output "  - Install Hydrodactyl Panel"
    output "  - Install Wings Daemon"
    echo ""
    output "If you just completed an installation, the information"
    output "should be available. Try running the installer again."
    echo ""
    output "Press Enter to return to the menu..."
    read -r
    return 0
  fi

  echo ""

  # Display panel info if available
  if [ "$has_panel_info" == true ]; then
    display_panel_install_info
    echo ""
  fi

  # Display Wings info if available
  if [ "$has_Wings_info" == true ]; then
    display_Wings_install_info
    echo ""
  fi

  # Check for health check failure logs
  local has_health_check_failures=false
  
  if [ -f "/etc/Hydrodactyl/update-health-check-failure.log" ]; then
    has_health_check_failures=true
  fi
  
  if [ -f "/etc/Wings/update-health-check-failure.log" ]; then
    has_health_check_failures=true
  fi
  
  if [ "$has_health_check_failures" == true ]; then
    echo ""
    warning "Health check failures detected!"
    output "Recent update attempts failed health checks."
    echo ""
    echo -n "* View health check failure logs? [y/N]: "
    read -r view_health
    view_health=$(echo "$view_health" | tr '[:upper:]' '[:lower:]')
    
    if [ "$view_health" == "y" ]; then
      echo ""
      if [ -f "/etc/Hydrodactyl/update-health-check-failure.log" ]; then
        output "Panel Health Check Failure Log:"
        echo "---"
        cat "/etc/Hydrodactyl/update-health-check-failure.log" 2>/dev/null || echo "Could not read file"
        echo "---"
        echo ""
      fi
      
      if [ -f "/etc/Wings/update-health-check-failure.log" ]; then
        output "Wings Health Check Failure Log:"
        echo "---"
        cat "/etc/Wings/update-health-check-failure.log" 2>/dev/null || echo "Could not read file"
        echo "---"
        echo ""
      fi
      
      output "To fix these issues, run the Repair Tool from the main menu."
      echo ""
    fi
  fi

  # Option to view raw files
  echo ""
  echo -n "* View raw configuration files? [y/N]: "
  read -r view_raw
  view_raw=$(echo "$view_raw" | tr '[:upper:]' '[:lower:]')

  if [ "$view_raw" == "y" ]; then
    echo ""
    if [ "$has_panel_info" == true ]; then
      output "Panel Info File: $INSTALL_INFO_DIR/panel-info"
      echo "---"
      cat "$INSTALL_INFO_DIR/panel-info" 2>/dev/null || echo "Could not read file"
      echo "---"
      echo ""
    fi

    if [ "$has_Wings_info" == true ]; then
      output "Wings Info File: $INSTALL_INFO_DIR/Wings-info"
      echo "---"
      cat "$INSTALL_INFO_DIR/Wings-info" 2>/dev/null || echo "Could not read file"
      echo "---"
      echo ""
    fi
  fi

  output "Press Enter to return to the menu..."
  read -r
}

# Run main
main "$@"