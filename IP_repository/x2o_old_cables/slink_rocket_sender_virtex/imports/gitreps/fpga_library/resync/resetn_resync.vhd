--###################################################
-- clock domain translate
--
-- V1.00 : clock IN should be lower that clock out
-- v2.00 : clock IN and clock out can be anything
--
--
--


LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity resetn_resync is
port (
	aresetn				: in std_logic;
	clock				: in std_logic; 

	Resetn_sync		: out std_logic;
	Resetp_sync		: out std_logic
	);
end resetn_resync;

architecture behavioral of resetn_resync is

signal reg			: std_logic_vector(1 downto 0) := "11";

attribute KEEP : string;
attribute KEEP of reg : signal is "TRUE";

--#################################################
--# here start code
--#################################################
begin

process(aresetn,clock)
begin
	if 	aresetn = '0' then
		reg	 		<= (others => '0');
	elsif rising_edge(clock) then
		reg(1)		<= reg(0);
		reg(0)		<= '1';
	end if;
end process;

Resetp_sync			<= not(reg(1));
Resetn_sync			<= reg(1);

end behavioral;
