/*
 *  PicoSoC - A simple example SoC using PicoRV32
 *
 *  Copyright (C) 2017  Clifford Wolf <clifford@clifford.at>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *


The `simpleuart` module implements a basic UART (Universal Asynchronous Receiver/Transmitter) 
for serial communication. It handles both transmission and reception of data over a serial line. 
Here’s a detailed description of its components and functionality:

### Inputs and Outputs:
- **Inputs**:
  - **`clk`**: Clock signal for the module.
  - **`resetn`**: Active-low reset signal to initialize or clear the module state.
  - **`ser_rx`**: Serial data input (received data).
  - **`cfg_divider`**: Configuration parameter for the baud rate divider.
  - **`reg_dat_we`**: Write enable signal for data register.
  - **`reg_dat_re`**: Read enable signal for data register.
  - **`reg_dat_di`**: Data input for the register.

- **Outputs**:
  - **`ser_tx`**: Serial data output (transmitted data).
  - **`reg_dat_do`**: Data output from the register.
  - **`reg_dat_wait`**: Indicates if the data register is busy.
  - **`recv_buf_valid`**: Indicates that received data is valid.
  - **`tdre`**: Transmit Data Register Empty signal, indicating the transmit buffer is ready to accept new data.

### Internal Registers:
- **Reception**:
  - **`recv_state`**: State machine for handling the reception process.
  - **`recv_divcnt`**: Divider counter for generating baud rate timing during reception.
  - **`recv_pattern`**: Register holding the received data pattern.
  - **`recv_buf_data`**: Buffer to hold the received data.
  - **`recv_buf_valid`**: Flag indicating the validity of received data.

- **Transmission**:
  - **`send_pattern`**: Register holding the data pattern to be transmitted.
  - **`send_bitcnt`**: Counter for the number of bits to be transmitted.
  - **`send_divcnt`**: Divider counter for generating baud rate timing during transmission.
  - **`send_dummy`**: Dummy register used for initialization purposes.
  - **`tdre`**: Transmit Data Register Empty flag.

### Functional Description:

1. **Reception**:
   - **Idle State**: The UART waits for a low start bit to indicate the beginning of a data frame (`recv_state == 0`). The `recv_divcnt` is reset.
   - **Start Bit Detection**: When a low start bit is detected, the state transitions to `1` and waits for the appropriate baud rate timing (`2*recv_divcnt > cfg_divider`).
   - **Data Sampling**: The UART samples the data bits for 8 cycles (one bit per cycle) and accumulates them in `recv_pattern`. It moves through states `2` to `10` to sample each bit.
   - **Data Validity**: After all 8 data bits are sampled, the data is stored in `recv_buf_data`, and `recv_buf_valid` is set to `1`, signaling valid received data.

2. **Transmission**:
   - **Idle State**: The UART waits for data to be written to the register (`send_dummy` is used initially). When data is written (`reg_dat_we`), the `send_pattern` is loaded with the data and the start bit.
   - **Data Transmission**: The UART transmits data bits serially, one bit per cycle. It shifts out the bits in `send_pattern` while decrementing `send_bitcnt`. The `tdre` signal is set when the transmission is complete and the buffer is empty.

### Key Functional Points:
- **Baud Rate Divider**: The baud rate for both transmission and reception is controlled by `cfg_divider`, which determines the timing of bit sampling and transmission.
- **State Machines**: Separate state machines for reception and transmission manage the UART operations, ensuring correct data framing and timing.
- **Buffering**: Received data is buffered and flagged as valid. Transmit data is shifted out bit by bit, with `tdre` indicating when the transmit buffer is ready for new data.

### Summary:
The `simpleuart` module provides basic UART functionality for serial communication. It manages 
both receiving and transmitting data with appropriate timing based on the baud rate configuration. 
It includes a state machine for handling data reception and another for data transmission, 
ensuring smooth serial communication and accurate data handling.


 */

module simpleuart (
	input clk,
	input resetn,

	output ser_tx,
	input  ser_rx,

	input  [31:0] cfg_divider,

	input         reg_dat_we,
	input         reg_dat_re,
	input  [7:0]  reg_dat_di,
	output [7:0]  reg_dat_do,
	output        reg_dat_wait,
	output 	reg   recv_buf_valid,
	output  reg   tdre
);

	reg [3:0] recv_state;
	reg [31:0] recv_divcnt;
	reg [7:0] recv_pattern;
	reg [7:0] recv_buf_data;

	reg [9:0] send_pattern;
	reg [3:0] send_bitcnt;
	reg [31:0] send_divcnt;
	reg send_dummy;

	assign reg_dat_wait = reg_dat_we && (send_bitcnt || send_dummy);
	assign reg_dat_do = recv_buf_valid ? recv_buf_data : ~8'd0;

	always @(posedge clk) begin
		if (!resetn) begin
			recv_state <= 0;
			recv_divcnt <= 0;
			recv_pattern <= 0;
			recv_buf_data <= 0;
			recv_buf_valid <= 0;			
		end else begin
			recv_divcnt <= recv_divcnt + 1;
			if (reg_dat_re)
				recv_buf_valid <= 0;
			case (recv_state)
				0: begin
					if (!ser_rx)
						recv_state <= 1;
					recv_divcnt <= 0;
				end
				1: begin
					if (2*recv_divcnt > cfg_divider) begin
						recv_state <= 2;
						recv_divcnt <= 0;
					end
				end
				10: begin
					if (recv_divcnt > cfg_divider) begin
						recv_buf_data <= recv_pattern;
						recv_buf_valid <= 1;
						recv_state <= 0;
					end
				end
				default: begin
					if (recv_divcnt > cfg_divider) begin
						recv_pattern <= {ser_rx, recv_pattern[7:1]};
						recv_state <= recv_state + 4'd1;
						recv_divcnt <= 0;
					end
				end
			endcase
		end
	end

	assign ser_tx = send_pattern[0];

	always @(posedge clk) begin
		send_divcnt <= send_divcnt + 1;
		if (!resetn) begin
			send_pattern <= ~10'd0;
			send_bitcnt <= 0;
			send_divcnt <= 0;
			send_dummy <= 1;
			tdre <=0;
		end else begin
			if (send_dummy && !send_bitcnt) begin
				send_pattern <= ~10'd0;
				send_bitcnt <= 15;
				send_divcnt <= 0;
				send_dummy <= 0;				
			end else
			if (reg_dat_we && !send_bitcnt) begin
				send_pattern <= {1'b1, reg_dat_di, 1'b0};
				send_bitcnt <= 10;
				send_divcnt <= 0;
				tdre <=0;
			end else
			if (send_divcnt > cfg_divider && send_bitcnt) begin
				send_pattern <= {1'b1, send_pattern[9:1]};
				send_bitcnt <= send_bitcnt - 4'd1;
				send_divcnt <= 0;
			end else if (send_bitcnt==0)
			begin
				tdre <=1;
			end
		end
	end
endmodule
