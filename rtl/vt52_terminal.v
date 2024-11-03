module VT52_terminal 
(
   input       clk,
   output wire hsync,
   output wire vsync,
   output wire hblank,
   output wire vblank,
   output wire video,
   output wire led,
   input       ps2_data,
   input       ps2_clk,
   inout       pin_usb_p,
   inout       pin_usb_n,
   output wire pin_pu
);

   localparam ROWS = 24;
   localparam COLS = 80;
   localparam ROW_BITS = 5;
   localparam COL_BITS = 7;
   localparam ADDR_BITS = 11;

   // clock generator outputs
   wire clk_usb, reset_usb;
   wire clk_vga, reset_vga;

   // scroll
   wire [ADDR_BITS-1:0] new_first_char;
   wire new_first_char_wen;
   wire [ADDR_BITS-1:0] first_char;
   // cursor
   wire [ROW_BITS-1:0]  new_cursor_y;
   wire [COL_BITS-1:0]  new_cursor_x;
   wire new_cursor_wen;
   wire cursor_blink_on;
   wire [ROW_BITS-1:0] cursor_y;
   wire [COL_BITS-1:0] cursor_x;
   // char buffer
   wire [7:0] new_char;
   wire [ADDR_BITS-1:0] new_char_address;
   wire new_char_wen;
   wire [ADDR_BITS-1:0] char_address;
   wire [7:0] char;
   // char rom
   wire [11:0] char_rom_address;
   wire [7:0] char_rom_data;

   // video generator
//   wire vblank, hblank;

   // uart input/output
   wire [7:0] uart_out_data;
   wire uart_out_valid;
   wire uart_out_ready;

   wire [7:0] uart_in_data;
   wire uart_in_valid;
   wire uart_in_ready;

   // simpleuart specific signals
   wire [31:0] cfg_divider;
   wire reg_dat_we;
   wire reg_dat_re;
   wire [7:0] reg_dat_di;
   wire [7:0] reg_dat_do;
   wire reg_dat_wait;
   wire recv_buf_valid;
   wire tdre;

   // LED follows the cursor blink
   assign led = cursor_blink_on;

   // USB host detect
   assign pin_pu = 1'b1;

   // Clock divider configuration (you may need to adjust this value)
   assign cfg_divider = 32'd868; // Example value, adjust as needed

   //
   // Instantiate all modules
   //
   clock_generator clock_generator(.clk(clk),
                                   .clk_usb(clk_usb),
                                   .reset_usb(reset_usb),
                                   .clk_vga(clk_vga),
                                   .reset_vga(reset_vga)
                                   );

   keyboard keyboard(.clk(clk),
                     .reset(reset_usb),
                     .ps2_data(ps2_data),
                     .ps2_clk(ps2_clk),
                     .data(uart_in_data),
                     .valid(uart_in_valid),
                     .ready(uart_in_ready)
                     );

   cursor #(.ROW_BITS(ROW_BITS), .COL_BITS(COL_BITS))
      cursor(.clk(clk_usb),
             .reset(reset_usb),
             .tick(vblank),
             .x(cursor_x),
             .y(cursor_y),
             .blink_on(cursor_blink_on),
             .new_x(new_cursor_x),
             .new_y(new_cursor_y),
             .wen(new_cursor_wen)
            );

   simple_register #(.SIZE(ADDR_BITS))
      scroll_register(.clk(clk_usb),
                      .reset(reset_usb),
                      .idata(new_first_char),
                      .wen(new_first_char_wen),
                      .odata(first_char)
                      );

   char_buffer char_buffer(.clk(clk_usb),
                           .din(new_char),
                           .waddr(new_char_address),
                           .wen(new_char_wen),
                           .raddr(char_address),
                           .dout(char)
                           );

   char_rom char_rom(.clk(clk_usb),
                     .addr(char_rom_address),
                     .dout(char_rom_data)
                     );

   video_generator #(.ROWS(ROWS),
                     .COLS(COLS),
                     .ROW_BITS(ROW_BITS),
                     .COL_BITS(COL_BITS),
                     .ADDR_BITS(ADDR_BITS))
      video_generator(.clk(clk_vga),
                      .reset(reset_vga),
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

   simpleuart uart(.clk(clk_usb),
                   .resetn(~reset_usb),  // Note: simpleuart uses active-low reset
                   .ser_tx(pin_usb_p),   // Assuming pin_usb_p is for TX
                   .ser_rx(pin_usb_n),   // Assuming pin_usb_n is for RX
                   .cfg_divider(cfg_divider),
                   .reg_dat_we(reg_dat_we),
                   .reg_dat_re(reg_dat_re),
                   .reg_dat_di(reg_dat_di),
                   .reg_dat_do(reg_dat_do),
                   .reg_dat_wait(reg_dat_wait),
                   .recv_buf_valid(recv_buf_valid),
                   .tdre(tdre)
                   );

   command_handler #(.ROWS(ROWS),
                     .COLS(COLS),
                     .ROW_BITS(ROW_BITS),
                     .COL_BITS(COL_BITS),
                     .ADDR_BITS(ADDR_BITS))
      command_handler(.clk(clk_usb),
                      .reset(reset_usb),
                      .data(reg_dat_do),             // Use reg_dat_do from simpleuart
                      .valid(recv_buf_valid),        // Use recv_buf_valid from simpleuart
                      .ready(reg_dat_re),            // Connect to reg_dat_re of simpleuart
                      .new_first_char(new_first_char),
                      .new_first_char_wen(new_first_char_wen),
                      .new_char(new_char),
                      .new_char_address(new_char_address),
                      .new_char_wen(new_char_wen),
                      .new_cursor_x(new_cursor_x),
                      .new_cursor_y(new_cursor_y),
                      .new_cursor_wen(new_cursor_wen)
                      );

   // Additional logic to handle UART data transmission
   assign reg_dat_we = uart_in_valid & uart_in_ready;
   assign reg_dat_di = uart_in_data;
   assign uart_in_ready = ~reg_dat_wait & tdre;

endmodule