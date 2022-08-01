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

    constant CFG_SPY_10GBE                  : boolean := false; -- true = 10 GbE; false = 1 GbE

    ------------ DEBUG FLAGS ------------
    constant CFG_DEBUG_GBT                  : boolean := true; -- if set to true, an ILA will be instantiated which allows probing any GBT link
    constant CFG_DEBUG_OH                   : boolean := true; -- if set to true, and ILA will be instantiated on VFATs and OH trigger link
    constant CFG_DEBUG_DAQ                  : boolean := true;
    constant CFG_DEBUG_TRIGGER              : boolean := true;
    constant CFG_DEBUG_SBIT_ME0             : boolean := true; -- if set to true, and ILA will be instantiated on sbit ME0
    constant CFG_DEBUG_IC_RX                : boolean := false; --set to true to instantiate ILA in IC rx
    constant CFG_DEBUG_TRIGGER_TX           : boolean := false; -- if set to true, an ILA will be instantiated which allows probing any trigger TX link
    constant CFG_DEBUG_10GBE_MAC_PCS        : boolean := false; -- if set to true, an ILA will be instantiated which allows probing the 10 GbE MAC-PCS core
    
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
        --========= QSFP cage #0 =========--
        (003, 007, true , true ), -- fiber 0 (SLR 0)
        (005, 001, true , true ), -- fiber 1 (SLR 0)
        (001, 003, true , true ), -- fiber 2 (SLR 0)
        (009, 005, true , true ), -- fiber 3 (SLR 0)
        --========= QSFP cage #1 =========--
        (007, 009, true , true ), -- fiber 4 (SLR 0)
        (011, 015, true , true ), -- fiber 5 (SLR 0)
        (013, 011, true , true ), -- fiber 6 (SLR 0)
        (015, 013, true , true ), -- fiber 7 (SLR 0)
        --========= QSFP cage #2 =========--
        (014, 008, true , true ), -- fiber 8 (SLR 0)
        (012, 010, true , true ), -- fiber 9 (SLR 0)
        (010, 012, true , true ), -- fiber 10 (SLR 0)
        (008, 014, true , true ), -- fiber 11 (SLR 0)
        --========= QSFP cage #3 =========--
        (006, 002, true , true ), -- fiber 12 (SLR 0)
        (000, 000, true , true ), -- fiber 13 (SLR 0)
        (004, 004, true , true ), -- fiber 14 (SLR 0)
        (002, 006, true , true ), -- fiber 15 (SLR 0)
        --========= QSFP cage #4 =========--
        (017, 023, true , true ), -- fiber 16 (SLR 1)
        (019, 021, true , true ), -- fiber 17 (SLR 1)
        (021, 019, true , true ), -- fiber 18 (SLR 1)
        (023, 017, true , true ), -- fiber 19 (SLR 1)
        --========= QSFP cage #6 =========--
        (025, 031, true , true ), -- fiber 20 (SLR 2)
        (027, 029, true , true ), -- fiber 21 (SLR 2)
        (029, 027, true , true ), -- fiber 22 (SLR 2)
        (031, 025, true , true ), -- fiber 23 (SLR 2)
        --========= QSFP cage #7 =========--
        (033, 039, true , true ), -- fiber 24 (SLR 2)
        (035, 037, true , true ), -- fiber 25 (SLR 2)
        (037, 035, true , true ), -- fiber 26 (SLR 2)
        (039, 033, true , true ), -- fiber 27 (SLR 2)
        --========= QSFP cage #8 =========--
        (038, 032, true , true ), -- fiber 28 (SLR 2)
        (036, 034, true , true ), -- fiber 29 (SLR 2)
        (034, 036, true , true ), -- fiber 30 (SLR 2)
        (032, 038, true , true ), -- fiber 31 (SLR 2)
        --========= QSFP cage #9 =========--
        (030, 024, true , true ), -- fiber 32 (SLR 2)
        (028, 026, true , true ), -- fiber 33 (SLR 2)
        (026, 028, true , true ), -- fiber 34 (SLR 2)
        (024, 030, true , true ), -- fiber 35 (SLR 2)
        --========= QSFP cage #10 =========--
        (041, 047, true , true ), -- fiber 36 (SLR 3)
        (043, 045, true , true ), -- fiber 37 (SLR 3)
        (045, 043, true , true ), -- fiber 38 (SLR 3)
        (047, 041, true , true ), -- fiber 39 (SLR 3)
        --========= QSFP cage #11 =========--
        (049, 049, true , true ), -- fiber 40 (SLR 3)
        (055, 051, true , true ), -- fiber 41 (SLR 3)
        (053, 053, true , true ), -- fiber 42 (SLR 3)
        (051, 055, true , true ), -- fiber 43 (SLR 3)
        --========= QSFP cage #12 =========--
        (050, 048, true , true ), -- fiber 44 (SLR 3)
        (052, 054, true , true ), -- fiber 45 (SLR 3)
        (048, 052, true , true ), -- fiber 46 (SLR 3)
        (046, 050, true , true ), -- fiber 47 (SLR 3)
        --========= QSFP cage #13 =========--
        (044, 040, true , true ), -- fiber 48 (SLR 3)
        (042, 042, true , true ), -- fiber 49 (SLR 3)
        (054, 044, true , true ), -- fiber 50 (SLR 3)
        (040, 046, true , true ), -- fiber 51 (SLR 3)
        --========= QSFP cage #14 =========--
        (111, 115, true , true ), -- fiber 52 (SLR 3)
        (113, 113, true , true ), -- fiber 53 (SLR 3)
        (115, 111, true , true ), -- fiber 54 (SLR 3)
        (109, 109, true , true ), -- fiber 55 (SLR 3)
        --========= QSFP cage #15 =========--
        (107, 101, true , true ), -- fiber 56 (SLR 3)
        (105, 103, true , true ), -- fiber 57 (SLR 3)
        (103, 105, true , true ), -- fiber 58 (SLR 3)
        (101, 107, true , true ), -- fiber 59 (SLR 3)
        --========= QSFP cage #16 =========--
        (100, 106, true , true ), -- fiber 60 (SLR 3)
        (114, 104, true , true ), -- fiber 61 (SLR 3)
        (102, 102, true , true ), -- fiber 62 (SLR 3)
        (104, 100, true , true ), -- fiber 63 (SLR 3)
        --========= QSFP cage #17 =========--
        (106, 114, true , true ), -- fiber 64 (SLR 3)
        (108, 112, true , true ), -- fiber 65 (SLR 3)
        (112, 110, true , true ), -- fiber 66 (SLR 3)
        (110, 108, true , true ), -- fiber 67 (SLR 3)
        --========= QSFP cage #22 =========--
        (087, 081, true , true ), -- fiber 68 (SLR 1)
        (085, 083, true , true ), -- fiber 69 (SLR 1)
        (083, 085, true , true ), -- fiber 70 (SLR 1)
        (081, 087, true , true ), -- fiber 71 (SLR 1)
        --========= QSFP cage #23 =========--
        (079, 073, true , true ), -- fiber 72 (SLR 1)
        (077, 075, true , true ), -- fiber 73 (SLR 1)
        (075, 077, true , true ), -- fiber 74 (SLR 1)
        (073, 079, true , true ), -- fiber 75 (SLR 1)
        --========= QSFP cage #24 =========--
        (072, 078, true , true ), -- fiber 76 (SLR 1)
        (074, 076, true , true ), -- fiber 77 (SLR 1)
        (076, 074, true , true ), -- fiber 78 (SLR 1)
        (078, 072, true , true ), -- fiber 79 (SLR 1)
        --========= QSFP cage #25 =========--
        (080, 086, true , true ), -- fiber 80 (SLR 1)
        (082, 084, true , true ), -- fiber 81 (SLR 1)
        (084, 082, true , true ), -- fiber 82 (SLR 1)
        (086, 080, true , true ), -- fiber 83 (SLR 1)
        --========= QSFP cage #26 =========--
        (071, 069, true , true ), -- fiber 84 (SLR 0)
        (069, 067, true , true ), -- fiber 85 (SLR 0)
        (067, 071, true , true ), -- fiber 86 (SLR 0)
        (063, 065, true , true ), -- fiber 87 (SLR 0)
        --========= QSFP cage #27 =========--
        (065, 061, true , true ), -- fiber 88 (SLR 0)
        (057, 059, true , true ), -- fiber 89 (SLR 0)
        (061, 057, true , true ), -- fiber 90 (SLR 0)
        (059, 063, true , true ), -- fiber 91 (SLR 0)
        --========= QSFP cage #28 =========--
        (058, 062, true , true ), -- fiber 92 (SLR 0)
        (060, 060, true , true ), -- fiber 93 (SLR 0)
        (056, 058, true , true ), -- fiber 94 (SLR 0)
        (062, 056, true , true ), -- fiber 95 (SLR 0)
        --========= QSFP cage #29 =========--
        (064, 070, true , true ), -- fiber 96 (SLR 0)
        (066, 068, true , true ), -- fiber 97 (SLR 0)
        (068, 066, true , true ), -- fiber 98 (SLR 0)
        (070, 064, true , true ), -- fiber 99 (SLR 0)
        --=== DUMMY fiber - use for unconnected channels ===--
        others => (MGT_NULL, MGT_NULL, false, false)
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
        rx_use_buf              => true,
        rx_use_chan_bonding     => false
    );

    constant CFG_MGT_GBTX : t_mgt_type_config := (
        link_type               => MGT_GBTX,
        cpll_refclk_01          => 0, 
        qpll0_refclk_01         => 0,
        qpll1_refclk_01         => 0,
        tx_use_qpll             => true, 
        rx_use_qpll             => true,
        tx_qpll_01              => 1,
        rx_qpll_01              => 1,
        tx_refclk_freq          => CFG_ASYNC_REFCLK_156p25_FREQ,
        rx_refclk_freq          => CFG_ASYNC_REFCLK_156p25_FREQ,
        tx_bus_width            => 40,
        tx_multilane_phalign    => false, 
        rx_use_buf              => false,
        rx_use_chan_bonding     => false
    );

    constant CFG_MGT_LPGBT : t_mgt_type_config := (
        link_type               => MGT_LPGBT,
        cpll_refclk_01          => 0, 
        qpll0_refclk_01         => 0,
        qpll1_refclk_01         => 0,
        tx_use_qpll             => true, 
        rx_use_qpll             => true,
        tx_qpll_01              => 0,
        rx_qpll_01              => 0,
        tx_refclk_freq          => CFG_ASYNC_REFCLK_156p25_FREQ,
        rx_refclk_freq          => CFG_ASYNC_REFCLK_156p25_FREQ,
        tx_bus_width            => 32,
        tx_multilane_phalign    => false, 
        rx_use_buf              => false,
        rx_use_chan_bonding     => false
    );
        
    type t_mgt_config_arr is array (0 to CFG_MGT_NUM_CHANNELS - 1) of t_mgt_config;
    
end board_config_package;

--============================================================================
--                                                                 Package end 
--============================================================================

