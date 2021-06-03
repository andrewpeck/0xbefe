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

    ------------ DAQ configuration ------------
    constant CFG_DAQ_MAX_DMBS               : integer := 15; -- the number of DMBs that are supported by the DAQ module (the CFG_NUM_DMBS can be less than or equal to this number)
    
    constant CFG_DAQ_EVTFIFO_DEPTH          : integer := 4096;
    constant CFG_DAQ_EVTFIFO_PROG_FULL_SET  : integer := 3072;
    constant CFG_DAQ_EVTFIFO_PROG_FULL_RESET: integer := 2047;
    constant CFG_DAQ_EVTFIFO_DATA_CNT_WIDTH : integer := 12;
    
    constant CFG_DAQ_INFIFO_DEPTH           : integer := 16384;
    constant CFG_DAQ_INFIFO_PROG_FULL_SET   : integer := 12288;
    constant CFG_DAQ_INFIFO_PROG_FULL_RESET : integer := 8192;
    constant CFG_DAQ_INFIFO_DATA_CNT_WIDTH  : integer := 14;

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

    --========================--
    --== Link configuration ==--
    --========================--

    type t_dmb_rx_fiber_arr is array (0 to 2) of integer range 0 to CFG_BOARD_MAX_LINKS;
    type t_dmb_config is record
        num_fibers  : integer range 0 to 3; -- number of downlink fibers to be used for this DMB (should be 1 for old DMBs/ODMBs, and greater than 1 for multilink ODMBs)
        rx_fibers   : t_dmb_rx_fiber_arr;       -- RX fiber number(s) to be used for this DMB (only items [0 to num_fibers -1] will be used)  
    end record;

    type t_dmb_config_arr is array (integer range <>) of t_dmb_config;

    constant CFG_NUM_DMBS           : integer := PRJ_CFG_NUM_DMBS;    -- total number of DMBs to instanciate

    constant CFG_DMB_CONFIG_ARR : t_dmb_config_arr(0 to CFG_NUM_DMBS - 1) := (
        (num_fibers => 1, rx_fibers => (0, 0, 0)),
        (num_fibers => 1, rx_fibers => (1, 0, 0))
    );

    constant CFG_USE_SPY_LINK : boolean := true;
    constant CFG_SPY_LINK : integer := 2;
    
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
        --=== Quad 128 ===--
        (2, 1),   -- fiber 0
        (1, 3),   -- fiber 1  ! RX inverted
        (0, 0),   -- fiber 2  ! RX inverted
        (3, 2),   -- fiber 3  ! RX inverted

        --=== dummy ===--
        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS),
        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS),
        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS),
        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS),
        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS),
        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS),
        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS),
        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS),
        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS),
        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS),
        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS),
        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS),
        
--        --=== Quad 129 ===--
--        (0, 0),   -- fiber 0  ! RX inverted
--        (2, 1),   -- fiber 1  ! RX inverted
--        (1, 2),   -- fiber 2
--        (3, 3),   -- fiber 3
--        --=== Quad 131 ===--
--        (10, 8),  -- fiber 4  ! RX inverted ! TX inverted
--        (9, 9),   -- fiber 5  ! RX inverted ! TX inverted
--        (8, 10),  -- fiber 6  ! RX inverted ! TX inverted
--        (11, 11), -- fiber 7  ! RX inverted ! TX inverted
--        --=== Quad 130 ===--
--        (5, 4),   -- fiber 8
--        (7, 5),   -- fiber 9  ! RX inverted
--        (4, 6),   -- fiber 10 ! RX inverted
--        (6, 7),   -- fiber 11 ! RX inverted
--        --=== Quad 132 ===--
--        (12, 12), -- fiber 12 ! RX inverted
--        (13, 13), -- fiber 13               ! TX inverted
--        (15, 14), -- fiber 14               ! TX inverted
--        (14, 15), -- fiber 15
        --=== DUMMY channel - use for unconnected channels ===--
        (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)  -- dummy fiber
    );
    
    --================================--
    -- MGT configuration
    --================================--    
    
    constant CFG_MGT_NUM_CHANNELS : integer := 4;
    
    type t_mgt_config_arr is array (0 to CFG_MGT_NUM_CHANNELS - 1) of t_mgt_config;
    
    constant CFG_MGT_LINK_CONFIG : t_mgt_config_arr := (
        (link_type => MGT_DMB,  use_refclk_01 => 1, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 16, tx_multilane_phalign => false, rx_use_buf => false, is_master => true,  ibert_inst => true),        
        (link_type => MGT_DMB,  use_refclk_01 => 1, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 16, tx_multilane_phalign => false, rx_use_buf => false, is_master => false, ibert_inst => true),        
        (link_type => MGT_GBE,  use_refclk_01 => 1, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 16, tx_multilane_phalign => false, rx_use_buf => false, is_master => true,  ibert_inst => true),        
        (link_type => MGT_GBTX, use_refclk_01 => 0, use_qpll => false, use_qpll_01 => 0, tx_bus_width => 40, tx_multilane_phalign => true,  rx_use_buf => false, is_master => true,  ibert_inst => true)        
    );

end board_config_package;

--============================================================================
--                                                                 Package end 
--============================================================================

