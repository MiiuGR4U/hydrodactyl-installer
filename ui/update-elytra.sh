#!/bin/bash

set -e

# shellcheck source=lib/lib.sh
source /tmp/pyrodactyl-lib.sh

ELYTRA_REPO=""
ELYTRA_REPO_PRIVATE=false
GITHUB_TOKEN=""
USE_AUTO_UPDATER_REPO=false

detect_current_installation() {
  print_header
  print_flame "Detecting Current Installation"

  if [ ! -f "/usr/local/bin/elytra" ]; then
    error "Elytra is not installed at /usr/local/bin/elytra"
    exit 1
  fi

  output "Found Elytra installation at /usr/local/bin/elytra"

  # Try to detect current version
  local current_version="unknown"
  current_version=$(/usr/local/bin/elytra --version 2>/dev/null || echo "unknown")

  output "Current version: ${COLOR_ORANGE}${current_version}${COLOR_NC}"

  # Check if auto-updater config exists
  if [ -f "/etc/systemd/system/pyrodactyl-elytra-auto-update.service" ]; then
    output "Auto-updater configuration detected"
    local use_existing=""
    bool_input use_existing "Use repository from auto-updater configuration?" "y"

    if [ "$use_existing" == "y" ]; then
      USE_AUTO_UPDATER_REPO=true
      # Extract repo from service file
      ELYTRA_REPO=$(grep "ELYTRA_REPO=" /etc/systemd/system/pyrodactyl-elytra-auto-update.service | cut -d'=' -f2 || echo "$DEFAULT_ELYTRA_REPO")
      output "Using repository: ${COLOR_ORANGE}${ELYTRA_REPO}${COLOR_NC}"
    fi
  fi
}

configure_repository() {
  if [ "$USE_AUTO_UPDATER_REPO" == "true" ]; then
    return 0
  fi

  print_header
  print_flame "Repository Configuration"

  output "The default Elytra repository is:"
  output "  ${COLOR_ORANGE}${DEFAULT_ELYTRA_REPO}${COLOR_NC}"
  echo ""

  local use_default=""
  bool_input use_default "Use default repository?" "y"

  if [ "$use_default" == "y" ]; then
    ELYTRA_REPO="$DEFAULT_ELYTRA_REPO"
  else
    required_input ELYTRA_REPO "Enter the GitHub repository (format: owner/repo): " "Repository cannot be empty"

    # Validate repo format
    if [[ ! "$ELYTRA_REPO" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
      error "Invalid repository format. Must be 'owner/repo'"
      exit 1
    fi
  fi

  echo ""
  output "Repository: ${COLOR_ORANGE}${ELYTRA_REPO}${COLOR_NC}"

  # Ask if repository is private
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
}

check_for_update() {
  print_header
  print_flame "Checking for Updates"

  output "Checking latest release from ${ELYTRA_REPO}..."

  local latest_release
  latest_release=$(get_latest_release "$ELYTRA_REPO" "$GITHUB_TOKEN")

  if [ -z "$latest_release" ] || [ "$latest_release" == "null" ]; then
    error "Could not fetch latest version from repository"
    exit 1
  fi

  local current_version="unknown"
  current_version=$(/usr/local/bin/elytra --version 2>/dev/null || echo "unknown")

  echo ""
  echo -e "  ${COLOR_ORANGE}Current version:${COLOR_NC}  ${current_version}"
  echo -e "  ${COLOR_ORANGE}Latest version:${COLOR_NC}   ${latest_release}"
  echo ""

  if [ "$current_version" == "$latest_release" ]; then
    success "Elytra is already up to date!"
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
  print_flame "Updating Elytra"

  # Run the auto-update script directly
  export ELYTRA_REPO
  export GITHUB_TOKEN

  /usr/local/bin/pyrodactyl-auto-update-elytra.sh 2>&1 | tee -a /var/log/pyrodactyl-elytra-update.log

  if [ ${PIPESTATUS[0]} -eq 0 ]; then
    success "Elytra updated successfully!"
  else
    error "Elytra update failed. Check the log for details."
    exit 1
  fi
}

main() {
  print_flame "Welcome to the Elytra Updater"

  detect_current_installation
  configure_repository
  check_for_update
  perform_update

  print_header
  print_flame "Update Complete!"

  echo ""
  output "Elytra has been updated to the latest version!"
  output "Check the logs at: ${COLOR_ORANGE}/var/log/pyrodactyl-elytra-auto-update.log${COLOR_NC}"
  echo ""

  print_brake 70
}

main
