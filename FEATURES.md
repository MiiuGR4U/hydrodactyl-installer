# 🔥 Pyrodactyl Installer - Features & Game Support

## 🎮 Game Server Port Configuration

The Pyrodactyl Installer comes with comprehensive game server support out of the box. When installing the Elytra daemon (either standalone or with the panel), the installer automatically opens **specific port ranges** for popular games, plus a general range for other games.

### Pre-Configured Port Ranges

The following port ranges are **automatically opened** (both TCP and UDP):

| Game Category | Port Range | Games |
|--------------|------------|-------|
| **Minecraft** | 25565-25665 | Java & Bedrock editions |
| **Source Engine** | 27015-27150 | CS:GO, TF2, GMod, L4D |
| **Unreal Engine** | 7777-8000 | ARK, Satisfactory |
| **Rust** | 28015-28025 | Game + RCON |
| **Valheim** | 2456-2466 | Game + Query |
| **FiveM/GTA** | 30120-30130 | GTA V roleplay |
| **General Range** | 27015-28025 | Other Pterodactyl eggs |

**Total:** 2,000+ ports available for game servers

### Supported Games by Category

#### 🧱 Sandbox & Building
| Game | Ports Used | Notes |
|------|-----------|-------|
| **Minecraft (Java)** | 25565 | Default + mods support |
| **Minecraft (Bedrock)** | 19132-19133 | UDP only |
| **Terraria** | 7777 | Default TShock port |
| **Factorio** | 34197 | Default multiplayer |
| **Satisfactory** | 7777, 15000, 15777 | 3 ports required |

#### 🔫 FPS & Source Engine
| Game | Ports Used | Notes |
|------|-----------|-------|
| **Counter-Strike: Global Offensive** | 27015-27020 | Game + SourceTV |
| **Counter-Strike 1.6** | 27015 | Classic port |
| **Team Fortress 2** | 27015-27020 | Game + SourceTV |
| **Garry's Mod** | 27015 | Default |
| **Left 4 Dead 2** | 27015 | Default |
| **Insurgency** | 27015 | Source engine |
| **Day of Defeat: Source** | 27015 | Classic Source |

#### 🦕 Survival & Adventure
| Game | Ports Used | Notes |
|------|-----------|-------|
| **ARK: Survival Evolved** | 7777-7778, 27015, 32330 | 4 ports (game, query, steam, rcon) |
| **Rust** | 28015, 28016, 28082 | Game + RCON + App |
| **Valheim** | 2456-2458 | Game + Query + Steam |
| **Palworld** | 8211 | Default multiplayer |
| **7 Days to Die** | 26900-26905 | Multiple services |
| **Project Zomboid** | 16261-16262 | Default ports |

#### 🚗 Roleplay & Racing
| Game | Ports Used | Notes |
|------|-----------|-------|
| **FiveM (GTA V)** | 30120 | Primary port |
| **RedM (RDR2)** | 30120 | Same as FiveM |
| **Assetto Corsa** | 9600 | Default |
| **BeamMP (BeamNG)** | 30814 | Default |

#### ⚔️ Strategy & MMO
| Game | Ports Used | Notes |
|------|-----------|-------|
| **Starbound** | 21025 | Default |
| **Don't Starve Together** | 10999-11000 | Default |
| **Vintage Story** | 42420 | Default |

### Multi-Port Game Requirements

Some games require multiple consecutive ports per server instance. The installer accounts for this:

| Game | Ports Needed | Allocation |
|------|-------------|------------|
| **ARK** | 4 ports | game, query, steam, rcon |
| **Satisfactory** | 3 ports | game, query, beacon |
| **ARMA 3** | 3 ports | game, steam, rcon |
| **Rust** | 3 ports | game, rcon, app |
| **Valheim** | 3 ports | game, query, steam |

### Port Allocation Strategy

With all port ranges combined (2,000+ ports), you can host approximately:

- **400+** single-port games (Minecraft, CS:GO, etc.)
- **200+** multi-port games (ARK, Satisfactory, Rust)
- **Mixed environment** of various game types

### Custom Port Ranges

During installation, you can customize the port range:

```bash
? Configure game server port range
Popular games use these ports:
  - Minecraft: 25565-25665
  - Source Engine (CS:GO, TF2, GMod): 27015-27150
  - ARK, Satisfactory: 7777-8000
  - Rust: 28015-28025
? Start port [27015]: 
? End port [28025]: 
```

**Note:** Some games have hardcoded default ports. While you can allocate any range, players may need to specify custom ports when connecting if you don't use the game's default.

## 🛡️ Firewall Configuration

The installer automatically configures both **TCP** and **UDP** for all game ports, as different games use different protocols:

### Protocol Usage by Game Type

| Protocol | Used By |
|----------|---------|
| **TCP** | Minecraft RCON, Source RCON, Web-based games |
| **UDP** | Most game traffic, Steam queries, heartbeat |
| **Both** | Most modern multiplayer games |

### Firewall Rules Applied

When you select "Yes" to firewall configuration:

```bash
# Always opened
22    (SSH - TCP)
80    (HTTP - TCP)
443   (HTTPS - TCP)
8080  (Elytra API - TCP)
2022  (SFTP - TCP)

# Game ports (both TCP and UDP)
25565-25665  (Minecraft)
27015-27150  (Source Engine)
7777-8000    (Unreal Engine)
28015-28025  (Rust)
2456-2466    (Valheim)
30120-30130  (FiveM/GTA)
27015-28025  (General range)
```

### Manual Firewall Configuration

If you skipped firewall setup during installation:

**UFW (Ubuntu/Debian):**
```bash
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8080/tcp
ufw allow 2022/tcp
# Minecraft
ufw allow 25565:25665/tcp
ufw allow 25565:25665/udp
# Source Engine
ufw allow 27015:27150/tcp
ufw allow 27015:27150/udp
# Unreal Engine
ufw allow 7777:8000/tcp
ufw allow 7777:8000/udp
# Rust
ufw allow 28015:28025/tcp
ufw allow 28015:28025/udp
# Valheim
ufw allow 2456:2466/tcp
ufw allow 2456:2466/udp
# FiveM
ufw allow 30120:30130/tcp
ufw allow 30120:30130/udp
ufw reload
```

**FirewallD (Rocky/AlmaLinux):**
```bash
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --permanent --add-port=2022/tcp
# Minecraft
firewall-cmd --permanent --add-port=25565-25665/tcp
firewall-cmd --permanent --add-port=25565-25665/udp
# Source Engine
firewall-cmd --permanent --add-port=27015-27150/tcp
firewall-cmd --permanent --add-port=27015-27150/udp
# Unreal Engine
firewall-cmd --permanent --add-port=7777-8000/tcp
firewall-cmd --permanent --add-port=7777-8000/udp
# Rust
firewall-cmd --permanent --add-port=28015-28025/tcp
firewall-cmd --permanent --add-port=28015-28025/udp
# Valheim
firewall-cmd --permanent --add-port=2456-2466/tcp
firewall-cmd --permanent --add-port=2456-2466/udp
# FiveM
firewall-cmd --permanent --add-port=30120-30130/tcp
firewall-cmd --permanent --add-port=30120-30130/udp
firewall-cmd --reload
```

## 🌐 Panel Allocation Setup

When installing both Panel and Elytra, the installer automatically creates allocations in the database:

```sql
INSERT INTO panel.allocations (node_id, ip, port) 
VALUES (1, '0.0.0.0', 27015),
       (1, '0.0.0.0', 27016),
       ... through 28025
```

These allocations appear in the Panel's "Allocations" tab and can be assigned to game servers.

## 🔄 Updating Game Port Range

If you need to expand your port range after installation:

1. **Via Panel:** Go to Admin → Nodes → Your Node → Allocation → Create New
2. **Via Database:** Insert new ports into the `allocations` table
3. **Via Firewall:** Open additional ports in UFW/FirewallD

## 📊 Port Reference Table

| Port Range | Purpose |
|------------|---------|
| 22 | SSH (admin access) |
| 80 | HTTP (web redirect) |
| 443 | HTTPS (panel web) |
| 8080 | Elytra API (panel communication) |
| 2022 | SFTP (file transfers) |
| 25565-25665 | Minecraft (Java & Bedrock) |
| 27015-27150 | Source Engine games |
| 7777-8000 | Unreal Engine games |
| 28015-28025 | Rust |
| 2456-2466 | Valheim |
| 30120-30130 | FiveM/GTA |
| 27015-28025 | General game range |

## 🎯 Best Practices

1. **Start with default range** (27015-28025) - covers 99% of use cases
2. **Allocate ports sequentially** - easier to manage and firewall
3. **Reserve 100+ ports** for multi-port games like ARK
4. **Document custom ports** - if using non-default ports, inform your users
5. **Monitor port usage** - check Panel's allocation page for usage statistics

## 🐛 Troubleshooting

### "Port already in use" error
- Check if another service is using the port: `ss -tulpn | grep :27015`
- Use a different port from your allocated range

### Game not appearing in server browser
- Ensure UDP is open for the game port
- Check Steam query port is allocated (usually game port + 1)

### Cannot connect to game server
- Verify firewall rules allow both TCP and UDP
- Check Elytra logs: `journalctl -u elytra -f`
- Ensure allocation exists in Panel for the port

### SFTP connection issues
- Port 2022 must be open in firewall
- Use SFTP (not FTP) protocol in your client

---

<p align="center">
  <b>🔥 Happy hosting with Pyrodactyl! 🔥</b>
</p>