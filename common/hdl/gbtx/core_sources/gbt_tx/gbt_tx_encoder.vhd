-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Tx Encoder
-------------------------------------------------------

--! IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Custom libraries and packages:
use work.gbt_bank_package.all;
use work.vendor_specific_gbt_bank_package.all;

--! @brief GBT_tx_encoder - Tx Encoder
--! @details 
--! The gbt_tx_encoder module computes the FEC when the GBT_FRAME encoding is selected and interleaves the data
--! to increase the protocol performance.
entity gbt_tx_encoder is 
   generic (   
		TX_ENCODING											: integer range 0 to 2 := GBT_FRAME 
   );
   port (
      
      --================--
      -- Reset & Clocks --
      --================--    
      
      -- Reset:
      ---------
      
      TX_RESET_I                                : in  std_logic;
      TX_ENCODING_SEL_i                         : in  std_logic;
      
      --==============--
      -- Frame header --
      --==============-- 
      
      TX_HEADER_I                               : in  std_logic_vector(  3 downto 0);      
      
      --=======--           
      -- Frame --           
      --=======--              
      
      -- Common:
      ----------
      
      TX_COMMON_FRAME_I                         : in  std_logic_vector( 83 downto 0);      
      
      -- Wide-Bus:
      ------------
      
      TX_EXTRA_FRAME_WIDEBUS_I                  : in  std_logic_vector( 31 downto 0);  
      
      -- Frame:
      ---------
      
      TX_FRAME_O                                : out std_logic_vector(119 downto 0)      

   );
end gbt_tx_encoder;

--! @brief GBT_tx_encoder architecture - Tx datapath
--! @details The GBT_tx_encoder architecture divides the GBT frame in two part and computes a FEC for
--! each frame. Then the data are interleaved to improve the performance. When the TX path is configured
--! in WideBus mode, the data are just copied from the input to the output.
architecture structural of gbt_tx_encoder is 


   --================================ Signal Declarations ================================--
   signal txFrame_from_rsEncoder                : std_logic_vector(119 downto 0);        --! Frame from reed solomon encoder

   signal tx_frame_gbt_s                        : std_logic_vector(119 downto 0);
   signal tx_frame_wb_s                         : std_logic_vector(119 downto 0);
   --=====================================================================================--  
   
--=================================================================================================--
begin                 --========####   Architecture Body   ####========-- 
--=================================================================================================--   
   
   --==================================== User Logic =====================================--   
   
   --===========--
   -- GBT-Frame --
   --===========--
   
   gbtFrame_gen: if TX_ENCODING = GBT_FRAME or TX_ENCODING = GBT_DYNAMIC generate
      
      -- Reed-Solomon encoder:
      ------------------------
      --! First reed solomon encoder (60bit)
      reedSolomonEncoder60to119: entity work.gbt_tx_encoder_gbtframe_rsencode
         port map (
            TX_COMMON_FRAME_I                   => TX_HEADER_I(3 DOWNTO 0) & TX_COMMON_FRAME_I(83 DOWNTO 44),
            TX_COMMON_FRAME_ENCODED_O           => txFrame_from_rsEncoder(119 DOWNTO 60)
         );
      
	  --! Second reed solomon encoder (60bit)
      reedSolomonEncoder0to59: entity work.gbt_tx_encoder_gbtframe_rsencode
         port map (
            TX_COMMON_FRAME_I                   => TX_COMMON_FRAME_I(43 DOWNTO 0),
            TX_COMMON_FRAME_ENCODED_O           => txFrame_from_rsEncoder(59 DOWNTO 0)
         );
      
      -- Interleaver:
      ---------------
      --! Interleaver to mix the two reed solomon frames.
      interleaver: entity work.gbt_tx_encoder_gbtframe_intlver
         port map (
            TX_FRAME_I                          => txFrame_from_rsEncoder,
            TX_FRAME_O                          => tx_frame_gbt_s
         );

   end generate;
   
   --==========--
   -- Wide-Bus --
   --==========--
   
   wideBus_gen: if TX_ENCODING = WIDE_BUS or TX_ENCODING = GBT_DYNAMIC generate
      
      tx_frame_wb_s                                <= TX_HEADER_I & TX_COMMON_FRAME_I & TX_EXTRA_FRAME_WIDEBUS_I;
   
   end generate;
   
   --===================--
   -- Data out select.  --
   --===================--   
   wbsel_gen: if TX_ENCODING = WIDE_BUS generate      
      TX_FRAME_O                                <= tx_frame_wb_s;   
   end generate; 
   
   gbtsel_gen: if TX_ENCODING = GBT_FRAME generate      
      TX_FRAME_O                                <= tx_frame_gbt_s;   
   end generate;
   
   dynsel_gen: if TX_ENCODING = GBT_DYNAMIC generate      
      TX_FRAME_O                                <= tx_frame_gbt_s when TX_ENCODING_SEL_i = '1' else
                                                   tx_frame_wb_s;   
   end generate;
   
   
   --=====================================================================================--
end structural;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--