--###################################################
-- clock domain translate
-- this component resync a stable signal from one clock domain to another
-- if you need a pulse transfer  use  resync.vhd
--
--
--


LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity resync_sig_gen is 
port ( 
	clocko				: in std_logic;
	input				: in std_logic;
	output				: out std_logic
	);
end resync_sig_gen;

architecture behavioral of resync_sig_gen is
signal reg1							: std_logic;
signal reg0							: std_logic;
signal reg_async					: std_logic;

attribute ASYNC_REG : string;
attribute ASYNC_REG of  reg_async 		: signal is "true";
attribute ASYNC_REG of  reg0	 		: signal is "true";

--#################################################
--# here start code
--#################################################
begin
 
process(clocko)
begin
	if rising_edge(clocko) then
		reg1					<= reg0;
		reg0 					<= reg_async;
		reg_async				<= input;
	end if;
end process;

output <= reg1;

end behavioral;
