-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Rx Gearbox (Latency Optimized)
-------------------------------------------------------

--! IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Custom libraries and packages:
use work.vendor_specific_gbt_bank_package.all;

--! @brief GBT_rx_gearbox_latopt - Rx Gearbox (Latency optimized)
--! @details 
--! The GBT_rx_gearbox_latopt ensure the clock domain crossing to pass from the
--! transceiver frequency to the Frameclk frequency with fix and low latency.
entity gbt_rx_gearbox_latopt is
  port (    
    --================--
    -- Reset & Clocks --
    --================--    
    RX_RESET_I                  : in  std_logic;
    RX_WORDCLK_I                : in  std_logic;
	 RX_FRAMECLK_I               : in  std_logic;
    RX_CLKEN_o                  : out std_logic;
	 RX_CLKEN_i                  : in  std_logic;
	 
    --==============--
    -- Controls     --
    --==============--
    RX_HEADERFLAG_i             : in  std_logic;
    READY_O                     : out std_logic;
	 
    --==============--
    -- Frame & Word --
    --==============--      
    RX_WORD_I                   : in  std_logic_vector(WORD_WIDTH-1 downto 0);
    RX_FRAME_O                  : out std_logic_vector(119 downto 0)
   );
end gbt_rx_gearbox_latopt;

--! @brief GBT_rx_gearbox_latopt architecture - Rx Gearbox (Latency optimized)
--! @details The GBT_rx_gearbox_latopt module implements a process used to write and read a register,
--! synchronized with the header flag, to ensure the clock domain crossing.
architecture behavioral of gbt_rx_gearbox_latopt is

    --==================================== User Logic =====================================--
  
	 
	 signal clken_s            : std_logic_vector(RX_GEARBOXSYNCSHIFT_COUNT downto 0);
	 signal ready_s            : std_logic_vector(RX_GEARBOXSYNCSHIFT_COUNT downto 0);
	 
    signal reg0               : std_logic_vector (119 downto 0);
    signal reg1               : std_logic_vector (119 downto 0);
	 
	 signal gbReset_s          : std_logic;
	 signal firstOut           : std_logic;
    --=====================================================================================--     
   
--=================================================================================================--
begin                 --========####   Architecture Body   ####========-- 
--=================================================================================================--  

   gbRstSynch_proc: process(RX_RESET_I, RX_WORDCLK_I)
	begin
	
		if RX_RESET_I = '1' then
			gbReset_s  <= '1';
			
		elsif rising_edge(RX_WORDCLK_I) then
		
			if RX_HEADERFLAG_i = '1' then
            gbReset_s <= '0';
         end if;
			
		end if;
	
	end process;
	
   --================================ Signal Declarations ================================--
    gbRegMan_proc: process(gbReset_s, RX_WORDCLK_I)
		variable cnter              : integer range 0 to GBT_WORD_RATIO;
    begin
    
        if gbReset_s = '1' then
            reg0        <= (others => '0');
            reg1        <= (others => '0');
				ready_s(0)  <= '0';
				cnter       := 2;
				firstOut  <= '0';
        elsif rising_edge(RX_WORDCLK_I) then
				
				if cnter = 0 then					
                   reg1       <= reg0;
                   firstOut   <= '1';
				   ready_s(0) <= firstOut;
				end if;
								
                reg0((WORD_WIDTH*(1+cnter))-1 downto (WORD_WIDTH*cnter))     <= RX_WORD_I;
                cnter                                                        := cnter + 1;
            
				if cnter = GBT_WORD_RATIO then
					cnter := 0;
				end if;
				
        end if;
        
    end process;
	 
	 --==================--
 	 -- Output registers --
	 --==================--
	 clken_s(0)   <= RX_CLKEN_i;
	
	 syncShiftReg_gen: for j in 1 to RX_GEARBOXSYNCSHIFT_COUNT generate
	  
		flipflop_proc: process(gbReset_s, RX_FRAMECLK_I)
		begin
			 if gbReset_s = '1' then
				  clken_s(j) <= '0';
				  ready_s(j) <= '0';

			 elsif rising_edge(RX_FRAMECLK_I) then
				  clken_s(j) <= clken_s(j-1);
				  ready_s(j) <= ready_s(j-1);


			 end if;
		end process;
		
	 end generate;
			
	 RX_CLKEN_o   <= clken_s(RX_GEARBOXSYNCSHIFT_COUNT);
	 READY_O      <= ready_s(RX_GEARBOXSYNCSHIFT_COUNT);
   
    frameInverter: for i in 119 downto 0 generate
        RX_FRAME_O(i)                             <= reg1(119-i);
    end generate;
    
   --=====================================================================================--
end behavioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--