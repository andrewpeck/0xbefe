-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Rx Reed solomon error location computing
-------------------------------------------------------

--! IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Custom libraries and packages:
use work.gbt_bank_package.all;

--! @brief GBT_rx_decoder_gbtframe_errlcpoly - Rx Error location polynomial computing
--! @details 
--! The gbt_rx_decoder_gbtframe_errlcpoly compute the error location polynomial.
entity gbt_rx_decoder_gbtframe_errlcpoly is
   port (
      
      --========--
      -- Inputs --
      --========--
      
      S1_I                                      : in  std_logic_vector(3 downto 0);
      S2_I                                      : in  std_logic_vector(3 downto 0);
      S3_I                                      : in  std_logic_vector(3 downto 0);
      S4_I                                      : in  std_logic_vector(3 downto 0);
      DET_IS_ZERO_I                             : in  std_logic;
      
      --=========--
      -- Outputs --
      --=========--
      
      ERROR_1_LOC_O                             : out std_logic_vector(3 downto 0);
      ERROR_2_LOC_O                             : out std_logic_vector(3 downto 0)     
      
   );
end gbt_rx_decoder_gbtframe_errlcpoly;

--! @brief GBT_rx_decoder_gbtframe_errlcpoly - Rx Error location polynomial computing
--! @details The gbt_rx_decoder_gbtframe_errlcpoly calls the gf16mult and gf16add functions to compute the error amplitude.
architecture behavioral of gbt_rx_decoder_gbtframe_errlcpoly is

   --================================ Signal Declarations ================================--
  
   signal location1b                            : std_logic_vector(3 downto 0);
   signal location1a                            : std_logic_vector(3 downto 0);
   signal location2a                            : std_logic_vector(3 downto 0);
      
   signal invertedS                             : gbt_reg4_A(1 to  3); --errlcpoly_invertedS_3x4bit_A;
   signal net                                   : gbt_reg4_A(1 to 18); --errlcpoly_net_18x4bit_A;
   signal invertedNet14                         : std_logic_vector(3 downto 0);
   
   --=====================================================================================--
   
--=================================================================================================--
begin                 --========####   Architecture Body   ####========-- 
--=================================================================================================--

   --==================================== User Logic =====================================--      

   --==============================--
   -- Error 1 location  polynomial --
   --==============================--   
  
   invertedS(1)                                 <= gf16invr(S1_I);   
   location1b                                   <= gf16mult(invertedS(1),S2_I);        

   --==============================--
   -- Error 2 location  polynomial --
   --==============================--                   

   invertedS(2)                                 <= gf16invr(S2_I);      
   invertedS(3)                                 <= gf16invr(S3_I);  
   invertedNet14                                <= gf16invr(net(14));                 
   ---------------------------------------------
   net(1)                                       <= gf16mult(S3_I,S3_I);      
   net(3)                                       <= gf16mult(S1_I,S3_I);   
   net(6)                                       <= gf16mult(net(1),invertedS(2));      
   net(7)                                       <= gf16mult(invertedS(2),net(3));   
   net(9)                                       <= gf16mult(S3_I,invertedS(2));  
   net(10)                                      <= gf16mult(invertedS(2),S1_I);      
   net(11)                                      <= gf16mult(invertedS(3),S4_I);            
   net(12)                                      <= gf16mult(S3_I,invertedS(1));            
   net(17)                                      <= gf16mult(net(13),invertedNet14);            
   net(16)                                      <= gf16mult(net(17),net(10));            
   net(18)                                      <= gf16add(net(9),net(16));            
   net(13)                                      <= gf16add(S4_I,net(6));      
   net(14)                                      <= gf16add(net(7),S2_I);
   ---------------------------------------------
   location1a                                   <= net(11) when S2_I = x"0" else net(18);
   location2a                                   <= net(12) when S2_I = x"0" else net(17);  
   
   --=========--
   -- Outputs --
   --=========--   
   
   ERROR_1_LOC_O                                <= location1b when DET_IS_ZERO_I = '1' else location1a;
   ERROR_2_LOC_O                                <= x"0"       when DET_IS_ZERO_I = '1' else location2a; 
   
   --=====================================================================================--
end behavioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--