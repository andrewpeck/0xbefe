`timescale 1ps/1ps

// =====================================================================================================================
// This example design top module instantiates the example design wrapper; slices vectored ports for per-channel
// assignment; and instantiates example resources such as buffers, pattern generators, and pattern checkers for core
// demonstration purposes
// =====================================================================================================================

module c2c_gth_tux 
(

  // Differential reference clock inputs
  input  wire mgtrefclk1_x0y5_p,
  input  wire mgtrefclk1_x0y5_n,
  input  wire [1:0] gthrxn_int,
  input  wire [1:0] gthrxp_int,
  output wire [1:0] gthtxn_int,
  output wire [1:0] gthtxp_int,

  // User-provided ports for reset helper block(s)
  input  drp_clk, // drp clock, 50M from MMCM in BD

  output c2c_channel_up,
  output c2c_init_clk,
  output c2c_mmcm_unlocked,
  output c2c_phy_clk,
  input  c2c_pma_init,
  
  output [31:0] c2c_rx_data,
  output        c2c_rx_valid,
  
  output       c2c_tx_ready,
  input [31:0] c2c_tx_tdata,
  input        c2c_tx_tvalid,
  input        c2c_do_cc,
  output [2:0] c2c_rxbufstatus,
  output [1:0] c2c_rxclkcorcnt,
  output       c2c_link_reset
);

  wire link_down_latched_reset_in = 1'b0; // unused
  reg  link_down_latched_out = 1'b1; // unused
  wire hb_gtwiz_reset_clk_freerun_in = drp_clk;
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
  assign txctrl0_int[31:16] = ch1_txctrl0_int;

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
  wire mgtrefclk_odiv2_b;

  IBUFDS_GTE4 #(
    .REFCLK_EN_TX_PATH  (1'b0),
    .REFCLK_HROW_CK_SEL (2'b00),
    .REFCLK_ICNTL_RX    (2'b00)
  ) IBUFDS_GTE4_MGTREFCLK1_X0Y5_INST (
    .I     (mgtrefclk1_x0y5_p),
    .IB    (mgtrefclk1_x0y5_n),
    .CEB   (1'b0),
    .O     (mgtrefclk1_x0y5_int),
    .ODIV2 (mgtrefclk_odiv2_b)
  );

   BUFG_GT mgtrefclk_bufg
   (
      .O       (mgtrefclk_odiv2),  // 1-bit output: Buffer
      .CE      (1'b1),             // 1-bit input: Buffer enable
      .CEMASK  (1'b0),             // 1-bit input: CE Mask
      .CLR     (1'b0),             // 1-bit input: Asynchronous clear
      .CLRMASK (1'b0),             // 1-bit input: CLR Mask
      .DIV     (3'h0),             // 3-bit input: Dynamic divide Value
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
  c2c_gth_example_reset_synchronizer reset_synchronizer_prbs_match_all_inst (
    .clk_in (hb_gtwiz_reset_clk_freerun_buf_int),
    .rst_in (prbs_error_any_async),
    .rst_out(prbs_error_any_sync)
  );

  // Synchronize the latched link down reset input and the VIO-driven signal into the free-running clock domain
  wire link_down_latched_reset_vio_int;
  wire link_down_latched_reset_sync;

  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_link_down_latched_reset_inst (
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
  c2c_gth_example_init example_init_inst (
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
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_gtpowergood_0_inst (
    .clk_in (hb_gtwiz_reset_clk_freerun_buf_int),
    .i_in   (gtpowergood_int[0]),
    .o_out  (gtpowergood_vio_sync[0])
  );

  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_gtpowergood_1_inst (
    .clk_in (hb_gtwiz_reset_clk_freerun_buf_int),
    .i_in   (gtpowergood_int[1]),
    .o_out  (gtpowergood_vio_sync[1])
  );

  // Synchronize txpmaresetdone into the free-running clock domain for VIO usage
  wire [1:0] txpmaresetdone_vio_sync;

  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_txpmaresetdone_0_inst (
    .clk_in (hb_gtwiz_reset_clk_freerun_buf_int),
    .i_in   (txpmaresetdone_int[0]),
    .o_out  (txpmaresetdone_vio_sync[0])
  );

  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_txpmaresetdone_1_inst (
    .clk_in (hb_gtwiz_reset_clk_freerun_buf_int),
    .i_in   (txpmaresetdone_int[1]),
    .o_out  (txpmaresetdone_vio_sync[1])
  );

  // Synchronize rxpmaresetdone into the free-running clock domain for VIO usage
  wire [1:0] rxpmaresetdone_vio_sync;

  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_rxpmaresetdone_0_inst (
    .clk_in (hb_gtwiz_reset_clk_freerun_buf_int),
    .i_in   (rxpmaresetdone_int[0]),
    .o_out  (rxpmaresetdone_vio_sync[0])
  );

  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_rxpmaresetdone_1_inst (
    .clk_in (hb_gtwiz_reset_clk_freerun_buf_int),
    .i_in   (rxpmaresetdone_int[1]),
    .o_out  (rxpmaresetdone_vio_sync[1])
  );

  // Synchronize gtwiz_reset_tx_done into the free-running clock domain for VIO usage
  wire [0:0] gtwiz_reset_tx_done_vio_sync;

  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_gtwiz_reset_tx_done_0_inst (
    .clk_in (hb_gtwiz_reset_clk_freerun_buf_int),
    .i_in   (gtwiz_reset_tx_done_int[0]),
    .o_out  (gtwiz_reset_tx_done_vio_sync[0])
  );

  // Synchronize gtwiz_reset_rx_done into the free-running clock domain for VIO usage
  wire [0:0] gtwiz_reset_rx_done_vio_sync;

  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_gtwiz_reset_rx_done_0_inst (
    .clk_in (hb_gtwiz_reset_clk_freerun_buf_int),
    .i_in   (gtwiz_reset_rx_done_int[0]),
    .o_out  (gtwiz_reset_rx_done_vio_sync[0])
  );

  // Synchronize rxprbserr into the free-running clock domain for VIO usage
  wire [1:0] rxprbserr_vio_sync;

  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_rxprbserr_0_inst (
    .clk_in (hb_gtwiz_reset_clk_freerun_buf_int),
    .i_in   (rxprbserr_int[0]),
    .o_out  (rxprbserr_vio_sync[0])
  );

  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_rxprbserr_1_inst (
    .clk_in (hb_gtwiz_reset_clk_freerun_buf_int),
    .i_in   (rxprbserr_int[1]),
    .o_out  (rxprbserr_vio_sync[1])
  );

  // Synchronize txprbssel into the TXUSRCLK2 clock domain from VIO usage
  wire [7:0] txprbssel_vio_async;

  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_txprbssel_0_inst (
    .clk_in (hb0_gtwiz_userclk_tx_usrclk2_int),
    .i_in   (txprbssel_vio_async[0]),
    .o_out  (txprbssel_int[0])
  );
  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_txprbssel_1_inst (
    .clk_in (hb0_gtwiz_userclk_tx_usrclk2_int),
    .i_in   (txprbssel_vio_async[1]),
    .o_out  (txprbssel_int[1])
  );
  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_txprbssel_2_inst (
    .clk_in (hb0_gtwiz_userclk_tx_usrclk2_int),
    .i_in   (txprbssel_vio_async[2]),
    .o_out  (txprbssel_int[2])
  );
  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_txprbssel_3_inst (
    .clk_in (hb0_gtwiz_userclk_tx_usrclk2_int),
    .i_in   (txprbssel_vio_async[3]),
    .o_out  (txprbssel_int[3])
  );

  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_txprbssel_4_inst (
    .clk_in (hb0_gtwiz_userclk_tx_usrclk2_int),
    .i_in   (txprbssel_vio_async[4]),
    .o_out  (txprbssel_int[4])
  );
  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_txprbssel_5_inst (
    .clk_in (hb0_gtwiz_userclk_tx_usrclk2_int),
    .i_in   (txprbssel_vio_async[5]),
    .o_out  (txprbssel_int[5])
  );
  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_txprbssel_6_inst (
    .clk_in (hb0_gtwiz_userclk_tx_usrclk2_int),
    .i_in   (txprbssel_vio_async[6]),
    .o_out  (txprbssel_int[6])
  );
  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_txprbssel_7_inst (
    .clk_in (hb0_gtwiz_userclk_tx_usrclk2_int),
    .i_in   (txprbssel_vio_async[7]),
    .o_out  (txprbssel_int[7])
  );

  // Synchronize rxprbssel into the RXUSRCLK2 clock domain from VIO usage
  wire [7:0] rxprbssel_vio_async;

  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_rxprbssel_0_inst (
    .clk_in (hb0_gtwiz_userclk_rx_usrclk2_int),
    .i_in   (rxprbssel_vio_async[0]),
    .o_out  (rxprbssel_int[0])
  );
  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_rxprbssel_1_inst (
    .clk_in (hb0_gtwiz_userclk_rx_usrclk2_int),
    .i_in   (rxprbssel_vio_async[1]),
    .o_out  (rxprbssel_int[1])
  );
  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_rxprbssel_2_inst (
    .clk_in (hb0_gtwiz_userclk_rx_usrclk2_int),
    .i_in   (rxprbssel_vio_async[2]),
    .o_out  (rxprbssel_int[2])
  );
  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_rxprbssel_3_inst (
    .clk_in (hb0_gtwiz_userclk_rx_usrclk2_int),
    .i_in   (rxprbssel_vio_async[3]),
    .o_out  (rxprbssel_int[3])
  );

  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_rxprbssel_4_inst (
    .clk_in (hb0_gtwiz_userclk_rx_usrclk2_int),
    .i_in   (rxprbssel_vio_async[4]),
    .o_out  (rxprbssel_int[4])
  );
  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_rxprbssel_5_inst (
    .clk_in (hb0_gtwiz_userclk_rx_usrclk2_int),
    .i_in   (rxprbssel_vio_async[5]),
    .o_out  (rxprbssel_int[5])
  );
  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_rxprbssel_6_inst (
    .clk_in (hb0_gtwiz_userclk_rx_usrclk2_int),
    .i_in   (rxprbssel_vio_async[6]),
    .o_out  (rxprbssel_int[6])
  );
  (* DONT_TOUCH = "TRUE" *)
  c2c_gth_example_bit_synchronizer bit_synchronizer_vio_rxprbssel_7_inst (
    .clk_in (hb0_gtwiz_userclk_rx_usrclk2_int),
    .i_in   (rxprbssel_vio_async[7]),
    .o_out  (rxprbssel_int[7])
  );


  // Instantiate the VIO IP core for hardware bring-up and debug purposes, connecting relevant debug and analysis
  // signals which have been enabled during Wizard IP customization. This initial set of connected signals is
  // provided as a convenience and example, but more or fewer ports can be used as needed; simply re-customize and
  // re-generate the VIO instance, then connect any exposed signals that are needed. Signals which are synchronous to
  // clocks other than the free-running clock will require synchronization. For usage, refer to Vivado Design Suite
  // User Guide: Programming and Debugging (UG908)
  c2c_gth_vio_0 c2c_gth_vio_0_inst (
    .clk (hb_gtwiz_reset_clk_freerun_buf_int)
    ,.probe_in0 (link_status_out)
    ,.probe_in1 (link_down_latched_out)
    ,.probe_in2 (init_done_int)
    ,.probe_in3 (init_retry_ctr_int)
    ,.probe_in4 (gtpowergood_vio_sync)
    ,.probe_in5 (txpmaresetdone_vio_sync)
    ,.probe_in6 (rxpmaresetdone_vio_sync)
    ,.probe_in7 (gtwiz_reset_tx_done_vio_sync)
    ,.probe_in8 (gtwiz_reset_rx_done_vio_sync)
    ,.probe_in9 (rxprbserr_vio_sync)
    ,.probe_in10 (rxbyteisaligned_int)
    
    ,.probe_out0 (hb_gtwiz_reset_all_vio_int)
    ,.probe_out1 (hb0_gtwiz_reset_tx_pll_and_datapath_int)
    ,.probe_out2 (hb0_gtwiz_reset_tx_datapath_int)
    ,.probe_out3 (hb_gtwiz_reset_rx_pll_and_datapath_vio_int)
    ,.probe_out4 (hb_gtwiz_reset_rx_datapath_vio_int)
    ,.probe_out5 (link_down_latched_reset_vio_int)
    ,.probe_out6 (txprbssel_vio_async)
    ,.probe_out7 (rxprbssel_vio_async)
  );


  // ===================================================================================================================
  // IN-SYSTEM IBERT FOR HARDWARE BRING-UP AND LINK ANALYSIS
  // ===================================================================================================================

  // Instantiate the In-System IBERT IP core for hardware bring-up and link analysis purposes. For usage, refer to
  // Vivado Design Suite User Guide: Programming and Debugging (UG908)
  // In-System IBERT IP instance property dictionary is as follows:
  // CONFIG.C_GT_TYPE {GTH} CONFIG.C_GTS_USED {X0Y24 X0Y25} CONFIG.C_ENABLE_INPUT_PORTS {true}

    assign drpclk_int = {2{hb_gtwiz_reset_clk_freerun_buf_int}};

  
`ifdef C2C_R1_UEC3 // for revision 1 KU15P module, using different MGTs
    c2c_gth_in_system_ibert_0_R1_UEC3
`else
    c2c_gth_in_system_ibert_0
`endif
   
  c2c_gth_in_system_ibert_0_inst 
  (
    .drpclk_o       (drpclk_int),
    .gt0_drpen_o    (drpen_int[0:0]),
    .gt0_drpwe_o    (drpwe_int[0:0]),
    .gt0_drpaddr_o  (drpaddr_int[9:0]),
    .gt0_drpdi_o    (drpdi_int[15:0]),
    .gt0_drprdy_i   (drprdy_int[0:0]),
    .gt0_drpdo_i    (drpdo_int[15:0]),
    .gt1_drpen_o    (drpen_int[1:1]),
    .gt1_drpwe_o    (drpwe_int[1:1]),
    .gt1_drpaddr_o  (drpaddr_int[19:10]),
    .gt1_drpdi_o    (drpdi_int[31:16]),
    .gt1_drprdy_i   (drprdy_int[1:1]),
    .gt1_drpdo_i    (drpdo_int[31:16]),
    .eyescanreset_o (eyescanreset_int),
    .rxrate_o       (rxrate_int),
    .txdiffctrl_o   (txdiffctrl_int),
    .txprecursor_o  (txprecursor_int),
    .txpostcursor_o (txpostcursor_int),
    .rxlpmen_o      (rxlpmen_int),
    .rxrate_i       ({2{3'b000}}),
    .txdiffctrl_i   ({2{5'b11000}}),
    .txprecursor_i  ({2{5'b00000}}),
    .txpostcursor_i ({2{5'b00000}}),
    .rxlpmen_i      ({2{1'b1}}),
    .rxoutclk_i     ({2{hb0_gtwiz_userclk_rx_usrclk2_int}}),
    .drpclk_i       ({2{hb_gtwiz_reset_clk_freerun_buf_int}}),
    .clk            (hb_gtwiz_reset_clk_freerun_buf_int)
  );


   (* mark_debug *) wire [5 : 0] rxbufstatus_out;
   (* mark_debug *) wire [3 : 0] rxclkcorcnt_out;
  // ===================================================================================================================
  // EXAMPLE WRAPPER INSTANCE
  // ===================================================================================================================

  // Instantiate the example design wrapper, mapping its enabled ports to per-channel internal signals and example
  // resources as appropriate
  c2c_gth_example_wrapper example_wrapper_inst (
    .gthrxn_in                               (gthrxn_int)
   ,.gthrxp_in                               (gthrxp_int)
   ,.gthtxn_out                              (gthtxn_int)
   ,.gthtxp_out                              (gthtxp_int)
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
   ,.rxprbssel_in                            (rxprbssel_int)
   ,.rxrate_in                               (rxrate_int)
   ,.tx8b10ben_in                            (tx8b10ben_int)
   ,.txctrl0_in                              (txctrl0_int)
   ,.txctrl1_in                              (txctrl1_int)
   ,.txctrl2_in                              (txctrl2_int)
   ,.txdiffctrl_in                           (txdiffctrl_int)
   ,.txpolarity_in                           (txpolarity_int)
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
   ,.rxdata_out                              (rxdata_int)
   ,.rxpmaresetdone_out                      (rxpmaresetdone_int)
   ,.rxprbserr_out                           (rxprbserr_int)
   ,.txpmaresetdone_out                      (txpmaresetdone_int)

   ,.rxbufstatus_out(rxbufstatus_out)                        // output wire [5 : 0] rxbufstatus_out
   ,.rxclkcorcnt_out(rxclkcorcnt_out)                        // output wire [3 : 0] rxclkcorcnt_out
);


reg [7:0] cc_cnt; // clock correction counter
always @(posedge gtwiz_userclk_tx_usrclk2_int)
begin
    cc_cnt++;
end
wire local_do_cc = (cc_cnt == 8'h0);

// using channel 1 

    c2c_adapter c2c_adapter_i
    (
        .c2c_phy_clk  (gtwiz_userclk_tx_usrclk2_int),
        
        .c2c_rx_data  (c2c_rx_data),
        .c2c_rx_valid (c2c_rx_valid),
        
        .c2c_tx_tdata  (c2c_tx_tdata),
        .c2c_tx_tvalid (c2c_tx_tvalid),
        .do_cc         (local_do_cc),
        .link_reset    (c2c_link_reset),
        

`ifdef C2C_R1_UEC3 // for revision 1 KU15P module, need to use RX and TX in different MGTs due to PCB routing in UEC3 connector
        .mgt_rx_data  (hb1_gtwiz_userdata_rx_int),
        .mgt_rx_k     (ch1_rxctrl2_int[3:0]),
        .rx_aligned   (ch1_rxbyteisaligned_int),
        .mgt_tx_data  (hb0_gtwiz_userdata_tx_int),
        .mgt_tx_k     (ch0_txctrl2_int)
`else
        .mgt_rx_data  (hb1_gtwiz_userdata_rx_int),
        .mgt_rx_k     (ch1_rxctrl2_int[3:0]),
        .rx_aligned   (ch1_rxbyteisaligned_int),
        .mgt_tx_data  (hb1_gtwiz_userdata_tx_int),
        .mgt_tx_k     (ch1_txctrl2_int)
`endif
    );

assign c2c_tx_ready      = 1'b1; // always ready
assign c2c_mmcm_unlocked = 1'b0;
assign c2c_channel_up    = ch1_rxbyteisaligned_int;
assign c2c_init_clk      = mgtrefclk_odiv2; // 250M clock directly from refclk buffer
assign c2c_phy_clk       = gtwiz_userclk_tx_usrclk2_int;

assign c2c_rxbufstatus = rxbufstatus_out [5:3];
assign c2c_rxclkcorcnt = rxclkcorcnt_out [3:2];

endmodule
