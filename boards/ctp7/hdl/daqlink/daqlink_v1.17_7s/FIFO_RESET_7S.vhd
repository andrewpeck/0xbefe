----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    07:11:35 04/14/2014 
-- Design Name: 
-- Module Name:    FIFO_RESET_7S - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity FIFO_RESET_7S is
    Port ( reset : in  STD_LOGIC;
           clk : in  STD_LOGIC;
           fifo_rst : out  STD_LOGIC;
           fifo_en : out  STD_LOGIC);
end FIFO_RESET_7S;

architecture Behavioral of FIFO_RESET_7S is
signal ResetFIFO_sync : std_logic_vector(5 downto 0) := (others => '1');
begin
fifo_rst <= ResetFIFO_sync(5);
process(clk,reset)
begin
	if(reset = '1')then
		ResetFIFO_sync <= (others => '1');
		fifo_en <= '0';
	elsif(clk'event and clk = '1')then
		ResetFIFO_sync <= ResetFIFO_sync(4 downto 0) & '0';
		if(ResetFIFO_sync(5) = '0')then
			fifo_en <= '1';
		end if;
	end if;
end process;
end Behavioral;

