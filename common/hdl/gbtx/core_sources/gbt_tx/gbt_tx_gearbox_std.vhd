-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Tx gearbox (Standard)
-------------------------------------------------------

--! IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Custom libraries and packages:
use work.vendor_specific_gbt_bank_package.all;

--! @brief GBT_tx_gearbox_std - Tx gearbox (Standard)
--! @details 
--! The GBT_tx_gearbox_std ensures a stable clock domain crossing between Tx Frameclock and Tx Wordclock.
entity gbt_tx_gearbox_std is 
   port (
      
      --================--
      -- Reset & Clocks --
      --================--    
      
      -- Reset:
      ---------
      
      TX_RESET_I                                : in  std_logic;
      
      -- Clocks:
      ----------
      
      TX_FRAMECLK_I                             : in  std_logic;
		TX_CLKEN_i                                : in  std_logic;
      TX_WORDCLK_I                              : in  std_logic;
      
      --==============--
      -- Frame & Word --
      --==============--
      
      TX_FRAME_I                                : in  std_logic_vector(119 downto 0);
      TX_WORD_O                                 : out std_logic_vector(WORD_WIDTH-1 downto 0);
		
      TX_GEARBOX_READY_O                        : out std_logic
      
   );
end gbt_tx_gearbox_std;

--! @brief GBT_tx_gearbox_std - Tx gearbox (Standard)
--! @details The GBT_tx_gearbox_std implements the DPRAM controller and the memory.
architecture structural of gbt_tx_gearbox_std is 

   --================================ Signal Declarations ================================--
   
   --=========--
   -- Control --
   --=========--
   
   signal writeAddress_from_readWriteControl    : std_logic_vector(2 downto 0);
   signal readAddress_from_readWriteControl     : std_logic_vector(GBT_GEARBOXWORDADDR_SIZE-1 downto 0);
   
   --==========--
   -- Inverter --
   --==========--
   
   signal txFrame_from_frameInverter            : std_logic_vector(119 downto 0);   
   
   --=====================================================================================--

--=================================================================================================--
begin                 --========####   Architecture Body   ####========-- 
--=================================================================================================--  

   --==================================== User Logic =====================================--   
   
   --=========--
   -- Control --
   --=========--
   
   readWriteControl: entity work.gbt_tx_gearbox_std_rdwrctrl
      port map (
         TX_RESET_I                             => TX_RESET_I,   
         TX_FRAMECLK_I                          => TX_FRAMECLK_I,
			TX_CLKEN_i                             => TX_CLKEN_i,
         TX_WORDCLK_I                           => TX_WORDCLK_I,          
         WRITE_ADDRESS_O                        => writeAddress_from_readWriteControl,
         READ_ADDRESS_O                         => readAddress_from_readWriteControl
      );

   --==========--
   -- Inverter --
   --==========--
   
   -- Comment: Bits are inverted to transmit the MSB first by the MGT.
   
   frameInverter: for i in 119 downto 0 generate
      txFrame_from_frameInverter(i)             <= TX_FRAME_I(119-i);      
   end generate;

   --==========--
   -- Inverter --
   --==========--   

   dpram: entity work.gbt_tx_gearbox_std_dpram
      port map (
         WR_CLK_I                               => TX_FRAMECLK_I,
			TX_CLKEN_i                             => TX_CLKEN_i,
         WR_ADDRESS_I                           => writeAddress_from_readWriteControl,   
         WR_DATA_I                              => txFrame_from_frameInverter,
         RD_CLK_I                               => TX_WORDCLK_I,
         RD_ADDRESS_I                           => readAddress_from_readWriteControl,
         RD_DATA_O                              => TX_WORD_O
      );   
   
	TX_GEARBOX_READY_O <= not(TX_RESET_I);
   --=====================================================================================--
end structural;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--