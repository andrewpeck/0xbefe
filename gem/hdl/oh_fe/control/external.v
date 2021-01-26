//--------------------------------------------------------------------------------
// CMS Muon Endcap
// GEM Collaboration
// Optohybrid v3 Firmware -- Stupid HDMI Controller
// T. Lenzi, A. Peck
//--------------------------------------------------------------------------------
// Description:
//   This module controls the HDMI outputs to provide programmable combinations
//   of S-bits
//--------------------------------------------------------------------------------
// 2017/07/24 -- Initial port to version 3 electronics
// 2017/07/25 -- Port to Verilog
// 2017/07/25 -- Clear synthesis warnings from module
// 2017/08/10 -- Add reset and fanout
// 2018/04/17 -- Add lite mode
//--------------------------------------------------------------------------------

module external (

  input clock,

  input reset_i,

  //Sbits

  input [NUM_VFATS-1:0] active_vfats_i,

  input [1:0]  sbit_mode0,
  input [1:0]  sbit_mode1,
  input [1:0]  sbit_mode2,
  input [1:0]  sbit_mode3,
  input [1:0]  sbit_mode4,
  input [1:0]  sbit_mode5,
  input [1:0]  sbit_mode6,
  input [1:0]  sbit_mode7,

  input [4:0] sbit_sel0,
  input [4:0] sbit_sel1,
  input [4:0] sbit_sel2,
  input [4:0] sbit_sel3,
  input [4:0] sbit_sel4,
  input [4:0] sbit_sel5,
  input [4:0] sbit_sel6,
  input [4:0] sbit_sel7,

  output reg [7:0]  ext_sbits_o

);

  parameter GE21=0;
  parameter NUM_VFATS = 24;

  initial $display ("Instantiating external.v with NUM_VFATS=%d OH_LITE=%d", NUM_VFATS, GE21);

  wire [4:0] sbit_sel [7:0];
  wire [1:0] sbit_mode [7:0];

  assign sbit_sel[0] = sbit_sel0;
  assign sbit_sel[1] = sbit_sel1;
  assign sbit_sel[2] = sbit_sel2;
  assign sbit_sel[3] = sbit_sel3;
  assign sbit_sel[4] = sbit_sel4;
  assign sbit_sel[5] = sbit_sel5;
  assign sbit_sel[6] = sbit_sel6;
  assign sbit_sel[7] = sbit_sel7;

  assign sbit_mode[0] = sbit_mode0;
  assign sbit_mode[1] = sbit_mode1;
  assign sbit_mode[2] = sbit_mode2;
  assign sbit_mode[3] = sbit_mode3;
  assign sbit_mode[4] = sbit_mode4;
  assign sbit_mode[5] = sbit_mode5;
  assign sbit_mode[6] = sbit_mode6;
  assign sbit_mode[7] = sbit_mode7;

  reg reset=0;
  always @(posedge clock)
    reset <= reset_i;

  wire [NUM_VFATS-1:0] ors = active_vfats_i;

  reg  [ 7:0] eta_row;
  reg  [ 5:0] sector_row;

  // SBits output

  // split the chamber into eta partitions

  genvar j;
  generate
    if (GE21) begin: partitionsplit

      for (j=0; j<2; j=j+1) begin: zerotoone
        always @(posedge clock)
          eta_row[j] <= ors[j] || ors[j+2] || ors[j+4] || ors[j+6] || ors[j+6] || ors[j+8] || ors[j+10];
      end

    end
    else begin

      for (j=0; j<8; j=j+1) begin: zerotoseven
        always @(posedge clock)
          eta_row[j] <= ors[j] || ors[8+j] || ors[16+j];
      end

    end // if GE21
  endgenerate


  // split the chamber into 6 sectors
  // (top left, top center, top right, bottom left, bottom center, bottom right)

  generate
  for (j=0; j<6; j=j+1) begin: zerotofive

    always @(posedge clock) begin
      if (reset) begin
        sector_row[j] <= 0;
      end
      else begin
        if (GE21) sector_row[j] <= ors[j*2] || ors[j*2+1];
        else      sector_row[j] <= ors[j*4] || ors[j*4+1] || ors[j*4+2] || ors[j*4+3];
      end
    end
  end
  endgenerate

  generate
  for (j=0; j<8; j=j+1) begin: out_loop

    always @(posedge clock) begin
      if (reset) begin
        ext_sbits_o[j] <= 0;
      end
      else begin
        case (sbit_mode[j])
          2'b00: ext_sbits_o[j] <= ors        [sbit_sel[j]];
          2'b01: ext_sbits_o[j] <= eta_row    [sbit_sel[j]];
          2'b10: ext_sbits_o[j] <= sector_row [sbit_sel[j]];
          2'b11: ext_sbits_o[j] <= 6'h0;
        endcase
      end
    end

  end
  endgenerate

endmodule
