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
 *  file: downLinkFECDecoder.v
 *
 *  downLinkFECDecoder
 *
 *  History:
 *  2016/05/20 Szymon Kulis    : Created
 *  2016/11/02 José Fonseca    : Modified
 *  2017/04/03 Eduardo Brandao de Souza Mendes  : Removed error correction counter from this level for FPGA impl.
 **/

module downLinkFECDecoder (
    input             clk,
    input             bypass,
    input      [35:0] data,
    input      [23:0] fec,
    output     [35:0] dataOut,
    output     [15:0] fecCorrectionCount
);

// -------------------------------------------------------------------------- //
// ------------- Triple Modular Redundancy Generator Directives ------------- //
// -------------------------------------------------------------------------- //
// tmrg do_not_touch
// -------------------------------------------------------------------------- //

	

	wire [20:0] virtualFrame_C0;
	wire [20:0] virtualFrame_C1;
	wire [20:0] virtualFrame_C2;
	wire [20:0] virtualFrame_C3;
	wire [14:0] decData_C0;
	wire [14:0] decData_C1;
	wire [14:0] decData_C2;
	wire [14:0] decData_C3;
	wire [1:0] fecErrorSub0;
	wire [1:0] fecErrorSub1;
	wire [1:0] fecErrorSub2;
	wire [1:0] fecErrorSub3;

	assign virtualFrame_C0 = {fec[5:0],   6'b0, data[8:0]};
	assign virtualFrame_C1 = {fec[11:6],  6'b0, data[17:9]};
	assign virtualFrame_C2 = {fec[17:12], 6'b0, data[26:18]};
	assign virtualFrame_C3 = {fec[23:18], 6'b0, data[35:27]};

	
	rs_decoder_N7K5 RSD0 (
		.msgInput(virtualFrame_C0),
		.error(fecErrorSub0),
		.decMsg(decData_C0)
		);

	rs_decoder_N7K5 RSD1 (
		.msgInput(virtualFrame_C1),
		.error(fecErrorSub1),
		.decMsg(decData_C1)
		);

	rs_decoder_N7K5 RSD2 (
		.msgInput(virtualFrame_C2),
		.error(fecErrorSub2),
		.decMsg(decData_C2)
		);

	rs_decoder_N7K5 RSD3 (
		.msgInput(virtualFrame_C3),
		.error(fecErrorSub3),
		.decMsg(decData_C3)
		);

	assign fecCorrectionCount = fecErrorSub0+fecErrorSub1+fecErrorSub2+fecErrorSub3;

	assign dataOut = (bypass) ? data : {decData_C3[8:0], decData_C2[8:0], decData_C1[8:0], decData_C0[8:0]};

endmodule
