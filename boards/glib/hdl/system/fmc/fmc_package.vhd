library ieee;
use ieee.std_logic_1164.all;

package fmc_package is

	--===========--
	type fmc_io_pin_type is
	--===========--
	record
		la_p				: std_logic_vector(0 to 33);
		la_n				: std_logic_vector(0 to 33);
		ha_p				: std_logic_vector(0 to 23);
		ha_n				: std_logic_vector(0 to 23);
		hb_p				: std_logic_vector(0 to 21);
		hb_n				: std_logic_vector(0 to 21);
   end record;
      
end fmc_package;