//--------------------------------------------------------------------------------
// CMS Muon Endcap
// GEM Collaboration
// Optohybrid v3 Firmware -- Frame Alignment
// A. Peck
//--------------------------------------------------------------------------------
// Description:
//   This module takes in 8 bit frames from a single VFAT pair, and phase
//   aligns them to 40 MHz LHC clock, aligns the bitstream to the frame clock
//   and deserialize to 40MHz
//--------------------------------------------------------------------------------
// 2017/07/24 -- Initial
// 2018/09/18 -- Modifications for light optohybrid
// 2018/10/10 -- Rewrite/simplification based on new oversampler / dru module
// 2021/10/01 -- Use bitslip_fast
//--------------------------------------------------------------------------------

module frame_aligner
  #(parameter MXSBITS=64,
    parameter EN_BITSLIP_TMR = 0,
    parameter FRAME_SIZE = 8) (

    input [MXSBITS-1:0]    sbits_i,
    output [MXSBITS-1:0]   sbits_o,

    input [FRAME_SIZE-1:0] start_of_frame_i,

    input                  reset_i,
    input                  mask_i,

    input                  clock,

    input [11:0]           aligned_count_to_ready_i,

    output reg             sot_unstable_o,
    output reg             sot_is_aligned_o
);

  //--------------------------------------------------------------------------------------------------------------------
  //  Reset
  //--------------------------------------------------------------------------------------------------------------------

  reg reset=1;
  always @(posedge clock) begin
    reset <= reset_i;
  end

  //--------------------------------------------------------------------------------------------------------------------
  // Copy SoF Register
  //--------------------------------------------------------------------------------------------------------------------

  reg [FRAME_SIZE-1:0] start_of_frame_reg;
  always @(posedge clock) begin
    start_of_frame_reg <= start_of_frame_i;
  end

  //--------------------------------------------------------------------------------------------------------------------
  //  Bitslips
  //--------------------------------------------------------------------------------------------------------------------

  reg [2:0] bitslip_cnt;
  wire [7:0] start_of_frame_slipped;

  (* KEEP = "TRUE" *) wire sot_mon;

  genvar I;
  generate
  for (I=0; I<8; I=I+1'b1) begin  : Iloop

  bitslip_tmr data_bitslip (
    .clock        (clock),
    .reset        (1'b0), //(reset || mask_i || ~sot_is_aligned),
    .bitslip_cnt  (bitslip_cnt),
    .din          (sbits_i[8*(I+1)-1 : 8*I]),
    .dout         (sbits_o[8*(I+1)-1 : 8*I])
  );

  end
  endgenerate

  bitslip_tmr sot_bitslip (
    .clock        (clock),
    .reset        (reset),
    .bitslip_cnt  (bitslip_cnt),
    .din          (start_of_frame_reg),
    .dout         (start_of_frame_slipped)
  );

  assign sot_mon = start_of_frame_slipped[0];

  //--------------------------------------------------------------------------------------------------------------------
  // Bitslip Control
  //--------------------------------------------------------------------------------------------------------------------

  reg sot_good             = 0;
  reg [11:0] stable_counts = 0;

  // the bitslip_cnt here is determined by the phase of the S-bits relative to the SoT signal
  // the VFAT3 docs specify that it should be centered on the zeroeth bit
  // sot: s
  // dat: 01234567
  //
  // in this case the bitslip cnt should progress from 0,1,2,3,4,5,6,7 in the logical way
  //
  // but empirically the firmware seems to require:
  // sot:  s
  // dat: 01234567
  //
  // I have no idea why

  always @(posedge clock) begin
    case (start_of_frame_reg)
      8'b00000001: begin bitslip_cnt <= 3'd1; sot_good <= 1'b1; end
      8'b00000010: begin bitslip_cnt <= 3'd2; sot_good <= 1'b1; end
      8'b00000100: begin bitslip_cnt <= 3'd3; sot_good <= 1'b1; end
      8'b00001000: begin bitslip_cnt <= 3'd4; sot_good <= 1'b1; end
      8'b00010000: begin bitslip_cnt <= 3'd5; sot_good <= 1'b1; end
      8'b00100000: begin bitslip_cnt <= 3'd6; sot_good <= 1'b1; end
      8'b01000000: begin bitslip_cnt <= 3'd7; sot_good <= 1'b1; end
      8'b10000000: begin bitslip_cnt <= 3'd0; sot_good <= 1'b1; end
      default:     begin bitslip_cnt <= 3'd1; sot_good <= 1'b0; end
    endcase
  end

  //--------------------------------------------------------------------------------------------------------------------
  // SOT ready/unstable
  //--------------------------------------------------------------------------------------------------------------------

  always @(posedge clock) begin
    if (sot_good) begin
      if (stable_counts == aligned_count_to_ready_i) stable_counts <= stable_counts;
      else                                          stable_counts <= stable_counts + 1'b1;
    end
    else begin
      stable_counts <= 0;
    end
  end

  always @(posedge clock) begin
    if      (reset)                        sot_unstable_o <= 1'b0;
    else if (sot_is_aligned_o && !sot_good) sot_unstable_o <= 1'b1;
  end

  always @(posedge clock) begin
    sot_is_aligned_o <= (stable_counts == aligned_count_to_ready_i);
  end


endmodule
