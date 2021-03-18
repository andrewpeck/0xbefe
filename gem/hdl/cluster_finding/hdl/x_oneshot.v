`timescale 1ns / 1ps
//`define DEBUG_X_ONESHOT 1
//------------------------------------------------------------------------------------------------------------------
// Digital One-Shot:
//    Produces 1-clk wide pulse when d goes high.
//    Waits for d to go low before re-triggering.
//
//  02/07/2002  Initial
//  09/15/2006  Mod for XST
//  01/13/2009  Mod for ISE 10.1i
//  04/26/2010  Mod for ISE 11.5
//  07/12/2010  Port to ISE 12, convert to nonblocking operators
//  09/06/2016  Mod to reduce latency by 1bx
//  08/11/2017  Mod to add programmable deadtime
//-----------------------------------------------------------------------------------------------------------------
  module x_oneshot (d,clk,slowclk,deadtime,q);

  parameter NBITS    = 4;

  input  d;
  input  clk;
  input [NBITS-1:0] deadtime;
  input  slowclk;
  output q;

// State Machine declarations
  reg [2:0] sm;    // synthesis attribute safe_implementation of sm is "yes";
  parameter idle  =  0;
  parameter hold  =  1;

  reg [NBITS-1:0] halt = 3'd0;
  always @(posedge slowclk) begin
    if (d && (sm==idle))
      halt <= deadtime-1'b1;
    else if (halt!=0)
      halt <= halt - 1'b1;
    else
      halt <= 0;
  end

  wire done = (halt==0);


// One-shot state machine
  initial sm = idle;

  always @(posedge clk) begin
    case (sm)
      idle:    if (d)         sm <= hold;
      hold:    if(!d && done) sm <= idle;
      default:                sm <= idle;
    endcase
  end

// Output FF
  reg  q = 0;

  generate
  always @(posedge clk) begin
      q <= d && (sm==idle);
  end
  endgenerate

// Debug state machine display
`ifdef DEBUG_X_ONESHOT
  output [39:0] sm_dsp;
  reg    [39:0] sm_dsp;

  always @* begin
    case (sm)
      idle:   sm_dsp <= "idle ";
      hold:   sm_dsp <= "hold ";
      default sm_dsp <= "deflt";
    endcase
  end
`endif

//------------------------------------------------------------------------------------------------------------------
  endmodule
//------------------------------------------------------------------------------------------------------------------
