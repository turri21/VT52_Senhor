from PIL import Image, ImageDraw, ImageFont

def read_font_file(filename):
    data = []
    with open(filename, 'r') as f:
        for line in f:
            # Remove any whitespace and convert to integer
            byte = int(line.strip(), 16)
            data.append(byte)
    return data

def create_bitmap(data):
    # 128 characters, each preceded by its index
    # Each character is 8x16 pixels, index is 24x16 pixels (3 digits)
    char_width, char_height = 8, 16
    index_width = 24
    total_width = 32  # index_width + char_width
    chars_per_row = 8
    
    img_width = total_width * chars_per_row
    img_height = 256  # 16 rows of characters
    img = Image.new('RGB', (img_width, img_height), color=(255, 255, 255))
    draw = ImageDraw.Draw(img)
    
    # Load a font for drawing indices
    try:
        font = ImageFont.truetype("arial.ttf", 12)
    except IOError:
        font = ImageFont.load_default()

    for char_index in range(128):
        row = char_index // chars_per_row
        col = char_index % chars_per_row
        
        x = col * total_width
        y = row * char_height
        
        # Draw the index
        index_str = f"{char_index:03d}"
        draw.text((x, y), index_str, font=font, fill=(0, 0, 0))
        
        # Draw the character
        char_x = x + index_width
        for row_offset in range(16):
            byte = data[char_index * 16 + row_offset]
            for col_offset in range(8):
                if byte & (0x80 >> col_offset):
                    draw.point((char_x + col_offset, y + row_offset), fill=(0, 0, 0))

    return img

def main():
    font_file = 'rtl/mem/character_set.hex'  # Make sure this file exists
    data = read_font_file(font_file)
    if len(data) != 4096:
        print(f"Error: Expected 4096 bytes, but got {len(data)} bytes.")
        return

    img = create_bitmap(data)
    img = img.resize((img.width * 2, img.height * 2), Image.NEAREST)  # Scale up for better visibility
    img.show()
    img.save('font_bitmap_with_indices.png')

if __name__ == "__main__":
    main()