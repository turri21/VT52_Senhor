module baud_rate_divider (
    input [15:0] baud_rate,   // Input: desired baud rate (e.g., 9600)
    output reg [31:0] cfg_divider  // Output: corresponding cfg_divider value
);

    // Define constants for 50 MHz clock
    localparam CLOCK_FREQ = 50_000_000;
    localparam BAUD_RATE_DIVISOR = 16;

    always @(*) begin
        case (baud_rate)
            300:    cfg_divider = (CLOCK_FREQ / (BAUD_RATE_DIVISOR * 300)) - 1;
            600:    cfg_divider = (CLOCK_FREQ / (BAUD_RATE_DIVISOR * 600)) - 1;
            1200:   cfg_divider = (CLOCK_FREQ / (BAUD_RATE_DIVISOR * 1200)) - 1;
            2400:   cfg_divider = (CLOCK_FREQ / (BAUD_RATE_DIVISOR * 2400)) - 1;
            4800:   cfg_divider = (CLOCK_FREQ / (BAUD_RATE_DIVISOR * 4800)) - 1;
            9600:   cfg_divider = (CLOCK_FREQ / (BAUD_RATE_DIVISOR * 9600)) - 1;
            19200:  cfg_divider = (CLOCK_FREQ / (BAUD_RATE_DIVISOR * 19200)) - 1;
            38400:  cfg_divider = (CLOCK_FREQ / (BAUD_RATE_DIVISOR * 38400)) - 1;
            57600:  cfg_divider = (CLOCK_FREQ / (BAUD_RATE_DIVISOR * 57600)) - 1;
            115200: cfg_divider = (CLOCK_FREQ / (BAUD_RATE_DIVISOR * 115200)) - 1;
            230400: cfg_divider = (CLOCK_FREQ / (BAUD_RATE_DIVISOR * 230400)) - 1;
            460800: cfg_divider = (CLOCK_FREQ / (BAUD_RATE_DIVISOR * 460800)) - 1;
            921600: cfg_divider = (CLOCK_FREQ / (BAUD_RATE_DIVISOR * 921600)) - 1;
            default: cfg_divider = 32'hFFFF_FFFF;  // Default to an invalid value
        endcase
    end

endmodule
