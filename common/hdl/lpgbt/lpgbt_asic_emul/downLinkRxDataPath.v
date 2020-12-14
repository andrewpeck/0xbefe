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
 *  file: downLinkDeinterleaver.v
 *
 *  downLinkDeinterleaver
 *
 *  History:
 *  2016/05/20 Szymon Kulis    : Created
 *  2016/11/02 José Fonseca    : Modified
 *  2017/03/27 Eduardo Brandao de Souza Mendes    : Modified for FPGA impl.
 *
 **/

module downLinkRxDataPath (
    // Clocks inputs:
    input         clk,

    // data input
    input  [63:0] downLinkFrame,

    // data outputs
	output reg    dataStrobe,
    output [31:0] dataOut,
    output [1:0]  dataEC,
    output [1:0]  dataIC,
    output [3:0]  header,

    // control signals
	input         dataEnable,
    input         bypassDeinterleaver,
    input         bypassFECDecoder,
    input         bypassDescrambler,

    // -- fec error corrected --
    output reg [15:0] fecCorrectionCount
    );

// -------------------------------------------------------------------------- //
// ------------- Triple Modular Redundancy Generator Directives ------------- //
// -------------------------------------------------------------------------- //
// tmrg default triplicate
// tmrg do_not_triplicate downLinkFrame
// -------------------------------------------------------------------------- //


	wire [35:0] dataDeint;
	wire [23:0] fecDeint;
	wire [35:0] decData;
	reg  [35:0] decDataReg;
	wire [35:0] descrambledData;
	reg  [63:0] downLinkFrameReg;

	wire [15:0] fecCorrectionCountComb;
	
  downLinkDeinterleaver DLD (
    .bypass(bypassDeinterleaver),
    .downLinkFrame(downLinkFrame),
    .data(dataDeint),
    .fec(fecDeint)
  );

  downLinkFECDecoder DLFD (
    .clk(clk),
    .bypass(bypassFECDecoder),
    .data(dataDeint),
    .fec(fecDeint),
    .dataOut(decData),
    .fecCorrectionCount(fecCorrectionCountComb)
  );

  descrambler36bitOrder36 DES (
    .bypass(bypassDescrambler),
    .clock(clk),
	.enable(dataEnable),
    .scrambledData(decData),
    .descrambledData(descrambledData)
  );

  assign dataOut = descrambledData[31:0];
  assign dataEC  = descrambledData[33:32];
  assign dataIC  = descrambledData[35:34];

	always @(posedge clk)
	begin
		dataStrobe <= dataEnable;
		if(dataEnable)
			fecCorrectionCount <= fecCorrectionCountComb;
	end	
  
  
//  assign  header = downLinkFrame[63:60];  // version with the header in front
  assign  header = {downLinkFrame[63],downLinkFrame[61],downLinkFrame[59],downLinkFrame[57]}; // header interleaved with data for DC balance

endmodule
