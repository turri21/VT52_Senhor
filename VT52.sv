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

module emu
(
   //Master input clock
   input         CLK_50M,

   //Async reset from top-level module.
   //Can be used as initial reset.
   input         RESET,

   //Must be passed to hps_io module
   inout  [48:0] HPS_BUS,

   //Base video clock. Usually equals to CLK_SYS.
   output        CLK_VIDEO,

   //Multiple resolutions are supported using different CE_PIXEL rates.
   //Must be based on CLK_VIDEO
   output        CE_PIXEL,

   //Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
   //if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
   output [12:0] VIDEO_ARX,
   output [12:0] VIDEO_ARY,

   output  [7:0] VGA_R,
   output  [7:0] VGA_G,
   output  [7:0] VGA_B,
   output        VGA_HS,
   output        VGA_VS,
   output        VGA_DE,    // = ~(VBlank | HBlank)
   output        VGA_F1,
   output [1:0]  VGA_SL,
   output        VGA_SCALER, // Force VGA scaler
   output        VGA_DISABLE, // analog out is off

   input  [11:0] HDMI_WIDTH,
   input  [11:0] HDMI_HEIGHT,
   output        HDMI_FREEZE,
   output        HDMI_BLACKOUT,
   output        HDMI_BOB_DEINT,

`ifdef MISTER_FB
   // Use framebuffer in DDRAM
   output        FB_EN,
   output  [4:0] FB_FORMAT,
   output [11:0] FB_WIDTH,
   output [11:0] FB_HEIGHT,
   output [31:0] FB_BASE,
   output [13:0] FB_STRIDE,
   input         FB_VBL,
   input         FB_LL,
   output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
   // Palette control for 8bit modes.
   output        FB_PAL_CLK,
   output  [7:0] FB_PAL_ADDR,
   output [23:0] FB_PAL_DOUT,
   input  [23:0] FB_PAL_DIN,
   output        FB_PAL_WR,
`endif
`endif

   output        LED_USER,  // 1 - ON, 0 - OFF.

   // b[1]: 0 - LED status is system status OR'd with b[0]
   //       1 - LED status is controled solely by b[0]
   // hint: supply 2'b00 to let the system control the LED.
   output  [1:0] LED_POWER,
   output  [1:0] LED_DISK,

   // I/O board button press simulation (active high)
   // b[1]: user button
   // b[0]: osd button
   output  [1:0] BUTTONS,

   input         CLK_AUDIO, // 24.576 MHz
   output [15:0] AUDIO_L,
   output [15:0] AUDIO_R,
   output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
   output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

   //ADC
   inout   [3:0] ADC_BUS,

   //SD-SPI
   output        SD_SCK,
   output        SD_MOSI,
   input         SD_MISO,
   output        SD_CS,
   input         SD_CD,

   //High latency DDR3 RAM interface
   //Use for non-critical time purposes
   output        DDRAM_CLK,
   input         DDRAM_BUSY,
   output  [7:0] DDRAM_BURSTCNT,
   output [28:0] DDRAM_ADDR,
   input  [63:0] DDRAM_DOUT,
   input         DDRAM_DOUT_READY,
   output        DDRAM_RD,
   output [63:0] DDRAM_DIN,
   output  [7:0] DDRAM_BE,
   output        DDRAM_WE,

   //SDRAM interface with lower latency
   output        SDRAM_CLK,
   output        SDRAM_CKE,
   output [12:0] SDRAM_A,
   output  [1:0] SDRAM_BA,
   inout  [15:0] SDRAM_DQ,
   output        SDRAM_DQML,
   output        SDRAM_DQMH,
   output        SDRAM_nCS,
   output        SDRAM_nCAS,
   output        SDRAM_nRAS,
   output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
   //Secondary SDRAM
   input         SDRAM2_EN,
   output        SDRAM2_CLK,
   output [12:0] SDRAM2_A,
   output  [1:0] SDRAM2_BA,
   inout  [15:0] SDRAM2_DQ,
   output        SDRAM2_nCS,
   output        SDRAM2_nCAS,
   output        SDRAM2_nRAS,
   output        SDRAM2_nWE,
`endif

   input         UART_CTS,
   output        UART_RTS,
   input         UART_RXD,
   output        UART_TXD,
   output        UART_DTR,
   input         UART_DSR,

   // Open-drain User port.
   // 0 - D+/RX
   // 1 - D-/TX
   // 2..6 - USR2..USR6
   // Set USER_OUT to 1 to read from USER_IN.
   input   [6:0] USER_IN,
   output  [6:0] USER_OUT,

   input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign {UART_RTS, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER = 1;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BOB_DEINT = 0;

assign AUDIO_S = 0;
assign AUDIO_L = 0;
assign AUDIO_R = 0;
assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[122:121];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

// enable input on USER_IO[0] for UART i.e. USER_IN[0] rx
assign USER_OUT[0] = 1'b1;

`include "build_id.v" 
localparam CONF_STR = {
   "VT52;;",
   "-;",
   "O[122:121],Aspect ratio,Original (4:3),Full Screen;",
   "O[4:3],Text Color,White,Red,Green,Blue;",
   "OC,Serial Port,User IO Port,Console Port;",
   "OE,Font,Terminus 8x16, VT52 rom 8x8;", 
   "-;",
   "T[0],Reset;",
   "R[0],Reset and close OSD;",
   "V,v",`BUILD_DATE 
};

///////////////////////   CLOCKS   ///////////////////////////////

wire locked;

pll pll
(
   .refclk(CLK_50M),
   .rst(0),
   .outclk_0(CLK_VIDEO),
   .locked(locked)
);

wire forced_scandoubler;
wire [1:0] buttons;
wire [127:0] status;
wire ps2_clk, ps2_data;

hps_io #(.CONF_STR(CONF_STR), .PS2DIV(800)) hps_io
(
   .clk_sys(CLK_VIDEO),
   .HPS_BUS(HPS_BUS),
   .EXT_BUS(),
   .gamma_bus(),

   .forced_scandoubler(forced_scandoubler),

   .buttons(buttons),
   .status(status),
   .status_menumask({status[5]}),
   
   .ps2_kbd_clk_out(ps2_clk),
   .ps2_kbd_data_out(ps2_data)
);

wire reset = RESET | status[0] | buttons[1];

// Generate CE_PIXEL for ~14.7MHz from 29.4MHz
reg ce_pix;
always @(posedge CLK_VIDEO) begin
   reg div;  // Single bit for divide by 2
   div <= div + 1'd1;
   ce_pix <= !div;
end

wire HBlank;
wire HSync;
wire VBlank;
wire VSync;
wire video_out;

assign CE_PIXEL = ce_pix;
assign VGA_DE = ~(HBlank | VBlank);
assign VGA_HS = HSync;
assign VGA_VS = VSync;

// Color selection
reg [7:0] R, G, B;
always @(posedge CLK_VIDEO) begin
   case (status[4:3])
      2'b00: begin  // White
         R <= {8{video_out}};
         G <= {8{video_out}};
         B <= {8{video_out}};
      end
      2'b01: begin  // Red
         R <= {8{video_out}};
         G <= 8'd0;
         B <= 8'd0;
      end
      2'b10: begin  // Green
         R <= 8'd0;
         G <= {8{video_out}};
         B <= 8'd0;
      end
      2'b11: begin  // Blue
         R <= 8'd0;
         G <= 8'd0;
         B <= {8{video_out}};
      end
   endcase
end

assign VGA_R = R;
assign VGA_G = G;
assign VGA_B = B;

// UART port selection logic
wire uart_tx_wire;
wire uart_rx_wire = !status[12] ? USER_IN[0] : UART_RXD;
assign UART_TXD = !status[12] ? 1'b1 : uart_tx_wire;
assign USER_OUT[1] = !status[12] ? 
                 uart_tx_wire : // When USER_IO selected
                 1'b1;         // When UART selected

VT52_terminal vt52_inst
(
    .clk(CLK_VIDEO),
    .reset(reset),
    .ce_pix(ce_pix),
    .font_8x8(status[14]),
    .hsync(HSync),
    .vsync(VSync),
    .hblank(HBlank),
    .vblank(VBlank),
    .video(video_out),
    .led(LED_USER),
    .ps2_data(ps2_data),
    .ps2_clk(ps2_clk),
    .uart_tx(uart_tx_wire),
    .uart_rx(uart_rx_wire)
);

endmodule