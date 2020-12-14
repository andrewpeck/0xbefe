------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    00:36 2016-10-25
-- Module Name:    CRC16 CCITT
-- Description:    This module computes CRC16 CCITT for use in the SCA controller (poly = "10001000000100001", init value = x"ffff")
------------------------------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

entity crc16_ccitt is
    port(
        clk_i               : in  std_logic;
        sync_reset_i        : in  std_logic;
        data_i              : in  std_logic;
        data_en_i           : in  std_logic;
        crc_o               : out std_logic_vector(15 downto 0)
    );
end crc16_ccitt;

architecture crc16_ccitt_arch of crc16_ccitt is
    signal crc  : std_logic_vector(15 downto 0);
begin
    
    crc_o <= crc;

    process(clk_i)
    begin
        if (rising_edge(clk_i)) then
            if (sync_reset_i = '1') then
                crc <= (others => '1');
            elsif (data_en_i = '1') then
                crc(15) <= crc(14);
                crc(14) <= crc(13);
                crc(13) <= crc(12);
                crc(12) <= crc(11) xor (data_i xor crc(15));
                crc(11) <= crc(10);
                crc(10) <= crc(9);
                crc(9)  <= crc(8);
                crc(8)  <= crc(7);
                crc(7)  <= crc(6);
                crc(6)  <= crc(5);
                crc(5)  <= crc(4) xor (data_i xor crc(15));
                crc(4)  <= crc(3);
                crc(3)  <= crc(2);
                crc(2)  <= crc(1);
                crc(1)  <= crc(0);
                crc(0)  <= data_i xor crc(15);
            end if;
        end if;
    end process;

end crc16_ccitt_arch;
