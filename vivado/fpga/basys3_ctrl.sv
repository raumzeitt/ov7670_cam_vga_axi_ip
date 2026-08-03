// Basys3 bring-up sequencer: power-on reset, SCCB config, then stream enable.
// No CPU — VGA display/axis are enabled via vga_axis_fb INIT_* parameters.
module basys3_ctrl #(
  parameter int unsigned POR_CYCLES = 65536,
  parameter int unsigned CFG_TIMEOUT = 25_000_000
) (
  input  logic clk,
  input  logic rst_n,

  input  logic cfg_done,
  output logic cfg_start,
  output logic stream_enable,

  output logic [15:0] dbg_led
);

  typedef enum logic [2:0] {
    ST_POR,
    ST_IDLE,
    ST_CFG,
    ST_RUN,
    ST_ERR
  } state_t;

  state_t state;
  logic [31:0] timer;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state         <= ST_POR;
      timer         <= '0;
      cfg_start     <= 1'b0;
      stream_enable <= 1'b0;
    end else begin
      cfg_start <= 1'b0;

      unique case (state)
        ST_POR: begin
          timer <= timer + 1'b1;
          if (timer >= POR_CYCLES - 1) begin
            state <= ST_IDLE;
            timer <= '0;
          end
        end

        ST_IDLE: begin
          cfg_start <= 1'b1;
          state     <= ST_CFG;
          timer     <= '0;
        end

        ST_CFG: begin
          timer <= timer + 1'b1;
          if (cfg_done) begin
            stream_enable <= 1'b1;
            state         <= ST_RUN;
            timer         <= '0;
          end else if (timer >= CFG_TIMEOUT) begin
            state <= ST_ERR;
          end
        end

        ST_RUN: ; // hold stream_enable

        ST_ERR: ; // latch until reset

        default: state <= ST_POR;
      endcase
    end
  end

  assign dbg_led[0]  = rst_n;
  assign dbg_led[1]  = cfg_done;
  assign dbg_led[2]  = stream_enable;
  assign dbg_led[3]  = (state == ST_RUN);
  assign dbg_led[4]  = (state == ST_ERR);
  assign dbg_led[15:5] = '0;

endmodule
