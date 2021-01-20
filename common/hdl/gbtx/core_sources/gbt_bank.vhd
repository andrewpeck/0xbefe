-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Top Level
-------------------------------------------------------

--! Include the IEEE VHDL standard library
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Include the GBT-FPGA specific packages
use work.gbt_bank_package.all;
use work.vendor_specific_gbt_bank_package.all;

--! @brief GBT_BANK - TOP Level
--! @details 
--! The gbt_bank module implements the logic required to implement the encoding/decoding
--! required to communicate or emulate a GBTx
entity gbt_bank is 
   generic (   
        NUM_LINKS                 : integer := 1;                            --! NUM_LINKS: number of links instantiated by the core (Altera: up to 6, Xilinx: up to 4)
        TX_OPTIMIZATION           : integer range 0 to 1 := STANDARD;        --! TX_OPTIMIZATION: Latency mode for the Tx path (STANDARD or LATENCY_OPTIMIZED)
        RX_OPTIMIZATION           : integer range 0 to 1 := STANDARD;        --! RX_OPTIMIZATION: Latency mode for the Rx path (STANDARD or LATENCY_OPTIMIZED)
        TX_ENCODING               : integer range 0 to 2 := GBT_FRAME;       --! TX_ENCODING: Encoding scheme for the Tx datapath (GBT_FRAME or WIDE_BUS)
        RX_ENCODING               : integer range 0 to 2 := GBT_FRAME        --! RX_ENCODING: Encoding scheme for the Rx datapath (GBT_FRAME or WIDE_BUS)
   );
   port (   
      
        --========--
        -- Resets --
        --========--
        MGT_TXRESET_i            : in  std_logic_vector(1 to NUM_LINKS);    --! Reset the TX path of the transceiver (Tx PLL is reset with the first link) [Clock domain: MGT_CLK_i]
        MGT_RXRESET_i            : in  std_logic_vector(1 to NUM_LINKS);    --! Reset the Rx path of the transceiver [Clock domain: MGT_CLK_i]
        GBT_TXRESET_i            : in  std_logic_vector(1 to NUM_LINKS);    --! Reset the Tx Scrambler/Encoder and the Tx Gearbox [Clock domain: GBT_TXFRAMECLK_i]
        GBT_RXRESET_i            : in  std_logic_vector(1 to NUM_LINKS);    --! Reset the Rx Decoder/Descrambler and the Rx gearbox [Clock domain: GBT_RXFRAMECLK_i]
        
        --========--
        -- Clocks --     
        --========--
        MGT_CLK_i                : in  std_logic;                           --! Transceiver reference clock
        GBT_TXFRAMECLK_i         : in  std_logic_vector(1 to NUM_LINKS);    --! Tx datapath's clock (40MHz with GBT_TXCLKEn_i = '1' or MGT_TXWORDCLK_o with GBT_TXCLKEn_i pulsed every 3/6 clock cycles)
        GBT_TXCLKEn_i            : in  std_logic_vector(1 to NUM_LINKS);    --! Rx clock enable signal used when the Rx frameclock is different from 40MHz
		GBT_RXFRAMECLK_i         : in  std_logic_Vector(1 to NUM_LINKS);    --! Rx datapath's clock (40MHz syncrhonous with NGT_RXWORDCLK_o and GBT_RXCLKEn_i = '1' or MGT_RXWORDCLK_o with GBT_RXCLKEn_i connected to the header flag signal)
        GBT_RXCLKEn_i            : in  std_logic_vector(1 to NUM_LINKS);    --! Rx clock enable signal used when the Rx frameclock is different from 40MHz
		MGT_TXWORDCLK_o          : out std_logic_vector(1 to NUM_LINKS);    --! Tx Wordclock from the transceiver (could be used to clock the core with Clocking enable)
        MGT_RXWORDCLK_o          : out std_logic_vector(1 to NUM_LINKS);    --! Rx Wordclock from the transceiver (could be used to clock the core with Clocking enable)
        
        --================--
        -- GBT TX Control --
        --================--
        TX_ENCODING_SEL_i        : in  std_logic_vector(1 to NUM_LINKS);    --! Select the Tx encoding in dynamic mode ('1': GBT / '0': WideBus)
        GBT_ISDATAFLAG_i         : in  std_logic_vector(1 to NUM_LINKS);    --! Enable dataflag (header) [Clock domain: GBT_TXFRAMECLK_i]
        
        --=================--
        -- GBT TX Status   --
        --=================--
        TX_PHCOMPUTED_o          : out std_logic_vector(1 to NUM_LINKS);    --! Tx frameclock and Tx wordclock alignement is computed (flag)
		TX_PHALIGNED_o           : out std_logic_vector(1 to NUM_LINKS);    --! Tx frameclock and Tx wordclock are aligned (gearbox is working correctly)
		  
        --================--
        -- GBT RX Control --
        --================--
        RX_ENCODING_SEL_i        : in  std_logic_vector(1 to NUM_LINKS);    --! Select the Rx encoding in dynamic mode ('1': GBT / '0': WideBus)
        
        --=================--
        -- GBT RX Status   --
        --=================--
        GBT_RXREADY_o            : out std_logic_vector(1 to NUM_LINKS);    --! GBT Encoding/Scrambler is ready[Clock domain: GBT_RXFRAMECLK_i]
        GBT_ISDATAFLAG_o         : out std_logic_vector(1 to NUM_LINKS);    --! Header Is data flag [Clock domain: GBT_RXFRAMECLK_i]
        GBT_ERRORDETECTED_o      : out std_logic_vector(1 to NUM_LINKS);    --! Pulsed when error has been corrected by the decoder [Clock domain: GBT_RXFRAMECLK_i]
        GBT_ERRORFLAG_o          : out gbt_reg84_A(1 to NUM_LINKS);         --! Position of high level bits indicate the position of the bits flipped by the decoder [Clock domain: GBT_RXFRAMECLK_i]
        
        --================--
        -- MGT Control    --
        --================--
        MGT_DEVSPECIFIC_i        : in  mgtDeviceSpecific_i_R;               --! Device specific record connected to the transceiver, defined into the device specific package
        MGT_RSTONBITSLIPEn_i     : in  std_logic_vector(1 to NUM_LINKS);    --! Enable of the "reset on even or odd bitslip" state machine. It ensures fix latency with a UI precision [Clock domain: MGT_CLK_i]
        MGT_RSTONEVEN_i          : in  std_logic_vector(1 to NUM_LINKS);    --! Configure the "reset on even or odd bitslip": '1' reset when bitslip is even and '0' when is odd [Clock domain: MGT_CLK_i]
        
        --=================--
        -- MGT Status      --
        --=================--
        MGT_TXREADY_o            : out std_logic_vector(1 to NUM_LINKS);    --! Transceiver tx's path ready signal [Clock domain: MGT_CLK_i]
        MGT_RXREADY_o            : out std_logic_vector(1 to NUM_LINKS);    --! Transceiver rx's path ready signal [Clock domain: MGT_CLK_i]
        MGT_DEVSPECIFIC_o        : out mgtDeviceSpecific_o_R;               --! Device specific record connected to the transceiver, defined into the device specific package
        MGT_HEADERFLAG_o         : out std_logic_vector(1 to NUM_LINKS);    --! Pulsed when the MGT word contains the header [Clock domain: MGT_RXWORDCLK_o]
        MGT_HEADERLOCKED_o       : out std_logic_vector(1 to NUM_LINKS);    --! Asserted when the header is locked
        MGT_RSTCNT_o             : out gbt_reg8_A(1 to NUM_LINKS);          --! Number of resets because of a wrong bitslip parity
		  
        --========--
        -- Data   --
        --========--
        GBT_TXDATA_i             : in  gbt_reg84_A(1 to NUM_LINKS);         --! GBT Data to be encoded and transmit
        GBT_RXDATA_o             : out gbt_reg84_A(1 to NUM_LINKS);         --! GBT Data received and decoded
        
        WB_TXDATA_i              : in  gbt_reg32_A(1 to NUM_LINKS);         --! (tx) Extra data (32bit) to replace the FEC when the WideBus encoding scheme is selected
        WB_RXDATA_o              : out gbt_reg32_A(1 to NUM_LINKS)          --! (rx) Extra data (32bit) replacing the FEC when the WideBus encoding scheme is selected
      
   );
end gbt_bank;

--! @brief GBT_BANK architecture - TOP Level
--! @details The GBT_BANK architecture instantiates the Tx datapath, Rx datapath, Gearboxes for the clock domain
--! crossing and the transceiver required to establish GBT links.
architecture structural of gbt_bank is   

    --================================ Signal Declarations ================================--

    --========--
    -- GBT TX --
    --========--
    signal gbt_txencdata_s                  : gbt_reg120_A (1 to NUM_LINKS);      --! Encoded data buses used to connect the output of the datapath to the Tx gearbox
    signal gbt_txclkfromDesc_s              : std_logic_vector(1 to NUM_LINKS);	 
	 
    --========--
    -- MGT    --
    --========--
    signal mgt_txwordclk_s                  : std_logic_vector(1 to NUM_LINKS);   --! Tx wordclock signal used to connect the clock from the transceiver to the Tx gearbox
    signal mgt_rxwordclk_s                  : std_logic_vector(1 to NUM_LINKS);   --! Rx wordclock signal used to connect the clock recovered from the data to the Rx gearbox
    signal mgt_txword_s                     : word_mxnbit_A (1 to NUM_LINKS);     --! Tx word to the transceiver (from the Tx gearbox to the MGT)
    signal mgt_rxword_s                     : word_mxnbit_A (1 to NUM_LINKS);     --! Rx word from the transceiver (from the transceiver to the Rx gearbox)
    signal mgt_headerflag_s                 : std_logic_vector(1 to NUM_LINKS);   --! Header flag to provide the header position over the 3/6 MGT word used to make the GBT word
    
    --========--
    -- GBT Rx --
    --========--
    signal gbt_rxencdata_s                  : gbt_reg120_A (1 to NUM_LINKS);      --! Encoded data buses used to connect the output of the Rx gearbox to the datapath
    signal gbt_rxgearboxready_s             : std_logic_vector(1 to NUM_LINKS);
	signal gbt_rxclkengearbox_s             : std_logic_vector(1 to NUM_LINKS);
	 
   --=====================================================================================--
   
--=================================================================================================--
begin                 --========####   Architecture Body   ####========-- 
--=================================================================================================--

   --==================================== User Logic =====================================--
   
    --! Multi instantiation of the GBT Tx datapath (Srambler and Encoder) for each link of the bank
    gbt_txdatapath_multilink_gen: for i in 1 to NUM_LINKS generate 
        gbt_txdatapath_inst: entity work.gbt_tx        
            generic map (            
                TX_ENCODING                        => TX_ENCODING
            )
            port map (                
                TX_RESET_I                         => GBT_TXRESET_i(i),
                TX_FRAMECLK_I                      => GBT_TXFRAMECLK_i(i),
                TX_CLKEN_i                         => GBT_TXCLKEn_i(i),
                
                TX_ENCODING_SEL_i                  => TX_ENCODING_SEL_i(i),					 
                TX_ISDATA_SEL_I                    => GBT_ISDATAFLAG_i(i), 

                TX_DATA_I                          => GBT_TXDATA_i(i),
                TX_EXTRA_DATA_WIDEBUS_I            => WB_TXDATA_i(i),
                
                TX_FRAME_o                         => gbt_txencdata_s(i)
            );                    
    end generate;
       
    --! Multi instantiation of the GBT Tx gearbox (from GBT word [120bit] to MGT words [20/40bit]) for each link of the bank   
    gbt_txgearbox_multilink_gen: for i in 1 to NUM_LINKS generate 
        gbt_txgearbox_inst: entity work.gbt_tx_gearbox    
          generic map (
            TX_OPTIMIZATION                        => TX_OPTIMIZATION
          )
          port map (
            TX_RESET_I                             => GBT_TXRESET_i(i),
            TX_FRAMECLK_I                          => GBT_TXFRAMECLK_i(i),
				TX_CLKEN_i                             => GBT_TXCLKEn_i(i),
            TX_WORDCLK_I                           => mgt_txwordclk_s(i),
             ---------------------------------------
				TX_PHALIGNED_o                         => TX_PHALIGNED_o(i),
				TX_PHCOMPUTED_o                        => TX_PHCOMPUTED_o(i),
				
            TX_FRAME_I                             => gbt_txencdata_s(i),
            TX_WORD_O                              => mgt_txword_s(i)
          );
    end generate;
    
    --! Instantiation of the transceiver module (MGT and FrameAligner)
    mgt_inst: entity work.mgt
        generic map (
            NUM_LINKS                    => NUM_LINKS
        )
        port map (            
            MGT_REFCLK_i                 => MGT_CLK_i,
            
            MGT_RXUSRCLK_o               => mgt_rxwordclk_s,
            MGT_TXUSRCLK_o               => mgt_txwordclk_s,
            
            --=============--
            -- Resets      --
            --=============--
            MGT_TXRESET_i                => MGT_TXRESET_i,
            MGT_RXRESET_i                => MGT_RXRESET_i,
            
            --=============--
            -- Status      --
            --=============--
            MGT_TXREADY_o                => MGT_TXREADY_o,
            MGT_RXREADY_o                => MGT_RXREADY_o,

            RX_HEADERLOCKED_o            => MGT_HEADERLOCKED_o,
            RX_HEADERFLAG_o              => mgt_headerflag_s,
            MGT_RSTCNT_o                 => MGT_RSTCNT_o,
				
			--==============--
			-- Control      --
			--==============--				
		    MGT_AUTORSTEn_i              => MGT_RSTONBITSLIPEn_i,
            MGT_AUTORSTONEVEN_i          => MGT_RSTONEVEN_i,
		  
            --==============--
            -- Data         --
            --==============--
            MGT_USRWORD_i                => mgt_txword_s,
            MGT_USRWORD_o                => mgt_rxword_s,
            
            --=============================--
            -- Device specific connections --
            --=============================--
            MGT_DEVSPEC_i                => MGT_DEVSPECIFIC_i,
            MGT_DEVSPEC_o                => MGT_DEVSPECIFIC_o
        );
    
    MGT_HEADERFLAG_o <= mgt_headerflag_s;
    MGT_TXWORDCLK_o  <= mgt_txwordclk_s;
    MGT_RXWORDCLK_o  <= mgt_rxwordclk_s;
    
    --! Multi instantiation of the GBT Rx gearbox (from MGT word [20/40bit] to GBT word [120bit]) for each link of the bank
    gbt_rxgearbox_multilink_gen: for i in 1 to NUM_LINKS generate
        gbt_rxgearbox_inst: entity work.gbt_rx_gearbox
          generic map (
            RX_OPTIMIZATION                        => RX_OPTIMIZATION
          )
          port map (
            RX_RESET_I                             => GBT_RXRESET_i(i), 
            RX_WORDCLK_I                           => mgt_rxwordclk_s(i), 
				RX_FRAMECLK_I                          => GBT_RXFRAMECLK_i(i),
				RX_CLKEN_i                             => GBT_RXCLKEn_i(i),
				RX_CLKEN_o                             => gbt_rxclkengearbox_s(i),
            ---------------------------------------
            RX_HEADERFLAG_i                        => mgt_headerflag_s(i),
				READY_O                                => gbt_rxgearboxready_s(i),
            ---------------------------------------
            RX_WORD_I                              => mgt_rxword_s(i),
            RX_FRAME_O                             => gbt_rxencdata_s(i)
        ); 
    end generate;
    
    --! Multi instantiation of the GBT Rx datapath (Decoder and Descrambler) for each link of the bank
    gbt_rxdatapath_multilink_gen: for i in 1 to NUM_LINKS generate    
        
        gbt_rxdatapath_inst: entity work.gbt_rx            
            generic map (
                RX_ENCODING                        => RX_ENCODING
            )         
            port map (    
                RX_RESET_I                         => not(gbt_rxgearboxready_s(i)),
                RX_FRAMECLK_I                      => GBT_RXFRAMECLK_i(i),
				RX_CLKEN_i                         => gbt_rxclkengearbox_s(i),
                
                RX_ENCODING_SEL_i                  => RX_ENCODING_SEL_i(i),                
                RX_READY_O                         => GBT_RXREADY_o(i),
                RX_ISDATA_FLAG_O                   => GBT_ISDATAFLAG_o(i),
                RX_ERROR_DETECTED                  => GBT_ERRORDETECTED_o(i),
                RX_BIT_MODIFIED_FLAG               => GBT_ERRORFLAG_o(i),
                    
                GBT_RXFRAME_i                      => gbt_rxencdata_s(i),
                RX_DATA_O                          => GBT_RXDATA_o(i),
                RX_EXTRA_DATA_WIDEBUS_O            => WB_RXDATA_o(i)
            );
                
    end generate;
    
   --=====================================================================================--
end structural;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--