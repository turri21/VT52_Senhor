module input_multiplexer (
    input                clk,
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

    // Simple priority mux - keyboard takes priority over UART
    always @(posedge clk) begin
        if (reset) begin
            out_data <= 8'h0;
            out_valid <= 1'b0;
        end
        else if (!out_valid) begin
            // If we're not currently sending data, accept new input
            if (kbd_valid) begin
                out_data <= kbd_data;
                out_valid <= 1'b1;
            end
            else if (uart_valid) begin
                out_data <= uart_data;
                out_valid <= 1'b1;
            end
        end
        else if (out_valid && out_ready) begin
            // Clear valid once data is accepted
            out_valid <= 1'b0;
        end
    end

    // Generate ready signals
    // A source is ready for new data if:
    // 1. We're not currently sending data (out_valid is low) OR
    // 2. Current data will be accepted this cycle (out_valid && out_ready)
    assign kbd_ready = !out_valid || (out_valid && out_ready);
    assign uart_ready = !kbd_valid && (!out_valid || (out_valid && out_ready));

endmodule
