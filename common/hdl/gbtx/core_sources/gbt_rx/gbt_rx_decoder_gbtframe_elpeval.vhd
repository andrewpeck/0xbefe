-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Rx error location polynomial zero computing
-------------------------------------------------------
 
--! IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Custom libraries and packages:
use work.gbt_bank_package.all;

--! @brief GBT_rx_decoder_gbtframe_chnsrch - Rx Reed solomon chien search
--! @details 
--! The gbt_rx_decoder_gbtframe_elpeval computes the error location polynomial zero.
entity gbt_rx_decoder_gbtframe_elpeval is
   port (    
      
      --========--
      -- Inputs --
      --========--
      
      ALPHA_I                                   : in  std_logic_vector( 3 downto 0);
      ERRLOCPOLY_I                              : in  std_logic_vector(11 downto 0);
      
      --=========--
      -- Outputs --
      --=========--
      
      ZERO_O                                    : out std_logic
      
   );
end gbt_rx_decoder_gbtframe_elpeval;

--! @brief GBT_rx_decoder_gbtframe_elpeval - Rx error location polynomial zero computing
--! @details The GBT_rx_decoder_gbtframe_elpeval calls the gf16mult, gf16add and ERRLOCPOLY_I functions to compute 
--! the error location polynomial zero.
architecture behavioral of gbt_rx_decoder_gbtframe_elpeval is

   --================================ Signal Declarations ================================--
   
   signal alpha2                                : std_logic_vector(3 downto 0);   
   signal alpha3                                : std_logic_vector(3 downto 0);  
   
   signal net1                                  : std_logic_vector(3 downto 0);
   signal net2                                  : std_logic_vector(3 downto 0);
   signal net3                                  : std_logic_vector(3 downto 0);
   signal net4                                  : std_logic_vector(3 downto 0);
   signal net5                                  : std_logic_vector(3 downto 0);   
   
   --=====================================================================================--

--=================================================================================================--
begin                 --========####   Architecture Body   ####========-- 
--=================================================================================================--
   
   --==================================== User Logic =====================================--      

   --======================================--
   -- Error location polynomial evaluation --
   --======================================--
   
   alpha2                                       <= gf16mult(ALPHA_I, ALPHA_I);   
   alpha3                                       <= gf16mult( alpha2, ALPHA_I);
   ---------------------------------------------
   net1                                         <= gf16mult(ERRLOCPOLY_I(11 downto 8), alpha3);   
   net2                                         <= gf16mult(ERRLOCPOLY_I( 7 downto 4), alpha2);   
   net3                                         <= gf16mult(ERRLOCPOLY_I( 3 downto 0), ALPHA_I);   
   net4                                         <= gf16add(net1, net2);   
   net5                                         <= gf16add(net3, net4);
   
   --=========--
   -- Outputs --
   --=========--
   
   ZERO_O                                       <= '1' when net5 = x"0" else '0';

   --=====================================================================================--
end behavioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--