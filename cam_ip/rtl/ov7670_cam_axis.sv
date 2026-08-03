// OV7670 camera IP with AXI-Stream pixel output (RGB565).
// - Configures the sensor over SCCB
// - Captures pixels on pclk
// - Crosses to axis_aclk via a shallow async FIFO (low latency)
//
// XCLK must be supplied by the board/wrapper (not generated here).
module ov7670_cam_axis #(
  parameter int unsigned CFG_CLK_HZ = 25_000_000,
  parameter int unsigned SCCB_HZ    = 100_000,
  parameter int unsigned IMG_W      = 320,
  parameter int unsigned IMG_H      = 240,
  parameter int unsigned FIFO_DEPTH = 16
) (
  input  logic        cfg_clk,
  input  logic        axis_aclk,
  input  logic        rst_n,

  input  logic        cfg_start,
  output logic        cfg_done,
  input  logic        stream_enable,

  output logic        ov7670_pwdn,
  output logic        ov7670_reset_n,
  input  logic        ov7670_pclk,
  input  logic        ov7670_vsync,
  input  logic        ov7670_href,
  input  logic [7:0]  ov7670_data,
  output logic        ov7670_sioc,
  output logic        ov7670_siod,

  output logic [15:0] m_axis_tdata,
  output logic        m_axis_tvalid,
  input  logic        m_axis_tready,
  output logic        m_axis_tlast,
  output logic        m_axis_tuser
);

  // -------------------------------------------------------------------------
  // Pad controls
  // -------------------------------------------------------------------------
  assign ov7670_pwdn    = 1'b0;
  assign ov7670_reset_n = rst_n;

  logic sioc_oe;
  logic siod_oe;
  // Open-drain model: drive low or release high (board pull-ups in real HW / XDC)
  assign ov7670_sioc = sioc_oe ? 1'b0 : 1'b1;
  assign ov7670_siod = siod_oe ? 1'b0 : 1'b1;

  // -------------------------------------------------------------------------
  // Reset sync (per clock domain)
  // -------------------------------------------------------------------------
  logic cfg_rst_n, pclk_rst_n, axis_rst_n;

  // Simple 2-flop synchronizers (async assert, sync deassert)
  logic [1:0] cfg_rst_sync, pclk_rst_sync, axis_rst_sync;

  always_ff @(posedge cfg_clk or negedge rst_n) begin
    if (!rst_n) cfg_rst_sync <= 2'b00;
    else        cfg_rst_sync <= {cfg_rst_sync[0], 1'b1};
  end
  assign cfg_rst_n = cfg_rst_sync[1];

  always_ff @(posedge ov7670_pclk or negedge rst_n) begin
    if (!rst_n) pclk_rst_sync <= 2'b00;
    else        pclk_rst_sync <= {pclk_rst_sync[0], 1'b1};
  end
  assign pclk_rst_n = pclk_rst_sync[1];

  always_ff @(posedge axis_aclk or negedge rst_n) begin
    if (!rst_n) axis_rst_sync <= 2'b00;
    else        axis_rst_sync <= {axis_rst_sync[0], 1'b1};
  end
  assign axis_rst_n = axis_rst_sync[1];

  // -------------------------------------------------------------------------
  // Configuration path (cfg_clk)
  // -------------------------------------------------------------------------
  logic [7:0]  rom_addr;
  logic [15:0] rom_data;
  logic [7:0]  sccb_reg, sccb_val;
  logic        sccb_start, sccb_ready;

  ov7670_cfg_rom u_rom (
    .clk (cfg_clk),
    .addr(rom_addr),
    .dout(rom_data)
  );

  ov7670_cfg_sequencer #(
    .CLK_HZ(CFG_CLK_HZ)
  ) u_seq (
    .clk        (cfg_clk),
    .rst_n      (cfg_rst_n),
    .start      (cfg_start),
    .sccb_ready (sccb_ready),
    .rom_data   (rom_data),
    .rom_addr   (rom_addr),
    .sccb_reg   (sccb_reg),
    .sccb_val   (sccb_val),
    .sccb_start (sccb_start),
    .done       (cfg_done)
  );

  ov7670_sccb_master #(
    .CLK_HZ (CFG_CLK_HZ),
    .SCCB_HZ(SCCB_HZ)
  ) u_sccb (
    .clk     (cfg_clk),
    .rst_n   (cfg_rst_n),
    .start   (sccb_start),
    .reg_addr(sccb_reg),
    .reg_data(sccb_val),
    .ready   (sccb_ready),
    .sioc_oe (sioc_oe),
    .siod_oe (siod_oe)
  );

  // -------------------------------------------------------------------------
  // Capture (pclk)
  // -------------------------------------------------------------------------
  logic        cap_enable;
  logic [15:0] pixel;
  logic        pixel_valid, sof, eol;

  // Bring stream_enable / cfg_done into pclk domain (level sync)
  logic [1:0] en_sync;
  always_ff @(posedge ov7670_pclk or negedge pclk_rst_n) begin
    if (!pclk_rst_n) en_sync <= 2'b00;
    else             en_sync <= {en_sync[0], stream_enable};
  end
  assign cap_enable = en_sync[1];

  ov7670_capture #(
    .IMG_W(IMG_W)
  ) u_capture (
    .pclk       (ov7670_pclk),
    .rst_n      (pclk_rst_n),
    .enable     (cap_enable),
    .vsync      (ov7670_vsync),
    .href       (ov7670_href),
    .data       (ov7670_data),
    .pixel      (pixel),
    .pixel_valid(pixel_valid),
    .sof        (sof),
    .eol        (eol)
  );

  // -------------------------------------------------------------------------
  // CDC FIFO: {sof, eol, pixel}
  // -------------------------------------------------------------------------
  logic        fifo_full, fifo_empty;
  logic [17:0] fifo_rdata;
  logic        fifo_pop;

  axis_async_fifo #(
    .WIDTH(18),
    .DEPTH(FIFO_DEPTH)
  ) u_fifo (
    .wr_clk  (ov7670_pclk),
    .wr_rst_n(pclk_rst_n),
    .wr_en   (pixel_valid && !fifo_full),
    .wr_data ({sof, eol, pixel}),
    .wr_full (fifo_full),

    .rd_clk  (axis_aclk),
    .rd_rst_n(axis_rst_n),
    .rd_en   (fifo_pop),
    .rd_data (fifo_rdata),
    .rd_empty(fifo_empty)
  );

  // AXI-Stream: present FIFO head; pop on handshake
  assign m_axis_tvalid = !fifo_empty;
  assign m_axis_tdata  = fifo_rdata[15:0];
  assign m_axis_tlast  = fifo_rdata[16];
  assign m_axis_tuser  = fifo_rdata[17];
  assign fifo_pop      = m_axis_tvalid && m_axis_tready;

  // IMG_H reserved for future frame-size checks / AXI-Lite status
  // verilator lint_off UNUSEDPARAM
  // verilator lint_on  UNUSEDPARAM

endmodule
