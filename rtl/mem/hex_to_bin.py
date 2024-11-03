def hex_to_bin_file_with_comments(input_file, output_file):
    try:
        with open(input_file, 'r', encoding='utf-8') as infile, open(output_file, 'w', encoding='utf-8') as outfile:
            line_number = 0  # To track the number of lines processed

            for line in infile:
                # Strip whitespace and convert hex to an integer
                hex_value = line.strip()
                if hex_value:
                    # Convert hex to integer and then to binary (remove '0b' prefix)
                    bin_value = bin(int(hex_value, 16))[2:].zfill(8)  # 8-bit binary with leading zeros
                    
                    # Add a comment every 16 lines with the ASCII character
                    if line_number % 16 == 0:
                        ascii_char = chr(line_number // 16)
                        if ascii_char.isprintable():
                            comment = f" // Character: {ascii_char} (ASCII {line_number // 16})"
                        else:
                            comment = f" // Character: Non-printable (ASCII {line_number // 16})"
                    else:
                        comment = ""  # No comment on non-16th lines
                    
                    # Write the binary value and any comment
                    outfile.write(bin_value + comment + '\n')
                
                line_number += 1

        print(f"Successfully converted {input_file} to binary with comments and saved as {output_file}")
    except Exception as e:
        print(f"An error occurred: {e}")

# Example usage
input_file = 'mem/terminus_816_bold_latin1.hex'
output_file = 'mem/terminus_816_bold_latin1.bin'
hex_to_bin_file_with_comments(input_file, output_file)
