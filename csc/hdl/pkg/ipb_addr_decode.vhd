library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use work.ipbus.all;

package ipb_addr_decode is

    type t_integer_arr is array (natural range <>) of integer;
    type t_ipb_slv is record
        system      : integer;
        links       : integer;
        ttc         : integer;
        daq         : integer;
        tests       : integer;
        none        : integer;
    end record;

    constant C_NUM_IPB_SLAVES : integer := 5;

    -- IPbus slave index definition
    constant C_IPB_SLV : t_ipb_slv := (
        system  => 0,
        links   => 1,
        ttc     => 2,
        daq     => 3,
        tests   => 4,
        none    => C_NUM_IPB_SLAVES
    );

    function ipb_addr_sel(signal addr : in std_logic_vector(31 downto 0)) return integer;
    
end ipb_addr_decode;

package body ipb_addr_decode is

	function ipb_addr_sel(signal addr : in std_logic_vector(31 downto 0)) return integer is
		variable sel : integer;
	begin
  
        -- The addressing below uses 24 usable bits.
        -- Addressing goes like this: [23:20] - AMC module, [19:0] - module specific.
        -- AMC modules:
        --   0x1: System
        --   0x2: Links
        --   0x3: TTC
        --   0x4: DAQ
    
        if    std_match(addr, "--------1001000-----------------") then sel := C_IPB_SLV.system;
        elsif std_match(addr, "--------00100000000-------------") then sel := C_IPB_SLV.links;
        elsif std_match(addr, "--------0011000000000000--------") then sel := C_IPB_SLV.ttc;
        elsif std_match(addr, "--------01000000000-------------") then sel := C_IPB_SLV.daq;
        elsif std_match(addr, "--------01010000000-------------") then sel := C_IPB_SLV.tests;
        else sel := C_IPB_SLV.none;
        end if;

		return sel;
	end ipb_addr_sel;

end ipb_addr_decode;