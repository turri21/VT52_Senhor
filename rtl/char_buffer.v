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

module char_buffer #(
    parameter ADDR_BITS = 11,
    parameter COLS = 80,
    parameter ROWS = 25,                     // One extra row for scroll buffer
    parameter INIT_FILE = "mem/empty.hex"
) (
    input wire clk,
    input wire reset,
    input wire [7:0] din,
    input wire [ADDR_BITS-1:0] waddr,
    input wire wen,
    input wire scroll,
    input wire vblank,
    input wire [ADDR_BITS-1:0] raddr,
    output reg [7:0] dout,
    output reg scroll_busy,
    output reg scroll_done,
    input wire font_8x8
);

    reg [7:0] mem [(ROWS*COLS)-1:0];
    reg [ADDR_BITS-1:0] scroll_addr;
    reg scrolling;
    reg scroll_pending;
	
    integer i;

    initial begin
        for (i = 0; i < ROWS*COLS; i = i + 1) begin
            mem[i] = 8'h20;  // Initialize all to space
        end
        $readmemh(INIT_FILE, mem);
    end

    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < ROWS*COLS; i = i + 1) begin
                mem[i] = 8'h20;  // Initialize all to space
            end
            $readmemh(INIT_FILE, mem);
            scrolling <= 0;
            scroll_busy <= 0;
            scroll_done <= 0;
            scroll_addr <= 0;
            scroll_pending <= 0;
        end
        else begin
            scroll_done <= 0;  // Single cycle pulse

            // Handle new scroll requests
            if (scroll && !scrolling && !scroll_pending) begin
                scroll_pending <= 1;    // Queue the scroll operation
                scroll_busy <= 1;       // Indicate we're waiting to scroll
            end

            // Start scroll operation on vblank rising edge if there's a pending scroll
            if (vblank && scroll_pending && !scrolling) begin
                scrolling <= 1;
                scroll_addr <= 0;
                scroll_pending <= 0;    // Clear pending flag
            end
            
            // Perform scroll operation
            if (scrolling) begin
                if (scroll_addr < (ROWS-1)*COLS) begin
                    mem[scroll_addr] <= mem[scroll_addr + COLS];
                    scroll_addr <= scroll_addr + 1;
                end
                else begin
                    mem[scroll_addr] <= 8'h20;  // Clear current position
                    if (scroll_addr < (ROWS*COLS - 1)) begin
                        scroll_addr <= scroll_addr + 1;
                    end
                    else begin
                        scrolling <= 0;
                        scroll_busy <= 0;
                        scroll_done <= 1;
                    end
                end
            end
            else begin
                // Normal write operation with character validation
                if (wen && (waddr < ROWS*COLS)) begin
                    // Validate character based on font mode
                    if (!font_8x8 || !din[7]) begin  // 8-bit for 8x16, 7-bit for 8x8
                        mem[waddr] <= din;
                    end
                    else begin
                        mem[waddr] <= 8'h20;  // Write space for invalid characters
                    end
                end
            end
            
            // Read operation
            dout <= (raddr < ROWS*COLS) ? mem[raddr] : 8'h20;
        end
    end

endmodule