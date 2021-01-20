-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - 16bit descrambler
-------------------------------------------------------

--! IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! @brief GBT_rx_descrambler_16bit - Descrambler
--! @details 
--! The gbt_rx_descrambler_16bit descrambles a packet of 16bit using 
--! the same algorithm as the GBTx. It is used to descramble the 
--! widebus part of the frame (32 extra bits).
entity gbt_rx_descrambler_16bit is
   port (
      
      --===============--
      -- Reset & Clock --
      --===============--    
      
      -- Reset:
      ---------
      
      RX_RESET_I                                : in  std_logic;
      
      -- Clock:
      ---------
      
      RX_FRAMECLK_I                             : in  std_logic;
      RX_CLKEN_i                                : in  std_logic;
		
      --==============--           
      -- Frame & Data --           
      --==============--
      
      -- Wide-Bus extra frame:
      ------------------------
      
      RX_EXTRA_FRAME_WIDEBUS_I                  : in  std_logic_vector(15 downto 0);

       -- Wide-Bus extra data:
      ------------------------
      
      RX_EXTRA_DATA_WIDEBUS_O                   : out std_logic_vector(15 downto 0)
   
   );
end gbt_rx_descrambler_16bit;

--! @brief GBT_rx_descrambler_16bit architecture - Descrambler
--! @details The gbt_rx_descrambler_16bit descrambles the frame using the algorithm defined
--! by the GBTx and based on xor elements.
architecture behavioral of gbt_rx_descrambler_16bit is
   
   --================================ Signal Declarations ================================--
 
   signal feedbackRegister                      : std_logic_vector(15 downto 0);
   
   --=====================================================================================--  
  
--=================================================================================================--
begin                 --========####   Architecture Body   ####========-- 
--=================================================================================================--

   --==================================== User Logic =====================================--   
   
   desscrambler16bit: process(RX_RESET_I, RX_FRAMECLK_I)
   begin   
      if RX_RESET_I = '1' then
         feedbackRegister                       <= (others => '0');
      elsif RISING_EDGE(RX_FRAMECLK_I) then
		
			if RX_CLKEN_i = '1' then

				RX_EXTRA_DATA_WIDEBUS_O( 0) <= RX_EXTRA_FRAME_WIDEBUS_I( 0) xor feedbackRegister( 0) xor feedbackRegister        ( 2) xor feedbackRegister        ( 3) xor feedbackRegister        ( 5);
				RX_EXTRA_DATA_WIDEBUS_O( 1) <= RX_EXTRA_FRAME_WIDEBUS_I( 1) xor feedbackRegister( 1) xor feedbackRegister        ( 3) xor feedbackRegister        ( 4) xor feedbackRegister        ( 6);
				RX_EXTRA_DATA_WIDEBUS_O( 2) <= RX_EXTRA_FRAME_WIDEBUS_I( 2) xor feedbackRegister( 2) xor feedbackRegister        ( 4) xor feedbackRegister        ( 5) xor feedbackRegister        ( 7);
				RX_EXTRA_DATA_WIDEBUS_O( 3) <= RX_EXTRA_FRAME_WIDEBUS_I( 3) xor feedbackRegister( 3) xor feedbackRegister        ( 5) xor feedbackRegister        ( 6) xor feedbackRegister        ( 8);
				RX_EXTRA_DATA_WIDEBUS_O( 4) <= RX_EXTRA_FRAME_WIDEBUS_I( 4) xor feedbackRegister( 4) xor feedbackRegister        ( 6) xor feedbackRegister        ( 7) xor feedbackRegister        ( 9);
				RX_EXTRA_DATA_WIDEBUS_O( 5) <= RX_EXTRA_FRAME_WIDEBUS_I( 5) xor feedbackRegister( 5) xor feedbackRegister        ( 7) xor feedbackRegister        ( 8) xor feedbackRegister        (10);
				RX_EXTRA_DATA_WIDEBUS_O( 6) <= RX_EXTRA_FRAME_WIDEBUS_I( 6) xor feedbackRegister( 6) xor feedbackRegister        ( 8) xor feedbackRegister        ( 9) xor feedbackRegister        (11);
				RX_EXTRA_DATA_WIDEBUS_O( 7) <= RX_EXTRA_FRAME_WIDEBUS_I( 7) xor feedbackRegister( 7) xor feedbackRegister        ( 9) xor feedbackRegister        (10) xor feedbackRegister        (12);
				RX_EXTRA_DATA_WIDEBUS_O( 8) <= RX_EXTRA_FRAME_WIDEBUS_I( 8) xor feedbackRegister( 8) xor feedbackRegister        (10) xor feedbackRegister        (11) xor feedbackRegister        (13);
				RX_EXTRA_DATA_WIDEBUS_O( 9) <= RX_EXTRA_FRAME_WIDEBUS_I( 9) xor feedbackRegister( 9) xor feedbackRegister        (11) xor feedbackRegister        (12) xor feedbackRegister        (14);
				RX_EXTRA_DATA_WIDEBUS_O(10) <= RX_EXTRA_FRAME_WIDEBUS_I(10) xor feedbackRegister(10) xor feedbackRegister        (12) xor feedbackRegister        (13) xor feedbackRegister        (15);
				RX_EXTRA_DATA_WIDEBUS_O(11) <= RX_EXTRA_FRAME_WIDEBUS_I(11) xor feedbackRegister(11) xor feedbackRegister        (13) xor feedbackRegister        (14) xor RX_EXTRA_FRAME_WIDEBUS_I( 0);
				RX_EXTRA_DATA_WIDEBUS_O(12) <= RX_EXTRA_FRAME_WIDEBUS_I(12) xor feedbackRegister(12) xor feedbackRegister        (14) xor feedbackRegister        (15) xor RX_EXTRA_FRAME_WIDEBUS_I( 1);
				RX_EXTRA_DATA_WIDEBUS_O(13) <= RX_EXTRA_FRAME_WIDEBUS_I(13) xor feedbackRegister(13) xor feedbackRegister        (15) xor RX_EXTRA_FRAME_WIDEBUS_I( 0) xor RX_EXTRA_FRAME_WIDEBUS_I( 2);
				RX_EXTRA_DATA_WIDEBUS_O(14) <= RX_EXTRA_FRAME_WIDEBUS_I(14) xor feedbackRegister(14) xor RX_EXTRA_FRAME_WIDEBUS_I( 0) xor RX_EXTRA_FRAME_WIDEBUS_I( 1) xor RX_EXTRA_FRAME_WIDEBUS_I( 3);
				RX_EXTRA_DATA_WIDEBUS_O(15) <= RX_EXTRA_FRAME_WIDEBUS_I(15) xor feedbackRegister(15) xor RX_EXTRA_FRAME_WIDEBUS_I( 1) xor RX_EXTRA_FRAME_WIDEBUS_I( 2) xor RX_EXTRA_FRAME_WIDEBUS_I( 4);
				----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
				feedbackRegister                       <= RX_EXTRA_FRAME_WIDEBUS_I;
				
			end if;
			
      end if;
   end process;  

   --=====================================================================================--   
end behavioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--