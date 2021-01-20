-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Rx Datapath
-------------------------------------------------------

--! Include the IEEE VHDL standard library
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Include the GBT-FPGA specific packages
use work.gbt_bank_package.all;

--! @brief GBT_rx - Rx Datapath
--! @details 
--! The gbt_rx module implements the logic to decode the data from a GBTx.
entity gbt_rx is
  generic (   
    RX_ENCODING                               : integer range 0 to 2 := GBT_FRAME    --! RX_ENCODING: Encoding scheme for the Rx datapath (GBT_FRAME or WIDE_BUS)
  );
  port (

    --================--
    -- Reset & Clocks --
    --================--   
    RX_RESET_I                                : in  std_logic;                        --! Reset the Rx Decoder/Descrambler and the Rx gearbox [Clock domain: GBT_RXFRAMECLK_i]
    RX_FRAMECLK_I                             : in  std_logic;                        --! Rx datapath's clock (40MHz syncrhonous with NGT_RXWORDCLK_o and GBT_RXCLKEn_i = '1' or MGT_RXWORDCLK_o with GBT_RXCLKEn_i connected to the header flag signal)
    RX_CLKEN_i                                : in  std_logic;

    --=========--                                
    -- Status  --                                
    --=========--
    RX_ENCODING_SEL_i                         : in  std_logic;                        --! Select the Rx encoding in dynamic mode ('1': GBT / '0': WideBus)
    RX_READY_O                                : out std_logic;                        --! GBT Encoding/Scrambler is ready[Clock domain: GBT_RXFRAMECLK_i]
    RX_ISDATA_FLAG_O                          : out std_logic;                        --! Header Is data flag [Clock domain: GBT_RXFRAMECLK_i]
    RX_ERROR_DETECTED                         : out std_logic;                        --! Pulsed when error has been corrected by the decoder [Clock domain: GBT_RXFRAMECLK_i]
    RX_BIT_MODIFIED_FLAG                      : out std_logic_vector(83 downto 0);    --! Position of high level bits indicate the position of the bits flipped by the decoder [Clock domain: GBT_RXFRAMECLK_i]

    --=============--                                
    -- Word & Data --                                
    --=============--
    GBT_RXFRAME_i                             : in  std_logic_vector(119 downto 0);   --! Encoded frame from the Rx gearbox [Clock domain: GBT_RXFRAMECLK_i]
    RX_DATA_O                                 : out std_logic_vector(83 downto 0);    --! GBT Data received and decoded
    RX_EXTRA_DATA_WIDEBUS_O                   : out std_logic_vector(31 downto 0)     --! (rx) Extra data (32bit) replacing the FEC when the WideBus encoding scheme is selected

   );  
end gbt_rx;

--! @brief GBT_rx architecture - Rx datapath
--! @details The GBT_rx architecture implements all of the modules required to recover
--! the data from a GBT link.
architecture structural of gbt_rx is

   --================================ Signal Declarations ================================--
   
   --=========--
   -- Decoder --
   --=========--
   signal ready_from_decoder                    : std_logic;                         --! Ready status from the decoder
   signal rxIsDataFlag_from_decoder             : std_logic;                         --! Is data flag from header retrieved by the decoder
   signal rxCommonFrame_from_decoder            : std_logic_vector(83 downto 0);     --! Decoded GBT-FRAME
   signal rxExtraFrameWidebus_from_decoder      : std_logic_vector(31 downto 0);     --! "Decoded" extra data for widebus mode
   
   --=============--
   -- Descrambler --
   --=============--   
   signal ready_from_descrambler                : std_logic;                          --! Ready status from descrambler
   
   --=====================================================================================-- 
  
--=================================================================================================--
begin                 --========####   Architecture Body   ####========-- 
--=================================================================================================--
  
    --==================================== User Logic =====================================--
	--! Instantiation of the GBT Rx decoder
    decoder: entity work.gbt_rx_decoder 
      generic map (
        RX_ENCODING                            => RX_ENCODING
      )
      port map (
        RX_RESET_I                             => RX_RESET_I,
        RX_FRAMECLK_I                          => RX_FRAMECLK_I, 
		RX_CLKEN_i                             => RX_CLKEN_i,
        RX_ENCODING_SEL_i                      => RX_ENCODING_SEL_i,
         ---------------------------------------
        READY_O                                => ready_from_decoder,         
         ---------------------------------------
        RX_ISDATA_FLAG_ENABLE_I                => ready_from_descrambler,
        RX_ISDATA_FLAG_O                       => rxIsDataFlag_from_decoder,
         ---------------------------------------
        RX_FRAME_I                             => GBT_RXFRAME_i,
         ---------------------------------------
        RX_COMMON_FRAME_O                      => rxCommonFrame_from_decoder,
        RX_EXTRA_FRAME_WIDEBUS_O               => rxExtraFrameWidebus_from_decoder,
            ---------------------------------------
        RX_ERROR_DETECTED                      => RX_ERROR_DETECTED,
        RX_BIT_MODIFIED_FLAG                   => RX_BIT_MODIFIED_FLAG    
    );
      
    --! Instantiation of the GBT Rx descrambler 
    descrambler: entity work.gbt_rx_descrambler
      generic map (
        RX_ENCODING                            => RX_ENCODING
      )
      port map (
        RX_RESET_I                             => RX_RESET_I, 
        RX_FRAMECLK_I                          => RX_FRAMECLK_I,
		RX_CLKEN_i                             => RX_CLKEN_i,
        RX_ENCODING_SEL_i                      => RX_ENCODING_SEL_i,
         ---------------------------------------
        RX_DECODER_READY_I                     => ready_from_decoder,
        READY_O                                => ready_from_descrambler,
         ---------------------------------------
        RX_ISDATA_FLAG_I                       => rxIsDataFlag_from_decoder,
        RX_ISDATA_FLAG_O                       => RX_ISDATA_FLAG_O,
         ---------------------------------------
        RX_COMMON_FRAME_I                      => rxCommonFrame_from_decoder,
        RX_DATA_O                              => RX_DATA_O,
         ---------------------------------------
        RX_EXTRA_FRAME_WIDEBUS_I               => rxExtraFrameWidebus_from_decoder,
        RX_EXTRA_DATA_WIDEBUS_O                => RX_EXTRA_DATA_WIDEBUS_O
      );

    RX_READY_O                                   <= ready_from_descrambler;
   
   --=====================================================================================--  
end structural;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--