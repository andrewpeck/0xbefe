-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Tx Datapath
-------------------------------------------------------

--! Include the IEEE VHDL standard library
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Include the GBT-FPGA specific packages
use work.gbt_bank_package.all;

--! @brief GBT_tx - Tx Datapath
--! @details 
--! The gbt_tx module implements the logic to scramble and encode the data according to the GBTx specifications.
entity gbt_tx is
  generic (   
    TX_ENCODING                        : integer range 0 to 2 := GBT_FRAME     --! TX_ENCODING: Encoding scheme for the Tx datapath (GBT_FRAME or WIDE_BUS)
  );
  port (
    TX_RESET_I                         : in  std_logic;                        --! Reset the Tx Scrambler/Encoder
    TX_FRAMECLK_I                      : in  std_logic;                        --! Tx datapath's clock (40MHz with GBT_TXCLKEn_i = '1' or MGT_TXWORDCLK_o with GBT_TXCLKEn_i pulsed every 3/6 clock cycles)
    TX_CLKEN_i                         : in  std_logic;
	 
    TX_ENCODING_SEL_i                  : in  std_logic;
    TX_ISDATA_SEL_I                    : in  std_logic;                        --! Enable dataflag (header)

    TX_DATA_I                          : in  std_logic_vector(83 downto 0);    --! GBT Data to be encoded
    TX_EXTRA_DATA_WIDEBUS_I            : in  std_logic_vector(31 downto 0);    --! (tx) Extra data (32bit) to replace the FEC when the WideBus encoding scheme is selected

    TX_FRAME_o                         : out std_logic_vector(119 downto 0)    --! Encoded data
  );  
end gbt_tx;

--! @brief GBT_tx architecture - Tx datapath
--! @details The GBT_tx architecture implements all of the modules required to scramble and encode
--! the data according to the GBTx specifications.
architecture structural of gbt_tx is

   --================================ Signal Declarations ================================--
   
   --===========--
   -- Scrambler --
   --===========--
   signal txHeader_from_scrambler               : std_logic_vector( 3 downto 0);  --! 4bit header generated depending on the IsData flag
   signal txCommonFrame_from_scrambler          : std_logic_vector(83 downto 0);  --! 84bit frame from the scrambler to the encoder
   signal txExtraFrameWidebus_from_scrambler    : std_logic_vector(31 downto 0);  --! 32bit extra data frame from the scrambler to the encoder
       
   --=====================================================================================--   
  
--=================================================================================================--
begin                 --========####   Architecture Body   ####========-- 
--=================================================================================================--
  
    --==================================== User Logic =====================================--
   
    --! Instantiation of the GBT Tx scrambler
    scrambler: entity work.gbt_tx_scrambler
      generic map (
        TX_ENCODING                            => TX_ENCODING
      )
      port map (
        TX_RESET_I                             => TX_RESET_I,
        TX_FRAMECLK_I                          => TX_FRAMECLK_I,
		  TX_CLKEN_i                             => TX_CLKEN_i,
		   ---------------------------------------  
        TX_ISDATA_SEL_I                        => TX_ISDATA_SEL_I,
        TX_HEADER_O                            => txHeader_from_scrambler,
         ---------------------------------------  
        TX_DATA_I                              => TX_DATA_I,
        TX_COMMON_FRAME_O                      => txCommonFrame_from_scrambler,
         ---------------------------------------
        TX_EXTRA_DATA_WIDEBUS_I                => TX_EXTRA_DATA_WIDEBUS_I,
        TX_EXTRA_FRAME_WIDEBUS_O               => txExtraFrameWidebus_from_scrambler
    );    

    --! Instantiation of the GBT Tx encoder  
    encoder: entity work.gbt_tx_encoder
      generic map (
        TX_ENCODING                            => TX_ENCODING
      )
      port map (
        TX_RESET_I                             => TX_RESET_I,
        TX_ENCODING_SEL_i                      => TX_ENCODING_SEL_i,
         ---------------------------------------
        TX_HEADER_I                            => txHeader_from_scrambler,
         ---------------------------------------
        TX_COMMON_FRAME_I                      => txCommonFrame_from_scrambler,
        TX_EXTRA_FRAME_WIDEBUS_I               => txExtraFrameWidebus_from_scrambler,
         ---------------------------------------
        TX_FRAME_O                             => TX_FRAME_o
    );    
   --=====================================================================================--  
end structural;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--