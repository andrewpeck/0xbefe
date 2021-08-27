`timescale 1ps/1ps
module c2c_mgt_bit_synchronizer # (

  parameter INITIALIZE = 5'b00000,
  parameter FREQUENCY  = 512

)(

  input  wire clk_in,
  input  wire i_in,
  output wire o_out

);

  // Use 5 flip-flops as a single synchronizer, and tag each declaration with the appropriate synthesis attribute to
  // enable clustering. Their GSR default values are provided by the INITIALIZE parameter.

  (* ASYNC_REG = "TRUE" *) reg i_in_meta  = INITIALIZE[0];
  (* ASYNC_REG = "TRUE" *) reg i_in_sync1 = INITIALIZE[1];
  (* ASYNC_REG = "TRUE" *) reg i_in_sync2 = INITIALIZE[2];
  (* ASYNC_REG = "TRUE" *) reg i_in_sync3 = INITIALIZE[3];
                           reg i_in_out   = INITIALIZE[4];

  always @(posedge clk_in) begin
    i_in_meta  <= i_in;
    i_in_sync1 <= i_in_meta;
    i_in_sync2 <= i_in_sync1;
    i_in_sync3 <= i_in_sync2;
    i_in_out   <= i_in_sync3;
  end

  assign o_out = i_in_out;


endmodule

module c2c_mgt_gtwiz_reset # (

  parameter real    P_FREERUN_FREQUENCY       = 39.0625,
  parameter integer P_USE_CPLL_CAL            = 0,
  parameter integer P_TX_PLL_TYPE             = 2,
  parameter integer P_RX_PLL_TYPE             = 2,
  parameter real    P_RX_LINE_RATE            = 3.125,
  parameter [25:0]  P_CDR_TIMEOUT_FREERUN_CYC = (37000 * 39.0625) / 3.125

)(

  // User interface ports
  input  wire gtwiz_reset_clk_freerun_in,
  input  wire gtwiz_reset_all_in,
  input  wire gtwiz_reset_tx_pll_and_datapath_in,
  input  wire gtwiz_reset_tx_datapath_in,
  input  wire gtwiz_reset_rx_pll_and_datapath_in,
  input  wire gtwiz_reset_rx_datapath_in,
  output wire gtwiz_reset_rx_cdr_stable_out,
  output wire gtwiz_reset_tx_done_out,
  output wire gtwiz_reset_rx_done_out,
  input  wire gtwiz_reset_userclk_tx_active_in,
  input  wire gtwiz_reset_userclk_rx_active_in,

  // Transceiver interface ports
  input  wire gtpowergood_in,
  input  wire txusrclk2_in,
  input  wire plllock_tx_in,
  input  wire txresetdone_in,
  input  wire rxusrclk2_in,
  input  wire plllock_rx_in,
  input  wire rxcdrlock_in,
  input  wire rxresetdone_in,
  output reg  pllreset_tx_out    = 1'b1,
  output wire txprogdivreset_out,
  output reg  gttxreset_out      = 1'b1,
  output reg  txuserrdy_out      = 1'b0,
  output reg  pllreset_rx_out,
  output reg  rxprogdivreset_out = 1'b1,
  output reg  gtrxreset_out      = 1'b1,
  output reg  rxuserrdy_out      = 1'b0,

  // Tie-offs based on core configuration
  input  wire tx_enabled_tie_in,
  input  wire rx_enabled_tie_in,
  input  wire shared_pll_tie_in

);


  // -------------------------------------------------------------------------------------------------------------------
  // "Reset all" state machine
  // -------------------------------------------------------------------------------------------------------------------

  // The "reset all" state machine responds to the synchronized gtwiz_reset_all_in input by resetting the enabled PLLs
  // and data paths of those transceiver resources to which the reset helper block is connected. It does so by guiding
  // the independent transmitter and receiver reset state machines, which are also user-accessible. The path through the
  // "reset all" state machine is a function of module input tie-offs, which depend on the core configuration.

  // Synchronize the "reset all" input signal into the free-running clock domain
  wire gtwiz_reset_all_sync;
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_reset_synchronizer reset_synchronizer_gtwiz_reset_all_inst (
    .clk_in  (gtwiz_reset_clk_freerun_in),
    .rst_in  (gtwiz_reset_all_in),
    .rst_out (gtwiz_reset_all_sync)
  );

  // Synchronize the transceiver power good indicator
  wire gtpowergood_sync;
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_gtpowergood_inst (
    .clk_in (gtwiz_reset_clk_freerun_in),
    .i_in   (gtpowergood_in),
    .o_out  (gtpowergood_sync)
  );

  // Declare the "reset all" state machine reset timer registers
  reg       sm_reset_all_timer_clr = 1'b1;
  reg [2:0] sm_reset_all_timer_ctr = 3'd0;
  reg       sm_reset_all_timer_sat = 1'b0;

  // Declare local parameters used to represent both static and variable state machine state values
  localparam [2:0] ST_RESET_ALL_INIT        = 3'd0;
  localparam [2:0] ST_RESET_ALL_BRANCH      = 3'd1;
  localparam [2:0] ST_RESET_ALL_TX_PLL      = 3'd2;
  localparam [2:0] ST_RESET_ALL_TX_PLL_WAIT = 3'd3;
  localparam [2:0] ST_RESET_ALL_RX_DP       = 3'd4;
  localparam [2:0] ST_RESET_ALL_RX_PLL      = 3'd5;
  localparam [2:0] ST_RESET_ALL_RX_WAIT     = 3'd6;
  localparam [2:0] ST_RESET_ALL_DONE        = 3'd7;
  reg        [2:0] sm_reset_all             = ST_RESET_ALL_INIT;

  // Declare relevant internal control and status registers of this and other state machines
  reg gtwiz_reset_tx_pll_and_datapath_int = 1'b0;
  reg gtwiz_reset_tx_done_int             = 1'b0;
  reg gtwiz_reset_rx_pll_and_datapath_int = 1'b0;
  reg gtwiz_reset_rx_datapath_int         = 1'b0;
  reg gtwiz_reset_rx_done_int             = 1'b0;

  // Implement the "reset all" state machine control and its outputs as a single sequential process. The state machine
  // is reset by the synchronized gtwiz_reset_all_sync input.
  always @(posedge gtwiz_reset_clk_freerun_in) begin
    if (gtwiz_reset_all_sync) begin
      gtwiz_reset_tx_pll_and_datapath_int <= 1'b0;
      gtwiz_reset_rx_pll_and_datapath_int <= 1'b0;
      gtwiz_reset_rx_datapath_int         <= 1'b0;
      sm_reset_all_timer_clr              <= 1'b1;
      sm_reset_all                        <= ST_RESET_ALL_BRANCH;
    end
    else begin
      case (sm_reset_all)

        // Upon initial configuration, check or wait for the transceiver power good indicator to be asserted before
        // proceeding with the sequence automatically
        ST_RESET_ALL_INIT: begin
          if (gtpowergood_sync)
            sm_reset_all <= ST_RESET_ALL_BRANCH;
        end

        // If the transmitter is enabled, begin by resetting the TX PLL. If the transmitter is disabled, begin by
        // resetting the RX PLL.
        ST_RESET_ALL_BRANCH: begin
          if (tx_enabled_tie_in)
            sm_reset_all <= ST_RESET_ALL_TX_PLL;
          else
            sm_reset_all <= ST_RESET_ALL_RX_PLL;
          sm_reset_all_timer_clr <= 1'b1;
        end

        // Force the transmitter reset state machine to reset the TX PLL and data path
        ST_RESET_ALL_TX_PLL: begin
          gtwiz_reset_tx_pll_and_datapath_int <= 1'b1;
          sm_reset_all                        <= ST_RESET_ALL_TX_PLL_WAIT;
        end

        // Await completion of the TX PLL and data path reset sequence. Then, if the receiver is enabled, continue by
        // either resetting just the RX data path (if the receiver and transmitter share a PLL) or the RX PLL (if the
        // receiver and transmitter PLLs are indepdendent). If the receiver is disabled, complete the sequence.
        ST_RESET_ALL_TX_PLL_WAIT: begin
          gtwiz_reset_tx_pll_and_datapath_int <= 1'b0;
          sm_reset_all_timer_clr              <= 1'b0;
          if (gtwiz_reset_tx_done_int && (~sm_reset_all_timer_clr) && sm_reset_all_timer_sat) begin
            if (rx_enabled_tie_in) begin
              if (shared_pll_tie_in)
                sm_reset_all <= ST_RESET_ALL_RX_DP;
              else
                sm_reset_all <= ST_RESET_ALL_RX_PLL;
            end
            else
              sm_reset_all <= ST_RESET_ALL_DONE;
            sm_reset_all_timer_clr <= 1'b1;
          end
        end

        // Force the receiver reset state machine to reset the RX data path
        ST_RESET_ALL_RX_DP: begin
          gtwiz_reset_rx_datapath_int <= 1'b1;
          sm_reset_all                <= ST_RESET_ALL_RX_WAIT;
        end

        // Force the receiver reset state machine to reset the RX PLL and data path
        ST_RESET_ALL_RX_PLL: begin
          gtwiz_reset_rx_pll_and_datapath_int <= 1'b1;
          sm_reset_all                        <= ST_RESET_ALL_RX_WAIT;
        end

        // Await completion of whichever RX reset sequence was performed
        ST_RESET_ALL_RX_WAIT: begin
          gtwiz_reset_rx_datapath_int         <= 1'b0;
          sm_reset_all_timer_clr              <= 1'b0;
          gtwiz_reset_rx_pll_and_datapath_int <= 1'b0;
          if (gtwiz_reset_rx_done_int && (~sm_reset_all_timer_clr) && sm_reset_all_timer_sat) begin
            sm_reset_all           <= ST_RESET_ALL_DONE;
            sm_reset_all_timer_clr <= 1'b1;
          end
        end

      endcase
    end
  end

  // Generate a small "reset all" state machine reset timer, used to stall certain states to guarantee that their
  // synchronized input values are being used at the appropriate time
  always @(posedge gtwiz_reset_clk_freerun_in) begin
    if (sm_reset_all_timer_clr) begin
      sm_reset_all_timer_ctr <= 3'd0;
      sm_reset_all_timer_sat <= 1'b0;
    end
    else begin
      if (sm_reset_all_timer_ctr != 3'd7)
        sm_reset_all_timer_ctr <= sm_reset_all_timer_ctr + 3'd1;
      else
        sm_reset_all_timer_sat <= 1'b1;
    end
  end


  // -------------------------------------------------------------------------------------------------------------------
  // Transmitter reset state machine
  // -------------------------------------------------------------------------------------------------------------------

  // The transmitter reset state machine responds to various synchronized inputs by resetting enabled transmitter-
  // related transceiver resources to which the reset helper block is connected. Various entry points to the sequential
  // reset sequence are available.

  // Synchronize the OR of all user input and internal TX reset signals for use in resetting the TX reset state machine
  wire gtwiz_reset_tx_any;
  wire gtwiz_reset_tx_any_sync;
  assign gtwiz_reset_tx_any = gtwiz_reset_tx_pll_and_datapath_in  ||
                              gtwiz_reset_tx_pll_and_datapath_int ||
                              gtwiz_reset_tx_datapath_in;
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_reset_synchronizer reset_synchronizer_gtwiz_reset_tx_any_inst (
    .clk_in  (gtwiz_reset_clk_freerun_in),
    .rst_in  (gtwiz_reset_tx_any),
    .rst_out (gtwiz_reset_tx_any_sync)
  );

  // Synchronize the OR of the user input and internal TX PLL and data path reset signals
  wire gtwiz_reset_tx_pll_and_datapath_sync;
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_reset_synchronizer reset_synchronizer_gtwiz_reset_tx_pll_and_datapath_inst (
    .clk_in  (gtwiz_reset_clk_freerun_in),
    .rst_in  (gtwiz_reset_tx_pll_and_datapath_in || gtwiz_reset_tx_pll_and_datapath_int),
    .rst_out (gtwiz_reset_tx_pll_and_datapath_sync)
  );

  // Use another synchronizer to delay the above signal for purposes of its detection following reset
  wire gtwiz_reset_tx_pll_and_datapath_dly;
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_gtwiz_reset_tx_pll_and_datapath_dly_inst (
    .clk_in (gtwiz_reset_clk_freerun_in),
    .i_in   (gtwiz_reset_tx_pll_and_datapath_sync),
    .o_out  (gtwiz_reset_tx_pll_and_datapath_dly)
  );

  // Synchronize the TX data path reset user input
  wire gtwiz_reset_tx_datapath_sync;
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_reset_synchronizer reset_synchronizer_gtwiz_reset_tx_datapath_inst (
    .clk_in  (gtwiz_reset_clk_freerun_in),
    .rst_in  (gtwiz_reset_tx_datapath_in),
    .rst_out (gtwiz_reset_tx_datapath_sync)
  );

  // Use another synchronizer to delay the above signal for purposes of its detection following reset
  wire gtwiz_reset_tx_datapath_dly;
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_gtwiz_reset_tx_datapath_dly_inst (
    .clk_in (gtwiz_reset_clk_freerun_in),
    .i_in   (gtwiz_reset_tx_datapath_sync),
    .o_out  (gtwiz_reset_tx_datapath_dly)
  );

  // Synchronize the TX user clock active indicator
  wire gtwiz_reset_userclk_tx_active_sync;
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_gtwiz_reset_userclk_tx_active_inst (
    .clk_in (gtwiz_reset_clk_freerun_in),
    .i_in   (gtwiz_reset_userclk_tx_active_in),
    .o_out  (gtwiz_reset_userclk_tx_active_sync)
  );

  // Synchronize the TX PLL lock indicator
  wire plllock_tx_sync;
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_plllock_tx_inst (
    .clk_in (gtwiz_reset_clk_freerun_in),
    .i_in   (plllock_tx_in),
    .o_out  (plllock_tx_sync)
  );

  // Declare the TX state machine reset timer registers
  reg       sm_reset_tx_timer_clr = 1'b1;
  reg [2:0] sm_reset_tx_timer_ctr = 3'd0;
  reg       sm_reset_tx_timer_sat = 1'b0;

  // Declare the TX state machine PLL reset timer registers
  localparam [9:0] P_TX_PLL_RESET_FREERUN_CYC = (P_TX_PLL_TYPE == 2) ?
                                                (2 * P_FREERUN_FREQUENCY) + 2 : 7;
  reg        sm_reset_tx_pll_timer_clr = 1'b1;
  reg  [9:0] sm_reset_tx_pll_timer_ctr = 10'd0;
  reg        sm_reset_tx_pll_timer_sat = 1'b0;
  wire [9:0] p_tx_pll_reset_freerun_cyc_int = P_TX_PLL_RESET_FREERUN_CYC;

  // Declare local parameters for TX reset state machine state values
  localparam [2:0] ST_RESET_TX_BRANCH         = 3'd0;
  localparam [2:0] ST_RESET_TX_PLL            = 3'd1;
  localparam [2:0] ST_RESET_TX_DATAPATH       = 3'd2;
  localparam [2:0] ST_RESET_TX_WAIT_LOCK      = 3'd3;
  localparam [2:0] ST_RESET_TX_WAIT_USERRDY   = 3'd4;
  localparam [2:0] ST_RESET_TX_WAIT_RESETDONE = 3'd5;
  localparam [2:0] ST_RESET_TX_IDLE           = 3'd6;
  reg        [2:0] sm_reset_tx                = ST_RESET_TX_BRANCH;

  // Implementation of transmitter reset state machine synchronous process
  always @(posedge gtwiz_reset_clk_freerun_in) begin

    // The state machine is synchronously reset by the synchronized OR of all user input and internal TX reset signals
    if (gtwiz_reset_tx_any_sync) begin
      gtwiz_reset_tx_done_int   <= 1'b0;
      sm_reset_tx_timer_clr     <= 1'b1;
      sm_reset_tx_pll_timer_clr <= 1'b1;
      sm_reset_tx               <= ST_RESET_TX_BRANCH;
    end
    else begin
      case (sm_reset_tx)

        // Once released from reset, branch to the reset control state indicated by the highest-priority synchronized
        // signal (which remains asserted due to its long synchronizer chain)
        ST_RESET_TX_BRANCH: begin
          if (gtwiz_reset_tx_pll_and_datapath_dly)
            sm_reset_tx <= ST_RESET_TX_PLL;
          else if (gtwiz_reset_tx_datapath_dly)
            sm_reset_tx <= ST_RESET_TX_DATAPATH;
          sm_reset_tx_timer_clr     <= 1'b1;
          sm_reset_tx_pll_timer_clr <= 1'b1;
        end

        // Assert the TX PLL and TX data path reset outputs
        ST_RESET_TX_PLL: begin
          pllreset_tx_out           <= 1'b1;
          gttxreset_out             <= 1'b1;
          txuserrdy_out             <= 1'b0;
          sm_reset_tx_pll_timer_clr <= 1'b0;
          if ((~sm_reset_tx_pll_timer_clr) && sm_reset_tx_pll_timer_sat) begin
            sm_reset_tx_pll_timer_clr <= 1'b1;
            sm_reset_tx               <= ST_RESET_TX_WAIT_LOCK;
          end
        end

        // Assert the TX data path reset output
        ST_RESET_TX_DATAPATH: begin
          gttxreset_out         <= 1'b1;
          txuserrdy_out         <= 1'b0;
          sm_reset_tx_timer_clr <= 1'b0;
          if ((~sm_reset_tx_timer_clr) && sm_reset_tx_timer_sat) begin
            sm_reset_tx_timer_clr <= 1'b1;
            sm_reset_tx           <= ST_RESET_TX_WAIT_LOCK;
          end
        end

        // De-assert the TX PLL reset output, and await the TX PLL lock indicator before de-asserting the TX data path
        // reset output
        ST_RESET_TX_WAIT_LOCK: begin
          pllreset_tx_out       <= 1'b0;
          sm_reset_tx_timer_clr <= 1'b0;
          if (plllock_tx_sync && (~sm_reset_tx_timer_clr) && sm_reset_tx_timer_sat) begin
            gttxreset_out         <= 1'b0;
            sm_reset_tx_timer_clr <= 1'b1;
            sm_reset_tx           <= ST_RESET_TX_WAIT_USERRDY;
          end
        end

        // Await the TX user clock active indicator from the TX user clocking helper block before asserting the TX user
        // ready output
        ST_RESET_TX_WAIT_USERRDY: begin
          sm_reset_tx_timer_clr <= 1'b0;
          if (gtwiz_reset_userclk_tx_active_sync && (~sm_reset_tx_timer_clr) && sm_reset_tx_timer_sat) begin
            txuserrdy_out         <= 1'b1;
            sm_reset_tx_timer_clr <= 1'b1;
            sm_reset_tx           <= ST_RESET_TX_WAIT_RESETDONE;
          end
        end

        // Await the TX reset done indicator before asserting the reset helper block TX reset done user output
        ST_RESET_TX_WAIT_RESETDONE: begin
          sm_reset_tx_timer_clr <= 1'b0;
          if (txresetdone_in && (~sm_reset_tx_timer_clr) && sm_reset_tx_timer_sat) begin
            gtwiz_reset_tx_done_int <= 1'b1;
            sm_reset_tx_timer_clr   <= 1'b1;
            sm_reset_tx             <= ST_RESET_TX_IDLE;
          end
        end

        // While idle, de-assert the reset helper block TX reset done user output if PLL lock is lost, signaling the
        // need for user intervention
        ST_RESET_TX_IDLE: begin
          if (!plllock_tx_sync)
            gtwiz_reset_tx_done_int <= 1'b0;
        end

        // Encountering the default case indicates a state register error, so de-assert the reset helper block TX
        // reset done user output, signaling the need for user intervention
        default: begin
          gtwiz_reset_tx_done_int <= 1'b0;
        end

      endcase
    end
  end

  // Generate a small TX state machine reset timer, used to stall certain states to guarantee that their synchronized
  // input values are being used at the appropriate time
  always @(posedge gtwiz_reset_clk_freerun_in) begin
    if (sm_reset_tx_timer_clr) begin
      sm_reset_tx_timer_ctr <= 3'd0;
      sm_reset_tx_timer_sat <= 1'b0;
    end
    else begin
      if (sm_reset_tx_timer_ctr != 3'd7)
        sm_reset_tx_timer_ctr <= sm_reset_tx_timer_ctr + 3'd1;
      else
        sm_reset_tx_timer_sat <= 1'b1;
    end
  end

  // Generate an TX PLL reset timer, used to indicate when the specified minimum TX PLL reset duration has expired. This
  // is used by the TX state machine to proceed beyond the ST_RESET_TX_PLL wait state.
  always @(posedge gtwiz_reset_clk_freerun_in) begin
    if (sm_reset_tx_pll_timer_clr) begin
      sm_reset_tx_pll_timer_ctr <= 10'd0;
      sm_reset_tx_pll_timer_sat <= 1'b0;
    end
    else begin
      if (sm_reset_tx_pll_timer_ctr != p_tx_pll_reset_freerun_cyc_int)
        sm_reset_tx_pll_timer_ctr <= sm_reset_tx_pll_timer_ctr + 10'd1;
      else
        sm_reset_tx_pll_timer_sat <= 1'b1;
    end
  end

  // Hold the TX programmable divider in reset until the TX PLL has locked
  c2c_mgt_reset_synchronizer reset_synchronizer_txprogdivreset_inst (
    .clk_in  (gtwiz_reset_clk_freerun_in),
    .rst_in  (~plllock_tx_in),
    .rst_out (txprogdivreset_out)
  );

  // Synchronize the reset helper block TX reset done user output into the TXUSRCLK2 domain for user consumption
  c2c_mgt_reset_inv_synchronizer reset_synchronizer_tx_done_inst (
    .clk_in  (txusrclk2_in),
    .rst_in  (gtwiz_reset_tx_done_int),
    .rst_out (gtwiz_reset_tx_done_out)
  );


  // -------------------------------------------------------------------------------------------------------------------
  // Receiver reset state machine
  // -------------------------------------------------------------------------------------------------------------------

  // The receiver reset state machine responds to various synchronized inputs by resetting enabled receiver-
  // related transceiver resources to which the reset helper block is connected. Various entry points to the sequential
  // reset sequence are available.

  // Initialize (for both synthesis and simulation) the RX PLL reset output flip-flop to 0 if the TX and RX PLLs are
  // shared upon device configuration, so as to not block TX PLL reset; or to 1 if the PLLs are independent, for
  // consistency with TX PLL initialization
  initial begin
    if (P_TX_PLL_TYPE == P_RX_PLL_TYPE)
      pllreset_rx_out = 1'b0;
    else
      pllreset_rx_out = 1'b1;
  end

  // Synchronize the OR of all user input and internal RX reset signals for use in resetting the RX reset state machine
  wire gtwiz_reset_rx_any;
  wire gtwiz_reset_rx_any_sync;
  assign gtwiz_reset_rx_any = gtwiz_reset_rx_pll_and_datapath_in  ||
                              gtwiz_reset_rx_pll_and_datapath_int ||
                              gtwiz_reset_rx_datapath_in          ||
                              gtwiz_reset_rx_datapath_int;
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_reset_synchronizer reset_synchronizer_gtwiz_reset_rx_any_inst (
    .clk_in  (gtwiz_reset_clk_freerun_in),
    .rst_in  (gtwiz_reset_rx_any),
    .rst_out (gtwiz_reset_rx_any_sync)
  );

  // Synchronize the OR of the user input and internal RX PLL and data path reset signals
  wire gtwiz_reset_rx_pll_and_datapath_sync;
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_reset_synchronizer reset_synchronizer_gtwiz_reset_rx_pll_and_datapath_inst (
    .clk_in  (gtwiz_reset_clk_freerun_in),
    .rst_in  (gtwiz_reset_rx_pll_and_datapath_in || gtwiz_reset_rx_pll_and_datapath_int),
    .rst_out (gtwiz_reset_rx_pll_and_datapath_sync)
  );

  // Use another synchronizer to delay the above signal for purposes of its detection following reset
  wire gtwiz_reset_rx_pll_and_datapath_dly;
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_gtwiz_reset_rx_pll_and_datapath_dly_inst (
    .clk_in (gtwiz_reset_clk_freerun_in),
    .i_in   (gtwiz_reset_rx_pll_and_datapath_sync),
    .o_out  (gtwiz_reset_rx_pll_and_datapath_dly)
  );

  // Synchronize the RX data path reset user input
  wire gtwiz_reset_rx_datapath_sync;
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_reset_synchronizer reset_synchronizer_gtwiz_reset_rx_datapath_inst (
    .clk_in  (gtwiz_reset_clk_freerun_in),
    .rst_in  (gtwiz_reset_rx_datapath_in || gtwiz_reset_rx_datapath_int),
    .rst_out (gtwiz_reset_rx_datapath_sync)
  );

  // Use another synchronizer to delay the above signal for purposes of its detection following reset
  wire gtwiz_reset_rx_datapath_dly;
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_gtwiz_reset_rx_datapath_dly_inst (
    .clk_in (gtwiz_reset_clk_freerun_in),
    .i_in   (gtwiz_reset_rx_datapath_sync),
    .o_out  (gtwiz_reset_rx_datapath_dly)
  );

  // Synchronize the RX user clock active indicator
  wire gtwiz_reset_userclk_rx_active_sync;
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_gtwiz_reset_userclk_rx_active_inst (
    .clk_in (gtwiz_reset_clk_freerun_in),
    .i_in   (gtwiz_reset_userclk_rx_active_in),
    .o_out  (gtwiz_reset_userclk_rx_active_sync)
  );

  // Synchronize the RX PLL lock indicator
  wire plllock_rx_sync;
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_plllock_rx_inst (
    .clk_in (gtwiz_reset_clk_freerun_in),
    .i_in   (plllock_rx_in),
    .o_out  (plllock_rx_sync)
  );

  // Synchronize the RX CDR lock indicator
  wire rxcdrlock_sync;
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_rxcdrlock_inst (
    .clk_in (gtwiz_reset_clk_freerun_in),
    .i_in   (rxcdrlock_in),
    .o_out  (rxcdrlock_sync)
  );

  // Declare the RX state machine reset timer registers
  reg       sm_reset_rx_timer_clr = 1'b1;
  reg [2:0] sm_reset_rx_timer_ctr = 3'd0;
  reg       sm_reset_rx_timer_sat = 1'b0;

  // Declare the RX state machine PLL reset timer registers
  localparam [9:0] P_RX_PLL_RESET_FREERUN_CYC = (P_RX_PLL_TYPE) ?
                                                (2 * P_FREERUN_FREQUENCY) + 2 : 7;
  reg        sm_reset_rx_pll_timer_clr = 1'b1;
  reg  [9:0] sm_reset_rx_pll_timer_ctr = 10'd0;
  reg        sm_reset_rx_pll_timer_sat = 1'b0;
  wire [9:0] p_rx_pll_reset_freerun_cyc_int = P_RX_PLL_RESET_FREERUN_CYC;

  // Declare the RX state machine CDR lock timeout counter
  reg         sm_reset_rx_cdr_to_clr = 1'b1;
  reg  [25:0] sm_reset_rx_cdr_to_ctr = 26'd0;
  reg         sm_reset_rx_cdr_to_sat = 1'b0;
  wire [25:0] p_cdr_timeout_freerun_cyc_int = P_CDR_TIMEOUT_FREERUN_CYC;

  // Declare local parameters for RX reset state machine state values
  localparam [2:0] ST_RESET_RX_BRANCH         = 3'd0;
  localparam [2:0] ST_RESET_RX_PLL            = 3'd1;
  localparam [2:0] ST_RESET_RX_DATAPATH       = 3'd2;
  localparam [2:0] ST_RESET_RX_WAIT_LOCK      = 3'd3;
  localparam [2:0] ST_RESET_RX_WAIT_CDR       = 3'd4;
  localparam [2:0] ST_RESET_RX_WAIT_USERRDY   = 3'd5;
  localparam [2:0] ST_RESET_RX_WAIT_RESETDONE = 3'd6;
  localparam [2:0] ST_RESET_RX_IDLE           = 3'd7;
  reg        [2:0] sm_reset_rx                = ST_RESET_RX_BRANCH;

  // Implementation of receiver reset state machine synchronous process
  always @(posedge gtwiz_reset_clk_freerun_in) begin

    // The state machine is synchronously reset by the synchronized OR of all user input and internal RX reset signals
    if (gtwiz_reset_rx_any_sync) begin
      gtwiz_reset_rx_done_int   <= 1'b0;
      sm_reset_rx_timer_clr     <= 1'b1;
      sm_reset_rx_pll_timer_clr <= 1'b1;
      sm_reset_rx_cdr_to_clr    <= 1'b1;
      sm_reset_rx               <= ST_RESET_RX_BRANCH;
    end
    else begin
      case (sm_reset_rx)

        // Once released from reset, branch to the reset control state indicated by the highest-priority synchronized
        // signal (which remains asserted due to its long synchronizer chain)
        ST_RESET_RX_BRANCH: begin
          if (gtwiz_reset_rx_pll_and_datapath_dly)
            sm_reset_rx <= ST_RESET_RX_PLL;
          else if (gtwiz_reset_rx_datapath_dly)
            sm_reset_rx <= ST_RESET_RX_DATAPATH;
          sm_reset_rx_timer_clr     <= 1'b1;
          sm_reset_rx_pll_timer_clr <= 1'b1;
          sm_reset_rx_cdr_to_clr    <= 1'b1;
        end

        // Assert the RX PLL, RX programmable divider, and RX data path reset outputs
        ST_RESET_RX_PLL: begin
          pllreset_rx_out           <= 1'b1;
          rxprogdivreset_out        <= 1'b1;
          gtrxreset_out             <= 1'b1;
          rxuserrdy_out             <= 1'b0;
          sm_reset_rx_pll_timer_clr <= 1'b0;
          if ((~sm_reset_rx_pll_timer_clr) && sm_reset_rx_pll_timer_sat) begin
            sm_reset_rx_pll_timer_clr <= 1'b1;
            sm_reset_rx               <= ST_RESET_RX_WAIT_LOCK;
          end
        end

        // Assert the RX data path and RX programmable divider reset outputs
        ST_RESET_RX_DATAPATH: begin
          rxprogdivreset_out    <= 1'b1;
          gtrxreset_out         <= 1'b1;
          rxuserrdy_out         <= 1'b0;
          sm_reset_rx_timer_clr <= 1'b0;
          if ((~sm_reset_rx_timer_clr) && sm_reset_rx_timer_sat) begin
            sm_reset_rx_timer_clr <= 1'b1;
            sm_reset_rx           <= ST_RESET_RX_WAIT_LOCK;
          end
        end

        // De-assert the RX PLL reset output, and await the RX PLL lock indicator before de-asserting the RX data path
        // reset output
        ST_RESET_RX_WAIT_LOCK: begin
          pllreset_rx_out       <= 1'b0;
          sm_reset_rx_timer_clr <= 1'b0;
          if (plllock_rx_sync && (~sm_reset_rx_timer_clr) && sm_reset_rx_timer_sat) begin
            gtrxreset_out          <= 1'b0;
            sm_reset_rx_timer_clr  <= 1'b1;
            sm_reset_rx_cdr_to_clr <= 1'b0;
            sm_reset_rx            <= ST_RESET_RX_WAIT_CDR;
          end
        end

        // Await an indication of CDR stability (either the direct transceiver RXCDRLOCK output, or expiration of the
        // specified maximum CDR locking time, whichever occurs first) before removing the RX programmable divider reset
        // and proceeding
        ST_RESET_RX_WAIT_CDR: begin
          if (rxcdrlock_sync || sm_reset_rx_cdr_to_sat) begin
            rxprogdivreset_out     <= 1'b0;
            sm_reset_rx_cdr_to_clr <= 1'b1;
            sm_reset_rx            <= ST_RESET_RX_WAIT_USERRDY;
          end
        end

        // Await the RX user clock active indicator from the RX user clocking helper block before asserting the RX user
        // ready output
        ST_RESET_RX_WAIT_USERRDY: begin
          sm_reset_rx_timer_clr <= 1'b0;
          if (gtwiz_reset_userclk_rx_active_sync && (~sm_reset_rx_timer_clr) && sm_reset_rx_timer_sat) begin
            rxuserrdy_out         <= 1'b1;
            sm_reset_rx_timer_clr <= 1'b1;
            sm_reset_rx           <= ST_RESET_RX_WAIT_RESETDONE;
          end
        end

        // Await the RX reset done indicator before asserting the reset helper block RX reset done user output
        ST_RESET_RX_WAIT_RESETDONE: begin
          sm_reset_rx_timer_clr <= 1'b0;
          if (rxresetdone_in && (~sm_reset_rx_timer_clr) && sm_reset_rx_timer_sat)
          begin
            gtwiz_reset_rx_done_int <= 1'b1;
            sm_reset_rx_timer_clr   <= 1'b1;
            sm_reset_rx             <= ST_RESET_RX_IDLE;
          end
        end

        // While idle, de-assert the reset helper block RX reset done user output if PLL lock is lost, signaling the
        // need for user intervention
        ST_RESET_RX_IDLE: begin
          if (!plllock_rx_sync)
            gtwiz_reset_rx_done_int <= 1'b0;
        end

      endcase
    end
  end

  // Generate a small RX state machine reset timer, used to stall certain states to guarantee that their synchronized
  // input values are being used at the appropriate time
  always @(posedge gtwiz_reset_clk_freerun_in) begin
    if (sm_reset_rx_timer_clr) begin
      sm_reset_rx_timer_ctr <= 3'd0;
      sm_reset_rx_timer_sat <= 1'b0;
    end
    else begin
      if (sm_reset_rx_timer_ctr != 3'd7)
        sm_reset_rx_timer_ctr <= sm_reset_rx_timer_ctr + 3'd1;
      else
        sm_reset_rx_timer_sat <= 1'b1;
    end
  end

  // Generate an RX PLL reset timer, used to indicate when the specified minimum RX PLL reset duration has expired. This
  // is used by the RX state machine to proceed beyond the ST_RESET_RX_PLL wait state.
  always @(posedge gtwiz_reset_clk_freerun_in) begin
    if (sm_reset_rx_pll_timer_clr) begin
      sm_reset_rx_pll_timer_ctr <= 10'd0;
      sm_reset_rx_pll_timer_sat <= 1'b0;
    end
    else begin
      if (sm_reset_rx_pll_timer_ctr != p_rx_pll_reset_freerun_cyc_int)
        sm_reset_rx_pll_timer_ctr <= sm_reset_rx_pll_timer_ctr + 10'd1;
      else
        sm_reset_rx_pll_timer_sat <= 1'b1;
    end
  end

  // Generate a CDR lock timeout timer, used to indicate when the specified maximum CDR locking time has expired. This
  // is used by the RX state machine to proceed beyond the ST_RESET_RX_WAIT_CDR wait state in the event that the
  // transceiver RXCDRLOCK output does not assert within that time period.
  always @(posedge gtwiz_reset_clk_freerun_in) begin
    if (sm_reset_rx_cdr_to_clr) begin
      sm_reset_rx_cdr_to_ctr <= 26'd0;
      sm_reset_rx_cdr_to_sat <= 1'b0;
    end
    else begin
      if (sm_reset_rx_cdr_to_ctr != p_cdr_timeout_freerun_cyc_int)
        sm_reset_rx_cdr_to_ctr <= sm_reset_rx_cdr_to_ctr + 26'd1;
      else
        sm_reset_rx_cdr_to_sat <= 1'b1;
    end
  end

  // Assign the RX CDR stable user indicator to the transceiver RXCDRLOCK output
  assign gtwiz_reset_rx_cdr_stable_out = rxcdrlock_sync;

  // Synchronize the reset helper block RX reset done user output into the RXUSRCLK2 domain for user consumption
  c2c_mgt_reset_inv_synchronizer reset_synchronizer_rx_done_inst (
    .clk_in  (rxusrclk2_in),
    .rst_in  (gtwiz_reset_rx_done_int),
    .rst_out (gtwiz_reset_rx_done_out)
  );


endmodule

module c2c_mgt_gtwiz_userclk_rx #(

  parameter integer P_CONTENTS                     = 0,
  parameter integer P_FREQ_RATIO_SOURCE_TO_USRCLK  = 1,
  parameter integer P_FREQ_RATIO_USRCLK_TO_USRCLK2 = 1

)(

  input  wire gtwiz_userclk_rx_srcclk_in,
  input  wire gtwiz_userclk_rx_reset_in,
  output wire gtwiz_userclk_rx_usrclk_out,
  output wire gtwiz_userclk_rx_usrclk2_out,
  output wire gtwiz_userclk_rx_active_out

);


  // -------------------------------------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------------------------------------

  // Convert integer parameters with known, limited legal range to a 3-bit local parameter values
  localparam integer P_USRCLK_INT_DIV  = P_FREQ_RATIO_SOURCE_TO_USRCLK - 1;
  localparam   [2:0] P_USRCLK_DIV      = P_USRCLK_INT_DIV[2:0];
  localparam integer P_USRCLK2_INT_DIV = (P_FREQ_RATIO_SOURCE_TO_USRCLK * P_FREQ_RATIO_USRCLK_TO_USRCLK2) - 1;
  localparam   [2:0] P_USRCLK2_DIV     = P_USRCLK2_INT_DIV[2:0];


  // -------------------------------------------------------------------------------------------------------------------
  // Receiver user clocking network conditional generation, based on parameter values in module instantiation
  // -------------------------------------------------------------------------------------------------------------------
  generate if (1) begin: gen_gtwiz_userclk_rx_main

    // Use BUFG_GT instance(s) to drive RXUSRCLK and RXUSRCLK2, inferred for integral source to RXUSRCLK frequency ratio
    if (P_CONTENTS == 0) begin

      // Drive RXUSRCLK with BUFG_GT-buffered source clock, dividing the input by the integral source clock to RXUSRCLK
      // frequency ratio
      BUFG_GT bufg_gt_usrclk_inst (
        .CE      (1'b1),
        .CEMASK  (1'b0),
        .CLR     (gtwiz_userclk_rx_reset_in),
        .CLRMASK (1'b0),
        .DIV     (P_USRCLK_DIV),
        .I       (gtwiz_userclk_rx_srcclk_in),
        .O       (gtwiz_userclk_rx_usrclk_out)
      );

      // If RXUSRCLK and RXUSRCLK2 frequencies are identical, drive both from the same BUFG_GT. Otherwise, drive
      // RXUSRCLK2 from a second BUFG_GT instance, dividing the source clock down to the RXUSRCLK2 frequency.
      if (P_FREQ_RATIO_USRCLK_TO_USRCLK2 == 1)
        assign gtwiz_userclk_rx_usrclk2_out = gtwiz_userclk_rx_usrclk_out;
      else begin
        BUFG_GT bufg_gt_usrclk2_inst (
          .CE      (1'b1),
          .CEMASK  (1'b0),
          .CLR     (gtwiz_userclk_rx_reset_in),
          .CLRMASK (1'b0),
          .DIV     (P_USRCLK2_DIV),
          .I       (gtwiz_userclk_rx_srcclk_in),
          .O       (gtwiz_userclk_rx_usrclk2_out)
        );
      end

      // Indicate active helper block functionality when the BUFG_GT divider is not held in reset
      (* ASYNC_REG = "TRUE" *) reg gtwiz_userclk_rx_active_meta = 1'b0;
      (* ASYNC_REG = "TRUE" *) reg gtwiz_userclk_rx_active_sync = 1'b0;
      always @(posedge gtwiz_userclk_rx_usrclk2_out, posedge gtwiz_userclk_rx_reset_in) begin
        if (gtwiz_userclk_rx_reset_in) begin
          gtwiz_userclk_rx_active_meta <= 1'b0;
          gtwiz_userclk_rx_active_sync <= 1'b0;
        end
        else begin
          gtwiz_userclk_rx_active_meta <= 1'b1;
          gtwiz_userclk_rx_active_sync <= gtwiz_userclk_rx_active_meta;
        end
      end
      assign gtwiz_userclk_rx_active_out = gtwiz_userclk_rx_active_sync;

    end

  end
  endgenerate


endmodule

module c2c_mgt_gtwiz_userclk_tx #(

  parameter integer P_CONTENTS                     = 0,
  parameter integer P_FREQ_RATIO_SOURCE_TO_USRCLK  = 1,
  parameter integer P_FREQ_RATIO_USRCLK_TO_USRCLK2 = 1

)(

  input  wire gtwiz_userclk_tx_srcclk_in,
  input  wire gtwiz_userclk_tx_reset_in,
  output wire gtwiz_userclk_tx_usrclk_out,
  output wire gtwiz_userclk_tx_usrclk2_out,
  output wire gtwiz_userclk_tx_active_out

);


  // -------------------------------------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------------------------------------

  // Convert integer parameters with known, limited legal range to a 3-bit local parameter values
  localparam integer P_USRCLK_INT_DIV  = P_FREQ_RATIO_SOURCE_TO_USRCLK - 1;
  localparam   [2:0] P_USRCLK_DIV      = P_USRCLK_INT_DIV[2:0];
  localparam integer P_USRCLK2_INT_DIV = (P_FREQ_RATIO_SOURCE_TO_USRCLK * P_FREQ_RATIO_USRCLK_TO_USRCLK2) - 1;
  localparam   [2:0] P_USRCLK2_DIV     = P_USRCLK2_INT_DIV[2:0];


  // -------------------------------------------------------------------------------------------------------------------
  // Transmitter user clocking network conditional generation, based on parameter values in module instantiation
  // -------------------------------------------------------------------------------------------------------------------
  generate if (1) begin: gen_gtwiz_userclk_tx_main

    // Use BUFG_GT instance(s) to drive TXUSRCLK and TXUSRCLK2, inferred for integral source to TXUSRCLK frequency ratio
    if (P_CONTENTS == 0) begin

      // Drive TXUSRCLK with BUFG_GT-buffered source clock, dividing the input by the integral source clock to TXUSRCLK
      // frequency ratio
      BUFG_GT bufg_gt_usrclk_inst (
        .CE      (1'b1),
        .CEMASK  (1'b0),
        .CLR     (gtwiz_userclk_tx_reset_in),
        .CLRMASK (1'b0),
        .DIV     (P_USRCLK_DIV),
        .I       (gtwiz_userclk_tx_srcclk_in),
        .O       (gtwiz_userclk_tx_usrclk_out)
      );

      // If TXUSRCLK and TXUSRCLK2 frequencies are identical, drive both from the same BUFG_GT. Otherwise, drive
      // TXUSRCLK2 from a second BUFG_GT instance, dividing the source clock down to the TXUSRCLK2 frequency.
      if (P_FREQ_RATIO_USRCLK_TO_USRCLK2 == 1)
        assign gtwiz_userclk_tx_usrclk2_out = gtwiz_userclk_tx_usrclk_out;
      else begin
        BUFG_GT bufg_gt_usrclk2_inst (
          .CE      (1'b1),
          .CEMASK  (1'b0),
          .CLR     (gtwiz_userclk_tx_reset_in),
          .CLRMASK (1'b0),
          .DIV     (P_USRCLK2_DIV),
          .I       (gtwiz_userclk_tx_srcclk_in),
          .O       (gtwiz_userclk_tx_usrclk2_out)
        );
      end

      // Indicate active helper block functionality when the BUFG_GT divider is not held in reset
      (* ASYNC_REG = "TRUE" *) reg gtwiz_userclk_tx_active_meta = 1'b0;
      (* ASYNC_REG = "TRUE" *) reg gtwiz_userclk_tx_active_sync = 1'b0;
      always @(posedge gtwiz_userclk_tx_usrclk2_out, posedge gtwiz_userclk_tx_reset_in) begin
        if (gtwiz_userclk_tx_reset_in) begin
          gtwiz_userclk_tx_active_meta <= 1'b0;
          gtwiz_userclk_tx_active_sync <= 1'b0;
        end
        else begin
          gtwiz_userclk_tx_active_meta <= 1'b1;
          gtwiz_userclk_tx_active_sync <= gtwiz_userclk_tx_active_meta;
        end
      end
      assign gtwiz_userclk_tx_active_out = gtwiz_userclk_tx_active_sync;

    end

  end
  endgenerate


endmodule

module c2c_mgt_init # (

  parameter real   P_FREERUN_FREQUENCY    = 39.0625,
  parameter real   P_TX_TIMER_DURATION_US = 30000,
  parameter real   P_RX_TIMER_DURATION_US = 130000

)(

  input  wire      clk_freerun_in,
  input  wire      reset_all_in,
  input  wire      tx_init_done_in,
  input  wire      rx_init_done_in,
  input  wire      rx_data_good_in,
  output reg       reset_all_out = 1'b0,
  output reg       reset_rx_out  = 1'b0,
  output reg       init_done_out = 1'b0,
  output reg [3:0] retry_ctr_out = 4'd0

);


  // -------------------------------------------------------------------------------------------------------------------
  // Synchronizers
  // -------------------------------------------------------------------------------------------------------------------

  // Synchronize the "reset all" input signal into the free-running clock domain
  // The reset_all_in input should be driven by the master "reset all" example design input
  wire reset_all_sync;
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_reset_synchronizer reset_synchronizer_reset_all_inst (
    .clk_in  (clk_freerun_in),
    .rst_in  (reset_all_in),
    .rst_out (reset_all_sync)
  );

  // Synchronize the TX initialization done indicator into the free-running clock domain
  // The tx_init_done_in input should be driven by the signal or logical combination of signals that represents a
  // completed TX initialization process; for example, the reset helper block gtwiz_reset_tx_done_out signal, or the
  // logical AND of gtwiz_reset_tx_done_out with gtwiz_buffbypass_tx_done_out if the TX buffer is bypassed.
  wire tx_init_done_sync;
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_tx_init_done_inst (
    .clk_in (clk_freerun_in),
    .i_in   (tx_init_done_in),
    .o_out  (tx_init_done_sync)
  );

  // Synchronize the RX initialization done indicator into the free-running clock domain
  // The rx_init_done_in input should be driven by the signal or logical combination of signals that represents a
  // completed RX initialization process; for example, the reset helper block gtwiz_reset_rx_done_out signal, or the
  // logical AND of gtwiz_reset_rx_done_out with gtwiz_buffbypass_rx_done_out if the RX elastic buffer is bypassed.
  wire rx_init_done_sync;
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_rx_init_done_inst (
    .clk_in (clk_freerun_in),
    .i_in   (rx_init_done_in),
    .o_out  (rx_init_done_sync)
  );

  // Synchronize the RX data good indicator into the free-running clock domain
  // The rx_data_good_in input should be driven the user application's indication of continual good data reception.
  // The example design drives rx_data_good_in high when no PRBS checker errors are seen in the 8 most recent
  // consecutive clock cycles of data reception.
  wire rx_data_good_sync;
  (* DONT_TOUCH = "TRUE" *)
  c2c_mgt_bit_synchronizer bit_synchronizer_rx_data_good_inst (
    .clk_in (clk_freerun_in),
    .i_in   (rx_data_good_in),
    .o_out  (rx_data_good_sync)
  );


  // -------------------------------------------------------------------------------------------------------------------
  // Timer
  // -------------------------------------------------------------------------------------------------------------------

  // Declare registers and local parameters used for the shared TX and RX initialization timer
  // The free-running clock frequency is specified by the P_FREERUN_FREQUENCY parameter. The TX initialization timer
  // duration is specified by the P_TX_TIMER_DURATION_US parameter (default 30,000us), and the resulting terminal count
  // is assigned to p_tx_timer_term_cyc_int. The RX initialization timer duration is specified by the
  // P_RX_TIMER_DURATION_US parameter (default 130,000us), and the resulting terminal count is assigned to
  // p_rx_timer_term_cyc_int.
  reg         timer_clr = 1'b1;
  reg  [24:0] timer_ctr = 25'd0;
  reg         tx_timer_sat = 1'b0;
  reg         rx_timer_sat = 1'b0;
  wire [24:0] p_tx_timer_term_cyc_int = P_TX_TIMER_DURATION_US * P_FREERUN_FREQUENCY;
  wire [24:0] p_rx_timer_term_cyc_int = P_RX_TIMER_DURATION_US * P_FREERUN_FREQUENCY;

  // When the timer is enabled by the initialization state machine, increment the timer_ctr counter until its value
  // reaches p_rx_timer_term_cyc_int RX terminal count and rx_timer_sat is asserted. Assert tx_timer_sat when the
  // counter value reaches the p_tx_timer_term_cyc_int TX terminal count. Clear the timer and remove assertions when the
  // timer is disabled by the initialization state machine.
  always @(posedge clk_freerun_in) begin
    if (timer_clr) begin
      timer_ctr    <= 25'd0;
      tx_timer_sat <= 1'b0;
      rx_timer_sat <= 1'b0;
    end
    else begin
      if (timer_ctr == p_tx_timer_term_cyc_int)
        tx_timer_sat <= 1'b1;

      if (timer_ctr == p_rx_timer_term_cyc_int)
        rx_timer_sat <= 1'b1;
      else
        timer_ctr <= timer_ctr + 25'd1;
    end
  end


  // -------------------------------------------------------------------------------------------------------------------
  // Retry counter
  // -------------------------------------------------------------------------------------------------------------------

  // Increment the retry_ctr_out register for each TX or RX reset asserted by the initialization state machine until the
  // register saturates at 4'd15. This value, which is initialized on device programming and is never reset, could be
  // useful for debugging purposes. The initialization state machine will continue to retry as needed beyond the retry
  // register saturation point indicated, so 4'd15 should be interpreted as "15 or more attempts since programming."
  reg retry_ctr_incr = 1'b0;

  always @(posedge clk_freerun_in) begin
    if ((retry_ctr_incr == 1'b1) && (retry_ctr_out != 4'd15))
      retry_ctr_out <= retry_ctr_out + 4'd1;
  end


  // -------------------------------------------------------------------------------------------------------------------
  // Initialization state machine
  // -------------------------------------------------------------------------------------------------------------------

  // Declare local parameters and state register for the initialization state machine
  localparam [1:0] ST_START       = 2'd0;
  localparam [1:0] ST_TX_WAIT     = 2'd1;
  localparam [1:0] ST_RX_WAIT     = 2'd2;
  localparam [1:0] ST_MONITOR     = 2'd3;
  reg        [1:0] sm_init        = ST_START;
  reg              sm_init_active = 1'b0;

  // Implement the initialization state machine control and its outputs as a single sequential process. The state
  // machine is reset by the synchronized reset_all_in input, and does not begin operating until its first use. Note
  // that this state machine is designed to interact with and enhance the reset controller helper block.
  always @(posedge clk_freerun_in) begin
    if (reset_all_sync) begin
      timer_clr      <= 1'b1;
      reset_all_out  <= 1'b0;
      reset_rx_out   <= 1'b0;
      retry_ctr_incr <= 1'b0;
      init_done_out  <= 1'b0;
      sm_init_active <= 1'b1;
      sm_init        <= ST_START;
    end
    else begin
      case (sm_init)

        // When starting the initialization procedure, clear the timer and remove reset outputs, then proceed to wait
        // for completion of TX initialization
        ST_START: begin
          if (sm_init_active) begin
            timer_clr      <= 1'b1;
            reset_all_out  <= 1'b0;
            reset_rx_out   <= 1'b0;
            retry_ctr_incr <= 1'b0;
            sm_init        <= ST_TX_WAIT;
          end
        end

        // Enable the timer. If TX initialization completes before the counter's TX terminal count, clear the timer and
        // proceed to wait for RX initialization. If the TX terminal count is reached, clear the timer, assert the
        // reset_all_out output (which in this example causes a master reset_all assertion), and increment the retry
        // counter. Completion conditions for TX initialization are described above.
        ST_TX_WAIT: begin
          if (tx_init_done_sync) begin
            timer_clr <= 1'b1;
            sm_init   <= ST_RX_WAIT;
          end
          else begin
            if (tx_timer_sat) begin
              timer_clr      <= 1'b1;
              reset_all_out  <= 1'b1;
              retry_ctr_incr <= 1'b1;
              sm_init        <= ST_START;
            end
            else begin
              timer_clr <= 1'b0;
            end
          end
        end

        // Enable the timer. When the RX terminal count is reached, check whether RX initialization has completed and
        // whether the data good indicator is high. If both conditions are met, transition to the MONITOR state. If
        // either condition is not met, then clear the timer, assert the reset_rx_out output (which in this example
        // either drives gtwiz_reset_rx_pll_and_datapath_in or gtwiz_reset_rx_datapath_in, depending on PLL sharing),
        // and increnent the retry counter.
        ST_RX_WAIT: begin
          if (rx_timer_sat) begin
            if (rx_init_done_sync && rx_data_good_sync) begin
              init_done_out <= 1'b1;
              sm_init       <= ST_MONITOR;
            end
            else begin
              timer_clr      <= 1'b1;
              reset_rx_out   <= 1'b1;
              retry_ctr_incr <= 1'b1;
              sm_init        <= ST_START;
            end
          end
          else begin
            timer_clr <= 1'b0;
          end
        end

        // In this MONITOR state, assert the init_done_out output for use as desired. If RX initialization or the data
        // good indicator is lost while in this state, reset the RX components as described in the ST_RX_WAIT state.
        ST_MONITOR: begin
          if (~rx_init_done_sync || ~rx_data_good_sync) begin
            init_done_out  <= 1'b0;
            timer_clr      <= 1'b1;
            reset_rx_out   <= 1'b1;
            retry_ctr_incr <= 1'b1;
            sm_init        <= ST_START;
          end
        end

      endcase
    end
  end


endmodule

module c2c_mgt_reset_inv_synchronizer # (

  parameter FREQUENCY = 512

)(

  input  wire clk_in,
  input  wire rst_in,
  output wire rst_out

);

  // Use 5 flip-flops as a single synchronizer, and tag each declaration with the appropriate synthesis attribute to
  // enable clustering. Each flip-flop in the synchronizer is asynchronously reset so that the downstream logic is also
  // asynchronously reset but encounters no reset assertion latency. The removal of reset is synchronous, so that the
  // downstream logic is also removed from reset synchronously. This module is designed for active-low reset use.

  (* ASYNC_REG = "TRUE" *) reg rst_in_meta  = 1'b0;
  (* ASYNC_REG = "TRUE" *) reg rst_in_sync1 = 1'b0;
  (* ASYNC_REG = "TRUE" *) reg rst_in_sync2 = 1'b0;
  (* ASYNC_REG = "TRUE" *) reg rst_in_sync3 = 1'b0;
                           reg rst_in_out   = 1'b0;

  always @(posedge clk_in, negedge rst_in) begin
    if (!rst_in) begin
      rst_in_meta  <= 1'b0;
      rst_in_sync1 <= 1'b0;
      rst_in_sync2 <= 1'b0;
      rst_in_sync3 <= 1'b0;
      rst_in_out   <= 1'b0;
    end
    else begin
      rst_in_meta  <= 1'b1;
      rst_in_sync1 <= rst_in_meta;
      rst_in_sync2 <= rst_in_sync1;
      rst_in_sync3 <= rst_in_sync2;
      rst_in_out   <= rst_in_sync3;
    end
  end

  assign rst_out = rst_in_out;


endmodule

module c2c_mgt_reset_synchronizer # (

  parameter FREQUENCY = 512

)(

  input  wire clk_in,
  input  wire rst_in,
  output wire rst_out

);

  // Use 5 flip-flops as a single synchronizer, and tag each declaration with the appropriate synthesis attribute to
  // enable clustering. Each flip-flop in the synchronizer is asynchronously reset so that the downstream logic is also
  // asynchronously reset but encounters no reset assertion latency. The removal of reset is synchronous, so that the
  // downstream logic is also removed from reset synchronously. This module is designed for active-high reset use.

  (* ASYNC_REG = "TRUE" *) reg rst_in_meta  = 1'b0;
  (* ASYNC_REG = "TRUE" *) reg rst_in_sync1 = 1'b0;
  (* ASYNC_REG = "TRUE" *) reg rst_in_sync2 = 1'b0;
  (* ASYNC_REG = "TRUE" *) reg rst_in_sync3 = 1'b0;
                           reg rst_in_out   = 1'b0;

  always @(posedge clk_in, posedge rst_in) begin
    if (rst_in) begin
      rst_in_meta  <= 1'b1;
      rst_in_sync1 <= 1'b1;
      rst_in_sync2 <= 1'b1;
      rst_in_sync3 <= 1'b1;
      rst_in_out   <= 1'b1;
    end
    else begin
      rst_in_meta  <= 1'b0;
      rst_in_sync1 <= rst_in_meta;
      rst_in_sync2 <= rst_in_sync1;
      rst_in_sync3 <= rst_in_sync2;
      rst_in_out   <= rst_in_sync3;
    end
  end

  assign rst_out = rst_in_out;


endmodule


module c2c_mgt_wrapper (
  input  wire [1:0] gtyrxn_in
 ,input  wire [1:0] gtyrxp_in
 ,output wire [1:0] gtytxn_out
 ,output wire [1:0] gtytxp_out
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
 ,input  wire [1:0] rxbufreset_in
 ,input  wire [1:0] rxcommadeten_in
 ,input  wire [1:0] rxlpmen_in
 ,input  wire [1:0] rxmcommaalignen_in
 ,input  wire [1:0] rxpcommaalignen_in
 ,input  wire [1:0] rxpolarity_in
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
 ,output wire [5:0] rxbufstatus_out
 ,output wire [1:0] rxbyteisaligned_out
 ,output wire [1:0] rxbyterealign_out
 ,output wire [3:0] rxclkcorcnt_out
 ,output wire [1:0] rxcommadet_out
 ,output wire [31:0] rxctrl0_out
 ,output wire [31:0] rxctrl1_out
 ,output wire [15:0] rxctrl2_out
 ,output wire [15:0] rxctrl3_out
 ,output wire [1:0] rxpmaresetdone_out
 ,output wire [1:0] rxprbserr_out
 ,output wire [1:0] txpmaresetdone_out
);


  // ===================================================================================================================
  // PARAMETERS AND FUNCTIONS
  // ===================================================================================================================
function integer f_calc_pk_mc_idx (
  input integer idx_mc
);
begin : main_f_calc_pk_mc_idx
  integer i, j;
  integer tmp;
  j = 0;
  for (i = 0; i < 192; i = i + 1) begin
    if (P_CHANNEL_ENABLE[i] == 1'b1) begin
      if (i == idx_mc)
        tmp = j;
      else
        j = j + 1;
    end
  end
  f_calc_pk_mc_idx = tmp;
end
endfunction
   
  // Declare and initialize local parameters and functions used for HDL generation
  localparam [191:0] P_CHANNEL_ENABLE = 192'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000100000000;
//  `include "c2c_mgt_wrapper_functions.v"
//  localparam integer P_TX_MASTER_CH_PACKED_IDX = f_calc_pk_mc_idx(0);
//  localparam integer P_RX_MASTER_CH_PACKED_IDX = f_calc_pk_mc_idx(0);
  localparam integer P_TX_MASTER_CH_PACKED_IDX = f_calc_pk_mc_idx(14);
  localparam integer P_RX_MASTER_CH_PACKED_IDX = f_calc_pk_mc_idx(8);

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
  c2c_mgt_gtwiz_userclk_tx gtwiz_userclk_tx_inst (
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
  c2c_mgt_gtwiz_userclk_rx gtwiz_userclk_rx_inst (
    .gtwiz_userclk_rx_srcclk_in   (gtwiz_userclk_rx_srcclk_out),
    .gtwiz_userclk_rx_reset_in    (gtwiz_userclk_rx_reset_in),
    .gtwiz_userclk_rx_usrclk_out  (gtwiz_userclk_rx_usrclk_out),
    .gtwiz_userclk_rx_usrclk2_out (gtwiz_userclk_rx_usrclk2_out),
    .gtwiz_userclk_rx_active_out  (gtwiz_userclk_rx_active_out)
  );

  // Drive RXUSRCLK and RXUSRCLK2 for all channels with the respective helper block outputs
  assign rxusrclk_int  = {2{gtwiz_userclk_tx_usrclk_out}};
  assign rxusrclk2_int = {2{gtwiz_userclk_tx_usrclk2_out}};
//  assign rxusrclk_int  = {2{gtwiz_userclk_rx_usrclk_out}};
//  assign rxusrclk2_int = {2{gtwiz_userclk_rx_usrclk2_out}};

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
    c2c_mgt_bit_synchronizer bit_synchronizer_txresetdone_inst (
      .clk_in (gtwiz_reset_clk_freerun_in),
      .i_in   (txresetdone_int[gi_ch_xrd]),
      .o_out  (txresetdone_sync[gi_ch_xrd])
    );
    (* DONT_TOUCH = "TRUE" *)
    c2c_mgt_bit_synchronizer bit_synchronizer_rxresetdone_inst (
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
  c2c_mgt_gtwiz_reset gtwiz_reset_inst (
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
  c2c_mgt c2c_mgt_inst (
    .gtyrxn_in                               (gtyrxn_in)
   ,.gtyrxp_in                               (gtyrxp_in)
   ,.gtytxn_out                              (gtytxn_out)
   ,.gtytxp_out                              (gtytxp_out)
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
   ,.rxbufreset_in                           (rxbufreset_in)
   ,.rxcommadeten_in                         (rxcommadeten_in)
   ,.rxlpmen_in                              (rxlpmen_in)
   ,.rxmcommaalignen_in                      (rxmcommaalignen_in)
   ,.rxpcommaalignen_in                      (rxpcommaalignen_in)
   ,.rxpolarity_in                           (rxpolarity_in)
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
   ,.rxbufstatus_out                         (rxbufstatus_out)
   ,.rxbyteisaligned_out                     (rxbyteisaligned_out)
   ,.rxbyterealign_out                       (rxbyterealign_out)
   ,.rxcdrlock_out                           (rxcdrlock_int)
   ,.rxclkcorcnt_out                         (rxclkcorcnt_out)
   ,.rxcommadet_out                          (rxcommadet_out)
   ,.rxctrl0_out                             (rxctrl0_int)
   ,.rxctrl1_out                             (rxctrl1_int)
   ,.rxctrl2_out                             (rxctrl2_out)
   ,.rxctrl3_out                             (rxctrl3_out)
   ,.rxoutclk_out                            (rxoutclk_int)
   ,.rxpmaresetdone_out                      (rxpmaresetdone_out)
   ,.rxprbserr_out                           (rxprbserr_out)
   ,.rxresetdone_out                         (rxresetdone_int)
   ,.txoutclk_out                            (txoutclk_int)
   ,.txpmaresetdone_out                      (txpmaresetdone_out)
   ,.txresetdone_out                         (txresetdone_int)
);

endmodule
