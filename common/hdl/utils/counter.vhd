----------------------------------------------------------------------------------
-- Company:        IIHE - ULB
-- Engineer:       Thomas Lenzi (thomas.lenzi@cern.ch)
-- 
-- Create Date:    15:17:59 07/09/2015 
-- Design Name:    OptoHybrid v2
-- Module Name:    counter - Behavioral 
-- Project Name:   OptoHybrid v2
-- Target Devices: xc6vlx130t-1ff1156
-- Tool versions:  ISE  P.20131013
-- Description: 
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter is
    generic(
        g_COUNTER_WIDTH  : integer := 32;
        g_ALLOW_ROLLOVER : boolean := false;
        g_INCREMENT_STEP : integer := 1
    );
    port(
        ref_clk_i : in  std_logic;
        reset_i   : in  std_logic;
        en_i      : in  std_logic;
        count_o   : out std_logic_vector(g_COUNTER_WIDTH - 1 downto 0)
    );
end counter;

architecture counter_arch of counter is

    constant max_count : unsigned(g_COUNTER_WIDTH - 1 downto 0) := (others => '1');
    signal count : unsigned(g_COUNTER_WIDTH - 1 downto 0);

begin

    process(ref_clk_i)
    begin
        if rising_edge(ref_clk_i) then
            if reset_i = '1' then
                count_o <= (others => '0');
                count <= (others => '0');
            else
                if en_i = '1' and (count /= max_count or g_ALLOW_ROLLOVER) then
                    count <= count + g_INCREMENT_STEP;
                end if;
                count_o <= std_logic_vector(count);
            end if;
        end if;
    end process;

end counter_arch;