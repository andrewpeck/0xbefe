module fader #(
  parameter MXFADERCNT  = 27,
  parameter MXFADERBITS = 5)
(
  input clock,
  output led
);

  // count to 27 bits , ~3.5 second period
  localparam INCREMENT   = (2**MXFADERBITS)/4;

  reg [MXFADERCNT -1:0] fader_cnt = 0;
  reg [MXFADERBITS-1:0] pwm_cnt  = 0;

  wire [MXFADERBITS-2:0] fader_msbs     = fader_cnt[MXFADERCNT-2:MXFADERCNT-MXFADERBITS];
  wire [MXFADERBITS-2:0] pwm_brightness = fader_cnt[MXFADERCNT-1] ? fader_msbs : ~fader_msbs;

  always @(posedge clock) begin
    fader_cnt <= fader_cnt + 1'b1;
    pwm_cnt <= pwm_cnt[MXFADERBITS-2:0] + pwm_brightness + INCREMENT;
  end

  assign led = pwm_cnt[4];

endmodule
