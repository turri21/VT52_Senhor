/**
 * Character Font ROM (4kx8)
 * This could be a RAM to allow font modifications, but not for now
 * latin-1 subset of Terminus Font 8x16 (http://terminus-font.sourceforge.net)
 * Terminus Font is licensed under the SIL Open Font License, Version 1.1.
 * The license is included as ofl.txt, and is also available with a FAQ
 * at http://scripts.sil.org/OFL
 
 
 
 
 This Verilog module defines a `char_rom` (character read-only memory) that is used to 
 store and retrieve character data, for use in a text display system, such as 
 for an FPGA project.

### Breakdown:

1. **Inputs and Outputs**:
   - **`clk` (input)**: The clock signal that synchronizes the module's operations.
   - **`addr` (input)**: A 12-bit address input, which can access up to 4096 memory locations (`2^12 = 4096`).
   - **`dout` (output)**: An 8-bit output that retrieves data from the memory (`mem`) at the specified address (`addr`).

2. **Memory Declaration**:
   - **`mem`**: A 4096x8-bit memory (`reg [7:0] mem [4095:0]`), which holds 4096 8-bit values. 
   This memory array is used to store character bitmaps or glyph data.

3. **`initial` Block**:
   - This block is executed once at the start of the simulation. It initializes the memory 
   by loading data from an external file.
   - **`$readmemb`**: Loads binary data from the file `"mem/terminus_816_latin1.bin"` into the memory.
   - There is also a commented-out line that could alternatively load a hexadecimal file (`$readmemh`), 
   which would load data from `"mem/terminus_816_bold_latin1.hex"` if used.

4. **`always @(posedge clk)` Block**:
   - This block is triggered on the rising edge of the clock (`clk`). 
   - When this happens, the module reads from the memory location specified by `addr` and assigns 
   the corresponding value to the output `dout`.

### Purpose:
The module is likely used to store character bitmap data, where each character is represented by an 
8-bit value, and the `addr` input is used to retrieve specific characters. This could be part of a 
character generator for a display system, such as for rendering text on a screen in an FPGA core. The 
binary or hexadecimal file loaded in the `initial` block would contain the graphical representation 
of characters (e.g., ASCII or Latin-1 characters).
 
 
 
 */
module char_rom
  (input clk,
   input [11:0] addr,
   output reg [7:0] dout
   );
   
   reg [7:0] mem [4095:0];
   
   initial begin
      $readmemb("mem/terminus_816_latin1.bin", mem);
      // $readmemh("mem/terminus_816_bold_latin1.hex", mem);
   end
   
   always @(posedge clk) begin
      dout <= mem[addr];
   end
endmodule
