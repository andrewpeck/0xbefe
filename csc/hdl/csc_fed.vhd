------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    23:45:21 2016-11-23
-- Module Name:    CSC_FED 
-- Description:    This is the top module of all the common CSC FED logic. It is board-agnostic and can be used in different FPGA / board designs 
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.common_pkg.all;
use work.csc_pkg.all;
use work.ipb_addr_decode.all;
use work.ipbus.all;
use work.ttc_pkg.all;

entity csc_fed is
    generic(
        g_SLR                : integer;
        g_NUM_OF_DMBs        : integer;
        g_NUM_GBT_LINKS      : integer;
        g_NUM_IPB_SLAVES     : integer;
        g_IPB_CLK_PERIOD_NS  : integer;
        g_DAQLINK_CLK_FREQ   : integer;
        g_USE_SLINK_ROCKET   : boolean;
        g_DISABLE_TTC_DATA   : boolean := false -- set this to true when ttc_data_p_i / ttc_data_n_i are not connected to anything, this will disable ttc data completely (generator can still be used though)
    );
    port(
        -- Resets
        reset_i                 : in   std_logic;
        reset_pwrup_o           : out  std_logic;

        -- TTC
        ttc_clocks_i            : in  t_ttc_clks;
        ttc_clk_status_i        : in  t_ttc_clk_status;
        ttc_clk_ctrl_o          : out t_ttc_clk_ctrl;
        ttc_data_p_i            : in  std_logic;      -- TTC protocol backplane signals
        ttc_data_n_i            : in  std_logic;
        external_trigger_i      : in  std_logic;      -- should be on TTC clk domain
        ttc_cmds_o              : out t_ttc_cmds;
        
        -- DMB links
        dmb_rx_usrclk_i         : in  std_logic;
        dmb_rx_data_arr_i       : in  t_mgt_16b_rx_data_arr(g_NUM_OF_DMBs - 1 downto 0);
        dmb_rx_status_arr_i     : in  t_mgt_status_arr(g_NUM_OF_DMBs - 1 downto 0);

        -- GBT links
        gbt_rx_data_arr_i       : in  t_std40_array(g_NUM_GBT_LINKS - 1 downto 0);
        gbt_tx_data_arr_o       : out t_std40_array(g_NUM_GBT_LINKS - 1 downto 0);
        gbt_rx_clk_arr_i        : in  std_logic_vector(g_NUM_GBT_LINKS - 1 downto 0);
        gbt_tx_clk_arr_i        : in  std_logic_vector(g_NUM_GBT_LINKS - 1 downto 0);
        gbt_rx_common_clk_i     : in  std_logic;
                                
        gbt_status_arr_i        : in  t_mgt_status_arr(g_NUM_GBT_LINKS - 1 downto 0);
        gbt_ctrl_arr_o          : out t_mgt_ctrl_arr(g_NUM_GBT_LINKS - 1 downto 0);
        
        -- Spy link
        spy_usrclk_i            : in  std_logic;
        spy_rx_data_i           : in  t_mgt_16b_rx_data;
        spy_tx_data_o           : out t_mgt_16b_tx_data;                
        spy_rx_status_i         : in  t_mgt_status;

        -- IPbus
        ipb_reset_i             : in  std_logic;
        ipb_clk_i               : in  std_logic;
        ipb_miso_arr_o          : out ipb_rbus_array(g_NUM_IPB_SLAVES - 1 downto 0);
        ipb_mosi_arr_i          : in  ipb_wbus_array(g_NUM_IPB_SLAVES - 1 downto 0);
        
        -- DAQLink
        daqlink_clk_i           : in  std_logic;
        daqlink_clk_locked_i    : in  std_logic;
        daq_to_daqlink_o        : out t_daq_to_daqlink;
        daqlink_to_daq_i        : in  t_daqlink_to_daq;
        
        -- Board ID
        board_id_i              : in std_logic_vector(15 downto 0);
        
        -- PROMless
        to_promless_o           : out t_to_promless;
        from_promless_i         : in  t_from_promless                
    );
end csc_fed;

architecture csc_fed_arch of csc_fed is

    --================================--
    -- Components
    --================================--

    component ila_gbt
        port(
            clk     : in std_logic;
            probe0  : in std_logic_vector(83 downto 0);
            probe1  : in std_logic_vector(83 downto 0);
            probe2  : in std_logic_vector(31 downto 0);
            probe3  : in std_logic;
            probe4  : in std_logic;
            probe5  : in std_logic;
            probe6  : in std_logic;
            probe7  : in std_logic;
            probe8  : in std_logic_vector(5 downto 0)
        );
    end component;
    
    --================================--
    -- Constants
    --================================--

    constant POWER_UP_RESET_TIME : std_logic_vector(31 downto 0) := x"02625a00"; -- 40_000_000 clock cycles (1s) - way too long of course, but fine -- this is only used at powerup (FED doesn't care about hard resets), it's not like someone will want to start taking data sooner than that :) 

    --================================--
    -- Signals
    --================================--

    --== Resets ==--
    signal reset                : std_logic;
    signal reset_pwrup          : std_logic;
    signal ipb_reset            : std_logic;
    signal link_reset           : std_logic;
    signal manual_link_reset    : std_logic;
    signal manual_gbt_reset     : std_logic;
    signal manual_global_reset  : std_logic;
    signal manual_ipbus_reset   : std_logic;

    --== TTC signals ==--
    signal ttc_cmd              : t_ttc_cmds;
    signal ttc_counters         : t_ttc_daq_cntrs;
    signal ttc_status           : t_ttc_status;
    signal daq_l1a_request      : std_logic := '0';
    signal daq_l1a_reset        : std_logic := '0';

    --== Spy path ==--
    signal spy_gbe_test_en      : std_logic;
    signal spy_gbe_test_data    : t_mgt_16b_tx_data;
    signal spy_gbe_daq_data     : t_mgt_16b_tx_data; 

    --== GBT ==--
    signal gbt_tx_data_arr              : t_gbt_frame_array(g_NUM_GBT_LINKS - 1 downto 0);
    signal gbt_rx_data_arr              : t_gbt_frame_array(g_NUM_GBT_LINKS - 1 downto 0);
    signal gbt_rx_valid_arr             : std_logic_vector(g_NUM_GBT_LINKS - 1 downto 0);
    signal gbt_tx_bitslip_arr           : t_std7_array(g_NUM_GBT_LINKS - 1 downto 0);
    signal gbt_link_status_arr          : t_gbt_link_status_arr(g_NUM_GBT_LINKS - 1 downto 0);
    signal gbt_ready_arr                : std_logic_vector(g_NUM_GBT_LINKS - 1 downto 0);

    --== GBT elinks ==--
    signal promless_tx_data             : std_logic_vector(15 downto 0);

    -- test module links
    signal test_gbt_wide_rx_data_arr    : t_gbt_wide_frame_array(g_NUM_GBT_LINKS - 1 downto 0);
    signal test_gbt_tx_data_arr         : t_gbt_frame_array(g_NUM_GBT_LINKS - 1 downto 0);
    signal test_gbt_ready_arr           : std_logic_vector(g_NUM_GBT_LINKS - 1 downto 0);
        
    --== TEST module ==--
    signal loopback_gbt_test_en         : std_logic; 

    --== XDCFEB ==--
    signal xdcfeb_switches              : t_xdcfeb_switches;
    signal xdcfeb_switches_regs         : t_xdcfeb_switches;
    signal xdcfeb_rx_data               : std_logic_vector(31 downto 0);
    
    --== Other ==--
    signal board_id             : std_logic_vector(15 downto 0);

    --== IPbus ==--
    signal ipb_miso_arr         : ipb_rbus_array(g_NUM_IPB_SLAVES - 1 downto 0) := (others => (ipb_rdata => (others => '0'), ipb_ack => '0', ipb_err => '0'));

    --== PROMless ==--
    signal promless_stats       : t_promless_stats := (load_request_cnt => (others => '0'), success_cnt => (others => '0'), fail_cnt => (others => '0'), gap_detect_cnt => (others => '0'), loader_ovf_unf_cnt => (others => '0'));
    signal promless_cfg         : t_promless_cfg;

begin

    --================================--
    -- I/O wiring  
    --================================--
    
    reset_pwrup_o <= reset_pwrup;
    reset <= reset_i or reset_pwrup or manual_global_reset;
    ipb_reset <= ipb_reset_i or reset_pwrup or manual_ipbus_reset;
    ipb_miso_arr_o <= ipb_miso_arr;
    link_reset <= manual_link_reset or ttc_cmd.hard_reset;

    ipb_miso_arr_o <= ipb_miso_arr;
    spy_tx_data_o <= spy_gbe_daq_data when spy_gbe_test_en = '0' else spy_gbe_test_data;
    
    board_id <= board_id_i;
    
    ttc_cmds_o <= ttc_cmd;

    --================================--
    -- Power-on reset  
    --================================--
    
    process(ttc_clocks_i.clk_40) -- NOTE: using TTC clock, no nothing will work if there's no TTC clock
        variable countdown : integer := 40_000_000; -- 1s - probably way too long, but ok for now (this is only used after powerup)
    begin
        if (rising_edge(ttc_clocks_i.clk_40)) then
            if (countdown > 0) then
              reset_pwrup <= '1';
              countdown := countdown - 1;
            else
              reset_pwrup <= '0';
            end if;
        end if;
    end process;    
    
    --================================--
    -- TTC  
    --================================--

    i_ttc : entity work.ttc
        generic map(
            g_DISABLE_TTC_DATA  => g_DISABLE_TTC_DATA,
            g_IPB_CLK_PERIOD_NS => g_IPB_CLK_PERIOD_NS
        )
        port map(
            reset_i             => reset,
            ttc_clks_i          => ttc_clocks_i,
            ttc_clks_status_i   => ttc_clk_status_i,
            ttc_clks_ctrl_o     => ttc_clk_ctrl_o,
            ttc_data_p_i        => ttc_data_p_i,
            ttc_data_n_i        => ttc_data_n_i,
            local_l1a_req_i     => daq_l1a_request or external_trigger_i,
            local_l1a_reset_i   => daq_l1a_reset,
            ttc_cmds_o          => ttc_cmd,
            ttc_daq_cntrs_o     => ttc_counters,
            ttc_status_o        => ttc_status,
            l1a_led_o           => open,
            ipb_reset_i         => ipb_reset,
            ipb_clk_i           => ipb_clk_i,
            ipb_mosi_i          => ipb_mosi_arr_i(C_IPB_SLV.ttc),
            ipb_miso_o          => ipb_miso_arr(C_IPB_SLV.ttc)
        );

    --================================--
    -- DAQ  
    --================================--

    i_daq : entity work.daq
        generic map(
            g_NUM_OF_DMBs       => g_NUM_OF_DMBs,
            g_DAQ_CLK_FREQ      => g_DAQLINK_CLK_FREQ,
            g_IS_SLINK_ROCKET   => g_USE_SLINK_ROCKET,
            g_IPB_CLK_PERIOD_NS => g_IPB_CLK_PERIOD_NS
        )
        port map(
            reset_i          => reset,
            daq_clk_i        => daqlink_clk_i,
            daq_clk_locked_i => daqlink_clk_locked_i,
            daq_to_daqlink_o => daq_to_daqlink_o,
            daqlink_to_daq_i => daqlink_to_daq_i,
            ttc_clks_i       => ttc_clocks_i,
            ttc_cmds_i       => ttc_cmd,
            ttc_daq_cntrs_i  => ttc_counters,
            ttc_status_i     => ttc_status,
            l1a_request_o    => daq_l1a_request,
            l1a_reset_req_o  => daq_l1a_reset,
            dmb_clk_i        => dmb_rx_usrclk_i,
            dmb_link_arr_i   => dmb_rx_data_arr_i,
            spy_clk_i        => spy_usrclk_i,
            spy_link_o       => spy_gbe_daq_data,
            ipb_reset_i      => ipb_reset,
            ipb_clk_i        => ipb_clk_i,
            ipb_mosi_i       => ipb_mosi_arr_i(C_IPB_SLV.daq),
            ipb_miso_o       => ipb_miso_arr(C_IPB_SLV.daq),
            board_id_i       => board_id,
            tts_ready_o      => open
        );    
    
    --================================--
    -- System registers
    --================================--

    i_system : entity work.system_regs
        generic map(
            g_SLR                => g_SLR,
            g_NUM_OF_DMBs        => g_NUM_OF_DMBs,
            g_NUM_IPB_MON_SLAVES => g_NUM_IPB_SLAVES,
            g_IPB_CLK_PERIOD_NS  => g_IPB_CLK_PERIOD_NS
        )
        port map(
            reset_i                => reset,
            ttc_clks_i             => ttc_clocks_i,
            ipb_clk_i              => ipb_clk_i,
            ipb_reset_i            => ipb_reset,
            ipb_mosi_i             => ipb_mosi_arr_i(C_IPB_SLV.system),
            ipb_miso_o             => ipb_miso_arr(C_IPB_SLV.system),
            ipb_mon_miso_arr_i     => ipb_miso_arr,
            global_reset_o         => manual_global_reset,
            gbt_reset_o            => manual_gbt_reset,
            manual_ipbus_reset_o   => manual_ipbus_reset,
            manual_link_reset_o    => manual_link_reset,
            loopback_gbt_test_en_o => loopback_gbt_test_en,
            xdcfeb_switches_o      => xdcfeb_switches_regs,
            xdcfeb_rx_data_i       => xdcfeb_rx_data,
            promless_stats_i       => promless_stats,
            promless_cfg_o         => promless_cfg
        );

    xdcfeb_switches.prog_b <= not ttc_cmd.hard_reset;
    xdcfeb_switches.prog_en <= xdcfeb_switches_regs.prog_en;
    xdcfeb_switches.gbt_override <= xdcfeb_switches_regs.gbt_override; 
    xdcfeb_switches.sel_gbt <= xdcfeb_switches_regs.sel_gbt; 
    xdcfeb_switches.sel_8bit <= xdcfeb_switches_regs.sel_8bit; 
    xdcfeb_switches.sel_master <= xdcfeb_switches_regs.sel_master; 
    xdcfeb_switches.sel_cclk_src <= xdcfeb_switches_regs.sel_cclk_src; 
    xdcfeb_switches.sel_gbt_cclk_src <= xdcfeb_switches_regs.sel_gbt_cclk_src;
    
    xdcfeb_switches.pattern_en <= xdcfeb_switches_regs.pattern_en;
    xdcfeb_switches.pattern_data <= xdcfeb_switches_regs.pattern_data;
    xdcfeb_switches.rx_select <= xdcfeb_switches_regs.rx_select;

    --================================--
    -- Link status monitor
    --================================--

    i_link_monitor : entity work.link_monitor
        generic map(
            g_NUM_OF_DMBs       => g_NUM_OF_DMBs,
            g_NUM_GBT_LINKS     => g_NUM_GBT_LINKS,
            g_IPB_CLK_PERIOD_NS => g_IPB_CLK_PERIOD_NS
        )
        port map(
            reset_i                 => reset,
            clk_i                   => dmb_rx_usrclk_i,

            -- TTC
            ttc_clks_i              => ttc_clocks_i,
            ttc_cmds_i              => ttc_cmd,
        
            -- DMB links
            dmb_rx_usrclk_i         => dmb_rx_usrclk_i,
            dmb_rx_data_arr_i       => dmb_rx_data_arr_i,
            dmb_rx_status_arr_i     => dmb_rx_status_arr_i,

            -- GBT links
            gbt_link_status_arr_i   => gbt_link_status_arr,
                                    
            -- Spy link             
            spy_usrclk_i            => spy_usrclk_i,
            spy_rx_data_i           => spy_rx_data_i,
            spy_rx_status_i         => spy_rx_status_i,
                                    
            -- IPbus                
            ipb_reset_i             => ipb_reset,
            ipb_clk_i               => ipb_clk_i,
            ipb_miso_o              => ipb_miso_arr(C_IPB_SLV.links),
            ipb_mosi_i              => ipb_mosi_arr_i(C_IPB_SLV.links)
        );

    --================================--
    -- Tests
    --================================--

    i_csc_tests : entity work.csc_tests
        generic map(
            g_NUM_OF_DMBs       => g_NUM_OF_DMBs,
            g_NUM_GBT_LINKS     => g_NUM_GBT_LINKS,
            g_IPB_CLK_PERIOD_NS => g_IPB_CLK_PERIOD_NS
        )
        port map(
            reset_i                => reset,
            
            -- TTC
            ttc_clk_i              => ttc_clocks_i,
            ttc_cmds_i             => ttc_cmd,
            
            -- GbE link
            gbe_clk_i              => spy_usrclk_i,
            gbe_tx_data_o          => spy_gbe_test_data,
            gbe_test_enable_o      => spy_gbe_test_en,
            
            -- GBT links
            loopback_gbt_test_en_i => loopback_gbt_test_en,
            gbt_link_ready_i       => test_gbt_ready_arr,
            gbt_tx_data_arr_o      => test_gbt_tx_data_arr,
            gbt_wide_rx_data_arr_i => test_gbt_wide_rx_data_arr,
            
            -- DMB links
            dmb_rx_usrclk_i        => dmb_rx_usrclk_i,
            dmb_rx_data_arr_i      => dmb_rx_data_arr_i,
            dmb_rx_status_arr_i    => dmb_rx_status_arr_i,  
            
            -- IPbus
            ipb_reset_i            => ipb_reset,
            ipb_clk_i              => ipb_clk_i,
            ipb_miso_o             => ipb_miso_arr(C_IPB_SLV.tests),
            ipb_mosi_i             => ipb_mosi_arr_i(C_IPB_SLV.tests)
        );

    --================================--
    -- GBT
    --================================--

    i_gbt : entity work.gbt
        generic map(
            NUM_LINKS           => g_NUM_GBT_LINKS,
            TX_OPTIMIZATION     => 1,
            RX_OPTIMIZATION     => 0,
            TX_ENCODING         => 0,
            RX_ENCODING_EVEN    => 0,
            RX_ENCODING_ODD     => 0,
            g_USE_RX_SYNC_FIFOS => false
        )
        port map(
            reset_i                     => reset or manual_gbt_reset,
            cnt_reset_i                 => link_reset,

            tx_frame_clk_i              => ttc_clocks_i.clk_40,
            rx_frame_clk_i              => ttc_clocks_i.clk_40,
            rx_word_common_clk_i        => gbt_rx_common_clk_i,
            tx_word_clk_arr_i           => gbt_tx_clk_arr_i,
            rx_word_clk_arr_i           => gbt_rx_clk_arr_i,

            tx_we_arr_i                 => (others => '1'),
            tx_data_arr_i               => gbt_tx_data_arr,
            tx_bitslip_cnt_i            => gbt_tx_bitslip_arr,

            rx_data_valid_arr_o         => gbt_rx_valid_arr,
            rx_data_arr_o               => gbt_rx_data_arr,
            rx_data_widebus_arr_o       => open,

            mgt_status_arr_i            => gbt_status_arr_i,
            mgt_ctrl_arr_o              => gbt_ctrl_arr_o,
            mgt_tx_data_arr_o           => gbt_tx_data_arr_o,
            mgt_rx_data_arr_i           => gbt_rx_data_arr_i,

            link_status_arr_o           => gbt_link_status_arr
        );

    i_gbt_link_mux : entity work.gbt_link_mux_csc
        generic map(
            g_NUM_LINKS  => g_NUM_GBT_LINKS
        )
        port map(
            gbt_frame_clk_i             => ttc_clocks_i.clk_40,
            
            gbt_rx_data_arr_i           => gbt_rx_data_arr,
            gbt_tx_data_arr_o           => gbt_tx_data_arr,
            gbt_link_status_arr_i       => gbt_link_status_arr,

            link_test_mode_i            => loopback_gbt_test_en,

            sca_tx_data_arr_i           => (others => (others => '0')),
            sca_rx_data_arr_o           => open,
            gbt_ic_tx_data_arr_i        => (others => (others => '1')),
            gbt_ic_rx_data_arr_o        => open,

            promless_tx_data_i          => promless_tx_data,
            xdcfeb_switches_i           => xdcfeb_switches,
            xdcfeb_rx_data_o            => xdcfeb_rx_data,

            gbt_ready_arr_o             => gbt_ready_arr,
            
            tst_gbt_wide_rx_data_arr_o  => test_gbt_wide_rx_data_arr,
            tst_gbt_tx_data_arr_i       => test_gbt_tx_data_arr,
            tst_gbt_ready_arr_o         => test_gbt_ready_arr
        );  

    --===========================--
    --    OH FPGA programming    --
    --===========================--

    i_fpga_loader : entity work.promless_fpga_loader
        generic map(
            g_LOADER_CLK_80_MHZ => true
        )
        port map(
            reset_i          => reset_i,
            gbt_clk_i        => ttc_clocks_i.clk_40,
            loader_clk_i     => ttc_clocks_i.clk_80,
            to_promless_o    => to_promless_o,
            from_promless_i  => from_promless_i,
            elink_data_o     => promless_tx_data,
            hard_reset_i     => ttc_cmd.hard_reset,
            promless_stats_o => promless_stats,
            promless_cfg_i   => promless_cfg
        );
            
    --================================--
    -- Debug
    --================================--

    i_ila_dmb0_link : entity work.ila_mgt_rx_16b_wrapper
        port map(
            clk_i        => dmb_rx_usrclk_i,
            rx_data_i    => dmb_rx_data_arr_i(0),
            mgt_status_i => dmb_rx_status_arr_i(0)
        );

    i_ila_dmb1_link : entity work.ila_mgt_rx_16b_wrapper
        port map(
            clk_i        => dmb_rx_usrclk_i,
            rx_data_i    => dmb_rx_data_arr_i(1),
            mgt_status_i => dmb_rx_status_arr_i(1)
        );

    i_ila_gbe_rx_link : entity work.ila_mgt_rx_16b_wrapper
        port map(
            clk_i        => spy_usrclk_i,
            rx_data_i    => spy_rx_data_i,
            mgt_status_i => spy_rx_status_i
        );

    i_ila_gbe_tx_link : entity work.ila_mgt_tx_16b_wrapper
        port map(
            clk_i   => spy_usrclk_i,
            kchar_i => spy_tx_data_o.txcharisk,
            data_i  => spy_tx_data_o.txdata
        );

end csc_fed_arch;
