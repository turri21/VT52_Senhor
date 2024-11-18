from PIL import Image, ImageDraw, ImageFont
import os

# File configuration
FONT_FILE = 'rtl/mem/terminus_816_bold_latin1.bin'  # Can be .bin for binary or .hex for hex format

# Font configuration constants
CHAR_WIDTH = 8
CHAR_HEIGHT = 16
INDEX_WIDTH = 24
TOTAL_WIDTH = INDEX_WIDTH + CHAR_WIDTH
CHARS_PER_ROW = 8
NUM_CHARS = 256

# Since each row requires one byte, BYTES_PER_CHAR equals CHAR_HEIGHT
BYTES_PER_CHAR = CHAR_HEIGHT

# Image configuration
SCALE_FACTOR = 2  # For final image scaling
BG_COLOR = (255, 255, 255)  # White
FG_COLOR = (0, 0, 0)        # Black

def get_output_filename(input_filename):
    # Get directory and base filename without extension
    directory = os.path.dirname(input_filename)
    basename = os.path.splitext(os.path.basename(input_filename))[0]
    
    # Create output filename with _bitmap suffix
    return os.path.join(directory, f"{basename}_bitmap.png")

def read_binary_font_file(filename):
    data = []
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            for line in f:
                # Skip comment lines
                line = line.split('//')[0].strip()
                if not line:
                    continue
                
                # Convert binary string to integer
                try:
                    byte = int(line, 2)
                    data.append(byte)
                except ValueError:
                    print(f"Warning: Skipping invalid binary line: {line}")
                    continue
    except UnicodeDecodeError:
        # If UTF-8 fails, try reading as raw binary
        with open(filename, 'rb') as f:
            data = list(f.read())
    return data

def read_hex_font_file(filename):
    data = []
    with open(filename, 'r', encoding='utf-8') as f:
        for line in f:
            # Remove any whitespace and convert to integer
            try:
                byte = int(line.strip(), 16)
                data.append(byte)
            except ValueError:
                print(f"Warning: Skipping invalid hex line: {line}")
                continue
    return data

def read_font_file(filename):
    _, ext = os.path.splitext(filename)
    if ext.lower() == '.bin':
        return read_binary_font_file(filename)
    else:  # Default to hex format
        return read_hex_font_file(filename)

def create_bitmap(data):
    # Calculate image dimensions
    img_width = TOTAL_WIDTH * CHARS_PER_ROW
    num_rows = NUM_CHARS // CHARS_PER_ROW
    img_height = num_rows * CHAR_HEIGHT
    
    # Create new image
    img = Image.new('RGB', (img_width, img_height), color=BG_COLOR)
    draw = ImageDraw.Draw(img)
    
    # Load a font for drawing indices
    try:
        font = ImageFont.truetype("arial.ttf", 12)
    except IOError:
        font = ImageFont.load_default()

    # Calculate actual bytes per character from data size
    actual_bytes_per_char = len(data) // NUM_CHARS

    for char_index in range(NUM_CHARS):
        row = char_index // CHARS_PER_ROW
        col = char_index % CHARS_PER_ROW
        
        # Calculate position
        x = col * TOTAL_WIDTH
        y = row * CHAR_HEIGHT
        
        # Draw the index
        index_str = f"{char_index:03d}"
        draw.text((x, y), index_str, font=font, fill=FG_COLOR)
        
        # Draw the character
        char_x = x + INDEX_WIDTH
        for row_offset in range(CHAR_HEIGHT):
            # For files with more bytes per character than we need,
            # pick the bytes that correspond to the visible part of the character
            byte_offset = row_offset * (actual_bytes_per_char // CHAR_HEIGHT)
            byte = data[char_index * actual_bytes_per_char + byte_offset]
            for col_offset in range(CHAR_WIDTH):
                if byte & (0x80 >> col_offset):
                    draw.point((char_x + col_offset, y + row_offset), fill=FG_COLOR)

    return img

def main():
    if not os.path.exists(FONT_FILE):
        print(f"Error: Font file '{FONT_FILE}' not found.")
        return

    data = read_font_file(FONT_FILE)
    
    # Check if data size is a multiple of NUM_CHARS
    if len(data) % NUM_CHARS != 0:
        print(f"Error: Data size ({len(data)} bytes) is not a multiple of character count ({NUM_CHARS}).")
        return
        
    actual_bytes_per_char = len(data) // NUM_CHARS
    print(f"Found {actual_bytes_per_char} bytes per character in input file.")

    img = create_bitmap(data)
    # Scale up for better visibility
    img = img.resize((img.width * SCALE_FACTOR, img.height * SCALE_FACTOR), Image.NEAREST)
    
    # Generate output filename and ensure output directory exists
    output_file = get_output_filename(FONT_FILE)
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    img.save(output_file)
    print(f"Bitmap saved to: {output_file}")
    img.show()

if __name__ == "__main__":
    main()