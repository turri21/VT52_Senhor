#!/usr/bin/env python3

import socket
import time
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
    """VT52 terminal testing and demonstration"""
    def __init__(self, connection: VT52Connection):
        self.connection = connection

    def position_cursor(self, row: int, col: int) -> None:
        """Position cursor at row,col (1-based)"""
        self.connection.send(ESC + CURSOR_POS + bytes([row + 31]) + bytes([col + 31]))

    def test_control_chars(self) -> None:
        """Test basic control characters"""
        print("Testing control characters...")
        
        self.connection.send(ESC + CURSOR_HOME)
        self.connection.send(ESC + ERASE_SCREEN)
        self.position_cursor(1, 1)
        self.connection.send(b'Control Characters Test:\r\n\n')
        
        # Test backspace behavior
        self.connection.send(b'Backspace Test: ')
        self.connection.send(b'ABC')          # Write ABC
        self.connection.send(b'\x08')         # Backspace
        self.connection.send(b'\x08')         # Backspace
        self.connection.send(b'XY')           # Should show AXY
        self.connection.send(b'\r\n')
        
        # Test line feed and carriage return
        self.connection.send(b'LF/CR Test:\r\n')
        self.connection.send(b'First')
        self.connection.send(b'\n')           # Line feed
        self.connection.send(b'Second')
        self.connection.send(b'\r')           # Carriage return
        self.connection.send(b'Third')        # Should overwrite 'Second'
        self.connection.send(b'\r\n\n')
        
        # Test tabs
        self.connection.send(b'Tab Test:\r\n')
        self.connection.send(b'1\t2\t3\t4')   # Should tab every 8 spaces
        time.sleep(2)

    def test_cursor_positioning(self) -> None:
        """Test all cursor positioning commands"""
        print("Testing cursor positioning...")
        
        self.connection.send(ESC + CURSOR_HOME)
        self.connection.send(ESC + ERASE_SCREEN)
        time.sleep(0.5)  # Allow for erase operation
        
        self.position_cursor(1, 1)
        self.connection.send(b'Cursor Positioning Test:\r\n\n')
        
        # Test absolute positioning
        self.connection.send(b'Testing absolute cursor positioning...\r\n')
        positions = [(5,10), (5,30), (10,10), (10,30), (15,10), (15,30)]
        for y, x in positions:
            self.position_cursor(y, x)
            self.connection.send(b'X')
            time.sleep(0.2)  # Allow for cursor movement
        
        time.sleep(1)
        
        # Test relative movements
        self.position_cursor(12, 20)
        self.connection.send(b'O')  # Start point
        time.sleep(0.2)
        
        # Test each direction with delays
        for _ in range(3):
            self.connection.send(ESC + CURSOR_UP)
            time.sleep(0.2)
            self.connection.send(b'^')
        
        for _ in range(3):
            self.connection.send(ESC + CURSOR_RIGHT)
            time.sleep(0.2)
            self.connection.send(b'>')
        
        for _ in range(3):
            self.connection.send(ESC + CURSOR_DOWN)
            time.sleep(0.2)
            self.connection.send(b'v')
        
        for _ in range(3):
            self.connection.send(ESC + CURSOR_LEFT)
            time.sleep(0.2)
            self.connection.send(b'<')
            
        time.sleep(2)

    def test_erase_functions(self) -> None:
        """Test erase functions"""
        print("Testing erase functions...")
        
        self.connection.send(ESC + CURSOR_HOME)
        self.connection.send(ESC + ERASE_SCREEN)
        time.sleep(0.5)  # Allow for erase operation
        
        self.position_cursor(1, 1)
        self.connection.send(b'Erase Functions Test:\r\n\n')
        
        # Fill screen with test pattern
        for y in range(5, 20):
            self.position_cursor(y, 1)
            self.connection.send(f"Line {y:02d}: Testing erase functions...".encode())
            time.sleep(0.1)  # Prevent buffer overflow
        
        time.sleep(2)
        
        # Test erase to end of line
        self.connection.send(b'\r\nTesting Erase to End of Line (ESC K):')
        self.position_cursor(10, 20)
        self.connection.send(ESC + ERASE_TO_EOL)
        time.sleep(0.5)  # Allow for erase operation
        self.position_cursor(10, 40)
        self.connection.send(b'<-- Erased to here')
        
        time.sleep(2)
        
        # Test erase screen and verify home
        self.connection.send(b'\r\nTesting Erase Screen (ESC J) - should home cursor:')
        self.position_cursor(15, 20)
        self.connection.send(ESC + ERASE_SCREEN)
        time.sleep(0.5)  # Allow for erase operation
        self.connection.send(b'This should be at home position (1,1)')
        
        time.sleep(2)

    def test_scroll_behavior(self) -> None:
        """Test scrolling behavior with hardware timing considerations"""
        print("Testing scroll behavior...")
        
        self.connection.send(ESC + CURSOR_HOME)
        self.connection.send(ESC + ERASE_SCREEN)
        time.sleep(0.5)  # Allow for erase operation
        
        self.position_cursor(1, 1)
        self.connection.send(b'Scroll Behavior Test:\r\n\n')
        
        self.connection.send(ESC + CURSOR_HOME)
        self.connection.send(ESC + ERASE_SCREEN)
        time.sleep(0.5)  # Allow for erase operation

        # Fill screen with numbered lines
        for i in range(1, 23):
            self.position_cursor(i, 1)
            self.connection.send(f"Line {i:02d}: test content".encode())
            time.sleep(0.1)  # Prevent buffer overflow
        
        time.sleep(2)
        
        # Test forward scroll with hardware timing
        self.connection.send(b'\r\nTesting forward scroll...')

        self.connection.send(ESC + CURSOR_HOME)
        self.connection.send(ESC + ERASE_SCREEN)
        time.sleep(0.5)  # Allow for erase operation


        self.position_cursor(22, 1)
        
        for i in range(7):
            self.connection.send(f"New line {i} - testing scroll\r\n".encode())
            time.sleep(1.0)  # Allow for hardware scroll operation
        
        time.sleep(2)
        self.connection.send(ESC + ERASE_SCREEN)
        time.sleep(0.5)
        
        # Test reverse scroll
        self.connection.send(b'Testing reverse scroll (ESC I):\r\n')
        self.position_cursor(10, 1)
        
        for i in range(5):
            self.connection.send(ESC + REVERSE_LINEFEED)
            time.sleep(1.0)  # Allow for hardware scroll operation
            self.connection.send(f"Reverse scroll line {i+1}\r".encode())
        
        time.sleep(2)

    def demo_cursor_movement(self) -> None:
        """Demonstrate cursor movement with box drawing"""
        print("Demonstrating cursor movement...")
        
        self.connection.send(ESC + CURSOR_HOME)
        self.connection.send(ESC + ERASE_SCREEN)
        time.sleep(0.5)

        self.position_cursor(1, 1)
        self.connection.send(b'Box Drawing Demo:\r\n\n')

        # Draw a box using cursor movements
        self.position_cursor(5, 10)
        
        # Top line with delays
        for _ in range(10):
            self.connection.send(b'*')
            time.sleep(0.1)
        
        # Right side
        for _ in range(5):
            self.connection.send(ESC + CURSOR_DOWN)
            time.sleep(0.1)
            self.connection.send(ESC + CURSOR_LEFT)
            self.connection.send(b'*')
        
        # Bottom line
        for _ in range(10):
            self.connection.send(ESC + CURSOR_LEFT)
            time.sleep(0.1)
            self.connection.send(ESC + CURSOR_LEFT)
            self.connection.send(b'*')
        
        # Left side
        for _ in range(5):
            self.connection.send(ESC + CURSOR_UP)
            time.sleep(0.1)
            self.connection.send(ESC + CURSOR_LEFT)
            self.connection.send(b'*')
        
        time.sleep(2)

    def run_demo(self) -> None:
        """Run all implemented tests"""
        try:
            welcome = """
            **** VT52 Terminal Test Suite ****
            
            Testing implemented features:
            - Control characters (BS, LF, CR, TAB)
            - Cursor positioning (abs/rel)
            - Erase functions (EOL/screen)
            - Hardware scroll behavior
            - Box drawing
            
            Starting in 3 seconds...
            """
            
            self.connection.send(ESC + CURSOR_HOME)
            self.connection.send(ESC + ERASE_SCREEN)
            time.sleep(0.5)
            
            for line in welcome.split('\n'):
                self.connection.send(line.encode() + b'\r\n')
            
            time.sleep(3)
            
            # Run tests with proper delays
            self.test_control_chars()
            self.position_cursor(22, 1)
            self.connection.send(b'\r3 seconds to continue...')
            time.sleep(3)
            
            self.test_cursor_positioning()
            self.position_cursor(22, 1)
            self.connection.send(b'\r3 seconds to continue...')
            time.sleep(3)
            
            self.test_erase_functions()
            self.position_cursor(22, 1)
            self.connection.send(b'\r3 seconds to continue...')
            time.sleep(3)
            
            self.test_scroll_behavior()
            self.position_cursor(22, 1)
            self.connection.send(b'\r3 seconds to continue...')
            time.sleep(3)
            
            self.demo_cursor_movement()
            self.position_cursor(22, 1)
            self.connection.send(b'\r3 seconds to continue...')
            time.sleep(3)
            
            # Final message
            self.connection.send(ESC + CURSOR_HOME)
            self.connection.send(ESC + ERASE_SCREEN)
            time.sleep(0.5)
            
            self.position_cursor(1, 1)
            summary = """
            Test Summary:
            - Control Characters
            - Cursor Positioning
            - Erase Functions
            - Hardware Scroll Operations
            - Box Drawing
            
            Tests complete! Connection will close in 5 seconds.
            """
            for line in summary.split('\n'):
                self.connection.send(line.encode() + b'\r\n')
            
            time.sleep(5)
            
        except ConnectionError as e:
            print(f"Connection error: {e}")
        except Exception as e:
            print(f"Error during tests: {e}")
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
    parser = argparse.ArgumentParser(description='VT52 Terminal Test Suite')
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
        print(f"Starting VT52 test suite on serial port {args.port} at {args.baudrate} baud")
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