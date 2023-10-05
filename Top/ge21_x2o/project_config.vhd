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
    constant CFG_NUM_OF_OHs             : t_int_per_gem := (others => 2); -- total number of OHs to instanciate (remember to adapt the CFG_OH_LINK_CONFIG_ARR accordingly)
    constant CFG_NUM_GBTS_PER_OH        : t_int_per_gem := (others => 2);  -- number of GBTs per OH
    constant CFG_NUM_VFATS_PER_OH       : t_int_per_gem := (others => 12); -- number of VFATs per OH
    constant CFG_GBT_WIDEBUS            : t_int_per_gem := (others => 1);  -- 0 means use standard mode, 1 means use widebus (set to 1 for GE2/1 OH version 2+)

    constant CFG_OH_TRIG_LINK_TYPE      : t_oh_trig_link_type_arr := (others => OH_TRIG_LINK_TYPE_GBT); -- type of trigger link to use, the 3.2G and 4.0G are applicable to GE11, and GBT type is only applicable to GE21
    constant CFG_USE_TRIG_TX_LINKS      : boolean := false; -- if true, then trigger transmitters will be instantiated (used to connect to EMTF)
    constant CFG_NUM_TRIG_TX            : integer := 8; -- number of trigger transmitters used to connect to EMTF

    --========================--
    --== Link configuration ==--
    --========================--

    constant CFG_USE_SPY_LINK_TX : t_spy_link_enable_arr := (others => false);
    constant CFG_USE_SPY_LINK_RX : t_spy_link_enable_arr := (others => false);
    constant CFG_SPY_LINK : t_spy_link_config := (0 => 8, others => TXRX_NULL);

    constant CFG_USE_TTC_TX_LINK : boolean := true;
    constant CFG_TTC_LINKS : t_int_array(0 to 3) := (4, 5, 6, 7);   

    constant CFG_USE_TTC_GBTX_LINK  : boolean := false;
    constant CFG_TTC_GBTX_LINK      : integer := 4;   

    constant CFG_TRIG_TX_LINK_CONFIG_ARR : t_trig_tx_link_config_arr_arr := (others => (others => TXRX_NULL));

    constant CFG_OH_LINK_CONFIG_ARR : t_oh_link_config_arr_arr := (
        0 =>
        ( ------------------------------------------------ SLR0 ------------------------------------------------
            (((0, 0), (1, 1), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), -- OH0, SLR 0
            (((2, 2), (3, 3), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), -- OH1, SLR 0
            (((4, 4), (5, 5), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), -- OH2, SLR 0
            (((6, 6), (7, 7), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), -- OH3, SLR 0
            others => ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))
        ),
        others => (others => ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)))
    );

    --================================--
    -- MGT configuration
    --================================--    

    constant CFG_MGT_LINK_CONFIG : t_mgt_config_arr := (
        ----------------------------- quad 224 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 0, refclk0_idx => 18, refclk1_idx => 10, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 72
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 0, refclk0_idx => 18, refclk1_idx => 10, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 73
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 0, refclk0_idx => 18, refclk1_idx => 10, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 74
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 0, refclk0_idx => 18, refclk1_idx => 10, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 75
        ----------------------------- quad 225 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 4, refclk0_idx => 19, refclk1_idx => 10, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 76
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 4, refclk0_idx => 19, refclk1_idx => 10, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 77
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 4, refclk0_idx => 19, refclk1_idx => 10, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 78
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL       , qpll_idx => 4, refclk0_idx => 19, refclk1_idx => 10, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 79
        ----------------------------- quad 226 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_TTC, qpll_inst_type => QPLL_LPGBT      , qpll_idx => 8, refclk0_idx => 20, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 80
        (mgt_type => CFG_MGT_TTC, qpll_inst_type => QPLL_NULL       , qpll_idx => 8, refclk0_idx => 20, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 81
        (mgt_type => CFG_MGT_TTC, qpll_inst_type => QPLL_NULL       , qpll_idx => 8, refclk0_idx => 20, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 82
        (mgt_type => CFG_MGT_TTC, qpll_inst_type => QPLL_NULL       , qpll_idx => 8, refclk0_idx => 20, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 83
        ----------------------------- quad 227 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_GBTX, qpll_inst_type => QPLL_GBTX       , qpll_idx => 12, refclk0_idx => 21, refclk1_idx => 11, is_master => true, chbond_master => 0, ibert_inst => false), -- MGT 84
        (mgt_type => CFG_MGT_GBTX, qpll_inst_type => QPLL_NULL       , qpll_idx => 12, refclk0_idx => 21, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 85
        (mgt_type => CFG_MGT_GBTX, qpll_inst_type => QPLL_NULL       , qpll_idx => 12, refclk0_idx => 21, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 86
        (mgt_type => CFG_MGT_GBTX, qpll_inst_type => QPLL_NULL       , qpll_idx => 12, refclk0_idx => 21, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false) -- MGT 87
    );

end package project_config;

