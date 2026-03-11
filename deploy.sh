#!/bin/bash

# Simple CS 1.6 LAN Party Deployment Script
# Deploys gun game, FFA DM, tournament, and TDM servers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0
]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
ENV_FILE="$SCRIPT_DIR/.env"

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

# Check prerequisites
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker not found. Install Docker first."
        exit 1
    fi

    if docker compose version &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
    else
        log_error "Docker Compose not found. Install Docker Compose."
        exit 1
    fi

    log "Using $DOCKER_COMPOSE_CMD"
}

# Check if ports are in use
check_ports() {
    log "Checking ports..."

    # Source .env if it exists
    if [ -f "$ENV_FILE" ]; then
        # Export variables from .env
        export $(grep -v '^#' "$ENV_FILE" | xargs)
        log "Loaded environment from $ENV_FILE"
    fi

    # Default ports if not set in .env
    TOURNAMENT_PORT=${TOURNAMENT_PORT:-27015}
    PUBLIC_PORT=${PUBLIC_PORT:-27016}
    PRACTICE_PORT=${PRACTICE_PORT:-27017}
    GUNGAME_PORT=${GUNGAME_PORT:-27018}

    local ports=("$TOURNAMENT_PORT" "$PUBLIC_PORT" "$PRACTICE_PORT" "$GUNGAME_PORT")
    local in_use=()

    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            in_use+=("$port")
            log_warn "Port $port is already in use"
        else
            log "Port $port is available"
        fi
    done

    if [ ${#in_use[@]} -gt 0 ]; then
        log_warn "Some ports are already in use: ${in_use[*]}"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Aborting deployment"
            exit 1
        fi
    fi
}

# Build images if needed
build_images() {
    log "Building Docker images (this may take a few minutes)..."
    $DOCKER_COMPOSE_CMD build
    log "Images built successfully"
}

# Start servers
start_servers() {
    log "Starting CS 1.6 servers..."

    # Stop any existing containers first
    $DOCKER_COMPOSE_CMD down --remove-orphans 2>/dev/null || true

    # Use --build to ensure latest images are used
    $DOCKER_COMPOSE_CMD up -d --build

    if [ $? -eq 0 ]; then
        log "Servers started successfully"
    else
        log_error "Failed to start servers"
        exit 1
    fi
}

# Show server status
show_status() {
    log "Server status:"
    echo ""

    # Get container status
    $DOCKER_COMPOSE_CMD ps

    echo ""
    log "Server ports (from .env or defaults):"

    # Source .env again for ports
    if [ -f "$ENV_FILE" ]; then
        export $(grep -v '^#' "$ENV_FILE" | xargs)
    fi

    echo "  Tournament: ${TOURNAMENT_PORT:-27015}"
    echo "  Public:     ${PUBLIC_PORT:-27016}"
    echo "  Practice:   ${PRACTICE_PORT:-27017}"
    echo "  GunGame:    ${GUNGAME_PORT:-27018}"

    echo ""
    log "To view logs: docker compose logs [server-name]"
    log "To stop: docker compose down"
}

# Main deployment function
deploy() {
    log "Starting CS 1.6 LAN party deployment"

    check_docker
    check_ports
    build_images
    start_servers
    show_status

    log "Deployment complete! Connect to servers using:"
    log "  connect <server-ip>:<port>"
}

# Help function
show_help() {
    echo "Simple CS 1.6 LAN Party Deployment"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -b, --build    Build images only (don't start servers)"
    echo "  -s, --status   Show server status only"
    echo "  -d, --down     Stop all servers"
    echo "  -l, --logs     Show logs for all servers"
    echo ""
    echo "Examples:"
    echo "  $0             Deploy all servers"
    echo "  $0 --status    Check server status"
    echo "  $0 --down      Stop all servers"
    echo ""
    echo "Configuration:"
    echo "  Edit .env file to change ports and server names"
    echo "  Edit docker-compose.yml to change server configurations"
}

# Parse command line arguments
if [ $# -eq 0 ]; then
    deploy
    exit 0
fi

case $1 in
    -h|--help)
        show_help
        ;;
    -b|--build)
        check_docker
        build_images
        ;;
    -s|--status)
        check_docker
        show_status
        ;;
    -d|--down)
        check_docker
        log "Stopping all servers..."
        $DOCKER_COMPOSE_CMD down
        log "Servers stopped"
        ;;
    -l|--logs)
        check_docker
        log "Showing logs (Ctrl+C to exit)..."
        $DOCKER_COMPOSE_CMD logs -f
        ;;
    *)
        log_error "Unknown option: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
