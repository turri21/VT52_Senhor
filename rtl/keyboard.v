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
  (input  clk,
   input  reset,
   input  ps2_data,
   input  ps2_clk,
   output reg [7:0] data,
   output reg valid,
   input ready
   );

   // state: one hot encoding
   // idle is the normal state, reading the ps/2 bus
   // key up/down (long and short) are for key events
   // keymap_read is for reading the keymap rom
   // esc_char is for sending ESC- prefixed chars
   localparam state_idle        = 5'b00001;
   localparam state_keymap      = 5'b00010;
   localparam state_key_down    = 5'b00100;
   localparam state_key_up      = 5'b01000;
   localparam state_esc_char    = 5'b10000;

   localparam esc = 8'h1b;

   localparam keycode_regular = 2'b0x;
   localparam keycode_modifier = 2'b10;
   localparam keycode_escaped = 2'b11;

   reg [4:0] state;

   reg [1:0] ps2_old_clks;
   reg [10:0] ps2_raw_data;
   reg [3:0]  ps2_count;
   reg [7:0]  ps2_byte;
   // we are processing a break_code (key up)
   reg ps2_break_keycode;
   // we are processing a long keycode (two bytes)
   reg ps2_long_keycode;
   // shift, control & meta key status, bit order:
   // lshift, lcontrol, lmeta, rmeta, rcontrol, rshift
   // alt/meta key status, vt52 doesn't have meta, but I want to use
   // emacs & can't stand that Esc- business, so alt sends esc+keypress
   reg [5:0] modifier_pressed;
   wire shift_pressed = modifier_pressed[5] || modifier_pressed[0];
   wire control_pressed = modifier_pressed[4] || modifier_pressed[1];
   wire meta_pressed = modifier_pressed[3] || modifier_pressed[2];
   // caps lock
   reg caps_lock_active;
   // keymap
   wire [10:0] keymap_address;
   wire [7:0] keymap_data;
   // special char to send after ESC
   reg [7:0] special_data;

   // ps2_byte is the actual keycode, we use long/short keycode, caps lock &
   // shift to determine the plane we need
   assign keymap_address = { ps2_long_keycode, caps_lock_active, shift_pressed, ps2_byte };

   // address is 3 bits for longkeycode/capslock/shift + 8 bits for keycode
   // data is on of
   // 0xxxxxxx: regular ASCII key
   // 10xxxxxx: control/meta/shift or caps lock, each bit is a key, all 0 for caps lock
   // 11xxxxxx: special key, ESC + upper case ASCII (clear msb to get char)
   keymap_rom keymap_rom(.clk(clk),
                         .addr(keymap_address),
                         .dout(keymap_data)
                         );

   // we don't need to do this on the pixel clock, we could use
   // something way slower, but it works
   always @(posedge clk) begin
      if (reset) begin
         state <= state_idle;

         data <= 0;
         valid <= 0;

         // the clk is usually high and pulled down to start
         ps2_old_clks <= 2'b00;
         ps2_raw_data <= 0;
         ps2_count <= 0;
         ps2_byte <= 0;

         ps2_break_keycode <= 0;
         ps2_long_keycode <= 0;

         modifier_pressed = 6'h00;
         caps_lock_active <= 0;

         special_data <= 0;
      end
      else if (valid && ready) begin
         // as soon as data is transmitted, clear valid
         valid <= 0;
      end
      else begin
        case (state)
          state_idle: begin
             ps2_old_clks <= {ps2_old_clks[0], ps2_clk};
             if(ps2_clk && ps2_old_clks == 2'b01) begin
                // clock edge detected, read another bit
                if(ps2_count == 10) begin
                   // 11 bits means we are done (XXX/TODO check parity and stop bits)
                   ps2_count <= 0;
                   ps2_byte <= ps2_raw_data[10:3];
                   // handle the breaks & long keycodes and only change to
                   // keycode state if a complete keycode is already received
                   if (ps2_raw_data[10:3] == 8'he0) begin
                      ps2_break_keycode <= 0;
                      ps2_long_keycode <= 1;
                   end
                   else if (ps2_raw_data[10:3] == 8'hf0) begin
                      ps2_break_keycode <= 1;
                   end
                   else begin
                      state <= state_keymap;
                   end
                end
                else begin
                   // the data comes lsb first
                   ps2_raw_data <= {ps2_data, ps2_raw_data[10:1]};
                   ps2_count <= ps2_count + 1;
                end
             end
          end
          state_keymap: begin
             // after reading the keymap we can finally process the key
             state <= ps2_break_keycode? state_key_up : state_key_down;
          end
          state_key_up: begin
             // on key up we only care about released modifiers
             ps2_break_keycode <= 0;
             ps2_long_keycode <= 0;
             state <= state_idle;
             if (keymap_data[7:6] == keycode_modifier) begin
                // the released modifier is in keymap_data[5:0]
                // or 0 for caps lock
                modifier_pressed <= modifier_pressed & ~keymap_data[5:0];
             end
          end
          state_key_down: begin
             ps2_long_keycode <= 0;
             if (keymap_data == 0) begin
                // unrecognized key, just go back to idle
                state <= state_idle;
             end
             else begin
                casex (keymap_data[7:6])
                  keycode_regular: begin
                     // regular key, apply modifiers:
                     // control turns off 7th & 6th bits
                     // meta sends an ESC prefix
                     if (meta_pressed) begin
                        data <= esc;
                        valid <= 1;
                        state <= state_esc_char;
                        special_data <= {
                                         1'b0,
                                         control_pressed? 2'b00 : keymap_data[6:5],
                                         keymap_data[4:0]
                                         };
                     end
                     else begin
                        data <= {
                                 1'b0,
                                 control_pressed? 2'b00 : keymap_data[6:5],
                                 keymap_data[4:0]
                                 };
                        valid <= 1;
                        state <= state_idle;
                     end
                  end
                  keycode_escaped: begin
                     // escaped char, send Esc- and then the ascii value
                     // including the leading 1 (only uppercase, lowercase and some symbols allowed)
                     data <= esc;
                     valid <= 1;
                     state <= state_esc_char;
                     special_data <= {
                                      1'b0,
                                      control_pressed? 2'b00 : keymap_data[6:5],
                                      keymap_data[4:0]
                                      };
                  end
                  keycode_modifier: begin
                     // the pressed modifier is in keymap_data[5:0], or 0 for caps lock
                     state <= state_idle;
                     modifier_pressed <= modifier_pressed | keymap_data[5:0];
                     caps_lock_active <= caps_lock_active ^ ~|keymap_data[5:0];
                  end
                endcase
             end // else: !if(keymap_data == 0)
          end // case: state_keymap_down
          state_esc_char: begin
             // only send special char after ESC was successfully sent
             if (valid == 0) begin
                state <= state_idle;
                data <= {
                         1'b0,
                         control_pressed? 2'b00 : special_data[6:5],
                         special_data[4:0]
                         };
                valid <= 1;
             end
          end
        endcase // case (state)
      end // else: !if(valid && ready)
   end // always @ (posedge clk)
endmodule
