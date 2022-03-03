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
    constant CFG_FW_FLAVOR          : std_logic_vector(3 downto 0) := x"1"; -- 0 = GEM_AMC; 1 = CSC_FED
    constant CFG_BOARD_TYPE         : std_logic_vector(3 downto 0) := x"4"; -- 0 = GLIB; 1 = CTP7; 2 = CVP13; 3 = APEX; 4 = X2O

    ------------ Board specific constants ------------
    constant CFG_BOARD_MAX_LINKS    : integer := 116;

    ------------ DAQ configuration ------------
    constant CFG_DAQ_MAX_DMBS               : integer := 15; -- the number of DMBs that are supported by the DAQ module (the CFG_NUM_DMBS can be less than or equal to this number)
    constant CFG_MAX_GBTS                   : integer := 15; -- max number of GBT links that can be supported by this board
    
    constant CFG_DAQ_EVTFIFO_DEPTH          : integer := 4096;
    constant CFG_DAQ_EVTFIFO_PROG_FULL_SET  : integer := 3072;
    constant CFG_DAQ_EVTFIFO_PROG_FULL_RESET: integer := 2047;
    constant CFG_DAQ_EVTFIFO_DATA_CNT_WIDTH : integer := 12;
    
    constant CFG_DAQ_INFIFO_DEPTH           : integer := 16384;
    constant CFG_DAQ_INFIFO_PROG_FULL_SET   : integer := 12288;
    constant CFG_DAQ_INFIFO_PROG_FULL_RESET : integer := 8192;
    constant CFG_DAQ_INFIFO_DATA_CNT_WIDTH  : integer := 14;

    constant CFG_DAQ_OUTPUT_RAM_TYPE        : string  := "ultra"; -- "block"
    constant CFG_DAQ_OUTPUT_READ_LATENCY    : integer := 8;       -- need higher number for ultraram, use 1 for BRAM
    constant CFG_DAQ_OUTPUT_DEPTH           : integer := 524288; --1048576;  --8192;
    constant CFG_DAQ_OUTPUT_PROG_FULL_SET   : integer := 393216; --786432;   --4045;
    constant CFG_DAQ_OUTPUT_PROG_FULL_RESET : integer := 262144; --524285;   --1365;
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
    
    --================================--
    -- Fiber to MGT mapping
    --================================--    

    constant CFG_NUM_REFCLK0      : integer := 30;
    constant CFG_NUM_REFCLK1      : integer := 8; 
    constant CFG_MGT_NUM_CHANNELS : integer := CFG_BOARD_MAX_LINKS;
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

    -- defines the MGT TX and RX index for each fiber index
    -- each line here corresponds to a logical link number (starting at 0), where the first element refers to the TX MGT number, and the second element refers to the RX MGT number (inversions are always noted in the comments)    
    -- DUMMY: fiber 16 - use this for unconnected channels (e.g. the non-existing GBT#2 in GE2/1)
    -- note that GTH channel #16 is used as a placeholder for fiber links that are not connected to the FPGA
    constant CFG_FIBER_TO_MGT_MAP : t_fiber_to_mgt_link_map := (
        --========= QSFP #0 =========--
        (059, 061, false, true ), -- fiber 0 (SLR 0)
        (058, 056, true , false), -- fiber 1 (SLR 0)
        (061, 059, false, true ), -- fiber 2 (SLR 0)
        (060, 058, true , false), -- fiber 3 (SLR 0)
        --========= QSFP #1 =========--
        (070, 070, true , false), -- fiber 4 (SLR 0)
        (071, 065, false, true ), -- fiber 5 (SLR 0)
        (068, 068, false, false), -- fiber 6 (SLR 0)
        (069, 071, false, true ), -- fiber 7 (SLR 0)
        --========= QSFP #2 =========--
        (073, 073, false, true ), -- fiber 8 (SLR 1)
        (072, 072, false, false), -- fiber 9 (SLR 1)
        (075, 075, false, true ), -- fiber 10 (SLR 1)
        (074, 074, false, false), -- fiber 11 (SLR 1)
        --========= QSFP #3 =========--
        (086, 086, false, false), -- fiber 12 (SLR 1)
        (087, 087, false, true ), -- fiber 13 (SLR 1)
        (084, 084, false, false), -- fiber 14 (SLR 1)
        (085, 085, false, true ), -- fiber 15 (SLR 1)
        --========= QSFP #4 =========--
        (089, 089, false, false), -- fiber 16 (SLR 2)
        (088, 088, false, true ), -- fiber 17 (SLR 2)
        (091, 091, false, false), -- fiber 18 (SLR 2)
        (090, 090, false, true ), -- fiber 19 (SLR 2)
        --========= QSFP #5 =========--
        (101, 101, true , false), -- fiber 20 (SLR 3)
        (100, 100, false, true ), -- fiber 21 (SLR 3)
        (103, 103, true , false), -- fiber 22 (SLR 3)
        (114, 102, false, true ), -- fiber 23 (SLR 3)
        --========= QSFP #6 =========--
        (110, 114, false, true ), -- fiber 24 (SLR 3)
        (111, 109, true , false), -- fiber 25 (SLR 3)
        (112, 112, false, true ), -- fiber 26 (SLR 3)
        (113, 111, true , false), -- fiber 27 (SLR 3)
        --========= QSFP #7 =========--
        (051, 049, false, true ), -- fiber 28 (SLR 3)
        (050, 050, true , false), -- fiber 29 (SLR 3)
        (053, 051, false, true ), -- fiber 30 (SLR 3)
        (052, 052, true , false), -- fiber 31 (SLR 3)
        --========= QSFP #8 =========--
        (040, 040, true , false), -- fiber 32 (SLR 3)
        (041, 041, false, true ), -- fiber 33 (SLR 3)
        (054, 042, true , false), -- fiber 34 (SLR 3)
        (043, 043, false, true ), -- fiber 35 (SLR 3)
        --========= QSFP #9 =========--
        (039, 039, true , true ), -- fiber 36 (SLR 2)
        (038, 038, true , false), -- fiber 37 (SLR 2)
        (037, 037, true , true ), -- fiber 38 (SLR 2)
        (036, 036, true , false), -- fiber 39 (SLR 2)
        --========= QSFP #10 =========--
        (024, 024, true , false), -- fiber 40 (SLR 2)
        (025, 025, true , true ), -- fiber 41 (SLR 2)
        (026, 026, true , false), -- fiber 42 (SLR 2)
        (027, 027, true , true ), -- fiber 43 (SLR 2)
        --========= QSFP #11 =========--
        (016, 016, false, true ), -- fiber 44 (SLR 1)
        (017, 017, false, false), -- fiber 45 (SLR 1)
        (018, 018, false, true ), -- fiber 46 (SLR 1)
        (019, 019, false, false), -- fiber 47 (SLR 1)
        --========= QSFP #12 =========--
        (015, 009, true , false), -- fiber 48 (SLR 0)
        (014, 014, false, true ), -- fiber 49 (SLR 0)
        (013, 015, true , false), -- fiber 50 (SLR 0)
        (012, 012, true , true ), -- fiber 51 (SLR 0)
        --========= QSFP #13 =========--
        (002, 002, false, true ), -- fiber 52 (SLR 0)
        (003, 005, true , false), -- fiber 53 (SLR 0)
        (004, 000, false, true ), -- fiber 54 (SLR 0)
        (005, 003, true , false), -- fiber 55 (SLR 0)
        --=== DUMMY fiber - use for unconnected channels ===--
        (MGT_NULL, MGT_NULL, false, false)
    );
    
    --================================--
    -- MGT configuration
    --================================--    
    
    constant CFG_ASYNC_REFCLK_200_FREQ      : integer := 200_000_000;
    constant CFG_ASYNC_REFCLK_156p25_FREQ   : integer := 156_250_000;
    constant CFG_LHC_REFCLK_FREQ            : integer := C_TTC_CLK_FREQUENCY * 4;
    
    constant CFG_MGT_GBE : t_mgt_type_config := (
        link_type               => MGT_GBE,
        cpll_refclk_01          => 0, 
        qpll0_refclk_01         => 0,
        qpll1_refclk_01         => 0,
        tx_use_qpll             => true, 
        rx_use_qpll             => true,
        tx_qpll_01              => 1,
        rx_qpll_01              => 1,
        tx_refclk_freq          => CFG_ASYNC_REFCLK_156p25_FREQ,
        rx_refclk_freq          => CFG_ASYNC_REFCLK_156p25_FREQ,
        tx_bus_width            => 16,
        tx_multilane_phalign    => false, 
        rx_use_buf              => true
    );

    constant CFG_MGT_TTC : t_mgt_type_config := (
        link_type               => MGT_TTC,
        cpll_refclk_01          => 1, 
        qpll0_refclk_01         => 1,
        qpll1_refclk_01         => 1,
        tx_use_qpll             => true, 
        rx_use_qpll             => true,
        tx_qpll_01              => 0,
        rx_qpll_01              => 0,
        tx_refclk_freq          => CFG_LHC_REFCLK_FREQ,
        rx_refclk_freq          => CFG_LHC_REFCLK_FREQ,
        tx_bus_width            => 16,
        tx_multilane_phalign    => true, 
        rx_use_buf              => false
    );
    
    constant CFG_MGT_DMB : t_mgt_type_config := (
        link_type               => MGT_DMB,
        cpll_refclk_01          => 0, 
        qpll0_refclk_01         => 0,
        qpll1_refclk_01         => 0,
        tx_use_qpll             => true, 
        rx_use_qpll             => true,
        tx_qpll_01              => 0,
        rx_qpll_01              => 0,
        tx_refclk_freq          => CFG_ASYNC_REFCLK_156p25_FREQ,
        rx_refclk_freq          => CFG_ASYNC_REFCLK_156p25_FREQ,
        tx_bus_width            => 16,
        tx_multilane_phalign    => false, 
        rx_use_buf              => true
    );

    constant CFG_MGT_ODMB57 : t_mgt_type_config := (
        link_type               => MGT_ODMB57,
        cpll_refclk_01          => 1, 
        qpll0_refclk_01         => 0,
        qpll1_refclk_01         => 1,
        tx_use_qpll             => true, 
        rx_use_qpll             => true,
        tx_qpll_01              => 1,
        rx_qpll_01              => 0,
        tx_refclk_freq          => CFG_LHC_REFCLK_FREQ,
        rx_refclk_freq          => CFG_ASYNC_REFCLK_156p25_FREQ,
        tx_bus_width            => 40,
        tx_multilane_phalign    => true, 
        rx_use_buf              => true
    );

    constant CFG_MGT_GBTX : t_mgt_type_config := (
        link_type               => MGT_GBTX,
        cpll_refclk_01          => 1, 
        qpll0_refclk_01         => 1,
        qpll1_refclk_01         => 1,
        tx_use_qpll             => true, 
        rx_use_qpll             => true,
        tx_qpll_01              => 1,
        rx_qpll_01              => 1,
        tx_refclk_freq          => CFG_LHC_REFCLK_FREQ,
        rx_refclk_freq          => CFG_LHC_REFCLK_FREQ,
        tx_bus_width            => 40,
        tx_multilane_phalign    => true, 
        rx_use_buf              => false
    );
            
    type t_mgt_config_arr is array (0 to CFG_MGT_NUM_CHANNELS - 1) of t_mgt_config;
    
end board_config_package;

--============================================================================
--                                                                 Package end 
--============================================================================

