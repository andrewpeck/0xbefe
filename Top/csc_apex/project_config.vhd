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

    --================================--
    -- Link configuration
    --================================--   

    constant CFG_DMB_CONFIG_ARR : t_dmb_config_arr_per_slr(0 to CFG_NUM_SLRS - 1)(0 to CFG_DAQ_MAX_DMBS - 1) := (
        0 => ------------------------------------------------ SLR0 ------------------------------------------------
        (
            (dmb_type => DMB, num_fibers => 1, tx_fiber => 8, rx_fibers => (8, others => CFG_BOARD_MAX_LINKS)),
            (dmb_type => DMB, num_fibers => 1, tx_fiber => 9, rx_fibers => (9, others => CFG_BOARD_MAX_LINKS)),
            others => DMB_CONFIG_NULL
        )
    );

    constant CFG_USE_SPY_LINK : t_bool_array(0 to CFG_NUM_SLRS - 1) := (0 => true);
    constant CFG_SPY_LINK : t_int_array(0 to CFG_NUM_SLRS -1) := (0 => 11);
    
    constant CFG_TTC_TX_SOURCE_SLR : integer := 0;
    constant CFG_USE_TTC_TX_LINK : boolean := true;
    constant CFG_TTC_LINKS : t_int_array(0 to 3) := (0, 1, 2, 3);   
    
    --================================--
    -- MGT configuration
    --================================--   
    
    constant CFG_MGT_LINK_CONFIG : t_mgt_config_arr := (
        --======================== 127 ========================--
        (mgt_type => CFG_MGT_TTC,    qpll_inst_type => QPLL_LPGBT,       qpll_idx => 0, refclk0_idx => 0, refclk1_idx => 0, is_master => false, ibert_inst => false),        
        (mgt_type => CFG_MGT_TTC,    qpll_inst_type => QPLL_NULL,        qpll_idx => 0, refclk0_idx => 0, refclk1_idx => 0, is_master => false, ibert_inst => false),        
        (mgt_type => CFG_MGT_TTC,    qpll_inst_type => QPLL_NULL,        qpll_idx => 0, refclk0_idx => 0, refclk1_idx => 0, is_master => false, ibert_inst => false),        
        (mgt_type => CFG_MGT_TTC,    qpll_inst_type => QPLL_NULL,        qpll_idx => 0, refclk0_idx => 0, refclk1_idx => 0, is_master => false, ibert_inst => false),        

        --======================== 131 ========================--
        (mgt_type => CFG_MGT_ODMB57, qpll_inst_type => QPLL_ODMB57_156,  qpll_idx => 4, refclk0_idx => 1, refclk1_idx => 1, is_master => true,  ibert_inst => true ),        
        (mgt_type => CFG_MGT_ODMB57, qpll_inst_type => QPLL_NULL,        qpll_idx => 4, refclk0_idx => 1, refclk1_idx => 1, is_master => false, ibert_inst => true ),        
        (mgt_type => CFG_MGT_ODMB57, qpll_inst_type => QPLL_NULL,        qpll_idx => 4, refclk0_idx => 1, refclk1_idx => 1, is_master => false, ibert_inst => true ),        
        (mgt_type => CFG_MGT_ODMB57, qpll_inst_type => QPLL_NULL,        qpll_idx => 4, refclk0_idx => 1, refclk1_idx => 1, is_master => false, ibert_inst => true ),
                        
        --======================== 130 ========================--
        (mgt_type => CFG_MGT_DMB,    qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 8, refclk0_idx => 1, refclk1_idx => 1, is_master => true,  ibert_inst => true ),        
        (mgt_type => CFG_MGT_DMB,    qpll_inst_type => QPLL_NULL,        qpll_idx => 8, refclk0_idx => 1, refclk1_idx => 1, is_master => false, ibert_inst => true ),        
        (mgt_type => CFG_MGT_GBE,    qpll_inst_type => QPLL_NULL,        qpll_idx => 8, refclk0_idx => 1, refclk1_idx => 1, is_master => true,  ibert_inst => true ),        
        (mgt_type => CFG_MGT_GBE,    qpll_inst_type => QPLL_NULL,        qpll_idx => 8, refclk0_idx => 1, refclk1_idx => 1, is_master => false, ibert_inst => true )
    );

end package project_config;

