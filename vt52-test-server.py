import socket
import time
import random
import threading
import socketserver
import serial
import argparse
from typing import Union, Any

# VT52 Control Sequences
ESC = b'\x1B'  # Escape character
CURSOR_UP = b'A'
CURSOR_DOWN = b'B'
CURSOR_RIGHT = b'C'
CURSOR_LEFT = b'D'
CURSOR_HOME = b'H'
REVERSE_LINEFEED = b'I'
ERASE_TO_EOL = b'K'
ERASE_SCREEN = b'J'
CURSOR_POS = b'Y'
ENTER_ALT_KEYPAD = b'='
EXIT_ALT_KEYPAD = b'>'
ENTER_GRAPHICS = b'F'
EXIT_GRAPHICS = b'G'

class VT52Connection:
    """Base class for VT52 communication"""
    def send(self, data: bytes) -> None:
        raise NotImplementedError

    def close(self) -> None:
        raise NotImplementedError

class SerialConnection(VT52Connection):
    """Serial port connection handler"""
    def __init__(self, port: str = "COM9", baudrate: int = 115200):
        self.serial = serial.Serial(port, baudrate)
        print(f"Opened serial port {port} at {baudrate} baud")

    def send(self, data: bytes) -> None:
        try:
            self.serial.write(data)
            time.sleep(0.01)  # Small delay to simulate real terminal timing
        except serial.SerialException:
            raise ConnectionError("Serial port disconnected")

    def close(self) -> None:
        if self.serial.is_open:
            self.serial.close()

class TelnetConnection(VT52Connection):
    """Telnet connection handler"""
    def __init__(self, socket: socket.socket):
        self.socket = socket

    def send(self, data: bytes) -> None:
        try:
            self.socket.send(data)
            time.sleep(0.01)
        except socket.error:
            raise ConnectionError("Telnet client disconnected")

    def close(self) -> None:
        self.socket.close()

class VT52Demo:
    """VT52 terminal demonstration"""
    def __init__(self, connection: VT52Connection):
        self.connection = connection

    def position_cursor(self, row: int, col: int) -> None:
        """Position cursor at row,col (1-based)"""
        self.connection.send(ESC + CURSOR_POS + bytes([row + 31]) + bytes([col + 31]))

    def demo_cursor_movement(self) -> None:
        """Demonstrate cursor movement commands"""
        print("Demonstrating cursor movement...")
        
        self.connection.send(ESC + CURSOR_HOME)
        self.connection.send(ESC + ERASE_SCREEN)
        self.connection.send(ESC + CURSOR_HOME)

        # Draw a box using cursor movements
        self.position_cursor(5, 10)
        for i in range(10):
            self.connection.send(b'*')
            self.connection.send(ESC + CURSOR_RIGHT)
        for i in range(5):
            self.connection.send(b'*')
            self.connection.send(ESC + CURSOR_DOWN)
        for i in range(10):
            self.connection.send(b'*')
            self.connection.send(ESC + CURSOR_LEFT)
        for i in range(5):
            self.connection.send(b'*')
            self.connection.send(ESC + CURSOR_UP)
        
        time.sleep(1)

    def demo_graphics_mode(self) -> None:
        """Demonstrate graphics mode by drawing a box with title and line graph"""
        print("Demonstrating graphics mode...")
        
        self.connection.send(ESC + CURSOR_HOME)
        self.connection.send(ESC + ERASE_SCREEN)
        self.connection.send(ESC + CURSOR_HOME)

        # Box drawing characters in VT52 graphics mode
        TOP_LEFT = b'l'     # ┌
        TOP_RIGHT = b'k'    # ┐
        BOTTOM_LEFT = b'm'  # └
        BOTTOM_RIGHT = b'j' # ┘
        HORIZONTAL = b'q'   # ─
        VERTICAL = b'x'     # │
        
        # Enter graphics mode
        self.connection.send(ESC + ENTER_GRAPHICS)
        
        # Draw box (30 wide x 15 high, starting at position 10,5)
        self.position_cursor(5, 10)
        
        # Top border
        self.connection.send(TOP_LEFT)
        self.connection.send(HORIZONTAL * 28)
        self.connection.send(TOP_RIGHT)
        
        # Sides
        for i in range(13):
            self.position_cursor(6 + i, 10)
            self.connection.send(VERTICAL)
            self.position_cursor(6 + i, 39)
            self.connection.send(VERTICAL)
        
        # Bottom border
        self.position_cursor(19, 10)
        self.connection.send(BOTTOM_LEFT)
        self.connection.send(HORIZONTAL * 28)
        self.connection.send(BOTTOM_RIGHT)
        
        # Exit graphics mode to write title
        self.connection.send(ESC + EXIT_GRAPHICS)
        self.position_cursor(4, 20)
        self.connection.send(b"SAMPLE GRAPH")
        
        # Draw Y axis labels
        self.position_cursor(7, 7)
        self.connection.send(b"100")
        self.position_cursor(13, 7)
        self.connection.send(b" 50")
        self.position_cursor(18, 7)
        self.connection.send(b"  0")
        
        # Draw X axis labels
        self.position_cursor(20, 15)
        self.connection.send(b"0")
        self.position_cursor(20, 25)
        self.connection.send(b"50")
        self.position_cursor(20, 35)
        self.connection.send(b"100")
        
        # Draw a sample line graph
        points = [
            (12,8), (15,9), (18,12), (21,10), (24,13),
            (27,11), (30,14), (33,12), (36,15)
        ]
        
        self.connection.send(ESC + ENTER_GRAPHICS)
        
        for x, y in points:
            self.position_cursor(y, x)
            self.connection.send(b'a')
            
        self.connection.send(ESC + EXIT_GRAPHICS)
        
        time.sleep(5)

    def demo_screen_clear(self) -> None:
        """Demonstrate screen clearing functions"""
        print("Demonstrating screen clearing...")

        self.connection.send(ESC + CURSOR_HOME)
        self.connection.send(ESC + ERASE_SCREEN)
        self.connection.send(ESC + CURSOR_HOME)
        
        # Fill screen with numbers
        for row in range(1, 24):
            self.position_cursor(row, 1)
            for col in range(1, 81):
                self.connection.send(f"{col % 10}".encode())
        
        time.sleep(2)
        
        # Clear lines one by one
        for row in range(1, 24):
            self.position_cursor(row, 1)
            self.connection.send(ESC + ERASE_TO_EOL)
            time.sleep(0.1)
        
        time.sleep(1)
        
        # Fill again
        for row in range(1, 24):
            self.position_cursor(row, 1)
            for col in range(1, 81):
                self.connection.send(f"{col % 10}".encode())
        
        time.sleep(2)
        self.connection.send(ESC + CURSOR_HOME)
        self.connection.send(ESC + ERASE_SCREEN)
        self.connection.send(ESC + CURSOR_HOME)

    def demo_scrolling(self) -> None:
        """Demonstrate terminal scrolling"""
        print("Demonstrating scrolling...")
        
        self.connection.send(ESC + CURSOR_HOME)
        self.connection.send(ESC + ERASE_SCREEN)
        self.connection.send(ESC + CURSOR_HOME)

        # Fill screen
        for i in range(1, 30):
            self.connection.send(f"This is line {i} of scrolling text test\r\n".encode())
            time.sleep(0.2)
        
        # Demonstrate reverse linefeed
        self.position_cursor(12, 1)
        for i in range(5):
            self.connection.send(ESC + REVERSE_LINEFEED)
            self.connection.send(b"*** Reverse linefeed line ***\r\n")
            time.sleep(0.5)

    def run_demo(self) -> None:
        """Run through all demos"""
        try:
            # Clear screen and home cursor
            self.connection.send(ESC + CURSOR_HOME)
            self.connection.send(ESC + ERASE_SCREEN)
            self.connection.send(ESC + CURSOR_HOME)
            
            # Welcome message
            welcome = """
            **** VT52 Terminal Demonstration ****
            
            This program will demonstrate various
            VT52 terminal features including:
            - Cursor positioning
            - Graphics mode
            - Screen clearing
            - Scrolling
            
            Starting in 3 seconds...
            """
            
            for line in welcome.split('\n'):
                self.connection.send(line.encode() + b'\r\n')
            
            time.sleep(3)
            
            self.demo_cursor_movement()
            time.sleep(1)
            
            self.demo_graphics_mode()
            time.sleep(1)
            
            self.demo_screen_clear()
            time.sleep(1)
            
            self.demo_scrolling()
            
            # Final message
            self.position_cursor(23, 1)
            self.connection.send(b"Demo complete! Connection will close in 5 seconds.")
            time.sleep(5)
            
        except ConnectionError as e:
            print(f"Connection error: {e}")
        except Exception as e:
            print(f"Error during demo: {e}")
        finally:
            self.connection.close()

class VT52TelnetHandler(socketserver.BaseRequestHandler):
    def handle(self):
        print(f"New telnet connection from {self.client_address}")
        connection = TelnetConnection(self.request)
        demo = VT52Demo(connection)
        demo.run_demo()
        print(f"Telnet connection closed for {self.client_address}")

class ThreadedTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True

def run_serial_demo(port: str, baudrate: int) -> None:
    """Run the demo in serial mode"""
    try:
        connection = SerialConnection(port, baudrate)
        demo = VT52Demo(connection)
        demo.run_demo()
    except serial.SerialException as e:
        print(f"Serial port error: {e}")
    except Exception as e:
        print(f"Error during serial demo: {e}")

def run_telnet_server(host: str, port: int) -> None:
    """Run the demo in telnet server mode"""
    server = ThreadedTCPServer((host, port), VT52TelnetHandler)
    print(f"Starting VT52 telnet server on port {port}...")
    print(f"Connect using: telnet {host} {port}")
    print("Press Ctrl+C to stop the server")
    
    try:
        server_thread = threading.Thread(target=server.serve_forever)
        server_thread.daemon = True
        server_thread.start()
        
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nShutting down server...")
        server.shutdown()
        server.server_close()
        print("Server stopped")

def main():
    parser = argparse.ArgumentParser(description='VT52 Terminal Demo')
    parser.add_argument('--mode', choices=['serial', 'telnet'], default='serial',
                      help='Connection mode (default: serial)')
    parser.add_argument('--port', default='COM9',
                      help='Serial port or telnet port number (default: COM9)')
    parser.add_argument('--baudrate', type=int, default=115200,
                      help='Serial baudrate (default: 115200)')
    parser.add_argument('--host', default='0.0.0.0',
                      help='Telnet server host (default: 0.0.0.0)')
    
    args = parser.parse_args()
    
    if args.mode == 'serial':
        print(f"Starting VT52 demo on serial port {args.port} at {args.baudrate} baud")
        run_serial_demo(args.port, args.baudrate)
    else:
        try:
            telnet_port = int(args.port) if args.port != 'COM9' else 2323
            run_telnet_server(args.host, telnet_port)
        except ValueError:
            print("Error: Telnet port must be a number")
            return

if __name__ == "__main__":
    main()