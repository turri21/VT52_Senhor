import serial
import time
import sys

def setup_serial_port(port, baud_rate):
    """Configure and open serial port with error handling."""
    try:
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
        print(f"Error opening serial port {port}: {e}")
        sys.exit(1)

def main():
    port = "COM9"  # Adjust this to your port
    baud_rate = 115200

    ser = setup_serial_port(port, baud_rate)
    print(f"Opened {port} at {baud_rate} baud")
    print("Checking for incoming data (Ctrl+C to exit)")
    print(f"in_waiting at start: {ser.in_waiting}")

    try:
        while True:
            print(f"Checking in_waiting: {ser.in_waiting}")
            if ser.in_waiting > 0:
                data = ser.read(ser.in_waiting)
                print(f"Got data: {data.hex()}")
            time.sleep(1)  # Check every second

    except KeyboardInterrupt:
        print("\nExiting...")
    finally:
        if ser.is_open:
            ser.close()
            print("Serial port closed")

if __name__ == "__main__":
    main()