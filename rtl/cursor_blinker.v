/**
 * Cursor blinker (uses vblank as tick, blinks about once a second)
 
 The `cursor_blinker` module is a Verilog design that generates a blinking signal based on a 
 counter and a tick signal. It is likely used to control the blinking of a cursor or 
 indicator in a display system.

### Breakdown:

1. **Inputs and Outputs**:
   - **`clk` (input)**: The clock signal that drives the module.
   - **`reset` (input)**: A reset signal that initializes the counter and state.
   - **`tick` (input)**: A periodic signal used to increment the counter.
   - **`reset_count` (input)**: A signal to reset the counter while keeping track of whether it has been incremented.
   - **`blink_on` (output)**: An output signal that indicates whether the cursor should be visible or blinking.

2. **Parameters and Registers**:
   - **`BITS` (localparam)**: Defines the width of the counter. In this case, it's set to 6 bits, allowing the counter to count from 0 to 63.
   - **`has_incremented` (reg)**: A register used to track whether the counter has been incremented in the current clock cycle.
   - **`counter` (reg [BITS-1:0])**: A 6-bit register used to count ticks and control the blink rate.

3. **`always @(posedge clk)` Block**:
   - This block executes on the rising edge of the clock signal (`clk`).
   - **Reset Condition**:
     - If `reset` is high, the counter is reset to 0, and `has_incremented` is cleared.
   - **Reset Count Condition**:
     - If `reset_count` is high, the counter is reset to 0, and `has_incremented` is set based on the 
     `tick` signal. This effectively resets the counter and prepares for a new counting cycle.
   - **Tick Handling**:
     - If `tick` is high and `has_incremented` is low, the counter is incremented by 1, and 
     `has_incremented` is set to 1. This ensures the counter only increments once per tick.
     - If `tick` is low and `has_incremented` is high, `has_incremented` is reset to 0. This 
     prepares the module for the next tick.

4. **Blink Output**:
   - **`blink_on`**: The output signal is determined by the most significant bit of the counter 
   (`~counter[BITS-1]`). This means `blink_on` will toggle every 2^(BITS-1) ticks. For a 6-bit 
   counter, this will toggle every 32 ticks.

### Purpose:
The `cursor_blinker` module generates a blinking signal for a cursor or similar indicator. The 
blinking rate is controlled by the tick input and the counter. When the counter reaches a certain 
value, the `blink_on` output toggles, creating a blink effect.

- **Reset and Initialization**: On reset, the counter is cleared, and `has_incremented` is set to 0.
- **Counting and Blinking**: The counter increments on each tick and toggles the `blink_on` signal 
based on the most significant bit of the counter. The blinking frequency is determined by the 
counter's bit width (`BITS`).

This module can be used in display systems where a cursor or an indicator needs to blink at a 
specific rate, based on the provided tick signal and other control inputs.
 
 */
module cursor_blinker
  (input clk,
   input reset,
   input tick,
   input reset_count,
   output wire blink_on
   );
   localparam BITS = 6;
   reg has_incremented;
   reg [BITS-1:0] counter;
   always @(posedge clk) begin
      if (reset) begin
         counter <= 0;
         has_incremented <= 0;
      end
      else if (reset_count) begin
         counter <= 0;
         has_incremented <= tick;
      end
      else if (tick && !has_incremented) begin
         counter <= counter + 1;
         has_incremented <= 1;
      end
      else if (!tick && has_incremented) begin
         has_incremented <= 0;
      end
   end
   assign blink_on = ~counter[BITS-1];
endmodule
