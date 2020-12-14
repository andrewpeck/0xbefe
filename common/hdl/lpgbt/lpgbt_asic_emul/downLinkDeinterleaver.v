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
 * 
 **/

module downLinkDeinterleaver (
    input         bypass,
    input  [63:0] downLinkFrame,
    output [35:0] data,
    output [23:0] fec
    );

// -------------------------------------------------------------------------- //
// ------------- Triple Modular Redundancy Generator Directives ------------- //
// -------------------------------------------------------------------------- //

// -------------------------------------------------------------------------- //

	// Code 0
	assign data[8:0]    = (bypass) ?  downLinkFrame[32:24] : {downLinkFrame[50:48], downLinkFrame[38:36], downLinkFrame[26:24]};
	assign fec[5:0]     = (bypass) ?  downLinkFrame[5:0]   : {downLinkFrame[14:12], downLinkFrame[2:0]};

	// Code 1
	assign data[17:9]   = (bypass) ? downLinkFrame[41:33] : {downLinkFrame[53:51], downLinkFrame[41:39], downLinkFrame[29:27]};
	assign fec[11:6]    = (bypass) ? downLinkFrame[11:6]  : {downLinkFrame[17:15], downLinkFrame[5:3]};
   
	// Code 2
	assign data[26:18]  = (bypass) ? downLinkFrame[50:42] : {downLinkFrame[56:54], downLinkFrame[44:42], downLinkFrame[32:30]};
	assign fec[17:12]   = (bypass) ? downLinkFrame[17:12] : {downLinkFrame[20:18], downLinkFrame[8:6]};

	// Code 3
	assign data[35:27]  = (bypass) ? {downLinkFrame[62], downLinkFrame[60], downLinkFrame[58],  downLinkFrame[56:51]} : {downLinkFrame[62], downLinkFrame[60], downLinkFrame[58], downLinkFrame[47:45], downLinkFrame[35:33]};
	assign fec[23:18]   = (bypass) ? downLinkFrame[23:18] : {downLinkFrame[23:21], downLinkFrame[11:9]};

endmodule
