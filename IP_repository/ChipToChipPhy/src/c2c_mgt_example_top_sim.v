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
// This example design top simulation module instantiates the example design top module, provides basic stimulus to it
// while looping back transceiver data from transmit to receive, and utilizes the PRBS checker-based link status
// indicator to demonstrate simple data integrity checking of the design. This module is for use in simulation only.
// =====================================================================================================================

module c2c_mgt_example_top_sim ();


  // -------------------------------------------------------------------------------------------------------------------
  // Signal declarations and basic example design stimulus
  // -------------------------------------------------------------------------------------------------------------------

  // Declare wires to loop back serial data ports for transceiver channel 0
  wire ch0_gtyxn;
  wire ch0_gtyxp;

  // Declare wires to loop back serial data ports for transceiver channel 1
  wire ch1_gtyxn;
  wire ch1_gtyxp;

  // Declare register to drive reference clock at location MGTREFCLK0_X0Y0
  reg mgtrefclk0_x0y0 = 1'b0;

  // Drive that reference clock at the appropriate frequency
  // NOTE: the following simulation reference clock period may be up to +/- 2ps from its nominal value, due to rounding
  // within Verilog timescale granularity, especially when transmitter and receiver reference clock frequencies differ
  initial begin
    mgtrefclk0_x0y0 = 1'b0;
    forever
      mgtrefclk0_x0y0 = #3200 ~mgtrefclk0_x0y0;
  end

  // Declare registers to drive reset helper block(s)
  reg hb_gtwiz_reset_clk_freerun = 1'b0;
  reg hb_gtwiz_reset_all         = 1'b1;

  // Drive the helper block free running clock
  initial begin
    hb_gtwiz_reset_clk_freerun = 1'b0;
    forever
      hb_gtwiz_reset_clk_freerun = #12800 ~hb_gtwiz_reset_clk_freerun;
  end

  // Drive the helper block "reset all" input high, then low after some time
  initial begin
    hb_gtwiz_reset_all = 1'b1;
    #5E6;
    repeat (100)
      @(hb_gtwiz_reset_clk_freerun);
    hb_gtwiz_reset_all = 1'b0;
  end

  // Declare registers and wires to interface to the PRBS-based link status ports
  reg  link_down_latched_reset = 1'b0;
  wire link_status;
  wire link_down_latched;

  // -------------------------------------------------------------------------------------------------------------------
  // Pathological bit sequence handling
  // -------------------------------------------------------------------------------------------------------------------

  // The selected configuration may or may not achieve stable PRBS-based link in loopback, due to its use
  // of either a disabled or custom comma, modified comma mask, channel bonding sequence(s), or clock
  // correction sequence(s). When using these features, user-specified bit patterns cause feature-specific
  // behavior that may periodically disrupt the data stream due to coincidental matches of the provided
  // PRBS pattern, causing checker mismatches and resulting in no, or lost lock. The IP core therefore
  // disables checking of the PRBS-based link status within this simulation testbench. This simulation will
  // simply run for a short period of time and then end with a test completed successfully message, but it
  // should not be construed to mean that data integrity was observed in this configuration. You may wish
  // to extend this simulation period to observe actual behavior, which is not predictable by this IP core.

  initial begin
    $display("=====================================================================================================");
    $display("The selected configuration may or may not achieve stable PRBS-based link in loopback, due to its use");
    $display("of either a disabled or custom comma, modified comma mask, channel bonding sequence(s), or clock");
    $display("correction sequence(s). When using these features, user-specified bit patterns cause feature-specific");
    $display("behavior that may periodically disrupt the data stream due to coincidental matches of the provided");
    $display("PRBS pattern, causing checker mismatches and resulting in no, or lost lock. The IP core therefore");
    $display("disables checking of the PRBS-based link status within this simulation testbench. This simulation will");
    $display("simply run for a short period of time and then end with a test completed successfully message, but it");
    $display("should not be construed to mean that data integrity was observed in this configuration. You may wish");
    $display("to extend this simulation period to observe actual behavior, which is not predictable by this IP core.");
    $display("=====================================================================================================");

    #5E7;

    $display("Time : %12d ps   STOP: data integrity could not be *guaranteed* in this configuration", $time);
    $display("** Test completed successfully");

    $finish;
  end

  // -------------------------------------------------------------------------------------------------------------------
  // Instantiate example design top module as the simulation DUT
  // -------------------------------------------------------------------------------------------------------------------

  c2c_mgt_example_top example_top_inst (
    .mgtrefclk0_x0y0_p (mgtrefclk0_x0y0),
    .mgtrefclk0_x0y0_n (~mgtrefclk0_x0y0),
    .ch0_gtyrxn_in (ch0_gtyxn),
    .ch0_gtyrxp_in (ch0_gtyxp),
    .ch0_gtytxn_out (ch0_gtyxn),
    .ch0_gtytxp_out (ch0_gtyxp),
    .ch1_gtyrxn_in (ch1_gtyxn),
    .ch1_gtyrxp_in (ch1_gtyxp),
    .ch1_gtytxn_out (ch1_gtyxn),
    .ch1_gtytxp_out (ch1_gtyxp),
    .hb_gtwiz_reset_clk_freerun_in (hb_gtwiz_reset_clk_freerun),
    .hb_gtwiz_reset_all_in (hb_gtwiz_reset_all),
    .link_down_latched_reset_in (link_down_latched_reset),
    .link_status_out (link_status),
    .link_down_latched_out (link_down_latched)
  );


endmodule
