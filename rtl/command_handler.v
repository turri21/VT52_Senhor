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

module command_handler
#(parameter ROWS = 24,           // Visible rows
  parameter COLS = 80,
  parameter ROW_BITS = 5,
  parameter COL_BITS = 7,
  parameter ADDR_BITS = 11)
 (
  input wire clk,
  input wire reset,
  input wire [7:0] data,
  input wire valid,
  input wire from_uart,    
  output reg ready,
  output reg buffer_scroll,        
  input wire scroll_busy,          
  input wire scroll_done,          
  output reg [7:0] buffer_write_char,
  output reg [ADDR_BITS-1:0] buffer_write_addr,
  output reg buffer_write_enable,
  output reg [COL_BITS-1:0] new_cursor_x,
  output reg [ROW_BITS-1:0] new_cursor_y,
  output reg new_cursor_wen
  );

  reg [ROW_BITS-1:0] new_row;
  reg [COL_BITS-1:0] new_col;
  reg [ADDR_BITS-1:0] current_row_addr;
  reg [ADDR_BITS-1:0] current_char_addr;
  reg [ADDR_BITS-1:0] erase_address;
  reg [ADDR_BITS-1:0] last_char_to_erase;
  reg [31:0] timeout_counter;
  reg state_timeout;

  // State encoding - one-hot
  localparam state_char        = 8'b00000001;
  localparam state_esc         = 8'b00000010;
  localparam state_row         = 8'b00000100;
  localparam state_col         = 8'b00001000;
  localparam state_addr        = 8'b00010000;
  localparam state_cursor      = 8'b00100000;
  localparam state_erase       = 8'b01000000;
  localparam state_scroll_wait = 8'b10000000;

  reg [7:0] state;

  // At 25MHz clock:
  // 1 second = 25,000,000 cycles
  localparam UART_TIMEOUT    = 32'd25_000_000;    // 1 second
  localparam KEYBOARD_TIMEOUT = 32'd125_000_000;  // 5 seconds

  // Timeout counter
  always @(posedge clk) begin
    if (reset) begin
      timeout_counter <= 0;
      state_timeout <= 0;
    end
    else begin
      if (valid) begin  
        timeout_counter <= 0;
        state_timeout <= 0;
      end
      else if (state == state_esc || state == state_row || state == state_col) begin
        if (from_uart) begin
          if (timeout_counter >= UART_TIMEOUT) begin
            state_timeout <= 1;
          end
          else begin
            timeout_counter <= timeout_counter + 1;
          end
        end
        else begin
          if (timeout_counter >= KEYBOARD_TIMEOUT) begin
            state_timeout <= 1;
          end
          else begin
            timeout_counter <= timeout_counter + 1;
          end
        end
      end
      else begin
        timeout_counter <= 0;
        state_timeout <= 0;
      end
    end
  end

  // Ready signal generation
  wire in_multistate_operation = (state & (state_erase | state_cursor | state_addr | state_scroll_wait)) != 0;
  
  // Ready signal management
  always @(posedge clk) begin
    if (reset) begin
      ready <= 1'b1;
    end
    else begin
      ready <= 1'b1;  // Default to ready
      
      if (scroll_busy) begin
        ready <= 1'b0;
      end
      else if (valid && ready) begin  // Only drop ready for one cycle when accepting data
        ready <= 1'b0;
      end
      else if (in_multistate_operation && state != state_char) begin
        ready <= 1'b0;
      end
    end
  end

  // Main state machine
  always @(posedge clk) begin
    if (reset) begin
      buffer_write_char <= 0;
      buffer_write_addr <= 0;
      buffer_write_enable <= 0;
      buffer_scroll <= 0;
      new_cursor_x <= 0;
      new_cursor_y <= 0;
      new_cursor_wen <= 0;
      current_row_addr <= 0;
      current_char_addr <= 0;
      state <= state_char;
      new_row <= 0;
      new_col <= 0;
      erase_address <= 0;
      last_char_to_erase <= 0;
    end
    else begin
      // Clear one-cycle signals
      buffer_write_enable <= 0;
      new_cursor_wen <= 0;
      buffer_scroll <= 0;

      case (state)
        state_scroll_wait: begin
          if (scroll_done || !scroll_busy) begin
            current_row_addr <= (ROWS-1) * COLS;
            current_char_addr <= (ROWS-1) * COLS + new_cursor_x;
            state <= state_char;
          end
        end

        state_erase: begin
          if (!scroll_busy) begin
            if (erase_address > last_char_to_erase) begin
              state <= state_char;
            end
            else begin
              buffer_write_char <= 8'h20;
              buffer_write_addr <= erase_address;
              erase_address <= erase_address + 1;
              buffer_write_enable <= 1;
            end
          end
        end

        state_char: begin
          if (ready && valid && !scroll_busy) begin
            if (data >= 8'h20 && data != 8'h7f) begin
              // Write the character
              buffer_write_char <= data;
              buffer_write_addr <= current_char_addr;
              buffer_write_enable <= 1;

              // Standard VT52 cursor advance
              if (new_cursor_x == (COLS-1)) begin
                // At end of line
                if (new_cursor_y == (ROWS-1)) begin
                  buffer_scroll <= 1;
                  state <= state_scroll_wait;
                end
                else begin
                  new_cursor_y <= new_cursor_y + 1;
                  new_cursor_x <= 0;
                  new_cursor_wen <= 1;
                  current_row_addr <= current_row_addr + COLS;
                  current_char_addr <= current_row_addr + COLS;
                end
              end
              else begin
                new_cursor_x <= new_cursor_x + 1;
                current_char_addr <= current_char_addr + 1;
                new_cursor_wen <= 1;
              end
            end
            else begin
              case (data)
                8'h08: begin  // BS - Move cursor left (no erase)
                  if (new_cursor_x != 0) begin
                    new_cursor_x <= new_cursor_x - 1;
                    current_char_addr <= current_char_addr - 1;
                    new_cursor_wen <= 1;
                  end
                end

                8'h09: begin  // HT - Tab (every 8 columns)
                  if (new_cursor_x < (COLS-9)) begin
                    new_cursor_x <= {(new_cursor_x[COL_BITS-1:3]+1), 3'b000};
                    current_char_addr <= {(current_char_addr[ADDR_BITS-1:3]+1), 3'b000};
                    new_cursor_wen <= 1;
                  end
                  else if (new_cursor_x != (COLS-1)) begin
                    new_cursor_x <= new_cursor_x + 1;
                    current_char_addr <= current_char_addr + 1;
                    new_cursor_wen <= 1;
                  end
                end

                8'h0a: begin  // LF - Line feed
                  if (new_cursor_y == (ROWS-1)) begin
                    buffer_scroll <= 1;
                    state <= state_scroll_wait;
                  end
                  else begin
                    new_cursor_y <= new_cursor_y + 1;
                    new_cursor_wen <= 1;
                    current_row_addr <= current_row_addr + COLS;
                    current_char_addr <= current_char_addr + COLS;
                  end
                end

                8'h0d: begin  // CR - Return to start of line
                  new_cursor_x <= 0;
                  new_cursor_wen <= 1;
                  current_char_addr <= current_row_addr;
                end

                8'h1b: begin  // ESC - Start escape sequence
                  state <= state_esc;
                end
              endcase
            end
          end
        end

        state_esc: begin
          if (valid && !scroll_busy) begin
            case (data)
              "A": begin  // Cursor up
                if (new_cursor_y != 0) begin
                  new_cursor_y <= new_cursor_y - 1;
                  new_cursor_wen <= 1;
                  current_row_addr <= current_row_addr - COLS;
                  current_char_addr <= current_char_addr - COLS;
                end
                state <= state_char;
              end

              "B": begin  // Cursor down
                if (new_cursor_y != (ROWS-1)) begin
                  new_cursor_y <= new_cursor_y + 1;
                  new_cursor_wen <= 1;
                  current_row_addr <= current_row_addr + COLS;
                  current_char_addr <= current_char_addr + COLS;
                end
                state <= state_char;
              end

              "C": begin  // Cursor right
                if (new_cursor_x != (COLS-1)) begin
                  new_cursor_x <= new_cursor_x + 1;
                  new_cursor_wen <= 1;
                  current_char_addr <= current_char_addr + 1;
                end
                state <= state_char;
              end

              "D": begin  // Cursor left
                if (new_cursor_x != 0) begin
                  new_cursor_x <= new_cursor_x - 1;
                  new_cursor_wen <= 1;
                  current_char_addr <= current_char_addr - 1;
                end
                state <= state_char;
              end

              "H": begin  // Cursor home
                new_cursor_x <= 0;
                new_cursor_y <= 0;
                new_cursor_wen <= 1;
                current_row_addr <= 0;
                current_char_addr <= 0;
                state <= state_char;
              end

              "I": begin  // Reverse line feed
                if (new_cursor_y == 0) begin
                  buffer_scroll <= 1;
                  state <= state_scroll_wait;
                end
                else begin
                  new_cursor_y <= new_cursor_y - 1;
                  new_cursor_wen <= 1;
                  current_row_addr <= current_row_addr - COLS;
                  current_char_addr <= current_char_addr - COLS;
                  state <= state_char;
                end
              end

              "J": begin  // Erase to end of screen and home cursor
                buffer_write_char <= 8'h20;
                erase_address <= 0;
                last_char_to_erase <= (ROWS * COLS) - 1;
                buffer_write_enable <= 1;
                // Also move cursor home per VT52 spec
                new_cursor_x <= 0;
                new_cursor_y <= 0;
                new_cursor_wen <= 1;
                current_row_addr <= 0;
                current_char_addr <= 0;
                state <= state_erase;
              end

              "K": begin  // Erase to end of line (cursor doesn't move)
                buffer_write_char <= 8'h20;
                erase_address <= current_char_addr;
                last_char_to_erase <= current_row_addr + (COLS-1);
                buffer_write_enable <= 1;
                state <= state_erase;
              end

              "Y": begin  // Direct cursor address
                state <= state_row;
              end

              default: begin
                state <= state_char;  // Ignore unknown escape sequences
              end
            endcase
          end
          
          if (state_timeout) begin
            state <= state_char;
          end
        end

        state_row: begin
          if (valid) begin
            new_row <= (data >= 8'h20 && data < (8'h20 + ROWS)) ?
                      data - 8'h20 : new_cursor_y;
            state <= state_col;
          end
        end

        state_col: begin
          if (valid) begin
            new_col <= (data >= 8'h20 && data < (8'h20 + COLS)) ?
                      data - 8'h20 : new_cursor_x;
            state <= state_cursor;
          end
        end

        state_cursor: begin
          new_cursor_x <= new_col;
          new_cursor_y <= new_row;
          new_cursor_wen <= 1;
          current_row_addr <= new_row * COLS;
          current_char_addr <= (new_row * COLS) + new_col;
          state <= state_char;
        end

      endcase
    end
  end

endmodule