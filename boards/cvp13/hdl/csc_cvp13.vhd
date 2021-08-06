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
        
        -- USB-C
        usbc_cc_i           : in  std_logic;
        usbc_clk_i          : in  std_logic;
        usbc_trig_i         : in  std_logic;
        
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
    
    -- PCIe
    signal pcie_refclk0         : std_logic;
    signal pcie_refclk0_div2    : std_logic;
    signal pcie_phy_ready       : std_logic;
    signal pcie_link_up         : std_logic;
    
    -- slow control
    signal ipb_reset            : std_logic;
    signal ipb_clk              : std_logic;
    signal ipb_usr_miso_arr     : ipb_rbus_array(C_NUM_IPB_SLAVES - 1 downto 0) := (others => IPB_S2M_NULL);
    signal ipb_usr_mosi_arr     : ipb_wbus_array(C_NUM_IPB_SLAVES - 1 downto 0);
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

    -------------------- MGTs mapped to CSC links ---------------------------------
    
    -- DMB links
    signal csc_dmb_rx_usrclk_arr    : std_logic_vector(CFG_NUM_DMBS - 1 downto 0);
    signal csc_dmb_rx_data_arr      : t_mgt_16b_rx_data_arr(CFG_NUM_DMBS - 1 downto 0);
    signal csc_dmb_rx_status_arr    : t_mgt_status_arr(CFG_NUM_DMBS - 1 downto 0);
    
    -- Spy readout link
    signal csc_spy_usrclk           : std_logic;
    signal csc_spy_rx_data          : t_mgt_16b_rx_data;
    signal csc_spy_tx_data          : t_mgt_16b_tx_data;
    signal csc_spy_rx_status        : t_mgt_status;
    
    -------------------- AMC13 DAQLink ---------------------------------
    signal daq_to_daqlink           : t_daq_to_daqlink;
    signal daqlink_to_daq           : t_daqlink_to_daq := (ready => '0', almost_full => '0', disperr_cnt => (others => '0'), notintable_cnt => (others => '0'));

    -------------------- PROMless ---------------------------------
    signal to_promless              : t_to_promless := (clk => '0', en => '0');
    signal from_promless            : t_from_promless := (ready => '0', valid => '0', data => (others => '0'), first => '0', last => '0', error => '0');

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
            qsfp_refclk0_p_i         => qsfp_refclk0_p_i,
            qsfp_refclk0_n_i         => qsfp_refclk0_n_i,
            qsfp_refclk1_p_i         => qsfp_refclk1_p_i,
            qsfp_refclk1_n_i         => qsfp_refclk1_n_i,
            pcie_refclk0_p_i         => pcie_refclk0_p_i,
            pcie_refclk0_n_i         => pcie_refclk0_n_i,
            
            qsfp_refclk0_o           => open,
            qsfp_refclk1_o           => open,
            qsfp_refclk0_div2_o      => open,
            qsfp_refclk1_div2_o      => open,

            qsfp_mgt_refclks_o       => mgt_refclks,
            
            pcie_refclk0_o           => pcie_refclk0,
            pcie_refclk0_div2_o      => pcie_refclk0_div2,

            synth_b_out_p_i          => synth_b_out_p_i,
            synth_b_out_n_i          => synth_b_out_n_i,
            synth_b_clks_o           => synth_b_clks,

            sysclk_100_o             => clk100
        );

    i_ttc_clks : entity work.ttc_clocks
        generic map(
            g_GEM_STATION               => 1,
            g_LPGBT_2P56G_LOOPBACK_TEST => false
        )
        port map(
            clk_gbt_mgt_txout_i => mgt_master_txoutclk.gbt,
            clk_gbt_mgt_ready_i => '1',
            clocks_o            => ttc_clks,
            ctrl_i              => ttc_clk_ctrl,
            status_o            => ttc_clk_status
        );

    --================================--
    -- PCIe
    --================================--

    i_pcie : entity work.pcie
        port map(
            reset_i             => '0', -- TODO: connect it to the FPGA reset
            
            pcie_reset_b_i      => pcie_reset_b_i,
            pcie_refclk_i       => pcie_refclk0,
            pcie_sysclk_i       => pcie_refclk0_div2,
            
            pcie_phy_ready_o    => pcie_phy_ready,
            pcie_link_up_o      => pcie_link_up,
            
            status_leds_o       => leds_o,
            led_i               => clk100_led,

            ipb_reset_o         => ipb_reset,
            ipb_clk_i           => ipb_clk,
            ipb_usr_miso_arr_i  => ipb_usr_miso_arr,
            ipb_usr_mosi_arr_o  => ipb_usr_mosi_arr,
            ipb_sys_miso_arr_i  => ipb_sys_miso_arr,
            ipb_sys_mosi_arr_o  => ipb_sys_mosi_arr            
        );

    --================================--
    -- MGTs
    --================================--

    i_mgts : entity work.mgt_links_gty
        generic map(
            g_NUM_CHANNELS      => CFG_MGT_NUM_CHANNELS,
            g_LINK_CONFIG       => CFG_MGT_LINK_CONFIG,
            g_STABLE_CLK_PERIOD => 10,
            g_IPB_CLK_PERIOD_NS => IPB_CLK_PERIOD_NS 
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
            reset_i     => '0',
            board_id_o  => board_id,
            ipb_reset_i => ipb_reset,
            ipb_clk_i   => ipb_clk,
            ipb_mosi_i  => ipb_sys_mosi_arr(C_IPB_SYS_SLV.system),
            ipb_miso_o  => ipb_sys_miso_arr(C_IPB_SYS_SLV.system)
        );

    --================================--
    -- CSC Logic
    --================================--

    i_csc_fed : entity work.csc_fed
        generic map(
            g_NUM_OF_DMBs       => CFG_NUM_DMBS,
            g_NUM_IPB_SLAVES    => C_NUM_IPB_SLAVES,
            g_IPB_CLK_PERIOD_NS => IPB_CLK_PERIOD_NS,
            g_DAQLINK_CLK_FREQ  => 100_000_000,
            g_DISABLE_TTC_DATA  => true
        )
        port map(
            -- Resets
            reset_i                 => '0',
            reset_pwrup_o           => open,
            
            -- TTC
            ttc_clocks_i            => ttc_clks,
            ttc_clk_status_i        => ttc_clk_status,
            ttc_clk_ctrl_o          => ttc_clk_ctrl,
            ttc_data_p_i            => '1',
            ttc_data_n_i            => '0',
            
            -- DMB links
            csc_dmb_rx_usrclk_arr_i => csc_dmb_rx_usrclk_arr,
            csc_dmb_rx_data_arr_i   => csc_dmb_rx_data_arr,
            csc_dmb_rx_status_arr_i => csc_dmb_rx_status_arr,

            -- Spy link
            csc_spy_usrclk_i        => csc_spy_usrclk,
            csc_spy_rx_data_i       => csc_spy_rx_data,
            csc_spy_tx_data_o       => csc_spy_tx_data,
            csc_spy_rx_status_i     => csc_spy_rx_status,
            
            -- IPbus
            ipb_reset_i             => ipb_reset,
            ipb_clk_i               => ipb_clk,
            ipb_miso_arr_o          => ipb_usr_miso_arr,
            ipb_mosi_arr_i          => ipb_usr_mosi_arr,

            -- DAQLink
            daqlink_clk_i           => clk100,
            daqlink_clk_locked_i    => '1',
            daq_to_daqlink_o        => daq_to_daqlink,
            daqlink_to_daq_i        => daqlink_to_daq,

            -- Board ID
            board_id_i              => board_id,
            
            -- PROMless
            to_promless_o           => to_promless,
            from_promless_i         => from_promless            
        );

    -- GTH mapping to CSC links (for now only single link DMBs are supported)
    g_csc_dmb_links : for i in 0 to CFG_NUM_DMBS - 1 generate
        csc_dmb_rx_usrclk_arr(i)               <= mgt_rx_usrclk_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(i).rx_fibers(0)).rx);
        csc_dmb_rx_data_arr(i).rxdata          <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(i).rx_fibers(0)).rx).rxdata(15 downto 0);
        csc_dmb_rx_data_arr(i).rxbyteisaligned <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(i).rx_fibers(0)).rx).rxbyteisaligned;
        csc_dmb_rx_data_arr(i).rxbyterealign   <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(i).rx_fibers(0)).rx).rxbyterealign;
        csc_dmb_rx_data_arr(i).rxcommadet      <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(i).rx_fibers(0)).rx).rxcommadet;
        csc_dmb_rx_data_arr(i).rxdisperr       <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(i).rx_fibers(0)).rx).rxdisperr(1 downto 0);
        csc_dmb_rx_data_arr(i).rxnotintable    <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(i).rx_fibers(0)).rx).rxnotintable(1 downto 0);
        csc_dmb_rx_data_arr(i).rxchariscomma   <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(i).rx_fibers(0)).rx).rxchariscomma(1 downto 0);
        csc_dmb_rx_data_arr(i).rxcharisk       <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(i).rx_fibers(0)).rx).rxcharisk(1 downto 0);
        csc_dmb_rx_status_arr(i)               <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(i).rx_fibers(0)).rx);
        
        -- send some dummy data on the TX of the same fiber
        mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_DMB_CONFIG_ARR(i).rx_fibers(0)).tx) <= (txdata => x"00000000000050bc", txcharisk => x"01", txchardispmode => x"00", txchardispval => x"00");
    end generate; 

    -- spy link mapping
    g_csc_spy_link : if CFG_USE_SPY_LINK generate
        csc_spy_usrclk                  <= mgt_tx_usrclk_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK).tx);
        csc_spy_rx_data.rxdata          <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK).rx).rxdata(15 downto 0);
        csc_spy_rx_data.rxbyteisaligned <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK).rx).rxbyteisaligned;
        csc_spy_rx_data.rxbyterealign   <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK).rx).rxbyterealign;
        csc_spy_rx_data.rxcommadet      <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK).rx).rxcommadet;
        csc_spy_rx_data.rxdisperr       <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK).rx).rxdisperr(1 downto 0);
        csc_spy_rx_data.rxnotintable    <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK).rx).rxnotintable(1 downto 0);
        csc_spy_rx_data.rxchariscomma   <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK).rx).rxchariscomma(1 downto 0);
        csc_spy_rx_data.rxcharisk       <= mgt_rx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK).rx).rxcharisk(1 downto 0);
        csc_spy_rx_status               <= mgt_status_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK).rx);
        
        mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK).tx).txdata(15 downto 0) <= csc_spy_tx_data.txdata;
        mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK).tx).txcharisk(1 downto 0) <= csc_spy_tx_data.txcharisk;
        mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK).tx).txchardispval(1 downto 0) <= csc_spy_tx_data.txchardispval;
        mgt_tx_data_arr(CFG_FIBER_TO_MGT_MAP(CFG_SPY_LINK).tx).txchardispmode(1 downto 0) <= csc_spy_tx_data.txchardispmode;
    end generate;

    -- spy link mapping
    g_csc_fake_spy_link : if not CFG_USE_SPY_LINK generate
        csc_spy_usrclk      <= '0';
        csc_spy_rx_data     <= MGT_16B_RX_DATA_NULL;
        csc_spy_rx_status   <= MGT_STATUS_NULL;
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
