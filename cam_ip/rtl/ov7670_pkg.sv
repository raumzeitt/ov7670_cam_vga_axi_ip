package ov7670_pkg;
  localparam int unsigned OV7670_SCCB_ID = 8'h42; // write address

  // Default QVGA RGB565
  localparam int unsigned IMG_W = 320;
  localparam int unsigned IMG_H = 240;

  // Config ROM sentinels
  localparam logic [15:0] CFG_END   = 16'hFFFF;
  localparam logic [15:0] CFG_DELAY = 16'hFFF0;
endpackage
