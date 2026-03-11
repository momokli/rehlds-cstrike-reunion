#!/usr/bin/env python3
"""
zukka CS 1.6 Server Query Tool
Queries GoldSrc/ReHLDS servers using A2S_INFO protocol
Part of zukka LAN Tournament System - hub.zukkafabrik.de
"""

import argparse
import socket
import struct
import time
from datetime import datetime

# A2S_INFO query payload
A2S_INFO_QUERY = b"\xff\xff\xff\xff\x54\x53\x6f\x75\x72\x63\x65\x20\x45\x6e\x67\x69\x6e\x65\x20\x51\x75\x65\x72\x79\x00"


def query_server(host="localhost", port=27015, timeout=5):
    """
    Query a CS 1.6 server using A2S_INFO protocol

    Args:
        host: Server hostname or IP
        port: Server port
        timeout: Socket timeout in seconds

    Returns:
        Dictionary with server information or None on error
    """
    try:
        # Create UDP socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(timeout)

        # Send A2S_INFO query
        sock.sendto(A2S_INFO_QUERY, (host, port))

        # Receive response
        data, addr = sock.recvfrom(4096)
        sock.close()

        # Parse response
        return parse_a2s_info(data)

    except socket.timeout:
        print(f"Timeout connecting to {host}:{port}")
        return None
    except socket.error as e:
        print(f"Socket error connecting to {host}:{port}: {e}")
        return None
    except Exception as e:
        print(f"Error querying {host}:{port}: {e}")
        return None


def parse_a2s_info(data):
    """
    Parse A2S_INFO response from GoldSrc server

    Args:
        data: Raw response bytes

    Returns:
        Dictionary with parsed server info
    """
    if len(data) < 4:
        return None

    # Check response header (should be \xFF\xFF\xFF\xFF)
    if data[0:4] != b"\xff\xff\xff\xff":
        return None

    # Skip header
    offset = 4

    # Response type (should be 0x49 for A2S_INFO response)
    response_type = data[offset]
    offset += 1

    if response_type != 0x49:
        print(f"Unexpected response type: 0x{response_type:02X}")
        return None

    # Protocol version
    protocol = data[offset]
    offset += 1

    # Hostname (null-terminated string)
    hostname = b""
    while offset < len(data) and data[offset] != 0:
        hostname += bytes([data[offset]])
        offset += 1
    offset += 1  # Skip null terminator

    # Map name
    map_name = b""
    while offset < len(data) and data[offset] != 0:
        map_name += bytes([data[offset]])
        offset += 1
    offset += 1

    # Game directory
    game_dir = b""
    while offset < len(data) and data[offset] != 0:
        game_dir += bytes([data[offset]])
        offset += 1
    offset += 1

    # Game description
    game_desc = b""
    while offset < len(data) and data[offset] != 0:
        game_desc += bytes([data[offset]])
        offset += 1
    offset += 1

    # App ID (2 bytes)
    if offset + 1 >= len(data):
        return None
    app_id = struct.unpack("<H", data[offset : offset + 2])[0]
    offset += 2

    # Number of players (1 byte)
    if offset >= len(data):
        return None
    num_players = data[offset]
    offset += 1

    # Max players (1 byte)
    if offset >= len(data):
        return None
    max_players = data[offset]
    offset += 1

    # Number of bots (1 byte) - only in newer protocol versions
    num_bots = 0
    if protocol > 0x0F and offset < len(data):
        num_bots = data[offset]
        offset += 1

    # Server type (1 byte)
    if offset >= len(data):
        return None
    server_type = data[offset]
    offset += 1

    # Environment (1 byte)
    if offset >= len(data):
        return None
    environment = data[offset]
    offset += 1

    # Visibility (1 byte)
    if offset >= len(data):
        return None
    visibility = data[offset]
    offset += 1

    # VAC (1 byte)
    if offset >= len(data):
        return None
    vac = data[offset]
    offset += 1

    # Game version (null-terminated string)
    game_version = b""
    while offset < len(data) and data[offset] != 0:
        game_version += bytes([data[offset]])
        offset += 1
    offset += 1

    # Extra Data Flag (EDF)
    edf = 0
    if offset < len(data):
        edf = data[offset]
        offset += 1

    # Parse EDF if present
    port = 0
    steam_id = 0
    spectator_port = 0
    spectator_name = b""
    keywords = b""
    game_id = 0

    if edf & 0x80:  # Port
        if offset + 1 < len(data):
            port = struct.unpack("<H", data[offset : offset + 2])[0]
            offset += 2

    if edf & 0x10:  # SteamID
        if offset + 7 < len(data):
            steam_id = struct.unpack("<Q", data[offset : offset + 8])[0]
            offset += 8

    if edf & 0x40:  # Spectator
        if offset + 1 < len(data):
            spectator_port = struct.unpack("<H", data[offset : offset + 2])[0]
            offset += 2

        if offset < len(data):
            while offset < len(data) and data[offset] != 0:
                spectator_name += bytes([data[offset]])
                offset += 1
            offset += 1

    if edf & 0x20:  # Keywords
        if offset < len(data):
            while offset < len(data) and data[offset] != 0:
                keywords += bytes([data[offset]])
                offset += 1
            offset += 1

    if edf & 0x01:  # GameID
        if offset + 7 < len(data):
            game_id = struct.unpack("<Q", data[offset : offset + 8])[0]
            offset += 8

    # Decode strings
    try:
        hostname_str = hostname.decode("utf-8", errors="ignore")
        map_name_str = map_name.decode("utf-8", errors="ignore")
        game_dir_str = game_dir.decode("utf-8", errors="ignore")
        game_desc_str = game_desc.decode("utf-8", errors="ignore")
        game_version_str = game_version.decode("utf-8", errors="ignore")
        spectator_name_str = spectator_name.decode("utf-8", errors="ignore")
        keywords_str = keywords.decode("utf-8", errors="ignore")
    except:
        # Fallback to latin-1 if utf-8 fails
        hostname_str = hostname.decode("latin-1", errors="ignore")
        map_name_str = map_name.decode("latin-1", errors="ignore")
        game_dir_str = game_dir.decode("latin-1", errors="ignore")
        game_desc_str = game_desc.decode("latin-1", errors="ignore")
        game_version_str = game_version.decode("latin-1", errors="ignore")
        spectator_name_str = spectator_name.decode("latin-1", errors="ignore")
        keywords_str = keywords.decode("latin-1", errors="ignore")

    # Server type mapping
    server_types = {
        "d": "Dedicated",
        "l": "Non-dedicated",
        "p": "Proxy",
        "I": "Invalid",
    }
    server_type_char = chr(server_type)
    server_type_str = server_types.get(
        server_type_char, f"Unknown ({server_type_char})"
    )

    # Environment mapping
    environments = {"l": "Linux", "w": "Windows", "m": "Mac", "o": "Other"}
    env_char = chr(environment)
    environment_str = environments.get(env_char, f"Unknown ({env_char})")

    return {
        "protocol": protocol,
        "hostname": hostname_str,
        "map": map_name_str,
        "game_dir": game_dir_str,
        "game_description": game_desc_str,
        "app_id": app_id,
        "players": num_players,
        "max_players": max_players,
        "bots": num_bots,
        "server_type": server_type_str,
        "environment": environment_str,
        "visibility": "Private" if visibility == 0 else "Public",
        "vac": "Secured" if vac == 1 else "Unsecured",
        "version": game_version_str,
        "port": port,
        "steam_id": steam_id,
        "spectator_port": spectator_port,
        "spectator_name": spectator_name_str,
        "keywords": keywords_str,
        "game_id": game_id,
    }


def print_server_info(info, show_all=False):
    """
    Print formatted server information

    Args:
        info: Dictionary with server info
        show_all: Show all details including technical info
    """
    if not info:
        print("No server information available")
        return

    print(f"\n{'=' * 60}")
    print(f"ZUKKA SERVER INFO - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"{'=' * 60}")
    print(f"Hostname:    {info['hostname']}")
    print(f"Map:         {info['map']}")
    print(
        f"Players:     {info['players']}/{info['max_players']} (Bots: {info['bots']})"
    )
    print(f"Game:        {info['game_description']}")
    print(f"Version:     {info['version']}")
    print(f"VAC:         {info['vac']}")
    print(f"Visibility:  {info['visibility']}")

    if show_all:
        print(f"\nTechnical Details:")
        print(f"Protocol:    {info['protocol']}")
        print(f"Game Dir:    {info['game_dir']}")
        print(f"App ID:      {info['app_id']}")
        print(f"Server Type: {info['server_type']}")
        print(f"Environment: {info['environment']}")
        print(f"Port:        {info['port']}")
        print(f"Steam ID:    {info['steam_id']}")
        if info["spectator_port"] > 0:
            print(f"Spectator:   {info['spectator_name']}:{info['spectator_port']}")
        if info["keywords"]:
            print(f"Keywords:    {info['keywords']}")
        print(f"Game ID:     {info['game_id']}")

    print(f"{'=' * 60}")


def main():
    parser = argparse.ArgumentParser(description="Query CS 1.6 server information")
    parser.add_argument(
        "host",
        nargs="?",
        default="localhost",
        help="Server hostname or IP (default: localhost)",
    )
    parser.add_argument(
        "port", nargs="?", type=int, default=27015, help="Server port (default: 27015)"
    )
    parser.add_argument(
        "-a", "--all", action="store_true", help="Show all technical details"
    )
    parser.add_argument(
        "-t",
        "--timeout",
        type=float,
        default=5.0,
        help="Query timeout in seconds (default: 5)",
    )
    parser.add_argument(
        "-l", "--list", action="store_true", help="Query multiple predefined servers"
    )

    args = parser.parse_args()

    if args.list:
        # Query our predefined servers
        servers = [
            ("zukka Tournament Server", "localhost", 27015),
            ("zukka Public Server", "localhost", 27016),
            ("zukka Practice Server", "localhost", 27017),
        ]

        for name, host, port in servers:
            print(f"\nQuerying {name} ({host}:{port})...")
            info = query_server(host, port, args.timeout)
            if info:
                print_server_info(info, args.all)
            else:
                print(f"Failed to query {name}")
            time.sleep(1)  # Small delay between queries

        # Also try to query any other local servers
        print(f"\n{'=' * 60}")
        print("Scanning for additional zukka CS 1.6 servers on localhost...")
        print(f"{'=' * 60}")

        for port in range(27015, 27025):  # Scan ports 27015-27024
            if port == 27015 or port == 27016:  # Already queried
                continue

            print(f"Trying port {port}...", end="\r")
            info = query_server("localhost", port, 1.0)
            if info:
                print(f"\nFound server on port {port}: {info['hostname']}")
                print_server_info(info, args.all)

    else:
        # Query single server
        print(f"Querying server {args.host}:{args.port}...")
        info = query_server(args.host, args.port, args.timeout)
        print_server_info(info, args.all)


if __name__ == "__main__":
    main()
