/* ================================================================
 * VT52
 *
 * Copyright (C) 2024 Fred Van Eijk
 *
 * Permission is hereby granted, free of charge, to any person 
 * obtaining a copy of this software and associated documentation 
 * files (the "Software"), to deal in the Software without 
 * restriction, including without limitation the rights to use, 
 * copy, modify, merge, publish, distribute, sublicense, and/or 
 * sell copies of the Software, and to permit persons to whom 
 * the Software is furnished to do so, subject to the following 
 * conditions:
 * 
 * The above copyright notice and this permission notice shall be 
 * included in all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, 
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT 
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR 
 * OTHER DEALINGS IN THE SOFTWARE.
 * ================================================================
 */

module keyboard(
   input         clk,          // 25MHz system clock
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

   // Timing parameters in milliseconds and Hz
   localparam CLOCK_FREQ_MHZ   = 25;                    // Clock frequency in MHz
   localparam INITIAL_DELAY_MS = 500;                   // 500ms initial delay before repeat
   localparam REPEAT_RATE_HZ   = 10;                    // 10 characters per second

   // Convert to clock cycles for 25MHz clock
   localparam REPEAT_DELAY     = CLOCK_FREQ_MHZ * 1000 * INITIAL_DELAY_MS;  // 500ms = 12,500,000 cycles
   localparam REPEAT_RATE      = (CLOCK_FREQ_MHZ * 1000_000) / REPEAT_RATE_HZ; // 10Hz = 2,500,000 cycles

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

   // Key repeat registers
   reg [23:0] repeat_counter;
   reg        repeat_active;
   reg [7:0]  repeat_keycode;
   reg        in_repeat_delay;

   // Debug tracking registers
   reg        in_regular_path;
   reg [7:0]  last_data_reg;

   // Modifier key status
   wire       shift_pressed   = modifier_pressed[5] || modifier_pressed[0];
   wire       control_pressed = modifier_pressed[4] || modifier_pressed[1];
   wire       meta_pressed    = modifier_pressed[3] || modifier_pressed[2];

   // Non-repeatable keys
   wire is_non_repeatable = (ps2_byte == 8'hF0) ||     // Break code
                           (ps2_byte == 8'hE0) ||     // Extended prefix
                           (keymap_data[7:6] == KEYCODE_MODIFIER); // Modifier keys

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

   // Debug output assignments
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
         repeat_counter <= 0;
         repeat_active <= 0;
         repeat_keycode <= 0;
         in_repeat_delay <= 0;
      end
      else begin
         // Clear valid when data has been accepted
         if (valid && ready)
            valid <= 1'b0;

         // Handle key repeat timing
         if (repeat_active) begin
            repeat_counter <= repeat_counter + 1;
            
            if (in_repeat_delay && repeat_counter >= REPEAT_DELAY) begin
               repeat_counter <= 0;
               in_repeat_delay <= 0;
            end
            else if (!in_repeat_delay && repeat_counter >= REPEAT_RATE) begin
               repeat_counter <= 0;
               if (!valid) begin
                  valid <= 1;
                  data_reg <= keymap_data;
               end
            end
         end

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
               repeat_active <= 0;
               repeat_counter <= 0;
               in_repeat_delay <= 0;
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
                        
                        // Start repeat for regular keys
                        if (!is_non_repeatable) begin
                           repeat_keycode <= ps2_byte;
                           if (!repeat_active) begin
                              repeat_active <= 1;
                              repeat_counter <= 0;
                              in_repeat_delay <= 1;
                           end
                        end
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