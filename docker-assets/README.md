# Docker Assets Directory

This directory contains all the assets that are baked into the Docker image for the CS 1.6 server infrastructure.

## Overview

The goal is to have all required assets (maps, plugins, mods) stored directly in the repository, eliminating brittle download scripts and ensuring reliable builds. Assets placed here will be copied into the Docker image at build time.

## Directory Structure

```
docker-assets/
├── README.md              # This file
├── maps/                  # Custom map files (.bsp)
│   ├── .keep             # Keeps directory in git
│   └── [mapname].bsp     # Map files (e.g., aim_b0n0_d8c71.bsp)
└── plugins/              # AMX Mod X plugins
    ├── .keep             # Keeps directory in git
    └── [plugin].amxx     # Compiled plugin files
```

## Adding Maps

1. **Find or create your map file** (must be a `.bsp` file)
2. **Place it in `docker-assets/maps/`**
3. **Update server mapcycles** in `servers/[server-type]/mapcycle.txt`

Example:
```bash
# Add aim map
cp ~/Downloads/aim_b0n0_d8c71.bsp docker-assets/maps/

# Add surf map  
cp ~/Downloads/surf_water-run_2.bsp docker-assets/maps/
```

## Adding Plugins/Mods

### For AMX Mod X plugins (.amxx files):
1. Place compiled plugin in `docker-assets/plugins/`
2. Enable it in the appropriate server's `plugins-amxx.ini` file

### For complete mods (like GunGame):
1. Place the mod zip file in the repository root (e.g., `gg_213c_full.zip`)
2. The Dockerfile will automatically install it during build

## Server-specific Mapcycles

Each server has its own mapcycle in `servers/[server-type]/mapcycle.txt`:

- `servers/tournament/mapcycle.txt` - Competitive 5v5 maps
- `servers/surf/mapcycle.txt` - Surf maps  
- `servers/aim/mapcycle.txt` - Aim training maps
- `servers/gungame/mapcycle.txt` - GunGame maps
- `servers/public/mapcycle.txt` - Casual play maps
- `servers/practice/mapcycle.txt` - FFA practice maps
- `servers/tdm-bots/mapcycle.txt` - TDM with bots maps
- `servers/ffa-bots/mapcycle.txt` - FFA with bots maps

When adding a new map, make sure to add it to the appropriate server's mapcycle file.

## Git Considerations

- **Included**: `.bsp` files in `docker-assets/maps/` are tracked by git
- **Excluded**: Most other binary files are ignored (see `.gitignore`)
- **Exception**: `gg_213c_full.zip` in repo root is tracked

## Building the Docker Image

After adding assets to this directory:

1. **Rebuild the Docker image**:
   ```bash
   docker compose build --no-cache
   ```

2. **Start your servers**:
   ```bash
   docker compose up -d
   ```

## Current Assets

### Maps:
- `aim_b0n0_d8c71.bsp` - Aim training map (for aim server)

### Plugins:
*(None currently - add your .amxx files here)*

### Mods:
- `gg_213c_full.zip` - GunGame mod (installed automatically by Dockerfile)

## Notes

- The Dockerfile copies everything from `docker-assets/maps/` to `/opt/steam/hlds/cstrike/maps/` in the container
- Server configurations reference these maps by filename (without path)
- If a map is missing, servers will fall back to `de_dust2`
- Always test new maps locally before committing to the repository
