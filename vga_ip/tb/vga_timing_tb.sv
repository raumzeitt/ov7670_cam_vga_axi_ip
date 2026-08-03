// Thin wrapper exposing vga_timing for cocotb.
module vga_timing_tb;
  logic clk;
  logic rst_n;
  logic hsync_n;
  logic vsync_n;
  logic video_active;
  logic frame_start;
  logic [9:0] h_count;
  logic [9:0] v_count;
  logic [9:0] pix_x;
  logic [9:0] pix_y;

  // Compact timing for fast sim (not real VGA)
  vga_timing #(
    .H_VISIBLE(16),
    .H_FP     (2),
    .H_SYNC   (4),
    .H_BP     (2),
    .V_VISIBLE(8),
    .V_FP     (1),
    .V_SYNC   (2),
    .V_BP     (1)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .hsync_n(hsync_n),
    .vsync_n(vsync_n),
    .video_active(video_active),
    .frame_start(frame_start),
    .h_count(h_count),
    .v_count(v_count),
    .pix_x(pix_x),
    .pix_y(pix_y)
  );
endmodule
