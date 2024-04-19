------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: UCLA
-- Engineer: Joseph Carlson jecarlson30@gmail.com
-- 
-- Create Date:    2023-12-04
-- Module Name:    queso_link_decrypt
-- Description:    This module is used to decrypt each elink for the QUESO PRBS test 
------------------------------------------------------------------------------------------------------------------------------------------------------

-- ========================== VFAT mapping on ME0 GEB (Narrow) ==========================--
-- ====== OH0 (ASIAGO #1 on GEB) ======
-- OH_VFAT#    GEB_VFAT#    J#      DAQ_GBT#     GLOBAL_GBT#    DAQ_ELINK#
-- 0           17           6       1            1              6
-- 1           16           2       1            1              24
-- 2           9            5       1            1              11
-- 3           8            1       0            0              3
-- 4           1            3       0            0              27
-- 5           0            4       0            0              25

-- ====== OH1 (ASIAGO #2 on GEB) ======
-- OH_VFAT#    GEB_VFAT#    J#      DAQ_GBT#     GLOBAL_GBT#    DAQ_ELINK#      
-- 0           19           12      1            3              6              
-- 1           18           8       1            3              24       
-- 2           11           11      1            3              11       
-- 3           10           7       0            2              3        
-- 4           3            9       0            2              27       
-- 5           2            10      0            2              25       

-- ========================== VFAT mapping on ME0 GEB (Wide) ==========================--
-- ====== OH2 (ASIAGO #1 on GEB) ======
-- OH_VFAT#    GEB_VFAT#    J#      DAQ_GBT#     GLOBAL_GBT#   DAQ_ELINK#    
-- 0           21           6       1            5             6        
-- 1           20           2       1            5             24       
-- 2           13           5       1            5             11       
-- 3           4            1       0            4             3        
-- 4           5            3       0            4             27       
-- 5           12           4       0            4             25       

-- ====== OH3 (ASIAGO #2 on GEB) ======
-- OH_VFAT#    GEB_VFAT#    J#      DAQ_GBT#     GLOBAL_GBT#    DAQ_ELINK#    
-- 0           23           12      1            7              6        
-- 1           22           8       1            7              24       
-- 2           15           11      1            7              11       
-- 3           6            7       0            6              3        
-- 4           7            9       0            6              27       
-- 5           14           10      0            6              25       

--========================== OH0/OH1 GBT0 (fiber 1) master ==========================--
-- slow control to VFATs 0, 1 and 5 won't work till we have addressing since they share the same elink as VFATs 2, 3 and 4
-- RX from VFATs 3 and 5
--========================== OH0/OH1 GBT1 (fiber 2) slave ==========================--
-- TX normally unused, but can be connected to the master, in which case VFATs 1 and 5 will work, but 3 and 4 will stop working. Also VFAT 0 slow control will work, but VFAT 2 won't until we have addressing
-- RX from VFATs 0, 1, 2, 4 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common_pkg.all;
use work.gem_pkg.all;

entity queso_link_decrypt is
    generic(
        g_NUM_OF_OHs      : integer
    );
    port(
        -- clock
        clk_i                     : in  std_logic;
        -- links
        queso_rx_data_arr_i       : in  t_vfat3_queso_arr(g_NUM_OF_OHs - 1 downto 0);
        queso_data_arr_o : out t_vfat3_queso_arr(g_NUM_OF_OHs - 1 downto 0)
    );
end queso_link_decrypt;

architecture queso_link_decrypt_arch of queso_link_decrypt is
    
begin

    --inversions incorperated in ASIAGO config
    g_ohs : for i in 0 to g_NUM_OF_OHs - 1 generate
        process (clk_i)
        begin
            if rising_edge(clk_i) then
                --========================= QUESO TEST RX =========================--
                -- DAQ --
                queso_data_arr_o(i)(008) <= queso_rx_data_arr_i(i)(008) xor x"80"; -- VFAT00 pair 8 (GBT0 elink 25)
                queso_data_arr_o(i)(017) <= queso_rx_data_arr_i(i)(017) xor x"80"; -- VFAT01 pair 8 (GBT0 elink 27)
                queso_data_arr_o(i)(026) <= queso_rx_data_arr_i(i)(026) xor x"80"; -- VFAT02 pair 8 (GBT2 elink 25)
                queso_data_arr_o(i)(035) <= queso_rx_data_arr_i(i)(035) xor x"80"; -- VFAT03 pair 8 (GBT2 elink 27)
                queso_data_arr_o(i)(044) <= queso_rx_data_arr_i(i)(044) xor x"80"; -- VFAT04 pair 8 (GBT4 elink 03)
                queso_data_arr_o(i)(053) <= queso_rx_data_arr_i(i)(053) xor x"80"; -- VFAT05 pair 8 (GBT4 elink 27)
                queso_data_arr_o(i)(062) <= queso_rx_data_arr_i(i)(062) xor x"80"; -- VFAT06 pair 8 (GBT6 elink 03)
                queso_data_arr_o(i)(071) <= queso_rx_data_arr_i(i)(071) xor x"80"; -- VFAT07 pair 8 (GBT6 elink 27)
                queso_data_arr_o(i)(080) <= queso_rx_data_arr_i(i)(080) xor x"80"; -- VFAT08 pair 8 (GBT0 elink 03)
                queso_data_arr_o(i)(089) <= queso_rx_data_arr_i(i)(089) xor x"80"; -- VFAT09 pair 8 (GBT1 elink 11)
                queso_data_arr_o(i)(098) <= queso_rx_data_arr_i(i)(098) xor x"80"; -- VFAT10 pair 8 (GBT2 elink 03)
                queso_data_arr_o(i)(107) <= queso_rx_data_arr_i(i)(107) xor x"80"; -- VFAT11 pair 8 (GBT3 elink 11)
                queso_data_arr_o(i)(116) <= queso_rx_data_arr_i(i)(116) xor x"80"; -- VFAT12 pair 8 (GBT4 elink 25)
                queso_data_arr_o(i)(125) <= queso_rx_data_arr_i(i)(125) xor x"80"; -- VFAT13 pair 8 (GBT5 elink 11)
                queso_data_arr_o(i)(134) <= queso_rx_data_arr_i(i)(134) xor x"80"; -- VFAT14 pair 8 (GBT6 elink 25)
                queso_data_arr_o(i)(143) <= queso_rx_data_arr_i(i)(143) xor x"80"; -- VFAT15 pair 8 (GBT7 elink 11)
                queso_data_arr_o(i)(152) <= queso_rx_data_arr_i(i)(152) xor x"80"; -- VFAT16 pair 8 (GBT1 elink 24)
                queso_data_arr_o(i)(161) <= queso_rx_data_arr_i(i)(161) xor x"80"; -- VFAT17 pair 8 (GBT1 elink 06)
                queso_data_arr_o(i)(170) <= queso_rx_data_arr_i(i)(170) xor x"80"; -- VFAT18 pair 8 (GBT3 elink 24)
                queso_data_arr_o(i)(179) <= queso_rx_data_arr_i(i)(179) xor x"80"; -- VFAT19 pair 8 (GBT3 elink 06)
                queso_data_arr_o(i)(188) <= queso_rx_data_arr_i(i)(188) xor x"80"; -- VFAT20 pair 8 (GBT5 elink 24)
                queso_data_arr_o(i)(197) <= queso_rx_data_arr_i(i)(197) xor x"80"; -- VFAT21 pair 8 (GBT5 elink 06)
                queso_data_arr_o(i)(206) <= queso_rx_data_arr_i(i)(206) xor x"80"; -- VFAT22 pair 8 (GBT7 elink 24)
                queso_data_arr_o(i)(215) <= queso_rx_data_arr_i(i)(215) xor x"80"; -- VFAT23 pair 8 (GBT7 elink 06) 
                -- SBITS --
                queso_data_arr_o(i)(000) <= queso_rx_data_arr_i(i)(000) xor x"00"; -- VFAT00 pair 0 (GBT0 elink 16)
                queso_data_arr_o(i)(001) <= queso_rx_data_arr_i(i)(001) xor x"01"; -- VFAT00 pair 1 (GBT0 elink 18)
                queso_data_arr_o(i)(002) <= queso_rx_data_arr_i(i)(002) xor x"02"; -- VFAT00 pair 2 (GBT0 elink 20)
                queso_data_arr_o(i)(003) <= queso_rx_data_arr_i(i)(003) xor x"04"; -- VFAT00 pair 3 (GBT0 elink 22)
                queso_data_arr_o(i)(004) <= queso_rx_data_arr_i(i)(004) xor x"08"; -- VFAT00 pair 4 (GBT0 elink 24)
                queso_data_arr_o(i)(005) <= queso_rx_data_arr_i(i)(005) xor x"10"; -- VFAT00 pair 5 (GBT0 elink 26)
                queso_data_arr_o(i)(006) <= queso_rx_data_arr_i(i)(006) xor x"20"; -- VFAT00 pair 6 (GBT0 elink 21)
                queso_data_arr_o(i)(007) <= queso_rx_data_arr_i(i)(007) xor x"40"; -- VFAT00 pair 7 (GBT0 elink 23)
                queso_data_arr_o(i)(009) <= queso_rx_data_arr_i(i)(009) xor x"00"; -- VFAT01 pair 0 (GBT0 elink 15)
                queso_data_arr_o(i)(010) <= queso_rx_data_arr_i(i)(010) xor x"01"; -- VFAT01 pair 1 (GBT0 elink 14)
                queso_data_arr_o(i)(011) <= queso_rx_data_arr_i(i)(011) xor x"02"; -- VFAT01 pair 2 (GBT0 elink 12)
                queso_data_arr_o(i)(012) <= queso_rx_data_arr_i(i)(012) xor x"04"; -- VFAT01 pair 3 (GBT0 elink 10)
                queso_data_arr_o(i)(013) <= queso_rx_data_arr_i(i)(013) xor x"08"; -- VFAT01 pair 4 (GBT0 elink 11)
                queso_data_arr_o(i)(014) <= queso_rx_data_arr_i(i)(014) xor x"10"; -- VFAT01 pair 5 (GBT0 elink 13)
                queso_data_arr_o(i)(015) <= queso_rx_data_arr_i(i)(015) xor x"20"; -- VFAT01 pair 6 (GBT0 elink 19)
                queso_data_arr_o(i)(016) <= queso_rx_data_arr_i(i)(016) xor x"40"; -- VFAT01 pair 7 (GBT0 elink 17)
                queso_data_arr_o(i)(018) <= queso_rx_data_arr_i(i)(018) xor x"00"; -- VFAT02 pair 0 (GBT2 elink 16)
                queso_data_arr_o(i)(019) <= queso_rx_data_arr_i(i)(019) xor x"01"; -- VFAT02 pair 1 (GBT2 elink 18)
                queso_data_arr_o(i)(020) <= queso_rx_data_arr_i(i)(020) xor x"02"; -- VFAT02 pair 2 (GBT2 elink 20)
                queso_data_arr_o(i)(021) <= queso_rx_data_arr_i(i)(021) xor x"04"; -- VFAT02 pair 3 (GBT2 elink 22)
                queso_data_arr_o(i)(022) <= queso_rx_data_arr_i(i)(022) xor x"08"; -- VFAT02 pair 4 (GBT2 elink 24)
                queso_data_arr_o(i)(023) <= queso_rx_data_arr_i(i)(023) xor x"10"; -- VFAT02 pair 5 (GBT2 elink 26)
                queso_data_arr_o(i)(024) <= queso_rx_data_arr_i(i)(024) xor x"20"; -- VFAT02 pair 6 (GBT2 elink 21)
                queso_data_arr_o(i)(025) <= queso_rx_data_arr_i(i)(025) xor x"40"; -- VFAT02 pair 7 (GBT2 elink 23)
                queso_data_arr_o(i)(027) <= queso_rx_data_arr_i(i)(027) xor x"00"; -- VFAT03 pair 0 (GBT2 elink 15)
                queso_data_arr_o(i)(028) <= queso_rx_data_arr_i(i)(028) xor x"01"; -- VFAT03 pair 1 (GBT2 elink 14)
                queso_data_arr_o(i)(029) <= queso_rx_data_arr_i(i)(029) xor x"02"; -- VFAT03 pair 2 (GBT2 elink 12)
                queso_data_arr_o(i)(030) <= queso_rx_data_arr_i(i)(030) xor x"04"; -- VFAT03 pair 3 (GBT2 elink 10)
                queso_data_arr_o(i)(031) <= queso_rx_data_arr_i(i)(031) xor x"08"; -- VFAT03 pair 4 (GBT2 elink 11)
                queso_data_arr_o(i)(032) <= queso_rx_data_arr_i(i)(032) xor x"10"; -- VFAT03 pair 5 (GBT2 elink 13)
                queso_data_arr_o(i)(033) <= queso_rx_data_arr_i(i)(033) xor x"20"; -- VFAT03 pair 6 (GBT2 elink 19)
                queso_data_arr_o(i)(034) <= queso_rx_data_arr_i(i)(034) xor x"40"; -- VFAT03 pair 7 (GBT2 elink 17)
                queso_data_arr_o(i)(036) <= queso_rx_data_arr_i(i)(036) xor x"00"; -- VFAT04 pair 0 (GBT4 elink 06)
                queso_data_arr_o(i)(037) <= queso_rx_data_arr_i(i)(037) xor x"01"; -- VFAT04 pair 1 (GBT4 elink 07)
                queso_data_arr_o(i)(038) <= queso_rx_data_arr_i(i)(038) xor x"02"; -- VFAT04 pair 2 (GBT4 elink 09)
                queso_data_arr_o(i)(039) <= queso_rx_data_arr_i(i)(039) xor x"04"; -- VFAT04 pair 3 (GBT4 elink 04)
                queso_data_arr_o(i)(040) <= queso_rx_data_arr_i(i)(040) xor x"08"; -- VFAT04 pair 4 (GBT4 elink 05)
                queso_data_arr_o(i)(041) <= queso_rx_data_arr_i(i)(041) xor x"10"; -- VFAT04 pair 5 (GBT4 elink 02)
                queso_data_arr_o(i)(042) <= queso_rx_data_arr_i(i)(042) xor x"20"; -- VFAT04 pair 6 (GBT4 elink 00)
                queso_data_arr_o(i)(043) <= queso_rx_data_arr_i(i)(043) xor x"40"; -- VFAT04 pair 7 (GBT4 elink 01)
                queso_data_arr_o(i)(045) <= queso_rx_data_arr_i(i)(045) xor x"00"; -- VFAT05 pair 0 (GBT4 elink 15)
                queso_data_arr_o(i)(046) <= queso_rx_data_arr_i(i)(046) xor x"01"; -- VFAT05 pair 1 (GBT4 elink 14)
                queso_data_arr_o(i)(047) <= queso_rx_data_arr_i(i)(047) xor x"02"; -- VFAT05 pair 2 (GBT4 elink 12)
                queso_data_arr_o(i)(048) <= queso_rx_data_arr_i(i)(048) xor x"04"; -- VFAT05 pair 3 (GBT4 elink 10)
                queso_data_arr_o(i)(049) <= queso_rx_data_arr_i(i)(049) xor x"08"; -- VFAT05 pair 4 (GBT4 elink 11)
                queso_data_arr_o(i)(050) <= queso_rx_data_arr_i(i)(050) xor x"10"; -- VFAT05 pair 5 (GBT4 elink 13)
                queso_data_arr_o(i)(051) <= queso_rx_data_arr_i(i)(051) xor x"20"; -- VFAT05 pair 6 (GBT4 elink 19)
                queso_data_arr_o(i)(052) <= queso_rx_data_arr_i(i)(052) xor x"40"; -- VFAT05 pair 7 (GBT4 elink 17)
                queso_data_arr_o(i)(054) <= queso_rx_data_arr_i(i)(054) xor x"00"; -- VFAT06 pair 0 (GBT5 elink 06)
                queso_data_arr_o(i)(055) <= queso_rx_data_arr_i(i)(055) xor x"01"; -- VFAT06 pair 1 (GBT5 elink 07)
                queso_data_arr_o(i)(056) <= queso_rx_data_arr_i(i)(056) xor x"02"; -- VFAT06 pair 2 (GBT5 elink 09)
                queso_data_arr_o(i)(057) <= queso_rx_data_arr_i(i)(057) xor x"04"; -- VFAT06 pair 3 (GBT5 elink 04)
                queso_data_arr_o(i)(058) <= queso_rx_data_arr_i(i)(058) xor x"08"; -- VFAT06 pair 4 (GBT5 elink 05)
                queso_data_arr_o(i)(059) <= queso_rx_data_arr_i(i)(059) xor x"10"; -- VFAT06 pair 5 (GBT5 elink 02)
                queso_data_arr_o(i)(060) <= queso_rx_data_arr_i(i)(060) xor x"20"; -- VFAT06 pair 6 (GBT5 elink 00)
                queso_data_arr_o(i)(061) <= queso_rx_data_arr_i(i)(061) xor x"40"; -- VFAT06 pair 7 (GBT5 elink 01)
                queso_data_arr_o(i)(063) <= queso_rx_data_arr_i(i)(063) xor x"00"; -- VFAT07 pair 0 (GBT6 elink 15)
                queso_data_arr_o(i)(064) <= queso_rx_data_arr_i(i)(064) xor x"01"; -- VFAT07 pair 1 (GBT6 elink 14)
                queso_data_arr_o(i)(065) <= queso_rx_data_arr_i(i)(065) xor x"02"; -- VFAT07 pair 2 (GBT6 elink 12)
                queso_data_arr_o(i)(066) <= queso_rx_data_arr_i(i)(066) xor x"04"; -- VFAT07 pair 3 (GBT6 elink 10)
                queso_data_arr_o(i)(067) <= queso_rx_data_arr_i(i)(067) xor x"08"; -- VFAT07 pair 4 (GBT6 elink 11)
                queso_data_arr_o(i)(068) <= queso_rx_data_arr_i(i)(068) xor x"10"; -- VFAT07 pair 5 (GBT6 elink 13)
                queso_data_arr_o(i)(069) <= queso_rx_data_arr_i(i)(069) xor x"20"; -- VFAT07 pair 6 (GBT6 elink 19)
                queso_data_arr_o(i)(070) <= queso_rx_data_arr_i(i)(070) xor x"40"; -- VFAT07 pair 7 (GBT6 elink 17)
                queso_data_arr_o(i)(072) <= queso_rx_data_arr_i(i)(072) xor x"00"; -- VFAT08 pair 0 (GBT0 elink 06)
                queso_data_arr_o(i)(073) <= queso_rx_data_arr_i(i)(073) xor x"01"; -- VFAT08 pair 1 (GBT0 elink 07)
                queso_data_arr_o(i)(074) <= queso_rx_data_arr_i(i)(074) xor x"02"; -- VFAT08 pair 2 (GBT0 elink 09)
                queso_data_arr_o(i)(075) <= queso_rx_data_arr_i(i)(075) xor x"04"; -- VFAT08 pair 3 (GBT0 elink 04)
                queso_data_arr_o(i)(076) <= queso_rx_data_arr_i(i)(076) xor x"08"; -- VFAT08 pair 4 (GBT0 elink 05)
                queso_data_arr_o(i)(077) <= queso_rx_data_arr_i(i)(077) xor x"10"; -- VFAT08 pair 5 (GBT0 elink 02)
                queso_data_arr_o(i)(078) <= queso_rx_data_arr_i(i)(078) xor x"20"; -- VFAT08 pair 6 (GBT0 elink 00)
                queso_data_arr_o(i)(079) <= queso_rx_data_arr_i(i)(079) xor x"40"; -- VFAT08 pair 7 (GBT0 elink 01)
                queso_data_arr_o(i)(081) <= queso_rx_data_arr_i(i)(081) xor x"00"; -- VFAT09 pair 0 (GBT1 elink 17)
                queso_data_arr_o(i)(082) <= queso_rx_data_arr_i(i)(082) xor x"01"; -- VFAT09 pair 1 (GBT1 elink 19)
                queso_data_arr_o(i)(083) <= queso_rx_data_arr_i(i)(083) xor x"02"; -- VFAT09 pair 2 (GBT1 elink 14)
                queso_data_arr_o(i)(084) <= queso_rx_data_arr_i(i)(084) xor x"04"; -- VFAT09 pair 3 (GBT1 elink 07)
                queso_data_arr_o(i)(085) <= queso_rx_data_arr_i(i)(085) xor x"08"; -- VFAT09 pair 4 (GBT1 elink 09)
                queso_data_arr_o(i)(086) <= queso_rx_data_arr_i(i)(086) xor x"10"; -- VFAT09 pair 5 (GBT1 elink 10)
                queso_data_arr_o(i)(087) <= queso_rx_data_arr_i(i)(087) xor x"20"; -- VFAT09 pair 6 (GBT1 elink 15)
                queso_data_arr_o(i)(088) <= queso_rx_data_arr_i(i)(088) xor x"40"; -- VFAT09 pair 7 (GBT1 elink 08)
                queso_data_arr_o(i)(090) <= queso_rx_data_arr_i(i)(090) xor x"00"; -- VFAT10 pair 0 (GBT2 elink 06)
                queso_data_arr_o(i)(091) <= queso_rx_data_arr_i(i)(091) xor x"01"; -- VFAT10 pair 1 (GBT2 elink 07)
                queso_data_arr_o(i)(092) <= queso_rx_data_arr_i(i)(092) xor x"02"; -- VFAT10 pair 2 (GBT2 elink 09)
                queso_data_arr_o(i)(093) <= queso_rx_data_arr_i(i)(093) xor x"04"; -- VFAT10 pair 3 (GBT2 elink 04)
                queso_data_arr_o(i)(094) <= queso_rx_data_arr_i(i)(094) xor x"08"; -- VFAT10 pair 4 (GBT2 elink 05)
                queso_data_arr_o(i)(095) <= queso_rx_data_arr_i(i)(095) xor x"10"; -- VFAT10 pair 5 (GBT2 elink 02)
                queso_data_arr_o(i)(096) <= queso_rx_data_arr_i(i)(096) xor x"20"; -- VFAT10 pair 6 (GBT2 elink 00)
                queso_data_arr_o(i)(097) <= queso_rx_data_arr_i(i)(097) xor x"40"; -- VFAT10 pair 7 (GBT2 elink 01)
                queso_data_arr_o(i)(099) <= queso_rx_data_arr_i(i)(099) xor x"00"; -- VFAT11 pair 0 (GBT3 elink 17)
                queso_data_arr_o(i)(100) <= queso_rx_data_arr_i(i)(100) xor x"01"; -- VFAT11 pair 1 (GBT3 elink 19)
                queso_data_arr_o(i)(101) <= queso_rx_data_arr_i(i)(101) xor x"02"; -- VFAT11 pair 2 (GBT3 elink 14)
                queso_data_arr_o(i)(102) <= queso_rx_data_arr_i(i)(102) xor x"04"; -- VFAT11 pair 3 (GBT3 elink 07)
                queso_data_arr_o(i)(103) <= queso_rx_data_arr_i(i)(103) xor x"08"; -- VFAT11 pair 4 (GBT3 elink 09)
                queso_data_arr_o(i)(104) <= queso_rx_data_arr_i(i)(104) xor x"10"; -- VFAT11 pair 5 (GBT3 elink 10)
                queso_data_arr_o(i)(105) <= queso_rx_data_arr_i(i)(105) xor x"20"; -- VFAT11 pair 6 (GBT3 elink 15)
                queso_data_arr_o(i)(106) <= queso_rx_data_arr_i(i)(106) xor x"40"; -- VFAT11 pair 7 (GBT3 elink 08)
                queso_data_arr_o(i)(108) <= queso_rx_data_arr_i(i)(108) xor x"00"; -- VFAT12 pair 0 (GBT4 elink 16)
                queso_data_arr_o(i)(109) <= queso_rx_data_arr_i(i)(109) xor x"01"; -- VFAT12 pair 1 (GBT4 elink 18)
                queso_data_arr_o(i)(110) <= queso_rx_data_arr_i(i)(110) xor x"02"; -- VFAT12 pair 2 (GBT4 elink 20)
                queso_data_arr_o(i)(111) <= queso_rx_data_arr_i(i)(111) xor x"04"; -- VFAT12 pair 3 (GBT4 elink 22)
                queso_data_arr_o(i)(112) <= queso_rx_data_arr_i(i)(112) xor x"08"; -- VFAT12 pair 4 (GBT4 elink 24)
                queso_data_arr_o(i)(113) <= queso_rx_data_arr_i(i)(113) xor x"10"; -- VFAT12 pair 5 (GBT4 elink 26)
                queso_data_arr_o(i)(114) <= queso_rx_data_arr_i(i)(114) xor x"20"; -- VFAT12 pair 6 (GBT4 elink 21)
                queso_data_arr_o(i)(115) <= queso_rx_data_arr_i(i)(115) xor x"40"; -- VFAT12 pair 7 (GBT4 elink 23)
                queso_data_arr_o(i)(117) <= queso_rx_data_arr_i(i)(117) xor x"00"; -- VFAT13 pair 0 (GBT5 elink 17)
                queso_data_arr_o(i)(118) <= queso_rx_data_arr_i(i)(118) xor x"01"; -- VFAT13 pair 1 (GBT5 elink 19)
                queso_data_arr_o(i)(119) <= queso_rx_data_arr_i(i)(119) xor x"02"; -- VFAT13 pair 2 (GBT5 elink 14)
                queso_data_arr_o(i)(120) <= queso_rx_data_arr_i(i)(120) xor x"04"; -- VFAT13 pair 3 (GBT5 elink 07)
                queso_data_arr_o(i)(121) <= queso_rx_data_arr_i(i)(121) xor x"08"; -- VFAT13 pair 4 (GBT5 elink 09)
                queso_data_arr_o(i)(122) <= queso_rx_data_arr_i(i)(122) xor x"10"; -- VFAT13 pair 5 (GBT5 elink 10)
                queso_data_arr_o(i)(123) <= queso_rx_data_arr_i(i)(123) xor x"20"; -- VFAT13 pair 6 (GBT5 elink 15)
                queso_data_arr_o(i)(124) <= queso_rx_data_arr_i(i)(124) xor x"40"; -- VFAT13 pair 7 (GBT5 elink 08)
                queso_data_arr_o(i)(126) <= queso_rx_data_arr_i(i)(126) xor x"00"; -- VFAT14 pair 0 (GBT6 elink 16)
                queso_data_arr_o(i)(127) <= queso_rx_data_arr_i(i)(127) xor x"01"; -- VFAT14 pair 1 (GBT6 elink 18)
                queso_data_arr_o(i)(128) <= queso_rx_data_arr_i(i)(128) xor x"02"; -- VFAT14 pair 2 (GBT6 elink 20)
                queso_data_arr_o(i)(129) <= queso_rx_data_arr_i(i)(129) xor x"04"; -- VFAT14 pair 3 (GBT6 elink 22)
                queso_data_arr_o(i)(130) <= queso_rx_data_arr_i(i)(130) xor x"08"; -- VFAT14 pair 4 (GBT6 elink 24)
                queso_data_arr_o(i)(131) <= queso_rx_data_arr_i(i)(131) xor x"10"; -- VFAT14 pair 5 (GBT6 elink 26)
                queso_data_arr_o(i)(132) <= queso_rx_data_arr_i(i)(132) xor x"20"; -- VFAT14 pair 6 (GBT6 elink 21)
                queso_data_arr_o(i)(133) <= queso_rx_data_arr_i(i)(133) xor x"40"; -- VFAT14 pair 7 (GBT6 elink 23)
                queso_data_arr_o(i)(135) <= queso_rx_data_arr_i(i)(135) xor x"00"; -- VFAT15 pair 0 (GBT7 elink 17)
                queso_data_arr_o(i)(136) <= queso_rx_data_arr_i(i)(136) xor x"01"; -- VFAT15 pair 1 (GBT7 elink 19)
                queso_data_arr_o(i)(137) <= queso_rx_data_arr_i(i)(137) xor x"02"; -- VFAT15 pair 2 (GBT7 elink 14)
                queso_data_arr_o(i)(138) <= queso_rx_data_arr_i(i)(138) xor x"04"; -- VFAT15 pair 3 (GBT7 elink 07)
                queso_data_arr_o(i)(139) <= queso_rx_data_arr_i(i)(139) xor x"08"; -- VFAT15 pair 4 (GBT7 elink 09)
                queso_data_arr_o(i)(140) <= queso_rx_data_arr_i(i)(140) xor x"10"; -- VFAT15 pair 5 (GBT7 elink 10)
                queso_data_arr_o(i)(141) <= queso_rx_data_arr_i(i)(141) xor x"20"; -- VFAT15 pair 6 (GBT7 elink 15)
                queso_data_arr_o(i)(142) <= queso_rx_data_arr_i(i)(142) xor x"40"; -- VFAT15 pair 7 (GBT7 elink 08)
                queso_data_arr_o(i)(144) <= queso_rx_data_arr_i(i)(144) xor x"00"; -- VFAT16 pair 0 (GBT1 elink 18)
                queso_data_arr_o(i)(145) <= queso_rx_data_arr_i(i)(145) xor x"01"; -- VFAT16 pair 1 (GBT1 elink 21)
                queso_data_arr_o(i)(146) <= queso_rx_data_arr_i(i)(146) xor x"02"; -- VFAT16 pair 2 (GBT1 elink 20)
                queso_data_arr_o(i)(147) <= queso_rx_data_arr_i(i)(147) xor x"04"; -- VFAT16 pair 3 (GBT1 elink 23)
                queso_data_arr_o(i)(148) <= queso_rx_data_arr_i(i)(148) xor x"08"; -- VFAT16 pair 4 (GBT1 elink 22)
                queso_data_arr_o(i)(149) <= queso_rx_data_arr_i(i)(149) xor x"10"; -- VFAT16 pair 5 (GBT1 elink 27)
                queso_data_arr_o(i)(150) <= queso_rx_data_arr_i(i)(150) xor x"20"; -- VFAT16 pair 6 (GBT1 elink 26)
                queso_data_arr_o(i)(151) <= queso_rx_data_arr_i(i)(151) xor x"40"; -- VFAT16 pair 7 (GBT1 elink 25)
                queso_data_arr_o(i)(153) <= queso_rx_data_arr_i(i)(153) xor x"00"; -- VFAT17 pair 0 (GBT1 elink 03)
                queso_data_arr_o(i)(154) <= queso_rx_data_arr_i(i)(154) xor x"01"; -- VFAT17 pair 1 (GBT1 elink 13)
                queso_data_arr_o(i)(155) <= queso_rx_data_arr_i(i)(155) xor x"02"; -- VFAT17 pair 2 (GBT1 elink 05)
                queso_data_arr_o(i)(156) <= queso_rx_data_arr_i(i)(156) xor x"04"; -- VFAT17 pair 3 (GBT1 elink 01)
                queso_data_arr_o(i)(157) <= queso_rx_data_arr_i(i)(157) xor x"08"; -- VFAT17 pair 4 (GBT1 elink 00)
                queso_data_arr_o(i)(158) <= queso_rx_data_arr_i(i)(158) xor x"10"; -- VFAT17 pair 5 (GBT1 elink 02)
                queso_data_arr_o(i)(159) <= queso_rx_data_arr_i(i)(159) xor x"20"; -- VFAT17 pair 6 (GBT1 elink 12)
                queso_data_arr_o(i)(160) <= queso_rx_data_arr_i(i)(160) xor x"40"; -- VFAT17 pair 7 (GBT1 elink 04)
                queso_data_arr_o(i)(162) <= queso_rx_data_arr_i(i)(162) xor x"00"; -- VFAT18 pair 0 (GBT3 elink 18)
                queso_data_arr_o(i)(163) <= queso_rx_data_arr_i(i)(163) xor x"01"; -- VFAT18 pair 1 (GBT3 elink 21)
                queso_data_arr_o(i)(164) <= queso_rx_data_arr_i(i)(164) xor x"02"; -- VFAT18 pair 2 (GBT3 elink 20)
                queso_data_arr_o(i)(165) <= queso_rx_data_arr_i(i)(165) xor x"04"; -- VFAT18 pair 3 (GBT3 elink 23)
                queso_data_arr_o(i)(166) <= queso_rx_data_arr_i(i)(166) xor x"08"; -- VFAT18 pair 4 (GBT3 elink 22)
                queso_data_arr_o(i)(167) <= queso_rx_data_arr_i(i)(167) xor x"10"; -- VFAT18 pair 5 (GBT3 elink 27)
                queso_data_arr_o(i)(168) <= queso_rx_data_arr_i(i)(168) xor x"20"; -- VFAT18 pair 6 (GBT3 elink 26)
                queso_data_arr_o(i)(169) <= queso_rx_data_arr_i(i)(169) xor x"40"; -- VFAT18 pair 7 (GBT3 elink 25)
                queso_data_arr_o(i)(171) <= queso_rx_data_arr_i(i)(171) xor x"00"; -- VFAT19 pair 0 (GBT3 elink 03)
                queso_data_arr_o(i)(172) <= queso_rx_data_arr_i(i)(172) xor x"01"; -- VFAT19 pair 1 (GBT3 elink 13)
                queso_data_arr_o(i)(173) <= queso_rx_data_arr_i(i)(173) xor x"02"; -- VFAT19 pair 2 (GBT3 elink 05)
                queso_data_arr_o(i)(174) <= queso_rx_data_arr_i(i)(174) xor x"04"; -- VFAT19 pair 3 (GBT3 elink 01)
                queso_data_arr_o(i)(175) <= queso_rx_data_arr_i(i)(175) xor x"08"; -- VFAT19 pair 4 (GBT3 elink 00)
                queso_data_arr_o(i)(176) <= queso_rx_data_arr_i(i)(176) xor x"10"; -- VFAT19 pair 5 (GBT3 elink 02)
                queso_data_arr_o(i)(177) <= queso_rx_data_arr_i(i)(177) xor x"20"; -- VFAT19 pair 6 (GBT3 elink 12)
                queso_data_arr_o(i)(178) <= queso_rx_data_arr_i(i)(178) xor x"40"; -- VFAT19 pair 7 (GBT3 elink 04)
                queso_data_arr_o(i)(180) <= queso_rx_data_arr_i(i)(180) xor x"00"; -- VFAT20 pair 0 (GBT5 elink 18)
                queso_data_arr_o(i)(181) <= queso_rx_data_arr_i(i)(181) xor x"01"; -- VFAT20 pair 1 (GBT5 elink 21)
                queso_data_arr_o(i)(182) <= queso_rx_data_arr_i(i)(182) xor x"02"; -- VFAT20 pair 2 (GBT5 elink 20)
                queso_data_arr_o(i)(183) <= queso_rx_data_arr_i(i)(183) xor x"04"; -- VFAT20 pair 3 (GBT5 elink 23)
                queso_data_arr_o(i)(184) <= queso_rx_data_arr_i(i)(184) xor x"08"; -- VFAT20 pair 4 (GBT5 elink 22)
                queso_data_arr_o(i)(185) <= queso_rx_data_arr_i(i)(185) xor x"10"; -- VFAT20 pair 5 (GBT5 elink 27)
                queso_data_arr_o(i)(186) <= queso_rx_data_arr_i(i)(186) xor x"20"; -- VFAT20 pair 6 (GBT5 elink 26)
                queso_data_arr_o(i)(187) <= queso_rx_data_arr_i(i)(187) xor x"40"; -- VFAT20 pair 7 (GBT5 elink 25)
                queso_data_arr_o(i)(189) <= queso_rx_data_arr_i(i)(189) xor x"00"; -- VFAT21 pair 0 (GBT5 elink 03)
                queso_data_arr_o(i)(190) <= queso_rx_data_arr_i(i)(190) xor x"01"; -- VFAT21 pair 1 (GBT5 elink 13)
                queso_data_arr_o(i)(191) <= queso_rx_data_arr_i(i)(191) xor x"02"; -- VFAT21 pair 2 (GBT5 elink 05)
                queso_data_arr_o(i)(192) <= queso_rx_data_arr_i(i)(192) xor x"04"; -- VFAT21 pair 3 (GBT5 elink 01)
                queso_data_arr_o(i)(193) <= queso_rx_data_arr_i(i)(193) xor x"08"; -- VFAT21 pair 4 (GBT5 elink 00)
                queso_data_arr_o(i)(194) <= queso_rx_data_arr_i(i)(194) xor x"10"; -- VFAT21 pair 5 (GBT5 elink 02)
                queso_data_arr_o(i)(195) <= queso_rx_data_arr_i(i)(195) xor x"20"; -- VFAT21 pair 6 (GBT5 elink 12)
                queso_data_arr_o(i)(196) <= queso_rx_data_arr_i(i)(196) xor x"40"; -- VFAT21 pair 7 (GBT5 elink 04)
                queso_data_arr_o(i)(198) <= queso_rx_data_arr_i(i)(198) xor x"00"; -- VFAT22 pair 0 (GBT7 elink 18)
                queso_data_arr_o(i)(199) <= queso_rx_data_arr_i(i)(199) xor x"01"; -- VFAT22 pair 1 (GBT7 elink 21)
                queso_data_arr_o(i)(200) <= queso_rx_data_arr_i(i)(200) xor x"02"; -- VFAT22 pair 2 (GBT7 elink 20)
                queso_data_arr_o(i)(201) <= queso_rx_data_arr_i(i)(201) xor x"04"; -- VFAT22 pair 3 (GBT7 elink 23)
                queso_data_arr_o(i)(202) <= queso_rx_data_arr_i(i)(202) xor x"08"; -- VFAT22 pair 4 (GBT7 elink 22)
                queso_data_arr_o(i)(203) <= queso_rx_data_arr_i(i)(203) xor x"10"; -- VFAT22 pair 5 (GBT7 elink 27)
                queso_data_arr_o(i)(204) <= queso_rx_data_arr_i(i)(204) xor x"20"; -- VFAT22 pair 6 (GBT7 elink 26)
                queso_data_arr_o(i)(205) <= queso_rx_data_arr_i(i)(205) xor x"40"; -- VFAT22 pair 7 (GBT7 elink 25)
                queso_data_arr_o(i)(207) <= queso_rx_data_arr_i(i)(207) xor x"00"; -- VFAT23 pair 0 (GBT7 elink 03)
                queso_data_arr_o(i)(208) <= queso_rx_data_arr_i(i)(208) xor x"01"; -- VFAT23 pair 1 (GBT7 elink 13)
                queso_data_arr_o(i)(209) <= queso_rx_data_arr_i(i)(209) xor x"02"; -- VFAT23 pair 2 (GBT7 elink 05)
                queso_data_arr_o(i)(210) <= queso_rx_data_arr_i(i)(210) xor x"04"; -- VFAT23 pair 3 (GBT7 elink 01)
                queso_data_arr_o(i)(211) <= queso_rx_data_arr_i(i)(211) xor x"08"; -- VFAT23 pair 4 (GBT7 elink 00)
                queso_data_arr_o(i)(212) <= queso_rx_data_arr_i(i)(212) xor x"10"; -- VFAT23 pair 5 (GBT7 elink 02)
                queso_data_arr_o(i)(213) <= queso_rx_data_arr_i(i)(213) xor x"20"; -- VFAT23 pair 6 (GBT7 elink 12)
                queso_data_arr_o(i)(214) <= queso_rx_data_arr_i(i)(214) xor x"40"; -- VFAT23 pair 7 (GBT7 elink 04)
            end if;
        end process;
    end generate;
    
end queso_link_decrypt_arch;
