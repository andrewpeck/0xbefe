------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2022-06-10
-- Module Name:    LINK_PRBS_TEST
-- Description:    This module can be used to check PRBS31 data on a given RX link (optionally ignoring IDLE words), and also it can generate a PRBS31 sequence on TX links 
------------------------------------------------------------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.common_pkg.all;

entity link_prbs_test is
    generic(
        g_NUM_RX_LINKS          : integer;
        g_BUS_WIDTH             : integer;
        g_IDLE_WORD             : std_logic_vector;
        g_IDLE_CHAR_IS_K        : std_logic_vector;
        g_PRBS_ERR_CNT_WIDTH    : integer := 16
--        g_NUM_TX_LINKS          : integer;
--        g_ENABLE_TX_LINKS       : boolean
    );
    port(
        -- reset
        reset_i                 : in  std_logic;
        enable_i                : in  std_logic;

        -- rx links
        rx_link_select_i        : in  std_logic_vector(6 downto 0);
        rx_common_usrclk_i      : in  std_logic;
        rx_data_arr_i           : in  t_std64_array(g_NUM_RX_LINKS - 1 downto 0);
        rx_charisk_arr_i        : in  t_std8_array(g_NUM_RX_LINKS - 1 downto 0);
                                
--        -- tx links             
--        tx_usrclk_arr_i         : in  std_logic_vector(g_NUM_TX_LINKS - 1 downto 0);
--        tx_data_arr             : out t_mgt_64b_tx_data_arr(g_NUM_TX_LINKS - 1 downto 0);
        
        -- control
        rx_error_cnt_o          : out std_logic_vector(g_PRBS_ERR_CNT_WIDTH - 1 downto 0)
    );
end link_prbs_test;

architecture link_prbs_test_arch of link_prbs_test is

    signal rx_reset         : std_logic;

    signal rx_link_select   : std_logic_vector(6 downto 0) := (others => '0');
    signal rx_data          : std_logic_vector(g_BUS_WIDTH - 1 downto 0) := (others => '0');
    signal rx_data_d1       : std_logic_vector(g_BUS_WIDTH - 1 downto 0) := (others => '0');
    signal rx_charisk       : std_logic_vector((g_BUS_WIDTH / 8) - 1 downto 0) := (others => '0');
    signal rx_idle_d1       : std_logic := '0';
    signal rx_idle_d2       : std_logic := '0';
    signal rx_prbs_err_bits : std_logic_vector(g_BUS_WIDTH - 1 downto 0) := (others => '0');
    signal rx_prbs_err      : std_logic := '0';
    signal rx_prbs_err_cnt  : std_logic_vector(g_PRBS_ERR_CNT_WIDTH - 1 downto 0) := (others => '0');

begin

    -- reset synchronizer
    i_reset_sync : entity work.synch
        generic map(
            N_STAGES => 4,
            IS_RESET => true
        )
        port map(
            async_i => reset_i or (not enable_i),
            clk_i   => rx_common_usrclk_i,
            sync_o  => rx_reset
        );

    -- link select
    process(rx_common_usrclk_i)
    begin
        if rising_edge(rx_common_usrclk_i) then
            rx_link_select <= rx_link_select_i;
            rx_data <= rx_data_arr_i(to_integer(unsigned(rx_link_select)))(g_BUS_WIDTH - 1 downto 0);
            rx_charisk <= rx_charisk_arr_i(to_integer(unsigned(rx_link_select)))((g_BUS_WIDTH / 8) - 1 downto 0);
        end if;
    end process;

    -- idle detect
    process(rx_common_usrclk_i)
    begin
        if rising_edge(rx_common_usrclk_i) then
            if (rx_charisk = g_IDLE_CHAR_IS_K) and (rx_data = g_IDLE_WORD) then
                rx_idle_d1 <= '1';
            else
                rx_idle_d1 <= '0';
            end if; 

            rx_data_d1 <= rx_data;
            rx_idle_d2 <= rx_idle_d1;
            
        end if;
    end process;

    -- PRBS31 checker
    i_rx_prbs_check : entity work.PRBS_ANY
        generic map(
            CHK_MODE    => true,
            INV_PATTERN => true,
            POLY_LENGHT => 31,
            POLY_TAP    => 28,
            NBITS       => g_BUS_WIDTH
        )
        port map(
            RST      => rx_reset,
            CLK      => rx_common_usrclk_i,
            DATA_IN  => rx_data,
            EN       => not rx_idle_d1,
            DATA_OUT => rx_prbs_err_bits
        );

    -- PRBS error detect flag
    process(rx_common_usrclk_i) is
    begin
        if rising_edge(rx_common_usrclk_i) then
            if rx_reset = '1' then
                rx_prbs_err <= '0';
            else
                rx_prbs_err <= or_reduce(rx_prbs_err_bits) and not rx_idle_d2;
            end if;
        end if;
    end process;

    -- PRBS error counter
    i_prbs_err_cnt : entity work.counter
        generic map(
            g_COUNTER_WIDTH    => g_PRBS_ERR_CNT_WIDTH,
            g_ALLOW_ROLLOVER   => false
        )
        port map(
            ref_clk_i => rx_common_usrclk_i,
            reset_i   => rx_reset,
            en_i      => rx_prbs_err,
            count_o   => rx_prbs_err_cnt
        );

    -- register PRBS err cnt
    process(rx_common_usrclk_i) is
    begin
        if rising_edge(rx_common_usrclk_i) then
            rx_error_cnt_o <= rx_prbs_err_cnt;
        end if;
    end process;
    
            
end link_prbs_test_arch;
