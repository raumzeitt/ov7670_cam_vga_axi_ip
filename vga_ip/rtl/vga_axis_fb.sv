// VGA output IP: AXI-Stream pixel sink + AXI-Lite control → double-buffered FB → VGA.
//
// ASIC-ready:
//  - Sync active-low rst_n
//  - Clocks supplied externally (axi_aclk, vga_clk) — no PLLs inside
//  - Inferred dual-port RAM (replace dp_ram with SRAM macro in ASIC flow)
//  - No vendor primitives / FPGA interconnect IP
//
// AXIS: TDATA=RGB565, TUSER=SOF, TLAST=EOL (matches ov7670_cam_axis)
// VGA:  active-low HSYNC/VSYNC; RGB_BITS-wide channels (4 for Basys3)
module vga_axis_fb #(
  parameter int unsigned IMG_W      = 320,
  parameter int unsigned IMG_H      = 240,
  parameter int unsigned RGB_BITS   = 4,
  parameter int unsigned H_VISIBLE  = 640,
  parameter int unsigned H_FP       = 16,
  parameter int unsigned H_SYNC     = 96,
  parameter int unsigned H_BP       = 48,
  parameter int unsigned V_VISIBLE  = 480,
  parameter int unsigned V_FP       = 10,
  parameter int unsigned V_SYNC     = 2,
  parameter int unsigned V_BP       = 33,
  // Center image in visible area
  parameter int unsigned ORIGIN_X   = (H_VISIBLE > IMG_W) ? (H_VISIBLE - IMG_W) / 2 : 0,
  parameter int unsigned ORIGIN_Y   = (V_VISIBLE > IMG_H) ? (V_VISIBLE - IMG_H) / 2 : 0
) (
  input  logic                    axi_aclk,
  input  logic                    vga_clk,
  input  logic                    rst_n,

  // AXI4-Lite slave (control + FB poke)
  input  logic [7:0]              s_axil_awaddr,
  input  logic                    s_axil_awvalid,
  output logic                    s_axil_awready,
  input  logic [31:0]             s_axil_wdata,
  input  logic [3:0]              s_axil_wstrb,
  input  logic                    s_axil_wvalid,
  output logic                    s_axil_wready,
  output logic [1:0]              s_axil_bresp,
  output logic                    s_axil_bvalid,
  input  logic                    s_axil_bready,
  input  logic [7:0]              s_axil_araddr,
  input  logic                    s_axil_arvalid,
  output logic                    s_axil_arready,
  output logic [31:0]             s_axil_rdata,
  output logic [1:0]              s_axil_rresp,
  output logic                    s_axil_rvalid,
  input  logic                    s_axil_rready,

  // AXI-Stream slave (video in)
  input  logic [15:0]             s_axis_tdata,
  input  logic                    s_axis_tvalid,
  output logic                    s_axis_tready,
  input  logic                    s_axis_tlast,
  input  logic                    s_axis_tuser,

  // VGA out
  output logic                    vga_hsync_n,
  output logic                    vga_vsync_n,
  output logic [RGB_BITS-1:0]     vga_r,
  output logic [RGB_BITS-1:0]     vga_g,
  output logic [RGB_BITS-1:0]     vga_b
);

  localparam int unsigned ADDR_W = $clog2(IMG_W * IMG_H);

  // ---- shared control / status ----
  logic        ctrl_display_en;
  logic        ctrl_axis_en;
  logic        ctrl_swap_req;
  logic        status_clear;
  logic        frame_ready_q;
  logic        underrun_q;
  logic        wr_bank_q;
  logic        rd_bank_q;
  logic        swap_pending_q;

  logic        axil_fb_wr_en;
  logic [ADDR_W-1:0] axil_fb_wr_addr;
  logic [15:0] axil_fb_wr_data;

  logic        axis_fb_wr_en;
  logic [ADDR_W-1:0] axis_fb_wr_addr;
  logic [15:0] axis_fb_wr_data;
  logic        axis_frame_done;

  logic              fb_wr_en;
  logic [ADDR_W-1:0] fb_wr_addr;
  logic [15:0]       fb_wr_data;

  logic        swap_req_axi;
  logic        swap_ack_axi;
  logic        swap_ack_meta;
  logic        display_en_vga, display_en_meta;
  logic        rd_bank_vga;
  logic        swap_req_vga, swap_req_meta;
  logic        swap_ack_vga;
  logic        wr_bank_meta, wr_bank_sync;

  logic [15:0]       fb_rd_data;
  logic              fb_rd_en;
  logic [ADDR_W-1:0] fb_rd_addr;

  logic        video_active;
  logic        frame_start;
  logic [9:0]  pix_x, pix_y;
  logic        in_window;
  logic        in_window_d;
  logic        video_active_d;
  logic        display_en_d;
  logic        hsync_raw, vsync_raw;
  logic        hsync_d, vsync_d;
  logic [RGB_BITS-1:0] r_c, g_c, b_c;

  // -------------------------------------------------------------------------
  // VGA timing (needed early for frame_start used by bank-swap CDC)
  // -------------------------------------------------------------------------
  vga_timing #(
    .H_VISIBLE(H_VISIBLE),
    .H_FP     (H_FP),
    .H_SYNC   (H_SYNC),
    .H_BP     (H_BP),
    .V_VISIBLE(V_VISIBLE),
    .V_FP     (V_FP),
    .V_SYNC   (V_SYNC),
    .V_BP     (V_BP)
  ) u_timing (
    .clk          (vga_clk),
    .rst_n        (rst_n),
    .hsync_n      (hsync_raw),
    .vsync_n      (vsync_raw),
    .video_active (video_active),
    .frame_start  (frame_start),
    .h_count      (),
    .v_count      (),
    .pix_x        (pix_x),
    .pix_y        (pix_y)
  );

  // -------------------------------------------------------------------------
  // AXI-Lite registers
  // -------------------------------------------------------------------------
  vga_axil_regs #(
    .IMG_W(IMG_W),
    .IMG_H(IMG_H)
  ) u_regs (
    .clk                 (axi_aclk),
    .rst_n               (rst_n),
    .s_axil_awaddr       (s_axil_awaddr),
    .s_axil_awvalid      (s_axil_awvalid),
    .s_axil_awready      (s_axil_awready),
    .s_axil_wdata        (s_axil_wdata),
    .s_axil_wstrb        (s_axil_wstrb),
    .s_axil_wvalid       (s_axil_wvalid),
    .s_axil_wready       (s_axil_wready),
    .s_axil_bresp        (s_axil_bresp),
    .s_axil_bvalid       (s_axil_bvalid),
    .s_axil_bready       (s_axil_bready),
    .s_axil_araddr       (s_axil_araddr),
    .s_axil_arvalid      (s_axil_arvalid),
    .s_axil_arready      (s_axil_arready),
    .s_axil_rdata        (s_axil_rdata),
    .s_axil_rresp        (s_axil_rresp),
    .s_axil_rvalid       (s_axil_rvalid),
    .s_axil_rready       (s_axil_rready),
    .ctrl_display_en     (ctrl_display_en),
    .ctrl_axis_en        (ctrl_axis_en),
    .ctrl_swap_req       (ctrl_swap_req),
    .status_frame_ready  (frame_ready_q),
    .status_underrun     (underrun_q),
    .status_wr_bank      (wr_bank_q),
    .status_rd_bank      (rd_bank_q),
    .status_swap_pending (swap_pending_q),
    .status_clear        (status_clear),
    .fb_wr_en            (axil_fb_wr_en),
    .fb_wr_addr          (axil_fb_wr_addr),
    .fb_wr_data          (axil_fb_wr_data)
  );

  // -------------------------------------------------------------------------
  // AXIS → FB
  // -------------------------------------------------------------------------
  axis_fb_writer #(
    .IMG_W(IMG_W),
    .IMG_H(IMG_H)
  ) u_axis_wr (
    .clk           (axi_aclk),
    .rst_n         (rst_n),
    .enable        (ctrl_axis_en),
    .s_axis_tdata  (s_axis_tdata),
    .s_axis_tvalid (s_axis_tvalid),
    .s_axis_tready (s_axis_tready),
    .s_axis_tlast  (s_axis_tlast),
    .s_axis_tuser  (s_axis_tuser),
    .fb_wr_en      (axis_fb_wr_en),
    .fb_wr_addr    (axis_fb_wr_addr),
    .fb_wr_data    (axis_fb_wr_data),
    .frame_done    (axis_frame_done)
  );

  always_comb begin
    if (axis_fb_wr_en) begin
      fb_wr_en   = 1'b1;
      fb_wr_addr = axis_fb_wr_addr;
      fb_wr_data = axis_fb_wr_data;
    end else begin
      fb_wr_en   = axil_fb_wr_en;
      fb_wr_addr = axil_fb_wr_addr;
      fb_wr_data = axil_fb_wr_data;
    end
  end

  // -------------------------------------------------------------------------
  // Bank swap (request in axi domain, commit on VGA frame_start)
  // -------------------------------------------------------------------------
  always_ff @(posedge axi_aclk) begin
    if (!rst_n) begin
      wr_bank_q      <= 1'b0;
      rd_bank_q      <= 1'b1;
      frame_ready_q  <= 1'b0;
      underrun_q     <= 1'b0;
      swap_req_axi   <= 1'b0;
      swap_pending_q <= 1'b0;
      swap_ack_meta  <= 1'b0;
      swap_ack_axi   <= 1'b0;
    end else begin
      swap_ack_meta <= swap_ack_vga;
      swap_ack_axi  <= swap_ack_meta;

      if (status_clear) begin
        frame_ready_q <= 1'b0;
        underrun_q    <= 1'b0;
      end

      if (axis_frame_done) begin
        frame_ready_q  <= 1'b1;
        swap_req_axi   <= 1'b1;
        swap_pending_q <= 1'b1;
      end else if (ctrl_swap_req) begin
        swap_req_axi   <= 1'b1;
        swap_pending_q <= 1'b1;
      end

      if (swap_req_axi && swap_ack_axi) begin
        swap_req_axi   <= 1'b0;
        swap_pending_q <= 1'b0;
        wr_bank_q      <= ~wr_bank_q;
        rd_bank_q      <= wr_bank_q;
      end
    end
  end

  always_ff @(posedge vga_clk) begin
    if (!rst_n) begin
      wr_bank_meta    <= 1'b0;
      wr_bank_sync    <= 1'b0;
      swap_req_meta   <= 1'b0;
      swap_req_vga    <= 1'b0;
      display_en_meta <= 1'b0;
      display_en_vga  <= 1'b0;
      rd_bank_vga     <= 1'b1;
      swap_ack_vga    <= 1'b0;
    end else begin
      wr_bank_meta    <= wr_bank_q;
      wr_bank_sync    <= wr_bank_meta;
      swap_req_meta   <= swap_req_axi;
      swap_req_vga    <= swap_req_meta;
      display_en_meta <= ctrl_display_en;
      display_en_vga  <= display_en_meta;

      if (frame_start && swap_req_vga && !swap_ack_vga) begin
        rd_bank_vga  <= wr_bank_sync;
        swap_ack_vga <= 1'b1;
      end else if (!swap_req_vga) begin
        swap_ack_vga <= 1'b0;
      end
    end
  end

  // -------------------------------------------------------------------------
  // Frame buffer
  // -------------------------------------------------------------------------
  frame_buffer #(
    .IMG_W  (IMG_W),
    .IMG_H  (IMG_H),
    .PIX_W  (16),
    .N_BANKS(2)
  ) u_fb (
    .wr_clk  (axi_aclk),
    .wr_en   (fb_wr_en),
    .wr_bank (wr_bank_q),
    .wr_addr (fb_wr_addr),
    .wr_data (fb_wr_data),
    .rd_clk  (vga_clk),
    .rd_en   (fb_rd_en),
    .rd_bank (rd_bank_vga),
    .rd_addr (fb_rd_addr),
    .rd_data (fb_rd_data)
  );

  // -------------------------------------------------------------------------
  // Pixel fetch (1-cycle RAM latency) + RGB565 expand
  // -------------------------------------------------------------------------
  assign in_window = video_active &&
                     (pix_x >= ORIGIN_X) && (pix_x < ORIGIN_X + IMG_W) &&
                     (pix_y >= ORIGIN_Y) && (pix_y < ORIGIN_Y + IMG_H);

  assign fb_rd_en   = in_window && display_en_vga;
  assign fb_rd_addr = ADDR_W'((pix_y - ORIGIN_Y) * IMG_W + (pix_x - ORIGIN_X));

  // Delay window/sync by 1 cycle so they align with dp_ram's registered read data.
  always_ff @(posedge vga_clk) begin
    if (!rst_n) begin
      in_window_d    <= 1'b0;
      video_active_d <= 1'b0;
      display_en_d   <= 1'b0;
      hsync_d        <= 1'b1;
      vsync_d        <= 1'b1;
    end else begin
      in_window_d    <= in_window;
      video_active_d <= video_active;
      display_en_d   <= display_en_vga;
      hsync_d        <= hsync_raw;
      vsync_d        <= vsync_raw;
    end
  end

  // fb_rd_data is valid with *_d (1-cycle RAM latency)
  // RGB565 → RGB_BITS (take MSBs of each channel)
  always_comb begin
    if (video_active_d && display_en_d && in_window_d) begin
      r_c = fb_rd_data[15:16-RGB_BITS];
      g_c = fb_rd_data[10:11-RGB_BITS];
      b_c = fb_rd_data[4:5-RGB_BITS];
    end else begin
      r_c = '0;
      g_c = '0;
      b_c = '0;
    end
  end

  // Extra output register; delay sync the same amount so RGB stays aligned
  always_ff @(posedge vga_clk) begin
    if (!rst_n) begin
      vga_r       <= '0;
      vga_g       <= '0;
      vga_b       <= '0;
      vga_hsync_n <= 1'b1;
      vga_vsync_n <= 1'b1;
    end else begin
      vga_r       <= r_c;
      vga_g       <= g_c;
      vga_b       <= b_c;
      vga_hsync_n <= hsync_d;
      vga_vsync_n <= vsync_d;
    end
  end

endmodule
