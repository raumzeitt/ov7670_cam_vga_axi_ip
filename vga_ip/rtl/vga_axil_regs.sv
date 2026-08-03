// Minimal AXI4-Lite subordinate for VGA IP control + FB poke (index/data).
// Sync rst_n. No FPGA interconnect IP — plain Lite slave FSM.
module vga_axil_regs #(
  parameter int unsigned IMG_W = 320,
  parameter int unsigned IMG_H = 240
) (
  input  logic        clk,
  input  logic        rst_n,

  // AXI4-Lite slave
  input  logic [7:0]  s_axil_awaddr,
  input  logic        s_axil_awvalid,
  output logic        s_axil_awready,
  input  logic [31:0] s_axil_wdata,
  input  logic [3:0]  s_axil_wstrb,
  input  logic        s_axil_wvalid,
  output logic        s_axil_wready,
  output logic [1:0]  s_axil_bresp,
  output logic        s_axil_bvalid,
  input  logic        s_axil_bready,
  input  logic [7:0]  s_axil_araddr,
  input  logic        s_axil_arvalid,
  output logic        s_axil_arready,
  output logic [31:0] s_axil_rdata,
  output logic [1:0]  s_axil_rresp,
  output logic        s_axil_rvalid,
  input  logic        s_axil_rready,

  // Control / status (axi clock domain)
  output logic        ctrl_display_en,
  output logic        ctrl_axis_en,
  output logic        ctrl_swap_req,     // pulse
  input  logic        status_frame_ready,
  input  logic        status_underrun,
  input  logic        status_wr_bank,
  input  logic        status_rd_bank,
  input  logic        status_swap_pending,

  // Clear sticky status bits
  output logic        status_clear,

  // FB poke write (axi clock)
  output logic        fb_wr_en,
  output logic [$clog2(IMG_W*IMG_H)-1:0] fb_wr_addr,
  output logic [15:0] fb_wr_data
);

  import vga_pkg::*;

  localparam int unsigned ADDR_W = $clog2(IMG_W * IMG_H);

  // -------------------------------------------------------------------------
  // Registers
  // -------------------------------------------------------------------------
  logic        display_en_q;
  logic        axis_en_q;
  logic [ADDR_W-1:0] fb_addr_q;
  logic        swap_req_q;
  logic        status_clear_q;
  logic        fb_wr_en_q;
  logic [15:0] fb_wr_data_q;

  assign ctrl_display_en = display_en_q;
  assign ctrl_axis_en    = axis_en_q;
  assign ctrl_swap_req   = swap_req_q;
  assign status_clear    = status_clear_q;
  assign fb_wr_en        = fb_wr_en_q;
  assign fb_wr_addr      = fb_addr_q;
  assign fb_wr_data      = fb_wr_data_q;

  // -------------------------------------------------------------------------
  // Write channel (AW + W → B), simple accept-both-then-respond
  // -------------------------------------------------------------------------
  logic        aw_fire, w_fire;
  logic [7:0]  awaddr_q;
  logic        have_aw, have_w;
  logic [31:0] wdata_q;
  logic [3:0]  wstrb_q;
  logic        do_write;

  assign aw_fire  = s_axil_awvalid && s_axil_awready;
  assign w_fire   = s_axil_wvalid  && s_axil_wready;
  assign do_write = have_aw && have_w && !s_axil_bvalid;

  assign s_axil_awready = !have_aw && !s_axil_bvalid;
  assign s_axil_wready  = !have_w  && !s_axil_bvalid;
  assign s_axil_bresp   = 2'b00;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      have_aw        <= 1'b0;
      have_w         <= 1'b0;
      awaddr_q       <= '0;
      wdata_q        <= '0;
      wstrb_q        <= '0;
      s_axil_bvalid  <= 1'b0;
      display_en_q   <= 1'b0;
      axis_en_q      <= 1'b0;
      fb_addr_q      <= '0;
      swap_req_q     <= 1'b0;
      status_clear_q <= 1'b0;
      fb_wr_en_q     <= 1'b0;
      fb_wr_data_q   <= '0;
    end else begin
      swap_req_q     <= 1'b0;
      status_clear_q <= 1'b0;
      fb_wr_en_q     <= 1'b0;

      if (aw_fire) begin
        awaddr_q <= s_axil_awaddr;
        have_aw  <= 1'b1;
      end
      if (w_fire) begin
        wdata_q <= s_axil_wdata;
        wstrb_q <= s_axil_wstrb;
        have_w  <= 1'b1;
      end

      if (do_write) begin
        have_aw       <= 1'b0;
        have_w        <= 1'b0;
        s_axil_bvalid <= 1'b1;
        case (awaddr_q)
          REG_CTRL: begin
            if (wstrb_q[0]) begin
              display_en_q   <= wdata_q[0];
              axis_en_q      <= wdata_q[1];
              swap_req_q     <= wdata_q[2];
              status_clear_q <= wdata_q[3];
            end
          end
          REG_FB_ADDR: begin
            if (wstrb_q[0] || wstrb_q[1] || wstrb_q[2] || wstrb_q[3]) begin
              fb_addr_q <= ADDR_W'(wdata_q);
            end
          end
          REG_FB_DATA: begin
            // Write RGB565 in low 16 bits → one FB store
            if (wstrb_q[0] || wstrb_q[1]) begin
              fb_wr_data_q <= wdata_q[15:0];
              fb_wr_en_q   <= 1'b1;
            end
          end
          default: ;
        endcase
      end else if (s_axil_bvalid && s_axil_bready) begin
        s_axil_bvalid <= 1'b0;
      end
    end
  end

  // -------------------------------------------------------------------------
  // Read channel
  // -------------------------------------------------------------------------
  logic [31:0] rdata_c;

  always_comb begin
    case (s_axil_araddr)
      REG_CTRL:     rdata_c = {30'd0, axis_en_q, display_en_q};
      REG_STATUS:   rdata_c = {20'd0,
                               status_swap_pending,
                               status_rd_bank,
                               status_wr_bank,
                               5'd0,
                               status_underrun,
                               status_frame_ready};
      REG_IMG_SIZE: rdata_c = {IMG_H[15:0], IMG_W[15:0]};
      REG_VERSION:  rdata_c = IP_VERSION;
      REG_FB_ADDR:  rdata_c = 32'(fb_addr_q);
      REG_FB_DATA:  rdata_c = 32'(fb_wr_data_q); // last written value
      default:      rdata_c = 32'h0;
    endcase
  end

  assign s_axil_rresp   = 2'b00;
  assign s_axil_arready = !s_axil_rvalid;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      s_axil_rvalid <= 1'b0;
      s_axil_rdata  <= '0;
    end else begin
      if (s_axil_arvalid && s_axil_arready) begin
        s_axil_rvalid <= 1'b1;
        s_axil_rdata  <= rdata_c;
      end else if (s_axil_rvalid && s_axil_rready) begin
        s_axil_rvalid <= 1'b0;
      end
    end
  end

endmodule
