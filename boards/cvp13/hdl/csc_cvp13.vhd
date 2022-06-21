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
use work.csc_pkg.all;
use work.ttc_pkg.all;
use work.mgt_pkg.all;
use work.ipbus.all;
use work.ipb_addr_decode.all;
use work.ipb_sys_addr_decode.all;
use work.board_config_package.all;
use work.project_config.all;

entity csc_cvp13 is
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
        
        -- External interfaces
        usbc_cc_i           : in  std_logic;
        usbc_clk_i          : in  std_logic;
        usbc_trig_i         : in  std_logic;
        dimm2_dq5_trig_i    : in  std_logic;
        sas1_gprx_0_i       : in  std_logic;
        sas1_gprx_1_i       : in  std_logic;
        sas1_gptx_0_o       : out std_logic;
        sas1_gptx_1_o       : out std_logic;
        sas2_gprx_0_i       : in  std_logic;
        sas2_gprx_1_i       : in  std_logic;
        sas2_gptx_0_o       : out std_logic;
        sas2_gptx_1_o       : out std_logic;
        
        -- Other
        synth_b_out_p_i     : in  std_logic_vector(4 downto 0);
        synth_b_out_n_i     : in  std_logic_vector(4 downto 0);
        
        i2c_master_en_b_o   : out std_logic -- FPGA is the I2C master when this is set to 0
        
    );
end csc_cvp13;

architecture csc_cvp13_arch of csc_cvp13 is
   
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

    -- constants
    constant IPB_CLK_PERIOD_NS  : integer := 10;
       
    -- resets 
    signal reset                : std_logic;
    signal reset_pwrup          : std_logic;
    signal usr_logic_reset      : std_logic;
        
    -- qsfp mgts
    signal refclk0              : std_logic_vector(CFG_NUM_REFCLK0 - 1 downto 0);
    signal refclk1              : std_logic_vector(CFG_NUM_REFCLK1 - 1 downto 0);
    signal refclk0_fabric       : std_logic_vector(CFG_NUM_REFCLK0 - 1 downto 0);
    signal refclk1_fabric       : std_logic_vector(CFG_NUM_REFCLK1 - 1 downto 0);
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
        
    -- external trigger
    signal usbc_trig_sync       : std_logic;
    signal dimm2_trig_sync      : std_logic;
    signal sas1_trig_sync       : std_logic;
    signal sas2_trig_sync       : std_logic;
    signal ext_trig             : std_logic;
    signal ext_trig_in_sync     : std_logic;
    signal ext_trig_en          : std_logic;
    signal ext_trig_source      : std_logic_vector(1 downto 0);
    signal ext_trig_deadtime    : std_logic_vector(11 downto 0);
    signal ext_trig_cntdown     : unsigned(11 downto 0) := (others => '0');
    signal ext_clk_out_en       : std_logic;
    
    -- PCIe
    signal pcie_refclk0         : std_logic;
    signal pcie_refclk0_div2    : std_logic;
    signal pcie_phy_ready       : std_logic;
    signal pcie_link_up         : std_logic;
    
    signal axi_clk              : std_logic;
    signal pcie_daq_control     : t_pcie_daq_control;
    signal pcie_daq_status      : t_pcie_daq_status;
        
    -- slow control
    signal ipb_reset            : std_logic;
    signal ipb_clk              : std_logic;
    signal ipb_usr_miso_arr     : ipb_rbus_array(CFG_NUM_SLRS * C_NUM_IPB_SLAVES - 1 downto 0) := (others => IPB_S2M_NULL);
    signal ipb_usr_mosi_arr     : ipb_wbus_array(CFG_NUM_SLRS * C_NUM_IPB_SLAVES - 1 downto 0);
    signal ipb_sys_miso_arr     : ipb_rbus_array(C_NUM_IPB_SYS_SLAVES - 1 downto 0) := (others => IPB_S2M_NULL);
    signal ipb_sys_mosi_arr     : ipb_wbus_array(C_NUM_IPB_SYS_SLAVES - 1 downto 0);
    
    -- other
    signal synth_b_clks         : std_logic_vector(4 downto 0);
    signal clk100               : std_logic;
    signal clk100_led           : std_logic;
    signal board_id             : std_logic_vector(15 downto 0);

    -- debug
    signal tst_bx_cnt           : unsigned(11 downto 0) := (others => '0');
    signal tst_bx_cnt_max       : std_logic_vector(11 downto 0) := x"00f";
    signal tst_trig_cnt         : unsigned(31 downto 0) := (others => '0');
    signal leds_tmp             : std_logic_vector(4 downto 0) := (others => '0');
    
    -------------------- AMC13 DAQLink ---------------------------------
    signal daq_to_daqlink           : t_daq_to_daqlink_arr(CFG_NUM_SLRS - 1 downto 0);
    signal daqlink_to_daq           : t_daqlink_to_daq_arr(CFG_NUM_SLRS - 1 downto 0) := (others => DAQLINK_TO_DAQ_NULL);

    -------------------- PROMless ---------------------------------
    signal to_promless              : t_to_promless_arr(CFG_NUM_SLRS - 1 downto 0) := (others => TO_PROMLESS_NULL);
    signal from_promless            : t_from_promless_arr(CFG_NUM_SLRS - 1 downto 0) := (others => FROM_PROMLESS_NULL);

begin
    
    --================================--
    -- Wiring
    --================================--
    
    reset <= not reset_b_i;
    i2c_master_en_b_o <= '0';
    ipb_clk <= clk100;
    
    --================================--
    -- Clocks
    --================================--
    
    i_clk_bufs : entity work.clk_bufs
            generic map (
                g_SYSCLK100_SYNTH_B_OUT_SEL => 2
            )
        port map(
            pcie_refclk0_p_i         => pcie_refclk0_p_i,
            pcie_refclk0_n_i         => pcie_refclk0_n_i,
            
            pcie_refclk0_o           => pcie_refclk0,
            pcie_refclk0_div2_o      => pcie_refclk0_div2,

            synth_b_out_p_i          => synth_b_out_p_i,
            synth_b_out_n_i          => synth_b_out_n_i,
            synth_b_clks_o           => synth_b_clks,

            sysclk_100_o             => clk100
        );

    i_ttc_clks : entity work.ttc_clocks
        generic map(
            g_CLK_STABLE_FREQ           => 100_000_000,
            g_GEM_STATION               => 1,
            g_LPGBT_2P56G_LOOPBACK_TEST => false
        )
        port map(
            clk_stable_i        => clk100,
            clk_gbt_mgt_txout_i => mgt_master_txoutclk.gbt,
            clk_gbt_mgt_ready_i => '1',
            clocks_o            => ttc_clks,
            ctrl_i              => ttc_clk_ctrl(0),
            status_o            => ttc_clk_status
        );

    --================================--
    -- PCIe
    --================================--

    i_pcie : entity work.pcie
        generic map (
            g_USE_QDMA              => true,
            g_NUM_USR_BLOCKS        => 1,
            g_USR_BLOCK_SEL_BIT_TOP => 25,
            g_USR_BLOCK_SEL_BIT_BOT => 24
        )
        port map(
            reset_i             => '0', -- TODO: connect it to the FPGA reset
            
            pcie_reset_b_i      => pcie_reset_b_i,
            pcie_refclk_i       => pcie_refclk0,
            pcie_sysclk_i       => pcie_refclk0_div2,
            
            pcie_phy_ready_o    => pcie_phy_ready,
            pcie_link_up_o      => pcie_link_up,
            
            status_leds_o       => leds_o,
            led_i               => clk100_led,

            daq_to_daqlink_i    => daq_to_daqlink(0),
            daqlink_to_daq_o    => daqlink_to_daq(0),

            axi_clk_o             => axi_clk,
            pcie_daq_control_i    => pcie_daq_control,
            pcie_daq_status_o     => pcie_daq_status,

            ipb_reset_o         => ipb_reset,
            ipb_clk_i           => ipb_clk,
            ipb_usr_miso_arr_i  => ipb_usr_miso_arr,
            ipb_usr_mosi_arr_o  => ipb_usr_mosi_arr,
            ipb_sys_miso_arr_i  => ipb_sys_miso_arr,
            ipb_sys_mosi_arr_o  => ipb_sys_mosi_arr            
        );

    i_pcie_slow_control : entity work.pcie_slow_control
        generic map(
            g_IPB_CLK_PERIOD_NS => IPB_CLK_PERIOD_NS
        )
        port map(
            axi_clk            => axi_clk,
            pcie_daq_control_o => pcie_daq_control,
            pcie_daq_status_i  => pcie_daq_status,
            ipb_clk_i          => ipb_clk,
            ipb_reset_i        => ipb_reset,
            ipb_mosi_i         => ipb_sys_mosi_arr(C_IPB_SYS_SLV.pcie),
            ipb_miso_o         => ipb_sys_miso_arr(C_IPB_SYS_SLV.pcie)
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
            clk_stable_i         => clk100,

            refclk0_p_i          => qsfp_refclk0_p_i,
            refclk0_n_i          => qsfp_refclk0_n_i,
            refclk1_p_i          => qsfp_refclk1_p_i,
            refclk1_n_i          => qsfp_refclk1_n_i,
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
    -- PROMless
    --================================--

    i_promless : entity work.promless
        generic map(
            g_NUM_CHANNELS      => CFG_NUM_SLRS,
            g_MAX_SIZE_BYTES    => 8_388_608, --9_437_184, -- 9_600_000,
            g_MEMORY_PRIMITIVE  => "ultra",
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
            ext_trig_en_o       => ext_trig_en,
            ext_trig_deadtime_o => ext_trig_deadtime,
            ext_trig_source_o   => ext_trig_source,
            ext_clk_out_en_o    => ext_clk_out_en,
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
                g_NUM_GBT_LINKS     => CFG_NUM_GBT_LINKS(slr),
                g_SLR               => slr,
                g_NUM_OF_DMBs       => CFG_NUM_DMBS(slr),
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
                external_trigger_i      => ext_trig,
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
                daqlink_clk_i           => clk100,
                daqlink_clk_locked_i    => '1',
                daq_to_daqlink_o        => daq_to_daqlink(slr),
                daqlink_to_daq_i        => daqlink_to_daq(slr),
    
                -- Board ID
                board_id_i              => board_id,
                
                -- PROMless
                to_promless_o           => to_promless(slr),
                from_promless_i         => from_promless(slr)          
            );
            
        -- CSC link mapping (for now only single link DMBs are supported)
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
            mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_TTC_LINKS(i)).tx).txdata(15 downto 0) <= ttc_tx_mgt_data.txdata;
            mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_TTC_LINKS(i)).tx).txchardispmode <= (others => '0');
            mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_TTC_LINKS(i)).tx).txchardispval <= (others => '0');
            mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_TTC_LINKS(i)).tx).txcharisk <= (others => '0');
            mgt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_TTC_LINKS(i)).tx).txreset <= '0';
            mgt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_TTC_LINKS(i)).rx).rxreset <= '0';
            mgt_ctrl_arr(CFG_FIBER_TO_MGT_MAP(CFG_TTC_LINKS(i)).rx).rxslide <= '0';
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
                probe7 : in std_logic_vector(2 downto 0);
                probe8 : in std_logic_vector(1 downto 0)
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
                probe7 => "000", -- bufstatus
                probe8 => "00" -- rxclkcorr
            );

        -- PRBS checker ILA
        i_prbs_check_ila : ila_mgt_tx_128b
            port map(
                clk    => link_clk,
                probe0 => rx_prbs_err_bits(3) & rx_prbs_err_bits(2) & rx_prbs_err_bits(1) & rx_prbs_err_bits(0),
                probe1 => x"000" & rx_prbs_err(3) & rx_prbs_err(2) & rx_prbs_err(1) & rx_prbs_err(0)
            );
    
    end generate;

    --================================--
    -- External trigger
    --================================--

    ------------ trigger input synchronization and selection ------------

    i_usbc_trig_sync  : entity work.synch generic map(N_STAGES => 4) port map(async_i => usbc_trig_i, clk_i => ttc_clks.clk_40, sync_o => usbc_trig_sync);
    i_dimm2_trig_sync : entity work.synch generic map(N_STAGES => 4) port map(async_i => dimm2_dq5_trig_i, clk_i => ttc_clks.clk_40, sync_o => dimm2_trig_sync);
    i_sas1_trig_sync  : entity work.synch generic map(N_STAGES => 4) port map(async_i => sas1_gprx_0_i, clk_i => ttc_clks.clk_40, sync_o => sas1_trig_sync);
    i_sas2_trig_sync  : entity work.synch generic map(N_STAGES => 4) port map(async_i => sas2_gprx_0_i, clk_i => ttc_clks.clk_40, sync_o => sas2_trig_sync);

--    ext_trig_in_sync <= slimsas1_trig_sync when ext_trig_source = "00" else slimsas2_trig_sync when ext_trig_source = "01" else dimm2_trig_sync when ext_trig_source = "10" else usbc_trig_sync; 

    ext_trig_in_sync <= sas1_trig_sync;

    ------------ SlimSAS outputs ------------

    sas1_gptx_0_o <= '0';
    sas1_gptx_1_o <= ttc_clks.clk_40 when ext_clk_out_en = '1' else '0';
    sas2_gptx_0_o <= '0';
    sas2_gptx_1_o <= '0';

    ------------ trigger logic with configurable deadtime ------------
    process(ttc_clks.clk_40)
    begin
        if rising_edge(ttc_clks.clk_40) then
            if ext_trig_en = '0' then
                ext_trig <= '0';
                ext_trig_cntdown <= (others => '0');
            else
                
                if ext_trig_in_sync = '1' and ext_trig_cntdown = x"000" then
                    ext_trig <= '1';
                    ext_trig_cntdown <= unsigned(ext_trig_deadtime);
                else
                    ext_trig <= '0';
                    
                    if ext_trig_cntdown /= x"000" then
                        ext_trig_cntdown <= ext_trig_cntdown - 1;
                    end if;
                    
                end if;

            end if;
        end if;
    end process;
    
    ------------ trigger debugging ------------
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

                if ext_trig = '1' and tst_trig_cnt /= x"ffffffff" then
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
            probe0 => ext_trig_in_sync,
            probe1 => std_logic_vector(tst_bx_cnt)
        );

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
        
    ---------------------------------------------------------------------------------
    -- TEST clk output to LEDs (need to disconnect the LEDs from the PCIe module
--    leds_o <= leds_tmp(4 downto 1);
    
    g_test : for i in 0 to 4 generate
        process(synth_b_clks(i))
            variable cntdown : integer := 100_000_000;
        begin
            if rising_edge(synth_b_clks(i)) then
                if cntdown = 0 then
                    cntdown := 100_000_000;
                    leds_tmp(i) <= not leds_tmp(i);
                else
                    cntdown := cntdown - 1;
                end if;
            end if;
        end process;    
    end generate;

    process(clk100)
        variable cntdown : integer := 100_000_000;
    begin
        if rising_edge(clk100) then
            if cntdown = 0 then
                cntdown := 100_000_000;
                clk100_led <= not clk100_led;
            else
                cntdown := cntdown - 1;
            end if;
        end if;
    end process;    
    ---------------------------------------------------------------------------------
        
end csc_cvp13_arch;
