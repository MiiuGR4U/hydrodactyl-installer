#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Pyrodactyl Elytra Installer - Pinnacle Edition                                     #
#                                                                                    #
# Incorporates best practices from:                                                  #
# - Pterodactyl Installer reference                                                  #
# - Original Pyrodactyl scripts                                                      #
# - Modern error handling and validation                                             #
#                                                                                    #
######################################################################################

# Check if lib is loaded, load if not or fail otherwise.
fn_exists() { declare -F "$1" >/dev/null; }
if ! fn_exists lib_loaded; then
  source /tmp/pyrodactyl-lib.sh 2>/dev/null || source <(curl -sSL "${GITHUB_BASE_URL:-"https://raw.githubusercontent.com/Muspelheim-Hosting/pyrodactyl-installer"}/${GITHUB_SOURCE:-"main"}/lib/lib.sh")
  ! fn_exists lib_loaded && echo "* ERROR: Could not load lib script" && exit 1
fi

# ------------------ Variables ----------------- #

# Installation paths
INSTALL_DIR="${INSTALL_DIR:-/etc/elytra}"
PANEL_CONFIG_DIR="${PANEL_CONFIG_DIR:-/etc/pyrodactyl}"
ELYTRA_REPO="${ELYTRA_REPO:-pyrohost/elytra}"

# Panel connection
PANEL_URL="${PANEL_URL:-}"
NODE_TOKEN="${NODE_TOKEN:-}"
NODE_ID="${NODE_ID:-}"

# Network
BEHIND_PROXY="${BEHIND_PROXY:-false}"
FQDN="${FQDN:-}"

# Firewall
CONFIGURE_FIREWALL="${CONFIGURE_FIREWALL:-false}"
GAME_PORT_START="${GAME_PORT_START:-27015}"
GAME_PORT_END="${GAME_PORT_END:-28025}"

# Auto-updater
INSTALL_AUTO_UPDATER="${INSTALL_AUTO_UPDATER:-false}"

# GitHub
ELYTRA_REPO_PRIVATE="${ELYTRA_REPO_PRIVATE:-false}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# Validation
missing=()

for var in PANEL_URL NODE_TOKEN NODE_ID; do
  if [[ -z "${!var}" ]]; then
    missing+=("$var")
  fi
done

if (( ${#missing[@]} > 0 )); then
  print_header
  print_flame "Missing Required Variables"
  for m in "${missing[@]}"; do
    error "${m} is required"
  done
  exit 1
fi

# ---------------- Installation Functions ---------------- #

check_existing() {
  if check_existing_installation "elytra"; then
    echo ""
    if ! bool_input "Continue with installation? This will replace the existing installation" "n"; then
      error "Installation aborted."
      exit 1
    fi

    # Stop existing service
    systemctl stop elytra 2>/dev/null || true
  fi
}

install_docker() {
  print_flame "Installing Docker"

  if cmd_exists docker; then
    output "Docker is already installed, skipping..."
    return 0
  fi

  output "Installing Docker CE..."

  case "$OS" in
    ubuntu|debian)
      # Remove old versions
      apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

      # Install prerequisites
      install_packages "apt-transport-https ca-certificates curl gnupg lsb-release"

      # Add Docker GPG key
      mkdir -p /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

      # Add repository
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

      update_repos true
      install_packages "docker-ce docker-ce-cli containerd.io docker-compose-plugin"
      ;;

    rocky|almalinux)
      install_packages "yum-utils"
      yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      install_packages "docker-ce docker-ce-cli containerd.io docker-compose-plugin"
      ;;
  esac

  # Start Docker
  systemctl start docker
  systemctl enable docker

  # Check virtualization
  check_virt

  success "Docker installed and started"
}

install_elytra() {
  print_flame "Installing Elytra"

  # Create directories
  mkdir -p "$INSTALL_DIR"
  mkdir -p "$PANEL_CONFIG_DIR"
  mkdir -p /var/lib/pterodactyl/volumes
  mkdir -p /var/lib/pterodactyl/archives
  mkdir -p /var/lib/pterodactyl/backups

  # Determine architecture
  local arch
  arch=$(uname -m)
  [[ $arch == x86_64 ]] && arch=amd64 || arch=arm64

  local asset_name="elytra_linux_${arch}"

  # Get latest release
  output "Fetching latest Elytra release..."
  local latest_release
  latest_release=$(get_latest_release "$ELYTRA_REPO" "$GITHUB_TOKEN")

  if [ -z "$latest_release" ] || [ "$latest_release" == "null" ]; then
    error "Could not fetch latest release from $ELYTRA_REPO"
    exit 1
  fi

  info "Latest release: $latest_release"

  # Download binary
  output "Downloading Elytra binary..."
  if ! download_release_asset "$ELYTRA_REPO" "$asset_name" "/usr/local/bin/elytra" "$GITHUB_TOKEN"; then
    error "Failed to download Elytra binary"
    exit 1
  fi

  chmod +x /usr/local/bin/elytra

  success "Elytra installed to /usr/local/bin/elytra"
}

configure_elytra() {
  print_flame "Configuring Elytra"

  # Generate UUID
  local uuid
  uuid=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$(date +%s)-$(hostname)-$$")

  output "Downloading configuration template..."

  # Download config template from GitHub
  if ! curl -fsSL -o "${INSTALL_DIR}/config.yml" "$GITHUB_URL/configs/elytra-config.yml" 2>/dev/null; then
    error "Failed to download Elytra configuration template"
    exit 1
  fi

  # Replace placeholders
  sed -i "s|<UUID>|${uuid}|g" "${INSTALL_DIR}/config.yml"
  sed -i "s|<TOKEN_ID>|${NODE_ID}|g" "${INSTALL_DIR}/config.yml"
  sed -i "s|<TOKEN>|${NODE_TOKEN}|g" "${INSTALL_DIR}/config.yml"
  sed -i "s|<REMOTE>|${PANEL_URL}|g" "${INSTALL_DIR}/config.yml"

  if [ "$BEHIND_PROXY" == "true" ]; then
    sed -i "s|<TRUSTED_PROXIES>|[\"0.0.0.0/0\"]|g" "${INSTALL_DIR}/config.yml"
  else
    sed -i "s|<TRUSTED_PROXIES>|[]|g" "${INSTALL_DIR}/config.yml"
  fi

  # Copy config to pterodactyl directory for compatibility
  cp "${INSTALL_DIR}/config.yml" "${PANEL_CONFIG_DIR}/config.yml" 2>/dev/null || true

  success "Elytra configured"
}

install_rustic() {
  print_flame "Installing Rustic"

  if cmd_exists rustic; then
    output "Rustic is already installed, skipping..."
    return 0
  fi

  output "Installing rustic backup tool..."

  local arch
  arch=$(uname -m)
  [[ $arch == x86_64 ]] && arch=x86_64 || arch=aarch64

  local rustic_url="https://github.com/rustic-rs/rustic/releases/latest/download/rustic-${arch}-unknown-linux-gnu.tar.gz"

  curl -fsSL -o /tmp/rustic.tar.gz "$rustic_url" || {
    error "Failed to download rustic"
    return 1
  }

  tar -xzf /tmp/rustic.tar.gz -C /usr/local/bin rustic
  chmod +x /usr/local/bin/rustic
  rm -f /tmp/rustic.tar.gz

  success "Rustic installed"
}

setup_systemd_service() {
  print_flame "Setting up Systemd Service"

  output "Downloading elytra.service..."

  # Download service file from GitHub
  if ! curl -fsSL -o /etc/systemd/system/elytra.service "$GITHUB_URL/configs/elytra.service" 2>/dev/null; then
    error "Failed to download Elytra service file"
    exit 1
  fi

  systemctl daemon-reload
  systemctl enable elytra

  success "Elytra service created"
}

start_elytra() {
  print_flame "Starting Elytra"

  output "Starting Elytra service..."
  systemctl start elytra

  # Wait for service to start
  sleep 3

  if systemctl is-active --quiet elytra; then
    success "Elytra is running"
  else
    warning "Elytra service may not have started properly"
    warning "Check status with: systemctl status elytra"
  fi
}

verify_connection() {
  print_flame "Verifying Connection"

  output "Waiting for Elytra to initialize..."
  sleep 5

  # Check if service is running
  if ! systemctl is-active --quiet elytra; then
    warning "Elytra service is not running"
    warning "Check logs with: journalctl -u elytra -f"
    return 1
  fi

  output "Checking connection to panel..."

  # Try to reach panel health endpoint
  if curl -s -o /dev/null -w "%{http_code}" "${PANEL_URL}/api/health" | grep -qE "200|204"; then
    success "Successfully connected to panel"
  else
    warning "Could not verify connection to panel"
    warning "The node may still be initializing"
  fi

  # Test Elytra API
  if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/api/system" | grep -qE "200"; then
    success "Elytra API is responding"
  else
    info "Elytra API is not yet responding (this is normal during first start)"
  fi
}

configure_firewall() {
  if [ "$CONFIGURE_FIREWALL" == true ]; then
    print_flame "Configuring Firewall"

    # Ask about game ports
    ask_game_ports GAME_PORT_START GAME_PORT_END

    output "Opening ports for Elytra daemon and game servers..."
    output "  • 22 (SSH)"
    output "  • 8080 (Elytra API)"
    output "  • 2022 (SFTP)"
    output "  • 25565-25665 (Minecraft)"
    output "  • 27015-27150 (Source Engine - CS:GO, TF2, GMod)"
    output "  • 7777-8000 (Unreal Engine - ARK, Satisfactory)"
    output "  • 28015-28025 (Rust)"
    output "  • 2456-2466 (Valheim)"
    output "  • 30120-30130 (FiveM/GTA)"
    output "  • ${GAME_PORT_START}-${GAME_PORT_END} (Additional range)"

    # Configure firewall with all game ports
    configure_firewall_rules true true true "$GAME_PORT_START" "$GAME_PORT_END"
  fi
}

install_auto_updater_if_requested() {
  if [ "$INSTALL_AUTO_UPDATER" == true ]; then
    print_flame "Installing Auto-Updater"

    export ELYTRA_REPO
    export ELYTRA_REPO_PRIVATE
    export GITHUB_TOKEN

    install_auto_updater_elytra

    success "Auto-updater installed"
  fi
}

# ---------------- Main ---------------- #

main() {
  print_header
  print_flame "Starting Elytra Installation"

  check_existing
  install_docker
  install_elytra
  configure_elytra
  install_rustic
  setup_systemd_service
  start_elytra
  configure_firewall
  install_auto_updater_if_requested
  verify_connection

  print_header
  print_flame "Installation Complete!"

  echo ""
  output "🎉 Elytra has been installed successfully!"
  echo ""
  output "Panel URL: ${COLOR_ORANGE}${PANEL_URL}${COLOR_NC}"
  output "Node ID: ${COLOR_ORANGE}${NODE_ID}${COLOR_NC}"
  output "Configuration: ${COLOR_ORANGE}${INSTALL_DIR}/config.yml${COLOR_NC}"
  echo ""

  if [ "$CONFIGURE_FIREWALL" == "true" ]; then
    output "Game Server Ports Configured (TCP & UDP):"
    output "  ${COLOR_ORANGE}25565-25665${COLOR_NC}: Minecraft"
    output "  ${COLOR_ORANGE}27015-27150${COLOR_NC}: Source Engine (CS:GO, TF2, GMod)"
    output "  ${COLOR_ORANGE}7777-8000${COLOR_NC}: ARK, Satisfactory, etc."
    output "  ${COLOR_ORANGE}28015-28025${COLOR_NC}: Rust"
    output "  ${COLOR_ORANGE}2456-2466${COLOR_NC}: Valheim"
    output "  ${COLOR_ORANGE}30120-30130${COLOR_NC}: FiveM/GTA"
    output "  ${COLOR_ORANGE}$GAME_PORT_START-$GAME_PORT_END${COLOR_NC}: General range"
    echo ""
  fi

  output "Service Commands:"
  output "  ${COLOR_ORANGE}systemctl status elytra${COLOR_NC}    - Check service status"
  output "  ${COLOR_ORANGE}systemctl restart elytra${COLOR_NC}   - Restart service"
  output "  ${COLOR_ORANGE}journalctl -u elytra -f${COLOR_NC}   - View logs"
  echo ""

  if [ "$INSTALL_AUTO_UPDATER" == true ]; then
    output "✅ Auto-updater is enabled and will check for updates hourly."
    echo ""
  fi

  print_brake 70
}

main
