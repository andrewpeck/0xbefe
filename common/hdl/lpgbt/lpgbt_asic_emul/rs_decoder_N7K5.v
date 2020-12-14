/** ****************************************************************************
 *  lpGBTX                                                                     *
 *  Copyright (C) 2011-2016 GBTX Team, CERN                                    *
 *                                                                             *
 *  This IP block is free for HEP experiments and other scientific research    *
 *  purposes. Commercial exploitation of a chip containing the IP is not       *
 *  permitted.  You can not redistribute the IP without written permission     *
 *  from the authors. Any modifications of the IP have to be communicated back *
 *  to the authors. The use of the IP should be acknowledged in publications,  *
 *  public presentations, user manual, and other documents.                    *
 *                                                                             *
 *  This IP is distributed in the hope that it will be useful, but WITHOUT ANY *
 *  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS  *
 *  FOR A PARTICULAR PURPOSE.                                                  *
 *                                                                             *
 *******************************************************************************
 *
 *  file: rs_decoder_N7K5.v
 *
 *  rs_decoder_N7K5
 *
 *  History:
 *  2016/09    José Fonseca    : Created
 *  2016/10/06 José Fonseca    : Concluded
 * 
 **/

module rs_decoder_N7K5(msgInput, error, decMsg);

// -------------------------------------------------------------------------- //
// ------------- Triple Modular Redundancy Generator Directives ------------- //
// -------------------------------------------------------------------------- //
// tmrg do_not_touch
// -------------------------------------------------------------------------- //
	
	parameter N = 7;
	parameter K = 5;
	parameter m = 3;
	parameter INP_BW = N*m;
	parameter OUT_BW = K*m;

	// IO definitions
	input      [INP_BW-1:0] msgInput;
	output [1:0] error;
	output reg [OUT_BW-1:0] decMsg;

	// Connection wires and regs
	wire [m-1:0] outSt1;
	wire [m-1:0] outSt2;
	wire [m-1:0] outSt3;
	wire [m-1:0] outSt4;
	wire [m-1:0] outSt5;
	wire [m-1:0] outSt6;
	wire [m-1:0] outAdd0;
	wire [m-1:0] outAdd1;
	wire [m-1:0] outAdd2;
	wire [m-1:0] outAdd3;
	wire [m-1:0] outAdd4;
	wire [m-1:0] outAdd5;
	wire [m-1:0] outMult0;
	wire [m-1:0] outMult1;
	wire [m-1:0] outMult2;
	wire [m-1:0] outMult3;
	wire [m-1:0] outMult4;
	wire [m-1:0] outMult5;
	wire [m-1:0] outMult6;
	wire [m-1:0] syndr0;
	wire [m-1:0] syndr1;
	wire [m-1:0] syndr0_inv;
	wire [m-1:0] syndrProd;
	wire [m-1:0] errorPos;

	// Evaluating the first syndrome
	gf_add_3    ADD_0   (.op1(msgInput[0 +: m]),   .op2(msgInput[m +: m]), .res(outSt1));
	gf_add_3    ADD_1   (.op1(msgInput[2*m +: m]), .op2(outSt1),      .res(outSt2));
	gf_add_3    ADD_2   (.op1(msgInput[3*m +: m]), .op2(outSt2),      .res(outSt3));
	gf_add_3    ADD_3   (.op1(msgInput[4*m +: m]), .op2(outSt3),      .res(outSt4));
	gf_add_3    ADD_4   (.op1(msgInput[5*m +: m]), .op2(outSt4),      .res(outSt5));
	gf_add_3    ADD_5   (.op1(msgInput[6*m +: m]), .op2(outSt5),      .res(syndr0));
	
	// Evaluating the second syndrome
	gf_multBy2_3  MULT2_0 (.op(msgInput[0 +: m]), .res(outMult0));
	gf_add_3      ADD1_0  (.op1(outMult0), .op2(msgInput[m +: m]), .res(outAdd0));	

	gf_multBy2_3  MULT2_1 (.op(outAdd0), .res(outMult1));
	gf_add_3      ADD1_1  (.op1(outMult1), .op2(msgInput[2*m +: m]), .res(outAdd1));	

	gf_multBy2_3  MULT2_2 (.op(outAdd1), .res(outMult2));
	gf_add_3      ADD1_2  (.op1(outMult2), .op2(msgInput[3*m +: m]), .res(outAdd2));	

	gf_multBy2_3  MULT2_3 (.op(outAdd2), .res(outMult3));
	gf_add_3      ADD1_3  (.op1(outMult3), .op2(msgInput[4*m +: m]), .res(outAdd3));	

	gf_multBy2_3  MULT2_4 (.op(outAdd3), .res(outMult4));
	gf_add_3      ADD1_4  (.op1(outMult4), .op2(msgInput[5*m +: m]), .res(outAdd4));	

	gf_multBy2_3  MULT2_5 (.op(outAdd4), .res(outMult5));
	gf_add_3      ADD1_5  (.op1(outMult5), .op2(msgInput[6*m +: m]), .res(syndr1));	

	// Evaluate position of error
	gf_inv_3    INV3   (.op(syndr0), .res(syndr0_inv));
	gf_mult_3   MULT3  (.op1(syndr0_inv), .op2(syndr1), .res(syndrProd));
	gf_log_3    LOG3   (.op(syndrProd), .err(domainErr), .res(errorPos));

	// Number of Errors
	assign error = syndr0[0] + syndr0[1] + syndr0[2]; 

	// Correct message.. Correction on parity bits is ignored!
	always @* begin
		if(errorPos == 3'd2)
			decMsg[4*m +: m] = msgInput[4*m +: m] ^ syndr0;
		else 
			decMsg[4*m +: m] = msgInput[4*m +: m];
		
		if(errorPos == 3'd3)
			decMsg[3*m +: m] = msgInput[3*m +: m] ^ syndr0;
		else 
			decMsg[3*m +: m] = msgInput[3*m +: m];

		if(errorPos == 3'd4)
			decMsg[2*m +: m] = msgInput[2*m +: m] ^ syndr0;
		else 
			decMsg[2*m +: m] = msgInput[2*m +: m];

		if(errorPos == 3'd5)
			decMsg[m +: m] = msgInput[m +: m] ^ syndr0;
		else 
			decMsg[m +: m] = msgInput[m +: m];

		if(errorPos == 3'd6)
			decMsg[0 +: m] = msgInput[0 +: m] ^ syndr0;
		else 
			decMsg[0 +: m] = msgInput[0 +: m];
	end

endmodule
