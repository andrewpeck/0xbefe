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
        system           : integer;
        mgt              : integer;
        promless         : integer;
        pcie             : integer;
        ttc_tx           : integer;
        none             : integer;
    end record;

    constant C_NUM_IPB_SYS_SLAVES : integer := 5;

    -- IPbus slave index definition
    constant C_IPB_SYS_SLV : t_ipb_sys_slv := (
        system => 0,
        mgt => 1,
        promless => 2,
        pcie => 3,
        ttc_tx => 4,
        none => C_NUM_IPB_SYS_SLAVES
    );

    function ipb_sys_addr_sel(signal addr : in std_logic_vector(31 downto 0)) return integer;
    
end ipb_sys_addr_decode;

package body ipb_sys_addr_decode is

	function ipb_sys_addr_sel(signal addr : in std_logic_vector(31 downto 0)) return integer is
		variable sel : integer;
	begin
  
        if    std_match(addr, "--------00000000----------------") then sel := C_IPB_SYS_SLV.system;
        elsif std_match(addr, "--------00000001----------------") then sel := C_IPB_SYS_SLV.mgt;
        elsif std_match(addr, "--------00000010----------------") then sel := C_IPB_SYS_SLV.promless;
        elsif std_match(addr, "--------00000011----------------") then sel := C_IPB_SYS_SLV.pcie;
        elsif std_match(addr, "--------00000100----------------") then sel := C_IPB_SYS_SLV.ttc_tx;
        else sel := C_IPB_SYS_SLV.none;
        end if;

		return sel;
	end ipb_sys_addr_sel;

end ipb_sys_addr_decode;