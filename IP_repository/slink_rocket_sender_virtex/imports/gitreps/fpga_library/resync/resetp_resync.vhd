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

entity resetp_resync is
port (
	aresetp				: in std_logic;
	clock				: in std_logic; 

	Resetp_sync			: out std_logic
	);
end resetp_resync;

architecture behavioral of resetp_resync is

signal reg			: std_logic_vector(1 downto 0) := "00";

attribute KEEP : string;
attribute KEEP of reg : signal is "TRUE";
 

--#################################################
--# here start code
--#################################################
begin

process(aresetp,clock)
begin
	if 	aresetp = '1' then
		reg	 		<= (others => '1');
	elsif rising_edge(clock) then
		reg(1)		<= reg(0);
		reg(0)		<= '0';
	end if;
end process;

Resetp_sync			<= reg(1);

end behavioral;

