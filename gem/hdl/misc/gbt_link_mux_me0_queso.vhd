------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2019-08-29
-- Module Name:    LPGBT_LINK_MUX
-- Description:    This module is used to direct the LpGBT links either to the VFATs (standard operation) or to the GEM_TESTS module 
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

entity gbt_link_mux_me0_queso is
    generic(
        g_NUM_OF_OHs                : integer;
        g_NUM_GBTS_PER_OH           : integer
    );
    port(
        -- clock
        gbt_frame_clk_i             : in  std_logic;
        
        -- control
        gbt_ic_rx_use_ec_i          : in  std_logic;

        -- links
        gbt_rx_data_arr_i           : in  t_lpgbt_rx_frame_array(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);
        gbt_tx_data_arr_o           : out t_lpgbt_tx_frame_array(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);
        gbt_link_status_arr_i       : in  t_gbt_link_status_arr(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);
        
        -- elinks
        gbt_ic_tx_data_arr_i        : in  t_std2_array(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);
        gbt_ic_rx_data_arr_o        : out t_std2_array(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);

        vfat3_tx_data_arr_i         : in  t_vfat3_elinks_arr(g_NUM_OF_OHs - 1 downto 0);
        vfat3_rx_data_arr_o         : out t_vfat3_elinks_arr(g_NUM_OF_OHs - 1 downto 0);
        
        vfat3_sbits_arr_o           : out t_vfat3_sbits_arr(g_NUM_OF_OHs - 1 downto 0);

        gbt_ready_arr_o             : out std_logic_vector(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);
        vfat3_gbt_ready_arr_o       : out t_std24_array(g_NUM_OF_OHs - 1 downto 0);

        --test data
        test_vfat3_tx_data_arr_i    : in  std_logic_vector(7 downto 0);
        test_vfat3_rx_data_arr_o    : out t_vfat3_queso_arr(g_NUM_OF_OHs - 1 downto 0)

    );
end gbt_link_mux_me0_queso;

architecture gbt_link_mux_me0_queso_arch of gbt_link_mux_me0_queso is

    signal gbt_rx_ready_arr             : std_logic_vector((g_NUM_OF_OHs * g_NUM_GBTS_PER_OH) - 1 downto 0);
    signal gbt_tx_data_arr              : t_lpgbt_tx_frame_array(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);
    
begin

    --inversions incorperated in ASIAGO config

    gbt_ready_arr_o <= gbt_rx_ready_arr;
    gbt_tx_data_arr_o <= gbt_tx_data_arr;

    g_ohs : for i in 0 to g_NUM_OF_OHs - 1 generate

        --======================================================--
        --========================= RX =========================--
        --======================================================--

        -- IC
        gbt_ic_rx_data_arr_o(i * 8 + 0) <= gbt_rx_data_arr_i(i * 8 + 0).rx_ic_data(0) & gbt_rx_data_arr_i(i * 8 + 0).rx_ic_data(1); -- GBT0; bits reversed
        gbt_ic_rx_data_arr_o(i * 8 + 1) <= gbt_rx_data_arr_i(i * 8 + 1).rx_ic_data(0) & gbt_rx_data_arr_i(i * 8 + 1).rx_ic_data(1) when gbt_ic_rx_use_ec_i = '0' else
                                           gbt_rx_data_arr_i(i * 8 + 0).rx_ec_data(0) & gbt_rx_data_arr_i(i * 8 + 0).rx_ec_data(1); -- GBT1; bits reversed
        gbt_ic_rx_data_arr_o(i * 8 + 2) <= gbt_rx_data_arr_i(i * 8 + 2).rx_ic_data(0) & gbt_rx_data_arr_i(i * 8 + 2).rx_ic_data(1); -- GBT2; bits reversed
        gbt_ic_rx_data_arr_o(i * 8 + 3) <= gbt_rx_data_arr_i(i * 8 + 3).rx_ic_data(0) & gbt_rx_data_arr_i(i * 8 + 3).rx_ic_data(1) when gbt_ic_rx_use_ec_i = '0' else
                                           gbt_rx_data_arr_i(i * 8 + 2).rx_ec_data(0) & gbt_rx_data_arr_i(i * 8 + 2).rx_ec_data(1); -- GBT3; bits reversed
        gbt_ic_rx_data_arr_o(i * 8 + 4) <= gbt_rx_data_arr_i(i * 8 + 4).rx_ic_data(0) & gbt_rx_data_arr_i(i * 8 + 4).rx_ic_data(1); -- GBT4; bits reversed
        gbt_ic_rx_data_arr_o(i * 8 + 5) <= gbt_rx_data_arr_i(i * 8 + 5).rx_ic_data(0) & gbt_rx_data_arr_i(i * 8 + 5).rx_ic_data(1) when gbt_ic_rx_use_ec_i = '0' else
                                           gbt_rx_data_arr_i(i * 8 + 4).rx_ec_data(0) & gbt_rx_data_arr_i(i * 8 + 4).rx_ec_data(1); -- GBT5; bits reversed
        gbt_ic_rx_data_arr_o(i * 8 + 6) <= gbt_rx_data_arr_i(i * 8 + 6).rx_ic_data(0) & gbt_rx_data_arr_i(i * 8 + 6).rx_ic_data(1); -- GBT6; bits reversed
        gbt_ic_rx_data_arr_o(i * 8 + 7) <= gbt_rx_data_arr_i(i * 8 + 7).rx_ic_data(0) & gbt_rx_data_arr_i(i * 8 + 7).rx_ic_data(1) when gbt_ic_rx_use_ec_i = '0' else
                                           gbt_rx_data_arr_i(i * 8 + 6).rx_ec_data(0) & gbt_rx_data_arr_i(i * 8 + 6).rx_ec_data(1); -- GBT7; bits reversed

        -- GBT ready
        gbt_rx_ready_arr(i * 8 + 0) <= gbt_link_status_arr_i(i * 8 + 0).gbt_rx_ready; -- GBT0
        gbt_rx_ready_arr(i * 8 + 1) <= gbt_link_status_arr_i(i * 8 + 1).gbt_rx_ready; -- GBT1
        gbt_rx_ready_arr(i * 8 + 2) <= gbt_link_status_arr_i(i * 8 + 2).gbt_rx_ready; -- GBT2
        gbt_rx_ready_arr(i * 8 + 3) <= gbt_link_status_arr_i(i * 8 + 3).gbt_rx_ready; -- GBT3
        gbt_rx_ready_arr(i * 8 + 4) <= gbt_link_status_arr_i(i * 8 + 4).gbt_rx_ready; -- GBT4
        gbt_rx_ready_arr(i * 8 + 5) <= gbt_link_status_arr_i(i * 8 + 5).gbt_rx_ready; -- GBT5
        gbt_rx_ready_arr(i * 8 + 6) <= gbt_link_status_arr_i(i * 8 + 6).gbt_rx_ready; -- GBT6
        gbt_rx_ready_arr(i * 8 + 7) <= gbt_link_status_arr_i(i * 8 + 7).gbt_rx_ready; -- GBT7

        -- VFAT GBT ready
        vfat3_gbt_ready_arr_o(i)(00) <= gbt_rx_ready_arr(i * 8 + 0); -- VFAT00 (GBT0)
        vfat3_gbt_ready_arr_o(i)(01) <= gbt_rx_ready_arr(i * 8 + 0); -- VFAT01 (GBT0)
        vfat3_gbt_ready_arr_o(i)(02) <= gbt_rx_ready_arr(i * 8 + 2); -- VFAT02 (GBT2)
        vfat3_gbt_ready_arr_o(i)(03) <= gbt_rx_ready_arr(i * 8 + 2); -- VFAT03 (GBT2)
        vfat3_gbt_ready_arr_o(i)(04) <= gbt_rx_ready_arr(i * 8 + 4); -- VFAT04 (GBT4)
        vfat3_gbt_ready_arr_o(i)(05) <= gbt_rx_ready_arr(i * 8 + 4); -- VFAT05 (GBT4)
        vfat3_gbt_ready_arr_o(i)(06) <= gbt_rx_ready_arr(i * 8 + 6); -- VFAT06 (GBT6)
        vfat3_gbt_ready_arr_o(i)(07) <= gbt_rx_ready_arr(i * 8 + 6); -- VFAT07 (GBT6)
        vfat3_gbt_ready_arr_o(i)(08) <= gbt_rx_ready_arr(i * 8 + 0); -- VFAT08 (GBT0)
        vfat3_gbt_ready_arr_o(i)(09) <= gbt_rx_ready_arr(i * 8 + 1); -- VFAT09 (GBT1)
        vfat3_gbt_ready_arr_o(i)(10) <= gbt_rx_ready_arr(i * 8 + 2); -- VFAT10 (GBT2)
        vfat3_gbt_ready_arr_o(i)(11) <= gbt_rx_ready_arr(i * 8 + 3); -- VFAT11 (GBT3)
        vfat3_gbt_ready_arr_o(i)(12) <= gbt_rx_ready_arr(i * 8 + 4); -- VFAT12 (GBT4)
        vfat3_gbt_ready_arr_o(i)(13) <= gbt_rx_ready_arr(i * 8 + 5); -- VFAT13 (GBT5)
        vfat3_gbt_ready_arr_o(i)(14) <= gbt_rx_ready_arr(i * 8 + 6); -- VFAT14 (GBT6)
        vfat3_gbt_ready_arr_o(i)(15) <= gbt_rx_ready_arr(i * 8 + 7); -- VFAT15 (GBT7)
        vfat3_gbt_ready_arr_o(i)(16) <= gbt_rx_ready_arr(i * 8 + 1); -- VFAT16 (GBT1)
        vfat3_gbt_ready_arr_o(i)(17) <= gbt_rx_ready_arr(i * 8 + 1); -- VFAT17 (GBT1)
        vfat3_gbt_ready_arr_o(i)(18) <= gbt_rx_ready_arr(i * 8 + 3); -- VFAT18 (GBT3)
        vfat3_gbt_ready_arr_o(i)(19) <= gbt_rx_ready_arr(i * 8 + 3); -- VFAT19 (GBT3)
        vfat3_gbt_ready_arr_o(i)(20) <= gbt_rx_ready_arr(i * 8 + 5); -- VFAT20 (GBT5)
        vfat3_gbt_ready_arr_o(i)(21) <= gbt_rx_ready_arr(i * 8 + 5); -- VFAT21 (GBT5)
        vfat3_gbt_ready_arr_o(i)(22) <= gbt_rx_ready_arr(i * 8 + 7); -- VFAT22 (GBT7)
        vfat3_gbt_ready_arr_o(i)(23) <= gbt_rx_ready_arr(i * 8 + 7); -- VFAT23 (GBT7)
    
        --========================= QUESO TEST RX =========================--

        test_vfat3_rx_data_arr_o(i)(00) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(207 downto 200) xor x"28"; -- VFAT00 (GBT0 elink 25)
        test_vfat3_rx_data_arr_o(i)(09) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(223 downto 216) xor x"14"; -- VFAT01 (GBT0 elink 27)
        test_vfat3_rx_data_arr_o(i)(18) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(207 downto 200);-- xor x"28"; -- VFAT02 (GBT2 elink 25)
        test_vfat3_rx_data_arr_o(i)(27) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(223 downto 216);-- xor x"14"; -- VFAT03 (GBT2 elink 27)
        test_vfat3_rx_data_arr_o(i)(36) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(031 downto 024);-- xor x"00"; -- VFAT04 (GBT4 elink 03)
        test_vfat3_rx_data_arr_o(i)(45) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(223 downto 216);-- xor x"14"; -- VFAT05 (GBT4 elink 27)
        test_vfat3_rx_data_arr_o(i)(54) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(031 downto 024);-- xor x"00"; -- VFAT06 (GBT6 elink 03)
        test_vfat3_rx_data_arr_o(i)(63) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(223 downto 216);-- xor x"14"; -- VFAT07 (GBT6 elink 27)
        test_vfat3_rx_data_arr_o(i)(72) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(031 downto 024) xor x"00"; -- VFAT08 (GBT0 elink 03)
        test_vfat3_rx_data_arr_o(i)(81) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(095 downto 088) xor x"1e"; -- VFAT09 (GBT1 elink 11)
        test_vfat3_rx_data_arr_o(i)(90) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(031 downto 024);-- xor x"00"; -- VFAT10 (GBT2 elink 03)
        test_vfat3_rx_data_arr_o(i)(99) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(095 downto 088);-- xor x"1e"; -- VFAT11 (GBT3 elink 11)
        test_vfat3_rx_data_arr_o(i)(108) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(207 downto 200);-- xor x"28"; -- VFAT12 (GBT4 elink 25)
        test_vfat3_rx_data_arr_o(i)(117) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(095 downto 088);-- xor x"1e"; -- VFAT13 (GBT5 elink 11)
        test_vfat3_rx_data_arr_o(i)(126) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(207 downto 200);-- xor x"28"; -- VFAT14 (GBT6 elink 25)
        test_vfat3_rx_data_arr_o(i)(135) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(095 downto 088);-- xor x"1e"; -- VFAT15 (GBT7 elink 11)
        test_vfat3_rx_data_arr_o(i)(144) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(199 downto 192) xor x"0a"; -- VFAT16 (GBT1 elink 24)
        test_vfat3_rx_data_arr_o(i)(153) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(055 downto 048) xor x"32"; -- VFAT17 (GBT1 elink 06)
        test_vfat3_rx_data_arr_o(i)(162) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(199 downto 192);-- xor x"0a"; -- VFAT18 (GBT3 elink 24)
        test_vfat3_rx_data_arr_o(i)(171) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(055 downto 048);-- xor x"32"; -- VFAT19 (GBT3 elink 06)
        test_vfat3_rx_data_arr_o(i)(180) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(199 downto 192);-- xor x"0a"; -- VFAT20 (GBT5 elink 24)
        test_vfat3_rx_data_arr_o(i)(189) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(055 downto 048);-- xor x"32"; -- VFAT21 (GBT5 elink 06)
        test_vfat3_rx_data_arr_o(i)(198) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(199 downto 192);-- xor x"0a"; -- VFAT22 (GBT7 elink 24)
        test_vfat3_rx_data_arr_o(i)(207) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(055 downto 048);-- xor x"32"; -- VFAT23 (GBT7 elink 06)

        -- SBITS
        test_vfat3_rx_data_arr_o(i)(01) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(135 downto 128) xor x"29"; -- VFAT00 pair 0 (GBT0 elink 16)
        test_vfat3_rx_data_arr_o(i)(02) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(151 downto 144) xor x"2a"; -- VFAT00 pair 1 (GBT0 elink 18)
        test_vfat3_rx_data_arr_o(i)(03) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(167 downto 160) xor x"2b"; -- VFAT00 pair 2 (GBT0 elink 20)
        test_vfat3_rx_data_arr_o(i)(04) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(183 downto 176) xor x"2c"; -- VFAT00 pair 3 (GBT0 elink 22)
        test_vfat3_rx_data_arr_o(i)(05) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(199 downto 192) xor x"2d"; -- VFAT00 pair 4 (GBT0 elink 24)
        test_vfat3_rx_data_arr_o(i)(06) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(215 downto 208) xor x"2e"; -- VFAT00 pair 5 (GBT0 elink 26)
        test_vfat3_rx_data_arr_o(i)(07) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(175 downto 168) xor x"2f"; -- VFAT00 pair 6 (GBT0 elink 21)
        test_vfat3_rx_data_arr_o(i)(08) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(191 downto 184) xor x"30"; -- VFAT00 pair 7 (GBT0 elink 23)
        test_vfat3_rx_data_arr_o(i)(10) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(127 downto 120) xor x"15"; -- VFAT01 pair 0 (GBT0 elink 15)
        test_vfat3_rx_data_arr_o(i)(11) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(119 downto 112) xor x"16"; -- VFAT01 pair 1 (GBT0 elink 14)
        test_vfat3_rx_data_arr_o(i)(12) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(103 downto 096) xor x"17"; -- VFAT01 pair 2 (GBT0 elink 12)
        test_vfat3_rx_data_arr_o(i)(13) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(087 downto 080) xor x"18"; -- VFAT01 pair 3 (GBT0 elink 10)
        test_vfat3_rx_data_arr_o(i)(14) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(095 downto 088) xor x"19"; -- VFAT01 pair 4 (GBT0 elink 11)
        test_vfat3_rx_data_arr_o(i)(15) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(111 downto 104) xor x"1a"; -- VFAT01 pair 5 (GBT0 elink 13)
        test_vfat3_rx_data_arr_o(i)(16) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(159 downto 152) xor x"1b"; -- VFAT01 pair 6 (GBT0 elink 19)
        test_vfat3_rx_data_arr_o(i)(17) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(143 downto 136) xor x"1c"; -- VFAT01 pair 7 (GBT0 elink 17)
        test_vfat3_rx_data_arr_o(i)(19) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(135 downto 128); -- xor x"29"; -- VFAT02 pair 0 (GBT2 elink 16)
        test_vfat3_rx_data_arr_o(i)(20) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(151 downto 144); -- xor x"2a"; -- VFAT02 pair 1 (GBT2 elink 18)
        test_vfat3_rx_data_arr_o(i)(21) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(167 downto 160); -- xor x"2b"; -- VFAT02 pair 2 (GBT2 elink 20)
        test_vfat3_rx_data_arr_o(i)(22) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(183 downto 176); -- xor x"2c"; -- VFAT02 pair 3 (GBT2 elink 22)
        test_vfat3_rx_data_arr_o(i)(23) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(199 downto 192); -- xor x"2d"; -- VFAT02 pair 4 (GBT2 elink 24)
        test_vfat3_rx_data_arr_o(i)(24) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(215 downto 208); -- xor x"2e"; -- VFAT02 pair 5 (GBT2 elink 26)
        test_vfat3_rx_data_arr_o(i)(25) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(175 downto 168); -- xor x"2f"; -- VFAT02 pair 6 (GBT2 elink 21)
        test_vfat3_rx_data_arr_o(i)(26) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(191 downto 184); -- xor x"30"; -- VFAT02 pair 7 (GBT2 elink 23)
        test_vfat3_rx_data_arr_o(i)(28) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(127 downto 120); -- xor x"15"; -- VFAT03 pair 0 (GBT2 elink 15)
        test_vfat3_rx_data_arr_o(i)(29) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(119 downto 112); -- xor x"16"; -- VFAT03 pair 1 (GBT2 elink 14)
        test_vfat3_rx_data_arr_o(i)(30) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(103 downto 096); -- xor x"17"; -- VFAT03 pair 2 (GBT2 elink 12)
        test_vfat3_rx_data_arr_o(i)(31) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(087 downto 080); -- xor x"18"; -- VFAT03 pair 3 (GBT2 elink 10)
        test_vfat3_rx_data_arr_o(i)(32) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(095 downto 088); -- xor x"19"; -- VFAT03 pair 4 (GBT2 elink 11)
        test_vfat3_rx_data_arr_o(i)(33) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(111 downto 104); -- xor x"1a"; -- VFAT03 pair 5 (GBT2 elink 13)
        test_vfat3_rx_data_arr_o(i)(34) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(159 downto 152); -- xor x"1b"; -- VFAT03 pair 6 (GBT2 elink 19)
        test_vfat3_rx_data_arr_o(i)(35) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(143 downto 136); -- xor x"1c"; -- VFAT03 pair 7 (GBT2 elink 17)
        test_vfat3_rx_data_arr_o(i)(37) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(055 downto 048); -- xor x"01"; -- VFAT04 pair 0 (GBT4 elink 06)
        test_vfat3_rx_data_arr_o(i)(38) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(063 downto 056); -- xor x"02"; -- VFAT04 pair 1 (GBT4 elink 07)
        test_vfat3_rx_data_arr_o(i)(39) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(079 downto 072); -- xor x"03"; -- VFAT04 pair 2 (GBT4 elink 09)
        test_vfat3_rx_data_arr_o(i)(40) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(039 downto 032); -- xor x"04"; -- VFAT04 pair 3 (GBT4 elink 04)
        test_vfat3_rx_data_arr_o(i)(41) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(047 downto 040); -- xor x"05"; -- VFAT04 pair 4 (GBT4 elink 05)
        test_vfat3_rx_data_arr_o(i)(42) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(023 downto 016); -- xor x"06"; -- VFAT04 pair 5 (GBT4 elink 02)
        test_vfat3_rx_data_arr_o(i)(43) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(007 downto 000); -- xor x"07"; -- VFAT04 pair 6 (GBT4 elink 00)
        test_vfat3_rx_data_arr_o(i)(44) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(015 downto 008); -- xor x"08"; -- VFAT04 pair 7 (GBT4 elink 01)
        test_vfat3_rx_data_arr_o(i)(46) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(127 downto 120); -- xor x"15"; -- VFAT05 pair 0 (GBT4 elink 15)
        test_vfat3_rx_data_arr_o(i)(47) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(119 downto 112); -- xor x"16"; -- VFAT05 pair 1 (GBT4 elink 14)
        test_vfat3_rx_data_arr_o(i)(48) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(103 downto 096); -- xor x"17"; -- VFAT05 pair 2 (GBT4 elink 12)
        test_vfat3_rx_data_arr_o(i)(49) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(087 downto 080);-- xor x"18"; -- VFAT05 pair 3 (GBT4 elink 10)
        test_vfat3_rx_data_arr_o(i)(50) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(095 downto 088);-- xor x"19"; -- VFAT05 pair 4 (GBT4 elink 11)
        test_vfat3_rx_data_arr_o(i)(51) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(111 downto 104);-- xor x"1a"; -- VFAT05 pair 5 (GBT4 elink 13)
        test_vfat3_rx_data_arr_o(i)(52) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(159 downto 152);-- xor x"1b"; -- VFAT05 pair 6 (GBT4 elink 19)
        test_vfat3_rx_data_arr_o(i)(53) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(143 downto 136);-- xor x"1c"; -- VFAT05 pair 7 (GBT4 elink 17)
        test_vfat3_rx_data_arr_o(i)(55) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(055 downto 048);-- xor x"01"; -- VFAT06 pair 0 (GBT5 elink 06)
        test_vfat3_rx_data_arr_o(i)(56) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(063 downto 056);-- xor x"02"; -- VFAT06 pair 1 (GBT5 elink 07)
        test_vfat3_rx_data_arr_o(i)(57) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(079 downto 072);-- xor x"03"; -- VFAT06 pair 2 (GBT5 elink 09)
        test_vfat3_rx_data_arr_o(i)(58) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(039 downto 032);-- xor x"04"; -- VFAT06 pair 3 (GBT5 elink 04)
        test_vfat3_rx_data_arr_o(i)(59) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(047 downto 040);-- xor x"05"; -- VFAT06 pair 4 (GBT5 elink 05)
        test_vfat3_rx_data_arr_o(i)(60) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(023 downto 016);-- xor x"06"; -- VFAT06 pair 5 (GBT5 elink 02)
        test_vfat3_rx_data_arr_o(i)(61) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(007 downto 000);-- xor x"07"; -- VFAT06 pair 6 (GBT5 elink 00)
        test_vfat3_rx_data_arr_o(i)(62) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(015 downto 008);-- xor x"08"; -- VFAT06 pair 7 (GBT5 elink 01)
        test_vfat3_rx_data_arr_o(i)(64) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(127 downto 120);-- xor x"15"; -- VFAT07 pair 0 (GBT6 elink 15)
        test_vfat3_rx_data_arr_o(i)(65) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(119 downto 112);-- xor x"16"; -- VFAT07 pair 1 (GBT6 elink 14)
        test_vfat3_rx_data_arr_o(i)(66) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(103 downto 096);-- xor x"17"; -- VFAT07 pair 2 (GBT6 elink 12)
        test_vfat3_rx_data_arr_o(i)(67) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(087 downto 080);-- xor x"18"; -- VFAT07 pair 3 (GBT6 elink 10)
        test_vfat3_rx_data_arr_o(i)(68) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(095 downto 088);-- xor x"19"; -- VFAT07 pair 4 (GBT6 elink 11)
        test_vfat3_rx_data_arr_o(i)(69) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(111 downto 104); -- xor x"1a"; -- VFAT07 pair 5 (GBT6 elink 13)
        test_vfat3_rx_data_arr_o(i)(70) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(159 downto 152); -- xor x"1b"; -- VFAT07 pair 6 (GBT6 elink 19)
        test_vfat3_rx_data_arr_o(i)(71) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(143 downto 136); -- xor x"1c"; -- VFAT07 pair 7 (GBT6 elink 17)
        test_vfat3_rx_data_arr_o(i)(73) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(055 downto 048) xor x"01"; -- VFAT08 pair 0 (GBT0 elink 06)
        test_vfat3_rx_data_arr_o(i)(74) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(063 downto 056) xor x"02"; -- VFAT08 pair 1 (GBT0 elink 07)
        test_vfat3_rx_data_arr_o(i)(75) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(079 downto 072) xor x"03"; -- VFAT08 pair 2 (GBT0 elink 09)
        test_vfat3_rx_data_arr_o(i)(76) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(039 downto 032) xor x"04"; -- VFAT08 pair 3 (GBT0 elink 04)
        test_vfat3_rx_data_arr_o(i)(77) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(047 downto 040) xor x"05"; -- VFAT08 pair 4 (GBT0 elink 05)
        test_vfat3_rx_data_arr_o(i)(78) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(023 downto 016) xor x"06"; -- VFAT08 pair 5 (GBT0 elink 02)
        test_vfat3_rx_data_arr_o(i)(79) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(007 downto 000) xor x"07"; -- VFAT08 pair 6 (GBT0 elink 00)
        test_vfat3_rx_data_arr_o(i)(80) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(015 downto 008) xor x"08"; -- VFAT08 pair 7 (GBT0 elink 01)
        test_vfat3_rx_data_arr_o(i)(82) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(143 downto 136) xor x"1f"; -- VFAT09 pair 0 (GBT1 elink 17)
        test_vfat3_rx_data_arr_o(i)(83) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(159 downto 152) xor x"20"; -- VFAT09 pair 1 (GBT1 elink 19)
        test_vfat3_rx_data_arr_o(i)(84) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(119 downto 112) xor x"21"; -- VFAT09 pair 2 (GBT1 elink 14)
        test_vfat3_rx_data_arr_o(i)(85) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(063 downto 056) xor x"22"; -- VFAT09 pair 3 (GBT1 elink 07)
        test_vfat3_rx_data_arr_o(i)(86) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(079 downto 072) xor x"23"; -- VFAT09 pair 4 (GBT1 elink 09)
        test_vfat3_rx_data_arr_o(i)(87) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(087 downto 080) xor x"24"; -- VFAT09 pair 5 (GBT1 elink 10)
        test_vfat3_rx_data_arr_o(i)(88) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(127 downto 120) xor x"25"; -- VFAT09 pair 6 (GBT1 elink 15)
        test_vfat3_rx_data_arr_o(i)(89) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(071 downto 064) xor x"26"; -- VFAT09 pair 7 (GBT1 elink 08)
        test_vfat3_rx_data_arr_o(i)(91) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(055 downto 048); -- xor x"01"; -- VFAT10 pair 0 (GBT2 elink 06)
        test_vfat3_rx_data_arr_o(i)(92) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(063 downto 056); -- xor x"02"; -- VFAT10 pair 1 (GBT2 elink 07)
        test_vfat3_rx_data_arr_o(i)(93) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(079 downto 072); -- xor x"03"; -- VFAT10 pair 2 (GBT2 elink 09)
        test_vfat3_rx_data_arr_o(i)(94) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(039 downto 032); -- xor x"04"; -- VFAT10 pair 3 (GBT2 elink 04)
        test_vfat3_rx_data_arr_o(i)(95) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(047 downto 040); -- xor x"05"; -- VFAT10 pair 4 (GBT2 elink 05)
        test_vfat3_rx_data_arr_o(i)(96) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(023 downto 016); -- xor x"06"; -- VFAT10 pair 5 (GBT2 elink 02)
        test_vfat3_rx_data_arr_o(i)(97) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(007 downto 000); -- xor x"07"; -- VFAT10 pair 6 (GBT2 elink 00)
        test_vfat3_rx_data_arr_o(i)(98) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(015 downto 008); -- xor x"08"; -- VFAT10 pair 7 (GBT2 elink 01)
        test_vfat3_rx_data_arr_o(i)(100) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(143 downto 136); -- xor x"1f"; -- VFAT11 pair 0 (GBT3 elink 17)
        test_vfat3_rx_data_arr_o(i)(101) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(159 downto 152); -- xor x"20"; -- VFAT11 pair 1 (GBT3 elink 19)
        test_vfat3_rx_data_arr_o(i)(102) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(119 downto 112); -- xor x"21"; -- VFAT11 pair 2 (GBT3 elink 14)
        test_vfat3_rx_data_arr_o(i)(103) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(063 downto 056); -- xor x"22"; -- VFAT11 pair 3 (GBT3 elink 07)
        test_vfat3_rx_data_arr_o(i)(104) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(079 downto 072); -- xor x"23"; -- VFAT11 pair 4 (GBT3 elink 09)
        test_vfat3_rx_data_arr_o(i)(105) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(087 downto 080); -- xor x"24"; -- VFAT11 pair 5 (GBT3 elink 10)
        test_vfat3_rx_data_arr_o(i)(106) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(127 downto 120); -- xor x"25"; -- VFAT11 pair 6 (GBT3 elink 15)
        test_vfat3_rx_data_arr_o(i)(107) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(071 downto 064); -- xor x"26"; -- VFAT11 pair 7 (GBT3 elink 08)
        test_vfat3_rx_data_arr_o(i)(109) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(135 downto 128); -- xor x"29"; -- VFAT12 pair 0 (GBT4 elink 16)
        test_vfat3_rx_data_arr_o(i)(110) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(151 downto 144); -- xor x"2a"; -- VFAT12 pair 1 (GBT4 elink 18)
        test_vfat3_rx_data_arr_o(i)(111) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(167 downto 160); -- xor x"2b"; -- VFAT12 pair 2 (GBT4 elink 20)
        test_vfat3_rx_data_arr_o(i)(112) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(183 downto 176); -- xor x"2c"; -- VFAT12 pair 3 (GBT4 elink 22)
        test_vfat3_rx_data_arr_o(i)(113) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(199 downto 192); -- xor x"2d"; -- VFAT12 pair 4 (GBT4 elink 24)
        test_vfat3_rx_data_arr_o(i)(114) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(215 downto 208); -- xor x"2e"; -- VFAT12 pair 5 (GBT4 elink 26)
        test_vfat3_rx_data_arr_o(i)(115) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(175 downto 168); -- xor x"2f"; -- VFAT12 pair 6 (GBT4 elink 21)
        test_vfat3_rx_data_arr_o(i)(116) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(191 downto 184); -- xor x"30"; -- VFAT12 pair 7 (GBT4 elink 23)
        test_vfat3_rx_data_arr_o(i)(118) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(143 downto 136); -- xor x"1f"; -- VFAT13 pair 0 (GBT5 elink 17)
        test_vfat3_rx_data_arr_o(i)(119) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(159 downto 152); -- xor x"20"; -- VFAT13 pair 1 (GBT5 elink 19)
        test_vfat3_rx_data_arr_o(i)(120) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(119 downto 112); -- xor x"21"; -- VFAT13 pair 2 (GBT5 elink 14)
        test_vfat3_rx_data_arr_o(i)(121) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(063 downto 056); -- xor x"22"; -- VFAT13 pair 3 (GBT5 elink 07)
        test_vfat3_rx_data_arr_o(i)(122) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(079 downto 072); -- xor x"23"; -- VFAT13 pair 4 (GBT5 elink 09)
        test_vfat3_rx_data_arr_o(i)(123) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(087 downto 080); -- xor x"24"; -- VFAT13 pair 5 (GBT5 elink 10)
        test_vfat3_rx_data_arr_o(i)(124) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(127 downto 120); -- xor x"25"; -- VFAT13 pair 6 (GBT5 elink 15)
        test_vfat3_rx_data_arr_o(i)(125) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(071 downto 064); -- xor x"26"; -- VFAT13 pair 7 (GBT5 elink 08)
        test_vfat3_rx_data_arr_o(i)(127) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(135 downto 128); -- xor x"29"; -- VFAT14 pair 0 (GBT6 elink 16)
        test_vfat3_rx_data_arr_o(i)(128) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(151 downto 144); -- xor x"2a"; -- VFAT14 pair 1 (GBT6 elink 18)
        test_vfat3_rx_data_arr_o(i)(129) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(167 downto 160); -- xor x"2b"; -- VFAT14 pair 2 (GBT6 elink 20)
        test_vfat3_rx_data_arr_o(i)(130) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(183 downto 176); -- xor x"2c"; -- VFAT14 pair 3 (GBT6 elink 22)
        test_vfat3_rx_data_arr_o(i)(131) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(199 downto 192); -- xor x"2d"; -- VFAT14 pair 4 (GBT6 elink 24)
        test_vfat3_rx_data_arr_o(i)(132) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(215 downto 208); -- xor x"2e"; -- VFAT14 pair 5 (GBT6 elink 26)
        test_vfat3_rx_data_arr_o(i)(133) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(175 downto 168); -- xor x"2f"; -- VFAT14 pair 6 (GBT6 elink 21)
        test_vfat3_rx_data_arr_o(i)(134) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(191 downto 184); -- xor x"30"; -- VFAT14 pair 7 (GBT6 elink 23)
        test_vfat3_rx_data_arr_o(i)(136) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(143 downto 136); -- xor x"1f"; -- VFAT15 pair 0 (GBT7 elink 17)
        test_vfat3_rx_data_arr_o(i)(137) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(159 downto 152); -- xor x"20"; -- VFAT15 pair 1 (GBT7 elink 19)
        test_vfat3_rx_data_arr_o(i)(138) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(119 downto 112); -- xor x"21"; -- VFAT15 pair 2 (GBT7 elink 14)
        test_vfat3_rx_data_arr_o(i)(139) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(063 downto 056); -- xor x"22"; -- VFAT15 pair 3 (GBT7 elink 07)
        test_vfat3_rx_data_arr_o(i)(140) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(079 downto 072); -- xor x"23"; -- VFAT15 pair 4 (GBT7 elink 09)
        test_vfat3_rx_data_arr_o(i)(141) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(087 downto 080); -- xor x"24"; -- VFAT15 pair 5 (GBT7 elink 10)
        test_vfat3_rx_data_arr_o(i)(142) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(127 downto 120); -- xor x"25"; -- VFAT15 pair 6 (GBT7 elink 15)
        test_vfat3_rx_data_arr_o(i)(143) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(071 downto 064); -- xor x"26"; -- VFAT15 pair 7 (GBT7 elink 08)
        test_vfat3_rx_data_arr_o(i)(145) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(151 downto 144) xor x"0b"; -- VFAT16 pair 0 (GBT1 elink 18)
        test_vfat3_rx_data_arr_o(i)(146) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(175 downto 168) xor x"0c"; -- VFAT16 pair 1 (GBT1 elink 21)
        test_vfat3_rx_data_arr_o(i)(147) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(167 downto 160) xor x"0d"; -- VFAT16 pair 2 (GBT1 elink 20)
        test_vfat3_rx_data_arr_o(i)(148) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(191 downto 184) xor x"0e"; -- VFAT16 pair 3 (GBT1 elink 23)
        test_vfat3_rx_data_arr_o(i)(149) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(183 downto 176) xor x"0f"; -- VFAT16 pair 4 (GBT1 elink 22)
        test_vfat3_rx_data_arr_o(i)(150) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(223 downto 216) xor x"10"; -- VFAT16 pair 5 (GBT1 elink 27)
        test_vfat3_rx_data_arr_o(i)(151) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(215 downto 208) xor x"11"; -- VFAT16 pair 6 (GBT1 elink 26)
        test_vfat3_rx_data_arr_o(i)(152) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(207 downto 200) xor x"12"; -- VFAT16 pair 7 (GBT1 elink 25)
        test_vfat3_rx_data_arr_o(i)(154) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(031 downto 024) xor x"33"; -- VFAT17 pair 0 (GBT1 elink 03)
        test_vfat3_rx_data_arr_o(i)(155) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(111 downto 104) xor x"34"; -- VFAT17 pair 1 (GBT1 elink 13)
        test_vfat3_rx_data_arr_o(i)(156) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(047 downto 040) xor x"35"; -- VFAT17 pair 2 (GBT1 elink 05)
        test_vfat3_rx_data_arr_o(i)(157) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(015 downto 008) xor x"36"; -- VFAT17 pair 3 (GBT1 elink 01)
        test_vfat3_rx_data_arr_o(i)(158) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(007 downto 000) xor x"37"; -- VFAT17 pair 4 (GBT1 elink 00)
        test_vfat3_rx_data_arr_o(i)(159) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(023 downto 016) xor x"38"; -- VFAT17 pair 5 (GBT1 elink 02)
        test_vfat3_rx_data_arr_o(i)(160) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(103 downto 096) xor x"39"; -- VFAT17 pair 6 (GBT1 elink 12)
        test_vfat3_rx_data_arr_o(i)(161) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(039 downto 032) xor x"3a"; -- VFAT17 pair 7 (GBT1 elink 04)
        test_vfat3_rx_data_arr_o(i)(163) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(151 downto 144); -- xor x"0b"; -- VFAT18 pair 0 (GBT3 elink 18)
        test_vfat3_rx_data_arr_o(i)(164) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(175 downto 168); -- xor x"0c"; -- VFAT18 pair 1 (GBT3 elink 21)
        test_vfat3_rx_data_arr_o(i)(165) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(167 downto 160); -- xor x"0d"; -- VFAT18 pair 2 (GBT3 elink 20)
        test_vfat3_rx_data_arr_o(i)(166) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(191 downto 184); -- xor x"0e"; -- VFAT18 pair 3 (GBT3 elink 23)
        test_vfat3_rx_data_arr_o(i)(167) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(183 downto 176); -- xor x"0f"; -- VFAT18 pair 4 (GBT3 elink 22)
        test_vfat3_rx_data_arr_o(i)(168) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(223 downto 216); -- xor x"10"; -- VFAT18 pair 5 (GBT3 elink 27)
        test_vfat3_rx_data_arr_o(i)(169) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(215 downto 208); -- xor x"11"; -- VFAT18 pair 6 (GBT3 elink 26)
        test_vfat3_rx_data_arr_o(i)(170) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(207 downto 200); -- xor x"12"; -- VFAT18 pair 7 (GBT3 elink 25)
        test_vfat3_rx_data_arr_o(i)(172) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(031 downto 024); -- xor x"33"; -- VFAT19 pair 0 (GBT3 elink 03)
        test_vfat3_rx_data_arr_o(i)(173) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(111 downto 104); -- xor x"34"; -- VFAT19 pair 1 (GBT3 elink 13)
        test_vfat3_rx_data_arr_o(i)(174) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(047 downto 040); -- xor x"35"; -- VFAT19 pair 2 (GBT3 elink 05)
        test_vfat3_rx_data_arr_o(i)(175) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(015 downto 008); -- xor x"36"; -- VFAT19 pair 3 (GBT3 elink 01)
        test_vfat3_rx_data_arr_o(i)(176) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(007 downto 000); -- xor x"37"; -- VFAT19 pair 4 (GBT3 elink 00)
        test_vfat3_rx_data_arr_o(i)(177) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(023 downto 016); -- xor x"38"; -- VFAT19 pair 5 (GBT3 elink 02)
        test_vfat3_rx_data_arr_o(i)(178) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(103 downto 096); -- xor x"39"; -- VFAT19 pair 6 (GBT3 elink 12)
        test_vfat3_rx_data_arr_o(i)(179) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(039 downto 032); -- xor x"3a"; -- VFAT19 pair 7 (GBT3 elink 04)
        test_vfat3_rx_data_arr_o(i)(181) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(151 downto 144); -- xor x"0b"; -- VFAT20 pair 0 (GBT5 elink 18)
        test_vfat3_rx_data_arr_o(i)(182) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(175 downto 168); -- xor x"0c"; -- VFAT20 pair 1 (GBT5 elink 21)
        test_vfat3_rx_data_arr_o(i)(183) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(167 downto 160); -- xor x"0d"; -- VFAT20 pair 2 (GBT5 elink 20)
        test_vfat3_rx_data_arr_o(i)(184) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(191 downto 184); -- xor x"0e"; -- VFAT20 pair 3 (GBT5 elink 23)
        test_vfat3_rx_data_arr_o(i)(185) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(183 downto 176); -- xor x"0f"; -- VFAT20 pair 4 (GBT5 elink 22)
        test_vfat3_rx_data_arr_o(i)(186) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(223 downto 216); -- xor x"10"; -- VFAT20 pair 5 (GBT5 elink 27)
        test_vfat3_rx_data_arr_o(i)(187) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(215 downto 208); -- xor x"11"; -- VFAT20 pair 6 (GBT5 elink 26)
        test_vfat3_rx_data_arr_o(i)(188) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(207 downto 200); -- xor x"12"; -- VFAT20 pair 7 (GBT5 elink 25)
        test_vfat3_rx_data_arr_o(i)(190) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(031 downto 024); -- xor x"33"; -- VFAT21 pair 0 (GBT5 elink 03)
        test_vfat3_rx_data_arr_o(i)(191) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(111 downto 104); -- xor x"34"; -- VFAT21 pair 1 (GBT5 elink 13)
        test_vfat3_rx_data_arr_o(i)(192) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(047 downto 040); -- xor x"35"; -- VFAT21 pair 2 (GBT5 elink 05)
        test_vfat3_rx_data_arr_o(i)(193) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(015 downto 008); -- xor x"36"; -- VFAT21 pair 3 (GBT5 elink 01)
        test_vfat3_rx_data_arr_o(i)(194) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(007 downto 000); -- xor x"37"; -- VFAT21 pair 4 (GBT5 elink 00)
        test_vfat3_rx_data_arr_o(i)(195) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(023 downto 016); -- xor x"38"; -- VFAT21 pair 5 (GBT5 elink 02)
        test_vfat3_rx_data_arr_o(i)(196) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(103 downto 096); -- xor x"39"; -- VFAT21 pair 6 (GBT5 elink 12)
        test_vfat3_rx_data_arr_o(i)(197) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(039 downto 032); -- xor x"3a"; -- VFAT21 pair 7 (GBT5 elink 04)
        test_vfat3_rx_data_arr_o(i)(199) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(151 downto 144); -- xor x"0b"; -- VFAT22 pair 0 (GBT7 elink 18)
        test_vfat3_rx_data_arr_o(i)(200) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(175 downto 168); -- xor x"0c"; -- VFAT22 pair 1 (GBT7 elink 21)
        test_vfat3_rx_data_arr_o(i)(201) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(167 downto 160); -- xor x"0d"; -- VFAT22 pair 2 (GBT7 elink 20)
        test_vfat3_rx_data_arr_o(i)(202) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(191 downto 184); -- xor x"0e"; -- VFAT22 pair 3 (GBT7 elink 23)
        test_vfat3_rx_data_arr_o(i)(203) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(183 downto 176); -- xor x"0f"; -- VFAT22 pair 4 (GBT7 elink 22)
        test_vfat3_rx_data_arr_o(i)(204) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(223 downto 216); -- xor x"10"; -- VFAT22 pair 5 (GBT7 elink 27)
        test_vfat3_rx_data_arr_o(i)(205) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(215 downto 208); -- xor x"11"; -- VFAT22 pair 6 (GBT7 elink 26)
        test_vfat3_rx_data_arr_o(i)(206) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(207 downto 200); -- xor x"12"; -- VFAT22 pair 7 (GBT7 elink 25)
        test_vfat3_rx_data_arr_o(i)(208) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(031 downto 024); -- xor x"33"; -- VFAT23 pair 0 (GBT7 elink 03)
        test_vfat3_rx_data_arr_o(i)(209) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(111 downto 104); -- xor x"34"; -- VFAT23 pair 1 (GBT7 elink 13)
        test_vfat3_rx_data_arr_o(i)(210) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(047 downto 040); -- xor x"35"; -- VFAT23 pair 2 (GBT7 elink 05)
        test_vfat3_rx_data_arr_o(i)(211) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(015 downto 008); -- xor x"36"; -- VFAT23 pair 3 (GBT7 elink 01)
        test_vfat3_rx_data_arr_o(i)(212) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(007 downto 000); -- xor x"37"; -- VFAT23 pair 4 (GBT7 elink 00)
        test_vfat3_rx_data_arr_o(i)(213) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(023 downto 016); -- xor x"38"; -- VFAT23 pair 5 (GBT7 elink 02)
        test_vfat3_rx_data_arr_o(i)(214) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(103 downto 096); -- xor x"39"; -- VFAT23 pair 6 (GBT7 elink 12)
        test_vfat3_rx_data_arr_o(i)(215) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(039 downto 032); -- xor x"3a"; -- VFAT23 pair 7 (GBT7 elink 04)


    --======================================================--
    --========================= TX =========================--
    --======================================================--

        -- IC
        gbt_tx_data_arr(i * 8 + 0).tx_ic_data <= gbt_ic_tx_data_arr_i(i * 8 + 0)(0) & gbt_ic_tx_data_arr_i(i * 8 + 0)(1); -- GBT0 (master); bits reversed
        gbt_tx_data_arr(i * 8 + 0).tx_ec_data <= gbt_ic_tx_data_arr_i(i * 8 + 1)(0) & gbt_ic_tx_data_arr_i(i * 8 + 1)(1); -- GBT1 (slave); bits reversed
        gbt_tx_data_arr(i * 8 + 2).tx_ic_data <= gbt_ic_tx_data_arr_i(i * 8 + 2)(0) & gbt_ic_tx_data_arr_i(i * 8 + 2)(1); -- GBT2 (master); bits reversed
        gbt_tx_data_arr(i * 8 + 2).tx_ec_data <= gbt_ic_tx_data_arr_i(i * 8 + 3)(0) & gbt_ic_tx_data_arr_i(i * 8 + 3)(1); -- GBT3 (slave); bits reversed
        gbt_tx_data_arr(i * 8 + 4).tx_ic_data <= gbt_ic_tx_data_arr_i(i * 8 + 4)(0) & gbt_ic_tx_data_arr_i(i * 8 + 4)(1); -- GBT4 (master); bits reversed
        gbt_tx_data_arr(i * 8 + 4).tx_ec_data <= gbt_ic_tx_data_arr_i(i * 8 + 5)(0) & gbt_ic_tx_data_arr_i(i * 8 + 5)(1); -- GBT5 (slave); bits reversed
        gbt_tx_data_arr(i * 8 + 6).tx_ic_data <= gbt_ic_tx_data_arr_i(i * 8 + 6)(0) & gbt_ic_tx_data_arr_i(i * 8 + 6)(1); -- GBT6 (master); bits reversed
        gbt_tx_data_arr(i * 8 + 6).tx_ec_data <= gbt_ic_tx_data_arr_i(i * 8 + 7)(0) & gbt_ic_tx_data_arr_i(i * 8 + 7)(1); -- GBT7 (slave); bits reversed

        --==================== QUESO TEST TX ====================--
        -- VFAT control (send prbs7 to all vfats)
        gbt_tx_data_arr(i * 8 + 0).tx_data(07 downto 00) <= test_vfat3_tx_data_arr_i; -- GBT0 tx elink 00: VFAT9 & VFAT17
        gbt_tx_data_arr(i * 8 + 0).tx_data(15 downto 08) <= test_vfat3_tx_data_arr_i; -- GBT0 tx elink 01: VFAT8 & VFAT16
        gbt_tx_data_arr(i * 8 + 0).tx_data(23 downto 16) <= test_vfat3_tx_data_arr_i; -- GBT0 tx elink 02: VFAT1 & VFAT00
        gbt_tx_data_arr(i * 8 + 0).tx_data(31 downto 24) <= (others => '0'); -- GBT0 tx elink 03 is not connected
        gbt_tx_data_arr(i * 8 + 2).tx_data(07 downto 00) <= test_vfat3_tx_data_arr_i; -- GBT2 tx elink 00: VFAT11 & VFAT19
        gbt_tx_data_arr(i * 8 + 2).tx_data(15 downto 08) <= test_vfat3_tx_data_arr_i; -- GBT2 tx elink 01: VFAT10 & VFAT18
        gbt_tx_data_arr(i * 8 + 2).tx_data(23 downto 16) <= test_vfat3_tx_data_arr_i; -- GBT2 tx elink 02: VFAT3 & VFAT02
        gbt_tx_data_arr(i * 8 + 2).tx_data(31 downto 24) <= (others => '0'); -- GBT2 tx elink 03 is not connected
        gbt_tx_data_arr(i * 8 + 4).tx_data(07 downto 00) <= test_vfat3_tx_data_arr_i; -- GBT4 tx elink 00: VFAT13 & VFAT21
        gbt_tx_data_arr(i * 8 + 4).tx_data(15 downto 08) <= test_vfat3_tx_data_arr_i; -- GBT4 tx elink 01: VFAT4 & VFAT20
        gbt_tx_data_arr(i * 8 + 4).tx_data(23 downto 16) <= test_vfat3_tx_data_arr_i; -- GBT4 tx elink 02: VFAT5 & VFAT12
        gbt_tx_data_arr(i * 8 + 4).tx_data(31 downto 24) <= (others => '0'); -- GBT4 tx elink 03 is not connected
        gbt_tx_data_arr(i * 8 + 6).tx_data(07 downto 00) <= test_vfat3_tx_data_arr_i; -- GBT6 tx elink 00: VFAT15 & VFAT23
        gbt_tx_data_arr(i * 8 + 6).tx_data(15 downto 08) <= test_vfat3_tx_data_arr_i; -- GBT6 tx elink 01: VFAT6 & VFAT22
        gbt_tx_data_arr(i * 8 + 6).tx_data(23 downto 16) <= test_vfat3_tx_data_arr_i; -- GBT6 tx elink 02: VFAT7 & VFAT14
        gbt_tx_data_arr(i * 8 + 6).tx_data(31 downto 24) <= (others => '0'); -- GBT6 tx elink 03 is not connected

        -- Repeat the same data on the second transmitter (unused)
        gbt_tx_data_arr(i * 8 + 1) <= gbt_tx_data_arr(i * 8 + 0); -- GBT1
        gbt_tx_data_arr(i * 8 + 3) <= gbt_tx_data_arr(i * 8 + 2); -- GBT3
        gbt_tx_data_arr(i * 8 + 5) <= gbt_tx_data_arr(i * 8 + 4); -- GBT5
        gbt_tx_data_arr(i * 8 + 7) <= gbt_tx_data_arr(i * 8 + 6); -- GBT7 
        
    end generate;
    
end gbt_link_mux_me0_queso_arch;
