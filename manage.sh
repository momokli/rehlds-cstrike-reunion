#!/bin/bash

# zukka CS 1.6 Tournament Management Script
# Version: 1.0.0
# Description: Manage zukka tournament, public, and practice CS 1.6 servers

set -e

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
QUERY_SCRIPT="$PROJECT_ROOT/query_server.py"

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    export $(grep -v '^#' "$PROJECT_ROOT/.env" | xargs)
fi

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Server definitions
SERVERS=("tournament" "public" "practice" "gungame")
SERVER_PORTS=("${TOURNAMENT_PORT:-27015}" "${PUBLIC_PORT:-27016}" "${PRACTICE_PORT:-27017}" "${GUNGAME_PORT:-27018}")
SERVER_NAMES=("zukka Tournament Server" "zukka Team Deathmatch" "zukka FFA Deathmatch" "zukka GunGame")

# Helper functions
print_header() {
    echo -e "${BLUE}"
    echo "================================================"
    echo "zukka CS 1.6 Tournament Management"
    echo "================================================"
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}[✓] $1${NC}"
}

print_error() {
    echo -e "${RED}[✗] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

print_info() {
    echo -e "${BLUE}[i] $1${NC}"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        # Try docker compose (v2)
        if ! docker compose version &> /dev/null; then
            print_error "Docker Compose is not installed"
            exit 1
        fi
        DOCKER_COMPOSE_CMD="docker compose"
    else
        DOCKER_COMPOSE_CMD="docker-compose"
    fi

    print_success "Docker and Docker Compose are available"
}

check_python() {
    if ! command -v python3 &> /dev/null; then
        print_warning "Python 3 is not installed. Some features may be limited."
        return 1
    fi
    return 0
}

get_server_index() {
    local server_name=$1
    for i in "${!SERVERS[@]}"; do
        if [[ "${SERVERS[$i]}" == "$server_name" ]]; then
            echo $i
            return
        fi
    done
    echo -1
}

# Command functions
start_server() {
    local server=$1
    local index=$(get_server_index "$server")

    if [ $index -eq -1 ]; then
        print_error "Unknown server: $server"
        print_info "Available servers: ${SERVERS[*]}"
        exit 1
    fi

    print_info "Starting ${SERVER_NAMES[$index]} server..."
    $DOCKER_COMPOSE_CMD up -d "${server}-server"

    if [ $? -eq 0 ]; then
        print_success "${SERVER_NAMES[$index]} server started on port ${SERVER_PORTS[$index]}"
    else
        print_error "Failed to start ${SERVER_NAMES[$index]} server"
    fi
}

stop_server() {
    local server=$1
    local index=$(get_server_index "$server")

    if [ $index -eq -1 ]; then
        print_error "Unknown server: $server"
        print_info "Available servers: ${SERVERS[*]}"
        exit 1
    fi

    print_info "Stopping ${SERVER_NAMES[$index]} server..."
    $DOCKER_COMPOSE_CMD stop "${server}-server"

    if [ $? -eq 0 ]; then
        print_success "${SERVER_NAMES[$index]} server stopped"
    else
        print_error "Failed to stop ${SERVER_NAMES[$index]} server"
    fi
}

restart_server() {
    local server=$1
    local index=$(get_server_index "$server")

    if [ $index -eq -1 ]; then
        print_error "Unknown server: $server"
        print_info "Available servers: ${SERVERS[*]}"
        exit 1
    fi

    print_info "Restarting ${SERVER_NAMES[$index]} server..."
    $DOCKER_COMPOSE_CMD restart "${server}-server"

    if [ $? -eq 0 ]; then
        print_success "${SERVER_NAMES[$index]} server restarted"
    else
        print_error "Failed to restart ${SERVER_NAMES[$index]} server"
    fi
}

view_logs() {
    local server=$1
    local follow=$2
    local index=$(get_server_index "$server")

    if [ $index -eq -1 ]; then
        print_error "Unknown server: $server"
        print_info "Available servers: ${SERVERS[*]}"
        exit 1
    fi

    print_info "Showing logs for ${SERVER_NAMES[$index]} server..."

    if [ "$follow" = true ]; then
        $DOCKER_COMPOSE_CMD logs -f "${server}-server"
    else
        $DOCKER_COMPOSE_CMD logs "${server}-server"
    fi
}

query_server() {
    local server=$1
    local index=$(get_server_index "$server")

    if [ $index -eq -1 ]; then
        print_error "Unknown server: $server"
        print_info "Available servers: ${SERVERS[*]}"
        exit 1
    fi

    local port=${SERVER_PORTS[$index]}

    print_info "Querying ${SERVER_NAMES[$index]} server on port $port..."

    if check_python; then
        if [ -f "$QUERY_SCRIPT" ]; then
            python3 "$QUERY_SCRIPT" localhost "$port"
        else
            print_warning "Query script not found at $QUERY_SCRIPT"
            print_info "Trying alternative query method..."
            query_server_fallback "$port"
        fi
    else
        print_warning "Python not available, using fallback method..."
        query_server_fallback "$port"
    fi
}

query_server_fallback() {
    local port=$1

    # Try to get basic server info using netcat
    echo -e "\n${BLUE}Server Status (Port: $port)${NC}"
    echo "----------------------------------------"

    # Check if container is running
    local container_name="cs16-$(get_server_name_by_port "$port" | tr '[:upper:]' '[:lower:]')"
    if docker ps | grep -q "$container_name"; then
        print_success "Container: Running"

        # Get basic info from docker
        echo "Hostname: $(docker exec "$container_name" cat /opt/steam/hlds/cstrike/config/server.cfg 2>/dev/null | grep '^hostname' | cut -d'"' -f2 2>/dev/null || echo "Unknown")"
        echo "Port: $port"
    else
        print_error "Container: Not running"
    fi

    # Check if port is listening
    if netstat -an | grep -q ":$port.*LISTEN"; then
        print_success "Port $port: Listening"
    else
        print_warning "Port $port: Not listening"
    fi
}

get_server_name_by_port() {
    local port=$1
    for i in "${!SERVER_PORTS[@]}"; do
        if [[ "${SERVER_PORTS[$i]}" == "$port" ]]; then
            echo "${SERVER_NAMES[$i]}"
            return
        fi
    done
    echo "Unknown"
}

status_all() {
    print_header
    echo -e "${BLUE}Server Status Overview${NC}"
    echo "----------------------------------------"

    for i in "${!SERVERS[@]}"; do
        local server=${SERVERS[$i]}
        local port=${SERVER_PORTS[$i]}
        local name=${SERVER_NAMES[$i]}
        local container_name="cs16-$server"

        echo -e "\n${YELLOW}$name Server (Port: $port)${NC}"
        echo "Container: $container_name"

        # Check container status
        if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "$container_name"; then
            local container_status=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep "$container_name" | awk '{print $2}')
            print_success "Status: $container_status"

            # Get hostname from config
            local hostname=$(docker exec "$container_name" cat /opt/steam/hlds/cstrike/config/server.cfg 2>/dev/null | grep '^hostname' | cut -d'"' -f2 2>/dev/null || echo "Unknown")
            echo "Hostname: $hostname"

            # Get map info (if we can query)
            if check_python && [ -f "$QUERY_SCRIPT" ]; then
                local map_info=$(python3 "$QUERY_SCRIPT" localhost "$port" 2>/dev/null | grep "Map:" | cut -d':' -f2 | xargs)
                if [ -n "$map_info" ]; then
                    echo "Current Map: $map_info"
                fi
            fi
        else
            print_error "Status: Not running"
        fi
    done

    echo -e "\n----------------------------------------"
    print_info "Use './manage.sh query <server>' for detailed information"
}

update_config() {
    local server=$1
    local index=$(get_server_index "$server")

    if [ $index -eq -1 ]; then
        print_error "Unknown server: $server"
        print_info "Available servers: ${SERVERS[*]}"
        exit 1
    fi

    print_info "Updating configuration for ${SERVER_NAMES[$index]} server..."

    # Restart the server to pick up config changes
    restart_server "$server"

    print_success "Configuration updated and server restarted"
}

backup_configs() {
    local backup_dir="$PROJECT_ROOT/backup/$(date +%Y%m%d_%H%M%S)"

    print_info "Creating backup of server configurations..."

    mkdir -p "$backup_dir"

    for server in "${SERVERS[@]}"; do
        local server_dir="$PROJECT_ROOT/servers/$server"
        local backup_server_dir="$backup_dir/$server"

        if [ -d "$server_dir" ]; then
            mkdir -p "$backup_server_dir"
            cp -r "$server_dir"/* "$backup_server_dir"/
            print_success "Backed up $server configuration"
        else
            print_warning "Configuration directory not found for $server: $server_dir"
        fi
    done

    # Also backup docker-compose.yml
    cp "$DOCKER_COMPOSE_FILE" "$backup_dir/"

    print_success "Backup created at: $backup_dir"
    echo "Backup contents:"
    tree "$backup_dir"
}

restore_configs() {
    local backup_dir=$1

    if [ ! -d "$backup_dir" ]; then
        print_error "Backup directory not found: $backup_dir"
        print_info "Available backups in: $PROJECT_ROOT/backup/"
        if [ -d "$PROJECT_ROOT/backup" ]; then
            ls -la "$PROJECT_ROOT/backup/"
        fi
        exit 1
    fi

    print_warning "This will overwrite current server configurations!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Restore cancelled"
        exit 0
    fi

    print_info "Restoring configurations from: $backup_dir"

    for server in "${SERVERS[@]}"; do
        local backup_server_dir="$backup_dir/$server"
        local server_dir="$PROJECT_ROOT/servers/$server"

        if [ -d "$backup_server_dir" ]; then
            mkdir -p "$server_dir"
            cp -r "$backup_server_dir"/* "$server_dir"/
            print_success "Restored $server configuration"
        else
            print_warning "Backup not found for $server: $backup_server_dir"
        fi
    done

    # Restore docker-compose.yml if it exists in backup
    if [ -f "$backup_dir/docker-compose.yml" ]; then
        cp "$backup_dir/docker-compose.yml" "$DOCKER_COMPOSE_FILE"
        print_success "Restored docker-compose.yml"
    fi

    print_success "Configurations restored. Restart servers to apply changes."
}

build_images() {
    print_info "Building Docker images..."
    $DOCKER_COMPOSE_CMD build

    if [ $? -eq 0 ]; then
        print_success "Docker images built successfully"
    else
        print_error "Failed to build Docker images"
    fi
}

show_help() {
    print_header

    echo -e "${GREEN}Usage:${NC} ./manage.sh <command> [options]"
    echo ""
    echo -e "${BLUE}Available commands:${NC}"
    echo ""
    echo "  ${YELLOW}General Commands:${NC}"
    echo "    help                    Show this help message"
    echo "    status                  Show status of all servers"
    echo "    build                   Build Docker images"
    echo "    backup                  Backup server configurations"
    echo "    restore <backup_dir>    Restore configurations from backup"
    echo ""
    echo "  ${YELLOW}Server Management:${NC}"
    echo "    start all               Start all servers"
    echo "    start <server>          Start specific server"
    echo "    stop all                Stop all servers"
    echo "    stop <server>           Stop specific server"
    echo "    restart all             Restart all servers"
    echo "    restart <server>        Restart specific server"
    echo "    logs <server>           View server logs"
    echo "    logs <server> -f        Follow server logs"
    echo "    query <server>          Query server information"
    echo "    update <server>         Update config and restart server"
    echo ""
    echo "  ${YELLOW}Available Servers:${NC}"
    echo "tournament              5v5 Tournament Server (port 27015)"
    echo "public                  Team Deathmatch Server (port 27016)"
    echo "practice                FFA Deathmatch Server (port 27017)"
    echo "gungame                 GunGame Server (port 27018)"
    echo ""
    echo "  ${YELLOW}Examples:${NC}"
    echo "    ./manage.sh start all"
    echo "    ./manage.sh query tournament"
    echo "    ./manage.sh logs tournament -f"
    echo "    ./manage.sh backup"
    echo "    ./manage.sh restore backup/20250101_120000"
    echo ""
    echo -e "${BLUE}Server Ports:${NC}"
    echo "  Tournament: ${TOURNAMENT_PORT:-27015}"
    echo "  Public:     ${PUBLIC_PORT:-27016}"
    echo "  Practice:   ${PRACTICE_PORT:-27017}"
    echo "  GunGame:    ${GUNGAME_PORT:-27018}"
}

# Main script logic
main() {
    check_docker

    local command=$1
    local target=$2
    local option=$3

    case $command in
        help|--help|-h)
            show_help
            ;;

        start)
            if [ -z "$target" ]; then
                print_error "Please specify a server or 'all'"
                show_help
                exit 1
            fi

            if [ "$target" = "all" ]; then
                print_info "Starting all servers..."
                $DOCKER_COMPOSE_CMD up -d
                print_success "All servers started"
            else
                start_server "$target"
            fi
            ;;

        stop)
            if [ -z "$target" ]; then
                print_error "Please specify a server or 'all'"
                show_help
                exit 1
            fi

            if [ "$target" = "all" ]; then
                print_info "Stopping all servers..."
                $DOCKER_COMPOSE_CMD down
                print_success "All servers stopped"
            else
                stop_server "$target"
            fi
            ;;

        restart)
            if [ -z "$target" ]; then
                print_error "Please specify a server or 'all'"
                show_help
                exit 1
            fi

            if [ "$target" = "all" ]; then
                print_info "Restarting all servers..."
                $DOCKER_COMPOSE_CMD restart
                print_success "All servers restarted"
            else
                restart_server "$target"
            fi
            ;;

        logs)
            if [ -z "$target" ]; then
                print_error "Please specify a server"
                show_help
                exit 1
            fi

            local follow=false
            if [ "$option" = "-f" ]; then
                follow=true
            fi

            view_logs "$target" "$follow"
            ;;

        query)
            if [ -z "$target" ]; then
                print_error "Please specify a server"
                show_help
                exit 1
            fi

            if [ "$target" = "all" ]; then
                print_info "Querying all servers..."
                if check_python && [ -f "$QUERY_SCRIPT" ]; then
                    python3 "$QUERY_SCRIPT" --list
                else
                    for i in "${!SERVERS[@]}"; do
                        query_server "${SERVERS[$i]}"
                        echo ""
                    done
                fi
            else
                query_server "$target"
            fi
            ;;

        status)
            status_all
            ;;

        update)
            if [ -z "$target" ]; then
                print_error "Please specify a server"
                show_help
                exit 1
            fi

            if [ "$target" = "all" ]; then
                print_info "Updating all servers..."
                for server in "${SERVERS[@]}"; do
                    update_config "$server"
                done
            else
                update_config "$target"
            fi
            ;;

        backup)
            backup_configs
            ;;

        restore)
            if [ -z "$target" ]; then
                print_error "Please specify backup directory"
                show_help
                exit 1
            fi

            restore_configs "$target"
            ;;

        build)
            build_images
            ;;

        "")
            print_error "No command specified"
            show_help
            exit 1
            ;;

        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
