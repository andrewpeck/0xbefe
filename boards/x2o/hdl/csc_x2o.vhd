------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
--
-- Create Date:    2020-05-28
-- Module Name:    GEM_X2O
-- Description:    This is the top level of the GEM X2O project
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

entity csc_x2o is
    generic(
        -- Firmware version, date, time, git sha (passed in by Hog)
        GLOBAL_DATE     : std_logic_vector (31 downto 0);
        GLOBAL_TIME     : std_logic_vector (31 downto 0);
        GLOBAL_VER      : std_logic_vector (31 downto 0);
        GLOBAL_SHA      : std_logic_vector (31 downto 0)
    );
    port(
        c2c_mgt_clk_p   : in std_logic;
        c2c_mgt_clk_n   : in std_logic;
 
        tcds2_backplane_clk_p   : in  std_logic;
        tcds2_backplane_clk_n   : in  std_logic;
 
        tcds2_mgt_tx_p          : out std_logic;
        tcds2_mgt_tx_n          : out std_logic;
        tcds2_mgt_rx_p          : in  std_logic;
        tcds2_mgt_rx_n          : in  std_logic;
 
        lmk_refclk_0_p          : out std_logic;
        lmk_refclk_0_n          : out std_logic;
        lmk_refclk_1_p          : out std_logic;
        lmk_refclk_1_n          : out std_logic;
 
        refclk0_p_i     : in  std_logic_vector(CFG_NUM_REFCLK0 - 1 downto 0); -- async 156.25MHz clocks (one per quad)
        refclk0_n_i     : in  std_logic_vector(CFG_NUM_REFCLK0 - 1 downto 0);
        refclk1_p_i     : in  std_logic_vector(CFG_NUM_REFCLK1 - 1 downto 0);  -- sync clocks
        refclk1_n_i     : in  std_logic_vector(CFG_NUM_REFCLK1 - 1 downto 0)
    );
end csc_x2o;

architecture csc_x2o_arch of csc_x2o is

    component framework is
        port(
            clk_50_o          : out std_logic;
            clk_100_o         : out std_logic;
            clk_125_o         : out std_logic;
            user_axil_clk_o   : out std_logic;
            axi_reset_b_o     : out std_logic;
            user_axil_araddr  : out std_logic_vector(31 downto 0);
            user_axil_arprot  : out std_logic_vector(2 downto 0);
            user_axil_arready : in  std_logic;
            user_axil_arvalid : out std_logic;
            user_axil_awaddr  : out std_logic_vector(31 downto 0);
            user_axil_awprot  : out std_logic_vector(2 downto 0);
            user_axil_awready : in  std_logic;
            user_axil_awvalid : out std_logic;
            user_axil_bready  : out std_logic;
            user_axil_bresp   : in  std_logic_vector(1 downto 0);
            user_axil_bvalid  : in  std_logic;
            user_axil_rdata   : in  std_logic_vector(31 downto 0);
            user_axil_rready  : out std_logic;
            user_axil_rresp   : in  std_logic_vector(1 downto 0);
            user_axil_rvalid  : in  std_logic;
            user_axil_wdata   : out std_logic_vector(31 downto 0);
            user_axil_wready  : in  std_logic;
            user_axil_wstrb   : out std_logic_vector(3 downto 0);
            user_axil_wvalid  : out std_logic;
            c2c_mgt_clk_p     : in  std_logic;
            c2c_mgt_clk_n     : in  std_logic
        );
    end component framework;

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
    signal mgt_refclks          : t_mgt_refclks_arr(CFG_MGT_NUM_CHANNELS - 1 downto 0);
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
    signal clk_125              : std_logic;
    signal slink_mgt_ref_clk    : std_logic;
    signal board_id             : std_logic_vector(15 downto 0);

    -------------------- DAQ links ---------------------------------
    signal daq_to_daqlink           : t_daq_to_daqlink_arr(CFG_NUM_SLRS - 1 downto 0);
    signal daqlink_to_daq           : t_daqlink_to_daq_arr(CFG_NUM_SLRS - 1 downto 0) := (others => DAQLINK_TO_DAQ_NULL);

    -------------------- PROMless ---------------------------------
    signal to_promless_cfeb         : t_to_promless_arr(CFG_NUM_SLRS - 1 downto 0) := (others => TO_PROMLESS_NULL);
    signal from_promless_cfeb       : t_from_promless_arr(CFG_NUM_SLRS - 1 downto 0) := (others =>FROM_PROMLESS_NULL);
    signal to_promless_alct         : t_to_promless_arr(CFG_NUM_SLRS - 1 downto 0) := (others => TO_PROMLESS_NULL);
    signal from_promless_alct       : t_from_promless_arr(CFG_NUM_SLRS - 1 downto 0) := (others =>FROM_PROMLESS_NULL);

begin

    --================================--
    -- C2C
    --================================--

    i_x2o_framework : framework
        port map(
            c2c_mgt_clk_p     => c2c_mgt_clk_p,
            c2c_mgt_clk_n     => c2c_mgt_clk_n,
            clk_50_o          => clk_50,
            clk_100_o         => clk_100,
            clk_125_o         => clk_125,
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
            axi_reset_b_o     => axi_reset_b
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



    --================================--
    -- TTC / TCDS2
    --================================--

    assert CFG_BOARD_TYPE = x"4" or CFG_BOARD_TYPE = x"5" report "Unknown X2O revision: board type is not equal to 4 (X2O rev1) or 5 (X2O rev2)" severity failure;

    g_x2o_rev1 : if CFG_BOARD_TYPE = x"4" generate 
        i_ttc_clks : entity work.ttc_clocks
            generic map(
                g_CLK_STABLE_FREQ           => 100_000_000,
                g_GEM_STATION               => 1,
                g_LPGBT_2P56G_LOOPBACK_TEST => false,
                g_TXPROGDIVCLK_USED         => not is_refclk_160_lhc(CFG_MGT_GBTX.tx_refclk_freq)
            )
            port map(
                clk_stable_i        => axil_clk,
                clk_gbt_mgt_txout_i => mgt_master_txoutclk.gbt,
                clk_gbt_mgt_ready_i => '1',
                clocks_o            => ttc_clks,
                ctrl_i              => ttc_clk_ctrl(0),
                status_o            => ttc_clk_status
            );
    end generate;
    
    g_x2o_rev2 : if CFG_BOARD_TYPE = x"5" generate 
        i_tcds2 : entity work.tcds2
            generic map(
                G_USE_40MHZ_CLEANED_IN => true
            )
            port map(
                reset_i             => '0',
                clk_125_i           => clk_125,
                mgt_tx_p_o          => tcds2_mgt_tx_p,
                mgt_tx_n_o          => tcds2_mgt_tx_n,
                mgt_rx_p_i          => tcds2_mgt_rx_p,
                mgt_rx_n_i          => tcds2_mgt_rx_n,
                mgt_refclk_320_i    => refclk1(CFG_TCDS2_MGT_REFCLK1),
                clk40_cleaned_i     => refclk1_fabric(7),
                clk_backplane_p_i   => tcds2_backplane_clk_p,
                clk_backplane_n_i   => tcds2_backplane_clk_n,
                clk40_out_pri_p_o   => lmk_refclk_0_p,
                clk40_out_pri_n_o   => lmk_refclk_0_n,
                clk40_out_sec_p_o   => lmk_refclk_1_p,
                clk40_out_sec_n_o   => lmk_refclk_1_n,
                ttc_clks_o          => ttc_clks,
                ttc_cmds_o          => open, --ttc_cmds,
                clk_ctrl_i          => ttc_clk_ctrl(0),
                clk_status_o        => ttc_clk_status
            );
    end generate;
    
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

            refclk0_p_i          => refclk0_p_i,
            refclk0_n_i          => refclk0_n_i,
            refclk1_p_i          => refclk1_p_i,
            refclk1_n_i          => refclk1_n_i,
            refclk0_o            => refclk0,
            refclk1_o            => refclk1,
            refclk0_fabric_o     => refclk0_fabric,
            refclk1_fabric_o     => refclk1_fabric,

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

--    --================================--
--    -- SLink Rocket
--    --================================--
--
--    i_slink_rocket : entity work.slink_rocket
--        generic map(
--            g_NUM_CHANNELS      => CFG_NUM_SLRS,
--            g_LINE_RATE         => "25.78125",
--            q_REF_CLK_FREQ      => "156.25",
--            g_MGT_TYPE          => "GTY",
--            g_IPB_CLK_PERIOD_NS => IPB_CLK_PERIOD_NS
--        )
--        port map(
--            reset_i          => '0',
--            clk_stable_100_i => clk_100,
--            mgt_ref_clk_i    => slink_mgt_ref_clk,
--
--            daqlink_to_daq_o => daqlink_to_daq,
--            daq_to_daqlink_i => daq_to_daqlink,
--
--            ipb_reset_i      => ipb_reset,
--            ipb_clk_i        => ipb_clk,
--            ipb_mosi_i       => ipb_sys_mosi_arr(C_IPB_SYS_SLV.slink),
--            ipb_miso_o       => ipb_sys_miso_arr(C_IPB_SYS_SLV.slink)
--        );
--
--    slink_mgt_ref_clk <= refclk0(24);

    --================================--
    -- PROMless
    --================================--

    ----------- XDCFEB -----------
     
    -- XDCFEBs use Virtex 6 130T for which the max number of configuration bits = 43_719_776 bits / 5_464_972 bytes (UG360)
    -- uncompressed bit file size is 5_465_085 bytes
    -- we allocate 170 * 32KB = 5440KB = 5_570_560 Bytes
    i_promless_cfeb : entity work.promless
        generic map(
            g_NUM_CHANNELS => CFG_NUM_SLRS,
            g_MAX_SIZE_BYTES   => 5_570_560,
            g_MEMORY_PRIMITIVE => "ultra",
            g_IPB_CLK_PERIOD_NS => IPB_CLK_PERIOD_NS
        )
        port map(
            reset_i         => '0',
            to_promless_i   => to_promless_cfeb,
            from_promless_o => from_promless_cfeb,
            ipb_reset_i     => ipb_reset,
            ipb_clk_i       => ipb_clk,
            ipb_miso_o      => ipb_sys_miso_arr(C_IPB_SYS_SLV.promless),
            ipb_mosi_i      => ipb_sys_mosi_arr(C_IPB_SYS_SLV.promless)
        );

    ----------- ALCT -----------
     
    -- ME1/1 ALCTs use Spartan 6 LX100 for which the max number of configuration bits = 26_691_232 bits / 3_336_404 bytes (UG360)
    -- we allocate 102 * 32KB = 3264KB = 3_342_336 Bytes
    i_promless_alct : entity work.promless
        generic map(
            g_NUM_CHANNELS => CFG_NUM_SLRS,
            g_MAX_SIZE_BYTES   => 3_342_336,
            g_MEMORY_PRIMITIVE => "ultra",
            g_IPB_CLK_PERIOD_NS => IPB_CLK_PERIOD_NS
        )
        port map(
            reset_i         => '0',
            to_promless_i   => to_promless_alct,
            from_promless_o => from_promless_alct,
            ipb_reset_i     => ipb_reset,
            ipb_clk_i       => ipb_clk,
            ipb_miso_o      => ipb_sys_miso_arr(C_IPB_SYS_SLV.promless2),
            ipb_mosi_i      => ipb_sys_mosi_arr(C_IPB_SYS_SLV.promless2)
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
    -- Ethernet switch module
    --================================--
    
    g_eth_switch : if CFG_USE_ETH_SWITCH generate
        signal eth_gbe_clk      : std_logic;
        signal eth_rx_data      : t_mgt_64b_rx_data_arr(CFG_ETH_SWITCH_NUM_PORTS - 1 downto 0);
        signal eth_tx_data      : t_mgt_64b_tx_data_arr(CFG_ETH_SWITCH_NUM_PORTS - 1 downto 0);
        signal eth_mgt_status   : t_mgt_status_arr(CFG_ETH_SWITCH_NUM_PORTS - 1 downto 0);
    begin
        i_eth_switch : entity work.eth_switch
            generic map(
                g_NUM_PORTS         => CFG_ETH_SWITCH_NUM_PORTS,
                g_PORT_LINKS        => CFG_ETH_SWITCH_LINKS,
                g_ETH_PORT_ROUTES   => CFG_ETH_SWITCH_PORT_ROUTES,
                g_IPB_CLK_PERIOD_NS => IPB_CLK_PERIOD_NS,
                g_DEBUG             => true
            )
            port map(
                reset_i       => '0',
                gbe_clk_i     => eth_gbe_clk,
                mgt_rx_data_i => eth_rx_data,
                mgt_tx_data_o => eth_tx_data,
                mgt_status_i  => eth_mgt_status,
                ipb_reset_i   => ipb_reset,
                ipb_clk_i     => ipb_clk,
                ipb_miso_o    => ipb_sys_miso_arr(C_IPB_SYS_SLV.eth_switch),
                ipb_mosi_i    => ipb_sys_mosi_arr(C_IPB_SYS_SLV.eth_switch)
            );
    
        -- link mapping
        eth_gbe_clk <= mgt_tx_usrclk_arr(CFG_FIBER_TO_MGT_MAP(CFG_ETH_SWITCH_LINKS(0)).tx);
        
        g_eth_switch_links : for i in 0 to CFG_ETH_SWITCH_NUM_PORTS - 1 generate
            eth_rx_data(i) <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_ETH_SWITCH_LINKS(i)).rx);
            mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_ETH_SWITCH_LINKS(i)).tx) <= eth_tx_data(i);
            eth_mgt_status(i) <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_ETH_SWITCH_LINKS(i)).rx);
        end generate;
    
    end generate;

    --================================--
    -- CSC Logic
    --================================--

    g_slrs : for slr in 0 to CFG_NUM_SLRS - 1 generate
    
        -- DMB links
        signal csc_dmb_rx_usrclk_arr    : std_logic_vector(CFG_NUM_DMBS(slr) - 1 downto 0);
        signal csc_dmb_rx_data_arr2d    : t_mgt_64b_rx_data_arr_arr(CFG_NUM_DMBS(slr) - 1 downto 0)(3 downto 0);
        signal csc_dmb_rx_status_arr2d  : t_mgt_status_arr_arr(CFG_NUM_DMBS(slr) - 1 downto 0)(3 downto 0);
        
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
                g_DMB_CONFIG_ARR    => CFG_DMB_CONFIG_ARR(slr),
                g_NUM_GBT_LINKS     => CFG_NUM_GBT_LINKS(slr),
                g_NUM_IPB_SLAVES    => C_NUM_IPB_SLAVES,
                g_IPB_CLK_PERIOD_NS => IPB_CLK_PERIOD_NS,
                g_DAQLINK_CLK_FREQ  => 100_000_000,
                g_USE_SLINK_ROCKET  => true,
                g_EXT_TTC_RECEIVER  => true
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
                odmb_rx_usrclk_i        => mgt_master_rxusrclk.odmb57,
                dmb_rx_data_arr2d_i     => csc_dmb_rx_data_arr2d,
                dmb_rx_status_arr2d_i   => csc_dmb_rx_status_arr2d,
    
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
                to_promless_cfeb_o      => to_promless_cfeb(slr),
                from_promless_cfeb_i    => from_promless_cfeb(slr),          
                to_promless_alct_o      => to_promless_alct(slr),
                from_promless_alct_i    => from_promless_alct(slr)
            );

        -- DMB link mapping
        g_csc_dmb_links : for i in 0 to CFG_NUM_DMBS(slr) - 1 generate

            g_dmb : if CFG_DMB_CONFIG_ARR(slr)(i).dmb_type = DMB generate
                csc_dmb_rx_usrclk_arr(i) <= mgt_rx_usrclk_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(slr)(i).rx_fibers(0)).rx);
                
                csc_dmb_rx_data_arr2d(i)(0).rxdata(15 downto 0)         <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(slr)(i).rx_fibers(0)).rx).rxdata(15 downto 0);
                csc_dmb_rx_data_arr2d(i)(0).rxbyteisaligned             <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(slr)(i).rx_fibers(0)).rx).rxbyteisaligned;
                csc_dmb_rx_data_arr2d(i)(0).rxbyterealign               <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(slr)(i).rx_fibers(0)).rx).rxbyterealign;
                csc_dmb_rx_data_arr2d(i)(0).rxcommadet                  <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(slr)(i).rx_fibers(0)).rx).rxcommadet;
                csc_dmb_rx_data_arr2d(i)(0).rxdisperr(1 downto 0)       <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(slr)(i).rx_fibers(0)).rx).rxdisperr(1 downto 0);
                csc_dmb_rx_data_arr2d(i)(0).rxnotintable(1 downto 0)    <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(slr)(i).rx_fibers(0)).rx).rxnotintable(1 downto 0);
                csc_dmb_rx_data_arr2d(i)(0).rxchariscomma(1 downto 0)   <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(slr)(i).rx_fibers(0)).rx).rxchariscomma(1 downto 0);
                csc_dmb_rx_data_arr2d(i)(0).rxcharisk(1 downto 0)       <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(slr)(i).rx_fibers(0)).rx).rxcharisk(1 downto 0);
                
                csc_dmb_rx_status_arr2d(i)(0) <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(slr)(i).rx_fibers(0)).rx);
                
                -- send some dummy data on the TX of the same fiber
                mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(slr)(i).tx_fiber).tx) <= MGT_64B_TX_DATA_NULL;
            end generate;

            g_odmb7 : if CFG_DMB_CONFIG_ARR(slr)(i).dmb_type = ODMB7 generate
                csc_dmb_rx_usrclk_arr(i) <= mgt_master_rxusrclk.odmb57;
                
                g_odmb7_fiber : for f in 0 to CFG_DMB_CONFIG_ARR(slr)(i).num_fibers - 1 generate
                    csc_dmb_rx_data_arr2d(i)(f) <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(slr)(i).rx_fibers(0)).rx);
                    csc_dmb_rx_status_arr2d(i)(f) <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(slr)(i).rx_fibers(0)).rx);
                end generate;
                
                -- send some dummy data on the TX of the same fiber
                mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(slr)(i).tx_fiber).tx) <= MGT_64B_TX_DATA_NULL;
            end generate;

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
            csc_spy_usrclk <= mgt_tx_usrclk_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINKS(slr)(0)).tx);
            g_spy_links : for spy in 0 to CFG_SPY_LINKS'length(1) - 1 generate
                mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINKS(slr)(spy)).tx).txdata(15 downto 0) <= csc_spy_tx_data.txdata;
                mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINKS(slr)(spy)).tx).txcharisk(1 downto 0) <= csc_spy_tx_data.txcharisk;
                mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINKS(slr)(spy)).tx).txchardispval(1 downto 0) <= csc_spy_tx_data.txchardispval;
                mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINKS(slr)(spy)).tx).txchardispmode(1 downto 0) <= csc_spy_tx_data.txchardispmode;
            end generate;
        end generate;

        -- no spy link TX
        g_no_spy_link_tx : if not CFG_USE_SPY_LINK_TX(slr) generate
            csc_spy_usrclk <= '0';
        end generate;

        -- spy link RX mapping
        g_spy_link_rx : if CFG_USE_SPY_LINK_RX(slr) generate
            csc_spy_rx_data.rxdata          <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINKS(slr)(0)).rx).rxdata(15 downto 0);
            csc_spy_rx_data.rxbyteisaligned <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINKS(slr)(0)).rx).rxbyteisaligned;
            csc_spy_rx_data.rxbyterealign   <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINKS(slr)(0)).rx).rxbyterealign;
            csc_spy_rx_data.rxcommadet      <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINKS(slr)(0)).rx).rxcommadet;
            csc_spy_rx_data.rxdisperr       <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINKS(slr)(0)).rx).rxdisperr(1 downto 0);
            csc_spy_rx_data.rxnotintable    <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINKS(slr)(0)).rx).rxnotintable(1 downto 0);
            csc_spy_rx_data.rxchariscomma   <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINKS(slr)(0)).rx).rxchariscomma(1 downto 0);
            csc_spy_rx_data.rxcharisk       <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINKS(slr)(0)).rx).rxcharisk(1 downto 0);
            csc_spy_rx_status               <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINKS(slr)(0)).rx);
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

    -- ODMB57 loopback test
    g_odmb7_test : if CFG_ODMB57_BIDIR_TEST generate
        
        component vio_odmb57_loopback
            port(
                clk        : in  std_logic;
                probe_in0  : in  std_logic_vector(31 downto 0);
                probe_in1  : in  std_logic_vector(31 downto 0);
                probe_in2  : in  std_logic_vector(31 downto 0);
                probe_in3  : in  std_logic_vector(31 downto 0);
                probe_in4  : in  std_logic_vector(31 downto 0);
                probe_in5  : in  std_logic_vector(31 downto 0);
                probe_in6  : in  std_logic_vector(31 downto 0);
                probe_in7  : in  std_logic_vector(31 downto 0);
                probe_in8  : in  std_logic_vector(31 downto 0);
                probe_in9  : in  std_logic_vector(31 downto 0);
                probe_in10 : in  std_logic_vector(31 downto 0);
                probe_in11 : in  std_logic_vector(31 downto 0);
                probe_in12 : in  std_logic_vector(31 downto 0);
                probe_in13 : in  std_logic_vector(31 downto 0);
                probe_in14 : in  std_logic_vector(31 downto 0);
                probe_in15 : in  std_logic_vector(31 downto 0);
                probe_in16 : in  std_logic_vector(31 downto 0);
                probe_in17 : in  std_logic_vector(31 downto 0);
                probe_in18 : in  std_logic_vector(31 downto 0);
                probe_in19 : in  std_logic_vector(31 downto 0);
                probe_in20 : in  std_logic_vector(31 downto 0);
                probe_in21 : in  std_logic_vector(31 downto 0);
                probe_in22 : in  std_logic_vector(31 downto 0);
                probe_in23 : in  std_logic_vector(31 downto 0);
                probe_in24 : in  std_logic_vector(31 downto 0);
                probe_in25 : in  std_logic_vector(31 downto 0);
                probe_in26 : in  std_logic_vector(31 downto 0);
                probe_in27 : in  std_logic_vector(31 downto 0);
                probe_out0 : out std_logic;
                probe_out1 : out std_logic_vector(15 downto 0);
                probe_out2 : out std_logic;
                probe_out3 : out std_logic
            );
        end component;        
        
        component ila_mgt_tx_128b
            port(
                clk    : in std_logic;
                probe0 : in std_logic_vector(127 downto 0);
                probe1 : in std_logic_vector(15 downto 0)
            );
        end component;        
        
        component ila_mgt_rx_128b
            port(
                clk    : in std_logic;
                probe0 : in std_logic_vector(127 downto 0);
                probe1 : in std_logic_vector(15 downto 0);
                probe2 : in std_logic_vector(15 downto 0);
                probe3 : in std_logic_vector(15 downto 0);
                probe4 : in std_logic_vector(15 downto 0);
                probe5 : in std_logic;
                probe6 : in std_logic;
                probe7 : in std_logic;
                probe8 : in std_logic_vector(2 downto 0);
                probe9 : in std_logic_vector(1 downto 0)
            );
        end component;        
        
        signal o57_reset            : std_logic;
        signal link_clk             : std_logic;
        signal use_prbs             : std_logic := '1';
        signal reverse_rx_prbs      : std_logic := '1';
        
        signal tx_data              : std_logic_vector(127 downto 0);
        signal tx_charisk           : std_logic_vector(15 downto 0);
        signal rx_data              : std_logic_vector(127 downto 0);
        signal rx_byteisaligned     : std_logic_vector(3 downto 0);
        signal rx_byterealign       : std_logic_vector(3 downto 0);
        signal rx_commadet          : std_logic_vector(3 downto 0);
        signal rx_disperr           : std_logic_vector(15 downto 0);
        signal rx_notintable        : std_logic_vector(15 downto 0);
        signal rx_chariscomma       : std_logic_vector(15 downto 0);
        signal rx_charisk           : std_logic_vector(15 downto 0);
        signal rx_charisk_d1        : std_logic_vector(15 downto 0) := (others => '1');
        signal rx_charisk_d2        : std_logic_vector(15 downto 0) := (others => '1');
        signal rx_chanisaligned     : std_logic_vector(3 downto 0);
                                    
        signal idle_word_period     : std_logic_vector(15 downto 0);
        signal idle_cntdown         : integer range 0 to (2 ** 16) - 1 := 0;
        signal tx_counter           : unsigned(31 downto 0) := (others => '0');
        signal tx_prbs_data         : std_logic_vector(31 downto 0) := (others => '0');
        signal tx_prbs_en           : std_logic;
        
        signal rx_prbs_data         : t_std32_array(0 to 3) := (others => (others => '0'));
        signal rx_prbs_err_bits     : t_std32_array(0 to 3) := (others => (others => '0'));
        signal rx_prbs_err          : std_logic_vector(3 downto 0) := (others => '0');
                                    
        signal rx_counter           : unsigned(31 downto 0) := (others => '0');
        signal rx_data_err          : std_logic_vector(3 downto 0) := (others => '0');
        signal rx_data_err_cnt      : t_std32_array(3 downto 0) := (others => (others => '0'));
        signal rx_charisk_err       : std_logic_vector(3 downto 0) := (others => '0');
        signal rx_charisk_err_cnt   : t_std32_array(3 downto 0) := (others => (others => '0'));
        signal rx_notintable_err_cnt: t_std32_array(3 downto 0) := (others => (others => '0'));
        signal rx_disperr_err_cnt   : t_std32_array(3 downto 0) := (others => (others => '0'));
        signal rx_bytealign_err_cnt : t_std32_array(3 downto 0) := (others => (others => '0'));
        signal rx_chanalign_err_cnt : t_std32_array(3 downto 0) := (others => (others => '0'));
        signal rx_prbs_err_cnt      : t_std32_array(3 downto 0) := (others => (others => '0'));
                                    
        constant CHAN_BOND_WORD     : std_logic_vector(31 downto 0) := x"606060BC";
        constant IDLE_WORD          : std_logic_vector(31 downto 0) := x"505050BC";
        
    begin
        
        g_chan : for i in 0 to 3 generate
            mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_ODMB7_BIDIR_TX_LINK(i)).tx).txdata(31 downto 0) <= tx_data(32 * i + 31 downto 32 * i);
            mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_ODMB7_BIDIR_TX_LINK(i)).tx).txchardispmode <= (others => '0');
            mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_ODMB7_BIDIR_TX_LINK(i)).tx).txchardispval <= (others => '0');
            mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_ODMB7_BIDIR_TX_LINK(i)).tx).txcharisk(3 downto 0) <= tx_charisk(4 * i + 3 downto 4 * i);
            mgt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_ODMB7_BIDIR_TX_LINK(i)).tx).txreset <= '0';
            mgt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_ODMB7_BIDIR_TX_LINK(i)).rx).rxreset <= '0';
            mgt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_ODMB7_BIDIR_TX_LINK(i)).rx).rxslide <= '0';
            
            rx_data(32 * i + 31 downto 32 * i) <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_ODMB7_BIDIR_TX_LINK(i)).rx).rxdata(31 downto 0);
            rx_byteisaligned(i) <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_ODMB7_BIDIR_TX_LINK(i)).rx).rxbyteisaligned;
            rx_byterealign(i) <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_ODMB7_BIDIR_TX_LINK(i)).rx).rxbyterealign;
            rx_commadet(i) <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_ODMB7_BIDIR_TX_LINK(i)).rx).rxcommadet;
            rx_disperr(4 * i + 3 downto 4 * i) <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_ODMB7_BIDIR_TX_LINK(i)).rx).rxdisperr(3 downto 0);
            rx_notintable(4 * i + 3 downto 4 * i) <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_ODMB7_BIDIR_TX_LINK(i)).rx).rxnotintable(3 downto 0);
            rx_chariscomma(4 * i + 3 downto 4 * i) <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_ODMB7_BIDIR_TX_LINK(i)).rx).rxchariscomma(3 downto 0);
            rx_charisk(4 * i + 3 downto 4 * i) <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_ODMB7_BIDIR_TX_LINK(i)).rx).rxcharisk(3 downto 0);
            rx_chanisaligned(i) <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_ODMB7_BIDIR_TX_LINK(i)).rx).rxchanisaligned;
        end generate;
        
        link_clk <= mgt_master_txusrclk.odmb57;
        
        -- TX PRBS
        i_tx_prbs : entity work.PRBS_ANY
            generic map(
                CHK_MODE    => false,
                INV_PATTERN => true,
                POLY_LENGHT => 31,
                POLY_TAP    => 28,
                NBITS       => 32
            )
            port map(
                RST      => o57_reset,
                CLK      => link_clk,
                DATA_IN  => x"00000000",
                EN       => tx_prbs_en,
                DATA_OUT => tx_prbs_data
            );
        
        tx_prbs_en <= '0' when idle_cntdown = 0 else '1';
        
        -- RX PRBS checkers
        g_prbs_chekers : for i in 0 to 3 generate
        
            process(link_clk) is
            begin
                if rising_edge(link_clk) then
                    if reverse_rx_prbs = '1' then
                        rx_prbs_data(i) <= reverse_bits(rx_data(32 * i + 31 downto 32 * i));
                    else
                        rx_prbs_data(i) <= rx_data(32 * i + 31 downto 32 * i);
                    end if;
                    rx_charisk_d1(4 * i + 3 downto 4 * i) <= rx_charisk(4 * i + 3 downto 4 * i);
                    rx_charisk_d2(4 * i + 3 downto 4 * i) <= rx_charisk_d1(4 * i + 3 downto 4 * i);
                end if;
            end process;
        
            i_rx_prbs_check : entity work.PRBS_ANY
                generic map(
                    CHK_MODE    => true,
                    INV_PATTERN => true,
                    POLY_LENGHT => 31,
                    POLY_TAP    => 28,
                    NBITS       => 32
                )
                port map(
                    RST      => o57_reset,
                    CLK      => link_clk,
                    DATA_IN  => rx_prbs_data(i),
                    EN       => not rx_charisk_d1(4 * i),
                    DATA_OUT => rx_prbs_err_bits(i)
                );

            process(link_clk) is
            begin
                if rising_edge(link_clk) then
                    if o57_reset = '1' then
                        rx_prbs_err(i) <= '0';
                    else
                        rx_prbs_err(i) <= or_reduce(rx_prbs_err_bits(i)) and not or_reduce(rx_charisk_d2(4 * i + 3 downto 4 * i));
                    end if;
                end if;
            end process;

        end generate;
        
        -- tx logic
        process(link_clk)
            variable tx_idle_char : std_logic := '0';
        begin
            if rising_edge(link_clk) then
                if o57_reset = '1' then
                    idle_cntdown <= to_integer(unsigned(idle_word_period));
                    tx_counter <= (others => '0');
                    if tx_idle_char = '0' then
                        tx_data <= CHAN_BOND_WORD & CHAN_BOND_WORD & CHAN_BOND_WORD & CHAN_BOND_WORD;
                    else
                        tx_data <= IDLE_WORD & IDLE_WORD & IDLE_WORD & IDLE_WORD;
                    end if;
                    tx_charisk <= x"1111";
                    tx_idle_char := not tx_idle_char;
                else
                    
                    if idle_cntdown = 0 then
                        if tx_idle_char = '0' then
                            tx_data <= CHAN_BOND_WORD & CHAN_BOND_WORD & CHAN_BOND_WORD & CHAN_BOND_WORD;
                        else
                            tx_data <= IDLE_WORD & IDLE_WORD & IDLE_WORD & IDLE_WORD;
                        end if;
                        tx_idle_char := not tx_idle_char;
--                        tx_data <= IDLE_WORD & IDLE_WORD & IDLE_WORD & IDLE_WORD;
                        tx_charisk <= x"1111";
                        idle_cntdown <= to_integer(unsigned(idle_word_period));
                    else
                        idle_cntdown <= idle_cntdown - 1;
                        tx_counter <= tx_counter + 1;
                        if use_prbs = '1' then
                            tx_data <= tx_prbs_data & tx_prbs_data & tx_prbs_data & tx_prbs_data; 
                        else
                            tx_data <= std_logic_vector(tx_counter) & std_logic_vector(tx_counter) & std_logic_vector(tx_counter) & std_logic_vector(tx_counter);
                        end if;
                        tx_charisk <= x"0000";
                    end if;
                    
                end if;
            end if;
        end process;
        
        -- rx logic
        process (link_clk) is
        begin
            if rising_edge(link_clk) then
                if o57_reset = '1' then
                    rx_counter <= (others => '0');
                    rx_data_err <= (others => '0');
                    rx_charisk_err <= (others => '0');
                else
                    if rx_charisk = x"0000" then
                        rx_charisk_err <= (others => '0');
                        rx_counter <= rx_counter + 1;
                        for i in 0 to 3 loop
                            if rx_data(32 * i + 31 downto 32 * i) = std_logic_vector(rx_counter) then
                                rx_data_err(i) <= '0';
                            else
                                rx_data_err(i) <= '1';
                            end if;
                        end loop;
                    elsif rx_charisk = x"1111" then
                        rx_charisk_err <= (others => '0');
                        rx_data_err <= (others => '0');
                    else
                        rx_charisk_err <= or_reduce(rx_charisk(15 downto 12)) & or_reduce(rx_charisk(11 downto 8)) & or_reduce(rx_charisk(7 downto 4)) & or_reduce(rx_charisk(3 downto 0));
                        rx_data_err <= (others => '0');
                    end if;
                end if;
            end if;
        end process;
        
        -- error counters
        g_channels : for i in 0 to 3 generate
            
            i_data_err_cnt : entity work.counter
                generic map(
                    g_COUNTER_WIDTH  => 32,
                    g_ALLOW_ROLLOVER => false
                )
                port map(
                    ref_clk_i => link_clk,
                    reset_i   => o57_reset,
                    en_i      => rx_data_err(i),
                    count_o   => rx_data_err_cnt(i)
                );

            i_charisk_err_cnt : entity work.counter
                generic map(
                    g_COUNTER_WIDTH  => 32,
                    g_ALLOW_ROLLOVER => false
                )
                port map(
                    ref_clk_i => link_clk,
                    reset_i   => o57_reset,
                    en_i      => rx_charisk_err(i),
                    count_o   => rx_charisk_err_cnt(i)
                );

            i_notintable_err_cnt : entity work.counter
                generic map(
                    g_COUNTER_WIDTH  => 32,
                    g_ALLOW_ROLLOVER => false
                )
                port map(
                    ref_clk_i => link_clk,
                    reset_i   => o57_reset,
                    en_i      => or_reduce(rx_notintable(i * 4 + 3 downto i * 4)),
                    count_o   => rx_notintable_err_cnt(i)
                );

            i_disperr_err_cnt : entity work.counter
                generic map(
                    g_COUNTER_WIDTH  => 32,
                    g_ALLOW_ROLLOVER => false
                )
                port map(
                    ref_clk_i => link_clk,
                    reset_i   => o57_reset,
                    en_i      => or_reduce(rx_disperr(i * 4 + 3 downto i * 4)),
                    count_o   => rx_disperr_err_cnt(i)
                );

            i_bytealign_err_cnt : entity work.counter
                generic map(
                    g_COUNTER_WIDTH  => 32,
                    g_ALLOW_ROLLOVER => false
                )
                port map(
                    ref_clk_i => link_clk,
                    reset_i   => o57_reset,
                    en_i      => not rx_byteisaligned(i),
                    count_o   => rx_bytealign_err_cnt(i)
                );

            i_chanalign_err_cnt : entity work.counter
                generic map(
                    g_COUNTER_WIDTH  => 32,
                    g_ALLOW_ROLLOVER => false
                )
                port map(
                    ref_clk_i => link_clk,
                    reset_i   => o57_reset,
                    en_i      => not rx_chanisaligned(i),
                    count_o   => rx_chanalign_err_cnt(i)
                );

            i_prbs_err_cnt : entity work.counter
                generic map(
                    g_COUNTER_WIDTH  => 32,
                    g_ALLOW_ROLLOVER => false
                )
                port map(
                    ref_clk_i => link_clk,
                    reset_i   => o57_reset,
                    en_i      => rx_prbs_err(i),
                    count_o   => rx_prbs_err_cnt(i)
                );
                        
        end generate;
    
        -- VIO
        i_vio_odmb57_loop : vio_odmb57_loopback
            port map(
                clk        => link_clk,
                probe_in0  => rx_data_err_cnt(0),
                probe_in1  => rx_data_err_cnt(1),
                probe_in2  => rx_data_err_cnt(2),
                probe_in3  => rx_data_err_cnt(3),
                probe_in4  => rx_charisk_err_cnt(0),
                probe_in5  => rx_charisk_err_cnt(1),
                probe_in6  => rx_charisk_err_cnt(2),
                probe_in7  => rx_charisk_err_cnt(3),
                probe_in8  => rx_notintable_err_cnt(0),
                probe_in9  => rx_notintable_err_cnt(1),
                probe_in10 => rx_notintable_err_cnt(2),
                probe_in11 => rx_notintable_err_cnt(3),
                probe_in12 => rx_disperr_err_cnt(0),
                probe_in13 => rx_disperr_err_cnt(1),
                probe_in14 => rx_disperr_err_cnt(2),
                probe_in15 => rx_disperr_err_cnt(3),
                probe_in16 => rx_bytealign_err_cnt(0),
                probe_in17 => rx_bytealign_err_cnt(1),
                probe_in18 => rx_bytealign_err_cnt(2),
                probe_in19 => rx_bytealign_err_cnt(3),
                probe_in20 => rx_chanalign_err_cnt(0),
                probe_in21 => rx_chanalign_err_cnt(1),
                probe_in22 => rx_chanalign_err_cnt(2),
                probe_in23 => rx_chanalign_err_cnt(3),
                probe_in24 => rx_prbs_err_cnt(0),
                probe_in25 => rx_prbs_err_cnt(1),
                probe_in26 => rx_prbs_err_cnt(2),
                probe_in27 => rx_prbs_err_cnt(3),
                probe_out0 => o57_reset,
                probe_out1 => idle_word_period,
                probe_out2 => use_prbs,
                probe_out3 => reverse_rx_prbs
            );    
    
        -- TX ILA
        i_odmb57_tx_ila : ila_mgt_tx_128b
            port map(
                clk    => link_clk,
                probe0 => tx_data,
                probe1 => tx_charisk
            );
        
        -- RX ILA
        i_odmb57_rx_ila : ila_mgt_rx_128b
            port map(
                clk    => link_clk,
                probe0 => rx_data,
                probe1 => rx_charisk,
                probe2 => rx_chariscomma,
                probe3 => rx_notintable,
                probe4 => rx_disperr,
                probe5 => and_reduce(rx_byteisaligned),
                probe6 => or_reduce(rx_byterealign),
                probe7 => or_reduce(rx_commadet),
                probe8 => "000", -- bufstatus
                probe9 => "00" -- rxclkcorr
            );

        -- PRBS checker ILA
        i_prbs_check_ila : ila_mgt_tx_128b
            port map(
                clk    => link_clk,
                probe0 => rx_prbs_err_bits(3) & rx_prbs_err_bits(2) & rx_prbs_err_bits(1) & rx_prbs_err_bits(0),
                probe1 => x"000" & rx_prbs_err(3) & rx_prbs_err(2) & rx_prbs_err(1) & rx_prbs_err(0)
            );
    
    end generate;

end csc_x2o_arch;
