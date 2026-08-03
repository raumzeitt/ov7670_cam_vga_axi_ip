// Thin wrapper so cocotb can use a small IMG_W without rebuilding parameters in SV.
module ov7670_capture_tb;
  logic        pclk;
  logic        rst_n;
  logic        enable;
  logic        vsync;
  logic        href;
  logic [7:0]  data;
  logic [15:0] pixel;
  logic        pixel_valid;
  logic        sof;
  logic        eol;

  ov7670_capture #(
    .IMG_W(32)
  ) dut (
    .pclk       (pclk),
    .rst_n      (rst_n),
    .enable     (enable),
    .vsync      (vsync),
    .href       (href),
    .data       (data),
    .pixel      (pixel),
    .pixel_valid(pixel_valid),
    .sof        (sof),
    .eol        (eol)
  );
endmodule
