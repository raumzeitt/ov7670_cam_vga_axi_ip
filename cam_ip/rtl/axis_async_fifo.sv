// Dual-clock async FIFO (gray pointers). Pure SV — FPGA/ASIC friendly.
module axis_async_fifo #(
  parameter int unsigned WIDTH = 18,
  parameter int unsigned DEPTH = 16  // power of 2
) (
  input  logic             wr_clk,
  input  logic             wr_rst_n,
  input  logic             wr_en,
  input  logic [WIDTH-1:0] wr_data,
  output logic             wr_full,

  input  logic             rd_clk,
  input  logic             rd_rst_n,
  input  logic             rd_en,
  output logic [WIDTH-1:0] rd_data,
  output logic             rd_empty
);

  localparam int unsigned ADDR_W = $clog2(DEPTH);

  logic [WIDTH-1:0] mem [0:DEPTH-1];

  logic [ADDR_W:0] wr_ptr_bin, wr_ptr_gray;
  logic [ADDR_W:0] rd_ptr_bin, rd_ptr_gray, rd_ptr_gray_wr;
  logic [ADDR_W:0] wr_ptr_bin_inc, wr_ptr_gray_inc;
  logic [ADDR_W:0] rd_ptr_bin_inc, rd_ptr_gray_inc;
  logic            wr_en_safe, rd_en_safe;

  function automatic logic [ADDR_W:0] bin2gray(input logic [ADDR_W:0] b);
    return (b >> 1) ^ b;
  endfunction

  // -------------------------------------------------------------------------
  // Write domain
  // -------------------------------------------------------------------------
  // Full before accept: compare gray(wr_ptr+1) vs synced rd (no wr_en in loop)
  assign wr_ptr_bin_inc  = wr_ptr_bin + 1'b1;
  assign wr_ptr_gray_inc = bin2gray(wr_ptr_bin_inc);
  assign wr_en_safe      = wr_en && !wr_full;

  always_ff @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
      wr_ptr_bin  <= '0;
      wr_ptr_gray <= '0;
    end else if (wr_en_safe) begin
      wr_ptr_bin  <= wr_ptr_bin_inc;
      wr_ptr_gray <= wr_ptr_gray_inc;
    end
  end

  always_ff @(posedge wr_clk) begin
    if (wr_en_safe) begin
      mem[wr_ptr_bin[ADDR_W-1:0]] <= wr_data;
    end
  end

  // Synchronize read pointer into write domain
  logic [ADDR_W:0] rd_ptr_gray_wr_meta;
  always_ff @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
      rd_ptr_gray_wr_meta <= '0;
      rd_ptr_gray_wr      <= '0;
    end else begin
      rd_ptr_gray_wr_meta <= rd_ptr_gray;
      rd_ptr_gray_wr      <= rd_ptr_gray_wr_meta;
    end
  end

  assign wr_full = (wr_ptr_gray_inc == {~rd_ptr_gray_wr[ADDR_W:ADDR_W-1],
                                        rd_ptr_gray_wr[ADDR_W-2:0]});

  // -------------------------------------------------------------------------
  // Read domain
  // -------------------------------------------------------------------------
  assign rd_ptr_bin_inc  = rd_ptr_bin + 1'b1;
  assign rd_ptr_gray_inc = bin2gray(rd_ptr_bin_inc);
  assign rd_en_safe      = rd_en && !rd_empty;

  always_ff @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
      rd_ptr_bin  <= '0;
      rd_ptr_gray <= '0;
    end else if (rd_en_safe) begin
      rd_ptr_bin  <= rd_ptr_bin_inc;
      rd_ptr_gray <= rd_ptr_gray_inc;
    end
  end

  assign rd_data = mem[rd_ptr_bin[ADDR_W-1:0]];

  logic [ADDR_W:0] wr_ptr_gray_rd_meta, wr_ptr_gray_rd;
  always_ff @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
      wr_ptr_gray_rd_meta <= '0;
      wr_ptr_gray_rd      <= '0;
    end else begin
      wr_ptr_gray_rd_meta <= wr_ptr_gray;
      wr_ptr_gray_rd      <= wr_ptr_gray_rd_meta;
    end
  end

  assign rd_empty = (rd_ptr_gray == wr_ptr_gray_rd);

endmodule
