------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2020-05-28
-- Module Name:    GEM_APEX
-- Description:    This is the top level of the GEM APEX project 
------------------------------------------------------------------------------------------------------------------------------------------------------

---- general notes about the board
----   * may be nice to have also a direct LHC clock to the FPGA for monitoring purposes (maybe?)
----   * parallel programming from the Zynq

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;

use work.common_pkg.all;
use work.gem_pkg.all;
use work.axi_pkg.all;
use work.ttc_pkg.all;
use work.mgt_pkg.all;
use work.ipbus.all;
use work.ipb_addr_decode.all;
use work.ipb_sys_addr_decode.all;
use work.board_config_package.all;

entity gem_apex is
    generic(
        -- Firmware version, date, time, git sha (passed in by Hog)
        GLOBAL_DATE            : std_logic_vector (31 downto 0);
        GLOBAL_TIME            : std_logic_vector (31 downto 0);
        GLOBAL_VER             : std_logic_vector (31 downto 0);
        GLOBAL_SHA             : std_logic_vector (31 downto 0)        
    );
    port(
        -- GTH clocks
        gth_refclk0_p_i     : in  std_logic_vector(2 downto 0);
        gth_refclk0_n_i     : in  std_logic_vector(2 downto 0);
        gth_refclk1_p_i     : in  std_logic_vector(2 downto 0);
        gth_refclk1_n_i     : in  std_logic_vector(2 downto 0);
        
        -- GTY clocks
        gty_refclk0_p_i     : in  std_logic_vector(2 downto 0);
        gty_refclk0_n_i     : in  std_logic_vector(2 downto 0);
        gty_refclk1_p_i     : in  std_logic_vector(2 downto 0);
        gty_refclk1_n_i     : in  std_logic_vector(2 downto 0);
        
        -- C2C
        c2c_rx_rxp          : in  std_logic;
        c2c_rx_rxn          : in  std_logic;
        c2c_tx_txp          : out std_logic;
        c2c_tx_txn          : out std_logic
    );
end gem_apex;

architecture gem_apex_arch of gem_apex is

    component apex_blk is
        port(
            drp_clk             : out STD_LOGIC;
            c2c_refclk          : in  STD_LOGIC;
            c2c_refclk_bufg     : in  STD_LOGIC;
            drp_do              : in  STD_LOGIC_VECTOR(63 downto 0);
            drp_di              : out STD_LOGIC_VECTOR(63 downto 0);
            drp_en              : out STD_LOGIC;
            drp_we              : out STD_LOGIC_VECTOR(7 downto 0);
            drp_rdy             : in  STD_LOGIC;
            drp_addr            : out STD_LOGIC_VECTOR(13 downto 0);
            c2c_tx_txn          : out STD_LOGIC;
            c2c_tx_txp          : out STD_LOGIC;
            c2c_rx_rxn          : in  STD_LOGIC;
            c2c_rx_rxp          : in  STD_LOGIC;
            axi_reset_b_o       : out STD_LOGIC;            
            user_axil_clk_o     : out STD_LOGIC;
            user_axil_awaddr    : out STD_LOGIC_VECTOR(31 downto 0);
            user_axil_awprot    : out STD_LOGIC_VECTOR(2 downto 0);
            user_axil_awvalid   : out STD_LOGIC;
            user_axil_awready   : in  STD_LOGIC;
            user_axil_wdata     : out STD_LOGIC_VECTOR(31 downto 0);
            user_axil_wstrb     : out STD_LOGIC_VECTOR(3 downto 0);
            user_axil_wvalid    : out STD_LOGIC;
            user_axil_wready    : in  STD_LOGIC;
            user_axil_bresp     : in  STD_LOGIC_VECTOR(1 downto 0);
            user_axil_bvalid    : in  STD_LOGIC;
            user_axil_bready    : out STD_LOGIC;
            user_axil_araddr    : out STD_LOGIC_VECTOR(31 downto 0);
            user_axil_arprot    : out STD_LOGIC_VECTOR(2 downto 0);
            user_axil_arvalid   : out STD_LOGIC;
            user_axil_arready   : in  STD_LOGIC;
            user_axil_rdata     : in  STD_LOGIC_VECTOR(31 downto 0);
            user_axil_rresp     : in  STD_LOGIC_VECTOR(1 downto 0);
            user_axil_rvalid    : in  STD_LOGIC;
            user_axil_rready    : out STD_LOGIC;
            clk_100_o           : out STD_LOGIC
        );
    end component apex_blk;

    -- constants
    constant IPB_CLK_PERIOD_NS  : integer := 20;

    -- resets 
    --signal reset                : std_logic;
    signal gem_powerup_reset    : std_logic;
   
    -- refclks
    signal gth_refclk0          : std_logic_vector(2 downto 0);
    signal gth_refclk1          : std_logic_vector(2 downto 0);
    signal gth_refclk0_div2     : std_logic_vector(2 downto 0);
    signal gth_refclk1_div2     : std_logic_vector(2 downto 0);
    signal gty_refclk0          : std_logic_vector(2 downto 0);
    signal gty_refclk1          : std_logic_vector(2 downto 0);
    signal gty_refclk0_div2     : std_logic_vector(2 downto 0);
    signal gty_refclk1_div2     : std_logic_vector(2 downto 0);

    signal c2c_refclk           : std_logic;
    signal c2c_refclk_div2      : std_logic;
        
    -- qsfp mgts
    signal mgt_refclks          : t_mgt_refclks_arr(CFG_MGT_NUM_CHANNELS - 1 downto 0);
    signal mgt_master_txoutclk  : t_mgt_master_clks;
    signal mgt_master_txusrclk  : t_mgt_master_clks;
    signal mgt_master_rxusrclk  : t_mgt_master_clks;
    
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
    
    -- slow control
    signal axil_clk             : std_logic;
    signal axi_reset_b          : std_logic;
    signal axil_m2s             : t_axi_lite_m2s;
    signal axil_s2m             : t_axi_lite_s2m;
    signal ipb_reset            : std_logic;
    signal ipb_clk              : std_logic;
    signal ipb_usr_miso_arr     : ipb_rbus_array(C_NUM_IPB_SLAVES - 1 downto 0) := (others => IPB_S2M_NULL);
    signal ipb_usr_mosi_arr     : ipb_wbus_array(C_NUM_IPB_SLAVES - 1 downto 0);
    signal ipb_sys_miso_arr     : ipb_rbus_array(C_NUM_IPB_SYS_SLAVES - 1 downto 0) := (others => IPB_S2M_NULL);
    signal ipb_sys_mosi_arr     : ipb_wbus_array(C_NUM_IPB_SYS_SLAVES - 1 downto 0);
      
    -- DAQ and other
    signal clk_100              : std_logic;
    signal slink_mgt_ref_clk    : std_logic;
      
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

    signal gem_gt_gbt_ctrl_arr      : t_mgt_ctrl_arr(CFG_NUM_OF_OHs * CFG_NUM_GBTS_PER_OH - 1 downto 0);
    signal gem_gt_gbt_status_arr    : t_mgt_status_arr(CFG_NUM_OF_OHs * CFG_NUM_GBTS_PER_OH - 1 downto 0);
    
    -------------------- AMC13 DAQLink ---------------------------------
    signal daq_to_daqlink           : t_daq_to_daqlink;
    signal daqlink_to_daq           : t_daqlink_to_daq := (ready => '0', almost_full => '0', disperr_cnt => (others => '0'), notintable_cnt => (others => '0'));

    -------------------- PROMless ---------------------------------
    signal to_promless              : t_to_promless := (clk => '0', en => '0');
    signal from_promless            : t_from_promless := (ready => '0', valid => '0', data => (others => '0'), first => '0', last => '0', error => '0');
   
begin
    
    --================================--
    -- APEX C2C
    --================================--

    i_apex_c2c : apex_blk
        port map(
            drp_clk             => open,
            c2c_refclk          => c2c_refclk,
            c2c_refclk_bufg     => c2c_refclk_div2,
            drp_do              => (others => '0'),
            drp_di              => open,
            drp_en              => open,
            drp_we              => open,
            drp_rdy             => '1',
            drp_addr            => open,
            c2c_tx_txn          => c2c_tx_txn,
            c2c_tx_txp          => c2c_tx_txp,
            c2c_rx_rxn          => c2c_rx_rxn,
            c2c_rx_rxp          => c2c_rx_rxp,
            axi_reset_b_o       => axi_reset_b,
            user_axil_clk_o     => axil_clk,
            user_axil_awaddr    => axil_m2s.awaddr,
            user_axil_awprot    => axil_m2s.awprot,
            user_axil_awvalid   => axil_m2s.awvalid,
            user_axil_awready   => axil_s2m.awready,
            user_axil_wdata     => axil_m2s.wdata,
            user_axil_wstrb     => axil_m2s.wstrb,
            user_axil_wvalid    => axil_m2s.wvalid,
            user_axil_wready    => axil_s2m.wready,
            user_axil_bresp     => axil_s2m.bresp,
            user_axil_bvalid    => axil_s2m.bvalid,
            user_axil_bready    => axil_m2s.bready,
            user_axil_araddr    => axil_m2s.araddr,
            user_axil_arprot    => axil_m2s.arprot,
            user_axil_arvalid   => axil_m2s.arvalid,
            user_axil_arready   => axil_s2m.arready,
            user_axil_rdata     => axil_s2m.rdata,
            user_axil_rresp     => axil_s2m.rresp,
            user_axil_rvalid    => axil_s2m.rvalid,
            user_axil_rready    => axil_m2s.rready,
            clk_100_o           => clk_100
        );

    --================================--
    -- IPbus / wishbone
    --================================--

    i_axi_ipbus_bridge : entity work.axi_ipbus_bridge
        generic map(
            g_DEBUG => true,
            g_IPB_CLK_ASYNC => false,
            g_IPB_TIMEOUT => 3000
        )
        port map(
            axi_aclk_i     => axil_clk,
            axi_aresetn_i  => axi_reset_b,
            axil_m2s_i     => axil_m2s,
            axil_s2m_o     => axil_s2m,
            ipb_reset_o    => ipb_reset,
            ipb_clk_i      => ipb_clk,
            ipb_sys_miso_i => ipb_sys_miso_arr,
            ipb_sys_mosi_o => ipb_sys_mosi_arr,
            ipb_usr_miso_i => ipb_usr_miso_arr,
            ipb_usr_mosi_o => ipb_usr_mosi_arr,
            read_active_o  => open,
            write_active_o => open
        );

    ipb_clk <= axil_clk;

    --================================--
    -- Wiring
    --================================--
    
--    reset <= not reset_b_i;
    
    --================================--
    -- Clocks
    --================================--
    
    i_clk_bufs : entity work.clk_bufs
        port map(
            gth_refclk0_p_i    => gth_refclk0_p_i,
            gth_refclk0_n_i    => gth_refclk0_n_i,
            gth_refclk1_p_i    => gth_refclk1_p_i,
            gth_refclk1_n_i    => gth_refclk1_n_i,
            gty_refclk0_p_i    => gty_refclk0_p_i,
            gty_refclk0_n_i    => gty_refclk0_n_i,
            gty_refclk1_p_i    => gty_refclk1_p_i,
            gty_refclk1_n_i    => gty_refclk1_n_i,
            
            gth_mgt_refclks_o  => open,
            gty_mgt_refclks_o  => open,
            
            gth_refclk0_o      => gth_refclk0,
            gth_refclk1_o      => gth_refclk1,
            gth_refclk0_div2_o => gth_refclk0_div2,
            gth_refclk1_div2_o => gth_refclk1_div2,
            gty_refclk0_o      => gty_refclk0,
            gty_refclk1_o      => gty_refclk1,
            gty_refclk0_div2_o => gty_refclk0_div2,
            gty_refclk1_div2_o => gty_refclk1_div2
        );
    
    -- temporary GTY channel refclk wiring for some selected channels
    g_mgt_quad_129_ref_clks: for i in 0 to 3 generate
        mgt_refclks(i).gtrefclk0 <= gty_refclk0(0);
        mgt_refclks(i).gtrefclk1 <= gty_refclk1(0);
    end generate;
    g_mgt_quad_131_ref_clks: for i in 4 to 7 generate
        mgt_refclks(i).gtrefclk0 <= gty_refclk0(1);
        mgt_refclks(i).gtrefclk1 <= gty_refclk1(1);
    end generate;

    c2c_refclk <= gth_refclk1(0);
    c2c_refclk_div2 <= gth_refclk1_div2(0);

    i_ttc_clks : entity work.ttc_clocks
        generic map(
            g_GEM_STATION               => CFG_GEM_STATION
        )
        port map(
            clk_gbt_mgt_txout_i => mgt_master_txoutclk.gbt,
            clk_gbt_mgt_ready_i => '1',
            clocks_o            => ttc_clks,
            ctrl_i              => ttc_clk_ctrl,
            status_o            => ttc_clk_status
        );

    --================================--
    -- MGTs
    --================================--

    i_mgts : entity work.mgt_links_gty
        generic map(
            g_NUM_CHANNELS      => CFG_MGT_NUM_CHANNELS,
            g_NUM_QPLLS         => 0,
            g_LINK_CONFIG       => CFG_MGT_LINK_CONFIG,
            g_STABLE_CLK_PERIOD => 20,
            g_IPB_CLK_PERIOD_NS => IPB_CLK_PERIOD_NS
        )
        port map(
            reset_i              => '0',
            clk_stable_i         => axil_clk,
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
            master_txusrclk_o    => mgt_master_txusrclk,
            master_rxusrclk_o    => mgt_master_rxusrclk,
            ipb_reset_i          => ipb_reset,
            ipb_clk_i            => ipb_clk,
            ipb_mosi_i           => ipb_sys_mosi_arr(C_IPB_SYS_SLV.mgt),
            ipb_miso_o           => ipb_sys_miso_arr(C_IPB_SYS_SLV.mgt)
        );

    --================================--
    -- SLink Rocket
    --================================--

    i_slink_rocket : entity work.slink_rocket
        generic map(
            g_NUM_CHANNELS      => 1,
            g_LINE_RATE         => "25.78125",
            q_REF_CLK_FREQ      => "322.265625",
            g_MGT_TYPE          => "GTY",
            g_IPB_CLK_PERIOD_NS => IPB_CLK_PERIOD_NS
        )
        port map(
            reset_i          => gem_powerup_reset,
            clk_stable_100_i => clk_100,
            mgt_ref_clk_i    => slink_mgt_ref_clk,
            ipb_reset_i      => ipb_reset,
            ipb_clk_i        => ipb_clk,
            ipb_mosi_i       => ipb_sys_mosi_arr(C_IPB_SYS_SLV.slink),
            ipb_miso_o       => ipb_sys_miso_arr(C_IPB_SYS_SLV.slink)
        );

    slink_mgt_ref_clk <= gty_refclk1(1);

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
            g_NUM_IPB_SLAVES    => C_NUM_IPB_SLAVES,
            g_IPB_CLK_PERIOD_NS => IPB_CLK_PERIOD_NS,
            g_DAQ_CLK_FREQ      => 50_000_000,
            g_DISABLE_TTC_DATA  => true
        )
        port map(
            reset_i                 => '0',
            reset_pwrup_o           => gem_powerup_reset,
            
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
            gt_gbt_rx_common_clk_i  => mgt_master_rxusrclk.gbt,
            
            gt_gbt_status_arr_i     => gem_gt_gbt_status_arr,
            gt_gbt_ctrl_arr_o       => gem_gt_gbt_ctrl_arr,
            
            ipb_reset_i             => ipb_reset,
            ipb_clk_i               => ipb_clk,
            ipb_miso_arr_o          => ipb_usr_miso_arr,
            ipb_mosi_arr_i          => ipb_usr_mosi_arr,
            
            led_l1a_o               => open,
            led_trigger_o           => open,
            
            daq_data_clk_i          => axil_clk,
            daq_data_clk_locked_i   => '1',
            daq_to_daqlink_o        => daq_to_daqlink,
            daqlink_to_daq_i        => daqlink_to_daq,
            
            board_id_i              => x"bea0",
            
            to_promless_o           => to_promless,
            from_promless_i         => from_promless
        );

        g_gem_links : for oh in 0 to CFG_NUM_OF_OHs - 1 generate
    
            g_gbt_links : for gbt in 0 to CFG_NUM_GBTS_PER_OH - 1 generate
                gem_gt_gbt_rx_data_arr(oh * CFG_NUM_GBTS_PER_OH + gbt) <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).gbt_links(gbt)).rx).rxdata(39 downto 0);
                gem_gt_gbt_rx_clk_arr(oh * CFG_NUM_GBTS_PER_OH + gbt) <= mgt_rx_usrclk_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).gbt_links(gbt)).rx);
                mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).gbt_links(gbt)).tx).txdata(39 downto 0) <= gem_gt_gbt_tx_data_arr(oh * CFG_NUM_GBTS_PER_OH + gbt);
                gem_gt_gbt_tx_clk_arr(oh * CFG_NUM_GBTS_PER_OH + gbt) <= mgt_tx_usrclk_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).gbt_links(gbt)).tx);
                mgt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).gbt_links(gbt)).tx).txreset <= gem_gt_gbt_ctrl_arr(oh * CFG_NUM_GBTS_PER_OH + gbt).txreset;
                mgt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).gbt_links(gbt)).rx).rxreset <= gem_gt_gbt_ctrl_arr(oh * CFG_NUM_GBTS_PER_OH + gbt).rxreset;
                mgt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).gbt_links(gbt)).rx).rxslide <= gem_gt_gbt_ctrl_arr(oh * CFG_NUM_GBTS_PER_OH + gbt).rxslide;
                gem_gt_gbt_status_arr(oh * CFG_NUM_GBTS_PER_OH + gbt).tx_reset_done  <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).gbt_links(gbt)).tx).tx_reset_done;
                gem_gt_gbt_status_arr(oh * CFG_NUM_GBTS_PER_OH + gbt).tx_cpll_locked <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).gbt_links(gbt)).tx).tx_cpll_locked;
                gem_gt_gbt_status_arr(oh * CFG_NUM_GBTS_PER_OH + gbt).rx_reset_done  <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).gbt_links(gbt)).rx).rx_reset_done;
                gem_gt_gbt_status_arr(oh * CFG_NUM_GBTS_PER_OH + gbt).rx_cpll_locked <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).gbt_links(gbt)).rx).rx_cpll_locked;
            end generate;     
    
            --=== Trigger links (GE1/1 and GE2/1 only) ===--
            g_non_me0_trig_links: if CFG_GEM_STATION /= 0 generate
                gem_gt_trig0_rx_clk_arr(oh)  <= mgt_rx_usrclk_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).trig_rx_links(0)).rx);
                gem_gt_trig1_rx_clk_arr(oh)  <= mgt_rx_usrclk_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).trig_rx_links(1)).rx);

                gem_gt_trig0_rx_data_arr(oh).rxdata <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).trig_rx_links(0)).rx).rxdata(15 downto 0);
                gem_gt_trig0_rx_data_arr(oh).rxbyteisaligned <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).trig_rx_links(0)).rx).rxbyteisaligned;
                gem_gt_trig0_rx_data_arr(oh).rxbyterealign <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).trig_rx_links(0)).rx).rxbyterealign;
                gem_gt_trig0_rx_data_arr(oh).rxcommadet <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).trig_rx_links(0)).rx).rxcommadet;
                gem_gt_trig0_rx_data_arr(oh).rxdisperr <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).trig_rx_links(0)).rx).rxdisperr(1 downto 0);
                gem_gt_trig0_rx_data_arr(oh).rxnotintable <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).trig_rx_links(0)).rx).rxnotintable(1 downto 0);
                gem_gt_trig0_rx_data_arr(oh).rxchariscomma <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).trig_rx_links(0)).rx).rxchariscomma(1 downto 0);
                gem_gt_trig0_rx_data_arr(oh).rxcharisk <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).trig_rx_links(0)).rx).rxcharisk(1 downto 0);
                                         
                gem_gt_trig1_rx_data_arr(oh).rxdata <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).trig_rx_links(1)).rx).rxdata(15 downto 0);
                gem_gt_trig1_rx_data_arr(oh).rxbyteisaligned <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).trig_rx_links(1)).rx).rxbyteisaligned;
                gem_gt_trig1_rx_data_arr(oh).rxbyterealign <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).trig_rx_links(1)).rx).rxbyterealign;
                gem_gt_trig1_rx_data_arr(oh).rxcommadet <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).trig_rx_links(1)).rx).rxcommadet;
                gem_gt_trig1_rx_data_arr(oh).rxdisperr <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).trig_rx_links(1)).rx).rxdisperr(1 downto 0);
                gem_gt_trig1_rx_data_arr(oh).rxnotintable <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).trig_rx_links(1)).rx).rxnotintable(1 downto 0);
                gem_gt_trig1_rx_data_arr(oh).rxchariscomma <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).trig_rx_links(1)).rx).rxchariscomma(1 downto 0);
                gem_gt_trig1_rx_data_arr(oh).rxcharisk <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_OH_LINK_CONFIG_ARR(oh).trig_rx_links(1)).rx).rxcharisk(1 downto 0);
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
    
end gem_apex_arch;
