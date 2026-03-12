# zukka CS 1.6 LAN Party Server System

A Docker-based multi-server setup for Counter-Strike 1.6 LAN parties, hosted by zukka LAN Community. This system provides four different game modes for up to 16 players and is part of the zukka LAN event infrastructure at [lan.zukkafabrik.de](https://lan.zukkafabrik.de).

## Features

- **Four Game Mode Servers**:
  - **Tournament Server**: 5v5 competitive matches on empty maps (12 slots: 5v5 + 2 spectators)
  - **Team Deathmatch Server**: Casual team-based play for up to 16 players
  - **FFA Deathmatch Server**: Free-for-all with instant respawn for up to 16 players
  - **GunGame Server**: Weapon progression mode for up to 16 players with AMX Mod X plugin

- **LAN Party Ready**:
  - Simple deployment with Docker Compose
  - Configurable ports via environment variables
  - RCON administration tools included
  - Contact: lan@zukkafabrik.de

- **Modern CS 1.6 Stack**:
  - ReHLDS (Reverse-engineered Half-Life Dedicated Server)
  - ReGameDLL (Enhanced game logic for competitive features)
  - ReUnion (SteamID hash and anti-cheat improvements)
  - AMX Mod X 1.8.2 with GunGame plugin pre-installed
  - Metamod-r (Plugin loader)
  - **YaPB 4.4.957**: Advanced AI bots for team deathmatch and FFA servers

- **Dockerized Deployment**:
  - Isolated containers for each server
  - Persistent configuration via bind mounts
  - Easy management scripts for LAN events
  - Port configuration via .env file

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Python 3.x (for server query tool)

### Starting All Servers

```bash
docker compose up -d
```

### Starting Individual Servers

```bash
docker compose up tournament-server -d
docker compose up public-server -d
docker compose up practice-server -d
docker compose up gungame-server -d
```

### Checking Server Status

```bash
docker compose ps
docker compose logs tournament-server --tail=20
```

### Stopping Servers

```bash
docker compose down
```

## Server Details

| Server     | Port  | Max Players | Description                     | RCON Password                   |
| ---------- | ----- | ----------- | ------------------------------- | ------------------------------- |
| Tournament | 27015 | 12          | 5v5 competitive on empty maps   | `zukka_tournament_rcon_secure`  |
| Public     | 27016 | 16          | Team Deathmatch, casual play    | `zukka_public_rcon_secure`      |
| Practice   | 27017 | 16          | FFA Deathmatch, instant respawn | `zukka_practice_rcon_secure`    |
| GunGame    | 27018 | 16          | Weapon progression mode         | `zukka_gungame_rcon_secure`     |
| TDM Bots   | 27019 | 16          | Team Deathmatch with AI bots    | `zukka_public_bots_rcon_secure` |
| FFA Bots   | 27020 | 16          | FFA Deathmatch with AI bots     | `zukka_ffa_bots_rcon_secure`    |
| Surf       | 27021 | 16          | Movement-based surf gameplay    | `zukka_surf_rcon_secure`        |
| Aim        | 27022 | 16          | Fast-paced aim training maps    | `zukka_aim_rcon_secure`         |

### Tournament Server (CS 2v2 Competitive)

- **Hostname**: "zukka CS 2v2 Tournament - Competitive CS 1.6"
- **Format**: MR15, Best of 1 maps
- **Settings**: Friendly fire ON, 5s freezetime, team talk only
- **Map Pool**: de_dust2, de_inferno, cs_office, de_train, de_nuke, de_cbble, cs_italy, de_aztec, cs_militia, de_dust
- **Tournament Integration**: Connects to zukka tournament brackets at hub.zukkafabrik.de

### Public Server (Casual Community Play)

- **Hostname**: "zukka CS 1.6 Public Server - Casual Fun"
- **Format**: Casual 20-minute timelimit
- **Settings**: Friendly fire OFF, all-talk enabled
- **Map Pool**: 19 popular maps including de_dust2, de_inferno, de_nuke, cs_office, cs_italy, etc.

### Practice Server (Skill Development)

- **Hostname**: "zukka CS 1.6 Practice Server - Training Ground"
- **Features**: Unlimited money ($16,000), 60s buy time, no round limit, cheats enabled
- **Useful Commands**: `impulse 101`, `sv_gravity 200`, `sv_infinite_ammo 1`, `noclip`, `god`
- **Map Pool**: 12 standard maps for practice

## Tournament Server Focus

The tournament server is configured specifically for zukka tournament brackets:

### Starting a Tournament Match

1. **Set Match Password** (via RCON or tournament hub):

   ```bash
   rcon_password zukka_tournament_rcon_secure
   rcon sv_password "match_specific_password"
   ```

2. **Configure Match Settings** (pre-configured for 2v2):

   ```bash
   # Standard tournament settings already loaded
   rcon mp_restartgame 1  # Restart match with current settings
   rcon map de_dust2      # Change to tournament map
   ```

3. **Tournament Administration**:
   - Max players: 8 (4 players + 4 spectators)
   - Teams auto-balanced to 2v2
   - Dead players can only spectate teammates
   - Detailed logging enabled for match review

### Tournament Hub Integration

- Tournament brackets managed at: [hub.zukkafabrik.de](https://hub.zukkafabrik.de)
- Event information at: [lan.zukkafabrik.de](https://lan.zukkafabrik.de)
- Contact tournament organizers: lan@zukkafabrik.de

### Connecting Players

Players connect using tournament information from the hub:

```
connect [SERVER_IP]:27015; password [TOURNAMENT_PASSWORD]

# Team Deathmatch
connect [SERVER_IP]:27016

# FFA Deathmatch
connect [SERVER_IP]:27017

# GunGame
connect [SERVER_IP]:27018

# Team Deathmatch with Bots
connect [SERVER_IP]:27019

# FFA Deathmatch with Bots
connect [SERVER_IP]:27020

# Surf
connect [SERVER_IP]:27021

# Aim
connect [SERVER_IP]:27022
```

## Configuration

### Server Configuration Files

Each server has its own configuration directory under `servers/` with zukka branding:

```
servers/
├── tournament/
│   ├── server.cfg      # Tournament server configuration
│   ├── mapcycle.txt    # Tournament map rotation
│   └── motd.txt        # Tournament MOTD with console-style design
├── public/
│   ├── server.cfg      # Team Deathmatch server configuration
│   ├── mapcycle.txt    # Team Deathmatch map rotation
│   └── motd.txt        # Team Deathmatch MOTD
├── practice/
│   ├── server.cfg      # FFA Deathmatch server configuration
│   ├── mapcycle.txt    # FFA Deathmatch map rotation
│   └── motd.txt        # FFA Deathmatch MOTD
├── gungame/
│   ├── server.cfg      # GunGame server configuration
│   ├── mapcycle.txt    # GunGame map rotation
│   └── motd.txt        # GunGame MOTD
├── tdm-bots/
│   ├── server.cfg      # TDM with Bots server configuration
│   ├── mapcycle.txt    # TDM with Bots map rotation
│   └── motd.txt        # TDM with Bots MOTD
├── ffa-bots/
│   ├── server.cfg      # FFA with Bots server configuration
│   ├── mapcycle.txt    # FFA with Bots map rotation
│   └── motd.txt        # FFA with Bots MOTD
├── surf/
│   ├── server.cfg      # Surf server configuration
│   ├── mapcycle.txt    # Surf map rotation
│   └── motd.txt        # Surf MOTD
└── aim/
    ├── server.cfg      # Aim server configuration
    ├── mapcycle.txt    # Aim map rotation
    └── motd.txt        # Aim MOTD
```

### Map Downloads

Some servers use custom maps that need to be downloaded separately:

1. **Surf Server** (`surf_water-run_2`):
   - Download: `https://share.monocu.be/cs1.6-maps/surf/surf_water-run_2/`
   - Place in your CS 1.6 `maps/` folder

2. **Aim Server** (`aim_b0n0_d8c71`):
   - Download: `https://share.monocu.be/cs1.6-maps/aim_b0n0_d8c71.rar`
   - Extract and place `.bsp` file in your CS 1.6 `maps/` folder

**Note**: The servers will fall back to `de_dust2` if custom maps are not available on the server. Players can still connect and play.

### Customizing Configuration

1. Edit the respective `.cfg` files in the `servers/` directory
2. Restart the corresponding container:
   ```bash
   docker compose restart tournament-server
   docker compose restart gungame-server
   ```

### Adding Custom Maps

1. Place `.bsp` files in a directory on your host
2. Mount the directory to the container (modify `docker-compose.yml`):
   ```yaml
   volumes:
     - ./custom_maps:/opt/steam/hlds/cstrike/maps:ro
   ```
3. Add map names to the appropriate `mapcycle.txt`

## Docker Compose Structure

The `docker-compose.yml` defines three services with:

- **Platform**: Linux/amd64 (emulated on ARM via Rosetta 2)
- **Security**: `seccomp:unconfined` for GoldSrc compatibility
- **Environment**: `GLIBC_TUNABLES=glibc.rtld.execstack=2` for glibc 2.41+
- **Volumes**: Configuration files mounted read-only
- **Ports**: Host ports 27015-27018 mapped to container port 27015

## Query Tool

A Python script `query_server.py` is included to query server status:

```bash
# Query specific server
python3 query_server.py localhost 27015

# Query all zukka servers
python3 query_server.py --list

# Show all technical details
python3 query_server.py localhost 27015 --all

# Test GunGame server
python3 query_server.py localhost 27018
```

The tool uses the A2S_INFO protocol to retrieve server information including hostname, map, player count, and VAC status.

## Management Script

The `manage.sh` script provides easy server management:

```bash
# Check status of all servers
./manage.sh status

# Start tournament server
./manage.sh start tournament

# Query tournament server information
./manage.sh query tournament

# View tournament server logs
./manage.sh logs tournament

# Update configuration and restart
./manage.sh update tournament
```

## Troubleshooting

### Platform Warning

If you see: `The requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64/v8)`

- This is expected on Apple Silicon (ARM) Macs
- Docker will emulate x86_64 via Rosetta 2
- Server functionality is not affected

### Server Not Responding

1. Check if container is running:
   ```bash
   docker compose ps
   ```
2. Check logs for errors:
   ```bash
   docker compose logs tournament-server
   ```
3. Verify port availability:
   ```bash
   netstat -an | grep 27015
   netstat -an | grep 27018
   ```

### Configuration Not Loading

1. Ensure config files are mounted correctly:
   ```bash
   docker exec cs16-tournament cat /opt/steam/hlds/cstrike/config/server.cfg
   ```
2. Check file permissions (should be readable by `steam` user in container)

### Steam API Errors

Warnings about `steamclient.so` and Steam API failures are normal for ReHLDS servers and don't affect gameplay.

## Building from Source

To rebuild the Docker image with ReUnion:

```bash
docker compose build
```

The Dockerfile:

1. Uses `ghcr.io/blsalin/rehlds-cstrike:latest` as base
2. Installs ReUnion plugin
3. Configures SteamID hash salt
4. Adds ReUnion to Metamod plugins

## RCON Administration

Use RCON clients like HLSW, GameTracker, or command-line tools:

```bash
# Example using rcon-cli (install via npm install -g rcon-cli)
rcon-cli --host localhost --port 27015 --password zukka_tournament_rcon_secure status

# Test GunGame server RCON
python3 rcon_test.py gungame test
python3 rcon_test.py gungame cmd "status"
```

Common RCON commands:

- `status` - Server status
- `map de_dust2` - Change map
- `kick #USERID#` - Kick player
- `banid 0.0 #STEAMID# kick` - Ban player

## License

This project uses the ReHLDS, ReGameDLL, and ReUnion projects which have their own licenses. The Docker configuration and server setups are provided under the MIT License.

## zukka Integration

This server system is designed to integrate with the zukka tournament infrastructure:

- **Tournament Hub**: [hub.zukkafabrik.de](https://hub.zukkafabrik.de) - Tournament brackets and management
- **LAN Event Info**: [lan.zukkafabrik.de](https://lan.zukkafabrik.de) - Event schedules and information
- **Contact**: lan@zukkafabrik.de

## Acknowledgements

- [ReHLDS Team](https://github.com/ReHLDS) - Reverse-engineered HLDS
- [ReGameDLL](https://github.com/s1lentq/ReGameDLL_CS) - Enhanced game logic
- [ReUnion](https://github.com/rehlds/ReUnion) - SteamID and anti-cheat improvements
- [blsalin/rehlds-cstrike](https://github.com/blsalin/rehlds-cstrike) - Docker base image
- **zukka Community** - Tournament organization and LAN events

## YaPB Bot Integration

The system includes **YaPB (Yet Another PodBot)** for advanced AI bots in team deathmatch and FFA servers:

- **Pre-installed YaPB 4.4.957**: Advanced bot AI with waypoint navigation
- **Automatic bot filling**: Bots automatically join empty servers and leave when real players connect
- **Configurable difficulty**: Five difficulty levels from easy to nightmare
- **Enhanced behavior**: Bots use grenades, pick up weapons, and communicate via radio
- **Metamod integration**: Loads automatically via Metamod plugin system

### Configuration

YaPB is configured in the server configuration files:

- **Team Deathmatch with Bots** (`servers/tdm-bots/server.cfg`): YaPB settings for team-based play
- **FFA Deathmatch with Bots** (`servers/ffa-bots/server.cfg`): YaPB settings for free-for-all

### YaPB Commands

Common YaPB console commands:

```bash
yb_add                  # Add a bot
yb_kick                 # Remove all bots
yb_difficulty 2         # Set bot difficulty (0-4)
yb_quota 10             # Set maximum number of bots
yb_fill_server          # Fill server with bots
```

### Customizing Bot Behavior

Edit the `yapb.cfg` file in the server's cstrike directory for advanced configuration:

- Bot names and skins
- Weapon preferences
- Navigation waypoints
- Communication settings

The YaPB plugin is automatically included in the Docker image and requires no additional setup.

## Support

For tournament and server issues:

1. Check tournament information at [hub.zukkafabrik.de](https://hub.zukkafabrik.de)
2. Review server logs with `docker compose logs`
3. Contact tournament organizers: lan@zukkafabrik.de
4. Update configuration files in `servers/` directory for server-specific changes

```

```
