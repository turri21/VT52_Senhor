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

module vt52_8251_uart (
    input wire clk,           // System clock
    input wire rst_n,         // Active low reset

    // TX Configuration Interface
    input wire [1:0] tx_char_length,  // 00=5bit, 01=6bit, 10=7bit, 11=8bit
    input wire [1:0] tx_stop_bits,    // 00=1bit, 01=1.5bit, 10=2bit
    input wire [1:0] tx_parity_mode,  // 00=none, 01=odd, 10=even
    input wire [15:0] tx_baud_div,    // TX clock divider for baud rate

    // RX Configuration Interface
    input wire [1:0] rx_char_length,  // 00=5bit, 01=6bit, 10=7bit, 11=8bit
    input wire [1:0] rx_stop_bits,    // 00=1bit, 01=1.5bit, 10=2bit
    input wire [1:0] rx_parity_mode,  // 00=none, 01=odd, 10=even
    input wire [15:0] rx_baud_div,    // RX clock divider for baud rate

    // Status Signals
    output reg overrun_error,         // Receive overrun
    output reg framing_error,         // Stop bit error
    output reg parity_error,          // Parity check failed
    output reg tx_ready,              // Transmitter ready for data
    output reg rx_ready,              // Receiver has data
    output reg tx_bit_clock,          // Debug: toggles at TX baud rate
    output reg rx_bit_clock,          // Debug: pulse at sampling points
    output reg [2:0] rx_state,        // Debug: current RX state

    // Data Interface
    input wire [7:0] tx_data,         // Data to transmit
    input wire tx_load,               // Load transmit data
    output reg [7:0] rx_data,         // Received data
    input wire rx_read,               // Read received data

    // Serial Interface
    output reg serial_out,            // TX
    input wire serial_in              // RX
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam START = 3'b001;
    localparam DATA = 3'b010;
    localparam PARITY = 3'b011;
    localparam STOP = 3'b100;

    // Transmitter registers
    reg [2:0] tx_state;
    reg [3:0] tx_bit_count;
    reg [15:0] tx_baud_count;
    reg [7:0] tx_shift_reg;
    reg tx_parity;
    reg tx_active;
    wire [3:0] tx_char_bits = {1'b0, tx_char_length} + 4'd5;

    // Receiver registers
    reg [3:0] rx_bit_count;
    reg [15:0] rx_baud_count;
    reg [7:0] rx_shift_reg;
    reg rx_parity;
    reg rx_active;
    wire [3:0] rx_char_bits = {1'b0, rx_char_length} + 4'd5;

    // Input synchronizer for serial_in
    reg [2:0] rx_sync;
    wire rx_bit;

    // Synchronize input
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rx_sync <= 3'b111;
        else
            rx_sync <= {rx_sync[1:0], serial_in};
    end
    
    assign rx_bit = rx_sync[2];

    // TX bit clock
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_bit_clock <= 0;
        end
        else if (tx_active && tx_baud_count == tx_baud_div) begin
            tx_bit_clock <= ~tx_bit_clock;
        end
    end

    // RX bit clock - pulse at sampling points
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_bit_clock <= 0;
        end
        else begin
            // Default - clock is low
            rx_bit_clock <= 0;
            
            // Generate pulse at sampling points
            if (rx_active) begin
                case (rx_state)
                    START: begin
                        if (rx_baud_count == (rx_baud_div*3)/4)
                            rx_bit_clock <= 1;
                    end
                    
                    DATA, PARITY, STOP: begin
                        if (rx_baud_count == rx_baud_div/2)
                            rx_bit_clock <= 1;
                    end
                    
                    default: rx_bit_clock <= 0;
                endcase
            end
        end
    end

    // Transmitter logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state <= IDLE;
            tx_ready <= 1'b1;
            serial_out <= 1'b1;
            tx_baud_count <= 0;
            tx_bit_count <= 0;
            tx_parity <= 0;
            tx_active <= 0;
        end
        else begin
            if (tx_active) begin
                if (tx_baud_count == tx_baud_div) begin
                    tx_baud_count <= 0;
                end
                else begin
                    tx_baud_count <= tx_baud_count + 1'd1;
                end
            end

            case (tx_state)
                IDLE: begin
                    serial_out <= 1'b1;
                    tx_active <= 0;
                    if (tx_load && tx_ready) begin
                        tx_shift_reg <= tx_data;
                        tx_ready <= 1'b0;
                        tx_state <= START;
                        tx_parity <= (tx_parity_mode[1]) ? 1'b0 : 1'b1;
                        tx_baud_count <= 0;
                        tx_active <= 1;
                    end
                end

                START: begin
                    serial_out <= 1'b0;
                    if (tx_baud_count == tx_baud_div) begin
                        tx_state <= DATA;
                        tx_bit_count <= 0;
                        tx_baud_count <= 0;
                    end
                end

                DATA: begin
                    serial_out <= tx_shift_reg[0];
                    if (tx_baud_count == tx_baud_div) begin
                        tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};
                        tx_parity <= tx_parity ^ tx_shift_reg[0];
                        tx_baud_count <= 0;
                        
                        if (tx_bit_count == tx_char_bits - 1) begin
                            tx_state <= (tx_parity_mode != 0) ? PARITY : STOP;
                        end
                        else begin
                            tx_bit_count <= tx_bit_count + 1'd1;
                        end
                    end
                end

                PARITY: begin
                    serial_out <= tx_parity;
                    if (tx_baud_count == tx_baud_div) begin
                        tx_state <= STOP;
                        tx_baud_count <= 0;
                    end
                end

                STOP: begin
                    serial_out <= 1'b1;
                    if (tx_baud_count == tx_baud_div * 
                        ((tx_stop_bits == 2'b01) ? 3/2 : 
                         (tx_stop_bits == 2'b10) ? 2 : 
                         1)) begin
                        tx_state <= IDLE;
                        tx_ready <= 1'b1;
                        tx_baud_count <= 0;
                    end
                end

                default: begin
                    tx_state <= IDLE;
                end
            endcase
        end
    end

    // Receiver logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state <= IDLE;
            rx_ready <= 1'b0;
            overrun_error <= 1'b0;
            framing_error <= 1'b0;
            parity_error <= 1'b0;
            rx_bit_count <= 0;
            rx_baud_count <= 0;
            rx_parity <= 0;
            rx_active <= 0;
            rx_data <= 8'h00;
        end
        else begin
            if (rx_active) begin
                if (rx_baud_count == rx_baud_div) begin
                    rx_baud_count <= 0;
                end
                else begin
                    rx_baud_count <= rx_baud_count + 1'd1;
                end
            end

            if (rx_read) begin
                rx_ready <= 1'b0;
                overrun_error <= 1'b0;
                framing_error <= 1'b0;
                parity_error <= 1'b0;
            end

            case (rx_state)
                IDLE: begin
                    rx_active <= 0;
                    if (!rx_bit) begin  // Start bit detected in synchronized input
                        rx_state <= START;
                        rx_baud_count <= 2;  // Start at 2 to compensate for sync delay
                        rx_parity <= (rx_parity_mode[1]) ? 1'b0 : 1'b1;
                        rx_active <= 1;
                    end
                end

                START: begin
                    if (rx_baud_count == (rx_baud_div*3)/4) begin
                        if (!rx_bit) begin
                            rx_state <= DATA;
                            rx_bit_count <= 0;
                            rx_baud_count <= 0;
                        end
                        else begin
                            rx_state <= IDLE;
                            rx_active <= 0;
                        end
                    end
                end

                DATA: begin
                    if (rx_baud_count == rx_baud_div/2) begin
                        rx_shift_reg <= {rx_bit, rx_shift_reg[7:1]};
                        rx_parity <= rx_parity ^ rx_bit;
                        
                        if (rx_bit_count == rx_char_bits - 1) begin
                            rx_state <= (rx_parity_mode != 0) ? PARITY : STOP;
                            rx_baud_count <= 0;
                        end
                        else begin
                            rx_bit_count <= rx_bit_count + 1'd1;
                        end
                    end
                end

                PARITY: begin
                    if (rx_baud_count == rx_baud_div/2) begin
                        if (rx_bit != rx_parity) begin
                            parity_error <= 1'b1;
                        end
                        rx_state <= STOP;
                        rx_baud_count <= 0;
                    end
                end

                STOP: begin
                    if (rx_baud_count == rx_baud_div/2) begin
                        if (!rx_bit) begin
                            framing_error <= 1'b1;
                        end
                        
                        if (rx_ready) begin
                            overrun_error <= 1'b1;
                        end
                        else begin
                            case (rx_char_length)
                                2'b00: rx_data <= {3'b000, rx_shift_reg[4:0]};
                                2'b01: rx_data <= {2'b00, rx_shift_reg[5:0]};
                                2'b10: rx_data <= {1'b0, rx_shift_reg[6:0]};
                                2'b11: rx_data <= rx_shift_reg;
                            endcase
                            rx_ready <= 1'b1;  // Always set ready when we have new data
                        end
                    end
                    else if (rx_baud_count == rx_baud_div) begin  // End of stop bit
                        rx_state <= IDLE;
                        rx_active <= 0;
                        if (rx_bit) begin
                            framing_error <= 0;
                        end
                    end
                end

                default: begin
                    rx_state <= IDLE;
                end
            endcase
        end
    end

endmodule