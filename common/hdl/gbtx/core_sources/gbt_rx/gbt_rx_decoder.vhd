-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Rx decoder 
-------------------------------------------------------

--! Include the IEEE VHDL standard library
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Include the GBT-FPGA specific packages
use work.gbt_bank_package.all;
use work.vendor_specific_gbt_bank_package.all;

--! @brief GBT_rx_decoder - Rx decoder
--! @details 
--! The GBT_rx_decoder module decode the data and correct errors when the GBT_FRAME encoding scheme
--! is used.
entity gbt_rx_decoder is
  generic (   
    RX_ENCODING                               : integer range 0 to 2 := GBT_FRAME    --! RX_ENCODING: Encoding scheme for the Rx datapath (GBT_FRAME or WIDE_BUS)
  );
  port (

    --===============--
    -- Reset & Clock --
    --===============--
    RX_RESET_I                                : in  std_logic;                       --! Reset the Rx decoder (Asynchronous)
    RX_FRAMECLK_I                             : in  std_logic;                       --! Rx frame clock used to clock the decoder logic
	 RX_CLKEN_i                                : in  std_logic;
	 
    --=========--
    -- Control --
    --=========--
    RX_ENCODING_SEL_i                         : in  std_logic;                       --! Select the Rx encoding in dynamic mode ('1': GBT / '0': WideBus)
    READY_O                                   : out std_logic;                       --! Ready flag of the decoder
    RX_ISDATA_FLAG_ENABLE_I                   : in  std_logic;                       --! Enable the header flag detection
    RX_ISDATA_FLAG_O                          : out std_logic;                       --! Is data flag recovered from the header
    RX_ERROR_DETECTED                         : out std_logic;                       --! Error detected by the decoder
    RX_BIT_MODIFIED_FLAG                      : out std_logic_vector(83 downto 0);   --! Position of high level bits indicate the position of the bits flipped by the decoder

    --=======--
    -- Frame --
    --=======--
    RX_FRAME_I                                : in  std_logic_vector(119 downto 0);  --! GBT frame to be decoded
    RX_COMMON_FRAME_O                         : out std_logic_vector( 83 downto 0);  --! GBT frame decoded
    RX_EXTRA_FRAME_WIDEBUS_O                  : out std_logic_vector( 31 downto 0)   --! Extra data of the Widebus frame
  );
end gbt_rx_decoder;

--! @brief GBT_rx_decoder architecture - Rx decoder
--! @details The GBT_rx_decoder architecture implements the modules to reorder the frame and decode/correct 
--! the frame when the GBT_FRAME encoding is selected or to push the GBT and Widebus extra words in output
--! when the Wide_bus mode is selected.
architecture structural of gbt_rx_decoder is 

    --================================ Signal Declarations ================================--
    signal rxFrame_from_deinterleaver            : std_logic_vector(119 downto 0);   --! Reordered frame from the deinterleaver
    signal rxCommonFrame_from_reedSolomonDecoder : std_logic_vector( 87 downto 0);   --! Decoded frame from the reed Solomon decoders
    
    signal error_detected_lsb                    : std_logic;                        --! Error detected/corrected flag for the least significant bits of the frame
    signal error_detected_msb                    : std_logic;                        --! Error detected/corrected flag for the most significant bits of the frame
    
    
    signal RX_COMMON_FRAME_gbt_s                     : std_logic_vector( 83 downto 0);  --! GBT frame decoded (signal for gbt frame)
    signal RX_EXTRA_FRAME_WIDEBUS_gbt_s              : std_logic_vector( 31 downto 0);  --! Extra data of the Widebus frame (signal for gbt frame)
    signal RX_ERROR_DETECTED_gbt_s                   : std_logic;                       --! Error detected by the decoder (signal for gbt frame)
    signal RX_BIT_MODIFIED_FLAG_gbt_s                : std_logic_vector(83 downto 0);   --! Position of high level bits indicate the position of the bits flipped by the decoder (signal for gbt frame)
    
    signal RX_COMMON_FRAME_wb_s                      : std_logic_vector( 83 downto 0);  --! GBT frame decoded (signal for wb frame)
    signal RX_EXTRA_FRAME_WIDEBUS_wb_s               : std_logic_vector( 31 downto 0);  --! Extra data of the Widebus frame (signal for wb frame)
    signal RX_ERROR_DETECTED_wb_s                    : std_logic;                       --! Error detected by the decoder (signal for wb frame)
    signal RX_BIT_MODIFIED_FLAG_wb_s                 : std_logic_vector(83 downto 0);   --! Position of high level bits indicate the position of the bits flipped by the decoder (signal for wb frame)
    --=====================================================================================--

begin

    --==================================== User Logic =====================================--   
    
	--! Extract Is data flag from header information
    RX_ISDATA_FLAG_O  <= '1' when (RX_FRAME_I(119 downto 116) = DATA_HEADER_PATTERN) and (RX_ISDATA_FLAG_ENABLE_I = '1') else '0'; 
   
    --=========--
    -- Decoder --
    --=========--  
   
    -- GBT-Frame:
    -------------   
    gbtFrame_gen: if RX_ENCODING = GBT_FRAME or RX_ENCODING = GBT_DYNAMIC generate
   
		--! The deinterleaver realigned the frame to get 2 encoded words of 60 bits (44bit data + 16bit FEC)
        deinterleaver: entity work.gbt_rx_decoder_gbtframe_deintlver
          port map (        
            RX_FRAME_I                          => RX_FRAME_I,
            RX_FRAME_O                          => rxFrame_from_deinterleaver
          );   

		--! Reed solomon decoder for the first 44bit data word
        reedSolomonDecoder60to119: entity work.gbt_rx_decoder_gbtframe_rsdec
          port map (
            RX_FRAMECLK_I                       => RX_FRAMECLK_I,
				RX_CLKEN_i                          => RX_CLKEN_i,
            RX_COMMON_FRAME_ENCODED_I           => rxFrame_from_deinterleaver(119 downto 60),
            RX_COMMON_FRAME_O                   => rxCommonFrame_from_reedSolomonDecoder(87 downto 44),
            ERROR_DETECT_O                      => error_detected_msb   -- Comment: Port added for debugging.
          );   

		--! Reed solomon decoder for the second 44bit data word
        reedSolomonDecoder0to50: entity work.gbt_rx_decoder_gbtframe_rsdec
          port map(
            RX_FRAMECLK_I                       => RX_FRAMECLK_I,
			RX_CLKEN_i                          => RX_CLKEN_i,
            RX_COMMON_FRAME_ENCODED_I           => rxFrame_from_deinterleaver(59 downto 0),
            RX_COMMON_FRAME_O                   => rxCommonFrame_from_reedSolomonDecoder(43 downto 0),
            ERROR_DETECT_O                      => error_detected_lsb   -- Comment: Port added for debugging.
          );    
      
        RX_COMMON_FRAME_gbt_s                       <= rxCommonFrame_from_reedSolomonDecoder(83 downto 0);        
        RX_ERROR_DETECTED_gbt_s                     <= error_detected_lsb or error_detected_msb;        
        RX_EXTRA_FRAME_WIDEBUS_gbt_s                <= (others => '0');
        
		  errflag_proc: process(RX_FRAMECLK_I)
		  begin
			
			    if RX_RESET_I = '1' then
			        RX_BIT_MODIFIED_FLAG_gbt_s   <= (others => '0');
			        
				elsif rising_edge(RX_FRAMECLK_I) then
				
					if RX_CLKEN_i = '1' then
						RX_BIT_MODIFIED_FLAG_gbt_s(83 downto 44)      <= rxCommonFrame_from_reedSolomonDecoder(83 downto 44) xor rxFrame_from_deinterleaver(115 downto 76);
						RX_BIT_MODIFIED_FLAG_gbt_s(43 downto 0)       <= rxCommonFrame_from_reedSolomonDecoder(43 downto 0) xor rxFrame_from_deinterleaver(59 downto 16);
					
					end if;
					
				end if;
			
		  end process;
        
    end generate;
   
    -- Wide-Bus:
    ------------
    wideBus_gen: if RX_ENCODING = WIDE_BUS or RX_ENCODING = GBT_DYNAMIC generate
      
        RX_COMMON_FRAME_wb_s                      <= RX_FRAME_I(115 downto 32);   -- No decoding in WideBus mode
        RX_EXTRA_FRAME_WIDEBUS_wb_s               <= RX_FRAME_I( 31 downto  0);   -- No decoding in WideBus mode
        RX_ERROR_DETECTED_wb_s                    <= '0';                         -- Not supported in widebus mode (no error correction)
        RX_BIT_MODIFIED_FLAG_wb_s                 <= (others => '0');             -- Not supported in widebus mode (no error correction)

    end generate;
    
    -- Encoding select.    
    wbsel_gen: if RX_ENCODING = WIDE_BUS generate
      
        RX_COMMON_FRAME_o                      <= RX_COMMON_FRAME_wb_s;
        RX_EXTRA_FRAME_WIDEBUS_o               <= RX_EXTRA_FRAME_WIDEBUS_wb_s;
        RX_ERROR_DETECTED                      <= RX_ERROR_DETECTED_wb_s;
        RX_BIT_MODIFIED_FLAG                   <= RX_BIT_MODIFIED_FLAG_wb_s;

    end generate; 
    
    gbtsel_gen: if RX_ENCODING = GBT_FRAME generate
      
        RX_COMMON_FRAME_o                      <= RX_COMMON_FRAME_gbt_s;
        RX_EXTRA_FRAME_WIDEBUS_o               <= RX_EXTRA_FRAME_WIDEBUS_gbt_s;
        RX_ERROR_DETECTED                      <= RX_ERROR_DETECTED_gbt_s;
        RX_BIT_MODIFIED_FLAG                   <= RX_BIT_MODIFIED_FLAG_gbt_s;

    end generate;

    dynsel_gen: if RX_ENCODING = GBT_DYNAMIC generate
      
        RX_COMMON_FRAME_o                      <= RX_COMMON_FRAME_gbt_s when RX_ENCODING_SEL_i = '1' else RX_COMMON_FRAME_wb_s;
        RX_EXTRA_FRAME_WIDEBUS_o               <= RX_EXTRA_FRAME_WIDEBUS_gbt_s when RX_ENCODING_SEL_i = '1' else RX_EXTRA_FRAME_WIDEBUS_wb_s;
        RX_ERROR_DETECTED                      <= RX_ERROR_DETECTED_gbt_s when RX_ENCODING_SEL_i = '1' else RX_ERROR_DETECTED_wb_s;
        RX_BIT_MODIFIED_FLAG                   <= RX_BIT_MODIFIED_FLAG_gbt_s when RX_ENCODING_SEL_i = '1' else RX_BIT_MODIFIED_FLAG_wb_s;

    end generate;    
   
    --============--
    -- Ready flag --
    --============--   
    READY_O                                      <= not(RX_RESET_I);             

   --=====================================================================================--
end structural;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--