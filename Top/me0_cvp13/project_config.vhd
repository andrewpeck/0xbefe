library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.board_config_package.all;
use work.gem_pkg.all;
use work.mgt_pkg.all;

package project_config is

    constant CFG_NUM_GEM_BLOCKS         : integer := 1; -- total number of GEM blocks to instanciate    
    type t_int_per_gem is array (0 to CFG_NUM_GEM_BLOCKS - 1) of integer;
    type t_oh_trig_link_type_arr is array (0 to CFG_NUM_GEM_BLOCKS - 1) of t_oh_trig_link_type;
    
    constant CFG_GEM_STATION            : t_int_per_gem := (0 => 0);  -- 0 = ME0; 1 = GE1/1; 2 = GE2/1
    constant CFG_OH_VERSION             : t_int_per_gem := (0 => 1);  -- for now this is only relevant to GE2/1 where v2 OH has different elink map, and uses widebus mode
    constant CFG_NUM_OF_OHs             : t_int_per_gem := (0 => 3);  -- total number of OHs to instanciate (remember to adapt the CFG_OH_LINK_CONFIG_ARR accordingly)
    constant CFG_NUM_GBTS_PER_OH        : t_int_per_gem := (0 => 8);  -- number of GBTs per OH
    constant CFG_NUM_VFATS_PER_OH       : t_int_per_gem := (0 => 24); -- number of VFATs per OH
    constant CFG_GBT_WIDEBUS            : t_int_per_gem := (0 => 0);  -- 0 means use standard mode, 1 means use widebus (set to 1 for GE2/1 OH version 2+) 

    constant CFG_OH_TRIG_LINK_TYPE      : t_oh_trig_link_type_arr := (0 => OH_TRIG_LINK_TYPE_NONE); -- type of trigger link to use, the 3.2G and 4.0G are applicable to GE11, and GBT type is only applicable to GE21   
    constant CFG_USE_TRIG_TX_LINKS      : boolean := false; -- if true, then trigger transmitters will be instantiated (used to connect to EMTF)
    constant CFG_NUM_TRIG_TX            : integer := 8; -- number of trigger transmitters used to connect to EMTF

    --========================--
    --== Link configuration ==--
    --========================--

    -- this configuration supports 1 full layer + two half layers (narrow only)
    -- the fiber connections are as follows:
    -- layer 0 narrow: TX on QSFP0 channels 0&1 | RX on QSFP0 channels 0-3
    -- layer 0 wide:   TX on QSFP0 channels 2&3 | RX on QSFP1 channels 0-3
    -- layer 1 narrow: TX on QSFP1 channels 0&1 | RX on QSFP2 channels 0-3
    -- layer 2 narrow: TX on QSFP2 channels 0&1 | RX on QSFP3 channels 0-3
    -- LDAQ:           TX on QSFP3 channel 0

    constant CFG_OH_LINK_CONFIG_ARR : t_oh_link_config_arr_arr := (
        ( ------------------------------------------------ SLR0 ------------------------------------------------
            (((0, 0),  (TXRX_NULL, 1),  (1, 2),   (TXRX_NULL, 3),  (2, 4),   (TXRX_NULL, 5),  (3, 6),   (TXRX_NULL, 7)),  (LINK_NULL, LINK_NULL)),
            (((8, 8),  (TXRX_NULL, 9),  (9, 10),  (TXRX_NULL, 11), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL),  (LINK_NULL, LINK_NULL)),
            (((10, 12), (TXRX_NULL, 13), (11, 14),  (TXRX_NULL, 15), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL),  (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))         
        ),
        ( ------------------------------------------------ SLR1 ------------------------------------------------
--            (((8, 8), (TXRX_NULL, 9), (9, 10), (TXRX_NULL, 11), (10, 12), (TXRX_NULL, 13), (11, 14), (TXRX_NULL, 15)), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))         
        ),
        ( ------------------------------------------------ SLR2 ------------------------------------------------
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))         
        ),
        ( ------------------------------------------------ SLR3 ------------------------------------------------
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))         
        )
    );

    constant CFG_TRIG_TX_LINK_CONFIG_ARR : t_trig_tx_link_config_arr_arr := (
        (TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL),
        (TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL),
        (TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL),
        (TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL)
    );
    
    constant CFG_USE_SPY_LINK_TX : t_spy_link_enable_arr := (true, true, true, true);
    constant CFG_USE_SPY_LINK_RX : t_spy_link_enable_arr := (false, false, false, false);
    constant CFG_SPY_LINK : t_spy_link_config := (12, 13, 14, 15);

    --================================--
    -- MGT configuration
    --================================--    

    constant CFG_MGT_LINK_CONFIG : t_mgt_config_arr := (
        (mgt_type => CFG_MGT_LPGBT,             qpll_inst_type => QPLL_LPGBT,              qpll_idx => 0,  refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_LPGBT,             qpll_inst_type => QPLL_NULL,               qpll_idx => 0,  refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_LPGBT,             qpll_inst_type => QPLL_NULL,               qpll_idx => 0,  refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_LPGBT,             qpll_inst_type => QPLL_NULL,               qpll_idx => 0,  refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false),        
                                                                                                                                               
        (mgt_type => CFG_MGT_LPGBT,             qpll_inst_type => QPLL_LPGBT,              qpll_idx => 4,  refclk0_idx => 1, refclk1_idx => 1, is_master => TRUE,  chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_LPGBT,             qpll_inst_type => QPLL_NULL,               qpll_idx => 4,  refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_LPGBT,             qpll_inst_type => QPLL_NULL,               qpll_idx => 4,  refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_LPGBT,             qpll_inst_type => QPLL_NULL,               qpll_idx => 4,  refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false),
                                                                                                                                               
        (mgt_type => CFG_MGT_LPGBT,             qpll_inst_type => QPLL_LPGBT,              qpll_idx => 8,  refclk0_idx => 2, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_LPGBT,             qpll_inst_type => QPLL_NULL,               qpll_idx => 8,  refclk0_idx => 2, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_LPGBT,             qpll_inst_type => QPLL_NULL,               qpll_idx => 8,  refclk0_idx => 2, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_LPGBT,             qpll_inst_type => QPLL_NULL,               qpll_idx => 8,  refclk0_idx => 2, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false),        

        (mgt_type => CFG_MGT_TX_10GBE_RX_LPGBT, qpll_inst_type => QPLL0_LPGBT_QPLL1_10GBE, qpll_idx => 12, refclk0_idx => 3, refclk1_idx => 3, is_master => TRUE,  chbond_master => 0, ibert_inst => false),
        (mgt_type => CFG_MGT_TX_10GBE_RX_LPGBT, qpll_inst_type => QPLL_NULL,               qpll_idx => 12, refclk0_idx => 3, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false),
        (mgt_type => CFG_MGT_TX_10GBE_RX_LPGBT, qpll_inst_type => QPLL_NULL,               qpll_idx => 12, refclk0_idx => 3, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false),
        (mgt_type => CFG_MGT_TX_10GBE_RX_LPGBT, qpll_inst_type => QPLL_NULL,               qpll_idx => 12, refclk0_idx => 3, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false)
    );

end package project_config;

