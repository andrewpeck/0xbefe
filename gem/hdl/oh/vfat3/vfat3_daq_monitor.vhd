------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    00:00 2017-09-29
-- Module Name:    VFAT3_DAQ_MONITOR
-- Description:    This module monitors the DAQ packets of one VFAT3 and counts the number of hits on one or all strips along with an event count
------------------------------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.ttc_pkg.all;
use work.gem_pkg.all;

entity vfat3_daq_monitor is
    port (
        -- reset
        reset_i                 : in  std_logic;
        enable_i                : in  std_logic;
        
        -- clocks
        ttc_clk_i               : in t_ttc_clks;
        
        -- daq signals
        data_en_i               : in std_logic;
        data_i                  : in std_logic_vector(7 downto 0);
        event_done_i            : in std_logic;
        crc_error_i             : in std_logic;
        
        -- channel monitoring
        chan_global_or_i        : in  std_logic;
        chan_single_idx_i       : in  std_logic_vector(6 downto 0);
        
        -- outputs
        cnt_good_events_o       : out std_logic_vector(15 downto 0);
        cnt_chan_fired_o        : out std_logic_vector(15 downto 0)
        
    );
end vfat3_daq_monitor;

architecture Behavioral of vfat3_daq_monitor is

    -- TODO: this is a hard-coded start of rhe channel data, but this should be made configurable so that it can adapt to different VFAT3 configurations
    constant CHANNEL_DATA_WORD_START    : unsigned(4 downto 0) := "0" & x"4";

    constant TIED_TO_GND                : std_logic := '0';

    signal word_cnt                     : unsigned(4 downto 0) := (others => '0');
    signal chan_fired_cnt               : unsigned(15 downto 0) := (others => '0');
    signal good_events_cnt              : unsigned(15 downto 0) := (others => '0');

    signal chan_single_fired            : std_logic;
    signal chan_any_fired               : std_logic;
    signal chan_any_armed               : std_logic;

begin

    cnt_good_events_o <= std_logic_vector(good_events_cnt);
    cnt_chan_fired_o  <= std_logic_vector(chan_fired_cnt);
    
    -- word counter
    process(ttc_clk_i.clk_40)
    begin
        if (rising_edge(ttc_clk_i.clk_40)) then
            if (reset_i = '1') then
                word_cnt <= (others => '0');
            else
                if (data_en_i = '0') then
                   word_cnt <= (others => '0'); 
                else
                   word_cnt <= word_cnt + 1;
                end if;
            end if;
        end if;
    end process;
     
    -- channel fired monitor
    process(ttc_clk_i.clk_40)
    begin
        if (rising_edge(ttc_clk_i.clk_40)) then
            if (reset_i = '1') then
                chan_any_fired <= '0';
                chan_any_armed <= '0';
                chan_single_fired <= '0';
            else
                
                -- arm the checking during the channel data words
                if (word_cnt = CHANNEL_DATA_WORD_START - 1) then
                    chan_any_armed <= '1';
                elsif (word_cnt = CHANNEL_DATA_WORD_START + 15) then
                    chan_any_armed <= '0';
                end if;
                
                -- if any channel has fired during the armed period, latch in the chan_any_fired
                if (chan_any_armed = '1' and data_i /= x"00") then
                    chan_any_fired <= '1';
                end if;
                
                -- pick the right word with the upper bits of the channel index and then the bit within the word with the lower 3 bits of the channel index
                if ( (word_cnt = CHANNEL_DATA_WORD_START + 15 - unsigned(TIED_TO_GND & chan_single_idx_i(6 downto 3))) and
                     (data_i(to_integer(unsigned(chan_single_idx_i(2 downto 0)))) = '1') )
                then
                    chan_single_fired <= '1';
                end if;
                                
                -- unlatch the fired flags
                if (event_done_i = '1') then
                    chan_any_fired <= '0';
                    chan_single_fired <= '0';
                end if;
            end if;
        end if;
    end process;

    -- counters
    process(ttc_clk_i.clk_40)
    begin
        if (rising_edge(ttc_clk_i.clk_40)) then
            if (reset_i = '1') then
                chan_fired_cnt <= (others => '0');
                good_events_cnt <= (others => '0');
            else
                
                if (event_done_i = '1' and crc_error_i = '0' and good_events_cnt /= x"ffff" and enable_i = '1') then
                    good_events_cnt <= good_events_cnt + 1;
                    if (chan_global_or_i = '1' and chan_any_fired = '1') or (chan_global_or_i = '0' and chan_single_fired = '1') then
                        chan_fired_cnt <= chan_fired_cnt + 1;
                    end if;
                end if;

            end if;
        end if;
    end process;

end Behavioral;
