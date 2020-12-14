------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    15:04 2016-05-10
-- Module Name:    rate_counter
-- Description:    this module counts the rate in Hz of a given signal  
------------------------------------------------------------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gem_pkg.all;
use work.ttc_pkg.all;

entity rate_counter is
    generic(
        g_CLK_FREQUENCY : std_logic_vector(31 downto 0) := C_TTC_CLK_FREQUENCY_SLV;
        g_COUNTER_WIDTH : integer := 32
    );
    port(
        clk_i       : in  std_logic;
        reset_i     : in  std_logic;
        en_i        : in  std_logic;
        rate_o      : out std_logic_vector(g_COUNTER_WIDTH - 1 downto 0)
    );
end rate_counter;

architecture rate_counter_arch of rate_counter is
    
    constant max_count : unsigned(g_COUNTER_WIDTH - 1 downto 0) := (others => '1');
    signal count    : unsigned(g_COUNTER_WIDTH - 1 downto 0);
    signal timer    : unsigned(31 downto 0);
    
begin

    p_count:
    process (clk_i) is
    begin
        if rising_edge(clk_i) then
            if reset_i = '1' then
                count <= (others => '0');
                timer <= (others => '0');
            else
                if timer < unsigned(g_CLK_FREQUENCY) then
                    timer <= timer + 1;
                    if en_i = '1' and count < max_count then
                        count <= count + 1;
                    end if; 
                else
                    timer <= (others => '0');
                    count <= (others => '0');
                    rate_o <= std_logic_vector(count);
                end if;
            end if;
        end if;
    end process;
    

end rate_counter_arch;
