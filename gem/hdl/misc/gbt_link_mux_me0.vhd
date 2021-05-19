------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2019-08-29
-- Module Name:    LPGBT_LINK_MUX
-- Description:    This module is used to direct the LpGBT links either to the VFATs (standard operation) or to the GEM_TESTS module 
------------------------------------------------------------------------------------------------------------------------------------------------------

-- ========================== VFAT mapping on ME0 GEB (Wide) ==========================--
-- OH0 (ASIAGO #1 on GEB):




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

    type t_gbt_idx_array is array(integer range 0 to 23) of integer range 0 to g_NUM_GBTS_PER_OH - 1;
    constant VFAT_TO_GBT_MAP           : t_gbt_idx_array := (1, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
    signal gbt_rx_ready_arr             : std_logic_vector((g_NUM_OF_OHs * g_NUM_GBTS_PER_OH) - 1 downto 0);

begin

--inversions incorperated in ASIAGO config

    gbt_ready_arr_o <= gbt_rx_ready_arr;
     
    g_ohs : for i in 0 to g_NUM_OF_OHs - 1 generate

        gbt_rx_ready_arr(i * 2 + 0) <= gbt_link_status_arr_i(i * 2 + 0).gbt_rx_ready;
        gbt_rx_ready_arr(i * 2 + 1) <= gbt_link_status_arr_i(i * 2 + 1).gbt_rx_ready;

        --------- RX ---------
        gbt_ic_rx_data_arr_o(i * 2 + 0) <= gbt_rx_data_arr_i(i * 2 + 0).rx_ic_data(0) & gbt_rx_data_arr_i(i * 2 + 0).rx_ic_data(1);
        gbt_ic_rx_data_arr_o(i * 2 + 1) <= gbt_rx_data_arr_i(i * 2 + 0).rx_ec_data(0) & gbt_rx_data_arr_i(i * 2 + 0).rx_ec_data(1);

        gbt_rx_ready_arr(i * 2 + 0) <= gbt_link_status_arr_i(i * 2 + 0).gbt_rx_ready;
        gbt_rx_ready_arr(i * 2 + 1) <= gbt_link_status_arr_i(i * 2 + 1).gbt_rx_ready;

        g_vfat_gbt_ready: for vfat in 0 to 23 generate
            vfat3_gbt_ready_arr_o(i)(vfat) <= gbt_rx_ready_arr(i * 2 + VFAT_TO_GBT_MAP(vfat));
        end generate;

        vfat3_rx_data_arr_o(i)(23)  <= (others => '0');
        vfat3_rx_data_arr_o(i)(22)  <= (others => '0');
        vfat3_rx_data_arr_o(i)(21)  <= (others => '0');
        vfat3_rx_data_arr_o(i)(20)  <= (others => '0');
        vfat3_rx_data_arr_o(i)(19)  <= (others => '0');
        vfat3_rx_data_arr_o(i)(18)  <= (others => '0');
        vfat3_rx_data_arr_o(i)(17)  <= (others => '0');
        vfat3_rx_data_arr_o(i)(16)  <= (others => '0');
        vfat3_rx_data_arr_o(i)(15)  <= (others => '0');
        vfat3_rx_data_arr_o(i)(14)  <= (others => '0');
        vfat3_rx_data_arr_o(i)(13) <= (others => '0');
        vfat3_rx_data_arr_o(i)(12) <= (others => '0');
        vfat3_rx_data_arr_o(i)(11) <= (others => '0');
        vfat3_rx_data_arr_o(i)(10) <= (others => '0');
        vfat3_rx_data_arr_o(i)(9) <= (others => '0');
        vfat3_rx_data_arr_o(i)(8) <= (others => '0');
        vfat3_rx_data_arr_o(i)(7) <= (others => '0');
        vfat3_rx_data_arr_o(i)(6) <= (others => '0');
        
        -- DAQ 
        vfat3_rx_data_arr_o(i)(5) <=  gbt_rx_data_arr_i(i * 2 + 0).rx_data(207 downto 200);
        vfat3_rx_data_arr_o(i)(4) <=  gbt_rx_data_arr_i(i * 2 + 0).rx_data(223 downto 216);
        vfat3_rx_data_arr_o(i)(3) <=  gbt_rx_data_arr_i(i * 2 + 0).rx_data(31 downto 24);
        vfat3_rx_data_arr_o(i)(2) <=  gbt_rx_data_arr_i(i * 2 + 1).rx_data(95 downto 88);
        vfat3_rx_data_arr_o(i)(1) <=  gbt_rx_data_arr_i(i * 2 + 1).rx_data(199 downto 192);
        vfat3_rx_data_arr_o(i)(0) <=  gbt_rx_data_arr_i(i * 2 + 1).rx_data(55 downto 48);

        -- SBITS
        vfat3_sbits_arr_o(i)(0 )(7  downto 0 ) <=     gbt_rx_data_arr_i(i * 2 + 1).rx_data(31  downto 24 ); -- VFAT0  Pair 0 LPGBT=Slave
        vfat3_sbits_arr_o(i)(0 )(15 downto 8 ) <=     gbt_rx_data_arr_i(i * 2 + 1).rx_data(111 downto 104); -- VFAT0  Pair 1 LPGBT=Slave
        vfat3_sbits_arr_o(i)(0 )(23 downto 16) <=     gbt_rx_data_arr_i(i * 2 + 1).rx_data(47  downto 40 ); -- VFAT0  Pair 2 LPGBT=Slave
        vfat3_sbits_arr_o(i)(0 )(31 downto 24) <=     gbt_rx_data_arr_i(i * 2 + 1).rx_data(15  downto 8  ); -- VFAT0  Pair 3 LPGBT=Slave
        vfat3_sbits_arr_o(i)(0 )(39 downto 32) <=     gbt_rx_data_arr_i(i * 2 + 1).rx_data(7   downto 0  ); -- VFAT0  Pair 4 LPGBT=Slave
        vfat3_sbits_arr_o(i)(0 )(47 downto 40) <=     gbt_rx_data_arr_i(i * 2 + 1).rx_data(23  downto 16 ); -- VFAT0  Pair 5 LPGBT=Slave
        vfat3_sbits_arr_o(i)(0 )(55 downto 48) <=     gbt_rx_data_arr_i(i * 2 + 1).rx_data(103 downto 96 ); -- VFAT0  Pair 6 LPGBT=Slave
        vfat3_sbits_arr_o(i)(0 )(63 downto 56) <=     gbt_rx_data_arr_i(i * 2 + 1).rx_data(39  downto 32 ); -- VFAT0  Pair 7 LPGBT=Slave
        vfat3_sbits_arr_o(i)(1 )(7  downto 0 ) <=     gbt_rx_data_arr_i(i * 2 + 1).rx_data(151 downto 144); -- VFAT1  Pair 0 LPGBT=Slave
        vfat3_sbits_arr_o(i)(1 )(15 downto 8 ) <=     gbt_rx_data_arr_i(i * 2 + 1).rx_data(175 downto 168); -- VFAT1  Pair 1 LPGBT=Slave
        vfat3_sbits_arr_o(i)(1 )(23 downto 16) <=     gbt_rx_data_arr_i(i * 2 + 1).rx_data(167 downto 160); -- VFAT1  Pair 2 LPGBT=Slave
        vfat3_sbits_arr_o(i)(1 )(31 downto 24) <=     gbt_rx_data_arr_i(i * 2 + 1).rx_data(191 downto 184); -- VFAT1  Pair 3 LPGBT=Slave
        vfat3_sbits_arr_o(i)(1 )(39 downto 32) <=     gbt_rx_data_arr_i(i * 2 + 1).rx_data(183 downto 176); -- VFAT1  Pair 4 LPGBT=Slave
        vfat3_sbits_arr_o(i)(1 )(47 downto 40) <=     gbt_rx_data_arr_i(i * 2 + 1).rx_data(223 downto 216); -- VFAT1  Pair 5 LPGBT=Slave
        vfat3_sbits_arr_o(i)(1 )(55 downto 48) <=     gbt_rx_data_arr_i(i * 2 + 1).rx_data(215 downto 208); -- VFAT1  Pair 6 LPGBT=Slave
        vfat3_sbits_arr_o(i)(1 )(63 downto 56) <=     gbt_rx_data_arr_i(i * 2 + 1).rx_data(207 downto 200); -- VFAT1  Pair 7 LPGBT=Slave
        vfat3_sbits_arr_o(i)(2 )(7  downto 0 ) <=     gbt_rx_data_arr_i(i * 2 + 1).rx_data(143 downto 136); -- VFAT2  Pair 0 LPGBT=Slave
        vfat3_sbits_arr_o(i)(2 )(15 downto 8 ) <=     gbt_rx_data_arr_i(i * 2 + 1).rx_data(159 downto 152); -- VFAT2  Pair 1 LPGBT=Slave
        vfat3_sbits_arr_o(i)(2 )(23 downto 16) <=     gbt_rx_data_arr_i(i * 2 + 1).rx_data(119 downto 112); -- VFAT2  Pair 2 LPGBT=Slave
        vfat3_sbits_arr_o(i)(2 )(31 downto 24) <=     gbt_rx_data_arr_i(i * 2 + 1).rx_data(63  downto 56 ); -- VFAT2  Pair 3 LPGBT=Slave
        vfat3_sbits_arr_o(i)(2 )(39 downto 32) <=     gbt_rx_data_arr_i(i * 2 + 1).rx_data(79  downto 72 ); -- VFAT2  Pair 4 LPGBT=Slave
        vfat3_sbits_arr_o(i)(2 )(47 downto 40) <=     gbt_rx_data_arr_i(i * 2 + 1).rx_data(87  downto 80 ); -- VFAT2  Pair 5 LPGBT=Slave
        vfat3_sbits_arr_o(i)(2 )(55 downto 48) <=     gbt_rx_data_arr_i(i * 2 + 1).rx_data(127 downto 120); -- VFAT2  Pair 6 LPGBT=Slave
        vfat3_sbits_arr_o(i)(2 )(63 downto 56) <=     gbt_rx_data_arr_i(i * 2 + 1).rx_data(71  downto 64 ); -- VFAT2  Pair 7 LPGBT=Slave
        vfat3_sbits_arr_o(i)(3 )(7  downto 0 ) <=     gbt_rx_data_arr_i(i * 2 + 0).rx_data(55  downto 48 ); -- VFAT3  Pair 0 LPGBT=Master
        vfat3_sbits_arr_o(i)(3 )(15 downto 8 ) <=     gbt_rx_data_arr_i(i * 2 + 0).rx_data(63  downto 56 ); -- VFAT3  Pair 1 LPGBT=Master
        vfat3_sbits_arr_o(i)(3 )(23 downto 16) <=     gbt_rx_data_arr_i(i * 2 + 0).rx_data(79  downto 72 ); -- VFAT3  Pair 2 LPGBT=Master
        vfat3_sbits_arr_o(i)(3 )(31 downto 24) <=     gbt_rx_data_arr_i(i * 2 + 0).rx_data(39  downto 32 ); -- VFAT3  Pair 3 LPGBT=Master
        vfat3_sbits_arr_o(i)(3 )(39 downto 32) <=     gbt_rx_data_arr_i(i * 2 + 0).rx_data(47  downto 40 ); -- VFAT3  Pair 4 LPGBT=Master
        vfat3_sbits_arr_o(i)(3 )(47 downto 40) <=     gbt_rx_data_arr_i(i * 2 + 0).rx_data(23  downto 16 ); -- VFAT3  Pair 5 LPGBT=Master
        vfat3_sbits_arr_o(i)(3 )(55 downto 48) <=     gbt_rx_data_arr_i(i * 2 + 0).rx_data(7   downto 0  ); -- VFAT3  Pair 6 LPGBT=Master
        vfat3_sbits_arr_o(i)(3 )(63 downto 56) <=     gbt_rx_data_arr_i(i * 2 + 0).rx_data(15  downto 8  ); -- VFAT3  Pair 7 LPGBT=Master
        vfat3_sbits_arr_o(i)(4 )(7  downto 0 ) <=     gbt_rx_data_arr_i(i * 2 + 0).rx_data(127 downto 120); -- VFAT4  Pair 0 LPGBT=Master
        vfat3_sbits_arr_o(i)(4 )(15 downto 8 ) <=     gbt_rx_data_arr_i(i * 2 + 0).rx_data(119 downto 112); -- VFAT4  Pair 1 LPGBT=Master
        vfat3_sbits_arr_o(i)(4 )(23 downto 16) <=     gbt_rx_data_arr_i(i * 2 + 0).rx_data(103 downto 96 ); -- VFAT4  Pair 2 LPGBT=Master
        vfat3_sbits_arr_o(i)(4 )(31 downto 24) <=     gbt_rx_data_arr_i(i * 2 + 0).rx_data(87  downto 80 ); -- VFAT4  Pair 3 LPGBT=Master
        vfat3_sbits_arr_o(i)(4 )(39 downto 32) <=     gbt_rx_data_arr_i(i * 2 + 0).rx_data(95  downto 88 ); -- VFAT4  Pair 4 LPGBT=Master
        vfat3_sbits_arr_o(i)(4 )(47 downto 40) <=     gbt_rx_data_arr_i(i * 2 + 0).rx_data(111 downto 104); -- VFAT4  Pair 5 LPGBT=Master
        vfat3_sbits_arr_o(i)(4 )(55 downto 48) <=     gbt_rx_data_arr_i(i * 2 + 0).rx_data(159 downto 152); -- VFAT4  Pair 6 LPGBT=Master
        vfat3_sbits_arr_o(i)(4 )(63 downto 56) <=     gbt_rx_data_arr_i(i * 2 + 0).rx_data(143 downto 136); -- VFAT4  Pair 7 LPGBT=Master
        vfat3_sbits_arr_o(i)(5 )(7  downto 0 ) <=     gbt_rx_data_arr_i(i * 2 + 0).rx_data(135 downto 128); -- VFAT5  Pair 0 LPGBT=Master
        vfat3_sbits_arr_o(i)(5 )(15 downto 8 ) <=     gbt_rx_data_arr_i(i * 2 + 0).rx_data(151 downto 144); -- VFAT5  Pair 1 LPGBT=Master
        vfat3_sbits_arr_o(i)(5 )(23 downto 16) <=     gbt_rx_data_arr_i(i * 2 + 0).rx_data(167 downto 160); -- VFAT5  Pair 2 LPGBT=Master
        vfat3_sbits_arr_o(i)(5 )(31 downto 24) <=     gbt_rx_data_arr_i(i * 2 + 0).rx_data(183 downto 176); -- VFAT5  Pair 3 LPGBT=Master
        vfat3_sbits_arr_o(i)(5 )(39 downto 32) <=     gbt_rx_data_arr_i(i * 2 + 0).rx_data(199 downto 192); -- VFAT5  Pair 4 LPGBT=Master
        vfat3_sbits_arr_o(i)(5 )(47 downto 40) <=     gbt_rx_data_arr_i(i * 2 + 0).rx_data(215 downto 208); -- VFAT5  Pair 5 LPGBT=Master
        vfat3_sbits_arr_o(i)(5 )(55 downto 48) <=     gbt_rx_data_arr_i(i * 2 + 0).rx_data(175 downto 168); -- VFAT5  Pair 6 LPGBT=Master
        vfat3_sbits_arr_o(i)(5 )(63 downto 56) <=     gbt_rx_data_arr_i(i * 2 + 0).rx_data(191 downto 184); -- VFAT5  Pair 7 LPGBT=Master
            

        --------- TX ---------
        gbt_tx_data_arr_o(i * 2 + 0).tx_ec_data <= gbt_ic_tx_data_arr_i(i * 2 + 1)(0) & gbt_ic_tx_data_arr_i(i * 2 + 1)(1); -- reverse the bits
        gbt_tx_data_arr_o(i * 2 + 1).tx_ec_data <= gbt_ic_tx_data_arr_i(i * 2 + 1)(0) & gbt_ic_tx_data_arr_i(i * 2 + 1)(1); -- reverse the bits
        
        gbt_tx_data_arr_o(i * 2 + 0).tx_ic_data <= gbt_ic_tx_data_arr_i(i * 2 + 0)(0) & gbt_ic_tx_data_arr_i(i * 2 + 0)(1); -- reverse the bits
        gbt_tx_data_arr_o(i * 2 + 1).tx_ic_data <= gbt_ic_tx_data_arr_i(i * 2 + 0)(0) & gbt_ic_tx_data_arr_i(i * 2 + 0)(1); -- reverse the bits
        

        gbt_tx_data_arr_o(i * 2 + 0).tx_data(31 downto 24) <=  vfat3_tx_data_arr_i(i)(4); -- NOT CONNECTED ON THE ASIAGO, BUT JUST PUTTING IT HERE FOR A TEST SINCE 23:16 DOESNT SEEM TO BE WORKING
        gbt_tx_data_arr_o(i * 2 + 0).tx_data(23 downto 16) <=  vfat3_tx_data_arr_i(i)(4); -- this also covers position 5, but position 5 won't work since it needs addressing
        gbt_tx_data_arr_o(i * 2 + 0).tx_data(15 downto 8) <=  vfat3_tx_data_arr_i(i)(3); -- this also covers position 1, but position 1 won't work since it needs addressing
        gbt_tx_data_arr_o(i * 2 + 0).tx_data(7 downto 0) <=  vfat3_tx_data_arr_i(i)(2); -- this also covers position 0, but position 0 won't work since it needs addressing

	    --tricks firmware into thinking sub lpgbt linked to vfats 0 1 5. In reality these are mirrored from 2 3 4, but needs addressing implemented
        gbt_tx_data_arr_o(i * 2 + 1).tx_data(31 downto 24) <=  vfat3_tx_data_arr_i(i)(5); -- NOT CONNECTED ON THE ASIAGO, BUT JUST PUTTING IT HERE FOR A TEST SINCE 23:16 DOESNT SEEM TO BE WORKING
        gbt_tx_data_arr_o(i * 2 + 1).tx_data(23 downto 16) <=  vfat3_tx_data_arr_i(i)(5); -- this is just for a test since slave doesn't have RX, but this would work when connected to the master
        gbt_tx_data_arr_o(i * 2 + 1).tx_data(15 downto 8) <=  vfat3_tx_data_arr_i(i)(1); -- this is just for a test since slave doesn't have RX, but this would work when connected to the master
        gbt_tx_data_arr_o(i * 2 + 1).tx_data(7 downto 0) <=  vfat3_tx_data_arr_i(i)(0); -- this is just for a test since slave doesn't have RX, but this would work when connected to the master


    end generate;

end gbt_link_mux_me0_arch;
