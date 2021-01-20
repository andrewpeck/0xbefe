-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Rx Reed solomon chien search
-------------------------------------------------------
 
--! IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
--! Custom libraries and packages:
use work.gbt_bank_package.all;
 
--! @brief GBT_rx_decoder_gbtframe_chnsrch - Rx Reed solomon chien search
--! @details 
--! The gbt_rx_decoder_gbtframe_chnsrch provide the error position extracted
--! from the error location polynomial.
entity gbt_rx_decoder_gbtframe_chnsrch is
   port (
     
      --========--
      -- Inputs --
      --========--
     
      ERROR_1_LOC_I                             : in  std_logic_vector(3 downto 0);
      ERROR_2_LOC_I                             : in  std_logic_vector(3 downto 0);
      DET_IS_ZERO_I                             : in  std_logic;
     
      --=========--
      -- Outputs --
      --=========--
     
      XX0_O                                     : out std_logic_vector(3 downto 0);
      XX1_O                                     : out std_logic_vector(3 downto 0)
     
   );
end gbt_rx_decoder_gbtframe_chnsrch;
 
--! @brief GBT_rx_decoder_gbtframe_chnsrch - Rx Reed solomon chien search
--! @details The gbt_rx_decoder_gbtframe_chnsrch computes the error location polynomials zeros and uses them
--! to find the error position using a lookup table.
architecture behavioral of gbt_rx_decoder_gbtframe_chnsrch is
 
   --================================ Signal Declarations ================================--
   
	constant ALPHAS                              : std_logic_vector(59 downto 0)  :=  x"fedcba987654321";
	
   --===========================--
   -- Error location polynomial --
   --===========================--
   
   signal errorLocationPolynomial               : std_logic_vector(11 downto 0);
   
   --======================================--
   -- Error location polynomial evaluation --
   --======================================--
   
   signal zero_from_errLocPolyEval              : std_logic_vector(14 downto 0);
   
   --==================--
   -- Primary encoders --
   --==================--
   
   signal out_from_primEncRight                 : std_logic_vector(3 downto 0);
   signal out_from_primEncLeft                  : std_logic_vector(3 downto 0);
 
   --=====================================================================================--
 
--=================================================================================================--
begin                 --========####   Architecture Body   ####========--
--=================================================================================================--
   
   --==================================== User Logic =====================================--      
   
   --===========================--
   -- Error location polynomial --
   --===========================--
   
   errorLocationPolynomial                      <= (ERROR_2_LOC_I & ERROR_1_LOC_I & x"1") when DET_IS_ZERO_I = '0' else
                                                   --------------------------------------------------------------------
                                                   (x"0" & ERROR_1_LOC_I & x"1");  
 
   --======================================--
   -- Error location polynomial evaluation --
   --======================================--
   
   errLocPolyEval_gen: for i in 0 to 14 generate
   
      errLocPolyEval: entity work.gbt_rx_decoder_gbtframe_elpeval
         port map (
            ALPHA_I                             => ALPHAS((4*i)+3 downto 4*i),
            ERRLOCPOLY_I                        => errorLocationPolynomial,
            ZERO_O                              => zero_from_errLocPolyEval(i)
         );
 
   end generate;
 
   --==================--
   -- Primary encoders --
   --==================--
   
   -- Primary encoder right:
   -------------------------			
					
   out_from_primEncRight <= "0001" when (zero_from_errLocPolyEval(0) = '1') else
                            "0010" when (zero_from_errLocPolyEval(1 DOWNTO 0)  = "10") else
                            "0011" when (zero_from_errLocPolyEval(2 DOWNTO 0)  = "100") else
                            "0100" when (zero_from_errLocPolyEval(3 DOWNTO 0)  = "1000") else
                            "0101" when (zero_from_errLocPolyEval(4 DOWNTO 0)  = "10000") else
                            "0110" when (zero_from_errLocPolyEval(5 DOWNTO 0)  = "100000") else
                            "0111" when (zero_from_errLocPolyEval(6 DOWNTO 0)  = "1000000") else
                            "1000" when (zero_from_errLocPolyEval(7 DOWNTO 0)  = "10000000") else
                            "1001" when (zero_from_errLocPolyEval(8 DOWNTO 0)  = "100000000") else
                            "1010" when (zero_from_errLocPolyEval(9 DOWNTO 0)  = "1000000000") else
                            "1011" when (zero_from_errLocPolyEval(10 DOWNTO 0) = "10000000000") else
                            "1100" when (zero_from_errLocPolyEval(11 DOWNTO 0) = "100000000000") else
                            "1101" when (zero_from_errLocPolyEval(12 DOWNTO 0) = "1000000000000") else
                            "1110" when (zero_from_errLocPolyEval(13 DOWNTO 0) = "10000000000000") else
                            "1111" when (zero_from_errLocPolyEval(14 DOWNTO 0) = "100000000000000") else
                            "0000";              
   
   -- Primary encoder left:
   ------------------------
   
    out_from_primEncLeft <= "1111" when (zero_from_errLocPolyEval(14) = '1') else
                            "1110" when (zero_from_errLocPolyEval(14 DOWNTO 13) = "01") else
                            "1101" when (zero_from_errLocPolyEval(14 DOWNTO 12) = "001") else
                            "1100" when (zero_from_errLocPolyEval(14 DOWNTO 11) = "0001") else
                            "1011" when (zero_from_errLocPolyEval(14 DOWNTO 10) = "00001") else
                            "1010" when (zero_from_errLocPolyEval(14 DOWNTO 9)  = "000001") else
                            "1001" when (zero_from_errLocPolyEval(14 DOWNTO 8)  = "0000001") else
                            "1000" when (zero_from_errLocPolyEval(14 DOWNTO 7)  = "00000001") else
                            "0111" when (zero_from_errLocPolyEval(14 DOWNTO 6)  = "000000001") else
                            "0110" when (zero_from_errLocPolyEval(14 DOWNTO 5)  = "0000000001") else
                            "0101" when (zero_from_errLocPolyEval(14 DOWNTO 4)  = "00000000001") else
                            "0100" when (zero_from_errLocPolyEval(14 DOWNTO 3)  = "000000000001") else
                            "0011" when (zero_from_errLocPolyEval(14 DOWNTO 2)  = "0000000000001") else
                            "0010" when (zero_from_errLocPolyEval(14 DOWNTO 1)  = "00000000000001") else
                            "0001" when (zero_from_errLocPolyEval = "000000000000001") else
                            "0000";  
   --========--  
   -- Output --
   --========--
 
   XX0_O                                        <= gf16invr(out_from_primEncRight);  
   XX1_O                                        <= gf16invr(out_from_primEncLeft);
 
   --=====================================================================================--
end behavioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--