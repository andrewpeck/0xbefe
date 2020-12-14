/* Module: Descrambler36bitOrder36                                      */
/* Created: Paulo Moreira, 2015/09/15                                        */
/* Institute: CERN                                                           */
/* Version: 1.0                                                              */

/* Descrambler width: 36 - bits                                              */
/* Descrambler order: 36                                                     */
/* Recursive equation used for the scrambler: Si = Di xnor Si-25 xnor Si-36  */

`timescale 1 ps / 1 ps

module descrambler36bitOrder36(
    input [35:0] scrambledData,
    input clock,
	input enable,
    input bypass,
    output reg [35:0] descrambledData
    );

reg  [35:0] memoryRegister;
wire [35:0] iMemoryRegister;
wire [35:0] iMemoryRegisterVoted = iMemoryRegister;

wire [35:0] iDescrambledData;
wire [35:0] iDescrambledDataVoted = iDescrambledData;

always @(posedge clock)
    begin
	if(enable==1'b1) begin
		memoryRegister  <= iMemoryRegisterVoted;
		descrambledData <= iDescrambledDataVoted;
	end	
end

// Descrambler polynomial and bypass mux    
assign
    iDescrambledData[35:25] = (bypass)? scrambledData[35:25] : scrambledData[35:25] ~^ scrambledData[10:0]  ~^ memoryRegister[35:25],
    iDescrambledData[24:0]  = (bypass)? scrambledData[34:0]  : scrambledData[24:0]  ~^ memoryRegister[35:11] ~^ memoryRegister[24:0],
    iMemoryRegister[35:0]   = (bypass)? 36'h000000000 : scrambledData[35:0];
    
endmodule
