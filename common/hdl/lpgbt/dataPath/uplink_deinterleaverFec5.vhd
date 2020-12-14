-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 1.0
--! @brief LpGBT-FPGA Uplink data de-interleaver for FEC5 configuration
-------------------------------------------------------

--! Include the IEEE VHDL standard library
library ieee;
use ieee.std_logic_1164.all;

--! Include the LpGBT-FPGA specific package
use work.lpgbtfpga_package.all;

--! @brief upLinkDeinterleaver_fec5 - Uplink data de-interleaver for FEC5 configuration
--! @details De-interleaves the data to extract the encoded message from
--! the received frame. Interleaving data improves the decoding efficiency
--! by increasing the number of consecutive bits with errors that can be
--! corrected.
ENTITY upLinkDeinterleaver_fec5 IS
   GENERIC(
        DATARATE                        : integer range 0 to 2 := DYNAMIC       --! Datarate selection can be: DYNAMIC, DATARATE_10G24 or DATARATE_5G12
   );
   PORT (
        -- Data
        data_i                          : in  std_logic_vector(255 downto 0);   --! Input frame from the Rx gearbox (data shall be duplicated in upper/lower part of the frame @5.12Gbps)

        data_o                          : out std_logic_vector(233 downto 0);   --! Output data for FEC5 encoding (data is duplicated in upper/lower part of the frame @5.12Gbps)
        fec_o                           : out std_logic_vector(19 downto 0);    --! Output FEC for FEC5 encoding (data is duplicated in upper/lower part of the frame @5.12Gbps)

        -- Control
        datarate_select_i               : in  std_logic;                        --! Datarate selection (only in DYNAMIC mode) -> '0': 5.12Gbps / '1': 10.24Gbps
        bypass                          : in  std_logic                         --! Bypass uplink interleaver (test purpose only)
   );
END upLinkDeinterleaver_fec5;

--! @brief upLinkDeinterleaver_fec5 - Uplink data de-interleaver for FEC5 configuration
--! @details The upLinkDeinterleaver_fec5 routes the data from the MGT to recover
--! the message (symbols) and FEC. FEC5 de-interleaving depends on the datarate:
--!     * *10.24Gbps*: C0/C1/C0/C1/... Allows correcting 2 consecutive symbols
--!     * *5.12Gbps*: No interleaving ... Allows correcting 1 consecutive symbols
ARCHITECTURE behavioral of upLinkDeinterleaver_fec5 IS

    signal data_5g12_s        : std_logic_vector(233 downto 0);     --! Data output for 5.12Gbps configuration
    signal fec_5g12_s         : std_logic_vector(19 downto 0);      --! FEC output for 5.12Gbps configuration

    signal data_10g24_s        : std_logic_vector(233 downto 0);    --! Data output for 10.24Gbps configuration
    signal fec_10g24_s         : std_logic_vector(19 downto 0);     --! FEC output for 10.24Gbps configuration

BEGIN                 --========####   Architecture Body   ####========--

    -- Logic
    fec5_5g12: if DATARATE = DATARATE_5G12 or DATARATE = DYNAMIC generate

        -- Code 0
        data_5g12_s(116)            <= '0';
        data_5g12_s(115 downto 0)   <= data_i(125 downto 10);
        fec_5g12_s(9 downto 0)      <= data_i(9 downto 0);

        -- Code 1 (Not used @5.12Gbps - then uses 2nd phase of data)
        data_5g12_s(233)            <= '0';
        data_5g12_s(232 downto 117) <= data_i(253 downto 138);
        fec_5g12_s(19 downto 10)    <= data_i(137 downto 128);

    end generate;

    fec5_10g24: if DATARATE = DATARATE_10G24 or DATARATE = DYNAMIC generate

        -- Code 0
        data_10g24_s(233 downto 232) <= data_i(253 downto 252);
        data_10g24_s(116 downto 0)   <= data_i(251 downto 250) &
                                        data_i(244 downto 240) &
                                        data_i(234 downto 230) &
                                        data_i(224 downto 220) &
                                        data_i(214 downto 210) &
                                        data_i(204 downto 200) &
                                        data_i(194 downto 190) &
                                        data_i(184 downto 180) &
                                        data_i(174 downto 170) &
                                        data_i(164 downto 160) &
                                        data_i(154 downto 150) &
                                        data_i(144 downto 140) &
                                        data_i(134 downto 130) &
                                        data_i(124 downto 120) &
                                        data_i(114 downto 110) &
                                        data_i(104 downto 100) &
                                        data_i(94 downto 90) &
                                        data_i(84 downto 80) &
                                        data_i(74 downto 70) &
                                        data_i(64 downto 60) &
                                        data_i(54 downto 50) &
                                        data_i(44 downto 40) &
                                        data_i(34 downto 30) &
                                        data_i(24 downto 20);

        fec_10g24_s(9 downto 0)      <= data_i(14 downto 10) & data_i(4 downto 0);

        -- Code 1
        data_10g24_s(231 downto 117) <= data_i(249 downto 245) &
                                        data_i(239 downto 235) &
                                        data_i(229 downto 225) &
                                        data_i(219 downto 215) &
                                        data_i(209 downto 205) &
                                        data_i(199 downto 195) &
                                        data_i(189 downto 185) &
                                        data_i(179 downto 175) &
                                        data_i(169 downto 165) &
                                        data_i(159 downto 155) &
                                        data_i(149 downto 145) &
                                        data_i(139 downto 135) &
                                        data_i(129 downto 125) &
                                        data_i(119 downto 115) &
                                        data_i(109 downto 105) &
                                        data_i(99 downto 95) &
                                        data_i(89 downto 85) &
                                        data_i(79 downto 75) &
                                        data_i(69 downto 65) &
                                        data_i(59 downto 55) &
                                        data_i(49 downto 45) &
                                        data_i(39 downto 35) &
                                        data_i(29 downto 25);

        fec_10g24_s(19 downto 10)    <= data_i(19 downto 15) & data_i(9 downto 5);

    end generate;

    -- Mux
    data_o   <= data_i(253 downto 20) when bypass = '1' and (DATARATE = DATARATE_10G24 or (DATARATE = DYNAMIC and datarate_select_i = '1')) else
                data_5g12_s when bypass = '1' else
                data_5g12_s when DATARATE = DATARATE_5G12 or (DATARATE = DYNAMIC and datarate_select_i = '0') else
                data_10g24_s;

    fec_o    <= data_i(19 downto 0) when bypass = '1' and (DATARATE = DATARATE_10G24 or (DATARATE = DYNAMIC and datarate_select_i = '1')) else
                fec_5g12_s when bypass = '1' else
                fec_5g12_s when DATARATE = DATARATE_5G12 or (DATARATE = DYNAMIC and datarate_select_i = '0') else
                fec_10g24_s;

END behavioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--