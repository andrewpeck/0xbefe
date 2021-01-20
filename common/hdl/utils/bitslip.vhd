------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2021-01-20
-- Module Name:    bitslip
-- Description:    bitslips the input by a given number of bits
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bitslip is
    generic(
        g_DATA_WIDTH            : integer := 32;
        g_SLIP_CNT_WIDTH        : integer := 8;
        g_TRANSMIT_LOW_TO_HIGH  : boolean := true  -- indicate whether this data will be tranmitted low bit first or high bit first (this influences the way the bitslipping is done)
    );
    port(
        clk_i       : in  std_logic;
        slip_cnt_i  : in  std_logic_vector(g_SLIP_CNT_WIDTH - 1 downto 0);
        data_i      : in  std_logic_vector(g_DATA_WIDTH - 1 downto 0);
        data_o      : out std_logic_vector(g_DATA_WIDTH - 1 downto 0)
    );
end bitslip;

architecture bitslip_arch of bitslip is

    signal prev_data    : std_logic_vector(g_DATA_WIDTH - 1 downto 0);
    signal slip_cnt     : integer range 0 to g_DATA_WIDTH - 1;
    
begin

    slip_cnt <= to_integer(unsigned(slip_cnt_i));

    process(clk_i)
    begin
        if rising_edge(clk_i) then
            prev_data <= data_i;
            
            if slip_cnt = 0 then
                data_o <= prev_data;
            else
                if g_TRANSMIT_LOW_TO_HIGH then
                    -- vivado complains if we just assign the data like (says width mismatch), so we generate if statements for each case
                    for i in 1 to g_DATA_WIDTH - 1 loop
                        if slip_cnt = i then
                            data_o <= data_i(i - 1 downto 0) & prev_data(g_DATA_WIDTH - 1 downto i);
                        end if;
                    end loop;
                else
                    -- vivado complains if we just assign the data like (says width mismatch), so we generate if statements for each case
                    for i in 1 to g_DATA_WIDTH - 1 loop
                        if slip_cnt = i then
                            data_o <= prev_data(i - 1 downto 0) & data_i(g_DATA_WIDTH - 1 downto i);
                        end if;
                    end loop;
                end if;
            end if;
            
        end if;
    end process;

end bitslip_arch;