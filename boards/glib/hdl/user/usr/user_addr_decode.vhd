library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use work.ipbus.all;
use work.user_package.all;
use work.ipb_addr_decode.all;

package user_addr_decode is

	function user_wb_addr_sel (signal addr : in std_logic_vector(31 downto 0)) return integer;
	function user_ipb_addr_sel(signal addr : in std_logic_vector(31 downto 0)) return integer;

end user_addr_decode;

package body user_addr_decode is

	function user_ipb_addr_sel(signal addr : in std_logic_vector(31 downto 0)) return integer is
	begin
		return ipb_addr_sel(addr);
	end user_ipb_addr_sel;

   function user_wb_addr_sel(signal addr : in std_logic_vector(31 downto 0)) return integer is
		variable sel : integer;
   begin
		if   std_match(addr, "100000000000000000000000--------") then  	sel := user_wb_regs;
		else sel := 99;
		end if;
		return sel;
	end user_wb_addr_sel; 

end user_addr_decode;