#!/bin/bash

# zukka CS 1.6 Tournament System Deployment Script
# Deploys tournament, public, and practice servers to production
# Part of zukka LAN Tournament System - hub.zukkafabrik.de

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# Script version
VERSION="1.0.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Deployment directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
DEPLOY_LOG="$PROJECT_ROOT/deploy.log"
BACKUP_DIR="$PROJECT_ROOT/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Server configurations
SERVERS=("tournament" "public" "practice")
SERVER_PORTS=("27015" "27016" "27017")
SERVER_NAMES=("zukka Tournament" "zukka Public" "zukka Practice")

# Docker configuration
DOCKER_COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
ENV_EXAMPLE="$PROJECT_ROOT/.env.example"
ENV_FILE="$PROJECT_ROOT/.env"

# Git configuration
GIT_REMOTE="origin"
GIT_BRANCH="main"
GIT_URL="git@github.com:momokli/rehlds-cstrike-reunion.git"

# Deployment options (can be overridden by command line)
DEPLOY_ACTION="deploy"  # deploy, rollback, status, verify
SKIP_BUILD=false
FORCE_RECREATE=false
DRY_RUN=false
VERBOSE=false

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

log_header() {
    echo -e "\n${BLUE}================================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================================================${NC}\n"
}

# Error handling
error_exit() {
    log_error "$1"
    log "Deployment failed. Check $DEPLOY_LOG for details."
    exit 1
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        error_exit "Required command not found: $1"
    fi
}

# File operations
backup_configs() {
    log "Creating backup of server configurations..."

    local backup_path="$BACKUP_DIR/$TIMESTAMP"
    mkdir -p "$backup_path"

    for server in "${SERVERS[@]}"; do
        local server_dir="$PROJECT_ROOT/servers/$server"
        local backup_server_dir="$backup_path/$server"

        if [ -d "$server_dir" ]; then
            mkdir -p "$backup_server_dir"
            cp -r "$server_dir"/* "$backup_server_dir"/
            log_success "Backed up $server configuration"
        else
            log_warning "Configuration directory not found for $server: $server_dir"
        fi
    done

    # Also backup docker-compose.yml and .env if they exist
    [ -f "$DOCKER_COMPOSE_FILE" ] && cp "$DOCKER_COMPOSE_FILE" "$backup_path/"
    [ -f "$ENV_FILE" ] && cp "$ENV_FILE" "$backup_path/"

    log_success "Backup created at: $backup_path"
    echo "$backup_path"  # Return backup path for potential rollback
}

setup_environment() {
    log "Setting up environment..."

    # Check if .env exists, if not create from example
    if [ ! -f "$ENV_FILE" ]; then
        if [ -f "$ENV_EXAMPLE" ]; then
            log_warning ".env file not found. Creating from .env.example..."
            cp "$ENV_EXAMPLE" "$ENV_FILE"
            log_success "Created .env file from template"
            log_warning "Please edit $ENV_FILE with your configuration values!"
        else
            error_exit ".env.example not found. Cannot create .env file."
        fi
    else
        log_success ".env file already exists"
    fi

    # Set permissions
    chmod 600 "$ENV_FILE" 2>/dev/null || true
}

check_docker() {
    log "Checking Docker and Docker Compose..."

    check_command "docker"

    # Try docker compose v2 first, then docker-compose v1
    if docker compose version &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker compose"
        log_success "Using Docker Compose v2"
    elif command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
        log_success "Using Docker Compose v1"
    else
        error_exit "Docker Compose not found"
    fi

    log_success "Docker and Docker Compose are available"
}

# ============================================================================
# DEPLOYMENT FUNCTIONS
# ============================================================================

git_pull() {
    log_header "STEP 1: GIT OPERATIONS"

    # Check if we're in a git repository
    if [ ! -d "$PROJECT_ROOT/.git" ]; then
        log_warning "Not a git repository. Cloning from remote..."
        git clone "$GIT_URL" "$PROJECT_ROOT" || error_exit "Failed to clone repository"
        cd "$PROJECT_ROOT"
    fi

    # Check remote
    if ! git remote | grep -q "$GIT_REMOTE"; then
        log_warning "Remote '$GIT_REMOTE' not found. Adding remote..."
        git remote add "$GIT_REMOTE" "$GIT_URL"
    fi

    # Fetch latest changes
    log "Fetching latest changes from $GIT_REMOTE/$GIT_BRANCH..."
    git fetch "$GIT_REMOTE" "$GIT_BRANCH" || error_exit "Failed to fetch from git"

    # Check if we need to pull
    LOCAL_REV=$(git rev-parse HEAD)
    REMOTE_REV=$(git rev-parse "$GIT_REMOTE/$GIT_BRANCH")

    if [ "$LOCAL_REV" = "$REMOTE_REV" ]; then
        log_success "Already up to date with $GIT_REMOTE/$GIT_BRANCH"
    else
        log "Pulling latest changes..."
        git pull "$GIT_REMOTE" "$GIT_BRANCH" || error_exit "Failed to pull from git"
        log_success "Updated to latest version: $(git log -1 --pretty=format:'%H %s')"
    fi
}

build_images() {
    log_header "STEP 2: BUILD DOCKER IMAGES"

    if [ "$SKIP_BUILD" = true ]; then
        log_warning "Skipping Docker image build (--skip-build flag)"
        return 0
    fi

    log "Building Docker images (this may take several minutes)..."

    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would run: $DOCKER_COMPOSE_CMD build"
        return 0
    fi

    $DOCKER_COMPOSE_CMD build || error_exit "Failed to build Docker images"
    log_success "Docker images built successfully"
}

stop_servers() {
    log_header "STEP 3: STOPPING EXISTING SERVERS"

    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would stop all servers"
        return 0
    fi

    log "Stopping all CS 1.6 servers..."
    $DOCKER_COMPOSE_CMD down --remove-orphans || log_warning "Some containers may have failed to stop"
    log_success "All servers stopped"
}

start_servers() {
    log_header "STEP 4: STARTING SERVERS"

    local compose_args=("-d")

    if [ "$FORCE_RECREATE" = true ]; then
        compose_args+=("--force-recreate")
    fi

    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would start servers with args: ${compose_args[*]}"
        return 0
    fi

    log "Starting all CS 1.6 servers..."
    $DOCKER_COMPOSE_CMD up "${compose_args[@]}" || error_exit "Failed to start servers"
    log_success "All servers started"

    # Wait a bit for servers to initialize
    log "Waiting for servers to initialize..."
    sleep 10
}

verify_deployment() {
    log_header "STEP 5: VERIFYING DEPLOYMENT"

    log "Checking if all containers are running..."

    local all_running=true

    for i in "${!SERVERS[@]}"; do
        local server=${SERVERS[$i]}
        local port=${SERVER_PORTS[$i]}
        local container_name="cs16-$server"

        # Check container status
        if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "$container_name"; then
            local status=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep "$container_name" | awk '{print $2}')
            log_success "$container_name: $status"

            # Try to query server (if query tool is available)
            if [ -f "$PROJECT_ROOT/query_server.py" ]; then
                log "Querying $container_name on port $port..."
                if timeout 5 python3 "$PROJECT_ROOT/query_server.py" localhost "$port" &> /dev/null; then
                    log_success "Server $container_name is responding"
                else
                    log_warning "Server $container_name is not responding to queries (may still be starting)"
                fi
            fi
        else
            log_error "$container_name: NOT RUNNING"
            all_running=false
        fi
    done

    if [ "$all_running" = true ]; then
        log_success "All servers are running"
    else
        log_warning "Some servers may not be running correctly"
    fi

    # Show summary
    log "\nDeployment Summary:"
    echo "---------------------"
    $DOCKER_COMPOSE_CMD ps
}

rollback() {
    log_header "ROLLING BACK DEPLOYMENT"

    local backup_path="$1"

    if [ ! -d "$backup_path" ]; then
        error_exit "Backup directory not found: $backup_path"
    fi

    log_warning "Rolling back to backup: $backup_path"
    read -p "Are you sure you want to rollback? This will overwrite current configurations. (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Rollback cancelled"
        return 0
    fi

    # Restore configurations
    log "Restoring server configurations..."

    for server in "${SERVERS[@]}"; do
        local backup_server_dir="$backup_path/$server"
        local server_dir="$PROJECT_ROOT/servers/$server"

        if [ -d "$backup_server_dir" ]; then
            mkdir -p "$server_dir"
            cp -r "$backup_server_dir"/* "$server_dir"/
            log_success "Restored $server configuration"
        fi
    done

    # Restore docker-compose.yml if it exists in backup
    if [ -f "$backup_path/docker-compose.yml" ]; then
        cp "$backup_path/docker-compose.yml" "$DOCKER_COMPOSE_FILE"
        log_success "Restored docker-compose.yml"
    fi

    # Restore .env if it exists in backup
    if [ -f "$backup_path/.env" ]; then
        cp "$backup_path/.env" "$ENV_FILE"
        log_success "Restored .env"
    fi

    log_success "Rollback complete. Restart servers to apply changes."
}

show_status() {
    log_header "CURRENT DEPLOYMENT STATUS"

    check_docker

    log "Current git status:"
    echo "---------------------"
    git status --short || log_warning "Not a git repository"

    log "\nDocker container status:"
    echo "---------------------"
    $DOCKER_COMPOSE_CMD ps

    log "\nRecent deployment logs:"
    echo "---------------------"
    if [ -f "$DEPLOY_LOG" ]; then
        tail -20 "$DEPLOY_LOG"
    else
        log_warning "No deployment log found"
    fi

    log "\nAvailable backups:"
    echo "---------------------"
    if [ -d "$BACKUP_DIR" ]; then
        ls -la "$BACKUP_DIR/" | head -10
    else
        log_warning "No backups found"
    fi
}

# ============================================================================
# MAIN DEPLOYMENT FLOW
# ============================================================================

deploy() {
    log_header "ZUKKA CS 1.6 TOURNAMENT SYSTEM DEPLOYMENT"
    log "Version: $VERSION | Timestamp: $TIMESTAMP"
    log "Project: $PROJECT_ROOT"

    # Create log file
    mkdir -p "$(dirname "$DEPLOY_LOG")"
    exec > >(tee -a "$DEPLOY_LOG") 2>&1

    # Check prerequisites
    check_docker

    # Backup current configurations
    local backup_path=$(backup_configs)

    # Setup environment
    setup_environment

    # Git operations
    git_pull

    # Build images
    build_images

    # Stop existing servers
    stop_servers

    # Start servers
    start_servers

    # Verify deployment
    verify_deployment

    log_header "DEPLOYMENT COMPLETE"
    log_success "zukka CS 1.6 Tournament System successfully deployed!"
    log "Backup saved at: $backup_path"
    log "Deployment log: $DEPLOY_LOG"
    log "\nServer ports:"
    echo "  Tournament: 27015 (2v2 Competitive)"
    echo "  Public:     27016 (24-player Casual)"
    echo "  Practice:   27017 (12-player Training)"
    log "\nUse './manage.sh status' to check server status"
    log "Use './manage.sh query <server>' for detailed server information"
}

# ============================================================================
# COMMAND LINE PARSING
# ============================================================================

show_help() {
    cat << EOF
zukka CS 1.6 Tournament System Deployment Script v$VERSION

Usage: $0 [OPTIONS] [ACTION]

Actions:
  deploy           Deploy/update all servers (default)
  rollback <dir>   Rollback to a specific backup directory
  status           Show current deployment status
  verify           Verify deployment without making changes

Options:
  --skip-build     Skip Docker image building
  --force-recreate Force recreation of containers
  --dry-run        Show what would be done without making changes
  --verbose        Show more detailed output
  --help           Show this help message

Examples:
  $0                    # Deploy all servers
  $0 deploy             # Same as above
  $0 status             # Show current status
  $0 --dry-run deploy   # Show deployment plan without executing
  $0 rollback backups/20240101_120000  # Rollback to specific backup

Environment:
  The script uses .env file for configuration. If not present,
  it will be created from .env.example.

EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            deploy)
                DEPLOY_ACTION="deploy"
                shift
                ;;
            rollback)
                DEPLOY_ACTION="rollback"
                if [[ $# -gt 1 && ! ${2:-} =~ ^-- ]]; then
                    ROLLBACK_DIR="$2"
                    shift 2
                else
                    error_exit "Rollback requires a backup directory path"
                fi
                ;;
            status)
                DEPLOY_ACTION="status"
                shift
                ;;
            verify)
                DEPLOY_ACTION="verify"
                shift
                ;;
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --force-recreate)
                FORCE_RECREATE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                set -x
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                echo "zukka CS 1.6 Deployment Script v$VERSION"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    parse_arguments "$@"

    log_header "ZUKKA CS 1.6 TOURNAMENT DEPLOYMENT"
    log "Starting at: $(date)"
    log "Action: $DEPLOY_ACTION"

    case $DEPLOY_ACTION in
        deploy)
            deploy
            ;;
        rollback)
            if [ -z "${ROLLBACK_DIR:-}" ]; then
                error_exit "Rollback directory not specified"
            fi
            rollback "$ROLLBACK_DIR"
            ;;
        status)
            show_status
            ;;
        verify)
            check_docker
            verify_deployment
            ;;
        *)
            error_exit "Unknown action: $DEPLOY_ACTION"
            ;;
    esac

    log "\nDeployment script completed at: $(date)"
}

# Run main function
main "$@"
