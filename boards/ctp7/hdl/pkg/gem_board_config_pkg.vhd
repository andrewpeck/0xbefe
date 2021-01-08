-------------------------------------------------------------------------------
--                                                                            
--       Unit Name: gem_board_config_package
--                                                                            
--     Description: Configuration for CTP7 board
--
--                                                                            
-------------------------------------------------------------------------------
--                                                                            
--           Notes:                                                           
--                                                                            
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

--============================================================================
--                                                         Package declaration
--============================================================================
package gem_board_config_package is

    function get_num_gbts_per_oh(gem_station : integer) return integer;
    function get_num_vfats_per_oh(gem_station : integer) return integer;
    function get_gbt_widebus(gem_station, oh_version : integer) return integer;
    
    ----------------------------------------------------------------------------------------------
    
    constant CFG_GEM_STATION        : integer range 0 to 2 := 1; -- 0 = ME0; 1 = GE1/1; 2 = GE2/1
    constant CFG_OH_VERSION         : integer := 2; -- for now this is only relevant to GE2/1 where v2 OH has different elink map, and uses widebus mode
    constant CFG_NUM_OF_OHs         : integer := 12;   -- total number of OHs to instanciate (remember to adapt the CFG_OH_LINK_CONFIG_ARR accordingly)
    constant CFG_NUM_GBTS_PER_OH    : integer := get_num_gbts_per_oh(CFG_GEM_STATION);
    constant CFG_NUM_VFATS_PER_OH   : integer := get_num_vfats_per_oh(CFG_GEM_STATION);
    constant CFG_GBT_WIDEBUS        : integer := get_gbt_widebus(CFG_GEM_STATION, CFG_OH_VERSION);
    
    constant CFG_USE_TRIG_TX_LINKS  : boolean := true; -- if true, then trigger transmitters will be instantiated (used to connect to EMTF)
    constant CFG_NUM_TRIG_TX        : integer := 8; -- number of trigger transmitters used to connect to EMTF

    constant CFG_BOARD_TYPE         : std_logic_vector(3 downto 0) := x"1"; -- 0 = GLIB; 1 = CTP7
    
    ------------ DEBUG FLAGS ------------
    constant CFG_DEBUG_GBT                  : boolean := true; -- if set to true, an ILA will be instantiated which allows probing any GBT link
    constant CFG_DEBUG_OH                   : boolean := true; -- if set to true, and ILA will be instantiated on VFATs and OH trigger link
    constant CFG_DEBUG_DAQ                  : boolean := true;
    constant CFG_DEBUG_TRIGGER              : boolean := true;

    constant CFG_LPGBT_2P56G_LOOPBACK_TEST  : boolean := false; -- setting this to true will result in a test firmware with 2.56Gbps transceivers only usable for PRBS loopback tests with LpGBT chip, note that none of the GEM logic will be included (also no LpGBT core will be instantiated)
    constant CFG_LPGBT_EMTF_LOOP_TEST       : boolean := false;  -- setting this to true will instantiate an LpGBT RX core on the CFG_LPGBT_EMTF_RX_GTH, and an ILA. !!!!! NOTE: need to increase change the MGT 64-67 type to gth_10p24g and uncomment the constraints
    constant CFG_LPGBT_EMTF_LOOP_RX_GTH     : integer := 66;
    constant CFG_LPGBT_EMTF_LOOP_TX_LINK    : integer := 7;
    constant CFG_ILA_GBT0_MGT_EN            : boolean := false; -- setting this to 1 enables the instantiation of ILA on GBT link 0 MGT

    --========================--
    --== Link configuration ==--
    --========================--

    -- defines the GT index for each type of OH link
    type t_oh_link_config is record
        gbt0_link       : integer range 0 to 79; -- main GBT link on OH v2b
        gbt1_link       : integer range 0 to 79; -- with OH v2b this is just for test, this will be needed with OH v3
        gbt2_link       : integer range 0 to 79; -- with OH v2b this is just for test, this will be needed with OH v3
        trig0_rx_link   : integer range 0 to 79; -- trigger RX link for clusters 0, 1, 2, 3
        trig1_rx_link   : integer range 0 to 79; -- trigger RX link for clusters 4, 5, 6, 7
    end record t_oh_link_config;
    
    type t_oh_link_config_arr is array (0 to 11) of t_oh_link_config;

    constant CFG_OH_LINK_CONFIG_ARR_GE11 : t_oh_link_config_arr := (
        (0, 1, 2, 40, 41), 
        (3, 4, 5, 42, 43),
        (6, 7, 8, 44, 45), 
        (9, 10, 11, 46, 47),

        (12, 13, 14, 48, 49), 
        (15, 16, 17, 50, 51), 
        (18, 19, 20, 52, 53), 
        (21, 22, 23, 54, 55), 

        (24, 25, 26, 56, 57), 
        (27, 28, 29, 58, 59), 
        (30, 31, 32, 68, 69), 
        (33, 34, 35, 70, 71) 
    );

    constant CFG_OH_LINK_CONFIG_ARR_GE21 : t_oh_link_config_arr := (
        (0, 1, 72, 40, 41), 
        (2, 3, 72, 42, 43),
        (4, 5, 72, 44, 45), 
        (6, 7, 72, 46, 47),
        (8, 9, 72, 48, 49), 
        (10, 11, 72, 50, 51),
         
        (12, 13, 72, 52, 53), 
        (14, 15, 72, 54, 55), 
        (16, 17, 72, 56, 57), 
        (18, 19, 72, 58, 59), 
        (20, 21, 72, 68, 69), 
        (22, 23, 72, 70, 71) 
    );

    constant CFG_OH_LINK_CONFIG_ARR_ME0 : t_oh_link_config_arr := (
        (0, 1, 72, 72, 72), 
        (2, 3, 72, 72, 72),
        (4, 5, 72, 72, 72), 
        (6, 7, 72, 72, 72),
        (8, 9, 72, 72, 72), 
        (10, 11, 72, 72, 72),
         
        (12, 13, 72, 72, 72), 
        (14, 15, 72, 72, 72), 
        (16, 17, 72, 72, 72), 
        (18, 19, 72, 72, 72), 
        (20, 21, 72, 72, 72), 
        (22, 23, 72, 72, 72) 
    );

    function get_oh_link_config_arr(gem_station: integer; ge11_config, ge21_config, me0_config : t_oh_link_config_arr) return t_oh_link_config_arr;
    constant CFG_OH_LINK_CONFIG_ARR : t_oh_link_config_arr := get_oh_link_config_arr(CFG_GEM_STATION, CFG_OH_LINK_CONFIG_ARR_GE11, CFG_OH_LINK_CONFIG_ARR_GE21, CFG_OH_LINK_CONFIG_ARR_ME0);

    type t_trig_tx_link_config_arr is array (0 to CFG_NUM_TRIG_TX - 1) of integer range 0 to 79;
    
--    constant CFG_TRIG_TX_LINK_CONFIG_ARR : t_trig_tx_link_config_arr := (48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59);
    constant CFG_TRIG_TX_LINK_CONFIG_ARR : t_trig_tx_link_config_arr := (48, 49, 50, 51, 52, 53, 54, 59);


    -- this record is used in CXP fiber to GTH map (holding tx and rx GTH index)
    type t_cxp_fiber_to_gth_link is record
        tx      : integer range 0 to 67; -- GTH TX index (#67 means disconnected/non-existing)
        rx      : integer range 0 to 67; -- GTH RX index (#67 means disconnected/non-existing)
    end record;
    
    -- this array is meant to hold mapping from CXP fiber index to GTH TX and RX indexes
    type t_cxp_fiber_to_gth_link_map is array (0 to 72) of t_cxp_fiber_to_gth_link;

    -- defines the GTH TX and RX index for each index of the CXP and MP fiber
    -- CXP0: fibers 0-11
    -- CXP1: fibers 12-23
    -- CXP2: fibers 24-35
    -- MP0 RX: fibers 36-47
    -- MP1 RX: fibers 48-59
    -- MP TX : fibers 48-59
    -- MP2 RX: fibers 60-71
    -- DUMMY: fiber 72 - use this for unconnected channels (e.g. the non-existing GBT#2 in GE2/1)
    -- note that GTH channel #67 is used as a placeholder for fiber links that are not connected to the FPGA
    constant CFG_CXP_FIBER_TO_GTH_MAP : t_cxp_fiber_to_gth_link_map := (
        --=== CXP0 ===--
        (1, 2), -- fiber 0
        (3, 0), -- fiber 1
        (5, 4), -- fiber 2
        (0, 3), -- fiber 3
        (2, 5), -- fiber 4
        (4, 1), -- fiber 5
        (10, 7), -- fiber 6
        (8, 9), -- fiber 7
        (6, 10), -- fiber 8
        (11, 6), -- fiber 9
        (9, 8), -- fiber 10
        (7, 11), -- fiber 11
        --=== CXP1 ===--        
        (13, 15), -- fiber 12
        (15, 12), -- fiber 13
        (17, 16), -- fiber 14
        (12, 14), -- fiber 15 
        (14, 18), -- fiber 16
        (16, 13), -- fiber 17
        (22, 19), -- fiber 18
        (20, 23), -- fiber 19
        (18, 20), -- fiber 20
        (23, 17), -- fiber 21
        (21, 21), -- fiber 22
        (19, 22), -- fiber 23
        --=== CXP2 ===--        
        (25, 27), -- fiber 24
        (27, 24), -- fiber 25
        (29, 28), -- fiber 26
        (24, 26), -- fiber 27
        (26, 30), -- fiber 28
        (28, 25), -- fiber 29
        (34, 31), -- fiber 30
        (32, 35), -- fiber 31
        (30, 32), -- fiber 32
        (35, 29), -- fiber 33
        (33, 33), -- fiber 34
        (31, 34), -- fiber 35
        --=== no TX / MP0 RX ===--
        (67, 67), -- fiber 36 -- RX NULL (not connected)
        (67, 66), -- fiber 37
        (67, 64), -- fiber 38
        (67, 65), -- fiber 39
        (67, 62), -- fiber 40
        (67, 63), -- fiber 41
        (67, 61), -- fiber 42
        (67, 60), -- fiber 43
        (67, 59), -- fiber 44
        (67, 58), -- fiber 45
        (67, 57), -- fiber 46
        (67, 56), -- fiber 47
        --=== MP TX / MP1 RX ===--
        (59, 54), -- fiber 48 
        (56, 55), -- fiber 49
        (63, 52), -- fiber 50
        (52, 53), -- fiber 51
        (62, 50), -- fiber 52
        (53, 51), -- fiber 53
        (61, 49), -- fiber 54
        (54, 48), -- fiber 55
        (60, 47), -- fiber 56
        (55, 46), -- fiber 57
        (58, 45), -- fiber 58
        (57, 44), -- fiber 59
        --=== no TX / MP2 RX ===--
        (67, 67),  -- fiber 60 -- RX NULL (not connected)
        (67, 67), -- fiber 61 -- RX NULL (not connected)
        (67, 43), -- fiber 62
        (67, 67), -- fiber 63 -- RX NULL (not connected)
        (67, 42), -- fiber 64 
        (67, 67), -- fiber 65 -- RX NULL (not connected)
        (67, 40), -- fiber 66
        (67, 36), -- fiber 67 -- RX inverted
        (67, 41), -- fiber 68 
        (67, 37), -- fiber 69 -- RX inverted
        (67, 38), -- fiber 70
        (67, 39), -- fiber 71        
        --=== DUMMY channel - use for unconnected channels ===--
        (67, 67) -- fiber 72        
    );
    
end gem_board_config_package;

package body gem_board_config_package is

    function get_num_gbts_per_oh(gem_station : integer) return integer is
    begin
        if gem_station = 0 then
            return 2;
        elsif gem_station = 1 then
            return 3;
        elsif gem_station = 2 then
            return 2;
        else -- hmm whatever, lets say 3
            return 3;  
        end if;
    end function get_num_gbts_per_oh;
    
    function get_num_vfats_per_oh(gem_station : integer) return integer is
    begin
        if gem_station = 0 then
            return 6;
        elsif gem_station = 1 then
            return 24;
        elsif gem_station = 2 then
            return 12;
        else -- hmm whatever, lets say 24
            return 24;  
        end if;
    end function get_num_vfats_per_oh;
    
    function get_oh_link_config_arr(gem_station: integer; ge11_config, ge21_config, me0_config : t_oh_link_config_arr) return t_oh_link_config_arr is
    begin
        if gem_station = 0 then
            return me0_config;
        elsif gem_station = 1 then
            return ge11_config;
        elsif gem_station = 2 then
            return ge21_config;
        else -- hmm whatever, lets say GE1/1
            return ge11_config;  
        end if;
    end function get_oh_link_config_arr;
    
    function get_gbt_widebus(gem_station, oh_version : integer) return integer is
    begin
        if gem_station = 2 and oh_version > 1 then
            return 1;
        else
            return 0;
        end if;
    end function get_gbt_widebus;
    
end gem_board_config_package;
--============================================================================
--                                                                 Package end 
--============================================================================

