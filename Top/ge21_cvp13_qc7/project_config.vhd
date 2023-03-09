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
    
    constant CFG_GEM_STATION            : t_int_per_gem := (others => 2);  -- 0 = ME0; 1 = GE1/1; 2 = GE2/1
    constant CFG_OH_VERSION             : t_int_per_gem := (others => 2);  -- for now this is only relevant to GE2/1 where v2 OH has different elink map, and uses widebus mode
    constant CFG_NUM_OF_OHs             : t_int_per_gem := (others => 8);  -- total number of OHs to instanciate (remember to adapt the CFG_OH_LINK_CONFIG_ARR accordingly)
    constant CFG_NUM_GBTS_PER_OH        : t_int_per_gem := (others => 2);  -- number of GBTs per OH
    constant CFG_NUM_VFATS_PER_OH       : t_int_per_gem := (others => 12); -- number of VFATs per OH
    constant CFG_GBT_WIDEBUS            : t_int_per_gem := (others => 1);  -- 0 means use standard mode, 1 means use widebus (set to 1 for GE2/1 OH version 2+)

    constant CFG_OH_TRIG_LINK_TYPE      : t_oh_trig_link_type_arr := (0 => OH_TRIG_LINK_TYPE_GBT); -- type of trigger link to use, the 3.2G and 4.0G are applicable to GE11, and GBT type is only applicable to GE21   
    constant CFG_USE_TRIG_TX_LINKS      : boolean := false; -- if true, then trigger transmitters will be instantiated (used to connect to EMTF)
    constant CFG_NUM_TRIG_TX            : integer := 8; -- number of trigger transmitters used to connect to EMTF

    --========================--
    --== Link configuration ==--
    --========================--

    -- 8 OH per SLR (no trig links)
    constant CFG_OH_LINK_CONFIG_ARR : t_oh_link_config_arr_arr := (
        ( ------------------------------------------------ SLR0 ------------------------------------------------
            0 => (((0,  0),  (1,  1),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
            1 => (((2,  2),  (3,  3),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            2 => (((4,  4),  (5,  5),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
            3 => (((6,  6),  (7,  7),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            4 => (((8,  8),  (9,  9),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
            5 => (((10, 10), (11, 11), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
            6 => (((12, 12), (13, 13), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
            7 => (((14, 14), (15, 15), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            others => ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))
        ),
        ( ------------------------------------------------ SLR1 ------------------------------------------------
            others => ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)) 
        ),
        ( ------------------------------------------------ SLR2 ------------------------------------------------
            others => ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))
        ),
        ( ------------------------------------------------ SLR3 ------------------------------------------------
            others => ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))
        )        
    );

--    -- 4 OH per SLR (trig links on OHs 0 and 1)
--    constant CFG_OH_LINK_CONFIG_ARR : t_oh_link_config_arr_arr := (
--        ( ------------------------------------------------ SLR0 ------------------------------------------------
--            0 => (((0,  0),  (1,  1),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((TXRX_NULL, 8),  (TXRX_NULL, 9 ))), 
--            1 => (((2,  2),  (3,  3),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((TXRX_NULL, 10), (TXRX_NULL, 11))),
--            2 => (((4,  4),  (5,  5),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL,        LINK_NULL)), 
--            3 => (((6,  6),  (7,  7),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL,        LINK_NULL)),
--            others => ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))
--        ),
--        ( ------------------------------------------------ SLR1 ------------------------------------------------
--            0 => (((8,  8),  (9,  9),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
--            1 => (((10, 10), (11, 11), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
--            2 => (((12, 12), (13, 13), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
--            3 => (((14, 14), (15, 15), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
--            others => ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)) 
--        ),
--        ( ------------------------------------------------ SLR2 ------------------------------------------------
--            others => ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))
--        ),
--        ( ------------------------------------------------ SLR3 ------------------------------------------------
--            others => ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))
--        )        
--    );

--    -- 2 OH per SLR (no trig links)
--    constant CFG_OH_LINK_CONFIG_ARR : t_oh_link_config_arr_arr := (
--        ( ------------------------------------------------ SLR0 ------------------------------------------------
--            0 => (((0,  0),  (1,  1),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
--            1 => (((2,  2),  (3,  3),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
--            others => ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))             
--        ),
--        ( ------------------------------------------------ SLR1 ------------------------------------------------
--            0 => (((4,  4),  (5,  5),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
--            1 => (((6,  6),  (7,  7),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
--            others => ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))    
--        ),
--        ( ------------------------------------------------ SLR2 ------------------------------------------------
--            0 => (((8,  8),  (9,  9),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
--            1 => (((10, 10), (11, 11), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
--            others => ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))   
--        ),
--        ( ------------------------------------------------ SLR3 ------------------------------------------------
--            0 => (((12, 12), (13, 13), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
--            1 => (((14, 14), (15, 15), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)), 
--            others => ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))   
--        )        
--    );
    
    constant CFG_TRIG_TX_LINK_CONFIG_ARR : t_trig_tx_link_config_arr_arr := (
        others => (TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL, TXRX_NULL)
    );
    
    constant CFG_USE_SPY_LINK_TX : t_spy_link_enable_arr := (others => false);
    constant CFG_USE_SPY_LINK_RX : t_spy_link_enable_arr := (others => false);
    constant CFG_SPY_LINK : t_spy_link_config := (others => 0);

    --================================--
    -- MGT configuration
    --================================--    

    constant CFG_MGT_LINK_CONFIG : t_mgt_config_arr := (
        (mgt_type => CFG_MGT_GBTX,     qpll_inst_type => QPLL_GBTX,    qpll_idx => 0,  refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,     qpll_inst_type => QPLL_NULL,    qpll_idx => 0,  refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,     qpll_inst_type => QPLL_NULL,    qpll_idx => 0,  refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,     qpll_inst_type => QPLL_NULL,    qpll_idx => 0,  refclk0_idx => 0, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false),        
                                                                                                                           
        (mgt_type => CFG_MGT_GBTX,     qpll_inst_type => QPLL_GBTX,    qpll_idx => 4,  refclk0_idx => 1, refclk1_idx => 1, is_master => TRUE,  chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,     qpll_inst_type => QPLL_NULL,    qpll_idx => 4,  refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,     qpll_inst_type => QPLL_NULL,    qpll_idx => 4,  refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,     qpll_inst_type => QPLL_NULL,    qpll_idx => 4,  refclk0_idx => 1, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false),

        (mgt_type => CFG_MGT_GBTX,     qpll_inst_type => QPLL_GBTX,    qpll_idx => 8,  refclk0_idx => 2, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,     qpll_inst_type => QPLL_NULL,    qpll_idx => 8,  refclk0_idx => 2, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,     qpll_inst_type => QPLL_NULL,    qpll_idx => 8,  refclk0_idx => 2, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,     qpll_inst_type => QPLL_NULL,    qpll_idx => 8,  refclk0_idx => 2, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false),

        (mgt_type => CFG_MGT_GBTX,     qpll_inst_type => QPLL_GBTX,    qpll_idx => 12, refclk0_idx => 3, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,     qpll_inst_type => QPLL_NULL,    qpll_idx => 12, refclk0_idx => 3, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,     qpll_inst_type => QPLL_NULL,    qpll_idx => 12, refclk0_idx => 3, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false),        
        (mgt_type => CFG_MGT_GBTX,     qpll_inst_type => QPLL_NULL,    qpll_idx => 12, refclk0_idx => 3, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false)

--        (mgt_type => CFG_MGT_10GBE,    qpll_inst_type => QPLL_10GBE_156, qpll_idx => 12, refclk0_idx => 3, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => TRUE),
--        (mgt_type => CFG_MGT_10GBE,    qpll_inst_type => QPLL_NULL,      qpll_idx => 12, refclk0_idx => 3, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false),
--        (mgt_type => CFG_MGT_10GBE,    qpll_inst_type => QPLL_NULL,      qpll_idx => 12, refclk0_idx => 3, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false),
--        (mgt_type => CFG_MGT_10GBE,    qpll_inst_type => QPLL_NULL,      qpll_idx => 12, refclk0_idx => 3, refclk1_idx => 3, is_master => false, chbond_master => 0, ibert_inst => false)
    );

end package project_config;

