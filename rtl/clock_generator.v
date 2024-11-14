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


module clock_generator
  (input  clk,
   output clk_usb,
   output reset_usb,
   output clk_vga,
   output reset_vga
   );
   wire locked;
   reg vga_clk_divider;
   
   // PLL instantiation
   my_pll pll_inst (
      .inclk0(clk),
      .c0(clk_usb),
      .locked(locked)
   );
   
   // Generate reset signal
   reg [5:0] reset_cnt = 0;
   assign reset_usb = ~reset_cnt[5];
   always @(posedge clk_usb)
     if (locked) reset_cnt <= reset_cnt + reset_usb;
   
   // divide usb clock by two to get vga clock
   always @(posedge clk_usb) begin
      if (reset_usb) vga_clk_divider <= 0;
      else vga_clk_divider <= ~vga_clk_divider;
   end
   
   assign clk_vga = vga_clk_divider;
   assign reset_vga = reset_usb;
endmodule