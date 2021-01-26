module count_clusters (
    input clock,
    input  [1535:0] vpfs_i,
    output reg [10:0] cnt_o,
    output reg overflow_o
);

  parameter OVERFLOW_THRESH = 0;

  reg [2:0] cnt_s1 [255:0]; // count to 6
  reg [3:0] cnt_s2 [127:0]; // count to 12
  reg [4:0] cnt_s3  [63:0]; // count to 24
  reg [5:0] cnt_s4  [31:0]; // count to 48
  reg [6:0] cnt_s5  [15:0]; // count to 96
  reg [8:0] cnt_s6  [ 7:0]; // count to 192
  reg [9:0] cnt_s7  [ 1:0]; // count to 768

  reg [10:0] cnt; // count to 1536

  // register inputs
  // make sure xilinx doesn't merge these with copies in the cluster finding
  (*equivalent_register_removal="no"*)
  (*shreg_extract="no"*)
  reg  [1535:0] vpfs;

  always @(posedge clock) begin
    vpfs <= vpfs_i;
  end

  genvar icnt;

  generate
  for (icnt=0; icnt<(256); icnt=icnt+1) begin: cnt_s1_loop
    always @(posedge clock)
      cnt_s1[icnt] <= count1s(vpfs[(icnt+1)*6-1:icnt*6]);
  end
  endgenerate

  generate
  for (icnt=0; icnt<(128); icnt=icnt+1) begin: cnt_s2_loop
    always @(posedge clock)
        cnt_s2[icnt] <= cnt_s1[(icnt+1)*2-1] + cnt_s1[icnt*2];
  end
  endgenerate

  generate
  for (icnt=0; icnt<(64); icnt=icnt+1) begin: cnt_s3_loop
    always @(posedge clock)
      cnt_s3[icnt] <= cnt_s2[(icnt+1)*2-1] + cnt_s2[icnt*2];
  end
  endgenerate

  generate
  for (icnt=0; icnt<(32); icnt=icnt+1) begin: cnt_s4_loop
    always @(posedge clock)
      cnt_s4[icnt] <= cnt_s3[(icnt+1)*2-1] + cnt_s3[icnt*2];
  end
  endgenerate

  generate
  for (icnt=0; icnt<(16); icnt=icnt+1) begin: cnt_s5_loop
    always @(posedge clock)
      cnt_s5[icnt] <= cnt_s4[(icnt+1)*2-1] + cnt_s4[icnt*2];
  end
  endgenerate

  generate
  for (icnt=0; icnt<(8); icnt=icnt+1) begin: cnt_s6_loop
    always @(posedge clock)
      cnt_s6[icnt] <= cnt_s5[(icnt+1)*2-1] + cnt_s5[icnt*2];
  end
  endgenerate

  always @(posedge clock) begin
    cnt_s7[0] <= cnt_s6[0]  + cnt_s6[1]  + cnt_s6[2]  + cnt_s6[3];
    cnt_s7[1] <= cnt_s6[4]  + cnt_s6[5]  + cnt_s6[6]  + cnt_s6[7];
  end

  always @(posedge clock) begin
    cnt <=  cnt_s7[0] + cnt_s7[1];
    cnt_o <= cnt;
    overflow_o <= (cnt > OVERFLOW_THRESH);
  end

  `include "count1s.v"

endmodule
