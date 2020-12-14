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

--! @brief upLinkDecoder - Uplink FEC decoder
--! @details Decodes the received data and corrects error when possible. The decoding
--! is based on the N=31, K=29 and SymbWidth=5 or the N=15, K=13 and SymbWidth=4 
--! implementation of the Reed-Solomon scheme depending on the configuration (FEC5 or FEC12).
ENTITY upLinkDecoder IS
   GENERIC(
        DATARATE                        : integer range 0 to 2 := DYNAMIC;        --! Datarate selection can be: DYNAMIC, DATARATE_10G24 or DATARATE_5G12
        FEC                             : integer range 0 to 2 := DYNAMIC         --! FEC selection can be: DYNAMIC, FEC5 or FEC12
   );
   PORT (    
        -- Clock
        uplinkClk_i                     : in  std_logic;
        uplinkClkInEn_i                 : in  std_logic;
        uplinkClkOutEn_i                : in  std_logic;
        
        -- Data
        fec5_data_i                     : in  std_logic_vector(233 downto 0);     --! Data input from de-interleaver for FEC5 decoding (redundant on upper/lower part of the bus @5.12Gbps)
        fec5_fec_i                      : in  std_logic_vector(19 downto 0);      --! FEC input from de-interleaver for FEC5 decoding (redundant on upper/lower part of the bus @5.12Gbps)
        fec12_data_i                    : in  std_logic_vector(205 downto 0);     --! Data input from de-interleaver for FEC12 decoding (redundant on upper/lower part of the bus @5.12Gbps)
        fec12_fec_i                     : in  std_logic_vector(47 downto 0);      --! FEC input from de-interleaver for FEC12 decoding (redundant on upper/lower part of the bus @5.12Gbps)

        fec5_data_o                     : out std_logic_vector(233 downto 0);     --! Data output for FEC5 decoding (redundant on upper/lower part of the bus @5.12Gbps)
        fec12_data_o                    : out std_logic_vector(205 downto 0);     --! Data output for FEC12 decoding (redundant on upper/lower part of the bus @5.12Gbps)
        
        fec5_correction_pattern_o       : out std_logic_vector(233 downto 0);
        fec12_correction_pattern_o      : out std_logic_vector(205 downto 0);
        
        -- Control
        datarate_select_i               : in  std_logic;                          --! Datarate selection (only in DYNAMIC mode) -> '0': 5.12Gbps / '1': 10.24Gbps
        bypass                          : in  std_logic                           --! Bypass uplink FEC (test purpose only)
   );  
END upLinkDecoder;

--! @brief upLinkDecoder - Uplink FEC decoder
--! @details The upLinkDecoder module instantiates the Reed-Solomon N31K29 and N15K13
--! modules to correct errors for both FEC5 and FEC12 configuration. Only in dynamic mode,
--! the 2 types of decoders are instantated. Otherwise, only the one from the selected
--! mode is implemented. Additionnally, only the required logic is used when the DATARATE
--! is configured to run at 5.12gbps. In dynamic mode and 5.12g datarate, both the upper (255 downto 128)
--! and the lower (127 downto 0) frames are decoded and set in output. It means that the output bus
--! is also divided in two parts where the lower one is for the lower part the received bus and
--! vice-versa.
ARCHITECTURE behavioral of upLinkDecoder IS
    
    
    -- N31K29 decoder component
    COMPONENT rs_decoder_N31K29
       GENERIC (
            N								: integer := 31;
            K 								: integer := 29;
            SYMB_BITWIDTH					: integer := 5
       );
       PORT (
            payloadData_i                   : in  std_logic_vector((K*SYMB_BITWIDTH)-1 downto 0);
            fecData_i                       : in  std_logic_vector(((N-K)*SYMB_BITWIDTH)-1 downto 0);
            
            data_o                          : out std_logic_vector((K*SYMB_BITWIDTH)-1 downto 0)
       );
    END COMPONENT;
    
    -- N15K13 decoder component
    COMPONENT rs_decoder_N15K13
       GENERIC (
            N								: integer := 15;
            K 								: integer := 13;
            SYMB_BITWIDTH					: integer := 4
       );
       PORT (
            payloadData_i                   : in  std_logic_vector((K*SYMB_BITWIDTH)-1 downto 0);
            fecData_i                       : in  std_logic_vector(((N-K)*SYMB_BITWIDTH)-1 downto 0);
            
            data_o                          : out std_logic_vector((K*SYMB_BITWIDTH)-1 downto 0)
       );
    END COMPONENT;
    
    -- Signals
    signal fec5_encoded_code0_s           : std_logic_vector(144 downto 0);   --! FEC5 encoded data (code 0)
    signal fec5_encoded_code1_s           : std_logic_vector(144 downto 0);   --! FEC5 encoded data (code 1)
    
    signal fec5_decoded_code0_s           : std_logic_vector(144 downto 0);   --! FEC5 decoded data (code 0)
    signal fec5_decoded_code1_s           : std_logic_vector(144 downto 0);   --! FEC5 decoded data (code 1)
    
    signal fec12_encoded_code0_s          : std_logic_vector(51 downto 0);    --! FEC12 encoded data (code 0)
    signal fec12_encoded_code1_s          : std_logic_vector(51 downto 0);    --! FEC12 encoded data (code 1)
    signal fec12_encoded_code2_s          : std_logic_vector(51 downto 0);    --! FEC12 encoded data (code 2)
    signal fec12_encoded_code3_s          : std_logic_vector(51 downto 0);    --! FEC12 encoded data (code 3)
    signal fec12_encoded_code4_s          : std_logic_vector(51 downto 0);    --! FEC12 encoded data (code 4)
    signal fec12_encoded_code5_s          : std_logic_vector(51 downto 0);    --! FEC12 encoded data (code 5)
    
    signal fec12_decoded_code0_s          : std_logic_vector(51 downto 0);    --! FEC12 decoded data (code 0)
    signal fec12_decoded_code1_s          : std_logic_vector(51 downto 0);    --! FEC12 decoded data (code 1)
    signal fec12_decoded_code2_s          : std_logic_vector(51 downto 0);    --! FEC12 decoded data (code 2)
    signal fec12_decoded_code3_s          : std_logic_vector(51 downto 0);    --! FEC12 decoded data (code 3)
    signal fec12_decoded_code4_s          : std_logic_vector(51 downto 0);    --! FEC12 decoded data (code 4)
    signal fec12_decoded_code5_s          : std_logic_vector(51 downto 0);    --! FEC12 decoded data (code 5)
    
    signal fec5_data_s                    : std_logic_vector(233 downto 0);     --! Data output for FEC5 decoding (redundant on upper/lower part of the bus @5.12Gbps)
    signal fec5_toenc_data_s              : std_logic_vector(233 downto 0);     --! Data output for FEC5 decoding (redundant on upper/lower part of the bus @5.12Gbps)
    signal fec5_data_output_synch_s       : std_logic_vector(233 downto 0);     --! Data output for FEC5 decoding (redundant on upper/lower part of the bus @5.12Gbps)
    signal fec5_data_input_synch_s        : std_logic_vector(233 downto 0);     --! Data output for FEC5 decoding (redundant on upper/lower part of the bus @5.12Gbps)
    signal fec12_data_s                   : std_logic_vector(205 downto 0);     --! Data output for FEC12 decoding (redundant on upper/lower part of the bus @5.12Gbps)
    signal fec12_toenc_data_s              : std_logic_vector(205 downto 0);     --! Data output for FEC12 decoding (redundant on upper/lower part of the bus @5.12Gbps)
    signal fec12_data_output_synch_s      : std_logic_vector(205 downto 0);     --! Data output for FEC12 decoding (redundant on upper/lower part of the bus @5.12Gbps)
    signal fec12_data_input_synch_s       : std_logic_vector(205 downto 0);     --! Data output for FEC12 decoding (redundant on upper/lower part of the bus @5.12Gbps)

    signal uplinkClkInEn_pipe_s           : std_logic;
    
BEGIN                 --========####   Architecture Body   ####========-- 
    
    -- FEC5 decoders
    fec5_dec_gen: if FEC = FEC5 or FEC = DYNAMIC generate
    
        fec5_encoded_code0_s   <= "00000000000000000000000000" & 
                                  fec5_data_i(233 downto 232) & 
                                  fec5_data_i(116 downto 0)       when (DATARATE = DATARATE_10G24) or (DATARATE = DYNAMIC and datarate_select_i = '1') else
                                  "00000000000000000000000000000" & 
                                  fec5_data_i(115 downto 0);
        
        rs_decoder_N31K29_c0_inst: rs_decoder_N31K29
            port map (
                payloadData_i        => fec5_encoded_code0_s,                
                fecData_i            => fec5_fec_i(9 downto 0),
                
                data_o               => fec5_decoded_code0_s 
            );
        
        dec10g24_fec5_gen: if DATARATE = DATARATE_10G24 or DATARATE = DYNAMIC generate
        
            fec5_encoded_code1_s   <= "000000000000000000000000000000" & fec5_data_i(231 downto 117) when (DATARATE = DATARATE_10G24) or (DATARATE = DYNAMIC and datarate_select_i = '1') else
                                      "00000000000000000000000000000" & fec5_data_i(231 downto 116);
            
            rs_decoder_N31K29_c1_inst: rs_decoder_N31K29
                port map (
                    payloadData_i        => fec5_encoded_code1_s,                
                    fecData_i            => fec5_fec_i(19 downto 10),
                    
                    data_o               => fec5_decoded_code1_s 
                );
                
        end generate;
        
        dec5g12_fec5_gen: if DATARATE = DATARATE_5G12 generate
            fec5_decoded_code1_s <= (others =>  '0');
        end generate;
        
    end generate;
    
    -- FEC12 decoders
    fec12_dec_gen: if FEC = FEC12 or FEC = DYNAMIC generate

        fec12_encoded_code0_s   <= "0000000000000000" & fec12_data_i(135 downto 134) & fec12_data_i(33 downto 0) when (DATARATE = DATARATE_10G24) or (DATARATE = DYNAMIC and datarate_select_i = '1') else
                                   "0000000000000000" & fec12_data_i(67 downto 66) & fec12_data_i(33 downto 0);
                                   
        fec12_encoded_code1_s   <= "0000000000000000" & fec12_data_i(169 downto 168) & fec12_data_i(67 downto 34) when (DATARATE = DATARATE_10G24) or (DATARATE = DYNAMIC and datarate_select_i = '1') else
                                   "000000000000000000" & fec12_data_i(101 downto 100) & fec12_data_i(65 downto 34);
                                   
        fec12_encoded_code2_s   <= "0000000000000000" & fec12_data_i(203 downto 202) & fec12_data_i(101 downto 68) when (DATARATE = DATARATE_10G24) or (DATARATE = DYNAMIC and datarate_select_i = '1') else
                                   "00000000000000000000" & fec12_data_i(99 downto 68);
                
        rs_decoder_N15K13_c0_inst: rs_decoder_N15K13
            port map (
                payloadData_i        => fec12_encoded_code0_s,                
                fecData_i            => fec12_fec_i(7 downto 0),
                
                data_o               => fec12_decoded_code0_s 
            );
                
        rs_decoder_N15K13_c1_inst: rs_decoder_N15K13
            port map (
                payloadData_i        => fec12_encoded_code1_s,                
                fecData_i            => fec12_fec_i(15 downto 8),
                
                data_o               => fec12_decoded_code1_s 
            );
                
        rs_decoder_N15K13_c2_inst: rs_decoder_N15K13
            port map (
                payloadData_i        => fec12_encoded_code2_s,                
                fecData_i            => fec12_fec_i(23 downto 16),
                
                data_o               => fec12_decoded_code2_s 
            );

        dec5g12_fec12_gen: if DATARATE = DATARATE_5G12 generate
            fec12_decoded_code3_s <= (others => '0');
            fec12_decoded_code4_s <= (others => '0');
            fec12_decoded_code5_s <= (others => '0');            
        end generate;
        
        dec10g24_fec12_gen: if DATARATE = DATARATE_10G24 or DATARATE = DYNAMIC generate
        
            fec12_encoded_code3_s   <= "000000000000000000" & fec12_data_i(205 downto 204) & fec12_data_i(133 downto 102)  when (DATARATE = DATARATE_10G24) or (DATARATE = DYNAMIC and datarate_select_i = '1') else
                                       "0000000000000000" & fec12_data_i(169 downto 168) & fec12_data_i(135 downto 102);
                                       
            fec12_encoded_code4_s   <= "00000000000000000000" & fec12_data_i(167 downto 136)  when (DATARATE = DATARATE_10G24) or (DATARATE = DYNAMIC and datarate_select_i = '1') else
                                       "000000000000000000" & fec12_data_i(203 downto 202) & fec12_data_i(167 downto 136);
                                        
            fec12_encoded_code5_s   <= "00000000000000000000" & fec12_data_i(201 downto 170)  when (DATARATE = DATARATE_10G24) or (DATARATE = DYNAMIC and datarate_select_i = '1') else
                                       "00000000000000000000" & fec12_data_i(201 downto 170);

            rs_decoder_N15K13_c3_inst: rs_decoder_N15K13
                port map (
                    payloadData_i        => fec12_encoded_code3_s,                
                    fecData_i            => fec12_fec_i(31 downto 24),
                    
                    data_o               => fec12_decoded_code3_s 
                );
                    
            rs_decoder_N15K13_c4_inst: rs_decoder_N15K13
                port map (
                    payloadData_i        => fec12_encoded_code4_s,                
                    fecData_i            => fec12_fec_i(39 downto 32),
                    
                    data_o               => fec12_decoded_code4_s 
                );
                    
            rs_decoder_N15K13_c5_inst: rs_decoder_N15K13
                port map (
                    payloadData_i        => fec12_encoded_code5_s,                
                    fecData_i            => fec12_fec_i(47 downto 40),
                    
                    data_o               => fec12_decoded_code5_s 
                );
        end generate;
        
    end generate;
    
    -- If FEC5 is disabled, force value to 0
    fec5_dec_dis_gen: if FEC = FEC12 generate
        fec5_decoded_code0_s <= (others => '0');
        fec5_decoded_code1_s <= (others => '0');
    end generate;

    -- If FEC12 is disabled, force value to 0
    fec12_dec_dis_gen: if FEC = FEC5 generate
        fec12_decoded_code0_s <= (others => '0');
        fec12_decoded_code1_s <= (others => '0');
        fec12_decoded_code2_s <= (others => '0');
        fec12_decoded_code3_s <= (others => '0');
        fec12_decoded_code4_s <= (others => '0');
        fec12_decoded_code5_s <= (others => '0');
    end generate;
    
    process(uplinkClk_i)
    begin
        if rising_edge(uplinkClk_i) then
            if uplinkClkOutEn_i = '1' then
                fec5_data_input_synch_s    <= fec5_toenc_data_s;
                fec12_data_input_synch_s   <= fec12_toenc_data_s;
                fec5_correction_pattern_o  <= fec5_toenc_data_s xor fec5_data_s;
                fec12_correction_pattern_o <= fec12_toenc_data_s xor fec12_data_s;
            end if;
        end if;
    end process;
    
--    process(uplinkClk_i)
--    begin
--        if rising_edge(uplinkClk_i) then
--            uplinkClkInEn_pipe_s <= uplinkClkInEn_i;
--            if uplinkClkInEn_pipe_s = '1' then
--            end if;
--        end if;
--    end process;
    
    
    fec5_data_o    <= fec5_data_s;
    fec12_data_o   <= fec12_data_s;
    
    fec5_data_s    <= fec5_data_i                              when bypass = '1' else
                      fec5_decoded_code0_s(118 downto 117)     & 
                      fec5_decoded_code1_s(114 downto 0)       & 
                      fec5_decoded_code0_s(116 downto 0)       when (DATARATE = DYNAMIC and datarate_select_i = '1') or DATARATE = DATARATE_10G24 else
                      '0' & fec5_decoded_code1_s(115 downto 0) & 
                      '0' & fec5_decoded_code0_s(115 downto 0);
        
    fec12_data_s   <= fec12_data_i                        when bypass = '1' else
                      fec12_decoded_code3_s(33 downto 32) & 
                      fec12_decoded_code2_s(35 downto 34) & 
                      fec12_decoded_code5_s(31 downto 0)  &
                      fec12_decoded_code1_s(35 downto 34) &
                      fec12_decoded_code4_s(31 downto 0)  &
                      fec12_decoded_code0_s(35 downto 34) &
                      fec12_decoded_code3_s(31 downto 0)  &
                      fec12_decoded_code2_s(33 downto 0)  &
                      fec12_decoded_code1_s(33 downto 0)  &
                      fec12_decoded_code0_s(33 downto 0)  when (DATARATE = DYNAMIC and datarate_select_i = '1') or DATARATE = DATARATE_10G24 else
                      '0'                                 & 
                      fec12_decoded_code4_s(33 downto 32) & 
                      fec12_decoded_code5_s(31 downto 0)  & 
                      fec12_decoded_code3_s(35 downto 34) & 
                      fec12_decoded_code4_s(31 downto 0)  & 
                      fec12_decoded_code3_s(33 downto 0)  &
                      '0'                                 & 
                      fec12_decoded_code1_s(33 downto 32) & 
                      fec12_decoded_code2_s(31 downto 0)  & 
                      fec12_decoded_code0_s(35 downto 34) & 
                      fec12_decoded_code1_s(31 downto 0)  & 
                      fec12_decoded_code0_s(33 downto 0);
                      
    fec5_toenc_data_s <= fec5_data_i                              when bypass = '1' else
                      fec5_encoded_code0_s(118 downto 117)     & 
                      fec5_encoded_code1_s(114 downto 0)       & 
                      fec5_encoded_code0_s(116 downto 0)       when (DATARATE = DYNAMIC and datarate_select_i = '1') or DATARATE = DATARATE_10G24 else
                      '0' & fec5_encoded_code1_s(115 downto 0) & 
                      '0' & fec5_encoded_code0_s(115 downto 0);
        
    fec12_toenc_data_s <= fec12_data_i                        when bypass = '1' else
                      fec12_encoded_code3_s(33 downto 32) & 
                      fec12_encoded_code2_s(35 downto 34) & 
                      fec12_encoded_code5_s(31 downto 0)  &
                      fec12_encoded_code1_s(35 downto 34) &
                      fec12_encoded_code4_s(31 downto 0)  &
                      fec12_encoded_code0_s(35 downto 34) &
                      fec12_encoded_code3_s(31 downto 0)  &
                      fec12_encoded_code2_s(33 downto 0)  &
                      fec12_encoded_code1_s(33 downto 0)  &
                      fec12_encoded_code0_s(33 downto 0)  when (DATARATE = DYNAMIC and datarate_select_i = '1') or DATARATE = DATARATE_10G24 else
                      '0'                                 & 
                      fec12_encoded_code4_s(33 downto 32) & 
                      fec12_encoded_code5_s(31 downto 0)  & 
                      fec12_encoded_code3_s(35 downto 34) & 
                      fec12_encoded_code4_s(31 downto 0)  & 
                      fec12_encoded_code3_s(33 downto 0)  &
                      '0'                                 & 
                      fec12_encoded_code1_s(33 downto 32) & 
                      fec12_encoded_code2_s(31 downto 0)  & 
                      fec12_encoded_code0_s(35 downto 34) & 
                      fec12_encoded_code1_s(31 downto 0)  & 
                      fec12_encoded_code0_s(33 downto 0);
                      
END behavioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--