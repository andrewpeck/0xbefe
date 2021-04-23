//--------------------------------------------------------------------------------
// CMS Muon Endcap
// GEM Collaboration
// Project -- Find Cluster Primaries
// A. Peck
//--------------------------------------------------------------------------------
// 2019/05/09 -- Init description
//--------------------------------------------------------------------------------

module find_cluster_primaries #(
  parameter MXPADS=1536,
  parameter MXROWS=8,
  parameter MXKEYS=192,
  parameter MXCNTBITS=3,
  parameter SPLIT_CLUSTERS=0)
(
  input                             clock,
  input      [MXPADS-1:0]           sbits,
  output reg [MXPADS-1:0]           vpfs,
  output     [MXPADS*MXCNTBITS-1:0] cnts
);

wire [(MXKEYS-1)+8:0] partition_padded [MXROWS-1:0];
wire [(MXKEYS-1)  :0] partition [MXROWS-1:0];

genvar ikey, irow, ibit;

generate
  for (irow=0; irow<MXROWS; irow=irow+1) begin: cluster_vpf_rowloop

  assign partition[irow] = sbits[(irow+1)*MXKEYS-1 : irow*MXKEYS];

  // zero pad the partition to handle the edge cases for counting
  assign partition_padded[irow] = {{8{1'b0}}, partition[irow]};

  for (ikey=0; ikey<MXKEYS; ikey=ikey+1) begin: cluster_vpf_keyloop

        // first pad is always a cluster if it has an S-bit
        // other pads are cluster if they:
        //    (1) are preceded by a Zero (i.e. they start a cluster)
        // or (2) are preceded by a Size=8 cluster (and cluster truncation is turned off)
        //        if we have size > 16 cluster, the end will get cut off
        always @(posedge clock) begin
          if      (ikey == 0) vpfs [(MXKEYS*irow)+ikey] <= partition[irow][ikey];
          else if (ikey  < 9) vpfs [(MXKEYS*irow)+ikey] <= partition[irow][ikey:ikey-1]==2'b10;
          else if (ikey >= 9) vpfs [(MXKEYS*irow)+ikey] <= partition[irow][ikey:ikey-1]==2'b10 || (SPLIT_CLUSTERS && partition[irow][ikey:ikey-9]==10'b1111111110) ;
        end

        consecutive_count ucntseq (
          .clock (clock),
          .sbit  (partition_padded[irow][ikey+7:ikey+1]),
          .count (cnts[(MXKEYS*irow*3)+(ikey+1)*3-1:(MXKEYS*irow*3)+ikey*3])
        );

  end // row loop
  end // key_loop
endgenerate
endmodule
