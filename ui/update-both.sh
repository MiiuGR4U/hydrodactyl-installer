#!/bin/bash

set -e

# shellcheck source=lib/lib.sh
source /tmp/pyrodactyl-lib.sh

main() {
  print_header
  print_flame "Update Both Panel and Elytra"

  output "This will update both Pyrodactyl Panel and Elytra to the latest versions."
  echo ""

  local confirm=""
  bool_input confirm "Proceed with updating both components?" "y"

  if [ "$confirm" != "y" ]; then
    output "Update cancelled"
    exit 0
  fi

  # Update Panel first
  echo ""
  print_flame "Starting Panel Update"
  echo ""

  export -f print_header print_flame output success warning error info bool_input
  export COLOR_GREEN COLOR_YELLOW COLOR_RED COLOR_ORANGE COLOR_NC
  export DEFAULT_PANEL_REPO DEFAULT_ELYTRA_REPO

  if [ -d "/var/www/pyrodactyl" ]; then
    bash <(curl -sSL "$GITHUB_URL/ui/update-panel.sh")
  else
    warning "Panel is not installed, skipping panel update"
  fi

  # Update Elytra
  echo ""
  print_flame "Starting Elytra Update"
  echo ""

  if [ -f "/usr/local/bin/elytra" ]; then
    bash <(curl -sSL "$GITHUB_URL/ui/update-elytra.sh")
  else
    warning "Elytra is not installed, skipping Elytra update"
  fi

  print_header
  print_flame "All Updates Complete!"

  echo ""
  output "Both components have been updated to their latest versions!"
  echo ""

  print_brake 70
}

main
