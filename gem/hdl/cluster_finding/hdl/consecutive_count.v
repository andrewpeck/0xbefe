/*  JRG, 17 Dec 2015
 Count how many CONSECUTIVE bits are High in a cluster of S-bits as fast as possible:
   starting from a "10" sequence, count up to 7 additional 1 bits in sequence.
     --handles clusters up to 16 pads (makes them two separate clusters) when we have "1+111111110" pattern.
     --reports a count for every set of "10" or "1+111111110" S-bit seed pattern we see...
     --upper level module must provide the next 7 bits after pad "i" any time the above seeds are detected.
 Run this in parallel on each of the 1536 S-bit inputs? So 1536 instances are created!
     -- for edge of GEM cases, set non-existing s-bits to 0 of course.
 The result is ready after a single clock (one clock latency) for any 8-bit sequence.

 Note... not sure how fast this can run, but probably 160 MHz or more...
*/

module consecutive_count  ( // one logic step, could run at 320 MHz easy!
    clock, // This could be inverted lhc_clk or 80 MHz or a 1/4 phase shifted clk for optimal speed.
    sbit,  // Here we hand the *next 7* s-bits to this module and save the result for any s-bit i...
    count  // <<-3-bit output          ...where this is true:  [i:i-1]=2'b10 || [i:i-9]=10'b1111111110
   );

/*
  Count how many consecutive s-bits are set in the cluster after s-bit i.
  The next 7 s-bits go to the counting logic, with the result going to a clocked register with sync reset.
  If the next s-bit (i+1) is zero then the count is zero, so that will reset the register.
  At the upper level, only mark the cluster as valid if  sbit[i:i-1]=2'b10 || sbit[i:i-9]=10'b1111111110
*/

   input  clock;
   input  [6:0] sbit; // Note! This is s-bits i+1 to i+7 for candidate cluster i
   output [2:0]  count ;

   reg [2:0] 	 sum = 0; // sum <= cons_count(sbit[6:1]);

   assign count=sum;


   always @(posedge clock) begin  // uses sbit0 here (the 2nd bit of the cluster) as a sync register reset
      if (!sbit[0]) sum <= 0;
      else  sum <= cons_count(sbit[6:1]);
   end

   function [2:0] cons_count;  // do a fast count of 6 consecutive bits, in a single logic step!
      input [6:1] s;  // note bits 6:1 = sbit[i+7:i+2] are used here, and bit0 (sbit[i+1]) is implied true (else count gets reset)
      begin           //   of course sbit[i] is also assumed to be true (it's required to be a valid cluster pattern)
      cons_count[2] = &s[3:1];   // 4+ s-bits in a row will always trigger bit 2 of the count
      cons_count[1] = &s[5:1] |  s[3:1]==3'b011 |  s[2:1]==2'b01; // count 2,3,6,7... not 1,4,5
      cons_count[0] = &s[6:1] | s[5:1]==5'b01111 | s[3:1]==3'b011 | s[1]==1'b0; // count 1,3,5,7... not 2,4,6
      end
   endfunction

//------------------------------------------------------------------------------------------------------------------
endmodule
//------------------------------------------------------------------------------------------------------------------
