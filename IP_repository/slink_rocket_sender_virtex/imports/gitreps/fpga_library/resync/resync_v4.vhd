--###################################################
-- clock domain translate
--
--
--


LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity resync_v4 is
	port (
		aresetn				: in std_logic;
		clocki			    : in std_logic;	
		input				: in std_logic;
		clocko			    : in std_logic;
		output			    : out std_logic
		);
end resync_v4;

architecture behavioral of resync_v4 is

signal reg_1st_stage				: std_logic := '0';

signal reg_2nd_stage				: std_logic_vector(2 downto 1) ;
signal reg_2nd_stage_async			: std_logic ;
signal reg_o						: std_logic ;

attribute ASYNC_REG						: string;
attribute ASYNC_REG of reg_2nd_stage_async : signal is  "TRUE";
 
--#################################################
--# here start code
--#################################################
begin

process(aresetn,clocki)
begin
	if aresetn = '0' then
		reg_1st_stage 	<=	'0';
	elsif rising_edge(clocki) then
		if input = '1' then
			reg_1st_stage	<= not(reg_1st_stage);
		end if;
	end if;
end process;


process(clocko)
begin
	if rising_edge(clocko) then
		reg_o		<= '0';
		if (reg_2nd_stage(2) = '1' and reg_2nd_stage(1) = '0') or ((reg_2nd_stage(2) = '0' and reg_2nd_stage(1) = '1')) then
			reg_o					<= '1';
		end if;
		reg_2nd_stage(2) 			<= reg_2nd_stage(1);
		reg_2nd_stage(1)			<= reg_2nd_stage_async;
		reg_2nd_stage_async			<= reg_1st_stage;
	end if;
end process;
 
output	<= reg_o;

end behavioral;
