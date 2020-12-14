------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    23:40 2017-09-01
-- Module Name:    latch
-- Description:    the output is latched high any time the input goes high, and reset on reset input going high
------------------------------------------------------------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity latch is
    port(
        reset_i     : in  std_logic;
        clk_i       : in  std_logic;
        input_i     : in  std_logic;
        latch_o     : out std_logic
    );
end latch;

architecture latch_arch of latch is
    
    signal latch    : std_logic := '0';
    
begin

    latch_o <= latch;

    process (clk_i) is
    begin
        if rising_edge(clk_i) then
            if reset_i = '1' then
                latch <= '0';
            else
                if (input_i = '1') then
                    latch <= '1';
                else
                    latch <= latch;
                end if;
            end if;
        end if;
    end process;
    
end latch_arch;
