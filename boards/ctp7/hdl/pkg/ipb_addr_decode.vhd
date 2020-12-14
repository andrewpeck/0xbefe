library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use work.ipbus.all;

package ipb_addr_decode is

    type t_integer_arr is array (natural range <>) of integer;
    type t_ipb_slv is record
        oh_reg           : t_integer_arr(0 to 15);
        vfat3            : integer;
        oh_links         : integer;
        daq              : integer;
        ttc              : integer;
        trigger          : integer;
        system           : integer;
        test             : integer;
        slow_control     : integer;
        config_blaster   : integer;
    end record;

    constant C_NUM_IPB_SLAVES : integer := 25;

    -- IPbus slave index definition
    constant C_IPB_SLV : t_ipb_slv := (oh_reg => (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15),
        vfat3 => 16,
        ttc => 17,
        oh_links => 18,
        daq => 19,
        trigger => 20,
        system => 21,
        test => 22,
        slow_control => 23,
        config_blaster => 24);

    function ipb_addr_sel(signal addr : in std_logic_vector(31 downto 0)) return integer;
    
end ipb_addr_decode;

package body ipb_addr_decode is

	function ipb_addr_sel(signal addr : in std_logic_vector(31 downto 0)) return integer is
		variable sel : integer;
	begin
  
    -- The addressing below uses 24 usable bits. Note that this supports "only" up to 16 OHs and up to 12 bits of OH in-module addressing.
    -- Addressing goes like this: [23:20] - AMC module. Module 0x4 is OH reg forwarding where addressing is [19:16] - OH number, [15:12] - OH module, [11:0] - address within module
    -- AMC modules:
    --   0x3: TTC
    --   0x4: OH register access
    --   0x5: Tracking data FIFO (non related to DAQ module, just pure VFAT data as received from OH)
    --   0x6: Counters
    --   0x7: DAQ
    --   0x8: Trigger

    -- TTC
    if    std_match(addr, "--------0011000000000000--------") then sel := C_IPB_SLV.ttc;

	  -- OH register access request forwarding (minimal change from GLIB, but limited to 16 OHs): [26:22] - OH number, [21:18] - OH module, [17:2] - address within module
	  -- One exception is the VFAT 
    elsif std_match(addr, "--------01000000----------------") then sel := C_IPB_SLV.oh_reg(0);
    elsif std_match(addr, "--------01000001----------------") then sel := C_IPB_SLV.oh_reg(1);
    elsif std_match(addr, "--------01000010----------------") then sel := C_IPB_SLV.oh_reg(2);
    elsif std_match(addr, "--------01000011----------------") then sel := C_IPB_SLV.oh_reg(3);
    elsif std_match(addr, "--------01000100----------------") then sel := C_IPB_SLV.oh_reg(4);
    elsif std_match(addr, "--------01000101----------------") then sel := C_IPB_SLV.oh_reg(5);
    elsif std_match(addr, "--------01000110----------------") then sel := C_IPB_SLV.oh_reg(6);
    elsif std_match(addr, "--------01000111----------------") then sel := C_IPB_SLV.oh_reg(7);
    elsif std_match(addr, "--------01001000----------------") then sel := C_IPB_SLV.oh_reg(8);
    elsif std_match(addr, "--------01001001----------------") then sel := C_IPB_SLV.oh_reg(9);
    elsif std_match(addr, "--------01001010----------------") then sel := C_IPB_SLV.oh_reg(10);
    elsif std_match(addr, "--------01001011----------------") then sel := C_IPB_SLV.oh_reg(11);
    elsif std_match(addr, "--------01001100----------------") then sel := C_IPB_SLV.oh_reg(12);
    elsif std_match(addr, "--------01001101----------------") then sel := C_IPB_SLV.oh_reg(13);
    elsif std_match(addr, "--------01001110----------------") then sel := C_IPB_SLV.oh_reg(14);
    elsif std_match(addr, "--------01001111----------------") then sel := C_IPB_SLV.oh_reg(15);

    -- VFAT3 register forwarding
    -- bits [19:16] = OH index (0xf means write broadcast), and bits [15:11] = VFAT3 index (0x1f means write broadcast), for the rest of the bits we use this mapping:
    -- ipbus addr = 0x0xx is translated to VFAT3 addresses 0x000000xx  
    -- ipbus addr = 0x1xx is translated to VFAT3 addresses 0x000100xx  
    -- ipbus addr = 0x2xx is translated to VFAT3 addresses 0x000200xx  
    -- ipbus addr = 0x300 is translated to VFAT3 address   0x0000ffff
    elsif std_match(addr, "--------0101--------------------") then sel := C_IPB_SLV.vfat3;

    -- other AMC modules
    elsif std_match(addr, "--------01100000000-------------") then sel := C_IPB_SLV.oh_links;
    elsif std_match(addr, "--------011100000000000---------") then sel := C_IPB_SLV.daq;
    elsif std_match(addr, "--------10000000000-------------") then sel := C_IPB_SLV.trigger;
    elsif std_match(addr, "--------1001000-----------------") then sel := C_IPB_SLV.system;
    elsif std_match(addr, "--------1010000-----------------") then sel := C_IPB_SLV.test;
    elsif std_match(addr, "--------1011000-----------------") then sel := C_IPB_SLV.slow_control;
    elsif std_match(addr, "--------1011000-----------------") then sel := C_IPB_SLV.slow_control;
    elsif std_match(addr, "--------110000------------------") then sel := C_IPB_SLV.config_blaster;
    else sel := 999;
    end if;

-- GLIB old addressing:
--		if    std_match(addr, "0100----00000000----------------") then sel := C_IPB_SLV.oh_reg(0);
--		elsif std_match(addr, "0100----00010000----------------") then sel := C_IPB_SLV.oh_reg(1);
--		elsif std_match(addr, "010100000000000000000000000000--") then sel := C_IPB_SLV.oh_evt(0);
--		elsif std_match(addr, "010100000001000000000000000000--") then sel := C_IPB_SLV.oh_evt(1);
--		elsif std_match(addr, "011000000000000000000000--------") then sel := C_IPB_SLV.counters;
--		elsif std_match(addr, "01110000000000000000000---------") then sel := C_IPB_SLV.daq;
--		elsif std_match(addr, "01111000000000000000000---------") then sel := C_IPB_SLV.trigger;
--		elsif std_match(addr, "01111100000000000000000000000---") then sel := C_IPB_SLV.ttc;
--		else sel := 99;
--		end if;
		return sel;
	end ipb_addr_sel;

end ipb_addr_decode;