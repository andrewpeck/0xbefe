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

use work.mgt_pkg.all;
use work.project_config.all;

--============================================================================
--                                                         Package declaration
--============================================================================
package gem_board_config_package is

    function get_num_gbts_per_oh(gem_station : integer) return integer;
    function get_num_vfats_per_oh(gem_station : integer) return integer;
    function get_gbt_widebus(gem_station, oh_version : integer) return integer;
    
    ------------ Board specific constants ------------
    constant CFG_BOARD_TYPE         : std_logic_vector(3 downto 0) := x"3"; -- 0 = GLIB; 1 = CTP7; 2 = CVP13; 3 = APEX; 4 = APd1
    constant CFG_BOARD_MAX_LINKS    : integer := 16;

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
    
    --========================--
    --== Link configuration ==--
    --========================--

    -- defines the GT index for each type of OH link
    type t_oh_link_config is record
        gbt0_link       : integer range 0 to CFG_BOARD_MAX_LINKS; -- main GBT link on OH v2b
        gbt1_link       : integer range 0 to CFG_BOARD_MAX_LINKS; -- with OH v2b this is just for test, this will be needed with OH v3
        gbt2_link       : integer range 0 to CFG_BOARD_MAX_LINKS; -- with OH v2b this is just for test, this will be needed with OH v3
        trig0_rx_link   : integer range 0 to CFG_BOARD_MAX_LINKS; -- trigger RX link for clusters 0, 1, 2, 3
        trig1_rx_link   : integer range 0 to CFG_BOARD_MAX_LINKS; -- trigger RX link for clusters 4, 5, 6, 7
    end record t_oh_link_config;
    
    type t_oh_link_config_arr is array (0 to 7) of t_oh_link_config;

    constant CFG_OH_LINK_CONFIG_ARR_GE11 : t_oh_link_config_arr := (
        (0, 1, 2, 8, 9), 
        (4, 5, 6, 12, 13),
        
        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS), 
        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS), 

        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS), 
        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS), 
         
        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS), 
        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS) 
    );

    constant CFG_OH_LINK_CONFIG_ARR_GE21 : t_oh_link_config_arr := (
        (2, 3, CFG_BOARD_MAX_LINKS, 0, 1), 
        (6, 7, CFG_BOARD_MAX_LINKS, 4, 5),
        
        (10, 11, CFG_BOARD_MAX_LINKS, 8, 9), 
        (14, 15, CFG_BOARD_MAX_LINKS, 12, 13),
        
        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS), 
        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS), 
         
        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS), 
        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS) 
    );

--    constant CFG_OH_LINK_CONFIG_ARR_GE21 : t_oh_link_config_arr := (
--        (0, 1, CFG_BOARD_MAX_LINKS, 2, 3), 
--        (4, 5, CFG_BOARD_MAX_LINKS, 6, 7),
--        
--        (8, 9, CFG_BOARD_MAX_LINKS, 10, 11), 
--        (12, 13, CFG_BOARD_MAX_LINKS, 14, 15),
--        
--        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS), 
--        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS), 
--         
--        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS), 
--        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS) 
--    );
    
    constant CFG_OH_LINK_CONFIG_ARR_ME0 : t_oh_link_config_arr := (
        (0, 1, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS), 
        (2, 3, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS),
        
        (4, 5, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS), 
        (6, 7, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS),
        
        (8, 9, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS), 
        (10, 11, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS),
         
        (12, 13, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS), 
        (14, 15, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)
    );

    function get_oh_link_config_arr(gem_station: integer; ge11_config, ge21_config, me0_config : t_oh_link_config_arr) return t_oh_link_config_arr;
    constant CFG_OH_LINK_CONFIG_ARR : t_oh_link_config_arr := get_oh_link_config_arr(CFG_GEM_STATION, CFG_OH_LINK_CONFIG_ARR_GE11, CFG_OH_LINK_CONFIG_ARR_GE21, CFG_OH_LINK_CONFIG_ARR_ME0);

    type t_trig_tx_link_config_arr is array (0 to CFG_NUM_TRIG_TX - 1) of integer range 0 to CFG_BOARD_MAX_LINKS;
    
    constant CFG_TRIG_TX_LINK_CONFIG_ARR : t_trig_tx_link_config_arr := (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS);
    
    --================================--
    -- Fiber to MGT mapping
    --================================--    
        
    -- this record is used in fiber to MGT map (holding tx and rx MGT index)
    type t_fiber_to_mgt_link is record
        tx      : integer range 0 to CFG_BOARD_MAX_LINKS; -- MGT TX index (#CFG_BOARD_MAX_LINKS means disconnected/non-existing)
        rx      : integer range 0 to CFG_BOARD_MAX_LINKS; -- MGT RX index (#CFG_BOARD_MAX_LINKS means disconnected/non-existing)
    end record;
    
    -- this array is meant to hold a mapping from fiber index to MGT TX and RX indices
    type t_fiber_to_mgt_link_map is array (0 to CFG_BOARD_MAX_LINKS) of t_fiber_to_mgt_link;

    -- defines the MGT TX and RX index for each fiber index
    -- for now considering this fake map of only 16 fibers:
    -- quad 129 = fibers 0-3   | channels 0-3
    -- quad 131 = fibers 4-7   | channels 8-11
    -- quad 130 = fibers 8-11  | channels 4-7 
    -- quad 132 = fibers 12-15 | channels 12-15
    -- DUMMY: fiber 16 - use this for unconnected channels (e.g. the non-existing GBT#2 in GE2/1)
    -- note that GTH channel #16 is used as a placeholder for fiber links that are not connected to the FPGA
    constant CFG_FIBER_TO_MGT_MAP : t_fiber_to_mgt_link_map := (
        --=== Quad 129 ===--
        (0, 0),   -- fiber 0  ! RX inverted
        (2, 1),   -- fiber 1  ! RX inverted
        (1, 2),   -- fiber 2
        (3, 3),   -- fiber 3
        --=== Quad 131 ===--
        (10, 8),  -- fiber 4  ! RX inverted ! TX inverted
        (9, 9),   -- fiber 5  ! RX inverted ! TX inverted
        (8, 10),  -- fiber 6  ! RX inverted ! TX inverted
        (11, 11), -- fiber 7  ! RX inverted ! TX inverted
        --=== Quad 130 ===--
        (5, 4),   -- fiber 8
        (7, 5),   -- fiber 9  ! RX inverted
        (4, 6),   -- fiber 10 ! RX inverted
        (6, 7),   -- fiber 11 ! RX inverted
        --=== Quad 132 ===--
        (12, 12), -- fiber 12 ! RX inverted
        (13, 13), -- fiber 13               ! TX inverted
        (15, 14), -- fiber 14               ! TX inverted
        (14, 15), -- fiber 15
        --=== DUMMY channel - use for unconnected channels ===--
        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)  -- dummy fiber
    );
    
    --================================--
    -- MGT configuration
    --================================--    
    
    constant CFG_MGT_NUM_CHANNELS : integer := CFG_BOARD_MAX_LINKS;
    constant CFG_MGT_MASTER_CHANNEL : integer := 4;
    
    type t_mgt_config_arr is array (0 to CFG_MGT_NUM_CHANNELS - 1) of t_mgt_config;
    
    
    constant CFG_MGT_LINK_CONFIG_GE11 : t_mgt_config_arr := (
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        

        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),

        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        

        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false)        
    );

    constant CFG_MGT_LINK_CONFIG_GE21 : t_mgt_config_arr := (
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        

        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),

        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        

        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false)        
    );

    constant CFG_MGT_LINK_CONFIG_ME0 : t_mgt_config_arr := (
        (link_type => MGT_LPGBT, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_LPGBT, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_LPGBT, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_LPGBT, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false),        

        (link_type => MGT_LPGBT, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_LPGBT, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_LPGBT, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_LPGBT, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false),

        (link_type => MGT_LPGBT, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_LPGBT, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_LPGBT, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_LPGBT, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false),        

        (link_type => MGT_LPGBT, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_LPGBT, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_LPGBT, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false),        
        (link_type => MGT_LPGBT, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false)        
    );

    function get_mgt_config(gem_station: integer; ge11_config, ge21_config, me0_config : t_mgt_config_arr) return t_mgt_config_arr;
    constant CFG_MGT_LINK_CONFIG : t_mgt_config_arr := get_mgt_config(CFG_GEM_STATION, CFG_MGT_LINK_CONFIG_GE11, CFG_MGT_LINK_CONFIG_GE21, CFG_MGT_LINK_CONFIG_ME0);

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

    function get_mgt_config(gem_station: integer; ge11_config, ge21_config, me0_config : t_mgt_config_arr) return t_mgt_config_arr is
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
    end function get_mgt_config;
    
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

