#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Pyrodactyl Elytra Installation UI                                                  #
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

# ------------------ Configuration Variables ----------------- #

ELYTRA_REPO=""
ELYTRA_REPO_PRIVATE=false
GITHUB_TOKEN=""
PANEL_URL=""
NODE_TOKEN=""
NODE_ID=""
CONFIGURE_FIREWALL=false
INSTALL_AUTO_UPDATER=false
USE_SSL=false
BEHIND_PROXY=false
FQDN=""
ELYTRA_INSTALL_DIR="/etc/elytra"

# ------------------ Repository Configuration ----------------- #

configure_github_repository() {
  print_header
  print_flame "GitHub Repository Configuration"

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
      output "Create one at: $(hyperlink "https://github.com/settings/tokens")"
      output "Required scopes: ${COLOR_ORANGE}repo${COLOR_NC}"
      echo ""

      local token_valid=false
      while [ "$token_valid" == false ]; do
        password_input GITHUB_TOKEN "Enter your GitHub token: " "Token cannot be empty"

        output "Validating token..."
        if validate_github_token "$GITHUB_TOKEN" "$ELYTRA_REPO"; then
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
  if ! check_releases_exist "$ELYTRA_REPO" "$GITHUB_TOKEN"; then
    echo ""
    error "No releases found in repository: ${ELYTRA_REPO}"
    warning "Elytra must be installed from a release."
    exit 1
  fi

  local latest_release
  latest_release=$(get_latest_release "$ELYTRA_REPO" "$GITHUB_TOKEN")
  success "Found release: ${latest_release}"
}

# ------------------ Panel Connection ----------------- #

configure_panel_connection() {
  print_header
  print_flame "Panel Connection Configuration"

  output "Enter the URL of your Pyrodactyl Panel"
  output "Example: ${COLOR_ORANGE}https://panel.example.com${COLOR_NC}"
  echo ""

  required_input PANEL_URL "Panel URL: " "Panel URL is required"
  PANEL_URL="${PANEL_URL%/}"  # Remove trailing slash

  output ""
  output "To connect this node to the panel, you need to:"
  output "1. Go to ${PANEL_URL}/admin/nodes"
  output "2. Create a new node"
  output "3. Copy the configuration token"
  echo ""

  password_input NODE_TOKEN "Node configuration token: " "Token is required"
  required_input NODE_ID "Node ID: " "Node ID is required"
}

# ------------------ Network Configuration ----------------- #

configure_network() {
  print_header
  print_flame "Network Configuration"

  local behind_proxy_input=""
  bool_input behind_proxy_input "Is this node behind a proxy (e.g., Cloudflare)?" "n"
  BEHIND_PROXY=$([ "$behind_proxy_input" == "y" ] && echo "true" || echo "false")

  if [ "$BEHIND_PROXY" == "true" ]; then
    output "Node will be configured to work behind a proxy"
  fi
}

# ------------------ Auto-Updater ----------------- #

configure_auto_updater() {
  print_header
  print_flame "Auto-Updater Configuration"

  local install_auto_update=""
  bool_input install_auto_update "Install auto-updater for Elytra?" "y"

  if [ "$install_auto_update" == "y" ]; then
    INSTALL_AUTO_UPDATER=true
    output "Auto-updater will be installed"
  else
    output "Auto-updater will not be installed"
  fi
}

# ------------------ Firewall ----------------- #

configure_firewall() {
  print_header
  print_flame "Firewall Configuration"

  ask_firewall CONFIGURE_FIREWALL
}

# ------------------ Summary ----------------- #

show_summary() {
  print_header
  print_flame "Installation Summary"

  output "Please review the following configuration:"
  echo ""
  echo -e "  ${COLOR_ORANGE}Repository:${COLOR_NC}        ${ELYTRA_REPO} $([ "$ELYTRA_REPO_PRIVATE" == "true" ] && echo '(private)' || echo '(public)')"
  echo -e "  ${COLOR_ORANGE}Panel URL:${COLOR_NC}         ${PANEL_URL}"
  echo -e "  ${COLOR_ORANGE}Node ID:${COLOR_NC}           ${NODE_ID}"
  echo -e "  ${COLOR_ORANGE}Behind Proxy:${COLOR_NC}      $([ "$BEHIND_PROXY" == "true" ] && echo 'Yes' || echo 'No')"
  echo -e "  ${COLOR_ORANGE}Auto-Updater:${COLOR_NC}      $([ "$INSTALL_AUTO_UPDATER" == "true" ] && echo 'Yes' || echo 'No')"
  echo -e "  ${COLOR_ORANGE}Firewall:${COLOR_NC}          $([ "$CONFIGURE_FIREWALL" == "true" ] && echo 'Yes' || echo 'No')"
  echo ""

  local confirm=""
  bool_input confirm "Proceed with installation?" "y"

  if [ "$confirm" != "y" ]; then
    error "Installation aborted"
    exit 1
  fi
}

# ------------------ Export and Run ----------------- #

export_variables() {
  export ELYTRA_REPO
  export ELYTRA_REPO_PRIVATE
  export GITHUB_TOKEN
  export PANEL_URL
  export NODE_TOKEN
  export NODE_ID
  export CONFIGURE_FIREWALL
  export INSTALL_AUTO_UPDATER
  export USE_SSL
  export BEHIND_PROXY
  export FQDN
  export ELYTRA_INSTALL_DIR
}

# ------------------ Main ----------------- #

main() {
  print_flame "Welcome to the Elytra Daemon Installer"

  configure_github_repository
  configure_panel_connection
  configure_network
  configure_auto_updater
  configure_firewall
  show_summary

  export_variables

  output "Starting installation..."
  run_installer "elytra"
}

main
