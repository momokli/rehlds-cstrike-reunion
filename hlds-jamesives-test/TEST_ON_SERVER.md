# JamesIves/hlds-docker Test Instructions for Server

## Prerequisites
- Ubuntu server with Docker installed
- x86-64 architecture (not ARM)
- Git repository cloned at `/srv/cs1.6`

## Quick Test Commands

### 1. Pull the image
```bash
docker pull jives/hlds:cstrike
```

### 2. Test with standard map (de_dust2)
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

### 3. Check logs
```bash
docker logs cs16-test-dust2 --tail 50
```

### 4. Test with custom aim map (aim_headshot)
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

### 5. Check logs for map change
```bash
docker logs cs16-test-aim --tail 100 | grep -A5 -B5 "Mapchange"
```

## What to Look For

### Success Indicators
- `Mapchange to aim_headshot` appears in logs
- Server stays on `aim_headshot` (no `Mapchange to de_dust2`)
- Server shows `Connection to Steam servers successful`
- Server shows `VAC secure mode is activated`

### Failure Indicators
- `Mapchange to de_dust2` appears after `aim_headshot`
- `Couldn't spawn server maps/aim_headshot.bsp` error
- Server crashes and restarts

## Cleanup Commands
```bash
docker rm -f cs16-test-dust2 cs16-test-aim 2>/dev/null || true
```

## If Tests Pass
If the JamesIves image works without the `de_dust2` fallback issue:
1. We can use it as our new base
2. We need to add AMX Mod X, ReDeathmatch, etc.
3. Create a new Dockerfile based on `jives/hlds:cstrike`

## If Tests Fail
If it still falls back to `de_dust2`:
1. Try legacy version: `jives/hlds:cstrike-legacy`
2. Check if maps are properly mounted
3. Consider other alternatives

## Quick All-in-One Test Script
```bash
cd /srv/cs1.6/hlds-jamesives-test
chmod +x test_jamesives.sh
./test_jamesives.sh
```
