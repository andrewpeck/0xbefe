-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Rx Gearbox (Standard)
-------------------------------------------------------

--! IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Custom libraries and packages:
use work.vendor_specific_gbt_bank_package.all;

--! @brief GBT_rx_gearbox_std - Rx Gearbox (Standard)
--! @details 
--! The GBT_rx_gearbox_std ensure the clock domain crossing to pass from the
--! transceiver frequency to the Frameclk frequency.
entity gbt_rx_gearbox_std is
   port (  
      
      --================--
      -- Reset & Clocks --
      --================--    
      
      -- Reset:
      ---------
      
      RX_RESET_I                                : in  std_logic;
      
      -- Clocks:
      ----------
      
      RX_WORDCLK_I                              : in  std_logic;
      RX_FRAMECLK_I                             : in  std_logic;
      RX_CLKEN_i                                : in  std_logic;
		RX_CLKEN_o                                : out std_logic;
		
      --=========--
      -- Control --
      --=========--
      READY_O                                   : out std_logic;
      Rx_HEADERFLAG_i                           : in  std_logic;
		
      --==============--
      -- Word & Frame --
      --==============--
      
      RX_WORD_I                                 : in  std_logic_vector(WORD_WIDTH-1 downto 0);
      RX_FRAME_O                                : out std_logic_vector(119 downto 0)      

   );
end gbt_rx_gearbox_std;

--! @brief GBT_rx_gearbox_std architecture - Rx Gearbox (Standard)
--! @details The GBT_rx_gearbox_std module implement the read and write address controller as well as a 
--! Dual Port RAM to perform the clock domain crossing.
architecture structural of gbt_rx_gearbox_std is   
   
   --================================ Signal Declarations ================================--   
   
   --==============--
   -- Read control --
   --==============--
   
   signal readAddress_from_readControl          : std_logic_vector(  2 downto 0);
   signal ready_from_readControl                : std_logic;   
   
   --===============--
   -- Write control --
   --===============--
   signal RX_WRITE_ADDRESS_s                        : std_logic_vector(GBT_GEARBOXWORDADDR_SIZE-1 downto 0);
   --=======--
   -- DPRAM --
   --=======--
   
   signal rxFrame_from_dpram                    : std_logic_vector(119 downto 0);
   
   --================--
   -- Frame inverter --
   --================--
   
   signal rxFrame_from_frameInverter            : std_logic_vector(119 downto 0);
   
   
   
   signal rdAddress_from_readWriteControl       : std_logic_vector(2 downto 0);
   signal wrAddress_from_readWriteControl       : std_logic_vector(GBT_GEARBOXWORDADDR_SIZE-1 downto 0);
	
	constant RX_GEARBOXSYNCSHIFT_COUNT        : integer range 0 to GBT_WORD_RATIO-1 := GBT_WORD_RATIO-1;
	signal clken_s                            : std_logic_vector(RX_GEARBOXSYNCSHIFT_COUNT downto 0);
   --=====================================================================================--         

--=================================================================================================--
begin                 --========####   Architecture Body   ####========-- 
--=================================================================================================--  
   
   --==================================== User Logic =====================================-- 

   --==============--
   -- Read control --
   --==============--
   readControl: entity work.gbt_rx_gearbox_std_rdctrl
      port map (   
			RX_RESET_I                               => RX_RESET_I, 
			
			RX_FRAMECLK_I                            => RX_FRAMECLK_I,
			RX_CLKEN_i                               => RX_CLKEN_i,
			
			RX_WORDCLK_i                             => RX_WORDCLK_I,
			
			Rx_HEADERFLAG_i                          => Rx_HEADERFLAG_i, 
			
			READ_ADDRESS_O                           => rdAddress_from_readWriteControl,
			WRITE_ADDRESS_O                          => wrAddress_from_readWriteControl, 
			
			READY_O                                  => ready_from_readControl
      );
		   
   --=======--
   -- DPRAM --
   --=======--
   
   dpram: entity work.gbt_rx_gearbox_std_dpram
      port map   (
         WR_EN_I                                => '1',
         WR_CLK_I                               => RX_WORDCLK_I,
         WR_ADDRESS_I                           => wrAddress_from_readWriteControl,   
         WR_DATA_I                              => RX_WORD_I,
         ---------------------------------------
         RD_CLK_I                               => RX_FRAMECLK_I,
			RX_CLKEN_i                             => RX_CLKEN_i,
         RD_ADDRESS_I                           => rdAddress_from_readWriteControl,
         RD_DATA_O                              => rxFrame_from_dpram
      );
   
   --================--
   -- Frame inverter --
   --================--
   
   frameInverter: for i in 119 downto 0 generate
      RX_FRAME_O(i)             <= rxFrame_from_dpram(119-i);
   end generate;   
   
	
   --==================--
   -- Output registers --
   --==================--
	clken_s(0)   <= RX_CLKEN_i;
	
   syncShiftReg_gen: for j in 1 to RX_GEARBOXSYNCSHIFT_COUNT generate
	  
		flipflop_proc: process(RX_RESET_I, RX_FRAMECLK_I)
		begin
			 if RX_RESET_I = '1' then
				  clken_s(j) <= '0';

			 elsif rising_edge(RX_FRAMECLK_I) then
				  clken_s(j) <= clken_s(j-1);

			 end if;
		end process;
		
	end generate;
			
	RX_CLKEN_o                             <= clken_s(RX_GEARBOXSYNCSHIFT_COUNT);
			
		
   regs: process(RX_RESET_I, RX_FRAMECLK_I)
   begin
      if RX_RESET_I = '1' then
         READY_O                                <= '0';
			
      elsif rising_edge(RX_FRAMECLK_I) then
		   if RX_CLKEN_i = '1' then
				READY_O                                <= ready_from_readControl;
			end if;			
      end if;
   end process;    

   --=====================================================================================--   
end structural;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--