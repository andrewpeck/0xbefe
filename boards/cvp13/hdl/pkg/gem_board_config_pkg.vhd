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
package board_config_package is

    function get_num_gbts_per_oh(gem_station : integer) return integer;
    function get_num_vfats_per_oh(gem_station : integer) return integer;
    function get_gbt_widebus(gem_station, oh_version : integer) return integer;
    
    ------------ Board specific constants ------------
    constant CFG_BOARD_TYPE         : std_logic_vector(3 downto 0) := x"2"; -- 0 = GLIB; 1 = CTP7; 2 = CVP13; 3 = APEX; 4 = APd1
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

    constant CFG_DAQ_SPYFIFO_DEPTH          : integer := 32768;
    constant CFG_DAQ_SPYFIFO_PROG_FULL_SET  : integer := 24576;
    constant CFG_DAQ_SPYFIFO_PROG_FULL_RESET: integer := 16384;
    constant CFG_DAQ_SPYFIFO_DATA_CNT_WIDTH : integer := 17;

    constant CFG_DAQ_LASTEVT_FIFO_DEPTH     : integer := 4096;

    constant CFG_ETH_TEST_FIFO_DEPTH        : integer := 16384;

    ------------ DEBUG FLAGS ------------
    constant CFG_DEBUG_GBT                  : boolean := true; -- if set to true, an ILA will be instantiated which allows probing any GBT link
    constant CFG_DEBUG_OH                   : boolean := true; -- if set to true, and ILA will be instantiated on VFATs and OH trigger link
    constant CFG_DEBUG_DAQ                  : boolean := true;
    constant CFG_DEBUG_TRIGGER              : boolean := true;
        
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
    
    type t_oh_link_config_arr is array (0 to 7) of t_oh_link_config;

    constant CFG_OH_LINK_CONFIG_ARR_GE11 : t_oh_link_config_arr := (
        (((0, 0), (1, 1), (2, 2), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((rx => 8,  tx => TXRX_NULL), (rx => 9,  tx => TXRX_NULL))), 
        (((4, 4), (5, 5), (6, 6), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((rx => 12, tx => TXRX_NULL), (rx => 13, tx => TXRX_NULL))),
        
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 

        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
         
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)) 
    );

    constant CFG_OH_LINK_CONFIG_ARR_GE21 : t_oh_link_config_arr := (
        (((0, 0), (1, 1), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((rx => 2, tx => TXRX_NULL), (rx => 3, tx => TXRX_NULL))), 
        (((4, 4), (5, 5), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((rx => 6, tx => TXRX_NULL), (rx => 7, tx => TXRX_NULL))),
        
        (((8,  8),  (9,  9),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((rx => 10, tx => TXRX_NULL), (rx => 11, tx => TXRX_NULL))), 
        (((12, 12), (13, 13), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((rx => 14, tx => TXRX_NULL), (rx => 15, tx => TXRX_NULL))),
        
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
         
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)) 
    );

    constant CFG_OH_LINK_CONFIG_ARR_ME0 : t_oh_link_config_arr := (
        (((0, 0), (TXRX_NULL, 1), (1, 2),  (TXRX_NULL, 3),  (2, 4),   (TXRX_NULL, 5),  (3, 6),   (TXRX_NULL, 7)),  (LINK_NULL, LINK_NULL)),         
        (((8, 8), (TXRX_NULL, 9), (9, 10), (TXRX_NULL, 11), (10, 12), (TXRX_NULL, 13), (11, 14), (TXRX_NULL, 15)), (LINK_NULL, LINK_NULL)), 

        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)) 
    );

    function get_oh_link_config_arr(gem_station: integer; ge11_config, ge21_config, me0_config : t_oh_link_config_arr) return t_oh_link_config_arr;
    constant CFG_OH_LINK_CONFIG_ARR : t_oh_link_config_arr := get_oh_link_config_arr(CFG_GEM_STATION, CFG_OH_LINK_CONFIG_ARR_GE11, CFG_OH_LINK_CONFIG_ARR_GE21, CFG_OH_LINK_CONFIG_ARR_ME0);

    type t_trig_tx_link_config_arr is array (0 to CFG_NUM_TRIG_TX - 1) of integer range 0 to CFG_BOARD_MAX_LINKS;
    
    constant CFG_TRIG_TX_LINK_CONFIG_ARR : t_trig_tx_link_config_arr := (TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL);
    
    constant CFG_USE_SPY_LINK : boolean := false;
    constant CFG_SPY_LINK : integer := 3;
    
    --================================--
    -- Fiber to MGT mapping
    --================================--    

    constant CFG_MGT_NUM_CHANNELS : integer := CFG_BOARD_MAX_LINKS;
                
    -- this array is meant to hold a mapping from fiber index to MGT TX and RX indices
    type t_fiber_to_mgt_link_map is array (0 to CFG_BOARD_MAX_LINKS) of t_link;

    -- defines the MGT TX and RX index for each fiber index
    -- QSFP-0 (quad 233): fibers 0-3
    -- QSFP-1 (quad 232): fibers 4-7
    -- QSFP-2 (quad 229): fibers 8-11
    -- QSFP-3 (quad 228): fibers 12-15
    -- DUMMY: fiber 16 - use this for unconnected channels (e.g. the non-existing GBT#2 in GE2/1)
    -- note that GTH channel #16 is used as a placeholder for fiber links that are not connected to the FPGA
    constant CFG_FIBER_TO_MGT_MAP : t_fiber_to_mgt_link_map := (
        --=== QSFP-3 ===--
        (0, 0),   -- fiber 12
        (1, 1),   -- fiber 13
        (2, 2),   -- fiber 14
        (3, 3),   -- fiber 15
        --=== QSFP-2 ===--
        (4, 4),   -- fiber 8
        (5, 5),   -- fiber 9
        (6, 6),   -- fiber 10
        (7, 7),   -- fiber 11
        --=== QSFP-1 ===--
        (8, 8),   -- fiber 4
        (9, 9),   -- fiber 5
        (10, 10), -- fiber 6
        (11, 11), -- fiber 7
        --=== QSFP-0 ===--
        (12, 12), -- fiber 0
        (13, 13), -- fiber 1
        (14, 14), -- fiber 2
        (15, 15), -- fiber 3
        --=== DUMMY channel - use for unconnected channels ===--
        (CFG_MGT_NUM_CHANNELS, CFG_MGT_NUM_CHANNELS)  -- dummy fiber
    );
    
    --================================--
    -- MGT configuration
    --================================--    
    
    type t_mgt_config_arr is array (0 to CFG_MGT_NUM_CHANNELS - 1) of t_mgt_config;
    
    
    constant CFG_MGT_LINK_CONFIG_GE11 : t_mgt_config_arr := (
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        

        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => TRUE,  ibert_inst => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),

        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        

        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false)        
    );

    constant CFG_MGT_LINK_CONFIG_GE21 : t_mgt_config_arr := (
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => true),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => true),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        

        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => TRUE,  ibert_inst => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),

        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        

        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false)        
    );

    constant CFG_MGT_LINK_CONFIG_ME0 : t_mgt_config_arr := (
        (link_type => MGT_LPGBT, use_refclk_01 => 1, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => true),        
        (link_type => MGT_LPGBT, use_refclk_01 => 1, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => true),        
        (link_type => MGT_LPGBT, use_refclk_01 => 1, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_LPGBT, use_refclk_01 => 1, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        

        (link_type => MGT_LPGBT, use_refclk_01 => 1, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false, is_master => TRUE,  ibert_inst => false),        
        (link_type => MGT_LPGBT, use_refclk_01 => 1, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_LPGBT, use_refclk_01 => 1, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_LPGBT, use_refclk_01 => 1, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),

        (link_type => MGT_LPGBT, use_refclk_01 => 1, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_LPGBT, use_refclk_01 => 1, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_LPGBT, use_refclk_01 => 1, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_LPGBT, use_refclk_01 => 1, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        

        (link_type => MGT_LPGBT, use_refclk_01 => 1, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_LPGBT, use_refclk_01 => 1, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_LPGBT, use_refclk_01 => 1, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false),        
        (link_type => MGT_LPGBT, use_refclk_01 => 1, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 32, tx_multilane_phalign => true, rx_use_buf => false, is_master => false, ibert_inst => false)        
    );

    function get_mgt_config(gem_station: integer; ge11_config, ge21_config, me0_config : t_mgt_config_arr) return t_mgt_config_arr;
    constant CFG_MGT_LINK_CONFIG : t_mgt_config_arr := get_mgt_config(CFG_GEM_STATION, CFG_MGT_LINK_CONFIG_GE11, CFG_MGT_LINK_CONFIG_GE21, CFG_MGT_LINK_CONFIG_ME0);

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
    
end board_config_package;
--============================================================================
--                                                                 Package end 
--============================================================================

