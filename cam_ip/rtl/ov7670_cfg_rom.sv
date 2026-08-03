// OV7670 register program (QVGA RGB565).
// dout = {reg_addr[15:8], value[7:0]}
// Sentinels: FFF0 = delay, FFFF = end
module ov7670_cfg_rom (
  input  logic        clk,
  input  logic [7:0]  addr,
  output logic [15:0] dout
);

  always_ff @(posedge clk) begin
    unique case (addr)
      // Soft reset + settle
      8'd0:  dout <= 16'h1280;
      8'd1:  dout <= 16'hFFF0;
      // COM7: QVGA (bit4) + RGB (bit2)  -- was 0x04 (VGA) in the broken design
      8'd2:  dout <= 16'h1214;
      8'd3:  dout <= 16'h1180; // CLKRC
      8'd4:  dout <= 16'h0C00; // COM3
      8'd5:  dout <= 16'h3E00; // COM14
      8'd6:  dout <= 16'h0400; // COM1
      8'd7:  dout <= 16'h40D0; // COM15 RGB565 full range
      8'd8:  dout <= 16'h3A04; // TSLB
      8'd9:  dout <= 16'h1418; // COM9
      // Color matrix
      8'd10: dout <= 16'h4FB3;
      8'd11: dout <= 16'h50B3;
      8'd12: dout <= 16'h5100;
      8'd13: dout <= 16'h523D;
      8'd14: dout <= 16'h53A7;
      8'd15: dout <= 16'h54E4;
      8'd16: dout <= 16'h589E;
      8'd17: dout <= 16'h3DC0; // COM13
      // Windowing
      8'd18: dout <= 16'h1714; // HSTART
      8'd19: dout <= 16'h1802; // HSTOP
      8'd20: dout <= 16'h3280; // HREF
      8'd21: dout <= 16'h1903; // VSTART
      8'd22: dout <= 16'h1A7B; // VSTOP
      8'd23: dout <= 16'h030A; // VREF
      8'd24: dout <= 16'h0F41; // COM6
      8'd25: dout <= 16'h1E00; // MVFP
      8'd26: dout <= 16'h330B; // CHLF
      8'd27: dout <= 16'h3C78; // COM12
      8'd28: dout <= 16'h6900; // GFIX
      8'd29: dout <= 16'h7400; // REG74
      8'd30: dout <= 16'hB084; // RSVD (color)
      8'd31: dout <= 16'hB10C; // ABLC1
      8'd32: dout <= 16'hB20E;
      8'd33: dout <= 16'hB380; // THL_ST
      // Scaling
      8'd34: dout <= 16'h703A;
      8'd35: dout <= 16'h7135;
      8'd36: dout <= 16'h7211;
      8'd37: dout <= 16'h73F0;
      8'd38: dout <= 16'hA202;
      // Gamma
      8'd39: dout <= 16'h7A20;
      8'd40: dout <= 16'h7B10;
      8'd41: dout <= 16'h7C1E;
      8'd42: dout <= 16'h7D35;
      8'd43: dout <= 16'h7E5A;
      8'd44: dout <= 16'h7F69;
      8'd45: dout <= 16'h8076;
      8'd46: dout <= 16'h8180;
      8'd47: dout <= 16'h8288;
      8'd48: dout <= 16'h838F;
      8'd49: dout <= 16'h8496;
      8'd50: dout <= 16'h85A3;
      8'd51: dout <= 16'h86AF;
      8'd52: dout <= 16'h87C4;
      8'd53: dout <= 16'h88D7;
      8'd54: dout <= 16'h89E8; // fixed: was overwritten by duplicate case 54
      // AGC / AEC
      8'd55: dout <= 16'h13E0; // COM8 disable
      8'd56: dout <= 16'h0000;
      8'd57: dout <= 16'h1000;
      8'd58: dout <= 16'h0D40;
      8'd59: dout <= 16'h1418;
      8'd60: dout <= 16'hA505;
      8'd61: dout <= 16'hAB07;
      8'd62: dout <= 16'h2495;
      8'd63: dout <= 16'h2533;
      8'd64: dout <= 16'h26E3;
      8'd65: dout <= 16'h9F78;
      8'd66: dout <= 16'hA068;
      8'd67: dout <= 16'hA103;
      8'd68: dout <= 16'hA6D8;
      8'd69: dout <= 16'hA7D8;
      8'd70: dout <= 16'hA8F0;
      8'd71: dout <= 16'hA990;
      8'd72: dout <= 16'hAA94;
      8'd73: dout <= 16'h13E5; // COM8 enable AGC/AEC
      default: dout <= 16'hFFFF;
    endcase
  end

endmodule
