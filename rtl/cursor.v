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

module cursor
  #(parameter ROW_BITS = 5,
    parameter COL_BITS = 7)
   (input clk,
    input reset,
    input tick,
    output wire [COL_BITS-1:0] x,
    output wire [ROW_BITS-1:0] y,
    output wire blink_on,
    input [COL_BITS-1:0] new_x,
    input [ROW_BITS-1:0] new_y,
    input wen
    );

   cursor_blinker cursor_blinker(.clk(clk),
                                 .reset(reset),
                                 .tick(tick),
                                 .reset_count(wen),
                                 .blink_on(blink_on)
                                 );

   simple_register #(.SIZE(COL_BITS))
      cursor_x_reg(.clk(clk),
                   .reset(reset),
                   .idata(new_x),
                   .wen(wen),
                   .odata(x)
                   );

   simple_register #(.SIZE(ROW_BITS))
      cursor_y_reg(.clk(clk),
                   .reset(reset),
                   .idata(new_y),
                   .wen(wen),
                   .odata(y)
                   );
endmodule
