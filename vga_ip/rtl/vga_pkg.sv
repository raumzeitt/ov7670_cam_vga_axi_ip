package vga_pkg;
  // 640x480@60Hz pixel timing (clock ~25.0 / 25.175 MHz supplied externally)
  localparam int unsigned VGA_H_VISIBLE = 640;
  localparam int unsigned VGA_H_FP      = 16;
  localparam int unsigned VGA_H_SYNC    = 96;
  localparam int unsigned VGA_H_BP      = 48;
  localparam int unsigned VGA_H_TOTAL   = VGA_H_VISIBLE + VGA_H_FP + VGA_H_SYNC + VGA_H_BP; // 800

  localparam int unsigned VGA_V_VISIBLE = 480;
  localparam int unsigned VGA_V_FP      = 10;
  localparam int unsigned VGA_V_SYNC    = 2;
  localparam int unsigned VGA_V_BP      = 33;
  localparam int unsigned VGA_V_TOTAL   = VGA_V_VISIBLE + VGA_V_FP + VGA_V_SYNC + VGA_V_BP; // 525

  // Default framebuffer (QVGA RGB565) — override via IP parameters
  localparam int unsigned IMG_W = 320;
  localparam int unsigned IMG_H = 240;

  // AXI-Lite register offsets
  localparam logic [7:0] REG_CTRL     = 8'h00;
  localparam logic [7:0] REG_STATUS   = 8'h04;
  localparam logic [7:0] REG_IMG_SIZE = 8'h08;
  localparam logic [7:0] REG_VERSION  = 8'h0C;
  localparam logic [7:0] REG_FB_ADDR  = 8'h10;
  localparam logic [7:0] REG_FB_DATA  = 8'h14;

  localparam logic [31:0] IP_VERSION = 32'h0001_0000;
endpackage
