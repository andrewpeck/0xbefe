//---------------------------------------------------------------------------------------------------
//--  Project          : VFAT3/DataFormatter/ Cyclic Redundancy Check
//--  File description : File contains CRC code generator
//--  File name        : crc-ccitt.v
//--  Author           : Mieczyslaw Dabrowski
//--  Version          : V1.0
//---------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------
//--  File history:	Created 04/04/2013
//---------------------------------------------------------------------------------------------------
//--  Remarks: Default parameters produce a CRC16-CCITT output.
//--
//--		   Parameters:
//--
//--		   CRC_WIDTH 		- bit width of the CRC checksum
//--		   DATA_WIDTH 		- bit width of the input data
//--		   INIT_VAL			- initial value of CRC register
//--		   POLY				- CRC polynomial
//--
//--  This block performs a division of data by the polynomial in modulo 2 arithmetic
//---------------------------------------------------------------------------------------------------
//-- ### Verified
//---------------------------------------------------------------------------------------------------

module crc_vfat3_daq (clk, reset, SLEEP, ReSync, Data_in, Data_valid_in, Init_in, CRC_out, CRC_ok_out);
	
	// ---------------- PARAMETERs ---------------------	
	parameter CRC_WIDTH = 16;
	parameter DATA_WIDTH = 8;
	parameter INIT_VAL = 'hffff;
	parameter POLY = 'h1021;

	// ---------------- INPUTs ------------------------- 	
	input clk, reset, ReSync;
	input SLEEP;
	input [(DATA_WIDTH-1):0] Data_in;
	input Init_in;
	input Data_valid_in;
	
	// --------------- OUTPUTs -------------------------
	output wire [(CRC_WIDTH-1):0] CRC_out;
	output wire CRC_ok_out;
	
	// ----------- Internal Signals --------------------
	reg  [(CRC_WIDTH-1):0] CRC_p;		// present state
	wire [(CRC_WIDTH-1):0] CRC_n;		// present state
	wire [(CRC_WIDTH-1):0] CRC_value;	//<< value that would go to the CRC_Calc function
	
//---------------------------------------------------------------------------------------------
//-------------------------    Behavioral    --------------------------------------------------
//---------------------------------------------------------------------------------------------
	
	// --------- Concurrent assignments ---------------
	// Computation of present CRC value (the value also defines the next state of CRC register)
	assign CRC_out = CRC_p;
	
	// If the next value of CRC will be zero, CRC_ok signal changes to high. 
	assign CRC_ok_out = (CRC_out == 0) ? 1 : 0;
	
	// Value passed to CRC_Calc function
	assign CRC_value = (Init_in) ? INIT_VAL : CRC_p;
	
	// In order to avoid combinational loops, the computed value of CRC is stored in a register. Therefore it's available in the next clock cycle
	assign CRC_n = (Data_valid_in) ? CRC_Calc(CRC_value, Data_in) : CRC_p;

		
	// --------- Sequential process ------------------- 
	always @(posedge clk, posedge reset) begin
		if (reset)
			CRC_p <= 0;
		else
			if (SLEEP || ReSync)
				CRC_p <= 0;
			else
				CRC_p <= CRC_n;
	end
	
	// ----------- Functions --------------------
	function [(CRC_WIDTH-1):0] CRC_Calc;
		input [(CRC_WIDTH-1):0] CRC_in;
		input [(DATA_WIDTH-1):0] Data_in;
		
		reg [(CRC_WIDTH-1):0] crc;
		
		integer i;
		begin
			crc = CRC_in;
			for ( i=(DATA_WIDTH-1); i>=0; i=i-1) begin
				if (Data_in[i]^crc[CRC_WIDTH-1])
					crc = (crc << 1) ^ POLY;
				else
					crc = (crc << 1);
			end
			CRC_Calc = crc;
		end
	endfunction
	
endmodule
