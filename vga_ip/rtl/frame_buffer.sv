// Double-buffered RGB565 frame store.
// Write on wr_clk (AXIS / AXI-Lite); read on rd_clk (VGA). Pure SV dual-port RAM.
module frame_buffer #(
  parameter int unsigned IMG_W   = 320,
  parameter int unsigned IMG_H   = 240,
  parameter int unsigned PIX_W   = 16,
  parameter int unsigned N_BANKS = 2
) (
  // Write port (axi clock domain)
  input  logic                              wr_clk,
  input  logic                              wr_en,
  input  logic [$clog2(N_BANKS)-1:0]        wr_bank,
  input  logic [$clog2(IMG_W*IMG_H)-1:0]    wr_addr,
  input  logic [PIX_W-1:0]                  wr_data,

  // Read port (vga clock domain), 1-cycle latency
  input  logic                              rd_clk,
  input  logic                              rd_en,
  input  logic [$clog2(N_BANKS)-1:0]        rd_bank,
  input  logic [$clog2(IMG_W*IMG_H)-1:0]    rd_addr,
  output logic [PIX_W-1:0]                  rd_data
);

  localparam int unsigned DEPTH      = IMG_W * IMG_H;
  localparam int unsigned PIX_ADDR_W = $clog2(DEPTH);
  localparam int unsigned BANK_W     = $clog2(N_BANKS);
  localparam int unsigned MEM_DEPTH  = N_BANKS * DEPTH;
  localparam int unsigned MEM_ADDR_W = $clog2(MEM_DEPTH);

  // Linear address: bank * DEPTH + pixel (safe for non-power-of-two frames)
  logic [MEM_ADDR_W-1:0] wr_mem_addr;
  logic [MEM_ADDR_W-1:0] rd_mem_addr;

  assign wr_mem_addr = MEM_ADDR_W'(wr_bank * DEPTH + wr_addr);
  assign rd_mem_addr = MEM_ADDR_W'(rd_bank * DEPTH + rd_addr);

  dp_ram #(
    .WIDTH (PIX_W),
    .DEPTH (MEM_DEPTH),
    .ADDR_W(MEM_ADDR_W)
  ) u_ram (
    .wr_clk  (wr_clk),
    .wr_en   (wr_en),
    .wr_addr (wr_mem_addr),
    .wr_data (wr_data),
    .rd_clk  (rd_clk),
    .rd_en   (rd_en),
    .rd_addr (rd_mem_addr),
    .rd_data (rd_data)
  );

endmodule
