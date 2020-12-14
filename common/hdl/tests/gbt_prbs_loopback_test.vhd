------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2020-01-27
-- Module Name:    GEM_PRBS_LOOPBACK_TEST
-- Description:    This module is used for PRBS loopback tests for a single OH over all of its GBTs
------------------------------------------------------------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gem_pkg.all;

entity gbt_prbs_loopback_test is
    generic(
        g_NUM_GBTS_PER_OH           : integer;
        g_TX_ELINKS_PER_GBT         : integer;
        g_RX_ELINKS_PER_GBT         : integer
    );
    port(
        -- reset
        reset_i                 : in  std_logic;
        
        -- gbt links
        gbt_clk_i               : in  std_logic;
        gbt_tx_data_arr_o       : out t_gbt_frame_array(g_NUM_GBTS_PER_OH - 1 downto 0);
        gbt_wide_rx_data_arr_i  : in  t_gbt_wide_frame_array(g_NUM_GBTS_PER_OH - 1 downto 0);
        
        -- control
        error_inject_en_i       : in  std_logic; -- injects a PRBS error on the TX data when high
        
        -- status
        elink_prbs_locked_arr_o : out std_logic_vector(g_NUM_GBTS_PER_OH * g_RX_ELINKS_PER_GBT - 1 downto 0);
        elink_mwords_cnt_arr_o  : out t_std32_array(g_NUM_GBTS_PER_OH * g_RX_ELINKS_PER_GBT - 1 downto 0);
        elink_error_cnt_arr_o   : out t_std32_array(g_NUM_GBTS_PER_OH * g_RX_ELINKS_PER_GBT - 1 downto 0)
    );
end gbt_prbs_loopback_test;

architecture gbt_prbs_loopback_test_arch of gbt_prbs_loopback_test is

    constant PRBS_SEED          : std_logic_vector(7 downto 0) := x"d9";
    constant PRBS_ERR_PATTERN   : std_logic_vector(7 downto 0) := x"ff";
    
    signal tx_prbs_data         : std_logic_vector(7 downto 0);
    signal tx_prbs_err_data     : std_logic_vector(7 downto 0);

    signal rx_prbs_ready_arr    : std_logic_vector(g_NUM_GBTS_PER_OH * g_RX_ELINKS_PER_GBT - 1 downto 0);
    signal rx_prbs_err_arr      : std_logic_vector(g_NUM_GBTS_PER_OH * g_RX_ELINKS_PER_GBT - 1 downto 0);
    
    signal rx_err_cnt_arr       : t_std32_array(g_NUM_GBTS_PER_OH * g_RX_ELINKS_PER_GBT - 1 downto 0) := (others => (others => '0'));

    signal pulse_40hz           : std_logic;

begin

    --============== TX data generation ==============--

    -- generator (fanned out to all elinks)
    i_prbs7_8b_gen : entity work.prbs7_8b_generator
        generic map(
            INIT_c => PRBS_SEED
        )
        port map(
            reset_i       => reset_i,
            clk_i         => gbt_clk_i,
            clken_i       => '1',
            err_pattern_i => tx_prbs_err_data,
            rep_delay_i   => (others => '0'),
            prbs_word_o   => tx_prbs_data,
            rdy_o         => open
        );
    
    -- error injection data (0x00 means no injection)    
    tx_prbs_err_data <= x"00" when error_inject_en_i = '0' else PRBS_ERR_PATTERN;
    
    -- fanout the PRBS data to all TX elinks
    g_tx_gbts : for gbt in 0 to g_NUM_GBTS_PER_OH - 1 generate
        g_tx_elinks : for elink in 0 to g_TX_ELINKS_PER_GBT - 1 generate

            gbt_tx_data_arr_o(gbt)(elink * 8 + 7 downto elink * 8) <= tx_prbs_data;
        
        end generate;
    end generate;

    --============== RX checking logic ==============--

    g_rx_gbts : for gbt in 0 to g_NUM_GBTS_PER_OH - 1 generate
        g_rx_elinks : for elink in 0 to g_RX_ELINKS_PER_GBT - 1 generate

            -- PRBS7 checker instantiation
            i_prbs7_8b_check : entity work.prbs7_8b_checker
                port map(
                    reset_i     => reset_i,
                    clk_i       => gbt_clk_i,
                    clken_i     => '1',
                    prbs_word_i => gbt_wide_rx_data_arr_i(gbt)(elink * 8 + 7 downto elink * 8),
                    err_o       => open,
                    err_flag_o  => rx_prbs_err_arr(gbt * g_RX_ELINKS_PER_GBT + elink),
                    rdy_o       => rx_prbs_ready_arr(gbt * g_RX_ELINKS_PER_GBT + elink)
                );

            -- checked words counter (in units of 1 million)
            i_prbs7_mega_word_cnt : entity work.counter
                generic map(
                    g_COUNTER_WIDTH  => 32,
                    g_ALLOW_ROLLOVER => false
                )
                port map(
                    ref_clk_i => gbt_clk_i,
                    reset_i   => reset_i,
                    en_i      => rx_prbs_ready_arr(gbt * g_RX_ELINKS_PER_GBT + elink) and pulse_40hz,
                    count_o   => elink_mwords_cnt_arr_o(gbt * g_RX_ELINKS_PER_GBT + elink)
                );
        
            -- error counter
            i_prbs7_err_cnt : entity work.counter
                generic map(
                    g_COUNTER_WIDTH  => 31,
                    g_ALLOW_ROLLOVER => false
                )
                port map(
                    ref_clk_i => gbt_clk_i,
                    reset_i   => reset_i,
                    en_i      => rx_prbs_err_arr(gbt * g_RX_ELINKS_PER_GBT + elink) and rx_prbs_ready_arr(gbt * g_RX_ELINKS_PER_GBT + elink),
                    count_o   => rx_err_cnt_arr(gbt * g_RX_ELINKS_PER_GBT + elink)(30 downto 0)
                );
            
            elink_error_cnt_arr_o <= rx_err_cnt_arr;
        
        end generate;
    end generate;
    
    elink_prbs_locked_arr_o <= rx_prbs_ready_arr;
    
    -- 40 Hz pulse for counting mega words 
    process (gbt_clk_i)
        variable countdown : integer := 1_000_000;
    begin
        if (rising_edge(gbt_clk_i)) then
            if (countdown = 0) then
                pulse_40hz <= '1';
                countdown := 1_000_000;
            else
                pulse_40hz <= '0';
                countdown := countdown - 1;
            end if;
        end if;
    end process;    
    
end gbt_prbs_loopback_test_arch;
