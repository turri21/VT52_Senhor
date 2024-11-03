/**
 * Cursor (position and blinking)

The `cursor` module is a Verilog design that manages a cursor's position and blinking 
state. It uses a few submodules to handle cursor blinking and position updates. 
Here's a detailed breakdown of its components and functionality:

### Parameters:
- **`ROW_BITS`**: Number of bits used to represent the row coordinate of the cursor.
- **`COL_BITS`**: Number of bits used to represent the column coordinate of the cursor.

### Inputs and Outputs:
- **Inputs**:
  - **`clk`**: The clock signal driving the module.
  - **`reset`**: A reset signal to initialize the module.
  - **`tick`**: A periodic signal used to drive the cursor blinking.
  - **`new_x`**: New column coordinate value for the cursor.
  - **`new_y`**: New row coordinate value for the cursor.
  - **`wen`**: Write enable signal used to update the cursor position.

- **Outputs**:
  - **`x`**: Current column coordinate of the cursor.
  - **`y`**: Current row coordinate of the cursor.
  - **`blink_on`**: Signal indicating whether the cursor should be blinking.

### Submodules:
1. **`cursor_blinker`**:
   - This submodule handles the blinking behavior of the cursor. It uses the `cursor_blinker` module described earlier.
   - **Inputs**:
     - **`clk`**: Clock signal.
     - **`reset`**: Reset signal.
     - **`tick`**: Tick signal for controlling the blink rate.
     - **`reset_count`**: When high, resets the blinking counter.
   - **Output**:
     - **`blink_on`**: Blinking state signal.

2. **`simple_register` for `x`**:
   - This submodule stores the cursor's column position.
   - **Parameters**:
     - **`SIZE`**: The bit-width for the register, set to `COL_BITS`.
   - **Inputs**:
     - **`clk`**: Clock signal.
     - **`reset`**: Reset signal.
     - **`idata`**: Data input, which is the new column value (`new_x`).
     - **`wen`**: Write enable signal to update the register.
   - **Output**:
     - **`odata`**: Output data, which is the current column value (`x`).

3. **`simple_register` for `y`**:
   - This submodule stores the cursor's row position.
   - **Parameters**:
     - **`SIZE`**: The bit-width for the register, set to `ROW_BITS`.
   - **Inputs**:
     - **`clk`**: Clock signal.
     - **`reset`**: Reset signal.
     - **`idata`**: Data input, which is the new row value (`new_y`).
     - **`wen`**: Write enable signal to update the register.
   - **Output**:
     - **`odata`**: Output data, which is the current row value (`y`).

### Functionality:
- **Blinking**: The `cursor_blinker` submodule controls whether the cursor should be visible 
or blinking based on the tick signal and the internal counter.
- **Position Update**: The `simple_register` instances for `x` and `y` manage the cursor's 
position. The cursor's column and row coordinates can be updated with the `new_x` and `new_y` 
inputs when `wen` (write enable) is active.
- **Output**: The current cursor position is available on `x` and `y`, and the blinking state 
is indicated by `blink_on`.

### Summary:
The `cursor` module integrates cursor position management and blinking behavior into a 
single entity. It uses registers to hold the cursor's position and a blinking controller 
to toggle the cursor's visibility. The module allows the cursor to be updated and blink 
at a rate controlled by external signals.

 */
module cursor
  #(parameter ROW_BITS = 5,
    parameter COL_BITS = 7)
   (input clk,
    input reset,
    input tick,
    output wire [COL_BITS-1:0] x,
    output wire [ROW_BITS-1:0] y,
    output wire blink_on,
    input [COL_BITS-1:0] new_x,
    input [ROW_BITS-1:0] new_y,
    input wen
    );

   cursor_blinker cursor_blinker(.clk(clk),
                                 .reset(reset),
                                 .tick(tick),
                                 .reset_count(wen),
                                 .blink_on(blink_on)
                                 );

   simple_register #(.SIZE(COL_BITS))
      cursor_x_reg(.clk(clk),
                   .reset(reset),
                   .idata(new_x),
                   .wen(wen),
                   .odata(x)
                   );

   simple_register #(.SIZE(ROW_BITS))
      cursor_y_reg(.clk(clk),
                   .reset(reset),
                   .idata(new_y),
                   .wen(wen),
                   .odata(y)
                   );
endmodule
