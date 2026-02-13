<p align="center">
  <img width="1467" height="401" alt="image" src="https://github.com/user-attachments/assets/7d5138a4-acd0-43e5-932b-419c5125c0d7" />
</p>

<p align="center">
  <!-- <a href="https://github.com/Muspelheim-Hosting/pyrodactyl-installer/releases"><img src="https://img.shields.io/github/v/release/Muspelheim-Hosting/pyrodactyl-installer?style=for-the-badge&color=orange" alt="Release"></a> -->
  <a href="https://github.com/Muspelheim-Hosting/pyrodactyl-installer/blob/main/LICENSE"><img src="https://img.shields.io/github/license/Muspelheim-Hosting/pyrodactyl-installer?style=for-the-badge&color=orange" alt="License"></a>
</p>

A beautiful, modern, and feature-rich installer for **Pyrodactyl Panel** and **Elytra Daemon**. Built with an elegant flame-inspired UI and designed for ease of use.

## ✨ Features

- 🎨 **Beautiful Flame UI** - Orange gradient interface inspired by Muspelheim Hosting
- 📦 **Flexible Installation** - Install panel, Elytra, or both on the same machine
- 🔒 **Private Repository Support** - Full support for private GitHub repositories with token validation
- 🔄 **Auto-Updaters** - Optional automatic updates for both panel and Elytra
- 🌐 **SSL/TLS Ready** - Let's Encrypt integration and custom certificate support
- 🛡️ **Firewall Configuration** - Automatic UFW/FirewallD setup
- 📊 **OS Support** - Ubuntu 22.04/24.04, Debian 11/12, Rocky Linux 8/9, AlmaLinux 8/9
- 🗄️ **Database Management** - Automated MariaDB setup and configuration
- 🐳 **Docker Integration** - Seamless Docker installation for Elytra

## 🚀 Quick Start

```bash
bash <(curl -sSL https://pyrodactyl-installer.muspelheim.host)
```

Or download and run:

```bash
curl -sSL https://raw.githubusercontent.com/Muspelheim-Hosting/pyrodactyl-installer/main/install.sh -o install.sh
bash install.sh
```

## 📋 Requirements

### Minimum Requirements

| Component | Specification |
|-----------|--------------|
| **CPU** | 2 cores (x86_64 or ARM64) |
| **RAM** | 2 GB |
| **Storage** | 20 GB SSD |
| **Network** | Public IPv4 or IPv6 |
| **OS** | Ubuntu 22.04/24.04, Debian 11/12, Rocky Linux 8/9, AlmaLinux 8/9 |

### Recommended Requirements

| Component | Specification |
|-----------|--------------|
| **CPU** | 4+ cores |
| **RAM** | 4+ GB |
| **Storage** | 50+ GB SSD |
| **Network** | Both IPv4 and IPv6 |

## 🔧 Installation Options

<img width="848" height="504" alt="image" src="https://github.com/user-attachments/assets/9974e217-f667-4488-8a13-8745a9d2498f" />

```bash
bash <(curl -sSL https://pyrodactyl-installer.muspelheim.host)
```

## 🔄 Auto-Updater Installation

The installer can set up automatic updates that check for new releases every hour.

### Panel Auto-Updater
- Downloads and installs latest panel release
- Creates backups before updating
- Runs database migrations
- Maintains custom configurations

### Elytra Auto-Updater
- Downloads latest Elytra binary
- Stops service, updates, restarts
- Creates backups of binary and config
- Validates successful restart

## 🔐 Private Repository Support

The installer fully supports private GitHub repositories:

1. Select "private repository" during setup
2. Provide a GitHub Personal Access Token
3. The token is validated for repository access
4. Token is securely stored for auto-updaters

### Creating a GitHub Token

1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Select the `repo` scope
4. Generate and copy the token
5. Paste when prompted by the installer

## 🌟 Custom Repositories

You can install from custom forks or private builds:

### Default Repositories
- **Panel**: `pyrodactyl-oss/pyrodactyl`
- **Elytra**: `pyrohost/elytra`

### Using Custom Repositories

During installation, select "Use custom repository" and provide:
- Repository in `owner/repo` format
- Whether it's public or private
- GitHub token (if private)

### Requirements for Custom Repositories

- Repository must have published releases
- Release must contain the expected assets:
  - Panel: `panel.tar.gz`
  - Elytra: `elytra_linux_amd64` or `elytra_linux_arm64`

### Uninstall Options

- **Panel only**: Removes panel files, database (optional), web server config
- **Elytra only**: Removes binary, configuration, Docker containers
- **Both**: Complete removal of all components
- **Auto-updaters only**: Removes update scripts and timers

## 📁 Directory Structure

```
/var/www/pyrodactyl/         # Panel installation
/etc/elytra/                 # Elytra configuration
/etc/pyrodactyl/             # Panel configuration (Elytra)
/var/lib/pyrodactyl/         # Game server data
/var/log/pyrodactyl-*.log    # Installation/update logs
/var/backups/pyrodactyl/     # Panel backups
/var/backups/elytra/         # Elytra backups
```

## 🔧 Troubleshooting

### Installation Issues

**Error: "No releases found in repository"**
- Ensure your repository has published releases
- For private repos, verify your token has `repo` access

**Error: "Token cannot access repository"**
- Verify the token has not expired
- Check the repository exists and is accessible
- For private repos, ensure token has `repo` scope

**Error: "Unsupported OS"**
- Check your OS is in the supported list
- Ensure you're using a supported version

### Post-Installation Issues

**Panel not accessible**
```bash
systemctl status nginx
systemctl status pyroq
journalctl -u pyroq -f
```

**Elytra not connecting**
```bash
systemctl status elytra
journalctl -u elytra -f
cat /etc/elytra/config.yml
```

**Database connection errors**
```bash
systemctl status mariadb
mysql -u root -p -e "SHOW DATABASES;"
```

### Firewall Issues

If you skipped firewall configuration during install:

**UFW (Ubuntu/Debian)**
```bash
ufw allow 80,443/tcp
ufw allow 8080/tcp
ufw allow 2022/tcp
ufw allow 25500:25600/tcp
ufw allow 25500:25600/udp
```

**FirewallD (Rocky/AlmaLinux)**
```bash
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --permanent --add-port=2022/tcp
firewall-cmd --permanent --add-port=25565-25665/tcp
firewall-cmd --permanent --add-port=25565-25665/udp
firewall-cmd --permanent --add-port=27015-27150/tcp
firewall-cmd --permanent --add-port=27015-27150/udp
firewall-cmd --permanent --add-port=7777-8000/tcp
firewall-cmd --permanent --add-port=7777-8000/udp
firewall-cmd --permanent --add-port=28015-28025/tcp
firewall-cmd --permanent --add-port=28015-28025/udp
firewall-cmd --permanent --add-port=2456-2466/tcp
firewall-cmd --permanent --add-port=2456-2466/udp
firewall-cmd --permanent --add-port=30120-30130/tcp
firewall-cmd --permanent --add-port=30120-30130/udp
firewall-cmd --permanent --add-port=27015-28025/tcp
firewall-cmd --permanent --add-port=27015-28025/udp
firewall-cmd --reload
```

## 📝 Logs

All installation and update operations are logged:

- **Installation**: `/var/log/pyrodactyl-installer.log`
- **Panel Updates**: `/var/log/pyrodactyl-panel-auto-update.log`
- **Elytra Updates**: `/var/log/pyrodactyl-elytra-auto-update.log`

## 🎮 Game Server Ports

The installer automatically opens these specific port ranges for popular games (all TCP & UDP):

| Game/Category | Port Range | Notes |
|--------------|------------|-------|
| **Minecraft** | 25565-25665 | Java & Bedrock editions |
| **Source Engine** | 27015-27150 | CS:GO, TF2, Garry's Mod, Left 4 Dead |
| **Unreal Engine** | 7777-8000 | ARK, Satisfactory (multiple ports per server) |
| **Rust** | 28015-28025 | Game + RCON ports |
| **Valheim** | 2456-2466 | Game + Query ports |
| **FiveM/GTA** | 30120-30130 | GTA V roleplay servers |
| **General Range** | 27015-28025 | Additional ports for other games |

**Total:** 2,000+ ports available for game servers

### Multi-Port Requirements

Some games require multiple consecutive ports per server instance:
- **ARK**: 4 ports (game, query, RCON, steam)
- **Satisfactory**: 3 ports (game, query, beacon)
- **ARMA 3**: 3 ports (game, steam, RCON)
- **Rust**: 3 ports (game, RCON, app)
- **Valheim**: 3 ports (game, query, steam)

With all port ranges combined (approximately 2,000+ ports), you can host:
- **400+** single-port game servers
- **200+** multi-port game servers
- **Mixed environment** of various game types

## 🏗️ Architecture

```
┌─────────────────────────────────────┐
│           Pyrodactyl Panel          │
│   ┌─────────────────────────────┐   │
│   │      Nginx (Web Server)     │   │
│   │    PHP 8.3-FPM + Laravel    │   │
│   └─────────────────────────────┘   │
│   ┌─────────────────────────────┐   │
│   │     MariaDB (Database)      │   │
│   └─────────────────────────────┘   │
│   ┌─────────────────────────────┐   │
│   │   Redis (Queue/Cache)       │   │
│   └─────────────────────────────┘   │
└─────────────────────────────────────┘
                   │
                   │ HTTP/HTTPS
                   ▼
┌─────────────────────────────────────┐
│           Elytra Daemon             │
│   ┌─────────────────────────────┐   │
│   │     HTTP API (Port 8080)    │   │
│   └─────────────────────────────┘   │
│   ┌─────────────────────────────┐   │
│   │   Docker (Game Servers)     │   │
│   └─────────────────────────────┘   │
│   ┌─────────────────────────────┐   │
│   │    SFTP (Port 2022)         │   │
│   └─────────────────────────────┘   │
│   ┌─────────────────────────────┐   │
│   │  Game Ports (27015-28025)   │   │
│   └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Credits

- [Pyrodactyl](https://github.com/pyrodactyl-oss/pyrodactyl) - The panel software
- [Elytra](https://github.com/pyrohost/elytra) - The daemon software
- [Pterodactyl Installer](https://github.com/pterodactyl-installer/pterodactyl-installer) - Inspiration

---

<p align="center">
  <b>🔥 Brought to you by <a href="https://muspelheim.host">Muspelheim Hosting</a> 🔥</b>
</p>
