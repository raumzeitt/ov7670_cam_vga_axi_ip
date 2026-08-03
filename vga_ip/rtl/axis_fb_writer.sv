// AXI-Stream RGB565 sink → frame-buffer writer.
// TUSER = SOF (first pixel of frame), TLAST = EOL (last pixel of line).
module axis_fb_writer #(
  parameter int unsigned IMG_W = 320,
  parameter int unsigned IMG_H = 240
) (
  input  logic        clk,
  input  logic        rst_n,

  input  logic        enable,

  // AXI-Stream slave
  input  logic [15:0] s_axis_tdata,
  input  logic        s_axis_tvalid,
  output logic        s_axis_tready,
  input  logic        s_axis_tlast,
  input  logic        s_axis_tuser,

  // FB write
  output logic        fb_wr_en,
  output logic [$clog2(IMG_W*IMG_H)-1:0] fb_wr_addr,
  output logic [15:0] fb_wr_data,

  // Pulse when a full frame has been written
  output logic        frame_done
);

  localparam int unsigned ADDR_W = $clog2(IMG_W * IMG_H);

  logic [15:0] x_q, y_q;
  logic        in_frame_q;
  logic        frame_done_q;

  logic [15:0] cur_x, cur_y;
  logic        accept;

  wire beat = s_axis_tvalid && s_axis_tready;

  assign s_axis_tready = enable;

  // Address for *this* beat (SOF forces origin)
  always_comb begin
    if (s_axis_tuser) begin
      cur_x = '0;
      cur_y = '0;
    end else begin
      cur_x = x_q;
      cur_y = y_q;
    end
  end

  assign accept     = beat && (s_axis_tuser || in_frame_q);
  assign fb_wr_en   = accept;
  assign fb_wr_data = s_axis_tdata;
  assign fb_wr_addr = ADDR_W'(cur_y * IMG_W + cur_x);
  assign frame_done = frame_done_q;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      x_q          <= '0;
      y_q          <= '0;
      in_frame_q   <= 1'b0;
      frame_done_q <= 1'b0;
    end else begin
      frame_done_q <= 1'b0;

      if (!enable) begin
        x_q        <= '0;
        y_q        <= '0;
        in_frame_q <= 1'b0;
      end else if (accept) begin
        // Advance to next pixel position after this write
        if (s_axis_tlast) begin
          x_q <= '0;
          if (cur_y == IMG_H - 1) begin
            y_q          <= '0;
            in_frame_q   <= 1'b0;
            frame_done_q <= 1'b1;
          end else begin
            y_q        <= cur_y + 16'd1;
            in_frame_q <= 1'b1;
          end
        end else begin
          x_q        <= cur_x + 16'd1;
          y_q        <= cur_y;
          in_frame_q <= 1'b1;
        end
      end
    end
  end

endmodule
