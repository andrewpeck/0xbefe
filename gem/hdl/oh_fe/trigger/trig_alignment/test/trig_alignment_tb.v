
module sr32 (
  input CLK,
  input CE,
  input [4:0] SEL,
  input SI,
  output DO
);

parameter SELWIDTH = 5;
localparam DATAWIDTH = 2**SELWIDTH;
reg [DATAWIDTH-1:0] data;
assign DO = data[SEL];
always @(posedge CLK)
begin
  if (CE == 1'b1)
    data <= {data[DATAWIDTH-2:0], SI};
end
endmodule

//----------------------------------------------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------------------------------------------

module trig_alignment_tb;

parameter DDR = 1;

// need to simulate a fast clock for ps delays

reg clk12G8    = 0;
reg clk1280   = 0;
reg clk320    = 0;
reg clk40     = 0;
reg clk640    = 0;
reg clk320_90 = 0;

always @* begin
  clk12G8    <= #0.039   ~clk12G8; // 78 ps clock (12.8GHz) to simulate TAP delay
  clk1280   <= #0.390   ~clk1280;
  clk640    <= #0.780   ~clk640;
  clk320    <= #1.560   ~clk320;
  clk320_90 <= #0.780    clk320;
  clk40     <= # 12.48 ~clk40;
end

wire fastclk_0   =  clk320;
wire fastclk_180 = ~clk320;
wire fastclk_90  =  clk320_90;

reg [2:0] sot_cnt=0; // cnt to 8
wire sotd0 = (sot_cnt==0);

//parameter [127:0] test_pat = 128'hCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC;
parameter [127:0] test_pat = 128'hff00ff00ff00ff00ff00ff00ff00ff00;

reg [7:0] sbits_tx=0;
always @(posedge clk320) begin
  if (sot_cnt==7)
  sbits_tx <= ~sbits_tx;
end

reg [127:0] pat_sr   = test_pat;
always @ (posedge clk1280) begin
  pat_sr [0] <= sbits_tx[sot_cnt];

end

// reg [127:0] pat_sr   = test_pat;
// always @ (posedge clk1280)
//   pat_sr <= {pat_sr[126:0], pat_sr[127]};

always @(posedge clk320)
  sot_cnt <= sot_cnt + 1'b1;


wire [191:0] phase_err;
wire aligner_sump;

wire [1535+1536*DDR:0] sbits;


// apply a delay, opposite to the delay that we we later counteract with TU_POSNEG

wire [191:0] tu_p;

genvar ipin;
generate
for (ipin=0; ipin<192; ipin=ipin+1) begin: pinloop
  sr32 srp (clk12G8, 1'b1, 5'd31 - TU_OFFSET [ipin*5+:4],  pat_sr[0], tu_p[ipin]);
end
endgenerate


wire [23:0] sof;

genvar ifat;
generate
for (ifat=0; ifat<24; ifat=ifat+1) begin: fatloop
  sr32 srfp (clk12G8, 1'b1, 5'd31-SOF_OFFSET [ifat*5+:4],  sotd0, sof[ifat]);
  //sr32 srfp (clk12G8, 1'b1, 5'd31 - SOF_OFFSET [ifat*5+:4],  sotd0, sof[ifat]);
end
endgenerate

trig_alignment #(.DDR(DDR))
aligner
(

  .sbits_p( tu_p),
  .sbits_n(~tu_p),

  .start_of_frame_p( sof),
  .start_of_frame_n(~sof),

  .fastclk_0(clk320),
  .fastclk_90(clk320_90),
  .fastclk_180(~clk320),
  .clock(clk40),

  .sbits(sbits),

  .phase_err (phase_err),

  .sump(aligner_sump)
);


endmodule
