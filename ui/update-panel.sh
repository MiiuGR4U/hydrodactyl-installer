#!/bin/bash

set -e

# shellcheck source=lib/lib.sh
source /tmp/pyrodactyl-lib.sh

PANEL_REPO=""
PANEL_REPO_PRIVATE=false
GITHUB_TOKEN=""
USE_AUTO_UPDATER_REPO=false

detect_current_installation() {
  print_header
  print_flame "Detecting Current Installation"

  if [ ! -d "/var/www/pyrodactyl" ]; then
    error "Panel is not installed at /var/www/pyrodactyl"
    exit 1
  fi

  output "Found panel installation at /var/www/pyrodactyl"

  # Try to detect current version
  local current_version="unknown"
  if [ -f "/var/www/pyrodactyl/config/app.php" ]; then
    current_version=$(grep "'version'" /var/www/pyrodactyl/config/app.php 2>/dev/null | head -1 | cut -d"'" -f4 || echo "unknown")
  fi

  output "Current version: ${COLOR_ORANGE}${current_version}${COLOR_NC}"

  # Check if auto-updater config exists
  if [ -f "/etc/systemd/system/pyrodactyl-panel-auto-update.service" ]; then
    output "Auto-updater configuration detected"
    local use_existing=""
    bool_input use_existing "Use repository from auto-updater configuration?" "y"

    if [ "$use_existing" == "y" ]; then
      USE_AUTO_UPDATER_REPO=true
      # Extract repo from service file
      PANEL_REPO=$(grep "PANEL_REPO=" /etc/systemd/system/pyrodactyl-panel-auto-update.service | cut -d'=' -f2 || echo "$DEFAULT_PANEL_REPO")
      output "Using repository: ${COLOR_ORANGE}${PANEL_REPO}${COLOR_NC}"
    fi
  fi
}

configure_repository() {
  if [ "$USE_AUTO_UPDATER_REPO" == "true" ]; then
    return 0
  fi

  print_header
  print_flame "Repository Configuration"

  output "The default Pyrodactyl Panel repository is:"
  output "  ${COLOR_ORANGE}${DEFAULT_PANEL_REPO}${COLOR_NC}"
  echo ""

  local use_default=""
  bool_input use_default "Use default repository?" "y"

  if [ "$use_default" == "y" ]; then
    PANEL_REPO="$DEFAULT_PANEL_REPO"
  else
    required_input PANEL_REPO "Enter the GitHub repository (format: owner/repo): " "Repository cannot be empty"

    # Validate repo format
    if [[ ! "$PANEL_REPO" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
      error "Invalid repository format. Must be 'owner/repo'"
      exit 1
    fi
  fi

  echo ""
  output "Repository: ${COLOR_ORANGE}${PANEL_REPO}${COLOR_NC}"

  # Ask if repository is private
  local is_private=""
  bool_input is_private "Is this a private repository?" "n"
  PANEL_REPO_PRIVATE=$([ "$is_private" == "y" ] && echo "true" || echo "false")

  if [ "$PANEL_REPO_PRIVATE" == "true" ]; then
    echo ""
    output "A GitHub Personal Access Token is required for private repositories."
    output "Create one at: $(hyperlink "https://github.com/settings/tokens")"
    output "Required scopes: ${COLOR_ORANGE}repo${COLOR_NC}"
    echo ""

    local token_valid=false
    while [ "$token_valid" == false ]; do
      password_input GITHUB_TOKEN "Enter your GitHub token: " "Token cannot be empty"

      output "Validating token..."
      if validate_github_token "$GITHUB_TOKEN" "$PANEL_REPO"; then
        success "Token validated successfully"
        token_valid=true
      else
        warning "Token validation failed. Please check your token and try again."
      fi
    done
  fi
}

check_for_update() {
  print_header
  print_flame "Checking for Updates"

  output "Checking latest release from ${PANEL_REPO}..."

  local latest_release
  latest_release=$(get_latest_release "$PANEL_REPO" "$GITHUB_TOKEN")

  if [ -z "$latest_release" ] || [ "$latest_release" == "null" ]; then
    error "Could not fetch latest version from repository"
    exit 1
  fi

  local current_version="unknown"
  if [ -f "/var/www/pyrodactyl/config/app.php" ]; then
    current_version=$(grep "'version'" /var/www/pyrodactyl/config/app.php 2>/dev/null | head -1 | cut -d"'" -f4 || echo "unknown")
  fi

  echo ""
  echo -e "  ${COLOR_ORANGE}Current version:${COLOR_NC}  ${current_version}"
  echo -e "  ${COLOR_ORANGE}Latest version:${COLOR_NC}   ${latest_release}"
  echo ""

  if [ "$current_version" == "$latest_release" ]; then
    success "Your panel is already up to date!"
    output "No update needed."
    exit 0
  fi

  # Version comparison
  if printf '%s\n' "$latest_release" "$current_version" | sort -V -C; then
    # latest_release >= current_version
    if [ "$latest_release" != "$current_version" ]; then
      output "An update is available!"
    fi
  else
    warning "Your current version appears to be newer than the latest release."
    output "This may be a development build."
  fi

  local confirm=""
  bool_input confirm "Proceed with update to ${latest_release}?" "y"

  if [ "$confirm" != "y" ]; then
    output "Update cancelled"
    exit 0
  fi
}

perform_update() {
  print_header
  print_flame "Updating Panel"

  # Run the auto-update script directly
  export PANEL_REPO
  export GITHUB_TOKEN

  /usr/local/bin/pyrodactyl-auto-update-panel.sh 2>&1 | tee -a /var/log/pyrodactyl-panel-update.log

  if [ ${PIPESTATUS[0]} -eq 0 ]; then
    success "Panel updated successfully!"
  else
    error "Panel update failed. Check the log for details."
    exit 1
  fi
}

main() {
  print_flame "Welcome to the Pyrodactyl Panel Updater"

  detect_current_installation
  configure_repository
  check_for_update
  perform_update

  print_header
  print_flame "Update Complete!"

  echo ""
  output "Your panel has been updated to the latest version!"
  output "Check the logs at: ${COLOR_ORANGE}/var/log/pyrodactyl-panel-auto-update.log${COLOR_NC}"
  echo ""

  print_brake 70
}

main
