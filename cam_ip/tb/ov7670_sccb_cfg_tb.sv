// Config path TB: ROM + sequencer + SCCB master with simulated pull-ups.
// Uses a small CLK_HZ so the post-reset delay is short in simulation.
module ov7670_sccb_cfg_tb;
  localparam int unsigned CLK_HZ  = 10_000;
  localparam int unsigned SCCB_HZ = 2_500;

  logic clk;
  logic rst_n;
  logic start;
  logic done;

  logic sioc_oe;
  logic siod_oe;
  logic sioc;
  logic siod;

  // Strong pull-up model for open-drain SCCB
  assign sioc = sioc_oe ? 1'b0 : 1'b1;
  assign siod = siod_oe ? 1'b0 : 1'b1;

  logic [7:0]  rom_addr;
  logic [15:0] rom_data;
  logic [7:0]  sccb_reg;
  logic [7:0]  sccb_val;
  logic        sccb_start;
  logic        sccb_ready;

  ov7670_cfg_rom u_rom (
    .clk (clk),
    .addr(rom_addr),
    .dout(rom_data)
  );

  ov7670_cfg_sequencer #(
    .CLK_HZ(CLK_HZ)
  ) u_seq (
    .clk        (clk),
    .rst_n      (rst_n),
    .start      (start),
    .sccb_ready (sccb_ready),
    .rom_data   (rom_data),
    .rom_addr   (rom_addr),
    .sccb_reg   (sccb_reg),
    .sccb_val   (sccb_val),
    .sccb_start (sccb_start),
    .done       (done)
  );

  ov7670_sccb_master #(
    .CLK_HZ (CLK_HZ),
    .SCCB_HZ(SCCB_HZ)
  ) u_sccb (
    .clk     (clk),
    .rst_n   (rst_n),
    .start   (sccb_start),
    .reg_addr(sccb_reg),
    .reg_data(sccb_val),
    .ready   (sccb_ready),
    .sioc_oe (sioc_oe),
    .siod_oe (siod_oe)
  );
endmodule
