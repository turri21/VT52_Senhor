def generate_char_rom():
    char_rom = []
    for char in range(256):
        if char < 32 or char > 126:  # non-printable characters
            char_rom.extend([0] * 16)
        else:
            # Convert char to its ASCII character representation
            char_str = chr(char)
            # Basic 5x7 font in an 8x16 cell, centered
            font = [
                0b00000000,
                0b00000000,
                0b00000000,
                0b00000000,
                0b00011111 if char_str in '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz' else 0b00000000,
                0b00010001 if char_str in '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ' else 0b00000000,
                0b00010001 if char_str in '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ' else 0b00000000,
                0b00010001 if char_str in '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ' else 0b00000000,
                0b00010001 if char_str in '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ' else 0b00000000,
                0b00011111 if char_str in '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ' else 0b00000000,
                0b00000000,
                0b00000000,
                0b00000000,
                0b00000000,
                0b00000000,
                0b00000000,
            ]
            char_rom.extend(font)
    
    return char_rom

def write_hex_file(filename, data):
    with open(filename, 'w') as f:
        address = 0
        for i in range(0, len(data), 16):
            chunk = data[i:i+16]
            line = f":10{address:04X}00{''.join([f'{byte:02X}' for byte in chunk])}"
            checksum = (-(sum(chunk) + 16 + (address >> 8) + (address & 0xFF))) & 0xFF
            f.write(f"{line}{checksum:02X}\n")
            address += 16
        f.write(":00000001FF\n")  # EOF marker

char_rom = generate_char_rom()
write_hex_file('char_rom.hex', char_rom)