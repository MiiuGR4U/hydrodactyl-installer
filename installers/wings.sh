#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Hydrodactyl Wings Installer                                                        #
#                                                                                    #
# Incorporates best practices from:                                                  #
# - Hydrodactyl Installer reference                                                  #
# - Original Hydrodactyl scripts                                                      #
# - Modern error handling and validation                                             #
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
    source <(curl -sSL "${GITHUB_BASE_URL:-"https://raw.githubusercontent.com/blueprintframework/hydrodactyl-installer"}/${GITHUB_SOURCE:-"main"}/lib/lib.sh")
  fi
  ! fn_exists lib_loaded && echo "* ERROR: Could not load lib script" && exit 1
fi

# ------------------ Command Line Arguments ----------------- #

# Parse command line arguments
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --fqdn|-f)
        FQDN="$2"
        shift 2
        ;;
      --panel-url|-u)
        PANEL_URL="$2"
        shift 2
        ;;
      --panel-fqdn)
        PANEL_FQDN="$2"
        FQDN="$2"
        shift 2
        ;;
      --api-key|-k)
        PANEL_API_KEY="$2"
        shift 2
        ;;
      --node-name|-n)
        NODE_NAME="$2"
        shift 2
        ;;
      --node-token|-t)
        NODE_TOKEN="$2"
        shift 2
        ;;
      --node-id|-i)
        NODE_ID="$2"
        shift 2
        ;;
      --memory|-m)
        NODE_MEMORY="$2"
        shift 2
        ;;
      --disk|-d)
        NODE_DISK="$2"
        shift 2
        ;;
      --port-start)
        GAME_PORT_START_PARAM="$2"
        GAME_PORT_START="$2"
        shift 2
        ;;
      --port-end)
        GAME_PORT_END_PARAM="$2"
        GAME_PORT_END="$2"
        shift 2
        ;;
      --configure-firewall)
        CONFIGURE_FIREWALL="true"
        shift
        ;;
      --no-firewall)
        CONFIGURE_FIREWALL="false"
        shift
        ;;
      --install-auto-updater)
        INSTALL_AUTO_UPDATER="true"
        shift
        ;;
      --no-auto-updater)
        INSTALL_AUTO_UPDATER="false"
        shift
        ;;
      --behind-proxy)
        BEHIND_PROXY="true"
        shift
        ;;
      --github-token|-g)
        GITHUB_TOKEN="$2"
        shift 2
        ;;
      --Wings-repo)
        Wings_REPO="$2"
        shift 2
        ;;
      --skip-wings-setup)
        SKIP_WINGS_SETUP="true"
        shift
        ;;
      --assume-ssl)
        ASSUME_SSL="true"
        shift
        ;;
      --configure-letsencrypt)
        CONFIGURE_LETSENCRYPT="true"
        shift
        ;;
      --ssl-email)
        SSL_EMAIL="$2"
        shift 2
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done
}

show_help() {
  cat << EOF
Wings Installer - Command Line Options

Usage: Wings.sh [OPTIONS]

Connection (provide these or you'll be prompted):
  --fqdn, -f <fqdn>              This node's FQDN (e.g., node.example.com)
  --panel-url, -u <url>          Panel URL to connect to (e.g., https://panel.example.com)
  --api-key, -k <key>            Panel API key for automatic node setup
  --node-name, -n <name>         Node name (default: hostname)
  --node-token, -t <token>       Node token for manual setup
  --node-id, -i <id>             Node ID for manual setup

Resources (optional, auto-detected if not provided):
  --memory, -m <mb>              Memory limit in MB
  --disk, -d <mb>                Disk limit in MB
  --port-start <port>            Game port range start (default: 27015)
  --port-end <port>              Game port range end (default: 28025)

Options:
  --configure-firewall           Enable firewall configuration
  --no-firewall                  Disable firewall configuration
  --install-auto-updater         Install auto-updater
  --no-auto-updater              Don't install auto-updater
  --behind-proxy                 Node is behind a proxy
  --assume-ssl                   Assume SSL is already configured
  --configure-letsencrypt        Obtain SSL certificate via Let's Encrypt
  --ssl-email <email>            Email for Let's Encrypt registration
  --github-token, -g <token>     GitHub token for private repos
  --Wings-repo <repo>           Wings repo (default: pterodactyl/wings)
  --skip-wings-setup             Skip Wings detection/setup
  --help, -h                     Show this help message

Examples:
  # Automatic setup with API key (no prompts)
  Wings.sh --fqdn node.example.com --panel-url https://panel.example.com --api-key hydro_xxx --configure-firewall

  # With all options specified (completely unattended)
  Wings.sh --fqdn node.example.com --panel-url https://panel.example.com --api-key hydro_xxx \
    --node-name "My Node" --memory 8192 --disk 100000 --configure-firewall --install-auto-updater

  # Manual setup (will prompt for missing values)
  Wings.sh

EOF
}

# Parse arguments
parse_arguments "$@"

# ------------------ Variables ----------------- #

# Installation paths
# Use Wings_INSTALL_DIR to avoid collision with lib.sh's INSTALL_DIR (which is /var/www/Hydrodactyl for the panel)
Wings_INSTALL_DIR="/etc/Wings"
PANEL_CONFIG_DIR="${PANEL_CONFIG_DIR:-/etc/Hydrodactyl}"
Wings_REPO="${Wings_REPO:-pterodactyl/wings}"

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
Wings_REPO_PRIVATE="${Wings_REPO_PRIVATE:-false}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
Wings_RELEASE_VERSION="${Wings_RELEASE_VERSION:-latest}"

# Node configuration
NODE_NAME="${NODE_NAME:-}"
NODE_MEMORY="${NODE_MEMORY:-}"
NODE_DISK="${NODE_DISK:-}"
PANEL_FQDN="${PANEL_FQDN:-}"

# Mode flags
export SKIP_WINGS_SETUP="${SKIP_WINGS_SETUP:-false}"
export ASSUME_SSL="${ASSUME_SSL:-false}"
export CONFIGURE_LETSENCRYPT="${CONFIGURE_LETSENCRYPT:-false}"
export SSL_EMAIL="${SSL_EMAIL:-}"
export SSL_CERT_PATH="${SSL_CERT_PATH:-}"
export SSL_KEY_PATH="${SSL_KEY_PATH:-}"

# Validation - credentials are optional, but if provided must be complete
# User can skip configuration and configure later
missing=()
partial_creds=false

if [[ -n "$PANEL_API_KEY" ]]; then
  # API key provided - will use automatic setup
  :
elif [[ -n "$PANEL_URL" || -n "$NODE_TOKEN" || -n "$NODE_ID" ]]; then
  # Partial manual credentials provided - require all
  for var in PANEL_URL NODE_TOKEN NODE_ID; do
    if [[ -z "${!var}" ]]; then
      missing+=("$var")
    fi
  done
  if (( ${#missing[@]} > 0 )); then
    partial_creds=true
  fi
fi

# Only error if partial credentials were provided
if [[ "$partial_creds" == true ]]; then
  print_header
  print_flame "Missing Required Variables"
  for m in "${missing[@]}"; do
    error "${m} is required (or provide PANEL_API_KEY for automatic setup)"
  done
  exit 1
fi

# ---------------- Installation Functions ---------------- #

check_existing() {
  if check_existing_installation "Wings"; then
    echo ""
    if ! bool_input "Continue with installation? This will replace the existing installation" "n"; then
      error "Installation aborted."
      exit 1
    fi

    # Stop existing service
    systemctl stop Wings 2>/dev/null || true
  fi
}

install_Wings() {
  print_flame "Installing Wings Daemon"

  # Install Docker using shared function from lib.sh
  install_docker

  # Create directories with proper permissions
  output "Creating Wings directories..."
  mkdir -p "$Wings_INSTALL_DIR" || { error "Failed to create $Wings_INSTALL_DIR"; return 1; }
  mkdir -p "$PANEL_CONFIG_DIR" || { error "Failed to create $PANEL_CONFIG_DIR"; return 1; }
  mkdir -p /var/lib/Wings/volumes || { error "Failed to create /var/lib/Wings/volumes"; return 1; }
  mkdir -p /var/lib/Wings/archives || { error "Failed to create /var/lib/Wings/archives"; return 1; }
  mkdir -p /var/lib/Wings/backups || { error "Failed to create /var/lib/Wings/backups"; return 1; }

  # Create Hydrodactyl group first (required for user creation)
  output "Creating Hydrodactyl system group..."
  if ! getent group Hydrodactyl >/dev/null 2>&1; then
    groupadd --gid 8888 Hydrodactyl 2>/dev/null || true
  fi

  # Create Hydrodactyl user for Wings (UID/GID 8888) if it doesn't exist
  output "Creating Hydrodactyl system user..."
  if ! id -u Hydrodactyl >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin --uid 8888 --gid 8888 Hydrodactyl 2>/dev/null || \
    useradd --system --no-create-home --shell /sbin/nologin --uid 8888 Hydrodactyl 2>/dev/null || \
    useradd --system --no-create-home --shell /bin/false --uid 8888 Hydrodactyl
  fi

  # Add Hydrodactyl user to docker group for container management
  if getent group docker >/dev/null 2>&1; then
    output "Adding Hydrodactyl user to docker group..."
    usermod -aG docker Hydrodactyl 2>/dev/null || true
  fi

  # Determine architecture
  local arch
  arch=$(uname -m)
  [[ $arch == x86_64 ]] && arch=amd64 || arch=arm64

  local asset_name="Wings_linux_${arch}"

  # Determine which release to fetch
  local target_release="$Wings_RELEASE_VERSION"
  if [ "$target_release" == "latest" ]; then
    output "Fetching latest Wings release..."
    target_release=$(get_latest_release "$Wings_REPO" "$GITHUB_TOKEN")
  else
    output "Fetching Wings release ${Wings_RELEASE_VERSION}..."
  fi

  if [ -z "$target_release" ] || [ "$target_release" == "null" ]; then
    error "Could not fetch release from $Wings_REPO"
    if [ "$Wings_RELEASE_VERSION" != "latest" ]; then
      error "Release ${Wings_RELEASE_VERSION} may not exist."
    fi
    exit 1
  fi

  info "Installing release: $target_release"

  # Download binary
  output "Downloading Wings binary..."
  if ! download_release_asset "$Wings_REPO" "$asset_name" "/usr/local/bin/Wings" "$GITHUB_TOKEN" "$target_release"; then
    error "Failed to download Wings binary"
    exit 1
  fi

  chmod +x /usr/local/bin/Wings

  # Save version from GitHub release tag for auto-updater tracking
  mkdir -p /etc/Hydrodactyl
  echo "$target_release" > /etc/Hydrodactyl/Wings-version
  chmod 644 /etc/Hydrodactyl/Wings-version

  # Verify Wings binary works
  if /usr/local/bin/Wings --version >/dev/null 2>&1; then
    info "Wings binary verified: $(/usr/local/bin/Wings --version 2>/dev/null || echo 'unknown')"
  fi

  success "Wings installed to /usr/local/bin/Wings"
}

# Ask user if they want to skip auto-configuration
ask_skip_auto_config() {
  local skip_auto=""

  echo ""
  output "Auto-configuration will:"
  output "  â€¢ Create a new location (or use existing) in your panel"
  output "  â€¢ Create a new node in your panel"
  output "  â€¢ Automatically configure Wings with the new node"
  echo ""

  bool_input skip_auto "Would you like to skip auto-configuration and configure manually?" "n"

  if [ "$skip_auto" == "y" ]; then
    return 0  # Yes, skip
  else
    return 1  # No, don't skip
  fi
}

# Auto-configure Wings using API key
auto_configure_Wings() {
  print_flame "Auto-Configuring Wings via API"

  local api_key="$1"
  local panel_url="$2"
  local node_name="${3:-}"
  [ -z "$node_name" ] && node_name="Wings-Node-$(hostname -s)"

  output "Starting automatic Wings configuration..."
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

  # Determine node FQDN - must be set explicitly or detectable via hostname
  local node_fqdn
  if [ -n "$FQDN" ]; then
    node_fqdn="$FQDN"
    info "Using configured node FQDN: ${node_fqdn}"
  else
    node_fqdn=$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo "")
    if [ -z "$node_fqdn" ] || [ "$node_fqdn" == "localhost" ]; then
      error "Could not determine node FQDN"
      error "Set FQDN via --fqdn flag or FQDN environment variable"
      error "Example: Wings.sh --fqdn node.example.com"
      return 1
    else
      info "Detected node FQDN from hostname: ${node_fqdn}"
    fi
  fi

  if ! NODE_ID=$(create_node_via_api "$api_key" "$panel_url" "$location_id" "$node_name" "$memory_mb" "$disk_mb" "false" "$node_fqdn"); then
    error "Failed to create node"
    return 1
  fi

  success "Node created successfully"
  info "Node ID: ${NODE_ID}"

  # Step 3: Configure Wings
  output ""
  output "Step 3: Configuring Wings..."
  configure_Wings "${panel_url}" "${api_key}" "${NODE_ID}"

  success "Wings auto-configuration complete!"
  return 0
}

# ---------------- SSL Certificate (Let's Encrypt) ----------------- #

# Install Let's Encrypt certificate for Wings (standalone mode)
# Unlike the panel which uses certbot --nginx, Wings doesn't use nginx,
# so we use certbot certonly --standalone to obtain the certificate.
install_letsencrypt_Wings() {
  local fqdn="$1"
  local email="$2"

  output "Installing Certbot and obtaining SSL certificate..."

  case "$OS" in
    ubuntu|debian)
      install_packages certbot
      ;;
    rocky|almalinux|fedora|rhel|centos)
      install_packages certbot
      ;;
  esac

  # Use standalone mode since Wings doesn't use nginx as a reverse proxy
  # Standalone mode spins up its own temporary web server on port 80
  # If something is already using port 80, we need to stop it temporarily
  local stopped_service=""
  if ss -tlnp 2>/dev/null | grep -q ':80 '; then
    output "Port 80 is in use - attempting to free it for certbot verification..."

    # Try to identify and stop the service using port 80
    local port_80_pid
    port_80_pid=$(ss -tlnp 2>/dev/null | grep ':80 ' | head -1 | grep -oP 'pid=\K[0-9]+' || true)
    if [ -n "$port_80_pid" ]; then
      local port_80_service
      port_80_service=$(systemctl status "$port_80_pid" 2>/dev/null | grep -oP '.*\.service' | head -1 || true)
      if [ -n "$port_80_service" ]; then
        output "Temporarily stopping ${port_80_service} for certbot verification..."
        if systemctl stop "$port_80_service" 2>/dev/null; then
          stopped_service="$port_80_service"
          sleep 2
        fi
      fi
    fi

    if [ -z "$stopped_service" ]; then
      # Fallback: try common services that typically use port 80
      for svc in nginx apache2 httpd caddy; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
          output "Temporarily stopping ${svc} for certbot verification..."
          if systemctl stop "$svc" 2>/dev/null; then
            stopped_service="$svc"
            sleep 2
            break
          fi
        fi
      done
    fi
  fi

  # Build the certbot command
  local certbot_args="certonly --standalone -d $fqdn --non-interactive --agree-tos"
  if [ -n "$email" ]; then
    certbot_args="$certbot_args --email $email"
  else
    certbot_args="$certbot_args --register-unsafely-without-email"
  fi

  # Obtain the certificate
  if ! certbot $certbot_args; then
    warning "Certbot failed to obtain certificate for ${fqdn}"
    # Restart any service we stopped
    if [ -n "$stopped_service" ]; then
      output "Restarting ${stopped_service}..."
      systemctl start "$stopped_service" 2>/dev/null || true
    fi
    return 1
  fi

  # Restart any service we stopped on port 80
  if [ -n "$stopped_service" ]; then
    output "Restarting ${stopped_service}..."
    systemctl start "$stopped_service" 2>/dev/null || true
  fi

  success "SSL certificate obtained for ${fqdn}"

  # Setup automatic renewal using the shared function from lib.sh
  # This creates renewal hooks that restart nginx and Wings after cert renewal
  setup_certbot_renewal
}

configure_Wings() {
  local panel_url="${1:-$PANEL_URL}"
  local api_key="${2:-$PANEL_API_KEY}"
  local node_id="${3:-$NODE_ID}"

  # Validate required parameters
  if [ -z "$panel_url" ]; then
    error "Panel URL is required. Provide it as first argument or set PANEL_URL environment variable."
    error "Usage: configure_Wings <panel_url> <api_key> <node_id>"
    error "Example: configure_Wings 'https://panel.example.com' 'hydro_xxxxx' '1'"
    return 1
  fi

  if [ -z "$api_key" ]; then
    error "API key is required. Provide it as second argument or set PANEL_API_KEY environment variable."
    error "Usage: configure_Wings <panel_url> <api_key> <node_id>"
    return 1
  fi

  if [ -z "$node_id" ]; then
    error "Node ID is required. Provide it as third argument or set NODE_ID environment variable."
    error "Usage: configure_Wings <panel_url> <api_key> <node_id>"
    return 1
  fi

  print_flame "Configuring Wings"

  # Create Wings config directory with verification
  output "Creating Wings config directory at ${Wings_INSTALL_DIR}..."
  mkdir -p "${Wings_INSTALL_DIR}"
  if [ ! -d "${Wings_INSTALL_DIR}" ]; then
    error "Failed to create Wings config directory at ${Wings_INSTALL_DIR}"
    return 1
  fi

  # Determine FQDN for SSL certificate paths
  # Must be set explicitly - the panel FQDN is NOT the same as the node FQDN
  local node_fqdn
  if [ -n "$FQDN" ]; then
    node_fqdn="$FQDN"
  else
    if [ "$CONFIGURE_LETSENCRYPT" == true ]; then
      warning "Let's Encrypt requested but node FQDN not set"
      warning "Set FQDN via --fqdn flag or FQDN environment variable"
    fi
    node_fqdn=""
  fi

  output "Configuring Wings using 'Wings configure' command..."
  output "Panel URL: ${panel_url}"
  output "Node ID: ${node_id}"

  # Configure Wings using the official configure command
  # Note: Uses Panel API key, not node daemon token
  # Run in a subshell to avoid changing the working directory of the caller
  if ! (cd "${Wings_INSTALL_DIR}" && Wings configure --panel-url "${panel_url}" --token "${api_key}" --node "${node_id}"); then
    error "Failed to configure Wings"
    error ""
    error "To manually configure later, run:"
    error "  cd ${Wings_INSTALL_DIR} && sudo Wings configure \\"
    error "    --panel-url '${panel_url}' \\"
    error "    --token '<your-api-key>' \\"
    error "    --node '${node_id}'"
    return 1
  fi

  output "Wings configured successfully"

  # Disable permission checking to prevent Wings from resetting permissions
  output "Disabling permission checks in Wings config..."
  sed -i 's/check_permissions_on_boot: true/check_permissions_on_boot: false/' "${Wings_INSTALL_DIR}/config.yml" 2>/dev/null || true

  # Update container limits for better game server compatibility
  output "Updating container limits in Wings config..."
  sed -i 's/container_pid_limit: 512/container_pid_limit: 2048/' "${Wings_INSTALL_DIR}/config.yml" 2>/dev/null || true
  sed -i 's/memory: 1024/memory: 2048/' "${Wings_INSTALL_DIR}/config.yml" 2>/dev/null || true
  sed -i 's/cpu: 100/cpu: 200/' "${Wings_INSTALL_DIR}/config.yml" 2>/dev/null || true

  # Configure SSL for Wings
  # This mirrors the panel.sh/both.sh SSL approach:
  #   1. CONFIGURE_LETSENCRYPT=true â†’ obtain cert via certbot (standalone mode)
  #   2. SSL_CERT_PATH/SSL_KEY_PATH â†’ use custom certificate
  #   3. Pre-existing Let's Encrypt certs â†’ use them
  #   4. Otherwise â†’ warn and tell user how to set up later
  output "Configuring SSL for Wings..."

  # Step 1: If Let's Encrypt is requested, obtain the certificate
  if [ "$CONFIGURE_LETSENCRYPT" == true ]; then
    if [ -n "$node_fqdn" ]; then
      output "Obtaining Let's Encrypt certificate for ${node_fqdn}..."
      install_letsencrypt_Wings "$node_fqdn" "${SSL_EMAIL:-}"
    else
      warning "Cannot obtain Let's Encrypt certificate - node FQDN not configured"
      warning "Set FQDN via --fqdn flag or FQDN environment variable"
    fi
  fi

  # Step 2: Determine certificate paths and configure Wings
  local ssl_cert_path=""
  local ssl_key_path=""

  if [ -n "$SSL_CERT_PATH" ] && [ -n "$SSL_KEY_PATH" ] && [ -f "$SSL_CERT_PATH" ] && [ -f "$SSL_KEY_PATH" ]; then
    # Custom certificate paths provided
    ssl_cert_path="$SSL_CERT_PATH"
    ssl_key_path="$SSL_KEY_PATH"
    output "Using custom SSL certificate: ${ssl_cert_path}"
  elif [ -n "$node_fqdn" ] && [ -f "/etc/letsencrypt/live/${node_fqdn}/fullchain.pem" ] && [ -f "/etc/letsencrypt/live/${node_fqdn}/privkey.pem" ]; then
    # Let's Encrypt certificates found (either just obtained or pre-existing)
    ssl_cert_path="/etc/letsencrypt/live/${node_fqdn}/fullchain.pem"
    ssl_key_path="/etc/letsencrypt/live/${node_fqdn}/privkey.pem"
    output "Found Let's Encrypt certificates at /etc/letsencrypt/live/${node_fqdn}/"
  fi

  if [ -n "$ssl_cert_path" ] && [ -n "$ssl_key_path" ]; then
    # Enable SSL and set certificate paths in Wings config
    sed -i 's/enabled: false/enabled: true/' "${Wings_INSTALL_DIR}/config.yml"
    sed -i "s|certificate: .*|certificate: ${ssl_cert_path}|" "${Wings_INSTALL_DIR}/config.yml"
    sed -i "s|key: .*|key: ${ssl_key_path}|" "${Wings_INSTALL_DIR}/config.yml"
    success "SSL configured for Wings"
  else
    if [ -z "$node_fqdn" ]; then
      warning "Skipping SSL - node FQDN not configured"
    else
      warning "SSL certificates not found for ${node_fqdn}"
    fi
    output ""
    output "To set up SSL later, you can:"
    output "  1. Obtain a Let's Encrypt certificate:"
    output "     ${COLOR_ORANGE}certbot certonly --standalone -d ${node_fqdn:-'<fqdn>'}${COLOR_NC}"
    output "  2. Or provide custom certificate paths in ${Wings_INSTALL_DIR}/config.yml"
  fi

  # Also set ASSUME_SSL if SSL is configured (for URL construction elsewhere)
  if [ -n "$ssl_cert_path" ] && [ -n "$ssl_key_path" ]; then
    ASSUME_SSL="true"
  fi

  # Create allocations (after Wings configure)
  output ""
  output "Creating allocations..."
  create_node_allocations "$api_key" "$panel_url" "$node_id" "${GAME_PORT_START:-25565}" "${GAME_PORT_END:-25665}" || true

  success "Wings configured"
}

setup_systemd_service() {
  print_flame "Setting up Systemd Service"

  output "Setting up Wings.service..."

  # Get service file (downloads or copies from local)
  if ! get_config "Wings.service" "/etc/systemd/system/Wings.service"; then
    exit 1
  fi

  systemctl daemon-reload
  systemctl enable Wings

  success "Wings service created"
}

start_Wings() {
  print_flame "Starting Wings"

  output "Starting Wings service..."
  systemctl restart Wings

  # Wait for service to start
  sleep 3

  if systemctl is-active --quiet Wings; then
    success "Wings is running"
  else
    warning "Wings service may not have started properly"
    warning "Check status with: systemctl status Wings"
  fi
}

verify_connection() {
  print_flame "Verifying Connection"

  output "Waiting for Wings to initialize..."
  sleep 5

  # Check if service is running
  if ! systemctl is-active --quiet Wings; then
    warning "Wings service is not running"
    warning "Check logs with: journalctl -u Wings -f"
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

  # Test Wings API
  if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/api/system" | grep -qE "200"; then
    success "Wings API is responding"
  else
    info "Wings API is not yet responding (this is normal during first start)"
  fi
}

configure_firewall() {
  if [ "$CONFIGURE_FIREWALL" == true ]; then
    print_flame "Configuring Firewall"

    # Ask about game ports if not already set via parameters
    if [ -z "${GAME_PORT_START_PARAM:-}" ] || [ -z "${GAME_PORT_END_PARAM:-}" ]; then
      ask_game_ports GAME_PORT_START GAME_PORT_END
    fi

    output "Opening ports for Wings daemon and game servers..."
    output "  â€¢ 22 (SSH)"
    output "  â€¢ 80 (HTTP - needed for certbot renewal)"
    if [ "$CONFIGURE_LETSENCRYPT" == true ] || [ "$ASSUME_SSL" == true ] || [ -n "$SSL_CERT_PATH" ]; then
      output "  â€¢ 443 (HTTPS/SSL)"
    fi
    output "  â€¢ 8080 (Wings API)"
    output "  â€¢ 2022 (SFTP)"
    output "  â€¢ 25565-25665 (Minecraft)"
    output "  â€¢ 27015-27150 (Source Engine - CS:GO, TF2, GMod)"
    output "  â€¢ 7777-8000 (Unreal Engine - ARK, Satisfactory)"
    output "  â€¢ 28015-28025 (Rust)"
    output "  â€¢ 2456-2466 (Valheim)"
    output "  â€¢ 30120-30130 (FiveM/GTA)"
    output "  â€¢ ${GAME_PORT_START}-${GAME_PORT_END} (Additional range)"

    # Configure firewall with all game ports
    # Pass SSL flag so port 443 is opened when SSL is configured
    configure_firewall_rules true true true "$GAME_PORT_START" "$GAME_PORT_END"
  fi
}

install_auto_updater_if_requested() {
  if [ "$INSTALL_AUTO_UPDATER" == true ]; then
    print_flame "Installing Auto-Updater"

    export Wings_REPO
    export Wings_REPO_PRIVATE
    export GITHUB_TOKEN

    install_auto_updater_Wings

    success "Auto-updater installed"
  fi
}

# ---------------- Main ---------------- #

main() {
  print_header
  print_flame "Starting Wings Installation"

  check_existing
  install_Wings

  # ---- Configuration phase ----
  # Three paths: auto-configure with API key, manual credentials, or skip entirely
  if [ -n "$PANEL_API_KEY" ] && [ -n "$PANEL_URL" ]; then
    # API credentials provided - ask if user wants to skip auto-config
    if ask_skip_auto_config; then
      output ""
      output "Skipping auto-configuration."
      output ""
      output "You chose to manually configure Wings. To configure later, run:"
      output "  ${COLOR_ORANGE}cd ${Wings_INSTALL_DIR} && sudo Wings configure \\"
      output "    --panel-url 'https://your-panel.com' \\"
      output "    --token 'your-api-key' \\"
      output "    --node 'your-node-id'${COLOR_NC}"
      output ""
      output "Press Enter to continue with installation (Wings will not be fully configured)..."
      read -r
    else
      # User wants auto-configuration
      local _node_name="${NODE_NAME:-}"
      [ -z "$_node_name" ] && _node_name="Wings-Node-$(hostname -s)"
      if auto_configure_Wings "$PANEL_API_KEY" "$PANEL_URL" "$_node_name"; then
        success "Wings auto-configured via API"
      else
        error "Auto-configuration failed."
        error ""
        error "You can manually configure Wings later by running:"
        error "  cd ${Wings_INSTALL_DIR} && sudo Wings configure \\"
        error "    --panel-url '${PANEL_URL}' \\"
        error "    --token '<your-api-key>' \\"
        error "    --node '<node-id>'"
        error ""
        error "Or use the installer function:"
        error "  configure_Wings '${PANEL_URL}' '<api-key>' '<node-id>'"
        exit 1
      fi
    fi
  elif [ -n "$PANEL_URL" ] && [ -n "$PANEL_API_KEY" ] && [ -n "$NODE_ID" ]; then
    # Manual configuration credentials provided via environment/args
    output "Manual configuration credentials detected."
    configure_Wings "${PANEL_URL}" "${PANEL_API_KEY}" "${NODE_ID}"
  else
    # No credentials - ask if user wants to configure now or skip
    output ""
    output "No API credentials provided."
    output ""
    output "To configure Wings, you need:"
    output "  1. Panel URL (e.g., https://panel.example.com)"
    output "  2. Panel API Key"
    output "  3. Node ID (create a node in your panel first)"
    output "  4. This node's FQDN (for SSL certificate setup)"
    output ""

    local do_manual=""
    bool_input do_manual "Would you like to enter configuration details now?" "y"

    if [ "$do_manual" == "y" ]; then
      echo ""
      read -rp "* Enter Panel URL: " PANEL_URL
      read -rp "* Enter Panel API Key: " PANEL_API_KEY
      read -rp "* Enter Node ID: " NODE_ID
      echo ""

      # Ask for node FQDN if not already set
      if [ -z "$FQDN" ]; then
        output ""
        output "Enter the FQDN for this node (e.g., node.example.com)"
        output "This is used to locate SSL certificates for secure connections."
        read -rp "* Node FQDN: " FQDN
      fi
      echo ""

      configure_Wings "${PANEL_URL}" "${PANEL_API_KEY}" "${NODE_ID}"
    else
      output ""
      output "Skipping configuration. Wings is installed but not configured."
      output ""
      output "To configure later, run:"
      output "  ${COLOR_ORANGE}cd ${Wings_INSTALL_DIR} && sudo Wings configure \\"
      output "    --panel-url 'https://your-panel.com' \\"
      output "    --token 'your-api-key' \\"
      output "    --node 'your-node-id'${COLOR_NC}"
    fi
  fi

  # ---- Post-configuration phase ----
  # Only run config-dependent steps if Wings is configured
  if [ -f "${Wings_INSTALL_DIR}/config.yml" ]; then
    install_rustic
    setup_systemd_service
    start_Wings

    # Run auto-fix to ensure proper permissions, ACL defaults, and service restart
    # This handles: ownership, chmod, config permissions, ACL inheritance,
    # check_permissions_on_boot disable, and Wings service restart+verify
    # (matches both.sh behavior)
    output "Running Wings permission fix..."
    auto_fix_Wings_issues || true

    configure_firewall
    install_auto_updater_if_requested
    verify_connection
  fi

  # ---- Completion summary ----
  print_header
  print_flame "Installation Complete!"

  echo ""
  output "Wings has been installed successfully!"
  echo ""

  if [ -f "${Wings_INSTALL_DIR}/config.yml" ]; then
    output "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
    output "  Connection Details"
    output "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
    output "Panel URL: ${COLOR_ORANGE}${PANEL_URL:-Not configured}${COLOR_NC}"
    output "Node ID: ${COLOR_ORANGE}${NODE_ID:-Not configured}${COLOR_NC}"
    if [ -n "$PANEL_API_KEY" ]; then
      output "Setup Method: ${COLOR_ORANGE}Automatic (via API)${COLOR_NC}"
    else
      output "Setup Method: ${COLOR_ORANGE}Manual${COLOR_NC}"
    fi
    output "Configuration: ${COLOR_ORANGE}${Wings_INSTALL_DIR}/config.yml${COLOR_NC}"
    output "Node FQDN: ${COLOR_ORANGE}${FQDN:-Not configured}${COLOR_NC}"
    if [ "$CONFIGURE_LETSENCRYPT" == true ]; then
      output "SSL: ${COLOR_ORANGE}Let's Encrypt${COLOR_NC}"
    elif [ -n "$SSL_CERT_PATH" ] && [ -n "$SSL_KEY_PATH" ]; then
      output "SSL: ${COLOR_ORANGE}Custom Certificate${COLOR_NC}"
    elif [ "$ASSUME_SSL" == true ]; then
      output "SSL: ${COLOR_ORANGE}Assumed (external)${COLOR_NC}"
    else
      output "SSL: ${COLOR_ORANGE}None${COLOR_NC}"
    fi
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
    output "  ${COLOR_ORANGE}systemctl status Wings${COLOR_NC}    - Check service status"
    output "  ${COLOR_ORANGE}systemctl restart Wings${COLOR_NC}   - Restart service"
    output "  ${COLOR_ORANGE}journalctl -u Wings -f${COLOR_NC}   - View logs"
    echo ""

    output "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
    output "  Manual Reconfiguration"
    output "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
    output "If you need to reconfigure Wings manually, run:"
    output ""
    output "  ${COLOR_ORANGE}cd ${Wings_INSTALL_DIR} && sudo Wings configure \\"
    output "    --panel-url '${PANEL_URL}' \\"
    output "    --token '<your-api-key>' \\"
    output "    --node '${NODE_ID}'${COLOR_NC}"
    output ""
    output "Or use the installer function with parameters:"
    output "  ${COLOR_ORANGE}configure_Wings '${PANEL_URL}' '<api-key>' '${NODE_ID}'${COLOR_NC}"
    echo ""
  else
    output "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
    output "  Configuration Required"
    output "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
    output "Wings is installed but NOT configured."
    output ""
    output "The config directory has been created at ${Wings_INSTALL_DIR}."
    output "To complete setup, run:"
    output ""
    output "  ${COLOR_ORANGE}cd ${Wings_INSTALL_DIR} && sudo Wings configure \\"
    output "    --panel-url 'https://your-panel.com' \\"
    output "    --token 'your-api-key' \\"
    output "    --node 'your-node-id'${COLOR_NC}"
    output ""
    output "Then enable the service:"
    output "  ${COLOR_ORANGE}systemctl enable --now Wings${COLOR_NC}"
    echo ""
  fi

  if [ "$INSTALL_AUTO_UPDATER" == true ]; then
    output "Auto-updater is enabled and will check for updates hourly."
    echo ""
  fi

  print_brake 70

  # Save installation information
  save_Wings_install_info "install"

  # Pause to let user review logs before showing completion screen
  echo ""
  output "Installation finished, press Enter to view details..."
  read -r

  # Show completion screen
  show_Wings_completion "install"

  # Run health check only if configured
  if [ -f "${Wings_INSTALL_DIR}/config.yml" ]; then
    echo ""
    output "Running post-installation health check..."
    check_Wings_health
  fi
}

main
