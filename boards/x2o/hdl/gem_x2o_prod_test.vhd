------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
--
-- Create Date:    2021-07-27
-- Module Name:    GEM_X2O
-- Description:    This is the top level of the GEM X2O project (using Octopus FPGA module)
------------------------------------------------------------------------------------------------------------------------------------------------------

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
use work.project_config.all;

entity gem_x2o is
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
 
        refclk0_p_i     : in  std_logic_vector(CFG_NUM_REFCLK0 - 1 downto 0); -- async 156.25MHz clocks (one per quad)
        refclk0_n_i     : in  std_logic_vector(CFG_NUM_REFCLK0 - 1 downto 0);
        refclk1_p_i     : in  std_logic_vector(CFG_NUM_REFCLK1 - 1 downto 0);  -- sync clocks
        refclk1_n_i     : in  std_logic_vector(CFG_NUM_REFCLK1 - 1 downto 0)
    );
end gem_x2o;

architecture gem_x2o_arch of gem_x2o is

    component framework is
        port(
            clk_50_o          : out std_logic;
            clk_100_o         : out std_logic;
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
    signal gem_reset_powerup    : std_logic_vector(CFG_NUM_GEM_BLOCKS - 1 downto 0);
    signal reset_powerup        : std_logic;
    signal usr_logic_reset      : std_logic;
    signal usr_ttc_reset        : std_logic;

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
    signal ttc_clk_ctrl         : t_ttc_clk_ctrl_arr(CFG_NUM_GEM_BLOCKS - 1 downto 0);
    signal ttc_cmds             : t_ttc_cmds;

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
    signal ipb_usr_miso_arr     : ipb_rbus_array(CFG_NUM_GEM_BLOCKS * C_NUM_IPB_SLAVES - 1 downto 0) := (others => IPB_S2M_NULL);
    signal ipb_usr_mosi_arr     : ipb_wbus_array(CFG_NUM_GEM_BLOCKS * C_NUM_IPB_SLAVES - 1 downto 0);
    signal ipb_sys_miso_arr     : ipb_rbus_array(C_NUM_IPB_SYS_SLAVES - 1 downto 0) := (others => IPB_S2M_NULL);
    signal ipb_sys_mosi_arr     : ipb_wbus_array(C_NUM_IPB_SYS_SLAVES - 1 downto 0);

    -- DAQ and other
    signal clk_50               : std_logic;
    signal clk_100              : std_logic;
    signal slink_mgt_ref_clk    : std_logic;
    signal board_id             : std_logic_vector(15 downto 0);

    -------------------- DAQ links ---------------------------------
    signal daq_to_daqlink           : t_daq_to_daqlink_arr(CFG_NUM_GEM_BLOCKS - 1 downto 0);
    signal daqlink_to_daq           : t_daqlink_to_daq_arr(CFG_NUM_GEM_BLOCKS - 1 downto 0) := (others => DAQLINK_TO_DAQ_NULL);

    -------------------- PROMless ---------------------------------
    signal to_promless              : t_to_promless_arr(CFG_NUM_GEM_BLOCKS - 1 downto 0) := (others => TO_PROMLESS_NULL);
    signal from_promless            : t_from_promless_arr(CFG_NUM_GEM_BLOCKS - 1 downto 0) := (others => FROM_PROMLESS_NULL);

    -------------------- Test ---------------------------------
    signal fake_gbt_master_clk      : std_logic;
    signal fake_gbt_master_clk_rdy  : std_logic;

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
            g_NUM_USR_BLOCKS => CFG_NUM_GEM_BLOCKS,
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

    -- since we don't have any GBT links, and the TAMU board does not have sync ref clocks at all (no synthesizer installed), lets make 160 from 156.25 ref clk here
    
    g_fake_gbt_master_clk : if true generate
        signal clkin_156p25     : std_logic;
        signal clkfb            : std_logic;
        signal clkout_160       : std_logic;
        signal mmcm_160_locked  : std_logic;
        signal mmcm_160_reset   : std_logic := '1';
        signal reset_cntdown    : integer range 0 to 1_000_000 := 1_000_000;
      
    begin
        
        clkin_156p25 <= refclk0_fabric(26);
        
        process(clkin_156p25)
        begin
            if rising_edge(clkin_156p25) then
                if axi_reset_b = '0' then
                    reset_cntdown <= 1_000_000;
                    mmcm_160_reset <= '1';
                else
                    if reset_cntdown /= 0 then
                        mmcm_160_reset <= '1';
                        reset_cntdown <= reset_cntdown - 1;
                    else
                        mmcm_160_reset <= '0';
                        reset_cntdown <= 0;
                    end if;
                end if;
            end if;
        end process;
        
        i_main_mmcm : MMCME4_ADV
            generic map(
                BANDWIDTH            => "OPTIMIZED",
                CLKFBOUT_MULT_F      => 32.00,
                CLKFBOUT_PHASE       => 0.000,
                CLKFBOUT_USE_FINE_PS => "FALSE",
                CLKIN1_PERIOD        => 6.4,
                CLKOUT0_DIVIDE_F     => 6.25,
                CLKOUT0_DUTY_CYCLE   => 0.500,
                CLKOUT0_PHASE        => 0.000,
                CLKOUT0_USE_FINE_PS  => "FALSE",
    --            COMPENSATION         => "ZHOLD",
                DIVCLK_DIVIDE        => 5,
                REF_JITTER1          => 0.010,
                STARTUP_WAIT         => "FALSE"
            )
            port map(
                -- clock inputs
                CLKFBIN      => clkfb,
                CLKIN1       => clkin_156p25,
                CLKIN2       => '0',
                -- clock outputs
                CLKFBOUT     => clkfb,
                CLKOUT0      => clkout_160,
                -- control
                CLKINSEL     => '1', -- always select the primary clock
                PWRDWN       => '0',
                RST          => mmcm_160_reset,
                -- drp
                DO           => open,
                DRDY         => open,
                DADDR        => (others => '0'),
                DCLK         => '0',
                DEN          => '0',
                DI           => (others => '0'),
                DWE          => '0',
                -- dynamic phase shifting
                PSCLK        => clkin_156p25,
                PSEN         => '0',
                PSINCDEC     => '0',
                PSDONE       => open,
                -- status
                LOCKED       => mmcm_160_locked,
                CLKFBSTOPPED => open,
                CLKINSTOPPED => open,
                -- dynamic clock divide
                CDDCDONE     => open,
                CDDCREQ      => '0'           
            );
        
        fake_gbt_master_clk <= clkout_160;
        fake_gbt_master_clk_rdy <= mmcm_160_locked;
            
    end generate;
    

    i_ttc_clks : entity work.ttc_clocks
        generic map(
            g_CLK_STABLE_FREQ           => 100_000_000,
            g_GEM_STATION               => CFG_GEM_STATION(0),
            g_TXPROGDIVCLK_USED         => false,
            g_INST_BUFG_GT              => true
        )
        port map(
            clk_stable_i        => axil_clk,
            clk_gbt_mgt_txout_i => fake_gbt_master_clk,
            clk_gbt_mgt_ready_i => fake_gbt_master_clk_rdy,
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

            refclk0_p_i          => refclk0_p_i,
            refclk0_n_i          => refclk0_n_i,
            refclk1_p_i          => refclk1_p_i,
            refclk1_n_i          => refclk1_n_i,
            refclk0_o            => refclk0,
            refclk1_o            => refclk1,
            refclk0_fabric_o     => refclk0_fabric,
            refclk1_fabric_o     => refclk1_fabric,

            ttc_clks_i           => ttc_clks,
            ttc_clks_locked_i    => '1', --ttc_clk_status.mmcm_locked,
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
--            ipb_mosi_chan_drp_i  => ipb_sys_mosi_arr(C_IPB_SYS_SLV.mgt_chan_drp),
--            ipb_miso_chan_drp_o  => ipb_sys_miso_arr(C_IPB_SYS_SLV.mgt_chan_drp),
--            ipb_mosi_qpll_drp_i  => ipb_sys_mosi_arr(C_IPB_SYS_SLV.mgt_qpll_drp),
--            ipb_miso_qpll_drp_o  => ipb_sys_miso_arr(C_IPB_SYS_SLV.mgt_qpll_drp)
        );

    ggg : for i in 0 to CFG_MGT_NUM_CHANNELS - 1 generate
        mgt_ctrl_arr(i).rxreset <= '0';
        mgt_ctrl_arr(i).txreset <= '0';
        mgt_ctrl_arr(i).rxslide <= '0';
        
        ten_gbe_pcs : entity work.ten_gbe_tx_mac_pcs
            generic map(
                ASYNC_GEARBOX => true
            )
            port map(
                reset_i        => not mgt_status_arr(i).tx_reset_done,
                clk_i          => mgt_tx_usrclk_arr(i),
                tx_data_o      => mgt_tx_data_arr(i),
                packet_valid_i => '0',
                packet_data_i  => (others => '0'),
                packet_end_i   => '0',
                packet_rden_o  => open,
                generator_en   => '1',
                word_rate_o    => open
            );
        
    end generate;

--    --================================--
--    -- SLink Rocket
--    --================================--
--
--    i_slink_rocket : entity work.slink_rocket
--        generic map(
--            g_NUM_CHANNELS      => CFG_NUM_GEM_BLOCKS,
--            g_LINE_RATE         => "25.78125",
--            q_REF_CLK_FREQ      => "156.25",
--            g_MGT_TYPE          => "GTY",
--            g_IPB_CLK_PERIOD_NS => IPB_CLK_PERIOD_NS
--        )
--        port map(
--            reset_i          => reset_powerup,
--            clk_stable_100_i => clk_100,
--            mgt_ref_clk_i    => slink_mgt_ref_clk,
--
--            daq_to_daqlink_i => daq_to_daqlink,
--            daqlink_to_daq_o => daqlink_to_daq,
--            
--            ipb_reset_i      => ipb_reset,
--            ipb_clk_i        => ipb_clk,
--            ipb_mosi_i       => ipb_sys_mosi_arr(C_IPB_SYS_SLV.slink),
--            ipb_miso_o       => ipb_sys_miso_arr(C_IPB_SYS_SLV.slink)
--        );
--
--    slink_mgt_ref_clk <= refclk0(24);

--    --================================--
--    -- PROMless
--    --================================--
--
--    g_promless : if CFG_GEM_STATION(0) /= 0 generate
--        i_promless : entity work.promless
--            generic map(
--                g_NUM_CHANNELS => CFG_NUM_GEM_BLOCKS,
--                g_MAX_SIZE_BYTES   => 8_388_608,
--                g_MEMORY_PRIMITIVE => "ultra",
--                g_IPB_CLK_PERIOD_NS => IPB_CLK_PERIOD_NS
--            )
--            port map(
--                reset_i         => '0',
--                to_promless_i   => to_promless,
--                from_promless_o => from_promless,
--                ipb_reset_i     => ipb_reset,
--                ipb_clk_i       => ipb_clk,
--                ipb_miso_o      => ipb_sys_miso_arr(C_IPB_SYS_SLV.promless),
--                ipb_mosi_i      => ipb_sys_mosi_arr(C_IPB_SYS_SLV.promless)
--            );
--    end generate;
    
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
            ttc_reset_o         => usr_ttc_reset,
            ext_trig_en_o       => open,
            ext_trig_deadtime_o => open,
            ipb_reset_i         => ipb_reset,
            ipb_clk_i           => ipb_clk,
            ipb_mosi_i          => ipb_sys_mosi_arr(C_IPB_SYS_SLV.system),
            ipb_miso_o          => ipb_sys_miso_arr(C_IPB_SYS_SLV.system)
        );

    --================================--
    -- GEM Logic
    --================================--

    g_slrs : for slr in 0 to CFG_NUM_GEM_BLOCKS - 1 generate

        -- Trigger RX GTX / GTH links (3.2Gbs, 16bit @ 160MHz w/ 8b10b encoding)
        signal gem_gt_trig0_rx_clk_arr  : std_logic_vector(CFG_NUM_OF_OHs(slr) - 1 downto 0);
        signal gem_gt_trig0_rx_data_arr : t_mgt_16b_rx_data_arr(CFG_NUM_OF_OHs(slr) - 1 downto 0);
        signal gem_gt_trig1_rx_clk_arr  : std_logic_vector(CFG_NUM_OF_OHs(slr) - 1 downto 0);
        signal gem_gt_trig1_rx_data_arr : t_mgt_16b_rx_data_arr(CFG_NUM_OF_OHs(slr) - 1 downto 0);
        
        -- GBT GTX/GTH links (4.8Gbs, 40bit @ 120MHz w/o 8b10b encoding)
        signal gem_gt_gbt_rx_data_arr   : t_std40_array(CFG_NUM_OF_OHs(slr) * CFG_NUM_GBTS_PER_OH(slr) - 1 downto 0);
        signal gem_gt_gbt_tx_data_arr   : t_std40_array(CFG_NUM_OF_OHs(slr) * CFG_NUM_GBTS_PER_OH(slr) - 1 downto 0);
        signal gem_gt_gbt_rx_clk_arr    : std_logic_vector(CFG_NUM_OF_OHs(slr) * CFG_NUM_GBTS_PER_OH(slr) - 1 downto 0);
        signal gem_gt_gbt_tx_clk_arr    : std_logic_vector(CFG_NUM_OF_OHs(slr) * CFG_NUM_GBTS_PER_OH(slr) - 1 downto 0);
    
        signal gem_gt_gbt_ctrl_arr      : t_mgt_ctrl_arr(CFG_NUM_OF_OHs(slr) * CFG_NUM_GBTS_PER_OH(slr) - 1 downto 0);
        signal gem_gt_gbt_status_arr    : t_mgt_status_arr(CFG_NUM_OF_OHs(slr) * CFG_NUM_GBTS_PER_OH(slr) - 1 downto 0);

        -- Trigger TX links (10.24Gbs, 64bit @ 160MHz w/o encoding)
        signal gem_gt_trig_tx_clk       : std_logic;
        signal gem_gt_trig_tx_data_arr  : t_std64_array(CFG_NUM_TRIG_TX - 1 downto 0);
        signal gem_gt_trig_tx_status_arr: t_mgt_status_arr(CFG_NUM_TRIG_TX - 1 downto 0);
    
        -------------------- Spy / LDAQ readout link ---------------------------------
        signal spy_rx_data              : t_mgt_64b_rx_data;
        signal spy_tx_data              : t_mgt_64b_tx_data;
        signal spy_rx_usrclk            : std_logic;
        signal spy_tx_usrclk            : std_logic;
        signal spy_status               : t_mgt_status;

    begin
        
        i_gem : entity work.gem_amc
            generic map(
                g_SLR               => slr,
                g_GEM_STATION       => CFG_GEM_STATION(slr),
                g_NUM_OF_OHs        => CFG_NUM_OF_OHs(slr),
                g_OH_VERSION        => CFG_OH_VERSION(slr),
                g_GBT_WIDEBUS       => CFG_GBT_WIDEBUS(slr),
                g_OH_TRIG_LINK_TYPE => CFG_OH_TRIG_LINK_TYPE(slr),
                g_NUM_GBTS_PER_OH   => CFG_NUM_GBTS_PER_OH(slr),
                g_NUM_VFATS_PER_OH  => CFG_NUM_VFATS_PER_OH(slr),
                g_USE_TRIG_TX_LINKS => CFG_USE_TRIG_TX_LINKS,
                g_NUM_TRIG_TX_LINKS => CFG_NUM_TRIG_TX,
                g_NUM_IPB_SLAVES    => C_NUM_IPB_SLAVES,
                g_IPB_CLK_PERIOD_NS => IPB_CLK_PERIOD_NS,
                g_DAQ_CLK_FREQ      => 100_000_000,
                g_IS_SLINK_ROCKET   => true,
                g_EXT_TTC_RECEIVER  => true
            )
            port map(
                reset_i                 => usr_logic_reset,
                reset_pwrup_o           => gem_reset_powerup(slr),
    
                ttc_reset_i             => usr_ttc_reset,
                ttc_clocks_i            => ttc_clks,
                ttc_clk_status_i        => ttc_clk_status,
                ttc_clk_ctrl_o          => ttc_clk_ctrl(slr),
                ttc_cmds_i              => ttc_cmds,
                ttc_data_p_i            => '1',
                ttc_data_n_i            => '0',
                external_trigger_i      => '0',
    
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
    
                gt_gbt_status_arr_i     => gem_gt_gbt_status_arr,
                gt_gbt_ctrl_arr_o       => gem_gt_gbt_ctrl_arr,
    
                spy_rx_data_i           => spy_rx_data,
                spy_tx_data_o           => spy_tx_data,
                spy_rx_usrclk_i         => spy_rx_usrclk,
                spy_tx_usrclk_i         => spy_tx_usrclk,
                spy_status_i            => spy_status,
    
                ipb_reset_i             => ipb_reset,
                ipb_clk_i               => ipb_clk,
                ipb_miso_arr_o          => ipb_usr_miso_arr((slr + 1) * C_NUM_IPB_SLAVES - 1 downto slr * C_NUM_IPB_SLAVES),
                ipb_mosi_arr_i          => ipb_usr_mosi_arr((slr + 1) * C_NUM_IPB_SLAVES - 1 downto slr * C_NUM_IPB_SLAVES),
    
                led_l1a_o               => open,
                led_trigger_o           => open,
    
                daq_data_clk_i          => axil_clk,
                daq_data_clk_locked_i   => '1',
                daq_to_daqlink_o        => daq_to_daqlink(slr),
                daqlink_to_daq_i        => daqlink_to_daq(slr),
    
                board_id_i              => board_id,
    
                to_promless_o           => to_promless(slr),
                from_promless_i         => from_promless(slr)
            );

        -- GEM link mapping
        g_gem_links : for oh in 0 to CFG_NUM_OF_OHs(slr) - 1 generate
    
            g_gbt_links : for gbt in 0 to CFG_NUM_GBTS_PER_OH(slr) - 1 generate
                gem_gt_gbt_rx_data_arr(oh * CFG_NUM_GBTS_PER_OH(slr) + gbt) <= (others => '0');
                gem_gt_gbt_rx_clk_arr(oh * CFG_NUM_GBTS_PER_OH(slr) + gbt) <= '0';
                gem_gt_gbt_tx_clk_arr(oh * CFG_NUM_GBTS_PER_OH(slr) + gbt) <= '0';
                gem_gt_gbt_status_arr(oh * CFG_NUM_GBTS_PER_OH(slr) + gbt).tx_reset_done  <= '0';
                gem_gt_gbt_status_arr(oh * CFG_NUM_GBTS_PER_OH(slr) + gbt).tx_pll_locked <= '0';
                gem_gt_gbt_status_arr(oh * CFG_NUM_GBTS_PER_OH(slr) + gbt).rx_reset_done  <= '0';
                gem_gt_gbt_status_arr(oh * CFG_NUM_GBTS_PER_OH(slr) + gbt).rx_pll_locked <= '0';
            end generate;
    
            --=== Trigger links (GE1/1 and GE2/1 only) ===--
            g_non_me0_trig_links: if CFG_GEM_STATION(slr) /= 0 generate
                gem_gt_trig0_rx_clk_arr(oh)  <= '0';
                gem_gt_trig1_rx_clk_arr(oh)  <= '0';
    
                gem_gt_trig0_rx_data_arr(oh).rxdata <= (others => '0');
                gem_gt_trig0_rx_data_arr(oh).rxbyteisaligned <= '0';
                gem_gt_trig0_rx_data_arr(oh).rxbyterealign <= '0';
                gem_gt_trig0_rx_data_arr(oh).rxcommadet <= '0';
                gem_gt_trig0_rx_data_arr(oh).rxdisperr <= (others => '0');
                gem_gt_trig0_rx_data_arr(oh).rxnotintable <= (others => '0');
                gem_gt_trig0_rx_data_arr(oh).rxchariscomma <= (others => '0');
                gem_gt_trig0_rx_data_arr(oh).rxcharisk <= (others => '0');
    
                gem_gt_trig1_rx_data_arr(oh).rxdata <= (others => '0');
                gem_gt_trig1_rx_data_arr(oh).rxbyteisaligned <= '0';
                gem_gt_trig1_rx_data_arr(oh).rxbyterealign <= '0';
                gem_gt_trig1_rx_data_arr(oh).rxcommadet <= '0';
                gem_gt_trig1_rx_data_arr(oh).rxdisperr <= (others => '0');
                gem_gt_trig1_rx_data_arr(oh).rxnotintable <= (others => '0');
                gem_gt_trig1_rx_data_arr(oh).rxchariscomma <= (others => '0');
                gem_gt_trig1_rx_data_arr(oh).rxcharisk <= (others => '0');
            end generate;
    
        end generate;

        spy_tx_usrclk <= '0';
        spy_rx_usrclk <= '0';
        spy_rx_data <= MGT_64B_RX_DATA_NULL;
        spy_status <= MGT_STATUS_NULL;

    end generate;

    reset_powerup <= gem_reset_powerup(0);

end gem_x2o_arch;
