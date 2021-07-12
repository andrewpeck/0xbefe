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
        g_NUM_OF_DMBs        : integer;
        g_NUM_IPB_SLAVES     : integer;
        g_IPB_CLK_PERIOD_NS  : integer;
        g_DAQLINK_CLK_FREQ   : integer;
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
        
        -- DMB links
        csc_dmb_rx_usrclk_arr_i : in  std_logic_vector(g_NUM_OF_DMBs - 1 downto 0);
        csc_dmb_rx_data_arr_i   : in  t_mgt_16b_rx_data_arr(g_NUM_OF_DMBs - 1 downto 0);
        csc_dmb_rx_status_arr_i : in  t_mgt_status_arr(g_NUM_OF_DMBs - 1 downto 0);

        -- Spy link
        csc_spy_usrclk_i        : in  std_logic;
        csc_spy_rx_data_i       : in  t_mgt_16b_rx_data;
        csc_spy_tx_data_o       : out t_mgt_16b_tx_data;                
        csc_spy_rx_status_i     : in  t_mgt_status;

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
    signal ttc_clocks           : t_ttc_clks;
    signal ttc_cmd              : t_ttc_cmds;
    signal ttc_counters         : t_ttc_daq_cntrs;
    signal ttc_status           : t_ttc_status;
    signal daq_l1a_request      : std_logic := '0';

    --== Spy path ==--
    signal spy_gbe_test_en      : std_logic;
    signal spy_gbe_test_data    : t_mgt_16b_tx_data;
    signal spy_gbe_daq_data     : t_mgt_16b_tx_data; 

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
    csc_spy_tx_data_o <= spy_gbe_daq_data when spy_gbe_test_en = '0' else spy_gbe_test_data;
    
    board_id <= board_id_i;

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
            local_l1a_req_i     => daq_l1a_request,
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
            g_IPB_CLK_PERIOD_NS => g_IPB_CLK_PERIOD_NS
        )
        port map(
            reset_i          => reset,
            daq_clk_i        => daqlink_clk_i,
            daq_clk_locked_i => daqlink_clk_locked_i,
            daq_to_daqlink_o => daq_to_daqlink_o,
            daqlink_to_daq_i => daqlink_to_daq_i,
            ttc_clks_i       => ttc_clocks,
            ttc_cmds_i       => ttc_cmd,
            ttc_daq_cntrs_i  => ttc_counters,
            ttc_status_i     => ttc_status,
            l1a_request_o    => daq_l1a_request,
            input_clk_arr_i  => csc_dmb_rx_usrclk_arr_i,
            input_link_arr_i => csc_dmb_rx_data_arr_i,
            spy_clk_i        => csc_spy_usrclk_i,
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
            g_NUM_OF_DMBs        => g_NUM_OF_DMBs,
            g_NUM_IPB_MON_SLAVES => g_NUM_IPB_SLAVES,
            g_IPB_CLK_PERIOD_NS  => g_IPB_CLK_PERIOD_NS
        )
        port map(
            reset_i              => reset,
            ttc_clks_i           => ttc_clocks_i,
            ipb_clk_i            => ipb_clk_i,
            ipb_reset_i          => ipb_reset,
            ipb_mosi_i           => ipb_mosi_arr_i(C_IPB_SLV.system),
            ipb_miso_o           => ipb_miso_arr(C_IPB_SLV.system),
            ipb_mon_miso_arr_i   => ipb_miso_arr,
            global_reset_o       => manual_global_reset,
            gbt_reset_o          => manual_gbt_reset,
            manual_ipbus_reset_o => manual_ipbus_reset,
            manual_link_reset_o  => manual_link_reset,
            promless_stats_i     => promless_stats,
            promless_cfg_o       => promless_cfg
        );

    --================================--
    -- Link status monitor
    --================================--

    i_link_monitor : entity work.link_monitor
        generic map(
            g_NUM_OF_DMBs       => g_NUM_OF_DMBs,
            g_IPB_CLK_PERIOD_NS => g_IPB_CLK_PERIOD_NS
        )
        port map(
            reset_i                 => reset,
            clk_i                   => csc_dmb_rx_usrclk_arr_i(0),

            -- TTC
            ttc_clks_i              => ttc_clocks,
            ttc_cmds_i              => ttc_cmd,
        
            -- DMB links
            csc_dmb_rx_usrclk_arr_i => csc_dmb_rx_usrclk_arr_i,
            csc_dmb_rx_data_arr_i   => csc_dmb_rx_data_arr_i,
            csc_dmb_rx_status_arr_i => csc_dmb_rx_status_arr_i,
    
            -- Spy link
            csc_spy_usrclk_i        => csc_spy_usrclk_i,
            csc_spy_rx_data_i       => csc_spy_rx_data_i,
            csc_spy_rx_status_i     => csc_spy_rx_status_i,
                
            -- IPbus
            ipb_reset_i            => ipb_reset,
            ipb_clk_i              => ipb_clk_i,
            ipb_miso_o             => ipb_miso_arr(C_IPB_SLV.links),
            ipb_mosi_i             => ipb_mosi_arr_i(C_IPB_SLV.links)
        );

    --================================--
    -- Tests
    --================================--

    i_csc_tests : entity work.csc_tests
        generic map(
            g_IPB_CLK_PERIOD_NS => g_IPB_CLK_PERIOD_NS
        )
        port map(
            reset_i           => reset,
            ttc_clk_i         => ttc_clocks,
            ttc_cmds_i        => ttc_cmd,
            gbe_clk_i         => csc_spy_usrclk_i,
            gbe_tx_data_o     => spy_gbe_test_data,
            gbe_test_enable_o => spy_gbe_test_en,
            ipb_reset_i       => ipb_reset,
            ipb_clk_i         => ipb_clk_i,
            ipb_miso_o        => ipb_miso_arr(C_IPB_SLV.tests),
            ipb_mosi_i        => ipb_mosi_arr_i(C_IPB_SLV.tests)
        );

    --================================--
    -- Debug
    --================================--

    i_ila_dmb0_link : entity work.gt_rx_link_ila_wrapper
        port map(
            clk_i        => csc_dmb_rx_usrclk_arr_i(0),
            rx_data_i    => csc_dmb_rx_data_arr_i(0),
            mgt_status_i => csc_dmb_rx_status_arr_i(0)
        );

    i_ila_dmb1_link : entity work.gt_rx_link_ila_wrapper
        port map(
            clk_i        => csc_dmb_rx_usrclk_arr_i(1),
            rx_data_i    => csc_dmb_rx_data_arr_i(1),
            mgt_status_i => csc_dmb_rx_status_arr_i(1)
        );

    i_ila_gbe_rx_link : entity work.gt_rx_link_ila_wrapper
        port map(
            clk_i        => csc_spy_usrclk_i,
            rx_data_i    => csc_spy_rx_data_i,
            mgt_status_i => csc_spy_rx_status_i
        );

    i_ila_gbe_tx_link : entity work.gt_tx_link_ila_wrapper
        port map(
            clk_i   => csc_spy_usrclk_i,
            kchar_i => csc_spy_tx_data_o.txcharisk,
            data_i  => csc_spy_tx_data_o.txdata
        );

end csc_fed_arch;
