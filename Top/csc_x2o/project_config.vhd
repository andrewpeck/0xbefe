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

--    constant CFG_NUM_SLRS       : integer := 4;    -- number of full CSC blocks to instantiate (typically one per SLR)
    constant CFG_NUM_SLRS       : integer := 1;    -- number of full CSC blocks to instantiate (typically one per SLR)

    --================================--
    -- CSC configuration
    --================================--   
    
--    constant CFG_NUM_DMBS       : t_int_array(0 to CFG_NUM_SLRS - 1) := (others => 14);
    constant CFG_NUM_DMBS       : t_int_array(0 to CFG_NUM_SLRS - 1) := (others => 2);
    constant CFG_NUM_GBT_LINKS  : t_int_array(0 to CFG_NUM_SLRS - 1) := (others => 4);

    --================================--
    -- Link configuration
    --================================--   

--    constant CFG_DMB_CONFIG_ARR : t_dmb_config_arr_per_slr(0 to CFG_NUM_SLRS - 1)(0 to CFG_DAQ_MAX_DMBS - 1) := (
--        ( ------------------------------------------------ SLR0 ------------------------------------------------
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (0, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB0, SLR 0
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (1, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB1, SLR 0
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (2, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB2, SLR 0
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (3, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB3, SLR 0
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (4, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB4, SLR 0
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (5, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB5, SLR 0
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (6, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB6, SLR 0
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (7, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB7, SLR 0
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (8, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB8, SLR 0
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (9, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB9, SLR 0
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (10, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB10, SLR 0
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (11, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB11, SLR 0
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (12, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB12, SLR 0
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (13, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS))  -- DMB13, SLR 0
--        ),
--        (
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (32, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB14, SLR 1
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (33, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB15, SLR 1
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (34, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB16, SLR 1
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (35, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB17, SLR 1
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (36, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB18, SLR 1
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (37, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB19, SLR 1
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (38, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB20, SLR 1
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (39, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB21, SLR 1
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (40, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB22, SLR 1
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (41, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB23, SLR 1
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (42, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB24, SLR 1
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (43, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB25, SLR 1
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (44, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB26, SLR 1
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (45, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS))  -- DMB27, SLR 1            
--        ),
--        (
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (56, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB28, SLR 2
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (57, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB29, SLR 2
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (58, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB30, SLR 2
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (59, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB31, SLR 2
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (60, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB32, SLR 2
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (61, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB33, SLR 2
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (62, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB34, SLR 2
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (63, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB35, SLR 2
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (64, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB36, SLR 2
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (65, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB37, SLR 2
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (66, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB38, SLR 2
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (67, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB39, SLR 2
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (68, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB40, SLR 2
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (69, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS))  -- DMB41, SLR 2            
--        ),
--        (
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (84, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB42, SLR 3
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (85, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB43, SLR 3
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (86, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB44, SLR 3
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (87, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB45, SLR 3
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (88, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB46, SLR 3
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (89, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB47, SLR 3
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (90, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB48, SLR 3
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (91, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB49, SLR 3
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (92, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB50, SLR 3
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (93, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB51, SLR 3
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (94, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB52, SLR 3
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (95, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB53, SLR 3
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (96, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB54, SLR 3
--            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (97, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)) -- DMB55, SLR 3            
--        )
--    );

    constant CFG_DMB_CONFIG_ARR : t_dmb_config_arr_per_slr(0 to CFG_NUM_SLRS - 1)(0 to CFG_DAQ_MAX_DMBS - 1) := (
        0 =>
        ( ------------------------------------------------ SLR0 ------------------------------------------------
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (0, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB0, SLR 0
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (1, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB1, SLR 0
            others => DMB_CONFIG_NULL
        )
    );

    constant CFG_GBT_LINK_CONFIG_ARR : t_gbt_link_config_arr_per_slr(0 to CFG_NUM_SLRS - 1)(0 to CFG_MAX_GBTS - 1) := (
        0 =>  ------------------------------------------------ SLR0 ------------------------------------------------
        (
            (tx_fiber => 16, rx_fiber => 16),
            (tx_fiber => 17, rx_fiber => 17),
            (tx_fiber => 18, rx_fiber => 18),
            (tx_fiber => 19, rx_fiber => 19),
            others => (tx_fiber => CFG_BOARD_MAX_LINKS, rx_fiber => CFG_BOARD_MAX_LINKS)
        )
    );
    
    constant CFG_USE_SPY_LINK : t_bool_array(0 to CFG_NUM_SLRS - 1) := (others => true);
--    constant CFG_SPY_LINK : t_int_array(0 to CFG_NUM_SLRS -1) := (16, 48, 72, 108);
    constant CFG_SPY_LINK : t_int_array(0 to CFG_NUM_SLRS -1) := (0 => 3);
    
    constant CFG_TTC_TX_SOURCE_SLR : integer := 0;
    constant CFG_USE_TTC_TX_LINK : boolean := false;
    constant CFG_TTC_LINKS : t_int_array(0 to 3) := (24, 25, 26, 27);
    
    --================================--
    -- MGT configuration
    --================================--   
    
    constant CFG_MGT_LINK_CONFIG : t_mgt_config_arr := (
        ----------------------------- quad 120 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => TRUE ), -- DMB0
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 121 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 122 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 123 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_GBE      , qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => TRUE , ibert_inst => TRUE ), -- GBE link
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => TRUE ), -- DMB1
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 124 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 1, is_master => false, ibert_inst => false),
        ----------------------------- quad 125 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 1, is_master => false, ibert_inst => false),
        ----------------------------- quad 128 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 2, is_master => false, ibert_inst => false),
        ----------------------------- quad 129 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 2, is_master => false, ibert_inst => false),
        ----------------------------- quad 130 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 2, is_master => false, ibert_inst => false),
        ----------------------------- quad 131 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 2, is_master => false, ibert_inst => false),
        ----------------------------- quad 132 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 3, is_master => false, ibert_inst => false),
        ----------------------------- quad 133 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 3, is_master => false, ibert_inst => false),
        ----------------------------- quad 134 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 3, is_master => false, ibert_inst => false),
        ----------------------------- quad 135 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 3, is_master => false, ibert_inst => false),
        ----------------------------- quad 220 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX       , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 4, is_master => TRUE , ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL       , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL       , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 4, is_master => false, ibert_inst => false), -- GBTX TX ch1
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL       , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 4, is_master => false, ibert_inst => false),
        ----------------------------- quad 221 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX       , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 4, is_master => false, ibert_inst => false), -- GBTX TX ch3
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL       , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL       , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL       , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 4, is_master => false, ibert_inst => false),
        ----------------------------- quad 222 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX       , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL       , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL       , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL       , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 4, is_master => false, ibert_inst => false),
        ----------------------------- quad 223 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX       , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 4, is_master => false, ibert_inst => false), -- GBTX TX ch2
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL       , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL       , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 4, is_master => false, ibert_inst => false), -- GBTX TX ch0
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL       , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 4, is_master => false, ibert_inst => false),
        ----------------------------- quad 224 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBE      , qpll_inst_type => QPLL_NULL       , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 5, is_master => false, ibert_inst => false),
        ----------------------------- quad 225 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 5, is_master => TRUE , ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 5, is_master => false, ibert_inst => false),
        ----------------------------- quad 226 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 5, is_master => false, ibert_inst => false),
        ----------------------------- quad 227 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, ibert_inst => false),
        ----------------------------- quad 228 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 6, is_master => false, ibert_inst => false),
        ----------------------------- quad 229 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 6, is_master => false, ibert_inst => false),
        ----------------------------- quad 231 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_GBE      , qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 096, refclk0_idx => 25, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBE      , qpll_inst_type => QPLL_NULL       , qpll_idx => 096, refclk0_idx => 25, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBE      , qpll_inst_type => QPLL_NULL       , qpll_idx => 096, refclk0_idx => 25, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBE      , qpll_inst_type => QPLL_NULL       , qpll_idx => 096, refclk0_idx => 25, refclk1_idx => 6, is_master => false, ibert_inst => false),
        ----------------------------- quad 232 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_GBE      , qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 100, refclk0_idx => 26, refclk1_idx => 7, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBE      , qpll_inst_type => QPLL_NULL       , qpll_idx => 100, refclk0_idx => 26, refclk1_idx => 7, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBE      , qpll_inst_type => QPLL_NULL       , qpll_idx => 100, refclk0_idx => 26, refclk1_idx => 7, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBE      , qpll_inst_type => QPLL_NULL       , qpll_idx => 100, refclk0_idx => 26, refclk1_idx => 7, is_master => false, ibert_inst => false),
        ----------------------------- quad 233 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 104, refclk0_idx => 27, refclk1_idx => 7, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 104, refclk0_idx => 27, refclk1_idx => 7, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 104, refclk0_idx => 27, refclk1_idx => 7, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL       , qpll_idx => 104, refclk0_idx => 27, refclk1_idx => 7, is_master => false, ibert_inst => false),
        ----------------------------- quad 234 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_ODMB57_156 , qpll_idx => 108, refclk0_idx => 28, refclk1_idx => 7, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL       , qpll_idx => 108, refclk0_idx => 28, refclk1_idx => 7, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL       , qpll_idx => 108, refclk0_idx => 28, refclk1_idx => 7, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL       , qpll_idx => 108, refclk0_idx => 28, refclk1_idx => 7, is_master => false, ibert_inst => false),
        ----------------------------- quad 235 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_ODMB57_156 , qpll_idx => 112, refclk0_idx => 29, refclk1_idx => 7, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL       , qpll_idx => 112, refclk0_idx => 29, refclk1_idx => 7, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL       , qpll_idx => 112, refclk0_idx => 29, refclk1_idx => 7, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL       , qpll_idx => 112, refclk0_idx => 29, refclk1_idx => 7, is_master => false, ibert_inst => false)
    );

end package project_config;

