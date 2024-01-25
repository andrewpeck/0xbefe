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

    constant CFG_GEM_STATION            : t_int_per_gem := (0 => 0);  -- 0 = ME0; 1 = GE1/1; 2 = GE2/1
    constant CFG_OH_VERSION             : t_int_per_gem := (0 => 2);  -- for now this is only relevant to GE2/1 where v2 OH has different elink map, and uses widebus mode
    constant CFG_NUM_OF_OHs             : t_int_per_gem := (0 => 4);  -- total number of OHs to instanciate (remember to adapt the CFG_OH_LINK_CONFIG_ARR accordingly)
    constant CFG_NUM_GBTS_PER_OH        : t_int_per_gem := (0 => 8);  -- number of GBTs per OH
    constant CFG_NUM_VFATS_PER_OH       : t_int_per_gem := (0 => 24); -- number of VFATs per OH
    constant CFG_GBT_WIDEBUS            : t_int_per_gem := (0 => 0);  -- 0 means use standard mode, 1 means use widebus (set to 1 for GE2/1 OH version 2+)

    constant CFG_OH_TRIG_LINK_TYPE      : t_oh_trig_link_type_arr := (0 => OH_TRIG_LINK_TYPE_NONE); -- type of trigger link to use, the 3.2G and 4.0G are applicable to GE11, and GBT type is only applicable to GE21
    constant CFG_USE_TRIG_TX_LINKS      : t_bool_per_gem := (others => false); -- if true, then trigger transmitters will be instantiated (used to connect to EMTF)
    constant CFG_NUM_TRIG_TX            : t_int_per_gem := (others => 8); -- number of trigger transmitters used to connect to EMTF

    --========================--
    --== Link configuration ==--
    --========================--

    constant CFG_OH_LINK_CONFIG_ARR : t_oh_link_config_arr_arr := (
    0 => (
            ((( 0,  0), (TXRX_NULL,  1), ( 1,  2), (TXRX_NULL,  3), ( 2,  4), (TXRX_NULL,  5), ( 3,  6), (TXRX_NULL,  7)), ((tx => TXRX_NULL, rx => TXRX_NULL), (tx => TXRX_NULL, rx => TXRX_NULL))),
            ((( 8,  8), (TXRX_NULL,  9), ( 9, 10), (TXRX_NULL, 11), (10, 12), (TXRX_NULL, 13), (11, 14), (TXRX_NULL, 15)), ((tx => TXRX_NULL, rx => TXRX_NULL), (tx => TXRX_NULL, rx => TXRX_NULL))),
            (((16, 16), (TXRX_NULL, 17), (17, 18), (TXRX_NULL, 19), (18, 20), (TXRX_NULL, 21), (19, 22), (TXRX_NULL, 23)), ((tx => TXRX_NULL, rx => TXRX_NULL), (tx => TXRX_NULL, rx => TXRX_NULL))),
            (((24, 24), (TXRX_NULL, 25), (25, 26), (TXRX_NULL, 27), (26, 28), (TXRX_NULL, 29), (27, 30), (TXRX_NULL, 31)), ((tx => TXRX_NULL, rx => TXRX_NULL), (tx => TXRX_NULL, rx => TXRX_NULL))),

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
