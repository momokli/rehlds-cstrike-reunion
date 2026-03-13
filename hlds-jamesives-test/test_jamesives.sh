#!/bin/bash
# JamesIves/hlds-docker Test Script
# This script tests the JamesIves hlds-docker image for CS 1.6 server
# It checks if we can load custom maps without the de_dust2 fallback issue

set -e

echo "================================================"
echo "JamesIves/hlds-docker CS 1.6 Server Test"
echo "================================================"
echo "Date: $(date)"
echo "Working directory: $(pwd)"
echo "================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if port is in use
check_port() {
    local port=$1
    if lsof -i :$port > /dev/null 2>&1; then
        print_warn "Port $port is already in use"
        return 1
    fi
    return 0
}

# Function to wait for server to start
wait_for_server() {
    local container_name=$1
    local max_attempts=30
    local attempt=1

    print_info "Waiting for server '$container_name' to start..."

    while [ $attempt -le $max_attempts ]; do
        if docker logs "$container_name" 2>/dev/null | grep -q "Connection to Steam servers successful"; then
            print_info "Server '$container_name' started successfully (attempt $attempt/$max_attempts)"
            return 0
        fi

        if docker logs "$container_name" 2>/dev/null | grep -q "VAC secure mode is activated"; then
            print_info "Server '$container_name' is running with VAC (attempt $attempt/$max_attempts)"
            return 0
        fi

        if [ $attempt -eq $max_attempts ]; then
            print_warn "Server '$container_name' not fully started after $max_attempts attempts, continuing anyway"
            return 1
        fi

        sleep 2
        attempt=$((attempt + 1))
    done

    return 1
}

# Function to test map loading
test_map_loading() {
    local container_name=$1
    local test_map=$2
    local test_name=$3

    print_info "Testing $test_name: Starting server with map '$test_map'"

    # Stop existing container if running
    docker rm -f "$container_name" > /dev/null 2>&1 || true

    # Start container with test map
    if docker run -d \
        --name "$container_name" \
        -p 27030:27015/udp \
        -p 27030:27015 \
        -p 26900:26900/udp \
        -v "$(pwd)/config:/temp/config:ro" \
        -v "$(pwd)/mods:/temp/mods:ro" \
        -v "$(pwd)/../docker-assets/maps:/temp/mods/cstrike/maps:ro" \
        jives/hlds:cstrike \
        +log on +rcon_password "test123" +maxplayers 16 +map "$test_map" +hostname "Test: $test_map" > /dev/null 2>&1; then

        print_info "Container '$container_name' started with map '$test_map'"

        # Wait for server to start
        if wait_for_server "$container_name"; then
            # Check logs for map loading
            local logs=$(docker logs "$container_name" 2>/dev/null | tail -50)

            if echo "$logs" | grep -q "Mapchange to $test_map"; then
                print_info "✓ Server loaded map '$test_map' successfully"

                # Check if it changed to de_dust2
                if echo "$logs" | grep -q "Mapchange to de_dust2"; then
                    print_error "✗ Server changed from '$test_map' to de_dust2 (FAIL)"
                    echo "=== Log snippet ==="
                    echo "$logs" | grep -A5 -B5 "Mapchange"
                    echo "==================="
                    return 1
                else
                    print_info "✓ Server stayed on map '$test_map' (SUCCESS)"
                    return 0
                fi
            else
                print_warn "? No mapchange message found for '$test_map' in logs"
                echo "=== Last 20 lines of logs ==="
                docker logs "$container_name" 2>/dev/null | tail -20
                echo "============================"
                return 2
            fi
        else
            print_warn "? Server '$container_name' didn't start properly"
            return 2
        fi
    else
        print_error "Failed to start container '$container_name'"
        return 1
    fi
}

# Function to clean up
cleanup() {
    print_info "Cleaning up containers..."
    docker rm -f cs16-test-de_dust2 cs16-test-cs_italy cs16-test-aim_headshot > /dev/null 2>&1 || true
}

# Main test execution
main() {
    echo ""
    print_info "Starting JamesIves/hlds-docker tests..."
    echo ""

    # Clean up first
    cleanup

    # Test 1: Standard map (de_dust2) - should work
    print_info "=== TEST 1: Standard map (de_dust2) ==="
    if test_map_loading "cs16-test-de_dust2" "de_dust2" "Standard Map Test"; then
        print_info "Test 1 PASSED"
    else
        print_warn "Test 1 issues encountered"
    fi
    cleanup
    sleep 5

    # Test 2: Another standard map (cs_italy) - should work
    print_info "=== TEST 2: Standard map (cs_italy) ==="
    if test_map_loading "cs16-test-cs_italy" "cs_italy" "Standard Map Test 2"; then
        print_info "Test 2 PASSED"
    else
        print_warn "Test 2 issues encountered"
    fi
    cleanup
    sleep 5

    # Test 3: Custom aim map (aim_headshot) - critical test
    print_info "=== TEST 3: Custom aim map (aim_headshot) ==="
    print_info "This is the critical test - does it fall back to de_dust2?"

    # First check if the map file exists
    if [ -f "../docker-assets/maps/aim_headshot.bsp" ]; then
        print_info "Map file aim_headshot.bsp exists"
        if test_map_loading "cs16-test-aim_headshot" "aim_headshot" "Custom Map Test"; then
            print_info "✓✓✓ Test 3 PASSED - Custom map loaded without falling back to de_dust2!"
        else
            print_error "✗✗✗ Test 3 FAILED - Custom map issue detected"
        fi
    else
        print_warn "Map file aim_headshot.bsp not found, skipping custom map test"
        print_info "Please ensure custom maps are in ../docker-assets/maps/"
    fi

    # Final cleanup
    cleanup

    echo ""
    print_info "================================================"
    print_info "Test sequence completed"
    print_info "Check the results above"
    print_info "================================================"
    echo ""

    print_info "Next steps if tests pass:"
    print_info "1. This image doesn't have the de_dust2 fallback issue"
    print_info "2. We can use it as a base for our aim server"
    print_info "3. Need to add AMX Mod X, ReDeathmatch, etc."
    print_info "4. Create a new Dockerfile based on this image"

    print_info ""
    print_info "Next steps if tests fail:"
    print_info "1. Check if maps are properly mounted"
    print_info "2. Check server logs for map loading errors"
    print_info "3. Try with legacy version: jives/hlds:cstrike-legacy"
    print_info "4. Consider other alternatives"
}

# Handle script arguments
case "$1" in
    "cleanup")
        cleanup
        ;;
    "test")
        main
        ;;
    *)
        echo "Usage: $0 [command]"
        echo "Commands:"
        echo "  test     - Run all tests (default)"
        echo "  cleanup  - Clean up containers"
        ;;
esac

# If no command specified, run tests
if [ $# -eq 0 ]; then
    main
fi
