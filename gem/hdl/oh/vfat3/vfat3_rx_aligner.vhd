------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    12:00 2017-08-09
-- Module Name:    VFAT3_RX_ALIGNER
-- Description:    This module takes the raw VFAT3 elink data and aligns it to 40MHz clock by bitslipping during sync procedure and watching for SYNC ACK words from VFAT3
------------------------------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.ttc_pkg.all;
use work.common_pkg.all;
use work.gem_pkg.all;

entity vfat3_rx_aligner is
    port(
        -- reset
        reset_i                 : in  std_logic;
        
        -- clocks
        ttc_clk_i               : in t_ttc_clks;
        
        -- VFAT3 raw elink data
        data_i                  : in  std_logic_vector(7 downto 0);
        
        -- control
        sync_i                  : in  std_logic;
        sync_verify_i           : in  std_logic;
        
        -- outputs
        sync_ok_o               : out std_logic;
        num_bitslips_o          : out std_logic_vector(2 downto 0);
        sync_verify_err_cnt_o   : out std_logic_vector(3 downto 0);
        data_o                  : out std_logic_vector(7 downto 0)
    );
end vfat3_rx_aligner;

architecture vfat3_rx_aligner_arch of vfat3_rx_aligner is
    
    constant SYNC_ACK_WORD          : std_logic_vector(7 downto 0) := x"3a";
    constant SYNC_VERIFY_WORD       : std_logic_vector(7 downto 0) := x"fe";
    
    constant SYNC_VERIFY_TIMEOUT    : unsigned(11 downto 0) := x"5dc";  -- half of an orbit, kind of randomly chosen high value, should be adjusted once fiber propagation delay is known
    constant SYNC_VERIFY_ERR_BAD_CNT: unsigned(7 downto 0) := x"64";    -- number of sync verify errors in a row that will deassert sync_ok
    constant SYNC_VERIFY_GOOD_CNT   : unsigned(3 downto 0) := x"a";     -- number of good sync verifies in a row that will assert sync_ok
    
    
    signal do_pattern_search        : std_logic := '0';
    signal do_sync_verify           : std_logic := '0';
    
    signal prev_word                : std_logic_vector(7 downto 0) := (others => '0');
    signal num_bitslips             : integer range 0 to 7 := 0;
    signal sync_ok                  : std_logic := '0';
    
    signal aligned_data             : std_logic_vector(7 downto 0) := (others => '0');
    
    signal sync_verify_countdown    : unsigned(11 downto 0) := SYNC_VERIFY_TIMEOUT;
    signal sync_verify_err_cnt      : unsigned(3 downto 0) := (others => '0'); -- total number of sync verify errors since reset
    signal sync_verify_err_cnt_cont : unsigned(7 downto 0) := (others => '0'); -- number of sync verify errors in a row
    signal sync_verify_good_cnt_cont: unsigned(3 downto 0) := (others => '0'); -- number of good sync verifies in a row
    
begin
    
    -- wiring
    sync_ok_o <= sync_ok;
    num_bitslips_o <= std_logic_vector(to_unsigned(num_bitslips, 3));
    data_o <= aligned_data;
    sync_verify_err_cnt_o <= std_logic_vector(sync_verify_err_cnt);
    
    -- pattern search
    process(ttc_clk_i.clk_40)
    begin
        if (rising_edge(ttc_clk_i.clk_40)) then
            if (reset_i = '1') then
                do_pattern_search <= '1';
                num_bitslips <= 0;
            else
                prev_word <= data_i;
                
                if (do_pattern_search = '0' and sync_i = '1') then
                    do_pattern_search <= '1';
                end if;
                
                if (do_pattern_search = '1') then
                    if (data_i = SYNC_ACK_WORD) then
                        num_bitslips <= 0;
                        do_pattern_search <= '0';
                    end if;
                    for i in 1 to 7 loop
                        if (prev_word(i - 1 downto 0) & data_i(7 downto i) = SYNC_ACK_WORD) then
                            num_bitslips <= i;
                            do_pattern_search <= '0';
                        end if;
                    end loop;
                end if;
            end if;
        end if;
    end process;

    -- bitslipping
    aligned_data <= data_i                                      when num_bitslips = 0 else
                    prev_word(0 downto 0) & data_i (7 downto 1) when num_bitslips = 1 else
                    prev_word(1 downto 0) & data_i (7 downto 2) when num_bitslips = 2 else
                    prev_word(2 downto 0) & data_i (7 downto 3) when num_bitslips = 3 else
                    prev_word(3 downto 0) & data_i (7 downto 4) when num_bitslips = 4 else
                    prev_word(4 downto 0) & data_i (7 downto 5) when num_bitslips = 5 else
                    prev_word(5 downto 0) & data_i (7 downto 6) when num_bitslips = 6 else
                    prev_word(6 downto 0) & data_i (7 downto 7) when num_bitslips = 7 else
                    data_i;
                    
    -- sync checking
    process(ttc_clk_i.clk_40)
    begin
        if (rising_edge(ttc_clk_i.clk_40)) then
            if (reset_i = '1') then
                do_sync_verify <= '0';
                sync_verify_countdown <= SYNC_VERIFY_TIMEOUT;
                sync_verify_err_cnt <= (others => '0');
                sync_verify_err_cnt_cont <= (others => '0');
                sync_verify_good_cnt_cont <= (others => '0');
            else
                if (do_sync_verify = '0' and sync_verify_i = '1') then
                    do_sync_verify <= '1';
                    sync_verify_countdown <= SYNC_VERIFY_TIMEOUT;
                end if;
                
                if (do_sync_verify = '1') then
                    sync_verify_countdown <= sync_verify_countdown - 1;
                    
                    if (sync_verify_countdown = x"000") then
                        do_sync_verify <= '0';
                        sync_verify_err_cnt_cont <= sync_verify_err_cnt_cont + 1;
                        sync_verify_good_cnt_cont <= (others => '0');
                        
                        if (sync_verify_err_cnt /= x"f") then
                            sync_verify_err_cnt <= sync_verify_err_cnt + 1;
                        end if;
                                                
                    end if;

                    if (aligned_data = SYNC_VERIFY_WORD) then
                        sync_verify_good_cnt_cont <= sync_verify_good_cnt_cont + 1;
                        sync_verify_err_cnt_cont <= (others => '0');
                        do_sync_verify <= '0';
                    end if;
                    
                end if;
            end if;
        end if;
    end process;

    -- managing the sync_ok signal
    process(ttc_clk_i.clk_40)
    begin
        if (rising_edge(ttc_clk_i.clk_40)) then
            if (reset_i = '1') then
                sync_ok <= '0';
            else
                if (sync_ok = '0' and sync_verify_good_cnt_cont = SYNC_VERIFY_GOOD_CNT) then
                    sync_ok <= '1';
                elsif (sync_ok = '1' and sync_verify_err_cnt_cont = SYNC_VERIFY_ERR_BAD_CNT) then
                    sync_ok <= '0';
                end if;
            end if;
        end if;
    end process;    
    
end vfat3_rx_aligner_arch;
