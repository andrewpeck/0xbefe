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

    constant CFG_SPY_10GBE                     : boolean := false; -- true = 10 GbE; false = 1 GbE
    constant CFG_SPY_10GBE_ASYNC_GEARBOX       : boolean := true; -- true = async 64b66b gearbox (use with ultrascale FPGAs), false = sync 64b66b gearbox (use with older FPGAs, including virtex7)
    constant CFG_SPY_PACKETFIFO_DEPTH          : integer := 8192; -- buffer almost 8 maximum size packets (2 headers words, 1023 payload words, 1 trailer word)
    constant CFG_SPY_PACKETFIFO_DATA_CNT_WIDTH : integer := 13;

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
    constant CFG_MGT_NUM_CHANNELS : integer := 120;
    
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
        (014, 008, false, true ), -- fiber 0 (SLR 0)
        (012, 010, true , true ), -- fiber 1 (SLR 0)
        (010, 012, false, true ), -- fiber 2 (SLR 0)
        (008, 014, false, true ), -- fiber 3 (SLR 0)
        --========= QSFP cage #1 =========--
        (006, 002, false, true ), -- fiber 4 (SLR 0)
        (000, 000, false, true ), -- fiber 5 (SLR 0)
        (004, 004, false, true ), -- fiber 6 (SLR 0)
        (002, 006, false, true ), -- fiber 7 (SLR 0)
        --========= QSFP cage #2 =========--
        (003, 007, true , false), -- fiber 8 (SLR 0)
        (005, 001, true , false), -- fiber 9 (SLR 0)
        (001, 003, true , false), -- fiber 10 (SLR 0)
        (009, 005, true , false), -- fiber 11 (SLR 0)
        --========= QSFP cage #3 =========--
        (007, 009, false, false), -- fiber 12 (SLR 0)
        (011, 015, true , false), -- fiber 13 (SLR 0)
        (013, 011, true , false), -- fiber 14 (SLR 0)
        (015, 013, true , false), -- fiber 15 (SLR 0)
        --========= QSFP cage #4 =========--
        (017, 023, false, false), -- fiber 16 (SLR 1)
        (019, 021, false, false), -- fiber 17 (SLR 1)
        (021, 019, false, false), -- fiber 18 (SLR 1)
        (023, 017, false, false), -- fiber 19 (SLR 1)
        --========= QSFP cage #6 =========--
        (038, 032, true , false), -- fiber 20 (SLR 2)
        (036, 034, true , false), -- fiber 21 (SLR 2)
        (034, 036, true , false), -- fiber 22 (SLR 2)
        (032, 038, true , false), -- fiber 23 (SLR 2)
        --========= QSFP cage #7 =========--
        (030, 024, true , false), -- fiber 24 (SLR 2)
        (028, 026, true , false), -- fiber 25 (SLR 2)
        (026, 028, true , false), -- fiber 26 (SLR 2)
        (024, 030, true , false), -- fiber 27 (SLR 2)
        --========= QSFP cage #8 =========--
        (025, 031, true , true ), -- fiber 28 (SLR 2)
        (027, 029, true , true ), -- fiber 29 (SLR 2)
        (029, 027, true , true ), -- fiber 30 (SLR 2)
        (031, 025, true , true ), -- fiber 31 (SLR 2)
        --========= QSFP cage #9 =========--
        (033, 039, true , true ), -- fiber 32 (SLR 2)
        (035, 037, true , true ), -- fiber 33 (SLR 2)
        (037, 035, true , true ), -- fiber 34 (SLR 2)
        (039, 033, true , true ), -- fiber 35 (SLR 2)
        --========= QSFP cage #10 =========--
        (050, 048, true , false), -- fiber 36 (SLR 3)
        (052, 054, true , false), -- fiber 37 (SLR 3)
        (048, 052, true , false), -- fiber 38 (SLR 3)
        (046, 050, true , false), -- fiber 39 (SLR 3)
        --========= QSFP cage #11 =========--
        (044, 040, true , false), -- fiber 40 (SLR 3)
        (042, 042, true , false), -- fiber 41 (SLR 3)
        (054, 044, true , false), -- fiber 42 (SLR 3)
        (040, 046, true , false), -- fiber 43 (SLR 3)
        --========= QSFP cage #12 =========--
        (041, 047, false, true ), -- fiber 44 (SLR 3)
        (043, 045, false, true ), -- fiber 45 (SLR 3)
        (045, 043, false, true ), -- fiber 46 (SLR 3)
        (047, 041, false, true ), -- fiber 47 (SLR 3)
        --========= QSFP cage #13 =========--
        (049, 049, false, true ), -- fiber 48 (SLR 3)
        (055, 051, false, true ), -- fiber 49 (SLR 3)
        (053, 053, false, true ), -- fiber 50 (SLR 3)
        (051, 055, false, true ), -- fiber 51 (SLR 3)
        --========= QSFP cage #14 =========--
        (104, 110, false, true ), -- fiber 52 (SLR 3)
        (118, 108, false, true ), -- fiber 53 (SLR 3)
        (106, 106, false, true ), -- fiber 54 (SLR 3)
        (108, 104, false, true ), -- fiber 55 (SLR 3)
        --========= QSFP cage #15 =========--
        (110, 118, false, true ), -- fiber 56 (SLR 3)
        (112, 116, false, true ), -- fiber 57 (SLR 3)
        (116, 114, false, true ), -- fiber 58 (SLR 3)
        (114, 112, false, true ), -- fiber 59 (SLR 3)
        --========= QSFP cage #16 =========--
        (115, 119, true , false), -- fiber 60 (SLR 3)
        (117, 117, true , false), -- fiber 61 (SLR 3)
        (119, 115, true , false), -- fiber 62 (SLR 3)
        (113, 113, true , false), -- fiber 63 (SLR 3)
        --========= QSFP cage #17 =========--
        (111, 105, true , false), -- fiber 64 (SLR 3)
        (109, 107, true , false), -- fiber 65 (SLR 3)
        (107, 109, true , false), -- fiber 66 (SLR 3)
        (105, 111, true , false), -- fiber 67 (SLR 3)
        --========= QSFP cage #18 =========--
        (088, 094, false, true ), -- fiber 68 (SLR 2)
        (090, 092, false, true ), -- fiber 69 (SLR 2)
        (092, 090, false, true ), -- fiber 70 (SLR 2)
        (094, 088, false, true ), -- fiber 71 (SLR 2)
        --========= QSFP cage #19 =========--
        (096, 102, false, true ), -- fiber 72 (SLR 2)
        (098, 100, false, true ), -- fiber 73 (SLR 2)
        (100, 098, false, true ), -- fiber 74 (SLR 2)
        (102, 096, false, true ), -- fiber 75 (SLR 2)
        --========= QSFP cage #20 =========--
        (103, 097, false, false), -- fiber 76 (SLR 2)
        (101, 099, false, false), -- fiber 77 (SLR 2)
        (099, 101, false, false), -- fiber 78 (SLR 2)
        (097, 103, false, false), -- fiber 79 (SLR 2)
        --========= QSFP cage #21 =========--
        (095, 089, false, false), -- fiber 80 (SLR 2)
        (093, 091, false, false), -- fiber 81 (SLR 2)
        (091, 093, false, false), -- fiber 82 (SLR 2)
        (089, 095, false, false), -- fiber 83 (SLR 2)
        --========= QSFP cage #22 =========--
        (072, 078, false, false), -- fiber 84 (SLR 1)
        (074, 076, false, false), -- fiber 85 (SLR 1)
        (076, 074, false, false), -- fiber 86 (SLR 1)
        (078, 072, false, false), -- fiber 87 (SLR 1)
        --========= QSFP cage #23 =========--
        (080, 086, false, false), -- fiber 88 (SLR 1)
        (082, 084, false, false), -- fiber 89 (SLR 1)
        (084, 082, false, false), -- fiber 90 (SLR 1)
        (086, 080, false, false), -- fiber 91 (SLR 1)
        --========= QSFP cage #24 =========--
        (087, 081, false, true ), -- fiber 92 (SLR 1)
        (085, 083, false, true ), -- fiber 93 (SLR 1)
        (083, 085, false, true ), -- fiber 94 (SLR 1)
        (081, 087, false, true ), -- fiber 95 (SLR 1)
        --========= QSFP cage #25 =========--
        (079, 073, false, true ), -- fiber 96 (SLR 1)
        (077, 075, false, true ), -- fiber 97 (SLR 1)
        (075, 077, false, true ), -- fiber 98 (SLR 1)
        (073, 079, false, true ), -- fiber 99 (SLR 1)
        --========= QSFP cage #26 =========--
        (058, 062, true , false), -- fiber 100 (SLR 0)
        (060, 060, true , false), -- fiber 101 (SLR 0)
        (056, 058, true , false), -- fiber 102 (SLR 0)
        (062, 056, true , false), -- fiber 103 (SLR 0)
        --========= QSFP cage #27 =========--
        (064, 070, true , false), -- fiber 104 (SLR 0)
        (066, 068, true , false), -- fiber 105 (SLR 0)
        (068, 066, false, false), -- fiber 106 (SLR 0)
        (070, 064, true , false), -- fiber 107 (SLR 0)
        --========= QSFP cage #28 =========--
        (071, 069, false, true ), -- fiber 108 (SLR 0)
        (069, 067, false, true ), -- fiber 109 (SLR 0)
        (067, 071, false, true ), -- fiber 110 (SLR 0)
        (063, 065, true , true ), -- fiber 111 (SLR 0)
        --========= QSFP cage #29 =========--
        (065, 061, false, true ), -- fiber 112 (SLR 0)
        (057, 059, false, true ), -- fiber 113 (SLR 0)
        (061, 057, false, true ), -- fiber 114 (SLR 0)
        (059, 063, false, true ), -- fiber 115 (SLR 0)
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

    constant CFG_MGT_10GBE : t_mgt_type_config := (
        link_type               => MGT_10GBE,
        cpll_refclk_01          => 0, 
        qpll0_refclk_01         => 0,
        qpll1_refclk_01         => 0,
        tx_use_qpll             => true, 
        rx_use_qpll             => true,
        tx_qpll_01              => 1,
        rx_qpll_01              => 1,
        tx_refclk_freq          => CFG_ASYNC_REFCLK_156p25_FREQ,
        rx_refclk_freq          => CFG_ASYNC_REFCLK_156p25_FREQ,
        tx_bus_width            => 64,
        tx_multilane_phalign    => false, 
        rx_use_buf              => true,
        rx_use_chan_bonding     => false
    );

    constant CFG_MGT_25GBE : t_mgt_type_config := (
        link_type               => MGT_25GBE,
        cpll_refclk_01          => 0, 
        qpll0_refclk_01         => 0,
        qpll1_refclk_01         => 0,
        tx_use_qpll             => true, 
        rx_use_qpll             => true,
        tx_qpll_01              => 0,
        rx_qpll_01              => 0,
        tx_refclk_freq          => CFG_ASYNC_REFCLK_156p25_FREQ,
        rx_refclk_freq          => CFG_ASYNC_REFCLK_156p25_FREQ,
        tx_bus_width            => 128,
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

    constant CFG_MGT_ODMB57_BIDIR : t_mgt_type_config := (
        link_type               => MGT_ODMB57_BIDIR,
        cpll_refclk_01          => 0, 
        qpll0_refclk_01         => 0,
        qpll1_refclk_01         => 1,
        tx_use_qpll             => true, 
        rx_use_qpll             => true,
        tx_qpll_01              => 0,
        rx_qpll_01              => 0,
        tx_refclk_freq          => CFG_ASYNC_REFCLK_156p25_FREQ,
        rx_refclk_freq          => CFG_ASYNC_REFCLK_156p25_FREQ,
        tx_bus_width            => 32,
        tx_multilane_phalign    => false, 
        rx_use_buf              => true,
        rx_use_chan_bonding     => true
    );
        
    type t_mgt_config_arr is array (0 to CFG_MGT_NUM_CHANNELS - 1) of t_mgt_config;
    
end board_config_package;

--============================================================================
--                                                                 Package end 
--============================================================================

