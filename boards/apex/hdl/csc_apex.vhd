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
use work.csc_pkg.all;
use work.axi_pkg.all;
use work.ttc_pkg.all;
use work.mgt_pkg.all;
use work.ipbus.all;
use work.ipb_addr_decode.all;
use work.ipb_sys_addr_decode.all;
use work.board_config_package.all;
use work.project_config.all;

entity csc_apex is
    generic(
        -- Firmware version, date, time, git sha (passed in by Hog)
        GLOBAL_DATE            : std_logic_vector (31 downto 0);
        GLOBAL_TIME            : std_logic_vector (31 downto 0);
        GLOBAL_VER             : std_logic_vector (31 downto 0);
        GLOBAL_SHA             : std_logic_vector (31 downto 0)        
    );
    port(
        
        -- GTY clocks
        gty_refclk0_p_i     : in  std_logic_vector(2 downto 0);
        gty_refclk0_n_i     : in  std_logic_vector(2 downto 0);
        gty_refclk1_p_i     : in  std_logic_vector(2 downto 0);
        gty_refclk1_n_i     : in  std_logic_vector(2 downto 0);
        
        -- C2C
        c2c_mgt_refclk_p_i  : in  std_logic;
        c2c_mgt_refclk_n_i  : in  std_logic;
        c2c_rxp             : in  std_logic_vector(1 downto 0);
        c2c_rxn             : in  std_logic_vector(1 downto 0);
        c2c_txp             : out std_logic_vector(1 downto 0);
        c2c_txn             : out std_logic_vector(1 downto 0)
    );
end csc_apex;

architecture csc_apex_arch of csc_apex is

    component c2c_gth_tux is
        port(
            mgtrefclk1_x0y5_p   : in  std_logic;
            mgtrefclk1_x0y5_n   : in  std_logic;
            gthrxn_int          : in  std_logic_vector(1 downto 0);
            gthrxp_int          : in  std_logic_vector(1 downto 0);
            gthtxn_int          : out std_logic_vector(1 downto 0);
            gthtxp_int          : out std_logic_vector(1 downto 0);
            
            drp_clk             : in  std_logic;
            
            c2c_channel_up      : out std_logic;
            c2c_init_clk        : out std_logic;
            c2c_mmcm_unlocked   : out std_logic;
            c2c_phy_clk         : out std_logic;
            c2c_pma_init        : in  std_logic;
            
            c2c_rx_data         : out std_logic_vector(31 downto 0);
            c2c_rx_valid        : out std_logic;
            
            c2c_tx_ready        : out std_logic;
            c2c_tx_tdata        : in  std_logic_vector(31 downto 0);
            c2c_tx_tvalid       : in  std_logic;
            c2c_do_cc           : in  std_logic;
            c2c_rxbufstatus     : out std_logic_vector(5 downto 0);
            c2c_rxclkcorcnt     : out std_logic_vector(3 downto 0);
            c2c_link_reset      : out std_logic
        );
    end component c2c_gth_tux;

    component apex_blk is
        port(
            clk_50_o          : out std_logic;
            user_axil_clk_o   : out std_logic;
            axi_reset_b_o     : out std_logic;
            clk_100_o         : out std_logic;
            c2c_link_reset    : in  std_logic;
            c2c_mmcm_unlocked : in  std_logic;
            c2c_init_clk      : in  std_logic;
            c2c_channel_up    : in  std_logic;
            c2c_phy_clk       : in  std_logic;
            c2c_tx_ready      : in  std_logic;
            c2c_rx_valid      : in  std_logic;
            c2c_rx_data       : in  std_logic_vector(31 downto 0);
            c2c_rxclkcorcnt   : in  std_logic_vector(3 downto 0);
            c2c_rxbufstatus   : in  std_logic_vector(5 downto 0);
            c2c_do_cc         : out std_logic;
            c2c_tx_tvalid     : out std_logic;
            c2c_tx_tdata      : out std_logic_vector(31 downto 0);
            c2c_pma_init      : out std_logic;
            user_axil_awaddr  : out std_logic_vector(31 downto 0);
            user_axil_awprot  : out std_logic_vector(2 downto 0);
            user_axil_awvalid : out std_logic;
            user_axil_awready : in  std_logic;
            user_axil_wdata   : out std_logic_vector(31 downto 0);
            user_axil_wstrb   : out std_logic_vector(3 downto 0);
            user_axil_wvalid  : out std_logic;
            user_axil_wready  : in  std_logic;
            user_axil_bresp   : in  std_logic_vector(1 downto 0);
            user_axil_bvalid  : in  std_logic;
            user_axil_bready  : out std_logic;
            user_axil_araddr  : out std_logic_vector(31 downto 0);
            user_axil_arprot  : out std_logic_vector(2 downto 0);
            user_axil_arvalid : out std_logic;
            user_axil_arready : in  std_logic;
            user_axil_rdata   : in  std_logic_vector(31 downto 0);
            user_axil_rresp   : in  std_logic_vector(1 downto 0);
            user_axil_rvalid  : in  std_logic;
            user_axil_rready  : out std_logic
        );
    end component apex_blk;

    -- constants
    constant IPB_CLK_PERIOD_NS  : integer := 10;

    -- resets 
    signal usr_logic_reset      : std_logic;
   
    -- clocks
    signal refclk0              : std_logic_vector(CFG_NUM_REFCLK0 - 1 downto 0);
    signal refclk1              : std_logic_vector(CFG_NUM_REFCLK1 - 1 downto 0);
    signal refclk0_fabric       : std_logic_vector(CFG_NUM_REFCLK0 - 1 downto 0);
    signal refclk1_fabric       : std_logic_vector(CFG_NUM_REFCLK1 - 1 downto 0);
    
    -- qsfp mgts
    signal mgt_master_txoutclk  : t_mgt_master_clks;
    signal mgt_master_txusrclk  : t_mgt_master_clks;
    signal mgt_master_rxusrclk  : t_mgt_master_clks;
    
    signal mgt_status_arr       : t_mgt_status_arr(CFG_MGT_NUM_CHANNELS downto 0);
    signal mgt_ctrl_arr         : t_mgt_ctrl_arr(CFG_MGT_NUM_CHANNELS downto 0) := (others => (txreset => '0', rxreset => '0', rxslide => '0'));
    
    signal mgt_tx_data_arr      : t_mgt_64b_tx_data_arr(CFG_MGT_NUM_CHANNELS downto 0) := (others => MGT_64B_TX_DATA_NULL);
    signal mgt_rx_data_arr      : t_mgt_64b_rx_data_arr(CFG_MGT_NUM_CHANNELS downto 0);

    signal mgt_tx_usrclk_arr    : std_logic_vector(CFG_MGT_NUM_CHANNELS downto 0);
    signal mgt_rx_usrclk_arr    : std_logic_vector(CFG_MGT_NUM_CHANNELS downto 0);    
    
    -- ttc
    signal ttc_clks             : t_ttc_clks;
    signal ttc_clk_status       : t_ttc_clk_status;
    signal ttc_clk_ctrl         : t_ttc_clk_ctrl_arr(CFG_NUM_SLRS - 1 downto 0);
    signal ttc_cmds             : t_ttc_cmds_arr(CFG_NUM_SLRS - 1 downto 0) := (others => (others => '0'));
    signal ttc_tx_mgt_data      : t_mgt_16b_tx_data;

    -- c2c
    signal c2c_channel_up       : std_logic;
    signal c2c_init_clk         : std_logic;
    signal c2c_mmcm_unlocked    : std_logic;
    signal c2c_phy_clk          : std_logic;
    signal c2c_pma_init         : std_logic;
    signal c2c_rx_data          : std_logic_vector(31 downto 0);
    signal c2c_rx_valid         : std_logic;
    signal c2c_tx_ready         : std_logic;
    signal c2c_tx_tdata         : std_logic_vector(31 downto 0);
    signal c2c_tx_tvalid        : std_logic;
    signal c2c_do_cc            : std_logic;
    signal c2c_rxbufstatus      : std_logic_vector(5 downto 0);
    signal c2c_rxclkcorcnt      : std_logic_vector(3 downto 0);
    signal c2c_link_reset       : std_logic;
    
    -- slow control
    signal axil_clk             : std_logic;
    signal axi_reset_b          : std_logic;
    signal axil_m2s             : t_axi_lite_m2s;
    signal axil_s2m             : t_axi_lite_s2m;
    signal ipb_reset            : std_logic;
    signal ipb_clk              : std_logic;
    signal ipb_usr_miso_arr     : ipb_rbus_array(CFG_NUM_SLRS * C_NUM_IPB_SLAVES - 1 downto 0) := (others => IPB_S2M_NULL);
    signal ipb_usr_mosi_arr     : ipb_wbus_array(CFG_NUM_SLRS * C_NUM_IPB_SLAVES - 1 downto 0);
    signal ipb_sys_miso_arr     : ipb_rbus_array(C_NUM_IPB_SYS_SLAVES - 1 downto 0) := (others => IPB_S2M_NULL);
    signal ipb_sys_mosi_arr     : ipb_wbus_array(C_NUM_IPB_SYS_SLAVES - 1 downto 0);
      
    -- DAQ and other
    signal clk_50               : std_logic;
    signal clk_100              : std_logic;
    signal slink_mgt_ref_clk    : std_logic;
    signal board_id             : std_logic_vector(15 downto 0);
      
    -------------------- DAQ links ---------------------------------
    signal daq_to_daqlink           : t_daq_to_daqlink_arr(CFG_NUM_SLRS - 1 downto 0);
    signal daqlink_to_daq           : t_daqlink_to_daq_arr(CFG_NUM_SLRS - 1 downto 0) := (others => DAQLINK_TO_DAQ_NULL);

    -------------------- PROMless ---------------------------------
    signal to_promless              : t_to_promless_arr(CFG_NUM_SLRS - 1 downto 0) := (others => TO_PROMLESS_NULL);
    signal from_promless            : t_from_promless_arr(CFG_NUM_SLRS - 1 downto 0) := (others =>FROM_PROMLESS_NULL);
   
begin
    
    --================================--
    -- APEX C2C
    --================================--

    i_apex_c2c_mgt : c2c_gth_tux
        port map(
            mgtrefclk1_x0y5_p => c2c_mgt_refclk_p_i,
            mgtrefclk1_x0y5_n => c2c_mgt_refclk_n_i,
            gthrxn_int        => c2c_rxn,
            gthrxp_int        => c2c_rxp,
            gthtxn_int        => c2c_txn,
            gthtxp_int        => c2c_txp,
            drp_clk           => clk_50,
            c2c_channel_up    => c2c_channel_up,
            c2c_init_clk      => c2c_init_clk,
            c2c_mmcm_unlocked => c2c_mmcm_unlocked,
            c2c_phy_clk       => c2c_phy_clk,
            c2c_pma_init      => c2c_pma_init,
            c2c_rx_data       => c2c_rx_data,
            c2c_rx_valid      => c2c_rx_valid,
            c2c_tx_ready      => c2c_tx_ready,
            c2c_tx_tdata      => c2c_tx_tdata,
            c2c_tx_tvalid     => c2c_tx_tvalid,
            c2c_do_cc         => c2c_do_cc,
            c2c_rxbufstatus   => c2c_rxbufstatus,
            c2c_rxclkcorcnt   => c2c_rxclkcorcnt,
            c2c_link_reset    => c2c_link_reset
        );

    i_apex_c2c : apex_blk
        port map(
            c2c_link_reset    => c2c_link_reset,
            c2c_mmcm_unlocked => c2c_mmcm_unlocked,
            c2c_init_clk      => c2c_init_clk,
            c2c_channel_up    => c2c_channel_up,
            c2c_phy_clk       => c2c_phy_clk,
            c2c_tx_ready      => c2c_tx_ready,
            c2c_rx_valid      => c2c_rx_valid,
            c2c_rx_data       => c2c_rx_data,
            c2c_rxclkcorcnt   => c2c_rxclkcorcnt,
            c2c_rxbufstatus   => c2c_rxbufstatus,
            c2c_do_cc         => c2c_do_cc,
            c2c_tx_tvalid     => c2c_tx_tvalid,
            c2c_tx_tdata      => c2c_tx_tdata,
            c2c_pma_init      => c2c_pma_init,
            axi_reset_b_o     => axi_reset_b,
            user_axil_clk_o   => axil_clk,
            user_axil_awaddr  => axil_m2s.awaddr,
            user_axil_awprot  => axil_m2s.awprot,
            user_axil_awvalid => axil_m2s.awvalid,
            user_axil_awready => axil_s2m.awready,
            user_axil_wdata   => axil_m2s.wdata,
            user_axil_wstrb   => axil_m2s.wstrb,
            user_axil_wvalid  => axil_m2s.wvalid,
            user_axil_wready  => axil_s2m.wready,
            user_axil_bresp   => axil_s2m.bresp,
            user_axil_bvalid  => axil_s2m.bvalid,
            user_axil_bready  => axil_m2s.bready,
            user_axil_araddr  => axil_m2s.araddr,
            user_axil_arprot  => axil_m2s.arprot,
            user_axil_arvalid => axil_m2s.arvalid,
            user_axil_arready => axil_s2m.arready,
            user_axil_rdata   => axil_s2m.rdata,
            user_axil_rresp   => axil_s2m.rresp,
            user_axil_rvalid  => axil_s2m.rvalid,
            user_axil_rready  => axil_m2s.rready,
            clk_100_o         => clk_100,
            clk_50_o          => clk_50
        );

    --================================--
    -- IPbus / wishbone
    --================================--

    i_axi_ipbus_bridge : entity work.axi_ipbus_bridge
        generic map(
            g_NUM_USR_BLOCKS => CFG_NUM_SLRS,
            g_USR_BLOCK_SEL_BIT_TOP => 25,
            g_USR_BLOCK_SEL_BIT_BOT => 24,
            g_DEBUG => true,
            g_IPB_CLK_ASYNC => false,
            g_IPB_TIMEOUT => 6000
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

    i_ttc_clks : entity work.ttc_clocks
        generic map(
            g_GEM_STATION               => 1,
            g_LPGBT_2P56G_LOOPBACK_TEST => false,
            g_CLK_STABLE_FREQ           => 100_000_000
        )
        port map(
            clk_stable_i        => axil_clk,
            clk_gbt_mgt_txout_i => mgt_master_txoutclk.gbt,
            clk_gbt_mgt_ready_i => '1',
            clocks_o            => ttc_clks,
            ctrl_i              => ttc_clk_ctrl(0),
            status_o            => ttc_clk_status
        );

    --================================--
    -- MGTs
    --================================--

    i_mgts : entity work.mgt_links_gty
        generic map(
            g_NUM_REFCLK0       => CFG_NUM_REFCLK0,
            g_NUM_REFCLK1       => CFG_NUM_REFCLK1,
            g_NUM_CHANNELS      => CFG_MGT_NUM_CHANNELS,
            g_LINK_CONFIG       => CFG_MGT_LINK_CONFIG,
            g_STABLE_CLK_PERIOD => 10,
            g_IPB_CLK_PERIOD_NS => IPB_CLK_PERIOD_NS
        )
        port map(
            reset_i              => '0',
            clk_stable_i         => axil_clk,

            refclk0_p_i          => gty_refclk0_p_i,
            refclk0_n_i          => gty_refclk0_n_i,
            refclk1_p_i          => gty_refclk1_p_i,
            refclk1_n_i          => gty_refclk1_n_i,
            refclk0_fabric_o     => refclk0_fabric,
            refclk1_fabric_o     => refclk1_fabric,
            refclk0_o            => refclk0,
            refclk1_o            => refclk1,
            
            ttc_clks_i           => ttc_clks,
            ttc_clks_locked_i    => ttc_clk_status.mmcm_locked,
            ttc_clks_reset_o     => open,

            status_arr_o         => mgt_status_arr(CFG_MGT_NUM_CHANNELS - 1 downto 0),
            ctrl_arr_i           => mgt_ctrl_arr(CFG_MGT_NUM_CHANNELS - 1 downto 0),
            tx_data_arr_i        => mgt_tx_data_arr(CFG_MGT_NUM_CHANNELS - 1 downto 0),
            rx_data_arr_o        => mgt_rx_data_arr(CFG_MGT_NUM_CHANNELS - 1 downto 0),
            tx_usrclk_arr_o      => mgt_tx_usrclk_arr(CFG_MGT_NUM_CHANNELS - 1 downto 0),
            rx_usrclk_arr_o      => mgt_rx_usrclk_arr(CFG_MGT_NUM_CHANNELS - 1 downto 0),
            
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
            q_REF_CLK_FREQ      => "156.25",
            g_MGT_TYPE          => "GTY",
            g_IPB_CLK_PERIOD_NS => IPB_CLK_PERIOD_NS
        )
        port map(
            reset_i          => '0',
            clk_stable_100_i => clk_100,
            mgt_ref_clk_i    => slink_mgt_ref_clk,

            daqlink_to_daq_o => daqlink_to_daq,
            daq_to_daqlink_i => daq_to_daqlink,

            ipb_reset_i      => ipb_reset,
            ipb_clk_i        => ipb_clk,
            ipb_mosi_i       => ipb_sys_mosi_arr(C_IPB_SYS_SLV.slink),
            ipb_miso_o       => ipb_sys_miso_arr(C_IPB_SYS_SLV.slink)
        );

    slink_mgt_ref_clk <= refclk1(2);

    --================================--
    -- PROMless
    --================================--

    i_promless : entity work.promless
        generic map(
            g_NUM_CHANNELS => CFG_NUM_SLRS,
            g_MAX_SIZE_BYTES   => 4_194_304, --4_718_592, -- max on KU15P is 36Mb (ge21.200 OH firmware with TMR does not fit), ideally we would like to have at least 8_388_608
            g_MEMORY_PRIMITIVE => "ultra",
            g_IPB_CLK_PERIOD_NS => IPB_CLK_PERIOD_NS
        )
        port map(
            reset_i         => '0',
            to_promless_i   => to_promless,
            from_promless_o => from_promless,
            ipb_reset_i     => ipb_reset,
            ipb_clk_i       => ipb_clk,
            ipb_miso_o      => ipb_sys_miso_arr(C_IPB_SYS_SLV.promless),
            ipb_mosi_i      => ipb_sys_mosi_arr(C_IPB_SYS_SLV.promless)
        );
    
    --================================--
    -- Board System registers
    --================================--

    i_board_system : entity work.board_system
        generic map(
            g_FW_DATE           => GLOBAL_DATE,
            g_FW_TIME           => GLOBAL_TIME,
            g_FW_VER            => GLOBAL_VER,
            g_FW_SHA            => GLOBAL_SHA,
            g_IPB_CLK_PERIOD_NS => IPB_CLK_PERIOD_NS
        )
        port map(
            reset_i             => '0',
            ttc_clk40_i         => ttc_clks.clk_40,
            board_id_o          => board_id,
            usr_logic_reset_o   => usr_logic_reset,
            ttc_reset_o         => open,
            ext_trig_en_o       => open,
            ext_trig_deadtime_o => open,
            ext_trig_source_o   => open,
            ext_clk_out_en_o    => open,
            ipb_reset_i         => ipb_reset,
            ipb_clk_i           => ipb_clk,
            ipb_mosi_i          => ipb_sys_mosi_arr(C_IPB_SYS_SLV.system),
            ipb_miso_o          => ipb_sys_miso_arr(C_IPB_SYS_SLV.system)
        );

    --================================--
    -- TTC TX module
    --================================--

    i_ttc_tx : entity work.ttc_tx
        generic map(
            g_IPB_CLK_PERIOD_NS => IPB_CLK_PERIOD_NS
        )
        port map(
            reset_i      => '0',
            ttc_clocks_i => ttc_clks,
            ttc_cmds_i   => ttc_cmds(CFG_TTC_TX_SOURCE_SLR),
            ttc_data_o   => ttc_tx_mgt_data,
            ipb_reset_i  => ipb_reset,
            ipb_clk_i    => ipb_clk,
            ipb_miso_o   => ipb_sys_miso_arr(C_IPB_SYS_SLV.ttc_tx),
            ipb_mosi_i   => ipb_sys_mosi_arr(C_IPB_SYS_SLV.ttc_tx)
        );
        
    --================================--
    -- CSC Logic
    --================================--

    g_slrs : for slr in 0 to CFG_NUM_SLRS - 1 generate
    
        -- DMB links
        signal csc_dmb_rx_usrclk_arr    : std_logic_vector(CFG_NUM_DMBS(slr) - 1 downto 0);
        signal csc_dmb_rx_data_arr      : t_mgt_16b_rx_data_arr(CFG_NUM_DMBS(slr) - 1 downto 0);
        signal csc_dmb_rx_status_arr    : t_mgt_status_arr(CFG_NUM_DMBS(slr) - 1 downto 0);
        
        -- GBT links
        signal csc_gbt_rx_data_arr   : t_std40_array(CFG_NUM_GBT_LINKS(slr) - 1 downto 0);
        signal csc_gbt_tx_data_arr   : t_std40_array(CFG_NUM_GBT_LINKS(slr) - 1 downto 0);
        signal csc_gbt_rx_clk_arr    : std_logic_vector(CFG_NUM_GBT_LINKS(slr) - 1 downto 0);
        signal csc_gbt_tx_clk_arr    : std_logic_vector(CFG_NUM_GBT_LINKS(slr) - 1 downto 0);
    
        signal csc_gbt_ctrl_arr      : t_mgt_ctrl_arr(CFG_NUM_GBT_LINKS(slr) - 1 downto 0);
        signal csc_gbt_status_arr    : t_mgt_status_arr(CFG_NUM_GBT_LINKS(slr) - 1 downto 0);
        
        -- Spy readout link
        signal csc_spy_usrclk           : std_logic;
        signal csc_spy_rx_data          : t_mgt_16b_rx_data;
        signal csc_spy_tx_data          : t_mgt_16b_tx_data;
        signal csc_spy_rx_status        : t_mgt_status;
        
    begin

        i_csc_fed : entity work.csc_fed
            generic map(
                g_SLR               => slr,
                g_NUM_OF_DMBs       => CFG_NUM_DMBS(slr),
                g_NUM_GBT_LINKS     => CFG_NUM_GBT_LINKS(slr),
                g_NUM_IPB_SLAVES    => C_NUM_IPB_SLAVES,
                g_IPB_CLK_PERIOD_NS => IPB_CLK_PERIOD_NS,
                g_DAQLINK_CLK_FREQ  => 100_000_000,
                g_USE_SLINK_ROCKET  => true,
                g_DISABLE_TTC_DATA  => true
            )
            port map(
                -- Resets
                reset_i                 => usr_logic_reset,
                reset_pwrup_o           => open,
                
                -- TTC
                ttc_clocks_i            => ttc_clks,
                ttc_clk_status_i        => ttc_clk_status,
                ttc_clk_ctrl_o          => ttc_clk_ctrl(slr),
                ttc_data_p_i            => '1',
                ttc_data_n_i            => '0',
                external_trigger_i      => '0',
                ttc_cmds_o              => ttc_cmds(slr),
                
                -- DMB links
                dmb_rx_usrclk_i         => mgt_master_rxusrclk.dmb,
                dmb_rx_data_arr_i       => csc_dmb_rx_data_arr,
                dmb_rx_status_arr_i     => csc_dmb_rx_status_arr,
    
                -- GBT links
                gbt_rx_data_arr_i       => csc_gbt_rx_data_arr,
                gbt_tx_data_arr_o       => csc_gbt_tx_data_arr,
                gbt_rx_clk_arr_i        => csc_gbt_rx_clk_arr,
                gbt_tx_clk_arr_i        => csc_gbt_tx_clk_arr,
                gbt_rx_common_clk_i     => mgt_master_rxusrclk.gbt,

                gbt_status_arr_i        => csc_gbt_status_arr,
                gbt_ctrl_arr_o          => csc_gbt_ctrl_arr,
    
                -- Spy link
                spy_usrclk_i            => csc_spy_usrclk,
                spy_rx_data_i           => csc_spy_rx_data,
                spy_tx_data_o           => csc_spy_tx_data,
                spy_rx_status_i         => csc_spy_rx_status,
                
                -- IPbus
                ipb_reset_i             => ipb_reset,
                ipb_clk_i               => ipb_clk,
                ipb_miso_arr_o          => ipb_usr_miso_arr((slr + 1) * C_NUM_IPB_SLAVES - 1 downto slr * C_NUM_IPB_SLAVES),
                ipb_mosi_arr_i          => ipb_usr_mosi_arr((slr + 1) * C_NUM_IPB_SLAVES - 1 downto slr * C_NUM_IPB_SLAVES),
    
                -- DAQLink
                daqlink_clk_i           => clk_100,
                daqlink_clk_locked_i    => '1',
                daq_to_daqlink_o        => daq_to_daqlink(slr),
                daqlink_to_daq_i        => daqlink_to_daq(slr),
                
                -- Board ID
                board_id_i              => board_id,
                
                -- PROMless
                to_promless_o           => to_promless(slr),
                from_promless_i         => from_promless(slr)          
            );

        -- DMB link mapping (for now only single link DMBs are supported)
        g_csc_dmb_links : for i in 0 to CFG_NUM_DMBS(slr) - 1 generate
            csc_dmb_rx_usrclk_arr(i)               <= mgt_rx_usrclk_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(slr)(i).rx_fibers(0)).rx);
            csc_dmb_rx_data_arr(i).rxdata          <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(slr)(i).rx_fibers(0)).rx).rxdata(15 downto 0);
            csc_dmb_rx_data_arr(i).rxbyteisaligned <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(slr)(i).rx_fibers(0)).rx).rxbyteisaligned;
            csc_dmb_rx_data_arr(i).rxbyterealign   <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(slr)(i).rx_fibers(0)).rx).rxbyterealign;
            csc_dmb_rx_data_arr(i).rxcommadet      <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(slr)(i).rx_fibers(0)).rx).rxcommadet;
            csc_dmb_rx_data_arr(i).rxdisperr       <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(slr)(i).rx_fibers(0)).rx).rxdisperr(1 downto 0);
            csc_dmb_rx_data_arr(i).rxnotintable    <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(slr)(i).rx_fibers(0)).rx).rxnotintable(1 downto 0);
            csc_dmb_rx_data_arr(i).rxchariscomma   <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(slr)(i).rx_fibers(0)).rx).rxchariscomma(1 downto 0);
            csc_dmb_rx_data_arr(i).rxcharisk       <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(slr)(i).rx_fibers(0)).rx).rxcharisk(1 downto 0);
            csc_dmb_rx_status_arr(i)               <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(slr)(i).rx_fibers(0)).rx);
            
            -- send some dummy data on the TX of the same fiber
            mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(slr)(i).tx_fiber).tx) <= (txdata => x"00000000000050bc", txcharisk => x"01", txchardispmode => x"00", txchardispval => x"00");
        end generate; 

        g_csc_gbt_links : for gbt in 0 to CFG_NUM_GBT_LINKS(slr) - 1 generate
            csc_gbt_rx_data_arr(gbt) <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_GBT_LINK_CONFIG_ARR(slr)(gbt).rx_fiber).rx).rxdata(39 downto 0);
            csc_gbt_rx_clk_arr(gbt) <= mgt_rx_usrclk_arr(CFG_FIBER_TO_MGT_MAP(CFG_GBT_LINK_CONFIG_ARR(slr)(gbt).rx_fiber).rx);
            mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_GBT_LINK_CONFIG_ARR(slr)(gbt).tx_fiber).tx).txdata(39 downto 0) <= csc_gbt_tx_data_arr(gbt);
            csc_gbt_tx_clk_arr(gbt) <= mgt_tx_usrclk_arr(CFG_FIBER_TO_MGT_MAP(CFG_GBT_LINK_CONFIG_ARR(slr)(gbt).tx_fiber).tx);
            mgt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_GBT_LINK_CONFIG_ARR(slr)(gbt).tx_fiber).tx).txreset <= csc_gbt_ctrl_arr(gbt).txreset;
            mgt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_GBT_LINK_CONFIG_ARR(slr)(gbt).rx_fiber).rx).rxreset <= csc_gbt_ctrl_arr(gbt).rxreset;
            mgt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_GBT_LINK_CONFIG_ARR(slr)(gbt).rx_fiber).rx).rxslide <= csc_gbt_ctrl_arr(gbt).rxslide;
            csc_gbt_status_arr(gbt).tx_reset_done  <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_GBT_LINK_CONFIG_ARR(slr)(gbt).tx_fiber).tx).tx_reset_done;
            csc_gbt_status_arr(gbt).tx_pll_locked <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_GBT_LINK_CONFIG_ARR(slr)(gbt).tx_fiber).tx).tx_pll_locked;
            csc_gbt_status_arr(gbt).rx_reset_done  <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_GBT_LINK_CONFIG_ARR(slr)(gbt).rx_fiber).rx).rx_reset_done;
            csc_gbt_status_arr(gbt).rx_pll_locked <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_GBT_LINK_CONFIG_ARR(slr)(gbt).rx_fiber).rx).rx_pll_locked;
        end generate;

        -- spy link TX mapping
        g_spy_link_tx : if CFG_USE_SPY_LINK_TX(slr) generate
            csc_spy_usrclk                  <= mgt_tx_usrclk_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(slr)).tx);
            mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(slr)).tx).txdata(15 downto 0) <= csc_spy_tx_data.txdata;
            mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(slr)).tx).txcharisk(1 downto 0) <= csc_spy_tx_data.txcharisk;
            mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(slr)).tx).txchardispval(1 downto 0) <= csc_spy_tx_data.txchardispval;
            mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(slr)).tx).txchardispmode(1 downto 0) <= csc_spy_tx_data.txchardispmode;
        end generate;

        -- no spy link TX
        g_no_spy_link_tx : if not CFG_USE_SPY_LINK_TX(slr) generate
            csc_spy_usrclk <= '0';
        end generate;

        -- spy link RX mapping
        g_spy_link_rx : if CFG_USE_SPY_LINK_RX(slr) generate
            csc_spy_rx_data.rxdata          <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(slr)).rx).rxdata(15 downto 0);
            csc_spy_rx_data.rxbyteisaligned <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(slr)).rx).rxbyteisaligned;
            csc_spy_rx_data.rxbyterealign   <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(slr)).rx).rxbyterealign;
            csc_spy_rx_data.rxcommadet      <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(slr)).rx).rxcommadet;
            csc_spy_rx_data.rxdisperr       <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(slr)).rx).rxdisperr(1 downto 0);
            csc_spy_rx_data.rxnotintable    <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(slr)).rx).rxnotintable(1 downto 0);
            csc_spy_rx_data.rxchariscomma   <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(slr)).rx).rxchariscomma(1 downto 0);
            csc_spy_rx_data.rxcharisk       <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(slr)).rx).rxcharisk(1 downto 0);
            csc_spy_rx_status               <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK(slr)).rx);
        end generate;

        -- no spy link RX
        g_no_spy_link_rx : if not CFG_USE_SPY_LINK_RX(slr) generate
            csc_spy_rx_data     <= MGT_16B_RX_DATA_NULL;
            csc_spy_rx_status   <= MGT_STATUS_NULL;
        end generate;
                    
    end generate;

    -- TTC TX links
    g_use_ttc_links : if CFG_USE_TTC_TX_LINK generate
        g_ttc_links : for i in CFG_TTC_LINKS'range generate
            signal rx_link_data     : t_mgt_16b_rx_data;
            signal rx_link_status   : t_mgt_status; 
        begin
            mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_TTC_LINKS(i)).tx).txdata(15 downto 0) <= ttc_tx_mgt_data.txdata;
            mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_TTC_LINKS(i)).tx).txchardispmode <= (others => '0');
            mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_TTC_LINKS(i)).tx).txchardispval <= (others => '0');
            mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_TTC_LINKS(i)).tx).txcharisk <= (others => '0');
            mgt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_TTC_LINKS(i)).tx).txreset <= '0';
            mgt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_TTC_LINKS(i)).rx).rxreset <= '0';
            mgt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_TTC_LINKS(i)).rx).rxslide <= '0';
            
            rx_link_data.rxdata <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_TTC_LINKS(i)).rx).rxdata(15 downto 0);
            rx_link_data.rxbyteisaligned <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_TTC_LINKS(i)).rx).rxbyteisaligned;
            rx_link_data.rxbyterealign <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_TTC_LINKS(i)).rx).rxbyterealign;
            rx_link_data.rxcommadet <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_TTC_LINKS(i)).rx).rxcommadet;
            rx_link_data.rxdisperr <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_TTC_LINKS(i)).rx).rxdisperr(1 downto 0);  
            rx_link_data.rxnotintable <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_TTC_LINKS(i)).rx).rxnotintable(1 downto 0);  
            rx_link_data.rxchariscomma <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_TTC_LINKS(i)).rx).rxchariscomma(1 downto 0);  
            rx_link_data.rxcharisk <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_TTC_LINKS(i)).rx).rxcharisk(1 downto 0);     
            
            rx_link_status <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_TTC_LINKS(i)).rx);     
                        
            i_ila_ttc_rx_link : entity work.ila_mgt_rx_16b_wrapper
                port map(
                    clk_i        => mgt_rx_usrclk_arr(CFG_FIBER_TO_MGT_MAP(CFG_TTC_LINKS(i)).rx),
                    rx_data_i    => rx_link_data,
                    mgt_status_i => rx_link_status
                );            
        end generate;
    end generate;
        
end csc_apex_arch;
