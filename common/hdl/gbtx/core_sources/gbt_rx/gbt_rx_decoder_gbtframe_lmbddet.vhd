-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Rx lambda determinant computing
-------------------------------------------------------

-- IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Custom libraries and packages:
use work.gbt_bank_package.all;

--! @brief GBT_rx_decoder_gbtframe_lmbddet - Rx Error amplitude computing
--! @details 
--! The gbt_rx_decoder_gbtframe_lmbddet module computes the reed solomon lambda determinant used to
--! evaluate the amplitude of the error.
entity gbt_rx_decoder_gbtframe_lmbddet is
   port (
   
      --========--
      -- Inputs --
      --========--
      
      S1_I                                      : in  std_logic_vector(3 downto 0);
      S2_I                                      : in  std_logic_vector(3 downto 0);
      S3_I                                      : in  std_logic_vector(3 downto 0);
      
      --========--
      -- Output --
      --========--
      
      DET_IS_ZERO_O                             : out std_logic
      
   );
end gbt_rx_decoder_gbtframe_lmbddet;

--! @brief GBT_rx_decoder_gbtframe_lmbddet - Rx Error amplitude computing
--! @details The GBT_rx_decoder_gbtframe_lmbddet calls the gf16mult and gf16add functions to compute the error amplitude.
architecture behavioral of gbt_rx_decoder_gbtframe_lmbddet is

   --================================ Signal Declarations ================================--

   --=============--
   -- Multipliers --
   --=============--

   signal mult1_out                             : std_logic_vector(3 downto 0);
   signal mult2_out                             : std_logic_vector(3 downto 0);

   --=======--
   -- Adder --
   --=======--
   
   signal add_out                               : std_logic_vector(3 downto 0);   
   
   --=====================================================================================--   
   
--=================================================================================================--
begin                 --========####   Architecture Body   ####========-- 
--=================================================================================================--

   --==================================== User Logic =====================================--      

   --=============--
   -- Multipliers --
   --=============--

   mult1_out                                    <= gf16mult(S2_I,S3_I);
   mult2_out                                    <= gf16mult(S1_I,S2_I);      
   
   --=======--
   -- Adder --
   --=======--
   
   add_out                                      <= gf16add(mult1_out, mult2_out);
   
   --=============--
   -- Determinant --
   --=============--
   
   DET_IS_ZERO_O                                <= '1' when add_out = "0000" else '0'; 
   
   --=====================================================================================--
end behavioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--