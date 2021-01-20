-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Rx syndrom computing
-------------------------------------------------------

--! IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Custom libraries and packages:
use work.gbt_bank_package.all;

--! @brief GBT_rx_decoder_gbtframe_syndrom - Rx Syndrom computing
--! @details 
--! The gbt_rx_decoder_gbtframe_syndrom module computes the reed solomon syndroms used to detect and correct error. 
--! Since these are the zeros of the generator polynomial, the result should be zero if the scanned message is undamaged.
--! If not, the syndromes contain all the information necessary to determine the correction that should be made.
entity gbt_rx_decoder_gbtframe_syndrom is
   port (
   
      --=======--
      -- Input --
      --=======--   
      POLY_COEFFS_I                             : in  std_logic_vector(59 downto 0);
   
      --=========--
      -- Outputs --
      --=========--   
      S1_O                                      : out std_logic_vector( 3 downto 0);
      S2_O                                      : out std_logic_vector( 3 downto 0);
      S3_O                                      : out std_logic_vector( 3 downto 0);
      S4_O                                      : out std_logic_vector( 3 downto 0)
      
   );
end gbt_rx_decoder_gbtframe_syndrom;

--! @brief GBT_rx_decoder_gbtframe_syndrom - Rx Syndrom computing
--! @details The gbt_rx_decoder_gbtframe_syndrom calls the gf16mult and gf16add functions to compute the syndroms.
architecture behavioral of gbt_rx_decoder_gbtframe_syndrom is

   --================================ Signal Declarations ================================--
	type syndromes_alphaPower_4x60bit_A          is array(1 to  4         ) of std_logic_vector(59 downto 0); 
   constant ALPHAPOWER_S                        : syndromes_alphaPower_4x60bit_A := (x"9DFE7A5BC638421",   --! GBT decoder syndromes: from the GBTx spec.
                                                                                     x"DEAB6829F75C341",
                                                                                     x"FAC81FAC81FAC81",
                                                                                     x"EB897C4DA62F531");
																												 
   signal net1                                  : gbt_reg4_2dA(1 to  4, 0 to 14); --syndromes_net1_4x15x4bit_A; 
   signal net2                                  : gbt_reg4_2dA(1 to  4, 0 to  6); --syndromes_net2_4x7x4bit_A;
   signal net3                                  : gbt_reg4_2dA(1 to  4, 0 to  3); --syndromes_net3_4x4x4bit_A;
   signal net4                                  : gbt_reg4_2dA(1 to  4, 0 to  1); --syndromes_net4_4x2x4bit_A; 
   ---------------------------------------------
   signal syndrome_from_syndromeEvaluator       : gbt_reg4_A(1 to  4); --syndromes_syndrome_4x4bit_A;

   --=====================================================================================--   
   
--=================================================================================================--
begin                 --========####   Architecture Body   ####========-- 
--=================================================================================================--

   --==================================== User Logic =====================================--      

   --====================--
   -- Syndrome evaluator --
   --====================--   
   
   syndromeEvaluator_gen: for i in 1 to 4 generate   
   
      net1_gen: for j in 0 to 14 generate
         net1(i,j)                              <= gf16mult(POLY_COEFFS_I(59-(4*j) downto 56-(4*j)),ALPHAPOWER_S(i)(59-(4*j) downto 56-(4*j)));      
      end generate;
      
      net2_gen: for j in 0 to 6 generate
         net2(i,j)                              <= gf16add(net1(i,((2*j)+1)),net1(i,(2*j)));         
      end generate;
      
      net3_gen: for j in 0 to 2 generate
         net3(i,j)                              <= gf16add(net2(i,((2*j)+1)),net2(i,(2*j)));
      end generate;
      
      net3(i,3)                                 <= gf16add(net1(i,14),net2(i,6));
        
      net4_gen: for j in 0 to 1 generate
         net4(i,j)                              <= gf16add(net3(i,((2*j)+1)),net3(i,(2*j)));        
      end generate;
      
      syndrome_from_syndromeEvaluator(i)        <=  gf16add(net4(i,1),net4(i,0)); 

   end generate;
   
   --=========--
   -- Outputs --
   --=========--
   
   S1_O                                         <= syndrome_from_syndromeEvaluator(1);
   S2_O                                         <= syndrome_from_syndromeEvaluator(2);
   S3_O                                         <= syndrome_from_syndromeEvaluator(3);
   S4_O                                         <= syndrome_from_syndromeEvaluator(4);

   --=====================================================================================--      
end behavioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--