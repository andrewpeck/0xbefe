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

entity gbt_link_mux_me0 is
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
        vfat3_gbt_ready_arr_o       : out t_std24_array(g_NUM_OF_OHs - 1 downto 0)
    );
end gbt_link_mux_me0;

architecture gbt_link_mux_me0_arch of gbt_link_mux_me0 is

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

        -- DAQ
        vfat3_rx_data_arr_o(i)(00) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(207 downto 200); -- VFAT00 (GBT0 elink 25)
        vfat3_rx_data_arr_o(i)(01) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(223 downto 216); -- VFAT01 (GBT0 elink 27)
        vfat3_rx_data_arr_o(i)(02) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(207 downto 200); -- VFAT02 (GBT2 elink 25)
        vfat3_rx_data_arr_o(i)(03) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(223 downto 216); -- VFAT03 (GBT2 elink 27)
        vfat3_rx_data_arr_o(i)(04) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(031 downto 024); -- VFAT04 (GBT4 elink 03)
        vfat3_rx_data_arr_o(i)(05) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(223 downto 216); -- VFAT05 (GBT4 elink 27)
        vfat3_rx_data_arr_o(i)(06) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(031 downto 024); -- VFAT06 (GBT6 elink 03)
        vfat3_rx_data_arr_o(i)(07) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(223 downto 216); -- VFAT07 (GBT6 elink 27)
        vfat3_rx_data_arr_o(i)(08) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(031 downto 024); -- VFAT08 (GBT0 elink 03)
        vfat3_rx_data_arr_o(i)(09) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(095 downto 088); -- VFAT09 (GBT1 elink 11)
        vfat3_rx_data_arr_o(i)(10) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(031 downto 024); -- VFAT10 (GBT2 elink 03)
        vfat3_rx_data_arr_o(i)(11) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(095 downto 088); -- VFAT11 (GBT3 elink 11)
        vfat3_rx_data_arr_o(i)(12) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(207 downto 200); -- VFAT12 (GBT4 elink 25)
        vfat3_rx_data_arr_o(i)(13) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(095 downto 088); -- VFAT13 (GBT5 elink 11)
        vfat3_rx_data_arr_o(i)(14) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(207 downto 200); -- VFAT14 (GBT6 elink 25)
        vfat3_rx_data_arr_o(i)(15) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(095 downto 088); -- VFAT15 (GBT7 elink 11)
        vfat3_rx_data_arr_o(i)(16) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(199 downto 192); -- VFAT16 (GBT1 elink 24)
        vfat3_rx_data_arr_o(i)(17) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(055 downto 048); -- VFAT17 (GBT1 elink 06)
        vfat3_rx_data_arr_o(i)(18) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(199 downto 192); -- VFAT18 (GBT3 elink 24)
        vfat3_rx_data_arr_o(i)(19) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(055 downto 048); -- VFAT19 (GBT3 elink 06)
        vfat3_rx_data_arr_o(i)(20) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(199 downto 192); -- VFAT20 (GBT5 elink 24)
        vfat3_rx_data_arr_o(i)(21) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(055 downto 048); -- VFAT21 (GBT5 elink 06)
        vfat3_rx_data_arr_o(i)(22) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(199 downto 192); -- VFAT22 (GBT7 elink 24)
        vfat3_rx_data_arr_o(i)(23) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(055 downto 048); -- VFAT23 (GBT7 elink 06)

        -- SBITS
        vfat3_sbits_arr_o(i)(00)(07 downto 00) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(135 downto 128); -- VFAT00 pair 0 (GBT0 elink 16)
        vfat3_sbits_arr_o(i)(00)(15 downto 08) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(151 downto 144); -- VFAT00 pair 1 (GBT0 elink 18)
        vfat3_sbits_arr_o(i)(00)(23 downto 16) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(167 downto 160); -- VFAT00 pair 2 (GBT0 elink 20)
        vfat3_sbits_arr_o(i)(00)(31 downto 24) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(183 downto 176); -- VFAT00 pair 3 (GBT0 elink 22)
        vfat3_sbits_arr_o(i)(00)(39 downto 32) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(199 downto 192); -- VFAT00 pair 4 (GBT0 elink 24)
        vfat3_sbits_arr_o(i)(00)(47 downto 40) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(215 downto 208); -- VFAT00 pair 5 (GBT0 elink 26)
        vfat3_sbits_arr_o(i)(00)(55 downto 48) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(175 downto 168); -- VFAT00 pair 6 (GBT0 elink 21)
        vfat3_sbits_arr_o(i)(00)(63 downto 56) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(191 downto 184); -- VFAT00 pair 7 (GBT0 elink 23)
        vfat3_sbits_arr_o(i)(01)(07 downto 00) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(127 downto 120); -- VFAT01 pair 0 (GBT0 elink 15)
        vfat3_sbits_arr_o(i)(01)(15 downto 08) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(119 downto 112); -- VFAT01 pair 1 (GBT0 elink 14)
        vfat3_sbits_arr_o(i)(01)(23 downto 16) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(103 downto 096); -- VFAT01 pair 2 (GBT0 elink 12)
        vfat3_sbits_arr_o(i)(01)(31 downto 24) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(087 downto 080); -- VFAT01 pair 3 (GBT0 elink 10)
        vfat3_sbits_arr_o(i)(01)(39 downto 32) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(095 downto 088); -- VFAT01 pair 4 (GBT0 elink 11)
        vfat3_sbits_arr_o(i)(01)(47 downto 40) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(111 downto 104); -- VFAT01 pair 5 (GBT0 elink 13)
        vfat3_sbits_arr_o(i)(01)(55 downto 48) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(159 downto 152); -- VFAT01 pair 6 (GBT0 elink 19)
        vfat3_sbits_arr_o(i)(01)(63 downto 56) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(143 downto 136); -- VFAT01 pair 7 (GBT0 elink 17)
        vfat3_sbits_arr_o(i)(02)(07 downto 00) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(135 downto 128); -- VFAT02 pair 0 (GBT2 elink 16)
        vfat3_sbits_arr_o(i)(02)(15 downto 08) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(151 downto 144); -- VFAT02 pair 1 (GBT2 elink 18)
        vfat3_sbits_arr_o(i)(02)(23 downto 16) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(167 downto 160); -- VFAT02 pair 2 (GBT2 elink 20)
        vfat3_sbits_arr_o(i)(02)(31 downto 24) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(183 downto 176); -- VFAT02 pair 3 (GBT2 elink 22)
        vfat3_sbits_arr_o(i)(02)(39 downto 32) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(199 downto 192); -- VFAT02 pair 4 (GBT2 elink 24)
        vfat3_sbits_arr_o(i)(02)(47 downto 40) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(215 downto 208); -- VFAT02 pair 5 (GBT2 elink 26)
        vfat3_sbits_arr_o(i)(02)(55 downto 48) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(175 downto 168); -- VFAT02 pair 6 (GBT2 elink 21)
        vfat3_sbits_arr_o(i)(02)(63 downto 56) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(191 downto 184); -- VFAT02 pair 7 (GBT2 elink 23)
        vfat3_sbits_arr_o(i)(03)(07 downto 00) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(127 downto 120); -- VFAT03 pair 0 (GBT2 elink 15)
        vfat3_sbits_arr_o(i)(03)(15 downto 08) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(119 downto 112); -- VFAT03 pair 1 (GBT2 elink 14)
        vfat3_sbits_arr_o(i)(03)(23 downto 16) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(103 downto 096); -- VFAT03 pair 2 (GBT2 elink 12)
        vfat3_sbits_arr_o(i)(03)(31 downto 24) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(087 downto 080); -- VFAT03 pair 3 (GBT2 elink 10)
        vfat3_sbits_arr_o(i)(03)(39 downto 32) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(095 downto 088); -- VFAT03 pair 4 (GBT2 elink 11)
        vfat3_sbits_arr_o(i)(03)(47 downto 40) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(111 downto 104); -- VFAT03 pair 5 (GBT2 elink 13)
        vfat3_sbits_arr_o(i)(03)(55 downto 48) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(159 downto 152); -- VFAT03 pair 6 (GBT2 elink 19)
        vfat3_sbits_arr_o(i)(03)(63 downto 56) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(143 downto 136); -- VFAT03 pair 7 (GBT2 elink 17)
        vfat3_sbits_arr_o(i)(04)(07 downto 00) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(055 downto 048); -- VFAT04 pair 0 (GBT4 elink 06)
        vfat3_sbits_arr_o(i)(04)(15 downto 08) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(063 downto 056); -- VFAT04 pair 1 (GBT4 elink 07)
        vfat3_sbits_arr_o(i)(04)(23 downto 16) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(079 downto 072); -- VFAT04 pair 2 (GBT4 elink 09)
        vfat3_sbits_arr_o(i)(04)(31 downto 24) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(039 downto 032); -- VFAT04 pair 3 (GBT4 elink 04)
        vfat3_sbits_arr_o(i)(04)(39 downto 32) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(047 downto 040); -- VFAT04 pair 4 (GBT4 elink 05)
        vfat3_sbits_arr_o(i)(04)(47 downto 40) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(023 downto 016); -- VFAT04 pair 5 (GBT4 elink 02)
        vfat3_sbits_arr_o(i)(04)(55 downto 48) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(007 downto 000); -- VFAT04 pair 6 (GBT4 elink 00)
        vfat3_sbits_arr_o(i)(04)(63 downto 56) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(015 downto 008); -- VFAT04 pair 7 (GBT4 elink 01)
        vfat3_sbits_arr_o(i)(05)(07 downto 00) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(127 downto 120); -- VFAT05 pair 0 (GBT4 elink 15)
        vfat3_sbits_arr_o(i)(05)(15 downto 08) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(119 downto 112); -- VFAT05 pair 1 (GBT4 elink 14)
        vfat3_sbits_arr_o(i)(05)(23 downto 16) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(103 downto 096); -- VFAT05 pair 2 (GBT4 elink 12)
        vfat3_sbits_arr_o(i)(05)(31 downto 24) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(087 downto 080); -- VFAT05 pair 3 (GBT4 elink 10)
        vfat3_sbits_arr_o(i)(05)(39 downto 32) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(095 downto 088); -- VFAT05 pair 4 (GBT4 elink 11)
        vfat3_sbits_arr_o(i)(05)(47 downto 40) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(111 downto 104); -- VFAT05 pair 5 (GBT4 elink 13)
        vfat3_sbits_arr_o(i)(05)(55 downto 48) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(159 downto 152); -- VFAT05 pair 6 (GBT4 elink 19)
        vfat3_sbits_arr_o(i)(05)(63 downto 56) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(143 downto 136); -- VFAT05 pair 7 (GBT4 elink 17)
        vfat3_sbits_arr_o(i)(06)(07 downto 00) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(055 downto 048); -- VFAT06 pair 0 (GBT6 elink 06)
        vfat3_sbits_arr_o(i)(06)(15 downto 08) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(063 downto 056); -- VFAT06 pair 1 (GBT6 elink 07)
        vfat3_sbits_arr_o(i)(06)(23 downto 16) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(079 downto 072); -- VFAT06 pair 2 (GBT6 elink 09)
        vfat3_sbits_arr_o(i)(06)(31 downto 24) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(039 downto 032); -- VFAT06 pair 3 (GBT6 elink 04)
        vfat3_sbits_arr_o(i)(06)(39 downto 32) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(047 downto 040); -- VFAT06 pair 4 (GBT6 elink 05)
        vfat3_sbits_arr_o(i)(06)(47 downto 40) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(023 downto 016); -- VFAT06 pair 5 (GBT6 elink 02)
        vfat3_sbits_arr_o(i)(06)(55 downto 48) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(007 downto 000); -- VFAT06 pair 6 (GBT6 elink 00)
        vfat3_sbits_arr_o(i)(06)(63 downto 56) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(015 downto 008); -- VFAT06 pair 7 (GBT6 elink 01)
        vfat3_sbits_arr_o(i)(07)(07 downto 00) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(127 downto 120); -- VFAT07 pair 0 (GBT6 elink 15)
        vfat3_sbits_arr_o(i)(07)(15 downto 08) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(119 downto 112); -- VFAT07 pair 1 (GBT6 elink 14)
        vfat3_sbits_arr_o(i)(07)(23 downto 16) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(103 downto 096); -- VFAT07 pair 2 (GBT6 elink 12)
        vfat3_sbits_arr_o(i)(07)(31 downto 24) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(087 downto 080); -- VFAT07 pair 3 (GBT6 elink 10)
        vfat3_sbits_arr_o(i)(07)(39 downto 32) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(095 downto 088); -- VFAT07 pair 4 (GBT6 elink 11)
        vfat3_sbits_arr_o(i)(07)(47 downto 40) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(111 downto 104); -- VFAT07 pair 5 (GBT6 elink 13)
        vfat3_sbits_arr_o(i)(07)(55 downto 48) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(159 downto 152); -- VFAT07 pair 6 (GBT6 elink 19)
        vfat3_sbits_arr_o(i)(07)(63 downto 56) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(143 downto 136); -- VFAT07 pair 7 (GBT6 elink 17)
        vfat3_sbits_arr_o(i)(08)(07 downto 00) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(055 downto 048); -- VFAT08 pair 0 (GBT0 elink 06)
        vfat3_sbits_arr_o(i)(08)(15 downto 08) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(063 downto 056); -- VFAT08 pair 1 (GBT0 elink 07)
        vfat3_sbits_arr_o(i)(08)(23 downto 16) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(079 downto 072); -- VFAT08 pair 2 (GBT0 elink 09)
        vfat3_sbits_arr_o(i)(08)(31 downto 24) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(039 downto 032); -- VFAT08 pair 3 (GBT0 elink 04)
        vfat3_sbits_arr_o(i)(08)(39 downto 32) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(047 downto 040); -- VFAT08 pair 4 (GBT0 elink 05)
        vfat3_sbits_arr_o(i)(08)(47 downto 40) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(023 downto 016); -- VFAT08 pair 5 (GBT0 elink 02)
        vfat3_sbits_arr_o(i)(08)(55 downto 48) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(007 downto 000); -- VFAT08 pair 6 (GBT0 elink 00)
        vfat3_sbits_arr_o(i)(08)(63 downto 56) <= gbt_rx_data_arr_i(i * 8 + 0).rx_data(015 downto 008); -- VFAT08 pair 7 (GBT0 elink 01)
        vfat3_sbits_arr_o(i)(09)(07 downto 00) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(143 downto 136); -- VFAT09 pair 0 (GBT1 elink 17)
        vfat3_sbits_arr_o(i)(09)(15 downto 08) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(159 downto 152); -- VFAT09 pair 1 (GBT1 elink 19)
        vfat3_sbits_arr_o(i)(09)(23 downto 16) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(119 downto 112); -- VFAT09 pair 2 (GBT1 elink 14)
        vfat3_sbits_arr_o(i)(09)(31 downto 24) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(063 downto 056); -- VFAT09 pair 3 (GBT1 elink 07)
        vfat3_sbits_arr_o(i)(09)(39 downto 32) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(079 downto 072); -- VFAT09 pair 4 (GBT1 elink 09)
        vfat3_sbits_arr_o(i)(09)(47 downto 40) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(087 downto 080); -- VFAT09 pair 5 (GBT1 elink 10)
        vfat3_sbits_arr_o(i)(09)(55 downto 48) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(127 downto 120); -- VFAT09 pair 6 (GBT1 elink 15)
        vfat3_sbits_arr_o(i)(09)(63 downto 56) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(071 downto 064); -- VFAT09 pair 7 (GBT1 elink 08)
        vfat3_sbits_arr_o(i)(10)(07 downto 00) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(055 downto 048); -- VFAT10 pair 0 (GBT2 elink 06)
        vfat3_sbits_arr_o(i)(10)(15 downto 08) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(063 downto 056); -- VFAT10 pair 1 (GBT2 elink 07)
        vfat3_sbits_arr_o(i)(10)(23 downto 16) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(079 downto 072); -- VFAT10 pair 2 (GBT2 elink 09)
        vfat3_sbits_arr_o(i)(10)(31 downto 24) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(039 downto 032); -- VFAT10 pair 3 (GBT2 elink 04)
        vfat3_sbits_arr_o(i)(10)(39 downto 32) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(047 downto 040); -- VFAT10 pair 4 (GBT2 elink 05)
        vfat3_sbits_arr_o(i)(10)(47 downto 40) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(023 downto 016); -- VFAT10 pair 5 (GBT2 elink 02)
        vfat3_sbits_arr_o(i)(10)(55 downto 48) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(007 downto 000); -- VFAT10 pair 6 (GBT2 elink 00)
        vfat3_sbits_arr_o(i)(10)(63 downto 56) <= gbt_rx_data_arr_i(i * 8 + 2).rx_data(015 downto 008); -- VFAT10 pair 7 (GBT2 elink 01)
        vfat3_sbits_arr_o(i)(11)(07 downto 00) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(143 downto 136); -- VFAT11 pair 0 (GBT3 elink 17)
        vfat3_sbits_arr_o(i)(11)(15 downto 08) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(159 downto 152); -- VFAT11 pair 1 (GBT3 elink 19)
        vfat3_sbits_arr_o(i)(11)(23 downto 16) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(119 downto 112); -- VFAT11 pair 2 (GBT3 elink 14)
        vfat3_sbits_arr_o(i)(11)(31 downto 24) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(063 downto 056); -- VFAT11 pair 3 (GBT3 elink 07)
        vfat3_sbits_arr_o(i)(11)(39 downto 32) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(079 downto 072); -- VFAT11 pair 4 (GBT3 elink 09)
        vfat3_sbits_arr_o(i)(11)(47 downto 40) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(087 downto 080); -- VFAT11 pair 5 (GBT3 elink 10)
        vfat3_sbits_arr_o(i)(11)(55 downto 48) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(127 downto 120); -- VFAT11 pair 6 (GBT3 elink 15)
        vfat3_sbits_arr_o(i)(11)(63 downto 56) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(071 downto 064); -- VFAT11 pair 7 (GBT3 elink 08)
        vfat3_sbits_arr_o(i)(12)(07 downto 00) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(135 downto 128); -- VFAT12 pair 0 (GBT4 elink 16)
        vfat3_sbits_arr_o(i)(12)(15 downto 08) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(151 downto 144); -- VFAT12 pair 1 (GBT4 elink 18)
        vfat3_sbits_arr_o(i)(12)(23 downto 16) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(167 downto 160); -- VFAT12 pair 2 (GBT4 elink 20)
        vfat3_sbits_arr_o(i)(12)(31 downto 24) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(183 downto 176); -- VFAT12 pair 3 (GBT4 elink 22)
        vfat3_sbits_arr_o(i)(12)(39 downto 32) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(199 downto 192); -- VFAT12 pair 4 (GBT4 elink 24)
        vfat3_sbits_arr_o(i)(12)(47 downto 40) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(215 downto 208); -- VFAT12 pair 5 (GBT4 elink 26)
        vfat3_sbits_arr_o(i)(12)(55 downto 48) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(175 downto 168); -- VFAT12 pair 6 (GBT4 elink 21)
        vfat3_sbits_arr_o(i)(12)(63 downto 56) <= gbt_rx_data_arr_i(i * 8 + 4).rx_data(191 downto 184); -- VFAT12 pair 7 (GBT4 elink 23)
        vfat3_sbits_arr_o(i)(13)(07 downto 00) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(143 downto 136); -- VFAT13 pair 0 (GBT5 elink 17)
        vfat3_sbits_arr_o(i)(13)(15 downto 08) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(159 downto 152); -- VFAT13 pair 1 (GBT5 elink 19)
        vfat3_sbits_arr_o(i)(13)(23 downto 16) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(119 downto 112); -- VFAT13 pair 2 (GBT5 elink 14)
        vfat3_sbits_arr_o(i)(13)(31 downto 24) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(063 downto 056); -- VFAT13 pair 3 (GBT5 elink 07)
        vfat3_sbits_arr_o(i)(13)(39 downto 32) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(079 downto 072); -- VFAT13 pair 4 (GBT5 elink 09)
        vfat3_sbits_arr_o(i)(13)(47 downto 40) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(087 downto 080); -- VFAT13 pair 5 (GBT5 elink 10)
        vfat3_sbits_arr_o(i)(13)(55 downto 48) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(127 downto 120); -- VFAT13 pair 6 (GBT5 elink 15)
        vfat3_sbits_arr_o(i)(13)(63 downto 56) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(071 downto 064); -- VFAT13 pair 7 (GBT5 elink 08)
        vfat3_sbits_arr_o(i)(14)(07 downto 00) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(135 downto 128); -- VFAT14 pair 0 (GBT6 elink 16)
        vfat3_sbits_arr_o(i)(14)(15 downto 08) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(151 downto 144); -- VFAT14 pair 1 (GBT6 elink 18)
        vfat3_sbits_arr_o(i)(14)(23 downto 16) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(167 downto 160); -- VFAT14 pair 2 (GBT6 elink 20)
        vfat3_sbits_arr_o(i)(14)(31 downto 24) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(183 downto 176); -- VFAT14 pair 3 (GBT6 elink 22)
        vfat3_sbits_arr_o(i)(14)(39 downto 32) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(199 downto 192); -- VFAT14 pair 4 (GBT6 elink 24)
        vfat3_sbits_arr_o(i)(14)(47 downto 40) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(215 downto 208); -- VFAT14 pair 5 (GBT6 elink 26)
        vfat3_sbits_arr_o(i)(14)(55 downto 48) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(175 downto 168); -- VFAT14 pair 6 (GBT6 elink 21)
        vfat3_sbits_arr_o(i)(14)(63 downto 56) <= gbt_rx_data_arr_i(i * 8 + 6).rx_data(191 downto 184); -- VFAT14 pair 7 (GBT6 elink 23)
        vfat3_sbits_arr_o(i)(15)(07 downto 00) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(143 downto 136); -- VFAT15 pair 0 (GBT7 elink 17)
        vfat3_sbits_arr_o(i)(15)(15 downto 08) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(159 downto 152); -- VFAT15 pair 1 (GBT7 elink 19)
        vfat3_sbits_arr_o(i)(15)(23 downto 16) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(119 downto 112); -- VFAT15 pair 2 (GBT7 elink 14)
        vfat3_sbits_arr_o(i)(15)(31 downto 24) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(063 downto 056); -- VFAT15 pair 3 (GBT7 elink 07)
        vfat3_sbits_arr_o(i)(15)(39 downto 32) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(079 downto 072); -- VFAT15 pair 4 (GBT7 elink 09)
        vfat3_sbits_arr_o(i)(15)(47 downto 40) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(087 downto 080); -- VFAT15 pair 5 (GBT7 elink 10)
        vfat3_sbits_arr_o(i)(15)(55 downto 48) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(127 downto 120); -- VFAT15 pair 6 (GBT7 elink 15)
        vfat3_sbits_arr_o(i)(15)(63 downto 56) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(071 downto 064); -- VFAT15 pair 7 (GBT7 elink 08)
        vfat3_sbits_arr_o(i)(16)(07 downto 00) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(151 downto 144); -- VFAT16 pair 0 (GBT1 elink 18)
        vfat3_sbits_arr_o(i)(16)(15 downto 08) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(175 downto 168); -- VFAT16 pair 1 (GBT1 elink 21)
        vfat3_sbits_arr_o(i)(16)(23 downto 16) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(167 downto 160); -- VFAT16 pair 2 (GBT1 elink 20)
        vfat3_sbits_arr_o(i)(16)(31 downto 24) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(191 downto 184); -- VFAT16 pair 3 (GBT1 elink 23)
        vfat3_sbits_arr_o(i)(16)(39 downto 32) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(183 downto 176); -- VFAT16 pair 4 (GBT1 elink 22)
        vfat3_sbits_arr_o(i)(16)(47 downto 40) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(223 downto 216); -- VFAT16 pair 5 (GBT1 elink 27)
        vfat3_sbits_arr_o(i)(16)(55 downto 48) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(215 downto 208); -- VFAT16 pair 6 (GBT1 elink 26)
        vfat3_sbits_arr_o(i)(16)(63 downto 56) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(207 downto 200); -- VFAT16 pair 7 (GBT1 elink 25)
        vfat3_sbits_arr_o(i)(17)(07 downto 00) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(031 downto 024); -- VFAT17 pair 0 (GBT1 elink 03)
        vfat3_sbits_arr_o(i)(17)(15 downto 08) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(111 downto 104); -- VFAT17 pair 1 (GBT1 elink 13)
        vfat3_sbits_arr_o(i)(17)(23 downto 16) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(047 downto 040); -- VFAT17 pair 2 (GBT1 elink 05)
        vfat3_sbits_arr_o(i)(17)(31 downto 24) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(015 downto 008); -- VFAT17 pair 3 (GBT1 elink 01)
        vfat3_sbits_arr_o(i)(17)(39 downto 32) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(007 downto 000); -- VFAT17 pair 4 (GBT1 elink 00)
        vfat3_sbits_arr_o(i)(17)(47 downto 40) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(023 downto 016); -- VFAT17 pair 5 (GBT1 elink 02)
        vfat3_sbits_arr_o(i)(17)(55 downto 48) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(103 downto 096); -- VFAT17 pair 6 (GBT1 elink 12)
        vfat3_sbits_arr_o(i)(17)(63 downto 56) <= gbt_rx_data_arr_i(i * 8 + 1).rx_data(039 downto 032); -- VFAT17 pair 7 (GBT1 elink 04)
        vfat3_sbits_arr_o(i)(18)(07 downto 00) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(151 downto 144); -- VFAT18 pair 0 (GBT3 elink 18)
        vfat3_sbits_arr_o(i)(18)(15 downto 08) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(175 downto 168); -- VFAT18 pair 1 (GBT3 elink 21)
        vfat3_sbits_arr_o(i)(18)(23 downto 16) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(167 downto 160); -- VFAT18 pair 2 (GBT3 elink 20)
        vfat3_sbits_arr_o(i)(18)(31 downto 24) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(191 downto 184); -- VFAT18 pair 3 (GBT3 elink 23)
        vfat3_sbits_arr_o(i)(18)(39 downto 32) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(183 downto 176); -- VFAT18 pair 4 (GBT3 elink 22)
        vfat3_sbits_arr_o(i)(18)(47 downto 40) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(223 downto 216); -- VFAT18 pair 5 (GBT3 elink 27)
        vfat3_sbits_arr_o(i)(18)(55 downto 48) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(215 downto 208); -- VFAT18 pair 6 (GBT3 elink 26)
        vfat3_sbits_arr_o(i)(18)(63 downto 56) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(207 downto 200); -- VFAT18 pair 7 (GBT3 elink 25)
        vfat3_sbits_arr_o(i)(19)(07 downto 00) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(031 downto 024); -- VFAT19 pair 0 (GBT3 elink 03)
        vfat3_sbits_arr_o(i)(19)(15 downto 08) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(111 downto 104); -- VFAT19 pair 1 (GBT3 elink 13)
        vfat3_sbits_arr_o(i)(19)(23 downto 16) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(047 downto 040); -- VFAT19 pair 2 (GBT3 elink 05)
        vfat3_sbits_arr_o(i)(19)(31 downto 24) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(015 downto 008); -- VFAT19 pair 3 (GBT3 elink 01)
        vfat3_sbits_arr_o(i)(19)(39 downto 32) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(007 downto 000); -- VFAT19 pair 4 (GBT3 elink 00)
        vfat3_sbits_arr_o(i)(19)(47 downto 40) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(023 downto 016); -- VFAT19 pair 5 (GBT3 elink 02)
        vfat3_sbits_arr_o(i)(19)(55 downto 48) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(103 downto 096); -- VFAT19 pair 6 (GBT3 elink 12)
        vfat3_sbits_arr_o(i)(19)(63 downto 56) <= gbt_rx_data_arr_i(i * 8 + 3).rx_data(039 downto 032); -- VFAT19 pair 7 (GBT3 elink 04)
        vfat3_sbits_arr_o(i)(20)(07 downto 00) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(151 downto 144); -- VFAT20 pair 0 (GBT5 elink 18)
        vfat3_sbits_arr_o(i)(20)(15 downto 08) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(175 downto 168); -- VFAT20 pair 1 (GBT5 elink 21)
        vfat3_sbits_arr_o(i)(20)(23 downto 16) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(167 downto 160); -- VFAT20 pair 2 (GBT5 elink 20)
        vfat3_sbits_arr_o(i)(20)(31 downto 24) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(191 downto 184); -- VFAT20 pair 3 (GBT5 elink 23)
        vfat3_sbits_arr_o(i)(20)(39 downto 32) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(183 downto 176); -- VFAT20 pair 4 (GBT5 elink 22)
        vfat3_sbits_arr_o(i)(20)(47 downto 40) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(223 downto 216); -- VFAT20 pair 5 (GBT5 elink 27)
        vfat3_sbits_arr_o(i)(20)(55 downto 48) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(215 downto 208); -- VFAT20 pair 6 (GBT5 elink 26)
        vfat3_sbits_arr_o(i)(20)(63 downto 56) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(207 downto 200); -- VFAT20 pair 7 (GBT5 elink 25)
        vfat3_sbits_arr_o(i)(21)(07 downto 00) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(031 downto 024); -- VFAT21 pair 0 (GBT5 elink 03)
        vfat3_sbits_arr_o(i)(21)(15 downto 08) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(111 downto 104); -- VFAT21 pair 1 (GBT5 elink 13)
        vfat3_sbits_arr_o(i)(21)(23 downto 16) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(047 downto 040); -- VFAT21 pair 2 (GBT5 elink 05)
        vfat3_sbits_arr_o(i)(21)(31 downto 24) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(015 downto 008); -- VFAT21 pair 3 (GBT5 elink 01)
        vfat3_sbits_arr_o(i)(21)(39 downto 32) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(007 downto 000); -- VFAT21 pair 4 (GBT5 elink 00)
        vfat3_sbits_arr_o(i)(21)(47 downto 40) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(023 downto 016); -- VFAT21 pair 5 (GBT5 elink 02)
        vfat3_sbits_arr_o(i)(21)(55 downto 48) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(103 downto 096); -- VFAT21 pair 6 (GBT5 elink 12)
        vfat3_sbits_arr_o(i)(21)(63 downto 56) <= gbt_rx_data_arr_i(i * 8 + 5).rx_data(039 downto 032); -- VFAT21 pair 7 (GBT5 elink 04)
        vfat3_sbits_arr_o(i)(22)(07 downto 00) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(151 downto 144); -- VFAT22 pair 0 (GBT7 elink 18)
        vfat3_sbits_arr_o(i)(22)(15 downto 08) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(175 downto 168); -- VFAT22 pair 1 (GBT7 elink 21)
        vfat3_sbits_arr_o(i)(22)(23 downto 16) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(167 downto 160); -- VFAT22 pair 2 (GBT7 elink 20)
        vfat3_sbits_arr_o(i)(22)(31 downto 24) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(191 downto 184); -- VFAT22 pair 3 (GBT7 elink 23)
        vfat3_sbits_arr_o(i)(22)(39 downto 32) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(183 downto 176); -- VFAT22 pair 4 (GBT7 elink 22)
        vfat3_sbits_arr_o(i)(22)(47 downto 40) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(223 downto 216); -- VFAT22 pair 5 (GBT7 elink 27)
        vfat3_sbits_arr_o(i)(22)(55 downto 48) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(215 downto 208); -- VFAT22 pair 6 (GBT7 elink 26)
        vfat3_sbits_arr_o(i)(22)(63 downto 56) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(207 downto 200); -- VFAT22 pair 7 (GBT7 elink 25)
        vfat3_sbits_arr_o(i)(23)(07 downto 00) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(031 downto 024); -- VFAT23 pair 0 (GBT7 elink 03)
        vfat3_sbits_arr_o(i)(23)(15 downto 08) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(111 downto 104); -- VFAT23 pair 1 (GBT7 elink 13)
        vfat3_sbits_arr_o(i)(23)(23 downto 16) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(047 downto 040); -- VFAT23 pair 2 (GBT7 elink 05)
        vfat3_sbits_arr_o(i)(23)(31 downto 24) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(015 downto 008); -- VFAT23 pair 3 (GBT7 elink 01)
        vfat3_sbits_arr_o(i)(23)(39 downto 32) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(007 downto 000); -- VFAT23 pair 4 (GBT7 elink 00)
        vfat3_sbits_arr_o(i)(23)(47 downto 40) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(023 downto 016); -- VFAT23 pair 5 (GBT7 elink 02)
        vfat3_sbits_arr_o(i)(23)(55 downto 48) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(103 downto 096); -- VFAT23 pair 6 (GBT7 elink 12)
        vfat3_sbits_arr_o(i)(23)(63 downto 56) <= gbt_rx_data_arr_i(i * 8 + 7).rx_data(039 downto 032); -- VFAT23 pair 7 (GBT7 elink 04)

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

        -- VFAT control
        gbt_tx_data_arr(i * 8 + 0).tx_data(07 downto 00) <= vfat3_tx_data_arr_i(i)(09) when vfat3_tx_data_arr_i(i)(09) = VFAT3_SC0_WORD or vfat3_tx_data_arr_i(i)(09) = VFAT3_SC1_WORD else vfat3_tx_data_arr_i(i)(17); -- GBT0 tx elink 00: VFAT9 & VFAT17
        gbt_tx_data_arr(i * 8 + 0).tx_data(15 downto 08) <= vfat3_tx_data_arr_i(i)(08) when vfat3_tx_data_arr_i(i)(08) = VFAT3_SC0_WORD or vfat3_tx_data_arr_i(i)(08) = VFAT3_SC1_WORD else vfat3_tx_data_arr_i(i)(16); -- GBT0 tx elink 01: VFAT8 & VFAT16
        gbt_tx_data_arr(i * 8 + 0).tx_data(23 downto 16) <= vfat3_tx_data_arr_i(i)(01) when vfat3_tx_data_arr_i(i)(01) = VFAT3_SC0_WORD or vfat3_tx_data_arr_i(i)(01) = VFAT3_SC1_WORD else vfat3_tx_data_arr_i(i)(00); -- GBT0 tx elink 02: VFAT1 & VFAT00
        gbt_tx_data_arr(i * 8 + 0).tx_data(31 downto 24) <= (others => '0'); -- GBT0 tx elink 03 is not connected
        gbt_tx_data_arr(i * 8 + 2).tx_data(07 downto 00) <= vfat3_tx_data_arr_i(i)(11) when vfat3_tx_data_arr_i(i)(11) = VFAT3_SC0_WORD or vfat3_tx_data_arr_i(i)(11) = VFAT3_SC1_WORD else vfat3_tx_data_arr_i(i)(19); -- GBT2 tx elink 00: VFAT11 & VFAT19
        gbt_tx_data_arr(i * 8 + 2).tx_data(15 downto 08) <= vfat3_tx_data_arr_i(i)(10) when vfat3_tx_data_arr_i(i)(10) = VFAT3_SC0_WORD or vfat3_tx_data_arr_i(i)(10) = VFAT3_SC1_WORD else vfat3_tx_data_arr_i(i)(18); -- GBT2 tx elink 01: VFAT10 & VFAT18
        gbt_tx_data_arr(i * 8 + 2).tx_data(23 downto 16) <= vfat3_tx_data_arr_i(i)(03) when vfat3_tx_data_arr_i(i)(03) = VFAT3_SC0_WORD or vfat3_tx_data_arr_i(i)(03) = VFAT3_SC1_WORD else vfat3_tx_data_arr_i(i)(02); -- GBT2 tx elink 02: VFAT3 & VFAT02
        gbt_tx_data_arr(i * 8 + 2).tx_data(31 downto 24) <= (others => '0'); -- GBT2 tx elink 03 is not connected
        gbt_tx_data_arr(i * 8 + 4).tx_data(07 downto 00) <= vfat3_tx_data_arr_i(i)(13) when vfat3_tx_data_arr_i(i)(13) = VFAT3_SC0_WORD or vfat3_tx_data_arr_i(i)(13) = VFAT3_SC1_WORD else vfat3_tx_data_arr_i(i)(21); -- GBT4 tx elink 00: VFAT13 & VFAT21
        gbt_tx_data_arr(i * 8 + 4).tx_data(15 downto 08) <= vfat3_tx_data_arr_i(i)(04) when vfat3_tx_data_arr_i(i)(04) = VFAT3_SC0_WORD or vfat3_tx_data_arr_i(i)(04) = VFAT3_SC1_WORD else vfat3_tx_data_arr_i(i)(20); -- GBT4 tx elink 01: VFAT4 & VFAT20
        gbt_tx_data_arr(i * 8 + 4).tx_data(23 downto 16) <= vfat3_tx_data_arr_i(i)(05) when vfat3_tx_data_arr_i(i)(05) = VFAT3_SC0_WORD or vfat3_tx_data_arr_i(i)(05) = VFAT3_SC1_WORD else vfat3_tx_data_arr_i(i)(12); -- GBT4 tx elink 02: VFAT5 & VFAT12
        gbt_tx_data_arr(i * 8 + 4).tx_data(31 downto 24) <= (others => '0'); -- GBT4 tx elink 03 is not connected
        gbt_tx_data_arr(i * 8 + 6).tx_data(07 downto 00) <= vfat3_tx_data_arr_i(i)(15) when vfat3_tx_data_arr_i(i)(15) = VFAT3_SC0_WORD or vfat3_tx_data_arr_i(i)(15) = VFAT3_SC1_WORD else vfat3_tx_data_arr_i(i)(23); -- GBT6 tx elink 00: VFAT15 & VFAT23
        gbt_tx_data_arr(i * 8 + 6).tx_data(15 downto 08) <= vfat3_tx_data_arr_i(i)(06) when vfat3_tx_data_arr_i(i)(06) = VFAT3_SC0_WORD or vfat3_tx_data_arr_i(i)(06) = VFAT3_SC1_WORD else vfat3_tx_data_arr_i(i)(22); -- GBT6 tx elink 01: VFAT6 & VFAT22
        gbt_tx_data_arr(i * 8 + 6).tx_data(23 downto 16) <= vfat3_tx_data_arr_i(i)(07) when vfat3_tx_data_arr_i(i)(07) = VFAT3_SC0_WORD or vfat3_tx_data_arr_i(i)(07) = VFAT3_SC1_WORD else vfat3_tx_data_arr_i(i)(14); -- GBT6 tx elink 02: VFAT7 & VFAT14
        gbt_tx_data_arr(i * 8 + 6).tx_data(31 downto 24) <= (others => '0'); -- GBT6 tx elink 03 is not connected

        -- Repeat the same data on the second transmitter (unused)
        gbt_tx_data_arr(i * 8 + 1) <= gbt_tx_data_arr(i * 8 + 0); -- GBT1
        gbt_tx_data_arr(i * 8 + 3) <= gbt_tx_data_arr(i * 8 + 2); -- GBT3
        gbt_tx_data_arr(i * 8 + 5) <= gbt_tx_data_arr(i * 8 + 4); -- GBT5
        gbt_tx_data_arr(i * 8 + 7) <= gbt_tx_data_arr(i * 8 + 6); -- GBT7

    end generate;
    
end gbt_link_mux_me0_arch;
