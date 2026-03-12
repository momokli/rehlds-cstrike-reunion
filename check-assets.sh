#!/bin/bash
#
# CS 1.6 Server Asset Validation Script
# Checks that all required assets are present in the repository.
#
# Usage: ./check-assets.sh [--verbose]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

VERBOSE=false
if [[ "$1" == "--verbose" || "$1" == "-v" ]]; then
    VERBOSE=true
fi

# Project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Directories
MAPS_DIR="$PROJECT_ROOT/docker-assets/maps"
PLUGINS_DIR="$PROJECT_ROOT/docker-assets/plugins"
SERVERS_DIR="$PROJECT_ROOT/servers"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check directory structure
check_directories() {
    log_info "Checking directory structure..."

    local missing=0

    if [[ ! -d "$MAPS_DIR" ]]; then
        log_error "Missing directory: $MAPS_DIR"
        missing=$((missing + 1))
    else
        log_success "Maps directory exists: $MAPS_DIR"
    fi

    if [[ ! -d "$PLUGINS_DIR" ]]; then
        log_error "Missing directory: $PLUGINS_DIR"
        missing=$((missing + 1))
    else
        log_success "Plugins directory exists: $PLUGINS_DIR"
    fi

    if [[ ! -d "$SERVERS_DIR" ]]; then
        log_error "Missing directory: $SERVERS_DIR"
        missing=$((missing + 1))
    else
        log_success "Servers directory exists: $SERVERS_DIR"
    fi

    return $missing
}

# Check for GunGame zip file
check_gungame() {
    log_info "Checking for GunGame mod..."

    local gungame_zip="$PROJECT_ROOT/gg_213c_full.zip"

    if [[ -f "$gungame_zip" ]]; then
        local size=$(stat -f%z "$gungame_zip" 2>/dev/null || stat -c%s "$gungame_zip" 2>/dev/null || echo "unknown")
        log_success "GunGame zip found: $gungame_zip ($(numfmt --to=iec --format="%.1f" $size 2>/dev/null || echo $size) bytes)"
        return 0
    else
        log_warning "GunGame zip not found: $gungame_zip"
        log_info "GunGame server will use fallback maps"
        return 1
    fi
}

# Extract map names from mapcycle files
extract_map_names() {
    local mapcycle_file="$1"
    local server_name="$2"

    if [[ ! -f "$mapcycle_file" ]]; then
        log_warning "Mapcycle file not found: $mapcycle_file"
        return
    fi

    # Read mapcycle, skip empty lines and comments
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Remove leading/trailing whitespace
        line=$(echo "$line" | xargs)

        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^# ]]; then
            continue
        fi

        # Add to map list (remove .bsp extension if present)
        local map_name="${line%.bsp}"
        echo "$map_name"
    done < "$mapcycle_file"
}

# Check maps referenced in mapcycles
check_mapcycle_maps() {
    log_info "Checking maps referenced in mapcycles..."

    local total_maps=0
    local missing_maps=0
    local found_maps=0

    # Find all mapcycle.txt files
    local mapcycle_files=$(find "$SERVERS_DIR" -name "mapcycle.txt" -type f)

    if [[ -z "$mapcycle_files" ]]; then
        log_warning "No mapcycle files found"
        return 0
    fi

    # Process each mapcycle file
    for mapcycle_file in $mapcycle_files; do
        local server_name=$(basename $(dirname "$mapcycle_file"))

        if [[ "$VERBOSE" == "true" ]]; then
            log_info "Checking $server_name mapcycle..."
        fi

        # Get unique map names from this mapcycle
        local map_names=$(extract_map_names "$mapcycle_file" "$server_name" | sort | uniq)

        for map_name in $map_names; do
            total_maps=$((total_maps + 1))

            # Standard maps that come with CS 1.6
            local standard_maps=(
                "de_dust2" "de_inferno" "cs_office" "de_train" "de_nuke"
                "de_cbble" "cs_italy" "de_aztec" "cs_militia" "de_dust"
                "de_prodigy" "de_tides" "de_vegas" "cs_assault" "cs_backalley"
                "cs_estate" "cs_havana" "cs_siege" "cs_mansion" "de_piranesi"
                "de_chateau" "de_cpl_fire" "de_cpl_strike" "de_cpl_mill"
            )

            # Check if it's a standard map
            local is_standard=false
            for standard_map in "${standard_maps[@]}"; do
                if [[ "$map_name" == "$standard_map" ]]; then
                    is_standard=true
                    break
                fi
            done

            if [[ "$is_standard" == "true" ]]; then
                found_maps=$((found_maps + 1))
                if [[ "$VERBOSE" == "true" ]]; then
                    log_success "  ✓ $map_name (standard CS map)"
                fi
            elif [[ -f "$MAPS_DIR/$map_name.bsp" ]]; then
                found_maps=$((found_maps + 1))
                if [[ "$VERBOSE" == "true" ]]; then
                    log_success "  ✓ $map_name.bsp (custom map)"
                fi
            else
                missing_maps=$((missing_maps + 1))
                if [[ "$VERBOSE" == "true" ]]; then
                    log_warning "  ⚠ $map_name.bsp (not found)"
                fi
            fi
        done
    done

    # Summary
    echo ""
    log_info "Map validation summary:"
    echo "  Total unique maps referenced: $total_maps"
    echo "  Maps found/available: $found_maps"
    echo "  Maps missing: $missing_maps"

    if [[ $missing_maps -gt 0 ]]; then
        log_warning "Some maps referenced in mapcycles are not available"
        log_info "Missing maps will fall back to de_dust2 at runtime"
        return 1
    else
        log_success "All referenced maps are available!"
        return 0
    fi
}

# List available custom maps
list_custom_maps() {
    log_info "Available custom maps in docker-assets/maps/:"

    local bsp_files=$(find "$MAPS_DIR" -name "*.bsp" -type f 2>/dev/null || true)

    if [[ -z "$bsp_files" ]]; then
        log_warning "No custom maps found"
        return
    fi

    for bsp_file in $bsp_files; do
        local map_name=$(basename "$bsp_file" .bsp)
        local size=$(stat -f%z "$bsp_file" 2>/dev/null || stat -c%s "$bsp_file" 2>/dev/null || echo "unknown")
        local size_fmt=$(numfmt --to=iec --format="%.1f" $size 2>/dev/null || echo "$size bytes")
        log_success "  $map_name.bsp ($size_fmt)"
    done
}

# Main function
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  CS 1.6 Server Asset Validation       ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    local errors=0

    # Check directory structure
    check_directories || errors=$((errors + $?))
    echo ""

    # Check GunGame
    check_gungame || errors=$((errors + $?))
    echo ""

    # List available custom maps
    list_custom_maps
    echo ""

    # Check mapcycle maps
    check_mapcycle_maps || errors=$((errors + $?))
    echo ""

    # Final summary
    echo -e "${BLUE}========================================${NC}"
    if [[ $errors -eq 0 ]]; then
        echo -e "${GREEN}✅ All checks passed!${NC}"
        echo "Your server assets are ready for Docker build."
        echo ""
        echo "Next steps:"
        echo "  1. Rebuild Docker image: docker compose build --no-cache"
        echo "  2. Start servers: docker compose up -d"
        exit 0
    else
        echo -e "${YELLOW}⚠  Some checks failed${NC}"
        echo ""
        echo "Recommendations:"
        echo "  1. Add missing maps to docker-assets/maps/"
        echo "  2. Run with --verbose to see which maps are missing"
        echo "  3. Update mapcycle.txt files if maps are intentionally missing"
        echo ""
        echo "Note: Servers will fall back to de_dust2 for missing maps."
        exit 0  # Exit 0 because missing maps are not fatal
    fi
}

# Show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Validate CS 1.6 server assets in the repository."
    echo ""
    echo "Options:"
    echo "  -v, --verbose    Show detailed map validation"
    echo "  -h, --help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0               Basic validation"
    echo "  $0 --verbose     Detailed validation with map listings"
}

# Parse arguments
case "$1" in
    -h|--help)
        show_help
        exit 0
        ;;
    -v|--verbose)
        VERBOSE=true
        main
        ;;
    "")
        main
        ;;
    *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
