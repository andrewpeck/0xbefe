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
    
    constant CFG_NUM_DMBS       : t_int_array(0 to CFG_NUM_SLRS - 1) := (0 => 2);
    constant CFG_NUM_GBT_LINKS  : t_int_array(0 to CFG_NUM_SLRS - 1) := (0 => 4);

    --================================--
    -- Link configuration
    --================================--   

    constant CFG_DMB_CONFIG_ARR : t_dmb_config_arr_per_slr(0 to CFG_NUM_SLRS - 1)(0 to CFG_DAQ_MAX_DMBS - 1) := (
        0 => ------------------------------------------------ SLR0 ------------------------------------------------
        (
            (dmb_type => DMB, num_fibers => 1, tx_fiber => 4, rx_fibers => (4, others => CFG_BOARD_MAX_LINKS)),
            (dmb_type => DMB, num_fibers => 1, tx_fiber => 5, rx_fibers => (5, others => CFG_BOARD_MAX_LINKS)),
            others => DMB_CONFIG_NULL
        )
    );

    constant CFG_GBT_LINK_CONFIG_ARR : t_gbt_link_config_arr_per_slr(0 to CFG_NUM_SLRS - 1)(0 to CFG_MAX_GBTS - 1) := (
        0 =>  ------------------------------------------------ SLR0 ------------------------------------------------
        (
            (tx_fiber => 12, rx_fiber => 12),
            (tx_fiber => 13, rx_fiber => 13),
            (tx_fiber => 14, rx_fiber => 14),
            (tx_fiber => 15, rx_fiber => 15),
            others => (tx_fiber => CFG_BOARD_MAX_LINKS, rx_fiber => CFG_BOARD_MAX_LINKS)
        )
    );

    constant CFG_USE_SPY_LINK_TX : t_bool_array(0 to CFG_NUM_SLRS - 1) := (0 => true);
    constant CFG_USE_SPY_LINK_RX : t_bool_array(0 to CFG_NUM_SLRS - 1) := (0 => true);
    constant CFG_SPY_LINK : t_int_array(0 to CFG_NUM_SLRS -1) := (0 => 7);
    
    constant CFG_TTC_TX_SOURCE_SLR : integer := 0;
    constant CFG_USE_TTC_TX_LINK : boolean := true;
    constant CFG_TTC_LINKS : t_int_array(0 to 3) := (8, 9, 10, 11);   
    
    --================================--
    -- MGT configuration
    --================================--   
    
    constant CFG_MGT_LINK_CONFIG : t_mgt_config_arr := (
        --======================== 129 ========================--
        (mgt_type => CFG_MGT_ODMB57, qpll_inst_type => QPLL_ODMB57_156,  qpll_idx => 0,  refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_ODMB57, qpll_inst_type => QPLL_NULL,        qpll_idx => 0,  refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_ODMB57, qpll_inst_type => QPLL_NULL,        qpll_idx => 0,  refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_ODMB57, qpll_inst_type => QPLL_NULL,        qpll_idx => 0,  refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false),

        --======================== 130 ========================-- 
        (mgt_type => CFG_MGT_DMB,    qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 4,  refclk0_idx => 1, refclk1_idx => 1, is_master => true,  chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_DMB,    qpll_inst_type => QPLL_NULL,        qpll_idx => 4,  refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBE,    qpll_inst_type => QPLL_NULL,        qpll_idx => 4,  refclk0_idx => 1, refclk1_idx => 1, is_master => true,  chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBE,    qpll_inst_type => QPLL_NULL,        qpll_idx => 4,  refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false),
 
        --======================== 131 ========================-- 
        (mgt_type => CFG_MGT_TTC,    qpll_inst_type => QPLL_LPGBT,       qpll_idx => 8,  refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => true ),        
        (mgt_type => CFG_MGT_TTC,    qpll_inst_type => QPLL_NULL,        qpll_idx => 8,  refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => true ),        
        (mgt_type => CFG_MGT_TTC,    qpll_inst_type => QPLL_NULL,        qpll_idx => 8,  refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => true ),        
        (mgt_type => CFG_MGT_TTC,    qpll_inst_type => QPLL_NULL,        qpll_idx => 8,  refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => true ),        
 
        --======================== 132 ========================-- 
        (mgt_type => CFG_MGT_GBTX,    qpll_inst_type => QPLL_GBTX,       qpll_idx => 12, refclk0_idx => 1, refclk1_idx => 1, is_master => TRUE , chbond_master => 0, ibert_inst => true ),        
        (mgt_type => CFG_MGT_GBTX,    qpll_inst_type => QPLL_NULL,       qpll_idx => 12, refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => true ),        
        (mgt_type => CFG_MGT_GBTX,    qpll_inst_type => QPLL_NULL,       qpll_idx => 12, refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => true ),        
        (mgt_type => CFG_MGT_GBTX,    qpll_inst_type => QPLL_NULL,       qpll_idx => 12, refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => true )        
    );

end package project_config;

