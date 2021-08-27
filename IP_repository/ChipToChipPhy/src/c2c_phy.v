`timescale 1ps/1ps

// =====================================================================================================================
// This example design top module instantiates the example design wrapper; slices vectored ports for per-channel
// assignment; and instantiates example resources such as buffers, pattern generators, and pattern checkers for core
// demonstration purposes
// =====================================================================================================================

module c2c_phy#(
parameter GT_TX_POLARITY= 2'b00,
parameter GT_RX_POLARITY= 2'b11,
parameter GT_CLK_DIVIDER= 3 )
(

  // Differential reference clock inputs
  input wire 	     gt_clk,
  input wire 	     gt_clk_div2,
 

  // User-provided ports for reset helper block(s)
  output wire 	     c2c_channel_up,
  output wire 	     c2c_mmcm_unlocked,
  output wire 	     c2c_phy_clk,
  output wire 	     freerun_clk, 
  output wire 	     axi_clk, 
  input wire 	     c2c_pma_init,
  output wire [31:0] c2c_rx_axis_tdata,
  output wire 	     c2c_rx_axis_tvalid, 
  output wire 	     c2c_tx_axis_tready,
  input wire [31:0]  c2c_tx_axis_tdata,
  input wire 	     c2c_tx_axis_tvalid,
  input wire 	     c2c_do_cc,
  output wire [2:0]  c2c_rxbufstatus,
  output wire [1:0]  c2c_rxclkcorcnt,
  output wire 	     c2c_link_reset
);



   wire [1:0] 	     gt_rxn_in;
   
   wire [1:0] 	     gt_rxp_in;
   
   wire [1:0] 	     gt_txn_out;
   
   wire [1:0] 	     gt_txp_out;

   

   
  wire link_down_latched_reset_in = 1'b0; // unused
  reg  link_down_latched_out = 1'b1; // unused
  wire hb_gtwiz_reset_clk_freerun_in = freerun_clk;
  // ===================================================================================================================
  // PER-CHANNEL SIGNAL ASSIGNMENTS
  // ===================================================================================================================

  // The core and example design wrapper vectorize ports across all enabled transceiver channel and common instances for
  // simplicity and compactness. This example design top module assigns slices of each vector to individual, per-channel
  // signal vectors for use if desired. Signals which connect to helper blocks are prefixed "hb#", signals which connect
  // to transceiver common primitives are prefixed "cm#", and signals which connect to transceiver channel primitives
  // are prefixed "ch#", where "#" is the sequential resource number.

  //--------------------------------------------------------------------------------------------------------------------

  //--------------------------------------------------------------------------------------------------------------------
  wire [0:0] gtwiz_userclk_tx_reset_int;
  wire [0:0] hb0_gtwiz_userclk_tx_reset_int;
  assign gtwiz_userclk_tx_reset_int[0:0] = hb0_gtwiz_userclk_tx_reset_int;

  //--------------------------------------------------------------------------------------------------------------------
  wire [0:0] gtwiz_userclk_tx_srcclk_int;
  wire [0:0] hb0_gtwiz_userclk_tx_srcclk_int;
  assign hb0_gtwiz_userclk_tx_srcclk_int = gtwiz_userclk_tx_srcclk_int[0:0];

  //--------------------------------------------------------------------------------------------------------------------
  wire [0:0] gtwiz_userclk_tx_usrclk_int;
  wire [0:0] hb0_gtwiz_userclk_tx_usrclk_int;
  assign hb0_gtwiz_userclk_tx_usrclk_int = gtwiz_userclk_tx_usrclk_int[0:0];

  //--------------------------------------------------------------------------------------------------------------------
  wire [0:0] gtwiz_userclk_tx_usrclk2_int;
  wire [0:0] hb0_gtwiz_userclk_tx_usrclk2_int;
  assign hb0_gtwiz_userclk_tx_usrclk2_int = gtwiz_userclk_tx_usrclk2_int[0:0];

  //--------------------------------------------------------------------------------------------------------------------
  wire [0:0] gtwiz_userclk_tx_active_int;
  wire [0:0] hb0_gtwiz_userclk_tx_active_int;
  assign hb0_gtwiz_userclk_tx_active_int = gtwiz_userclk_tx_active_int[0:0];

  //--------------------------------------------------------------------------------------------------------------------
  wire [0:0] gtwiz_userclk_rx_reset_int;
  wire [0:0] hb0_gtwiz_userclk_rx_reset_int;
  assign gtwiz_userclk_rx_reset_int[0:0] = hb0_gtwiz_userclk_rx_reset_int;

  //--------------------------------------------------------------------------------------------------------------------
  wire [0:0] gtwiz_userclk_rx_srcclk_int;
  wire [0:0] hb0_gtwiz_userclk_rx_srcclk_int;
  assign hb0_gtwiz_userclk_rx_srcclk_int = gtwiz_userclk_rx_srcclk_int[0:0];

  //--------------------------------------------------------------------------------------------------------------------
  wire [0:0] gtwiz_userclk_rx_usrclk_int;
  wire [0:0] hb0_gtwiz_userclk_rx_usrclk_int;
  assign hb0_gtwiz_userclk_rx_usrclk_int = gtwiz_userclk_rx_usrclk_int[0:0];

  //--------------------------------------------------------------------------------------------------------------------
  wire [0:0] gtwiz_userclk_rx_usrclk2_int;
  wire [0:0] hb0_gtwiz_userclk_rx_usrclk2_int;
  assign hb0_gtwiz_userclk_rx_usrclk2_int = gtwiz_userclk_rx_usrclk2_int[0:0];

  //--------------------------------------------------------------------------------------------------------------------
  wire [0:0] gtwiz_userclk_rx_active_int;
  wire [0:0] hb0_gtwiz_userclk_rx_active_int;
  assign hb0_gtwiz_userclk_rx_active_int = gtwiz_userclk_rx_active_int[0:0];

  //--------------------------------------------------------------------------------------------------------------------
  wire [0:0] gtwiz_reset_clk_freerun_int;
  wire [0:0] hb0_gtwiz_reset_clk_freerun_int = 1'b0;
  assign gtwiz_reset_clk_freerun_int[0:0] = hb0_gtwiz_reset_clk_freerun_int;

  //--------------------------------------------------------------------------------------------------------------------
  wire [0:0] gtwiz_reset_all_int;
  wire [0:0] hb0_gtwiz_reset_all_int = 1'b0;
  assign gtwiz_reset_all_int[0:0] = hb0_gtwiz_reset_all_int;

  //--------------------------------------------------------------------------------------------------------------------
  wire [0:0] gtwiz_reset_tx_pll_and_datapath_int;
  wire [0:0] hb0_gtwiz_reset_tx_pll_and_datapath_int;
  assign gtwiz_reset_tx_pll_and_datapath_int[0:0] = hb0_gtwiz_reset_tx_pll_and_datapath_int;

  //--------------------------------------------------------------------------------------------------------------------
  wire [0:0] gtwiz_reset_tx_datapath_int;
  wire [0:0] hb0_gtwiz_reset_tx_datapath_int;
  assign gtwiz_reset_tx_datapath_int[0:0] = hb0_gtwiz_reset_tx_datapath_int;

  //--------------------------------------------------------------------------------------------------------------------
  wire [0:0] gtwiz_reset_rx_pll_and_datapath_int;
  wire [0:0] hb0_gtwiz_reset_rx_pll_and_datapath_int = 1'b0;
  assign gtwiz_reset_rx_pll_and_datapath_int[0:0] = hb0_gtwiz_reset_rx_pll_and_datapath_int;

  //--------------------------------------------------------------------------------------------------------------------
  wire [0:0] gtwiz_reset_rx_datapath_int;
  wire [0:0] hb0_gtwiz_reset_rx_datapath_int = 1'b0;
  assign gtwiz_reset_rx_datapath_int[0:0] = hb0_gtwiz_reset_rx_datapath_int;

  //--------------------------------------------------------------------------------------------------------------------
  wire [0:0] gtwiz_reset_rx_cdr_stable_int;
  wire [0:0] hb0_gtwiz_reset_rx_cdr_stable_int;
  assign hb0_gtwiz_reset_rx_cdr_stable_int = gtwiz_reset_rx_cdr_stable_int[0:0];

  //--------------------------------------------------------------------------------------------------------------------
  wire [0:0] gtwiz_reset_tx_done_int;
  wire [0:0] hb0_gtwiz_reset_tx_done_int;
  assign hb0_gtwiz_reset_tx_done_int = gtwiz_reset_tx_done_int[0:0];

  //--------------------------------------------------------------------------------------------------------------------
  wire [0:0] gtwiz_reset_rx_done_int;
  wire [0:0] hb0_gtwiz_reset_rx_done_int;
  assign hb0_gtwiz_reset_rx_done_int = gtwiz_reset_rx_done_int[0:0];

  //--------------------------------------------------------------------------------------------------------------------
  wire [63:0] gtwiz_userdata_tx_int;
  wire [31:0] hb0_gtwiz_userdata_tx_int;
  wire [31:0] hb1_gtwiz_userdata_tx_int;
  assign gtwiz_userdata_tx_int[31:0] = hb0_gtwiz_userdata_tx_int;
  assign gtwiz_userdata_tx_int[63:32] = hb1_gtwiz_userdata_tx_int;

  //--------------------------------------------------------------------------------------------------------------------
  wire [63:0] gtwiz_userdata_rx_int;
  wire [31:0] hb0_gtwiz_userdata_rx_int;
  (* mark_debug *) wire [31:0] hb1_gtwiz_userdata_rx_int;
  assign hb0_gtwiz_userdata_rx_int = gtwiz_userdata_rx_int[31:0];
  assign hb1_gtwiz_userdata_rx_int = gtwiz_userdata_rx_int[63:32];

  //--------------------------------------------------------------------------------------------------------------------
  wire [19:0] drpaddr_int;
  // This vector is not sliced because it is directly assigned in a debug core instance below

  //--------------------------------------------------------------------------------------------------------------------
  wire [1:0] drpclk_int;
  // This vector is not sliced because it is directly assigned in a debug core instance below

  //--------------------------------------------------------------------------------------------------------------------
  wire [31:0] drpdi_int;
  // This vector is not sliced because it is directly assigned in a debug core instance below

  //--------------------------------------------------------------------------------------------------------------------
  wire [1:0] drpen_int;
  // This vector is not sliced because it is directly assigned in a debug core instance below

  //--------------------------------------------------------------------------------------------------------------------
  wire [1:0] drpwe_int;
  // This vector is not sliced because it is directly assigned in a debug core instance below

  //--------------------------------------------------------------------------------------------------------------------
  wire [1:0] eyescanreset_int;
  // This vector is not sliced because it is directly assigned in a debug core instance below

  //--------------------------------------------------------------------------------------------------------------------
  wire [1:0] gtrefclk0_int;
  wire [0:0] ch0_gtrefclk0_int;
  wire [0:0] ch1_gtrefclk0_int;
  assign gtrefclk0_int[0:0] = ch0_gtrefclk0_int;
  assign gtrefclk0_int[1:1] = ch1_gtrefclk0_int;

  //--------------------------------------------------------------------------------------------------------------------
  wire [1:0] rx8b10ben_int;
  wire [0:0] ch0_rx8b10ben_int = 1'b1;
  wire [0:0] ch1_rx8b10ben_int = 1'b1;
  assign rx8b10ben_int[0:0] = ch0_rx8b10ben_int;
  assign rx8b10ben_int[1:1] = ch1_rx8b10ben_int;

  //--------------------------------------------------------------------------------------------------------------------
  wire [1:0] rxcommadeten_int;
  wire [0:0] ch0_rxcommadeten_int = 1'b1;
  wire [0:0] ch1_rxcommadeten_int = 1'b1;
  assign rxcommadeten_int[0:0] = ch0_rxcommadeten_int;
  assign rxcommadeten_int[1:1] = ch1_rxcommadeten_int;

  //--------------------------------------------------------------------------------------------------------------------
  wire [1:0] rxlpmen_int;
  // This vector is not sliced because it is directly assigned in a debug core instance below

  //--------------------------------------------------------------------------------------------------------------------
  wire [1:0] rxmcommaalignen_int;
  wire [0:0] ch0_rxmcommaalignen_int = 1'b0;
  wire [0:0] ch1_rxmcommaalignen_int = 1'b0;
  assign rxmcommaalignen_int[0:0] = ch0_rxmcommaalignen_int;
  assign rxmcommaalignen_int[1:1] = ch1_rxmcommaalignen_int;

  //--------------------------------------------------------------------------------------------------------------------
  wire [1:0] rxpcommaalignen_int;
  wire [0:0] ch0_rxpcommaalignen_int = 1'b1;
  wire [0:0] ch1_rxpcommaalignen_int = 1'b1;
  assign rxpcommaalignen_int[0:0] = ch0_rxpcommaalignen_int;
  assign rxpcommaalignen_int[1:1] = ch1_rxpcommaalignen_int;

  //--------------------------------------------------------------------------------------------------------------------
  wire [7:0] rxprbssel_int;
  // This vector is not sliced because it is directly assigned in a debug core instance below

  //--------------------------------------------------------------------------------------------------------------------
  wire [5:0] rxrate_int;
  // This vector is not sliced because it is directly assigned in a debug core instance below

  //--------------------------------------------------------------------------------------------------------------------
  wire [1:0] tx8b10ben_int;
  wire [0:0] ch0_tx8b10ben_int = 1'b1;
  wire [0:0] ch1_tx8b10ben_int = 1'b1;
  assign tx8b10ben_int[0:0] = ch0_tx8b10ben_int;
  assign tx8b10ben_int[1:1] = ch1_tx8b10ben_int;

  //--------------------------------------------------------------------------------------------------------------------
  wire [31:0] txctrl0_int;
  wire [15:0] ch0_txctrl0_int;
  wire [15:0] ch1_txctrl0_int;
  assign txctrl0_int[15:0] = ch0_txctrl0_int;
  assign txctrl0_int[31:16]= ch1_txctrl0_int;

  //--------------------------------------------------------------------------------------------------------------------
  wire [31:0] txctrl1_int;
  wire [15:0] ch0_txctrl1_int;
  wire [15:0] ch1_txctrl1_int;
  assign txctrl1_int[15:0] = ch0_txctrl1_int;
  assign txctrl1_int[31:16] = ch1_txctrl1_int;

  //--------------------------------------------------------------------------------------------------------------------
  wire [15:0] txctrl2_int;
  wire [7:0] ch0_txctrl2_int;
  wire [7:0] ch1_txctrl2_int;
  assign txctrl2_int[7:0] = ch0_txctrl2_int;
  assign txctrl2_int[15:8] = ch1_txctrl2_int;

  //--------------------------------------------------------------------------------------------------------------------
  wire [9:0] txdiffctrl_int;
  // This vector is not sliced because it is directly assigned in a debug core instance below

  //--------------------------------------------------------------------------------------------------------------------
  wire [1:0] txpolarity_int;
  wire [0:0] ch0_txpolarity_int = 1'b0;
  wire [0:0] ch1_txpolarity_int = 1'b0;
  assign txpolarity_int[0:0] = ch0_txpolarity_int;
  assign txpolarity_int[1:1] = ch1_txpolarity_int;

  //--------------------------------------------------------------------------------------------------------------------
  wire [9:0] txpostcursor_int;
  // This vector is not sliced because it is directly assigned in a debug core instance below

  //--------------------------------------------------------------------------------------------------------------------
  wire [7:0] txprbssel_int;
  // This vector is not sliced because it is directly assigned in a debug core instance below

  //--------------------------------------------------------------------------------------------------------------------
  wire [9:0] txprecursor_int;
  // This vector is not sliced because it is directly assigned in a debug core instance below

  //--------------------------------------------------------------------------------------------------------------------
  wire [31:0] drpdo_int;
  wire [15:0] ch0_drpdo_int;
  wire [15:0] ch1_drpdo_int;
  assign ch0_drpdo_int = drpdo_int[15:0];
  assign ch1_drpdo_int = drpdo_int[31:16];

  //--------------------------------------------------------------------------------------------------------------------
  wire [1:0] drprdy_int;
  wire [0:0] ch0_drprdy_int;
  wire [0:0] ch1_drprdy_int;
  assign ch0_drprdy_int = drprdy_int[0:0];
  assign ch1_drprdy_int = drprdy_int[1:1];

  //--------------------------------------------------------------------------------------------------------------------
  wire [1:0] gtpowergood_int;
  wire [0:0] ch0_gtpowergood_int;
  wire [0:0] ch1_gtpowergood_int;
  assign ch0_gtpowergood_int = gtpowergood_int[0:0];
  assign ch1_gtpowergood_int = gtpowergood_int[1:1];

  //--------------------------------------------------------------------------------------------------------------------
  wire [1:0] rxbyteisaligned_int;
  wire [0:0] ch0_rxbyteisaligned_int;
  wire [0:0] ch1_rxbyteisaligned_int;
  assign ch0_rxbyteisaligned_int = rxbyteisaligned_int[0:0];
  assign ch1_rxbyteisaligned_int = rxbyteisaligned_int[1:1];

  //--------------------------------------------------------------------------------------------------------------------
  wire [1:0] rxbyterealign_int;
  wire [0:0] ch0_rxbyterealign_int;
  wire [0:0] ch1_rxbyterealign_int;
  assign ch0_rxbyterealign_int = rxbyterealign_int[0:0];
  assign ch1_rxbyterealign_int = rxbyterealign_int[1:1];

  //--------------------------------------------------------------------------------------------------------------------
  wire [1:0] rxcommadet_int;
  wire [0:0] ch0_rxcommadet_int;
  wire [0:0] ch1_rxcommadet_int;
  assign ch0_rxcommadet_int = rxcommadet_int[0:0];
  assign ch1_rxcommadet_int = rxcommadet_int[1:1];

  //--------------------------------------------------------------------------------------------------------------------
  wire [31:0] rxctrl0_int;
  wire [15:0] ch0_rxctrl0_int;
  wire [15:0] ch1_rxctrl0_int;
  assign ch0_rxctrl0_int = rxctrl0_int[15:0];
  assign ch1_rxctrl0_int = rxctrl0_int[31:16];

  //--------------------------------------------------------------------------------------------------------------------
  wire [31:0] rxctrl1_int;
  wire [15:0] ch0_rxctrl1_int;
  wire [15:0] ch1_rxctrl1_int;
  assign ch0_rxctrl1_int = rxctrl1_int[15:0];
  assign ch1_rxctrl1_int = rxctrl1_int[31:16];

  //--------------------------------------------------------------------------------------------------------------------
  (* mark_debug *) wire [15:0] rxctrl2_int;
  wire [7:0] ch0_rxctrl2_int;
  wire [7:0] ch1_rxctrl2_int;
  assign ch0_rxctrl2_int = rxctrl2_int[7:0];
  assign ch1_rxctrl2_int = rxctrl2_int[15:8];

  //--------------------------------------------------------------------------------------------------------------------
  wire [15:0] rxctrl3_int;
  wire [7:0] ch0_rxctrl3_int;
  wire [7:0] ch1_rxctrl3_int;
  assign ch0_rxctrl3_int = rxctrl3_int[7:0];
  assign ch1_rxctrl3_int = rxctrl3_int[15:8];

  //--------------------------------------------------------------------------------------------------------------------
  wire [255:0] rxdata_int;
  wire [127:0] ch0_rxdata_int;
  wire [127:0] ch1_rxdata_int;
  assign ch0_rxdata_int = rxdata_int[127:0];
  assign ch1_rxdata_int = rxdata_int[255:128];

  //--------------------------------------------------------------------------------------------------------------------
  wire [1:0] rxpmaresetdone_int;
  wire [0:0] ch0_rxpmaresetdone_int;
  wire [0:0] ch1_rxpmaresetdone_int;
  assign ch0_rxpmaresetdone_int = rxpmaresetdone_int[0:0];
  assign ch1_rxpmaresetdone_int = rxpmaresetdone_int[1:1];

  //--------------------------------------------------------------------------------------------------------------------
  wire [1:0] rxprbserr_int;
  wire [0:0] ch0_rxprbserr_int;
  wire [0:0] ch1_rxprbserr_int;
  assign ch0_rxprbserr_int = rxprbserr_int[0:0];
  assign ch1_rxprbserr_int = rxprbserr_int[1:1];

  //--------------------------------------------------------------------------------------------------------------------
  wire [1:0] txpmaresetdone_int;
  wire [0:0] ch0_txpmaresetdone_int;
  wire [0:0] ch1_txpmaresetdone_int;
  assign ch0_txpmaresetdone_int = txpmaresetdone_int[0:0];
  assign ch1_txpmaresetdone_int = txpmaresetdone_int[1:1];


  // ===================================================================================================================
  // BUFFERS
  // ===================================================================================================================

  // Buffer the hb_gtwiz_reset_all_in input and logically combine it with the internal signal from the example
  // initialization block as well as the VIO-sourced reset
  wire hb_gtwiz_reset_all_vio_int;
  wire hb_gtwiz_reset_all_buf_int;
  wire hb_gtwiz_reset_all_init_int;
  wire hb_gtwiz_reset_all_int;

  IBUF ibuf_hb_gtwiz_reset_all_inst (
    .I (hb_gtwiz_reset_all_in),
    .O (hb_gtwiz_reset_all_buf_int)
  );

  assign hb_gtwiz_reset_all_int = hb_gtwiz_reset_all_buf_int || hb_gtwiz_reset_all_init_int || hb_gtwiz_reset_all_vio_int;

  // Globally buffer the free-running input clock
  wire hb_gtwiz_reset_clk_freerun_buf_int = hb_gtwiz_reset_clk_freerun_in;

  // Instantiate a differential reference clock buffer for each reference clock differential pair in this configuration,
  // and assign the single-ended output of each differential reference clock buffer to the appropriate PLL input signal

  // Differential reference clock buffer for MGTREFCLK1_X0Y5
  wire mgtrefclk1_x0y5_int;
  wire mgtrefclk_odiv2;
  assign freerun_clk = mgtrefclk_odiv2;
  wire mgtrefclk_odiv2_b;

   assign mgtrefclk1_x0y5_int = gt_clk;
   assign mgtrefclk_odiv2_b = gt_clk_div2;
   
   BUFG_GT mgtrefclk_bufg
   (
      .O       (mgtrefclk_odiv2),  // 1-bit output: Buffer
      .CE      (1'b1),             // 1-bit input: Buffer enable
      .CEMASK  (1'b0),             // 1-bit input: CE Mask
      .CLR     (1'b0),             // 1-bit input: Asynchronous clear
      .CLRMASK (1'b0),             // 1-bit input: CLR Mask
      .DIV     (GT_CLK_DIVIDER),             // 3-bit input: Dynamic divide Value
      .I       (mgtrefclk_odiv2_b) // 1-bit input: Buffer
   );
   BUFG_GT mgtrefclk_bufg_original
   (
      .O       (axi_clk),  // 1-bit output: Buffer
      .CE      (1'b1),             // 1-bit input: Buffer enable
      .CEMASK  (1'b0),             // 1-bit input: CE Mask
      .CLR     (1'b0),             // 1-bit input: Asynchronous clear
      .CLRMASK (1'b0),             // 1-bit input: CLR Mask
      .DIV     (3'd0),             // 3-bit input: Dynamic divide Value
      .I       (mgtrefclk_odiv2_b) // 1-bit input: Buffer
   );
  assign ch0_gtrefclk0_int = mgtrefclk1_x0y5_int;
  assign ch1_gtrefclk0_int = mgtrefclk1_x0y5_int;


  // ===================================================================================================================
  // USER CLOCKING RESETS
  // ===================================================================================================================

  // The TX user clocking helper block should be held in reset until the clock source of that block is known to be
  // stable. The following assignment is an example of how that stability can be determined, based on the selected TX
  // user clock source. Replace the assignment with the appropriate signal or logic to achieve that behavior as needed.
  assign hb0_gtwiz_userclk_tx_reset_int = ~(&txpmaresetdone_int);

  // The RX user clocking helper block should be held in reset until the clock source of that block is known to be
  // stable. The following assignment is an example of how that stability can be determined, based on the selected RX
  // user clock source. Replace the assignment with the appropriate signal or logic to achieve that behavior as needed.
  assign hb0_gtwiz_userclk_rx_reset_int = ~(&rxpmaresetdone_int);


  
  // PRBS match and related link management
  // -------------------------------------------------------------------------------------------------------------------

  // Perform a bitwise NAND of all PRBS match indicators, creating a combinatorial indication of any PRBS mismatch
  // across all transceiver channels
  wire prbs_error_any_sync;

  // Synchronize the PRBS mismatch indicator the free-running clock domain, using a reset synchronizer with asynchronous
  // reset and synchronous removal
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_reset_synchronizer reset_synchronizer_prbs_match_all_inst (
    .clk_in (hb_gtwiz_reset_clk_freerun_buf_int),
    .rst_in (prbs_error_any_async),
    .rst_out(prbs_error_any_sync)
  );

  // Synchronize the latched link down reset input and the VIO-driven signal into the free-running clock domain
  wire link_down_latched_reset_vio_int;
  wire link_down_latched_reset_sync;

  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_link_down_latched_reset_inst (
    .clk_in (hb_gtwiz_reset_clk_freerun_buf_int),
    .i_in   (link_down_latched_reset_in || link_down_latched_reset_vio_int),
    .o_out  (link_down_latched_reset_sync)
  );

    wire sm_link = 1'b1; // just to make example logic happy
  // Reset the latched link down indicator when the synchronized latched link down reset signal is high. Otherwise, set
  // the latched link down indicator upon losing link. This indicator is available for user reference.
  always @(posedge hb_gtwiz_reset_clk_freerun_buf_int) begin
    if (link_down_latched_reset_sync)
      link_down_latched_out <= 1'b0;
    else if (!sm_link)
      link_down_latched_out <= 1'b1;
  end

  // Assign the link status indicator to the top-level two-state output for user reference
  assign link_status_out = sm_link;


  // ===================================================================================================================
  // INITIALIZATION
  // ===================================================================================================================

  // Declare the receiver reset signals that interface to the reset controller helper block. For this configuration,
  // which uses the same PLL type for transmitter and receiver, the "reset RX PLL and datapath" feature is not used.
  wire hb_gtwiz_reset_rx_pll_and_datapath_int = 1'b0;
  wire hb_gtwiz_reset_rx_datapath_int;

  // Declare signals which connect the VIO instance to the initialization module for debug purposes
  wire       init_done_int;
  wire [3:0] init_retry_ctr_int;

  // Combine the receiver reset signals form the initialization module and the VIO to drive the appropriate reset
  // controller helper block reset input
  wire hb_gtwiz_reset_rx_pll_and_datapath_vio_int;
  wire hb_gtwiz_reset_rx_datapath_vio_int;
  wire hb_gtwiz_reset_rx_datapath_init_int;

  assign hb_gtwiz_reset_rx_datapath_int = hb_gtwiz_reset_rx_datapath_init_int || hb_gtwiz_reset_rx_datapath_vio_int;

  // The example initialization module interacts with the reset controller helper block and other example design logic
  // to retry failed reset attempts in order to mitigate bring-up issues such as initially-unavilable reference clocks
  // or data connections. It also resets the receiver in the event of link loss in an attempt to regain link, so please
  // note the possibility that this behavior can have the effect of overriding or disturbing user-provided inputs that
  // destabilize the data stream. It is a demonstration only and can be modified to suit your system needs.
  c2c_mgt_init example_init_inst (
    .clk_freerun_in  (hb_gtwiz_reset_clk_freerun_buf_int),
    .reset_all_in    (hb_gtwiz_reset_all_int),
    .tx_init_done_in (gtwiz_reset_tx_done_int),
    .rx_init_done_in (gtwiz_reset_rx_done_int),
    .rx_data_good_in (sm_link),
    .reset_all_out   (hb_gtwiz_reset_all_init_int),
    .reset_rx_out    (hb_gtwiz_reset_rx_datapath_init_int),
    .init_done_out   (init_done_int),
    .retry_ctr_out   (init_retry_ctr_int)
  );


  // ===================================================================================================================
  // VIO FOR HARDWARE BRING-UP AND DEBUG
  // ===================================================================================================================

  // Synchronize gtpowergood into the free-running clock domain for VIO usage
  wire [1:0] gtpowergood_vio_sync;

  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_gtpowergood_0_inst (
    .clk_in (hb_gtwiz_reset_clk_freerun_buf_int),
    .i_in   (gtpowergood_int[0]),
    .o_out  (gtpowergood_vio_sync[0])
  );

  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_gtpowergood_1_inst (
    .clk_in (hb_gtwiz_reset_clk_freerun_buf_int),
    .i_in   (gtpowergood_int[1]),
    .o_out  (gtpowergood_vio_sync[1])
  );

  // Synchronize txpmaresetdone into the free-running clock domain for VIO usage
  wire [1:0] txpmaresetdone_vio_sync;

  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_txpmaresetdone_0_inst (
    .clk_in (hb_gtwiz_reset_clk_freerun_buf_int),
    .i_in   (txpmaresetdone_int[0]),
    .o_out  (txpmaresetdone_vio_sync[0])
  );

  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_txpmaresetdone_1_inst (
    .clk_in (hb_gtwiz_reset_clk_freerun_buf_int),
    .i_in   (txpmaresetdone_int[1]),
    .o_out  (txpmaresetdone_vio_sync[1])
  );

  // Synchronize rxpmaresetdone into the free-running clock domain for VIO usage
  wire [1:0] rxpmaresetdone_vio_sync;

  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_rxpmaresetdone_0_inst (
    .clk_in (hb_gtwiz_reset_clk_freerun_buf_int),
    .i_in   (rxpmaresetdone_int[0]),
    .o_out  (rxpmaresetdone_vio_sync[0])
  );

  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_rxpmaresetdone_1_inst (
    .clk_in (hb_gtwiz_reset_clk_freerun_buf_int),
    .i_in   (rxpmaresetdone_int[1]),
    .o_out  (rxpmaresetdone_vio_sync[1])
  );

  // Synchronize gtwiz_reset_tx_done into the free-running clock domain for VIO usage
  wire [0:0] gtwiz_reset_tx_done_vio_sync;

  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_gtwiz_reset_tx_done_0_inst (
    .clk_in (hb_gtwiz_reset_clk_freerun_buf_int),
    .i_in   (gtwiz_reset_tx_done_int[0]),
    .o_out  (gtwiz_reset_tx_done_vio_sync[0])
  );

  // Synchronize gtwiz_reset_rx_done into the free-running clock domain for VIO usage
  wire [0:0] gtwiz_reset_rx_done_vio_sync;

  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_gtwiz_reset_rx_done_0_inst (
    .clk_in (hb_gtwiz_reset_clk_freerun_buf_int),
    .i_in   (gtwiz_reset_rx_done_int[0]),
    .o_out  (gtwiz_reset_rx_done_vio_sync[0])
  );

  // Synchronize rxprbserr into the free-running clock domain for VIO usage
  wire [1:0] rxprbserr_vio_sync;

  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_rxprbserr_0_inst (
    .clk_in (hb_gtwiz_reset_clk_freerun_buf_int),
    .i_in   (rxprbserr_int[0]),
    .o_out  (rxprbserr_vio_sync[0])
  );

  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_rxprbserr_1_inst (
    .clk_in (hb_gtwiz_reset_clk_freerun_buf_int),
    .i_in   (rxprbserr_int[1]),
    .o_out  (rxprbserr_vio_sync[1])
  );

  // Synchronize txprbssel into the TXUSRCLK2 clock domain from VIO usage
  wire [7:0] txprbssel_vio_async;

  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_txprbssel_0_inst (
    .clk_in (hb0_gtwiz_userclk_tx_usrclk2_int),
    .i_in   (txprbssel_vio_async[0]),
    .o_out  (txprbssel_int[0])
  );
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_txprbssel_1_inst (
    .clk_in (hb0_gtwiz_userclk_tx_usrclk2_int),
    .i_in   (txprbssel_vio_async[1]),
    .o_out  (txprbssel_int[1])
  );
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_txprbssel_2_inst (
    .clk_in (hb0_gtwiz_userclk_tx_usrclk2_int),
    .i_in   (txprbssel_vio_async[2]),
    .o_out  (txprbssel_int[2])
  );
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_txprbssel_3_inst (
    .clk_in (hb0_gtwiz_userclk_tx_usrclk2_int),
    .i_in   (txprbssel_vio_async[3]),
    .o_out  (txprbssel_int[3])
  );

  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_txprbssel_4_inst (
    .clk_in (hb0_gtwiz_userclk_tx_usrclk2_int),
    .i_in   (txprbssel_vio_async[4]),
    .o_out  (txprbssel_int[4])
  );
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_txprbssel_5_inst (
    .clk_in (hb0_gtwiz_userclk_tx_usrclk2_int),
    .i_in   (txprbssel_vio_async[5]),
    .o_out  (txprbssel_int[5])
  );
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_txprbssel_6_inst (
    .clk_in (hb0_gtwiz_userclk_tx_usrclk2_int),
    .i_in   (txprbssel_vio_async[6]),
    .o_out  (txprbssel_int[6])
  );
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_txprbssel_7_inst (
    .clk_in (hb0_gtwiz_userclk_tx_usrclk2_int),
    .i_in   (txprbssel_vio_async[7]),
    .o_out  (txprbssel_int[7])
  );

  // Synchronize rxprbssel into the RXUSRCLK2 clock domain from VIO usage
  wire [7:0] rxprbssel_vio_async;

  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_rxprbssel_0_inst (
    .clk_in (hb0_gtwiz_userclk_rx_usrclk2_int),
    .i_in   (rxprbssel_vio_async[0]),
    .o_out  (rxprbssel_int[0])
  );
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_rxprbssel_1_inst (
    .clk_in (hb0_gtwiz_userclk_rx_usrclk2_int),
    .i_in   (rxprbssel_vio_async[1]),
    .o_out  (rxprbssel_int[1])
  );
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_rxprbssel_2_inst (
    .clk_in (hb0_gtwiz_userclk_rx_usrclk2_int),
    .i_in   (rxprbssel_vio_async[2]),
    .o_out  (rxprbssel_int[2])
  );
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_rxprbssel_3_inst (
    .clk_in (hb0_gtwiz_userclk_rx_usrclk2_int),
    .i_in   (rxprbssel_vio_async[3]),
    .o_out  (rxprbssel_int[3])
  );

  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_rxprbssel_4_inst (
    .clk_in (hb0_gtwiz_userclk_rx_usrclk2_int),
    .i_in   (rxprbssel_vio_async[4]),
    .o_out  (rxprbssel_int[4])
  );
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_rxprbssel_5_inst (
    .clk_in (hb0_gtwiz_userclk_rx_usrclk2_int),
    .i_in   (rxprbssel_vio_async[5]),
    .o_out  (rxprbssel_int[5])
  );
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_rxprbssel_6_inst (
    .clk_in (hb0_gtwiz_userclk_rx_usrclk2_int),
    .i_in   (rxprbssel_vio_async[6]),
    .o_out  (rxprbssel_int[6])
  );
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_vio_rxprbssel_7_inst (
    .clk_in (hb0_gtwiz_userclk_rx_usrclk2_int),
    .i_in   (rxprbssel_vio_async[7]),
    .o_out  (rxprbssel_int[7])
  );


   assign hb_gtwiz_reset_all_vio_int = 1'b0;
   assign hb0_gtwiz_reset_tx_pll_and_datapath_int = 1'b0;
   assign hb0_gtwiz_reset_tx_datapath_int = 1'b0;
   assign hb_gtwiz_reset_rx_pll_and_datapath_vio_int = 1'b0;
   assign hb_gtwiz_reset_rx_datapath_vio_int =1'b0;
   assign link_down_latched_reset_vio_int = 1'b0;
   assign txprbssel_vio_async = 8'd0;
   assign rxprbssel_vio_async = 8'd0;
   


   assign drpclk_int = {2{hb_gtwiz_reset_clk_freerun_buf_int}};
   assign eyescanreset_int = 2'b00;
   assign rxrate_int = 6'b000000;
   assign txdiffctrl_int = {2{5'b11000}};
   assign txprecursor_int = {2{5'b00000}};
   assign txpostcursor_int = {2{5'b00000}};
   assign rxlpmen_int = 2'b11;


   

   (* mark_debug *) wire [5 : 0] rxbufstatus_out;
   (* mark_debug *) wire [3 : 0] rxclkcorcnt_out;
  // ===================================================================================================================
  // EXAMPLE WRAPPER INSTANCE
  // ===================================================================================================================

  // Instantiate the example design wrapper, mapping its enabled ports to per-channel internal signals and example
  // resources as appropriate
  
  c2c_mgt_wrapper example_wrapper_inst (
    .gtyrxn_in                               (gt_rxn_in)
   ,.gtyrxp_in                               (gt_rxp_in)
   ,.gtytxn_out                              (gt_txn_out)
   ,.gtytxp_out                              (gt_txp_out)
   ,.gtwiz_userclk_tx_reset_in               (gtwiz_userclk_tx_reset_int)
   ,.gtwiz_userclk_tx_srcclk_out             (gtwiz_userclk_tx_srcclk_int)
   ,.gtwiz_userclk_tx_usrclk_out             (gtwiz_userclk_tx_usrclk_int)
   ,.gtwiz_userclk_tx_usrclk2_out            (gtwiz_userclk_tx_usrclk2_int)
   ,.gtwiz_userclk_tx_active_out             (gtwiz_userclk_tx_active_int)
   ,.gtwiz_userclk_rx_reset_in               (gtwiz_userclk_rx_reset_int)
   ,.gtwiz_userclk_rx_srcclk_out             (gtwiz_userclk_rx_srcclk_int)
   ,.gtwiz_userclk_rx_usrclk_out             (gtwiz_userclk_rx_usrclk_int)
   ,.gtwiz_userclk_rx_usrclk2_out            (gtwiz_userclk_rx_usrclk2_int)
   ,.gtwiz_userclk_rx_active_out             (gtwiz_userclk_rx_active_int)
   ,.gtwiz_reset_clk_freerun_in              ({1{hb_gtwiz_reset_clk_freerun_buf_int}})
   ,.gtwiz_reset_all_in                      ({1{hb_gtwiz_reset_all_int}})
   ,.gtwiz_reset_tx_pll_and_datapath_in      (gtwiz_reset_tx_pll_and_datapath_int)
   ,.gtwiz_reset_tx_datapath_in              (gtwiz_reset_tx_datapath_int)
   ,.gtwiz_reset_rx_pll_and_datapath_in      ({1{hb_gtwiz_reset_rx_pll_and_datapath_int}})
   ,.gtwiz_reset_rx_datapath_in              ({1{hb_gtwiz_reset_rx_datapath_int}})
   ,.gtwiz_reset_rx_cdr_stable_out           (gtwiz_reset_rx_cdr_stable_int)
   ,.gtwiz_reset_tx_done_out                 (gtwiz_reset_tx_done_int)
   ,.gtwiz_reset_rx_done_out                 (gtwiz_reset_rx_done_int)
   ,.gtwiz_userdata_tx_in                    (gtwiz_userdata_tx_int)
   ,.gtwiz_userdata_rx_out                   (gtwiz_userdata_rx_int)
   ,.drpaddr_in                              (drpaddr_int)
   ,.drpclk_in                               (drpclk_int)
   ,.drpdi_in                                (drpdi_int)
   ,.drpen_in                                (drpen_int)
   ,.drpwe_in                                (drpwe_int)
   ,.eyescanreset_in                         (eyescanreset_int)
   ,.gtrefclk0_in                            (gtrefclk0_int)
   ,.rx8b10ben_in                            (rx8b10ben_int)
   ,.rxcommadeten_in                         (rxcommadeten_int)
   ,.rxlpmen_in                              (rxlpmen_int)
   ,.rxmcommaalignen_in                      (rxmcommaalignen_int)
   ,.rxpcommaalignen_in                      (rxpcommaalignen_int)
   ,.rxprbssel_in                            (rxprbssel_in)  
   ,.rxrate_in                               (rxrate_int)
   ,.tx8b10ben_in                            (tx8b10ben_int)
   ,.txctrl0_in                              (txctrl0_int)
   ,.txctrl1_in                              (txctrl1_int)
   ,.txctrl2_in                              (txctrl2_int)
   ,.txdiffctrl_in                           (txdiffctrl_int)
   ,.txpolarity_in                           (GT_TX_POLARITY)
   ,.txpostcursor_in                         (txpostcursor_int)
   ,.txprbssel_in                            (txprbssel_int) 
   ,.txprecursor_in                          (txprecursor_int)
   ,.drpdo_out                               (drpdo_int)
   ,.drprdy_out                              (drprdy_int)
   ,.gtpowergood_out                         (gtpowergood_int)
   ,.rxbyteisaligned_out                     (rxbyteisaligned_int)
   ,.rxbyterealign_out                       (rxbyterealign_int)
   ,.rxcommadet_out                          (rxcommadet_int)
   ,.rxctrl0_out                             (rxctrl0_int)
   ,.rxctrl1_out                             (rxctrl1_int)
   ,.rxctrl2_out                             (rxctrl2_int)
   ,.rxctrl3_out                             (rxctrl3_int)
//rxdata missing
   ,.rxpmaresetdone_out                      (rxpmaresetdone_int)
   ,.rxprbserr_out                           (rxprbserr_int)                   
   ,.txpmaresetdone_out                      (txpmaresetdone_int)
   ,.rxbufreset_in                           (rxbufreset_int)
   ,.rxpolarity_in                           (GT_RX_POLARITY)
   ,.rxbufstatus_out                         (rxbufstatus_int)
   ,.rxclkcorcnt_out                         (rxclkcorcnt_int)
);
   reg [9:0] cc_cnt = 10'd0; // clock correction counter
   reg 	  local_do_cc;
   
always @(posedge gtwiz_userclk_tx_usrclk2_int)
  begin
     if (cc_cnt==10'd1023)
       local_do_cc <=1'b1;
     else
       local_do_cc <=1'b0;
     cc_cnt<=cc_cnt+1'b1;
  end



   c2c_adapter c2c_adapter_i
    (
        .c2c_phy_clk   (gtwiz_userclk_tx_usrclk2_int),       
        .c2c_rx_data   (c2c_rx_axis_tdata),
        .c2c_rx_valid  (c2c_rx_axis_tvalid),
        .c2c_tx_tdata  (c2c_tx_axis_tdata),
        .c2c_tx_tvalid (c2c_tx_axis_tvalid),
        .do_cc         (local_do_cc),
        .link_reset    (c2c_link_reset),        
        .mgt_rx_data   (hb0_gtwiz_userdata_rx_int),
        .mgt_rx_k      (ch0_rxctrl0_int[3:0]),
        .rx_aligned    (ch0_rxbyteisaligned_int),        
        .mgt_tx_data   (hb1_gtwiz_userdata_tx_int),
        .mgt_tx_k      (ch1_txctrl2_int[3:0])
    );

assign c2c_tx_axis_tready      = 1'b1; // always ready
assign c2c_mmcm_unlocked       = 1'b0;
assign c2c_channel_up          = ch0_rxbyteisaligned_int;
assign c2c_phy_clk             = gtwiz_userclk_tx_usrclk2_int;
assign c2c_rxbufstatus         = rxbufstatus_out [2:0];
assign c2c_rxclkcorcnt         = rxclkcorcnt_out [1:0];

endmodule
