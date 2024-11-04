def hex_to_ascii():
    try:
        # Open input file with hex numbers
        with open('rtl/mem/test.hex', 'r') as infile:
            # Read all lines and remove whitespace
            hex_values = [line.strip() for line in infile.readlines()]
        
        # Convert hex to ASCII characters
        ascii_chars = []
        for hex_val in hex_values:
            # Convert hex string to integer and then to ASCII character
            try:
                ascii_char = chr(int(hex_val, 16))
                ascii_chars.append(ascii_char)
            except ValueError as e:
                print(f"Warning: Could not convert hex value: {hex_val}")
                continue
        
        # Format into 80-character rows
        formatted_text = ''
        for i in range(0, len(ascii_chars), 80):
            row = ''.join(ascii_chars[i:i+80])
            formatted_text += row + '\n'
        
        # Write formatted ASCII text to output file
        with open('rtl/mem/test-ascii.txt', 'w') as outfile:
            outfile.write(formatted_text)
            
        print("Conversion completed. Output written to rtl/mem/test-ascii.txt")
        print(f"Total characters converted: {len(ascii_chars)}")
        print(f"Number of rows: {len(formatted_text.splitlines())}")
        
    except FileNotFoundError:
        print("Error: Input file 'rtl/mem/test.hex' not found")
    except Exception as e:
        print(f"Error occurred: {str(e)}")

if __name__ == "__main__":
    hex_to_ascii()
