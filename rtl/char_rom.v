/* ================================================================
 * VT52
 *
 * Copyright (C) 2024 Fred Van Eijk
 *
 * Permission is hereby granted, free of charge, to any person 
 * obtaining a copy of this software and associated documentation 
 * files (the "Software"), to deal in the Software without 
 * restriction, including without limitation the rights to use, 
 * copy, modify, merge, publish, distribute, sublicense, and/or 
 * sell copies of the Software, and to permit persons to whom 
 * the Software is furnished to do so, subject to the following 
 * conditions:
 * 
 * The above copyright notice and this permission notice shall be 
 * included in all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, 
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT 
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR 
 * OTHER DEALINGS IN THE SOFTWARE.
 * ================================================================
 */

module char_rom (
    input wire clk,
    input wire font_8x8,           // Runtime font selection
    input wire [11:0] addr,        // Keep same address width for compatibility
    output wire [7:0] dout         // Changed from reg to wire
);
    // Two separate memory arrays
    reg [7:0] mem_8x8 [1023:0];    // 128 chars * 8 rows = 1K
    reg [7:0] mem_8x16 [4095:0];   // 256 chars * 16 rows = 4K
    
    initial begin
        $readmemb("mem/vt52_rom.bin", mem_8x8);
        $readmemb("mem/terminus_816_latin1.bin", mem_8x16);
    end
    
    // Map input character number and row to correct memory address
    wire [6:0] char_num = font_8x8 ? addr[11:3] & 7'h7F : addr[11:4];  // Mask to 7 bits in 8x8 mode
    wire [2:0] row_8 = addr[2:0];
    wire [3:0] row_16 = addr[3:0];
    
    wire [9:0] addr_8x8 = {char_num[6:0], row_8};     // 7 bits char + 3 bits row
    wire [11:0] addr_8x16 = {addr[11:4], row_16};     // Full 8-bit char + 4 bits row
    
    // Changed from registered to combinational output
    assign dout = font_8x8 ? mem_8x8[addr_8x8] : mem_8x16[addr_8x16];

endmodule