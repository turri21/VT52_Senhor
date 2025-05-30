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

module cursor_blinker
  (input clk,
   input reset,
   input tick,
   input reset_count,
   output wire blink_on
   );
   localparam BITS = 6;
   reg has_incremented;
   reg [BITS-1:0] counter;
   always @(posedge clk) begin
      if (reset) begin
         counter <= 0;
         has_incremented <= 0;
      end
      else if (reset_count) begin
         counter <= 0;
         has_incremented <= tick;
      end
      else if (tick && !has_incremented) begin
         counter <= counter + 1;
         has_incremented <= 1;
      end
      else if (!tick && has_incremented) begin
         has_incremented <= 0;
      end
   end
   assign blink_on = ~counter[BITS-1];
endmodule
