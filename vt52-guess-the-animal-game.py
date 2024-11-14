#!/usr/bin/env python3

import socket
import time
import threading
import socketserver
import serial
import argparse
from typing import Union, Any
from random import choice

# VT52 Control Sequences
ESC = b'\x1B'
CURSOR_UP = b'A'
CURSOR_DOWN = b'B'
CURSOR_RIGHT = b'C'
CURSOR_LEFT = b'D'
CURSOR_HOME = b'H'
ERASE_TO_EOL = b'K'
ERASE_SCREEN = b'J'
CURSOR_POS = b'Y'

class VT52Connection:
    """Base class for VT52 communication"""
    def send(self, data: bytes) -> None:
        raise NotImplementedError

    def receive(self, size: int = 1) -> bytes:
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
            time.sleep(0.01)
        except serial.SerialException:
            raise ConnectionError("Serial port disconnected")

    def receive(self, size: int = 1) -> bytes:
        try:
            return self.serial.read(size)
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

    def receive(self, size: int = 1) -> bytes:
        try:
            return self.socket.recv(size)
        except socket.error:
            raise ConnectionError("Telnet client disconnected")

    def close(self) -> None:
        self.socket.close()

class AnimalGame:
    """Guess the Animal game for VT52 terminals"""
    
    def __init__(self, connection: VT52Connection):
        self.connection = connection
        self.animals = [
            "LION", "TIGER", "BEAR", "ELEPHANT", "GIRAFFE",
            "ZEBRA", "MONKEY", "KANGAROO", "PENGUIN", "DOLPHIN",
            "SNAKE", "EAGLE", "WOLF", "FOX", "DEER"
        ]
        self.current_animal = ""
        self.guessed_letters = set()
        self.max_attempts = 6
        self.attempts_left = self.max_attempts

    def position_cursor(self, row: int, col: int) -> None:
        """Position cursor at row,col (1-based)"""
        self.connection.send(ESC + CURSOR_POS + bytes([row + 31]) + bytes([col + 31]))

    def clear_screen(self) -> None:
        """Clear screen and home cursor"""
        self.connection.send(ESC + CURSOR_HOME + ESC + ERASE_SCREEN)
        time.sleep(0.1)

    def draw_hangman(self, stage: int) -> None:
        """Draw hangman stage based on remaining attempts"""
        stages = [
            [
                "  +---+",
                "  |   |",
                "      |",
                "      |",
                "      |",
                "      |",
                "=========",
            ],
            [
                "  +---+",
                "  |   |",
                "  O   |",
                "      |",
                "      |",
                "      |",
                "=========",
            ],
            [
                "  +---+",
                "  |   |",
                "  O   |",
                "  |   |",
                "      |",
                "      |",
                "=========",
            ],
            [
                "  +---+",
                "  |   |",
                "  O   |",
                " /|   |",
                "      |",
                "      |",
                "=========",
            ],
            [
                "  +---+",
                "  |   |",
                "  O   |",
                " /|\\  |",
                "      |",
                "      |",
                "=========",
            ],
            [
                "  +---+",
                "  |   |",
                "  O   |",
                " /|\\  |",
                " /    |",
                "      |",
                "=========",
            ],
            [
                "  +---+",
                "  |   |",
                "  O   |",
                " /|\\  |",
                " / \\  |",
                "      |",
                "=========",
            ],
        ]
        
        stage_art = stages[self.max_attempts - self.attempts_left]
        for i, line in enumerate(stage_art):
            self.position_cursor(3 + i, 5)
            self.connection.send(line.encode())

    def display_word(self) -> None:
        """Display the word with guessed letters revealed"""
        display = ""
        for letter in self.current_animal:
            if letter in self.guessed_letters:
                display += letter + " "
            else:
                display += "_ "
        
        self.position_cursor(12, 5)
        self.connection.send(b"Word: " + display.encode())

    def display_guessed_letters(self) -> None:
        """Display all guessed letters"""
        self.position_cursor(14, 5)
        self.connection.send(b"Guessed letters: " + 
                           " ".join(sorted(self.guessed_letters)).encode())

    def display_attempts(self) -> None:
        """Display remaining attempts"""
        self.position_cursor(16, 5)
        self.connection.send(f"Attempts left: {self.attempts_left}".encode())

    def get_input(self) -> str:
        """Get a single character input from the user"""
        self.position_cursor(18, 5)
        self.connection.send(b"Enter a letter: ")
        
        while True:
            char = self.connection.receive(1)
            if not char:
                raise ConnectionError("Connection lost while waiting for input")
            
            # Convert to uppercase ASCII letter
            char = char.upper()
            if char >= b'A' and char <= b'Z':
                self.connection.send(char + b'\r\n')  # Echo the character
                return char.decode()

    def play_round(self) -> bool:
        """Play a single round of the game. Returns True if player wants to play again."""
        self.clear_screen()
        self.current_animal = choice(self.animals)
        self.guessed_letters = set()
        self.attempts_left = self.max_attempts
        
        while self.attempts_left > 0:
            self.clear_screen()
            
            # Display game state
            self.draw_hangman(self.attempts_left)
            self.display_word()
            self.display_guessed_letters()
            self.display_attempts()
            
            # Check win condition
            if all(letter in self.guessed_letters for letter in self.current_animal):
                self.position_cursor(20, 5)
                self.connection.send(b"Congratulations! You won!\r\n")
                break
            
            # Get player's guess
            try:
                guess = self.get_input()
            except ConnectionError:
                return False
            
            if guess in self.guessed_letters:
                continue
            
            self.guessed_letters.add(guess)
            
            if guess not in self.current_animal:
                self.attempts_left -= 1
                if self.attempts_left == 0:
                    self.clear_screen()
                    self.draw_hangman(self.max_attempts)
                    self.position_cursor(20, 5)
                    self.connection.send(f"Game Over! The word was: {self.current_animal}\r\n".encode())
        
        # Ask to play again
        self.position_cursor(22, 5)
        self.connection.send(b"Play again? (Y/N): ")
        
        try:
            while True:
                response = self.connection.receive(1).upper()
                if response == b'Y':
                    return True
                elif response == b'N':
                    return False
        except ConnectionError:
            return False

    def run_game(self) -> None:
        """Main game loop"""
        try:
            welcome = """
            **** Guess the Animal Game ****
            
            Try to guess the animal name one letter at a time.
            You have 6 attempts before the game is over.
            
            Starting in 3 seconds...
            """
            
            self.clear_screen()
            for line in welcome.split('\n'):
                self.connection.send(line.encode() + b'\r\n')
            
            time.sleep(3)
            
            while self.play_round():
                pass
            
            self.clear_screen()
            self.position_cursor(1, 1)
            self.connection.send(b"Thanks for playing! Goodbye!\r\n")
            time.sleep(2)
            
        except ConnectionError as e:
            print(f"Connection error: {e}")
        except Exception as e:
            print(f"Error during game: {e}")
        finally:
            self.connection.close()

class AnimalGameTelnetHandler(socketserver.BaseRequestHandler):
    def handle(self):
        print(f"New telnet connection from {self.client_address}")
        connection = TelnetConnection(self.request)
        game = AnimalGame(connection)
        game.run_game()
        print(f"Telnet connection closed for {self.client_address}")

class ThreadedTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True

def run_serial_game(port: str, baudrate: int) -> None:
    """Run the game in serial mode"""
    try:
        connection = SerialConnection(port, baudrate)
        game = AnimalGame(connection)
        game.run_game()
    except serial.SerialException as e:
        print(f"Serial port error: {e}")
    except Exception as e:
        print(f"Error during serial game: {e}")

def run_telnet_server(host: str, port: int) -> None:
    """Run the game in telnet server mode"""
    server = ThreadedTCPServer((host, port), AnimalGameTelnetHandler)
    print(f"Starting Animal Game telnet server on port {port}...")
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
    parser = argparse.ArgumentParser(description='VT52 Guess the Animal Game')
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
        print(f"Starting Animal Game on serial port {args.port} at {args.baudrate} baud")
        run_serial_game(args.port, args.baudrate)
    else:
        try:
            telnet_port = int(args.port) if args.port != 'COM9' else 2323
            run_telnet_server(args.host, telnet_port)
        except ValueError:
            print("Error: Telnet port must be a number")
            return

if __name__ == "__main__":
    main()