module VT52_terminal 
(
   input             clk,         // Single clock (CLK_VIDEO - 25MHz)
   input             reset,
   input             ce_pix,
   
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
   
   // TR1402A configuration parameters - TX Side
   localparam [1:0] TX_CHAR_LENGTH = 2'b11;    // 8 bits
   localparam [1:0] TX_STOP_BITS = 2'b00;      // 1 stop bit
   localparam [1:0] TX_PARITY_MODE = 2'b00;    // No parity
   localparam [15:0] TX_BAUD_DIV = 16'd217;    // 25MHz/115200 baud

   // TR1402A configuration parameters - RX Side
   localparam [1:0] RX_CHAR_LENGTH = 2'b11;    // 8 bits
   localparam [1:0] RX_STOP_BITS = 2'b00;      // 1 stop bit
   localparam [1:0] RX_PARITY_MODE = 2'b00;    // No parity
   localparam [15:0] RX_BAUD_DIV = 16'd217;    // 25MHz/115200 baud
   
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

   // Command handler outputs (system clock domain)
   wire [ADDR_BITS-1:0] new_first_char;
   wire new_first_char_wen;
   wire [7:0] new_char;
   wire [ADDR_BITS-1:0] new_char_address;
   wire new_char_wen;
   wire [COL_BITS-1:0] new_cursor_x;
   wire [ROW_BITS-1:0] new_cursor_y;
   wire new_cursor_wen;

   // Video clock domain signals
   wire [ADDR_BITS-1:0] first_char;
   wire [COL_BITS-1:0] cursor_x;
   wire [ROW_BITS-1:0] cursor_y;
   wire cursor_blink_on;
   wire [ADDR_BITS-1:0] char_address;
   wire [7:0] char;
   wire [11:0] char_rom_address;
   wire [7:0] char_rom_data;

   // TR1402A UART status signals
   wire uart_overrun_error;
   wire uart_framing_error;
   wire uart_parity_error;
   wire uart_tx_bit_clock;
   wire uart_rx_bit_clock;

   // Clock domain crossing registers
   reg [7:0] char_data_sync1, char_data_sync2;
   reg char_wen_sync1, char_wen_sync2;
   reg [ADDR_BITS-1:0] char_addr_sync1, char_addr_sync2;
   reg [COL_BITS-1:0] cursor_x_sync1, cursor_x_sync2;
   reg [ROW_BITS-1:0] cursor_y_sync1, cursor_y_sync2;
   reg cursor_wen_sync1, cursor_wen_sync2;
   reg [ADDR_BITS-1:0] scroll_pos_sync1, scroll_pos_sync2;
   reg scroll_wen_sync1, scroll_wen_sync2;

   // Keyboard activity detector with proper reset
   always @(posedge clk) begin
      if (reset)
         kbd_active <= 0;
      else if (kbd_activity)  // PS/2 activity detected
         kbd_active <= 1;
      else if (ps2_clk_sync == 3'b111)  // PS/2 clock stable high, activity done
         kbd_active <= 0;
   end

   // LED control with synchronized PS/2 clock
   reg [2:0] ps2_clk_sync;
   always @(posedge clk) begin
      ps2_clk_sync <= {ps2_clk_sync[1:0], ps2_clk};
      
      if (reset)
         led <= 0;
      else
         led <= cursor_blink_on | uart_overrun_error | uart_framing_error | 
                uart_parity_error | kbd_active | kbd_ps2_error;
   end


   reg [7:0] kbd_to_uart_data;
   reg kbd_to_uart_valid;

   // Add this logic to handle keyboard to UART transmission
   always @(posedge clk) begin
      if (reset) begin
         kbd_to_uart_data <= 8'h0;
         kbd_to_uart_valid <= 1'b0;
      end
      else begin
         // Clear valid when UART accepts the data
         if (kbd_to_uart_valid && uart_tx_ready) begin
               kbd_to_uart_valid <= 1'b0;
         end
         // Capture new keyboard data when available
         else if (kbd_valid && kbd_ready) begin
               kbd_to_uart_data <= kbd_data;
               kbd_to_uart_valid <= 1'b1;
         end
      end
   end

   // Add these assignments to connect to UART TX interface
   assign uart_tx_data = kbd_to_uart_data;
   assign uart_tx_valid = kbd_to_uart_valid;

   // TR1402A UART Instance
   tr1402a_uart uart (
      .clk(clk),
      .rst_n(~reset),
      
      // TX Configuration
      .tx_char_length(TX_CHAR_LENGTH),
      .tx_stop_bits(TX_STOP_BITS),
      .tx_parity_mode(TX_PARITY_MODE),
      .tx_baud_div(TX_BAUD_DIV),

      // RX Configuration      
      .rx_char_length(RX_CHAR_LENGTH),
      .rx_stop_bits(RX_STOP_BITS),
      .rx_parity_mode(RX_PARITY_MODE),
      .rx_baud_div(RX_BAUD_DIV),
      
      // Status
      .overrun_error(uart_overrun_error),
      .framing_error(uart_framing_error),
      .parity_error(uart_parity_error),
      .tx_ready(uart_tx_ready),
      .rx_ready(uart_rx_valid),

      // Debug bit clocks
      .tx_bit_clock(uart_tx_bit_clock),
      .rx_bit_clock(uart_rx_bit_clock),
      
      // Data Interface
      .tx_data(uart_tx_data),
      .tx_load(uart_tx_valid && uart_tx_ready),
      .rx_data(uart_rx_data),
      .rx_read(uart_rx_valid && uart_rx_ready),
      
      // Serial Interface
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
      
      // Keyboard connection
      .kbd_data(kbd_data),
      .kbd_valid(kbd_valid),
      .kbd_ready(kbd_ready),
      
      // UART connection
      .uart_data(uart_rx_data),
      .uart_valid(uart_rx_valid),
      .uart_ready(uart_rx_ready),
      
      // Command handler connection
      .out_data(mux_out_data),
      .out_valid(mux_out_valid),
      .out_ready(mux_out_ready)
   );

   // Command handler
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
      .ready(mux_out_ready),
      .new_first_char(new_first_char),
      .new_first_char_wen(new_first_char_wen),
      .new_char(new_char),
      .new_char_address(new_char_address),
      .new_char_wen(new_char_wen),
      .new_cursor_x(new_cursor_x),
      .new_cursor_y(new_cursor_y),
      .new_cursor_wen(new_cursor_wen)
   );

   // Synchronize control signals from system to video clock
   always @(posedge clk) begin
      // Character buffer signals
      char_data_sync1 <= new_char;
      char_data_sync2 <= char_data_sync1;
      char_wen_sync1 <= new_char_wen;
      char_wen_sync2 <= char_wen_sync1;
      char_addr_sync1 <= new_char_address;
      char_addr_sync2 <= char_addr_sync1;

      // Cursor signals
      cursor_x_sync1 <= new_cursor_x;
      cursor_x_sync2 <= cursor_x_sync1;
      cursor_y_sync1 <= new_cursor_y;
      cursor_y_sync2 <= cursor_y_sync1;
      cursor_wen_sync1 <= new_cursor_wen;
      cursor_wen_sync2 <= cursor_wen_sync1;

      // Scroll signals
      scroll_pos_sync1 <= new_first_char;
      scroll_pos_sync2 <= scroll_pos_sync1;
      scroll_wen_sync1 <= new_first_char_wen;
      scroll_wen_sync2 <= scroll_wen_sync1;
   end

   // Video clock domain components
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
      .new_x(cursor_x_sync2),
      .new_y(cursor_y_sync2),
      .wen(cursor_wen_sync2)
   );

   simple_register #(
      .SIZE(ADDR_BITS)
   ) scroll_register(
      .clk(clk),
      .reset(reset),
      .idata(scroll_pos_sync2),
      .wen(scroll_wen_sync2),
      .odata(first_char)
   );

   char_buffer char_buffer(
      .clk(clk),
      .din(char_data_sync2),
      .waddr(char_addr_sync2),
      .wen(char_wen_sync2),
      .raddr(char_address),
      .dout(char)
   );

   char_rom char_rom(
      .clk(clk),
      .addr(char_rom_address),
      .dout(char_rom_data)
   );

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
      .hsync(hsync),
      .vsync(vsync),
      .video(video),
      .hblank(hblank),
      .vblank(vblank),
      .cursor_x(cursor_x),
      .cursor_y(cursor_y),
      .cursor_blink_on(cursor_blink_on),
      .first_char(first_char),
      .char_buffer_address(char_address),
      .char_buffer_data(char),
      .char_rom_address(char_rom_address),
      .char_rom_data(char_rom_data)
   );

endmodule