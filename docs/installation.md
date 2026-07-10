# Panel Installation Manager

This repository provides an automated installation manager for popular hosting panels and their respective daemon components. 

Currently supported software suites:
1. **Hydrodactyl** (PHP/Laravel Panel + Go Wings)
2. **Calagopus** (Rust Panel + Rust Wings-RS)

## Installation Methods

Both suites support two primary installation methods:

### 1. Native Installation
Installs the software directly onto your server's host operating system.
* **Hydrodactyl**: Configures Nginx, PHP-FPM, MariaDB, and Redis. Uses Composer to manage dependencies.
* **Calagopus**: Configures PostgreSQL, Valkey (or Redis), and downloads the pre-compiled Rust binary. Configures a systemd service to run the application.

### 2. Docker Installation
Installs the software using Docker Compose for complete isolation and easier management.
* **Hydrodactyl**: Generates a `docker-compose.yml` with MariaDB, Redis, and Panel containers.
* **Calagopus**: Generates a `docker-compose.yml` with PostgreSQL, Valkey, and Panel containers.

## How to Run

Simply run the unified installer script:

```bash
bash install.sh
```

You will be prompted to:
1. Choose the **Software Suite** (Hydrodactyl or Calagopus).
2. Choose what to install (Panel, Wings, or Both).
3. Confirm or change the target GitHub repository (useful if you are maintaining a custom fork of the software).
4. Choose the installation method (Native vs Docker).
5. Provide standard configuration details (Domain, Database, Admin credentials).

## Progress / Features Tracking

- [x] Unify installer entrypoint (`install.sh`).
- [x] Support for custom GitHub repository definitions for both Panel and Wings.
- [x] Support for Hydrodactyl (Native and Docker).
- [ ] Support for Calagopus Panel (Native and Docker).
- [ ] Support for Calagopus Wings / Wings-RS (Native and Docker).
