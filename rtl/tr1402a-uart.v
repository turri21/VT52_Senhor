module tr1402a_uart (
    input wire clk,           // System clock
    input wire rst_n,         // Active low reset

    // Configuration Interface
    input wire [1:0] char_length,     // 00=5bit, 01=6bit, 10=7bit, 11=8bit
    input wire [1:0] stop_bits,       // 00=1bit, 01=1.5bit, 10=2bit
    input wire [1:0] parity_mode,     // 00=none, 01=odd, 10=even
    input wire [15:0] baud_div,       // Clock divider for baud rate

    // Status Signals
    output reg overrun_error,         // Receive overrun
    output reg framing_error,         // Stop bit error
    output reg parity_error,          // Parity check failed
    output reg tx_ready,              // Transmitter ready for data
    output reg rx_ready,              // Receiver has data

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

    // Receiver registers
    reg [2:0] rx_state;
    reg [3:0] rx_bit_count;
    reg [15:0] rx_baud_count;
    reg [7:0] rx_shift_reg;
    reg rx_parity;
    reg [3:0] rx_sample_count;

    // Calculate character length
    wire [3:0] char_bits = {1'b0, char_length} + 4'd5;

    // Transmitter logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state <= IDLE;
            serial_out <= 1'b1;
            tx_ready <= 1'b1;
            tx_bit_count <= 0;
            tx_baud_count <= 0;
            tx_parity <= 0;
        end
        else begin
            case (tx_state)
                IDLE: begin
                    serial_out <= 1'b1;
                    if (tx_load && tx_ready) begin
                        tx_shift_reg <= tx_data;
                        tx_ready <= 1'b0;
                        tx_state <= START;
                        tx_parity <= (parity_mode[1]) ? 1'b0 : 1'b1; // Even=0, Odd=1
                    end
                end

                START: begin
                    serial_out <= 1'b0; // Start bit
                    if (tx_baud_count == baud_div) begin
                        tx_baud_count <= 0;
                        tx_state <= DATA;
                        tx_bit_count <= 0;
                    end
                    else tx_baud_count <= tx_baud_count + 1;
                end

                DATA: begin
                    serial_out <= tx_shift_reg[0];
                    if (tx_baud_count == baud_div) begin
                        tx_baud_count <= 0;
                        tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};
                        tx_parity <= tx_parity ^ tx_shift_reg[0];
                        
                        if (tx_bit_count == char_bits - 1) begin
                            tx_state <= (parity_mode != 0) ? PARITY : STOP;
                        end
                        else tx_bit_count <= tx_bit_count + 1;
                    end
                    else tx_baud_count <= tx_baud_count + 1;
                end

                PARITY: begin
                    serial_out <= tx_parity;
                    if (tx_baud_count == baud_div) begin
                        tx_baud_count <= 0;
                        tx_state <= STOP;
                    end
                    else tx_baud_count <= tx_baud_count + 1;
                end

                STOP: begin
                    serial_out <= 1'b1; // Stop bit(s)
                    if (tx_baud_count == baud_div * 
                        ((stop_bits == 2'b01) ? 3/2 : // 1.5 stop bits
                         (stop_bits == 2'b10) ? 2 :   // 2 stop bits
                         1)) begin                    // 1 stop bit
                        tx_baud_count <= 0;
                        tx_state <= IDLE;
                        tx_ready <= 1'b1;
                    end
                    else tx_baud_count <= tx_baud_count + 1;
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
            rx_sample_count <= 0;
            rx_parity <= 0;
        end
        else begin
            // Clear error flags when data is read
            if (rx_read) begin
                rx_ready <= 1'b0;
                overrun_error <= 1'b0;
                framing_error <= 1'b0;
                parity_error <= 1'b0;
            end

            case (rx_state)
                IDLE: begin
                    if (!serial_in) begin // Start bit detected
                        rx_state <= START;
                        rx_baud_count <= 0;
                        rx_sample_count <= 0;
                        rx_parity <= (parity_mode[1]) ? 1'b0 : 1'b1; // Even=0, Odd=1
                    end
                end

                START: begin
                    // Sample middle of start bit
                    if (rx_baud_count == baud_div/2) begin
                        if (!serial_in) begin // Valid start bit
                            rx_state <= DATA;
                            rx_bit_count <= 0;
                            rx_baud_count <= 0;
                        end
                        else rx_state <= IDLE; // False start bit
                    end
                    else rx_baud_count <= rx_baud_count + 1;
                end

                DATA: begin
                    if (rx_baud_count == baud_div) begin
                        rx_baud_count <= 0;
                        rx_shift_reg <= {serial_in, rx_shift_reg[7:1]};
                        rx_parity <= rx_parity ^ serial_in;
                        
                        if (rx_bit_count == char_bits - 1) begin
                            rx_state <= (parity_mode != 0) ? PARITY : STOP;
                        end
                        else rx_bit_count <= rx_bit_count + 1;
                    end
                    else rx_baud_count <= rx_baud_count + 1;
                end

                PARITY: begin
                    if (rx_baud_count == baud_div) begin
                        rx_baud_count <= 0;
                        rx_state <= STOP;
                        if (serial_in != rx_parity) begin
                            parity_error <= 1'b1;
                        end
                    end
                    else rx_baud_count <= rx_baud_count + 1;
                end

                STOP: begin
                    if (rx_baud_count == baud_div) begin
                        rx_baud_count <= 0;
                        
                        if (!serial_in) begin // Stop bit error
                            framing_error <= 1'b1;
                        end
                        else begin
                            if (rx_ready) begin // Previous data not read
                                overrun_error <= 1'b1;
                            end
                            else begin
                                rx_data <= rx_shift_reg;
                                rx_ready <= 1'b1;
                            end
                        end
                        rx_state <= IDLE;
                    end
                    else rx_baud_count <= rx_baud_count + 1;
                end
            endcase
        end
    end

endmodule
