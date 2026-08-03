// Walks the config ROM and issues SCCB writes / delays until CFG_END.
module ov7670_cfg_sequencer #(
  parameter int unsigned CLK_HZ = 25_000_000
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic        sccb_ready,
  input  logic [15:0] rom_data,
  output logic [7:0]  rom_addr,
  output logic [7:0]  sccb_reg,
  output logic [7:0]  sccb_val,
  output logic        sccb_start,
  output logic        done
);

  import ov7670_pkg::*;

  typedef enum logic [2:0] {
    ST_IDLE       = 3'd0,
    ST_SEND       = 3'd1,
    ST_WAIT_BUSY  = 3'd2,
    ST_WAIT_READY = 3'd3,
    ST_DELAY      = 3'd4,
    ST_DONE       = 3'd5
  } state_t;

  state_t state;
  logic [31:0] timer;
  logic        start_q;

  // 10 ms delay after soft-reset marker
  localparam int unsigned DELAY_CYCLES = (CLK_HZ / 100) > 0 ? (CLK_HZ / 100) : 1;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= ST_IDLE;
      timer      <= '0;
      rom_addr   <= '0;
      sccb_reg   <= '0;
      sccb_val   <= '0;
      sccb_start <= 1'b0;
      done       <= 1'b0;
      start_q    <= 1'b0;
    end else begin
      start_q    <= start;
      sccb_start <= 1'b0;

      unique case (state)
        ST_IDLE: begin
          rom_addr <= '0;
          if (start && !start_q) begin
            done  <= 1'b0;
            state <= ST_SEND;
          end
        end

        ST_SEND: begin
          unique case (rom_data)
            CFG_END: begin
              state <= ST_DONE;
            end
            CFG_DELAY: begin
              timer    <= DELAY_CYCLES;
              rom_addr <= rom_addr + 8'd1;
              state    <= ST_DELAY;
            end
            default: begin
              if (sccb_ready) begin
                sccb_reg   <= rom_data[15:8];
                sccb_val   <= rom_data[7:0];
                sccb_start <= 1'b1;
                rom_addr   <= rom_addr + 8'd1;
                state      <= ST_WAIT_BUSY;
              end
            end
          endcase
        end

        // Wait until SCCB accepts the transaction
        ST_WAIT_BUSY: begin
          if (!sccb_ready) begin
            state <= ST_WAIT_READY;
          end
        end

        // Wait until SCCB finishes
        ST_WAIT_READY: begin
          if (sccb_ready) begin
            state <= ST_SEND;
          end
        end

        ST_DELAY: begin
          if (timer == 0) begin
            state <= ST_SEND;
          end else begin
            timer <= timer - 1;
          end
        end

        ST_DONE: begin
          done  <= 1'b1;
          state <= ST_IDLE;
        end

        default: state <= ST_IDLE;
      endcase
    end
  end

endmodule
