module VT52_terminal 
(
   input             clk_sys,     // 50MHz system clock for peripherals
   input             clk_vid,     // 25MHz video clock
   input             reset,       // Active high reset
   input             ce_pix,      // Pixel clock enable
   
   output wire       hsync,
   output wire       vsync,
   output wire       hblank,
   output wire       vblank,
   output wire       video,
   output wire       led,
   
   input             ps2_data,
   input             ps2_clk,
   
   inout             pin_usb_p,
   inout             pin_usb_n,
   output wire       pin_pu
);

   localparam ROWS = 24;
   localparam COLS = 80;
   localparam ROW_BITS = 5;
   localparam COL_BITS = 7;
   localparam ADDR_BITS = 11;

   // USB host detect
   assign pin_pu = 1'b1;

   // UART divider for 115200 baud at 50MHz
   wire [31:0] cfg_divider = 32'd434;  // 50MHz/115200 rounded

   // LED follows the cursor blink
   assign led = cursor_blink_on;

   // System clock domain signals
   wire [7:0] uart_out_data;
   wire uart_out_valid;
   wire uart_out_ready;
   wire [7:0] uart_in_data;
   wire uart_in_valid;
   wire uart_in_ready;
   wire reg_dat_we;
   wire reg_dat_re;
   wire [7:0] reg_dat_di;
   wire [7:0] reg_dat_do;
   wire reg_dat_wait;
   wire recv_buf_valid;
   wire tdre;

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

   // Clock domain crossing registers
   reg [7:0] char_data_sync1, char_data_sync2;
   reg char_wen_sync1, char_wen_sync2;
   reg [ADDR_BITS-1:0] char_addr_sync1, char_addr_sync2;
   reg [COL_BITS-1:0] cursor_x_sync1, cursor_x_sync2;
   reg [ROW_BITS-1:0] cursor_y_sync1, cursor_y_sync2;
   reg cursor_wen_sync1, cursor_wen_sync2;
   reg [ADDR_BITS-1:0] scroll_pos_sync1, scroll_pos_sync2;
   reg scroll_wen_sync1, scroll_wen_sync2;

   // Synchronize control signals from system to video clock
   always @(posedge clk_vid) begin
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

   // System clock domain components
   keyboard keyboard(
      .clk(clk_sys),
      .reset(reset),
      .ps2_data(ps2_data),
      .ps2_clk(ps2_clk),
      .data(uart_in_data),
      .valid(uart_in_valid),
      .ready(uart_in_ready)
   );

   simpleuart uart(
      .clk(clk_sys),
      .resetn(~reset),
      .ser_tx(pin_usb_p),
      .ser_rx(pin_usb_n),
      .cfg_divider(cfg_divider),
      .reg_dat_we(reg_dat_we),
      .reg_dat_re(reg_dat_re),
      .reg_dat_di(reg_dat_di),
      .reg_dat_do(reg_dat_do),
      .reg_dat_wait(reg_dat_wait),
      .recv_buf_valid(recv_buf_valid),
      .tdre(tdre)
   );

   command_handler #(
      .ROWS(ROWS),
      .COLS(COLS),
      .ROW_BITS(ROW_BITS),
      .COL_BITS(COL_BITS),
      .ADDR_BITS(ADDR_BITS)
   ) command_handler(
      .clk(clk_sys),
      .reset(reset),
      .data(reg_dat_do),
      .valid(recv_buf_valid),
      .ready(reg_dat_re),
      .new_first_char(new_first_char),
      .new_first_char_wen(new_first_char_wen),
      .new_char(new_char),
      .new_char_address(new_char_address),
      .new_char_wen(new_char_wen),
      .new_cursor_x(new_cursor_x),
      .new_cursor_y(new_cursor_y),
      .new_cursor_wen(new_cursor_wen)
   );

   // Video clock domain components
   cursor #(
      .ROW_BITS(ROW_BITS),
      .COL_BITS(COL_BITS)
   ) cursor(
      .clk(clk_vid),
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
      .clk(clk_vid),
      .reset(reset),
      .idata(scroll_pos_sync2),
      .wen(scroll_wen_sync2),
      .odata(first_char)
   );

   char_buffer char_buffer(
      .clk(clk_vid),
      .din(char_data_sync2),
      .waddr(char_addr_sync2),
      .wen(char_wen_sync2),
      .raddr(char_address),
      .dout(char)
   );

   char_rom char_rom(
      .clk(clk_vid),
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
      .clk(clk_vid),
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

   // UART data path connections
   assign reg_dat_we = uart_in_valid & uart_in_ready;
   assign reg_dat_di = uart_in_data;
   assign uart_in_ready = ~reg_dat_wait & tdre;

endmodule