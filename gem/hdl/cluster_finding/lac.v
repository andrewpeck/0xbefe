
// overcome limitation that the Spartan-6 and prior generations to not allow routing a clock into logic, but we can replicate it with a
// "logic accessible clock" which is recovered from the clock but available on the fabric

module lac (
  input clock, // 40 MHz clock
  input clock4x,
  output strobe4x // goes high on rising edge of clock_lac
);

reg lac_pos=0;
reg lac_neg=0;

(* max_fanout = 16 *) reg strobe_int_4x;
(* max_fanout = 16 *) wire clock_lac_int;

always @(posedge clock) lac_pos <= ~lac_pos;
always @(negedge clock) lac_neg <= ~lac_neg;

assign clock_lac_int = lac_pos ^ lac_neg;

wire clock_lac = clock_lac_int;
assign strobe4x    = strobe_int_4x;

reg [3:0] clock_sampled_4x;
always @(posedge clock4x) begin
  clock_sampled_4x <= {clock_sampled_4x[2:0], clock_lac};
  strobe_int_4x    <= (clock_sampled_4x==4'b0110);
end

endmodule
