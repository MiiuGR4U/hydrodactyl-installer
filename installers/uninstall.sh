#!/bin/bash

set -e

# shellcheck source=lib/lib.sh
fn_exists() { declare -F "$1" >/dev/null; }
if ! fn_exists lib_loaded; then
  if [ -f /tmp/hydrodactyl-lib.sh ]; then
    if ! source /tmp/hydrodactyl-lib.sh 2>/dev/null; then
      rm -f /tmp/hydrodactyl-lib.sh
    fi
  fi
  if ! fn_exists lib_loaded; then
    source <(curl -sSL "${GITHUB_BASE_URL:-https://raw.githubusercontent.com/MiiuGR4U/hydrodactyl-installer}/${GITHUB_SOURCE:-main}/lib/lib.sh?v=$RANDOM")
  fi
  ! fn_exists lib_loaded && echo "* ERROR: Could not load lib script" && exit 1
fi

# Configuration
PANEL_DIR="/var/www/hydrodactyl"
WINGS_DIR="/etc/wings"
PANEL_DATA_DIR="/var/lib/pterodactyl"

remove_panel() {
    print_flame "Removing Hydrodactyl Panel"

    # Remove Panel auto-updater
    output "Removing Panel Auto-Updater..."
    remove_auto_updater_panel 2>/dev/null || true
    rm -rf /var/backups/Hydrodactyl

    # Stop services
    output "Stopping panel services..."
    systemctl stop pteroq 2>/dev/null || true
    systemctl disable pteroq 2>/dev/null || true

    # Remove nginx config
    output "Removing nginx configuration..."
    rm -f /etc/nginx/sites-available/Hydrodactyl.conf
    rm -f /etc/nginx/sites-enabled/Hydrodactyl.conf

    # Reload nginx if it's running
    if systemctl is-active --quiet nginx; then
        nginx -t && systemctl reload nginx
    fi

    # Remove panel files
    if [ -d "$PANEL_DIR" ]; then
        output "Removing panel files..."
        rm -rf "$PANEL_DIR"
    fi

    # Remove systemd service
    rm -f /etc/systemd/system/pteroq.service
    systemctl daemon-reload

    # Remove cron job
    crontab -l 2>/dev/null | grep -v "Hydrodactyl" | crontab - 2>/dev/null || true

    # Remove SSL certificates if Let's Encrypt was used
    if [ -d "/etc/letsencrypt" ]; then
        output "Checking for Let's Encrypt certificates..."
        certbot delete --cert-name "$(hostname -f)" 2>/dev/null || true
    fi

    # Remove Panel install info
    rm -f /etc/hydrodactyl/install-info/panel-info

    success "Panel removed"
}

remove_wings() {
    print_flame "Removing Wings"

    # Attempt to remove Node from Panel
    if [ -f "/etc/hydrodactyl/install-info/wings-info" ]; then
        output "Attempting to remove Node from Panel via API..."
        local api_key panel_url node_id
        api_key=$(grep -m1 '^API_KEY=' "/etc/hydrodactyl/install-info/wings-info" | cut -d'"' -f2 || true)
        panel_url=$(grep -m1 '^PANEL_URL=' "/etc/hydrodactyl/install-info/wings-info" | cut -d'"' -f2 || true)
        node_id=$(grep -m1 '^NODE_ID=' "/etc/hydrodactyl/install-info/wings-info" | cut -d'"' -f2 || true)
        
        if [ -n "$api_key" ] && [ -n "$panel_url" ] && [ -n "$node_id" ]; then
            panel_url="${panel_url%/}"
            local status_code
            status_code=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$panel_url/api/application/nodes/$node_id" \
                -H "Authorization: Bearer $api_key" \
                -H "Accept: application/json")
            
            if [ "$status_code" == "204" ] || [ "$status_code" == "200" ]; then
                success "Node successfully removed from Panel"
            elif [ "$status_code" == "400" ]; then
                warning "Could not remove Node from Panel (Status 400). It may have active servers attached."
            elif [ "$status_code" == "404" ]; then
                success "Node already removed or not found in Panel"
            else
                warning "Failed to remove Node from Panel. API returned status: $status_code"
            fi
        else
            warning "Missing API credentials in wings-info file, skipping Node removal from Panel."
        fi
    fi

    # Remove Wings auto-updater
    output "Removing Wings Auto-Updater..."
    remove_auto_updater_wings 2>/dev/null || true
    rm -rf /var/backups/Wings

    # Stop and remove service
    output "Stopping Wings service..."
    systemctl stop wings 2>/dev/null || true
    systemctl disable wings 2>/dev/null || true

    # Remove binary
    output "Removing Wings binary..."
    rm -f /usr/local/bin/wings

    # Remove configuration
    if [ -d "$WINGS_DIR" ]; then
        output "Removing Wings configuration..."
        rm -rf "$WINGS_DIR"
    fi

    # Stop and remove all game servers (Docker containers)
    output "Stopping all game servers..."
    docker ps -q --filter "name=fly-" | xargs -r docker stop 2>/dev/null || true
    docker ps -aq --filter "name=fly-" | xargs -r docker rm 2>/dev/null || true

    # Remove systemd service
    rm -f /etc/systemd/system/wings.service
    systemctl daemon-reload

    # Remove Wings data directory
    if [ -d "/var/lib/pterodactyl" ]; then
        output "Removing Wings data directory..."
        rm -rf /var/lib/pterodactyl
    fi

    # Remove Wings install info and version
    rm -f /etc/hydrodactyl/Wings-version
    rm -f /etc/hydrodactyl/install-info/wings-info

    # Remove Hydrodactyl user (if it exists)
    if id -u Hydrodactyl >/dev/null 2>&1; then
        output "Removing Hydrodactyl user..."
        userdel Hydrodactyl 2>/dev/null || true
        groupdel Hydrodactyl 2>/dev/null || true
    fi

    success "Wings removed"
}

remove_auto_updaters() {
    print_flame "Removing Auto-Updaters"

    # Remove panel auto-updater
    remove_auto_updater_panel

    # Remove Wings auto-updater
    remove_auto_updater_wings

    # Remove backup directories
    rm -rf /var/backups/Hydrodactyl
    rm -rf /var/backups/Wings

    # Remove /etc/hydrodactyl directory if empty
    if [ -d "/etc/hydrodactyl" ]; then
        rmdir /etc/hydrodactyl 2>/dev/null || true
    fi

    success "Auto-updaters removed"
}

remove_database() {
    print_flame "Removing Database"

    output "This will remove the panel database and database user."

    if [ -f /root/.config/Hydrodactyl/db-credentials ]; then
        local db_root_pass
        db_root_pass=$(grep '^root:' /root/.config/Hydrodactyl/db-credentials | cut -d':' -f2)

        # Drop database
        output "Dropping database 'panel'..."
        mysql -u root -p"${db_root_pass}" -e "DROP DATABASE IF EXISTS panel;" 2>/dev/null || warning "Could not drop database"

        # Drop user
        output "Dropping database user..."
        mysql -u root -p"${db_root_pass}" -e "DROP USER IF EXISTS 'Hydrodactyl'@'localhost';" 2>/dev/null || true
        mysql -u root -p"${db_root_pass}" -e "DROP USER IF EXISTS 'Hydrodactyl'@'127.0.0.1';" 2>/dev/null || true
        mysql -u root -p"${db_root_pass}" -e "DROP USER IF EXISTS 'Hydrodactyl'@'%';" 2>/dev/null || true
        mysql -u root -p"${db_root_pass}" -e "FLUSH PRIVILEGES;" 2>/dev/null || true

        # Remove credentials file
        rm -f /root/.config/Hydrodactyl/db-credentials
        rmdir /root/.config/Hydrodactyl 2>/dev/null || true
        rmdir /root/.config 2>/dev/null || true

        success "Database removed"
    else
        warning "Database credentials not found. You may need to manually remove the database."
    fi
}

remove_phpmyadmin() {
    print_flame "Removing phpMyAdmin"

    output "Removing phpMyAdmin configuration..."

    # Get root password if available
    local db_root_pass=""
    if [ -f /root/.config/Hydrodactyl/db-credentials ]; then
        db_root_pass=$(grep '^root:' /root/.config/Hydrodactyl/db-credentials | cut -d':' -f2)
    fi

    # Drop phpmyadmin database users
    if [ -n "$db_root_pass" ]; then
        output "Dropping phpMyAdmin database users..."
        mysql -u root -p"${db_root_pass}" -e "DROP USER IF EXISTS 'phpmyadmin'@'localhost';" 2>/dev/null || true
        mysql -u root -p"${db_root_pass}" -e "DROP USER IF EXISTS 'phpmyadmin'@'127.0.0.1';" 2>/dev/null || true
        mysql -u root -p"${db_root_pass}" -e "DROP USER IF EXISTS 'phpmyadmin'@'%';" 2>/dev/null || true
        mysql -u root -p"${db_root_pass}" -e "FLUSH PRIVILEGES;" 2>/dev/null || true
    fi

    # Remove nginx config
    rm -f /etc/nginx/sites-available/phpmyadmin.conf
    rm -f /etc/nginx/sites-enabled/phpmyadmin.conf

    # Reload nginx
    if systemctl is-active --quiet nginx; then
        nginx -t && systemctl reload nginx
    fi

    # Remove phpMyAdmin config files
    rm -f /etc/phpmyadmin/conf.d/99-custom.php

    # Remove phpMyAdmin credentials from file
    if [ -f /root/.config/Hydrodactyl/db-credentials ]; then
        sed -i '/^phpmyadmin:/d' /root/.config/Hydrodactyl/db-credentials
    fi

    # Purge debconf database for clean reinstall
    output "Purging phpMyAdmin debconf database..."
    echo "PURGE" | debconf-communicate phpmyadmin 2>/dev/null || true

    success "phpMyAdmin configuration removed"
}

remove_data() {
    print_flame "Removing Data Files"

    output "This will remove all server data, backups, and eggs."

    if [ -d "$PANEL_DATA_DIR" ]; then
        output "Removing data directory: $PANEL_DATA_DIR"
        rm -rf "$PANEL_DATA_DIR"
    fi

    # Remove any remaining Docker volumes
    output "Removing Docker volumes..."
    docker volume ls -q --filter "name=Hydrodactyl" | xargs -r docker volume rm 2>/dev/null || true

    success "Data files removed"
}

cleanup_packages() {
    print_flame "Cleaning up packages"

    output "Would you like to remove the installed packages (nginx, php, mariadb, etc.)?"
    output "Warning: This may affect other services on your system."

    local remove_packages=""
    bool_input remove_packages "Remove packages?" "n"

    if [ "$remove_packages" == "y" ]; then
        output "Removing packages..."

        case "$OS" in
            ubuntu | debian)
                apt-get remove -y \
                    php8.4-fpm php8.4-cli php8.4-gd php8.4-mysql \
                    php8.4-pdo php8.4-mbstring php8.4-tokenizer \
                    php8.4-bcmath php8.4-xml php8.4-curl php8.4-zip \
                    php8.4-intl php8.4-redis php8.4-sqlite3 \
                    nginx mariadb-server redis-server \
                    2>/dev/null || warning "Some packages may not have been installed"

                apt-get autoremove -y
                ;;

            rocky | almalinux)
                dnf remove -y \
                    php-fpm php-cli php-gd php-mysqlnd \
                    php-pdo php-mbstring php-tokenizer \
                    php-bcmath php-xml php-curl php-zip \
                    php-intl php-redis php-sqlite3 \
                    nginx mariadb-server redis \
                    2>/dev/null || warning "Some packages may not have been installed"
                ;;
        esac

        success "Packages removed"
    fi
}

main() {
    print_header
    print_flame "Starting Uninstallation"

    # Remove components based on what was requested
    if [ "$REMOVE_AUTO_UPDATERS" == "true" ]; then
        remove_auto_updaters
    fi

    if [ "$REMOVE_PANEL" == "true" ]; then
        remove_panel
        remove_phpmyadmin
    fi

    if [ "$REMOVE_WINGS" == "true" ]; then
        remove_wings
    fi

    if [ "$REMOVE_DATABASE" == "true" ]; then
        remove_database
    fi

    if [ "$REMOVE_DATA" == "true" ]; then
        remove_data
    fi

    # Ask about package cleanup only if removing everything
    if [ "$REMOVE_PANEL" == "true" ] && [ "$REMOVE_WINGS" == "true" ]; then
        cleanup_packages
    fi

    print_header
    print_flame "Uninstallation Complete!"

    echo ""
    output "Hydrodactyl has been uninstalled from your system."
    output ""
    output "Note: Some configuration files may remain in:"
    output "  ${COLOR_BLUE_THEME}/etc/nginx/${COLOR_NC}"
    output "  ${COLOR_BLUE_THEME}/etc/mysql/${COLOR_NC}"
    output "  ${COLOR_BLUE_THEME}/etc/redis/${COLOR_NC}"
    output ""
    output "If you no longer need these services, you can remove them manually."

    print_brake 70
}

main
