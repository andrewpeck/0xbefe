//------------------------------------------------------------------------------
//  (c) Copyright 2013-2018 Xilinx, Inc. All rights reserved.
//
//  This file contains confidential and proprietary information
//  of Xilinx, Inc. and is protected under U.S. and
//  international copyright and other intellectual property
//  laws.
//
//  DISCLAIMER
//  This disclaimer is not a license and does not grant any
//  rights to the materials distributed herewith. Except as
//  otherwise provided in a valid license issued to you by
//  Xilinx, and to the maximum extent permitted by applicable
//  law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
//  WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
//  AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
//  BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
//  INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
//  (2) Xilinx shall not be liable (whether in contract or tort,
//  including negligence, or under any other theory of
//  liability) for any loss or damage of any kind or nature
//  related to, arising under or in connection with these
//  materials, including for any direct, or any indirect,
//  special, incidental, or consequential loss or damage
//  (including loss of data, profits, goodwill, or any type of
//  loss or damage suffered as a result of any action brought
//  by a third party) even if such damage or loss was
//  reasonably foreseeable or Xilinx had been advised of the
//  possibility of the same.
//
//  CRITICAL APPLICATIONS
//  Xilinx products are not designed or intended to be fail-
//  safe, or for use in any application requiring fail-safe
//  performance, such as life-support or safety devices or
//  systems, Class III medical devices, nuclear facilities,
//  applications related to the deployment of airbags, or any
//  other applications that could lead to death, personal
//  injury, or severe property or environmental damage
//  (individually and collectively, "Critical
//  Applications"). Customer assumes the sole risk and
//  liability of any use of Xilinx products in Critical
//  Applications, subject only to applicable laws and
//  regulations governing limitations on product liability.
//
//  THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
//  PART OF THIS FILE AT ALL TIMES.
//------------------------------------------------------------------------------


`timescale 1ps/1ps

// =====================================================================================================================
// This example design stimulus module generates PRBS31 data at the appropriate parallel data width for the transmitter,
// along with any sideband signaling necessary for the selected data encoding. The stimulus provided by this module
// instance drives a single transceiver channel for data transmission demonstration purposes.
// =====================================================================================================================

module c2c_mgt_example_stimulus_8b10b (
  input  wire         gtwiz_reset_all_in,
  input  wire         gtwiz_userclk_tx_usrclk2_in,
  input  wire         gtwiz_userclk_tx_active_in,
  output wire  [15:0] txctrl0_out,
  output wire  [15:0] txctrl1_out,
  output wire   [7:0] txctrl2_out,
  output wire [31:0] txdata_out
);


  // -------------------------------------------------------------------------------------------------------------------
  // Reset synchronizer
  // -------------------------------------------------------------------------------------------------------------------

  // Synchronize the example stimulus reset condition into the txusrclk2 domain
  wire example_stimulus_reset_int = gtwiz_reset_all_in || ~gtwiz_userclk_tx_active_in;
  wire example_stimulus_reset_sync;

  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_example_reset_synchronizer example_stimulus_reset_synchronizer_inst (
    .clk_in  (gtwiz_userclk_tx_usrclk2_in),
    .rst_in  (example_stimulus_reset_int),
    .rst_out (example_stimulus_reset_sync)
  );


  // -------------------------------------------------------------------------------------------------------------------
  // PRBS generator output enable and control generation
  // -------------------------------------------------------------------------------------------------------------------

  // For 8B/10B mode data transmission, the PRBS generator is always enabled
  wire prbs_any_gen_en_int = 1'b1;

  // Declare a txdata vector to be driven by the PRBS generator, a txdata vector to be driven by a comma alignment
  // character, and a txdata register that is used to synchronously capture and drive one of the two. Perform other
  // continuous assignments required for this use mode.
  wire   [31:0] txdata_prbs;
  wire   [31:0] txdata_char = {4{8'hBC}};
  reg    [31:0] txdata_reg  = 32'b0;
  reg    [7:0]  txctrl2_reg = 8'b0;
  assign        txctrl0_out = 16'b0;
  assign        txctrl1_out = 16'b0;
  assign        txctrl2_out = txctrl2_reg;
  assign        txdata_out  = txdata_reg;

  // Simply drive the comma alignment character for a short period of time upon bring-up to allow the receiver to align,
  // and then continually select the PRBS data afterwards. This provides a continuous stream of PRBS data to the aligned
  // receiver. Note that this simple mechanism assumes the receiver is operating by the time the prbs_slt_ctr counter
  // has saturated. This is sufficient for loopback demonstration of this example design, as this example stimulus
  // module is also held in reset until the receiver completes its reset sequence; but chip-to-chip or more complex
  // adaptations of this example design may require modifications for robustness.
  reg [9:0] prbs_slt_ctr = 10'd0;

  always @(posedge gtwiz_userclk_tx_usrclk2_in) begin
    if (example_stimulus_reset_sync) begin
      txdata_reg   <= 32'b0;
      txctrl2_reg  <= 8'b0;
      prbs_slt_ctr <= 10'd0;
    end
    else begin
      if (&prbs_slt_ctr) begin
        txdata_reg  <= txdata_prbs;
        txctrl2_reg <= 8'b0;
      end
      else begin
        txdata_reg   <= txdata_char;
        txctrl2_reg  <= 8'b0000_1111;
        prbs_slt_ctr <= prbs_slt_ctr + 10'd1;
      end
    end
  end


  // -------------------------------------------------------------------------------------------------------------------
  // PRBS generator block
  // -------------------------------------------------------------------------------------------------------------------

  // The prbs_any block, described in Xilinx Application Note 884 (XAPP884), "An Attribute-Programmable PRBS Generator
  // and Checker", generates or checks a parameterizable PRBS sequence. Instantiate and parameterize a prbs_any block
  // to generate a PRBS31 sequence with parallel data sized to the transmitter user data width.
  c2c_mgt_prbs_any # (
    .CHK_MODE    (0),
    .INV_PATTERN (1),
    .POLY_LENGHT (31),
    .POLY_TAP    (28),
    .NBITS       (32)
  ) prbs_any_gen_inst (
    .RST      (example_stimulus_reset_sync),
    .CLK      (gtwiz_userclk_tx_usrclk2_in),
    .DATA_IN  (32'b0),
    .EN       (prbs_any_gen_en_int),
    .DATA_OUT (txdata_prbs)
  );


endmodule
