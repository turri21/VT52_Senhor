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

module input_multiplexer 
(
    input                clk,          
    input                reset,
    
    // Keyboard input interface
    input         [7:0]  kbd_data,
    input                kbd_valid,
    output reg           kbd_ready,
    
    // UART input interface
    input         [7:0]  uart_data,
    input                uart_valid,
    output reg           uart_ready,
    
    // Output interface to command handler
    output reg    [7:0]  out_data,
    output reg           out_valid,
    output reg           out_from_uart,
    input                out_ready
);

    // State machine with simplified ready logic
    always @(posedge clk) begin
        if (reset) begin
            out_data <= 8'h0;
            out_valid <= 1'b0;
            out_from_uart <= 1'b0;
            kbd_ready <= 1'b1;
            uart_ready <= 1'b1;
        end
        else begin
            // If command handler has accepted the data, clear valid
            if (out_valid && out_ready) begin
                out_valid <= 1'b0;
                kbd_ready <= 1'b1;
                uart_ready <= 1'b1;
            end

            // If we're not currently sending data
            if (!out_valid) begin
                // Handle keyboard input with priority
                if (kbd_valid) begin
                    out_data <= kbd_data;
                    out_valid <= 1'b1;
                    out_from_uart <= 1'b0;
                    kbd_ready <= 1'b0;
                end
                // Handle UART input if no keyboard data
                else if (uart_valid) begin
                    out_data <= uart_data;
                    out_valid <= 1'b1;
                    out_from_uart <= 1'b1;
                    uart_ready <= 1'b0;
                end
                // If neither input is valid, stay ready
                else begin
                    kbd_ready <= 1'b1;
                    uart_ready <= 1'b1;
                end
            end
        end
    end

endmodule