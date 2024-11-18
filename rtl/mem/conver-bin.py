def hex_to_binary_str(hex_value):
    """Convert a hex value to 8-bit binary string."""
    return format(hex_value, '08b')

def convert_character(hex_bytes):
    """Convert 8 bytes of hex data to 8 lines of binary strings."""
    binary_lines = []
    
    # Convert each hex byte to binary
    for hex_byte in hex_bytes:
        bin_str = hex_to_binary_str(hex_byte)
        binary_lines.append(bin_str)
    
    return binary_lines

def parse_vt52rom_line(line):
    """Parse a line from the C header file and extract hex values."""
    # Remove comments and whitespace
    line = line.split('//')[0].strip()
    if not line:
        return None
        
    # Remove trailing comma
    line = line.rstrip(',')
    
    try:
        # Split hex values and convert to integers
        hex_values = [int(x.strip(), 16) for x in line.split(',') if x.strip() and x.strip().startswith('0x')]
        return hex_values if hex_values else None
    except ValueError:
        return None

def convert_vt52rom(input_file, output_file):
    """Convert VT52 ROM data from C header format to binary format."""
    with open(input_file, 'r') as f:
        content = f.readlines()
    
    # Find the start of the array
    start_index = 0
    for i, line in enumerate(content):
        if 'const int vt52rom[] = {' in line:
            start_index = i + 1
            break
    
    with open(output_file, 'w') as f:
        char_index = 0
        
        for line in content[start_index:]:
            # Stop at the end of the array
            if '};' in line:
                break
                
            hex_values = parse_vt52rom_line(line)
            if hex_values is None:
                continue
                
            if len(hex_values) == 8:  # One complete character
                binary_lines = convert_character(hex_values)
                # Write character with comment
                for i, bin_line in enumerate(binary_lines):
                    # Add comment only on first line of each character
                    if i == 0:
                        f.write(f"{bin_line} // Character: {chr(char_index) if 32 <= char_index <= 126 else 'Non-printable'} (ASCII {char_index})\n")
                    else:
                        f.write(f"{bin_line}\n")
                char_index += 1

# Example usage
if __name__ == "__main__":
    convert_vt52rom("data/vt52rom.h", "data/vt52_rom.bin")