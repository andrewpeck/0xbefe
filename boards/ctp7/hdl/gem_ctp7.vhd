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
use work.gem_pkg.all;
use work.ipbus.all;
use work.axi_pkg.all;
use work.ipb_addr_decode.all;
use work.gem_board_config_package.all;

--============================================================================
--                                                          Entity declaration
--============================================================================
entity gem_ctp7 is
    generic(
        C_DATE_CODE      : std_logic_vector(31 downto 0) := x"00000000";
        C_GITHASH_CODE   : std_logic_vector(31 downto 0) := x"00000000";
        C_GIT_REPO_DIRTY : std_logic                     := '0'
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
    signal clk_50       : std_logic;
    signal clk_62p5     : std_logic;
    signal clk_200      : std_logic;

    -------------------------- AXI-IPbus bridge ---------------------------------
    --AXI
    signal axi_clk      : std_logic;
    signal axi_reset    : std_logic;
    signal ipb_axi_mosi : t_axi_lite_mosi;
    signal ipb_axi_miso : t_axi_lite_miso;
    --IPbus
    signal ipb_reset    : std_logic;
    signal ipb_clk      : std_logic;
    signal ipb_miso_arr : ipb_rbus_array(C_NUM_IPB_SLAVES - 1 downto 0) := (others => (ipb_rdata => (others => '0'), ipb_ack => '0', ipb_err => '0'));
    signal ipb_mosi_arr : ipb_wbus_array(C_NUM_IPB_SLAVES - 1 downto 0);

    -------------------------- TTC ---------------------------------
    signal ttc_clocks           : t_ttc_clks;
    signal ttc_clk_status       : t_ttc_clk_status;
    signal ttc_clk_ctrl         : t_ttc_clk_ctrl;    

    -------------------------- GTH ---------------------------------
    signal clk_gth_tx_arr       : std_logic_vector(g_NUM_OF_GTH_GTs - 1 downto 0);
    signal clk_gth_rx_arr       : std_logic_vector(g_NUM_OF_GTH_GTs - 1 downto 0);
    signal gth_tx_data_arr      : t_mgt_64b_tx_data_arr(g_NUM_OF_GTH_GTs - 1 downto 0);
    signal gth_rx_data_arr      : t_mgt_64b_rx_data_arr(g_NUM_OF_GTH_GTs - 1 downto 0);
    signal gth_rxreset_arr      : std_logic_vector(g_NUM_OF_GTH_GTs - 1 downto 0);
    signal gth_txreset_arr      : std_logic_vector(g_NUM_OF_GTH_GTs - 1 downto 0);
    signal gt_ctrl_arr          : t_mgt_ctrl_arr(g_NUM_OF_GTH_GTs - 1 downto 0) := (others => (txreset => '0', rxreset => '0', rxslide => '0'));
    signal gt_status_arr        : t_mgt_status_arr(g_NUM_OF_GTH_GTs - 1 downto 0) := (others => (tx_reset_done => '0', rx_reset_done => '0', tx_cpll_locked => '0', rx_cpll_locked => '0', qpll_locked => '0'));
    
    -------------------- GTHs mapped to GEM links ---------------------------------
    
    -- Trigger RX GTX / GTH links (3.2Gbs, 16bit @ 160MHz w/ 8b10b encoding)
    signal gem_gt_trig0_rx_clk_arr  : std_logic_vector(CFG_NUM_OF_OHs - 1 downto 0);
    signal gem_gt_trig0_rx_data_arr : t_mgt_16b_rx_data_arr(CFG_NUM_OF_OHs - 1 downto 0);
    signal gem_gt_trig1_rx_clk_arr  : std_logic_vector(CFG_NUM_OF_OHs - 1 downto 0);
    signal gem_gt_trig1_rx_data_arr : t_mgt_16b_rx_data_arr(CFG_NUM_OF_OHs - 1 downto 0);

    -- Trigger TX GTH links (10.24Gbs, 64bit @ 160MHz w/o encoding)
    signal gem_gt_trig_tx_clk       : std_logic;
    signal gem_gt_trig_tx_data_arr  : t_std64_array(CFG_NUM_TRIG_TX - 1 downto 0);
    signal gem_gt_trig_tx_status_arr: t_mgt_status_arr(CFG_NUM_TRIG_TX - 1 downto 0);

    -- GBT GTX/GTH links (4.8Gbs, 40bit @ 120MHz w/o 8b10b encoding)
    signal gem_gt_gbt_rx_data_arr   : t_std40_array(CFG_NUM_OF_OHs * CFG_NUM_GBTS_PER_OH - 1 downto 0);
    signal gem_gt_gbt_tx_data_arr   : t_std40_array(CFG_NUM_OF_OHs * CFG_NUM_GBTS_PER_OH - 1 downto 0);
    signal gem_gt_gbt_rx_clk_arr    : std_logic_vector(CFG_NUM_OF_OHs * CFG_NUM_GBTS_PER_OH - 1 downto 0);
    signal gem_gt_gbt_tx_clk_arr    : std_logic_vector(CFG_NUM_OF_OHs * CFG_NUM_GBTS_PER_OH - 1 downto 0);
    signal gth_gbt_common_rxusrclk  : std_logic;

    signal gem_gt_gbt_ctrl_arr      : t_mgt_ctrl_arr(CFG_NUM_OF_OHs * CFG_NUM_GBTS_PER_OH - 1 downto 0);
    signal gem_gt_gbt_status_arr    : t_mgt_status_arr(CFG_NUM_OF_OHs * CFG_NUM_GBTS_PER_OH - 1 downto 0);
    
    -------------------- AMC13 DAQLink ---------------------------------
    signal daq_to_daqlink       : t_daq_to_daqlink;
    signal daqlink_to_daq       : t_daqlink_to_daq;

    -------------------- GEM loader ---------------------------------
    signal to_gem_loader        : t_to_gem_loader := (clk => '0', en => '0');
    signal from_gem_loader      : t_from_gem_loader;

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
        --    generic map(
        --      C_DATE_CODE      => C_DATE_CODE,
        --      C_GITHASH_CODE   => C_GITHASH_CODE,
        --      C_GIT_REPO_DIRTY => C_GIT_REPO_DIRTY
        --    )
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
            
            clk_gth_tx_arr_o               => clk_gth_tx_arr,
            clk_gth_rx_arr_o               => clk_gth_rx_arr,
            
            gth_tx_data_arr_i              => gth_tx_data_arr,
            gth_rx_data_arr_o              => gth_rx_data_arr,

            gth_gbt_common_rxusrclk_o      => gth_gbt_common_rxusrclk,
            
            gth_rxreset_arr_o              => gth_rxreset_arr,
            gth_txreset_arr_o              => gth_txreset_arr,

            gth_gem_mgt_status_arr_o       => gt_status_arr,
            gth_gem_mgt_ctrl_arr_i         => gt_ctrl_arr,

            amc13_gth_refclk_p             => amc13_gth_refclk_p,
            amc13_gth_refclk_n             => amc13_gth_refclk_n,
            amc_13_gth_rx_n                => amc_13_gth_rx_n,
            amc_13_gth_rx_p                => amc_13_gth_rx_p,
            amc13_gth_tx_n                 => amc13_gth_tx_n,
            amc13_gth_tx_p                 => amc13_gth_tx_p,
            
            daq_to_daqlink_i               => daq_to_daqlink,
            daqlink_to_daq_o               => daqlink_to_daq,

            from_gem_loader_o              => from_gem_loader,
            to_gem_loader_i                => to_gem_loader
        );

    -------------------------- IPBus ---------------------------------

    i_axi_ipbus_bridge : entity work.axi_ipbus_bridge
        generic map(
            C_NUM_IPB_SLAVES   => C_NUM_IPB_SLAVES,
            C_S_AXI_DATA_WIDTH => 32,
            C_S_AXI_ADDR_WIDTH => C_IPB_AXI_ADDR_WIDTH
        )
        port map(
            ipb_reset_o   => ipb_reset,
            ipb_clk_o     => ipb_clk,
            ipb_miso_i    => ipb_miso_arr,
            ipb_mosi_o    => ipb_mosi_arr,
            S_AXI_ACLK    => axi_clk,
            S_AXI_ARESETN => axi_reset,
            S_AXI_AWADDR  => ipb_axi_mosi.awaddr(C_IPB_AXI_ADDR_WIDTH - 1 downto 0),
            S_AXI_AWPROT  => ipb_axi_mosi.awprot,
            S_AXI_AWVALID => ipb_axi_mosi.awvalid,
            S_AXI_AWREADY => ipb_axi_miso.awready,
            S_AXI_WDATA   => ipb_axi_mosi.wdata,
            S_AXI_WSTRB   => ipb_axi_mosi.wstrb,
            S_AXI_WVALID  => ipb_axi_mosi.wvalid,
            S_AXI_WREADY  => ipb_axi_miso.wready,
            S_AXI_BRESP   => ipb_axi_miso.bresp,
            S_AXI_BVALID  => ipb_axi_miso.bvalid,
            S_AXI_BREADY  => ipb_axi_mosi.bready,
            S_AXI_ARADDR  => ipb_axi_mosi.araddr(C_IPB_AXI_ADDR_WIDTH - 1 downto 0),
            S_AXI_ARPROT  => ipb_axi_mosi.arprot,
            S_AXI_ARVALID => ipb_axi_mosi.arvalid,
            S_AXI_ARREADY => ipb_axi_miso.arready,
            S_AXI_RDATA   => ipb_axi_miso.rdata,
            S_AXI_RRESP   => ipb_axi_miso.rresp,
            S_AXI_RVALID  => ipb_axi_miso.rvalid,
            S_AXI_RREADY  => ipb_axi_mosi.rready
        );

    -------------------------- GEM logic ---------------------------------
    
    g_gem_logic : if not CFG_LPGBT_2P56G_LOOPBACK_TEST generate
        i_gem : entity work.gem_amc
            generic map(
                g_GEM_STATION        => CFG_GEM_STATION,
                g_NUM_OF_OHs         => CFG_NUM_OF_OHs,
                g_NUM_GBTS_PER_OH    => CFG_NUM_GBTS_PER_OH,
                g_NUM_VFATS_PER_OH   => CFG_NUM_VFATS_PER_OH,
                g_USE_TRIG_TX_LINKS  => CFG_USE_TRIG_TX_LINKS,
                g_NUM_TRIG_TX_LINKS  => CFG_NUM_TRIG_TX,
                g_NUM_IPB_SLAVES     => C_NUM_IPB_SLAVES,
                g_DAQ_CLK_FREQ       => 62_500_000 --50_000_000
            )
            port map(
                reset_i                 => '0',
                reset_pwrup_o           => gem_powerup_reset,
                
                ttc_data_p_i            => ttc_data_p_i,
                ttc_data_n_i            => ttc_data_n_i,
                ttc_clocks_i            => ttc_clocks,
                ttc_clk_status_i        => ttc_clk_status,
                ttc_clk_ctrl_o          => ttc_clk_ctrl,
                
                
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
                gt_gbt_rx_common_clk_i  => gth_gbt_common_rxusrclk,
                
                gt_gbt_status_arr_i     => gem_gt_gbt_status_arr,
                gt_gbt_ctrl_arr_o       => gem_gt_gbt_ctrl_arr,
                
                ipb_reset_i             => ipb_reset,
                ipb_clk_i               => ipb_clk,
                ipb_miso_arr_o          => ipb_miso_arr,
                ipb_mosi_arr_i          => ipb_mosi_arr,
    
                led_l1a_o               => LEDs(0),
                led_trigger_o           => LEDs(1),
                
                daq_data_clk_i          => clk_62p5, --clk_50,
                daq_data_clk_locked_i   => '1',
                daq_to_daqlink_o        => daq_to_daqlink,
                daqlink_to_daq_i        => daqlink_to_daq,
                
                board_id_i              => x"beef",
    
                to_gem_loader_o         => to_gem_loader,
                from_gem_loader_i       => from_gem_loader
            );
    
        -- GTH mapping to GEM links for GE1/1
        g_gem_links : for i in 0 to CFG_NUM_OF_OHs - 1 generate
    
            --=== GBT0 ===--
            gem_gt_gbt_rx_data_arr(i * CFG_NUM_GBTS_PER_OH)     <= gth_rx_data_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt0_link).rx).rxdata(39 downto 0);
            gem_gt_gbt_rx_clk_arr(i * CFG_NUM_GBTS_PER_OH)     <= clk_gth_rx_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt0_link).rx);
            gth_tx_data_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt0_link).tx).txdata(39 downto 0) <= gem_gt_gbt_tx_data_arr(i * CFG_NUM_GBTS_PER_OH);
            gem_gt_gbt_tx_clk_arr(i * CFG_NUM_GBTS_PER_OH)     <= clk_gth_tx_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt0_link).tx);
            gt_ctrl_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt0_link).tx).txreset <= gem_gt_gbt_ctrl_arr(i * CFG_NUM_GBTS_PER_OH).txreset;
            gt_ctrl_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt0_link).rx).rxreset <= gem_gt_gbt_ctrl_arr(i * CFG_NUM_GBTS_PER_OH).rxreset;
            gt_ctrl_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt0_link).rx).rxslide <= gem_gt_gbt_ctrl_arr(i * CFG_NUM_GBTS_PER_OH).rxslide;
            gem_gt_gbt_status_arr(i * CFG_NUM_GBTS_PER_OH).tx_reset_done <= gt_status_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt0_link).tx).tx_reset_done;
            gem_gt_gbt_status_arr(i * CFG_NUM_GBTS_PER_OH).tx_cpll_locked <= gt_status_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt0_link).tx).tx_cpll_locked;
            gem_gt_gbt_status_arr(i * CFG_NUM_GBTS_PER_OH).rx_reset_done <= gt_status_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt0_link).rx).rx_reset_done;
            gem_gt_gbt_status_arr(i * CFG_NUM_GBTS_PER_OH).rx_cpll_locked <= gt_status_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt0_link).rx).rx_cpll_locked;
    
            --=== GBT1 (no TX for ME0) ===--
            gem_gt_gbt_rx_data_arr(i * CFG_NUM_GBTS_PER_OH + 1) <= gth_rx_data_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt1_link).rx).rxdata(39 downto 0);
            gem_gt_gbt_rx_clk_arr(i * CFG_NUM_GBTS_PER_OH + 1) <= clk_gth_rx_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt1_link).rx);
            gt_ctrl_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt1_link).rx).rxreset <= gem_gt_gbt_ctrl_arr(i * CFG_NUM_GBTS_PER_OH + 1).rxreset;
            gt_ctrl_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt1_link).rx).rxslide <= gem_gt_gbt_ctrl_arr(i * CFG_NUM_GBTS_PER_OH + 1).rxslide;
            gem_gt_gbt_status_arr(i * CFG_NUM_GBTS_PER_OH + 1).rx_reset_done <= gt_status_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt1_link).rx).rx_reset_done;
            gem_gt_gbt_status_arr(i * CFG_NUM_GBTS_PER_OH + 1).rx_cpll_locked <= gt_status_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt1_link).rx).rx_cpll_locked;
--            g_non_me0_gbt1_tx_links: if CFG_GEM_STATION /= 0 generate        
                gth_tx_data_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt1_link).tx).txdata(39 downto 0) <= gem_gt_gbt_tx_data_arr(i * CFG_NUM_GBTS_PER_OH + 1);
                gem_gt_gbt_tx_clk_arr(i * CFG_NUM_GBTS_PER_OH + 1) <= clk_gth_tx_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt1_link).tx);
                gt_ctrl_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt1_link).tx).txreset <= gem_gt_gbt_ctrl_arr(i * CFG_NUM_GBTS_PER_OH + 1).txreset;
                gem_gt_gbt_status_arr(i * CFG_NUM_GBTS_PER_OH + 1).tx_reset_done <= gt_status_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt1_link).tx).tx_reset_done;
                gem_gt_gbt_status_arr(i * CFG_NUM_GBTS_PER_OH + 1).tx_cpll_locked <= gt_status_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt1_link).tx).tx_cpll_locked;
--            end generate;
            
            --=== GBT2 (GE1/1 only) ===--
            g_ge11_gbt2_links: if CFG_GEM_STATION = 1 generate        
                gem_gt_gbt_rx_data_arr(i * CFG_NUM_GBTS_PER_OH + 2) <= gth_rx_data_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt2_link).rx).rxdata(39 downto 0);    
                gem_gt_gbt_rx_clk_arr(i * CFG_NUM_GBTS_PER_OH + 2) <= clk_gth_rx_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt2_link).rx);
                gth_tx_data_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt2_link).tx).txdata(39 downto 0) <= gem_gt_gbt_tx_data_arr(i * CFG_NUM_GBTS_PER_OH + 2);            
                gem_gt_gbt_tx_clk_arr(i * CFG_NUM_GBTS_PER_OH + 2) <= clk_gth_tx_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt2_link).tx);
                gt_ctrl_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt2_link).tx).txreset <= gem_gt_gbt_ctrl_arr(i * CFG_NUM_GBTS_PER_OH + 2).txreset;
                gt_ctrl_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt2_link).rx).rxreset <= gem_gt_gbt_ctrl_arr(i * CFG_NUM_GBTS_PER_OH + 2).rxreset;
                gt_ctrl_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt2_link).rx).rxslide <= gem_gt_gbt_ctrl_arr(i * CFG_NUM_GBTS_PER_OH + 2).rxslide;
                gem_gt_gbt_status_arr(i * CFG_NUM_GBTS_PER_OH + 2).tx_reset_done <= gt_status_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt2_link).tx).tx_reset_done;
                gem_gt_gbt_status_arr(i * CFG_NUM_GBTS_PER_OH + 2).tx_cpll_locked <= gt_status_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt2_link).tx).tx_cpll_locked;
                gem_gt_gbt_status_arr(i * CFG_NUM_GBTS_PER_OH + 2).rx_reset_done <= gt_status_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt2_link).rx).rx_reset_done;
                gem_gt_gbt_status_arr(i * CFG_NUM_GBTS_PER_OH + 2).rx_cpll_locked <= gt_status_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt2_link).rx).rx_cpll_locked;
            end generate;        
    
            --=== Trigger links (GE1/1 and GE2/1 only) ===--
            g_non_me0_trig_links: if CFG_GEM_STATION /= 0 generate                
                gem_gt_trig0_rx_clk_arr(i)  <= clk_gth_rx_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig0_rx_link).rx);
                gem_gt_trig1_rx_clk_arr(i)  <= clk_gth_rx_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig1_rx_link).rx);

                gem_gt_trig0_rx_data_arr(i).rxdata <= gth_rx_data_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig0_rx_link).rx).rxdata(15 downto 0);
                gem_gt_trig0_rx_data_arr(i).rxbyteisaligned <= gth_rx_data_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig0_rx_link).rx).rxbyteisaligned;
                gem_gt_trig0_rx_data_arr(i).rxbyterealign <= gth_rx_data_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig0_rx_link).rx).rxbyterealign;
                gem_gt_trig0_rx_data_arr(i).rxcommadet <= gth_rx_data_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig0_rx_link).rx).rxcommadet;
                gem_gt_trig0_rx_data_arr(i).rxdisperr <= gth_rx_data_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig0_rx_link).rx).rxdisperr(1 downto 0);
                gem_gt_trig0_rx_data_arr(i).rxnotintable <= gth_rx_data_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig0_rx_link).rx).rxnotintable(1 downto 0);
                gem_gt_trig0_rx_data_arr(i).rxchariscomma <= gth_rx_data_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig0_rx_link).rx).rxchariscomma(1 downto 0);
                gem_gt_trig0_rx_data_arr(i).rxcharisk <= gth_rx_data_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig0_rx_link).rx).rxcharisk(1 downto 0);

                gem_gt_trig1_rx_data_arr(i).rxdata <= gth_rx_data_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig1_rx_link).rx).rxdata(15 downto 0);
                gem_gt_trig1_rx_data_arr(i).rxbyteisaligned <= gth_rx_data_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig1_rx_link).rx).rxbyteisaligned;
                gem_gt_trig1_rx_data_arr(i).rxbyterealign <= gth_rx_data_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig1_rx_link).rx).rxbyterealign;
                gem_gt_trig1_rx_data_arr(i).rxcommadet <= gth_rx_data_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig1_rx_link).rx).rxcommadet;
                gem_gt_trig1_rx_data_arr(i).rxdisperr <= gth_rx_data_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig1_rx_link).rx).rxdisperr(1 downto 0);
                gem_gt_trig1_rx_data_arr(i).rxnotintable <= gth_rx_data_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig1_rx_link).rx).rxnotintable(1 downto 0);
                gem_gt_trig1_rx_data_arr(i).rxchariscomma <= gth_rx_data_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig1_rx_link).rx).rxchariscomma(1 downto 0);
                gem_gt_trig1_rx_data_arr(i).rxcharisk <= gth_rx_data_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig1_rx_link).rx).rxcharisk(1 downto 0);
            end generate;
            
        end generate; 
        
        -- GTH mapping to EMTF links
        g_emtf_links : for i in 0 to CFG_NUM_TRIG_TX - 1 generate
            gth_tx_data_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_TRIG_TX_LINK_CONFIG_ARR(i)).tx).txdata <= gem_gt_trig_tx_data_arr(i);
            gem_gt_trig_tx_status_arr(i) <= gt_status_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_TRIG_TX_LINK_CONFIG_ARR(i)).tx);
        end generate;
        gem_gt_trig_tx_clk <= clk_gth_tx_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_TRIG_TX_LINK_CONFIG_ARR(0)).tx);
        
    end generate;
    
    -------------------------- LpGBT loopback test without GEM logic ---------------------------------
    
    g_lpgbt_loopback_logic : if CFG_LPGBT_2P56G_LOOPBACK_TEST generate
        
        lb_tx_clk <= clk_gth_tx_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(0).gbt0_link).tx);
        
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
        
        daq_to_daqlink <= (reset => '1', ttc_clk => ttc_clocks.clk_40, ttc_bc0 => '0', trig => (others => '0'), tts_clk => ttc_clocks.clk_40, tts_state => x"8", resync => '0', event_clk => clk_62p5, event_valid => '0', event_header => '0', event_trailer => '0', event_data => (others => '0'));
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
        
        lb_gbt_tx_gb_reset <= (not gt_status_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(0).gbt0_link).tx).tx_reset_done) or lb_gbt_reset;
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
                clk    => clk_gth_tx_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(0).gbt0_link).tx),
                probe0 => gth_tx_data_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(0).gbt0_link).tx).txdata(39 downto 0)
            );
        i_ila_gbt0_mgt_rx : ila_gbt_mgt
            port map(
                clk    => clk_gth_rx_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(0).gbt0_link).rx),
                probe0 => gth_rx_data_arr(CFG_CXP_FIBER_TO_GTH_MAP(CFG_OH_LINK_CONFIG_ARR(0).gbt0_link).rx).rxdata(39 downto 0)
            );
    end generate;
    
end gem_ctp7_arch;

--============================================================================
--                                                            Architecture end
--============================================================================

