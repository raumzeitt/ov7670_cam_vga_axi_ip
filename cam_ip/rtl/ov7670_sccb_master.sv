// Open-drain SCCB (I2C-like) write master for OV7670.
// Top-level must tri-state pads:
//   assign sioc = sioc_oe ? 1'b0 : 1'bz;
//   assign siod = siod_oe ? 1'b0 : 1'bz;
module ov7670_sccb_master #(
  parameter int unsigned CLK_HZ  = 25_000_000,
  parameter int unsigned SCCB_HZ = 100_000
) (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       start,
  input  logic [7:0] reg_addr,
  input  logic [7:0] reg_data,
  output logic       ready,
  output logic       sioc_oe,
  output logic       siod_oe
);

  import ov7670_pkg::*;

  localparam int unsigned QTR = (CLK_HZ / (4 * SCCB_HZ)) == 0 ? 1 : (CLK_HZ / (4 * SCCB_HZ));
  localparam int unsigned HLF = (CLK_HZ / (2 * SCCB_HZ)) == 0 ? 1 : (CLK_HZ / (2 * SCCB_HZ));
  localparam int unsigned GAP = (2 * CLK_HZ / SCCB_HZ) == 0 ? 1 : (2 * CLK_HZ / SCCB_HZ);

  typedef enum logic [3:0] {
    ST_IDLE,
    ST_START,
    ST_LOAD_BYTE,
    ST_TX1,
    ST_TX2,
    ST_TX3,
    ST_TX4,
    ST_END1,
    ST_END2,
    ST_END3,
    ST_END4,
    ST_DONE,
    ST_TIMER
  } state_t;

  state_t state, ret_state;
  logic [31:0] timer;
  logic [7:0]  latched_addr;
  logic [7:0]  latched_data;
  logic [1:0]  byte_counter;
  logic [7:0]  tx_byte;
  logic [3:0]  bit_index;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= ST_IDLE;
      ret_state    <= ST_IDLE;
      timer        <= '0;
      ready        <= 1'b1;
      sioc_oe      <= 1'b0;
      siod_oe      <= 1'b0;
      latched_addr <= '0;
      latched_data <= '0;
      byte_counter <= '0;
      tx_byte      <= '0;
      bit_index    <= '0;
    end else begin
      unique case (state)
        ST_IDLE: begin
          bit_index    <= '0;
          byte_counter <= '0;
          if (start) begin
            state        <= ST_START;
            latched_addr <= reg_addr;
            latched_data <= reg_data;
            ready        <= 1'b0;
          end else begin
            ready <= 1'b1;
          end
        end

        ST_START: begin
          state     <= ST_TIMER;
          ret_state <= ST_LOAD_BYTE;
          timer     <= QTR;
          sioc_oe   <= 1'b0;
          siod_oe   <= 1'b1;
        end

        ST_LOAD_BYTE: begin
          if (byte_counter == 2'd3) begin
            state <= ST_END1;
          end else begin
            state <= ST_TX1;
          end
          byte_counter <= byte_counter + 2'd1;
          bit_index    <= '0;
          unique case (byte_counter)
            2'd0: tx_byte <= OV7670_SCCB_ID;
            2'd1: tx_byte <= latched_addr;
            2'd2: tx_byte <= latched_data;
            default: tx_byte <= latched_data;
          endcase
        end

        ST_TX1: begin
          state     <= ST_TIMER;
          ret_state <= ST_TX2;
          timer     <= QTR;
          sioc_oe   <= 1'b1;
        end

        ST_TX2: begin
          state     <= ST_TIMER;
          ret_state <= ST_TX3;
          timer     <= QTR;
          // bit_index==8 => ACK slot, release SIOD
          siod_oe   <= (bit_index == 4'd8) ? 1'b0 : ~tx_byte[7];
        end

        ST_TX3: begin
          state     <= ST_TIMER;
          ret_state <= ST_TX4;
          timer     <= HLF;
          sioc_oe   <= 1'b0;
        end

        ST_TX4: begin
          if (bit_index == 4'd8) begin
            state <= ST_LOAD_BYTE;
          end else begin
            state <= ST_TX1;
          end
          tx_byte   <= {tx_byte[6:0], 1'b0};
          bit_index <= bit_index + 4'd1;
        end

        ST_END1: begin
          state     <= ST_TIMER;
          ret_state <= ST_END2;
          timer     <= QTR;
          sioc_oe   <= 1'b1;
        end

        ST_END2: begin
          state     <= ST_TIMER;
          ret_state <= ST_END3;
          timer     <= QTR;
          siod_oe   <= 1'b1;
        end

        ST_END3: begin
          state     <= ST_TIMER;
          ret_state <= ST_END4;
          timer     <= QTR;
          sioc_oe   <= 1'b0;
        end

        ST_END4: begin
          state     <= ST_TIMER;
          ret_state <= ST_DONE;
          timer     <= QTR;
          siod_oe   <= 1'b0;
        end

        ST_DONE: begin
          state        <= ST_TIMER;
          ret_state    <= ST_IDLE;
          timer        <= GAP;
          byte_counter <= '0;
        end

        ST_TIMER: begin
          if (timer == 0) begin
            state <= ret_state;
          end else begin
            timer <= timer - 1;
          end
        end

        default: state <= ST_IDLE;
      endcase
    end
  end

endmodule
