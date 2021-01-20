-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Tx gearbox (Standard - Read/Write control)
-------------------------------------------------------

--! IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Custom libraries and packages:
use work.vendor_specific_gbt_bank_package.all;

--! @brief GBT_tx_gearbox_std_rdwrctrl - Tx gearbox (Standard - Read/Write control)
--! @details 
--! The GBT_tx_gearbox_std_rdwrctrl module control the DPRAM read and write addresses
--! to place the words into the right memory register.
entity gbt_tx_gearbox_std_rdwrctrl is
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
      
      --===========--
      -- Addresses --
      --===========--
      
      WRITE_ADDRESS_O                           : out std_logic_vector(2 downto 0);
      READ_ADDRESS_O                            : out std_logic_vector(GBT_GEARBOXWORDADDR_SIZE-1 downto 0)
      
   );   
end gbt_tx_gearbox_std_rdwrctrl;

--! @brief GBT_tx_gearbox_std_rdwrctrl - Tx Gearbox
--! @details The GBT_tx_gearbox_std_rdwrctrl increments the write address at every FrameClk clock cycle
--! and the read address every TX_Wordclk clock cycle. Both processes are synchronized with the reset
--! which must be released on a rising edge of the frameclk. 
architecture behabioral of gbt_tx_gearbox_std_rdwrctrl is

   --================================ Signal Declarations ================================--

   signal writeAddress                          : integer range 0 to  7;
   signal readAddress                           : integer range 0 to 63;   
  
   --=====================================================================================--
  
--=================================================================================================--
begin                 --========####   Architecture Body   ####========-- 
--=================================================================================================--  
   
   --================================ Signal Declarations ================================--
  
   --===============--
   -- Write Address --
   --===============--   
   
   WRITE_ADDRESS_O                              <= std_logic_vector(to_unsigned(writeAddress,3));
   
   writeAddrCtrl: process(TX_RESET_I, TX_FRAMECLK_I)
   begin      
      if TX_RESET_I = '1' then
         writeAddress                           <= 2;   -- Comment: Note!! Do not modify (default value 6).
      elsif rising_edge(TX_FRAMECLK_I) then
		   if TX_CLKEN_i = '1' then
				if writeAddress = 7 then
					writeAddress                        <= 0;
				else   
					writeAddress                        <= writeAddress + 1;
				end if;
			end if;
      end if;
   end process;   
   
   --==============--
   -- Read Address --
   --==============--
   
   READ_ADDRESS_O                               <= std_logic_vector(to_unsigned(readAddress,(GBT_GEARBOXWORDADDR_SIZE)));
   
   -- Comment: The TX DPRAM is 160-bits wide but only 120-bits are used (the words of the last 40bit are not read).         
   
   -- Word width (20 Bit):
   -----------------------
   
   readAddrCtrl20b_gen: if WORD_WIDTH = 20 generate
 
      readAddrCtrl20b: process(TX_RESET_I, TX_WORDCLK_I)
      begin    
         if TX_RESET_I = '1' then
            readAddress                         <= 0; 
         elsif rising_edge(TX_WORDCLK_I) then
            case readAddress is
               when  5                          => readAddress <=  8;          
               when 13                          => readAddress <= 16;   
               when 21                          => readAddress <= 24;
               when 29                          => readAddress <= 32;
               when 37                          => readAddress <= 40;
               when 45                          => readAddress <= 48;
               when 53                          => readAddress <= 56;
               when 61                          => readAddress <=  0;
               when others                      => readAddress <= readAddress + 1;
            end case;           
         end if;
      end process;

   end generate;
   
   -- Word width (40 Bit):
   -----------------------
   
   readAddrCtrl40b_gen: if WORD_WIDTH = 40 generate

      readAddrCtrl40b: process(TX_RESET_I, TX_WORDCLK_I)
      begin    
         if TX_RESET_I = '1' then
            readAddress                         <= 0; 
         elsif rising_edge(TX_WORDCLK_I) then   
            case readAddress is  
               when  2                          => readAddress <=  4;          
               when  6                          => readAddress <=  8;   
               when 10                          => readAddress <= 12;
               when 14                          => readAddress <= 16;
               when 18                          => readAddress <= 20;
               when 22                          => readAddress <= 24;
               when 26                          => readAddress <= 28;
               when 30                          => readAddress <=  0;
               when others                      => readAddress <= readAddress + 1;
            end case;            
         end if;
      end process;
      
   end generate;

   --=====================================================================================--         
end behabioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--