-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 1.0
--! @brief LpGBT-FPGA Uplink datapath
-------------------------------------------------------

--! Include the IEEE VHDL standard library
library ieee;
use ieee.std_logic_1164.all;

--! Include the LpGBT-FPGA specific package
use work.lpgbtfpga_package.all;

--! @brief LpGBT_FPGA_Uplink_datapath - Uplink datapath top level
--! @details 
--! The LpGBT_FPGA_Uplink_datapath module implements the logic required 
--! for the decoding of data sent by the LpGBT on the uplink path
--! (Front-end to Back-end). It supports 2 datarates (10.24 and 5.12 gbps)
--! and 2 encodings (FEC5 or FEC12) configuration.
ENTITY LpGBT_FPGA_Uplink_datapath IS
   GENERIC(
        DATARATE                        : integer range 0 to 2 := DYNAMIC;       --! Datarate selection can be: DYNAMIC, DATARATE_10G24 or DATARATE_5G12
        FEC                             : integer range 0 to 2 := DYNAMIC;       --! FEC selection can be: DYNAMIC, FEC5 or FEC12
        MULTICYCLE_DELAY                : integer range 0 to 7 := 3              --! Multicycle delay
   );
   PORT (
        -- Clock and reset
        uplinkClk_i                     : in  std_logic;                         --! Input clock used to decode the received data
        uplinkClkInEn_i                 : in  std_logic;                         --! Clock enable from Rx gearbox (Data flag)
        uplinkClkOutEn_o                : out std_logic;                         --! Clock enable shifted from N clock cycle (clock data out - used by the user's logic)
        uplinkRst_i                     : in  std_logic;                         --! Uplink datapath's reset signal
        
        -- Input
        uplinkFrame_i                   : in  std_logic_vector(255 downto 0);    --! Input frame coming from the MGT -> Rx Gearbox. 
                                                                                 --! In case of 5g12 datarate, the data bus of 128 bits shall be duplicated
                                                                                 --! as followind: uplinkFrame_i <= data_5g12 & data_5g12
        -- Data
        uplinkUserData_o                : out std_logic_vector(229 downto 0);    --! User output (decoded data). The payload size varies depending on the
                                                                                 --! datarate/FEC configuration: 
                                                                                 --!     * *FEC5 / 5.12 Gbps*: 112bit
                                                                                 --!     * *FEC12 / 5.12 Gbps*: 98bit
                                                                                 --!     * *FEC5 / 10.24 Gbps*: 230bit
                                                                                 --!     * *FEC12 / 10.24 Gbps*: 202bit
        uplinkEcData_o                  : out std_logic_vector(1 downto 0);      --! EC field value received from the LpGBT
        uplinkIcData_o                  : out std_logic_vector(1 downto 0);      --! IC field value received from the LpGBT

        -- Control
        uplinkSelectDataRate_i          : in  std_logic;                         --! Datarate selection (only in DYNAMIC mode) -> '0': 5.12Gbps / '1': 10.24Gbps
        uplinkSelectFEC_i               : in  std_logic;                         --! FEC selection (only in DYNAMIC mode) -> '0': FEC5 / '1': FEC12
        uplinkBypassInterleaver_i       : in  std_logic;                         --! Bypass uplink interleaver (test purpose only)
        uplinkBypassFECEncoder_i        : in  std_logic;                         --! Bypass uplink FEC (test purpose only)
        uplinkBypassScrambler_i         : in  std_logic;                         --! Bypass uplink scrambler (test purpose only)
                        
        -- Status
        uplinkDataCorrected_o           : out std_logic_vector(229 downto 0);    --! Flag allowing to know which bit(s) were toggled by the FEC
        uplinkIcCorrected_o             : out std_logic_vector(1 downto 0);      --! Flag allowing to know which bit(s) of the IC field were toggled by the FEC
        uplinkEcCorrected_o             : out std_logic_vector(1 downto 0);      --! Flag allowing to know which bit(s) of the EC field  were toggled by the FEC
        uplinkReady_o                   : out std_logic                          --! Ready signal from the uplink decoder
   );  
END LpGBT_FPGA_Uplink_datapath;

--! @brief LpGBT_FPGA_Uplink_datapath - Uplink datapath top level
--! @details 
--! The LpGBT_FPGA_Uplink_datapath module de-interleaves, decodes and
--! descrambles the data received from the LpGBT. It supports the 4
--! following configurations:
--!     * *(FEC5 / 5.12 Gbps)*: User data output is 112bit (can correct up to 5 consecutives bits)
--!     * *(FEC12 / 5.12 Gbps)*: User data output is 98bit (can correct up to 12 consecutives bits)
--!     * *(FEC5 / 10.24 Gbps)*: User data output is 230bit (can correct up to 10 consecutives bits)
--!     * *(FEC12 / 10.24 Gbps)*: User data output is 202bit (can correct up to 24 consecutives bits)
ARCHITECTURE behabioral of LpGBT_FPGA_Uplink_datapath IS
    
    --! Uplink descrambler component
    COMPONENT upLinkDescramlber
       GENERIC(
            DATARATE                        : integer range 0 to 2 := DYNAMIC;
            FEC                             : integer range 0 to 2 := DYNAMIC
       );
       PORT (
            -- Clock and reset
            clk_i                           : in  std_logic;
            clkEn_i                         : in  std_logic;
            
            reset_i                         : in  std_logic;
            
            -- Data
            fec5_data_i                     : in  std_logic_vector(233 downto 0);
            fec12_data_i                    : in  std_logic_vector(205 downto 0);

            fec5_data_o                     : out std_logic_vector(233 downto 0);
            fec12_data_o                    : out std_logic_vector(205 downto 0);

            -- Control
            bypass                          : in  std_logic
       );  
    END COMPONENT;
    
    --! Uplink decoder component
    COMPONENT upLinkDecoder
       GENERIC(
            DATARATE                        : integer range 0 to 2 := DYNAMIC;
            FEC                             : integer range 0 to 2 := DYNAMIC
       );
       PORT (    
            uplinkClk_i                     : in  std_logic;
            uplinkClkInEn_i                 : in  std_logic;
            uplinkClkOutEn_i                : in  std_logic;
            -- Data
            fec5_data_i                     : in  std_logic_vector(233 downto 0);
            fec5_fec_i                      : in  std_logic_vector(19 downto 0);
            fec12_data_i                    : in  std_logic_vector(205 downto 0);
            fec12_fec_i                     : in  std_logic_vector(47 downto 0);

            fec5_data_o                     : out std_logic_vector(233 downto 0);
            fec12_data_o                    : out std_logic_vector(205 downto 0);
            
            fec5_correction_pattern_o       : out std_logic_vector(233 downto 0);
            fec12_correction_pattern_o      : out std_logic_vector(205 downto 0);
                    
            -- Control
            datarate_select_i               : in  std_logic;
            bypass                          : in  std_logic
       );  
    END COMPONENT;
    
    --! Uplink de-interleaver component
    COMPONENT upLinkDeinterleaver
       GENERIC(
            DATARATE                        : integer range 0 to 2 := DYNAMIC;
            FEC                             : integer range 0 to 2 := DYNAMIC
       );
       PORT (
            -- Data
            data_i                          : in  std_logic_vector(255 downto 0);

            fec5_data_o                     : out std_logic_vector(233 downto 0);
            fec5_fec_o                      : out std_logic_vector(19 downto 0);
            fec12_data_o                    : out std_logic_vector(205 downto 0);
            fec12_fec_o                     : out std_logic_vector(47 downto 0);

            -- Control
            datarate_select_i               : in  std_logic;
            bypass                          : in  std_logic
       );  
    END COMPONENT;
    
    signal fec5_data_from_deinterleaver_s   : std_logic_vector(233 downto 0);    --! Data from de-interleaver (FEC5)
    signal fec5_fec_from_deinterleaver_s    : std_logic_vector(19 downto 0);     --! FEC from de-interleaver (FEC5)
    signal fec12_data_from_deinterleaver_s  : std_logic_vector(205 downto 0);    --! Data from de-interleaver (FEC12)
    signal fec12_fec_from_deinterleaver_s   : std_logic_vector(47 downto 0);     --! FEC from de-interleaver (FEC12)
    
    signal fec5_data_from_decoder_s         : std_logic_vector(233 downto 0);    --! Data from decoder (FEC5)
    signal fec12_data_from_decoder_s        : std_logic_vector(205 downto 0);    --! Data from decoder (FEC12)
    
    signal fec5_data_from_descrambler_s     : std_logic_vector(233 downto 0);    --! Data from descrambler (FEC5)
    signal fec12_data_from_descrambler_s    : std_logic_vector(205 downto 0);    --! Data from descrambler (FEC12)
    
    signal fec5_correction_s                : std_logic_vector(233 downto 0);    --! Correction flag (FEC5)
    signal fec12_correction_s               : std_logic_vector(205 downto 0);    --! Correction flag (FEC12)
    
    signal uplinkReady_0_s                  : std_logic;                         --! Ready register to delay the ready signal
    signal uplinkReady_1_s                  : std_logic;                         --! Ready register to delay the ready signal
    
    signal uplinkUserData_10g24_s           : std_logic_vector(229 downto 0);    --! Uplink output for 10g24 datarate configuration (User data)
    signal uplinkEcData_10g24_s             : std_logic_vector(1 downto 0);      --! Uplink output for 10g24 datarate configuration (EC)
    signal uplinkIcData_10g24_s             : std_logic_vector(1 downto 0);      --! Uplink output for 10g24 datarate configuration (IC)
    
    signal uplinkUserData_5g12_s            : std_logic_vector(229 downto 0);    --! Uplink output for 5g12 datarate configuration (User data)
    signal uplinkEcData_5g12_s              : std_logic_vector(1 downto 0);      --! Uplink output for 5g12 datarate configuration (EC)
    signal uplinkIcData_5g12_s              : std_logic_vector(1 downto 0);      --! Uplink output for 5g12 datarate configuration (IC)
    
    signal uplinkCorrData_10g24_s           : std_logic_vector(229 downto 0);    --! Uplink correction flag output for 10g24 datarate configuration (User data)
    signal uplinkCorrEc_10g24_s             : std_logic_vector(1 downto 0);      --! Uplink correction flag output for 10g24 datarate configuration (EC)
    signal uplinkCorrIc_10g24_s             : std_logic_vector(1 downto 0);      --! Uplink correction flag output for 10g24 datarate configuration (IC)
    
    signal uplinkCorrData_5g12_s            : std_logic_vector(229 downto 0);    --! Uplink correction flag output for 5g12 datarate configuration (User data)
    signal uplinkCorrEc_5g12_s              : std_logic_vector(1 downto 0);      --! Uplink correction flag output for 5g12 datarate configuration (EC)
    signal uplinkCorrIc_5g12_s              : std_logic_vector(1 downto 0);      --! Uplink correction flag output for 5g12 datarate configuration (IC)
    
    signal uplinkFrame_pipelined_s          : std_logic_vector(255 downto 0);    --! Store input data in register to ensure stability
    signal uplinkClkOutEn_s                 : std_logic;
    signal rst_uplinkInitDone_s             : std_logic;
    
BEGIN                 --========####   Architecture Body   ####========-- 
        
    
    --! Multicycle path configuration
    syncShiftReg_proc: process(uplinkRst_i, uplinkClk_i)
        variable cnter  : integer range 0 to 7;
    begin
    
        if uplinkRst_i = '1' then
              cnter              := 0;
              uplinkClkOutEn_s   <= '0';
              
        elsif rising_edge(uplinkClk_i) then
            if uplinkClkInEn_i = '1' then
                cnter                 := 0;
                rst_uplinkInitDone_s  <= '1';
            elsif rst_uplinkInitDone_s = '1' then
                cnter            := cnter + 1;
            end if;
            
            uplinkClkOutEn_s       <= '0';
            if cnter = MULTICYCLE_DELAY then
                uplinkClkOutEn_s   <= '1';
            end if;
        end if;
    end process;
    
    uplinkClkOutEn_o  <= uplinkClkOutEn_s;
        
    --! Generate ready signal from the reset (2 clock cycle delay)
    dataInPipeliner_proc: process(uplinkClk_i, uplinkRst_i)
    begin    
        if uplinkRst_i = '1' then
            uplinkFrame_pipelined_s      <= (others => '0');
        elsif rising_edge(uplinkClk_i) then        
            if uplinkClkInEn_i = '1' then
                uplinkFrame_pipelined_s  <= uplinkFrame_i;
            end if;            
        end if;
    end process;
        
    
    upLinkDeinterleaver_inst: upLinkDeinterleaver
       generic map(
            DATARATE                        => DATARATE,
            FEC                             => FEC
       )
       port map (
            -- Data
            data_i                          => uplinkFrame_pipelined_s,

            fec5_data_o                     => fec5_data_from_deinterleaver_s,
            fec5_fec_o                      => fec5_fec_from_deinterleaver_s,
            fec12_data_o                    => fec12_data_from_deinterleaver_s,
            fec12_fec_o                     => fec12_fec_from_deinterleaver_s,

            -- Control
            datarate_select_i               => uplinkSelectDataRate_i,
            bypass                          => uplinkBypassInterleaver_i
       );  
    
    upLinkDecoder_inst: upLinkDecoder
       generic map(
            DATARATE                        => DATARATE,
            FEC                             => FEC
       )
       port map (    
            uplinkClk_i                     => uplinkClk_i,
            uplinkClkInEn_i                 => uplinkClkInEn_i,
            uplinkClkOutEn_i                => uplinkClkOutEn_s,
           
            -- Data
            fec5_data_i                     => fec5_data_from_deinterleaver_s,
            fec5_fec_i                      => fec5_fec_from_deinterleaver_s,
            fec12_data_i                    => fec12_data_from_deinterleaver_s,
            fec12_fec_i                     => fec12_fec_from_deinterleaver_s,

            fec5_data_o                     => fec5_data_from_decoder_s,
            fec12_data_o                    => fec12_data_from_decoder_s,
            
            fec5_correction_pattern_o       => fec5_correction_s,
            fec12_correction_pattern_o      => fec12_correction_s,
            
            -- Control
            datarate_select_i               => uplinkSelectDataRate_i,
            bypass                          => uplinkBypassFECEncoder_i
       );
       
    upLinkDescramlber_inst: upLinkDescramlber
       generic map(
            DATARATE                        => DATARATE,
            FEC                             => FEC
       )
       port map(
            -- Clock and reset
            clk_i                           => uplinkClk_i,
            clkEn_i                         => uplinkClkOutEn_s,
            
            reset_i                         => uplinkRst_i,
            
            -- Data
            fec5_data_i                     => fec5_data_from_decoder_s,
            fec12_data_i                    => fec12_data_from_decoder_s,

            fec5_data_o                     => fec5_data_from_descrambler_s,
            fec12_data_o                    => fec12_data_from_descrambler_s,

            -- Control
            bypass                          => uplinkBypassScrambler_i
       );

    -- Routes data depending on the datarate and FEC configurations
    uplinkUserData_10g24_s  <= (others => '0') when uplinkReady_1_s = '0' else
                               fec5_data_from_descrambler_s(229 downto 0) when (FEC = FEC5 or (FEC = DYNAMIC and uplinkSelectFEC_i = '0')) else
                               "0000000000000000000000000000" & fec12_data_from_descrambler_s(201 downto 0);
                         
    uplinkEcData_10g24_s    <= (others => '0') when uplinkReady_1_s = '0' else
                               fec5_data_from_descrambler_s(231 downto 230) when (FEC = FEC5 or (FEC = DYNAMIC and uplinkSelectFEC_i = '0')) else
                               fec12_data_from_descrambler_s(203 downto 202);
                         
    uplinkIcData_10g24_s    <= (others => '0') when uplinkReady_1_s = '0' else    
                               fec5_data_from_descrambler_s(233 downto 232) when (FEC = FEC5 or (FEC = DYNAMIC and uplinkSelectFEC_i = '0')) else
                               fec12_data_from_descrambler_s(205 downto 204);

    uplinkUserData_5g12_s   <= (others => '0') when uplinkReady_1_s = '0' else
                               x"00000000000000000000000000000" & "00" & fec5_data_from_descrambler_s(111 downto 0) when (FEC = FEC5 or (FEC = DYNAMIC and uplinkSelectFEC_i = '0')) else
                               x"000000000000000000000000000000000" & fec12_data_from_descrambler_s(97 downto 0);
                         
    uplinkEcData_5g12_s     <= (others => '0') when uplinkReady_1_s = '0' else
                               fec5_data_from_descrambler_s(113 downto 112) when (FEC = FEC5 or (FEC = DYNAMIC and uplinkSelectFEC_i = '0')) else
                               fec12_data_from_descrambler_s(99 downto 98);
                         
    uplinkIcData_5g12_s     <= (others => '0') when uplinkReady_1_s = '0' else    
                               fec5_data_from_descrambler_s(115 downto 114) when (FEC = FEC5 or (FEC = DYNAMIC and uplinkSelectFEC_i = '0')) else
                               fec12_data_from_descrambler_s(101 downto 100);
    
    
    uplinkUserData_o        <= uplinkUserData_10g24_s when (DATARATE = DATARATE_10G24 or (DATARATE = DYNAMIC and uplinkSelectDataRate_i = '1')) else
                               uplinkUserData_5g12_s;
                               
    uplinkEcData_o          <= uplinkEcData_10g24_s when (DATARATE = DATARATE_10G24 or (DATARATE = DYNAMIC and uplinkSelectDataRate_i = '1')) else
                               uplinkEcData_5g12_s;
                               
    uplinkIcData_o          <= uplinkIcData_10g24_s when (DATARATE = DATARATE_10G24 or (DATARATE = DYNAMIC and uplinkSelectDataRate_i = '1')) else
                               uplinkIcData_5g12_s;                               
                               
    uplinkCorrData_10g24_s  <= (others => '0') when uplinkReady_1_s = '0' else
                               fec5_correction_s(229 downto 0) when (FEC = FEC5 or (FEC = DYNAMIC and uplinkSelectFEC_i = '0')) else
                               "0000000000000000000000000000" & fec12_correction_s(201 downto 0);
                         
    uplinkCorrEc_10g24_s    <= (others => '0') when uplinkReady_1_s = '0' else
                               fec5_correction_s(231 downto 230) when (FEC = FEC5 or (FEC = DYNAMIC and uplinkSelectFEC_i = '0')) else
                               fec12_correction_s(203 downto 202);
                         
    uplinkCorrIc_10g24_s    <= (others => '0') when uplinkReady_1_s = '0' else    
                               fec5_correction_s(233 downto 232) when (FEC = FEC5 or (FEC = DYNAMIC and uplinkSelectFEC_i = '0')) else
                               fec12_correction_s(205 downto 204);

    uplinkCorrData_5g12_s   <= (others => '0') when uplinkReady_1_s = '0' else
                               x"00000000000000000000000000000" & "00" & fec5_correction_s(111 downto 0) when (FEC = FEC5 or (FEC = DYNAMIC and uplinkSelectFEC_i = '0')) else
                               x"000000000000000000000000000000000" & fec12_correction_s(97 downto 0);
                         
    uplinkCorrEc_5g12_s     <= (others => '0') when uplinkReady_1_s = '0' else
                               fec5_correction_s(113 downto 112) when (FEC = FEC5 or (FEC = DYNAMIC and uplinkSelectFEC_i = '0')) else
                               fec12_correction_s(99 downto 98);
                         
    uplinkCorrIc_5g12_s     <= (others => '0') when uplinkReady_1_s = '0' else    
                               fec5_correction_s(115 downto 114) when (FEC = FEC5 or (FEC = DYNAMIC and uplinkSelectFEC_i = '0')) else
                               fec12_correction_s(101 downto 100);    
    
    uplinkDataCorrected_o   <= uplinkCorrData_10g24_s when (DATARATE = DATARATE_10G24 or (DATARATE = DYNAMIC and uplinkSelectDataRate_i = '1')) else
                               uplinkCorrData_5g12_s;
                               
    uplinkEcCorrected_o     <= uplinkCorrEc_10g24_s when (DATARATE = DATARATE_10G24 or (DATARATE = DYNAMIC and uplinkSelectDataRate_i = '1')) else
                               uplinkCorrEc_5g12_s;
                               
    uplinkIcCorrected_o     <= uplinkCorrIc_10g24_s when (DATARATE = DATARATE_10G24 or (DATARATE = DYNAMIC and uplinkSelectDataRate_i = '1')) else
                               uplinkCorrIc_5g12_s;
                               
    --! Generate ready signal from the reset (2 clock cycle delay)
    readySync_proc: process(uplinkClk_i, uplinkRst_i)
    begin
    
        if uplinkRst_i = '1' then
            uplinkReady_1_s  <= '0';
            uplinkReady_0_s  <= '0';
            uplinkReady_o    <= '0';
            
        elsif rising_edge(uplinkClk_i) then
        
            if uplinkClkOutEn_s = '1' then
                uplinkReady_o    <= uplinkReady_1_s;
                uplinkReady_1_s  <= uplinkReady_0_s;
                uplinkReady_0_s  <= '1';            
            end if;
            
        end if;
    end process;
    
END behabioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--