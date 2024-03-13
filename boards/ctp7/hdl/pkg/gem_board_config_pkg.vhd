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
use work.ttc_pkg.C_TTC_CLK_FREQUENCY;

--============================================================================
--                                                         Package declaration
--============================================================================
package board_config_package is

    ------------ Firmware flavor and board type  ------------
    constant CFG_FW_FLAVOR          : std_logic_vector(3 downto 0) := x"0"; -- 0 = GEM; 1 = CSC_FED
    constant CFG_BOARD_TYPE         : std_logic_vector(3 downto 0) := x"1"; -- 0 = GLIB; 1 = CTP7; 2 = CVP13; 3 = APEX; 4 = X2O

    ------------ Board specific constants ------------
    constant CFG_BOARD_MAX_LINKS    : integer := 72;
    constant CFG_BOARD_MAX_OHS      : integer := 16;
    constant CFG_BOARD_MAX_SLRS     : integer := 1;

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

    constant CFG_SPY_10GBE                     : boolean := true; -- true = 10 GbE; false = 1 GbE
    constant CFG_SPY_10GBE_ASYNC_GEARBOX       : boolean := false; -- true = async 64b66b gearbox (use with ultrascale FPGAs), false = sync 64b66b gearbox (use with older FPGAs, including virtex7)
    constant CFG_SPY_PACKETFIFO_DEPTH          : integer := 8192; -- buffer almost 8 maximum size packets (2 headers words, 1023 payload words, 1 trailer word)
    constant CFG_SPY_PACKETFIFO_DATA_CNT_WIDTH : integer := 13;

    ------------ DEBUG FLAGS ------------
    constant CFG_DEBUG_GBT                  : boolean := true; -- if set to true, an ILA will be instantiated which allows probing any GBT link
    constant CFG_DEBUG_OH                   : boolean := true; -- if set to true, and ILA will be instantiated on VFATs and OH trigger link
    constant CFG_DEBUG_DAQ                  : boolean := true;
    constant CFG_DEBUG_TRIGGER              : boolean := true;
    constant CFG_DEBUG_SBIT_ME0             : boolean := true; -- if set to true, and ILA will be instantiated on sbit ME0
    constant CFG_DEBUG_IC_RX                : boolean := false; --set to true to instantiate ILA in IC rx
    constant CFG_DEBUG_TRIGGER_TX           : boolean := true; -- if set to true, an ILA will be instantiated which allows probing any trigger TX link
    constant CFG_DEBUG_10GBE_MAC_PCS        : boolean := false; -- if set to true, an ILA will be instantiated which allows probing the 10 GbE MAC-PCS core
    
    ----------------------------------------------------------------------------------------------

    constant CFG_LPGBT_2P56G_LOOPBACK_TEST  : boolean := false; -- setting this to true will result in a test firmware with 2.56Gbps transceivers only usable for PRBS loopback tests with LpGBT chip, note that none of the GEM logic will be included (also no LpGBT core will be instantiated)
    constant CFG_LPGBT_EMTF_LOOP_TEST       : boolean := false;  -- setting this to true will instantiate an LpGBT RX core on the CFG_LPGBT_EMTF_RX_GTH, and an ILA
    constant CFG_LPGBT_EMTF_LOOP_RX_GTH     : integer := 66;
    constant CFG_LPGBT_EMTF_LOOP_TX_LINK    : integer := 7;
    constant CFG_ILA_GBT0_MGT_EN            : boolean := false; -- setting this to 1 enables the instantiation of ILA on GBT link 0 MGT

    --================================--
    -- Fiber to MGT mapping
    --================================--    

    constant CFG_MGT_NUM_CHANNELS : integer := 68;
    constant MGT_NULL : integer := CFG_MGT_NUM_CHANNELS; 

    -- this record is used in fiber to MGT map (holding tx and rx MGT index)
    type t_fiber_to_mgt_link is record
        tx      : integer range 0 to CFG_MGT_NUM_CHANNELS; -- MGT TX index (#CFG_BOARD_MAX_LINKS means disconnected/non-existing)
        rx      : integer range 0 to CFG_MGT_NUM_CHANNELS; -- MGT RX index (#CFG_BOARD_MAX_LINKS means disconnected/non-existing)
        tx_inv  : boolean; -- indicates whether or not the TX is inverted on the board (this is used by software to invert the respective channels)
        rx_inv  : boolean; -- indicates whether or not the RX is inverted on the board (this is used by software to invert the respective channels)
    end record;

    -- this array is meant to hold a mapping from fiber index to MGT TX and RX indices
    type t_fiber_to_mgt_link_map is array (0 to CFG_BOARD_MAX_LINKS) of t_fiber_to_mgt_link;

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
    constant CFG_FIBER_TO_MGT_MAP : t_fiber_to_mgt_link_map := (
        --=== CXP0 ===--
        (1,        2,        false, false), -- fiber 0
        (3,        0,        false, false), -- fiber 1
        (5,        4,        false, false), -- fiber 2
        (0,        3,        false, false), -- fiber 3
        (2,        5,        false, false), -- fiber 4
        (4,        1,        false, false), -- fiber 5
        (10,       7,        false, false), -- fiber 6
        (8,        9,        false, false), -- fiber 7
        (6,        10,       false, false), -- fiber 8
        (11,       6,        false, false), -- fiber 9
        (9,        8,        false, false), -- fiber 10
        (7,        11,       false, true ), -- fiber 11 -- RX inverted
        --=== CXP1 ===--          
        (13,       15,       false, false), -- fiber 12
        (15,       12,       false, false), -- fiber 13
        (17,       16,       false, false), -- fiber 14
        (12,       14,       false, false), -- fiber 15 
        (14,       18,       false, false), -- fiber 16
        (16,       13,       false, false), -- fiber 17
        (22,       19,       false, false), -- fiber 18
        (20,       23,       false, false), -- fiber 19
        (18,       20,       false, false), -- fiber 20
        (23,       17,       false, false), -- fiber 21
        (21,       21,       false, false), -- fiber 22
        (19,       22,       false, false), -- fiber 23
        --=== CXP2 ===--          
        (25,       27,       false, false), -- fiber 24
        (27,       24,       false, false), -- fiber 25
        (29,       28,       false, false), -- fiber 26
        (24,       26,       false, false), -- fiber 27
        (26,       30,       false, false), -- fiber 28
        (28,       25,       false, false), -- fiber 29
        (34,       31,       false, false), -- fiber 30
        (32,       35,       false, false), -- fiber 31
        (30,       32,       false, false), -- fiber 32
        (35,       29,       false, false), -- fiber 33
        (33,       33,       false, false), -- fiber 34
        (31,       34,       false, false), -- fiber 35
        --=== no TX / MP0 RX ===--
        (MGT_NULL, MGT_NULL, false, false), -- fiber 36 -- RX NULL (not connected)
        (MGT_NULL, 66,       false, false), -- fiber 37
        (MGT_NULL, 64,       false, false), -- fiber 38
        (MGT_NULL, 65,       false, false), -- fiber 39
        (MGT_NULL, 62,       false, false), -- fiber 40
        (MGT_NULL, 63,       false, false), -- fiber 41
        (MGT_NULL, 61,       false, false), -- fiber 42
        (MGT_NULL, 60,       false, false), -- fiber 43
        (MGT_NULL, 59,       false, false), -- fiber 44
        (MGT_NULL, 58,       false, false), -- fiber 45
        (MGT_NULL, 57,       false, false), -- fiber 46
        (MGT_NULL, 56,       false, false), -- fiber 47
        --=== MP TX / MP1 RX ===-                  -
        (59,       54,       false, false), -- fiber 48 
        (56,       55,       false, false), -- fiber 49
        (63,       52,       false, false), -- fiber 50
        (52,       53,       false, false), -- fiber 51
        (62,       50,       false, false), -- fiber 52
        (53,       51,       false, false), -- fiber 53
        (61,       49,       false, false), -- fiber 54
        (54,       48,       false, false), -- fiber 55
        (60,       47,       false, false), -- fiber 56
        (55,       46,       false, false), -- fiber 57
        (58,       45,       false, false), -- fiber 58
        (57,       44,       false, false), -- fiber 59
        --=== no TX / MP2 RX ===--
        (MGT_NULL, MGT_NULL, false, false), -- fiber 60 -- RX NULL (not connected)
        (MGT_NULL, MGT_NULL, false, false), -- fiber 61 -- RX NULL (not connected)
        (MGT_NULL, 43,       false, false), -- fiber 62
        (MGT_NULL, MGT_NULL, false, false), -- fiber 63 -- RX NULL (not connected)
        (MGT_NULL, 42,       false, false), -- fiber 64 
        (MGT_NULL, MGT_NULL, false, false), -- fiber 65 -- RX NULL (not connected)
        (MGT_NULL, 40,       false, false), -- fiber 66
        (67,       36,       false, true ), -- fiber 67 -- RX inverted
        (MGT_NULL, 41,       false, false), -- fiber 68 
        (MGT_NULL, 37,       false, true ), -- fiber 69 -- RX inverted
        (MGT_NULL, 38,       false, false), -- fiber 70
        (MGT_NULL, 39,       false, false), -- fiber 71        
        --=== DUMMY channel - use for unconnected channels ===--
        (MGT_NULL, MGT_NULL, false, false) -- fiber 72        
    );

    --================================--
    -- MGT configuration
    --================================--    

    constant CFG_ASYNC_REFCLK_200_FREQ      : integer := 200_000_000;
    constant CFG_ASYNC_REFCLK_156p25_FREQ   : integer := 156_250_000;
    constant CFG_LHC_REFCLK_FREQ    : integer := C_TTC_CLK_FREQUENCY * 4;
    
    -- we're not using this on CTP7 yet, so this is just a dummy to suppress errors
    type t_mgt_config_arr is array (0 to 1) of t_mgt_config;
    constant CFG_MGT_LINK_CONFIG : t_mgt_config_arr := (
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_LPGBT, qpll_idx => 0, refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => true),   
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_LPGBT, qpll_idx => 0, refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => true)   
    );    
    
end board_config_package;

--============================================================================
--                                                                 Package end 
--============================================================================

