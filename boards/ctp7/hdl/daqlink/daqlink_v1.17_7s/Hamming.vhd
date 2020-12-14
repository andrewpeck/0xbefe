library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
entity Hamming is
    Port ( clk : in std_logic;
           sel_TTC : in std_logic;
           din : in std_logic_vector(17 downto 0);
           dout : out std_logic_vector(17 downto 0)
           );
end Hamming;

architecture my_arch of Hamming is
signal c: std_logic_vector(6 downto 1) := (others =>'0');
signal dinh_dl: std_logic_vector(9 downto 0) := (others =>'0');
begin
process(clk)
begin
  if(clk'event and clk = '1')then
		dinh_dl <= din(17 downto 8);
		if(sel_TTC = '0')then
			dout <= "01" & din(7 downto 0) & x"bc";
		else
			dout <= "00" & c & dinh_dl;
		end if;
		c(1) <= din(0) xor din(1) xor din(3) xor din(4) xor din(6) xor din(8) xor
						 din(10) xor din(11) xor din(13) xor din(15) xor din(17);
		c(2) <= din(0) xor din(2) xor din(3) xor din(5) xor din(6) xor din(9) xor
						 din(10) xor din(12) xor din(13) xor din(16) xor din(17);
		c(3) <= din(1) xor din(2) xor din(3) xor din(7) xor din(8) xor din(9) xor din(10) xor
						 din(14) xor din(15) xor din(16) xor din(17);
		c(4) <= din(4) xor din(5) xor din(6) xor din(7) xor din(8) xor din(9) xor din(10);
		c(5) <= din(11) xor din(12) xor din(13) xor din(14) xor din(15) xor din(16) xor din(17);
		c(6) <= not(din(0) xor din(1) xor din(2) xor din(4) xor din(5) xor din(7) xor din(10) xor din(11) xor din(12) xor din(14) xor din(17));
  end if;
end process;
end my_arch;
