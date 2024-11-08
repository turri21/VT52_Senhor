/*

The `keyboard` module processes input from a PS/2 keyboard and outputs the corresponding ASCII 
data and validity signal. It handles keypresses, key releases, and special key events, including 
modifiers and escape sequences. Here’s a detailed breakdown:

### Parameters:
- **`ROW_BITS`**: Number of bits used for the row coordinate (not directly used in this module but potentially for a larger design context).
- **`COL_BITS`**: Number of bits used for the column coordinate (similarly, might be used in a broader context).

### Inputs and Outputs:
- **Inputs**:
  - **`clk`**: The clock signal driving the module.
  - **`reset`**: Resets the module and clears internal states.
  - **`ps2_data`**: The data line from the PS/2 keyboard.
  - **`ps2_clk`**: The clock line from the PS/2 keyboard.
  - **`ready`**: A signal indicating if the output data can be processed.

- **Outputs**:
  - **`data`**: The ASCII value of the key pressed or a special character.
  - **`valid`**: Indicates if the `data` output is valid and ready to be read.

### Internal Signals and Registers:
- **`state`**: Holds the current state of the module using one-hot encoding.
  - **`state_idle`**: The default state, reading from the PS/2 bus.
  - **`state_keymap`**: Reads the keymap ROM to determine the ASCII value.
  - **`state_key_down`**: Handles key down events.
  - **`state_key_up`**: Handles key up events.
  - **`state_esc_char`**: Sends characters prefixed with ESC if meta (Alt) key is pressed.

- **`ps2_old_clks`**: Stores the previous state of the `ps2_clk` signal to detect rising edges.
- **`ps2_raw_data`**: Holds the raw data received from the PS/2 data line.
- **`ps2_count`**: Counts the number of bits received.
- **`ps2_byte`**: The processed byte value from the PS/2 data.
- **`ps2_break_keycode`**: Flag indicating if the current keycode is a break code (key release).
- **`ps2_long_keycode`**: Flag indicating if the keycode is a long keycode.
- **`modifier_pressed`**: Tracks the status of modifier keys (Shift, Control, Meta).
- **`caps_lock_active`**: Indicates if Caps Lock is active.
- **`special_data`**: Holds special data to be sent after ESC when meta is pressed.

### Key Components:
1. **Keymap ROM**:
   - **`keymap_rom`**: A ROM module that maps the keycode to ASCII or special codes based on the `keymap_address`.

2. **State Machine**:
   - **`state_idle`**: Monitors the PS/2 clock to detect and read keycodes. It processes the keycode after receiving 11 bits (start bit, 8 data bits, parity, and stop bits).
   - **`state_keymap`**: After receiving a keycode, this state looks up the keymap ROM to determine the actual character or action.
   - **`state_key_up`**: Handles key release events and updates the modifier key statuses.
   - **`state_key_down`**: Processes key press events, applies modifiers, and handles special cases like ESC and meta keys.
   - **`state_esc_char`**: Sends special characters after an ESC sequence if meta is pressed.

### Functionality:
- **Reading Keycodes**: The module reads keycodes from the PS/2 interface using a state machine that detects key press and release events.
- **Handling Modifiers**: It tracks modifier keys (Shift, Control, Meta) and adjusts the output accordingly.
- **Key Mapping**: Uses a keymap ROM to convert keycodes into ASCII values, taking into account modifiers and special key states.
- **Special Handling**: Handles ESC sequences and special characters when the meta key is pressed.

### Summary:
The `keyboard` module integrates the PS/2 keyboard interface with a state machine to process 
keycodes, handle key presses and releases, manage modifier keys, and generate ASCII output. 
It includes a keymap ROM to map keycodes to characters and handles special cases like ESC 
sequences when modifier keys are active. This design allows for efficient keyboard input 
processing in digital systems.

*/


module keyboard
(
   input         clk,          // 50MHz system clock
   input         reset,
   input         ps2_data,
   input         ps2_clk,
   output  [7:0] data,
   output reg    valid,
   input         ready,
   output [15:0] valid_extend,
   output        ps2_activity,
   output reg    ps2_error,    // Error signal output

   // Debug outputs
   output reg [10:0] debug_raw_data,     // Raw PS/2 data
   output reg [3:0]  debug_bit_count,    // Bit counter
   output reg [4:0]  debug_state,        // Current state
   output reg        debug_parity_calc,   // Calculated parity
   output reg        debug_parity_received, // Received parity bit
   output reg [2:0]  debug_frame_errors,  // Frame errors (start,stop,parity)
   output reg [7:0]  debug_byte,         // Processed PS/2 byte
   output reg        debug_break_code,    // Break code detected
   output reg        debug_valid,         // Valid signal copy
   output reg [7:0]  debug_keymap_data,  // Keymap ROM output
   output reg [4:0]  debug_next_state,   // Next state for debugging
   output reg [1:0]  debug_keycode_type, // Type of keycode being processed
   output reg        debug_meta_pressed,  // Meta key status
   output reg        debug_control_pressed, // Control key status
   output wire       debug_in_regular_path, // Shows when we're in regular keycode path
   output wire [7:0] debug_data_reg      // Shows what we're setting to data_reg
);

   // State machine encoding (one-hot)
   localparam STATE_IDLE        = 5'b00001;
   localparam STATE_KEYMAP      = 5'b00010;
   localparam STATE_KEY_DOWN    = 5'b00100;
   localparam STATE_KEY_UP      = 5'b01000;
   localparam STATE_ESC_CHAR    = 5'b10000;

   // PS/2 protocol constants
   localparam PS2_BITS         = 11;    // 11 bits total
   localparam ESC              = 8'h1b;

   // Keycode type indicators
   localparam KEYCODE_MODIFIER = 2'b10;
   localparam KEYCODE_ESCAPED  = 2'b11;

   // PS/2 input synchronization & edge detection
   reg [2:0]  ps2_clk_sync;
   reg [2:0]  ps2_data_sync;
   wire       ps2_clk_falling;
   
   // PS/2 protocol handling
   reg [10:0] ps2_raw_data;    // Raw PS/2 data shift register
   reg [3:0]  ps2_count;       // Bit counter
   reg [7:0]  ps2_byte;        // Current byte being processed
   reg        ps2_break_keycode;  // Break code flag
   reg        ps2_long_keycode;   // Extended keycode flag
   
   // Main state machine registers
   reg [4:0]  state;
   reg [7:0]  data_reg;
   reg [5:0]  modifier_pressed;  // lshift, lcontrol, lmeta, rmeta, rcontrol, rshift
   reg        caps_lock_active;
   reg [7:0]  special_data;
   reg [15:0] valid_extend_reg;

   // Debug tracking registers
   reg        in_regular_path;
   reg [7:0]  last_data_reg;

   // Modifier key status
   wire       shift_pressed   = modifier_pressed[5] || modifier_pressed[0];
   wire       control_pressed = modifier_pressed[4] || modifier_pressed[1];
   wire       meta_pressed    = modifier_pressed[3] || modifier_pressed[2];

   // Function to calculate parity
   function calc_parity;
      input [7:0] data;
      begin
         calc_parity = ~^data;    // Odd parity: XOR all bits and invert
      end
   endfunction

   // Synchronize inputs
   always @(posedge clk) begin
      ps2_clk_sync  <= {ps2_clk_sync[1:0], ps2_clk};
      ps2_data_sync <= {ps2_data_sync[1:0], ps2_data};
   end

   assign ps2_clk_falling = ps2_clk_sync[2] && !ps2_clk_sync[1];

   // Debug signal updates
   always @(posedge clk) begin
      if (reset) begin
         debug_state <= STATE_IDLE;
         debug_keycode_type <= 2'b00;
         debug_meta_pressed <= 0;
         debug_control_pressed <= 0;
      end
      else begin
         debug_state <= state;
         debug_raw_data <= ps2_raw_data;
         debug_bit_count <= ps2_count;
         debug_byte <= ps2_byte;
         debug_valid <= valid;
         debug_keymap_data <= keymap_data;
         debug_break_code <= ps2_break_keycode;
         debug_keycode_type <= keymap_data[7:6];
         debug_meta_pressed <= meta_pressed;
         debug_control_pressed <= control_pressed;
      end
   end

   // Separate debug block for path tracking
   always @(posedge clk) begin
      if (reset) begin
         in_regular_path <= 0;
         last_data_reg <= 8'h0;
      end
      else begin
         // Update based on state machine activity
         if (state == STATE_KEY_DOWN && keymap_data[7:6] != KEYCODE_MODIFIER && 
             keymap_data[7:6] != KEYCODE_ESCAPED) begin
            in_regular_path <= 1;
         end
         else begin
            in_regular_path <= 0;
         end

         // Track data_reg changes
         last_data_reg <= data_reg;
      end
   end

   // Error detection logic
   always @(posedge clk) begin
      if (reset) begin
         ps2_error <= 0;
         debug_frame_errors <= 0;
      end
      else if (ps2_count == PS2_BITS) begin
         debug_parity_calc <= calc_parity(ps2_raw_data[8:1]);
         debug_parity_received <= ps2_raw_data[9];
         debug_frame_errors <= {
            ps2_raw_data[0] != 0,           // Start bit error
            ps2_raw_data[10] != 1,          // Stop bit error
            ps2_raw_data[9] != calc_parity(ps2_raw_data[8:1])  // Parity error
         };
         
         ps2_error <= (ps2_raw_data[0] != 0) ||                              // Start bit error
                     (ps2_raw_data[10] != 1) ||                              // Stop bit error
                     (ps2_raw_data[9] != calc_parity(ps2_raw_data[8:1]));   // Parity error
      end
   end

   // Keymap interface
   wire [10:0] keymap_address;
   wire [7:0]  keymap_data;
   
   assign keymap_address = {ps2_long_keycode, caps_lock_active, shift_pressed, ps2_byte};
   
   keymap_rom keymap_rom(
      .clk(clk),
      .addr(keymap_address),
      .dout(keymap_data)
   );

   // Connect debug outputs
   assign debug_in_regular_path = in_regular_path;
   assign debug_data_reg = last_data_reg;

   // Main state machine
   always @(posedge clk) begin
      if (reset) begin
         state <= STATE_IDLE;
         data_reg <= 8'h0;
         valid <= 1'b0;
         ps2_raw_data <= 11'h0;
         ps2_count <= 4'h0;
         ps2_byte <= 8'h0;
         ps2_break_keycode <= 1'b0;
         ps2_long_keycode <= 1'b0;
         modifier_pressed <= 6'h0;
         caps_lock_active <= 1'b0;
         special_data <= 8'h0;
         valid_extend_reg <= 16'h0;
         debug_next_state <= STATE_IDLE;
      end
      else begin
         // Clear valid when data has been accepted
         if (valid && ready)
            valid <= 1'b0;

         case (state)
            STATE_IDLE: begin
               if (ps2_clk_falling) begin
                  ps2_raw_data <= {ps2_data_sync[1], ps2_raw_data[10:1]};
                  ps2_count <= ps2_count + 1'b1;
               end

               // Process after receiving all 11 bits
               if (ps2_count == PS2_BITS) begin
                  ps2_count <= 0;
                  
                  // Only process if frame is valid
                  if ((ps2_raw_data[0] == 0) &&                              // Valid start bit
                      (ps2_raw_data[10] == 1) &&                             // Valid stop bit
                      (ps2_raw_data[9] == calc_parity(ps2_raw_data[8:1])))  // Valid parity
                  begin
                     ps2_byte <= ps2_raw_data[8:1];  // Extract data bits
                     
                     if (ps2_raw_data[8:1] == 8'he0) begin
                        ps2_break_keycode <= 1'b0;
                        ps2_long_keycode <= 1'b1;
                     end
                     else if (ps2_raw_data[8:1] == 8'hf0) begin
                        ps2_break_keycode <= 1'b1;
                     end
                     else begin
                        debug_next_state <= STATE_KEYMAP;
                        state <= STATE_KEYMAP;
                     end
                  end
               end
            end

            STATE_KEYMAP: begin
               debug_next_state <= ps2_break_keycode ? STATE_KEY_UP : STATE_KEY_DOWN;
               state <= ps2_break_keycode ? STATE_KEY_UP : STATE_KEY_DOWN;
            end

            STATE_KEY_UP: begin
               ps2_break_keycode <= 1'b0;
               ps2_long_keycode <= 1'b0;
               debug_next_state <= STATE_IDLE;
               state <= STATE_IDLE;
               
               if (keymap_data[7:6] == KEYCODE_MODIFIER) begin
                  modifier_pressed <= modifier_pressed & ~keymap_data[5:0];
               end
            end

            STATE_KEY_DOWN: begin
               ps2_long_keycode <= 1'b0;
               
               if (keymap_data == 8'h0) begin
                  debug_next_state <= STATE_IDLE;
                  state <= STATE_IDLE;
               end
               else begin
                  if (keymap_data[7:6] == KEYCODE_MODIFIER) begin
                     debug_next_state <= STATE_IDLE;
                     state <= STATE_IDLE;
                     modifier_pressed <= modifier_pressed | keymap_data[5:0];
                     caps_lock_active <= caps_lock_active ^ ~|keymap_data[5:0];
                  end
                  else if (keymap_data[7:6] == KEYCODE_ESCAPED) begin
                     if (!valid) begin  // Set valid only if not already set
                        data_reg <= ESC;
                        valid <= 1'b1;
                     end
                     debug_next_state <= STATE_ESC_CHAR;
                     state <= STATE_ESC_CHAR;
                     special_data <= {1'b0, control_pressed ? 2'b00 : keymap_data[6:5], keymap_data[4:0]};
                  end
                  else begin  // Regular keycode (00 or 01)
                     if (meta_pressed) begin
                        if (!valid) begin  // Set valid only if not already set
                           data_reg <= ESC;
                           valid <= 1'b1;
                        end
                        debug_next_state <= STATE_ESC_CHAR;
                        state <= STATE_ESC_CHAR;
                        special_data <= {1'b0, control_pressed ? 2'b00 : keymap_data[6:5], keymap_data[4:0]};
                     end
                     else begin
                        if (!valid) begin  // Set valid only if not already set
                           data_reg <= keymap_data;
                           valid <= 1'b1;
                        end
                        debug_next_state <= STATE_IDLE;
                        state <= STATE_IDLE;
                     end
                  end
               end
            end

            STATE_ESC_CHAR: begin
               if (!valid) begin
                  debug_next_state <= STATE_IDLE;
                  state <= STATE_IDLE;
                  data_reg <= {1'b0, control_pressed ? 2'b00 : special_data[6:5], special_data[4:0]};
                  valid <= 1'b1;
               end
            end

            default: begin
                debug_next_state <= STATE_IDLE;
                state <= STATE_IDLE;
            end
         endcase

         // Update valid_extend register
         if (valid)
            valid_extend_reg <= 16'h0100;
         else if (valid_extend_reg > 0)
            valid_extend_reg <= valid_extend_reg - 1'b1;
      end
   end

   // Output assignments
   assign data = data_reg;
   assign ps2_activity = ps2_clk_falling;
   assign valid_extend = valid_extend_reg;

endmodule