------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: UCLA
-- Engineer: Joseph Carlson jecarlson30@gmail.com
-- 
-- Create Date:    2023-12-04
-- Module Name:    queso_link_unmask
-- Description:    This module is used to unmask each elink for the QUESO PRBS test 
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

entity queso_link_unmask is
    generic(
        g_NUM_OF_OHs      : integer;
    );
    port(
        -- clock
        clk_i : in  std_logic;
        -- links
        queso_rx_data_arr_i       : in  t_vfat3_queso_arr(g_NUM_OF_OHs - 1 downto 0);
        queso_data_unmasked_arr_o : out t_vfat3_queso_arr(g_NUM_OF_OHs - 1 downto 0)
    );
end queso_link_unmask;

architecture queso_link_unmask_arch of queso_link_unmask is
    
begin

    --inversions incorperated in ASIAGO config
    g_ohs : for i in 0 to g_NUM_OF_OHs - 1 generate

        --======================================================--
        --========================= RX =========================--
        --======================================================--
    
        --========================= QUESO TEST RX =========================--
        process (clk_i)
        begin
            if rising_edge(clk_i) then
                queso_data_unmasked_arr_o(i)(00)  <= queso_rx_data_arr_i(i)(00)  xor x"28"; -- VFAT00 (GBT0 elink 25)
                queso_data_unmasked_arr_o(i)(09)  <= queso_rx_data_arr_i(i)(09)  xor x"14"; -- VFAT01 (GBT0 elink 27)
                queso_data_unmasked_arr_o(i)(18)  <= queso_rx_data_arr_i(i)(18)  xor x"28"; -- VFAT02 (GBT2 elink 25)
                queso_data_unmasked_arr_o(i)(27)  <= queso_rx_data_arr_i(i)(27)  xor x"14"; -- VFAT03 (GBT2 elink 27)
                queso_data_unmasked_arr_o(i)(36)  <= queso_rx_data_arr_i(i)(36)  xor x"00"; -- VFAT04 (GBT4 elink 03)
                queso_data_unmasked_arr_o(i)(45)  <= queso_rx_data_arr_i(i)(45)  xor x"14"; -- VFAT05 (GBT4 elink 27)
                queso_data_unmasked_arr_o(i)(54)  <= queso_rx_data_arr_i(i)(54)  xor x"00"; -- VFAT06 (GBT6 elink 03)
                queso_data_unmasked_arr_o(i)(63)  <= queso_rx_data_arr_i(i)(63)  xor x"14"; -- VFAT07 (GBT6 elink 27)
                queso_data_unmasked_arr_o(i)(72)  <= queso_rx_data_arr_i(i)(72)  xor x"00"; -- VFAT08 (GBT0 elink 03)
                queso_data_unmasked_arr_o(i)(81)  <= queso_rx_data_arr_i(i)(81)  xor x"1e"; -- VFAT09 (GBT1 elink 11)
                queso_data_unmasked_arr_o(i)(90)  <= queso_rx_data_arr_i(i)(90)  xor x"00"; -- VFAT10 (GBT2 elink 03)
                queso_data_unmasked_arr_o(i)(99)  <= queso_rx_data_arr_i(i)(99)  xor x"1e"; -- VFAT11 (GBT3 elink 11)
                queso_data_unmasked_arr_o(i)(108) <= queso_rx_data_arr_i(i)(108) xor x"28"; -- VFAT12 (GBT4 elink 25)
                queso_data_unmasked_arr_o(i)(117) <= queso_rx_data_arr_i(i)(117) xor x"1e"; -- VFAT13 (GBT5 elink 11)
                queso_data_unmasked_arr_o(i)(126) <= queso_rx_data_arr_i(i)(126) xor x"28"; -- VFAT14 (GBT6 elink 25)
                queso_data_unmasked_arr_o(i)(135) <= queso_rx_data_arr_i(i)(135) xor x"1e"; -- VFAT15 (GBT7 elink 11)
                queso_data_unmasked_arr_o(i)(144) <= queso_rx_data_arr_i(i)(144) xor x"0a"; -- VFAT16 (GBT1 elink 24)
                queso_data_unmasked_arr_o(i)(153) <= queso_rx_data_arr_i(i)(153) xor x"32"; -- VFAT17 (GBT1 elink 06)
                queso_data_unmasked_arr_o(i)(162) <= queso_rx_data_arr_i(i)(162) xor x"0a"; -- VFAT18 (GBT3 elink 24)
                queso_data_unmasked_arr_o(i)(171) <= queso_rx_data_arr_i(i)(171) xor x"32"; -- VFAT19 (GBT3 elink 06)
                queso_data_unmasked_arr_o(i)(180) <= queso_rx_data_arr_i(i)(180) xor x"0a"; -- VFAT20 (GBT5 elink 24)
                queso_data_unmasked_arr_o(i)(189) <= queso_rx_data_arr_i(i)(189) xor x"32"; -- VFAT21 (GBT5 elink 06)
                queso_data_unmasked_arr_o(i)(198) <= queso_rx_data_arr_i(i)(198) xor x"0a"; -- VFAT22 (GBT7 elink 24)
                queso_data_unmasked_arr_o(i)(207) <= queso_rx_data_arr_i(i)(207) xor x"32"; -- VFAT23 (GBT7 elink 06) 
        
                queso_data_unmasked_arr_o(i)(01)  <= queso_rx_data_arr_i(i)(01)  xor x"29"; -- VFAT00 pair 0 (GBT0 elink 16)
                queso_data_unmasked_arr_o(i)(02)  <= queso_rx_data_arr_i(i)(02)  xor x"2a"; -- VFAT00 pair 1 (GBT0 elink 18)
                queso_data_unmasked_arr_o(i)(03)  <= queso_rx_data_arr_i(i)(03)  xor x"2b"; -- VFAT00 pair 2 (GBT0 elink 20)
                queso_data_unmasked_arr_o(i)(04)  <= queso_rx_data_arr_i(i)(04)  xor x"2c"; -- VFAT00 pair 3 (GBT0 elink 22)
                queso_data_unmasked_arr_o(i)(05)  <= queso_rx_data_arr_i(i)(05)  xor x"2d"; -- VFAT00 pair 4 (GBT0 elink 24)
                queso_data_unmasked_arr_o(i)(06)  <= queso_rx_data_arr_i(i)(06)  xor x"2e"; -- VFAT00 pair 5 (GBT0 elink 26)
                queso_data_unmasked_arr_o(i)(07)  <= queso_rx_data_arr_i(i)(07)  xor x"2f"; -- VFAT00 pair 6 (GBT0 elink 21)
                queso_data_unmasked_arr_o(i)(08)  <= queso_rx_data_arr_i(i)(08)  xor x"30"; -- VFAT00 pair 7 (GBT0 elink 23)
                queso_data_unmasked_arr_o(i)(10)  <= queso_rx_data_arr_i(i)(10)  xor x"15"; -- VFAT01 pair 0 (GBT0 elink 15)
                queso_data_unmasked_arr_o(i)(11)  <= queso_rx_data_arr_i(i)(11)  xor x"16"; -- VFAT01 pair 1 (GBT0 elink 14)
                queso_data_unmasked_arr_o(i)(12)  <= queso_rx_data_arr_i(i)(12)  xor x"17"; -- VFAT01 pair 2 (GBT0 elink 12)
                queso_data_unmasked_arr_o(i)(13)  <= queso_rx_data_arr_i(i)(13)  xor x"18"; -- VFAT01 pair 3 (GBT0 elink 10)
                queso_data_unmasked_arr_o(i)(14)  <= queso_rx_data_arr_i(i)(14)  xor x"19"; -- VFAT01 pair 4 (GBT0 elink 11)
                queso_data_unmasked_arr_o(i)(15)  <= queso_rx_data_arr_i(i)(15)  xor x"1a"; -- VFAT01 pair 5 (GBT0 elink 13)
                queso_data_unmasked_arr_o(i)(16)  <= queso_rx_data_arr_i(i)(16)  xor x"1b"; -- VFAT01 pair 6 (GBT0 elink 19)
                queso_data_unmasked_arr_o(i)(17)  <= queso_rx_data_arr_i(i)(17)  xor x"1c"; -- VFAT01 pair 7 (GBT0 elink 17)
                queso_data_unmasked_arr_o(i)(19)  <= queso_rx_data_arr_i(i)(19)  xor x"29"; -- VFAT02 pair 0 (GBT2 elink 16)
                queso_data_unmasked_arr_o(i)(20)  <= queso_rx_data_arr_i(i)(20)  xor x"2a"; -- VFAT02 pair 1 (GBT2 elink 18)
                queso_data_unmasked_arr_o(i)(21)  <= queso_rx_data_arr_i(i)(21)  xor x"2b"; -- VFAT02 pair 2 (GBT2 elink 20)
                queso_data_unmasked_arr_o(i)(22)  <= queso_rx_data_arr_i(i)(22)  xor x"2c"; -- VFAT02 pair 3 (GBT2 elink 22)
                queso_data_unmasked_arr_o(i)(23)  <= queso_rx_data_arr_i(i)(23)  xor x"2d"; -- VFAT02 pair 4 (GBT2 elink 24)
                queso_data_unmasked_arr_o(i)(24)  <= queso_rx_data_arr_i(i)(24)  xor x"2e"; -- VFAT02 pair 5 (GBT2 elink 26)
                queso_data_unmasked_arr_o(i)(25)  <= queso_rx_data_arr_i(i)(25)  xor x"2f"; -- VFAT02 pair 6 (GBT2 elink 21)
                queso_data_unmasked_arr_o(i)(26)  <= queso_rx_data_arr_i(i)(26)  xor x"30"; -- VFAT02 pair 7 (GBT2 elink 23)
                queso_data_unmasked_arr_o(i)(28)  <= queso_rx_data_arr_i(i)(28)  xor x"15"; -- VFAT03 pair 0 (GBT2 elink 15)
                queso_data_unmasked_arr_o(i)(29)  <= queso_rx_data_arr_i(i)(29)  xor x"16"; -- VFAT03 pair 1 (GBT2 elink 14)
                queso_data_unmasked_arr_o(i)(30)  <= queso_rx_data_arr_i(i)(30)  xor x"17"; -- VFAT03 pair 2 (GBT2 elink 12)
                queso_data_unmasked_arr_o(i)(31)  <= queso_rx_data_arr_i(i)(31)  xor x"18"; -- VFAT03 pair 3 (GBT2 elink 10)
                queso_data_unmasked_arr_o(i)(32)  <= queso_rx_data_arr_i(i)(32)  xor x"19"; -- VFAT03 pair 4 (GBT2 elink 11)
                queso_data_unmasked_arr_o(i)(33)  <= queso_rx_data_arr_i(i)(33)  xor x"1a"; -- VFAT03 pair 5 (GBT2 elink 13)
                queso_data_unmasked_arr_o(i)(34)  <= queso_rx_data_arr_i(i)(34)  xor x"1b"; -- VFAT03 pair 6 (GBT2 elink 19)
                queso_data_unmasked_arr_o(i)(35)  <= queso_rx_data_arr_i(i)(35)  xor x"1c"; -- VFAT03 pair 7 (GBT2 elink 17)
                queso_data_unmasked_arr_o(i)(37)  <= queso_rx_data_arr_i(i)(37)  xor x"01"; -- VFAT04 pair 0 (GBT4 elink 06)
                queso_data_unmasked_arr_o(i)(38)  <= queso_rx_data_arr_i(i)(38)  xor x"02"; -- VFAT04 pair 1 (GBT4 elink 07)
                queso_data_unmasked_arr_o(i)(39)  <= queso_rx_data_arr_i(i)(39)  xor x"03"; -- VFAT04 pair 2 (GBT4 elink 09)
                queso_data_unmasked_arr_o(i)(40)  <= queso_rx_data_arr_i(i)(40)  xor x"04"; -- VFAT04 pair 3 (GBT4 elink 04)
                queso_data_unmasked_arr_o(i)(41)  <= queso_rx_data_arr_i(i)(41)  xor x"05"; -- VFAT04 pair 4 (GBT4 elink 05)
                queso_data_unmasked_arr_o(i)(42)  <= queso_rx_data_arr_i(i)(42)  xor x"06"; -- VFAT04 pair 5 (GBT4 elink 02)
                queso_data_unmasked_arr_o(i)(43)  <= queso_rx_data_arr_i(i)(43)  xor x"07"; -- VFAT04 pair 6 (GBT4 elink 00)
                queso_data_unmasked_arr_o(i)(44)  <= queso_rx_data_arr_i(i)(44)  xor x"08"; -- VFAT04 pair 7 (GBT4 elink 01)
                queso_data_unmasked_arr_o(i)(46)  <= queso_rx_data_arr_i(i)(46)  xor x"15"; -- VFAT05 pair 0 (GBT4 elink 15)
                queso_data_unmasked_arr_o(i)(47)  <= queso_rx_data_arr_i(i)(47)  xor x"16"; -- VFAT05 pair 1 (GBT4 elink 14)
                queso_data_unmasked_arr_o(i)(48)  <= queso_rx_data_arr_i(i)(48)  xor x"17"; -- VFAT05 pair 2 (GBT4 elink 12)
                queso_data_unmasked_arr_o(i)(49)  <= queso_rx_data_arr_i(i)(49)  xor x"18"; -- VFAT05 pair 3 (GBT4 elink 10)
                queso_data_unmasked_arr_o(i)(50)  <= queso_rx_data_arr_i(i)(50)  xor x"19"; -- VFAT05 pair 4 (GBT4 elink 11)
                queso_data_unmasked_arr_o(i)(51)  <= queso_rx_data_arr_i(i)(51)  xor x"1a"; -- VFAT05 pair 5 (GBT4 elink 13)
                queso_data_unmasked_arr_o(i)(52)  <= queso_rx_data_arr_i(i)(52)  xor x"1b"; -- VFAT05 pair 6 (GBT4 elink 19)
                queso_data_unmasked_arr_o(i)(53)  <= queso_rx_data_arr_i(i)(53)  xor x"1c"; -- VFAT05 pair 7 (GBT4 elink 17)
                queso_data_unmasked_arr_o(i)(55)  <= queso_rx_data_arr_i(i)(55)  xor x"01"; -- VFAT06 pair 0 (GBT5 elink 06)
                queso_data_unmasked_arr_o(i)(56)  <= queso_rx_data_arr_i(i)(56)  xor x"02"; -- VFAT06 pair 1 (GBT5 elink 07)
                queso_data_unmasked_arr_o(i)(57)  <= queso_rx_data_arr_i(i)(57)  xor x"03"; -- VFAT06 pair 2 (GBT5 elink 09)
                queso_data_unmasked_arr_o(i)(58)  <= queso_rx_data_arr_i(i)(58)  xor x"04"; -- VFAT06 pair 3 (GBT5 elink 04)
                queso_data_unmasked_arr_o(i)(59)  <= queso_rx_data_arr_i(i)(59)  xor x"05"; -- VFAT06 pair 4 (GBT5 elink 05)
                queso_data_unmasked_arr_o(i)(60)  <= queso_rx_data_arr_i(i)(60)  xor x"06"; -- VFAT06 pair 5 (GBT5 elink 02)
                queso_data_unmasked_arr_o(i)(61)  <= queso_rx_data_arr_i(i)(61)  xor x"07"; -- VFAT06 pair 6 (GBT5 elink 00)
                queso_data_unmasked_arr_o(i)(62)  <= queso_rx_data_arr_i(i)(62)  xor x"08"; -- VFAT06 pair 7 (GBT5 elink 01)
                queso_data_unmasked_arr_o(i)(64)  <= queso_rx_data_arr_i(i)(64)  xor x"15"; -- VFAT07 pair 0 (GBT6 elink 15)
                queso_data_unmasked_arr_o(i)(65)  <= queso_rx_data_arr_i(i)(65)  xor x"16"; -- VFAT07 pair 1 (GBT6 elink 14)
                queso_data_unmasked_arr_o(i)(66)  <= queso_rx_data_arr_i(i)(66)  xor x"17"; -- VFAT07 pair 2 (GBT6 elink 12)
                queso_data_unmasked_arr_o(i)(67)  <= queso_rx_data_arr_i(i)(67)  xor x"18"; -- VFAT07 pair 3 (GBT6 elink 10)
                queso_data_unmasked_arr_o(i)(68)  <= queso_rx_data_arr_i(i)(68)  xor x"19"; -- VFAT07 pair 4 (GBT6 elink 11)
                queso_data_unmasked_arr_o(i)(69)  <= queso_rx_data_arr_i(i)(69)  xor x"1a"; -- VFAT07 pair 5 (GBT6 elink 13)
                queso_data_unmasked_arr_o(i)(70)  <= queso_rx_data_arr_i(i)(70)  xor x"1b"; -- VFAT07 pair 6 (GBT6 elink 19)
                queso_data_unmasked_arr_o(i)(71)  <= queso_rx_data_arr_i(i)(71)  xor x"1c"; -- VFAT07 pair 7 (GBT6 elink 17)
                queso_data_unmasked_arr_o(i)(73)  <= queso_rx_data_arr_i(i)(73)  xor x"01"; -- VFAT08 pair 0 (GBT0 elink 06)
                queso_data_unmasked_arr_o(i)(74)  <= queso_rx_data_arr_i(i)(74)  xor x"02"; -- VFAT08 pair 1 (GBT0 elink 07)
                queso_data_unmasked_arr_o(i)(75)  <= queso_rx_data_arr_i(i)(75)  xor x"03"; -- VFAT08 pair 2 (GBT0 elink 09)
                queso_data_unmasked_arr_o(i)(76)  <= queso_rx_data_arr_i(i)(76)  xor x"04"; -- VFAT08 pair 3 (GBT0 elink 04)
                queso_data_unmasked_arr_o(i)(77)  <= queso_rx_data_arr_i(i)(77)  xor x"05"; -- VFAT08 pair 4 (GBT0 elink 05)
                queso_data_unmasked_arr_o(i)(78)  <= queso_rx_data_arr_i(i)(78)  xor x"06"; -- VFAT08 pair 5 (GBT0 elink 02)
                queso_data_unmasked_arr_o(i)(79)  <= queso_rx_data_arr_i(i)(79)  xor x"07"; -- VFAT08 pair 6 (GBT0 elink 00)
                queso_data_unmasked_arr_o(i)(80)  <= queso_rx_data_arr_i(i)(80)  xor x"08"; -- VFAT08 pair 7 (GBT0 elink 01)
                queso_data_unmasked_arr_o(i)(82)  <= queso_rx_data_arr_i(i)(82)  xor x"1f"; -- VFAT09 pair 0 (GBT1 elink 17)
                queso_data_unmasked_arr_o(i)(83)  <= queso_rx_data_arr_i(i)(83)  xor x"20"; -- VFAT09 pair 1 (GBT1 elink 19)
                queso_data_unmasked_arr_o(i)(84)  <= queso_rx_data_arr_i(i)(84)  xor x"21"; -- VFAT09 pair 2 (GBT1 elink 14)
                queso_data_unmasked_arr_o(i)(85)  <= queso_rx_data_arr_i(i)(85)  xor x"22"; -- VFAT09 pair 3 (GBT1 elink 07)
                queso_data_unmasked_arr_o(i)(86)  <= queso_rx_data_arr_i(i)(86)  xor x"23"; -- VFAT09 pair 4 (GBT1 elink 09)
                queso_data_unmasked_arr_o(i)(87)  <= queso_rx_data_arr_i(i)(87)  xor x"24"; -- VFAT09 pair 5 (GBT1 elink 10)
                queso_data_unmasked_arr_o(i)(88)  <= queso_rx_data_arr_i(i)(88)  xor x"25"; -- VFAT09 pair 6 (GBT1 elink 15)
                queso_data_unmasked_arr_o(i)(89)  <= queso_rx_data_arr_i(i)(89)  xor x"26"; -- VFAT09 pair 7 (GBT1 elink 08)
                queso_data_unmasked_arr_o(i)(91)  <= queso_rx_data_arr_i(i)(91)  xor x"01"; -- VFAT10 pair 0 (GBT2 elink 06)
                queso_data_unmasked_arr_o(i)(92)  <= queso_rx_data_arr_i(i)(92)  xor x"02"; -- VFAT10 pair 1 (GBT2 elink 07)
                queso_data_unmasked_arr_o(i)(93)  <= queso_rx_data_arr_i(i)(93)  xor x"03"; -- VFAT10 pair 2 (GBT2 elink 09)
                queso_data_unmasked_arr_o(i)(94)  <= queso_rx_data_arr_i(i)(94)  xor x"04"; -- VFAT10 pair 3 (GBT2 elink 04)
                queso_data_unmasked_arr_o(i)(95)  <= queso_rx_data_arr_i(i)(95)  xor x"05"; -- VFAT10 pair 4 (GBT2 elink 05)
                queso_data_unmasked_arr_o(i)(96)  <= queso_rx_data_arr_i(i)(96)  xor x"06"; -- VFAT10 pair 5 (GBT2 elink 02)
                queso_data_unmasked_arr_o(i)(97)  <= queso_rx_data_arr_i(i)(97)  xor x"07"; -- VFAT10 pair 6 (GBT2 elink 00)
                queso_data_unmasked_arr_o(i)(98)  <= queso_rx_data_arr_i(i)(98)  xor x"08"; -- VFAT10 pair 7 (GBT2 elink 01)
                queso_data_unmasked_arr_o(i)(100) <= queso_rx_data_arr_i(i)(100) xor x"1f"; -- VFAT11 pair 0 (GBT3 elink 17)
                queso_data_unmasked_arr_o(i)(101) <= queso_rx_data_arr_i(i)(101) xor x"20"; -- VFAT11 pair 1 (GBT3 elink 19)
                queso_data_unmasked_arr_o(i)(102) <= queso_rx_data_arr_i(i)(102) xor x"21"; -- VFAT11 pair 2 (GBT3 elink 14)
                queso_data_unmasked_arr_o(i)(103) <= queso_rx_data_arr_i(i)(103) xor x"22"; -- VFAT11 pair 3 (GBT3 elink 07)
                queso_data_unmasked_arr_o(i)(104) <= queso_rx_data_arr_i(i)(104) xor x"23"; -- VFAT11 pair 4 (GBT3 elink 09)
                queso_data_unmasked_arr_o(i)(105) <= queso_rx_data_arr_i(i)(105) xor x"24"; -- VFAT11 pair 5 (GBT3 elink 10)
                queso_data_unmasked_arr_o(i)(106) <= queso_rx_data_arr_i(i)(106) xor x"25"; -- VFAT11 pair 6 (GBT3 elink 15)
                queso_data_unmasked_arr_o(i)(107) <= queso_rx_data_arr_i(i)(107) xor x"26"; -- VFAT11 pair 7 (GBT3 elink 08)
                queso_data_unmasked_arr_o(i)(109) <= queso_rx_data_arr_i(i)(109) xor x"29"; -- VFAT12 pair 0 (GBT4 elink 16)
                queso_data_unmasked_arr_o(i)(110) <= queso_rx_data_arr_i(i)(110) xor x"2a"; -- VFAT12 pair 1 (GBT4 elink 18)
                queso_data_unmasked_arr_o(i)(111) <= queso_rx_data_arr_i(i)(111) xor x"2b"; -- VFAT12 pair 2 (GBT4 elink 20)
                queso_data_unmasked_arr_o(i)(112) <= queso_rx_data_arr_i(i)(112) xor x"2c"; -- VFAT12 pair 3 (GBT4 elink 22)
                queso_data_unmasked_arr_o(i)(113) <= queso_rx_data_arr_i(i)(113) xor x"2d"; -- VFAT12 pair 4 (GBT4 elink 24)
                queso_data_unmasked_arr_o(i)(114) <= queso_rx_data_arr_i(i)(114) xor x"2e"; -- VFAT12 pair 5 (GBT4 elink 26)
                queso_data_unmasked_arr_o(i)(115) <= queso_rx_data_arr_i(i)(115) xor x"2f"; -- VFAT12 pair 6 (GBT4 elink 21)
                queso_data_unmasked_arr_o(i)(116) <= queso_rx_data_arr_i(i)(116) xor x"30"; -- VFAT12 pair 7 (GBT4 elink 23)
                queso_data_unmasked_arr_o(i)(118) <= queso_rx_data_arr_i(i)(118) xor x"1f"; -- VFAT13 pair 0 (GBT5 elink 17)
                queso_data_unmasked_arr_o(i)(119) <= queso_rx_data_arr_i(i)(119) xor x"20"; -- VFAT13 pair 1 (GBT5 elink 19)
                queso_data_unmasked_arr_o(i)(120) <= queso_rx_data_arr_i(i)(120) xor x"21"; -- VFAT13 pair 2 (GBT5 elink 14)
                queso_data_unmasked_arr_o(i)(121) <= queso_rx_data_arr_i(i)(121) xor x"22"; -- VFAT13 pair 3 (GBT5 elink 07)
                queso_data_unmasked_arr_o(i)(122) <= queso_rx_data_arr_i(i)(122) xor x"23"; -- VFAT13 pair 4 (GBT5 elink 09)
                queso_data_unmasked_arr_o(i)(123) <= queso_rx_data_arr_i(i)(123) xor x"24"; -- VFAT13 pair 5 (GBT5 elink 10)
                queso_data_unmasked_arr_o(i)(124) <= queso_rx_data_arr_i(i)(124) xor x"25"; -- VFAT13 pair 6 (GBT5 elink 15)
                queso_data_unmasked_arr_o(i)(125) <= queso_rx_data_arr_i(i)(125) xor x"26"; -- VFAT13 pair 7 (GBT5 elink 08)
                queso_data_unmasked_arr_o(i)(127) <= queso_rx_data_arr_i(i)(127) xor x"29"; -- VFAT14 pair 0 (GBT6 elink 16)
                queso_data_unmasked_arr_o(i)(128) <= queso_rx_data_arr_i(i)(128) xor x"2a"; -- VFAT14 pair 1 (GBT6 elink 18)
                queso_data_unmasked_arr_o(i)(129) <= queso_rx_data_arr_i(i)(129) xor x"2b"; -- VFAT14 pair 2 (GBT6 elink 20)
                queso_data_unmasked_arr_o(i)(130) <= queso_rx_data_arr_i(i)(130) xor x"2c"; -- VFAT14 pair 3 (GBT6 elink 22)
                queso_data_unmasked_arr_o(i)(131) <= queso_rx_data_arr_i(i)(131) xor x"2d"; -- VFAT14 pair 4 (GBT6 elink 24)
                queso_data_unmasked_arr_o(i)(132) <= queso_rx_data_arr_i(i)(132) xor x"2e"; -- VFAT14 pair 5 (GBT6 elink 26)
                queso_data_unmasked_arr_o(i)(133) <= queso_rx_data_arr_i(i)(133) xor x"2f"; -- VFAT14 pair 6 (GBT6 elink 21)
                queso_data_unmasked_arr_o(i)(134) <= queso_rx_data_arr_i(i)(134) xor x"30"; -- VFAT14 pair 7 (GBT6 elink 23)
                queso_data_unmasked_arr_o(i)(136) <= queso_rx_data_arr_i(i)(136) xor x"1f"; -- VFAT15 pair 0 (GBT7 elink 17)
                queso_data_unmasked_arr_o(i)(137) <= queso_rx_data_arr_i(i)(137) xor x"20"; -- VFAT15 pair 1 (GBT7 elink 19)
                queso_data_unmasked_arr_o(i)(138) <= queso_rx_data_arr_i(i)(138) xor x"21"; -- VFAT15 pair 2 (GBT7 elink 14)
                queso_data_unmasked_arr_o(i)(139) <= queso_rx_data_arr_i(i)(139) xor x"22"; -- VFAT15 pair 3 (GBT7 elink 07)
                queso_data_unmasked_arr_o(i)(140) <= queso_rx_data_arr_i(i)(140) xor x"23"; -- VFAT15 pair 4 (GBT7 elink 09)
                queso_data_unmasked_arr_o(i)(141) <= queso_rx_data_arr_i(i)(141) xor x"24"; -- VFAT15 pair 5 (GBT7 elink 10)
                queso_data_unmasked_arr_o(i)(142) <= queso_rx_data_arr_i(i)(142) xor x"25"; -- VFAT15 pair 6 (GBT7 elink 15)
                queso_data_unmasked_arr_o(i)(143) <= queso_rx_data_arr_i(i)(143) xor x"26"; -- VFAT15 pair 7 (GBT7 elink 08)
                queso_data_unmasked_arr_o(i)(145) <= queso_rx_data_arr_i(i)(145) xor x"0b"; -- VFAT16 pair 0 (GBT1 elink 18)
                queso_data_unmasked_arr_o(i)(146) <= queso_rx_data_arr_i(i)(146) xor x"0c"; -- VFAT16 pair 1 (GBT1 elink 21)
                queso_data_unmasked_arr_o(i)(147) <= queso_rx_data_arr_i(i)(147) xor x"0d"; -- VFAT16 pair 2 (GBT1 elink 20)
                queso_data_unmasked_arr_o(i)(148) <= queso_rx_data_arr_i(i)(148) xor x"0e"; -- VFAT16 pair 3 (GBT1 elink 23)
                queso_data_unmasked_arr_o(i)(149) <= queso_rx_data_arr_i(i)(149) xor x"0f"; -- VFAT16 pair 4 (GBT1 elink 22)
                queso_data_unmasked_arr_o(i)(150) <= queso_rx_data_arr_i(i)(150) xor x"10"; -- VFAT16 pair 5 (GBT1 elink 27)
                queso_data_unmasked_arr_o(i)(151) <= queso_rx_data_arr_i(i)(151) xor x"11"; -- VFAT16 pair 6 (GBT1 elink 26)
                queso_data_unmasked_arr_o(i)(152) <= queso_rx_data_arr_i(i)(152) xor x"12"; -- VFAT16 pair 7 (GBT1 elink 25)
                queso_data_unmasked_arr_o(i)(154) <= queso_rx_data_arr_i(i)(154) xor x"33"; -- VFAT17 pair 0 (GBT1 elink 03)
                queso_data_unmasked_arr_o(i)(155) <= queso_rx_data_arr_i(i)(155) xor x"34"; -- VFAT17 pair 1 (GBT1 elink 13)
                queso_data_unmasked_arr_o(i)(156) <= queso_rx_data_arr_i(i)(156) xor x"35"; -- VFAT17 pair 2 (GBT1 elink 05)
                queso_data_unmasked_arr_o(i)(157) <= queso_rx_data_arr_i(i)(157) xor x"36"; -- VFAT17 pair 3 (GBT1 elink 01)
                queso_data_unmasked_arr_o(i)(158) <= queso_rx_data_arr_i(i)(158) xor x"37"; -- VFAT17 pair 4 (GBT1 elink 00)
                queso_data_unmasked_arr_o(i)(159) <= queso_rx_data_arr_i(i)(159) xor x"38"; -- VFAT17 pair 5 (GBT1 elink 02)
                queso_data_unmasked_arr_o(i)(160) <= queso_rx_data_arr_i(i)(160) xor x"39"; -- VFAT17 pair 6 (GBT1 elink 12)
                queso_data_unmasked_arr_o(i)(161) <= queso_rx_data_arr_i(i)(161) xor x"3a"; -- VFAT17 pair 7 (GBT1 elink 04)
                queso_data_unmasked_arr_o(i)(163) <= queso_rx_data_arr_i(i)(163) xor x"0b"; -- VFAT18 pair 0 (GBT3 elink 18)
                queso_data_unmasked_arr_o(i)(164) <= queso_rx_data_arr_i(i)(164) xor x"0c"; -- VFAT18 pair 1 (GBT3 elink 21)
                queso_data_unmasked_arr_o(i)(165) <= queso_rx_data_arr_i(i)(165) xor x"0d"; -- VFAT18 pair 2 (GBT3 elink 20)
                queso_data_unmasked_arr_o(i)(166) <= queso_rx_data_arr_i(i)(166) xor x"0e"; -- VFAT18 pair 3 (GBT3 elink 23)
                queso_data_unmasked_arr_o(i)(167) <= queso_rx_data_arr_i(i)(167) xor x"0f"; -- VFAT18 pair 4 (GBT3 elink 22)
                queso_data_unmasked_arr_o(i)(168) <= queso_rx_data_arr_i(i)(168) xor x"10"; -- VFAT18 pair 5 (GBT3 elink 27)
                queso_data_unmasked_arr_o(i)(169) <= queso_rx_data_arr_i(i)(169) xor x"11"; -- VFAT18 pair 6 (GBT3 elink 26)
                queso_data_unmasked_arr_o(i)(170) <= queso_rx_data_arr_i(i)(170) xor x"12"; -- VFAT18 pair 7 (GBT3 elink 25)
                queso_data_unmasked_arr_o(i)(172) <= queso_rx_data_arr_i(i)(172) xor x"33"; -- VFAT19 pair 0 (GBT3 elink 03)
                queso_data_unmasked_arr_o(i)(173) <= queso_rx_data_arr_i(i)(173) xor x"34"; -- VFAT19 pair 1 (GBT3 elink 13)
                queso_data_unmasked_arr_o(i)(174) <= queso_rx_data_arr_i(i)(174) xor x"35"; -- VFAT19 pair 2 (GBT3 elink 05)
                queso_data_unmasked_arr_o(i)(175) <= queso_rx_data_arr_i(i)(175) xor x"36"; -- VFAT19 pair 3 (GBT3 elink 01)
                queso_data_unmasked_arr_o(i)(176) <= queso_rx_data_arr_i(i)(176) xor x"37"; -- VFAT19 pair 4 (GBT3 elink 00)
                queso_data_unmasked_arr_o(i)(177) <= queso_rx_data_arr_i(i)(177) xor x"38"; -- VFAT19 pair 5 (GBT3 elink 02)
                queso_data_unmasked_arr_o(i)(178) <= queso_rx_data_arr_i(i)(178) xor x"39"; -- VFAT19 pair 6 (GBT3 elink 12)
                queso_data_unmasked_arr_o(i)(179) <= queso_rx_data_arr_i(i)(179) xor x"3a"; -- VFAT19 pair 7 (GBT3 elink 04)
                queso_data_unmasked_arr_o(i)(181) <= queso_rx_data_arr_i(i)(181) xor x"0b"; -- VFAT20 pair 0 (GBT5 elink 18)
                queso_data_unmasked_arr_o(i)(182) <= queso_rx_data_arr_i(i)(182) xor x"0c"; -- VFAT20 pair 1 (GBT5 elink 21)
                queso_data_unmasked_arr_o(i)(183) <= queso_rx_data_arr_i(i)(183) xor x"0d"; -- VFAT20 pair 2 (GBT5 elink 20)
                queso_data_unmasked_arr_o(i)(184) <= queso_rx_data_arr_i(i)(184) xor x"0e"; -- VFAT20 pair 3 (GBT5 elink 23)
                queso_data_unmasked_arr_o(i)(185) <= queso_rx_data_arr_i(i)(185) xor x"0f"; -- VFAT20 pair 4 (GBT5 elink 22)
                queso_data_unmasked_arr_o(i)(186) <= queso_rx_data_arr_i(i)(186) xor x"10"; -- VFAT20 pair 5 (GBT5 elink 27)
                queso_data_unmasked_arr_o(i)(187) <= queso_rx_data_arr_i(i)(187) xor x"11"; -- VFAT20 pair 6 (GBT5 elink 26)
                queso_data_unmasked_arr_o(i)(188) <= queso_rx_data_arr_i(i)(188) xor x"12"; -- VFAT20 pair 7 (GBT5 elink 25)
                queso_data_unmasked_arr_o(i)(190) <= queso_rx_data_arr_i(i)(190) xor x"33"; -- VFAT21 pair 0 (GBT5 elink 03)
                queso_data_unmasked_arr_o(i)(191) <= queso_rx_data_arr_i(i)(191) xor x"34"; -- VFAT21 pair 1 (GBT5 elink 13)
                queso_data_unmasked_arr_o(i)(192) <= queso_rx_data_arr_i(i)(192) xor x"35"; -- VFAT21 pair 2 (GBT5 elink 05)
                queso_data_unmasked_arr_o(i)(193) <= queso_rx_data_arr_i(i)(193) xor x"36"; -- VFAT21 pair 3 (GBT5 elink 01)
                queso_data_unmasked_arr_o(i)(194) <= queso_rx_data_arr_i(i)(194) xor x"37"; -- VFAT21 pair 4 (GBT5 elink 00)
                queso_data_unmasked_arr_o(i)(195) <= queso_rx_data_arr_i(i)(195) xor x"38"; -- VFAT21 pair 5 (GBT5 elink 02)
                queso_data_unmasked_arr_o(i)(196) <= queso_rx_data_arr_i(i)(196) xor x"39"; -- VFAT21 pair 6 (GBT5 elink 12)
                queso_data_unmasked_arr_o(i)(197) <= queso_rx_data_arr_i(i)(197) xor x"3a"; -- VFAT21 pair 7 (GBT5 elink 04)
                queso_data_unmasked_arr_o(i)(199) <= queso_rx_data_arr_i(i)(199) xor x"0b"; -- VFAT22 pair 0 (GBT7 elink 18)
                queso_data_unmasked_arr_o(i)(200) <= queso_rx_data_arr_i(i)(200) xor x"0c"; -- VFAT22 pair 1 (GBT7 elink 21)
                queso_data_unmasked_arr_o(i)(201) <= queso_rx_data_arr_i(i)(201) xor x"0d"; -- VFAT22 pair 2 (GBT7 elink 20)
                queso_data_unmasked_arr_o(i)(202) <= queso_rx_data_arr_i(i)(202) xor x"0e"; -- VFAT22 pair 3 (GBT7 elink 23)
                queso_data_unmasked_arr_o(i)(203) <= queso_rx_data_arr_i(i)(203) xor x"0f"; -- VFAT22 pair 4 (GBT7 elink 22)
                queso_data_unmasked_arr_o(i)(204) <= queso_rx_data_arr_i(i)(204) xor x"10"; -- VFAT22 pair 5 (GBT7 elink 27)
                queso_data_unmasked_arr_o(i)(205) <= queso_rx_data_arr_i(i)(205) xor x"11"; -- VFAT22 pair 6 (GBT7 elink 26)
                queso_data_unmasked_arr_o(i)(206) <= queso_rx_data_arr_i(i)(206) xor x"12"; -- VFAT22 pair 7 (GBT7 elink 25)
                queso_data_unmasked_arr_o(i)(208) <= queso_rx_data_arr_i(i)(208) xor x"33"; -- VFAT23 pair 0 (GBT7 elink 03)
                queso_data_unmasked_arr_o(i)(209) <= queso_rx_data_arr_i(i)(209) xor x"34"; -- VFAT23 pair 1 (GBT7 elink 13)
                queso_data_unmasked_arr_o(i)(210) <= queso_rx_data_arr_i(i)(210) xor x"35"; -- VFAT23 pair 2 (GBT7 elink 05)
                queso_data_unmasked_arr_o(i)(211) <= queso_rx_data_arr_i(i)(211) xor x"36"; -- VFAT23 pair 3 (GBT7 elink 01)
                queso_data_unmasked_arr_o(i)(212) <= queso_rx_data_arr_i(i)(212) xor x"37"; -- VFAT23 pair 4 (GBT7 elink 00)
                queso_data_unmasked_arr_o(i)(213) <= queso_rx_data_arr_i(i)(213) xor x"38"; -- VFAT23 pair 5 (GBT7 elink 02)
                queso_data_unmasked_arr_o(i)(214) <= queso_rx_data_arr_i(i)(214) xor x"39"; -- VFAT23 pair 6 (GBT7 elink 12)
                queso_data_unmasked_arr_o(i)(215) <= queso_rx_data_arr_i(i)(215) xor x"3a"; -- VFAT23 pair 7 (GBT7 elink 04)
            end if;
        end process;
    end generate;
    
end queso_link_unmask_arch;
