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
    constant CFG_FW_FLAVOR          : std_logic_vector(3 downto 0) := x"0"; -- 0 = GEM_AMC; 1 = CSC_FED
    constant CFG_BOARD_TYPE         : std_logic_vector(3 downto 0) := x"4"; -- 0 = GLIB; 1 = CTP7; 2 = CVP13; 3 = APEX; 4 = X2O
    
    ------------ Board specific constants ------------
    constant CFG_BOARD_MAX_LINKS    : integer := 116;
    constant CFG_BOARD_MAX_OHS      : integer := 12;
    constant CFG_BOARD_MAX_SLRS     : integer := 4;

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
    constant CFG_DAQ_OUTPUT_PROG_FULL_RESET : integer := 1365;
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
    constant CFG_DEBUG_SBIT_ME0             : boolean := true; -- if set to true, and ILA will be instantiated on sbit ME0    
    constant CFG_DEBUG_IC_RX                : boolean := false; --set to true to instantiate ILA in IC rx
    
    -- oh link mapping is in the project pkg file
    
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
    -- DUMMY: last fiber - use this for unconnected channels (e.g. the non-existing GBT#2 in GE2/1)
    -- note that MGT_NULL is used as a placeholder for fiber links that are not connected to the FPGA
    constant CFG_FIBER_TO_MGT_MAP : t_fiber_to_mgt_link_map := (
        --========= ARF6 #0 (J19) =========--
        (002, 002, false, true ), -- fiber 0 (SLR 0)
        (014, 014, false, true ), -- fiber 1 (SLR 0)
        (004, 000, false, true ), -- fiber 2 (SLR 0)
        (012, 012, true , true ), -- fiber 3 (SLR 0)
        (000, 004, false, true ), -- fiber 4 (SLR 0)
        (010, 010, false, true ), -- fiber 5 (SLR 0)
        (006, 006, false, true ), -- fiber 6 (SLR 0)
        (008, 008, false, true ), -- fiber 7 (SLR 0)
        --========= ARF6 #1 (J20) =========--
        (015, 009, true , false), -- fiber 8 (SLR 0)
        (003, 005, true , false), -- fiber 9 (SLR 0)
        (013, 015, true , false), -- fiber 10 (SLR 0)
        (005, 003, true , false), -- fiber 11 (SLR 0)
        (011, 011, true , false), -- fiber 12 (SLR 0)
        (001, 001, true , false), -- fiber 13 (SLR 0)
        (007, 013, false, false), -- fiber 14 (SLR 0)
        (009, 007, true , false), -- fiber 15 (SLR 0)
        --========= ARF6 #2 (J18) =========--
        (070, 070, true , false), -- fiber 16 (SLR 0)
        (058, 056, true , false), -- fiber 17 (SLR 0)
        (068, 068, false, false), -- fiber 18 (SLR 0)
        (060, 058, true , false), -- fiber 19 (SLR 0)
        (066, 066, true , false), -- fiber 20 (SLR 0)
        (056, 060, true , false), -- fiber 21 (SLR 0)
        (064, 064, true , false), -- fiber 22 (SLR 0)
        (062, 062, true , false), -- fiber 23 (SLR 0)
        --========= ARF6 #3 (J17) =========--
        (059, 061, false, true ), -- fiber 24 (SLR 0)
        (071, 065, false, true ), -- fiber 25 (SLR 0)
        (061, 059, false, true ), -- fiber 26 (SLR 0)
        (069, 071, false, true ), -- fiber 27 (SLR 0)
        (057, 057, false, true ), -- fiber 28 (SLR 0)
        (067, 067, false, true ), -- fiber 29 (SLR 0)
        (065, 063, false, true ), -- fiber 30 (SLR 0)
        (063, 069, true , true ), -- fiber 31 (SLR 0)
        --========= ARF6 #4 (J12) =========--
        (016, 016, false, true ), -- fiber 32 (SLR 1)
        (018, 018, false, true ), -- fiber 33 (SLR 1)
        (020, 020, false, true ), -- fiber 34 (SLR 1)
        (022, 022, false, true ), -- fiber 35 (SLR 1)
        --========= ARF6 #5 (J11) =========--
        (017, 017, false, false), -- fiber 36 (SLR 1)
        (019, 019, false, false), -- fiber 37 (SLR 1)
        (021, 021, false, false), -- fiber 38 (SLR 1)
        (023, 023, false, false), -- fiber 39 (SLR 1)
        --========= ARF6 #6 (J7) =========--
        (086, 086, false, false), -- fiber 40 (SLR 1)
        (072, 072, false, false), -- fiber 41 (SLR 1)
        (084, 084, false, false), -- fiber 42 (SLR 1)
        (074, 074, false, false), -- fiber 43 (SLR 1)
        (082, 082, false, false), -- fiber 44 (SLR 1)
        (076, 076, false, false), -- fiber 45 (SLR 1)
        (080, 080, false, false), -- fiber 46 (SLR 1)
        (078, 078, false, false), -- fiber 47 (SLR 1)
        --========= ARF6 #7 (J10) =========--
        (073, 073, false, true ), -- fiber 48 (SLR 1)
        (087, 087, false, true ), -- fiber 49 (SLR 1)
        (075, 075, false, true ), -- fiber 50 (SLR 1)
        (085, 085, false, true ), -- fiber 51 (SLR 1)
        (077, 077, false, true ), -- fiber 52 (SLR 1)
        (083, 083, false, true ), -- fiber 53 (SLR 1)
        (079, 079, false, true ), -- fiber 54 (SLR 1)
        (081, 081, false, true ), -- fiber 55 (SLR 1)
        --========= ARF6 #8 (J15) =========--
        (024, 024, true , false), -- fiber 56 (SLR 2)
        (038, 038, true , false), -- fiber 57 (SLR 2)
        (026, 026, true , false), -- fiber 58 (SLR 2)
        (036, 036, true , false), -- fiber 59 (SLR 2)
        (028, 028, true , false), -- fiber 60 (SLR 2)
        (034, 034, true , false), -- fiber 61 (SLR 2)
        (030, 030, true , false), -- fiber 62 (SLR 2)
        (032, 032, true , false), -- fiber 63 (SLR 2)
        --========= ARF6 #9 (J16) =========--
        (039, 039, true , true ), -- fiber 64 (SLR 2)
        (025, 025, true , true ), -- fiber 65 (SLR 2)
        (037, 037, true , true ), -- fiber 66 (SLR 2)
        (027, 027, true , true ), -- fiber 67 (SLR 2)
        (035, 035, true , true ), -- fiber 68 (SLR 2)
        (029, 029, true , true ), -- fiber 69 (SLR 2)
        (033, 033, true , true ), -- fiber 70 (SLR 2)
        (031, 031, true , true ), -- fiber 71 (SLR 2)
        --========= ARF6 #10 (J14) =========--
        (098, 098, false, true ), -- fiber 72 (SLR 2)
        (088, 088, false, true ), -- fiber 73 (SLR 2)
        (096, 096, false, true ), -- fiber 74 (SLR 2)
        (090, 090, false, true ), -- fiber 75 (SLR 2)
        (092, 092, false, true ), -- fiber 76 (SLR 2)
        (094, 094, false, true ), -- fiber 77 (SLR 2)
        --========= ARF6 #11 (J13) =========--
        (089, 089, false, false), -- fiber 78 (SLR 2)
        (099, 099, false, false), -- fiber 79 (SLR 2)
        (091, 091, false, false), -- fiber 80 (SLR 2)
        (097, 097, false, false), -- fiber 81 (SLR 2)
        (093, 093, false, false), -- fiber 82 (SLR 2)
        (095, 095, false, false), -- fiber 83 (SLR 2)
        --========= ARF6 #12 (J5) =========--
        (040, 040, true , false), -- fiber 84 (SLR 3)
        (050, 050, true , false), -- fiber 85 (SLR 3)
        (054, 042, true , false), -- fiber 86 (SLR 3)
        (052, 052, true , false), -- fiber 87 (SLR 3)
        (042, 044, true , false), -- fiber 88 (SLR 3)
        (048, 054, true , false), -- fiber 89 (SLR 3)
        (044, 046, true , false), -- fiber 90 (SLR 3)
        (046, 048, true , false), -- fiber 91 (SLR 3)
        --========= ARF6 #13 (J6) =========--
        (051, 049, false, true ), -- fiber 92 (SLR 3)
        (041, 041, false, true ), -- fiber 93 (SLR 3)
        (053, 051, false, true ), -- fiber 94 (SLR 3)
        (043, 043, false, true ), -- fiber 95 (SLR 3)
        (055, 053, false, true ), -- fiber 96 (SLR 3)
        (045, 045, false, true ), -- fiber 97 (SLR 3)
        (049, 055, false, true ), -- fiber 98 (SLR 3)
        (047, 047, false, true ), -- fiber 99 (SLR 3)
        --========= ARF6 #14 (J4) =========--
        (110, 114, false, true ), -- fiber 100 (SLR 3)
        (100, 100, false, true ), -- fiber 101 (SLR 3)
        (112, 112, false, true ), -- fiber 102 (SLR 3)
        (114, 102, false, true ), -- fiber 103 (SLR 3)
        (108, 110, false, true ), -- fiber 104 (SLR 3)
        (102, 104, false, true ), -- fiber 105 (SLR 3)
        (106, 108, false, true ), -- fiber 106 (SLR 3)
        (104, 106, false, true ), -- fiber 107 (SLR 3)
        --========= ARF6 #15 (J3) =========--
        (101, 101, true , false), -- fiber 108 (SLR 3)
        (111, 109, true , false), -- fiber 109 (SLR 3)
        (103, 103, true , false), -- fiber 110 (SLR 3)
        (113, 111, true , false), -- fiber 111 (SLR 3)
        (105, 105, true , false), -- fiber 112 (SLR 3)
        (115, 113, true , false), -- fiber 113 (SLR 3)
        (107, 107, true , false), -- fiber 114 (SLR 3)
        (109, 115, true , false), -- fiber 115 (SLR 3)
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

    constant CFG_MGT_LPGBT : t_mgt_type_config := (
        link_type               => MGT_LPGBT,
        cpll_refclk_01          => 1, 
        qpll0_refclk_01         => 1,
        qpll1_refclk_01         => 1,
        tx_use_qpll             => true, 
        rx_use_qpll             => true,
        tx_qpll_01              => 0,
        rx_qpll_01              => 0,
        tx_refclk_freq          => CFG_LHC_REFCLK_FREQ,
        rx_refclk_freq          => CFG_LHC_REFCLK_FREQ,
        tx_bus_width            => 32,
        tx_multilane_phalign    => true, 
        rx_use_buf              => false
    );
        
    type t_mgt_config_arr is array (0 to CFG_MGT_NUM_CHANNELS - 1) of t_mgt_config;
    
end board_config_package;

--============================================================================
--                                                                 Package end 
--============================================================================

