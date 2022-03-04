
`timescale 1ps/1ps

// =====================================================================================================================
// This example design wrapper module instantiates the core and any helper blocks which the user chose to exclude from
// the core, connects them as appropriate, and maps enabled ports
// =====================================================================================================================

module c2c_gth_example_wrapper (
  input  wire [1:0] gthrxn_in
 ,input  wire [1:0] gthrxp_in
 ,output wire [1:0] gthtxn_out
 ,output wire [1:0] gthtxp_out
 ,input  wire [0:0] gtwiz_userclk_tx_reset_in
 ,output wire [0:0] gtwiz_userclk_tx_srcclk_out
 ,output wire [0:0] gtwiz_userclk_tx_usrclk_out
 ,output wire [0:0] gtwiz_userclk_tx_usrclk2_out
 ,output wire [0:0] gtwiz_userclk_tx_active_out
 ,input  wire [0:0] gtwiz_userclk_rx_reset_in
 ,output wire [0:0] gtwiz_userclk_rx_srcclk_out
 ,output wire [0:0] gtwiz_userclk_rx_usrclk_out
 ,output wire [0:0] gtwiz_userclk_rx_usrclk2_out
 ,output wire [0:0] gtwiz_userclk_rx_active_out
 ,input  wire [0:0] gtwiz_reset_clk_freerun_in
 ,input  wire [0:0] gtwiz_reset_all_in
 ,input  wire [0:0] gtwiz_reset_tx_pll_and_datapath_in
 ,input  wire [0:0] gtwiz_reset_tx_datapath_in
 ,input  wire [0:0] gtwiz_reset_rx_pll_and_datapath_in
 ,input  wire [0:0] gtwiz_reset_rx_datapath_in
 ,output wire [0:0] gtwiz_reset_rx_cdr_stable_out
 ,output wire [0:0] gtwiz_reset_tx_done_out
 ,output wire [0:0] gtwiz_reset_rx_done_out
 ,input  wire [63:0] gtwiz_userdata_tx_in
 ,output wire [63:0] gtwiz_userdata_rx_out
 ,input  wire [19:0] drpaddr_in
 ,input  wire [1:0] drpclk_in
 ,input  wire [31:0] drpdi_in
 ,input  wire [1:0] drpen_in
 ,input  wire [1:0] drpwe_in
 ,input  wire [1:0] eyescanreset_in
 ,input  wire [1:0] gtrefclk0_in
 ,input  wire [1:0] rx8b10ben_in
 ,input  wire [1:0] rxcommadeten_in
 ,input  wire [1:0] rxlpmen_in
 ,input  wire [1:0] rxmcommaalignen_in
 ,input  wire [1:0] rxpcommaalignen_in
 ,input  wire [7:0] rxprbssel_in
 ,input  wire [5:0] rxrate_in
 ,input  wire [1:0] tx8b10ben_in
 ,input  wire [31:0] txctrl0_in
 ,input  wire [31:0] txctrl1_in
 ,input  wire [15:0] txctrl2_in
 ,input  wire [9:0] txdiffctrl_in
 ,input  wire [1:0] txpolarity_in
 ,input  wire [9:0] txpostcursor_in
 ,input  wire [7:0] txprbssel_in
 ,input  wire [9:0] txprecursor_in
 ,output wire [31:0] drpdo_out
 ,output wire [1:0] drprdy_out
 ,output wire [1:0] gtpowergood_out
 ,output wire [1:0] rxbyteisaligned_out
 ,output wire [1:0] rxbyterealign_out
 ,output wire [1:0] rxcommadet_out
 ,output wire [31:0] rxctrl0_out
 ,output wire [31:0] rxctrl1_out
 ,output wire [15:0] rxctrl2_out
 ,output wire [15:0] rxctrl3_out
 ,output wire [255:0] rxdata_out
 ,output wire [1:0] rxpmaresetdone_out
 ,output wire [1:0] rxprbserr_out
 ,output wire [1:0] txpmaresetdone_out

 ,output wire [5 : 0] rxbufstatus_out
 ,output wire [3 : 0] rxclkcorcnt_out
);


  // ===================================================================================================================
  // PARAMETERS AND FUNCTIONS
  // ===================================================================================================================

  // Declare and initialize local parameters and functions used for HDL generation
  localparam [191:0] P_CHANNEL_ENABLE = 192'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000;
  `include "c2c_gth_example_wrapper_functions.v"
  localparam integer P_TX_MASTER_CH_PACKED_IDX = f_calc_pk_mc_idx(25);
  localparam integer P_RX_MASTER_CH_PACKED_IDX = f_calc_pk_mc_idx(25);


  // ===================================================================================================================
  // HELPER BLOCKS
  // ===================================================================================================================

  // Any helper blocks which the user chose to exclude from the core will appear below. In addition, some signal
  // assignments related to optionally-enabled ports may appear below.

  // -------------------------------------------------------------------------------------------------------------------
  // Transmitter user clocking network helper block
  // -------------------------------------------------------------------------------------------------------------------

  wire [1:0] txusrclk_int;
  wire [1:0] txusrclk2_int;
  wire [1:0] txoutclk_int;

  // Generate a single module instance which is driven by a clock source associated with the master transmitter channel,
  // and which drives TXUSRCLK and TXUSRCLK2 for all channels

  // The source clock is TXOUTCLK from the master transmitter channel
  assign gtwiz_userclk_tx_srcclk_out = txoutclk_int[P_TX_MASTER_CH_PACKED_IDX];

  // Instantiate a single instance of the transmitter user clocking network helper block
  c2c_gth_example_gtwiz_userclk_tx gtwiz_userclk_tx_inst (
    .gtwiz_userclk_tx_srcclk_in   (gtwiz_userclk_tx_srcclk_out),
    .gtwiz_userclk_tx_reset_in    (gtwiz_userclk_tx_reset_in),
    .gtwiz_userclk_tx_usrclk_out  (gtwiz_userclk_tx_usrclk_out),
    .gtwiz_userclk_tx_usrclk2_out (gtwiz_userclk_tx_usrclk2_out),
    .gtwiz_userclk_tx_active_out  (gtwiz_userclk_tx_active_out)
  );

  // Drive TXUSRCLK and TXUSRCLK2 for all channels with the respective helper block outputs
  assign txusrclk_int  = {2{gtwiz_userclk_tx_usrclk_out}};
  assign txusrclk2_int = {2{gtwiz_userclk_tx_usrclk2_out}};

  // -------------------------------------------------------------------------------------------------------------------
  // Receiver user clocking network helper block
  // -------------------------------------------------------------------------------------------------------------------

  wire [1:0] rxusrclk_int;
  wire [1:0] rxusrclk2_int;
  wire [1:0] rxoutclk_int;

  // Generate a single module instance which is driven by a clock source associated with the master receiver channel,
  // and which drives RXUSRCLK and RXUSRCLK2 for all channels

  // The source clock is RXOUTCLK from the master receiver channel
  assign gtwiz_userclk_rx_srcclk_out = rxoutclk_int[P_RX_MASTER_CH_PACKED_IDX];

  // Instantiate a single instance of the receiver user clocking network helper block
  c2c_gth_example_gtwiz_userclk_rx gtwiz_userclk_rx_inst (
    .gtwiz_userclk_rx_srcclk_in   (gtwiz_userclk_rx_srcclk_out),
    .gtwiz_userclk_rx_reset_in    (gtwiz_userclk_rx_reset_in),
    .gtwiz_userclk_rx_usrclk_out  (gtwiz_userclk_rx_usrclk_out),
    .gtwiz_userclk_rx_usrclk2_out (gtwiz_userclk_rx_usrclk2_out),
    .gtwiz_userclk_rx_active_out  (gtwiz_userclk_rx_active_out)
  );

  // Drive RXUSRCLK and RXUSRCLK2 for all channels with the respective helper block outputs
//  assign rxusrclk_int  = {2{gtwiz_userclk_rx_usrclk_out}};
//  assign rxusrclk2_int = {2{gtwiz_userclk_rx_usrclk2_out}};
// using tx clocks for rx
  assign rxusrclk_int  = {2{gtwiz_userclk_tx_usrclk_out}};
  assign rxusrclk2_int = {2{gtwiz_userclk_tx_usrclk2_out}};

  // -------------------------------------------------------------------------------------------------------------------
  // Reset controller helper block
  // -------------------------------------------------------------------------------------------------------------------

  // Generate a single module instance which controls all PLLs and all channels within the core

  // Depending on the number of user clocking network helper blocks, either use the single user clock active indicator
  // or a logical combination of per-channel user clock active indicators as the user clock active indicator for use in
  // this block
  wire gtwiz_reset_userclk_tx_active_int;
  wire gtwiz_reset_userclk_rx_active_int;

  assign gtwiz_reset_userclk_tx_active_int = gtwiz_userclk_tx_active_out;
  assign gtwiz_reset_userclk_rx_active_int = gtwiz_userclk_rx_active_out;

  // Combine the appropriate PLL lock signals such that the reset controller can sense when all PLLs which clock each
  // data direction are locked, regardless of what PLL source is used
  wire gtwiz_reset_plllock_tx_int;
  wire gtwiz_reset_plllock_rx_int;

  wire [1:0] cplllock_int;

  assign gtwiz_reset_plllock_tx_int = &cplllock_int;
  assign gtwiz_reset_plllock_rx_int = &cplllock_int;

  // Combine the power good, reset done, and CDR lock indicators across all channels, per data direction
  wire [1:0] gtpowergood_int;
  wire [1:0] rxcdrlock_int;
  wire [1:0] txresetdone_int;
  wire [1:0] rxresetdone_int;
  wire gtwiz_reset_gtpowergood_int;
  wire gtwiz_reset_rxcdrlock_int;
  wire gtwiz_reset_txresetdone_int;
  wire gtwiz_reset_rxresetdone_int;

  assign gtwiz_reset_gtpowergood_int = &gtpowergood_int;
  assign gtwiz_reset_rxcdrlock_int   = &rxcdrlock_int;

  wire [1:0] txresetdone_sync;
  wire [1:0] rxresetdone_sync;
  genvar gi_ch_xrd;
  generate for (gi_ch_xrd = 0; gi_ch_xrd < 2; gi_ch_xrd = gi_ch_xrd + 1) begin : gen_ch_xrd
    (* DONT_TOUCH = "TRUE" *)
    c2c_gth_example_bit_synchronizer bit_synchronizer_txresetdone_inst (
      .clk_in (gtwiz_reset_clk_freerun_in),
      .i_in   (txresetdone_int[gi_ch_xrd]),
      .o_out  (txresetdone_sync[gi_ch_xrd])
    );
    (* DONT_TOUCH = "TRUE" *)
    c2c_gth_example_bit_synchronizer bit_synchronizer_rxresetdone_inst (
      .clk_in (gtwiz_reset_clk_freerun_in),
      .i_in   (rxresetdone_int[gi_ch_xrd]),
      .o_out  (rxresetdone_sync[gi_ch_xrd])
    );
  end
  endgenerate
  assign gtwiz_reset_txresetdone_int = &txresetdone_sync;
  assign gtwiz_reset_rxresetdone_int = &rxresetdone_sync;

  wire gtwiz_reset_pllreset_tx_int;
  wire gtwiz_reset_txprogdivreset_int;
  wire gtwiz_reset_gttxreset_int;
  wire gtwiz_reset_txuserrdy_int;
  wire gtwiz_reset_pllreset_rx_int;
  wire gtwiz_reset_rxprogdivreset_int;
  wire gtwiz_reset_gtrxreset_int;
  wire gtwiz_reset_rxuserrdy_int;

  // Instantiate the single reset controller
  c2c_gth_example_gtwiz_reset gtwiz_reset_inst (
    .gtwiz_reset_clk_freerun_in         (gtwiz_reset_clk_freerun_in),
    .gtwiz_reset_all_in                 (gtwiz_reset_all_in),
    .gtwiz_reset_tx_pll_and_datapath_in (gtwiz_reset_tx_pll_and_datapath_in),
    .gtwiz_reset_tx_datapath_in         (gtwiz_reset_tx_datapath_in),
    .gtwiz_reset_rx_pll_and_datapath_in (gtwiz_reset_rx_pll_and_datapath_in),
    .gtwiz_reset_rx_datapath_in         (gtwiz_reset_rx_datapath_in),
    .gtwiz_reset_rx_cdr_stable_out      (gtwiz_reset_rx_cdr_stable_out),
    .gtwiz_reset_tx_done_out            (gtwiz_reset_tx_done_out),
    .gtwiz_reset_rx_done_out            (gtwiz_reset_rx_done_out),
    .gtwiz_reset_userclk_tx_active_in   (gtwiz_reset_userclk_tx_active_int),
    .gtwiz_reset_userclk_rx_active_in   (gtwiz_reset_userclk_rx_active_int),
    .gtpowergood_in                     (gtwiz_reset_gtpowergood_int),
    .txusrclk2_in                       (gtwiz_userclk_tx_usrclk2_out),
    .plllock_tx_in                      (gtwiz_reset_plllock_tx_int),
    .txresetdone_in                     (gtwiz_reset_txresetdone_int),
    .rxusrclk2_in                       (gtwiz_userclk_rx_usrclk2_out),
    .plllock_rx_in                      (gtwiz_reset_plllock_rx_int),
    .rxcdrlock_in                       (gtwiz_reset_rxcdrlock_int),
    .rxresetdone_in                     (gtwiz_reset_rxresetdone_int),
    .pllreset_tx_out                    (gtwiz_reset_pllreset_tx_int),
    .txprogdivreset_out                 (gtwiz_reset_txprogdivreset_int),
    .gttxreset_out                      (gtwiz_reset_gttxreset_int),
    .txuserrdy_out                      (gtwiz_reset_txuserrdy_int),
    .pllreset_rx_out                    (gtwiz_reset_pllreset_rx_int),
    .rxprogdivreset_out                 (gtwiz_reset_rxprogdivreset_int),
    .gtrxreset_out                      (gtwiz_reset_gtrxreset_int),
    .rxuserrdy_out                      (gtwiz_reset_rxuserrdy_int),
    .tx_enabled_tie_in                  (1'b1),
    .rx_enabled_tie_in                  (1'b1),
    .shared_pll_tie_in                  (1'b1)
  );

  // Drive the internal PLL reset inputs with the appropriate PLL reset signals produced by the reset controller. The
  // single reset controller instance generates independent transmit PLL reset and receive PLL reset outputs, which are
  // used across all such PLLs in the core.
  wire [1:0] cpllpd_int;

  assign cpllpd_int     = {2{gtwiz_reset_pllreset_tx_int || gtwiz_reset_pllreset_rx_int}};

  // Fan out appropriate reset controller outputs to all transceiver channels
  wire [1:0] txprogdivreset_int;
  wire [1:0] gttxreset_int;
  wire [1:0] txuserrdy_int;
  wire [1:0] rxprogdivreset_int;
  wire [1:0] gtrxreset_int;
  wire [1:0] rxuserrdy_int;

  assign txprogdivreset_int  = {2{gtwiz_reset_txprogdivreset_int}};
  assign gttxreset_int       = {2{gtwiz_reset_gttxreset_int}};
  assign txuserrdy_int       = {2{gtwiz_reset_txuserrdy_int}};
  assign rxprogdivreset_int  = {2{gtwiz_reset_rxprogdivreset_int}};
  assign gtrxreset_int       = {2{gtwiz_reset_gtrxreset_int}};
  assign rxuserrdy_int       = {2{gtwiz_reset_rxuserrdy_int}};

  // Required assignment to expose the GTPOWERGOOD port per user request
  assign gtpowergood_out = gtpowergood_int;

  // ----------------------------------------------------------------------------------------------------------------
  // Assignments to expose data ports, or data control ports, per configuration requirement or user request
  // ----------------------------------------------------------------------------------------------------------------

  wire [31:0] txctrl0_int;

  // Required assignment to expose the TXCTRL0 port per configuration requirement or user request
  assign txctrl0_int = txctrl0_in;
  wire [31:0] txctrl1_int;

  // Required assignment to expose the TXCTRL1 port per configuration requirement or user request
  assign txctrl1_int = txctrl1_in;
  wire [255:0] rxdata_int;

  // Required assignment to expose the RXDATA port per user request
  assign rxdata_out = rxdata_int;
  wire [31:0] rxctrl0_int;

  // Required assignment to expose the RXCTRL0 port per configuration requirement or user request
  assign rxctrl0_out = rxctrl0_int;
  wire [31:0] rxctrl1_int;

  // Required assignment to expose the RXCTRL1 port per configuration requirement or user request
  assign rxctrl1_out = rxctrl1_int;


  // ===================================================================================================================
  // CORE INSTANCE
  // ===================================================================================================================

  // Instantiate the core, mapping its enabled ports to example design ports and helper blocks as appropriate
`ifdef C2C_2P5G
    c2c_gth_2p5g c2c_gth_inst// 2.5G
`else
`ifdef C2C_3P125G
    c2c_gth_3p125g c2c_gth_inst// 3.125G
`else  
    c2c_gth c2c_gth_inst// 3.75G
`endif
`endif 
    (
    .gthrxn_in                               (gthrxn_in)
   ,.gthrxp_in                               (gthrxp_in)
   ,.gthtxn_out                              (gthtxn_out)
   ,.gthtxp_out                              (gthtxp_out)
   ,.gtwiz_userclk_tx_reset_in               (gtwiz_userclk_tx_reset_in)
   ,.gtwiz_userclk_tx_active_in              (gtwiz_userclk_tx_active_out)
   ,.gtwiz_userclk_rx_active_in              (gtwiz_userclk_rx_active_out)
   ,.gtwiz_reset_tx_done_in                  (gtwiz_reset_tx_done_out)
   ,.gtwiz_reset_rx_done_in                  (gtwiz_reset_rx_done_out)
   ,.gtwiz_userdata_tx_in                    (gtwiz_userdata_tx_in)
   ,.gtwiz_userdata_rx_out                   (gtwiz_userdata_rx_out)
   ,.cpllpd_in                               (cpllpd_int)
   ,.drpaddr_in                              (drpaddr_in)
   ,.drpclk_in                               (drpclk_in)
   ,.drpdi_in                                (drpdi_in)
   ,.drpen_in                                (drpen_in)
   ,.drpwe_in                                (drpwe_in)
   ,.eyescanreset_in                         (eyescanreset_in)
   ,.gtrefclk0_in                            (gtrefclk0_in)
   ,.gtrxreset_in                            (gtrxreset_int)
   ,.gttxreset_in                            (gttxreset_int)
   ,.rx8b10ben_in                            (rx8b10ben_in)
   ,.rxcommadeten_in                         (rxcommadeten_in)
   ,.rxlpmen_in                              (rxlpmen_in)
   ,.rxmcommaalignen_in                      (rxmcommaalignen_in)
   ,.rxpcommaalignen_in                      (rxpcommaalignen_in)
   ,.rxprbssel_in                            (rxprbssel_in)
   ,.rxprogdivreset_in                       (rxprogdivreset_int)
   ,.rxrate_in                               (rxrate_in)
   ,.rxuserrdy_in                            (rxuserrdy_int)
   ,.rxusrclk_in                             (rxusrclk_int)
   ,.rxusrclk2_in                            (rxusrclk2_int)
   ,.tx8b10ben_in                            (tx8b10ben_in)
   ,.txctrl0_in                              (txctrl0_int)
   ,.txctrl1_in                              (txctrl1_int)
   ,.txctrl2_in                              (txctrl2_in)
   ,.txdiffctrl_in                           (txdiffctrl_in)
   ,.txpolarity_in                           (txpolarity_in)
   ,.txpostcursor_in                         (txpostcursor_in)
   ,.txprbssel_in                            (txprbssel_in)
   ,.txprecursor_in                          (txprecursor_in)
   ,.txprogdivreset_in                       (txprogdivreset_int)
   ,.txuserrdy_in                            (txuserrdy_int)
   ,.txusrclk_in                             (txusrclk_int)
   ,.txusrclk2_in                            (txusrclk2_int)
   ,.cplllock_out                            (cplllock_int)
   ,.drpdo_out                               (drpdo_out)
   ,.drprdy_out                              (drprdy_out)
   ,.gtpowergood_out                         (gtpowergood_int)
   ,.rxbyteisaligned_out                     (rxbyteisaligned_out)
   ,.rxbyterealign_out                       (rxbyterealign_out)
   ,.rxcdrlock_out                           (rxcdrlock_int)
   ,.rxcommadet_out                          (rxcommadet_out)
   ,.rxctrl0_out                             (rxctrl0_int)
   ,.rxctrl1_out                             (rxctrl1_int)
   ,.rxctrl2_out                             (rxctrl2_out)
   ,.rxctrl3_out                             (rxctrl3_out)
   ,.rxdata_out                              (rxdata_int)
   ,.rxoutclk_out                            (rxoutclk_int)
   ,.rxpmaresetdone_out                      (rxpmaresetdone_out)
   ,.rxprbserr_out                           (rxprbserr_out)
   ,.rxresetdone_out                         (rxresetdone_int)
   ,.txoutclk_out                            (txoutclk_int)
   ,.txpmaresetdone_out                      (txpmaresetdone_out)
   ,.txresetdone_out                         (txresetdone_int)

   ,.rxbufstatus_out(rxbufstatus_out)                        // output wire [5 : 0] rxbufstatus_out
   ,.rxclkcorcnt_out(rxclkcorcnt_out)                        // output wire [3 : 0] rxclkcorcnt_out
);

endmodule
