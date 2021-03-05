------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2021-01-28
-- Module Name:    IPB_SYS_ADD_DECODE 
-- Description:    This package should define board-specific "system" busses and their address patterns  
------------------------------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use work.ipbus.all;

package ipb_sys_addr_decode is

    type t_ipb_sys_slv is record
        dummy            : integer;
        none             : integer;
    end record;

    constant C_NUM_IPB_SYS_SLAVES : integer := 1;

    -- IPbus slave index definition
    constant C_IPB_SYS_SLV : t_ipb_sys_slv := (
        dummy => 0,
        none => 1
    );

    function ipb_sys_addr_sel(signal addr : in std_logic_vector(31 downto 0)) return integer;
    
end ipb_sys_addr_decode;

package body ipb_sys_addr_decode is

	function ipb_sys_addr_sel(signal addr : in std_logic_vector(31 downto 0)) return integer is
		variable sel : integer;
	begin
  
		return C_IPB_SYS_SLV.none;
	end ipb_sys_addr_sel;

end ipb_sys_addr_decode;