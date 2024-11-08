import serial
import serial.tools.list_ports
import keyboard
import time
import sys
from queue import Queue
from threading import Lock

def list_available_ports():
    """List all available COM ports."""
    ports = serial.tools.list_ports.comports()
    if not ports:
        print("No COM ports found!")
        return []
    
    print("\nAvailable COM ports:")
    for port in ports:
        print(f"* {port.device}: {port.description}")
    return [port.device for port in ports]

def setup_serial_port(port, baud_rate):
    """Configure and open serial port with error handling."""
    try:
        # First check if port exists
        available_ports = list_available_ports()
        if port not in available_ports:
            print(f"\nError: {port} not found in available ports.")
            return None

        # Try to open the port
        print(f"\nTrying to open {port}...")
        ser = serial.Serial(
            port=port,
            baudrate=baud_rate,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=0.1
        )
        return ser
    except serial.SerialException as e:
        if "PermissionError" in str(e):
            print(f"\nError: Cannot access {port}. The port might be in use by another program.")
            print("Please:\n1. Close any other programs using the port")
            print("2. Check Device Manager to verify port status")
            print("3. Try running this program as administrator")
        else:
            print(f"\nError opening serial port {port}: {e}")
        return None

def hex_format(data):
    """Format byte data as hex string."""
    return f"0x{data:02X}"

# Global queue for keyboard events
key_queue = Queue()
key_lock = Lock()

def on_key_event(e):
    """Callback for keyboard events"""
    if e.event_type == keyboard.KEY_DOWN:
        with key_lock:
            key_queue.put(e)

def main():
    # First list available ports
    print("Scanning for available ports...")
    available_ports = list_available_ports()
    
    if not available_ports:
        print("No ports available. Please connect a device and try again.")
        return

    # Let user select port if COM9 isn't available
    port = "COM9"
    if port not in available_ports:
        print(f"\nDefault port {port} not found.")
        if len(available_ports) == 1:
            port = available_ports[0]
            print(f"Using available port: {port}")
        else:
            print("\nPlease select a port by number:")
            for i, p in enumerate(available_ports):
                print(f"{i + 1}: {p}")
            while True:
                try:
                    choice = int(input("Enter port number: ")) - 1
                    if 0 <= choice < len(available_ports):
                        port = available_ports[choice]
                        break
                    else:
                        print("Invalid choice. Please try again.")
                except ValueError:
                    print("Please enter a number.")

    baud_rate = 115200
    ser = setup_serial_port(port, baud_rate)
    if not ser:
        print("\nFailed to open serial port. Exiting...")
        return

    print(f"\nSuccessfully opened {port} at {baud_rate} baud")
    print("Press Ctrl+C to exit")

    # Set up keyboard hook
    keyboard.hook(on_key_event)

    try:
        while True:
            # Non-blocking keyboard check
            with key_lock:
                if not key_queue.empty():
                    event = key_queue.get()
                    key = event.name
                    if len(key) == 1:  # Single characters
                        ser.write(key.encode('utf-8'))
                        hex_value = hex_format(ord(key))
                        print(f"Sent: {key} [{hex_value}]")
                    elif key == "space":
                        ser.write(b' ')
                        print("Sent: <space> [0x20]")
                    elif key == "enter":
                        ser.write(b'\r\n')
                        print("Sent: <enter> [0x0D 0x0A]")

            # Check for received data and echo it
            if ser.in_waiting > 0:
                data = ser.read(ser.in_waiting)
                print(f"Received: {data.hex()}")
                for byte in data:
                    ser.write(bytes([byte]))
                    print(f"Echoed: {chr(byte) if 32 <= byte <= 126 else '<non-printable>'} [{hex_format(byte)}]")
                ser.flush()

            time.sleep(0.001)

    except KeyboardInterrupt:
        print("\nExiting...")
    finally:
        keyboard.unhook_all()
        if ser and ser.is_open:
            ser.close()
            print("Serial port closed")

if __name__ == "__main__":
    main()