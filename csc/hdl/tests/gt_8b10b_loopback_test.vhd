------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    16:36:00 2016-09-21
-- Module Name:    GT_8B10B_LOOPBACK_TEST
-- Description:    This module is used to send generated data over an 8b10b link and check that the received data is what is expected and count errors 
------------------------------------------------------------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gem_pkg.all;

entity gt_8b10b_loopback_test is
    port(
        -- reset
        reset_i                 : in  std_logic;
        
        -- 8b10b link
        link_clk_i              : in  std_logic;
        daq_tx_data_o           : out t_gt_8b10b_tx_data;
        daq_rx_data_i           : in  t_gt_8b10b_rx_data;
        trig0_rx_data_i         : in  t_gt_8b10b_rx_data;
        trig1_rx_data_i         : in  t_gt_8b10b_rx_data;
        
        -- control
        use_trig_links          : in std_logic;
        
        -- status
        mega_word_cnt_o         : out std_logic_vector(31 downto 0);

        daq_link_sync_done_o    : out std_logic;
        daq_error_cnt_o         : out std_logic_vector(31 downto 0);

        trig0_link_sync_done_o  : out std_logic;
        trig0_error_cnt_o       : out std_logic_vector(31 downto 0);

        trig1_link_sync_done_o  : out std_logic;
        trig1_error_cnt_o       : out std_logic_vector(31 downto 0)
    );
end gt_8b10b_loopback_test;

architecture Behavioral of gt_8b10b_loopback_test is

    constant SYNC_PATTERN       : std_logic_vector(15 downto 0) := x"12bc";
    constant BEGIN_PATTERN      : std_logic_vector(15 downto 0) := x"fafa";
    
    signal links_sync_done      : std_logic := '0';
    
    signal daq_valid_sync_cnt   : integer range 0 to 127;
    signal trig0_valid_sync_cnt : integer range 0 to 127;
    signal trig1_valid_sync_cnt : integer range 0 to 127;
    
    signal daq_link_sync_done   : std_logic := '0';
    signal trig0_link_sync_done : std_logic := '0';
    signal trig1_link_sync_done : std_logic := '0';
    
    signal mega_word_en         : std_logic := '0';
    signal daq_error_en         : std_logic := '0';
    signal trig0_error_en       : std_logic := '0';
    signal trig1_error_en       : std_logic := '0';
    
    signal mega_word_cnt        : std_logic_vector(31 downto 0) := (others => '0');
    signal daq_error_cnt        : std_logic_vector(31 downto 0) := (others => '0');
    signal trig0_error_cnt      : std_logic_vector(31 downto 0) := (others => '0');
    signal trig1_error_cnt      : std_logic_vector(31 downto 0) := (others => '0');
    
    -- FSMs
    type tx_state_t is (SYNC, TEST_BEGIN, RUNNING_CNT0, RUNNING_CNT1, RUNNING_CNT2, RUNNING_CNT3);
    type rx_state_t is (SYNC, WAITING_TEST_BEGIN, RUNNING_CNT0, RUNNING_CNT1, RUNNING_CNT2, RUNNING_CNT3);

    signal tx_state             : tx_state_t;
    signal daq_rx_state         : rx_state_t;
    signal trig0_rx_state       : rx_state_t;
    signal trig1_rx_state       : rx_state_t;
    
    -- generated data
    signal tx_test_counter      : std_logic_vector(7 downto 0) := (others => '0');
    signal daq_rx_test_counter  : std_logic_vector(7 downto 0) := (others => '0');
    signal trig0_rx_test_counter: std_logic_vector(7 downto 0) := (others => '0');
    signal trig1_rx_test_counter: std_logic_vector(7 downto 0) := (others => '0');

begin

    --============== Wiring ==============--
    
    mega_word_cnt_o <= mega_word_cnt;

    daq_link_sync_done_o <= daq_link_sync_done;
    daq_error_cnt_o <= daq_error_cnt;
    trig0_link_sync_done_o <= trig0_link_sync_done;
    trig0_error_cnt_o <= trig0_error_cnt;
    trig1_link_sync_done_o <= trig1_link_sync_done;
    trig1_error_cnt_o <= trig1_error_cnt;

    links_sync_done <= daq_link_sync_done when use_trig_links = '0' else daq_link_sync_done and trig0_link_sync_done and trig1_link_sync_done;
    
    --============== TX FSM ==============--
    
    process(link_clk_i)
    begin
        if (rising_edge(link_clk_i)) then
            if (reset_i = '1') then
                tx_state <= SYNC;
            else
                if (links_sync_done = '0') then
                    tx_state <= SYNC;
                else
                    case tx_state is
                        when SYNC           => tx_state <= TEST_BEGIN;
                        when TEST_BEGIN     => tx_state <= RUNNING_CNT0;
                        when RUNNING_CNT0   => tx_state <= RUNNING_CNT1;
                        when RUNNING_CNT1   => tx_state <= RUNNING_CNT2;
                        when RUNNING_CNT2   => tx_state <= RUNNING_CNT3;
                        when RUNNING_CNT3   => tx_state <= RUNNING_CNT0;
                        when others         => tx_state <= SYNC;
                    end case;
                end if;
            end if;
        end if;
    end process;

    --============== TX ==============--
    
    process(link_clk_i)
    begin
        if (rising_edge(link_clk_i)) then
            if (reset_i = '1') then
                tx_test_counter <= (others => '0');
                daq_tx_data_o.txdata <= (others => '0');
                daq_tx_data_o.txcharisk <= (others => '0');
            else
                case tx_state is
                    when SYNC =>
                        tx_test_counter <= (others => '0');
                        daq_tx_data_o.txdata(15 downto 0) <= SYNC_PATTERN;
                        daq_tx_data_o.txcharisk(1 downto 0) <= "01";
                    when TEST_BEGIN =>
                        tx_test_counter <= (others => '0');
                        daq_tx_data_o.txdata(15 downto 0) <= BEGIN_PATTERN;
                        daq_tx_data_o.txcharisk(1 downto 0) <= "00";
                    when RUNNING_CNT0 =>
                        tx_test_counter <= std_logic_vector(unsigned(tx_test_counter) + 1);
                        daq_tx_data_o.txdata(15 downto 0) <= tx_test_counter & x"bc";
                        daq_tx_data_o.txcharisk(1 downto 0) <= "01";
                    when RUNNING_CNT1 =>
                        tx_test_counter <= std_logic_vector(unsigned(tx_test_counter) + 1);
                        daq_tx_data_o.txdata(15 downto 0) <= not tx_test_counter & tx_test_counter;
                        daq_tx_data_o.txcharisk(1 downto 0) <= "00";
                    when RUNNING_CNT2 =>
                        tx_test_counter <= std_logic_vector(unsigned(tx_test_counter) + 1);
                        daq_tx_data_o.txdata(15 downto 0) <= tx_test_counter & not tx_test_counter;
                        daq_tx_data_o.txcharisk(1 downto 0) <= "00";
                    when RUNNING_CNT3 =>
                        tx_test_counter <= std_logic_vector(unsigned(tx_test_counter) + 1);
                        daq_tx_data_o.txdata(15 downto 0) <= not tx_test_counter & tx_test_counter;
                        daq_tx_data_o.txcharisk(1 downto 0) <= "00";
                    when others =>
                        tx_test_counter <= (others => '0');
                        daq_tx_data_o.txdata <= (others => '0');
                        daq_tx_data_o.txcharisk <= (others => '0');
                end case;
            end if;
        end if;
    end process;    

    --============== DAQ RX FSM ==============--
    
    process(link_clk_i)
    begin
        if (rising_edge(link_clk_i)) then
            if (reset_i = '1') then
                daq_rx_state <= SYNC;
            else
                if (links_sync_done = '0') then
                    daq_rx_state <= SYNC;
                else
                    case daq_rx_state is
                        when SYNC => daq_rx_state <= WAITING_TEST_BEGIN;
                        when WAITING_TEST_BEGIN =>
                            if (daq_rx_data_i.rxdata(15 downto 0) = BEGIN_PATTERN) then
                                daq_rx_state <= RUNNING_CNT0;
                            end if;
                        when RUNNING_CNT0 => daq_rx_state <= RUNNING_CNT1;
                        when RUNNING_CNT1 => daq_rx_state <= RUNNING_CNT2;
                        when RUNNING_CNT2 => daq_rx_state <= RUNNING_CNT3;
                        when RUNNING_CNT3 => daq_rx_state <= RUNNING_CNT0;
                        when others => daq_rx_state <= SYNC;
                    end case;
                end if;
            end if;
        end if;
    end process;

    --============== DAQ RX ==============--
    
    process(link_clk_i)
    begin
        if (rising_edge(link_clk_i)) then
            if (reset_i = '1') then
                daq_link_sync_done <= '0';
                daq_rx_test_counter <= (others => '0');
                daq_error_en <= '0';
            else
                case daq_rx_state is
                    when SYNC =>
                        daq_error_en <= '0';
                        daq_rx_test_counter <= (others => '0');
                        
                        if (daq_valid_sync_cnt >= 50) then
                            daq_link_sync_done <= '1';
                        elsif (daq_rx_data_i.rxdata(15 downto 0) = SYNC_PATTERN) then
                            daq_valid_sync_cnt <= daq_valid_sync_cnt + 1;
                        else
                            daq_valid_sync_cnt <= 0;
                        end if;
                    when RUNNING_CNT0 =>
                        daq_rx_test_counter <= std_logic_vector(unsigned(daq_rx_test_counter) + 1);
                        if (daq_rx_data_i.rxdata(15 downto 0) = daq_rx_test_counter & x"bc") then
                            daq_error_en <= '0';
                        else
                            daq_error_en <= '1';
                        end if;
                    when RUNNING_CNT1 =>
                        daq_rx_test_counter <= std_logic_vector(unsigned(daq_rx_test_counter) + 1);
                        if (daq_rx_data_i.rxdata(15 downto 0) = not daq_rx_test_counter & daq_rx_test_counter) then
                            daq_error_en <= '0';
                        else
                            daq_error_en <= '1';
                        end if;
                    when RUNNING_CNT2 =>
                        daq_rx_test_counter <= std_logic_vector(unsigned(daq_rx_test_counter) + 1);
                        if (daq_rx_data_i.rxdata(15 downto 0) = daq_rx_test_counter & not daq_rx_test_counter) then
                            daq_error_en <= '0';
                        else
                            daq_error_en <= '1';
                        end if;
                    when RUNNING_CNT3 =>
                        daq_rx_test_counter <= std_logic_vector(unsigned(daq_rx_test_counter) + 1);
                        if (daq_rx_data_i.rxdata(15 downto 0) = not daq_rx_test_counter & daq_rx_test_counter) then
                            daq_error_en <= '0';
                        else
                            daq_error_en <= '1';
                        end if;
                    when others =>
                        daq_error_en <= '0';
                end case;
            end if;
        end if;
    end process;

    --============== TRIG0 RX FSM ==============--
    
    process(link_clk_i)
    begin
        if (rising_edge(link_clk_i)) then
            if (reset_i = '1') then
                trig0_rx_state <= SYNC;
            else
                if (links_sync_done = '0') then
                    trig0_rx_state <= SYNC;
                else
                    case trig0_rx_state is
                        when SYNC => trig0_rx_state <= WAITING_TEST_BEGIN;
                        when WAITING_TEST_BEGIN =>
                            if (trig0_rx_data_i.rxdata(15 downto 0) = BEGIN_PATTERN) then
                                trig0_rx_state <= RUNNING_CNT0;
                            end if;
                        when RUNNING_CNT0 => trig0_rx_state <= RUNNING_CNT1;
                        when RUNNING_CNT1 => trig0_rx_state <= RUNNING_CNT2;
                        when RUNNING_CNT2 => trig0_rx_state <= RUNNING_CNT3;
                        when RUNNING_CNT3 => trig0_rx_state <= RUNNING_CNT0;
                        when others => trig0_rx_state <= SYNC;
                    end case;
                end if;
            end if;
        end if;
    end process;

    --============== TRIG0 RX ==============--
    
    process(link_clk_i)
    begin
        if (rising_edge(link_clk_i)) then
            if (reset_i = '1') then
                trig0_link_sync_done <= '0';
                trig0_rx_test_counter <= (others => '0');
                trig0_error_en <= '0';
            else
                case trig0_rx_state is
                    when SYNC =>
                        trig0_error_en <= '0';
                        trig0_rx_test_counter <= (others => '0');
                        
                        if (trig0_valid_sync_cnt >= 50) then
                            trig0_link_sync_done <= '1';
                        elsif (trig0_rx_data_i.rxdata(15 downto 0) = SYNC_PATTERN) then
                            trig0_valid_sync_cnt <= trig0_valid_sync_cnt + 1;
                        else
                            trig0_valid_sync_cnt <= 0;
                        end if;
                    when RUNNING_CNT0 =>
                        trig0_rx_test_counter <= std_logic_vector(unsigned(trig0_rx_test_counter) + 1);
                        if (trig0_rx_data_i.rxdata(15 downto 0) = trig0_rx_test_counter & x"bc") then
                            trig0_error_en <= '0';
                        else
                            trig0_error_en <= '1';
                        end if;
                    when RUNNING_CNT1 =>
                        trig0_rx_test_counter <= std_logic_vector(unsigned(trig0_rx_test_counter) + 1);
                        if (trig0_rx_data_i.rxdata(15 downto 0) = not trig0_rx_test_counter & trig0_rx_test_counter) then
                            trig0_error_en <= '0';
                        else
                            trig0_error_en <= '1';
                        end if;
                    when RUNNING_CNT2 =>
                        trig0_rx_test_counter <= std_logic_vector(unsigned(trig0_rx_test_counter) + 1);
                        if (trig0_rx_data_i.rxdata(15 downto 0) = trig0_rx_test_counter & not trig0_rx_test_counter) then
                            trig0_error_en <= '0';
                        else
                            trig0_error_en <= '1';
                        end if;
                    when RUNNING_CNT3 =>
                        trig0_rx_test_counter <= std_logic_vector(unsigned(trig0_rx_test_counter) + 1);
                        if (trig0_rx_data_i.rxdata(15 downto 0) = not trig0_rx_test_counter & trig0_rx_test_counter) then
                            trig0_error_en <= '0';
                        else
                            trig0_error_en <= '1';
                        end if;
                    when others =>
                        trig0_error_en <= '0';
                end case;
            end if;
        end if;
    end process;

    --============== TRIG1 RX FSM ==============--
    
    process(link_clk_i)
    begin
        if (rising_edge(link_clk_i)) then
            if (reset_i = '1') then
                trig1_rx_state <= SYNC;
            else
                if (links_sync_done = '0') then
                    trig1_rx_state <= SYNC;
                else
                    case trig1_rx_state is
                        when SYNC => trig1_rx_state <= WAITING_TEST_BEGIN;
                        when WAITING_TEST_BEGIN =>
                            if (trig1_rx_data_i.rxdata(15 downto 0) = BEGIN_PATTERN) then
                                trig1_rx_state <= RUNNING_CNT0;
                            end if;
                        when RUNNING_CNT0 => trig1_rx_state <= RUNNING_CNT1;
                        when RUNNING_CNT1 => trig1_rx_state <= RUNNING_CNT2;
                        when RUNNING_CNT2 => trig1_rx_state <= RUNNING_CNT3;
                        when RUNNING_CNT3 => trig1_rx_state <= RUNNING_CNT0;
                        when others => trig1_rx_state <= SYNC;
                    end case;
                end if;
            end if;
        end if;
    end process;

    --============== TRIG0 RX ==============--
    
    process(link_clk_i)
    begin
        if (rising_edge(link_clk_i)) then
            if (reset_i = '1') then
                trig1_link_sync_done <= '0';
                trig1_rx_test_counter <= (others => '0');
                trig1_error_en <= '0';
            else
                case trig1_rx_state is
                    when SYNC =>
                        trig1_error_en <= '0';
                        trig1_rx_test_counter <= (others => '0');
                        
                        if (trig1_valid_sync_cnt >= 50) then
                            trig1_link_sync_done <= '1';
                        elsif (trig1_rx_data_i.rxdata(15 downto 0) = SYNC_PATTERN) then
                            trig1_valid_sync_cnt <= trig1_valid_sync_cnt + 1;
                        else
                            trig1_valid_sync_cnt <= 0;
                        end if;                        
                    when RUNNING_CNT0 =>
                        trig1_rx_test_counter <= std_logic_vector(unsigned(trig1_rx_test_counter) + 1);
                        if (trig1_rx_data_i.rxdata(15 downto 0) = trig1_rx_test_counter & x"bc") then
                            trig1_error_en <= '0';
                        else
                            trig1_error_en <= '1';
                        end if;
                    when RUNNING_CNT1 =>
                        trig1_rx_test_counter <= std_logic_vector(unsigned(trig1_rx_test_counter) + 1);
                        if (trig1_rx_data_i.rxdata(15 downto 0) = not trig1_rx_test_counter & trig1_rx_test_counter) then
                            trig1_error_en <= '0';
                        else
                            trig1_error_en <= '1';
                        end if;
                    when RUNNING_CNT2 =>
                        trig1_rx_test_counter <= std_logic_vector(unsigned(trig1_rx_test_counter) + 1);
                        if (trig1_rx_data_i.rxdata(15 downto 0) = trig1_rx_test_counter & not trig1_rx_test_counter) then
                            trig1_error_en <= '0';
                        else
                            trig1_error_en <= '1';
                        end if;
                    when RUNNING_CNT3 =>
                        trig1_rx_test_counter <= std_logic_vector(unsigned(trig1_rx_test_counter) + 1);
                        if (trig1_rx_data_i.rxdata(15 downto 0) = not trig1_rx_test_counter & trig1_rx_test_counter) then
                            trig1_error_en <= '0';
                        else
                            trig1_error_en <= '1';
                        end if;
                    when others =>
                        trig1_error_en <= '0';
                end case;
            end if;
        end if;
    end process;

    --============== Counters ==============--

    -- process for counting mega words
    process (link_clk_i)
        variable countdown : integer := 1_000_000;
    begin
        if (rising_edge(link_clk_i)) then
            if ((reset_i = '1') or (links_sync_done = '0')) then
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
            ref_clk_i => link_clk_i,
            reset_i   => reset_i or (not links_sync_done),
            en_i      => mega_word_en,
            count_o   => mega_word_cnt
        );

    i_daq_error_cnt : entity work.counter
        generic map(
            g_COUNTER_WIDTH  => 32,
            g_ALLOW_ROLLOVER => false
        )
        port map(
            ref_clk_i => link_clk_i,
            reset_i   => reset_i or (not links_sync_done),
            en_i      => daq_error_en,
            count_o   => daq_error_cnt
        );

    i_trig0_error_cnt : entity work.counter
        generic map(
            g_COUNTER_WIDTH  => 32,
            g_ALLOW_ROLLOVER => false
        )
        port map(
            ref_clk_i => link_clk_i,
            reset_i   => reset_i or (not links_sync_done),
            en_i      => trig0_error_en,
            count_o   => trig0_error_cnt
        );

    i_trig1_error_cnt : entity work.counter
        generic map(
            g_COUNTER_WIDTH  => 32,
            g_ALLOW_ROLLOVER => false
        )
        port map(
            ref_clk_i => link_clk_i,
            reset_i   => reset_i or (not links_sync_done),
            en_i      => trig1_error_en,
            count_o   => trig1_error_cnt
        );


end Behavioral;
