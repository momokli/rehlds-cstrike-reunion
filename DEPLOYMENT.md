# zukka CS 1.6 LAN Party Server System Deployment Guide

## Overview

This guide covers the deployment and management of the zukka CS 1.6 LAN Party Server System on a production server. The system includes eight distinct Counter-Strike 1.6 servers:

1. **Tournament Server** (Port 27015): 5v5 competitive matches on empty maps
2. **Team Deathmatch Server** (Port 27016): Casual team-based play for up to 16 players
3. **FFA Deathmatch Server** (Port 27017): Free-for-all with instant respawn
4. **GunGame Server** (Port 27018): Weapon progression mode for up to 16 players
5. **Team Deathmatch with Bots** (Port 27019): Casual team play with AI bots
6. **FFA Deathmatch with Bots** (Port 27020): Free-for-all with AI bots and instant respawn
7. **Surf Server** (Port 27021): Movement-based surf gameplay with default map surf_water-run_2
8. **Aim Server** (Port 27022): Fast-paced aim training with default map aim_b0n0_d8c71

## Prerequisites

### Server Requirements

- **OS**: Linux (Ubuntu 20.04+ recommended, but any Docker-compatible Linux)
- **CPU**: 2+ cores (4+ recommended for running all eight servers)
- **RAM**: 4GB+ (8GB+ recommended)
- **Storage**: 10GB+ free space
- **Network**: Public IP address with ports 27015-27022 TCP/UDP open

### Software Requirements

- **Docker**: Version 20.10+ [Install Guide](https://docs.docker.com/engine/install/)
- **Docker Compose**: Version 2.0+ [Install Guide](https://docs.docker.com/compose/install/)
- **Git**: Latest version
- **Python 3**: For management tools (optional but recommended)

### Network Configuration

Ensure the following ports are open in your firewall:

```bash
# Tournament Server
27015/tcp
27015/udp

# Team Deathmatch Server
27016/tcp
27016/udp

# FFA Deathmatch Server
27017/tcp
27017/udp

# GunGame Server
27018/tcp
27018/udp

# Team Deathmatch with Bots
27019/tcp
27019/udp

# FFA Deathmatch with Bots
27020/tcp
27020/udp

# Surf Server
27021/tcp
27021/udp

# Aim Server
27022/tcp
27022/udp
```

## Initial Deployment

### 1. Clone the Repository

```bash
# Clone the repository to your server
git clone git@github.com:momokli/rehlds-cstrike-reunion.git
cd rehlds-cstrike-reunion

# Or clone via HTTPS if SSH keys aren't configured
git clone https://github.com/momokli/rehlds-cstrike-reunion.git
cd rehlds-cstrike-reunion
```

### 2. Set Up Environment Configuration

```bash
# Copy the environment template
cp .env.example .env

# Edit the .env file with your server configuration
nano .env
```

**Key .env Variables to Configure:**

```bash
# External server IP (for server listings and MOTD)
SERVER_EXTERNAL_IP="your.public.ip.address"

# Tournament server password (set via tournament hub)
# TOURNAMENT_MATCH_PASSWORD="match_specific_password_here"

# RCON passwords (change from defaults for security)
TOURNAMENT_RCON_PASSWORD="change_this_to_secure_password"
PUBLIC_RCON_PASSWORD="change_this_to_secure_password"
PRACTICE_RCON_PASSWORD="change_this_to_secure_password"
GUNGAME_RCON_PASSWORD="change_this_to_secure_password"
TDM_BOTS_RCON_PASSWORD="change_this_to_secure_password"
FFA_BOTS_RCON_PASSWORD="change_this_to_secure_password"
SURF_RCON_PASSWORD="change_this_to_secure_password"
AIM_RCON_PASSWORD="change_this_to_secure_password"
```

### 3. Build and Start Servers

```bash
# Make the deployment script executable
chmod +x deploy.sh

# Deploy all servers (this will backup, build, and start)
./deploy.sh

# Or deploy step by step:
# 1. Build Docker images
docker compose build

# 2. Start all servers
docker compose up -d
```

### 4. Verify Deployment

```bash
# Check if all containers are running
docker compose ps

# Test server connections
python3 query_server.py --list

# Check individual server status
python3 query_server.py localhost 27015
```

## Automated Deployment with deploy.sh

The `deploy.sh` script automates the entire deployment process:

### Basic Deployment

```bash
# Deploy/update all servers (default action)
./deploy.sh

# Or explicitly:
./deploy.sh deploy
```

### Deployment Options

```bash
# Show deployment status
./deploy.sh status

# Verify deployment without making changes
./deploy.sh --dry-run deploy

# Skip Docker image building (useful for quick restarts)
./deploy.sh --skip-build deploy

# Force recreation of containers
./deploy.sh --force-recreate deploy

# Show verbose output
./deploy.sh --verbose deploy
```

### Rollback Deployment

```bash
# List available backups
ls -la backups/

# Rollback to a specific backup
./deploy.sh rollback backups/20240101_120000
```

## Server Management

### Using manage.sh

The `manage.sh` script provides easy server management:

```bash
# Show status of all servers
./manage.sh status

# Start/stop individual servers
./manage.sh start tournament
./manage.sh stop tournament
./manage.sh restart tournament

# Start/stop all servers
./manage.sh start all
./manage.sh stop all

# View server logs
./manage.sh logs tournament
./manage.sh logs tournament -f  # Follow logs in real-time

# Query server information
./manage.sh query tournament
./manage.sh query all

# Update configuration and restart
./manage.sh update tournament
```

### Manual Docker Compose Commands

```bash
# View all container status
docker compose ps

# View logs for specific server
docker compose logs tournament-server
docker compose logs tournament-server --tail=50
docker compose logs tournament-server -f  # Follow logs

# Restart specific server
docker compose restart tournament-server

# Stop all servers
docker compose down

# Start all servers
docker compose up -d
```

### RCON Administration

Use the RCON test client for server administration:

```bash
# Test RCON connection
python3 rcon_test.py tournament test

# Send RCON commands
python3 rcon_test.py tournament cmd "status"
python3 rcon_test.py tournament cmd "map de_dust2"
python3 rcon_test.py tournament cmd "say Hello from RCON"

# Interactive RCON shell
python3 rcon_test.py tournament interactive
```

**Common RCON Commands:**

```bash
status                     # Show server status and player list
map de_dust2              # Change to de_dust2
changelevel de_inferno    # Change to de_inferno
say Hello from RCON       # Send message to all players
users                     # List connected players
kick #USERID#             # Kick a player by USERID
mp_restartgame 1          # Restart the game
sv_password newpass       # Set server password
exec server.cfg          # Execute server config
```

## Monitoring and Maintenance

### Log Files

Server logs are stored in Docker containers and can be accessed via:

```bash
# View recent logs
docker compose logs tournament-server --tail=100

# Export logs to file
docker compose logs tournament-server > tournament.log

# Monitor logs in real-time
docker compose logs tournament-server -f
```

### Performance Monitoring

```bash
# Check container resource usage
docker stats

# Check server disk usage
docker system df

# Remove unused Docker resources
docker system prune -a
```

### Regular Maintenance Tasks

```bash
# Weekly: Update Docker images
docker compose pull
docker compose build --pull

# Monthly: Clean up old backups
find backups/ -type d -mtime +30 -exec rm -rf {} \;

# As needed: Update server configurations
# Edit files in servers/ directory, then:
./manage.sh update all
```

## Configuration Management

### Server Configuration Files

Configuration files are stored in the `servers/` directory:

```
servers/
├── tournament/
│   ├── server.cfg      # Tournament server settings
│   ├── mapcycle.txt    # Tournament map rotation
│   └── motd.txt        # Tournament MOTD (HTML)
├── public/
│   ├── server.cfg      # Public server settings
│   ├── mapcycle.txt    # Public map rotation
│   └── motd.txt        # Public MOTD (HTML)
└── practice/
    ├── server.cfg      # Practice server settings
    ├── mapcycle.txt    # Practice map rotation
    └── motd.txt        # Practice MOTD (HTML)
```

### Customizing Server Settings

1. Edit the appropriate `.cfg` file in the `servers/` directory
2. Apply changes:

   ```bash
   # Update and restart specific server
   ./manage.sh update tournament

   # Or restart all servers
   docker compose restart
   ```

### Adding Custom Maps & Assets

All server assets are now stored directly in the repository for reliable builds:

1. **Custom Maps**: Place `.bsp` files in `docker-assets/maps/`
   - Example: `cp ~/Downloads/surf_water-run_2.bsp docker-assets/maps/`
2. **AMX Mod X Plugins**: Place `.amxx` files in `docker-assets/plugins/`
   - Example: `cp ~/Downloads/custom_plugin.amxx docker-assets/plugins/`
3. **Complete Mods**: Place mod zip files in the repository root
   - Example: `gg_213c_full.zip` (GunGame mod, installed automatically)

4. Update the appropriate server's `mapcycle.txt` file if adding new maps
   - Each server has its own mapcycle in `servers/[server-type]/mapcycle.txt`

5. Validate assets: `./check-assets.sh --verbose`

6. Rebuild the Docker image: `docker compose build --no-cache`

**Note**: The Dockerfile automatically copies all assets from `docker-assets/` into the image during build.

## Troubleshooting

### Common Issues

**Server Not Starting:**

```bash
# Check Docker logs
docker compose logs tournament-server

# Check if port is already in use
netstat -tulpn | grep :27015

# Increase timeout for server startup
docker compose restart tournament-server
```

**RCON Not Working:**

```bash
# Verify RCON password in .env file
grep RCON_PASSWORD .env

# Test RCON connection
python3 rcon_test.py tournament test

# Check if server is accepting RCON connections
docker compose logs tournament-server | grep -i rcon
```

**High CPU/RAM Usage:**

```bash
# Check container resource usage
docker stats

# Restart problematic container
docker compose restart tournament-server

# Adjust server tickrate if needed (in server.cfg)
# sys_ticrate 100  # Default is 100, lower for better performance
```

### Debug Commands

```bash
# Check server connectivity
python3 query_server.py localhost 27015 --all

# Test RCON authentication
python3 rcon_test.py tournament test

# View detailed Docker information
docker inspect cs16-tournament

# Check Docker daemon logs
sudo journalctl -u docker --since "1 hour ago"
```

### Platform-Specific Issues

**ARM/Mac M1/M2 Compatibility:**
The Docker image uses `linux/amd64` platform. On ARM systems (including Apple Silicon), Docker will emulate x86_64 via Rosetta 2. This is normal and server functionality is not affected.

**Windows/WSL2:**
Ensure Docker Desktop is properly configured with WSL2 integration. Port forwarding in Windows Defender Firewall may need configuration.

## Backup and Rollback

### Automatic Backups

The deployment script automatically creates backups before each deployment:

```bash
# Backups are stored in:
ls -la backups/
# backups/20240101_120000/
# backups/20240102_150000/
```

### Manual Backups

```bash
# Create manual backup
./manage.sh backup

# Backup specific configurations
cp -r servers/ tournament-config-backup/
cp docker-compose.yml docker-compose.backup.yml
cp .env .env.backup
```

### Restoring from Backup

```bash
# Restore using deployment script
./deploy.sh rollback backups/20240101_120000

# Or manually restore configurations
cp -r backups/20240101_120000/tournament/ servers/tournament/
cp backups/20240101_120000/docker-compose.yml .
cp backups/20240101_120000/.env .
```

## Security Considerations

### RCON Passwords

1. **Change default passwords** in `.env` file
2. **Use strong passwords** with mix of characters
3. **Restrict RCON access** to trusted administrators
4. **Never commit `.env` file** to version control

### Server Security

1. **Keep Docker updated**: `sudo apt-get update && sudo apt-get upgrade docker-ce`
2. **Regular security updates**: Apply OS and Docker security patches
3. **Firewall configuration**: Only open necessary ports (27015-27017)
4. **Monitor logs**: Regularly check for suspicious activity

### Network Security

```bash
# Configure firewall (example with UFW)
sudo ufw allow 27015:27017/tcp
sudo ufw allow 27015:27017/udp
sudo ufw enable

# Or with iptables
iptables -A INPUT -p tcp --dport 27015:27017 -j ACCEPT
iptables -A INPUT -p udp --dport 27015:27017 -j ACCEPT
```

## Integration with Tournament Hub

The tournament servers are designed to integrate with the zukka tournament infrastructure:

### Tournament Hub Connection

- **Tournament Brackets**: [hub.zukkafabrik.de](https://hub.zukkafabrik.de)
- **LAN Event Info**: [lan.zukkafabrik.de](https://lan.zukkafabrik.de)
- **Contact**: lan@zukkafabrik.de

### Setting Match Passwords

Match-specific passwords should be set via the tournament hub or RCON:

```bash
# Set tournament password via RCON
python3 rcon_test.py tournament cmd "sv_password tournament_match_123"

# Clear password after match
python3 rcon_test.py tournament cmd "sv_password"
```

### Player Connection Instructions

Players connect using tournament information from the hub:

```
connect [SERVER_IP]:27015; password [TOURNAMENT_PASSWORD]
```

## Performance Optimization

### Server Settings for Performance

Edit `server.cfg` files for optimal performance:

```bash
# Network settings (adjust based on your bandwidth)
sv_maxrate 25000
sv_minrate 10000
sv_maxupdaterate 101
sv_minupdaterate 30

# Server tickrate
sys_ticrate 100  # 100 is standard, increase for better physics
```

### Docker Resource Limits

Add resource limits to `docker-compose.yml` if needed:

```yaml
services:
  tournament-server:
    # ... other configuration ...
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 1G
        reservations:
          cpus: "0.5"
          memory: 512M
```

### Monitoring Performance

```bash
# Monitor container performance
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Check server response times
timeout 5 python3 query_server.py localhost 27015
```

## Updating the System

### Regular Updates

```bash
# Pull latest changes from repository
git pull origin main

# Deploy updates
./deploy.sh

# Or update step by step:
docker compose pull
docker compose build
docker compose up -d
```

### Major Version Updates

For major updates that change configuration formats:

1. **Backup current setup**: `./manage.sh backup`
2. **Review changelog**: Check commit history or README for breaking changes
3. **Update configurations**: May need to manually update `.cfg` files
4. **Test thoroughly**: Before deploying to production

## Support and Resources

### Documentation

- **README.md**: Project overview and quick start guide
- **DEPLOYMENT.md**: This deployment guide
- **GitHub Repository**: [github.com/momokli/rehlds-cstrike-reunion](https://github.com/momokli/rehlds-cstrike-reunion)

### Community and Support

- **Tournament Hub**: [hub.zukkafabrik.de](https://hub.zukkafabrik.de)
- **LAN Event Info**: [lan.zukkafabrik.de](https://lan.zukkafabrik.de)
- **Contact**: lan@zukkafabrik.de

### Troubleshooting Resources

- **Docker Documentation**: [docs.docker.com](https://docs.docker.com)
- **ReHLDS Documentation**: [github.com/ReHLDS](https://github.com/ReHLDS)
- **CS 1.6 Server Administration Guides**: Various community resources

---

**Last Updated**: $(date +%Y-%m-%d)  
**System Version**: 1.0.0  
**Documentation Version**: 1.0

For issues not covered in this guide, please check the GitHub repository issues page or contact tournament organizers.
