------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    20:38:00 2016-08-30
-- Module Name:    GEM_TESTS
-- Description:    This module is the entry point for hardware tests e.g. fiber loopback testing with generated data 
------------------------------------------------------------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.csc_pkg.all;
use work.ttc_pkg.all;
use work.common_pkg.all;
use work.ipbus.all;
use work.registers.all;

entity csc_tests is
    generic(
        g_NUM_GBT_LINKS     : integer;
        g_NUM_OF_DMBs       : integer;
        g_IPB_CLK_PERIOD_NS : integer
    );
    port(
        -- reset
        reset_i                     : in  std_logic;
        
        -- TTC
        ttc_clk_i                   : in  t_ttc_clks;        
        ttc_cmds_i                  : in  t_ttc_cmds;
        
        -- GbE link
        gbe_clk_i                   : in  std_logic;
        gbe_tx_data_o               : out t_mgt_16b_tx_data;
        gbe_test_enable_o           : out std_logic; 
        
        -- GBT links
        loopback_gbt_test_en_i      : in std_logic;
        gbt_link_ready_i            : in  std_logic_vector(g_NUM_GBT_LINKS - 1 downto 0);
        gbt_tx_data_arr_o           : out t_gbt_frame_array(g_NUM_GBT_LINKS - 1 downto 0);
        gbt_wide_rx_data_arr_i      : in  t_gbt_wide_frame_array(g_NUM_GBT_LINKS - 1 downto 0);

        -- DMB links
        dmb_rx_usrclk_i             : in  std_logic;
        dmb_rx_data_arr2d_i         : in  t_mgt_64b_rx_data_arr_arr(g_NUM_OF_DMBs - 1 downto 0)(3 downto 0);
        dmb_rx_status_arr2d_i       : in  t_mgt_status_arr_arr(g_NUM_OF_DMBs - 1 downto 0)(3 downto 0);
                
        -- IPbus
        ipb_reset_i                 : in  std_logic;
        ipb_clk_i                   : in  std_logic;
        ipb_miso_o                  : out ipb_rbus;
        ipb_mosi_i                  : in  ipb_wbus        
    );
end csc_tests;

architecture Behavioral of csc_tests is

    -- reset
    signal reset_global         : std_logic;
    signal reset_local          : std_logic;
    signal reset                : std_logic;

    -- GbE test
    signal gbe_test_enable      : std_logic;
    signal gbe_user_data        : std_logic_vector(17 downto 0);
    signal gbe_user_data_en     : std_logic;
    signal gbe_send_en          : std_logic;
    signal gbe_busy             : std_logic;
    signal gbe_empty            : std_logic;
    
    signal gbe_manual_rd_enabled: std_logic;
    signal gbe_manual_rd_en     : std_logic;
    signal gbe_manual_rd_valid  : std_logic;
    signal gbe_manual_rd_data   : std_logic_vector(17 downto 0);
    
    -- GBT loopback test
    signal gbt_loop_reset       : std_logic;
    signal gbt_loop_link_select : std_logic_vector(3 downto 0);
    signal gbt_loop_err_inject  : std_logic;

    -- gbt loopback link
    signal gbt_loop_tx_link     : t_gbt_frame_array(0 downto 0);
    signal gbt_loop_rx_link     : t_gbt_wide_frame_array(0 downto 0);
    
    -- gbt loopback status
    signal gbt_loop_locked_arr          : std_logic_vector(9 downto 0);
    signal gbt_loop_mega_word_cnt_arr   : t_std32_array(9 downto 0);
    signal gbt_loop_error_cnt_arr       : t_std32_array(9 downto 0);
    
    -- dmb link test
    signal dmb_link_test_en     : std_logic;
    signal dmb_link_select      : std_logic_vector(6 downto 0);
    signal dmb_data_arr         : t_std64_array(g_NUM_OF_DMBs - 1 downto 0);
    signal dmb_charisk_arr      : t_std8_array(g_NUM_OF_DMBs - 1 downto 0);
    signal dmb_prbs_err_cnt     : std_logic_vector(31 downto 0);
    signal dmb_mega_words_cnt   : std_logic_vector(31 downto 0);

    ------ Register signals begin (this section is generated by <csc_amc_repo_root>/scripts/generate_registers.py -- do not edit)
    ------ Register signals end ----------------------------------------------    

begin

    --== Resets ==--
    
    i_reset_sync : entity work.synch
        generic map(
            N_STAGES => 3
        )
        port map(
            async_i => reset_i,
            clk_i   => ttc_clk_i.clk_40,
            sync_o  => reset_global
        );

    reset <= reset_global or reset_local;
    
    --== GBT loopback test ==--
    
    -- instantiate the OH tester
    i_prbs_test : entity work.gbt_prbs_loopback_test
        generic map(
            g_NUM_GBTS_PER_OH => 1,
            g_TX_ELINKS_PER_GBT  => 10,
            g_RX_ELINKS_PER_GBT  => 10
        )
        port map(
            reset_i                 => reset or gbt_loop_reset,
            enable_i                => loopback_gbt_test_en_i,
            gbt_clk_i               => ttc_clk_i.clk_40,
            gbt_tx_data_arr_o       => gbt_loop_tx_link,
            gbt_wide_rx_data_arr_i  => gbt_loop_rx_link,
            error_inject_en_i       => gbt_loop_err_inject,
            elink_prbs_locked_arr_o => gbt_loop_locked_arr,
            elink_mwords_cnt_arr_o  => gbt_loop_mega_word_cnt_arr,
            elink_error_cnt_arr_o   => gbt_loop_error_cnt_arr
        );
    
    -- fanout the tester TX to all links
    g_tx_links : for link in 0 to g_NUM_GBT_LINKS - 1 generate
        gbt_tx_data_arr_o(link) <= gbt_loop_tx_link(0);
    end generate;
    
    -- MUX the gbt RX links, and route the selected link to the tester
    g_rx_gbt : for gbt in 0 to g_NUM_GBT_LINKS - 1 generate
        gbt_loop_rx_link(0) <= gbt_wide_rx_data_arr_i(to_integer(unsigned(gbt_loop_link_select)));
    end generate;
    
    --== GbE test ==--
    
    gbe_test_enable_o <= gbe_test_enable;
    
    i_gbe_test : entity work.eth_test
        port map(
            reset_i                     => reset,
            gbe_clk_i                   => gbe_clk_i,
            gbe_tx_data_o               => gbe_tx_data_o,
            user_data_clk_i             => ipb_clk_i,
            user_data_i                 => gbe_user_data(15 downto 0),
            user_data_charisk_i         => gbe_user_data(17 downto 16),
            user_data_en_i              => gbe_user_data_en,
            send_en_i                   => gbe_send_en,
            busy_o                      => gbe_busy,
            empty_o                     => gbe_empty,
            manual_reading_enabled_i    => gbe_manual_rd_enabled,
            manual_read_en_i            => gbe_manual_rd_en,
            manual_read_data_o          => gbe_manual_rd_data,
            manual_read_valid_o         => gbe_manual_rd_valid
        );

    --== DMB link PRBS test ==--
    g_dmb_rx_links : for dmb in 0 to g_NUM_OF_DMBs - 1 generate
        dmb_data_arr(dmb)(15 downto 0) <= dmb_rx_data_arr2d_i(dmb)(0).rxdata(15 downto 0);
        dmb_data_arr(dmb)(63 downto 16) <= (others => '0');
        dmb_charisk_arr(dmb)(1 downto 0) <= dmb_rx_data_arr2d_i(dmb)(0).rxcharisk(1 downto 0);
        dmb_charisk_arr(dmb)(7 downto 2) <= (others => '0');
    end generate;
    
    i_dmb_prbs_test : entity work.link_prbs_test
        generic map(
            g_NUM_RX_LINKS         => g_NUM_OF_DMBs,
            g_BUS_WIDTH            => 16,
            g_IDLE_WORD_WIDTH      => 8,
            g_IDLE_WORD_DATA       => x"bc",
            g_IDLE_CHAR_IS_K       => "1",
            g_PRBS_ERR_CNT_WIDTH   => 32,
            g_MEGA_WORDS_CNT_WIDTH => 32,
            g_DEBUG                => false
            
        )
        port map(
            reset_i                 => reset,
            enable_i                => dmb_link_test_en,
            rx_link_select_i        => dmb_link_select,
            rx_common_usrclk_i      => dmb_rx_usrclk_i,
            rx_data_arr_i           => dmb_data_arr,
            rx_charisk_arr_i        => dmb_charisk_arr,
            rx_error_cnt_o          => dmb_prbs_err_cnt,
            rx_mega_words_checked_o => dmb_mega_words_cnt
        );


    --===============================================================================================
    -- this section is generated by <csc_amc_repo_root>/scripts/generate_registers.py (do not edit) 
    --==== Registers begin ==========================================================================

    --==== Registers end ============================================================================

end Behavioral;
