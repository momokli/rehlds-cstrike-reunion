# Migration Plan to JamesIves/hlds-docker

## Current Status
We're currently using `blsalin/rehlds-cstrike` which has a critical bug:
- Server crashes on startup with `CWorkThreadPool` errors
- After crash, server changes to `de_dust2` regardless of `+map` parameter
- This prevents us from choosing which map to play

## JamesIves/hlds-docker Advantages
1. **Actively maintained** (66 stars, 9 forks, regular updates)
2. **Clean design** - Uses official SteamCMD, no pre-bundled mods
3. **Proper volume mounting** - `/temp/config` and `/temp/mods` system
4. **Multiple game support** - CS 1.6, Condition Zero, Day of Defeat, etc.
5. **Legacy versions available** - Pre-25th anniversary builds

## Test Results Needed
Before migration, we need to verify on the x86 server:

### Critical Tests
1. ✅ Can start with `+map de_dust2` (baseline)
2. ✅ Can start with `+map cs_italy` (standard map)
3. ✅ **CRITICAL**: Can start with `+map aim_headshot` (custom aim map)
   - Must NOT fall back to `de_dust2`
   - Must stay on specified map

### Secondary Tests
4. Server stability after 5+ minutes
5. RCON connectivity
6. Player connectivity

## Migration Steps (If Tests Pass)

### Phase 1: Create New Dockerfile
Create `Dockerfile.jamesives` based on `jives/hlds:cstrike`:

```dockerfile
FROM jives/hlds:cstrike

# Install dependencies
USER root
RUN apt-get update && apt-get install -y wget unzip xz-utils

# Switch back to steam user
USER steam
WORKDIR /opt/steam/hlds

# Install AMX Mod X 1.10.0
RUN wget https://amxmodx.org/amxxdrop/1.10/amxmodx-1.10.0-git5474-base-linux.tar.gz && \
    tar -xzf amxmodx-1.10.0-git5474-base-linux.tar.gz -C cstrike/ && \
    wget https://amxmodx.org/amxxdrop/1.10/amxmodx-1.10.0-git5474-cstrike-linux.tar.gz && \
    tar -xzf amxmodx-1.10.0-git5474-cstrike-linux.tar.gz -C cstrike/ && \
    rm -f amxmodx-1.10.0-git5474-base-linux.tar.gz amxmodx-1.10.0-git5474-cstrike-linux.tar.gz

# Install ReDeathmatch
RUN wget https://github.com/ReDeathmatch/ReDeathmatch_AMXX/releases/download/1.0.0-b11/ReDeathmatch-1.0.0-b11.zip -O /tmp/redm.zip && \
    unzip /tmp/redm.zip -d /tmp/redm && \
    cp -r /tmp/redm/cstrike/addons/amxmodx/* cstrike/addons/amxmodx/ && \
    rm -rf /tmp/redm /tmp/redm.zip

# Install ReGameDLL (optional - test stability first)
# RUN wget https://github.com/s1lentq/ReGameDLL_CS/releases/download/5.26.0.668/regamedll-bin-5.26.0.668.zip && \
#     unzip -o -j regamedll-bin-5.26.0.668.zip "bin/linux32/cstrike/*" -d "cstrike"

# Create necessary directories
RUN mkdir -p cstrike/addons/metamod

# Create default metamod plugins.ini
RUN echo "linux addons/amxmodx/dlls/amxmodx_mm_i386.so" > cstrike/addons/metamod/plugins.ini

# Set working directory
WORKDIR /opt/steam/hlds
```

### Phase 2: Update docker-compose.yml
Update server configurations to use new image:

```yaml
aim-server:
  build:
    context: .
    dockerfile: Dockerfile.jamesives
  image: cs16-jamesives-aim
  container_name: cs16-aim-new
  ports:
    - "${AIM_PORT:-27022}:27015"
    - "${AIM_PORT:-27022}:27015/udp"
  volumes:
    - ./servers/aim/server.cfg:/temp/config/server.cfg:ro
    - ./servers/aim/mapcycle.txt:/temp/config/mapcycle.txt:ro
    - ./servers/aim/motd.txt:/temp/config/motd.txt:ro
    - ./servers/aim/plugins.ini:/temp/config/addons/metamod/plugins.ini:ro
    - ./servers/aim/plugins-amxx.ini:/temp/config/addons/amxmodx/configs/plugins.ini:ro
    - ./docker-assets/maps:/temp/mods/cstrike/maps:ro
    - ./docker-assets/gfx:/temp/mods/cstrike/gfx:ro
    - ./docker-assets/overviews:/temp/mods/cstrike/overviews:ro
  command:
    - "+log"
    - "on"
    - "+rcon_password"
    - "${AIM_RCON_PASSWORD:-zukka_aim_rcon_secure}"
    - "+maxplayers"
    - "16"
    - "+map"
    - "aim_headshot"
    - "+hostname"
    - "${AIM_HOSTNAME:-zukka Aim Server (JamesIves)}"
```

### Phase 3: Configuration Updates
1. **Mapcycle.txt**: Keep current format
2. **Maps.ini**: May not be needed (AMX Mod X feature)
3. **Server.cfg**: Update paths if needed
4. **Plugins**: ReDeathmatch needs spawn files for aim maps

### Phase 4: Testing
1. Build new image: `docker compose build aim-server`
2. Start server: `docker compose up aim-server`
3. Test map loading with different maps
4. Test ReDeathmatch functionality
5. Test server stability over 24 hours

## Potential Issues and Solutions

### Issue 1: Missing ReHLDS/ReGameDLL
- **Problem**: JamesIves image uses vanilla HLDS, not ReHLDS
- **Solution**: Install ReGameDLL in Dockerfile (test stability first)
- **Alternative**: Use vanilla if stable enough

### Issue 2: AMX Mod X Compatibility
- **Problem**: Different HLDS version may affect AMX Mod X
- **Solution**: Test with AMX Mod X 1.8.2 (more stable) first
- **Alternative**: Use AMX Mod X 1.10.0 if compatible

### Issue 3: ReDeathmatch Spawn Files
- **Problem**: Aim maps don't have spawn files
- **Solution**: Create spawn files or disable ReDeathmatch for aim maps
- **Alternative**: Use different deathmatch plugin

### Issue 4: Performance Differences
- **Problem**: Vanilla HLDS vs ReHLDS performance
- **Solution**: Monitor server performance, adjust settings
- **Alternative**: Install ReHLDS if needed

## Rollback Plan
If migration fails:
1. Keep current `blsalin/rehlds-cstrike` setup
2. Implement workaround script to change maps after startup
3. Continue searching for alternative base images

## Success Criteria
Migration is successful if:
1. Server starts with specified map (not `de_dust2`)
2. Server runs stable for 24+ hours
3. All plugins work correctly
4. Players can connect and play normally

## Timeline
1. **Day 1**: Test JamesIves image on server
2. **Day 2**: Create new Dockerfile and test build
3. **Day 3**: Test individual servers (aim, practice, etc.)
4. **Day 4**: Full deployment and monitoring
5. **Day 5-7**: Stability monitoring and bug fixes

## Documentation Updates Needed
1. Update `README.md` with new setup instructions
2. Update `DEPLOYMENT.md` with migration notes
3. Update server configuration documentation
4. Create troubleshooting guide for new setup
