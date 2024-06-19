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
    constant CFG_BOARD_MAX_LINKS    : integer := 16;
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

    constant CFG_SPY_10GBE                     : boolean := true; -- true = 10 GbE; false = 1 GbE
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
    constant CFG_MGT_NUM_CHANNELS : integer := CFG_BOARD_MAX_LINKS;
    
    constant CFG_TCDS2_MGT_REFCLK1: integer := CFG_NUM_REFCLK1; -- not used in X2O rev1
    
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
--        --========= QSFP cage #9 (actually 7?) =========--
--        (033-24, 039-24, true , true ), -- fiber 32 | 0 (SLR 2) | TX 130_1, RX 131_3 | GE11 OH0 trig0 | GE21 OH2 FIBER BOX
--        (035-24, 037-24, true , true ), -- fiber 33 | 1 (SLR 2) | TX 130_3, RX 131_1 | GE11 OH0 trig1 | GE21 OH2 FIBER BOX
--        (037-24, 035-24, true , true ), -- fiber 34 | 2 (SLR 2) | TX 131_1, RX 130_3 | GE11 OH1 trig0 | GE21 OH3 FIBER BOX
--        (039-24, 033-24, true , true ), -- fiber 35 | 3 (SLR 2) | TX 131_3, RX 130_1 | GE11 OH1 trig1 | GE21 OH3 FIBER BOX
--        --========= QSFP cage #6 (actually 8?) =========--
--        (038-24, 032-24, true , false), -- fiber 20 | 4 (SLR 2) | TX 131_2, RX 130_0 | GE11 none      | GE21 OH0
--        (036-24, 034-24, true , false), -- fiber 21 | 5 (SLR 2) | TX 131_0, RX 130_2 | GE11 none      | GE21 OH0
--        (034-24, 036-24, true , false), -- fiber 22 | 6 (SLR 2) | TX 130_2, RX 131_0 | GE11 none      | GE21 OH1
--        (032-24, 038-24, true , false), -- fiber 23 | 7 (SLR 2) | TX 130_0, RX 131_2 | GE11 none      | GE21 OH1
--        --========= QSFP cage #7 (actually ?) =========--
--        (030-24, 024-24, true , false), -- fiber 24 | 8  (SLR 2) | TX 129_2, RX 128_0 | GE11 OH 0 GBT0 | 
--        (028-24, 026-24, true , false), -- fiber 25 | 9  (SLR 2) | TX 129_0, RX 128_2 | GE11 OH 0 GBT1 | 
--        (026-24, 028-24, true , false), -- fiber 26 | 10 (SLR 2) | TX 128_2, RX 129_0 | GE11 OH 0 GBT2 | 
--        (024-24, 030-24, true , false), -- fiber 27 | 11 (SLR 2) | TX 128_0, RX 129_2 | GE11 none      | 
--        --========= QSFP cage #8 (actually ?) =========--
--        (025-24, 031-24, true , true ), -- fiber 28 | 12 (SLR 2) | TX 128_1, RX 129_3 | GE11 OH 1 GBT0 | 
--        (027-24, 029-24, true , true ), -- fiber 29 | 13 (SLR 2) | TX 128_3, RX 129_1 | GE11 OH 1 GBT1 | 
--        (029-24, 027-24, true , true ), -- fiber 30 | 14 (SLR 2) | TX 129_1, RX 128_3 | GE11 OH 1 GBT2 | 
--        (031-24, 025-24, true , true ), -- fiber 31 | 15 (SLR 2) | TX 129_3, RX 128_1 | GE11 none      | 
        --========= QSFP cage #19 (actually 18) =========--
        (096-88, 102-88, false, true ), -- fiber 72 (SLR 2)
        (098-88, 100-88, false, true ), -- fiber 73 (SLR 2)
        (100-88, 098-88, false, true ), -- fiber 74 (SLR 2)
        (102-88, 096-88, false, true ), -- fiber 75 (SLR 2)
        --========= QSFP cage #20 =========--
        (103-88, 097-88, false, false), -- fiber 76 (SLR 2)
        (101-88, 099-88, false, false), -- fiber 77 (SLR 2)
        (099-88, 101-88, false, false), -- fiber 78 (SLR 2)
        (097-88, 103-88, false, false), -- fiber 79 (SLR 2)
        --========= QSFP cage #18 =========--
        (088-88, 094-88, false, true ), -- fiber 68 (SLR 2)
        (090-88, 092-88, false, true ), -- fiber 69 (SLR 2)
        (092-88, 090-88, false, true ), -- fiber 70 (SLR 2)
        (094-88, 088-88, false, true ), -- fiber 71 (SLR 2)
        --========= QSFP cage #21 (actually 20) =========--
        (095-88, 089-88, false, false), -- fiber 80 (SLR 2)
        (093-88, 091-88, false, false), -- fiber 81 (SLR 2)
        (091-88, 093-88, false, false), -- fiber 82 (SLR 2)
        (089-88, 095-88, false, false), -- fiber 83 (SLR 2)

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
        tx_multilane_phalign    => true, --false, 
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
        tx_multilane_phalign    => true, --false, 
        rx_use_buf              => false,
        rx_use_chan_bonding     => false
    );

    constant CFG_MGT_TRIG_3P2 : t_mgt_type_config := (
        link_type               => MGT_3P2G_8B10B,
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
        rx_use_buf              => false,
        rx_use_chan_bonding     => false
    );

    constant CFG_MGT_TRIG_4P0 : t_mgt_type_config := (
        link_type               => MGT_4P0G_8B10B,
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

