#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Pyrodactyl + Elytra Combined Installer                                             #
#                                                                                    #
# Installs both Panel and Elytra on the same machine with automatic configuration    #
#                                                                                    #
######################################################################################

# Check if lib is loaded, load if not or fail otherwise.
fn_exists() { declare -F "$1" >/dev/null; }
if ! fn_exists lib_loaded; then
  source /tmp/pyrodactyl-lib.sh 2>/dev/null || source <(curl -sSL "${GITHUB_BASE_URL:-"https://raw.githubusercontent.com/Muspelheim-Hosting/pyrodactyl-installer"}/${GITHUB_SOURCE:-"main"}/lib/lib.sh")
  ! fn_exists lib_loaded && echo "* ERROR: Could not load lib script" && exit 1
fi

# ------------------ Variables ----------------- #

# Panel configuration
PANEL_REPO="${PANEL_REPO:-pyrodactyl-oss/pyrodactyl}"
PANEL_INSTALL_METHOD="${PANEL_INSTALL_METHOD:-release}"
PANEL_FQDN="${PANEL_FQDN:-}"
PANEL_TIMEZONE="${PANEL_TIMEZONE:-UTC}"
PANEL_ADMIN_EMAIL="${PANEL_ADMIN_EMAIL:-}"
PANEL_ADMIN_USERNAME="${PANEL_ADMIN_USERNAME:-}"
PANEL_ADMIN_FIRSTNAME="${PANEL_ADMIN_FIRSTNAME:-}"
PANEL_ADMIN_LASTNAME="${PANEL_ADMIN_LASTNAME:-}"
PANEL_ADMIN_PASSWORD="${PANEL_ADMIN_PASSWORD:-$(gen_passwd 32)}"
ASSUME_SSL="${ASSUME_SSL:-false}"
CONFIGURE_LETSENCRYPT="${CONFIGURE_LETSENCRYPT:-false}"
SSL_CERT_PATH="${SSL_CERT_PATH:-}"
SSL_KEY_PATH="${SSL_KEY_PATH:-}"

# Database
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-panel}"
DB_USER="${DB_USER:-pyrodactyl}"

# Load existing credentials or generate new ones
if saved_pass=$(load_existing_db_credentials); then
  MYSQL_ROOT_PASSWORD="${saved_pass}"
else
  DB_PASSWORD="${DB_PASSWORD:-$(gen_passwd 64)}"
  MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-$(gen_passwd 64)}"
fi

# Elytra configuration
ELYTRA_REPO="${ELYTRA_REPO:-pyrohost/elytra}"
NODE_NAME="${NODE_NAME:-local}"
NODE_DESCRIPTION="${NODE_DESCRIPTION:-Local Node}"
NODE_TOKEN="${NODE_TOKEN:-$(gen_passwd 32)}"
BEHIND_PROXY="${BEHIND_PROXY:-false}"

# General
CONFIGURE_FIREWALL="${CONFIGURE_FIREWALL:-false}"
GAME_PORT_START="${GAME_PORT_START:-27015}"
GAME_PORT_END="${GAME_PORT_END:-28025}"
INSTALL_AUTO_UPDATER_PANEL="${INSTALL_AUTO_UPDATER_PANEL:-false}"
INSTALL_AUTO_UPDATER_ELYTRA="${INSTALL_AUTO_UPDATER_ELYTRA:-false}"

# GitHub
PANEL_REPO_PRIVATE="${PANEL_REPO_PRIVATE:-false}"
ELYTRA_REPO_PRIVATE="${ELYTRA_REPO_PRIVATE:-false}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# Paths
INSTALL_DIR="${INSTALL_DIR:-/var/www/pyrodactyl}"
ELYTRA_DIR="${ELYTRA_DIR:-/etc/elytra}"
PANEL_CONFIG_DIR="${PANEL_CONFIG_DIR:-/etc/pyrodactyl}"

# Node ID (will be set during installation)
NODE_ID=""

# Validation
missing=()

for var in PANEL_FQDN PANEL_ADMIN_EMAIL PANEL_ADMIN_USERNAME PANEL_ADMIN_FIRSTNAME PANEL_ADMIN_LASTNAME; do
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

# Validate FQDN
if ! check_fqdn "$PANEL_FQDN"; then
  error "Invalid FQDN: $PANEL_FQDN"
  error "FQDN must be a domain name, not an IP address"
  exit 1
fi

# ---------------- Installation Functions ---------------- #

check_existing() {
  local has_existing=false

  if check_existing_installation "panel"; then
    has_existing=true
  fi

  if check_existing_installation "elytra"; then
    has_existing=true
  fi

  if [ "$has_existing" == true ]; then
    echo ""
    if ! bool_input "Continue with installation? This may overwrite existing files" "n"; then
      error "Installation aborted."
      exit 1
    fi

    # Stop services if they exist
    systemctl stop elytra 2>/dev/null || true
    systemctl stop pyroq 2>/dev/null || true
  fi
}

# ---------------- Panel Installation ---------------- #

install_panel_dependencies() {
  print_flame "Installing Panel Dependencies"

  update_repos true

  case "$OS" in
    ubuntu)
      output "Setting up Ubuntu repositories..."
      install_packages "software-properties-common apt-transport-https ca-certificates gnupg2"
      add-apt-repository universe -y
      LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
      update_repos true
      install_packages "php${PHP_VERSION}-fpm php${PHP_VERSION}-cli php${PHP_VERSION}-gd php${PHP_VERSION}-mysql php${PHP_VERSION}-pdo php${PHP_VERSION}-mbstring php${PHP_VERSION}-tokenizer php${PHP_VERSION}-bcmath php${PHP_VERSION}-xml php${PHP_VERSION}-curl php${PHP_VERSION}-zip php${PHP_VERSION}-intl php${PHP_VERSION}-redis php${PHP_VERSION}-sqlite3"

      ensure_php_default
      ;;

    debian)
      output "Setting up Debian repositories..."
      install_packages "dirmngr ca-certificates apt-transport-https lsb-release"
      curl -o /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
      echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
      update_repos true
      install_packages "php${PHP_VERSION}-fpm php${PHP_VERSION}-cli php${PHP_VERSION}-gd php${PHP_VERSION}-mysql php${PHP_VERSION}-pdo php${PHP_VERSION}-mbstring php${PHP_VERSION}-tokenizer php${PHP_VERSION}-bcmath php${PHP_VERSION}-xml php${PHP_VERSION}-curl php${PHP_VERSION}-zip php${PHP_VERSION}-intl php${PHP_VERSION}-redis php${PHP_VERSION}-sqlite3"

      ensure_php_default
      ;;

    rocky|almalinux)
      output "Setting up RHEL repositories..."
      install_packages "epel-release"
      dnf install -y "https://rpms.remirepo.net/enterprise/remi-release-${OS_VER_MAJOR}.rpm"
      dnf module reset php -y
      dnf module enable php:remi-${PHP_VERSION} -y
      install_packages "php-fpm php-cli php-gd php-mysqlnd php-pdo php-mbstring php-tokenizer php-bcmath php-xml php-curl php-zip php-intl php-redis php-sqlite3"
      php_fpm_conf
      ;;
  esac

  # Install common packages
  install_packages "nginx mariadb-server redis-server curl tar unzip git certbot python3-certbot-nginx jq"

  success "Panel dependencies installed"
}

install_panel_release() {
  print_flame "Downloading Panel Release"

  # Ensure jq is installed for JSON parsing
  if ! cmd_exists jq; then
    output "Installing jq for JSON parsing..."
    install_packages "jq" true
  fi

  # Only require token for private repos
  if [ "$PANEL_REPO_PRIVATE" == "true" ] && [ -z "$GITHUB_TOKEN" ]; then
    error "GitHub token is required to download the panel from the private repository."
    error "Please provide a token using --github-token or set the GITHUB_TOKEN environment variable."
    exit 1
  fi

  output "Fetching latest release from ${PANEL_REPO}..."

  # Build curl headers based on whether we have a token
  local curl_headers=(
    "--header" "Accept: application/vnd.github+json"
    "--header" "X-GitHub-Api-Version: 2022-11-28"
  )

  if [ -n "$GITHUB_TOKEN" ]; then
    curl_headers+=("--header" "Authorization: Bearer $GITHUB_TOKEN")
  fi

  # Get the latest release info from GitHub API
  local release_data
  release_data=$(curl -sS "${curl_headers[@]}" \
    "https://api.github.com/repos/${PANEL_REPO}/releases/latest")

  # Check if we got a valid response
  if echo "$release_data" | grep -q '"message"'; then
    error "Failed to fetch release data from ${PANEL_REPO}"
    error "API Response: $(echo "$release_data" | jq -r '.message' 2>/dev/null || echo "$release_data")"
    exit 1
  fi

  # Get the asset API URL
  local asset_api_url
  asset_api_url=$(echo "$release_data" | jq -r ".assets[] | select(.name == \"panel.tar.gz\") | .url")

  if [ -z "$asset_api_url" ] || [ "$asset_api_url" == "null" ]; then
    error "Could not find asset 'panel.tar.gz' in latest release"
    error "Available assets: $(echo "$release_data" | jq -r '.assets[].name' 2>/dev/null || echo "(failed to parse)")"
    exit 1
  fi

  local release_tag
  release_tag=$(echo "$release_data" | jq -r '.tag_name')
  info "Latest release: $release_tag"

  output "Downloading panel.tar.gz..."

  mkdir -p "$INSTALL_DIR"
  cd "$INSTALL_DIR"

  # Build download headers - token optional for public repos
  local download_headers=(
    "--header" "Accept: application/octet-stream"
    "--header" "X-GitHub-Api-Version: 2022-11-28"
  )

  if [ -n "$GITHUB_TOKEN" ]; then
    download_headers+=("--header" "Authorization: Bearer $GITHUB_TOKEN")
  fi

  # Download using the asset API URL
  if ! curl --location --fail --silent --show-error "${download_headers[@]}" \
    --output panel.tar.gz \
    "$asset_api_url"; then
    error "Failed to download panel from repository"
    if [ "$PANEL_REPO_PRIVATE" == "true" ]; then
      error "Please check that your GitHub token has 'repo' scope and the release exists."
    else
      error "Please check that the release exists and is accessible."
    fi
    exit 1
  fi

  output "Extracting files..."
  tar -xzf panel.tar.gz
  chmod -R 755 storage/* bootstrap/cache/ 2>/dev/null || true
  rm -f panel.tar.gz

  # Check if .env.example exists, if not download from repo
  if [ ! -f ".env.example" ]; then
    output ".env.example not found in release, downloading from repository..."
    local env_url="https://raw.githubusercontent.com/${PANEL_REPO}/main/.env.example"

    if [ -n "$GITHUB_TOKEN" ]; then
      curl -fsSL \
        --header "Authorization: Bearer $GITHUB_TOKEN" \
        --header "Accept: application/vnd.github.v3.raw" \
        -o .env.example \
        "$env_url" 2>/dev/null || warning "Failed to download .env.example from repository"
    else
      curl -fsSL -o .env.example "$env_url" 2>/dev/null || warning "Failed to download .env.example from repository"
    fi

    if [ ! -f ".env.example" ]; then
      error "Could not obtain .env.example file"
      error "The release package may be incomplete or the repository may be inaccessible"
      exit 1
    fi
  fi

  cp .env.example .env

  # Install composer and dependencies
  install_composer

  [ "$OS" == "rocky" ] || [ "$OS" == "almalinux" ] && export PATH=/usr/local/bin:$PATH

  output "Installing composer dependencies..."
  COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction

  # Build frontend assets
  build_panel_assets "$INSTALL_DIR"

  success "Panel downloaded to $INSTALL_DIR"
}

install_panel_clone() {
  print_flame "Cloning Panel Repository"

  if [ -d "$INSTALL_DIR" ] && [ "$(ls -A "$INSTALL_DIR")" ]; then
    error "Directory $INSTALL_DIR already exists and is not empty"
    exit 1
  fi

  output "Cloning from https://github.com/${PANEL_REPO}.git"
  mkdir -p "$(dirname "$INSTALL_DIR")"

  if [ -n "$GITHUB_TOKEN" ] && [ "$PANEL_REPO_PRIVATE" == "true" ]; then
    git clone "https://${GITHUB_TOKEN}@github.com/${PANEL_REPO}.git" "$INSTALL_DIR"
  else
    git clone "https://github.com/${PANEL_REPO}.git" "$INSTALL_DIR"
  fi

  cd "$INSTALL_DIR"
  cp .env.example .env

  # Install composer and dependencies
  install_composer

  [ "$OS" == "rocky" ] || [ "$OS" == "almalinux" ] && export PATH=/usr/local/bin:$PATH

  output "Installing composer dependencies..."
  COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction

  # Build frontend assets
  build_panel_assets "$INSTALL_DIR"

  success "Panel cloned to $INSTALL_DIR"
}

configure_mariadb() {
  print_flame "Configuring MariaDB"

  output "Starting MariaDB..."
  systemctl start mariadb
  systemctl enable mariadb

  # Check if MariaDB is already secured with our credentials
  if mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1" >/dev/null 2>&1; then
    output "MariaDB already secured with existing credentials"
  else
    output "Securing MariaDB..."
    # Try to set root password (may fail if already secured differently)
    mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';" 2>/dev/null || true

    # Test if it worked
    if ! mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1" >/dev/null 2>&1; then
      error "Could not secure MariaDB with provided credentials"
      error "If MariaDB was previously configured with a different password, set MYSQL_ROOT_PASSWORD environment variable"
      exit 1
    fi

    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DELETE FROM mysql.user WHERE User='';" 2>/dev/null || true
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" 2>/dev/null || true
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DROP DATABASE IF EXISTS test;" 2>/dev/null || true
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" 2>/dev/null || true
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;" 2>/dev/null || true
  fi

  # Save credentials
  mkdir -p /root/.config/pyrodactyl
  echo "root:${MYSQL_ROOT_PASSWORD}" > /root/.config/pyrodactyl/db-credentials
  chmod 600 /root/.config/pyrodactyl/db-credentials

  # Create panel database and user
  output "Creating panel database..."
  mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};" 2>/dev/null || true

  # Check if user exists, create or update password
  local user_exists
  user_exists=$(mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -N -B -e "SELECT COUNT(*) FROM mysql.user WHERE user='${DB_USER}' AND host='${DB_HOST}';" 2>/dev/null || echo "0")

  if [ "$user_exists" == "0" ]; then
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "CREATE USER '${DB_USER}'@'${DB_HOST}' IDENTIFIED BY '${DB_PASSWORD}';" 2>/dev/null || true
  else
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "ALTER USER '${DB_USER}'@'${DB_HOST}' IDENTIFIED BY '${DB_PASSWORD}';" 2>/dev/null || true
  fi

  mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'${DB_HOST}';" 2>/dev/null || true
  mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;" 2>/dev/null || true

  success "MariaDB configured"
}

configure_panel_environment() {
  print_flame "Configuring Panel Environment"

  cd "$INSTALL_DIR"

  # Generate application key
  output "Generating application key..."
  php artisan key:generate --force

  # Determine app URL
  local app_url="http://$PANEL_FQDN"
  [ "$ASSUME_SSL" == true ] && app_url="https://$PANEL_FQDN"
  [ "$CONFIGURE_LETSENCRYPT" == true ] && app_url="https://$PANEL_FQDN"

  # Setup environment using artisan commands
  output "Configuring environment..."
  php artisan p:environment:setup \
    --author="$PANEL_ADMIN_EMAIL" \
    --url="$app_url" \
    --timezone="$PANEL_TIMEZONE" \
    --cache="redis" \
    --session="redis" \
    --queue="redis" \
    --redis-host="localhost" \
    --redis-pass="null" \
    --redis-port="6379" \
    --settings-ui=true

  # Configure database
  output "Configuring database..."
  php artisan p:environment:database -n \
    --host="$DB_HOST" \
    --port="$DB_PORT" \
    --database="$DB_NAME" \
    --username="$DB_USER" \
    --password="$DB_PASSWORD"

  # Run migrations
  output "Running database migrations..."
  php artisan migrate --seed --force

  # Create admin user
  output "Creating admin user..."
  php artisan p:user:make \
    --email="$PANEL_ADMIN_EMAIL" \
    --username="$PANEL_ADMIN_USERNAME" \
    --name-first="$PANEL_ADMIN_FIRSTNAME" \
    --name-last="$PANEL_ADMIN_LASTNAME" \
    --password="$PANEL_ADMIN_PASSWORD" \
    --admin=1

  success "Environment configured"
}

setup_panel_services() {
  print_flame "Setting up Panel Services"

  # Set permissions
  output "Setting ownership to $WEBUSER:$WEBGROUP..."
  chown -R "$WEBUSER":"$WEBGROUP" "$INSTALL_DIR"/*
  chmod -R 755 "$INSTALL_DIR"/storage/* "$INSTALL_DIR"/bootstrap/cache/*

  # Enable Redis
  enable_redis

  # Enable nginx
  systemctl enable nginx

  # Enable MariaDB
  systemctl enable mariadb

  # SELinux configuration for RHEL
  selinux_allow

  # Install nginx config
  local php_socket
  php_socket=$(get_php_socket)

  local use_ssl=false
  [ -n "$SSL_CERT_PATH" ] && [ -n "$SSL_KEY_PATH" ] && use_ssl=true

  install_nginx_config "$PANEL_FQDN" "$php_socket" "$use_ssl" "$SSL_CERT_PATH" "$SSL_KEY_PATH"

  # Setup SSL if requested
  if [ "$CONFIGURE_LETSENCRYPT" == true ]; then
    install_letsencrypt "$PANEL_FQDN" "$PANEL_ADMIN_EMAIL"
  fi

  # Setup cron
  insert_cronjob

  # Install queue worker
  install_pyroq

  success "Panel services configured"
}

# ---------------- Node Creation ---------------- #

create_node_in_panel() {
  print_flame "Creating Node in Panel"

  cd "$INSTALL_DIR"

  # Create location first
  output "Creating location..."
  php artisan p:location:make --short=local --long="Local Location" 2>/dev/null || true

  # Get location ID
  local location_id
  location_id=$(mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -D panel -N -B -e "SELECT id FROM locations WHERE short='local' LIMIT 1;" 2>/dev/null || echo "1")

  # Create node
  output "Creating node: $NODE_NAME..."
  php artisan p:node:make \
    --name="$NODE_NAME" \
    --description="$NODE_DESCRIPTION" \
    --locationId="$location_id" \
    --fqdn="localhost" \
    --public=1 \
    --scheme=http \
    --proxy=$([ "$BEHIND_PROXY" == "true" ] && echo "yes" || echo "no") \
    --maxMemory=0 \
    --overallocateMemory=0 \
    --maxDisk=0 \
    --overallocateDisk=0 \
    --uploadSize=100 2>/dev/null || true

  # Get the node ID
  NODE_ID=$(mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -D panel -N -B -e "SELECT id FROM nodes WHERE name='${NODE_NAME}' LIMIT 1;" 2>/dev/null || echo "1")

  if [ -z "$NODE_ID" ] || [ "$NODE_ID" == "NULL" ]; then
    NODE_ID="1"
  fi

  output "Node ID: $NODE_ID"

  # Create allocations
  output "Creating allocations (ports $GAME_PORT_START-$GAME_PORT_END)..."
  output "This range supports: Minecraft, CS:GO/TF2/GMod, ARK, Satisfactory, Rust, Valheim, FiveM"
  for i in $(seq "$GAME_PORT_START" "$GAME_PORT_END"); do
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "INSERT IGNORE INTO panel.allocations (node_id, ip, port) VALUES (${NODE_ID}, '0.0.0.0', ${i})" 2>/dev/null || true
  done

  # Update node with daemon token
  mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "
    UPDATE panel.nodes SET
      daemon_token = '${NODE_TOKEN}',
      daemonListen = 8080,
      daemonSFTP = 2022
    WHERE id = ${NODE_ID}
  " 2>/dev/null || true

  success "Node created in panel"
}

# ---------------- Elytra Installation ---------------- #

install_elytra_daemon() {
  print_flame "Installing Elytra Daemon"

  # Check if Docker is installed
  if ! cmd_exists docker; then
    output "Installing Docker..."

    case "$OS" in
      ubuntu|debian)
        apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
        install_packages "apt-transport-https ca-certificates curl gnupg lsb-release"
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        update_repos true
        install_packages "docker-ce docker-ce-cli containerd.io docker-compose-plugin"
        ;;

      rocky|almalinux)
        install_packages "yum-utils"
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        install_packages "docker-ce docker-ce-cli containerd.io docker-compose-plugin"
        ;;
    esac

    systemctl start docker
    systemctl enable docker

    # Check virtualization
    check_virt
  else
    output "Docker is already installed"
  fi

  # Create directories
  mkdir -p "$ELYTRA_DIR"
  mkdir -p "$PANEL_CONFIG_DIR"
  mkdir -p /var/lib/pyrodactyl/volumes
  mkdir -p /var/lib/pyrodactyl/archives
  mkdir -p /var/lib/pyrodactyl/backups

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

  # Generate UUID
  local uuid
  uuid=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$(date +%s)-$(hostname)-$$")

  # Download configuration template
  output "Downloading Elytra configuration template..."

  if ! curl -fsSL -o "${ELYTRA_DIR}/config.yml" "$GITHUB_URL/configs/elytra-config.yml" 2>/dev/null; then
    error "Failed to download Elytra configuration template"
    exit 1
  fi

  # Replace placeholders
  sed -i "s|<UUID>|${uuid}|g" "${ELYTRA_DIR}/config.yml"
  sed -i "s|<TOKEN_ID>|${NODE_ID}|g" "${ELYTRA_DIR}/config.yml"
  sed -i "s|<TOKEN>|${NODE_TOKEN}|g" "${ELYTRA_DIR}/config.yml"
  sed -i "s|<REMOTE>|http://localhost|g" "${ELYTRA_DIR}/config.yml"

  if [ "$BEHIND_PROXY" == "true" ]; then
    sed -i "s|<TRUSTED_PROXIES>|[\"0.0.0.0/0\"]|g" "${ELYTRA_DIR}/config.yml"
  else
    sed -i "s|<TRUSTED_PROXIES>|[]|g" "${ELYTRA_DIR}/config.yml"
  fi

  # Copy config to pyrodactyl directory
  cp "${ELYTRA_DIR}/config.yml" "${PANEL_CONFIG_DIR}/config.yml" 2>/dev/null || true

  # Install rustic
  if ! cmd_exists rustic; then
    output "Installing rustic backup tool..."
    local rustic_arch
    rustic_arch=$(uname -m)
    [[ $rustic_arch == x86_64 ]] && rustic_arch=x86_64 || rustic_arch=aarch64

    curl -fsSL -o /tmp/rustic.tar.gz "https://github.com/rustic-rs/rustic/releases/latest/download/rustic-${rustic_arch}-unknown-linux-gnu.tar.gz" || {
      warning "Failed to download rustic"
    }

    if [ -f /tmp/rustic.tar.gz ]; then
      tar -xzf /tmp/rustic.tar.gz -C /usr/local/bin rustic
      chmod +x /usr/local/bin/rustic
      rm -f /tmp/rustic.tar.gz
    fi
  fi

  # Download systemd service
  output "Downloading Elytra service..."
  if ! curl -fsSL -o /etc/systemd/system/elytra.service "$GITHUB_URL/configs/elytra.service" 2>/dev/null; then
    error "Failed to download Elytra service file"
    exit 1
  fi

  systemctl daemon-reload
  systemctl enable elytra
  systemctl start elytra

  # Wait for service to start
  sleep 3

  if systemctl is-active --quiet elytra; then
    success "Elytra is running"
  else
    warning "Elytra service may not have started properly"
  fi

  success "Elytra installed and started"
}

# ---------------- Final Configuration ---------------- #

configure_firewall() {
  if [ "$CONFIGURE_FIREWALL" == true ]; then
    print_flame "Configuring Firewall"

    install_firewall

    output "Opening ports for panel and game servers..."
    output "  • 22 (SSH)"
    output "  • 80, 443 (HTTP/HTTPS)"
    output "  • 8080 (Elytra API)"
    output "  • 2022 (SFTP)"
    output "  • 25565-25665 (Minecraft)"
    output "  • 27015-27150 (Source Engine - CS:GO, TF2, GMod)"
    output "  • 7777-8000 (Unreal Engine - ARK, Satisfactory)"
    output "  • 28015-28025 (Rust)"
    output "  • 2456-2466 (Valheim)"
    output "  • 30120-30130 (FiveM/GTA)"
    output "  • ${GAME_PORT_START}-${GAME_PORT_END} (Additional range)"

    local ports="22 80 443 8080 2022"
    ports="$ports 25565:25665 27015:27150 7777:8000 28015:28025 2456:2466 30120:30130"
    ports="$ports ${GAME_PORT_START}:${GAME_PORT_END}"

    # Allow SSH
    case "$OS" in
      ubuntu|debian)
        ufw allow ssh
        ;;
      rocky|almalinux)
        firewall-cmd --permanent --add-service=ssh
        ;;
    esac

    firewall_allow_ports "$ports"
    success "Firewall configured"
  fi
}

install_auto_updaters() {
  if [ "$INSTALL_AUTO_UPDATER_PANEL" == true ]; then
    print_flame "Installing Panel Auto-Updater"
    export PANEL_REPO
    export PANEL_REPO_PRIVATE
    export GITHUB_TOKEN
    install_auto_updater_panel
  fi

  if [ "$INSTALL_AUTO_UPDATER_ELYTRA" == true ]; then
    print_flame "Installing Elytra Auto-Updater"
    export ELYTRA_REPO
    export ELYTRA_REPO_PRIVATE
    export GITHUB_TOKEN
    install_auto_updater_elytra
  fi
}

# ---------------- Main ---------------- #

main() {
  print_header
  print_flame "Starting Combined Installation"
  output "This will install Pyrodactyl Panel and Elytra on the same machine."
  echo ""

  check_existing

  # Panel installation
  install_panel_dependencies
  configure_mariadb

  if [ "$PANEL_INSTALL_METHOD" == "release" ]; then
    install_panel_release
  else
    install_panel_clone
  fi

  configure_panel_environment
  setup_panel_services
  install_phpmyadmin

  # Create node in panel
  create_node_in_panel

  # Setup database host for the panel
  setup_database_host "$PANEL_FQDN"

  # Elytra installation
  install_elytra_daemon

  # Firewall
  configure_firewall

  # Auto-updaters
  install_auto_updaters

  print_header
  print_flame "Installation Complete!"

  echo ""
  output "🎉 Pyrodactyl Panel and Elytra have been successfully installed!"
  echo ""
  output "Panel URL: ${COLOR_ORANGE}https://${PANEL_FQDN}${COLOR_NC}"
  output "Admin Email: ${COLOR_ORANGE}${PANEL_ADMIN_EMAIL}${COLOR_NC}"
  output "Admin Username: ${COLOR_ORANGE}${PANEL_ADMIN_USERNAME}${COLOR_NC}"
  output "Admin Password: ${COLOR_ORANGE}**hidden** (hope you remember it!)${COLOR_NC}"
  echo ""
  output "Node Information:"
  output "  Name: ${COLOR_ORANGE}${NODE_NAME}${COLOR_NC}"
  output "  ID: ${COLOR_ORANGE}${NODE_ID}${COLOR_NC}"
  output "  Description: ${COLOR_ORANGE}${NODE_DESCRIPTION}${COLOR_NC}"
  echo ""
  output "Game Server Ports Configured (TCP & UDP):"
  output "  • 25565-25665: Minecraft"
  output "  • 27015-27150: Source Engine (CS:GO, TF2, GMod)"
  output "  • 7777-8000: Unreal Engine (ARK, Satisfactory)"
  output "  • 28015-28025: Rust"
  output "  • 2456-2466: Valheim"
  output "  • 30120-30130: FiveM/GTA"
  output "  • ${GAME_PORT_START}-${GAME_PORT_END}: General range"
  echo ""
  output "Both components are configured to work together on this machine!"
  echo ""

  if [ "$INSTALL_AUTO_UPDATER_PANEL" == true ] || [ "$INSTALL_AUTO_UPDATER_ELYTRA" == true ]; then
    output "✅ Auto-updaters are enabled and will check for updates hourly."
    echo ""
  fi

  output "Service Commands:"
  output "  ${COLOR_ORANGE}systemctl status pyroq${COLOR_NC}    - Panel queue worker"
  output "  ${COLOR_ORANGE}systemctl status elytra${COLOR_NC}    - Elytra daemon"
  output "  ${COLOR_ORANGE}journalctl -u elytra -f${COLOR_NC}   - View Elytra logs"
  echo ""

  print_brake 70
}

main
