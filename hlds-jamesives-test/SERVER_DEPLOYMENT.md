# Server Deployment Instructions for JamesIves/hlds-docker Test

## Overview
This document provides step-by-step instructions for testing the JamesIves/hlds-docker image on the x86 Ubuntu server. The goal is to determine if this image can load custom maps without the `de_dust2` fallback issue present in the current `blsalin/rehlds-cstrike` image.

## Server Environment
- **Location**: `/srv/cs1.6`
- **OS**: Ubuntu (x86-64)
- **Docker**: Installed and running
- **Repository**: Already cloned at `/srv/cs1.6`

## Quick Start Test

### 1. Navigate to Test Directory
```bash
cd /srv/cs1.6/hlds-jamesives-test
```

### 2. Pull the Docker Image
```bash
docker pull jives/hlds:cstrike
```

### 3. Run Automated Test Script
```bash
chmod +x test_jamesives.sh
./test_jamesives.sh
```

### 4. Check Results
The script will:
- Test with `de_dust2` (baseline)
- Test with `cs_italy` (standard map)
- Test with `aim_headshot` (custom aim map - CRITICAL TEST)
- Clean up containers after each test

## Manual Testing (Optional)

### Test 1: Standard Map (de_dust2)
```bash
docker run -d \
  --name cs16-test-dust2 \
  -p 27030:27015/udp \
  -p 27030:27015 \
  -p 26900:26900/udp \
  -v /srv/cs1.6/hlds-jamesives-test/config:/temp/config:ro \
  -v /srv/cs1.6/hlds-jamesives-test/mods:/temp/mods:ro \
  -v /srv/cs1.6/docker-assets/maps:/temp/mods/cstrike/maps:ro \
  jives/hlds:cstrike \
  +log on +rcon_password "test123" +maxplayers 16 +map de_dust2 +hostname "Test: de_dust2"
```

Check logs:
```bash
docker logs cs16-test-dust2 --tail 50
```

### Test 2: Custom Aim Map (aim_headshot) - CRITICAL
```bash
docker run -d \
  --name cs16-test-aim \
  -p 27031:27015/udp \
  -p 27031:27015 \
  -p 26901:26900/udp \
  -v /srv/cs1.6/hlds-jamesives-test/config:/temp/config:ro \
  -v /srv/cs1.6/hlds-jamesives-test/mods:/temp/mods:ro \
  -v /srv/cs1.6/docker-assets/maps:/temp/mods/cstrike/maps:ro \
  jives/hlds:cstrike \
  +log on +rcon_password "test123" +maxplayers 16 +map aim_headshot +hostname "Test: aim_headshot"
```

Check for map change issues:
```bash
docker logs cs16-test-aim --tail 100 | grep -A5 -B5 "Mapchange"
```

## What to Look For

### Success Indicators ✅
- Log shows `Mapchange to aim_headshot`
- No subsequent `Mapchange to de_dust2`
- Server shows `Connection to Steam servers successful`
- Server shows `VAC secure mode is activated`
- Server remains stable for several minutes

### Failure Indicators ❌
- Log shows `Mapchange to de_dust2` after `aim_headshot`
- Error: `Couldn't spawn server maps/aim_headshot.bsp`
- Server crashes and restarts
- `CWorkThreadPool` errors (like current image)

## Cleanup Commands
```bash
# Stop and remove test containers
docker rm -f cs16-test-dust2 cs16-test-aim 2>/dev/null || true

# Remove all test containers
docker ps -a | grep "cs16-test" | awk '{print $1}' | xargs -r docker rm -f

# Remove unused images
docker image prune -f
```

## Testing Legacy Version
If the standard version has issues, test the legacy (pre-25th anniversary) version:
```bash
docker pull jives/hlds:cstrike-legacy

docker run -d \
  --name cs16-test-legacy \
  -p 27032:27015/udp \
  -p 27032:27015 \
  -p 26902:26900/udp \
  -v /srv/cs1.6/hlds-jamesives-test/config:/temp/config:ro \
  -v /srv/cs1.6/hlds-jamesives-test/mods:/temp/mods:ro \
  -v /srv/cs1.6/docker-assets/maps:/temp/mods/cstrike/maps:ro \
  jives/hlds:cstrike-legacy \
  +log on +rcon_password "test123" +maxplayers 16 +map aim_headshot +hostname "Test: Legacy aim_headshot"
```

## Next Steps Based on Results

### If Tests PASS ✅
1. **Create new Dockerfile**: Based on `jives/hlds:cstrike` with our modifications
2. **Add AMX Mod X**: Install version 1.10.0 or 1.8.2
3. **Add ReDeathmatch**: For random spawns
4. **Test plugins**: Ensure compatibility
5. **Deploy gradually**: Start with aim server, then others

### If Tests FAIL ❌
1. **Try legacy version**: `jives/hlds:cstrike-legacy`
2. **Check map files**: Verify `aim_headshot.bsp` exists in maps directory
3. **Check permissions**: Ensure Docker can read mounted volumes
4. **Review logs**: Look for specific error messages
5. **Consider alternatives**: Other Docker images or fix current setup

## Troubleshooting

### Issue: "no matching manifest for linux/arm64"
- **Cause**: Running on ARM architecture
- **Solution**: Ensure server is x86-64 (Ubuntu on x86)

### Issue: "Couldn't spawn server maps/aim_headshot.bsp"
- **Cause**: Map file not found or corrupted
- **Solution**: Verify map file exists at `/srv/cs1.6/docker-assets/maps/aim_headshot.bsp`

### Issue: Port already in use
- **Cause**: Another container using same port
- **Solution**: Change port numbers or stop existing containers

### Issue: Permission denied on volumes
- **Cause**: Docker can't read mounted directories
- **Solution**: Check directory permissions: `ls -la /srv/cs1.6/`

## Reporting Results
Please provide the following information:
1. Test script output
2. Logs from `aim_headshot` test (most important)
3. Any error messages
4. Server stability after 5 minutes

## Contact
For questions or issues, refer to the migration plan in `MIGRATION_PLAN.md` or check the main project documentation.

---
**Last Updated**: $(date)
**Test Directory**: `/srv/cs1.6/hlds-jamesives-test`
**Critical Test**: `aim_headshot` map loading without fallback to `de_dust2`
