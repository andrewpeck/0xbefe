library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package project_config is
    
    constant PRJ_CFG_GEM_STATION        : integer range 0 to 2 := 0; -- 0 = ME0; 1 = GE1/1; 2 = GE2/1
    constant PRJ_CFG_OH_VERSION         : integer := 1; -- for now this is only relevant to GE2/1 where v2 OH has different elink map, and uses widebus mode
    constant PRJ_CFG_NUM_OF_OHs         : integer := 2;   -- total number of OHs to instanciate (remember to adapt the CFG_OH_LINK_CONFIG_ARR accordingly)

    constant PRJ_CFG_USE_TRIG_TX_LINKS  : boolean := false; -- if true, then trigger transmitters will be instantiated (used to connect to EMTF)
    constant PRJ_CFG_NUM_TRIG_TX        : integer := 8; -- number of trigger transmitters used to connect to EMTF

    constant PRJ_CFG_GBT_DEBUG          : boolean := true; -- if set to true, an ILA will be instantiated which allows probing any GBT link
    
end package project_config;

