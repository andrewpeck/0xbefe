module oversampler_tb;

reg clk320 = 0;
reg clk640 = 0;
reg clk320_90=0;

always @* begin
  clk640 <= #0.78       ~clk640;
  clk320 <= #1.56       ~clk320;
  clk320_90 <= #0.78    clk320;
end

wire fastclk_0 = clk320;
wire fastclk_180 = ~clk320;
wire fastclk_90 = clk320_90;


parameter [127:0] test_pat = 128'hCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC;
reg [127:0] pat_sr   = test_pat;

always @ (posedge clk640)
  pat_sr <= {pat_sr[126:0], pat_sr[127]};

wire rx_p =  pat_sr[0];
wire rx_n = ~pat_sr[0];

reg [1:0] sel = 0;

wire err;
reg reset = 0;

wire d0;
wire d1;


  oversampler ovs (
    .rx_p (rx_p),
    .rx_n (rx_n),

    .clock (fastclk_0),
    .clock90 (fastclk_90),
    .clock180 (fastclk_180),

    .phase_sel (sel[1:0]),
    .phase_sel_manual (1'b0),
    .phase_err (err),

    .d0(d0),
    .d1(d1),

    .reset(reset)
  );


  endmodule
