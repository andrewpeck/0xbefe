------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2020-06-05
-- Module Name:    GEM_BOARD_CONFIG_PACKAGE 
-- Description:    Configuration for the CVP13 card 
------------------------------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

use work.common_pkg.all;
use work.mgt_pkg.all;
use work.project_config.all;

--============================================================================
--                                                         Package declaration
--============================================================================
package board_config_package is

    function get_num_gbts_per_oh(gem_station : integer) return integer;
    function get_num_vfats_per_oh(gem_station : integer) return integer;
    function get_gbt_widebus(gem_station, oh_version : integer) return integer;

    ------------ Board specific constants ------------
    constant CFG_BOARD_TYPE         : std_logic_vector(3 downto 0) := x"1"; -- 0 = GLIB; 1 = CTP7; 2 = CVP13; 3 = APEX; 4 = APd1
    constant CFG_BOARD_MAX_LINKS    : integer := 72;

    ------------ GEM specific constants ------------
    constant CFG_GEM_STATION        : integer range 0 to 2 := PRJ_CFG_GEM_STATION; -- Controlled by the project_config.vhd:  0 = ME0; 1 = GE1/1; 2 = GE2/1
    constant CFG_OH_VERSION         : integer := PRJ_CFG_OH_VERSION; -- Controlled by the project_config.vhd:  OH version
    constant CFG_NUM_OF_OHs         : integer := PRJ_CFG_NUM_OF_OHs; -- Controlled by the project_config.vhd:  total number of OHs to instanciate
    constant CFG_NUM_GBTS_PER_OH    : integer := get_num_gbts_per_oh(CFG_GEM_STATION);
    constant CFG_NUM_VFATS_PER_OH   : integer := get_num_vfats_per_oh(CFG_GEM_STATION);
    constant CFG_GBT_WIDEBUS        : integer := get_gbt_widebus(CFG_GEM_STATION, CFG_OH_VERSION);
    
    constant CFG_USE_TRIG_TX_LINKS  : boolean := PRJ_CFG_USE_TRIG_TX_LINKS; -- Controlled by the project_config.vhd:  if true, then trigger transmitters will be instantiated (used to connect to EMTF)
    constant CFG_NUM_TRIG_TX        : integer := PRJ_CFG_NUM_TRIG_TX; -- Controlled by the project_config.vhd:  number of trigger transmitters used to connect to EMTF

    ------------ DAQ configuration ------------
    constant CFG_DAQ_EVTFIFO_DEPTH          : integer := 4096;
    constant CFG_DAQ_EVTFIFO_PROG_FULL_SET  : integer := 3072;
    constant CFG_DAQ_EVTFIFO_PROG_FULL_RESET: integer := 2047;
    constant CFG_DAQ_EVTFIFO_DATA_CNT_WIDTH : integer := 12;
    
    constant CFG_DAQ_INFIFO_DEPTH           : integer := 4096;
    constant CFG_DAQ_INFIFO_PROG_FULL_SET   : integer := 3072;
    constant CFG_DAQ_INFIFO_PROG_FULL_RESET : integer := 2047;
    constant CFG_DAQ_INFIFO_DATA_CNT_WIDTH  : integer := 12;

    constant CFG_DAQ_OUTPUT_DEPTH           : integer := 8192;
    constant CFG_DAQ_OUTPUT_PROG_FULL_SET   : integer := 4045;
    constant CFG_DAQ_OUTPUT_PROG_FULL_RESET : integer := 2730;
    constant CFG_DAQ_OUTPUT_DATA_CNT_WIDTH  : integer := 13;

    constant CFG_DAQ_L1AFIFO_DEPTH          : integer := 8192;
    constant CFG_DAQ_L1AFIFO_PROG_FULL_SET  : integer := 6144;
    constant CFG_DAQ_L1AFIFO_PROG_FULL_RESET: integer := 4096;
    constant CFG_DAQ_L1AFIFO_DATA_CNT_WIDTH : integer := 13;


    ------------ DEBUG FLAGS ------------
    constant CFG_DEBUG_GBT                  : boolean := true; -- if set to true, an ILA will be instantiated which allows probing any GBT link
    constant CFG_DEBUG_OH                   : boolean := true; -- if set to true, and ILA will be instantiated on VFATs and OH trigger link
    constant CFG_DEBUG_DAQ                  : boolean := true;
    constant CFG_DEBUG_TRIGGER              : boolean := true;
    
    ----------------------------------------------------------------------------------------------

    constant CFG_LPGBT_2P56G_LOOPBACK_TEST  : boolean := false; -- setting this to true will result in a test firmware with 2.56Gbps transceivers only usable for PRBS loopback tests with LpGBT chip, note that none of the GEM logic will be included (also no LpGBT core will be instantiated)
    constant CFG_LPGBT_EMTF_LOOP_TEST       : boolean := false;  -- setting this to true will instantiate an LpGBT RX core on the CFG_LPGBT_EMTF_RX_GTH, and an ILA. !!!!! NOTE: need to increase change the MGT 64-67 type to gth_10p24g and uncomment the constraints
    constant CFG_LPGBT_EMTF_LOOP_RX_GTH     : integer := 66;
    constant CFG_LPGBT_EMTF_LOOP_TX_LINK    : integer := 7;
    constant CFG_ILA_GBT0_MGT_EN            : boolean := false; -- setting this to 1 enables the instantiation of ILA on GBT link 0 MGT

    --========================--
    --== Link configuration ==--
    --========================--

    constant TXRX_NULL : integer := CFG_BOARD_MAX_LINKS;
    
    -- this record represents a single link (TXRX_NULL can be used to represent an unused tx or rx)
    type t_link is record
        tx      : integer range 0 to CFG_BOARD_MAX_LINKS;
        rx      : integer range 0 to CFG_BOARD_MAX_LINKS;
    end record;

    -- this constant can be used to represent an unused link
    constant LINK_NULL : t_link := (tx => TXRX_NULL, rx => TXRX_NULL);

    -- defines the GT index for each type of OH link
    type t_link_arr is array(integer range <>) of t_link;
    
    type t_oh_link_config is record
        gbt_links       : t_link_arr(0 to 7); -- GBT links
        trig_rx_links   : t_link_arr(0 to 1); -- GE1/1 trigger RX links
    end record t_oh_link_config;
    
    type t_oh_link_config_arr is array (0 to 11) of t_oh_link_config;

    constant CFG_OH_LINK_CONFIG_ARR_GE11 : t_oh_link_config_arr := (
        (((0,  0),  (1,  1),  (2,  2),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 40), (tx => TXRX_NULL, rx => 41))), 
        (((3,  3),  (4,  4),  (5,  5),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 42), (tx => TXRX_NULL, rx => 43))),
        (((6,  6),  (7,  7),  (8,  8),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 44), (tx => TXRX_NULL, rx => 45))), 
        (((9,  9),  (10, 10), (11, 11), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 46), (tx => TXRX_NULL, rx => 47))),
                                                                                                 
        (((12, 12), (13, 13), (14, 14), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 48), (tx => TXRX_NULL, rx => 49))), 
        (((15, 15), (16, 16), (17, 17), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 50), (tx => TXRX_NULL, rx => 51))), 
        (((18, 18), (19, 19), (20, 20), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 52), (tx => TXRX_NULL, rx => 53))), 
        (((21, 21), (22, 22), (23, 23), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 54), (tx => TXRX_NULL, rx => 55))), 
                                                                                                 
        (((24, 24), (25, 25), (26, 26), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 56), (tx => TXRX_NULL, rx => 57))), 
        (((27, 27), (28, 28), (29, 29), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 58), (tx => TXRX_NULL, rx => 59))), 
        (((30, 30), (31, 31), (32, 32), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 68), (tx => TXRX_NULL, rx => 69))), 
        (((33, 33), (34, 34), (35, 35), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 70), (tx => TXRX_NULL, rx => 71))) 
    );

    constant CFG_OH_LINK_CONFIG_ARR_GE21 : t_oh_link_config_arr := (
        (((0,  0),  (1,  1),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 40), (tx => TXRX_NULL, rx => 41))), 
        (((2,  2),  (3,  3),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 42), (tx => TXRX_NULL, rx => 43))),
        (((4,  4),  (5,  5),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 44), (tx => TXRX_NULL, rx => 45))), 
        (((6,  6),  (7,  7),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 46), (tx => TXRX_NULL, rx => 47))),
        (((8,  8),  (9,  9),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 48), (tx => TXRX_NULL, rx => 49))), 
        (((10, 10), (11, 11), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 50), (tx => TXRX_NULL, rx => 51))),
                                                                                                  
        (((12, 12), (13, 13), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 52), (tx => TXRX_NULL, rx => 53))), 
        (((14, 14), (15, 15), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 54), (tx => TXRX_NULL, rx => 55))), 
        (((16, 16), (17, 17), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 56), (tx => TXRX_NULL, rx => 57))), 
        (((18, 18), (19, 19), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 58), (tx => TXRX_NULL, rx => 59))), 
        (((20, 20), (21, 21), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 68), (tx => TXRX_NULL, rx => 69))), 
        (((22, 22), (23, 23), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 70), (tx => TXRX_NULL, rx => 71))) 
    );

    constant CFG_OH_LINK_CONFIG_ARR_ME0 : t_oh_link_config_arr := (
        (((0,  0),  (TXRX_NULL, 1),  (1,  2),  (TXRX_NULL, 3),  (2,  4),  (TXRX_NULL, 5),  (3,  6),  (TXRX_NULL, 7)),  (LINK_NULL, LINK_NULL)),
        (((12, 12), (TXRX_NULL, 13), (13, 14), (TXRX_NULL, 15), (14, 16), (TXRX_NULL, 17), (15, 18), (TXRX_NULL, 19)), (LINK_NULL, LINK_NULL)),
        (((24, 24), (TXRX_NULL, 25), (25, 26), (TXRX_NULL, 27), (26, 28), (TXRX_NULL, 29), (27, 30), (TXRX_NULL, 31)), (LINK_NULL, LINK_NULL)),
        
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))
    );

    function get_oh_link_config_arr(gem_station: integer; ge11_config, ge21_config, me0_config : t_oh_link_config_arr) return t_oh_link_config_arr;
    constant CFG_OH_LINK_CONFIG_ARR : t_oh_link_config_arr := get_oh_link_config_arr(CFG_GEM_STATION, CFG_OH_LINK_CONFIG_ARR_GE11, CFG_OH_LINK_CONFIG_ARR_GE21, CFG_OH_LINK_CONFIG_ARR_ME0);

    type t_trig_tx_link_config_arr is array (0 to CFG_NUM_TRIG_TX - 1) of integer range 0 to 79;
    
--    constant CFG_TRIG_TX_LINK_CONFIG_ARR : t_trig_tx_link_config_arr := (48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59);
    constant CFG_TRIG_TX_LINK_CONFIG_ARR : t_trig_tx_link_config_arr := (48, 49, 50, 51, 52, 53, 54, 59);


    -- this record is used in CXP fiber to GTH map (holding tx and rx GTH index)
    type t_cxp_fiber_to_gth_link is record
        tx      : integer range 0 to 68; -- GTH TX index (#68 means disconnected/non-existing)
        rx      : integer range 0 to 68; -- GTH RX index (#68 means disconnected/non-existing)
    end record;
    
    -- this array is meant to hold mapping from CXP fiber index to GTH TX and RX indexes
    type t_cxp_fiber_to_gth_link_map is array (0 to CFG_BOARD_MAX_LINKS) of t_cxp_fiber_to_gth_link;

    -- defines the GTH TX and RX index for each index of the CXP and MP fiber
    -- CXP0: fibers 0-11
    -- CXP1: fibers 12-23
    -- CXP2: fibers 24-35
    -- MP0 RX: fibers 36-47
    -- MP1 RX: fibers 48-59
    -- MP TX : fibers 48-59
    -- MP2 RX: fibers 60-71
    -- DUMMY: fiber 72 - use this for unconnected channels (e.g. the non-existing GBT#2 in GE2/1)
    -- note that GTH channel #68 is used as a placeholder for fiber links that are not connected to the FPGA
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
        (68, 68), -- fiber 36 -- RX NULL (not connected)
        (68, 66), -- fiber 37
        (68, 64), -- fiber 38
        (68, 65), -- fiber 39
        (68, 62), -- fiber 40
        (68, 63), -- fiber 41
        (68, 61), -- fiber 42
        (68, 60), -- fiber 43
        (68, 59), -- fiber 44
        (68, 58), -- fiber 45
        (68, 57), -- fiber 46
        (68, 56), -- fiber 47
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
        (68, 68),  -- fiber 60 -- RX NULL (not connected)
        (68, 68), -- fiber 61 -- RX NULL (not connected)
        (68, 43), -- fiber 62
        (68, 68), -- fiber 63 -- RX NULL (not connected)
        (68, 42), -- fiber 64 
        (68, 68), -- fiber 65 -- RX NULL (not connected)
        (68, 40), -- fiber 66
        (67, 36), -- fiber 67 -- RX inverted
        (68, 41), -- fiber 68 
        (68, 37), -- fiber 69 -- RX inverted
        (68, 38), -- fiber 70
        (68, 39), -- fiber 71        
        --=== DUMMY channel - use for unconnected channels ===--
        (68, 68) -- fiber 72        
    );
    
    -- we're not using this on CTP7 yet, so this is just a dummy to suppress errors
    type t_mgt_config_arr is array (0 to 1) of t_mgt_config;
    constant CFG_MGT_LINK_CONFIG : t_mgt_config_arr := (
        (link_type => MGT_LPGBT, use_refclk_01 => 1, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false, is_master => true, ibert_inst => true),   
        (link_type => MGT_LPGBT, use_refclk_01 => 1, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => true)   
    );    
    
end board_config_package;

package body board_config_package is

    function get_num_gbts_per_oh(gem_station : integer) return integer is
    begin
        if gem_station = 0 then
            return 8;
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
            return 24;
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
    
end board_config_package;
--============================================================================
--                                                                 Package end 
--============================================================================

