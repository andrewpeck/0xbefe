-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - 16bit scrambler
-------------------------------------------------------

--! IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! @brief GBT_tx_scrambler_16bit - Tx Scrambler
--! @details 
--! The GBT_tx_scrambler_16bit scrambles a packet of 16bit using 
--! the same algorithm as the GBTx. It is used to scramble the 
--! widebus part of the frame (32 extra bits).
entity gbt_tx_scrambler_16bit is
   port (
  
      --================--
      -- Reset & Clocks --
      --================--    
      
      -- Reset scheme:
      ----------------
      
      TX_RESET_I                                : in  std_logic;
      ------------------------------------------
      RESET_PATTERN_I                           : in  std_logic_vector(15 downto 0);      
      
      -- Clock:
      ---------
      
      TX_FRAMECLK_I                             : in  std_logic;
      TX_CLKEN_i                                : in  std_logic;
      --==============--           
      -- Data & Frame --           
      --==============--              
      
      -- Wide-Bus extra data:
      -----------------------
      
      TX_EXTRA_DATA_WIDEBUS_I                   : in  std_logic_vector(15 downto 0);
      
      -- Wide-Bus extra frame:
      ------------------------
      
      TX_EXTRA_FRAME_WIDEBUS_O                  : out std_logic_vector(15 downto 0)
   
   );
end gbt_tx_scrambler_16bit;

--! @brief GBT_tx_scrambler_16bit architecture - Tx scrambler
--! @details The GBT_tx_scrambler_16bit scrambles the frame using the algorithm defined
--! by the GBTx and based on xor elements.
architecture behavioral of gbt_tx_scrambler_16bit is

   --================================ Signal Declarations ================================--

   signal feedbackRegister                      : std_logic_vector(15 downto 0);

   --=====================================================================================--  
  
--=================================================================================================--
begin                 --========####   Architecture Body   ####========-- 
--=================================================================================================--

   --==================================== User Logic =====================================--

   scrambler16bit: process(TX_RESET_I, TX_FRAMECLK_I)
   begin
      if TX_RESET_I = '1' then
         feedbackRegister                       <= RESET_PATTERN_I;
      elsif rising_edge(TX_FRAMECLK_I) then      

		   if TX_CLKEN_i = '1' then
				feedbackRegister( 0) <= TX_EXTRA_DATA_WIDEBUS_I( 0) xor feedbackRegister( 0) xor feedbackRegister       ( 2) xor feedbackRegister       ( 3) xor feedbackRegister       ( 5);
				feedbackRegister( 1) <= TX_EXTRA_DATA_WIDEBUS_I( 1) xor feedbackRegister( 1) xor feedbackRegister       ( 3) xor feedbackRegister       ( 4) xor feedbackRegister       ( 6);
				feedbackRegister( 2) <= TX_EXTRA_DATA_WIDEBUS_I( 2) xor feedbackRegister( 2) xor feedbackRegister       ( 4) xor feedbackRegister       ( 5) xor feedbackRegister       ( 7);
				feedbackRegister( 3) <= TX_EXTRA_DATA_WIDEBUS_I( 3) xor feedbackRegister( 3) xor feedbackRegister       ( 5) xor feedbackRegister       ( 6) xor feedbackRegister       ( 8);
				feedbackRegister( 4) <= TX_EXTRA_DATA_WIDEBUS_I( 4) xor feedbackRegister( 4) xor feedbackRegister       ( 6) xor feedbackRegister       ( 7) xor feedbackRegister       ( 9);
				feedbackRegister( 5) <= TX_EXTRA_DATA_WIDEBUS_I( 5) xor feedbackRegister( 5) xor feedbackRegister       ( 7) xor feedbackRegister       ( 8) xor feedbackRegister       (10);
				feedbackRegister( 6) <= TX_EXTRA_DATA_WIDEBUS_I( 6) xor feedbackRegister( 6) xor feedbackRegister       ( 8) xor feedbackRegister       ( 9) xor feedbackRegister       (11);
				feedbackRegister( 7) <= TX_EXTRA_DATA_WIDEBUS_I( 7) xor feedbackRegister( 7) xor feedbackRegister       ( 9) xor feedbackRegister       (10) xor feedbackRegister       (12);
				feedbackRegister( 8) <= TX_EXTRA_DATA_WIDEBUS_I( 8) xor feedbackRegister( 8) xor feedbackRegister       (10) xor feedbackRegister       (11) xor feedbackRegister       (13);
				feedbackRegister( 9) <= TX_EXTRA_DATA_WIDEBUS_I( 9) xor feedbackRegister( 9) xor feedbackRegister       (11) xor feedbackRegister       (12) xor feedbackRegister       (14);
				feedbackRegister(10) <= TX_EXTRA_DATA_WIDEBUS_I(10) xor feedbackRegister(10) xor feedbackRegister       (12) xor feedbackRegister       (13) xor feedbackRegister       (15);
				feedbackRegister(11) <= TX_EXTRA_DATA_WIDEBUS_I(11) xor feedbackRegister(11) xor feedbackRegister       (13) xor feedbackRegister       (14) xor TX_EXTRA_DATA_WIDEBUS_I( 0) xor feedbackRegister(0) xor feedbackRegister(2) xor feedbackRegister       (3) xor feedbackRegister       (5);
				feedbackRegister(12) <= TX_EXTRA_DATA_WIDEBUS_I(12) xor feedbackRegister(12) xor feedbackRegister       (14) xor feedbackRegister       (15) xor TX_EXTRA_DATA_WIDEBUS_I( 1) xor feedbackRegister(1) xor feedbackRegister(3) xor feedbackRegister       (4) xor feedbackRegister       (6);
				feedbackRegister(13) <= TX_EXTRA_DATA_WIDEBUS_I(13) xor feedbackRegister(13) xor feedbackRegister       (15) xor TX_EXTRA_DATA_WIDEBUS_I( 0) xor feedbackRegister       ( 0) xor feedbackRegister(2) xor feedbackRegister(3) xor feedbackRegister       (5) xor TX_EXTRA_DATA_WIDEBUS_I(2) xor feedbackRegister(2) xor feedbackRegister(4) xor feedbackRegister(5) xor feedbackRegister       (7);
				feedbackRegister(14) <= TX_EXTRA_DATA_WIDEBUS_I(14) xor feedbackRegister(14) xor TX_EXTRA_DATA_WIDEBUS_I( 0) xor feedbackRegister       ( 0) xor feedbackRegister       ( 2) xor feedbackRegister(3) xor feedbackRegister(5) xor TX_EXTRA_DATA_WIDEBUS_I(1) xor feedbackRegister       (1) xor feedbackRegister(3) xor feedbackRegister(4) xor feedbackRegister(6) xor TX_EXTRA_DATA_WIDEBUS_I(3) xor feedbackRegister(3) xor feedbackRegister(5) xor feedbackRegister(6) xor feedbackRegister(8);
				feedbackRegister(15) <= TX_EXTRA_DATA_WIDEBUS_I(15) xor feedbackRegister(15) xor TX_EXTRA_DATA_WIDEBUS_I( 1) xor feedbackRegister       ( 1) xor feedbackRegister       ( 3) xor feedbackRegister(4) xor feedbackRegister(6) xor TX_EXTRA_DATA_WIDEBUS_I(2) xor feedbackRegister       (2) xor feedbackRegister(4) xor feedbackRegister(5) xor feedbackRegister(7) xor TX_EXTRA_DATA_WIDEBUS_I(4) xor feedbackRegister(4) xor feedbackRegister(6) xor feedbackRegister(7) xor feedbackRegister(9);                                             
			end if;
			
      end if;
   end process;
  
   TX_EXTRA_FRAME_WIDEBUS_O                     <= feedbackRegister;

   --=====================================================================================--
end behavioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--