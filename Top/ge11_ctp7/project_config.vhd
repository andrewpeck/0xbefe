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
    
    constant CFG_GEM_STATION            : t_int_per_gem := (0 => 1);  -- 0 = ME0; 1 = GE1/1; 2 = GE2/1
    constant CFG_OH_VERSION             : t_int_per_gem := (0 => 2);  -- for now this is only relevant to GE2/1 where v2 OH has different elink map, and uses widebus mode
    constant CFG_NUM_OF_OHs             : t_int_per_gem := (0 => 12); -- total number of OHs to instanciate (remember to adapt the CFG_OH_LINK_CONFIG_ARR accordingly)
    constant CFG_NUM_GBTS_PER_OH        : t_int_per_gem := (0 => 3);  -- number of GBTs per OH
    constant CFG_NUM_VFATS_PER_OH       : t_int_per_gem := (0 => 24); -- number of VFATs per OH
    constant CFG_GBT_WIDEBUS            : t_int_per_gem := (0 => 0);  -- 0 means use standard mode, 1 means use widebus (set to 1 for GE2/1 OH version 2+) 

    constant CFG_OH_TRIG_LINK_TYPE      : t_oh_trig_link_type_arr := (0 => OH_TRIG_LINK_TYPE_4P0G); -- type of trigger link to use, the 3.2G and 4.0G are applicable to GE11, and GBT type is only applicable to GE21   
    constant CFG_USE_TRIG_TX_LINKS      : t_bool_per_gem := (others => true); -- if true, then trigger transmitters will be instantiated (used to connect to EMTF)
    constant CFG_NUM_TRIG_TX            : t_int_per_gem := (others => 8); -- number of trigger transmitters used to connect to EMTF

    --========================--
    --== Link configuration ==--
    --========================--

    constant CFG_OH_LINK_CONFIG_ARR : t_oh_link_config_arr_arr := (
    0 => (
            (((0,  0),  (1,  1),  (2,  2),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 40), (tx => TXRX_NULL, rx => 41))),
            (((3,  3),  (4,  4),  (5,  5),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 42), (tx => TXRX_NULL, rx => 43))),
            (((6,  6),  (7,  7),  (8,  8),  LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 44), (tx => TXRX_NULL, rx => 45))),
            (((9,  9),  (10, 10), (11, 11), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 46), (tx => TXRX_NULL, rx => 47))),

            (((12, 12), (13, 13), (14, 14), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 48), (tx => TXRX_NULL, rx => 49))),
            (((15, 15), (16, 16), (17, 17), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 50), (tx => TXRX_NULL, rx => 51))),
            (((18, 18), (19, 19), (20, 20), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 52), (tx => TXRX_NULL, rx => 53))),
            (((21, 21), (22, 22), (23, 23), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 54), (tx => TXRX_NULL, rx => 55))),

            (((24, 24), (25, 25), (26, 26), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 56), (tx => TXRX_NULL, rx => 57))),
            (((27, 27), (28, 28), (29, 29), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 58), (tx => TXRX_NULL, rx => 59))),
            (((30, 30), (31, 31), (32, 32), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 68), (tx => TXRX_NULL, rx => 69))),
            (((33, 33), (34, 34), (35, 35), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), ((tx => TXRX_NULL, rx => 70), (tx => TXRX_NULL, rx => 71))),

            others => ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))
        )
    );

    constant CFG_TRIG_TX_LINK_CONFIG_ARR : t_trig_tx_link_config_arr_arr := (
        0 => (48, 49, 50, 51, 52, 53, 54, 59)
    );

    constant CFG_USE_SPY_LINK_TX : t_spy_link_enable_arr := (0 => true);
    constant CFG_USE_SPY_LINK_RX : t_spy_link_enable_arr := (0 => false);
    constant CFG_SPY_LINK : t_spy_link_config := (0 => 58);

    constant CFG_USE_TTC_TX_LINK : boolean := false;
    constant CFG_TTC_LINKS : t_int_array(0 to 3) := (others => CFG_BOARD_MAX_LINKS);

    constant CFG_USE_TTC_GBTX_LINK  : boolean := false;
    constant CFG_TTC_GBTX_LINK      : integer := CFG_BOARD_MAX_LINKS;

end package project_config;
