<div align="center">
  <img src="https://raw.githubusercontent.com/blueprintframework/hydrodactyl/main/public/favicons/apple-touch-icon.png" width="150" alt="Hydrodactyl Logo">
  <h1>Hydrodactyl Installer</h1>
  <p>The official one-line installation script for Hydrodactyl Panel and Wings.</p>
</div>

---

## ⚡ Overview

Hydrodactyl Installer is a robust, automated script designed to set up [Hydrodactyl Panel](https://github.com/blueprintframework/hydrodactyl) and its accompanying daemon (**Wings**) with ease. 

Built and optimized by the **Blueprint Framework** team, this installer takes care of downloading the panel, setting up the Nginx web server, configuring PHP-FPM, initializing MariaDB, and handling the required background workers effortlessly.

## 🚀 Installation

You can install both the Hydrodactyl Panel and the Wings Daemon using our one-line command on any supported Linux distribution.

```bash
bash <(curl -sSL https://raw.githubusercontent.com/blueprintframework/hydrodactyl-installer/main/install.sh)
```

The script will present a menu allowing you to:
- Install the Hydrodactyl Panel
- Install the Wings Daemon
- Install both on the same machine
- Update existing installations
- Configure auto-updaters

### 📦 Supported Operating Systems

- **Ubuntu**: 20.04, 22.04, 24.04
- **Debian**: 11, 12
- **AlmaLinux / Rocky Linux**: 8, 9

## 🛠️ Features

- **Automated Dependency Resolution**: Installs Nginx, PHP (with necessary extensions), Redis, and MariaDB automatically.
- **Auto-Updater**: Optional background jobs to automatically update your Panel and Wings daemon to the latest release.
- **SSL Configuration**: Built-in Let's Encrypt support using Certbot for secure connections out-of-the-box.
- **Firewall Integration**: Automatically configures `ufw` or `firewalld` to open necessary ports.
- **Database Initialization**: Sets up the MariaDB databases and user accounts seamlessly.

## ⚙️ Architecture

Hydrodactyl relies on a modern stack for high performance and reliability:
- **Frontend**: Vite & Turbo powered UI.
- **Backend**: Laravel framework (PHP) with a Redis cache and queue system.
- **Daemon**: Wings (written in Go) running Docker containers for server isolation.

## 🤝 Support & Blueprint Framework

This installer is maintained as part of the **Blueprint Framework** ecosystem.

If you encounter issues with this script, please open an issue in this repository. For general support regarding Hydrodactyl, visit the official community or documentation.

---

*Made with ❤️ by Blueprint.*
