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

  logic [ADDR_W:0] wr_ptr_bin, wr_ptr_gray, wr_ptr_gray_rd;
  logic [ADDR_W:0] rd_ptr_bin, rd_ptr_gray, rd_ptr_gray_wr;
  logic [ADDR_W:0] wr_ptr_bin_next, wr_ptr_gray_next;
  logic [ADDR_W:0] rd_ptr_bin_next, rd_ptr_gray_next;

  function automatic logic [ADDR_W:0] bin2gray(input logic [ADDR_W:0] b);
    return (b >> 1) ^ b;
  endfunction

  function automatic logic [ADDR_W:0] gray2bin(input logic [ADDR_W:0] g);
    logic [ADDR_W:0] b;
    b[ADDR_W] = g[ADDR_W];
    for (int i = ADDR_W - 1; i >= 0; i--) begin
      b[i] = b[i+1] ^ g[i];
    end
    return b;
  endfunction

  // -------------------------------------------------------------------------
  // Write domain
  // -------------------------------------------------------------------------
  assign wr_ptr_bin_next  = wr_ptr_bin + {{ADDR_W{1'b0}}, (wr_en && !wr_full)};
  assign wr_ptr_gray_next = bin2gray(wr_ptr_bin_next);

  always_ff @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
      wr_ptr_bin  <= '0;
      wr_ptr_gray <= '0;
    end else begin
      wr_ptr_bin  <= wr_ptr_bin_next;
      wr_ptr_gray <= wr_ptr_gray_next;
    end
  end

  always_ff @(posedge wr_clk) begin
    if (wr_en && !wr_full) begin
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

  assign wr_full = (wr_ptr_gray_next == {~rd_ptr_gray_wr[ADDR_W:ADDR_W-1],
                                         rd_ptr_gray_wr[ADDR_W-2:0]});

  // -------------------------------------------------------------------------
  // Read domain
  // -------------------------------------------------------------------------
  assign rd_ptr_bin_next  = rd_ptr_bin + {{ADDR_W{1'b0}}, (rd_en && !rd_empty)};
  assign rd_ptr_gray_next = bin2gray(rd_ptr_bin_next);

  always_ff @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
      rd_ptr_bin  <= '0;
      rd_ptr_gray <= '0;
    end else begin
      rd_ptr_bin  <= rd_ptr_bin_next;
      rd_ptr_gray <= rd_ptr_gray_next;
    end
  end

  assign rd_data = mem[rd_ptr_bin[ADDR_W-1:0]];

  logic [ADDR_W:0] wr_ptr_gray_rd_meta;
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
