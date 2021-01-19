------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2020-05-28
-- Module Name:    GEM_CVP13
-- Description:    This is the top level of the GEM project on Bittware CVP13 card 
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;

use work.common_pkg.all;
use work.gem_pkg.all;
use work.ttc_pkg.all;
use work.mgt_pkg.all;
use work.ipbus.all;
use work.ipb_addr_decode.all;
use work.gem_board_config_package.all;

entity gem_cvp13 is
    generic(
        -- Firmware version, date, time, git sha (passed in by Hog)
        GLOBAL_DATE            : std_logic_vector (31 downto 0);
        GLOBAL_TIME            : std_logic_vector (31 downto 0);
        GLOBAL_VER             : std_logic_vector (31 downto 0);
        GLOBAL_SHA             : std_logic_vector (31 downto 0)        
    );
    port(

        reset_b_i           : in  std_logic; -- active low reset (pulsed by BMC after FPGA is programmed as signaled by config_done)
        
        -- QSFP control and monitoring
        qsfp_present_b_i    : in  std_logic_vector(3 downto 0); -- active low QSFP present input
        qsfp_reset_b_o      : out std_logic_vector(3 downto 0); -- active low QSFP reset output
        qsfp_lp_o           : out std_logic; -- QSFP low power mode output (to all QSFPs)
        qsfp_ctrl_en_o      : out std_logic; -- QSFP I2C Control Enable. 1 = Connect QSFP I2C/Status to FPGA
        qsfp_int_b_i        : in  std_logic; -- QSFP active low interrup (or'ed from all QSFPs) 

        -- MGT clocks
        qsfp_refclk0_p_i    : in  std_logic_vector(3 downto 0);
        qsfp_refclk0_n_i    : in  std_logic_vector(3 downto 0);
        qsfp_refclk1_p_i    : in  std_logic_vector(3 downto 0);
        qsfp_refclk1_n_i    : in  std_logic_vector(3 downto 0);
                
        -- LEDs
        leds_o              : out std_logic_vector(3 downto 0);
        
        -- PCIe
        pcie_reset_b_i      : in  std_logic;
        pcie_refclk0_p_i    : in  std_logic;
        pcie_refclk0_n_i    : in  std_logic;
        
        -- USB-C
        usbc_cc_i           : in  std_logic;
        usbc_clk_i          : in  std_logic;
        usbc_trig_i         : in  std_logic;
        
        -- Other
        progclk_b5_p_i      : in  std_logic;
        progclk_b5_n_i      : in  std_logic;
        
        i2c_master_en_b_o   : out std_logic; -- FPGA is the I2C master when this is set to 0
        
        -- DIMM0
        dimm0_refclk_p_i    : in  std_logic;
        dimm0_refclk_n_i    : in  std_logic

    );
end gem_cvp13;

architecture gem_cvp13_arch of gem_cvp13 is
   
    COMPONENT vio_qsfp_control
        PORT(
            clk        : IN  STD_LOGIC;
            probe_in0  : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
            probe_in1  : IN  STD_LOGIC;
            probe_out0 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            probe_out1 : OUT STD_LOGIC;
            probe_out2 : OUT STD_LOGIC
        );
    END COMPONENT;
       
    COMPONENT ila_test
        PORT(
            clk    : IN STD_LOGIC;
            probe0 : IN STD_LOGIC;
            probe1 : IN STD_LOGIC_VECTOR(11 DOWNTO 0)
        );
    END COMPONENT;
       
    COMPONENT vio_test
      PORT (
        clk : IN STD_LOGIC;
        probe_in0 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_out0 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0)
      );
    END COMPONENT;
       
    -- resets 
    signal reset                : std_logic;
    signal reset_pwrup          : std_logic;
        
    -- qsfp mgts
    signal mgt_refclks          : t_mgt_refclks_arr(CFG_MGT_NUM_CHANNELS - 1 downto 0);
    signal mgt_master_txoutclk  : std_logic;
    
    signal mgt_status_arr       : t_mgt_status_arr(CFG_MGT_NUM_CHANNELS - 1 downto 0);
    signal mgt_ctrl_arr         : t_mgt_ctrl_arr(CFG_MGT_NUM_CHANNELS - 1 downto 0) := (others => (txreset => '0', rxreset => '0', rxslide => '0'));
    
    signal mgt_tx_data_arr      : t_mgt_64b_tx_data_arr(CFG_MGT_NUM_CHANNELS - 1 downto 0) := (others => MGT_64B_TX_DATA_NULL);
    signal mgt_rx_data_arr      : t_mgt_64b_rx_data_arr(CFG_MGT_NUM_CHANNELS - 1 downto 0);

    signal mgt_tx_usrclk_arr    : std_logic_vector(CFG_MGT_NUM_CHANNELS - 1 downto 0);
    signal mgt_rx_usrclk_arr    : std_logic_vector(CFG_MGT_NUM_CHANNELS - 1 downto 0);    
    
    -- ttc
    signal ttc_clks             : t_ttc_clks;
    signal ttc_clk_status       : t_ttc_clk_status;
    signal ttc_clk_ctrl         : t_ttc_clk_ctrl;
    
    -- PCIe
    signal pcie_refclk0         : std_logic;
    signal pcie_refclk0_div2    : std_logic;
    signal pcie_phy_ready       : std_logic;
    signal pcie_link_up         : std_logic;
    
    -- slow control
    signal ipb_reset            : std_logic;
    signal ipb_clk              : std_logic;
    signal ipb_miso_arr         : ipb_rbus_array(C_NUM_IPB_SLAVES - 1 downto 0) := (others => IPB_RBUS_NULL);
    signal ipb_mosi_arr         : ipb_wbus_array(C_NUM_IPB_SLAVES - 1 downto 0);
    
    -- other
    signal clk100               : std_logic;

    -- debug
    signal tst_bx_cnt           : unsigned(11 downto 0) := (others => '0');
    signal tst_bx_cnt_max       : std_logic_vector(11 downto 0) := x"00f";
    signal tst_trig_cnt         : unsigned(31 downto 0) := (others => '0');

    -------------------- MGTs mapped to GEM links ---------------------------------
    
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
    signal mgt_gbt_common_rxusrclk  : std_logic;

    signal gem_gt_gbt_ctrl_arr      : t_mgt_ctrl_arr(CFG_NUM_OF_OHs * CFG_NUM_GBTS_PER_OH - 1 downto 0);
    signal gem_gt_gbt_status_arr    : t_mgt_status_arr(CFG_NUM_OF_OHs * CFG_NUM_GBTS_PER_OH - 1 downto 0);
    
    -------------------- AMC13 DAQLink ---------------------------------
    signal daq_to_daqlink           : t_daq_to_daqlink;
    signal daqlink_to_daq           : t_daqlink_to_daq := (ready => '0', almost_full => '0', disperr_cnt => (others => '0'), notintable_cnt => (others => '0'));

    -------------------- GEM loader ---------------------------------
    signal to_gem_loader            : t_to_gem_loader := (clk => '0', en => '0');
    signal from_gem_loader          : t_from_gem_loader := (ready => '0', valid => '0', data => (others => '0'), first => '0', last => '0', error => '0', size => (others => '0'));

begin
    
    --================================--
    -- Wiring
    --================================--
    
    reset <= not reset_b_i;
    i2c_master_en_b_o <= '0';
    
    --================================--
    -- Clocks
    --================================--
    
    i_clk_bufs : entity work.clk_bufs
        port map(
            qsfp_refclk0_p_i         => qsfp_refclk0_p_i,
            qsfp_refclk0_n_i         => qsfp_refclk0_n_i,
            qsfp_refclk1_p_i         => qsfp_refclk1_p_i,
            qsfp_refclk1_n_i         => qsfp_refclk1_n_i,
            pcie_refclk0_p_i         => pcie_refclk0_p_i,
            pcie_refclk0_n_i         => pcie_refclk0_n_i,
            sysclk_100_p_i           => progclk_b5_p_i,
            sysclk_100_n_i           => progclk_b5_n_i,
            
            qsfp_refclk0_o           => open,
            qsfp_refclk1_o           => open,
            qsfp_refclk0_div2_o      => open,
            qsfp_refclk1_div2_o      => open,

            qsfp_mgt_refclks_o       => mgt_refclks,
            
            pcie_refclk0_o           => pcie_refclk0,
            pcie_refclk0_div2_o      => pcie_refclk0_div2,

            sysclk_100_o             => clk100
        );

    i_ttc_clks : entity work.ttc_clocks
        generic map(
            g_GEM_STATION               => CFG_GEM_STATION,
            g_LPGBT_2P56G_LOOPBACK_TEST => false
        )
        port map(
            clk_gbt_mgt_txout_i => mgt_master_txoutclk,
            clk_gbt_mgt_ready_i => '1',
            clocks_o            => ttc_clks,
            ctrl_i              => ttc_clk_ctrl,
            status_o            => ttc_clk_status
        );

    --================================--
    -- PCIe
    --================================--

    i_pcie : entity work.pcie
        generic map(
            g_NUM_IPB_SLAVES => C_NUM_IPB_SLAVES
        )
        port map(
            reset_i          => '0', -- TODO: connect it to the FPGA reset
            
            pcie_reset_b_i   => pcie_reset_b_i,
            pcie_refclk_i    => pcie_refclk0,
            pcie_sysclk_i    => pcie_refclk0_div2,
            
            pcie_phy_ready_o => pcie_phy_ready,
            pcie_link_up_o   => pcie_link_up,
            
            status_leds_o    => leds_o,

            ipb_reset_o      => ipb_reset,
            ipb_clk_o        => ipb_clk,
            ipb_miso_arr_i   => ipb_miso_arr,
            ipb_mosi_arr_o   => ipb_mosi_arr            
        );

    --================================--
    -- MGTs
    --================================--

    i_mgts : entity work.mgt_links_gty
        generic map(
            g_NUM_CHANNELS      => CFG_MGT_NUM_CHANNELS,
            g_NUM_QPLLS         => 0,
            g_LINK_CONFIG       => CFG_MGT_LINK_CONFIG,
            g_MASTER_CHANNEL    => CFG_MGT_MASTER_CHANNEL,
            g_STABLE_CLK_PERIOD => 10
        )
        port map(
            reset_i              => '0',
            clk_stable_i         => clk100,
            ttc_clks_i           => ttc_clks,
            ttc_clks_locked_i    => ttc_clk_status.mmcm_locked,
            ttc_clks_reset_o     => open,
            channel_refclk_arr_i => mgt_refclks,
            status_arr_o         => mgt_status_arr,
            ctrl_arr_i           => mgt_ctrl_arr,
            tx_data_arr_i        => mgt_tx_data_arr,
            rx_data_arr_o        => mgt_rx_data_arr,
            tx_usrclk_arr_o      => mgt_tx_usrclk_arr,
            rx_usrclk_arr_o      => mgt_rx_usrclk_arr,
            master_txoutclk_o    => mgt_master_txoutclk,
            master_rxusrclk_o    => open,
            master_txusrclk_o    => mgt_gbt_common_rxusrclk,
            ipb_reset_i          => ipb_reset,
            ipb_clk_i            => ipb_clk,
            ipb_mosi_i           => ipb_mosi_arr(C_IPB_SLV.mgt),
            ipb_miso_o           => ipb_miso_arr(C_IPB_SLV.mgt)
        );

    --================================--
    -- GEM Loader
    --================================--

--    i_gemloader : entity work.gem_loader
--        generic map(
--            g_MAX_SIZE_BYTES   => 9_600_000,
--            g_MEMORY_PRIMITIVE => "ultra"
--        )
--        port map(
--            reset_i           => '0',
--            to_gem_loader_i   => to_gem_loader,
--            from_gem_loader_o => from_gem_loader,
--            ipb_reset_i       => ipb_reset,
--            ipb_clk_i         => ipb_clk,
--            ipb_miso_o        => ipb_miso_o,
--            ipb_mosi_i        => ipb_mosi_i
--        );

    --================================--
    -- GEM Logic
    --================================--

    i_gem : entity work.gem_amc
        generic map(
            g_FW_DATE           => GLOBAL_DATE,
            g_FW_TIME           => GLOBAL_TIME,
            g_FW_VER            => GLOBAL_VER,
            g_FW_SHA            => GLOBAL_SHA,
            g_GEM_STATION       => CFG_GEM_STATION,
            g_NUM_OF_OHs        => CFG_NUM_OF_OHs,
            g_NUM_GBTS_PER_OH   => CFG_NUM_GBTS_PER_OH,
            g_NUM_VFATS_PER_OH  => CFG_NUM_VFATS_PER_OH,
            g_USE_TRIG_TX_LINKS => CFG_USE_TRIG_TX_LINKS,
            g_NUM_TRIG_TX_LINKS => CFG_NUM_TRIG_TX,
            g_NUM_IPB_SLAVES    => C_NUM_IPB_SLAVES - 2, -- NOTE: cheating here, leaving out the last bus, which is connected to the MGTs at the system level (BE CAREFUL WITH THIS WHEN ADDING NEW BUSSES IN THE FUTURE, BEST WOULD BE TO REWORK THIS)
            g_DAQ_CLK_FREQ      => 100_000_000,
            g_DISABLE_TTC_DATA  => true
        )
        port map(
            reset_i                 => '0',
            reset_pwrup_o           => open,
            
            ttc_clocks_i            => ttc_clks,
            ttc_clk_status_i        => ttc_clk_status,
            ttc_clk_ctrl_o          => ttc_clk_ctrl,
            ttc_data_p_i            => '1',
            ttc_data_n_i            => '0',
            
            gt_trig0_rx_clk_arr_i   => gem_gt_trig0_rx_clk_arr,
            gt_trig0_rx_data_arr_i  => gem_gt_trig0_rx_data_arr,
            gt_trig1_rx_clk_arr_i   => gem_gt_trig1_rx_clk_arr,
            gt_trig1_rx_data_arr_i  => gem_gt_trig1_rx_data_arr,
            
            gt_trig_tx_data_arr_o   => gem_gt_trig_tx_data_arr,
            gt_trig_tx_clk_i        => gem_gt_trig_tx_clk,
            gt_trig_tx_status_arr_i => gem_gt_trig_tx_status_arr,
            trig_tx_data_raw_arr_o  => open,
            
            gt_gbt_rx_data_arr_i    => gem_gt_gbt_rx_data_arr,
            gt_gbt_tx_data_arr_o    => gem_gt_gbt_tx_data_arr,
            gt_gbt_rx_clk_arr_i     => gem_gt_gbt_rx_clk_arr,
            gt_gbt_tx_clk_arr_i     => gem_gt_gbt_tx_clk_arr,
            gt_gbt_rx_common_clk_i  => mgt_gbt_common_rxusrclk,
            
            gt_gbt_status_arr_i     => gem_gt_gbt_status_arr,
            gt_gbt_ctrl_arr_o       => gem_gt_gbt_ctrl_arr,
            
            ipb_reset_i             => ipb_reset,
            ipb_clk_i               => ipb_clk,
            ipb_miso_arr_o          => ipb_miso_arr(C_NUM_IPB_SLAVES - 3 downto 0), -- NOTE: cheating here, leaving out the last bus, which is connected to the MGTs at the system level (BE CAREFUL WITH THIS WHEN ADDING NEW BUSSES IN THE FUTURE, BEST WOULD BE TO REWORK THIS)
            ipb_mosi_arr_i          => ipb_mosi_arr(C_NUM_IPB_SLAVES - 3 downto 0), -- NOTE: cheating here, leaving out the last bus, which is connected to the MGTs at the system level (BE CAREFUL WITH THIS WHEN ADDING NEW BUSSES IN THE FUTURE, BEST WOULD BE TO REWORK THIS)
            
            led_l1a_o               => open,
            led_trigger_o           => open,
            
            daq_data_clk_i          => clk100,
            daq_data_clk_locked_i   => '1',
            daq_to_daqlink_o        => daq_to_daqlink,
            daqlink_to_daq_i        => daqlink_to_daq,
            
            board_id_i              => x"caca",
            
            to_gem_loader_o         => to_gem_loader,
            from_gem_loader_i       => from_gem_loader
        );

        -- GEM link mapping
        g_gem_links : for i in 0 to CFG_NUM_OF_OHs - 1 generate
    
            --=== GBT0 ===--
            gem_gt_gbt_rx_data_arr(i * CFG_NUM_GBTS_PER_OH)     <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt0_link).rx).rxdata(39 downto 0);
            gem_gt_gbt_rx_clk_arr(i * CFG_NUM_GBTS_PER_OH)     <= mgt_rx_usrclk_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt0_link).rx);
            mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt0_link).tx).txdata(39 downto 0) <= gem_gt_gbt_tx_data_arr(i * CFG_NUM_GBTS_PER_OH);
            gem_gt_gbt_tx_clk_arr(i * CFG_NUM_GBTS_PER_OH)     <= mgt_tx_usrclk_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt0_link).tx);
            mgt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt0_link).tx).txreset <= gem_gt_gbt_ctrl_arr(i * CFG_NUM_GBTS_PER_OH).txreset;
            mgt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt0_link).rx).rxreset <= gem_gt_gbt_ctrl_arr(i * CFG_NUM_GBTS_PER_OH).rxreset;
            mgt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt0_link).rx).rxslide <= gem_gt_gbt_ctrl_arr(i * CFG_NUM_GBTS_PER_OH).rxslide;
            gem_gt_gbt_status_arr(i * CFG_NUM_GBTS_PER_OH).tx_reset_done <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt0_link).tx).tx_reset_done;
            gem_gt_gbt_status_arr(i * CFG_NUM_GBTS_PER_OH).tx_cpll_locked <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt0_link).tx).tx_cpll_locked;
            gem_gt_gbt_status_arr(i * CFG_NUM_GBTS_PER_OH).rx_reset_done <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt0_link).rx).rx_reset_done;
            gem_gt_gbt_status_arr(i * CFG_NUM_GBTS_PER_OH).rx_cpll_locked <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt0_link).rx).rx_cpll_locked;
    
            --=== GBT1 (no TX for ME0) ===--
            gem_gt_gbt_rx_data_arr(i * CFG_NUM_GBTS_PER_OH + 1) <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt1_link).rx).rxdata(39 downto 0);
            gem_gt_gbt_rx_clk_arr(i * CFG_NUM_GBTS_PER_OH + 1) <= mgt_rx_usrclk_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt1_link).rx);
            mgt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt1_link).rx).rxreset <= gem_gt_gbt_ctrl_arr(i * CFG_NUM_GBTS_PER_OH + 1).rxreset;
            mgt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt1_link).rx).rxslide <= gem_gt_gbt_ctrl_arr(i * CFG_NUM_GBTS_PER_OH + 1).rxslide;
            gem_gt_gbt_status_arr(i * CFG_NUM_GBTS_PER_OH + 1).rx_reset_done <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt1_link).rx).rx_reset_done;
            gem_gt_gbt_status_arr(i * CFG_NUM_GBTS_PER_OH + 1).rx_cpll_locked <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt1_link).rx).rx_cpll_locked;
--            g_non_me0_gbt1_tx_links: if CFG_GEM_STATION /= 0 generate        
                mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt1_link).tx).txdata(39 downto 0) <= gem_gt_gbt_tx_data_arr(i * CFG_NUM_GBTS_PER_OH + 1);
                gem_gt_gbt_tx_clk_arr(i * CFG_NUM_GBTS_PER_OH + 1) <= mgt_tx_usrclk_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt1_link).tx);
                mgt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt1_link).tx).txreset <= gem_gt_gbt_ctrl_arr(i * CFG_NUM_GBTS_PER_OH + 1).txreset;
                gem_gt_gbt_status_arr(i * CFG_NUM_GBTS_PER_OH + 1).tx_reset_done <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt1_link).tx).tx_reset_done;
                gem_gt_gbt_status_arr(i * CFG_NUM_GBTS_PER_OH + 1).tx_cpll_locked <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt1_link).tx).tx_cpll_locked;
--            end generate;
            
            --=== GBT2 (GE1/1 only) ===--
            g_ge11_gbt2_links: if CFG_GEM_STATION = 1 generate        
                gem_gt_gbt_rx_data_arr(i * CFG_NUM_GBTS_PER_OH + 2) <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt2_link).rx).rxdata(39 downto 0);    
                gem_gt_gbt_rx_clk_arr(i * CFG_NUM_GBTS_PER_OH + 2) <= mgt_rx_usrclk_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt2_link).rx);
                mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt2_link).tx).txdata(39 downto 0) <= gem_gt_gbt_tx_data_arr(i * CFG_NUM_GBTS_PER_OH + 2);            
                gem_gt_gbt_tx_clk_arr(i * CFG_NUM_GBTS_PER_OH + 2) <= mgt_tx_usrclk_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt2_link).tx);
                mgt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt2_link).tx).txreset <= gem_gt_gbt_ctrl_arr(i * CFG_NUM_GBTS_PER_OH + 2).txreset;
                mgt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt2_link).rx).rxreset <= gem_gt_gbt_ctrl_arr(i * CFG_NUM_GBTS_PER_OH + 2).rxreset;
                mgt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt2_link).rx).rxslide <= gem_gt_gbt_ctrl_arr(i * CFG_NUM_GBTS_PER_OH + 2).rxslide;
                gem_gt_gbt_status_arr(i * CFG_NUM_GBTS_PER_OH + 2).tx_reset_done <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt2_link).tx).tx_reset_done;
                gem_gt_gbt_status_arr(i * CFG_NUM_GBTS_PER_OH + 2).tx_cpll_locked <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt2_link).tx).tx_cpll_locked;
                gem_gt_gbt_status_arr(i * CFG_NUM_GBTS_PER_OH + 2).rx_reset_done <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt2_link).rx).rx_reset_done;
                gem_gt_gbt_status_arr(i * CFG_NUM_GBTS_PER_OH + 2).rx_cpll_locked <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).gbt2_link).rx).rx_cpll_locked;
            end generate;        
    
            --=== Trigger links (GE1/1 and GE2/1 only) ===--
            g_non_me0_trig_links: if CFG_GEM_STATION /= 0 generate                
                gem_gt_trig0_rx_clk_arr(i)  <= mgt_rx_usrclk_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig0_rx_link).rx);
                gem_gt_trig1_rx_clk_arr(i)  <= mgt_rx_usrclk_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig1_rx_link).rx);

                gem_gt_trig0_rx_data_arr(i).rxdata <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig0_rx_link).rx).rxdata(15 downto 0);
                gem_gt_trig0_rx_data_arr(i).rxbyteisaligned <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig0_rx_link).rx).rxbyteisaligned;
                gem_gt_trig0_rx_data_arr(i).rxbyterealign <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig0_rx_link).rx).rxbyterealign;
                gem_gt_trig0_rx_data_arr(i).rxcommadet <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig0_rx_link).rx).rxcommadet;
                gem_gt_trig0_rx_data_arr(i).rxdisperr <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig0_rx_link).rx).rxdisperr(1 downto 0);
                gem_gt_trig0_rx_data_arr(i).rxnotintable <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig0_rx_link).rx).rxnotintable(1 downto 0);
                gem_gt_trig0_rx_data_arr(i).rxchariscomma <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig0_rx_link).rx).rxchariscomma(1 downto 0);
                gem_gt_trig0_rx_data_arr(i).rxcharisk <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig0_rx_link).rx).rxcharisk(1 downto 0);

                gem_gt_trig1_rx_data_arr(i).rxdata <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig1_rx_link).rx).rxdata(15 downto 0);
                gem_gt_trig1_rx_data_arr(i).rxbyteisaligned <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig1_rx_link).rx).rxbyteisaligned;
                gem_gt_trig1_rx_data_arr(i).rxbyterealign <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig1_rx_link).rx).rxbyterealign;
                gem_gt_trig1_rx_data_arr(i).rxcommadet <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig1_rx_link).rx).rxcommadet;
                gem_gt_trig1_rx_data_arr(i).rxdisperr <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig1_rx_link).rx).rxdisperr(1 downto 0);
                gem_gt_trig1_rx_data_arr(i).rxnotintable <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig1_rx_link).rx).rxnotintable(1 downto 0);
                gem_gt_trig1_rx_data_arr(i).rxchariscomma <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig1_rx_link).rx).rxchariscomma(1 downto 0);
                gem_gt_trig1_rx_data_arr(i).rxcharisk <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(i).trig1_rx_link).rx).rxcharisk(1 downto 0);
            end generate;
            
        end generate; 
        
        -- GTH mapping to EMTF links
        g_use_emtf_links : if CFG_USE_TRIG_TX_LINKS generate
            g_emtf_links : for i in 0 to CFG_NUM_TRIG_TX - 1 generate
                mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_TRIG_TX_LINK_CONFIG_ARR(i)).tx).txdata <= gem_gt_trig_tx_data_arr(i);
                gem_gt_trig_tx_status_arr(i) <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_TRIG_TX_LINK_CONFIG_ARR(i)).tx);
            end generate;
            gem_gt_trig_tx_clk <= mgt_tx_usrclk_arr(CFG_FIBER_TO_MGT_MAP(CFG_TRIG_TX_LINK_CONFIG_ARR(0)).tx);
        end generate;


    --================================--
    -- Debug
    --================================--
    
    i_vio_qsfp : vio_qsfp_control
        port map(
            clk        => clk100,
            probe_in0  => qsfp_present_b_i,
            probe_in1  => qsfp_int_b_i,
            probe_out0 => qsfp_reset_b_o,
            probe_out1 => qsfp_lp_o,
            probe_out2 => qsfp_ctrl_en_o
        );
        
    -- copper input test
    
    process(ttc_clks.clk_40)
    begin
        if rising_edge(ttc_clks.clk_40) then
            if reset = '1' then
                tst_trig_cnt <= (others => '0');
                tst_bx_cnt <= (others => '0');
            else
                if std_logic_vector(tst_bx_cnt) = tst_bx_cnt_max then
                    tst_bx_cnt <= (others => '0');
                else
                    tst_bx_cnt <= tst_bx_cnt + 1;
                end if;
                
                if usbc_trig_i = '1' and tst_trig_cnt /= x"ffffffff" then
                    tst_trig_cnt <= tst_trig_cnt + 1;
                end if;
            end if;
        end if;
    end process;
        
    i_vio_test : vio_test
        port map(
            clk        => ttc_clks.clk_40,
            probe_in0  => std_logic_vector(tst_trig_cnt),
            probe_out0 => tst_bx_cnt_max
        );
        
    i_ila_test : ila_test
        port map(
            clk    => ttc_clks.clk_40,
            probe0 => usbc_trig_i,
            probe1 => std_logic_vector(tst_bx_cnt)
        );
        
end gem_cvp13_arch;
