library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common_pkg.all;
use work.board_config_package.all;
use work.gem_pkg.all;
use work.mgt_pkg.all;

package project_config is

    --================================--
    -- GEM blocks and associated types  
    --================================--

    constant CFG_NUM_GEM_BLOCKS         : integer := 1; -- total number of GEM blocks to instanciate
    type t_int_per_gem is array (0 to CFG_NUM_GEM_BLOCKS - 1) of integer;
    type t_oh_trig_link_type_arr is array (0 to CFG_NUM_GEM_BLOCKS - 1) of t_oh_trig_link_type;

    --================================--
    -- GEM configuration                
    --================================--

    constant CFG_GEM_STATION            : t_int_per_gem := (others => 2);  -- 0 = ME0; 1 = GE1/1; 2 = GE2/1
    constant CFG_OH_VERSION             : t_int_per_gem := (others => 2);  -- for now this is only relevant to GE2/1 where v2 OH has different elink map, and uses widebus mode
    constant CFG_NUM_OF_OHs             : t_int_per_gem := (others => 1); -- total number of OHs to instanciate (remember to adapt the CFG_OH_LINK_CONFIG_ARR accordingly)
    constant CFG_NUM_GBTS_PER_OH        : t_int_per_gem := (others => 2);  -- number of GBTs per OH
    constant CFG_NUM_VFATS_PER_OH       : t_int_per_gem := (others => 12); -- number of VFATs per OH
    constant CFG_GBT_WIDEBUS            : t_int_per_gem := (others => 1);  -- 0 means use standard mode, 1 means use widebus (set to 1 for GE2/1 OH version 2+)

    constant CFG_OH_TRIG_LINK_TYPE      : t_oh_trig_link_type_arr := (others => OH_TRIG_LINK_TYPE_GBT); -- type of trigger link to use, the 3.2G and 4.0G are applicable to GE11, and GBT type is only applicable to GE21
    constant CFG_USE_TRIG_TX_LINKS      : boolean := false; -- if true, then trigger transmitters will be instantiated (used to connect to EMTF)
    constant CFG_NUM_TRIG_TX            : integer := 8; -- number of trigger transmitters used to connect to EMTF

    --========================--
    --== Link configuration ==--
    --========================--

    constant CFG_USE_SPY_LINK_TX : t_spy_link_enable_arr := (others => true);
    constant CFG_USE_SPY_LINK_RX : t_spy_link_enable_arr := (others => true);
    constant CFG_SPY_LINK : t_spy_link_config := (0 => 36, others => TXRX_NULL);

    constant CFG_USE_TTC_TX_LINK : boolean := false;
    constant CFG_TTC_LINKS : t_int_array(0 to 3) := (others => 0);

    constant CFG_USE_TTC_GBTX_LINK  : boolean := false;
    constant CFG_TTC_GBTX_LINK      : integer := 0;


    constant CFG_TRIG_TX_LINK_CONFIG_ARR : t_trig_tx_link_config_arr_arr := (others => (others => TXRX_NULL));

    constant CFG_OH_LINK_CONFIG_ARR : t_oh_link_config_arr_arr := (
        0 =>
        ( ------------------------------------------------ SLR0 ------------------------------------------------
            (((024, 024), (025, 025), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), -- OH0, SLR 0
            (((026, 026), (027, 027), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), -- OH1, SLR 0
            (((020, 020), (021, 021), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), -- OH2, SLR 0
            (((022, 022), (023, 023), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), -- OH3, SLR 0
            others => ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))
        ),
        others => (others => ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)))
    );

    --================================--
    -- MGT configuration
    --================================--    

    constant CFG_MGT_LINK_CONFIG : t_mgt_config_arr := (
        ----------------------------- quad 120 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 0
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 1
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 2
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 3
        ----------------------------- quad 121 (SLR 0) -----------------------------                                           
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 4
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 5
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 6
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 7
        ----------------------------- quad 122 (SLR 0) -----------------------------                                           
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 1,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 8
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 1,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 9
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 1,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 10
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 1,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 11
        ----------------------------- quad 123 (SLR 0) -----------------------------                                           
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 1,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 12
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 1,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 13
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 1,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 14
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 1,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 15
        ----------------------------- quad 126 (SLR 1) -----------------------------                                           
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 2,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 16
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 2,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 17
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 2,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 18
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 2,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 19
        ----------------------------- quad 127 (SLR 1) -----------------------------                                           
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 3,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 20
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 3,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 21
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 3,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 22
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 3,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 23
        ----------------------------- quad 128 (SLR 2) -----------------------------                                           
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 4,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 24
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 4,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 25
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 4,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 26
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 4,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 27
        ----------------------------- quad 129 (SLR 2) -----------------------------                                           
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 4,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 28
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 4,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 29
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 4,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 30
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 4,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 31
        ----------------------------- quad 130 (SLR 2) -----------------------------                                           
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 5,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 32
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 5,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 33
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 5,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 34
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 5,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 35
        ----------------------------- quad 131 (SLR 2) -----------------------------                                           
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 5,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 36
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 5,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 37
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 5,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 38
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 5,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 39
        ----------------------------- quad 132 (SLR 3) -----------------------------                                           
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 6,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 40
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 6,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 41
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 6,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 42
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 6,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 43
        ----------------------------- quad 133 (SLR 3) -----------------------------                                           
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 6,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 44
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 6,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 45
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 6,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 46
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 6,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 47
        ----------------------------- quad 134 (SLR 3) -----------------------------                                           
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 6,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 48
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 6,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 49
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 6,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 50
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 6,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 51
        ----------------------------- quad 135 (SLR 3) -----------------------------                                           
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 7,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 52
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 7,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 53
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 7,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 54
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 7,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 55
        ----------------------------- quad 220 (SLR 0) -----------------------------                                           
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 8,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 56
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 8,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 57
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 8,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 58
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 8,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 59
        ----------------------------- quad 221 (SLR 0) -----------------------------                                           
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 8,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 60
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 8,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 61
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 8,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 62
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 8,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 63
        ----------------------------- quad 222 (SLR 0) -----------------------------                                           
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 9,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 64
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 9,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 65
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 9,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 66
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 9,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 67
        ----------------------------- quad 223 (SLR 0) -----------------------------                                           
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 9,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 68
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 9,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 69
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 9,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 70
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 9,  is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 71
        ----------------------------- quad 224 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 10, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 72
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 10, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 73
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 10, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 74
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 10, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 75
        ----------------------------- quad 225 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 10, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 76
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 10, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 77
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 10, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 78
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 10, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 79
        ----------------------------- quad 226 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 80
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 81
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 82
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 83
        ----------------------------- quad 227 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 84
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 85
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 86
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 87
        ----------------------------- quad 228 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 12, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 88
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 12, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 89
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 12, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 90
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 12, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 91
        ----------------------------- quad 229 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 12, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 92
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 12, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 93
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 12, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 94
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 12, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 95
        ----------------------------- quad 230 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 096, refclk0_idx => 24, refclk1_idx => 13, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 96
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 096, refclk0_idx => 24, refclk1_idx => 13, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 97
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 096, refclk0_idx => 24, refclk1_idx => 13, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 98
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 096, refclk0_idx => 24, refclk1_idx => 13, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 99
        ----------------------------- quad 231 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 100, refclk0_idx => 25, refclk1_idx => 13, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 100
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 100, refclk0_idx => 25, refclk1_idx => 13, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 101
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 100, refclk0_idx => 25, refclk1_idx => 13, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 102
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 100, refclk0_idx => 25, refclk1_idx => 13, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 103
        ----------------------------- quad 232 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 104, refclk0_idx => 26, refclk1_idx => 14, is_master => false, chbond_master => 0, ibert_inst => true), -- MGT 104
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 104, refclk0_idx => 26, refclk1_idx => 14, is_master => false, chbond_master => 0, ibert_inst => true), -- MGT 105
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 104, refclk0_idx => 26, refclk1_idx => 14, is_master => false, chbond_master => 0, ibert_inst => true), -- MGT 106
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 104, refclk0_idx => 26, refclk1_idx => 14, is_master => false, chbond_master => 0, ibert_inst => true), -- MGT 107
        ----------------------------- quad 233 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 108, refclk0_idx => 27, refclk1_idx => 14, is_master => false, chbond_master => 0, ibert_inst => true), -- MGT 108
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 108, refclk0_idx => 27, refclk1_idx => 14, is_master => false, chbond_master => 0, ibert_inst => true), -- MGT 109
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 108, refclk0_idx => 27, refclk1_idx => 14, is_master => false, chbond_master => 0, ibert_inst => true), -- MGT 110
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 108, refclk0_idx => 27, refclk1_idx => 14, is_master => false, chbond_master => 0, ibert_inst => true), -- MGT 111
        ----------------------------- quad 234 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 112, refclk0_idx => 28, refclk1_idx => 15, is_master => false, chbond_master => 0, ibert_inst => true), -- MGT 112
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 112, refclk0_idx => 28, refclk1_idx => 15, is_master => false, chbond_master => 0, ibert_inst => true), -- MGT 113
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 112, refclk0_idx => 28, refclk1_idx => 15, is_master => false, chbond_master => 0, ibert_inst => true), -- MGT 114
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 112, refclk0_idx => 28, refclk1_idx => 15, is_master => false, chbond_master => 0, ibert_inst => true), -- MGT 115
        ----------------------------- quad 235 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_10GBE_156  , qpll_idx => 116, refclk0_idx => 29, refclk1_idx => 15, is_master => false, chbond_master => 0, ibert_inst => true), -- MGT 116
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 116, refclk0_idx => 29, refclk1_idx => 15, is_master => false, chbond_master => 0, ibert_inst => true), -- MGT 117
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 116, refclk0_idx => 29, refclk1_idx => 15, is_master => false, chbond_master => 0, ibert_inst => true), -- MGT 118
        (mgt_type => CFG_MGT_10GBE, qpll_inst_type => QPLL_NULL       , qpll_idx => 116, refclk0_idx => 29, refclk1_idx => 15, is_master => false, chbond_master => 0, ibert_inst => true) -- MGT 119
    );

end package project_config;

