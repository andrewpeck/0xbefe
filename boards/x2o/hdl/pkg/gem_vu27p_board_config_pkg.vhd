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
use work.ttc_pkg.C_TTC_CLK_FREQUENCY;

--============================================================================
--                                                         Package declaration
--============================================================================
package board_config_package is

    function get_num_gbts_per_oh(gem_station : integer) return integer;
    function get_num_vfats_per_oh(gem_station : integer) return integer;
    function get_gbt_widebus(gem_station, oh_version : integer) return integer;
    
    ------------ Firmware flavor and board type  ------------
    constant CFG_FW_FLAVOR          : std_logic_vector(3 downto 0) := x"0"; -- 0 = GEM_AMC; 1 = CSC_FED
    constant CFG_BOARD_TYPE         : std_logic_vector(3 downto 0) := x"3"; -- 0 = GLIB; 1 = CTP7; 2 = CVP13; 3 = APEX; 4 = X2O
    
    ------------ Board specific constants ------------
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
    
    type t_oh_link_config_arr is array (0 to 3) of t_oh_link_config;

    constant CFG_OH_LINK_CONFIG_ARR_GE11 : t_oh_link_config_arr := (
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))
    );
    constant CFG_OH_LINK_CONFIG_ARR_GE21 : t_oh_link_config_arr := (
        (((00, 00), (01, 01), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((02, 02), (03, 03), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((04, 04), (05, 05), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((06, 06), (07, 07), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))
    );
    constant CFG_OH_LINK_CONFIG_ARR_ME0 : t_oh_link_config_arr := (
        (((00, 00), (TXRX_NULL, 01), (01, 02),  (TXRX_NULL, 03),  (02, 04),   (TXRX_NULL, 05),  (03, 06),  (TXRX_NULL, 07)), (LINK_NULL, LINK_NULL)),
        (((08, 08), (TXRX_NULL, 09), (09, 10),  (TXRX_NULL, 11),  (10, 12),   (TXRX_NULL, 13),  (11, 14),  (TXRX_NULL, 15)), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))
    );

    function get_oh_link_config_arr(gem_station: integer; ge11_config, ge21_config, me0_config : t_oh_link_config_arr) return t_oh_link_config_arr;
    constant CFG_OH_LINK_CONFIG_ARR : t_oh_link_config_arr := get_oh_link_config_arr(CFG_GEM_STATION, CFG_OH_LINK_CONFIG_ARR_GE11, CFG_OH_LINK_CONFIG_ARR_GE21, CFG_OH_LINK_CONFIG_ARR_ME0);

    type t_trig_tx_link_config_arr is array (0 to CFG_NUM_TRIG_TX - 1) of integer range 0 to CFG_BOARD_MAX_LINKS;
    
    constant CFG_TRIG_TX_LINK_CONFIG_ARR : t_trig_tx_link_config_arr := (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS);
    
    constant CFG_USE_SPY_LINK : boolean := false;
    constant CFG_SPY_LINK : integer := 0;
    
    --================================--
    -- Fiber to MGT mapping
    --================================--    

    constant CFG_NUM_REFCLK0      : integer := 4;
    constant CFG_NUM_REFCLK1      : integer := 1; 
    constant CFG_MGT_NUM_CHANNELS : integer := 16;
    
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
        --========= ARF6 #10 (J7) =========--
        (014, 014, false, false), -- fiber 0
        (000, 000, false, false), -- fiber 1
        (012, 012, false, false), -- fiber 2
        (002, 002, false, false), -- fiber 3
        (010, 010, false, false), -- fiber 4
        (004, 004, false, false), -- fiber 5
        (008, 008, false, false), -- fiber 6
        (006, 006, false, false), -- fiber 7
        --========= ARF6 #11 (J10) =========--
        (001, 001, false, true ), -- fiber 8
        (015, 015, false, true ), -- fiber 9
        (003, 003, false, true ), -- fiber 10
        (013, 013, false, true ), -- fiber 11
        (005, 005, false, true ), -- fiber 12
        (011, 011, false, true ), -- fiber 13
        (007, 007, false, true ), -- fiber 14
        (009, 009, false, true ), -- fiber 15
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
        cpll_refclk_01          => 1, 
        qpll0_refclk_01         => 1,
        qpll1_refclk_01         => 1,
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
        cpll_refclk_01          => 0, 
        qpll0_refclk_01         => 0,
        qpll1_refclk_01         => 0,
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
        cpll_refclk_01          => 0, 
        qpll0_refclk_01         => 0,
        qpll1_refclk_01         => 0,
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
    
    
    constant CFG_MGT_LINK_CONFIG_GE11 : t_mgt_config_arr := (
        ----------------------------- quad 224 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 225 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 226 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 227 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false)
    );
    constant CFG_MGT_LINK_CONFIG_GE21 : t_mgt_config_arr := (
        ----------------------------- quad 224 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => true , ibert_inst => true ),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => true ),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 225 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 226 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 227 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false)
    );
    constant CFG_MGT_LINK_CONFIG_ME0 : t_mgt_config_arr := (
        ----------------------------- quad 224 -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => true , ibert_inst => true ),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => true ),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => true ),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => true ),
        ----------------------------- quad 225 -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => true ),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => true ),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => true ),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => true ),
        ----------------------------- quad 226 -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 227 -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false)
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
