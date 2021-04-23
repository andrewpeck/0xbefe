module frame_aligner_tb;

parameter DDR = 1;

reg clk320 = 0;
reg clk40  = 0;
reg clk640 = 0;
reg clk320_90=0;

always @* begin
  clk640 <= #0.78       ~clk640;
  clk320 <= #1.56       ~clk320;
  clk320_90 <= #0.78    clk320;
  clk40 <= # 12.48 ~clk40;
end

wire fastclk_0   = clk320;
wire fastclk_180 = ~clk320;
wire fastclk_90  = clk320_90;

reg [2:0] sot_cnt=0; // cnt to 8

parameter [127:0] test_pat = 128'hCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC;
reg [127:0] pat_sr   = test_pat;
always @ (posedge clk320)
  pat_sr <= {pat_sr[125:0], pat_sr[127:126]};

always @(posedge clk320) sot_cnt <= sot_cnt + 1'b1;

wire sotd0 = (sot_cnt==0);


wire [64*DDR+63:0] sbits;

frame_aligner #(.DDR(DDR))
aligner (

  .d0 ({8{pat_sr[0]}}),
  .d1 ({8{pat_sr[1]}}),

  .sot_d0(sotd0), // start of frame marker
  .sot_d1(0),
  .clock (clk40), // 40 MHz frame clock in FPGA
  .clock_fast (clk320), // 160/320 MHz serdes clock in FPGA

  .alignment_error (),
  .sbits(sbits)
);


endmodule
