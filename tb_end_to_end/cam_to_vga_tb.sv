// End-to-end: OV7670 BFM → ov7670_cam_axis → vga_axis_fb → VGA pins
// Small image + compact VGA timing for sim speed.
module cam_to_vga_tb;
  localparam int unsigned IMG_W = 8;
  localparam int unsigned IMG_H = 4;

  // Clocks / reset
  logic cfg_clk;
  logic axi_aclk;
  logic vga_clk;
  logic rst_n;

  // Camera control
  logic cfg_start;
  logic cfg_done;
  logic stream_enable;

  // OV7670 pads (BFM-driven except SIOx)
  logic        ov7670_pwdn;
  logic        ov7670_reset_n;
  logic        ov7670_pclk;
  logic        ov7670_vsync;
  logic        ov7670_href;
  logic [7:0]  ov7670_data;
  logic        ov7670_sioc;
  logic        ov7670_siod;

  // AXIS cam → VGA
  logic [15:0] axis_tdata;
  logic        axis_tvalid;
  logic        axis_tready;
  logic        axis_tlast;
  logic        axis_tuser;

  // VGA AXI-Lite
  logic [7:0]  s_axil_awaddr;
  logic        s_axil_awvalid;
  logic        s_axil_awready;
  logic [31:0] s_axil_wdata;
  logic [3:0]  s_axil_wstrb;
  logic        s_axil_wvalid;
  logic        s_axil_wready;
  logic [1:0]  s_axil_bresp;
  logic        s_axil_bvalid;
  logic        s_axil_bready;
  logic [7:0]  s_axil_araddr;
  logic        s_axil_arvalid;
  logic        s_axil_arready;
  logic [31:0] s_axil_rdata;
  logic [1:0]  s_axil_rresp;
  logic        s_axil_rvalid;
  logic        s_axil_rready;

  // VGA out
  logic       vga_hsync_n;
  logic       vga_vsync_n;
  logic [3:0] vga_r;
  logic [3:0] vga_g;
  logic [3:0] vga_b;

  ov7670_cam_axis #(
    .CFG_CLK_HZ(10_000_000),
    .SCCB_HZ   (1_000_000),
    .IMG_W     (IMG_W),
    .IMG_H     (IMG_H),
    .FIFO_DEPTH(64)
  ) u_cam (
    .cfg_clk       (cfg_clk),
    .axis_aclk     (axi_aclk),
    .rst_n         (rst_n),
    .cfg_start     (cfg_start),
    .cfg_done      (cfg_done),
    .stream_enable (stream_enable),
    .ov7670_pwdn   (ov7670_pwdn),
    .ov7670_reset_n(ov7670_reset_n),
    .ov7670_pclk   (ov7670_pclk),
    .ov7670_vsync  (ov7670_vsync),
    .ov7670_href   (ov7670_href),
    .ov7670_data   (ov7670_data),
    .ov7670_sioc   (ov7670_sioc),
    .ov7670_siod   (ov7670_siod),
    .m_axis_tdata  (axis_tdata),
    .m_axis_tvalid (axis_tvalid),
    .m_axis_tready (axis_tready),
    .m_axis_tlast  (axis_tlast),
    .m_axis_tuser  (axis_tuser)
  );

  vga_axis_fb #(
    .IMG_W    (IMG_W),
    .IMG_H    (IMG_H),
    .RGB_BITS (4),
    .H_VISIBLE(32),
    .H_FP     (2),
    .H_SYNC   (4),
    .H_BP     (2),
    .V_VISIBLE(16),
    .V_FP     (1),
    .V_SYNC   (2),
    .V_BP     (1),
    .ORIGIN_X (4),
    .ORIGIN_Y (2)
  ) u_vga (
    .axi_aclk      (axi_aclk),
    .vga_clk       (vga_clk),
    .rst_n         (rst_n),
    .s_axil_awaddr (s_axil_awaddr),
    .s_axil_awvalid(s_axil_awvalid),
    .s_axil_awready(s_axil_awready),
    .s_axil_wdata  (s_axil_wdata),
    .s_axil_wstrb  (s_axil_wstrb),
    .s_axil_wvalid (s_axil_wvalid),
    .s_axil_wready (s_axil_wready),
    .s_axil_bresp  (s_axil_bresp),
    .s_axil_bvalid (s_axil_bvalid),
    .s_axil_bready (s_axil_bready),
    .s_axil_araddr (s_axil_araddr),
    .s_axil_arvalid(s_axil_arvalid),
    .s_axil_arready(s_axil_arready),
    .s_axil_rdata  (s_axil_rdata),
    .s_axil_rresp  (s_axil_rresp),
    .s_axil_rvalid (s_axil_rvalid),
    .s_axil_rready (s_axil_rready),
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
endmodule
