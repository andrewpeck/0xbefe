-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Reed Solomon encoder
-------------------------------------------------------

--! IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Custom libraries and packages:
use work.gbt_bank_package.all;

--! @brief GBT_tx_encoder_gbtframe_rsencode - Reed Solomon Encoder
--! @details 
--! The GBT_tx_encoder_gbtframe_rsencode generates the FEC used to detect and correct errors.
entity gbt_tx_encoder_gbtframe_rsencode is
   port (
   
      TX_COMMON_FRAME_I                         : in  std_logic_vector(43 downto 0);
      TX_COMMON_FRAME_ENCODED_O                 : out std_logic_vector(59 downto 0)
      
   );
end gbt_tx_encoder_gbtframe_rsencode;

--! @brief GBT_tx_encoder_gbtframe_rsencode architecture - Tx datapath
--! @details The GBT_tx_encoder_gbtframe_rsencode architecture implements the polynomial calculator
--! to generate the 16bit FEC of the 60bit word to be encoded.
architecture structural of gbt_tx_encoder_gbtframe_rsencode is

   --================================ Signal Declarations ================================--

   signal remainder_from_polyDivider            : std_logic_vector(15 downto 0);

   --=====================================================================================--  
   
--=================================================================================================--
begin                 --========####   Architecture Body   ####========-- 
--=================================================================================================--  

   --==================================== User Logic =====================================--   

   polyDivider: entity work.gbt_tx_encoder_gbtframe_polydiv
      port map (
         DIVIDER_I                              => TX_COMMON_FRAME_I & x"0000",
         DIVISOR_I                              => x"1DC87",
         QUOTIENT_O                             => open, 
         REMAINDER_O                            => remainder_from_polyDivider
      );
   
   TX_COMMON_FRAME_ENCODED_O                    <= TX_COMMON_FRAME_I & remainder_from_polyDivider;
   
   --=====================================================================================--         
end structural;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--