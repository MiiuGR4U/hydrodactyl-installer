#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Pyrodactyl Auto-Updater Management UI                                              #
#                                                                                    #
# Copyright (C) 2025, Muspelheim Hosting                                             #
#                                                                                    #
######################################################################################

# Check if lib is loaded, load if not or fail otherwise.
fn_exists() { declare -F "$1" >/dev/null; }
if ! fn_exists lib_loaded; then
  source /tmp/pyrodactyl-lib.sh 2>/dev/null || source <(curl -sSL "${GITHUB_BASE_URL:-"https://raw.githubusercontent.com/Muspelheim-Hosting/pyrodactyl-installer"}/${GITHUB_SOURCE:-"main"}/lib/lib.sh")
  ! fn_exists lib_loaded && echo "* ERROR: Could not load lib script" && exit 1
fi

# ------------------ State Variables ----------------- #

PANEL_REPO=""
PANEL_REPO_PRIVATE=false
GITHUB_TOKEN_PANEL=""
ELYTRA_REPO=""
ELYTRA_REPO_PRIVATE=false
GITHUB_TOKEN_ELYTRA=""

# ------------------ Panel Auto-Updater ----------------- #

configure_panel_auto_updater() {
  print_header
  print_flame "Panel Auto-Updater Configuration"

  output "The default Pyrodactyl Panel repository is:"
  output "  ${COLOR_ORANGE}${DEFAULT_PANEL_REPO}${COLOR_NC}"
  echo ""

  local use_default=""
  bool_input use_default "Use default repository?" "y"

  if [ "$use_default" == "y" ]; then
    PANEL_REPO="$DEFAULT_PANEL_REPO"
  else
    required_input PANEL_REPO "Enter the GitHub repository (format: owner/repo): " "Repository cannot be empty"

    if [[ ! "$PANEL_REPO" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
      error "Invalid repository format. Must be 'owner/repo'"
      exit 1
    fi
  fi

  echo ""
  output "Repository: ${COLOR_ORANGE}${PANEL_REPO}${COLOR_NC}"

  # Only ask about private repo if not using default (default is public)
  if [ "$use_default" == "n" ]; then
    local is_private=""
    bool_input is_private "Is this a private repository?" "n"
    PANEL_REPO_PRIVATE=$([ "$is_private" == "y" ] && echo "true" || echo "false")

    if [ "$PANEL_REPO_PRIVATE" == "true" ]; then
      echo ""
      output "A GitHub Personal Access Token is required for private repositories."
      output "Create one at: https://github.com/settings/tokens"
      output "Required scopes: ${COLOR_ORANGE}repo${COLOR_NC}"
      echo ""

      local token_valid=false
      while [ "$token_valid" == false ]; do
        password_input GITHUB_TOKEN_PANEL "Enter your GitHub token: " "Token cannot be empty"

        output "Validating token..."
        if validate_github_token "$GITHUB_TOKEN_PANEL" "$PANEL_REPO"; then
          success "Token validated successfully"
          token_valid=true
        else
          warning "Token validation failed. Please check your token and try again."
        fi
      done
    fi
  else
    PANEL_REPO_PRIVATE="false"
  fi

  output "Checking for releases in repository..."
  if ! check_releases_exist "$PANEL_REPO" "$GITHUB_TOKEN_PANEL"; then
    echo ""
    error "No releases found in repository: ${PANEL_REPO}"
    warning "You must publish a release before using the auto-updater."
    exit 1
  fi

  local latest_release
  latest_release=$(get_latest_release "$PANEL_REPO" "$GITHUB_TOKEN_PANEL")
  success "Found release: ${latest_release}"

  export PANEL_REPO
  export PANEL_REPO_PRIVATE
  export GITHUB_TOKEN="$GITHUB_TOKEN_PANEL"

  install_auto_updater_panel
}

# ------------------ Elytra Auto-Updater ----------------- #

configure_elytra_auto_updater() {
  print_header
  print_flame "Elytra Auto-Updater Configuration"

  output "The default Elytra repository is:"
  output "  ${COLOR_ORANGE}${DEFAULT_ELYTRA_REPO}${COLOR_NC}"
  echo ""

  local use_default=""
  bool_input use_default "Use default repository?" "y"

  if [ "$use_default" == "y" ]; then
    ELYTRA_REPO="$DEFAULT_ELYTRA_REPO"
  else
    required_input ELYTRA_REPO "Enter the GitHub repository (format: owner/repo): " "Repository cannot be empty"

    if [[ ! "$ELYTRA_REPO" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
      error "Invalid repository format. Must be 'owner/repo'"
      exit 1
    fi
  fi

  echo ""
  output "Repository: ${COLOR_ORANGE}${ELYTRA_REPO}${COLOR_NC}"

  # Only ask about private repo if not using default (default is public)
  if [ "$use_default" == "n" ]; then
    local is_private=""
    bool_input is_private "Is this a private repository?" "n"
    ELYTRA_REPO_PRIVATE=$([ "$is_private" == "y" ] && echo "true" || echo "false")

    if [ "$ELYTRA_REPO_PRIVATE" == "true" ]; then
      echo ""
      output "A GitHub Personal Access Token is required for private repositories."
      output "Create one at: https://github.com/settings/tokens"
      output "Required scopes: ${COLOR_ORANGE}repo${COLOR_NC}"
      echo ""

      local token_valid=false
      while [ "$token_valid" == false ]; do
        password_input GITHUB_TOKEN_ELYTRA "Enter your GitHub token: " "Token cannot be empty"

        output "Validating token..."
        if validate_github_token "$GITHUB_TOKEN_ELYTRA" "$ELYTRA_REPO"; then
          success "Token validated successfully"
          token_valid=true
        else
          warning "Token validation failed. Please check your token and try again."
        fi
      done
    fi
  else
    ELYTRA_REPO_PRIVATE="false"
  fi

  output "Checking for releases in repository..."
  if ! check_releases_exist "$ELYTRA_REPO" "$GITHUB_TOKEN_ELYTRA"; then
    echo ""
    error "No releases found in repository: ${ELYTRA_REPO}"
    warning "You must publish a release before using the auto-updater."
    exit 1
  fi

  local latest_release
  latest_release=$(get_latest_release "$ELYTRA_REPO" "$GITHUB_TOKEN_ELYTRA")
  success "Found release: ${latest_release}"

  export ELYTRA_REPO
  export ELYTRA_REPO_PRIVATE
  export GITHUB_TOKEN="$GITHUB_TOKEN_ELYTRA"

  install_auto_updater_elytra
}

# ------------------ Both Auto-Updaters ----------------- #

configure_both_auto_updaters() {
  print_header
  print_flame "Configure Both Auto-Updaters"

  configure_panel_auto_updater

  echo ""
  output "Now configuring Elytra auto-updater..."
  echo ""

  configure_elytra_auto_updater

  success "Both auto-updaters installed successfully!"
}

# ------------------ Remove Menu ----------------- #

show_remove_menu() {
  print_header
  print_flame "Remove Auto-Updaters"

  # Check what's installed
  local panel_updater_installed=false
  local elytra_updater_installed=false

  if systemctl is-enabled --quiet pyrodactyl-panel-auto-update.timer 2>/dev/null; then
    panel_updater_installed=true
  fi

  if systemctl is-enabled --quiet pyrodactyl-elytra-auto-update.timer 2>/dev/null; then
    elytra_updater_installed=true
  fi

  if [ "$panel_updater_installed" == false ] && [ "$elytra_updater_installed" == false ]; then
    warning "No auto-updaters are currently installed."
    echo ""
    output "Press Enter to return to main menu..."
    read -r
    return
  fi

  output "Which auto-updaters would you like to remove?"
  echo ""

  if [ "$panel_updater_installed" == true ]; then
    output "[${COLOR_ORANGE}0${COLOR_NC}] Panel auto-updater only"
  fi

  if [ "$elytra_updater_installed" == true ]; then
    output "[${COLOR_ORANGE}1${COLOR_NC}] Elytra auto-updater only"
  fi

  if [ "$panel_updater_installed" == true ] && [ "$elytra_updater_installed" == true ]; then
    output "[${COLOR_ORANGE}2${COLOR_NC}] Both auto-updaters"
  fi

  output "[${COLOR_ORANGE}3${COLOR_NC}] Cancel"
  echo ""

  local choice=""
  while true; do
    echo -n "* Select option: "
    read -r choice

    case "$choice" in
      0)
        if [ "$panel_updater_installed" == true ]; then
          warning "This will remove the Panel auto-updater"
          local confirm=""
          bool_input confirm "Are you sure?" "n"
          if [ "$confirm" == "y" ]; then
            remove_auto_updater_panel
            success "Panel auto-updater removed"
          fi
          break
        else
          error "Invalid option"
        fi
        ;;
      1)
        if [ "$elytra_updater_installed" == true ]; then
          warning "This will remove the Elytra auto-updater"
          local confirm=""
          bool_input confirm "Are you sure?" "n"
          if [ "$confirm" == "y" ]; then
            remove_auto_updater_elytra
            success "Elytra auto-updater removed"
          fi
          break
        else
          error "Invalid option"
        fi
        ;;
      2)
        if [ "$panel_updater_installed" == true ] && [ "$elytra_updater_installed" == true ]; then
          warning "This will remove both auto-updaters"
          local confirm=""
          bool_input confirm "Are you sure?" "n"
          if [ "$confirm" == "y" ]; then
            remove_auto_updater_panel
            remove_auto_updater_elytra
            success "All auto-updaters removed"
          fi
          break
        else
          error "Invalid option"
        fi
        ;;
      3)
        output "Cancelled"
        break
        ;;
      *)
        error "Invalid option"
        ;;
    esac
  done
}

# ------------------ Trigger Update Functions ----------------- #

trigger_panel_update() {
  print_header
  print_flame "Trigger Panel Update"

  if [ ! -f /usr/local/bin/pyrodactyl-auto-update-panel.sh ]; then
    error "Panel auto-updater is not installed"
    output "Install it first from the main menu"
    echo ""
    output "Press Enter to continue..."
    read -r
    return
  fi

  output "Running Panel auto-updater now..."
  echo ""

  /usr/local/bin/pyrodactyl-auto-update-panel.sh

  echo ""
  output "Press Enter to continue..."
  read -r
}

trigger_elytra_update() {
  print_header
  print_flame "Trigger Elytra Update"

  if [ ! -f /usr/local/bin/pyrodactyl-auto-update-elytra.sh ]; then
    error "Elytra auto-updater is not installed"
    output "Install it first from the main menu"
    echo ""
    output "Press Enter to continue..."
    read -r
    return
  fi

  output "Running Elytra auto-updater now..."
  echo ""

  /usr/local/bin/pyrodactyl-auto-update-elytra.sh

  echo ""
  output "Press Enter to continue..."
  read -r
}

trigger_both_updates() {
  print_header
  print_flame "Trigger Both Updates"

  local panel_installed=false
  local elytra_installed=false

  if [ -f /usr/local/bin/pyrodactyl-auto-update-panel.sh ]; then
    panel_installed=true
  fi

  if [ -f /usr/local/bin/pyrodactyl-auto-update-elytra.sh ]; then
    elytra_installed=true
  fi

  if [ "$panel_installed" == false ] && [ "$elytra_installed" == false ]; then
    error "No auto-updaters are installed"
    output "Install them first from the main menu"
    echo ""
    output "Press Enter to continue..."
    read -r
    return
  fi

  if [ "$panel_installed" == true ]; then
    output "Running Panel auto-updater..."
    echo ""
    /usr/local/bin/pyrodactyl-auto-update-panel.sh
    echo ""
  fi

  if [ "$elytra_installed" == true ]; then
    output "Running Elytra auto-updater..."
    echo ""
    /usr/local/bin/pyrodactyl-auto-update-elytra.sh
    echo ""
  fi

  output "Press Enter to continue..."
  read -r
}

# ------------------ Main Menu ----------------- #

show_main_menu() {
  while true; do
    print_header
    print_flame "Auto-Updater Management"

    output "What would you like to do?"
    echo ""
    output "[${COLOR_ORANGE}0${COLOR_NC}] Install Panel auto-updater"
    output "[${COLOR_ORANGE}1${COLOR_NC}] Install Elytra auto-updater"
    output "[${COLOR_ORANGE}2${COLOR_NC}] Install both auto-updaters"
    echo ""
    output "[${COLOR_ORANGE}3${COLOR_NC}] Remove auto-updaters"
    output "[${COLOR_ORANGE}4${COLOR_NC}] Trigger Panel update now"
    output "[${COLOR_ORANGE}5${COLOR_NC}] Trigger Elytra update now"
    output "[${COLOR_ORANGE}6${COLOR_NC}] Trigger both updates now"
    echo ""
    output "[${COLOR_ORANGE}7${COLOR_NC}] Return to main menu"
    echo ""

    local choice=""
    echo -n "* Select [0-7]: "
    read -r choice

    case "$choice" in
      0)
        configure_panel_auto_updater
        echo ""
        output "Press Enter to continue..."
        read -r
        ;;
      1)
        configure_elytra_auto_updater
        echo ""
        output "Press Enter to continue..."
        read -r
        ;;
      2)
        configure_both_auto_updaters
        echo ""
        output "Press Enter to continue..."
        read -r
        ;;
      3)
        show_remove_menu
        ;;
      4)
        trigger_panel_update
        ;;
      5)
        trigger_elytra_update
        ;;
      6)
        trigger_both_updates
        ;;
      7)
        output "Returning to main menu..."
        exit 0
        ;;
      *)
        error "Invalid option. Please select 0-7."
        sleep 2
        ;;
    esac
  done
}

# ------------------ Main ----------------- #

main() {
  show_main_menu
}

main
