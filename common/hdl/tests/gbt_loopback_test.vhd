------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    20:38:00 2016-08-30
-- Module Name:    GEM_LOOPBACK_TEST
-- Description:    This module is used to send generated data over a GBT link and check that the received data is what is expected and count errors 
------------------------------------------------------------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gem_pkg.all;

entity gbt_loopback_test is
    port(
        -- reset
        reset_i                 : in  std_logic;
        
        -- control
        oh_in_the_loop_i        : in std_logic;
        
        -- gbt link
        gbt_clk_i               : in  std_logic;
        gbt_link_ready_i        : in  std_logic;
        gbt_tx_data_o           : out std_logic_vector(83 downto 0);
        gbt_rx_data_i           : in  std_logic_vector(83 downto 0);
        
        -- status
        link_sync_done_o        : out std_logic;
        mega_word_cnt_o         : out std_logic_vector(31 downto 0);
        error_cnt_o             : out std_logic_vector(31 downto 0)
    );
end gbt_loopback_test;

architecture Behavioral of gbt_loopback_test is
    
    constant SYNC_PATTERN : std_logic_vector(83 downto 0) := x"076bc76bc76bc76bc76bc";
    
    signal link_sync_done   : std_logic := '0';
    
    signal mega_word_en     : std_logic := '0';
    signal error_en         : std_logic := '0';
    
    signal mega_word_cnt    : std_logic_vector(31 downto 0) := (others => '0');
    signal error_cnt        : std_logic_vector(31 downto 0) := (others => '0');
    
    -- FSMs
    type tx_state_t is (SYNC, TEST_BEGIN, RUNNING);
    type rx_state_t is (SYNC, WAITING_TEST_BEGIN, RUNNING);

    signal tx_state         : tx_state_t;
    signal rx_state         : rx_state_t;
    
    -- generated data
    signal tx_test_counter  : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_test_counter  : std_logic_vector(7 downto 0) := (others => '0');

begin

    --============== Wiring ==============--
    
    link_sync_done_o <= link_sync_done;
    mega_word_cnt_o <= mega_word_cnt;
    error_cnt_o <= error_cnt;

    --============== TX FSM ==============--
    
    process(gbt_clk_i)
    begin
        if (rising_edge(gbt_clk_i)) then
            if (reset_i = '1') then
                tx_state <= SYNC;
            else
                if (link_sync_done = '0') then
                    tx_state <= SYNC;
                else
                    case tx_state is
                        when SYNC        => tx_state <= TEST_BEGIN;
                        when TEST_BEGIN  => tx_state <= RUNNING;
                        when RUNNING     => tx_state <= RUNNING;
                        when others      => tx_state <= SYNC;
                    end case;
                end if;
            end if;
        end if;
    end process;

    --============== TX ==============--
    
    process(gbt_clk_i)
    begin
        if (rising_edge(gbt_clk_i)) then
            if (reset_i = '1') then
                tx_test_counter <= (others => '0');
                gbt_tx_data_o <= (others => '0');
            else
                case tx_state is
                    when SYNC =>
                        tx_test_counter <= (others => '0');
                        gbt_tx_data_o <= SYNC_PATTERN;
                    when TEST_BEGIN =>
                        tx_test_counter <= (others => '0');
                        gbt_tx_data_o <= not SYNC_PATTERN;
                    when RUNNING =>
                        tx_test_counter <= std_logic_vector(unsigned(tx_test_counter) + 1);
                        gbt_tx_data_o <= x"0" & tx_test_counter & not tx_test_counter &
                                                tx_test_counter & not tx_test_counter &
                                                tx_test_counter & not tx_test_counter &
                                                tx_test_counter & not tx_test_counter &
                                                tx_test_counter & not tx_test_counter;
                    when others =>
                        tx_test_counter <= (others => '0');
                        gbt_tx_data_o <= (others => '0');
                end case;
            end if;
        end if;
    end process;    

    --============== RX FSM ==============--
    
    process(gbt_clk_i)
    begin
        if (rising_edge(gbt_clk_i)) then
            if (reset_i = '1') then
                rx_state <= SYNC;
            else
                if (link_sync_done = '0') then
                    rx_state <= SYNC;
                else
                    case rx_state is
                        when SYNC => rx_state <= WAITING_TEST_BEGIN;
                        when WAITING_TEST_BEGIN =>
                            if (oh_in_the_loop_i = '0') then
                                if (gbt_rx_data_i = not SYNC_PATTERN) then -- start running when we see an inverted sync pattern
                                    rx_state <= RUNNING;
                                end if;
                            else
                                if ((gbt_rx_data_i(71 downto 64) = not SYNC_PATTERN(47 downto 40)) and
                                    (gbt_rx_data_i(55 downto 48) = not SYNC_PATTERN(39 downto 32)) and
                                    (gbt_rx_data_i(39 downto 32) = not SYNC_PATTERN(47 downto 40)) and
                                    (gbt_rx_data_i(7 downto 0) = not SYNC_PATTERN(39 downto 32)))
                                then
                                    rx_state <= RUNNING;
                                end if;                                
                            end if;
                        when RUNNING => rx_state <= RUNNING;
                        when others => rx_state <= SYNC;
                    end case;
                end if;
            end if;
        end if;
    end process;

    --============== RX ==============--
    
    process(gbt_clk_i)
    begin
        if (rising_edge(gbt_clk_i)) then
            if (reset_i = '1') then
                link_sync_done <= '0';
                rx_test_counter <= (others => '0');
                error_en <= '0';
            else
                if (gbt_link_ready_i = '0') then
                    link_sync_done <= '0';
                    rx_test_counter <= (others => '0');
                    error_en <= '0';
                else
                    case rx_state is
                        when SYNC =>
                            error_en <= '0';
                            rx_test_counter <= (others => '0');
                            if (oh_in_the_loop_i = '0') then
                                if (gbt_rx_data_i = SYNC_PATTERN) then
                                    link_sync_done <= '1';
                                end if;
                            else
                                if ((gbt_rx_data_i(71 downto 64) = SYNC_PATTERN(47 downto 40)) and
                                    (gbt_rx_data_i(55 downto 48) = SYNC_PATTERN(39 downto 32)) and
                                    (gbt_rx_data_i(39 downto 32) = SYNC_PATTERN(47 downto 40)) and
                                    (gbt_rx_data_i(7 downto 0) = SYNC_PATTERN(39 downto 32)))
                                then
                                    link_sync_done <= '1';
                                end if;
                            end if;
                        when RUNNING =>
                            rx_test_counter <= std_logic_vector(unsigned(rx_test_counter) + 1);
                            if (oh_in_the_loop_i = '0') then
                                if (gbt_rx_data_i = x"0" & rx_test_counter & not rx_test_counter &
                                                           rx_test_counter & not rx_test_counter &
                                                           rx_test_counter & not rx_test_counter &
                                                           rx_test_counter & not rx_test_counter &
                                                           rx_test_counter & not rx_test_counter)
                                then
                                    error_en <= '0';
                                else
                                    error_en <= '1';
                                end if;
                            else
                                if ((gbt_rx_data_i(71 downto 64) = rx_test_counter) and
                                    (gbt_rx_data_i(55 downto 48) = not rx_test_counter) and
                                    (gbt_rx_data_i(39 downto 32) = rx_test_counter) and
                                    (gbt_rx_data_i(7 downto 0) = not rx_test_counter))
                                then
                                    error_en <= '0';
                                else
                                    error_en <= '1';
                                end if;
                            end if;
                        when others =>
                            error_en <= '0';
                    end case;
                end if;
            end if;
        end if;
    end process;

    --============== Counters ==============--

    -- process for counting mega words
    process (gbt_clk_i)
        variable countdown : integer := 1_000_000;
    begin
        if (rising_edge(gbt_clk_i)) then
            if ((reset_i = '1') or (rx_state /= RUNNING)) then
                mega_word_en <= '0';
                countdown := 1_000_000;
            else
                if (countdown = 0) then
                    mega_word_en <= '1';
                    countdown := 1_000_000;
                else
                    mega_word_en <= '0';
                    countdown := countdown - 1;
                end if;
            end if;
        end if;
    end process;
    
    i_mega_word_cnt : entity work.counter
        generic map(
            g_COUNTER_WIDTH  => 32,
            g_ALLOW_ROLLOVER => false
        )
        port map(
            ref_clk_i => gbt_clk_i,
            reset_i   => reset_i or (not link_sync_done),
            en_i      => mega_word_en,
            count_o   => mega_word_cnt
        );

    i_error_cnt : entity work.counter
        generic map(
            g_COUNTER_WIDTH  => 32,
            g_ALLOW_ROLLOVER => false
        )
        port map(
            ref_clk_i => gbt_clk_i,
            reset_i   => reset_i or (not link_sync_done),
            en_i      => error_en,
            count_o   => error_cnt
        );

end Behavioral;
