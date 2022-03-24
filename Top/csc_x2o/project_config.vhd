library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common_pkg.all;
use work.board_config_package.all;
use work.csc_pkg.all;
use work.mgt_pkg.all;


package project_config is

    --================================--
    -- CSC blocks and associated types  
    --================================--

    constant CFG_NUM_SLRS       : integer := 1;    -- number of full CSC blocks to instantiate (typically one per SLR)

    --================================--
    -- CSC configuration                
    --================================--

    constant CFG_NUM_DMBS       : t_int_array(0 to CFG_NUM_SLRS - 1) := (others => 2);
    constant CFG_NUM_GBT_LINKS  : t_int_array(0 to CFG_NUM_SLRS - 1) := (others => 4);
    constant CFG_USE_SPY_LINK : t_bool_array(0 to CFG_NUM_SLRS - 1) := (others => true);
    constant CFG_TTC_TX_SOURCE_SLR : integer := 0;
    constant CFG_USE_TTC_TX_LINK : boolean := true;

    --================================--
    -- Link configuration               
    --================================--

    constant CFG_SPY_LINK : t_int_array(0 to CFG_NUM_SLRS -1) := (0 => 19);

    constant CFG_TTC_LINKS : t_int_array(0 to 3) := (44, 45, 46, 47);

    constant CFG_DMB_CONFIG_ARR : t_dmb_config_arr_per_slr(0 to CFG_NUM_SLRS - 1)(0 to CFG_DAQ_MAX_DMBS - 1) := (
        0 =>
        ( ------------------------------------------------ SLR0 ------------------------------------------------
        (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (16, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB0, SLR 0
        (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (17, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB1, SLR 0
            others => DMB_CONFIG_NULL
        )
    );

    constant CFG_GBT_LINK_CONFIG_ARR : t_gbt_link_config_arr_per_slr(0 to CFG_NUM_SLRS - 1)(0 to CFG_MAX_GBTS - 1) := (
        0 =>
        ( ------------------------------------------------ SLR0 ------------------------------------------------
            (tx_fiber => 40, rx_fiber => 40), -- GBT0, SLR 0
            (tx_fiber => 41, rx_fiber => 41), -- GBT1, SLR 0
            (tx_fiber => 42, rx_fiber => 42), -- GBT2, SLR 0
            (tx_fiber => 43, rx_fiber => 43), -- GBT3, SLR 0
            others => (tx_fiber => CFG_BOARD_MAX_LINKS, rx_fiber => CFG_BOARD_MAX_LINKS)
        )
    );

    --================================--
    -- MGT configuration
    --================================--   
    
    constant CFG_MGT_LINK_CONFIG : t_mgt_config_arr := (
        ----------------------------- quad 120 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 0
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 1
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 2
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 3
        ----------------------------- quad 121 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 4
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 5
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 6
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 7
        ----------------------------- quad 122 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 8
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 9
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 10
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 11
        ----------------------------- quad 123 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 12
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 13
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 14
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 15
        ----------------------------- quad 124 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_TTC      , qpll_inst_type => QPLL_LPGBT      , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => true ), -- MGT 16
        (mgt_type => CFG_MGT_TTC      , qpll_inst_type => QPLL_NULL       , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => true ), -- MGT 17
        (mgt_type => CFG_MGT_TTC      , qpll_inst_type => QPLL_NULL       , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => true ), -- MGT 18
        (mgt_type => CFG_MGT_TTC      , qpll_inst_type => QPLL_NULL       , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => true ), -- MGT 19
        ----------------------------- quad 125 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 20
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 21
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 22
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 23
        ----------------------------- quad 128 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX       , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 2, is_master => true , chbond_master => 0, ibert_inst => false), -- MGT 24
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL       , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 25
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL       , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 26
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL       , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 27
        ----------------------------- quad 129 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 28
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 29
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 30
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 31
        ----------------------------- quad 130 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 32
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 33
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 34
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 35
        ----------------------------- quad 131 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 36
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 37
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 38
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 39
        ----------------------------- quad 132 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 40
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 41
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 42
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 43
        ----------------------------- quad 133 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 44
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 45
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 46
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 47
        ----------------------------- quad 134 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 48
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 49
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 50
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 51
        ----------------------------- quad 135 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 52
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 53
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 54
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 55
        ----------------------------- quad 220 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 4, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 56
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 4, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 57
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 4, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 58
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 4, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 59
        ----------------------------- quad 221 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 4, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 60
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 4, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 61
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 4, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 62
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 4, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 63
        ----------------------------- quad 222 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 4, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 64
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 4, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 65
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 4, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 66
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 4, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 67
        ----------------------------- quad 223 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 4, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 68
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 4, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 69
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 4, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 70
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 4, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 71
        ----------------------------- quad 224 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 5, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 72
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 5, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 73
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 5, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 74
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 5, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 75
        ----------------------------- quad 225 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 5, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 76
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 5, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 77
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 5, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 78
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 5, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 79
        ----------------------------- quad 226 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 5, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 80
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 5, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 81
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 5, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 82
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 5, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 83
        ----------------------------- quad 227 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 84
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 85
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 86
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 87
        ----------------------------- quad 228 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 6, is_master => true , chbond_master => 0, ibert_inst => true ), -- MGT 88
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 6, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 89
        (mgt_type => CFG_MGT_GBE      , qpll_inst_type => QPLL_NULL       , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 6, is_master => true , chbond_master => 0, ibert_inst => false), -- MGT 90
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 6, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 91
        ----------------------------- quad 229 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 6, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 92
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 6, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 93
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 6, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 94
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 6, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 95
        ----------------------------- quad 230 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 096, refclk0_idx => 24, refclk1_idx => 6, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 96
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 096, refclk0_idx => 24, refclk1_idx => 6, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 97
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 096, refclk0_idx => 24, refclk1_idx => 6, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 98
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 096, refclk0_idx => 24, refclk1_idx => 6, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 99
        ----------------------------- quad 232 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 100, refclk0_idx => 26, refclk1_idx => 7, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 100
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 100, refclk0_idx => 26, refclk1_idx => 7, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 101
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 100, refclk0_idx => 26, refclk1_idx => 7, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 102
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 100, refclk0_idx => 26, refclk1_idx => 7, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 103
        ----------------------------- quad 233 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 104, refclk0_idx => 27, refclk1_idx => 7, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 104
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 104, refclk0_idx => 27, refclk1_idx => 7, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 105
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 104, refclk0_idx => 27, refclk1_idx => 7, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 106
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 104, refclk0_idx => 27, refclk1_idx => 7, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 107
        ----------------------------- quad 234 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 108, refclk0_idx => 28, refclk1_idx => 7, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 108
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 108, refclk0_idx => 28, refclk1_idx => 7, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 109
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 108, refclk0_idx => 28, refclk1_idx => 7, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 110
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 108, refclk0_idx => 28, refclk1_idx => 7, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 111
        ----------------------------- quad 235 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 112, refclk0_idx => 29, refclk1_idx => 7, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 112
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 112, refclk0_idx => 29, refclk1_idx => 7, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 113
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 112, refclk0_idx => 29, refclk1_idx => 7, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 114
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 112, refclk0_idx => 29, refclk1_idx => 7, is_master => false, chbond_master => 0, ibert_inst => false) -- MGT 115
    );

end package project_config;

