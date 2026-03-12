#!/bin/bash

# YaPB Installation Script for CS 1.6 Servers
# Downloads and installs Yet Another PodBot for ReHLDS/AMX Mod X servers
# Part of zukka CS 1.6 LAN Party Server System

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default configuration
YAPB_VERSION="4.4.957"
YAPB_RELEASE_URL="https://github.com/yapb/yapb/releases/download/${YAPB_VERSION}"
YAPB_LINUX_PACKAGE="yapb-${YAPB_VERSION}-linux.tar.xz"
YAPB_EXTRAS_PACKAGE="yapb-${YAPB_VERSION}-extras.zip"

# Default installation paths
DEFAULT_TARGET_DIR="./yapb-files"
DEFAULT_SERVER_DIR="/opt/steam/hlds/cstrike"

# Logging functions
log() {
    echo -e "${GREEN}[+]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Help function
show_help() {
    echo "YaPB Installation Script for CS 1.6 Servers"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -v, --version       Specify YaPB version (default: ${YAPB_VERSION})"
    echo "  -t, --target DIR    Target directory for YaPB files (default: ${DEFAULT_TARGET_DIR})"
    echo "  -s, --server DIR    Server cstrike directory (default: ${DEFAULT_SERVER_DIR})"
    echo "  -d, --docker        Install directly to Docker container (requires container name)"
    echo "  -c, --container NAME Docker container name (default: cs16-tournament)"
    echo "  --dry-run           Show what would be done without making changes"
    echo "  --skip-download     Skip downloading, use existing files in target directory"
    echo ""
    echo "Examples:"
    echo "  $0                         # Download YaPB to ./yapb-files"
    echo "  $0 -t /tmp/yapb            # Download YaPB to custom directory"
    echo "  $0 -d -c cs16-tournament   # Install YaPB to tournament server container"
    echo "  $0 -s /path/to/cstrike     # Install YaPB to specific server directory"
    echo ""
    echo "Note: For Docker installations, the script will copy files to the container's"
    echo "      cstrike directory and update Metamod plugins.ini"
}

# Parse command line arguments
TARGET_DIR="${DEFAULT_TARGET_DIR}"
SERVER_DIR="${DEFAULT_SERVER_DIR}"
DOCKER_INSTALL=false
CONTAINER_NAME="cs16-tournament"
DRY_RUN=false
SKIP_DOWNLOAD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            YAPB_VERSION="$2"
            shift 2
            ;;
        -t|--target)
            TARGET_DIR="$2"
            shift 2
            ;;
        -s|--server)
            SERVER_DIR="$2"
            shift 2
            ;;
        -d|--docker)
            DOCKER_INSTALL=true
            shift
            ;;
        -c|--container)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-download)
            SKIP_DOWNLOAD=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    if ! command -v curl &> /dev/null; then
        log_error "curl not found. Install curl first."
        exit 1
    fi

    if ! command -v tar &> /dev/null; then
        log_error "tar not found. Install tar first."
        exit 1
    fi

    if [ "$DOCKER_INSTALL" = true ]; then
        if ! command -v docker &> /dev/null; then
            log_error "Docker not found. Install Docker first or remove --docker flag."
            exit 1
        fi

        if ! docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
            log_error "Docker container '${CONTAINER_NAME}' not found or not running."
            log_warn "Available containers:"
            docker ps --format "{{.Names}}" | while read name; do
                log_warn "  - $name"
            done
            exit 1
        fi
    fi

    log "Prerequisites check passed"
}

# Download YaPB files
download_yapb() {
    local target_dir="$1"

    log "Downloading YaPB ${YAPB_VERSION}..."

    # Create target directory
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "${target_dir}"
    fi

    # Download main Linux package
    local linux_package_url="${YAPB_RELEASE_URL}/${YAPB_LINUX_PACKAGE}"
    local linux_package_path="${target_dir}/${YAPB_LINUX_PACKAGE}"

    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would download ${linux_package_url} to ${linux_package_path}"
    else
        if [ ! -f "${linux_package_path}" ] || [ "$SKIP_DOWNLOAD" = false ]; then
            log "Downloading ${YAPB_LINUX_PACKAGE}..."
            curl -L -o "${linux_package_path}" "${linux_package_url}"

            if [ $? -ne 0 ]; then
                log_error "Failed to download ${YAPB_LINUX_PACKAGE}"
                exit 1
            fi
        else
            log "Using existing file: ${linux_package_path}"
        fi
    fi

    # Download extras package (optional)
    local extras_package_url="${YAPB_RELEASE_URL}/${YAPB_EXTRAS_PACKAGE}"
    local extras_package_path="${target_dir}/${YAPB_EXTRAS_PACKAGE}"

    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would download ${extras_package_url} to ${extras_package_path}"
    else
        if [ ! -f "${extras_package_path}" ] || [ "$SKIP_DOWNLOAD" = false ]; then
            log "Downloading ${YAPB_EXTRAS_PACKAGE}..."
            curl -L -o "${extras_package_path}" "${extras_package_url}"

            if [ $? -ne 0 ]; then
                log_warn "Failed to download extras package (optional, continuing)"
                rm -f "${extras_package_path}" 2>/dev/null || true
            fi
        else
            log "Using existing file: ${extras_package_path}"
        fi
    fi

    log "Download complete"
}

# Extract YaPB files
extract_yapb() {
    local target_dir="$1"
    local extract_dir="${target_dir}/extracted"

    log "Extracting YaPB files..."

    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would extract ${target_dir}/${YAPB_LINUX_PACKAGE} to ${extract_dir}"
        if [ -f "${target_dir}/${YAPB_EXTRAS_PACKAGE}" ]; then
            log "DRY RUN: Would extract ${target_dir}/${YAPB_EXTRAS_PACKAGE} to ${extract_dir}"
        fi
        return
    fi

    # Create extraction directory
    mkdir -p "${extract_dir}"

    # Extract main package
    local linux_package_path="${target_dir}/${YAPB_LINUX_PACKAGE}"
    if [ -f "${linux_package_path}" ]; then
        log "Extracting ${YAPB_LINUX_PACKAGE}..."
        tar -xf "${linux_package_path}" -C "${extract_dir}"

        if [ $? -ne 0 ]; then
            log_error "Failed to extract ${YAPB_LINUX_PACKAGE}"
            exit 1
        fi
    else
        log_error "Package not found: ${linux_package_path}"
        exit 1
    fi

    # Extract extras package if available
    local extras_package_path="${target_dir}/${YAPB_EXTRAS_PACKAGE}"
    if [ -f "${extras_package_path}" ]; then
        log "Extracting extras package..."
        if command -v unzip &> /dev/null; then
            unzip -q -o "${extras_package_path}" -d "${extract_dir}"
        else
            log_warn "unzip not found, skipping extras package extraction"
        fi
    fi

    log "Extraction complete"

    # Show extracted contents
    log "Extracted contents in ${extract_dir}:"
    find "${extract_dir}" -type f -name "*.so" -o -name "*.cfg" -o -name "*.txt" | head -20 | while read file; do
        log "  $(basename "${file}")"
    done
}

# Install YaPB to local directory
install_to_directory() {
    local source_dir="$1/extracted"
    local dest_dir="$2"

    log "Installing YaPB to ${dest_dir}..."

    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would copy files from ${source_dir} to ${dest_dir}/addons/yapb"
        log "DRY RUN: Would update ${dest_dir}/addons/metamod/plugins.ini"
        log "DRY RUN: Would copy yapb.cfg to ${dest_dir}/"
        return
    fi

    # Check if source directory exists
    if [ ! -d "${source_dir}" ]; then
        log_error "Source directory not found: ${source_dir}"
        exit 1
    fi

    # Create YaPB directory in server
    local yapb_dest="${dest_dir}/addons/yapb"
    mkdir -p "${yapb_dest}"

    # Copy all files from extracted directory
    log "Copying YaPB files to ${yapb_dest}..."
    cp -r "${source_dir}"/* "${yapb_dest}/" 2>/dev/null || true

    # Find the YaPB plugin file
    local yapb_plugin=$(find "${yapb_dest}" -name "yapb*.so" -o -name "yapb*.dll" | head -1)

    if [ -z "${yapb_plugin}" ]; then
        log_error "Could not find YaPB plugin file (yapb*.so or yapb*.dll)"
        exit 1
    fi

    # Get relative path for plugins.ini
    local plugin_relative_path="addons/yapb/$(basename "${yapb_plugin}")"

    # Update Metamod plugins.ini
    local plugins_ini="${dest_dir}/addons/metamod/plugins.ini"

    if [ -f "${plugins_ini}" ]; then
        # Check if YaPB is already in plugins.ini
        if grep -q "yapb" "${plugins_ini}" 2>/dev/null; then
            log "YaPB already configured in ${plugins_ini}"
        else
            log "Adding YaPB to ${plugins_ini}"
            echo "linux ${plugin_relative_path}" >> "${plugins_ini}"
        fi
    else
        log_warn "Metamod plugins.ini not found at ${plugins_ini}"
        log_warn "Creating new plugins.ini file"
        mkdir -p "$(dirname "${plugins_ini}")"
        echo "linux ${plugin_relative_path}" > "${plugins_ini}"
    fi

    # Copy yapb.cfg to cstrike directory if it exists
    local yapb_cfg_source=$(find "${yapb_dest}" -name "yapb.cfg" | head -1)
    if [ -n "${yapb_cfg_source}" ]; then
        log "Copying yapb.cfg to ${dest_dir}/"
        cp "${yapb_cfg_source}" "${dest_dir}/yapb.cfg"
    fi

    # Set proper permissions
    chmod -R 755 "${yapb_dest}" 2>/dev/null || true

    log "Installation to directory complete"
}

# Install YaPB to Docker container
install_to_docker() {
    local source_dir="$1/extracted"
    local container_name="$2"

    log "Installing YaPB to Docker container: ${container_name}..."

    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would copy files from ${source_dir} to container ${container_name}:/opt/steam/hlds/cstrike/addons/yapb"
        log "DRY RUN: Would update container ${container_name}:/opt/steam/hlds/cstrike/addons/metamod/plugins.ini"
        log "DRY RUN: Would copy yapb.cfg to container ${container_name}:/opt/steam/hlds/cstrike/"
        return
    fi

    # Check if source directory exists
    if [ ! -d "${source_dir}" ]; then
        log_error "Source directory not found: ${source_dir}"
        exit 1
    fi

    # Create YaPB directory in container
    log "Creating directory structure in container..."
    docker exec "${container_name}" mkdir -p /opt/steam/hlds/cstrike/addons/yapb

    # Copy files to container
    log "Copying YaPB files to container..."
    for file in "${source_dir}"/*; do
        if [ -f "${file}" ]; then
            local filename=$(basename "${file}")
            docker cp "${file}" "${container_name}:/opt/steam/hlds/cstrike/addons/yapb/${filename}"
        fi
    done

    # Find the YaPB plugin file in the container
    local yapb_plugin=$(docker exec "${container_name}" find /opt/steam/hlds/cstrike/addons/yapb -name "yapb*.so" -o -name "yapb*.dll" 2>/dev/null | head -1)

    if [ -z "${yapb_plugin}" ]; then
        log_error "Could not find YaPB plugin file in container"
        exit 1
    fi

    # Get relative path for plugins.ini
    local plugin_relative_path="addons/yapb/$(basename "${yapb_plugin}")"

    # Update Metamod plugins.ini in container
    log "Updating Metamod plugins.ini in container..."

    # Check if plugins.ini exists
    if docker exec "${container_name}" test -f /opt/steam/hlds/cstrike/addons/metamod/plugins.ini; then
        # Check if YaPB is already in plugins.ini
        if docker exec "${container_name}" grep -q "yapb" /opt/steam/hlds/cstrike/addons/metamod/plugins.ini 2>/dev/null; then
            log "YaPB already configured in container's plugins.ini"
        else
            log "Adding YaPB to container's plugins.ini"
            docker exec "${container_name}" sh -c "echo 'linux ${plugin_relative_path}' >> /opt/steam/hlds/cstrike/addons/metamod/plugins.ini"
        fi
    else
        log_warn "Metamod plugins.ini not found in container"
        log_warn "Creating new plugins.ini file"
        docker exec "${container_name}" mkdir -p /opt/steam/hlds/cstrike/addons/metamod
        docker exec "${container_name}" sh -c "echo 'linux ${plugin_relative_path}' > /opt/steam/hlds/cstrike/addons/metamod/plugins.ini"
    fi

    # Copy yapb.cfg to cstrike directory if it exists
    local yapb_cfg_source=$(find "${source_dir}" -name "yapb.cfg" | head -1)
    if [ -n "${yapb_cfg_source}" ]; then
        log "Copying yapb.cfg to container's cstrike directory..."
        docker cp "${yapb_cfg_source}" "${container_name}:/opt/steam/hlds/cstrike/yapb.cfg"
    fi

    # Set proper permissions in container
    docker exec "${container_name}" chmod -R 755 /opt/steam/hlds/cstrike/addons/yapb 2>/dev/null || true

    log "Docker installation complete"
    log "You may need to restart the container for changes to take effect:"
    log "  docker restart ${container_name}"
}

# Configure YaPB settings
configure_yapb() {
    local dest_dir="$1"

    log "Configuring YaPB settings..."

    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would configure YaPB settings in ${dest_dir}/yapb.cfg"
        return
    fi

    local yapb_cfg="${dest_dir}/yapb.cfg"

    if [ -f "${yapb_cfg}" ]; then
        log "Found yapb.cfg at ${yapb_cfg}"

        # Backup original config
        cp "${yapb_cfg}" "${yapb_cfg}.backup" 2>/dev/null || true

        # Configure common settings for LAN parties
        log "Applying recommended LAN party settings..."

        # Create a simple configuration script
        cat > /tmp/yapb_configure.sh << 'EOF'
#!/bin/bash
cfg_file="$1"

# Enable fill server mode for empty servers
sed -i 's/^yb_quota_mode.*/yb_quota_mode fill/' "${cfg_file}"
sed -i 's/^yb_join_after_player.*/yb_join_after_player 0/' "${cfg_file}"

# Set bot difficulty (0=easy, 1=normal, 2=hard, 3=expert, 4=nightmare)
sed -i 's/^yb_difficulty.*/yb_difficulty 1/' "${cfg_file}"

# Enable bot chatter
sed -i 's/^yb_chatter.*/yb_chatter on/' "${cfg_file}"

# Allow bots to use all weapons
sed -i 's/^yb_jason_mode.*/yb_jason_mode 0/' "${cfg_file}"

# Enable auto-kick to make room for real players
sed -i 's/^yb_kick_after_player_connect.*/yb_kick_after_player_connect 1/' "${cfg_file}"

# Set bot quota to fill server (adjust based on server maxplayers)
sed -i 's/^yb_quota.*/yb_quota 14/' "${cfg_file}"

# Enable weapon pickup
sed -i 's/^yb_pickup_weapons.*/yb_pickup_weapons 1/' "${cfg_file}"

# Enable grenade usage
sed -i 's/^yb_grenades.*/yb_grenades 1/' "${cfg_file}"
EOF

        chmod +x /tmp/yapb_configure.sh
        /tmp/yapb_configure.sh "${yapb_cfg}"
        rm -f /tmp/yapb_configure.sh

        log "YaPB configuration updated"
        log "Original config backed up to ${yapb_cfg}.backup"
    else
        log_warn "yapb.cfg not found at ${yapb_cfg}"
        log_warn "Using default YaPB configuration"
    fi
}

# Main installation process
main() {
    log "Starting YaPB installation for CS 1.6 servers"
    log "Version: ${YAPB_VERSION}"
    log "Target directory: ${TARGET_DIR}"

    if [ "$DOCKER_INSTALL" = true ]; then
        log "Docker installation: Enabled (container: ${CONTAINER_NAME})"
    else
        log "Server directory: ${SERVER_DIR}"
    fi

    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN MODE: No changes will be made"
    fi

    echo ""

    # Check prerequisites
    check_prerequisites

    # Download YaPB
    if [ "$SKIP_DOWNLOAD" = false ]; then
        download_yapb "${TARGET_DIR}"
    else
        log "Skipping download (--skip-download flag set)"
    fi

    # Extract YaPB
    extract_yapb "${TARGET_DIR}"

    # Install based on mode
    if [ "$DOCKER_INSTALL" = true ]; then
        install_to_docker "${TARGET_DIR}" "${CONTAINER_NAME}"
    else
        install_to_directory "${TARGET_DIR}" "${SERVER_DIR}"
        configure_yapb "${SERVER_DIR}"
    fi

    echo ""
    log "YaPB installation complete!"

    # Show next steps
    if [ "$DOCKER_INSTALL" = true ]; then
        log "Next steps:"
        log "1. Restart the Docker container:"
        log "   docker restart ${CONTAINER_NAME}"
        log "2. Verify YaPB is loading:"
        log "   docker logs ${CONTAINER_NAME} | grep -i yapb"
        log "3. Connect to server and check if bots are present"
    else
        log "Next steps:"
        log "1. Restart your CS 1.6 server"
        log "2. Verify YaPB is loading by checking server logs"
        log "3. Connect to server and check if bots are present"
        log "4. Adjust bot settings in ${SERVER_DIR}/yapb.cfg as needed"
    fi

    log ""
    log "For more information about YaPB configuration, see:"
    log "  https://github.com/yapb/yapb"
    log "  https://yapb.jeefo.net/"
}

# Run main function
main

exit 0
