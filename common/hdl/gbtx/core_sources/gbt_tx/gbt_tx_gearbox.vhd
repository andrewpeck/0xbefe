-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Tx gearbox
-------------------------------------------------------

--! IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Custom libraries and packages:
use work.gbt_bank_package.all;
use work.vendor_specific_gbt_bank_package.all;

--! @brief GBT_tx_gearbox - Tx Gearbox
--! @details 
--! The GBT_tx_gearbox module implements the standard or latency optimized version of the gearbox depending
--! on the TX_OPTIMIZATION parameter.
entity gbt_tx_gearbox is
  generic (    
    TX_OPTIMIZATION                    : integer range 0 to 1 := STANDARD
  );
  port (
    --================--
    -- Reset & Clocks --
    --================--    
    TX_RESET_I                           : in  std_logic;
    TX_FRAMECLK_I                        : in  std_logic; 
	TX_CLKEN_i                           : in  std_logic;
    TX_WORDCLK_I                         : in  std_logic;
  
    --==============--
	 -- Status       --
	 --==============--
	 TX_PHALIGNED_o                       : out std_logic;
	 TX_PHCOMPUTED_o                      : out std_logic;
	 
    --==============--
    -- Frame & Word --
    --==============--      
    TX_FRAME_I                           : in  std_logic_vector(119 downto 0);
    TX_WORD_O                            : out std_logic_vector(WORD_WIDTH-1 downto 0)
  );
end gbt_tx_gearbox;

--! @brief GBT_tx_gearbox - Tx Gearbox
--! @details The GBT_tx_gearbox module implements the standard (based on a DPRAM memory) or latency optimized (register based)
--! version of the gearbox depending on the TX_OPTIMIZATION parameter.
architecture structural of gbt_tx_gearbox is

   constant flipflopdepth : integer range 0 to GBT_WORD_RATIO-1  := 2;
	
	signal tx_clken_s   : std_logic_vector(GBT_WORD_RATIO-1 downto 0);
begin 

   --==================================== User Logic =====================================--
	tx_clken_s(0) <= TX_CLKEN_i;
	
	syncShiftReg_gen: for j in 1 to GBT_WORD_RATIO-1 generate
		enableFlagAligner_proc: process(TX_RESET_I, TX_FRAMECLK_I)
		begin
		
			if TX_RESET_I = '1' then
				tx_clken_s(j) <= '0';
				
			elsif rising_edge(TX_FRAMECLK_I) then
				tx_clken_s(j) <= tx_clken_s(j-1);
				
			end if;			
		end process;
			
	end generate;
	
   
	
   --==========--
   -- Standard --
   --==========--
   txGearboxStd_gen: if TX_OPTIMIZATION = STANDARD generate
   
      --! Instantiation of the Standard Tx gearbox (DPRAM based)
      txGearboxStd: entity work.gbt_tx_gearbox_std
         port map (
            TX_RESET_I                          => TX_RESET_I,  
            ------------------------------------
            TX_FRAMECLK_I                       => TX_FRAMECLK_I, 
            TX_CLKEN_i                          => tx_clken_s(flipflopdepth),				
            TX_WORDCLK_I                        => TX_WORDCLK_I,   
            ------------------------------------
            TX_FRAME_I                          => TX_FRAME_I,    
            TX_WORD_O                           => TX_WORD_O
         );
			
			TX_PHALIGNED_o  <= '1';
			TX_PHCOMPUTED_o <= '1';
   
   end generate;
   
    --===================--
    -- Latency-optimized --
    --===================--
   
    txGearboxLatOpt_gen: if TX_OPTIMIZATION = LATENCY_OPTIMIZED generate   
   
	    --! Instantiation of the Latency Optimized Tx gearbox (Register based)
        txGearboxLatOpt: entity work.gbt_tx_gearbox_latopt
          port map (
            TX_RESET_I                          => TX_RESET_I,   
            TX_FRAMECLK_I                       => TX_FRAMECLK_I,
		    TX_CLKEN_i                          => TX_CLKEN_i,
            TX_WORDCLK_I                        => TX_WORDCLK_I,   
            ------------------------------------
            TX_FRAME_I                          => TX_FRAME_I,    
            TX_WORD_O                           => TX_WORD_O,   
             ------------------------------------
            TX_GEARBOX_READY_O                  => open, --TX_GEARBOX_READY_O,
            TX_PHALIGNED_O                      => TX_PHALIGNED_o,
            TX_PHCOMPUTED_O                     => TX_PHCOMPUTED_o
          );
		  
    end generate;  
   
   --=====================================================================================--     
end structural;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--