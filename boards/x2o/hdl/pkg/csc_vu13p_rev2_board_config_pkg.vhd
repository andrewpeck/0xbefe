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
    constant CFG_FW_FLAVOR          : std_logic_vector(3 downto 0) := x"1"; -- 0 = GEM; 1 = CSC_FED
    constant CFG_BOARD_TYPE         : std_logic_vector(3 downto 0) := x"5"; -- 0 = GLIB; 1 = CTP7; 2 = CVP13; 3 = APEX; 4 = X2O rev1; 5 = X2O rev2

    ------------ Board specific constants ------------
    constant CFG_BOARD_MAX_LINKS    : integer := 24; --120;

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

    constant CFG_SPY_10GBE                     : boolean := false; -- true = 10 GbE; false = 1 GbE
    constant CFG_SPY_10GBE_ASYNC_GEARBOX       : boolean := true; -- true = async 64b66b gearbox (use with ultrascale FPGAs), false = sync 64b66b gearbox (use with older FPGAs, including virtex7)
    constant CFG_SPY_PACKETFIFO_DEPTH          : integer := 8192; -- buffer almost 8 maximum size packets (2 headers words, 1023 payload words, 1 trailer word)
    constant CFG_SPY_PACKETFIFO_DATA_CNT_WIDTH : integer := 13;

    ------------ DEBUG FLAGS ------------
    constant CFG_DEBUG_10GBE_MAC_PCS        : boolean := false; -- if set to true, an ILA will be instantiated which allows probing the 10 GbE MAC-PCS core
    
    --================================--
    -- Fiber to MGT mapping
    --================================--    

    constant CFG_NUM_REFCLK0      : integer := 30;
    constant CFG_NUM_REFCLK1      : integer := 16; 
    constant CFG_MGT_NUM_CHANNELS : integer := CFG_BOARD_MAX_LINKS;

    constant CFG_TCDS2_MGT_REFCLK1: integer := 2;

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
--    constant CFG_FIBER_TO_MGT_MAP : t_fiber_to_mgt_link_map := (
--        --========= QSFP cage #0 =========--
--        (002, 002, false, false), -- fiber 0 (SLR 0)
--        (003, 005, true , true ), -- fiber 1 (SLR 0)
--        (004, 000, false, false), -- fiber 2 (SLR 0)
--        (005, 003, true , true ), -- fiber 3 (SLR 0)
--        --========= QSFP cage #1 =========--
--        (000, 004, false, false), -- fiber 4 (SLR 0)
--        (001, 001, true , true ), -- fiber 5 (SLR 0)
--        (006, 006, false, false), -- fiber 6 (SLR 0)
--        (009, 007, true , true ), -- fiber 7 (SLR 0)
--        --========= QSFP cage #2 =========--
--        (011, 011, true , true ), -- fiber 8 (SLR 0)
--        (010, 010, false, false), -- fiber 9 (SLR 0)
--        (007, 013, false, true ), -- fiber 10 (SLR 0)
--        (008, 008, false, false), -- fiber 11 (SLR 0)
--        --========= QSFP cage #3 =========--
--        (015, 009, true , true ), -- fiber 12 (SLR 0)
--        (014, 014, false, false), -- fiber 13 (SLR 0)
--        (013, 015, true , true ), -- fiber 14 (SLR 0)
--        (012, 012, true , false), -- fiber 15 (SLR 0)
--        --========= QSFP cage #4 =========--
--        (023, 023, false, true ), -- fiber 16 (SLR 1)
--        (022, 022, false, false), -- fiber 17 (SLR 1)
--        (021, 021, false, true ), -- fiber 18 (SLR 1)
--        (020, 020, false, false), -- fiber 19 (SLR 1)
--        --========= QSFP cage #5 =========--
--        (019, 019, false, true ), -- fiber 20 (SLR 1)
--        (018, 018, false, false), -- fiber 21 (SLR 1)
--        (017, 017, false, true ), -- fiber 22 (SLR 1)
--        (016, 016, false, false), -- fiber 23 (SLR 1)
--        --========= QSFP cage #6 =========--
--        (024, 024, true , true ), -- fiber 24 (SLR 2)
--        (025, 025, true , false), -- fiber 25 (SLR 2)
--        (026, 026, true , true ), -- fiber 26 (SLR 2)
--        (027, 027, true , false), -- fiber 27 (SLR 2)
--        --========= QSFP cage #7 =========--
--        (028, 028, true , true ), -- fiber 28 (SLR 2)
--        (029, 029, true , false), -- fiber 29 (SLR 2)
--        (030, 030, true , true ), -- fiber 30 (SLR 2)
--        (031, 031, true , false), -- fiber 31 (SLR 2)
--        --========= QSFP cage #8 =========--
--        (035, 035, true , false), -- fiber 32 (SLR 2)
--        (034, 034, true , true ), -- fiber 33 (SLR 2)
--        (033, 033, true , false), -- fiber 34 (SLR 2)
--        (032, 032, true , true ), -- fiber 35 (SLR 2)
--        --========= QSFP cage #9 =========--
--        (039, 039, true , false), -- fiber 36 (SLR 2)
--        (038, 038, true , true ), -- fiber 37 (SLR 2)
--        (037, 037, true , false), -- fiber 38 (SLR 2)
--        (036, 036, true , true ), -- fiber 39 (SLR 2)
--        --========= QSFP cage #10 =========--
--        (040, 040, true , true ), -- fiber 40 (SLR 3)
--        (041, 041, false, false), -- fiber 41 (SLR 3)
--        (054, 042, true , true ), -- fiber 42 (SLR 3)
--        (043, 043, false, false), -- fiber 43 (SLR 3)
--        --========= QSFP cage #11 =========--
--        (042, 044, true , true ), -- fiber 44 (SLR 3)
--        (045, 045, false, false), -- fiber 45 (SLR 3)
--        (044, 046, true , true ), -- fiber 46 (SLR 3)
--        (047, 047, false, false), -- fiber 47 (SLR 3)
--        --========= QSFP cage #12 =========--
--        (055, 053, false, false), -- fiber 48 (SLR 3)
--        (048, 054, true , true ), -- fiber 49 (SLR 3)
--        (049, 055, false, false), -- fiber 50 (SLR 3)
--        (046, 048, true , true ), -- fiber 51 (SLR 3)
--        --========= QSFP cage #13 =========--
--        (051, 049, false, false), -- fiber 52 (SLR 3)
--        (050, 050, true , true ), -- fiber 53 (SLR 3)
--        (053, 051, false, false), -- fiber 54 (SLR 3)
--        (052, 052, true , true ), -- fiber 55 (SLR 3)
--        --========= QSFP cage #14 =========--
--        (114, 118, false, false), -- fiber 56 (SLR 3)
--        (115, 113, true , true ), -- fiber 57 (SLR 3)
--        (116, 116, false, false), -- fiber 58 (SLR 3)
--        (117, 115, true , true ), -- fiber 59 (SLR 3)
--        --========= QSFP cage #15 =========--
--        (112, 114, false, false), -- fiber 60 (SLR 3)
--        (119, 117, true , true ), -- fiber 61 (SLR 3)
--        (110, 112, false, false), -- fiber 62 (SLR 3)
--        (113, 119, true , true ), -- fiber 63 (SLR 3)
--        --========= QSFP cage #16 =========--
--        (109, 109, true , true ), -- fiber 64 (SLR 3)
--        (106, 108, false, false), -- fiber 65 (SLR 3)
--        (111, 111, true , true ), -- fiber 66 (SLR 3)
--        (108, 110, false, false), -- fiber 67 (SLR 3)
--        --========= QSFP cage #17 =========--
--        (105, 105, true , true ), -- fiber 68 (SLR 3)
--        (104, 104, false, false), -- fiber 69 (SLR 3)
--        (107, 107, true , true ), -- fiber 70 (SLR 3)
--        (118, 106, false, false), -- fiber 71 (SLR 3)
--        --========= QSFP cage #18 =========--
--        (102, 102, false, false), -- fiber 72 (SLR 2)
--        (103, 103, false, true ), -- fiber 73 (SLR 2)
--        (100, 100, false, false), -- fiber 74 (SLR 2)
--        (101, 101, false, true ), -- fiber 75 (SLR 2)
--        --========= QSFP cage #19 =========--
--        (098, 098, false, false), -- fiber 76 (SLR 2)
--        (099, 099, false, true ), -- fiber 77 (SLR 2)
--        (096, 096, false, false), -- fiber 78 (SLR 2)
--        (097, 097, false, true ), -- fiber 79 (SLR 2)
--        --========= QSFP cage #20 =========--
--        (093, 093, false, true ), -- fiber 80 (SLR 2)
--        (092, 092, false, false), -- fiber 81 (SLR 2)
--        (095, 095, false, true ), -- fiber 82 (SLR 2)
--        (094, 094, false, false), -- fiber 83 (SLR 2)
--        --========= QSFP cage #21 =========--
--        (089, 089, false, true ), -- fiber 84 (SLR 2)
--        (088, 088, false, false), -- fiber 85 (SLR 2)
--        (091, 091, false, true ), -- fiber 86 (SLR 2)
--        (090, 090, false, false), -- fiber 87 (SLR 2)
--        --========= QSFP cage #22 =========--
--        (086, 086, false, true ), -- fiber 88 (SLR 1)
--        (087, 087, false, false), -- fiber 89 (SLR 1)
--        (084, 084, false, true ), -- fiber 90 (SLR 1)
--        (085, 085, false, false), -- fiber 91 (SLR 1)
--        --========= QSFP cage #23 =========--
--        (082, 082, false, true ), -- fiber 92 (SLR 1)
--        (083, 083, false, false), -- fiber 93 (SLR 1)
--        (080, 080, false, true ), -- fiber 94 (SLR 1)
--        (081, 081, false, false), -- fiber 95 (SLR 1)
--        --========= QSFP cage #24 =========--
--        (077, 077, false, false), -- fiber 96 (SLR 1)
--        (076, 076, false, true ), -- fiber 97 (SLR 1)
--        (079, 079, false, false), -- fiber 98 (SLR 1)
--        (078, 078, false, true ), -- fiber 99 (SLR 1)
--        --========= QSFP cage #25 =========--
--        (073, 073, false, false), -- fiber 100 (SLR 1)
--        (072, 072, false, true ), -- fiber 101 (SLR 1)
--        (075, 075, false, false), -- fiber 102 (SLR 1)
--        (074, 074, false, true ), -- fiber 103 (SLR 1)
--        --========= QSFP cage #26 =========--
--        (070, 070, true , true ), -- fiber 104 (SLR 0)
--        (071, 065, false, false), -- fiber 105 (SLR 0)
--        (068, 068, false, true ), -- fiber 106 (SLR 0)
--        (069, 071, false, false), -- fiber 107 (SLR 0)
--        --========= QSFP cage #27 =========--
--        (066, 066, true , true ), -- fiber 108 (SLR 0)
--        (067, 067, false, false), -- fiber 109 (SLR 0)
--        (064, 064, true , true ), -- fiber 110 (SLR 0)
--        (063, 069, true , false), -- fiber 111 (SLR 0)
--        --========= QSFP cage #28 =========--
--        (057, 057, false, false), -- fiber 112 (SLR 0)
--        (056, 060, true , true ), -- fiber 113 (SLR 0)
--        (065, 063, false, false), -- fiber 114 (SLR 0)
--        (062, 062, true , true ), -- fiber 115 (SLR 0)
--        --========= QSFP cage #29 =========--
--        (059, 061, false, false), -- fiber 116 (SLR 0)
--        (058, 056, true , true ), -- fiber 117 (SLR 0)
--        (061, 059, false, false), -- fiber 118 (SLR 0)
--        (060, 058, true , true ), -- fiber 119 (SLR 0)
--        --=== DUMMY fiber - use for unconnected channels ===--
--        others => (MGT_NULL, MGT_NULL, false, false)
--    );

    constant CFG_FIBER_TO_MGT_MAP : t_fiber_to_mgt_link_map := (
        --========= QSFP cage #22 =========--
        (086-72, 086-72, false, true ), -- fiber 88 (SLR 1)
        (087-72, 087-72, false, false), -- fiber 89 (SLR 1)
        (084-72, 084-72, false, true ), -- fiber 90 (SLR 1)
        (085-72, 085-72, false, false), -- fiber 91 (SLR 1)
        --========= QSFP cage #23 =========--
        (082-72, 082-72, false, true ), -- fiber 92 (SLR 1)
        (083-72, 083-72, false, false), -- fiber 93 (SLR 1)
        (080-72, 080-72, false, true ), -- fiber 94 (SLR 1)
        (081-72, 081-72, false, false), -- fiber 95 (SLR 1)
        --========= QSFP cage #24 =========--
        (077-72, 077-72, false, false), -- fiber 96 (SLR 1)
        (076-72, 076-72, false, true ), -- fiber 97 (SLR 1)
        (079-72, 079-72, false, false), -- fiber 98 (SLR 1)
        (078-72, 078-72, false, true ), -- fiber 99 (SLR 1)
        --========= QSFP cage #25 =========--
        (073-72, 073-72, false, false), -- fiber 100 (SLR 1)
        (072-72, 072-72, false, true ), -- fiber 101 (SLR 1)
        (075-72, 075-72, false, false), -- fiber 102 (SLR 1)
        (074-72, 074-72, false, true ), -- fiber 103 (SLR 1)
        --========= QSFP cage #4 =========--
        (023, 023, false, true ), -- fiber 16 (SLR 1)
        (022, 022, false, false), -- fiber 17 (SLR 1)
        (021, 021, false, true ), -- fiber 18 (SLR 1)
        (020, 020, false, false), -- fiber 19 (SLR 1)
        --========= QSFP cage #5 =========--
        (019, 019, false, true ), -- fiber 20 (SLR 1)
        (018, 018, false, false), -- fiber 21 (SLR 1)
        (017, 017, false, true ), -- fiber 22 (SLR 1)
        (016, 016, false, false), -- fiber 23 (SLR 1)        
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
        rx_use_buf              => false,
        rx_use_chan_bonding     => false
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
        rx_use_buf              => true,
        rx_use_chan_bonding     => false
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
        rx_use_buf              => true,
        rx_use_chan_bonding     => true
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
        rx_use_buf              => false,
        rx_use_chan_bonding     => false
    );
            
    type t_mgt_config_arr is array (0 to CFG_MGT_NUM_CHANNELS - 1) of t_mgt_config;
    
end board_config_package;

--============================================================================
--                                                                 Package end 
--============================================================================

