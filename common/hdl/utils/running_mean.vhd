------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    12:10 2018-06-07
-- Module Name:    running_mean
-- Description:    This module calculates the running/moving mean/average of the input over the last specified number of input values
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity running_mean is
    generic(
        g_INPUT_OUTPUT_WIDTH        : integer := 12;
        g_WINDOW_SIZE_POWER_OF_TWO  : integer := 20
    );
    port(
        clk_i       : in  std_logic;
        reset_i     : in  std_logic;
        value_i     : in  std_logic_vector(g_INPUT_OUTPUT_WIDTH - 1 downto 0);
        valid_i     : in  std_logic;
        mean_o      : out std_logic_vector(g_INPUT_OUTPUT_WIDTH - 1 downto 0)
    );
end running_mean;

architecture running_mean_arch of running_mean is

    constant WINDOW_SIZE : unsigned(g_WINDOW_SIZE_POWER_OF_TWO downto 0) := (g_WINDOW_SIZE_POWER_OF_TWO => '1', others => '0');

    signal sum      : unsigned(g_INPUT_OUTPUT_WIDTH + g_WINDOW_SIZE_POWER_OF_TWO - 1 downto 0);
    signal mean     : std_logic_vector(g_INPUT_OUTPUT_WIDTH - 1 downto 0);
    signal count    : unsigned(g_WINDOW_SIZE_POWER_OF_TWO downto 0);

begin

    mean_o <= mean;

    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if reset_i = '1' then
                mean <= (others => '0');
                sum <= (others => '0');
                count <= (others => '0');
            else
                if (valid_i = '1') then
                    if (count /= WINDOW_SIZE) then
                        count <= count + 1;
                        sum <= sum + unsigned(value_i);
                        mean <= mean;
                    else
                        mean <= std_logic_vector(sum(g_INPUT_OUTPUT_WIDTH + g_WINDOW_SIZE_POWER_OF_TWO - 1 downto g_WINDOW_SIZE_POWER_OF_TWO));
                        count <= (others => '0');
                        sum <= (others => '0');
                    end if;
                else
                    count <= count;
                    sum <= sum;
                    mean <= mean;
                end if;
            end if;
        end if;
    end process;

end running_mean_arch;