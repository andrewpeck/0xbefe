library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
--***********************************Entity Declaration************************

entity gth_amc13_support is
    generic(
        EXAMPLE_SIM_GTRESET_SPEEDUP : string  := "TRUE"; -- simulation setting for GT SecureIP model
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

end gth_amc13_support;

architecture RTL of gth_amc13_support is
    attribute DowngradeIPIdentifiedWarnings : string;
    attribute DowngradeIPIdentifiedWarnings of RTL : architecture is "yes";

    --**************************Component Declarations*****************************

    component gth_amc13_1
        port(
            SYSCLK_IN                   : in  std_logic;
            SOFT_RESET_TX_IN            : in  std_logic;
            SOFT_RESET_RX_IN            : in  std_logic;
            DONT_RESET_ON_DATA_ERROR_IN : in  std_logic;
            GT0_TX_FSM_RESET_DONE_OUT   : out std_logic;
            GT0_RX_FSM_RESET_DONE_OUT   : out std_logic;
            GT0_DATA_VALID_IN           : in  std_logic;

            --_________________________________________________________________________
            --GT0  (X0Y9)
            --____________________________CHANNEL PORTS________________________________
            --------------------------------- CPLL Ports -------------------------------
            gt0_cpllfbclklost_out       : out std_logic;
            gt0_cplllock_out            : out std_logic;
            gt0_cplllockdetclk_in       : in  std_logic;
            gt0_cpllreset_in            : in  std_logic;
            -------------------------- Channel - Clocking Ports ------------------------
            gt0_gtrefclk0_in            : in  std_logic;
            ---------------------------- Channel - DRP Ports  --------------------------
            gt0_drpaddr_in              : in  std_logic_vector(8 downto 0);
            gt0_drpclk_in               : in  std_logic;
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
            ------------------ Receive Ports - FPGA RX Interface Ports -----------------
            gt0_rxusrclk_in             : in  std_logic;
            gt0_rxusrclk2_in            : in  std_logic;
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
            ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
            gt0_txusrclk_in             : in  std_logic;
            gt0_txusrclk2_in            : in  std_logic;
            ------------------ Transmit Ports - TX Data Path interface -----------------
            gt0_txdata_in               : in  std_logic_vector(15 downto 0);
            ---------------- Transmit Ports - TX Driver and OOB signaling --------------
            gt0_gthtxn_out              : out std_logic;
            gt0_gthtxp_out              : out std_logic;
            ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
            gt0_txoutclk_out            : out std_logic;
            gt0_txoutclkfabric_out      : out std_logic;
            gt0_txoutclkpcs_out         : out std_logic;
            ------------- Transmit Ports - TX Initialization and Reset Ports -----------
            gt0_txresetdone_out         : out std_logic;
            ----------- Transmit Transmit Ports - 8b10b Encoder Control Ports ----------
            gt0_txcharisk_in            : in  std_logic_vector(1 downto 0);

            --____________________________COMMON PORTS________________________________
            GT0_QPLLOUTCLK_IN           : in  std_logic;
            GT0_QPLLOUTREFCLK_IN        : in  std_logic
        );

    end component;

    component gth_amc13_common_reset
        generic(
            STABLE_CLOCK_PERIOD : integer := 8 -- Period of the stable clock driving this state-machine, unit is [ns]
        );
        port(
            STABLE_CLOCK : in  std_logic; --Stable Clock, either a stable clock from the PCB
            SOFT_RESET   : in  std_logic; --User Reset, can be pulled any time
            COMMON_RESET : out std_logic --Reset QPLL
        );
    end component;

    component gth_amc13_common
        generic(
            -- Simulation attributes
            WRAPPER_SIM_GTRESET_SPEEDUP : string := "FALSE" -- Set to "TRUE" to speed up sim reset 
        );
        port(
            DRPADDR_COMMON_IN  : in  std_logic_vector(7 downto 0);
            DRPCLK_COMMON_IN   : in  std_logic;
            DRPDI_COMMON_IN    : in  std_logic_vector(15 downto 0);
            DRPDO_COMMON_OUT   : out std_logic_vector(15 downto 0);
            DRPEN_COMMON_IN    : in  std_logic;
            DRPRDY_COMMON_OUT  : out std_logic;
            DRPWE_COMMON_IN    : in  std_logic;
            GTREFCLK0_IN       : in  std_logic;
            QPLLLOCK_OUT       : out std_logic;
            QPLLLOCKDETCLK_IN  : in  std_logic;
            QPLLOUTCLK_OUT     : out std_logic;
            QPLLOUTREFCLK_OUT  : out std_logic;
            QPLLREFCLKLOST_OUT : out std_logic;
            QPLLRESET_IN       : in  std_logic
        );

    end component;
    component gth_amc13_GT_USRCLK_SOURCE
        port(
            Q2_CLK0_GTREFCLK_PAD_N_IN : in  std_logic;
            Q2_CLK0_GTREFCLK_PAD_P_IN : in  std_logic;
            Q2_CLK0_GTREFCLK_OUT      : out std_logic;
            GT0_TXUSRCLK_OUT          : out std_logic;
            GT0_TXUSRCLK2_OUT         : out std_logic;
            GT0_TXOUTCLK_IN           : in  std_logic;
            GT0_RXUSRCLK_OUT          : out std_logic;
            GT0_RXUSRCLK2_OUT         : out std_logic;
            DRPCLK_IN_P               : in  std_logic;
            DRPCLK_IN_N               : in  std_logic;
            DRPCLK_OUT                : out std_logic
        );
    end component;

    --***********************************Parameter Declarations********************

    constant DLY : time := 1 ns;

    --************************** Register Declarations ****************************

    signal gt0_txfsmresetdone_i  : std_logic;
    signal gt0_rxfsmresetdone_i  : std_logic;
    signal gt0_txfsmresetdone_r  : std_logic;
    signal gt0_txfsmresetdone_r2 : std_logic;
    signal gt0_rxresetdone_r     : std_logic;
    signal gt0_rxresetdone_r2    : std_logic;
    signal gt0_rxresetdone_r3    : std_logic;

    signal reset_pulse   : std_logic_vector(3 downto 0);
    signal reset_counter : unsigned(5 downto 0) := "000000";

    --**************************** Wire Declarations ******************************
    -------------------------- GT Wrapper Wires ------------------------------
    --________________________________________________________________________
    --________________________________________________________________________
    --GT0  (X0Y9)

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
    signal gt0_rxmcommaalignen_i  : std_logic;
    signal gt0_rxpcommaalignen_i  : std_logic;
    --------------------- Receive Ports - RX Equalizer Ports -------------------
    signal gt0_rxdfeagchold_i     : std_logic;
    signal gt0_rxdfelfhold_i      : std_logic;
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
    signal gt0_qplllock_i       : std_logic;
    signal gt0_qpllrefclklost_i : std_logic;
    signal gt0_qpllreset_i      : std_logic;
    signal gt0_qpllreset_t      : std_logic;
    signal gt0_qplloutclk_i     : std_logic;
    signal gt0_qplloutrefclk_i  : std_logic;

    ------------------------------- Global Signals -----------------------------
    signal gt0_tx_system_reset_c : std_logic;
    signal gt0_rx_system_reset_c : std_logic;
    signal tied_to_ground_i      : std_logic;
    signal tied_to_ground_vec_i  : std_logic_vector(63 downto 0);
    signal tied_to_vcc_i         : std_logic;
    signal tied_to_vcc_vec_i     : std_logic_vector(7 downto 0);
    signal drpclk_in_i           : std_logic;
    signal sysclk_in_i           : std_logic;
    signal GTTXRESET_IN          : std_logic;
    signal GTRXRESET_IN          : std_logic;
    signal CPLLRESET_IN          : std_logic;
    signal QPLLRESET_IN          : std_logic;

    attribute keep : string;
    ------------------------------- User Clocks ---------------------------------
    signal gt0_txusrclk_i  : std_logic;
    signal gt0_txusrclk2_i : std_logic;
    signal gt0_rxusrclk_i  : std_logic;
    signal gt0_rxusrclk2_i : std_logic;

    ----------------------------- Reference Clocks ----------------------------

    signal q2_clk0_refclk_i : std_logic;

    signal commonreset_i : std_logic;
--**************************** Main Body of Code *******************************
begin

    --  Static signal Assigments
    tied_to_ground_i     <= '0';
    tied_to_ground_vec_i <= x"0000000000000000";
    tied_to_vcc_i        <= '1';
    tied_to_vcc_vec_i    <= "11111111";

    gt0_qpllreset_t       <= tied_to_vcc_i;
    gt0_qplloutclk_out    <= gt0_qplloutclk_i;
    gt0_qplloutrefclk_out <= gt0_qplloutrefclk_i;

    GT0_TXUSRCLK_OUT  <= gt0_txusrclk_i;
    GT0_TXUSRCLK2_OUT <= gt0_txusrclk2_i;
    GT0_RXUSRCLK_OUT  <= gt0_rxusrclk_i;
    GT0_RXUSRCLK2_OUT <= gt0_rxusrclk2_i;

    gt_usrclk_source : gth_amc13_GT_USRCLK_SOURCE
        port map(
            Q2_CLK0_GTREFCLK_PAD_N_IN => Q2_CLK0_GTREFCLK_PAD_N_IN,
            Q2_CLK0_GTREFCLK_PAD_P_IN => Q2_CLK0_GTREFCLK_PAD_P_IN,
            Q2_CLK0_GTREFCLK_OUT      => q2_clk0_refclk_i,
            GT0_TXUSRCLK_OUT          => gt0_txusrclk_i,
            GT0_TXUSRCLK2_OUT         => gt0_txusrclk2_i,
            GT0_TXOUTCLK_IN           => gt0_txoutclk_i,
            GT0_RXUSRCLK_OUT          => gt0_rxusrclk_i,
            GT0_RXUSRCLK2_OUT         => gt0_rxusrclk2_i,
            DRPCLK_IN_P               => SYSCLK_IN_P,
            DRPCLK_IN_N               => SYSCLK_IN_N,
            DRPCLK_OUT                => open
        );

    sysclk_in_i <= drp_clk_i;

    DRP_CLK_O <= sysclk_in_i;

    common0_i : gth_amc13_common
        generic map(
            WRAPPER_SIM_GTRESET_SPEEDUP => EXAMPLE_SIM_GTRESET_SPEEDUP
        )
        port map(
            DRPADDR_COMMON_IN  => gt0_drpaddr_common_in,
            DRPCLK_COMMON_IN   => sysclk_in_i,
            DRPDI_COMMON_IN    => gt0_drpdi_common_in,
            DRPDO_COMMON_OUT   => gt0_drpdo_common_out,
            DRPEN_COMMON_IN    => gt0_drpen_common_in,
            DRPRDY_COMMON_OUT  => gt0_drprdy_common_out,
            DRPWE_COMMON_IN    => gt0_drpwe_common_in,
            GTREFCLK0_IN       => q2_clk0_refclk_i,
            QPLLLOCK_OUT       => gt0_qplllock_i,
            QPLLLOCKDETCLK_IN  => sysclk_in_i,
            QPLLOUTCLK_OUT     => gt0_qplloutclk_i,
            QPLLOUTREFCLK_OUT  => gt0_qplloutrefclk_i,
            QPLLREFCLKLOST_OUT => gt0_qpllrefclklost_i,
            QPLLRESET_IN       => gt0_qpllreset_t
        );

    common_reset_i : gth_amc13_common_reset
        generic map(
            STABLE_CLOCK_PERIOD => STABLE_CLOCK_PERIOD -- Period of the stable clock driving this state-machine, unit is [ns]
        )
        port map(
            STABLE_CLOCK => sysclk_in_i, --Stable Clock, either a stable clock from the PCB
            SOFT_RESET   => soft_reset_in, --User Reset, can be pulled any time
            COMMON_RESET => commonreset_i --Reset QPLL
        );

    gth_amc13_init_i : gth_amc13_1
        port map(
            sysclk_in                   => sysclk_in_i,
            SOFT_RESET_TX_IN            => SOFT_RESET_IN,
            SOFT_RESET_RX_IN            => SOFT_RESET_IN,
            dont_reset_on_data_error_in => DONT_RESET_ON_DATA_ERROR_IN,
            gt0_tx_fsm_reset_done_out   => gt0_tx_fsm_reset_done_out,
            gt0_rx_fsm_reset_done_out   => gt0_rx_fsm_reset_done_out,
            gt0_data_valid_in           => gt0_data_valid_in,

            --_____________________________________________________________________
            --_____________________________________________________________________
            --GT0  (X0Y9)

            --------------------------------- CPLL Ports -------------------------------
            gt0_cpllfbclklost_out       => gt0_cpllfbclklost_out,
            gt0_cplllock_out            => gt0_cplllock_out,
            gt0_cplllockdetclk_in       => sysclk_in_i,
            gt0_cpllreset_in            => gt0_cpllreset_in,
            -------------------------- Channel - Clocking Ports ------------------------
            gt0_gtrefclk0_in            => q2_clk0_refclk_i,
            ---------------------------- Channel - DRP Ports  --------------------------
            gt0_drpaddr_in              => gt0_drpaddr_in,
            gt0_drpclk_in               => sysclk_in_i,
            gt0_drpdi_in                => gt0_drpdi_in,
            gt0_drpdo_out               => gt0_drpdo_out,
            gt0_drpen_in                => gt0_drpen_in,
            gt0_drprdy_out              => gt0_drprdy_out,
            gt0_drpwe_in                => gt0_drpwe_in,
            --------------------- RX Initialization and Reset Ports --------------------
            gt0_eyescanreset_in         => gt0_eyescanreset_in,
            gt0_rxuserrdy_in            => gt0_rxuserrdy_in,
            -------------------------- RX Margin Analysis Ports ------------------------
            gt0_eyescandataerror_out    => gt0_eyescandataerror_out,
            gt0_eyescantrigger_in       => gt0_eyescantrigger_in,
            ------------------- Receive Ports - Clock Correction Ports -----------------
            gt0_rxclkcorcnt_out         => gt0_rxclkcorcnt_out,
            ------------------- Receive Ports - Digital Monitor Ports ------------------
            gt0_dmonitorout_out         => gt0_dmonitorout_out,
            ------------------ Receive Ports - FPGA RX Interface Ports -----------------
            gt0_rxusrclk_in             => gt0_rxusrclk_i,
            gt0_rxusrclk2_in            => gt0_rxusrclk2_i,
            ------------------ Receive Ports - FPGA RX interface Ports -----------------
            gt0_rxdata_out              => gt0_rxdata_out,
            ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
            gt0_rxdisperr_out           => gt0_rxdisperr_out,
            gt0_rxnotintable_out        => gt0_rxnotintable_out,
            ------------------------ Receive Ports - RX AFE Ports ----------------------
            gt0_gthrxn_in               => gt0_gthrxn_in,
            -------------- Receive Ports - RX Byte and Word Alignment Ports ------------
            gt0_rxbyteisaligned_out     => gt0_rxbyteisaligned_out,
            gt0_rxbyterealign_out       => gt0_rxbyterealign_out,
            gt0_rxcommadet_out          => gt0_rxcommadet_out,
            gt0_rxmcommaalignen_in      => gt0_rxmcommaalignen_in,
            gt0_rxpcommaalignen_in      => gt0_rxpcommaalignen_in,
            --------------------- Receive Ports - RX Equalizer Ports -------------------
            gt0_rxmonitorout_out        => gt0_rxmonitorout_out,
            gt0_rxmonitorsel_in         => gt0_rxmonitorsel_in,
            ------------- Receive Ports - RX Initialization and Reset Ports ------------
            gt0_gtrxreset_in            => gt0_gtrxreset_in,
            ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
            gt0_rxchariscomma_out       => gt0_rxchariscomma_out,
            gt0_rxcharisk_out           => gt0_rxcharisk_out,
            ------------------------ Receive Ports -RX AFE Ports -----------------------
            gt0_gthrxp_in               => gt0_gthrxp_in,
            -------------- Receive Ports -RX Initialization and Reset Ports ------------
            gt0_rxresetdone_out         => gt0_rxresetdone_out,
            --------------------- TX Initialization and Reset Ports --------------------
            gt0_gttxreset_in            => gt0_gttxreset_in,
            gt0_txuserrdy_in            => gt0_txuserrdy_in,
            ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
            gt0_txusrclk_in             => gt0_txusrclk_i,
            gt0_txusrclk2_in            => gt0_txusrclk2_i,
            ------------------ Transmit Ports - TX Data Path interface -----------------
            gt0_txdata_in               => gt0_txdata_in,
            ---------------- Transmit Ports - TX Driver and OOB signaling --------------
            gt0_gthtxn_out              => gt0_gthtxn_out,
            gt0_gthtxp_out              => gt0_gthtxp_out,
            ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
            gt0_txoutclk_out            => gt0_txoutclk_i,
            gt0_txoutclkfabric_out      => gt0_txoutclkfabric_out,
            gt0_txoutclkpcs_out         => gt0_txoutclkpcs_out,
            ------------- Transmit Ports - TX Initialization and Reset Ports -----------
            gt0_txresetdone_out         => gt0_txresetdone_out,
            ----------- Transmit Transmit Ports - 8b10b Encoder Control Ports ----------
            gt0_txcharisk_in            => gt0_txcharisk_in,
            gt0_qplloutclk_in           => gt0_qplloutclk_i,
            gt0_qplloutrefclk_in        => gt0_qplloutrefclk_i
        );

end RTL;
