-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Rx Gearbox (Standard - Read control)
-------------------------------------------------------

--! IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Custom libraries and packages:
use work.gbt_bank_package.all;
use work.vendor_specific_gbt_bank_package.all;

--! @brief GBT_rx_gearbox_std_rdctrl - Rx Gearbox (Standard - Read control)
--! @details 
--! The GBT_rx_gearbox_std_rdctrl module control the read address of the 
--! DPRAM memory used for the clock domain crossing.
entity gbt_rx_gearbox_std_rdctrl is
   port (
      
      --================--
      -- Reset & Clocks --
      --================--   
      
      -- Reset:
      ---------      
      RX_RESET_I                                : in std_logic;
      
      -- Clocks
      ----------      
      RX_FRAMECLK_I                             : in  std_logic;
		RX_CLKEN_i                                : in  std_logic;
      RX_WORDCLK_i                              : in  std_logic;
		
      --=========--
      -- Control --
      --=========--
		Rx_HEADERFLAG_i                           : in  std_logic;
		
		READ_ADDRESS_O                            : out std_logic_vector(2 downto 0);
      WRITE_ADDRESS_O                           : out std_logic_vector(GBT_GEARBOXWORDADDR_SIZE-1 downto 0);
		
      READY_O                                   : out std_logic
   
   ); 
end gbt_rx_gearbox_std_rdctrl;

--! @brief GBT_rx_gearbox_std_rdctrl architecture - Rx Gearbox (Standard - Read control)
--! @details The Read controller increments the address every RX_FrameClk clock cycle with the
--! zero position synchronized using the header flag.
architecture behavioral of gbt_rx_gearbox_std_rdctrl is

   --================================ Signal Declarations ================================--   
	constant RX_GB_READ_DLY                      : integer :=  2;

   signal ready_r                               : std_logic_vector(2 downto 0);
   
	signal resetAddrManager                      : std_logic;   
	
	type readFSM_t is (e0_wait, e1_read);
	signal readRSM_s                               : readFSM_t;	
   --=====================================================================================--            
  
--=================================================================================================--
begin                 --========####   Architecture Body   ####========-- 
--=================================================================================================--  
  
   --==================================== User Logic =====================================-- 
    
	-- Header flag synchronizer
	addrSynch: process(RX_RESET_I, RX_WORDCLK_i)
	begin
	
		if RX_RESET_I = '1' then
			resetAddrManager <= '1';
			
		elsif rising_edge(RX_WORDCLK_I) then
		
			if Rx_HEADERFLAG_i = '1' then
			    resetAddrManager <= '0';
			end if;
			
		end if;		
	end process;
	
	wrAddrCtrl20b_gen: if WORD_WIDTH = 20 generate
		wrAddr: process(resetAddrManager, RX_WORDCLK_i)
			variable writeAddress                          : integer range 0 to 63;
		begin
		
			if resetAddrManager = '1' then
				writeAddress    := 2;
				WRITE_ADDRESS_O <= (others => '0');
				
			elsif rising_edge(RX_WORDCLK_i) then
			
				case writeAddress is 
					when  5                          => writeAddress :=  8;
					when 13                          => writeAddress := 16;
					when 21                          => writeAddress := 24;
					when 29                          => writeAddress := 32;
					when 37                          => writeAddress := 40;
					when 45                          => writeAddress := 48;
					when 53                          => writeAddress := 56;
					when 61                          => writeAddress :=  0;
					when others                      => writeAddress := writeAddress + 1;
				end case;
							
				WRITE_ADDRESS_O  <= std_logic_Vector(to_unsigned(writeAddress, GBT_GEARBOXWORDADDR_SIZE));
				
			end if;
			
		end process;
	end generate;
	
	wrAddrCtrl40b_gen: if WORD_WIDTH = 40 generate
		wrAddr: process(resetAddrManager, RX_WORDCLK_i)
			variable writeAddress                          : integer range 0 to 63;
		begin
		
			if resetAddrManager = '1' then
				writeAddress    := 2;
				WRITE_ADDRESS_O <= (others => '0');
				
			elsif rising_edge(RX_WORDCLK_i) then
			
				case writeAddress is 
               when  2                          => writeAddress :=  4;          
               when  6                          => writeAddress :=  8;   
               when 10                          => writeAddress := 12;
               when 14                          => writeAddress := 16;
               when 18                          => writeAddress := 20;
               when 22                          => writeAddress := 24;
               when 26                          => writeAddress := 28;
               when 30                          => writeAddress :=  0;
               when others                      => writeAddress := writeAddress + 1;
				end case;
							
				WRITE_ADDRESS_O  <= std_logic_Vector(to_unsigned(writeAddress, GBT_GEARBOXWORDADDR_SIZE));
				
			end if;
			
		end process;
	end generate;
	
	
	rdAddr: process(resetAddrManager, RX_FRAMECLK_I)
		variable timer         : integer range 0 to RX_GB_READ_DLY;
	   variable readAddress   : integer range 0 to  7;
		
	begin
	
		if resetAddrManager = '1' then
			readAddress    := 1;
			readRSM_s      <= e0_wait;
			timer          := 0;
			READY_O        <= '0';
			READ_ADDRESS_O <= (others => '0');
			
		elsif rising_edge(RX_FRAMECLK_I) then
		
		   if RX_CLKEN_i = '1' then
				case readRSM_s is
				
					when e0_wait	=> if timer >= RX_GB_READ_DLY then
												readRSM_s <= e1_read;
												
											else
												timer := timer + 1;
											end if;
				
					when e1_read   => readAddress := readAddress + 1;
									  if readAddress = 1 then  -- Ready after one full read to be sure that all register contains true data
									     READY_O     <= '1';
									  end if;
											
				end case;
				
				READ_ADDRESS_O  <= std_logic_Vector(to_unsigned(readAddress, 3));
			end if;
			
		end if;
		
	end process;
	
   --=====================================================================================--
end behavioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--