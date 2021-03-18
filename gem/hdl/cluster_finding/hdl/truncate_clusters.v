//----------------------------------------------------------------------------------------------------------------------
// truncate_clusters.v
//----------------------------------------------------------------------------------------------------------------------
//
// This module is designed to Truncate LSB 1s from a 1536 bit number, and is
// capable of running at well over 160 MHz even on VERY large busses
//
// The details:
//
// At each clock cycle, the least-significant 1 becomes 0, using a simple
// property of integers: subtracting 1 from a number will always affect the
// least-significant set 1-bit. Using just arithmetic, with this trick we can
// take some starting number, and generate a copy of it that has the
// least-significant 1 changed to a zero.
//
// e.g.
// let a        = 101100100  // our starting number
//    ~a        = 010011011  // bitwise inversion
//     b = ~a+1 = 010011100  // b is exactly the twos complement of a, which we know to be the same as (-a) ! :)
//    ~b        = 101100011  //
//     a & b    = 000000100  // one hot of first one set
//     a &~b    = 101100000  // copy of a with the first non-zero bit set to zero. Voila!
//
// or as a one line expression,
//     c = a & ~(~a+1), or equivalently
//     c = a & ~(  -a), or equivalently
//     c = a & ~({1536{1'b1}}-a), etc., I'm sure there are more.
//
// But alas, the point: we can Zero out bits without knowing the position of
// the bit, So this so-called cluster-truncator can run independently of
// a priority encoder that is finding the position of the bit. This allows the
// cluster truncation to be the timing critical step (running at 160 MHz)
// while the larger amount of logic in the priority encoder can be pipelined,
// to run over 2 or 3 clock cycles, which adds an overall latency but still
// allows the priority encoding to be done at 160MHz without imposing much of
// any constraint on the priority encoding logic.
//----------------------------------------------------------------------------------------------------------------------

//----------------------------------------------------------------------------------------------------------------------
`timescale 1ns / 100 ps
//----------------------------------------------------------------------------------------------------------------------

module truncate_clusters #(
  parameter MXVPF = 768,
  parameter MXSEGS = 16
) (

  input clock,

  input latch_pulse,

  output reg [2:0] pass_o,

  input  [MXVPF-1:0] vpfs_in,
  output [MXVPF-1:0] vpfs_out

);

  parameter SEGSIZE = MXVPF/MXSEGS;

  (* DONT_TOUCH = "TRUE" *)
  (* MAX_FANOUT = 128 *)
  (*EQUIVALENT_REGISTER_REMOVAL="NO"*)

  always @(posedge clock) begin
    if (latch_pulse)
      pass_o <= 0;
    else
      pass_o <= pass_o + 1'b1;
  end


  wire [SEGSIZE-1:0] segment           [MXSEGS-1:0];
  wire [SEGSIZE-1:0] segment_copy      [MXSEGS-1:0];
  reg  [SEGSIZE-1:0] segment_ff        [MXSEGS-1:0];
  wire [SEGSIZE-1:0] segment_out       [MXSEGS-1:0];

  wire [MXSEGS-1:0]  segment_keep      ;
  wire [MXSEGS-1:0]  segment_active    ;

  genvar iseg;
  generate
  for (iseg=0; iseg<MXSEGS; iseg=iseg+1) begin: segloop
    initial segment_ff      [iseg] = {SEGSIZE{1'b0}};

    // remap cluster inputs into Segments
    assign segment[iseg]        = {vpfs_in [(iseg+1)*SEGSIZE-1:iseg*SEGSIZE]};

    // mark segment as active it has any clusters
    assign segment_active[iseg] = |segment_ff[iseg];

    // copy of segment with least significant 1 removed
    assign segment_copy[iseg]      =  segment_ff[iseg] & ({SEGSIZE{segment_keep[iseg]}} | ~(~segment_ff[iseg]+1));

    // with latch_pulseen, our ff latches the incoming clusters, otherwise we latch the copied segments
    always @(posedge clock) begin
      if   (latch_pulse) segment_ff[iseg] <= segment      [iseg];
      else               segment_ff[iseg] <= segment_copy [iseg];
    end

    assign segment_out[iseg] = segment_ff[iseg];

  end
  endgenerate

  // Segments should be kept if any preceeding segment has ANY sbit.. there are
  // a lot of very different (logically equivalent) ways to write this. But
  // there is a balance between logic depth and routing time that needs to be
  // found.
  //
  //    this is the best that I've found so far, but there will probably be
  //    something better. But something to keep in mind: the synthesis speed
  //    estimates are not very accurate for this, since it is so dependent on
  //    the post-PAR routing times.  I've seen many times that a faster
  //    configuration in synthesis will be slower in post-PAR, so if you want to
  //    experiment effectively you have to go through the pain of doing PAR
  //    and looking at the timing report

  generate
  for (iseg=0; iseg<MXSEGS; iseg=iseg+1) begin: keeploop
    if (iseg>0)
      assign segment_keep [iseg]  =  |segment_active[iseg-1:0];
    else
      assign segment_keep [iseg]  =  0;
  end
  endgenerate

  generate
  for (iseg=0; iseg<MXSEGS; iseg=iseg+1) begin: flatloop
    assign vpfs_out [(iseg+1)*SEGSIZE-1 : iseg*SEGSIZE]  =  segment_out[iseg];
  end
  endgenerate

//----------------------------------------------------------------------------------------------------------------------
endmodule
//----------------------------------------------------------------------------------------------------------------------
