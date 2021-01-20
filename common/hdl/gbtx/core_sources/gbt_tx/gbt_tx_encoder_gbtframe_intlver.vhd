-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Interleaver
-------------------------------------------------------

--! IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! @brief GBT_tx_encoder_gbtframe_intlver - Interleaver
--! @details 
--! The GBT_tx_encoder_gbtframe_intlver interleaves the symbols to improve the encoder performace.
entity gbt_tx_encoder_gbtframe_intlver is
   port (
   
      TX_FRAME_I                                : in  std_logic_vector(119 downto 0);
      TX_FRAME_O                                : out std_logic_vector(119 downto 0)
      
   );   
end gbt_tx_encoder_gbtframe_intlver;

--! @brief GBT_tx_encoder_gbtframe_intlver architecture - Tx datapath
--! @details The GBT_tx_encoder_gbtframe_intlver routes the bits of the two reed solomon frame 
--! in a way to interleave the symbols.
architecture behavioral of gbt_tx_encoder_gbtframe_intlver is
begin

    --==================================== User Logic =====================================--   
    gbtFrameInterleaving_gen: for i in 0 to 14 generate
   
      TX_FRAME_O(119-(8*i) downto 116-(8*i))    <= TX_FRAME_I(119-(4*i) downto 116-(4*i));
      TX_FRAME_O(115-(8*i) downto 112-(8*i))    <= TX_FRAME_I( 59-(4*i) downto  56-(4*i));
      
    end generate;   
    --=====================================================================================-- 
    
end behavioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--