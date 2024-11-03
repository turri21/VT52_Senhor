/*

# VT52 Module Analysis

## Inputs and Outputs
- Inputs: `clk`, `reset`, `pal`, `scandouble`
- Outputs: `ce_pix`, `HBlank`, `HSync`, `VBlank`, `VSync`, `video`

## Key Components

1. **Counters**: 
   - `hc`: Horizontal counter
   - `vc`: Vertical counter
   - `vvc`: Another vertical counter (possibly for effects)

2. **Random Number Generator**:
   - Uses an LFSR (Linear Feedback Shift Register) for randomness

3. **Cosine Generator**:
   - Generates cosine values based on vertical position

4. **Timing Logic**:
   - Generates horizontal and vertical sync and blank signals
   - Supports both PAL and non-PAL (likely NTSC) modes
   - Implements scan doubling option

5. **Video Output**:
   - Generates an 8-bit video output based on cosine and random values

## Functionality

1. **Clock and Reset**:
   - The module is synchronized to the input clock
   - Reset initializes counters

2. **Pixel Clock**:
   - `ce_pix` (clock enable for pixel) is generated based on `scandouble`

3. **Counters**:
   - Horizontal counter (`hc`) counts up to 637
   - Vertical counter (`vc`) counts up to 623/311 (PAL) or 523/261 (non-PAL)
   - `vvc` is incremented by 6 at the end of each frame

4. **Sync and Blank Signals**:
   - HBlank: Active from 529 to 0
   - HSync: Active from 544 to 590
   - VSync and VBlank: Timing depends on PAL/non-PAL and scandouble settings

5. **Video Generation**:
   - Uses cosine values and random numbers to create a pattern
   - The final video output is an 8-bit value

## Notable Features
- Supports both PAL and non-PAL (likely NTSC) video standards
- Implements scan doubling for higher refresh rates
- Uses a combination of deterministic (cosine) and random elements for video generation

This module appears to be designed for generating test patterns or special effects, possibly for a retro-style video system or display.

*/


module VT52
(
	input         clk,
	input         reset,
	
	input         pal,
	input         scandouble,

	output reg    ce_pix,

	output reg    HBlank,
	output reg    HSync,
	output reg    VBlank,
	output reg    VSync,

	output  [7:0] video
);

reg   [9:0] hc;
reg   [9:0] vc;
reg   [9:0] vvc;
reg  [63:0] rnd_reg;

wire  [5:0] rnd_c = {rnd_reg[0],rnd_reg[1],rnd_reg[2],rnd_reg[2],rnd_reg[2],rnd_reg[2]};
wire [63:0] rnd;

lfsr random(rnd);

always @(posedge clk) begin
	if(scandouble) ce_pix <= 1;
		else ce_pix <= ~ce_pix;

	if(reset) begin
		hc <= 0;
		vc <= 0;
	end
	else if(ce_pix) begin
		if(hc == 637) begin
			hc <= 0;
			if(vc == (pal ? (scandouble ? 623 : 311) : (scandouble ? 523 : 261))) begin 
				vc <= 0;
				vvc <= vvc + 9'd6;
			end else begin
				vc <= vc + 1'd1;
			end
		end else begin
			hc <= hc + 1'd1;
		end

		rnd_reg <= rnd;
	end
end

always @(posedge clk) begin
	if (hc == 529) HBlank <= 1;
		else if (hc == 0) HBlank <= 0;

	if (hc == 544) begin
		HSync <= 1;

		if(pal) begin
			if(vc == (scandouble ? 609 : 304)) VSync <= 1;
				else if (vc == (scandouble ? 617 : 308)) VSync <= 0;

			if(vc == (scandouble ? 601 : 300)) VBlank <= 1;
				else if (vc == 0) VBlank <= 0;
		end
		else begin
			if(vc == (scandouble ? 490 : 245)) VSync <= 1;
				else if (vc == (scandouble ? 496 : 248)) VSync <= 0;

			if(vc == (scandouble ? 480 : 240)) VBlank <= 1;
				else if (vc == 0) VBlank <= 0;
		end
	end
	
	if (hc == 590) HSync <= 0;
end

wire [5:0] cos_g = cos_out[7:3]+6'd32;
wire [7:0] cos_out;
cos cos(
    .x(vvc + {vc>>scandouble, 2'b00}),
    .y(cos_out)
);
assign video = (cos_g >= rnd_c) ? {cos_g - rnd_c, 2'b00} : 8'd0;

endmodule
