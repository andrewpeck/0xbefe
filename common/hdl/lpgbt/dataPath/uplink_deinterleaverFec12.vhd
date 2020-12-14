-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 1.0
--! @brief LpGBT-FPGA Uplink data de-interleaver for FEC12 configuration
-------------------------------------------------------

--! Include the IEEE VHDL standard library
library ieee;
use ieee.std_logic_1164.all;

--! Include the LpGBT-FPGA specific package
use work.lpgbtfpga_package.all;

--! @brief upLinkDeinterleaver_fec12 - Uplink data de-interleaver for FEC12 configuration
--! @details De-interleaves the data to extract the encoded message from
--! the received frame. Interleaving data improves the decoding efficiency 
--! by increasing the number of consecutive bits with errors that can be
--! corrected.
ENTITY upLinkDeinterleaver_fec12 IS
   GENERIC(
        DATARATE                        : integer range 0 to 2 := DYNAMIC       --! Datarate selection can be: DYNAMIC, DATARATE_10G24 or DATARATE_5G12
   );                                                                           
   PORT (                                                                       
        -- Data                                                                 
        data_i                          : in  std_logic_vector(255 downto 0);   --! Input frame from the Rx gearbox (data shall be duplicated in upper/lower part of the frame @5.12Gbps)  
                                                                                
        data_o                          : out std_logic_vector(205 downto 0);   --! Output data for FEC12 encoding (data is duplicated in upper/lower part of the frame @5.12Gbps)
        fec_o                           : out std_logic_vector(47 downto 0);    --! Output FEC for FEC12 encoding (data is duplicated in upper/lower part of the frame @5.12Gbps)
                                                                                
        -- Control                                                              
        datarate_select_i               : in  std_logic;                        --! Datarate selection (only in DYNAMIC mode) -> '0': 5.12Gbps / '1': 10.24Gbps
        bypass                          : in  std_logic                         --! Bypass uplink interleaver (test purpose only)
   );
END upLinkDeinterleaver_fec12;

--! @brief upLinkDeinterleaver_fec12 - Uplink data de-interleaver for FEC12 configuration
--! @details The upLinkDeinterleaver_fec12 routes the data from the MGT to recover
--! the message (symbols) and FEC. FEC12 de-interleaving depends on the datarate:
--!     * *10.24Gbps*: C0/C1/C2/C3/C4/C5/C0/C1... Allows correcting 6 consecutive symbols
--!     * *5.12Gbps*: C0/C1/C2/C0/C1/C2/C0... Allows correcting 3 consecutive symbols
ARCHITECTURE behavioral of upLinkDeinterleaver_fec12 IS
    
    signal data_5g12_s        : std_logic_vector(205 downto 0);   --! Data output for 5.12Gbps configuration
    signal fec_5g12_s         : std_logic_vector(47 downto 0);    --! FEC output for 5.12Gbps configuration

    signal data_10g24_s        : std_logic_vector(205 downto 0);  --! Data output for 10.24Gbps configuration
    signal fec_10g24_s         : std_logic_vector(47 downto 0);   --! FEC output for 10.24Gbps configuration
    
BEGIN                 --========####   Architecture Body   ####========-- 
    
    -- Logic
    fec12_5g12: if DATARATE = DATARATE_5G12 or DATARATE = DYNAMIC generate
    
        -- Code 0
        data_5g12_s(67 downto 66)   <= data_i(123 downto 122);
        data_5g12_s(33 downto 0)    <= data_i(121 downto 120) & 
                                       data_i(111 downto 108) &
                                       data_i(99 downto 96)   &
                                       data_i(87 downto 84)   &
                                       data_i(75 downto 72)   &
                                       data_i(63 downto 60)   &
                                       data_i(51 downto 48)   &
                                       data_i(39 downto 36)   &
                                       data_i(27 downto 24);

        -- Code 1
        data_5g12_s(101 downto 100) <= data_i(125 downto 124);
        data_5g12_s(65 downto 34)   <= data_i(115 downto 112) & 
                                       data_i(103 downto 100) &
                                       data_i(91 downto 88)   &
                                       data_i(79 downto 76)   &
                                       data_i(67 downto 64)   &
                                       data_i(55 downto 52)   &
                                       data_i(43 downto 40)   &
                                       data_i(31 downto 28);

        -- Code 2
        data_5g12_s(99 downto 68)   <= data_i(119 downto 116) & 
                                       data_i(107 downto 104) &
                                       data_i(95 downto 92)   &
                                       data_i(83 downto 80)   &
                                       data_i(71 downto 68)   &
                                       data_i(59 downto 56)   &
                                       data_i(47 downto 44)   &
                                       data_i(35 downto 32);
        
        -- "Code 3, 4 & 5" : Duplicates code 0, 1 and 2 with second phase
        data_5g12_s(169 downto 168)   <= data_i(251 downto 250);     -- Code 3
        data_5g12_s(135 downto 102)   <= data_i(249 downto 248) & 
                                         data_i(239 downto 236) &
                                         data_i(227 downto 224) &
                                         data_i(215 downto 212) &
                                         data_i(203 downto 200) &
                                         data_i(191 downto 188) &
                                         data_i(179 downto 176) &
                                         data_i(167 downto 164) &
                                         data_i(155 downto 152);
        
        data_5g12_s(203 downto 202)   <= data_i(253 downto 252);     -- Code 4
        data_5g12_s(167 downto 136)   <= data_i(243 downto 240) & 
                                         data_i(231 downto 228) &
                                         data_i(219 downto 216) &
                                         data_i(207 downto 204) &
                                         data_i(195 downto 192) &
                                         data_i(183 downto 180) &
                                         data_i(171 downto 168) &
                                         data_i(159 downto 156);

        data_5g12_s(201 downto 170)   <= data_i(247 downto 244) &    -- Code 5
                                         data_i(235 downto 232) &
                                         data_i(223 downto 220) &
                                         data_i(211 downto 208) &
                                         data_i(199 downto 196) &
                                         data_i(187 downto 184) &
                                         data_i(175 downto 172) &
                                         data_i(163 downto 160);

        -- FEC 0, 1 & 2
        fec_5g12_s(23 downto 0)     <= data_i(23 downto 20)   &
                                       data_i(11 downto 8)    &
                                       data_i(19 downto 16)   &
                                       data_i(7 downto 4)     &
                                       data_i(15 downto 12)   &
                                       data_i(3 downto 0);

        -- FEC 3, 4 & 5: Duplicates FEC 0, 1 and 2 with second phase
        fec_5g12_s(47 downto 24)    <= data_i(151 downto 148) &
                                       data_i(139 downto 136) &
                                       data_i(147 downto 144) &
                                       data_i(135 downto 132) &
                                       data_i(143 downto 140) &
                                       data_i(131 downto 128);

    end generate;
    
    fec12_10g24: if DATARATE = DATARATE_10G24 or DATARATE = DYNAMIC generate
    
        
        -- Code 0
        data_10g24_s(135 downto 134) <= data_i(243 downto 242);
        data_10g24_s(33 downto 0)    <= data_i(241 downto 240) &
                                        data_i(219 downto 216) & 
                                        data_i(195 downto 192) &
                                        data_i(171 downto 168) &
                                        data_i(147 downto 144) &
                                        data_i(123 downto 120) &
                                        data_i(99 downto 96)   &
                                        data_i(75 downto 72)   &
                                        data_i(51 downto 48);

        -- Code 1
        data_10g24_s(169 downto 168) <= data_i(247 downto 246);
        data_10g24_s(67 downto 34)   <= data_i(245 downto 244) &
                                        data_i(223 downto 220) & 
                                        data_i(199 downto 196) &
                                        data_i(175 downto 172) &
                                        data_i(151 downto 148) &
                                        data_i(127 downto 124) &
                                        data_i(103 downto 100) &
                                        data_i(79 downto 76)   &
                                        data_i(55 downto 52);

        -- Code 2
        data_10g24_s(203 downto 202) <= data_i(251 downto 250);
        data_10g24_s(101 downto 68)  <= data_i(249 downto 248) &
                                        data_i(227 downto 224) & 
                                        data_i(203 downto 200) &
                                        data_i(179 downto 176) &
                                        data_i(155 downto 152) &
                                        data_i(131 downto 128) &
                                        data_i(107 downto 104) &
                                        data_i(83 downto 80)   &
                                        data_i(59 downto 56);
        
        -- Code 3
        data_10g24_s(205 downto 204) <= data_i(253 downto 252);
        data_10g24_s(133 downto 102) <= data_i(231 downto 228) & 
                                        data_i(207 downto 204) &
                                        data_i(183 downto 180) &
                                        data_i(159 downto 156) &
                                        data_i(135 downto 132) &
                                        data_i(111 downto 108) &
                                        data_i(87 downto 84)   &
                                        data_i(63 downto 60);
        
        -- Code 4
        data_10g24_s(167 downto 136) <= data_i(235 downto 232) & 
                                        data_i(211 downto 208) &
                                        data_i(187 downto 184) &
                                        data_i(163 downto 160) &
                                        data_i(139 downto 136) &
                                        data_i(115 downto 112) &
                                        data_i(91 downto 88)   &
                                        data_i(67 downto 64);
        
        -- Code 5
        data_10g24_s(201 downto 170) <= data_i(239 downto 236) & 
                                        data_i(215 downto 212) &
                                        data_i(191 downto 188) &
                                        data_i(167 downto 164) &
                                        data_i(143 downto 140) &
                                        data_i(119 downto 116) &
                                        data_i(95 downto 92)   &
                                        data_i(71 downto 68);
        
        fec_10g24_s                  <= data_i(47 downto 44)   &
                                        data_i(23 downto 20)   &
                                        data_i(43 downto 40)   &
                                        data_i(19 downto 16)   &
                                        data_i(39 downto 36)   &
                                        data_i(15 downto 12)   &
                                        data_i(35 downto 32)   &
                                        data_i(11 downto 8)    &
                                        data_i(31 downto 28)   &
                                        data_i(7 downto 4)     &
                                        data_i(27 downto 24)   &
                                        data_i(3 downto 0);
        
    end generate;
    
    -- Mux
    data_o   <= data_i(253 downto 48) when bypass = '1' and (DATARATE = DATARATE_10G24 or (DATARATE = DYNAMIC and datarate_select_i = '1')) else
                '0' & data_i (253 downto 152) & '0' & data_i(125 downto 24) when bypass = '1' else
                data_5g12_s when DATARATE = DATARATE_5G12 or (DATARATE = DYNAMIC and datarate_select_i = '0') else
                data_10g24_s;

    fec_o    <= data_i(47 downto 0) when bypass = '1' and (DATARATE = DATARATE_10G24 or (DATARATE = DYNAMIC and datarate_select_i = '1')) else
                data_i(151 downto 128) & data_i(23 downto 0) when bypass = '1' else
                fec_5g12_s when DATARATE = DATARATE_5G12 or (DATARATE = DYNAMIC and datarate_select_i = '0') else
                fec_10g24_s;
                
END behavioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--