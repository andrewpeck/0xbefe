library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

use work.gth_pkg.all;

use work.ctp7_utils_pkg.all;
use work.ttc_pkg.all;
use work.system_package.all;
use work.gem_pkg.all;

--============================================================================
entity daqlink_wrapper is
    port(
        daq_to_daqlink : in  t_daq_to_daqlink;
        daqlink_to_daq : out t_daqlink_to_daq;
        
        clk_50_i       : in  std_logic;
        
        GTX_REFCLK_p   : in  std_logic;
        GTX_REFCLK_n   : in  std_logic;
        GTX_RXN        : in  std_logic;
        GTX_RXP        : in  std_logic;
        GTX_TXN        : out std_logic;
        GTX_TXP        : out std_logic
    );
end daqlink_wrapper;

architecture daqlink_wrapper_arch of daqlink_wrapper is
    component gth_amc13_support
        generic(
            -- Simulation attributes
            EXAMPLE_SIM_GTRESET_SPEEDUP : string  := "FALSE"; -- Set to TRUE to speed up sim reset
            STABLE_CLOCK_PERIOD         : integer := 20
        );
        port(
            SOFT_RESET_IN               : in  std_logic;
            drp_clk_i                   : in  std_logic;
            DONT_RESET_ON_DATA_ERROR_IN : in  std_logic;
            Q2_CLK0_GTREFCLK_PAD_N_IN   : in  std_logic;
            Q2_CLK0_GTREFCLK_PAD_P_IN   : in  std_logic;
            GT0_TX_FSM_RESET_DONE_OUT   : out std_logic;
            GT0_RX_FSM_RESET_DONE_OUT   : out std_logic;
            GT0_DATA_VALID_IN           : in  std_logic;
            GT0_TXUSRCLK_OUT            : out std_logic;
            GT0_TXUSRCLK2_OUT           : out std_logic;
            GT0_RXUSRCLK_OUT            : out std_logic;
            GT0_RXUSRCLK2_OUT           : out std_logic;
            --_________________________________________________________________________
            --_________________________________________________________________________
            --GT0  (X0Y9)
            --____________________________CHANNEL PORTS________________________________
            --------------------------------- CPLL Ports -------------------------------
            gt0_cpllfbclklost_out       : out std_logic;
            gt0_cplllock_out            : out std_logic;
            gt0_cpllreset_in            : in  std_logic;
            ---------------------------- Channel - DRP Ports  --------------------------
            gt0_drpaddr_in              : in  std_logic_vector(8 downto 0);
            gt0_drpdi_in                : in  std_logic_vector(15 downto 0);
            gt0_drpdo_out               : out std_logic_vector(15 downto 0);
            gt0_drpen_in                : in  std_logic;
            gt0_drprdy_out              : out std_logic;
            gt0_drpwe_in                : in  std_logic;
            --------------------- RX Initialization and Reset Ports --------------------
            gt0_eyescanreset_in         : in  std_logic;
            gt0_rxuserrdy_in            : in  std_logic;
            -------------------------- RX Margin Analysis Ports ------------------------
            gt0_eyescandataerror_out    : out std_logic;
            gt0_eyescantrigger_in       : in  std_logic;
            ------------------- Receive Ports - Clock Correction Ports -----------------
            gt0_rxclkcorcnt_out         : out std_logic_vector(1 downto 0);
            ------------------- Receive Ports - Digital Monitor Ports ------------------
            gt0_dmonitorout_out         : out std_logic_vector(14 downto 0);
            ------------------ Receive Ports - FPGA RX interface Ports -----------------
            gt0_rxdata_out              : out std_logic_vector(15 downto 0);
            ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
            gt0_rxdisperr_out           : out std_logic_vector(1 downto 0);
            gt0_rxnotintable_out        : out std_logic_vector(1 downto 0);
            ------------------------ Receive Ports - RX AFE Ports ----------------------
            gt0_gthrxn_in               : in  std_logic;
            -------------- Receive Ports - RX Byte and Word Alignment Ports ------------
            gt0_rxbyteisaligned_out     : out std_logic;
            gt0_rxbyterealign_out       : out std_logic;
            gt0_rxcommadet_out          : out std_logic;
            gt0_rxmcommaalignen_in      : in  std_logic;
            gt0_rxpcommaalignen_in      : in  std_logic;
            --------------------- Receive Ports - RX Equalizer Ports -------------------
            gt0_rxmonitorout_out        : out std_logic_vector(6 downto 0);
            gt0_rxmonitorsel_in         : in  std_logic_vector(1 downto 0);
            ------------- Receive Ports - RX Initialization and Reset Ports ------------
            gt0_gtrxreset_in            : in  std_logic;
            ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
            gt0_rxchariscomma_out       : out std_logic_vector(1 downto 0);
            gt0_rxcharisk_out           : out std_logic_vector(1 downto 0);
            ------------------------ Receive Ports -RX AFE Ports -----------------------
            gt0_gthrxp_in               : in  std_logic;
            -------------- Receive Ports -RX Initialization and Reset Ports ------------
            gt0_rxresetdone_out         : out std_logic;
            --------------------- TX Initialization and Reset Ports --------------------
            gt0_gttxreset_in            : in  std_logic;
            gt0_txuserrdy_in            : in  std_logic;
            ------------------ Transmit Ports - TX Data Path interface -----------------
            gt0_txdata_in               : in  std_logic_vector(15 downto 0);
            ---------------- Transmit Ports - TX Driver and OOB signaling --------------
            gt0_gthtxn_out              : out std_logic;
            gt0_gthtxp_out              : out std_logic;
            ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
            gt0_txoutclkfabric_out      : out std_logic;
            gt0_txoutclkpcs_out         : out std_logic;
            ------------- Transmit Ports - TX Initialization and Reset Ports -----------
            gt0_txresetdone_out         : out std_logic;
            ----------- Transmit Transmit Ports - 8b10b Encoder Control Ports ----------
            gt0_txcharisk_in            : in  std_logic_vector(1 downto 0);
            GT0_DRPADDR_COMMON_IN       : in  std_logic_vector(7 downto 0);
            GT0_DRPDI_COMMON_IN         : in  std_logic_vector(15 downto 0);
            GT0_DRPDO_COMMON_OUT        : out std_logic_vector(15 downto 0);
            GT0_DRPEN_COMMON_IN         : in  std_logic;
            GT0_DRPRDY_COMMON_OUT       : out std_logic;
            GT0_DRPWE_COMMON_IN         : in  std_logic;
            --____________________________COMMON PORTS________________________________
            GT0_QPLLOUTCLK_OUT          : out std_logic;
            GT0_QPLLOUTREFCLK_OUT       : out std_logic;
            DRP_CLK_O                   : out std_logic;
            SYSCLK_IN_P                 : in  std_logic;
            SYSCLK_IN_N                 : in  std_logic
        );
    end component;

    --***********************************Parameter Declarations********************

    constant DLY : time := 1 ns;

    --************************** Register Declarations ****************************
    attribute ASYNC_REG : string;

    signal gt_txfsmresetdone_i  : std_logic;
    signal gt_rxfsmresetdone_i  : std_logic;
    signal gt_txfsmresetdone_r  : std_logic;
    signal gt_txfsmresetdone_r2 : std_logic;
    attribute ASYNC_REG of gt_txfsmresetdone_r : signal is "TRUE";
    attribute ASYNC_REG of gt_txfsmresetdone_r2 : signal is "TRUE";
    signal gt0_txfsmresetdone_i  : std_logic;
    signal gt0_rxfsmresetdone_i  : std_logic;
    signal gt0_txfsmresetdone_r  : std_logic;
    signal gt0_txfsmresetdone_r2 : std_logic;
    attribute ASYNC_REG of gt0_txfsmresetdone_r : signal is "TRUE";
    attribute ASYNC_REG of gt0_txfsmresetdone_r2 : signal is "TRUE";
    signal gt0_rxresetdone_r  : std_logic;
    signal gt0_rxresetdone_r2 : std_logic;
    signal gt0_rxresetdone_r3 : std_logic;
    attribute ASYNC_REG of gt0_rxresetdone_r : signal is "TRUE";
    attribute ASYNC_REG of gt0_rxresetdone_r2 : signal is "TRUE";
    attribute ASYNC_REG of gt0_rxresetdone_r3 : signal is "TRUE";

    --**************************** Wire Declarations ******************************
    -------------------------- GT Wrapper Wires ------------------------------

    --------------------------------- CPLL Ports -------------------------------
    signal gt0_cpllfbclklost_i    : std_logic;
    signal gt0_cplllock_i         : std_logic;
    signal gt0_cpllrefclklost_i   : std_logic;
    signal gt0_cpllreset_i        : std_logic;
    ---------------------------- Channel - DRP Ports  --------------------------
    signal gt0_drpaddr_i          : std_logic_vector(8 downto 0);
    signal gt0_drpdi_i            : std_logic_vector(15 downto 0);
    signal gt0_drpdo_i            : std_logic_vector(15 downto 0);
    signal gt0_drpen_i            : std_logic;
    signal gt0_drprdy_i           : std_logic;
    signal gt0_drpwe_i            : std_logic;
    --------------------- RX Initialization and Reset Ports --------------------
    signal gt0_eyescanreset_i     : std_logic;
    signal gt0_rxuserrdy_i        : std_logic;
    -------------------------- RX Margin Analysis Ports ------------------------
    signal gt0_eyescandataerror_i : std_logic;
    signal gt0_eyescantrigger_i   : std_logic;
    ------------------- Receive Ports - Clock Correction Ports -----------------
    signal gt0_rxclkcorcnt_i      : std_logic_vector(1 downto 0);
    ------------------- Receive Ports - Digital Monitor Ports ------------------
    signal gt0_dmonitorout_i      : std_logic_vector(14 downto 0);
    ------------------ Receive Ports - FPGA RX interface Ports -----------------
    signal gt0_rxdata_i           : std_logic_vector(15 downto 0);
    ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
    signal gt0_rxdisperr_i        : std_logic_vector(1 downto 0);
    signal gt0_rxnotintable_i     : std_logic_vector(1 downto 0);
    ------------------------ Receive Ports - RX AFE Ports ----------------------
    signal gt0_gthrxn_i           : std_logic;
    -------------- Receive Ports - RX Byte and Word Alignment Ports ------------
    signal gt0_rxbyteisaligned_i  : std_logic;
    signal gt0_rxbyterealign_i    : std_logic;
    signal gt0_rxcommadet_i       : std_logic;
    signal gt0_rxmcommaalignen_i  : std_logic := '1';
    signal gt0_rxpcommaalignen_i  : std_logic := '1';
    --------------------- Receive Ports - RX Equalizer Ports -------------------
    signal gt0_rxmonitorout_i     : std_logic_vector(6 downto 0);
    signal gt0_rxmonitorsel_i     : std_logic_vector(1 downto 0);
    --------------- Receive Ports - RX Fabric Output Control Ports -------------
    signal gt0_rxoutclk_i         : std_logic;
    ------------- Receive Ports - RX Initialization and Reset Ports ------------
    signal gt0_gtrxreset_i        : std_logic;
    ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    signal gt0_rxchariscomma_i    : std_logic_vector(1 downto 0);
    signal gt0_rxcharisk_i        : std_logic_vector(1 downto 0);
    ------------------------ Receive Ports -RX AFE Ports -----------------------
    signal gt0_gthrxp_i           : std_logic;
    -------------- Receive Ports -RX Initialization and Reset Ports ------------
    signal gt0_rxresetdone_i      : std_logic;
    --------------------- TX Initialization and Reset Ports --------------------
    signal gt0_gttxreset_i        : std_logic;
    signal gt0_txuserrdy_i        : std_logic;
    ------------------ Transmit Ports - TX Data Path interface -----------------
    signal gt0_txdata_i           : std_logic_vector(15 downto 0);
    ---------------- Transmit Ports - TX Driver and OOB signaling --------------
    signal gt0_gthtxn_i           : std_logic;
    signal gt0_gthtxp_i           : std_logic;
    ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    signal gt0_txoutclk_i         : std_logic;
    signal gt0_txoutclkfabric_i   : std_logic;
    signal gt0_txoutclkpcs_i      : std_logic;
    ------------- Transmit Ports - TX Initialization and Reset Ports -----------
    signal gt0_txresetdone_i      : std_logic;
    ----------- Transmit Transmit Ports - 8b10b Encoder Control Ports ----------
    signal gt0_txcharisk_i        : std_logic_vector(1 downto 0);

    --____________________________COMMON PORTS________________________________
    ------------- Common Block  - Dynamic Reconfiguration Port (DRP) -----------
    signal gt0_drpaddr_common_i : std_logic_vector(7 downto 0);
    signal gt0_drpdi_common_i   : std_logic_vector(15 downto 0);
    signal gt0_drpdo_common_i   : std_logic_vector(15 downto 0);
    signal gt0_drpen_common_i   : std_logic;
    signal gt0_drprdy_common_i  : std_logic;
    signal gt0_drpwe_common_i   : std_logic;
    ------------------------- Common Block - QPLL Ports ------------------------
    signal gt0_qplllock_i       : std_logic;
    signal gt0_qpllrefclklost_i : std_logic;
    signal gt0_qpllreset_i      : std_logic;

    ------------------------------- Global Signals -----------------------------
    signal gt0_tx_system_reset_c : std_logic;
    signal gt0_rx_system_reset_c : std_logic;
    signal tied_to_ground_i      : std_logic;
    signal tied_to_ground_vec_i  : std_logic_vector(63 downto 0);
    signal tied_to_vcc_i         : std_logic;
    signal tied_to_vcc_vec_i     : std_logic_vector(7 downto 0);
    signal drpclk_in_i           : std_logic;
    signal GTTXRESET_IN          : std_logic;
    signal GTRXRESET_IN          : std_logic;
    signal CPLLRESET_IN          : std_logic;
    signal QPLLRESET_IN          : std_logic;

    ------------------------------- User Clocks ---------------------------------
    signal gt0_txusrclk_i  : std_logic;
    signal gt0_txusrclk2_i : std_logic;
    signal gt0_rxusrclk_i  : std_logic;
    signal gt0_rxusrclk2_i : std_logic;

    ----------------------------- Reference Clocks ----------------------------
    signal q2_clk0_refclk_i : std_logic;

    ----------------------- Frame check/gen Module Signals --------------------

    signal gt0_matchn_i            : std_logic;
    signal gt0_txcharisk_float_i   : std_logic_vector(5 downto 0);
    signal gt0_txdata_float16_i    : std_logic_vector(15 downto 0);
    signal gt0_txdata_float_i      : std_logic_vector(47 downto 0);
    signal gt0_track_data_i        : std_logic;
    signal gt0_block_sync_i        : std_logic;
    signal gt0_error_count_i       : std_logic_vector(7 downto 0);
    signal gt0_frame_check_reset_i : std_logic;
    signal gt0_inc_in_i            : std_logic;
    signal gt0_inc_out_i           : std_logic;
    signal gt0_unscrambled_data_i  : std_logic_vector(15 downto 0);

    signal reset_on_data_error_i : std_logic;
    signal track_data_out_i      : std_logic;
    signal track_data_out_ila_i  : std_logic_vector(0 downto 0);

    ----------------------- DAQLink signals --------------------

    signal daqlink_UsrClk         : std_logic;
    signal daqlink_cplllock       : std_logic;
    signal daqlink_RxResetDone    : std_logic;
    signal daqlink_txfsmresetdone : std_logic;
    signal daqlink_RXNOTINTABLE   : std_logic_vector(1 downto 0);
    signal daqlink_RXCHARISCOMMA  : std_logic_vector(1 downto 0);
    signal daqlink_RXCHARISK      : std_logic_vector(1 downto 0);
    signal daqlink_RXDATA         : std_logic_vector(15 downto 0);
    signal daqlink_TXCHARISK      : std_logic_vector(1 downto 0);
    signal daqlink_TXDATA         : std_logic_vector(15 downto 0);

    signal daqlink_reset                : std_logic := '1';
    signal daqlink_reset_pwrup          : std_logic := '1';
    signal reset_cooldown_countdown     : unsigned(27 downto 0);
    signal gtx_err_disper_count         : std_logic_vector(15 downto 0);
    signal gtx_err_not_in_table_count   : std_logic_vector(15 downto 0);
    
begin

    --  Static signal Assigments
    tied_to_ground_i       <= '0';
    tied_to_ground_vec_i   <= x"0000000000000000";
    tied_to_vcc_i          <= '1';
    tied_to_vcc_vec_i      <= "11111111";
    q2_clk0_refclk_i       <= '0';
    daqlink_UsrClk         <= gt0_txusrclk2_i;
    daqlink_cplllock       <= gt0_cplllock_i;
    daqlink_RxResetDone    <= gt0_rxresetdone_i;
    daqlink_txfsmresetdone <= gt0_txfsmresetdone_i;

    daqlink_RXNOTINTABLE  <= gt0_rxnotintable_i;
    daqlink_RXCHARISCOMMA <= gt0_rxchariscomma_i;
    daqlink_RXCHARISK     <= gt0_rxcharisk_i;
    daqlink_RXDATA        <= gt0_rxdata_i;
    gt0_txcharisk_i       <= daqlink_TXCHARISK;
    gt0_txdata_i          <= daqlink_TXDATA;

    gth_amc13_support_i : gth_amc13_support
        generic map(
            EXAMPLE_SIM_GTRESET_SPEEDUP => "TRUE",
            STABLE_CLOCK_PERIOD         => 20
        )
        port map(
            SOFT_RESET_IN               => daq_to_daqlink.reset,
            drp_clk_i                   => clk_50_i, -- 50 MHz MMCM clock

            DONT_RESET_ON_DATA_ERROR_IN => tied_to_ground_i,
            Q2_CLK0_GTREFCLK_PAD_N_IN   => GTX_REFCLK_n,
            Q2_CLK0_GTREFCLK_PAD_P_IN   => GTX_REFCLK_p,
            GT0_TX_FSM_RESET_DONE_OUT   => gt0_txfsmresetdone_i,
            GT0_RX_FSM_RESET_DONE_OUT   => gt0_rxfsmresetdone_i,
            GT0_DATA_VALID_IN           => '1',
            GT0_TXUSRCLK_OUT            => gt0_txusrclk_i,
            GT0_TXUSRCLK2_OUT           => gt0_txusrclk2_i,
            GT0_RXUSRCLK_OUT            => gt0_rxusrclk_i,
            GT0_RXUSRCLK2_OUT           => gt0_rxusrclk2_i,

            --_____________________________________________________________________
            --_____________________________________________________________________
            --GT0  (X0Y9)

            --------------------------------- CPLL Ports -------------------------------

            gt0_cpllfbclklost_out       => gt0_cpllfbclklost_i,
            gt0_cplllock_out            => gt0_cplllock_i,
            gt0_cpllreset_in            => tied_to_ground_i,
            ---------------------------- Channel - DRP Ports  --------------------------
            gt0_drpaddr_in              => gt0_drpaddr_i,
            gt0_drpdi_in                => gt0_drpdi_i,
            gt0_drpdo_out               => gt0_drpdo_i,
            gt0_drpen_in                => gt0_drpen_i,
            gt0_drprdy_out              => gt0_drprdy_i,
            gt0_drpwe_in                => gt0_drpwe_i,
            --------------------- RX Initialization and Reset Ports --------------------
            gt0_eyescanreset_in         => tied_to_ground_i,
            gt0_rxuserrdy_in            => tied_to_ground_i,
            -------------------------- RX Margin Analysis Ports ------------------------
            gt0_eyescandataerror_out    => gt0_eyescandataerror_i,
            gt0_eyescantrigger_in       => tied_to_ground_i,
            ------------------- Receive Ports - Clock Correction Ports -----------------
            gt0_rxclkcorcnt_out         => gt0_rxclkcorcnt_i,
            ------------------- Receive Ports - Digital Monitor Ports ------------------
            gt0_dmonitorout_out         => gt0_dmonitorout_i,
            ------------------ Receive Ports - FPGA RX interface Ports -----------------
            gt0_rxdata_out              => gt0_rxdata_i,
            ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
            gt0_rxdisperr_out           => gt0_rxdisperr_i,
            gt0_rxnotintable_out        => gt0_rxnotintable_i,
            ------------------------ Receive Ports - RX AFE Ports ----------------------
            gt0_gthrxn_in               => GTX_RXN,
            -------------- Receive Ports - RX Byte and Word Alignment Ports ------------
            gt0_rxbyteisaligned_out     => gt0_rxbyteisaligned_i,
            gt0_rxbyterealign_out       => gt0_rxbyterealign_i,
            gt0_rxcommadet_out          => gt0_rxcommadet_i,
            gt0_rxmcommaalignen_in      => gt0_rxmcommaalignen_i,
            gt0_rxpcommaalignen_in      => gt0_rxpcommaalignen_i,
            --------------------- Receive Ports - RX Equalizer Ports -------------------
            gt0_rxmonitorout_out        => gt0_rxmonitorout_i,
            gt0_rxmonitorsel_in         => "00",
            ------------- Receive Ports - RX Initialization and Reset Ports ------------
            gt0_gtrxreset_in            => tied_to_ground_i,
            ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
            gt0_rxchariscomma_out       => gt0_rxchariscomma_i,
            gt0_rxcharisk_out           => gt0_rxcharisk_i,
            ------------------------ Receive Ports -RX AFE Ports -----------------------
            gt0_gthrxp_in               => GTX_RXP,
            -------------- Receive Ports -RX Initialization and Reset Ports ------------
            gt0_rxresetdone_out         => gt0_rxresetdone_i,
            --------------------- TX Initialization and Reset Ports --------------------
            gt0_gttxreset_in            => tied_to_ground_i,
            gt0_txuserrdy_in            => tied_to_ground_i,
            ------------------ Transmit Ports - TX Data Path interface -----------------
            gt0_txdata_in               => gt0_txdata_i,
            ---------------- Transmit Ports - TX Driver and OOB signaling --------------
            gt0_gthtxn_out              => GTX_TXN,
            gt0_gthtxp_out              => GTX_TXP,
            ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
            gt0_txoutclkfabric_out      => gt0_txoutclkfabric_i,
            gt0_txoutclkpcs_out         => gt0_txoutclkpcs_i,
            ------------- Transmit Ports - TX Initialization and Reset Ports -----------
            gt0_txresetdone_out         => gt0_txresetdone_i,
            ----------- Transmit Transmit Ports - 8b10b Encoder Control Ports ----------
            gt0_txcharisk_in            => gt0_txcharisk_i,
            GT0_DRPADDR_COMMON_IN       => "00000000",
            GT0_DRPDI_COMMON_IN         => "0000000000000000",
            GT0_DRPDO_COMMON_OUT        => open,
            GT0_DRPEN_COMMON_IN         => '0',
            GT0_DRPRDY_COMMON_OUT       => open,
            GT0_DRPWE_COMMON_IN         => '0',
            --____________________________COMMON PORTS________________________________
            GT0_QPLLOUTCLK_OUT          => open,
            GT0_QPLLOUTREFCLK_OUT       => open,
            DRP_CLK_O                   => open,
            sysclk_in_p                 => '1', -- not using sys clk internally
            sysclk_in_n                 => '0'
        );

    process(gt0_rxusrclk2_i, gt0_rxresetdone_i)
    begin
        if (gt0_rxresetdone_i = '0') then
            gt0_rxresetdone_r  <= '0' after DLY;
            gt0_rxresetdone_r2 <= '0' after DLY;
            gt0_rxresetdone_r3 <= '0' after DLY;
        elsif (gt0_rxusrclk2_i'event and gt0_rxusrclk2_i = '1') then
            gt0_rxresetdone_r  <= gt0_rxresetdone_i after DLY;
            gt0_rxresetdone_r2 <= gt0_rxresetdone_r after DLY;
            gt0_rxresetdone_r3 <= gt0_rxresetdone_r2 after DLY;
        end if;
    end process;

    process(gt0_txusrclk2_i, gt0_txfsmresetdone_i)
    begin
        if (gt0_txfsmresetdone_i = '0') then
            gt0_txfsmresetdone_r  <= '0' after DLY;
            gt0_txfsmresetdone_r2 <= '0' after DLY;
        elsif (gt0_txusrclk2_i'event and gt0_txusrclk2_i = '1') then
            gt0_txfsmresetdone_r  <= gt0_txfsmresetdone_i after DLY;
            gt0_txfsmresetdone_r2 <= gt0_txfsmresetdone_r after DLY;
        end if;
    end process;

    -------------------------------------------------------------------------------
    ----------------------------- Debug Signals assignment -----------------------

    ------------ optional Ports assignments --------------
    ------------------------------------------------------ 


    -- assign resets for frame_gen modules
    gt0_tx_system_reset_c <= not gt0_txfsmresetdone_r2;

    -- assign resets for frame_check modules
    gt0_rx_system_reset_c <= not gt0_rxresetdone_r3;

    gt0_drpaddr_i <= (others => '0');
    gt0_drpdi_i   <= (others => '0');
    gt0_drpen_i   <= '0';
    gt0_drpwe_i   <= '0';

    i_daqlink : entity work.DAQ_Link_7S
        generic map(
            simulation => false
        )
        port map(
            reset             => daqlink_reset, -- asynchronous reset, assert reset until GTX REFCLK stable
            USE_TRIGGER_PORT  => false,         -- must set this to true when using HCAL type AMC13
            -- MGT signals --
            UsrClk            => daqlink_UsrClk,
            cplllock          => daqlink_cplllock,
            RxResetDone       => daqlink_RxResetDone,
            txfsmresetdone    => daqlink_txfsmresetdone,
            RXNOTINTABLE      => daqlink_RXNOTINTABLE,
            RXCHARISCOMMA     => daqlink_RXCHARISCOMMA,
            RXCHARISK         => daqlink_RXCHARISK,
            RXDATA            => daqlink_RXDATA,
            TXCHARISK         => daqlink_TXCHARISK,
            TXDATA            => daqlink_TXDATA,
            -- TRIGGER port --
            TTCclk            => daq_to_daqlink.ttc_clk,
            BcntRes           => daq_to_daqlink.ttc_bc0,
            trig              => daq_to_daqlink.trig,
            -- TTS port --
            TTSclk            => daq_to_daqlink.tts_clk,
            TTS               => daq_to_daqlink.tts_state,
            -- Data port --
            ReSyncAndEmpty    => daq_to_daqlink.resync,
            EventDataClk      => daq_to_daqlink.event_clk,
            EventData_valid   => daq_to_daqlink.event_valid,
            EventData_header  => daq_to_daqlink.event_header,
            EventData_trailer => daq_to_daqlink.event_trailer,
            EventData         => daq_to_daqlink.event_data,
            AlmostFull        => daqlink_to_daq.almost_full,
            Ready             => daqlink_to_daq.ready,
            sysclk            => tied_to_ground_i,
            L1A_DATA_we       => open,
            L1A_DATA          => open
        );


    -- DAQLink reset at powerup
    daqlink_reset <= daqlink_reset_pwrup;
    process(clk_50_i)
        variable countdown : integer := 50_000_000; -- probably way too long, but ok for now (this is only used after powerup)
    begin
        if (rising_edge(clk_50_i)) then
            if (countdown > 0) then
              daqlink_reset_pwrup <= '1';
              countdown := countdown - 1;
            else
              daqlink_reset_pwrup <= '0';
            end if;
        end if;
    end process;
    
    -- error counters
    process(gt0_txusrclk2_i)
    begin
        if (rising_edge(gt0_txusrclk2_i)) then
            if (daqlink_reset = '1') then
                gtx_err_disper_count <= (others => '0');
                gtx_err_not_in_table_count <= (others => '0');
                reset_cooldown_countdown <= x"27bc86a"; -- about 333ms
            else
                -- wait for some time after a reset before starting to count gtx errors
                if (reset_cooldown_countdown > x"0000000") then
                    reset_cooldown_countdown <= reset_cooldown_countdown - 1;
                else
                    if ((gt0_rxdisperr_i(0) or gt0_rxdisperr_i(1)) = '1' and gt0_rxresetdone_i = '1') then
                        gtx_err_disper_count <= std_logic_vector(unsigned(gtx_err_disper_count) + 1);
                    end if;
                    if ((gt0_rxnotintable_i(0) or gt0_rxnotintable_i(1)) = '1' and gt0_rxresetdone_i = '1') then
                        gtx_err_not_in_table_count <= std_logic_vector(unsigned(gtx_err_not_in_table_count) + 1);
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    daqlink_to_daq.disperr_cnt <= gtx_err_disper_count;
    daqlink_to_daq.notintable_cnt <= gtx_err_not_in_table_count;
    
end daqlink_wrapper_arch;
