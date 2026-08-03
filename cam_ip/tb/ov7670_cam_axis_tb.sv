// Full camera IP TB: config + capture + AXIS out (small frame for sim speed).
module ov7670_cam_axis_tb;
  localparam int unsigned CFG_CLK_HZ = 1_000_000;
  localparam int unsigned SCCB_HZ    = 100_000;
  localparam int unsigned IMG_W      = 32;
  localparam int unsigned IMG_H      = 24;

  logic        cfg_clk;
  logic        axis_aclk;
  logic        rst_n;
  logic        cfg_start;
  logic        cfg_done;
  logic        stream_enable;

  logic        ov7670_pwdn;
  logic        ov7670_reset_n;
  logic        ov7670_pclk;
  logic        ov7670_vsync;
  logic        ov7670_href;
  logic [7:0]  ov7670_data;
  logic        ov7670_sioc;
  logic        ov7670_siod;

  logic [15:0] m_axis_tdata;
  logic        m_axis_tvalid;
  logic        m_axis_tready;
  logic        m_axis_tlast;
  logic        m_axis_tuser;

  ov7670_cam_axis #(
    .CFG_CLK_HZ(CFG_CLK_HZ),
    .SCCB_HZ   (SCCB_HZ),
    .IMG_W     (IMG_W),
    .IMG_H     (IMG_H),
    .FIFO_DEPTH(64)
  ) dut (
    .cfg_clk        (cfg_clk),
    .axis_aclk      (axis_aclk),
    .rst_n          (rst_n),
    .cfg_start      (cfg_start),
    .cfg_done       (cfg_done),
    .stream_enable  (stream_enable),
    .ov7670_pwdn    (ov7670_pwdn),
    .ov7670_reset_n (ov7670_reset_n),
    .ov7670_pclk    (ov7670_pclk),
    .ov7670_vsync   (ov7670_vsync),
    .ov7670_href    (ov7670_href),
    .ov7670_data    (ov7670_data),
    .ov7670_sioc    (ov7670_sioc),
    .ov7670_siod    (ov7670_siod),
    .m_axis_tdata   (m_axis_tdata),
    .m_axis_tvalid  (m_axis_tvalid),
    .m_axis_tready  (m_axis_tready),
    .m_axis_tlast   (m_axis_tlast),
    .m_axis_tuser   (m_axis_tuser)
  );
endmodule
