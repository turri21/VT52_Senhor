module input_multiplexer 
(
    input                clk,          // Single 50MHz clock
    input                reset,
    
    // Keyboard input interface
    input         [7:0]  kbd_data,
    input                kbd_valid,
    output               kbd_ready,
    
    // UART input interface
    input         [7:0]  uart_data,
    input                uart_valid,
    output               uart_ready,
    
    // Output interface to command handler
    output reg    [7:0]  out_data,
    output reg           out_valid,
    input                out_ready
);

    // Simplified ready logic
    assign kbd_ready = !out_valid;  // Ready to accept new data only when not holding data
    assign uart_ready = !kbd_valid && !out_valid;  // Ready when no keyboard data and not holding data

    // Multiplexer logic
    always @(posedge clk) begin
        if (reset) begin
            out_data <= 8'h0;
            out_valid <= 1'b0;
        end
        else begin
            // Clear valid when data is accepted
            if (out_valid && out_ready) begin
                out_valid <= 1'b0;
            end
            // Accept new data when not valid
            else if (!out_valid) begin
                if (kbd_valid) begin
                    out_data <= kbd_data;
                    out_valid <= 1'b1;
                end
                else if (uart_valid) begin
                    out_data <= uart_data;
                    out_valid <= 1'b1;
                end
            end
        end
    end

endmodule