module top_module (
    input wire clk,
    input wire reset,
    output wire hsync,
    output wire vsync,
    output wire video
);

    // Parameters
    localparam ROWS = 24;
    localparam COLS = 80;
    localparam BUF_SIZE = ROWS * COLS;
    localparam ADDR_BITS = 11;

    // Signals for char_buffer
    wire [7:0] char_buffer_din;
    wire [ADDR_BITS-1:0] char_buffer_waddr;
    wire char_buffer_wen;
    wire [ADDR_BITS-1:0] char_buffer_raddr;
    wire [7:0] char_buffer_dout;

    // Signals for char_rom
    wire [11:0] char_rom_addr;
    wire [7:0] char_rom_dout;

    // Signals for video_generator
    wire [6:0] cursor_x;
    wire [4:0] cursor_y;
    wire cursor_blink_on;
    wire [ADDR_BITS-1:0] first_char;
    wire hblank, vblank;

    // Instantiate char_buffer
    char_buffer #(
        .BUF_SIZE(BUF_SIZE),
        .ADDR_BITS(ADDR_BITS)
    ) char_buffer_inst (
        .clk(clk),
        .din(char_buffer_din),
        .waddr(char_buffer_waddr),
        .wen(char_buffer_wen),
        .raddr(char_buffer_raddr),
        .dout(char_buffer_dout)
    );

    // Instantiate char_rom
    char_rom char_rom_inst (
        .clk(clk),
        .addr(char_rom_addr),
        .dout(char_rom_dout)
    );

    // Instantiate video_generator
    video_generator #(
        .ROWS(ROWS),
        .COLS(COLS),
        .ROW_BITS(5),
        .COL_BITS(7),
        .ADDR_BITS(ADDR_BITS)
    ) video_generator_inst (
        .clk(clk),
        .reset(reset),
        .hsync(hsync),
        .vsync(vsync),
        .video(video),
        .hblank(hblank),
        .vblank(vblank),
        .cursor_x(cursor_x),
        .cursor_y(cursor_y),
        .cursor_blink_on(cursor_blink_on),
        .first_char(first_char),
        .char_buffer_address(char_buffer_raddr),
        .char_buffer_data(char_buffer_dout),
        .char_rom_address(char_rom_addr),
        .char_rom_data(char_rom_dout)
    );

    // Buffer initialization logic
    reg [2:0] char_counter;
    reg [ADDR_BITS-1:0] init_addr;
    reg init_done;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            char_counter <= 0;
            init_addr <= 0;
            init_done <= 0;
        end else if (!init_done) begin
            if (init_addr == BUF_SIZE - 1) begin
                init_done <= 1;
            end else begin
                init_addr <= init_addr + 1;
                char_counter <= (char_counter == 6) ? 0 : char_counter + 1;
            end
        end
    end

    assign char_buffer_din = "A" + char_counter;
    assign char_buffer_waddr = init_addr;
    assign char_buffer_wen = !init_done;

    // Set other signals
    assign cursor_x = 0;
    assign cursor_y = 0;
    assign cursor_blink_on = 0;
    assign first_char = 0;

endmodule