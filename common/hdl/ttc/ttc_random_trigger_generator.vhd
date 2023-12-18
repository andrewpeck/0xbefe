--------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company:
-- Engineer: Laurent Pétré (laurent.petre@cern.ch)
--
-- Create Date: 11/01/2023
-- Module Name: ttc_random_trigger_generator
-- Project Name:
-- Description: This module generates random L1A triggers at any desired rate
--    configured through the threshold_i parameter.
--
--------------------------------------------------------------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity ttc_random_trigger_generator is
    port (
        reset_i     : in  std_logic;
        clk_i       : in  std_logic;
        enable_i    : in  std_logic;
        threshold_i : in  std_logic_vector(31 downto 0);
        trigger_o   : out std_logic
    );
end ttc_random_trigger_generator;

architecture Behavioral of ttc_random_trigger_generator is

    signal random_number : unsigned(31 downto 0);

begin

    -- Pseudo-random number generator
    --
    -- Based on "Numerical Recipes in C", ISBN 0-521-43108-5
    -- Chapter 7, "An Even Quicker Generator"
    process(clk_i)
        constant SEED : natural := 48894; -- 0xbefe
        constant A    : natural := 1664525;
        constant C    : natural := 1013904223;

        variable tmp  : unsigned(63 downto 0);
    begin
        if (rising_edge(clk_i)) then
            if (reset_i = '1') then
                random_number <= to_unsigned(SEED, 32);
            else
                tmp           := A * random_number;
                tmp           := C + tmp;
                random_number <= tmp(31 downto 0);
            end if;
        end if;
    end process;

    -- L1A generator
    process(clk_i)
    begin
        if (rising_edge(clk_i)) then
            if (reset_i = '1') then
                trigger_o <= '0';
            else
                if (enable_i = '1') and (random_number < unsigned(threshold_i)) then
                    trigger_o <= '1';
                else
                    trigger_o <= '0';
                end if;
            end if;
        end if;
    end process;

end Behavioral;
