library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common_pkg.all;
use work.board_config_package.all;
use work.gem_pkg.all;
use work.mgt_pkg.all;

package project_config is

    constant CFG_NUM_GEM_BLOCKS         : integer := 1; -- total number of GEM blocks to instanciate    
    type t_int_per_gem is array (0 to CFG_NUM_GEM_BLOCKS - 1) of integer;
    type t_bool_per_gem is array (0 to CFG_NUM_GEM_BLOCKS - 1) of boolean;
    type t_oh_trig_link_type_arr is array (0 to CFG_NUM_GEM_BLOCKS - 1) of t_oh_trig_link_type;
    
    constant CFG_GEM_STATION            : t_int_per_gem := (0 => 2);  -- 0 = ME0; 1 = GE1/1; 2 = GE2/1
    constant CFG_OH_VERSION             : t_int_per_gem := (0 => 2);  -- for now this is only relevant to GE2/1 where v2 OH has different elink map, and uses widebus mode
    constant CFG_NUM_OF_OHs             : t_int_per_gem := (0 => 12);  -- total number of OHs to instanciate (remember to adapt the CFG_OH_LINK_CONFIG_ARR accordingly)
    constant CFG_NUM_GBTS_PER_OH        : t_int_per_gem := (0 => 2);  -- number of GBTs per OH
    constant CFG_NUM_VFATS_PER_OH       : t_int_per_gem := (0 => 12); -- number of VFATs per OH
    constant CFG_GBT_WIDEBUS            : t_int_per_gem := (0 => 1);  -- 0 means use standard mode, 1 means use widebus (set to 1 for GE2/1 OH version 2+)

    constant CFG_OH_TRIG_LINK_TYPE      : t_oh_trig_link_type_arr := (0 => OH_TRIG_LINK_TYPE_GBT); -- type of trigger link to use, the 3.2G and 4.0G are applicable to GE11, and GBT type is only applicable to GE21   
    constant CFG_USE_TRIG_TX_LINKS      : t_bool_per_gem := (others => false); -- if true, then trigger transmitters will be instantiated (used to connect to EMTF)
    constant CFG_NUM_TRIG_TX            : t_int_per_gem := (others => 8); -- number of trigger transmitters used to connect to EMTF

    --========================--
    --== Link configuration ==--
    --========================--

    constant CFG_OH_LINK_CONFIG_ARR : t_oh_link_config_arr_arr := (
        0 => ( ------------------------------------------------ SLR0 ------------------------------------------------
                 (((0, 0),   (1, 1),   LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
                 (((2, 2),   (3, 3),   LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
                 
                 (((4,  4),  (5,  5),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
                 (((6,  6),  (7,  7),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
                 
                 (((8,  8),  (9,  9),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
                 (((10, 10), (11, 11), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
                  
                 (((12, 12), (13, 13), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
                 (((14, 14), (15, 15), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 

                 (((16, 16), (17, 17), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
                 (((18, 18), (19, 19), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 

                 (((20, 20), (21, 21), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
                 (((22, 22), (23, 23), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)) 
             )
    );

    constant CFG_TRIG_TX_LINK_CONFIG_ARR : t_trig_tx_link_config_arr_arr := (
        0 => (TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL)
    );
    
    constant CFG_USE_SPY_LINK_TX : t_spy_link_enable_arr := (0 => true);
    constant CFG_USE_SPY_LINK_RX : t_spy_link_enable_arr := (0 => true);
    constant CFG_SPY_LINK : t_spy_link_config := (0 => 28);

    constant CFG_USE_TTC_TX_LINK : boolean := true;
    constant CFG_TTC_LINKS : t_int_array(0 to 3) := (24, 25, 26, 27);   

    constant CFG_USE_TTC_GBTX_LINK  : boolean := true;
    constant CFG_TTC_GBTX_LINK      : integer := 29;   
    

    --================================--
    -- MGT configuration
    --================================--    

    constant CFG_MGT_LINK_CONFIG : t_mgt_config_arr := (
        -------------------- quad 127 --------------------
        (mgt_type => CFG_MGT_GBTX,  qpll_inst_type => QPLL_GBTX,      qpll_idx => 0,  refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,  qpll_inst_type => QPLL_NULL,      qpll_idx => 0,  refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,  qpll_inst_type => QPLL_NULL,      qpll_idx => 0,  refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,  qpll_inst_type => QPLL_NULL,      qpll_idx => 0,  refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false),
        -------------------- quad 128 --------------------            
        (mgt_type => CFG_MGT_GBTX,  qpll_inst_type => QPLL_GBTX,      qpll_idx => 4,  refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,  qpll_inst_type => QPLL_NULL,      qpll_idx => 4,  refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,  qpll_inst_type => QPLL_NULL,      qpll_idx => 4,  refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,  qpll_inst_type => QPLL_NULL,      qpll_idx => 4,  refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false),     
        -------------------- quad 129 --------------------                                                                     
        (mgt_type => CFG_MGT_GBTX,  qpll_inst_type => QPLL_GBTX,      qpll_idx => 8,  refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,  qpll_inst_type => QPLL_NULL,      qpll_idx => 8,  refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,  qpll_inst_type => QPLL_NULL,      qpll_idx => 8,  refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,  qpll_inst_type => QPLL_NULL,      qpll_idx => 8,  refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false),        
        -------------------- quad 130 --------------------            
        (mgt_type => CFG_MGT_GBTX,  qpll_inst_type => QPLL_GBTX,      qpll_idx => 12, refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,  qpll_inst_type => QPLL_NULL,      qpll_idx => 12, refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,  qpll_inst_type => QPLL_NULL,      qpll_idx => 12, refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,  qpll_inst_type => QPLL_NULL,      qpll_idx => 12, refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false),
        -------------------- quad 131 --------------------                                                                                                                
        (mgt_type => CFG_MGT_GBTX,  qpll_inst_type => QPLL_GBTX,      qpll_idx => 16, refclk0_idx => 1, refclk1_idx => 1, is_master => TRUE,  chbond_master => 0, ibert_inst => true),        
        (mgt_type => CFG_MGT_GBTX,  qpll_inst_type => QPLL_NULL,      qpll_idx => 16, refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,  qpll_inst_type => QPLL_NULL,      qpll_idx => 16, refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,  qpll_inst_type => QPLL_NULL,      qpll_idx => 16, refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false),
        -------------------- quad 132 --------------------                                                                                                                
        (mgt_type => CFG_MGT_GBTX,  qpll_inst_type => QPLL_GBTX,      qpll_idx => 20, refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,  qpll_inst_type => QPLL_NULL,      qpll_idx => 20, refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,  qpll_inst_type => QPLL_NULL,      qpll_idx => 20, refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,  qpll_inst_type => QPLL_NULL,      qpll_idx => 20, refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false),
        -------------------- quad 133 --------------------                                                                                                                
        (mgt_type => CFG_MGT_TTC,   qpll_inst_type => QPLL_LPGBT,     qpll_idx => 24, refclk0_idx => 2, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_TTC,   qpll_inst_type => QPLL_NULL,      qpll_idx => 24, refclk0_idx => 2, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_TTC,   qpll_inst_type => QPLL_NULL,      qpll_idx => 24, refclk0_idx => 2, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_TTC,   qpll_inst_type => QPLL_NULL,      qpll_idx => 24, refclk0_idx => 2, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false),
        -------------------- quad 134 --------------------                                                                                                              
        (mgt_type => CFG_MGT_10GBE_QPLL0, qpll_inst_type => QPLL0_10GBE_QPLL1_GBTX, qpll_idx => 28, refclk0_idx => 2, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX, qpll_inst_type => QPLL_NULL,      qpll_idx => 28, refclk0_idx => 2, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_10GBE_QPLL0, qpll_inst_type => QPLL_NULL,      qpll_idx => 28, refclk0_idx => 2, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX, qpll_inst_type => QPLL_NULL,      qpll_idx => 28, refclk0_idx => 2, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false)
    );

end package project_config;

