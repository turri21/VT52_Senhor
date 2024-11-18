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

module VT52_terminal 
(
 input             clk,
 input             reset,
 input             ce_pix,
 input             font_8x8,
 
 output wire       hsync,
 output wire       vsync,
 output wire       hblank,
 output wire       vblank,
 output wire       video,
 output reg        led,
 
 input             ps2_data,
 input             ps2_clk,
 
 output wire       uart_tx,
 input  wire       uart_rx
);

 localparam ROWS = 24;
 localparam COLS = 80;
 localparam ROW_BITS = 5;
 localparam COL_BITS = 7;
 localparam ADDR_BITS = 11;
 
 // vt52_8251_uart configuration parameters - TX Side
 localparam [1:0] TX_CHAR_LENGTH = 2'b11;    // 8 bits
 localparam [1:0] TX_STOP_BITS = 2'b00;      // 1 stop bit
 localparam [1:0] TX_PARITY_MODE = 2'b00;    // No parity
 localparam [15:0] TX_BAUD_DIV = 16'd255;    // 29.4MHz/115200 baud

 // vt52_8251_uart configuration parameters - RX Side
 localparam [1:0] RX_CHAR_LENGTH = 2'b11;    // 8 bits
 localparam [1:0] RX_STOP_BITS = 2'b00;      // 1 stop bit
 localparam [1:0] RX_PARITY_MODE = 2'b00;    // No parity
 localparam [15:0] RX_BAUD_DIV = 16'd255;    // 29.4MHz/115200 baud
 
 // Debug signals from keyboard
 wire [15:0] kbd_valid_extend;
 wire kbd_activity;
 reg kbd_active;
 wire kbd_ps2_error;     // PS/2 frame error signal
 
 // Separate keyboard and UART data paths
 wire [7:0] kbd_data;
 wire kbd_valid;
 wire kbd_ready;
 
 wire [7:0] uart_rx_data;
 wire uart_rx_valid;
 wire uart_rx_ready;
 
 wire [7:0] uart_tx_data;
 wire uart_tx_valid;
 wire uart_tx_ready;

 // Multiplexer signals
 wire [7:0] mux_out_data;
 wire mux_out_valid;
 wire mux_out_ready;
 wire mux_out_from_uart;

 // Command handler outputs
 wire buffer_scroll;
 wire scroll_busy;    
 wire scroll_done;    
 wire [7:0] buffer_write_char;
 wire [ADDR_BITS-1:0] buffer_write_addr;
 wire buffer_write_enable;
 wire [COL_BITS-1:0] new_cursor_x;
 wire [ROW_BITS-1:0] new_cursor_y;
 wire new_cursor_wen;

 // Video signals
 wire [COL_BITS-1:0] cursor_x;
 wire [ROW_BITS-1:0] cursor_y;
 wire cursor_blink_on;
 wire [ADDR_BITS-1:0] buffer_read_addr;
 wire [7:0] buffer_read_char;
 wire [11:0] char_rom_address;
 wire [7:0] char_rom_data;

 // vt52_8251_uart UART status signals
 wire uart_overrun_error;
 wire uart_framing_error;
 wire uart_parity_error;
 wire uart_tx_bit_clock;
 wire uart_rx_bit_clock;
 wire [2:0] uart_rx_state;

 // LED logic includes scroll_busy indication
 always @(posedge clk) begin
    if (reset)
       led <= 0;
    else
       led <= cursor_blink_on | uart_overrun_error | uart_framing_error | 
              uart_parity_error | kbd_active | kbd_ps2_error | scroll_busy;
 end

 // Keyboard activity detector with proper reset
 always @(posedge clk) begin
    if (reset)
       kbd_active <= 0;
    else if (kbd_activity)  // PS/2 activity detected
       kbd_active <= 1;
    else if (ps2_clk_sync == 3'b111)  // PS/2 clock stable high, activity done
       kbd_active <= 0;
 end

 // PS/2 clock sync
 reg [2:0] ps2_clk_sync;
 always @(posedge clk) begin
    ps2_clk_sync <= {ps2_clk_sync[1:0], ps2_clk};
 end

 // UART handling
 reg [7:0] kbd_to_uart_data;
 reg kbd_to_uart_valid;

 always @(posedge clk) begin
    if (reset) begin
       kbd_to_uart_data <= 8'h0;
       kbd_to_uart_valid <= 1'b0;
    end
    else begin
       if (kbd_to_uart_valid && uart_tx_ready) begin
          kbd_to_uart_valid <= 1'b0;
       end
       else if (kbd_valid && kbd_ready) begin
          kbd_to_uart_data <= kbd_data;
          kbd_to_uart_valid <= 1'b1;
       end
    end
 end

 assign uart_tx_data = kbd_to_uart_data;
 assign uart_tx_valid = kbd_to_uart_valid;

 // UART Instance
 vt52_8251_uart uart (
    .clk(clk),
    .rst_n(~reset),
    .tx_char_length(TX_CHAR_LENGTH),
    .tx_stop_bits(TX_STOP_BITS),
    .tx_parity_mode(TX_PARITY_MODE),
    .tx_baud_div(TX_BAUD_DIV),
    .rx_char_length(RX_CHAR_LENGTH),
    .rx_stop_bits(RX_STOP_BITS),
    .rx_parity_mode(RX_PARITY_MODE),
    .rx_baud_div(RX_BAUD_DIV),
    .overrun_error(uart_overrun_error),
    .framing_error(uart_framing_error),
    .parity_error(uart_parity_error),
    .tx_ready(uart_tx_ready),
    .rx_ready(uart_rx_valid),
    .tx_bit_clock(uart_tx_bit_clock),
    .rx_bit_clock(uart_rx_bit_clock),
    .rx_state(uart_rx_state),
    .tx_data(uart_tx_data),
    .tx_load(uart_tx_valid && uart_tx_ready),
    .rx_data(uart_rx_data),
    .rx_read(uart_rx_valid && uart_rx_ready),
    .serial_out(uart_tx),
    .serial_in(uart_rx)
 );

 // Keyboard interface
 keyboard keyboard(
    .clk(clk),
    .reset(reset),
    .ps2_data(ps2_data),
    .ps2_clk(ps2_clk),
    .data(kbd_data),
    .valid(kbd_valid),
    .ready(kbd_ready),
    .valid_extend(kbd_valid_extend),
    .ps2_activity(kbd_activity),
    .ps2_error(kbd_ps2_error)
 );

 // Input multiplexer
 input_multiplexer input_mux (
    .clk(clk),
    .reset(reset),
    .kbd_data(kbd_data),
    .kbd_valid(kbd_valid),
    .kbd_ready(kbd_ready),
    .uart_data(uart_rx_data),
    .uart_valid(uart_rx_valid),
    .uart_ready(uart_rx_ready),
    .out_data(mux_out_data),
    .out_valid(mux_out_valid),
    .out_from_uart(mux_out_from_uart),
    .out_ready(mux_out_ready)
 );

 // Command handler with scroll synchronization
 command_handler #(
    .ROWS(ROWS),
    .COLS(COLS),
    .ROW_BITS(ROW_BITS),
    .COL_BITS(COL_BITS),
    .ADDR_BITS(ADDR_BITS)
 ) command_handler(
    .clk(clk),
    .reset(reset),
    .data(mux_out_data),
    .valid(mux_out_valid),
    .from_uart(mux_out_from_uart),
    .ready(mux_out_ready),
    .buffer_scroll(buffer_scroll),
    .scroll_busy(scroll_busy),
    .scroll_done(scroll_done),
    .buffer_write_char(buffer_write_char),
    .buffer_write_addr(buffer_write_addr),
    .buffer_write_enable(buffer_write_enable),
    .new_cursor_x(new_cursor_x),
    .new_cursor_y(new_cursor_y),
    .new_cursor_wen(new_cursor_wen)
 );

 // Cursor
 cursor #(
    .ROW_BITS(ROW_BITS),
    .COL_BITS(COL_BITS)
 ) cursor(
    .clk(clk),
    .reset(reset),
    .tick(vblank),
    .x(cursor_x),
    .y(cursor_y),
    .blink_on(cursor_blink_on),
    .new_x(new_cursor_x),
    .new_y(new_cursor_y),
    .wen(new_cursor_wen)
 );

 // Character buffer with scroll support
 char_buffer #(
    .COLS(COLS),
    .ROWS(25),              // One extra row for scroll buffer
    .ADDR_BITS(ADDR_BITS),
    .INIT_FILE("mem/empty.hex")
 ) char_buffer(
    .clk(clk),
    .reset(reset),
    .scroll(buffer_scroll),
    .vblank(vblank),
    .scroll_busy(scroll_busy),
    .scroll_done(scroll_done),
    .din(buffer_write_char),
    .waddr(buffer_write_addr),
    .wen(buffer_write_enable),
    .raddr(buffer_read_addr),
    .dout(buffer_read_char),
    .font_8x8(font_8x8)
 );

 // Character ROM
 char_rom char_rom(
    .clk(clk),
    .addr(char_rom_address),
    .dout(char_rom_data),
    .font_8x8(font_8x8)
 );

 // Video generator
 video_generator #(
    .ROWS(ROWS),
    .COLS(COLS),
    .ROW_BITS(ROW_BITS),
    .COL_BITS(COL_BITS),
    .ADDR_BITS(ADDR_BITS)
 ) video_generator(
    .clk(clk),
    .reset(reset),
    .ce_pixel(ce_pix),
    .font_8x8(font_8x8),
    .hsync(hsync),
    .vsync(vsync),
    .video(video),
    .hblank(hblank),
    .vblank(vblank),
    .cursor_x(cursor_x),
    .cursor_y(cursor_y),
    .cursor_blink_on(cursor_blink_on),
    .char_buffer_address(buffer_read_addr),
    .char_buffer_data(buffer_read_char),
    .char_rom_address(char_rom_address),
    .char_rom_data(char_rom_data)
 );

endmodule