module priority_n #(
                    parameter MXKEYS    = 192,
                    parameter MXKEYBITS = 8,
                    parameter MXCNTB    = 3) (
    input clock,

    input      [2:0] pass_i,
    output reg [2:0] pass_o = 0,

    input   [MXKEYS  -1:0] vpfs_i,
    input   [MXKEYS*3-1:0] cnts_i,

    output reg  [MXKEYBITS-1:0] adr_o,
    output reg                  vpf_o,
    output reg  [MXCNTB-1:0]    cnt_o
);

   generate

      if (MXKEYS == 192) begin

         //----------------------------------------------------------------------------------------------------------------------
         // Wires
         //----------------------------------------------------------------------------------------------------------------------

         reg [2:0] pass_s0 = 0;
         reg [2:0] pass_s1 = 0;
         reg [2:0] pass_s2 = 0;
         reg [2:0] pass_s3 = 0;
         reg [2:0] pass_s4 = 0;
         reg [2:0] pass_s5 = 0;
         reg [2:0] pass_s6 = 0;

         reg [191:0] vpf_s0 = 0;
         reg [95:0]  vpf_s1 = 0;
         reg [47:0]  vpf_s2 = 0;
         reg [23:0]  vpf_s3 = 0;
         reg [11:0]  vpf_s4 = 0;
         reg [5:0]   vpf_s5 = 0;
         reg [2:0]   vpf_s6 = 0;
         reg         vpf    = 0;

         reg [0:0]   key_s1 [95:0];
         reg [1:0]   key_s2 [47:0];
         reg [2:0]   key_s3 [23:0];
         reg [3:0]   key_s4 [11:0];
         reg [4:0]   key_s5 [5:0];
         reg [5:0]   key_s6 [2:0];
         reg [7:0]   key;

         reg [2:0]   cnt_s0 [191:0];
         reg [2:0]   cnt_s1 [95:0];
         reg [2:0]   cnt_s2 [47:0];
         reg [2:0]   cnt_s3 [23:0];
         reg [2:0]   cnt_s4 [11:0];
         reg [2:0]   cnt_s5 [5:0];
         reg [2:0]   cnt_s6 [2:0];
         reg [2:0]   cnt;

         // choose here to specify pipeline register stages
         `define always_in  always @(*)
         `define always_s0  always @(*)
         `define always_s1  always @(posedge clock)
         `define always_s2  always @(*)
         `define always_s3  always @(*)
         `define always_s4  always @(*)
         `define always_s5  always @(posedge clock)
         `define always_s6  always @(*)
         `define always_out always @(*)

         `always_s1  pass_s1 <= pass_s0;
         `always_s2  pass_s2 <= pass_s1;
         `always_s3  pass_s3 <= pass_s2;
         `always_s4  pass_s4 <= pass_s3;
         `always_s5  pass_s5 <= pass_s4;
         `always_s6  pass_s6 <= pass_s5;
         `always_out pass_o <= pass_s6;

         `always_in pass_s0 <= pass_i;
         `always_in vpf_s0 <= vpfs_i;

         //Remap flattened count bits into a 2D vector
         genvar      ipad;
         for (ipad=0; ipad<192; ipad=ipad+1) begin: padloop
            `always_in
                   cnt_s0 [ipad] <= cnts_i [ipad*3+2:ipad*3];
         end

         //----------------------------------------------------------------------------------------------------------------------
         // Comparators
         //----------------------------------------------------------------------------------------------------------------------

         genvar icmp;

         // Stage 1 : 96 of 192
            for (icmp=0; icmp<96; icmp=icmp+1) begin: s1
               initial vpf_s1[icmp] = 0; initial cnt_s1[icmp] = 0; initial key_s1[icmp] = 0;
               `always_s1
                 {vpf_s1[icmp], cnt_s1[icmp], key_s1[icmp]} = vpf_s0[icmp*2] ?  {vpf_s0[icmp*2  ], cnt_s0[icmp*2], 1'b0} : {vpf_s0[icmp*2+1], cnt_s0[icmp*2+1], 1'b1};
            end

         // Stage 2 : 48 of 96
            for (icmp=0; icmp<48; icmp=icmp+1) begin: s2
               initial vpf_s2[icmp] = 0; initial cnt_s2[icmp] = 0; initial key_s2[icmp] = 0;
               `always_s2
                 {vpf_s2[icmp], cnt_s2[icmp], key_s2[icmp]} = vpf_s1[icmp*2] ?  {vpf_s1[icmp*2  ], cnt_s1[icmp*2], {1'b0,key_s1[icmp*2  ]}} : {vpf_s1[icmp*2+1], cnt_s1[icmp*2+1], {1'b1,key_s1[icmp*2+1]}};
            end

         // Stage 3 : 24 of 48
            for (icmp=0; icmp<24; icmp=icmp+1) begin: s3
               initial vpf_s3[icmp] = 0; initial cnt_s3[icmp] = 0; initial key_s3[icmp] = 0;
               `always_s3
                 {vpf_s3[icmp], cnt_s3[icmp], key_s3[icmp]} = vpf_s2[icmp*2] ?  {vpf_s2[icmp*2  ], cnt_s2[icmp*2], {1'b0,key_s2[icmp*2  ]}} : {vpf_s2[icmp*2+1], cnt_s2[icmp*2+1], {1'b1,key_s2[icmp*2+1]}};
            end

         // Stage 4 : 12 of 24
            for (icmp=0; icmp<12; icmp=icmp+1) begin: s4
               initial vpf_s4[icmp] = 0; initial cnt_s4[icmp] = 0; initial key_s4[icmp] = 0;
               `always_s4
                 {vpf_s4[icmp], cnt_s4[icmp], key_s4[icmp]} = vpf_s3[icmp*2] ?  {vpf_s3[icmp*2  ], cnt_s3[icmp*2], {1'b0,key_s3[icmp*2  ]}} : {vpf_s3[icmp*2+1], cnt_s3[icmp*2+1], {1'b1,key_s3[icmp*2+1]}};
            end

         // Stage 5 : 6 of 12
            for (icmp=0; icmp<6; icmp=icmp+1) begin: s5
               initial vpf_s5[icmp] = 0; initial cnt_s5[icmp] = 0; initial key_s5[icmp] = 0;
               `always_s5
                 {vpf_s5[icmp], cnt_s5[icmp], key_s5[icmp]} = vpf_s4[icmp*2] ?  {vpf_s4[icmp*2  ], cnt_s4[icmp*2], {1'b0,key_s4[icmp*2  ]}} : {vpf_s4[icmp*2+1], cnt_s4[icmp*2+1], {1'b1,key_s4[icmp*2+1]}};
            end

         // Stage 6 : 3 of 6
            for (icmp=0; icmp<3; icmp=icmp+1) begin: s6
               initial vpf_s6[icmp] = 0; initial cnt_s6[icmp] = 0; initial key_s6[icmp] = 0;
               `always_s6
                 {vpf_s6[icmp], cnt_s6[icmp], key_s6[icmp]} = vpf_s5[icmp*2] ?  {vpf_s5[icmp*2  ], cnt_s5[icmp*2], {1'b0,key_s5[icmp*2  ]}} : {vpf_s5[icmp*2+1], cnt_s5[icmp*2+1], {1'b1,key_s5[icmp*2+1]}};
            end

         // Stage 7: 1 of 3 Parallel Encoder
         always @(*)
           begin
              if      (vpf_s6[0]) {vpf, cnt, key} = {vpf_s6[0], cnt_s6[0], {2'b00, key_s6[0]}};
              else if (vpf_s6[1]) {vpf, cnt, key} = {vpf_s6[1], cnt_s6[1], {2'b01, key_s6[1]}};
              else if (vpf_s6[2]) {vpf, cnt, key} = {vpf_s6[2], cnt_s6[2], {2'b10, key_s6[2]}};
              else   begin
                 vpf <= 0;
                 cnt <= 0;
                 key <= ~0;
              end
                end

         `always_out begin
            cnt_o <= cnt;
            vpf_o <= vpf;
            adr_o <= key;
         end
         end
      endgenerate

   generate
      if (MXKEYS == 384) begin
         //----------------------------------------------------------------------------------------------------------------------
         // Wires
         //----------------------------------------------------------------------------------------------------------------------

         reg [2:0] pass_s0 = 0;
         reg [2:0] pass_s1 = 0;
         reg [2:0] pass_s2 = 0;
         reg [2:0] pass_s3 = 0;
         reg [2:0] pass_s4 = 0;
         reg [2:0] pass_s5 = 0;
         reg [2:0] pass_s6 = 0;
         reg [2:0] pass_s7 = 0;

         reg [383:0] vpf_s0 = 0;
         reg [191:0] vpf_s1 = 0;
         reg [95:0]  vpf_s2 = 0;
         reg [47:0]  vpf_s3 = 0;
         reg [23:0]  vpf_s4 = 0;
         reg [11:0]  vpf_s5 = 0;
         reg [5:0]   vpf_s6 = 0;
         reg [2:0]   vpf_s7 = 0;
         reg         vpf = 0;

         reg [0:0]   key_s1 [191:0];
         reg [1:0]   key_s2 [95:0];
         reg [2:0]   key_s3 [47:0];
         reg [3:0]   key_s4 [23:0];
         reg [4:0]   key_s5 [11:0];
         reg [5:0]   key_s6 [5:0];
         reg [6:0]   key_s7 [2:0];
         reg [8:0]   key;

         reg [2:0]   cnt_s0 [383:0];
         reg [2:0]   cnt_s1 [191:0];
         reg [2:0]   cnt_s2 [95:0];
         reg [2:0]   cnt_s3 [47:0];
         reg [2:0]   cnt_s4 [23:0];
         reg [2:0]   cnt_s5 [11:0];
         reg [2:0]   cnt_s6 [5:0];
         reg [2:0]   cnt_s7 [2:0];

         reg [2:0]   cnt;

         // choose here to specify pipeline register stages
         `define always_in  always @(*)
         `define always_s0  always @(*)
         `define always_s1  always @(posedge clock)
         `define always_s2  always @(*)
         `define always_s3  always @(*)
         `define always_s4  always @(*)
         `define always_s5  always @(posedge clock)
         `define always_s6  always @(*)
         `define always_s7  always @(*)
         `define always_out always @(*)

         `always_s1  pass_s1 <= pass_s0;
         `always_s2  pass_s2 <= pass_s1;
         `always_s3  pass_s3 <= pass_s2;
         `always_s4  pass_s4 <= pass_s3;
         `always_s5  pass_s5 <= pass_s4;
         `always_s6  pass_s6 <= pass_s5;
         `always_s7  pass_s7 <= pass_s6;
         `always_out pass_o   <= pass_s7;

         `always_in pass_s0 <= pass_i;
         `always_in vpf_s0 <= vpfs_i;

         //Remap flattened count bits into a 2D vector
         genvar      ipad;
         for (ipad=0; ipad<384; ipad=ipad+1) begin: padloop
            `always_in
                   cnt_s0 [ipad] <= cnts_i [ipad*3+2:ipad*3];
         end

         //----------------------------------------------------------------------------------------------------------------------
         // Comparators
         //----------------------------------------------------------------------------------------------------------------------

         genvar icmp;

         // Stage 1 : 192 of 384
         for (icmp=0; icmp<192; icmp=icmp+1) begin: s1
            initial vpf_s1[icmp] = 0; initial cnt_s1[icmp] = 0; initial key_s1[icmp] = 0;
            `always_s1 {vpf_s1[icmp], cnt_s1[icmp], key_s1[icmp]} = vpf_s0[icmp*2] ?  {vpf_s0[icmp*2  ], cnt_s0[icmp*2], 1'b0} : {vpf_s0[icmp*2+1], cnt_s0[icmp*2+1], 1'b1};
         end


         // Stage 2 : 96 of 192
         for (icmp=0; icmp<96; icmp=icmp+1) begin: s2
            initial vpf_s2[icmp] = 0; initial cnt_s2[icmp] = 0; initial key_s2[icmp] = 0;
            `always_s2 {vpf_s2[icmp], cnt_s2[icmp], key_s2[icmp]} = vpf_s1[icmp*2] ?  {vpf_s1[icmp*2  ], cnt_s1[icmp*2], {1'b0,key_s1[icmp*2  ]}} : {vpf_s1[icmp*2+1], cnt_s1[icmp*2+1], {1'b1,key_s1[icmp*2+1]}};
         end

         // Stage 3 : 48 of 96
         for (icmp=0; icmp<48; icmp=icmp+1) begin: s3
            initial vpf_s3[icmp] = 0; initial cnt_s3[icmp] = 0; initial key_s3[icmp] = 0;
            `always_s3 {vpf_s3[icmp], cnt_s3[icmp], key_s3[icmp]} = vpf_s2[icmp*2] ?  {vpf_s2[icmp*2  ], cnt_s2[icmp*2], {1'b0,key_s2[icmp*2  ]}} : {vpf_s2[icmp*2+1], cnt_s2[icmp*2+1], {1'b1,key_s2[icmp*2+1]}};
         end

         // Stage 4 : 24 of 48
         for (icmp=0; icmp<24; icmp=icmp+1) begin: s4
            initial vpf_s4[icmp] = 0; initial cnt_s4[icmp] = 0; initial key_s4[icmp] = 0;
            `always_s4 {vpf_s4[icmp], cnt_s4[icmp], key_s4[icmp]} = vpf_s3[icmp*2] ?  {vpf_s3[icmp*2  ], cnt_s3[icmp*2], {1'b0,key_s3[icmp*2  ]}} : {vpf_s3[icmp*2+1], cnt_s3[icmp*2+1], {1'b1,key_s3[icmp*2+1]}};
         end

         // Stage 5 : 12 of 24
         for (icmp=0; icmp<12; icmp=icmp+1) begin: s5
            initial vpf_s5[icmp] = 0; initial cnt_s5[icmp] = 0; initial key_s5[icmp] = 0;
            `always_s5 {vpf_s5[icmp], cnt_s5[icmp], key_s5[icmp]} = vpf_s4[icmp*2] ?  {vpf_s4[icmp*2  ], cnt_s4[icmp*2], {1'b0,key_s4[icmp*2  ]}} : {vpf_s4[icmp*2+1], cnt_s4[icmp*2+1], {1'b1,key_s4[icmp*2+1]}};
         end

         // Stage 6 : 6 of 12
         for (icmp=0; icmp<6; icmp=icmp+1) begin: s6
            initial vpf_s6[icmp] = 0; initial cnt_s6[icmp] = 0; initial key_s6[icmp] = 0;
            `always_s6 {vpf_s6[icmp], cnt_s6[icmp], key_s6[icmp]} = vpf_s5[icmp*2] ?  {vpf_s5[icmp*2  ], cnt_s5[icmp*2], {1'b0,key_s5[icmp*2  ]}} : {vpf_s5[icmp*2+1], cnt_s5[icmp*2+1], {1'b1,key_s5[icmp*2+1]}};
         end

         // Stage 7 : 3 of 6
         for (icmp=0; icmp<3; icmp=icmp+1) begin: s7
            initial vpf_s7[icmp] = 0; initial cnt_s7[icmp] = 0; initial key_s7[icmp] = 0;
            `always_s7 {vpf_s7[icmp], cnt_s7[icmp], key_s7[icmp]} = vpf_s6[icmp*2] ?  {vpf_s6[icmp*2  ], cnt_s6[icmp*2], {1'b0,key_s6[icmp*2  ]}} : {vpf_s6[icmp*2+1], cnt_s6[icmp*2+1], {1'b1,key_s6[icmp*2+1]}};
         end

         // Stage 8: 1 of 3 Parallel Encoder
         always @(*)
           begin
              if      (vpf_s7[0]) {vpf, cnt, key} = {vpf_s7[0], cnt_s7[0], {2'b00, key_s7[0]}};
              else if (vpf_s7[1]) {vpf, cnt, key} = {vpf_s7[1], cnt_s7[1], {2'b01, key_s7[1]}};
              else if (vpf_s7[2]) {vpf, cnt, key} = {vpf_s7[2], cnt_s7[2], {2'b10, key_s7[2]}};
              else   begin
                 vpf =  0;
                 cnt =  0;
                 key = ~0;
              end
                end

         `always_out begin
            cnt_o = cnt;
            vpf_o = vpf;
            adr_o = key;
         end

      end
   endgenerate

//----------------------------------------------------------------------------------------------------------------------
endmodule
//----------------------------------------------------------------------------------------------------------------------
