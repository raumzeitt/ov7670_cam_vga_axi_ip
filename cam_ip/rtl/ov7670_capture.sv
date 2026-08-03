// OV7670 pixel capture (pclk domain)
// Assembles RGB565 from the 8-bit data bus using HREF/VSYNC.
// - SOF pulses with the first valid pixel of a frame
// - EOL pulses with the last valid pixel of each line
module ov7670_capture #(
  parameter int unsigned IMG_W = 320
) (
  input  logic        pclk,
  input  logic        rst_n,
  input  logic        enable,

  input  logic        vsync,
  input  logic        href,
  input  logic [7:0]  data,

  output logic [15:0] pixel,
  output logic        pixel_valid,
  output logic        sof,
  output logic        eol
);

  typedef enum logic {
    WAIT_FRAME = 1'b0,
    RUN        = 1'b1
  } state_t;

  state_t state;

  logic        byte_phase;  // 0: expect high byte, 1: expect low byte
  logic [7:0]  high_byte;
  logic [15:0] x_count;
  logic        need_sof;

  logic vsync_d;
  logic href_d;

  always_ff @(posedge pclk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= WAIT_FRAME;
      byte_phase  <= 1'b0;
      high_byte   <= '0;
      pixel       <= '0;
      pixel_valid <= 1'b0;
      sof         <= 1'b0;
      eol         <= 1'b0;
      x_count     <= '0;
      need_sof    <= 1'b1;
      vsync_d     <= 1'b0;
      href_d      <= 1'b0;
    end else begin
      vsync_d     <= vsync;
      href_d      <= href;
      pixel_valid <= 1'b0;
      sof         <= 1'b0;
      eol         <= 1'b0;

      if (!enable) begin
        state      <= WAIT_FRAME;
        byte_phase <= 1'b0;
        x_count    <= '0;
        need_sof   <= 1'b1;
      end else begin
        unique case (state)
          WAIT_FRAME: begin
            byte_phase <= 1'b0;
            x_count    <= '0;
            need_sof   <= 1'b1;
            // Active frame while VSYNC is low (OV7670 common polarity)
            if (vsync_d && !vsync) begin
              state <= RUN;
            end
          end

          RUN: begin
            // Rising VSYNC ends the frame
            if (!vsync_d && vsync) begin
              state      <= WAIT_FRAME;
              byte_phase <= 1'b0;
              x_count    <= '0;
              need_sof   <= 1'b1;
            end else begin
              // Falling HREF: force byte alignment for next line
              if (href_d && !href) begin
                byte_phase <= 1'b0;
                x_count    <= '0;
              end

              if (href) begin
                if (!byte_phase) begin
                  high_byte  <= data;
                  byte_phase <= 1'b1;
                end else begin
                  pixel       <= {high_byte, data};
                  pixel_valid <= 1'b1;
                  byte_phase  <= 1'b0;

                  if (need_sof) begin
                    sof      <= 1'b1;
                    need_sof <= 1'b0;
                  end

                  if (x_count == IMG_W - 1) begin
                    eol     <= 1'b1;
                    x_count <= '0;
                  end else begin
                    x_count <= x_count + 16'd1;
                  end
                end
              end
            end
          end

          default: state <= WAIT_FRAME;
        endcase
      end
    end
  end

endmodule
