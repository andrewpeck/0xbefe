`timescale 1ns / 1ps
//`define DEBUG_CYLON1 1
//--------------------------------------------------------------------------------------------------------------
//  Cylon sequence generator, one eye
//
//  10/01/2003  Initial
//  09/28/2006  Mod xst remove output ff, inferred ROM is already registered
//  10/10/2006  Replace init ff with srl
//  05/21/2007  Rename cylon9 to cylon1 to distinguish from 2-eye, add rate
//  08/11/2009  Replace 10MHz clock_vme with  40MHz clock, increase prescale counter by 2 bits
//  04/22/2010  Port to ise 11, add FF to srl output to sync with gsr
//  07/09/2010  Port to ise 12
//  07/24/2017  Expand to 12 bit for optohybrid
//  07/25/2017  Flop the q output
//--------------------------------------------------------------------------------------------------------------
  module cylon1 (clock,rate,q);

// Ports
  input              clock;
  input       [1:0]  rate;
  output  reg [7:0]  q;

// Scale clock down below visual fusion
  `ifndef DEBUG_CYLON1
  parameter MXPRE = 21;  `else
  parameter MXPRE = 2;
  `endif

  reg  [MXPRE-1:0] prescaler  = 0;
  wire [MXPRE-1:0] full_scale = {MXPRE{1'b1}};

  always @(posedge clock) begin
  prescaler <= prescaler + rate + 1'b1;
  end

  wire next_adr = (prescaler==full_scale);

// ROM address pointer runs 0 to 13
  reg  [4:0] adr = 0;

  wire last_adr = (adr==13);

  always @(posedge clock) begin
  if (next_adr) begin
  if (last_adr) adr <= 0;
  else          adr <= adr + 1'b1;
  end
  end

// Display pattern ROM
  reg  [7:0] rom;

  always @(adr) begin
  case (adr)
  5'd0:  rom   <= 8'b00000001;
  5'd1:  rom   <= 8'b00000010;
  5'd2:  rom   <= 8'b00000100;
  5'd3:  rom   <= 8'b00001000;
  5'd4:  rom   <= 8'b00010000;
  5'd5:  rom   <= 8'b00100000;
  5'd6:  rom   <= 8'b01000000;
  5'd7:  rom   <= 8'b10000000;
  5'd8:  rom   <= 8'b01000000;
  5'd9:  rom   <= 8'b00100000;
  5'd10: rom   <= 8'b00010000;
  5'd11: rom   <= 8'b00001000;
  5'd12: rom   <= 8'b00000100;
  5'd13: rom   <= 8'b00000010;
  default: rom <= 8'b10101010;
  endcase
  end

  always @(posedge clock) begin
    q <= rom;
  end

//--------------------------------------------------------------------------------------------------------------
  endmodule
//--------------------------------------------------------------------------------------------------------------
