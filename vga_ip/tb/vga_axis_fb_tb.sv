// Full VGA IP wrapper with small image + compact timing for cocotb.
module vga_axis_fb_tb;
  logic axi_aclk;
  logic vga_clk;
  logic rst_n;

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

  logic [15:0] s_axis_tdata;
  logic        s_axis_tvalid;
  logic        s_axis_tready;
  logic        s_axis_tlast;
  logic        s_axis_tuser;

  logic        vga_hsync_n;
  logic        vga_vsync_n;
  logic [3:0]  vga_r;
  logic [3:0]  vga_g;
  logic [3:0]  vga_b;

  vga_axis_fb #(
    .IMG_W    (8),
    .IMG_H    (4),
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
  ) dut (
    .axi_aclk(axi_aclk),
    .vga_clk(vga_clk),
    .rst_n(rst_n),
    .s_axil_awaddr(s_axil_awaddr),
    .s_axil_awvalid(s_axil_awvalid),
    .s_axil_awready(s_axil_awready),
    .s_axil_wdata(s_axil_wdata),
    .s_axil_wstrb(s_axil_wstrb),
    .s_axil_wvalid(s_axil_wvalid),
    .s_axil_wready(s_axil_wready),
    .s_axil_bresp(s_axil_bresp),
    .s_axil_bvalid(s_axil_bvalid),
    .s_axil_bready(s_axil_bready),
    .s_axil_araddr(s_axil_araddr),
    .s_axil_arvalid(s_axil_arvalid),
    .s_axil_arready(s_axil_arready),
    .s_axil_rdata(s_axil_rdata),
    .s_axil_rresp(s_axil_rresp),
    .s_axil_rvalid(s_axil_rvalid),
    .s_axil_rready(s_axil_rready),
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .s_axis_tlast(s_axis_tlast),
    .s_axis_tuser(s_axis_tuser),
    .vga_hsync_n(vga_hsync_n),
    .vga_vsync_n(vga_vsync_n),
    .vga_r(vga_r),
    .vga_g(vga_g),
    .vga_b(vga_b)
  );
endmodule
