// VGA timing generator (default 640x480@60).
// Pure SV, sync active-low rst_n. Pixel clock supplied externally.
// Sync pulses are active-low (Basys3 / Digilent VGA).
module vga_timing #(
  parameter int unsigned H_VISIBLE = 640,
  parameter int unsigned H_FP      = 16,
  parameter int unsigned H_SYNC    = 96,
  parameter int unsigned H_BP      = 48,
  parameter int unsigned V_VISIBLE = 480,
  parameter int unsigned V_FP      = 10,
  parameter int unsigned V_SYNC    = 2,
  parameter int unsigned V_BP      = 33
) (
  input  logic        clk,
  input  logic        rst_n,

  output logic        hsync_n,
  output logic        vsync_n,
  output logic        video_active,
  output logic        frame_start,   // 1-cycle pulse at start of vertical blank / new frame
  output logic [9:0]  h_count,
  output logic [9:0]  v_count,
  output logic [9:0]  pix_x,         // 0 .. H_VISIBLE-1 when active, else 0
  output logic [9:0]  pix_y
);

  localparam int unsigned H_TOTAL = H_VISIBLE + H_FP + H_SYNC + H_BP;
  localparam int unsigned V_TOTAL = V_VISIBLE + V_FP + V_SYNC + V_BP;
  localparam int unsigned H_SYNC_START = H_VISIBLE + H_FP;
  localparam int unsigned H_SYNC_END   = H_SYNC_START + H_SYNC;
  localparam int unsigned V_SYNC_START = V_VISIBLE + V_FP;
  localparam int unsigned V_SYNC_END   = V_SYNC_START + V_SYNC;

  logic [9:0] h_q, v_q;
  logic       h_last;
  logic       frame_start_q;

  assign h_last = (h_q == H_TOTAL - 1);

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      h_q <= '0;
      v_q <= '0;
      frame_start_q <= 1'b0;
    end else begin
      frame_start_q <= 1'b0;
      if (h_last) begin
        h_q <= '0;
        if (v_q == V_TOTAL - 1) begin
          v_q <= '0;
          frame_start_q <= 1'b1;
        end else begin
          v_q <= v_q + 10'd1;
        end
      end else begin
        h_q <= h_q + 10'd1;
      end
    end
  end

  assign h_count     = h_q;
  assign v_count     = v_q;
  assign frame_start = frame_start_q;

  // Active-low sync (pulse during sync interval)
  assign hsync_n = ~((h_q >= H_SYNC_START) && (h_q < H_SYNC_END));
  assign vsync_n = ~((v_q >= V_SYNC_START) && (v_q < V_SYNC_END));

  assign video_active = (h_q < H_VISIBLE) && (v_q < V_VISIBLE);
  assign pix_x = video_active ? h_q : '0;
  assign pix_y = video_active ? v_q : '0;

endmodule
