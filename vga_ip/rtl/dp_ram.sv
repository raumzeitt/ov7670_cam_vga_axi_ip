// True dual-port RAM (separate clocks). Inferrable as FPGA BRAM or replaceable
// with an ASIC SRAM macro — no vendor IP primitives.
//
// Write port: wr_clk domain
// Read  port: rd_clk domain, 1-cycle read latency
module dp_ram #(
  parameter int unsigned WIDTH = 16,
  parameter int unsigned DEPTH = 1024,
  parameter int unsigned ADDR_W = $clog2(DEPTH)
) (
  input  logic                 wr_clk,
  input  logic                 wr_en,
  input  logic [ADDR_W-1:0]    wr_addr,
  input  logic [WIDTH-1:0]     wr_data,

  input  logic                 rd_clk,
  input  logic                 rd_en,
  input  logic [ADDR_W-1:0]    rd_addr,
  output logic [WIDTH-1:0]     rd_data
);

  // Soft array: FPGA tools infer BRAM; ASIC flow swaps this module for an SRAM macro.
  logic [WIDTH-1:0] mem [0:DEPTH-1];

  always_ff @(posedge wr_clk) begin
    if (wr_en) begin
      mem[wr_addr] <= wr_data;
    end
  end

  always_ff @(posedge rd_clk) begin
    if (rd_en) begin
      rd_data <= mem[rd_addr];
    end
  end

endmodule
