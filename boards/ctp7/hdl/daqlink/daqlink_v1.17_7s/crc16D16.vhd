--
-- Purpose: VHDL package containing a synthesizable CRC function
--   * polynomial: (0 2 15 16)
--   * data width: 16
--                                                                     
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
entity crc16D16 is
    Port ( clk : in std_logic;
           init_crc : in std_logic;
           we_crc : in std_logic;
           d : in std_logic_vector(15 downto 0);
           crc : out std_logic_vector(15 downto 0));
end crc16D16;

architecture my_arch of crc16D16 is
signal c : std_logic_vector(15 downto 0) := (others => '0');
begin
crc <= c;
process(clk)
begin
  if(clk'event and clk = '1')then
    if(init_crc = '1')then
      c <= (others => '1');
	 elsif(we_crc = '1')then
      c(0)  <= d(15) xor d(13) xor d(12) xor d(11) xor d(10) xor d(9)  xor
               d(8)  xor d(7)  xor d(6)  xor d(5)  xor d(4)  xor d(3)  xor
               d(2)  xor d(1)  xor d(0)  xor c(15) xor c(13) xor c(12) xor
               c(11) xor c(10) xor c(9)  xor c(8)  xor c(7)  xor c(6)  xor
               c(5)  xor c(4)  xor c(3)  xor c(2)  xor c(1)  xor c(0);
      c(1)  <= d(14) xor d(13) xor d(12) xor d(11) xor d(10) xor d(9)  xor
               d(8)  xor d(7)  xor d(6)  xor d(5)  xor d(4)  xor d(3)  xor
               d(2)  xor d(1)  xor c(14) xor c(13) xor c(12) xor c(11) xor
               c(10) xor c(9)  xor c(8)  xor c(7)  xor c(6)  xor c(5)  xor
               c(4)  xor c(3)  xor c(2)  xor c(1);
      c(2)  <= d(14) xor d(1)  xor d(0)  xor c(14) xor c(1)  xor c(0);
      c(3)  <= d(15) xor d(2)  xor d(1)  xor c(15) xor c(2)  xor c(1);
      c(4)  <= d(3)  xor d(2)  xor c(3)  xor c(2);
      c(5)  <= d(4)  xor d(3)  xor c(4)  xor c(3);
      c(6)  <= d(5)  xor d(4)  xor c(5)  xor c(4);
      c(7)  <= d(6)  xor d(5)  xor c(6)  xor c(5);
      c(8)  <= d(7)  xor d(6)  xor c(7)  xor c(6);
      c(9)  <= d(8)  xor d(7)  xor c(8)  xor c(7);
      c(10) <= d(9)  xor d(8)  xor c(9)  xor c(8);
      c(11) <= d(10) xor d(9)  xor c(10) xor c(9);
      c(12) <= d(11) xor d(10) xor c(11) xor c(10);
      c(13) <= d(12) xor d(11) xor c(12) xor c(11);
      c(14) <= d(13) xor d(12) xor c(13) xor c(12);
      c(15) <= d(15) xor d(14) xor d(12) xor d(11) xor d(10) xor d(9)  xor
               d(8)  xor d(7)  xor d(6)  xor d(5)  xor d(4)  xor d(3)  xor
               d(2)  xor d(1)  xor d(0)  xor c(15) xor c(14) xor c(12) xor
               c(11) xor c(10) xor c(9)  xor c(8)  xor c(7)  xor c(6)  xor
               c(5)  xor c(4)  xor c(3)  xor c(2)  xor c(1)  xor c(0);
	 end if;
  end if;
end process;
end my_arch;
