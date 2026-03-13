# JamesIves/hlds-docker Test Directory

## Overview
This directory contains tests and migration plans for evaluating the JamesIves/hlds-docker image as a potential replacement for our current `blsalin/rehlds-cstrike` base image.

## Problem Statement
Our current `blsalin/rehlds-cstrike` image has a critical bug:
- Server crashes on startup with `CWorkThreadPool` errors
- After crash, server changes to `de_dust2` regardless of the `+map` parameter
- This prevents us from choosing which map to play on our aim server

## JamesIves/hlds-docker Advantages
1. **Actively maintained** (66 stars, 9 forks, regular updates)
2. **Clean design** - Uses official SteamCMD, no pre-bundled mods
3. **Proper volume mounting** - `/temp/config` and `/temp/mods` system
4. **Multiple game support** - CS 1.6, Condition Zero, Day of Defeat, etc.
5. **Legacy versions available** - Pre-25th anniversary builds

## Test Objectives
The primary goal is to determine if the JamesIves image can:
1. Start with custom aim maps (e.g., `aim_headshot`)
2. **CRITICAL**: Stay on the specified map without falling back to `de_dust2`
3. Run stably without `CWorkThreadPool` errors

## Directory Structure
```
hlds-jamesives-test/
├── README.md                          # This file
├── docker-compose.yml                 # Docker Compose configuration for testing
├── test_jamesives.sh                  # Automated test script
├── TEST_ON_SERVER.md                  # Quick test instructions for server
├── SERVER_DEPLOYMENT.md               # Detailed server deployment guide
├── MIGRATION_PLAN.md                  # Complete migration plan if tests pass
├── config/                            # Test server configuration
│   ├── server.cfg                     # Basic server configuration
│   └── mapcycle.txt                   # Map rotation for testing
└── mods/                              # Empty mods directory (for structure)
```

## Quick Start Test (On x86 Server)

### 1. Navigate to Test Directory
```bash
cd /srv/cs1.6/hlds-jamesives-test
```

### 2. Pull the Docker Image
```bash
docker pull jives/hlds:cstrike
```

### 3. Run Automated Tests
```bash
chmod +x test_jamesives.sh
./test_jamesives.sh
```

### 4. Check Results
The script will test:
- `de_dust2` (baseline - should work)
- `cs_italy` (standard map - should work)
- `aim_headshot` (custom aim map - **CRITICAL TEST**)

## Critical Success Criteria
The migration will be considered viable if:
1. ✅ Server starts with `+map aim_headshot`
2. ✅ Server stays on `aim_headshot` (no fallback to `de_dust2`)
3. ✅ Server runs stable for 5+ minutes
4. ✅ No `CWorkThreadPool` errors

## Next Steps Based on Results

### If Tests PASS ✅
1. Create new Dockerfile based on `jives/hlds:cstrike`
2. Add AMX Mod X, ReDeathmatch, and other required plugins
3. Test plugin compatibility
4. Deploy gradually starting with aim server

### If Tests FAIL ❌
1. Try legacy version: `jives/hlds:cstrike-legacy`
2. Check map files and permissions
3. Consider other alternatives or implement workaround for current setup

## Important Notes
- **Architecture Requirement**: This image only works on **x86-64** systems (not ARM)
- **Map Files**: Custom maps must be in `/srv/cs1.6/docker-assets/maps/`
- **Volume Mounts**: Configs go to `/temp/config`, mods to `/temp/mods`

## Documentation
- [TEST_ON_SERVER.md](TEST_ON_SERVER.md) - Quick test commands for server
- [SERVER_DEPLOYMENT.md](SERVER_DEPLOYMENT.md) - Detailed deployment instructions
- [MIGRATION_PLAN.md](MIGRATION_PLAN.md) - Complete migration plan
- [test_jamesives.sh](test_jamesives.sh) - Automated test script

## Related Resources
- [JamesIves/hlds-docker GitHub](https://github.com/JamesIves/hlds-docker)
- [Docker Hub - jives/hlds](https://hub.docker.com/r/jives/hlds)
- [Original Issue Documentation](../docs/) - Current setup issues and investigation

## Support
For questions or issues, refer to the migration plan or check the main project documentation in the parent directory.

---
**Last Updated**: March 13, 2026  
**Test Directory**: `/srv/cs1.6/hlds-jamesives-test`  
**Critical Test**: `aim_headshot` map loading without fallback to `de_dust2`
