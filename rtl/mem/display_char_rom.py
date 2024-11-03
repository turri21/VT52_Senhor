from PIL import Image, ImageDraw

def read_font_file(filename):
    data = []
    with open(filename, 'r') as f:
        for line in f:
            # Remove any whitespace and convert to integer
            byte = int(line.strip(), 16)
            data.append(byte)
    return data

def create_bitmap(data):
    # 256 characters, each 8x16 pixels
    img_width = 128  # 16 characters per row
    img_height = 256  # 16 rows of characters
    img = Image.new('1', (img_width, img_height), color=0)
    draw = ImageDraw.Draw(img)

    for char_index in range(128):
        char_x = (char_index % 16) * 8
        char_y = (char_index // 16) * 16
        
        for row in range(16):
            byte = data[char_index * 16 + row]
            for col in range(8):
                if byte & (0x80 >> col):
                    draw.point((char_x + col, char_y + row), fill=1)

    return img

def main():
    font_file = 'mem/terminus_816_latin1.hex'  # Updated filename
    data = read_font_file(font_file)
    if len(data) != 4096:
        print(f"Error: Expected 2048 bytes, but got {len(data)} bytes.")
        return

    img = create_bitmap(data)
    img = img.resize((img.width * 4, img.height * 4), Image.NEAREST)  # Scale up for better visibility
    img.show()

if __name__ == "__main__":
    main()