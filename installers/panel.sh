#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Pyrodactyl Panel Installer                                                         #
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

# ------------------ Variables ----------------- #

PANEL_REPO="${PANEL_REPO:-pyrodactyl-oss/pyrodactyl}"
PANEL_INSTALL_METHOD="${PANEL_INSTALL_METHOD:-release}"
PANEL_FQDN="${PANEL_FQDN:-}"
PANEL_TIMEZONE="${PANEL_TIMEZONE:-UTC}"
PANEL_ADMIN_EMAIL="${PANEL_ADMIN_EMAIL:-}"
PANEL_ADMIN_USERNAME="${PANEL_ADMIN_USERNAME:-}"
PANEL_ADMIN_FIRSTNAME="${PANEL_ADMIN_FIRSTNAME:-}"
PANEL_ADMIN_LASTNAME="${PANEL_ADMIN_LASTNAME:-}"
PANEL_ADMIN_PASSWORD="${PANEL_ADMIN_PASSWORD:-}"
ASSUME_SSL="${ASSUME_SSL:-false}"
CONFIGURE_LETSENCRYPT="${CONFIGURE_LETSENCRYPT:-false}"
SSL_CERT_PATH="${SSL_CERT_PATH:-}"
SSL_KEY_PATH="${SSL_KEY_PATH:-}"
CONFIGURE_FIREWALL="${CONFIGURE_FIREWALL:-false}"
INSTALL_AUTO_UPDATER="${INSTALL_AUTO_UPDATER:-false}"
PANEL_REPO_PRIVATE="${PANEL_REPO_PRIVATE:-false}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

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

# ------------------ Validation ----------------- #

validate_configuration() {
  print_flame "Validating Configuration"

  local missing=()

  [ -z "$PANEL_FQDN" ] && missing+=("PANEL_FQDN")
  [ -z "$PANEL_ADMIN_EMAIL" ] && missing+=("PANEL_ADMIN_EMAIL")
  [ -z "$PANEL_ADMIN_USERNAME" ] && missing+=("PANEL_ADMIN_USERNAME")
  [ -z "$PANEL_ADMIN_FIRSTNAME" ] && missing+=("PANEL_ADMIN_FIRSTNAME")
  [ -z "$PANEL_ADMIN_LASTNAME" ] && missing+=("PANEL_ADMIN_LASTNAME")

  if [ ${#missing[@]} -gt 0 ]; then
    error "Missing required configuration variables:"
    for var in "${missing[@]}"; do
      output "  - $var"
    done
    exit 1
  fi

  if ! check_fqdn "$PANEL_FQDN"; then
    error "Invalid FQDN: $PANEL_FQDN"
    exit 1
  fi

  success "Configuration valid"
}

# ------------------ Dependencies ----------------- #

install_dependencies() {
  print_flame "Installing Dependencies"

  update_repos true

  case "$OS" in
    ubuntu)
      output "Configuring Ubuntu repositories..."
      install_packages "software-properties-common apt-transport-https ca-certificates gnupg2"
      add-apt-repository universe -y
      LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
      update_repos true

      install_packages "php${PHP_VERSION}-fpm php${PHP_VERSION}-cli php${PHP_VERSION}-gd php${PHP_VERSION}-mysql php${PHP_VERSION}-pdo php${PHP_VERSION}-mbstring php${PHP_VERSION}-tokenizer php${PHP_VERSION}-bcmath php${PHP_VERSION}-xml php${PHP_VERSION}-curl php${PHP_VERSION}-zip php${PHP_VERSION}-intl php${PHP_VERSION}-redis"
      ;;

    debian)
      output "Configuring Debian repositories..."
      install_packages "dirmngr ca-certificates apt-transport-https lsb-release"
      curl -fsSL -o /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
      echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
      update_repos true

      install_packages "php${PHP_VERSION}-fpm php${PHP_VERSION}-cli php${PHP_VERSION}-gd php${PHP_VERSION}-mysql php${PHP_VERSION}-pdo php${PHP_VERSION}-mbstring php${PHP_VERSION}-tokenizer php${PHP_VERSION}-bcmath php${PHP_VERSION}-xml php${PHP_VERSION}-curl php${PHP_VERSION}-zip php${PHP_VERSION}-intl php${PHP_VERSION}-redis"
      ;;

    rocky|almalinux|fedora|rhel|centos)
      output "Configuring RHEL repositories..."
      install_packages "epel-release"
      dnf install -y "https://rpms.remirepo.net/enterprise/remi-release-${OS_VER_MAJOR}.rpm"
      dnf module reset php -y
      dnf module enable php:remi-${PHP_VERSION} -y

      install_packages "php php-fpm php-cli php-gd php-mysqlnd php-pdo php-mbstring php-tokenizer php-bcmath php-xml php-curl php-zip php-intl php-redis"
      php_fpm_conf
      ;;
  esac

  # Install common packages
  install_packages "nginx mariadb-server redis-server curl tar unzip git"

  if [ "$CONFIGURE_LETSENCRYPT" == true ]; then
    install_packages "certbot python3-certbot-nginx"
  fi

  # Install composer
  install_composer

  success "Dependencies installed"
}

# ------------------ MariaDB ----------------- #

setup_database() {
  print_flame "Setting up MariaDB"

  output "Starting MariaDB service..."
  systemctl start mariadb
  systemctl enable mariadb



  # Check if MariaDB is accessible with current credentials
  if mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1" >/dev/null 2>&1; then
    output "MariaDB connection successful with existing credentials"
  # Check if MariaDB has no root password set (fresh install)
  elif mysql -u root -e "SELECT 1" >/dev/null 2>&1; then
    output "Securing MariaDB with new credentials..."
    mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';" 2>/dev/null || true

    # Verify the new password works
    if ! mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1" >/dev/null 2>&1; then
      error "Failed to set MariaDB root password"
      exit 1
    fi

    # Remove anonymous users and test database
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DELETE FROM mysql.user WHERE User='';" 2>/dev/null || true
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" 2>/dev/null || true
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DROP DATABASE IF EXISTS test;" 2>/dev/null || true
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" 2>/dev/null || true
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;" 2>/dev/null || true
  else
    # Cannot connect - MariaDB is secured with unknown password
    error "Cannot connect to MariaDB"
    error "MariaDB appears to be secured with a password that doesn't match our records"
    error "Please either:"
    error "  1. Set MYSQL_ROOT_PASSWORD environment variable to the correct password"
    error "  2. Reset MariaDB root password manually"
    error "  3. Remove /root/.config/pyrodactyl/db-credentials if you want to start fresh"
    exit 1
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

  success "Database configured"
}

# ------------------ Panel Installation ----------------- #

install_panel_release() {
  print_flame "Installing Panel from Release"

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
    if [ "$PANEL_REPO_PRIVATE" != "true" ]; then
      error "If this is a private repository, please set PANEL_REPO_PRIVATE=true and provide a GITHUB_TOKEN"
    fi
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

  output "Creating installation directory..."
  mkdir -p "$INSTALL_DIR"
  cd "$INSTALL_DIR"

  output "Downloading panel.tar.gz..."

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

  success "Panel downloaded to $INSTALL_DIR"
}

install_panel_clone() {
  print_flame "Installing Panel from Git Repository"

  if [ -d "$INSTALL_DIR" ] && [ "$(ls -A "$INSTALL_DIR")" ]; then
    error "Directory $INSTALL_DIR already exists and is not empty"
    exit 1
  fi

  output "Cloning from https://github.com/${PANEL_REPO}.git"
  mkdir -p "$(dirname "$INSTALL_DIR")"

  local git_url="https://github.com/${PANEL_REPO}.git"
  if [ -n "$GITHUB_TOKEN" ] && [ "$PANEL_REPO_PRIVATE" == "true" ]; then
    git_url="https://${GITHUB_TOKEN}@github.com/${PANEL_REPO}.git"
  fi

  if ! git clone "$git_url" "$INSTALL_DIR"; then
    error "Failed to clone repository"
    exit 1
  fi

  cd "$INSTALL_DIR"
  cp .env.example .env

  output "Installing composer dependencies..."
  COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction

  success "Panel cloned to $INSTALL_DIR"
}

# ------------------ Panel Configuration ----------------- #

configure_panel() {
  print_flame "Configuring Panel"

  cd "$INSTALL_DIR"

  # Generate application key
  output "Generating application key..."
  php artisan key:generate --force

  # Determine app URL
  local app_url="http://$PANEL_FQDN"
  [ "$ASSUME_SSL" == true ] && app_url="https://$PANEL_FQDN"
  [ "$CONFIGURE_LETSENCRYPT" == true ] && app_url="https://$PANEL_FQDN"

  # Setup environment
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
  output "Configuring database connection..."
  php artisan p:environment:database \
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

  success "Panel configured"
}

# ------------------ Services ----------------- #

setup_services() {
  print_flame "Setting up Services"

  # Set permissions
  output "Setting file permissions..."
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

  # Setup nginx
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

  success "Services configured"
}

# ------------------ Firewall ----------------- #

configure_firewall() {
  if [ "$CONFIGURE_FIREWALL" != true ]; then
    return 0
  fi

  print_flame "Configuring Firewall"

  install_firewall

  local ports="22 80"
  [ "$CONFIGURE_LETSENCRYPT" == true ] || [ -n "$SSL_CERT_PATH" ] && ports="$ports 443"

  firewall_allow_ports "$ports"

  success "Firewall configured"
}

# ------------------ Auto-Updater ----------------- #

setup_auto_updater() {
  if [ "$INSTALL_AUTO_UPDATER" != true ]; then
    return 0
  fi

  print_flame "Installing Auto-Updater"

  export PANEL_REPO
  export PANEL_REPO_PRIVATE
  export GITHUB_TOKEN

  install_auto_updater_panel

  success "Auto-updater installed"
}

# ------------------ Main ----------------- #

main() {
  print_header
  print_flame "Starting Pyrodactyl Panel Installation"

  validate_configuration

  # Check for existing installation
  if check_existing_installation "panel"; then
    warning "Existing panel installation detected"
    if ! bool_input "Continue and overwrite existing installation? [y/N]: " "n"; then
      error "Installation aborted"
      exit 1
    fi
  fi

  # Install
  install_dependencies
  setup_database

  if [ "$PANEL_INSTALL_METHOD" == "release" ]; then
    install_panel_release
  else
    install_panel_clone
  fi

  configure_panel
  setup_services
  configure_firewall
  setup_auto_updater

  # Final output
  print_header
  print_flame "Installation Complete!"

  echo ""
  output "🎉 Your Pyrodactyl Panel has been installed successfully!"
  echo ""
  output "Panel URL: ${COLOR_ORANGE}https://${PANEL_FQDN}${COLOR_NC}"
  output "Admin Email: ${COLOR_ORANGE}${PANEL_ADMIN_EMAIL}${COLOR_NC}"
  output "Admin Username: ${COLOR_ORANGE}${PANEL_ADMIN_USERNAME}${COLOR_NC}"
  output "Admin Password: ${COLOR_ORANGE}${PANEL_ADMIN_PASSWORD}${COLOR_NC}"
  echo ""
  output "Database credentials saved to: ${COLOR_ORANGE}/root/.config/pyrodactyl/db-credentials${COLOR_NC}"
  echo ""

  if [ "$INSTALL_AUTO_UPDATER" == true ]; then
    output "✅ Auto-updater is enabled and will check for updates hourly."
    echo ""
  fi

  output "Service Commands:"
  output "  ${COLOR_ORANGE}systemctl status pyroq${COLOR_NC}    - Panel queue worker"
  output "  ${COLOR_ORANGE}systemctl status nginx${COLOR_NC}    - Web server"
  output "  ${COLOR_ORANGE}systemctl status mariadb${COLOR_NC}  - Database"
  echo ""

  print_brake 70
}

main "$@"
