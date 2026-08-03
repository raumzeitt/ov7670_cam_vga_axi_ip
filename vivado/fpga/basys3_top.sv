// Basys3 top: OV7670 camera IP → AXI-Stream → VGA framebuffer IP.
//
// Clocks (generated here — not inside the portable IPs):
//   100 MHz board clock → 25 MHz cfg / axis / VGA pixel / camera XCLK
//
// Framebuffer: single bank (QVGA RGB565 fits XC7A35T BRAM); expect tearing
// until a second bank or smaller format is used.
module basys3_top (
  input  logic        clk,           // 100 MHz (W5)
  input  logic        switch,        // SW0 — hold low to stay in reset (V16)
  output logic [15:0] dbg_led,
  output logic [7:0]  dbg_gpio,

  // OV7670 Pmod JB + JC (see constraints/basys3.xdc)
  output logic        ov7670_pwdn,
  input  logic [7:0]  ov7670_pdata,
  output logic        ov7670_reset,
  output logic        ov7670_xclk,
  input  logic        ov7670_href,
  output logic        ov7670_siod,
  input  logic        ov7670_pclk,
  input  logic        ov7670_vsync,
  output logic        ov7670_sioc,

  // VGA connector
  output logic [3:0]  VGA_R,
  output logic [3:0]  VGA_B,
  output logic [3:0]  VGA_G,
  output logic        VGA_HS,
  output logic        VGA_VS
);

  localparam int unsigned IMG_W = 320;
  localparam int unsigned IMG_H = 240;

  // -------------------------------------------------------------------------
  // 100 MHz → 25 MHz (divide by 4)
  // -------------------------------------------------------------------------
  logic [1:0] clk_div_q;
  logic       clk25;

  always_ff @(posedge clk) begin
    clk_div_q <= clk_div_q + 2'b01;
  end

  assign clk25 = clk_div_q[1];

  // -------------------------------------------------------------------------
  // Reset: power-on + user switch (SW0 up = run)
  // -------------------------------------------------------------------------
  logic por_n;
  logic [15:0] por_cnt;

  always_ff @(posedge clk) begin
    if (&por_cnt)
      por_cnt <= por_cnt;
    else
      por_cnt <= por_cnt + 16'd1;
  end

  assign por_n = &por_cnt;

  logic rst_n;
  assign rst_n = por_n & switch;

  // -------------------------------------------------------------------------
  // Camera + VGA control
  // -------------------------------------------------------------------------
  logic cfg_start;
  logic cfg_done;
  logic stream_enable;
  logic [15:0] ctrl_led;

  basys3_ctrl u_ctrl (
    .clk           (clk25),
    .rst_n         (rst_n),
    .cfg_done      (cfg_done),
    .cfg_start     (cfg_start),
    .stream_enable (stream_enable),
    .dbg_led       (ctrl_led)
  );

  // -------------------------------------------------------------------------
  // AXI-Stream cam → VGA
  // -------------------------------------------------------------------------
  logic [15:0] axis_tdata;
  logic        axis_tvalid;
  logic        axis_tready;
  logic        axis_tlast;
  logic        axis_tuser;

  logic cam_pwdn;
  logic cam_reset_n;
  logic cam_sioc;
  logic cam_siod;

  ov7670_cam_axis #(
    .CFG_CLK_HZ (25_000_000),
    .SCCB_HZ    (100_000),
    .IMG_W      (IMG_W),
    .IMG_H      (IMG_H),
    .FIFO_DEPTH (64)
  ) u_cam (
    .cfg_clk       (clk25),
    .axis_aclk     (clk25),
    .rst_n         (rst_n),
    .cfg_start     (cfg_start),
    .cfg_done      (cfg_done),
    .stream_enable (stream_enable),
    .ov7670_pwdn   (cam_pwdn),
    .ov7670_reset_n(cam_reset_n),
    .ov7670_pclk   (ov7670_pclk),
    .ov7670_vsync  (ov7670_vsync),
    .ov7670_href   (ov7670_href),
    .ov7670_data   (ov7670_pdata),
    .ov7670_sioc   (cam_sioc),
    .ov7670_siod   (cam_siod),
    .m_axis_tdata  (axis_tdata),
    .m_axis_tvalid (axis_tvalid),
    .m_axis_tready (axis_tready),
    .m_axis_tlast  (axis_tlast),
    .m_axis_tuser  (axis_tuser)
  );

  assign ov7670_pwdn  = cam_pwdn;
  assign ov7670_reset = cam_reset_n;
  assign ov7670_xclk  = clk25;
  assign ov7670_sioc  = cam_sioc;
  assign ov7670_siod  = cam_siod;

  // -------------------------------------------------------------------------
  // VGA (no AXI-Lite master — display + axis enabled at reset via INIT_*)
  // -------------------------------------------------------------------------
  logic vga_hsync_n;
  logic vga_vsync_n;
  logic [3:0] vga_r;
  logic [3:0] vga_g;
  logic [3:0] vga_b;

  vga_axis_fb #(
    .IMG_W            (IMG_W),
    .IMG_H            (IMG_H),
    .N_BANKS          (1),
    .INIT_DISPLAY_EN  (1'b1),
    .INIT_AXIS_EN     (1'b1),
    .RGB_BITS         (4)
  ) u_vga (
    .axi_aclk      (clk25),
    .vga_clk       (clk25),
    .rst_n         (rst_n),
    .s_axil_awaddr (8'd0),
    .s_axil_awvalid(1'b0),
    .s_axil_awready(),
    .s_axil_wdata  (32'd0),
    .s_axil_wstrb  (4'h0),
    .s_axil_wvalid (1'b0),
    .s_axil_wready(),
    .s_axil_bresp  (),
    .s_axil_bvalid (),
    .s_axil_bready (1'b1),
    .s_axil_araddr (8'd0),
    .s_axil_arvalid(1'b0),
    .s_axil_arready(),
    .s_axil_rdata  (),
    .s_axil_rresp  (),
    .s_axil_rvalid (),
    .s_axil_rready (1'b1),
    .s_axis_tdata  (axis_tdata),
    .s_axis_tvalid (axis_tvalid),
    .s_axis_tready (axis_tready),
    .s_axis_tlast  (axis_tlast),
    .s_axis_tuser  (axis_tuser),
    .vga_hsync_n   (vga_hsync_n),
    .vga_vsync_n   (vga_vsync_n),
    .vga_r         (vga_r),
    .vga_g         (vga_g),
    .vga_b         (vga_b)
  );

  assign VGA_R  = vga_r;
  assign VGA_G  = vga_g;
  assign VGA_B  = vga_b;
  assign VGA_HS = vga_hsync_n;
  assign VGA_VS = vga_vsync_n;

  // -------------------------------------------------------------------------
  // Debug
  // -------------------------------------------------------------------------
  assign dbg_led = ctrl_led;

  assign dbg_gpio[0] = cfg_done;
  assign dbg_gpio[1] = stream_enable;
  assign dbg_gpio[2] = axis_tvalid;
  assign dbg_gpio[3] = axis_tready;
  assign dbg_gpio[7:4] = '0;

endmodule
