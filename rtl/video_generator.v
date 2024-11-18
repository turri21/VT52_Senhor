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
 
module video_generator
 #(parameter ROWS = 24,            // Visible rows
   parameter COLS = 80,
   parameter ROW_BITS = 5,
   parameter COL_BITS = 7,
   parameter ADDR_BITS = 11)
  (
   input  wire        clk,
   input  wire        reset,
   input  wire        ce_pixel,    // Pixel clock enable
   input  wire        font_8x8,    // Runtime font selection
   
   // video output
   output reg         hsync,
   output reg         vsync,
   output reg         video,
   output reg         hblank,
   output reg         vblank,
   
   // cursor
   input  wire [COL_BITS-1:0] cursor_x,
   input  wire [ROW_BITS-1:0] cursor_y,
   input  wire        cursor_blink_on,
   
   // char buffer
   output wire [ADDR_BITS-1:0] char_buffer_address,
   input  wire [7:0]  char_buffer_data,
   
   // char rom
   output wire [11:0] char_rom_address,
   input  wire [7:0]  char_rom_data
   );

  localparam hbits = 10;         // Need 10 bits to count up to 936
  localparam vbits = 9;          // Need 9 bits to count up to 420

 // VT52 timing with dynamic character height
 localparam hpixels = 936;       // Total horizontal pixels
 localparam hvisible = 640;      // 80 chars * 8 dots
 localparam hbp = 96;            // Back porch
 localparam hfp = 104;           // Front porch
 localparam hpulse = 96;         // Sync pulse

   reg [vbits-1:0] vlines;          // Total scan lines
   reg [vbits-1:0] vvisible;        // Visible scan lines 
   reg [vbits-1:0] voffset;         // Vertical offset
   reg [vbits-1:0] vfp_reg;         // Dynamic front porch
   reg [vbits-1:0] vbp_reg;         // Dynamic back porch
 
 localparam vpulse = 2;          // Vertical sync pulse
 
 // Calculate vertical timing values based on font_8x8
 always @* begin
   vvisible = ROWS * (font_8x8 ? 8 : 16);
   vlines = font_8x8 ? 262 : 420;
   vbp_reg = font_8x8 ? 16 : 16;
   vfp_reg = font_8x8 ? 52 : 18;  // Adjusted for exact 60Hz in 8x8 mode
   voffset = ((vvisible - (ROWS * (font_8x8 ? 8 : 16))) >> 1);
 end

  localparam hsync_on = 1'b0;     // Horizontal sync is active low
  localparam vsync_on = 1'b0;     // Vertical sync is active low
  localparam hsync_off = ~hsync_on;
  localparam vsync_off = ~vsync_on;
  
  localparam video_on = 1'b1;
  localparam video_off = ~video_on;

  // Video generation signals
  reg is_under_cursor;
  reg cursor_pixel;
  reg char_pixel;
  reg combined_pixel;

  // Counters for horizontal and vertical timing
  reg [hbits-1:0] hc, next_hc;
  reg [vbits-1:0] vc, next_vc;
  
  // Next state signals for sync and blank
  reg next_hblank, next_vblank, next_hsync, next_vsync;
  
  // Character position tracking
  reg [ROW_BITS-1:0] row, next_row;
  reg [COL_BITS-1:0] col, next_col;
  
  // Pixel position within character
  reg [2:0] colc, next_colc;      // 0-7 for 8 pixels wide
  reg [4:0] rowc, next_rowc;      // Made wide enough for 0-15

  // Memory interface assignments
  assign char_buffer_address = row * COLS + col;
  assign char_rom_address = font_8x8 ? 
                           {1'b0, char_buffer_data[6:0], rowc[2:0]} :   // 7-bit char + 3-bit row for 8x8
                           {char_buffer_data, rowc[3:0]};               // 8-bit char + 4-bit row for 8x16

  // Calculate if current position is in visible text area
  wire in_visible_area = !next_hblank && !next_vblank &&
                        (next_vc >= (vbp_reg + voffset)) &&
                        (next_vc < (vbp_reg + voffset + vvisible));

  // Horizontal and vertical counters with sync and blank generation
  always @(posedge clk) begin
     if (reset) begin
        hc <= 0;
        vc <= 0;
        hsync <= hsync_off;
        vsync <= vsync_off;
        hblank <= 1'b1;
        vblank <= 1'b1;
     end
     else if (ce_pixel) begin
        hc <= next_hc;
        vc <= next_vc;
        hsync <= next_hsync;
        vsync <= next_vsync;
        hblank <= next_hblank;
        vblank <= next_vblank;
     end
  end

  // Next state calculation for counters and sync signals
  always @(*) begin
     if (hc == hpixels - 1) begin
        next_hc = 0;
        next_vc = (vc == vlines - 1) ? 0 : vc + 1;
     end
     else begin
        next_hc = hc + 1;
        next_vc = vc;
     end
     
     // Generate sync pulses
     next_hsync = (next_hc >= (hbp + hvisible + hfp)) ? hsync_on : hsync_off;
     next_vsync = (next_vc >= (vbp_reg + vvisible + vfp_reg)) ? vsync_on : vsync_off;
     
     // Generate blank signals
     next_hblank = (next_hc < hbp) || (next_hc >= (hbp + hvisible));
     next_vblank = (next_vc < vbp_reg) || (next_vc >= (vbp_reg + vvisible));
  end

  // Character and row/column position tracking
  always @(posedge clk) begin
     if (reset) begin
        row <= 0;
        col <= 0;
        rowc <= 0;
        colc <= 0;
     end
     else if (ce_pixel) begin
        row <= next_row;
        col <= next_col;
        rowc <= next_rowc;
        colc <= next_colc;
     end
  end

  // Next state calculation for character position
  always @(*) begin
     if (next_vc < (vbp_reg + voffset)) begin
        // Before visible area
        next_row = 0;
        next_rowc = 0;
        next_col = 0;
        next_colc = 0;
     end
     else if (next_hblank) begin
        // Reset column counters at line end
        next_row = row;
        next_rowc = rowc;
        next_col = 0;
        next_colc = 0;

        if (hblank == 0) begin  // Positive edge of hblank
           if ((font_8x8 && rowc == 7) || (!font_8x8 && rowc == 15)) begin
              next_row = row + 1;
              next_rowc = 0;
           end
           else begin
              next_rowc = rowc + 1;
           end
        end
     end
     else begin
        next_row = row;
        next_rowc = rowc;
        next_col = col;
        next_colc = colc + 1;

        if (colc == 7) begin
           next_col = col + 1;
           next_colc = 0;
        end
     end
  end

  // pixel out (char & cursor combination)
  always @(posedge clk) begin
     if (reset) 
        video <= video_off;
     else if (ce_pixel)
        video <= in_visible_area ? combined_pixel : video_off;
  end

  // Pixel combination logic
  always @(*) begin
      // cursor pixel: invert video when we are under the cursor (if it's blinking)
     is_under_cursor = (cursor_x == col) & (cursor_y == row);
     cursor_pixel = is_under_cursor & cursor_blink_on;
      // char pixel: read from the appropiate char, row & col on the font ROM,
      // the pixels LSB->MSB ordered
     char_pixel = char_rom_data[7 - colc];
      
     // Combine character and cursor
     combined_pixel = char_pixel ^ cursor_pixel;
  end

endmodule