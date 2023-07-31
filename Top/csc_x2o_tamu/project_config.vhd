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

    constant CFG_NUM_DMBS          : t_int_array(0 to CFG_NUM_SLRS - 1) := (others => 4);
    constant CFG_NUM_GBT_LINKS     : t_int_array(0 to CFG_NUM_SLRS - 1) := (others => 1);
    constant CFG_USE_SPY_LINK      : t_bool_array(0 to CFG_NUM_SLRS - 1) := (others => true);
    constant CFG_USE_TTC_TX_LINK   : boolean := true;
    constant CFG_TTC_TX_SOURCE_SLR : integer := 0;
    constant CFG_USE_TTC_GBTX_LINK  : boolean := false;
    constant CFG_TTC_GBTX_LINK      : integer := CFG_BOARD_MAX_LINKS;
    
    --================================--
    -- Link configuration               
    --================================--

    constant CFG_SPY_LINK : t_int_array(0 to CFG_NUM_SLRS -1) := (0 => 5);

    constant CFG_TTC_LINKS : t_int_array(0 to 3) := (10, 11, 12, 13);

    constant CFG_DMB_CONFIG_ARR : t_dmb_config_arr_per_slr(0 to CFG_NUM_SLRS - 1)(0 to CFG_DAQ_MAX_DMBS - 1) := (
        0 =>
        ( ------------------------------------------------ SLR0 ------------------------------------------------
        (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (0, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB0, SLR 0
        (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (1, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB1, SLR 0
        (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (2, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB2, SLR 0
        (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (3, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB3, SLR 0
            others => DMB_CONFIG_NULL
        )
    );

    constant CFG_GBT_LINK_CONFIG_ARR : t_gbt_link_config_arr_per_slr(0 to CFG_NUM_SLRS - 1)(0 to CFG_MAX_GBTS - 1) := (
        0 =>
        ( ------------------------------------------------ SLR0 ------------------------------------------------
            (tx_fiber => 8, rx_fiber => 11), -- GBT0, SLR 0        
            others => (tx_fiber => CFG_BOARD_MAX_LINKS, rx_fiber => CFG_BOARD_MAX_LINKS)
        )
    );

    constant CFG_ODMB57_BIDIR_TEST : boolean := false;
    constant CFG_ODMB7_BIDIR_TX_LINK : t_int_array(0 to 3) := (others => CFG_BOARD_MAX_LINKS);
    constant CFG_ODMB7_BIDIR_RX_LINK : t_int_array(0 to 3) := (others => CFG_BOARD_MAX_LINKS);
    
    --================================--
    -- MGT configuration
    --================================--   
    
    constant CFG_MGT_LINK_CONFIG : t_mgt_config_arr := (
        ----------------------------- quad 130 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_DMB,  qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 0,  refclk0_idx => 08, refclk1_idx => 2, is_master => true , chbond_master => 0, ibert_inst => false), -- MGT 32 | 0
        (mgt_type => CFG_MGT_DMB,  qpll_inst_type => QPLL_NULL       , qpll_idx => 0,  refclk0_idx => 08, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 33 | 1
        (mgt_type => CFG_MGT_GBE,  qpll_inst_type => QPLL_NULL       , qpll_idx => 0,  refclk0_idx => 08, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 34 | 2
        (mgt_type => CFG_MGT_DMB,  qpll_inst_type => QPLL_NULL       , qpll_idx => 0,  refclk0_idx => 08, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 35 | 3
        ----------------------------- quad 131 (SLR 2) -----------------------------  
        (mgt_type => CFG_MGT_DMB,  qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 4,  refclk0_idx => 08, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 36 | 4
        (mgt_type => CFG_MGT_DMB,  qpll_inst_type => QPLL_NULL       , qpll_idx => 4,  refclk0_idx => 08, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 37 | 5
        (mgt_type => CFG_MGT_DMB,  qpll_inst_type => QPLL_NULL       , qpll_idx => 4,  refclk0_idx => 08, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 38 | 6
        (mgt_type => CFG_MGT_DMB,  qpll_inst_type => QPLL_NULL       , qpll_idx => 4,  refclk0_idx => 08, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => true ), -- MGT 39 | 7
        ----------------------------- quad 128 (SLR 2) -----------------------------  
        (mgt_type => CFG_MGT_GBTX, qpll_inst_type => QPLL_GBTX       , qpll_idx => 8,  refclk0_idx => 08, refclk1_idx => 2, is_master => true,  chbond_master => 0, ibert_inst => false), -- MGT xx | 8
        (mgt_type => CFG_MGT_GBTX, qpll_inst_type => QPLL_NULL       , qpll_idx => 8,  refclk0_idx => 08, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT xx | 9
        (mgt_type => CFG_MGT_GBTX, qpll_inst_type => QPLL_NULL       , qpll_idx => 8,  refclk0_idx => 08, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT xx | 10
        (mgt_type => CFG_MGT_GBTX, qpll_inst_type => QPLL_NULL       , qpll_idx => 8,  refclk0_idx => 08, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT xx | 11
        ----------------------------- quad 129 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_TTC,  qpll_inst_type => QPLL_LPGBT      , qpll_idx => 12, refclk0_idx => 08, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT xx | 12
        (mgt_type => CFG_MGT_TTC,  qpll_inst_type => QPLL_NULL       , qpll_idx => 12, refclk0_idx => 08, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT xx | 13
        (mgt_type => CFG_MGT_TTC,  qpll_inst_type => QPLL_NULL       , qpll_idx => 12, refclk0_idx => 08, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT xx | 14
        (mgt_type => CFG_MGT_TTC,  qpll_inst_type => QPLL_NULL       , qpll_idx => 12, refclk0_idx => 08, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false)  -- MGT xx | 15
    );


-- for ODMB7 bidir test:
--        ----------------------------- quad 227 (SLR 1) -----------------------------
--        (mgt_type => CFG_MGT_ODMB57_BIDIR, qpll_inst_type => QPLL_ODMB57_156 , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, chbond_master => 85, ibert_inst => true), -- MGT 84
--        (mgt_type => CFG_MGT_ODMB57_BIDIR, qpll_inst_type => QPLL_NULL       , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => true , chbond_master => 85, ibert_inst => true), -- MGT 85
--        (mgt_type => CFG_MGT_ODMB57_BIDIR, qpll_inst_type => QPLL_NULL       , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, chbond_master => 85, ibert_inst => true), -- MGT 86
--        (mgt_type => CFG_MGT_ODMB57_BIDIR, qpll_inst_type => QPLL_NULL       , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, chbond_master => 85, ibert_inst => true), -- MGT 87
 

end package project_config;

