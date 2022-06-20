-------------------------------------------------------------------------------
--
--       Unit Name: gem_ctp7
--
--     Description:
--
--
-------------------------------------------------------------------------------
--
--           Notes:
--
-------------------------------------------------------------------------------

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
use work.common_pkg.all;
use work.gem_pkg.all;
use work.ipbus.all;
use work.axi_pkg.all;
use work.ipb_addr_decode.all;
use work.ipb_sys_addr_decode.all;
use work.board_config_package.all;
use work.project_config.all;

--============================================================================
--                                                          Entity declaration
--============================================================================
entity gem_ctp7 is
    generic(
        -- Firmware version, date, time, git sha (passed in by Hog)
        GLOBAL_DATE            : std_logic_vector (31 downto 0);
        GLOBAL_TIME            : std_logic_vector (31 downto 0);
        GLOBAL_VER             : std_logic_vector (31 downto 0);
        GLOBAL_SHA             : std_logic_vector (31 downto 0)
    );
    port(
        clk_200_diff_in_clk_p          : in  std_logic;
        clk_200_diff_in_clk_n          : in  std_logic;

        clk_40_ttc_p_i                 : in  std_logic; -- TTC backplane clock signals
        clk_40_ttc_n_i                 : in  std_logic;
        ttc_data_p_i                   : in  std_logic;
        ttc_data_n_i                   : in  std_logic;

        LEDs                           : out std_logic_vector(1 downto 0);

        axi_c2c_v7_to_zynq_data        : out std_logic_vector(16 downto 0);
        axi_c2c_v7_to_zynq_clk         : out std_logic;
        axi_c2c_zynq_to_v7_clk         : in  std_logic;
        axi_c2c_zynq_to_v7_data        : in  std_logic_vector(16 downto 0);
        axi_c2c_v7_to_zynq_link_status : out std_logic;
        axi_c2c_zynq_to_v7_reset       : in  std_logic;

        refclk_F_0_p_i                 : in  std_logic_vector(3 downto 0);
        refclk_F_0_n_i                 : in  std_logic_vector(3 downto 0);
        refclk_F_1_p_i                 : in  std_logic_vector(3 downto 0);
        refclk_F_1_n_i                 : in  std_logic_vector(3 downto 0);

        refclk_B_0_p_i                 : in  std_logic_vector(3 downto 1);
        refclk_B_0_n_i                 : in  std_logic_vector(3 downto 1);
        refclk_B_1_p_i                 : in  std_logic_vector(3 downto 1);
        refclk_B_1_n_i                 : in  std_logic_vector(3 downto 1);

        -- AMC13 GTH
        amc13_gth_refclk_p             : in  std_logic;
        amc13_gth_refclk_n             : in  std_logic;
        amc_13_gth_rx_n                : in  std_logic;
        amc_13_gth_rx_p                : in  std_logic;
        amc13_gth_tx_n                 : out std_logic;
        amc13_gth_tx_p                 : out std_logic

    );
end gem_ctp7;

--============================================================================
--                                                        Architecture section
--============================================================================
architecture gem_ctp7_arch of gem_ctp7 is

    component ila_gbt_mgt
        port(
            clk    : in std_logic;
            probe0 : in std_logic_vector(39 downto 0)
        );
    end component;

    component vio_lpgbt_loopback
        port(
            clk        : in  std_logic;
            probe_in0  : in  std_logic;
            probe_in1  : in  std_logic;
            probe_out0 : out std_logic_vector(31 downto 0);
            probe_out1 : out std_logic_vector(31 downto 0);
            probe_out2 : out std_logic;
            probe_out3 : out std_logic;
            probe_out4 : out std_logic;
            probe_out5 : out std_logic;
            probe_out6 : out std_logic;
            probe_out7 : out std_logic_vector(1 downto 0);
            probe_out8 : out std_logic_vector(1 downto 0)
        );
    end component;

    component ila_emtf_loopback
        port(
            clk    : in std_logic;
            probe0 : in std_logic_vector(233 downto 0);
            probe1 : in std_logic;
            probe2 : in std_logic;
            probe3 : in std_logic;
            probe4 : in std_logic;
            probe5 : in std_logic;
            probe6 : in std_logic_vector(15 downto 0);
            probe7 : in std_logic;
            probe8 : in std_logic_vector(233 downto 0)
        );
    end component;

    --============================================================================
    --                                                         Signal declarations
    --============================================================================

    -------------------------- System clocks ---------------------------------
    signal clk_50           : std_logic;
    signal clk_62p5         : std_logic;
    signal clk_200          : std_logic;
    signal amc13_refclk125  : std_logic;

    -------------------------- AXI-IPbus bridge ---------------------------------
    --AXI
    signal axi_clk          : std_logic;
    signal axi_reset        : std_logic;
    signal ipb_axi_mosi     : t_axi_lite_m2s;
    signal ipb_axi_miso     : t_axi_lite_s2m;
    --IPbus
    signal ipb_reset        : std_logic;
    signal ipb_clk          : std_logic;
    signal ipb_usr_miso_arr : ipb_rbus_array(C_NUM_IPB_SLAVES - 1 downto 0) := (others => IPB_S2M_NULL);
    signal ipb_usr_mosi_arr : ipb_wbus_array(C_NUM_IPB_SLAVES - 1 downto 0);
    signal ipb_sys_miso_arr : ipb_rbus_array(C_NUM_IPB_SYS_SLAVES - 1 downto 0) := (others => IPB_S2M_NULL);

    -------------------------- TTC ---------------------------------
    signal ttc_clocks           : t_ttc_clks;
    signal ttc_clk_status       : t_ttc_clk_status;
    signal ttc_clk_ctrl         : t_ttc_clk_ctrl;

    -------------------------- GTH ---------------------------------
    signal clk_gth_tx_arr       : std_logic_vector(g_NUM_OF_GTH_GTs downto 0);
    signal clk_gth_rx_arr       : std_logic_vector(g_NUM_OF_GTH_GTs downto 0);
    signal gth_tx_data_arr      : t_mgt_64b_tx_data_arr(g_NUM_OF_GTH_GTs downto 0);
    signal gth_rx_data_arr      : t_mgt_64b_rx_data_arr(g_NUM_OF_GTH_GTs downto 0);
    signal gth_rxreset_arr      : std_logic_vector(g_NUM_OF_GTH_GTs downto 0);
    signal gth_txreset_arr      : std_logic_vector(g_NUM_OF_GTH_GTs downto 0);
    signal gt_ctrl_arr          : t_mgt_ctrl_arr(g_NUM_OF_GTH_GTs downto 0) := (others => (txreset => '0', rxreset => '0', rxslide => '0'));
    signal gt_status_arr        : t_mgt_status_arr(g_NUM_OF_GTH_GTs downto 0) := (others => MGT_STATUS_NULL);

    -------------------- GTHs mapped to GEM links ---------------------------------

    -- Trigger RX GTX / GTH links (3.2Gbs, 16bit @ 160MHz w/ 8b10b encoding)
    signal gem_gt_trig0_rx_clk_arr  : std_logic_vector(CFG_NUM_OF_OHs(0) - 1 downto 0);
    signal gem_gt_trig0_rx_data_arr : t_mgt_16b_rx_data_arr(CFG_NUM_OF_OHs(0) - 1 downto 0);
    signal gem_gt_trig1_rx_clk_arr  : std_logic_vector(CFG_NUM_OF_OHs(0) - 1 downto 0);
    signal gem_gt_trig1_rx_data_arr : t_mgt_16b_rx_data_arr(CFG_NUM_OF_OHs(0) - 1 downto 0);

    -- Trigger TX GTH links (10.24Gbs, 64bit @ 160MHz w/o encoding)
    signal gem_gt_trig_tx_clk       : std_logic;
    signal gem_gt_trig_tx_data_arr  : t_std64_array(CFG_NUM_TRIG_TX - 1 downto 0);
    signal gem_gt_trig_tx_status_arr: t_mgt_status_arr(CFG_NUM_TRIG_TX - 1 downto 0);

    -- GBT GTX/GTH links (4.8Gbs, 40bit @ 120MHz w/o 8b10b encoding)
    signal gem_gt_gbt_rx_data_arr   : t_std40_array(CFG_NUM_OF_OHs(0) * CFG_NUM_GBTS_PER_OH(0) - 1 downto 0);
    signal gem_gt_gbt_tx_data_arr   : t_std40_array(CFG_NUM_OF_OHs(0) * CFG_NUM_GBTS_PER_OH(0) - 1 downto 0);
    signal gem_gt_gbt_rx_clk_arr    : std_logic_vector(CFG_NUM_OF_OHs(0) * CFG_NUM_GBTS_PER_OH(0) - 1 downto 0);
    signal gem_gt_gbt_tx_clk_arr    : std_logic_vector(CFG_NUM_OF_OHs(0) * CFG_NUM_GBTS_PER_OH(0) - 1 downto 0);
    signal gth_gbt_common_rxusrclk  : std_logic;

    signal gem_gt_gbt_ctrl_arr      : t_mgt_ctrl_arr(CFG_NUM_OF_OHs(0) * CFG_NUM_GBTS_PER_OH(0) - 1 downto 0);
    signal gem_gt_gbt_status_arr    : t_mgt_status_arr(CFG_NUM_OF_OHs(0) * CFG_NUM_GBTS_PER_OH(0) - 1 downto 0);

    -------------------- Spy / LDAQ readout link ---------------------------------
    signal spy_usrclk               : std_logic;
    signal spy_rx_data              : t_mgt_16b_rx_data;
    signal spy_tx_data              : t_mgt_16b_tx_data;
    signal spy_rx_status            : t_mgt_status;

    -------------------- AMC13 DAQLink ---------------------------------
    signal daq_to_daqlink       : t_daq_to_daqlink;
    signal daqlink_to_daq       : t_daqlink_to_daq;

    -------------------- PROMless ---------------------------------
    signal to_promless          : t_to_promless := (clk => '0', en => '0');
    signal from_promless        : t_from_promless;

    -------------------- Other ---------------------------------

    signal gem_powerup_reset    : std_logic;

    -------------------- EMTF RX test signals ---------------------------------

    signal emtf_tx_data                 : t_std234_array(CFG_NUM_TRIG_TX - 1 downto 0);
    signal emtf_rx_data                 : std_logic_vector(233 downto 0);
    signal emtf_rx_ready                : std_logic;
    signal emtf_rx_had_not_ready        : std_logic;
    signal emtf_rx_header_locked        : std_logic;
    signal emtf_rx_header_had_unlock    : std_logic;
    signal emtf_rx_gearbox_ready        : std_logic;
    signal emtf_rx_correction_cnt       : std_logic_vector(15 downto 0);
    signal emtf_rx_correction_flag      : std_logic;

    -------------------- LpGBT loopback ---------------------------------
    constant LB_PATTERN_LENGTH          : integer := 2;
    constant LB_GBT_USE_CLK_EN          : boolean := false;

    signal lb_tx_clk                    : std_logic;
    signal lb_pattern_idx               : integer range 0 to LB_PATTERN_LENGTH - 1 := 0;
    signal lb_pattern                   : t_std32_array(1 downto 0);
    signal lb_tx_data                   : std_logic_vector(31 downto 0);
    signal lb_use_lpgbt_core            : std_logic;
    signal lb_gbt_ic_pattern            : std_logic_vector(1 downto 0);
    signal lb_gbt_ec_pattern            : std_logic_vector(1 downto 0);
    signal lb_gbt_reset                 : std_logic;
    signal lb_gbt_tx_dp_reset           : std_logic;
    signal lb_gbt_tx_gb_reset           : std_logic;
    signal lb_gbt_tx_frame              : std_logic_vector(63 downto 0);
    signal lb_gbt_tx_mgt_word           : std_logic_vector(31 downto 0);
    signal lb_gbt_dp_ready              : std_logic;
    signal lb_gbt_gb_ready              : std_logic;
    signal lb_gbt_bypass_interleaver    : std_logic;
    signal lb_gbt_bypass_fec            : std_logic;
    signal lb_gbt_bypass_scrambler      : std_logic;

--============================================================================
--                                                          Architecture begin
--============================================================================

begin

    -------------------------- SYSTEM ---------------------------------

    i_system : entity work.system
        generic map (
            g_GEM_STATION => CFG_GEM_STATION(0)
        )
        port map(
            clk_200_diff_in_clk_p          => clk_200_diff_in_clk_p,
            clk_200_diff_in_clk_n          => clk_200_diff_in_clk_n,

            axi_c2c_v7_to_zynq_data        => axi_c2c_v7_to_zynq_data,
            axi_c2c_v7_to_zynq_clk         => axi_c2c_v7_to_zynq_clk,
            axi_c2c_zynq_to_v7_clk         => axi_c2c_zynq_to_v7_clk,
            axi_c2c_zynq_to_v7_data        => axi_c2c_zynq_to_v7_data,
            axi_c2c_v7_to_zynq_link_status => axi_c2c_v7_to_zynq_link_status,
            axi_c2c_zynq_to_v7_reset       => axi_c2c_zynq_to_v7_reset,

            refclk_F_0_p_i                 => refclk_F_0_p_i,
            refclk_F_0_n_i                 => refclk_F_0_n_i,
            refclk_F_1_p_i                 => refclk_F_1_p_i,
            refclk_F_1_n_i                 => refclk_F_1_n_i,
            refclk_B_0_p_i                 => refclk_B_0_p_i,
            refclk_B_0_n_i                 => refclk_B_0_n_i,
            refclk_B_1_p_i                 => refclk_B_1_p_i,
            refclk_B_1_n_i                 => refclk_B_1_n_i,

            clk_50_o                       => clk_50,
            clk_62p5_o                     => clk_62p5,
            clk_200_o                      => clk_200,

            axi_clk_o                      => axi_clk,
            axi_reset_o                    => axi_reset,
            ipb_axi_mosi_o                 => ipb_axi_mosi,
            ipb_axi_miso_i                 => ipb_axi_miso,

            clk_40_ttc_p_i                 => clk_40_ttc_p_i,
            clk_40_ttc_n_i                 => clk_40_ttc_n_i,
            ttc_clks_o                     => ttc_clocks,
            ttc_clk_status_o               => ttc_clk_status,
            ttc_clk_ctrl_i                 => ttc_clk_ctrl,

            clk_gth_tx_arr_o               => clk_gth_tx_arr(g_NUM_OF_GTH_GTs - 1 downto 0),
            clk_gth_rx_arr_o               => clk_gth_rx_arr(g_NUM_OF_GTH_GTs - 1 downto 0),

            gth_tx_data_arr_i              => gth_tx_data_arr(g_NUM_OF_GTH_GTs - 1 downto 0),
            gth_rx_data_arr_o              => gth_rx_data_arr(g_NUM_OF_GTH_GTs - 1 downto 0),

            gth_gbt_common_rxusrclk_o      => gth_gbt_common_rxusrclk,

            gth_rxreset_arr_o              => gth_rxreset_arr(g_NUM_OF_GTH_GTs - 1 downto 0),
            gth_txreset_arr_o              => gth_txreset_arr(g_NUM_OF_GTH_GTs - 1 downto 0),

            gth_gem_mgt_status_arr_o       => gt_status_arr(g_NUM_OF_GTH_GTs - 1 downto 0),
            gth_gem_mgt_ctrl_arr_i         => gt_ctrl_arr(g_NUM_OF_GTH_GTs - 1 downto 0),

            amc13_gth_refclk_p             => amc13_gth_refclk_p,
            amc13_gth_refclk_n             => amc13_gth_refclk_n,
            amc13_gth_refclk_out           => amc13_refclk125,
            amc_13_gth_rx_n                => amc_13_gth_rx_n,
            amc_13_gth_rx_p                => amc_13_gth_rx_p,
            amc13_gth_tx_n                 => amc13_gth_tx_n,
            amc13_gth_tx_p                 => amc13_gth_tx_p,

            daq_to_daqlink_i               => daq_to_daqlink,
            daqlink_to_daq_o               => daqlink_to_daq,

            from_promless_o                => from_promless,
            to_promless_i                  => to_promless
        );

    -------------------------- IPBus ---------------------------------

    i_axi_ipbus_bridge : entity work.axi_ipbus_bridge
        generic map(
            g_DEBUG => true,
            g_IPB_CLK_ASYNC => false,
            g_IPB_TIMEOUT => 3000
        )
        port map(
            axi_aclk_i     => axi_clk,
            axi_aresetn_i  => axi_reset,
            axil_m2s_i     => ipb_axi_mosi,
            axil_s2m_o     => ipb_axi_miso,
            ipb_reset_o    => ipb_reset,
            ipb_clk_i      => ipb_clk,
            ipb_sys_miso_i => ipb_sys_miso_arr,
            ipb_sys_mosi_o => open,
            ipb_usr_miso_i => ipb_usr_miso_arr,
            ipb_usr_mosi_o => ipb_usr_mosi_arr,
            read_active_o  => open,
            write_active_o => open
        );

    ipb_clk <= axi_clk;

    -------------------------- GEM logic ---------------------------------

    g_gem_logic : if not CFG_LPGBT_2P56G_LOOPBACK_TEST generate
        i_gem : entity work.gem_amc
            generic map(
                g_SLR                => 0,
                g_DISABLE_TTC_DATA   => false,
                g_GEM_STATION        => CFG_GEM_STATION(0),
                g_NUM_OF_OHs         => CFG_NUM_OF_OHs(0),
                g_OH_VERSION         => CFG_OH_VERSION(0),
                g_GBT_WIDEBUS        => CFG_GBT_WIDEBUS(0),
                g_NUM_GBTS_PER_OH    => CFG_NUM_GBTS_PER_OH(0),
                g_NUM_VFATS_PER_OH   => CFG_NUM_VFATS_PER_OH(0),
                g_USE_TRIG_TX_LINKS  => CFG_USE_TRIG_TX_LINKS,
                g_NUM_TRIG_TX_LINKS  => CFG_NUM_TRIG_TX,
                g_OH_TRIG_LINK_TYPE  => CFG_OH_TRIG_LINK_TYPE(0),
                g_NUM_IPB_SLAVES     => C_NUM_IPB_SLAVES,
                g_IPB_CLK_PERIOD_NS  => 20,
                g_DAQ_CLK_FREQ       => 62_500_000, --50_000_000
                g_IS_SLINK_ROCKET    => false
            )
            port map(
                reset_i                 => '0',
                reset_pwrup_o           => gem_powerup_reset,

                ttc_reset_i             => '0',
                ttc_data_p_i            => ttc_data_p_i,
                ttc_data_n_i            => ttc_data_n_i,
                ttc_clocks_i            => ttc_clocks,
                ttc_clk_status_i        => ttc_clk_status,
                ttc_clk_ctrl_o          => ttc_clk_ctrl,
                external_trigger_i      => '0',

                gt_trig0_rx_clk_arr_i   => gem_gt_trig0_rx_clk_arr,
                gt_trig0_rx_data_arr_i  => gem_gt_trig0_rx_data_arr,
                gt_trig1_rx_clk_arr_i   => gem_gt_trig1_rx_clk_arr,
                gt_trig1_rx_data_arr_i  => gem_gt_trig1_rx_data_arr,

                gt_trig_tx_data_arr_o   => gem_gt_trig_tx_data_arr,
                gt_trig_tx_clk_i        => gem_gt_trig_tx_clk,
                gt_trig_tx_status_arr_i => gem_gt_trig_tx_status_arr,
                trig_tx_data_raw_arr_o  => emtf_tx_data,

                gt_gbt_rx_data_arr_i    => gem_gt_gbt_rx_data_arr,
                gt_gbt_tx_data_arr_o    => gem_gt_gbt_tx_data_arr,
                gt_gbt_rx_clk_arr_i     => gem_gt_gbt_rx_clk_arr,
                gt_gbt_tx_clk_arr_i     => gem_gt_gbt_tx_clk_arr,

                gt_gbt_status_arr_i     => gem_gt_gbt_status_arr,
                gt_gbt_ctrl_arr_o       => gem_gt_gbt_ctrl_arr,

                spy_usrclk_i            => spy_usrclk,
                spy_rx_data_i           => spy_rx_data,
                spy_tx_data_o           => spy_tx_data,
                spy_rx_status_i         => spy_rx_status,

                ipb_reset_i             => ipb_reset,
                ipb_clk_i               => ipb_clk,
                ipb_miso_arr_o          => ipb_usr_miso_arr,
                ipb_mosi_arr_i          => ipb_usr_mosi_arr,

                led_l1a_o               => LEDs(0),
                led_trigger_o           => LEDs(1),

                daq_data_clk_i          => clk_62p5, --clk_50,
                daq_data_clk_locked_i   => '1',
                daq_to_daqlink_o        => daq_to_daqlink,
                daqlink_to_daq_i        => daqlink_to_daq,

                board_id_i              => x"beef",

                to_promless_o           => to_promless,
                from_promless_i         => from_promless
            );

        -- MGT mapping to GEM links
        g_gem_links : for oh in 0 to CFG_NUM_OF_OHs(0) - 1 generate

            g_gbt_links : for gbt in 0 to CFG_NUM_GBTS_PER_OH(0) - 1 generate
                gem_gt_gbt_rx_data_arr(oh * CFG_NUM_GBTS_PER_OH(0) + gbt)     <= gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).gbt_links(gbt).rx).rx).rxdata(39 downto 0);
                gem_gt_gbt_rx_clk_arr(oh * CFG_NUM_GBTS_PER_OH(0) + gbt)     <= clk_gth_rx_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).gbt_links(gbt).rx).rx);
                gth_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).gbt_links(gbt).tx).tx).txdata(39 downto 0) <= gem_gt_gbt_tx_data_arr(oh * CFG_NUM_GBTS_PER_OH(0) + gbt);
                gem_gt_gbt_tx_clk_arr(oh * CFG_NUM_GBTS_PER_OH(0) + gbt)     <= clk_gth_tx_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).gbt_links(gbt).tx).tx);
                gt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).gbt_links(gbt).tx).tx).txreset <= gem_gt_gbt_ctrl_arr(oh * CFG_NUM_GBTS_PER_OH(0) + gbt).txreset;
                gt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).gbt_links(gbt).rx).rx).rxreset <= gem_gt_gbt_ctrl_arr(oh * CFG_NUM_GBTS_PER_OH(0) + gbt).rxreset;
                gt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).gbt_links(gbt).rx).rx).rxslide <= gem_gt_gbt_ctrl_arr(oh * CFG_NUM_GBTS_PER_OH(0) + gbt).rxslide;
                gem_gt_gbt_status_arr(oh * CFG_NUM_GBTS_PER_OH(0) + gbt).tx_reset_done <= gt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).gbt_links(gbt).tx).tx).tx_reset_done;
                gem_gt_gbt_status_arr(oh * CFG_NUM_GBTS_PER_OH(0) + gbt).tx_pll_locked <= gt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).gbt_links(gbt).tx).tx).tx_pll_locked;
                gem_gt_gbt_status_arr(oh * CFG_NUM_GBTS_PER_OH(0) + gbt).rx_reset_done <= gt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).gbt_links(gbt).rx).rx).rx_reset_done;
                gem_gt_gbt_status_arr(oh * CFG_NUM_GBTS_PER_OH(0) + gbt).rx_pll_locked <= gt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).gbt_links(gbt).rx).rx).rx_pll_locked;
            end generate;

            --=== Trigger links (GE1/1 and GE2/1 only) ===--
            g_non_me0_trig_links: if CFG_GEM_STATION(0) /= 0 generate
                gem_gt_trig0_rx_clk_arr(oh)  <= clk_gth_rx_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).trig_rx_links(0).rx).rx);
                gem_gt_trig1_rx_clk_arr(oh)  <= clk_gth_rx_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).trig_rx_links(1).rx).rx);

                gem_gt_trig0_rx_data_arr(oh).rxdata <= gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).trig_rx_links(0).rx).rx).rxdata(15 downto 0);
                gem_gt_trig0_rx_data_arr(oh).rxbyteisaligned <= gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).trig_rx_links(0).rx).rx).rxbyteisaligned;
                gem_gt_trig0_rx_data_arr(oh).rxbyterealign <= gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).trig_rx_links(0).rx).rx).rxbyterealign;
                gem_gt_trig0_rx_data_arr(oh).rxcommadet <= gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).trig_rx_links(0).rx).rx).rxcommadet;
                gem_gt_trig0_rx_data_arr(oh).rxdisperr <= gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).trig_rx_links(0).rx).rx).rxdisperr(1 downto 0);
                gem_gt_trig0_rx_data_arr(oh).rxnotintable <= gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).trig_rx_links(0).rx).rx).rxnotintable(1 downto 0);
                gem_gt_trig0_rx_data_arr(oh).rxchariscomma <= gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).trig_rx_links(0).rx).rx).rxchariscomma(1 downto 0);
                gem_gt_trig0_rx_data_arr(oh).rxcharisk <= gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).trig_rx_links(0).rx).rx).rxcharisk(1 downto 0);

                gem_gt_trig1_rx_data_arr(oh).rxdata <= gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).trig_rx_links(1).rx).rx).rxdata(15 downto 0);
                gem_gt_trig1_rx_data_arr(oh).rxbyteisaligned <= gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).trig_rx_links(1).rx).rx).rxbyteisaligned;
                gem_gt_trig1_rx_data_arr(oh).rxbyterealign <= gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).trig_rx_links(1).rx).rx).rxbyterealign;
                gem_gt_trig1_rx_data_arr(oh).rxcommadet <= gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).trig_rx_links(1).rx).rx).rxcommadet;
                gem_gt_trig1_rx_data_arr(oh).rxdisperr <= gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).trig_rx_links(1).rx).rx).rxdisperr(1 downto 0);
                gem_gt_trig1_rx_data_arr(oh).rxnotintable <= gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).trig_rx_links(1).rx).rx).rxnotintable(1 downto 0);
                gem_gt_trig1_rx_data_arr(oh).rxchariscomma <= gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).trig_rx_links(1).rx).rx).rxchariscomma(1 downto 0);
                gem_gt_trig1_rx_data_arr(oh).rxcharisk <= gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(oh).trig_rx_links(1).rx).rx).rxcharisk(1 downto 0);
            end generate;

        end generate;

        -- MGT mapping to EMTF links
        g_emtf_links : for i in 0 to CFG_NUM_TRIG_TX - 1 generate
            gth_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_TRIG_TX_LINK_CONFIG_ARR(0)(i)).tx).txdata <= gem_gt_trig_tx_data_arr(i);
            gem_gt_trig_tx_status_arr(i) <= gt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_TRIG_TX_LINK_CONFIG_ARR(0)(i)).tx);
        end generate;
        gem_gt_trig_tx_clk <= clk_gth_tx_arr(CFG_FIBER_TO_MGT_MAP(CFG_TRIG_TX_LINK_CONFIG_ARR(0)(0)).tx);

    end generate;

    -- spy link TX mapping
    g_spy_link_tx : if CFG_USE_SPY_LINK_TX(0) generate
        spy_usrclk                  <= clk_gth_tx_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(0)).tx);

        gth_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(0)).tx).txdata(15 downto 0) <= spy_tx_data.txdata;
        gth_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(0)).tx).txcharisk(1 downto 0) <= spy_tx_data.txcharisk;
        gth_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(0)).tx).txchardispval(1 downto 0) <= spy_tx_data.txchardispval;
        gth_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(0)).tx).txchardispmode(1 downto 0) <= spy_tx_data.txchardispmode;
        
        gth_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(0)).tx).txdata(63 downto 16) <= (others => '0');
        gth_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(0)).tx).txcharisk(7 downto 2) <= (others => '0');
        gth_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(0)).tx).txchardispval(7 downto 2) <= (others => '0');
        gth_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(0)).tx).txchardispmode(7 downto 2) <= (others => '0');
    end generate;

    -- spy link TX mapping
    g_no_spy_link_tx : if not CFG_USE_SPY_LINK_TX(0) generate
        spy_usrclk      <= '0';
    end generate;

    -- spy link RX mapping
    g_spy_link_rx : if CFG_USE_SPY_LINK_RX(0) generate
        spy_rx_data.rxdata          <= gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(0)).rx).rxdata(15 downto 0);
        spy_rx_data.rxbyteisaligned <= gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(0)).rx).rxbyteisaligned;
        spy_rx_data.rxbyterealign   <= gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(0)).rx).rxbyterealign;
        spy_rx_data.rxcommadet      <= gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(0)).rx).rxcommadet;
        spy_rx_data.rxdisperr       <= gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(0)).rx).rxdisperr(1 downto 0);
        spy_rx_data.rxnotintable    <= gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(0)).rx).rxnotintable(1 downto 0);
        spy_rx_data.rxchariscomma   <= gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(0)).rx).rxchariscomma(1 downto 0);
        spy_rx_data.rxcharisk       <= gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(0)).rx).rxcharisk(1 downto 0);
        spy_rx_status               <= gt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(0)).rx);
    end generate;

    -- spy link RX mapping
    g_no_spy_link_rx : if not CFG_USE_SPY_LINK_RX(0) generate
        spy_rx_data     <= MGT_16B_RX_DATA_NULL;
        spy_rx_status   <= MGT_STATUS_NULL;
    end generate;

    -------------------------- LpGBT loopback test without GEM logic ---------------------------------

    g_lpgbt_loopback_logic : if CFG_LPGBT_2P56G_LOOPBACK_TEST generate

        lb_tx_clk <= clk_gth_tx_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(0).gbt_links(0).tx).tx);

        i_vio_lpgbt_loopback : vio_lpgbt_loopback
            port map(
                clk         => lb_tx_clk,
                probe_in0   => lb_gbt_dp_ready,
                probe_in1   => lb_gbt_gb_ready,
                probe_out0  => lb_pattern(0),
                probe_out1  => lb_pattern(1),
                probe_out2  => lb_gbt_bypass_interleaver,
                probe_out3  => lb_gbt_bypass_fec,
                probe_out4  => lb_gbt_bypass_scrambler,
                probe_out5  => lb_gbt_reset,
                probe_out6  => lb_use_lpgbt_core,
                probe_out7  => lb_gbt_ic_pattern,
                probe_out8  => lb_gbt_ec_pattern
            );

        daq_to_daqlink <= DAQ_TO_DAQLINK_NULL;
        LEDs <= "00";
        g_gth_signals_cxp0 : for i in 0 to 11 generate
            gth_tx_data_arr(i).txdata(31 downto 0) <= lb_gbt_tx_mgt_word when lb_use_lpgbt_core = '1' else lb_tx_data;
        end generate;
        g_gth_signals_fake : for i in 12 to g_NUM_OF_GTH_GTs - 1 generate
            gth_tx_data_arr(i).txdata(31 downto 0) <= x"55555555";
        end generate;

        p_lb_const_pattern:
        process(lb_tx_clk)
        begin
            if rising_edge(lb_tx_clk) then
                if lb_pattern_idx = LB_PATTERN_LENGTH - 1 then
                   lb_pattern_idx <= 0;
                else
                   lb_pattern_idx <= lb_pattern_idx + 1;
                end if;

                lb_tx_data <= lb_pattern(lb_pattern_idx);

            end if;
        end process;

        -- LpGBT TX core

        lb_gbt_tx_gb_reset <= (not gt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(0).gbt_links(0).tx).tx).tx_reset_done) or lb_gbt_reset;
        lb_gbt_tx_dp_reset <= not lb_gbt_gb_ready;

        g_gbt_not_use_clk_en : if not LB_GBT_USE_CLK_EN generate
            i_tx_datapath : entity work.LpGBT_FPGA_Downlink_datapath
                    generic map (
                        MULTICYCLE_DELAY => 0
                    )
                port map(
                    donwlinkClk_i               => ttc_clocks.clk_40,
                    downlinkClkEn_i             => '1',
                    downlinkRst_i               => lb_gbt_tx_dp_reset,

                    downlinkUserData_i          => lb_pattern(0),
                    downlinkEcData_i            => lb_gbt_ec_pattern,
                    downlinkIcData_i            => lb_gbt_ic_pattern,

                    downLinkFrame_o             => lb_gbt_tx_frame,

                    downLinkBypassInterleaver_i => lb_gbt_bypass_interleaver,
                    downLinkBypassFECEncoder_i  => lb_gbt_bypass_fec,
                    downLinkBypassScrambler_i   => lb_gbt_bypass_scrambler,

                    downlinkReady_o             => lb_gbt_dp_ready
                );

            i_tx_gearbox : entity work.txGearbox
                generic map(
                    c_clockRatio  => 2,
                    c_inputWidth  => 64,
                    c_outputWidth => 32
                )
                port map(
                    clk_inClk_i    => ttc_clocks.clk_40,
                    clk_clkEn_i    => '1',
                    clk_outClk_i   => lb_tx_clk,

                    rst_gearbox_i  => lb_gbt_tx_gb_reset,

                    dat_inFrame_i  => lb_gbt_tx_frame,
                    dat_outFrame_o => lb_gbt_tx_mgt_word,

                    sta_gbRdy_o    => lb_gbt_gb_ready
                );
        end generate;

        g_gbt_use_clk_en : if LB_GBT_USE_CLK_EN generate
            i_tx_datapath : entity work.LpGBT_FPGA_Downlink_datapath
                    generic map (
                        MULTICYCLE_DELAY => 1
                    )
                port map(
                    donwlinkClk_i               => lb_tx_clk,
                    downlinkClkEn_i             => lb_tx_clk and ttc_clocks.clk_40,
                    downlinkRst_i               => lb_gbt_tx_dp_reset,

                    downlinkUserData_i          => lb_pattern(0),
                    downlinkEcData_i            => lb_gbt_ec_pattern,
                    downlinkIcData_i            => lb_gbt_ic_pattern,

                    downLinkFrame_o             => lb_gbt_tx_frame,

                    downLinkBypassInterleaver_i => lb_gbt_bypass_interleaver,
                    downLinkBypassFECEncoder_i  => lb_gbt_bypass_fec,
                    downLinkBypassScrambler_i   => lb_gbt_bypass_scrambler,

                    downlinkReady_o             => lb_gbt_dp_ready
                );

            i_tx_gearbox : entity work.txGearbox
                generic map(
                    c_clockRatio  => 2,
                    c_inputWidth  => 64,
                    c_outputWidth => 32
                )
                port map(
                    clk_inClk_i    => lb_tx_clk,
                    clk_clkEn_i    => lb_tx_clk and ttc_clocks.clk_40,
                    clk_outClk_i   => lb_tx_clk,

                    rst_gearbox_i  => lb_gbt_tx_gb_reset,

                    dat_inFrame_i  => lb_gbt_tx_frame,
                    dat_outFrame_o => lb_gbt_tx_mgt_word,

                    sta_gbRdy_o    => lb_gbt_gb_ready
                );
        end generate;

    end generate;

    -------------------------- EMTF RX test ---------------------------------

    g_emtf_rx_test : if CFG_LPGBT_EMTF_LOOP_TEST generate

        i_lpgbt_emtf_rx_test : entity work.lpgbt_10g_bidir
            port map(
                reset_i                => gem_powerup_reset,
                clk40_i                => ttc_clocks.clk_40,
                mgt_tx_usrclk_i        => '0',
                mgt_rx_usrclk_i        => clk_gth_rx_arr(CFG_LPGBT_EMTF_LOOP_RX_GTH),
                mgt_tx_ready_i         => '1',
                mgt_rx_ready_i         => gt_status_arr(CFG_LPGBT_EMTF_LOOP_RX_GTH).rx_reset_done,
                mgt_rx_slide_o         => gt_ctrl_arr(CFG_LPGBT_EMTF_LOOP_RX_GTH).rxslide,
                mgt_tx_data_o          => open,
                mgt_rx_data_i          => gth_rx_data_arr(CFG_LPGBT_EMTF_LOOP_RX_GTH).rxdata(31 downto 0),
                tx_data_i              => (others => '0'),
                rx_data_o              => emtf_rx_data,
                tx_ready_o             => open,
                tx_had_not_ready_o     => open,
                rx_ready_o             => emtf_rx_ready,
                rx_had_not_ready_o     => emtf_rx_had_not_ready,
                rx_header_locked_o     => emtf_rx_header_locked,
                rx_header_had_unlock_o => emtf_rx_header_had_unlock,
                rx_gearbox_ready_o     => emtf_rx_gearbox_ready,
                rx_correction_cnt_o    => emtf_rx_correction_cnt,
                rx_correction_flag_o   => emtf_rx_correction_flag
            );

        i_ila_emtf_rx_test : ila_emtf_loopback
            port map(
                clk    => ttc_clocks.clk_40,
                probe0 => emtf_rx_data,
                probe1 => emtf_rx_ready,
                probe2 => emtf_rx_had_not_ready,
                probe3 => emtf_rx_header_locked,
                probe4 => emtf_rx_header_had_unlock,
                probe5 => emtf_rx_gearbox_ready,
                probe6 => emtf_rx_correction_cnt,
                probe7 => emtf_rx_correction_flag,
                probe8 => emtf_tx_data(CFG_LPGBT_EMTF_LOOP_TX_LINK)
            );

    end generate;

    -------------------------- DEBUG ---------------------------------

    g_ila_gbt0_mgt : if CFG_ILA_GBT0_MGT_EN generate
        i_ila_gbt0_mgt_tx : ila_gbt_mgt
            port map(
                clk    => clk_gth_tx_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(0).gbt_links(0).tx).tx),
                probe0 => gth_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(0).gbt_links(0).tx).tx).txdata(39 downto 0)
            );
        i_ila_gbt0_mgt_rx : ila_gbt_mgt
            port map(
                clk    => clk_gth_rx_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(0).gbt_links(0).rx).rx),
                probe0 => gth_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(0)(0).gbt_links(0).rx).rx).rxdata(39 downto 0)
            );
    end generate;

    g_clk_freq_counters : if true generate
        component freq_meter is
            generic(
                REF_F       : std_logic_vector(31 downto 0);
                N           : integer
            );
            port(
                ref_clk     : in  std_logic;
                f           : in  std_logic_vector(N - 1 downto 0);
                freq        : out t_std32_array(N - 1 downto 0)
            );
        end component freq_meter;        
        
        component vio_clk_freq
            port(
                clk       : in std_logic;
                probe_in0 : in std_logic_vector(31 downto 0);
                probe_in1 : in std_logic_vector(31 downto 0)
            );
        end component;        
        
        signal clks_to_measure  : std_logic_vector(1 downto 0);
        signal clks_freq        : t_std32_array(1 downto 0); 
        
    begin
        
        clks_to_measure(0) <= ipb_clk;
        clks_to_measure(1) <= clk_62p5;
        
        i_axi_clk_freq_meter : freq_meter
            generic map(
                REF_F => C_TTC_CLK_FREQUENCY_SLV,
                N     => 2
            )
            port map(
                ref_clk => ttc_clocks.clk_40,
                f       => clks_to_measure,
                freq    => clks_freq
            );

        i_vio_freq_meter : vio_clk_freq
            port map(
                clk       => ttc_clocks.clk_40,
                probe_in0 => clks_freq(0),
                probe_in1 => clks_freq(1)
            );

    end generate;

end gem_ctp7_arch;

--============================================================================
--                                                            Architecture end
--============================================================================
