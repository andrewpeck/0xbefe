-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Deinterleaver
-------------------------------------------------------

--! IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! @brief GBT_rx_decoder_gbtframe_deintlver - Deinterleaver
--! @details 
--! The gbt_rx_decoder_gbtframe_deintlver modules deinterleave the frame in order to
--! reconstruct the 2 reed solomon frames.
entity gbt_rx_decoder_gbtframe_deintlver is
   port (   
      --=======--
      -- Input --
      --=======--   
      RX_FRAME_I                                : in  std_logic_vector(119 downto 0);
      
      --========--
      -- Output --
      --========--      
      RX_FRAME_O                                : out std_logic_vector(119 downto 0)
   
   );   
end gbt_rx_decoder_gbtframe_deintlver;

--! @brief GBT_rx_decoder_gbtframe_deintlver architecture - Rx datapath
--! @details The GBT_rx_decoder_gbtframe_deintlver reconstruct the two parts of the
--! GBT frame using bit to bit connections.
architecture behavioral of gbt_rx_decoder_gbtframe_deintlver is

--=================================================================================================--
begin                 --========####   Architecture Body   ####========-- 
--=================================================================================================--  
   
   --==================================== User Logic =====================================--      
   
   gbtframedeinterleaving_gen:   for i in 0 to 14 generate
   
      RX_FRAME_O(119-(4*i) downto 116-(4*i))    <= RX_FRAME_I(119-(8*i) downto 116-(8*i));
      RX_FRAME_O( 59-(4*i) downto  56-(4*i))    <= RX_FRAME_I(115-(8*i) downto 112-(8*i));
      
   end generate;
   
   --=====================================================================================--
end behavioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--