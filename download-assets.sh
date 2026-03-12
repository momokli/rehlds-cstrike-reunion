#!/bin/bash

# CS 1.6 Server Assets Download Script
# Downloads missing assets for zukka CS 1.6 LAN Party Server System
# Usage: ./download-assets.sh [OPTIONS]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MAPS_DIR="${PROJECT_ROOT}/maps"
PLUGINS_DIR="${PROJECT_ROOT}/plugins"

# Asset URLs (with fallbacks)
# Note: GunGame is now baked into the Dockerfile via gg_213c_full.zip in repo root

AIM_MAP_URL="https://share.monocu.be/cs1.6-maps/aim_b0n0_d8c71.rar"
SURF_MAP_URL="https://share.monocu.be/cs1.6-maps/surf/surf_water-run_2/"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    local missing=()

    if ! command -v wget &> /dev/null; then
        missing+=("wget")
    fi

    if ! command -v curl &> /dev/null; then
        missing+=("curl")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing[*]}"
        log_info "Install missing tools and try again."
        exit 1
    fi

    log_success "Prerequisites check passed"
}

# Create necessary directories
create_directories() {
    log_info "Creating asset directories..."

    mkdir -p "$MAPS_DIR"
    mkdir -p "$PLUGINS_DIR"

    log_success "Directories created"
}

# Check for GunGame zip file
check_gungame() {
    log_info "Checking for GunGame zip file..."

    if [[ -f "$PROJECT_ROOT/gg_213c_full.zip" ]]; then
        log_success "GunGame zip file found: $PROJECT_ROOT/gg_213c_full.zip"
        log_info "The Dockerfile will automatically install GunGame from this file."
        return 0
    else
        log_warning "GunGame zip file not found in repository root: gg_213c_full.zip"
        log_info "Place gg_213c_full.zip in the repository root for automatic installation."
        return 1
    fi
}

# Download aim map
download_aim_map() {
    log_info "Downloading aim map (aim_b0n0_d8c71)..."

    local aim_map_path="$MAPS_DIR/aim_b0n0_d8c71.rar"
    local bsp_path="$MAPS_DIR/aim_b0n0_d8c71.bsp"

    # Check if already exists
    if [[ -f "$bsp_path" ]]; then
        log_success "Aim map already exists: $bsp_path"
        return 0
    fi

    # Download RAR file
    if ! curl -s -f -L "$AIM_MAP_URL" -o "$aim_map_path"; then
        log_warning "Could not download aim map RAR file"
        log_info "Manual installation required:"
        log_info "1. Download from: $AIM_MAP_URL"
        log_info "2. Extract aim_b0n0_d8c71.bsp"
        log_info "3. Place it in: $MAPS_DIR/"
        return 1
    fi

    # Check if we have unrar or 7z to extract
    log_info "Extracting aim map..."

    if command -v unrar &> /dev/null; then
        if unrar e -o+ -y "$aim_map_path" "$MAPS_DIR/" 2>/dev/null; then
            log_success "Aim map extracted successfully"
        else
            log_warning "Failed to extract with unrar"
        fi
    elif command -v 7z &> /dev/null; then
        if 7z e -y "$aim_map_path" -o"$MAPS_DIR/" 2>/dev/null; then
            log_success "Aim map extracted successfully"
        else
            log_warning "Failed to extract with 7z"
        fi
    else
        log_warning "No extraction tool found (unrar or 7z)"
        log_info "Install 'unrar' or 'p7zip' to extract the RAR file automatically"
        log_info "For now, manually extract $aim_map_path to $MAPS_DIR/"
    fi

    # Clean up RAR file
    if [[ -f "$aim_map_path" ]]; then
        rm -f "$aim_map_path"
    fi

    # Verify extraction
    if [[ -f "$bsp_path" ]]; then
        log_success "Aim map ready: $bsp_path"
        return 0
    else
        log_warning "Aim map extraction may have failed"
        return 1
    fi
}

# Download surf map
download_surf_map() {
    log_info "Downloading surf map (surf_water-run_2)..."

    local surf_dir="$MAPS_DIR/surf_water-run_2"
    local bsp_path="$MAPS_DIR/surf_water-run_2.bsp"

    # Check if already exists
    if [[ -f "$bsp_path" ]]; then
        log_success "Surf map already exists: $bsp_path"
        return 0
    fi

    # Create directory for surf map files
    mkdir -p "$surf_dir"

    # Download surf map files
    log_info "Fetching surf map directory listing..."

    # Try to get directory listing and download files
    if curl -s -f -L "$SURF_MAP_URL" | grep -o 'href="[^"]*\.bsp"' | sed 's/href="//' | sed 's/"//' | head -1 | while read filename; do
        log_info "Downloading: $filename"
        curl -s -f -L "${SURF_MAP_URL}${filename}" -o "$MAPS_DIR/$filename"

        if [[ $? -eq 0 ]]; then
            log_success "Downloaded: $filename"
            # Check if this is the BSP file
            if [[ "$filename" == *".bsp" ]]; then
                return 0
            fi
        fi
    done; then
        # Check if we got a BSP file
        if ls "$MAPS_DIR/"*.bsp 2>/dev/null | grep -q "surf"; then
            log_success "Surf map downloaded"
            return 0
        fi
    fi

    log_warning "Could not download surf map automatically"
    log_info "Manual installation required:"
    log_info "1. Visit: $SURF_MAP_URL"
    log_info "2. Download surf_water-run_2.bsp"
    log_info "3. Place it in: $MAPS_DIR/"
    return 1
}

# Copy assets to Docker build context
setup_docker_assets() {
    log_info "Setting up Docker build assets..."

    # Create Dockerfile directory for assets
    local docker_assets_dir="$PROJECT_ROOT/docker-assets"
    mkdir -p "$docker_assets_dir/maps"
    mkdir -p "$docker_assets_dir/plugins"

    # Copy maps if they exist
    if ls "$MAPS_DIR/"*.bsp 2>/dev/null | grep -q "aim_b0n0_d8c71"; then
        cp "$MAPS_DIR/aim_b0n0_d8c71.bsp" "$docker_assets_dir/maps/" 2>/dev/null && \
        log_success "Aim map copied to Docker assets"
    fi

    if ls "$MAPS_DIR/"*.bsp 2>/dev/null | grep -q "surf_water-run_2"; then
        cp "$MAPS_DIR/surf_water-run_2.bsp" "$docker_assets_dir/maps/" 2>/dev/null && \
        log_success "Surf map copied to Docker assets"
    fi

    # GunGame is now baked into the Dockerfile via gg_213c_full.zip
    # No need to copy plugin separately

    log_info "Docker assets ready in: $docker_assets_dir/"
}

# Update Dockerfile to include local assets
update_dockerfile() {
    log_info "Checking Dockerfile for asset integration..."

    local dockerfile="$PROJECT_ROOT/Dockerfile"

    if [[ ! -f "$dockerfile" ]]; then
        log_warning "Dockerfile not found at: $dockerfile"
        return 1
    fi

    # Check if Dockerfile already has asset copying
    if grep -q "docker-assets" "$dockerfile"; then
        log_success "Dockerfile already configured for assets"
        return 0
    fi

    log_info "Dockerfile needs to be updated to include downloaded assets"
    log_info "Add the following lines to your Dockerfile after installing AMX Mod X:"
    log_info ""
    log_info "# Copy downloaded maps"
    log_info "COPY docker-assets/maps/ /opt/steam/hlds/cstrike/maps/"
    log_info ""
    log_info "# Copy downloaded plugins"
    log_info "COPY docker-assets/plugins/ /opt/steam/hlds/cstrike/addons/amxmodx/plugins/"
    log_info ""
    log_info "Then rebuild Docker image: docker compose build --no-cache"

    return 0
}

# Main function
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  CS 1.6 Server Assets Download Script  ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # Parse arguments
    local skip_gungame=false
    local skip_maps=false
    local skip_docker=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-gungame)
                skip_gungame=true
                shift
                ;;
            --skip-maps)
                skip_maps=true
                shift
                ;;
            --skip-docker)
                skip_docker=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Run tasks
    check_prerequisites
    create_directories

    if [[ "$skip_gungame" = false ]]; then
        check_gungame
    else
        log_info "Skipping GunGame check (--skip-gungame)"
    fi

    if [[ "$skip_maps" = false ]]; then
        download_aim_map
        download_surf_map
    else
        log_info "Skipping map downloads (--skip-maps)"
    fi

    if [[ "$skip_docker" = false ]]; then
        setup_docker_assets
        update_dockerfile
    else
        log_info "Skipping Docker setup (--skip-docker)"
    fi

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}           Download Complete!           ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    # Summary
    log_info "Summary of downloaded assets:"
    echo ""

    if [[ -f "$PROJECT_ROOT/gg_213c_full.zip" ]]; then
        echo -e "  ${GREEN}✓${NC} GunGame zip file: $PROJECT_ROOT/gg_213c_full.zip"
    else
        echo -e "  ${YELLOW}⚠${NC} GunGame zip file: NOT FOUND (place gg_213c_full.zip in repo root)"
    fi

    if [[ -f "$MAPS_DIR/aim_b0n0_d8c71.bsp" ]]; then
        echo -e "  ${GREEN}✓${NC} Aim map: $MAPS_DIR/aim_b0n0_d8c71.bsp"
    else
        echo -e "  ${YELLOW}⚠${NC} Aim map: NOT FOUND (server will use de_dust2)"
    fi

    if ls "$MAPS_DIR/"*.bsp 2>/dev/null | grep -q "surf_water-run_2"; then
        echo -e "  ${GREEN}✓${NC} Surf map: $MAPS_DIR/surf_water-run_2.bsp"
    else
        echo -e "  ${YELLOW}⚠${NC} Surf map: NOT FOUND (server will use de_dust2)"
    fi

    echo ""
    log_info "Next steps:"
    echo "  1. Review downloaded assets above"
    echo "  2. Update Dockerfile to include assets (if not already done)"
    echo "  3. Rebuild Docker image: docker compose build --no-cache"
    echo "  4. Start servers: docker compose up -d"
    echo ""
}

# Show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Download missing assets for CS 1.6 server infrastructure"
    echo ""
    echo "Options:"
    echo "  --skip-gungame    Skip checking for GunGame zip file"
    echo "  --skip-maps       Skip downloading aim and surf maps"
    echo "  --skip-docker     Skip Docker asset setup"
    echo "  -h, --help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    Download all assets"
    echo "  $0 --skip-maps        Check only for GunGame zip file"
    echo "  $0 --skip-gungame     Download only aim and surf maps"
    echo ""
}

# Run main function
main "$@"
