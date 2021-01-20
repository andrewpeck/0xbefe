-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Tx scrambler
-------------------------------------------------------

--! IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
--! Custom libraries and packages:
use work.gbt_bank_package.all;
use work.vendor_specific_gbt_bank_package.all;

--! @brief GBT_tx_scrambler - Tx scrambler
--! @details 
--! The GBT_tx_scrambler module scrambles data using the algorithm specified
--! by the GBTx.
entity gbt_tx_scrambler is
   generic (
		TX_ENCODING											: integer range 0 to 2 := GBT_FRAME   
   );
  port (
      
      --===============--
      -- Reset & Clock --
      --===============--    
      
      -- Reset:
      ---------
      
      TX_RESET_I                                : in  std_logic;
      
      -- Clock:
      ---------
      
      TX_FRAMECLK_I                             : in  std_logic;
      TX_CLKEN_i                                : in  std_logic;
		
      --=========--                                
      -- Control --                                
      --=========-- 
      
      -- TX is data selector:
      -----------------------  
      
      TX_ISDATA_SEL_I                           : in  std_logic;
      
      -- Frame header:
      ----------------
      
      TX_HEADER_O                               : out std_logic_vector( 3 downto 0);
      
      --==============--           
      -- Data & Frame --           
      --==============--              
      
      -- Common:
      ----------
      
      TX_DATA_I                                 : in  std_logic_vector(83 downto 0);
      TX_COMMON_FRAME_O                         : out std_logic_vector(83 downto 0);
      
      -- Wide-Bus:
      ------------
      
      TX_EXTRA_DATA_WIDEBUS_I                   : in  std_logic_vector(31 downto 0);
      TX_EXTRA_FRAME_WIDEBUS_O                  : out std_logic_vector(31 downto 0)
      
   );
end gbt_tx_scrambler;

--! @brief GBT_tx_scrambler architecture - Tx scrambler
--! @details The GBT_tx_scrambler architecture instantiates 4 times 21bit scrambler for the GBT encoded data (84bit)
--! and 2 times 16bit scrambler for the 32bit Widebus extra data when the Widebus encoding scheme is selected.
architecture structural of gbt_tx_scrambler is   

	-- Comment: Value of SCRAMBLER_21BIT_RESET_PATTERNS[1:4] chosen arbitrarily except the
   --          last byte (=0 because it is OR-ed with i during multiple instantiations).
	constant SCRAMBLER_21BIT_RESET_PATTERNS      : gbt_reg21_A := ('1' & x"A23E0",
                                                                  '0' & x"F4350",
                                                                  '1' & x"3EDC0",
                                                                  '0' & x"78E20");
																						
	-- Comment: Value of SCRAMBLER_16BIT_RESET_PATTERNS[1:2] chosen arbitrarily except the 
   --          last byte (=0 because it is OR-ed with i during multiple instantiations).																			
	constant SCRAMBLER_16BIT_RESET_PATTERNS      : gbt_reg16_A := (x"23E0",
                                                                  x"4350");
																						
--=================================================================================================--
begin                 --========####   Architecture Body   ####========-- 
--=================================================================================================--

   --==================================== User Logic =====================================--

   --==============--
   -- Frame header --
   --==============--
   
   headerSel: process(TX_RESET_I, TX_FRAMECLK_I)
   begin
      if TX_RESET_I = '1' then
         TX_HEADER_O                            <= (others => '0');
			
      elsif rising_edge(TX_FRAMECLK_I) then
		   if TX_CLKEN_i = '1' then
             if TX_ISDATA_SEL_I = '1' then
                TX_HEADER_O                         <= DATA_HEADER_PATTERN;
             else           
                TX_HEADER_O                         <= IDLE_HEADER_PATTERN;      
             end if; 
			end if;
						
      end if;
   end process;
   
   --============--
   -- Scramblers --
   --============--
   
   -- 84 bit scrambler (GBT-Frame & Wide-Bus):
   -------------------------------------------   
   gbtTxScrambler84bit_gen: for i in 0 to 3 generate
    
     -- Comment: [83:63] & [62:42] & [41:21] & [20:0]
    
     gbtTxScrambler21bit: entity work.gbt_tx_scrambler_21bit
        port map(
           TX_RESET_I                       => TX_RESET_I,
           RESET_PATTERN_I                  => SCRAMBLER_21BIT_RESET_PATTERNS(i),
           ---------------------------------
           TX_FRAMECLK_I                    => TX_FRAMECLK_I,
                TX_CLKEN_i                       => TX_CLKEN_i,					
           ---------------------------------
           TX_DATA_I                        => TX_DATA_I(((21*i)+20) downto (21*i)),
           TX_COMMON_FRAME_O                => TX_COMMON_FRAME_O(((21*i)+20) downto (21*i))
        );
  
   end generate;
         
   -- 32 bit scrambler (Wide-Bus):
   ------------------------------   
   wideBus_gen: if TX_ENCODING = WIDE_BUS or TX_ENCODING = GBT_DYNAMIC generate
   
      gbtTxScrambler32bit_gen: for i in 0 to 1 generate
         
         -- Comment: [31:16] & [15:0]
        
         gbtTxScrambler16bit: entity work.gbt_tx_scrambler_16bit
            port map(
               TX_RESET_I                       => TX_RESET_I,
               RESET_PATTERN_I                  => SCRAMBLER_16BIT_RESET_PATTERNS(i),
               ---------------------------------
               TX_FRAMECLK_I                    => TX_FRAMECLK_I,
			   TX_CLKEN_i                       => TX_CLKEN_i,
               ---------------------------------
               TX_EXTRA_DATA_WIDEBUS_I          => TX_EXTRA_DATA_WIDEBUS_I(((16*i)+15) downto (16*i)),
               TX_EXTRA_FRAME_WIDEBUS_O         => TX_EXTRA_FRAME_WIDEBUS_O(((16*i)+15) downto (16*i))
            );

      end generate;
   
   end generate;
   
   wideBus_no_gen: if TX_ENCODING = GBT_FRAME generate
   
      TX_EXTRA_FRAME_WIDEBUS_O                  <= (others => '0');
   
   end generate;
    
   
   --=====================================================================================--
end structural;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--