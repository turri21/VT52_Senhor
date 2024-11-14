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


/**
 * Keymap ROM (2KB, maps keycodes to ASCII chars)
 * This could be a RAM to allow keymap modifications, but not for now
 * There's 8 planes for each keycode (controlled by the highest three bits)
 * MSB is for long keycode vs short keycode, the the next two bits:
 * 00: no shift or caps lock
 * 01: just shift
 * 10: just caps lock
 * 11: caps lock & shift
 */

module keymap_rom
  (input clk,
   input [10:0] addr,
   output reg [7:0] dout
   );
   
   reg [7:0]    mem [2047:0];
   integer i;
   
   initial begin
      // the hex file is sparse, prefill with zeros
      // XXX yosys doesn't like this, it overrides the readmemh
      // so for now just assume that all other positions have zeros...
      // for (i = 0; i < 2047; i = i + 1) mem[i] = "b";
      $readmemh("mem/keymap.hex", mem);
   end
   
   always @(posedge clk) begin
      dout <= mem[addr];
   end
endmodule