-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Rx Reed solomon error correcter
-------------------------------------------------------

-- IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Custom libraries and packages:
use work.gbt_bank_package.all;

--! @brief GBT_rx_decoder_gbtframe_rs2errcor - Rx Reed solomon chien search
--! @details 
--! The GBT_rx_decoder_gbtframe_rs2errcor can correct up to 2 symbols.
entity gbt_rx_decoder_gbtframe_rs2errcor is
   port (
      
      --========--
      -- Inputs --
      --========--
      
      S1_I                                      : in  std_logic_vector( 3 downto 0);
      S2_I                                      : in  std_logic_vector( 3 downto 0);
      XX0_I                                     : in  std_logic_vector( 3 downto 0);
      XX1_I                                     : in  std_logic_vector( 3 downto 0);
      REC_COEFFS_I                              : in  std_logic_vector(59 downto 0);
      DET_IS_ZERO_I                             : in  std_logic;
      
      --========--
      -- Output --
      --========--
      
      COR_COEFFS_O                              : out std_logic_vector(59 downto 0)
      
   );
end gbt_rx_decoder_gbtframe_rs2errcor;

--! @brief GBT_rx_decoder_gbtframe_rs2errcor - Rx Reed solomon chien search
--! @details The GBT_rx_decoder_gbtframe_rs2errcor can correct up to 2 symbols using the information
--! computed by the chien search, the lambda determinant and the syndroms.
architecture behavioral of gbt_rx_decoder_gbtframe_rs2errcor is

   --================================ Signal Declarations ================================--
   
   signal net                                   : gbt_reg4_A(1 to 11); --rs2errcor_net_11x4bit_A;
   signal net20, net21                          : std_logic_vector( 3 downto 0);
   signal y1, y2, y1b                           : std_logic_vector( 3 downto 0);
   signal ermag1, ermag2, ermag3                : std_logic_vector(59 downto 0);
   signal temp                                  : gbt_reg60_A(1 to  6); --rs2errcor_temp_6x60bit_A;
   
   --=====================================================================================--
   
--=================================================================================================--
begin                 --========####   Architecture Body   ####========-- 
--=================================================================================================--
   
   --==================================== User Logic =====================================--         
   
   --==================--
   -- Error correction --
   --==================--
   
   net(1)                                       <= gf16mult(S1_I, XX0_I);            
   net(3)                                       <= gf16mult(XX1_I, XX1_I);   
   net(4)                                       <= gf16mult(XX0_I, XX1_I);            
   y2                                           <= gf16mult(net(2), net(6));          
   net(8)                                       <= gf16mult(y2, XX1_I);            
   y1                                           <= gf16mult(net(9), net(10));
   
   net(10)                                      <= gf16invr(XX0_I);
   net( 6)                                      <= gf16invr(net(5));
   
   net(5)                                       <= gf16add(net(3), net(4));   
   net(9)                                       <= gf16add(net(8), S1_I);            
   net(2)                                       <= gf16add(S2_I, net(1));   
   
   y1b                                          <= gf16mult(S1_I, net(10));   
   
   net20                                        <= gf16loga(XX0_I);
   net21                                        <= gf16loga(XX1_I); 
   
   ermag1                                       <= x"00000000000000" & y1;   
   temp(1)                                      <= gf16shift(ermag1, net20);     
   ermag2                                       <= x"00000000000000" & y2;   
   temp(2)                                      <= gf16shift(ermag2, net21);   
   ermag3                                       <= x"00000000000000" & y1b;   
   temp(4)                                      <= gf16shift(ermag3, net20);
 
   adder60_1_gen: for i in 0 to 14 generate   
      temp(3)((4*i)+3 downto 4*i) <= gf16add(temp(1)((4*i)+3 downto 4*i), REC_COEFFS_I((4*i)+3 downto 4*i));         
   end generate;
   
   adder60_2_gen: for i in 0 to 14 generate
      temp(6)((4*i)+3 downto 4*i) <= gf16add(temp(3)((4*i)+3 downto 4*i), temp(2)((4*i)+3 downto 4*i));      
   end generate;
   
   adder60_3_gen: for i in 0 to 14 generate
      temp(5)((4*i)+3 downto 4*i) <= gf16add(temp(4)((4*i)+3 downto 4*i), REC_COEFFS_I((4*i)+3 downto 4*i));      
   end generate;
   
   --========--  
   -- Output --
   --========--
   
   COR_COEFFS_O                                 <= temp(6) when DET_IS_ZERO_I = '0' else temp(5);
   
   --=====================================================================================--
end behavioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--