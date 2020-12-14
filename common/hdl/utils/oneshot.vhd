------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    23:40 2016-12-18
-- Module Name:    oneshot
-- Description:    given an input signal, the output is asserted high for one clock cycle when input goes from low to high.
--                 Even if the input signal stays high for longe that one clock cycle, the output is only asserted high for one cycle.
--                 Both input and output signals are on the same clock domain. Use oneshot_cross_domain if you need them to be on separate domains.
------------------------------------------------------------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity oneshot is
    port(
        reset_i     : in  std_logic;
        clk_i       : in  std_logic;
        input_i     : in  std_logic;
        oneshot_o   : out std_logic
    );
end oneshot;

architecture oneshot_arch of oneshot is
    
    signal last_input   : std_logic := '0';
        
begin

    process (clk_i) is
    begin
        if rising_edge(clk_i) then
            if reset_i = '1' then
                last_input <= '0';
                oneshot_o <= '0';
            else
                last_input <= input_i;
                if ((last_input = '0') and (input_i = '1')) then
                    oneshot_o <= '1';
                else
                    oneshot_o <= '0';
                end if; 
            end if;
        end if;
    end process;
    
end oneshot_arch;
