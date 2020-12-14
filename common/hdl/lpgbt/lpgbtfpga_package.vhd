-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Common package
-------------------------------------------------------

-- IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package lpgbtfpga_package is  
  
   --=============================== Constant Declarations ===============================--
	constant DYNAMIC					  : integer := 0;
	constant FEC5						  : integer := 1;
	constant FEC12						  : integer := 2;
	constant DATARATE_5G12				  : integer := 1;
	constant DATARATE_10G24				  : integer := 2;
   --=====================================================================================--   
   
end lpgbtfpga_package;