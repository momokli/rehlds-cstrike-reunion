#!/usr/bin/env python3
"""
zukka CS 1.6 RCON Test Client
Remote Console client for testing tournament, public, and practice servers.
Part of zukka LAN Tournament System - hub.zukkafabrik.de
"""

import argparse
import socket
import sys
import time
from typing import List, Optional

# Default server configurations
DEFAULT_SERVERS = {
    "tournament": {
        "host": "localhost",
        "port": 27015,
        "password": "zukka_tournament_rcon_secure",
        "description": "zukka Tournament Server (2v2 Competitive)",
    },
    "public": {
        "host": "localhost",
        "port": 27016,
        "password": "zukka_public_rcon_secure",
        "description": "zukka Public Server (Casual)",
    },
    "practice": {
        "host": "localhost",
        "port": 27017,
        "password": "zukka_practice_rcon_secure",
        "description": "zukka Practice Server (Training)",
    },
    "gungame": {
        "host": "localhost",
        "port": 27018,
        "password": "zukka_gungame_rcon_secure",
        "description": "zukka GunGame Server (Weapon Progression)",
    },
    "tdm-bots": {
        "host": "localhost",
        "port": 27019,
        "password": "zukka_public_bots_rcon_secure",
        "description": "zukka Team Deathmatch Server with Bots",
    },
    "ffa-bots": {
        "host": "localhost",
        "port": 27020,
        "password": "zukka_ffa_bots_rcon_secure",
        "description": "zukka FFA Deathmatch Server with Bots",
    },
    "surf": {
        "host": "localhost",
        "port": 27021,
        "password": "zukka_surf_rcon_secure",
        "description": "zukka Surf Server (Movement & Skill)",
    },
    "aim": {
        "host": "localhost",
        "port": 27022,
        "password": "zukka_aim_rcon_secure",
        "description": "zukka Aim Server (Fast-Paced Aim Training)",
    },
}


class RCONError(Exception):
    """Custom exception for RCON errors."""

    pass


class RCONClient:
    """RCON client for GoldSrc/HLDS servers (UDP-based RCON)."""

    # RCON packet constants
    PACKET_PREFIX = b"\xff\xff\xff\xff"
    MAX_PACKET_SIZE = 4096
    RESPONSE_TIMEOUT = 5.0

    def __init__(self, host: str, port: int, password: str, timeout: float = 5.0):
        """
        Initialize RCON client.

        Args:
            host: Server hostname or IP
            port: Server port (UDP)
            password: RCON password
            timeout: Socket timeout in seconds
        """
        self.host = host
        self.port = port
        self.password = password
        self.timeout = timeout
        self.socket = None
        self.authenticated = False

    def __enter__(self):
        """Context manager entry."""
        self.connect()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.close()

    def connect(self) -> None:
        """Connect to the server."""
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self.socket.settimeout(self.timeout)
            self.socket.connect((self.host, self.port))
        except socket.error as e:
            raise RCONError(f"Failed to connect to {self.host}:{self.port}: {e}")

    def close(self) -> None:
        """Close the connection."""
        if self.socket:
            self.socket.close()
            self.socket = None

    def send_packet(self, data: str) -> None:
        """
        Send an RCON packet to the server.

        Args:
            data: The RCON command string (e.g., "rcon password command")
        """
        if not self.socket:
            raise RCONError("Not connected to server")

        # Format: 0xFF 0xFF 0xFF 0xFF + data + null terminator
        packet = self.PACKET_PREFIX + data.encode("utf-8") + b"\x00"

        try:
            self.socket.send(packet)
        except socket.error as e:
            raise RCONError(f"Failed to send packet: {e}")

    def receive_packet(self) -> Optional[str]:
        """
        Receive a packet from the server.

        Returns:
            Decoded response string or None if no response
        """
        if not self.socket:
            return None

        try:
            data, _ = self.socket.recvfrom(self.MAX_PACKET_SIZE)

            # Strip packet prefix and null terminator
            if data.startswith(self.PACKET_PREFIX):
                data = data[len(self.PACKET_PREFIX) :]
            if data.endswith(b"\x00"):
                data = data[:-1]

            return data.decode("utf-8", errors="ignore")
        except socket.timeout:
            return None
        except socket.error as e:
            raise RCONError(f"Failed to receive packet: {e}")

    def authenticate(self) -> bool:
        """
        Authenticate with the server using RCON password.

        Returns:
            True if authentication successful, False otherwise
        """
        # Send authentication command
        self.send_packet(f"rcon {self.password}")

        # Wait for response
        response = self.receive_packet()

        # In GoldSrc RCON, successful authentication doesn't always get a response
        # Try sending a simple command to verify
        if response:
            # If we get "Bad rcon_password." then authentication failed
            if "Bad rcon_password" in response:
                return False

        # Try to get server status to verify authentication
        try:
            self.send_command("status", expect_response=False)
            time.sleep(0.1)  # Brief pause for response
            response = self.receive_packet()
            # If we get a response (even empty), authentication likely succeeded
            self.authenticated = True
            return True
        except:
            return False

    def send_command(self, command: str, expect_response: bool = True) -> List[str]:
        """
        Send an RCON command to the server.

        Args:
            command: The command to execute (e.g., "status", "map de_dust2")
            expect_response: Whether to wait for and return response

        Returns:
            List of response lines (empty list if no response expected)
        """
        if not self.authenticated:
            # Try to authenticate first
            if not self.authenticate():
                raise RCONError("Authentication failed")

        full_command = f"rcon {self.password} {command}"
        self.send_packet(full_command)

        if not expect_response:
            return []

        # Collect responses (may be split across multiple packets)
        responses = []
        start_time = time.time()

        while time.time() - start_time < self.RESPONSE_TIMEOUT:
            response = self.receive_packet()
            if response is None:
                break

            # Clean up response
            response = response.strip()
            if response:
                responses.append(response)

            # Check if response is complete (no more data expected)
            # This is heuristic - GoldSrc RCON responses are usually complete in one packet
            time.sleep(0.1)

        return responses

    def test_connection(self) -> dict:
        """
        Test connection and authentication.

        Returns:
            Dictionary with test results
        """
        results = {
            "server": f"{self.host}:{self.port}",
            "connected": False,
            "authenticated": False,
            "server_info": None,
            "error": None,
        }

        try:
            # Test connection
            self.connect()
            results["connected"] = True

            # Test authentication
            if self.authenticate():
                results["authenticated"] = True

                # Get server info
                try:
                    status_response = self.send_command("status")
                    if status_response:
                        results["server_info"] = "\n".join(
                            status_response[:5]
                        )  # First 5 lines
                except:
                    results["server_info"] = "Could not retrieve server status"

            else:
                results["error"] = "Authentication failed - check RCON password"

        except RCONError as e:
            results["error"] = str(e)
        except Exception as e:
            results["error"] = f"Unexpected error: {e}"
        finally:
            self.close()

        return results


def print_test_results(results: dict, server_name: str) -> None:
    """Print formatted test results."""
    print(f"\n{'=' * 60}")
    print(f"RCON TEST RESULTS - {server_name}")
    print(f"{'=' * 60}")
    print(f"Server: {results['server']}")
    print(f"Connected: {'✓' if results['connected'] else '✗'}")
    print(f"Authenticated: {'✓' if results['authenticated'] else '✗'}")

    if results["error"]:
        print(f"Error: {results['error']}")

    if results["server_info"]:
        print(f"\nServer Status (first 5 lines):")
        print("-" * 40)
        print(results["server_info"])

    print(f"{'=' * 60}")


def interactive_mode(client: RCONClient) -> None:
    """Interactive RCON shell."""
    print(f"Interactive RCON shell for {client.host}:{client.port}")
    print("Type 'quit' or 'exit' to leave, 'help' for available commands")
    print("-" * 60)

    # Common RCON commands for CS 1.6
    common_commands = {
        "status": "Show server status and player list",
        "maps *": "List all available maps",
        "map de_dust2": "Change to de_dust2",
        "changelevel de_inferno": "Change to de_inferno",
        "say Hello from RCON": "Send message to all players",
        "users": "List connected players",
        "kick #USERID#": "Kick a player by USERID",
        "banid 0.0 #STEAMID# kick": "Ban a player by STEAMID",
        "mp_restartgame 1": "Restart the game",
        "mp_timelimit 30": "Set timelimit to 30 minutes",
        "sv_password newpass": "Set server password",
        "exec server.cfg": "Execute server config",
    }

    while True:
        try:
            command = input("\nRCON> ").strip()

            if command.lower() in ("quit", "exit", "q"):
                print("Goodbye!")
                break

            if command.lower() in ("help", "?"):
                print("\nCommon RCON Commands:")
                for cmd, desc in common_commands.items():
                    print(f"  {cmd:30} - {desc}")
                print("\nYou can also use any valid server console command.")
                continue

            if not command:
                continue

            # Send command
            print(f"Sending: {command}")
            responses = client.send_command(command)

            # Print responses
            if responses:
                print("\nResponse:")
                for response in responses:
                    print(response)
            else:
                print("(No response)")

        except KeyboardInterrupt:
            print("\n\nInterrupted. Type 'quit' to exit.")
        except RCONError as e:
            print(f"RCON Error: {e}")
        except Exception as e:
            print(f"Error: {e}")


def main():
    parser = argparse.ArgumentParser(
        description="zukka CS 1.6 RCON Test Client - Test and manage tournament servers",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s tournament test              # Test tournament server connection
  %(prog)s public test                  # Test public server connection
  %(prog)s practice test                # Test practice server connection
  %(prog)s tournament cmd "status"      # Send status command to tournament server
  %(prog)s --host 192.168.1.100 --port 27015 --password mypass test
  %(prog)s tournament interactive       # Start interactive RCON shell

Default server configurations:
  tournament: localhost:27015 (password: zukka_tournament_rcon_secure)
  public:     localhost:27016 (password: zukka_public_rcon_secure)
  practice:   localhost:27017 (password: zukka_practice_rcon_secure)
  gungame:    localhost:27018 (password: zukka_gungame_rcon_secure)
  tdm-bots:   localhost:27019 (password: zukka_public_bots_rcon_secure)
  ffa-bots:   localhost:27020 (password: zukka_ffa_bots_rcon_secure)
  surf:       localhost:27021 (password: zukka_surf_rcon_secure)
  aim:        localhost:27022 (password: zukka_aim_rcon_secure)
        """,
    )

    # Server selection
    parser.add_argument(
        "server",
        nargs="?",
        choices=[
            "tournament",
            "public",
            "practice",
            "gungame",
            "tdm-bots",
            "ffa-bots",
            "surf",
            "aim",
        ],
        help="Server to connect to (uses default configuration)",
    )

    # Action selection
    parser.add_argument(
        "action",
        nargs="?",
        choices=["test", "cmd", "interactive"],
        default="test",
        help="Action to perform (default: test)",
    )

    # Custom server options
    parser.add_argument(
        "--host", default="localhost", help="Server hostname or IP (default: localhost)"
    )
    parser.add_argument(
        "--port", type=int, help="Server port (overrides default for selected server)"
    )
    parser.add_argument(
        "--password", help="RCON password (overrides default for selected server)"
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=5.0,
        help="Connection timeout in seconds (default: 5)",
    )

    # Command argument (for "cmd" action)
    parser.add_argument(
        "command_args",
        nargs=argparse.REMAINDER,
        help="Command to send (for 'cmd' action)",
    )

    args = parser.parse_args()

    # Determine server configuration
    if args.server:
        config = DEFAULT_SERVERS[args.server]
        host = args.host if args.host != "localhost" else config["host"]
        port = args.port if args.port is not None else config["port"]
        password = args.password if args.password is not None else config["password"]
        server_name = config["description"]
    else:
        # Custom server
        if not args.port:
            print("Error: --port is required when not using a predefined server")
            sys.exit(1)
        if not args.password:
            print("Error: --password is required when not using a predefined server")
            sys.exit(1)

        host = args.host
        port = args.port
        password = args.password
        server_name = f"Custom Server ({host}:{port})"

    # Create RCON client
    client = RCONClient(host, port, password, args.timeout)

    # Perform requested action
    try:
        if args.action == "test":
            print(f"Testing RCON connection to {server_name}...")
            results = client.test_connection()
            print_test_results(results, server_name)

        elif args.action == "cmd":
            if not args.command_args:
                print("Error: No command specified for 'cmd' action")
                sys.exit(1)

            command = " ".join(args.command_args)
            print(f"Sending command to {server_name}: {command}")

            client.connect()
            if client.authenticate():
                responses = client.send_command(command)

                if responses:
                    print("\nResponse:")
                    for response in responses:
                        print(response)
                else:
                    print("(No response)")
            else:
                print("Authentication failed!")

        elif args.action == "interactive":
            print(f"Starting interactive RCON session with {server_name}")
            client.connect()
            if client.authenticate():
                interactive_mode(client)
            else:
                print("Authentication failed! Cannot start interactive mode.")

    except RCONError as e:
        print(f"RCON Error: {e}")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
        sys.exit(0)
    except Exception as e:
        print(f"Unexpected error: {e}")
        sys.exit(1)
    finally:
        client.close()


if __name__ == "__main__":
    main()
