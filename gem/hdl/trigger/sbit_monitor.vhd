------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    12:22 2017-11-20
-- Module Name:    sbit_monitor
-- Description:    This module monitors the sbits cluster inputs and freezes a selected link whenever a valid sbit is detected there
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

use work.gem_pkg.all;
use work.ttc_pkg.all;

entity sbit_monitor is
    generic(
        g_NUM_OF_OHs : integer := 1
    );
    port(
        -- reset
        reset_i             : in  std_logic;
        
        -- TTC
        ttc_clk_i           : in  t_ttc_clks;
        ttc_cmds_i          : in  t_ttc_cmds;

        -- Sbit cluster inputs
        link_select_i       : in std_logic_vector(3 downto 0);
        sbit_clusters_i     : in t_oh_sbits_arr(g_NUM_OF_OHs - 1 downto 0);
        sbit_trigger_i      : in std_logic_vector(g_NUM_OF_OHs - 1 downto 0);

        -- output
        frozen_sbits_o      : out t_oh_sbits;
        l1a_dealy_o         : out std_logic_vector(31 downto 0)

    );
end sbit_monitor;

architecture sbit_monitor_arch of sbit_monitor is
    
    constant ZERO_SBITS     : t_oh_sbits := (others => (address => "111" & x"FA", size => "000"));
    
    signal armed            : std_logic := '1';
    signal link_trigger     : std_logic;
    signal link_sbits       : t_oh_sbits;
    
    signal l1a_delay_run    : std_logic := '0';
    signal l1a_delay        : unsigned(31 downto 0);
    
begin

    l1a_dealy_o <= std_logic_vector(l1a_delay);

    -- MUX to select the link
    link_trigger <= sbit_trigger_i(to_integer(unsigned(link_select_i)));
    link_sbits <= sbit_clusters_i(to_integer(unsigned(link_select_i)));

    -- freeze the sbits on the output when a trigger comes
    process(ttc_clk_i.clk_40)
    begin
        if (rising_edge(ttc_clk_i.clk_40)) then
            if (reset_i = '1') then
                frozen_sbits_o <= ZERO_SBITS;
                armed <= '1';
            else
                if (link_trigger = '1' and armed = '1') then
                    frozen_sbits_o <= link_sbits;
                    armed <= '0';
                end if;
            end if;
        end if;
    end process;
    
    -- count the gap between this sbit cluster and the following L1A
    process(ttc_clk_i.clk_40)
    begin
        if (rising_edge(ttc_clk_i.clk_40)) then
            if (reset_i = '1') then
                l1a_delay <= (others => '0');
                l1a_delay_run <= '0';
            else
                
                if (link_trigger = '1' and armed = '1' and l1a_delay_run = '0') then
                    l1a_delay_run <= '1';
                end if;
                
                if (l1a_delay_run = '1' and ttc_cmds_i.l1a = '1') then
                    l1a_delay_run <= '0';
                end if;
                
                if (l1a_delay_run = '1') then
                    l1a_delay <= l1a_delay + 1;
                end if;
                
            end if;
        end if;
    end process;
    

end sbit_monitor_arch;