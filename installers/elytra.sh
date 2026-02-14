#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Pyrodactyl Elytra Installer                                                        #
#                                                                                    #
# Incorporates best practices from:                                                  #
# - Pyrodactyl Installer reference                                                  #
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

# API Key for automatic configuration (alternative to manual token/ID)
PANEL_API_KEY="${PANEL_API_KEY:-}"

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

# Validation - either API key OR manual credentials required
missing=()

if [[ -z "$PANEL_API_KEY" ]]; then
  # No API key, require manual credentials
  for var in PANEL_URL NODE_TOKEN NODE_ID; do
    if [[ -z "${!var}" ]]; then
      missing+=("$var")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    print_header
    print_flame "Missing Required Variables"
    for m in "${missing[@]}"; do
      error "${m} is required (or provide PANEL_API_KEY for automatic setup)"
    done
    exit 1
  fi
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



install_elytra() {
  print_flame "Installing Elytra"

  # Create directories
  mkdir -p "$INSTALL_DIR"
  mkdir -p "$PANEL_CONFIG_DIR"
  mkdir -p /var/lib/elytra/volumes
  mkdir -p /var/lib/elytra/archives
  mkdir -p /var/lib/elytra/backups

  # Create pyrodactyl user for Elytra (UID/GID 8888) if it doesn't exist
  output "Creating pyrodactyl system user..."
  if ! id -u pyrodactyl >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin --uid 8888 --gid 8888 pyrodactyl 2>/dev/null || \
    useradd --system --no-create-home --shell /sbin/nologin --uid 8888 pyrodactyl 2>/dev/null || \
    useradd --system --no-create-home --shell /bin/false --uid 8888 pyrodactyl
  fi

  # Ensure pyrodactyl group exists
  if ! getent group pyrodactyl >/dev/null 2>&1; then
    groupadd --gid 8888 pyrodactyl 2>/dev/null || true
  fi

  # Set proper ownership on Elytra data directories
  output "Setting permissions on Elytra data directories..."
  chown -R 8888:8888 /var/lib/elytra/volumes 2>/dev/null || true
  chown -R 8888:8888 /var/lib/elytra/archives 2>/dev/null || true
  chown -R 8888:8888 /var/lib/elytra/backups 2>/dev/null || true
  chown -R 8888:8888 "$INSTALL_DIR" 2>/dev/null || true

  # Set full permissions so containers can read/write/execute
  # TODO: Can we figure out if 777 is required or not? Launching a server did not work without this...
  chmod -R 777 /var/lib/elytra/volumes 2>/dev/null || true
  chmod -R 777 /var/lib/elytra/archives 2>/dev/null || true
  chmod -R 777 /var/lib/elytra/backups 2>/dev/null || true
  chmod -R 777 "$INSTALL_DIR" 2>/dev/null || true

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

# Auto-configure Elytra using API key
auto_configure_elytra() {
  print_flame "Auto-Configuring Elytra via API"

  local api_key="$1"
  local panel_url="$2"
  local node_name="${3:-Elytra-Node-$(hostname -s)}"

  output "Starting automatic Elytra configuration..."
  output "Node name: ${COLOR_ORANGE}${node_name}${COLOR_NC}"

  # Step 1: Detect country and get/create location
  output ""
  output "Step 1: Setting up location..."
  local country_code
  country_code=$(get_server_country_code)
  info "Detected country code: ${country_code}"

  local location_id
  if ! location_id=$(get_or_create_location "$api_key" "$panel_url" "$country_code"); then
    error "Failed to set up location"
    return 1
  fi

  # Step 2: Create node
  output ""
  output "Step 2: Creating node..."
  local memory_mb
  local disk_mb
  memory_mb=$(get_system_memory)
  disk_mb=$(df -m / | awk 'NR==2 {print $2}')

  # Extract FQDN from panel_url for node configuration
  local panel_fqdn
  panel_fqdn=$(echo "$panel_url" | sed 's|https://||' | sed 's|http://||')

  if ! NODE_ID=$(create_node_via_api "$api_key" "$panel_url" "$location_id" "$node_name" "$memory_mb" "$disk_mb" "false" "$panel_fqdn"); then
    error "Failed to create node"
    return 1
  fi

  success "Node created successfully"
  info "Node ID: ${NODE_ID}"

  # Step 5: Configure Elytra
  output ""
  output "Step 5: Configuring Elytra..."
  configure_elytra

  success "Elytra auto-configuration complete!"
  return 0
}

configure_elytra() {
  print_flame "Configuring Elytra"

  # Create Elytra config directory
  mkdir -p "${INSTALL_DIR}"

  output "Configuring Elytra using 'elytra configure' command..."

  # Configure Elytra using the official configure command
  # Note: Uses Panel API key, not node daemon token
  cd "${INSTALL_DIR}" && elytra configure --panel-url "${PANEL_URL}" --token "${api_key}" --node "${NODE_ID}"

  if [ $? -ne 0 ]; then
    error "Failed to configure Elytra"
    return 1
  fi

  # Configure SSL for Elytra using Let's Encrypt certificates
  output "Configuring SSL for Elytra..."
  # Extract FQDN from PANEL_URL (remove https:// prefix)
  local panel_fqdn
  panel_fqdn=$(echo "${PANEL_URL}" | sed 's|https://||' | sed 's|http://||')
  if [ -f "/etc/letsencrypt/live/${panel_fqdn}/fullchain.pem" ] && [ -f "/etc/letsencrypt/live/${panel_fqdn}/privkey.pem" ]; then
    # Enable SSL and set certificate paths
    sed -i 's/enabled: false/enabled: true/' "${INSTALL_DIR}/config.yml"
    sed -i "s|cert: .*|cert: /etc/letsencrypt/live/${panel_fqdn}/fullchain.pem|" "${INSTALL_DIR}/config.yml"
    sed -i "s|key: .*|key: /etc/letsencrypt/live/${panel_fqdn}/privkey.pem|" "${INSTALL_DIR}/config.yml"
    success "SSL configured for Elytra using Let's Encrypt certificates"
  else
    warning "Let's Encrypt certificates not found, SSL may need manual configuration"
  fi

  # Step 4: Create allocations (after Elytra configure)
  output ""
  output "Step 4: Creating allocations..."
  create_node_allocations "$api_key" "$panel_url" "$NODE_ID"

  if [ $? -ne 0 ]; then
    error "Failed to configure Elytra"
    exit 1
  fi

  success "Elytra configured"
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
  systemctl restart elytra

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

  # Check if we should use API-based auto-configuration
  if [ -n "$PANEL_API_KEY" ] && [ -n "$PANEL_URL" ]; then
    if auto_configure_elytra "$PANEL_API_KEY" "$PANEL_URL" "${NODE_NAME:-Elytra-Node-$(hostname -s)}"; then
      success "Elytra auto-configured via API"
    else
      error "Auto-configuration failed. Please provide manual credentials (NODE_ID, NODE_TOKEN) and try again."
      exit 1
    fi
  else
    configure_elytra
  fi

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
  output "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  output "  Connection Details"
  output "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  output "Panel URL: ${COLOR_ORANGE}${PANEL_URL}${COLOR_NC}"
  output "Node ID: ${COLOR_ORANGE}${NODE_ID}${COLOR_NC}"
  if [ -n "$PANEL_API_KEY" ]; then
    output "Setup Method: ${COLOR_ORANGE}Automatic (via API)${COLOR_NC}"
  else
    output "Setup Method: ${COLOR_ORANGE}Manual${COLOR_NC}"
  fi
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
