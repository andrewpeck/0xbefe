library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.board_config_package.all;
use work.gem_pkg.all;
use work.mgt_pkg.all;

package project_config is

    constant CFG_NUM_GEM_BLOCKS         : integer := 4; -- total number of GEM blocks to instanciate    
    type t_int_per_gem is array (0 to CFG_NUM_GEM_BLOCKS - 1) of integer;
    type t_oh_trig_link_type_arr is array (0 to CFG_NUM_GEM_BLOCKS - 1) of t_oh_trig_link_type;
    
    constant CFG_GEM_STATION            : t_int_per_gem := (others => 0);  -- 0 = ME0; 1 = GE1/1; 2 = GE2/1
    constant CFG_OH_VERSION             : t_int_per_gem := (others => 1);  -- for now this is only relevant to GE2/1 where v2 OH has different elink map, and uses widebus mode
    constant CFG_NUM_OF_OHs             : t_int_per_gem := (others => 3);  -- total number of OHs to instanciate (remember to adapt the CFG_OH_LINK_CONFIG_ARR accordingly)
    constant CFG_NUM_GBTS_PER_OH        : t_int_per_gem := (others => 8);  -- number of GBTs per OH
    constant CFG_NUM_VFATS_PER_OH       : t_int_per_gem := (others => 24); -- number of VFATs per OH
    constant CFG_GBT_WIDEBUS            : t_int_per_gem := (others => 0);  -- 0 means use standard mode, 1 means use widebus (set to 1 for GE2/1 OH version 2+)

    constant CFG_OH_TRIG_LINK_TYPE      : t_oh_trig_link_type_arr := (0 => OH_TRIG_LINK_TYPE_NONE); -- type of trigger link to use, the 3.2G and 4.0G are applicable to GE11, and GBT type is only applicable to GE21   
    constant CFG_USE_TRIG_TX_LINKS      : boolean := false; -- if true, then trigger transmitters will be instantiated (used to connect to EMTF)
    constant CFG_NUM_TRIG_TX            : integer := 8; -- number of trigger transmitters used to connect to EMTF

    --========================--
    --== Link configuration ==--
    --========================--

    -- 10 OH per SLR
    constant CFG_OH_LINK_CONFIG_ARR : t_oh_link_config_arr_arr := (
        ( ------------------------------------------------ SLR0 ------------------------------------------------
            (((000, 000), (TXRX_NULL, 001), (001, 002),  (TXRX_NULL, 003),  (002, 004),   (TXRX_NULL, 005),  (003, 006),  (TXRX_NULL, 007)), (LINK_NULL, LINK_NULL)), -- OH0, SLR 0
            (((008, 008), (TXRX_NULL, 009), (009, 010),  (TXRX_NULL, 011),  (010, 012),   (TXRX_NULL, 013),  (011, 014),  (TXRX_NULL, 015)), (LINK_NULL, LINK_NULL)), -- OH1, SLR 0
            (((016, 016), (TXRX_NULL, 017), (017, 018),  (TXRX_NULL, 019),  (018, 020),   (TXRX_NULL, 021),  (019, 022),  (TXRX_NULL, 023)), (LINK_NULL, LINK_NULL)), -- OH2, SLR 0
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))
        ),
        ( ------------------------------------------------ SLR1 ------------------------------------------------
            (((032, 032), (TXRX_NULL, 033), (033, 034),  (TXRX_NULL, 035),  (034, 036),   (TXRX_NULL, 037),  (035, 038),  (TXRX_NULL, 039)), (LINK_NULL, LINK_NULL)), -- OH3, SLR 1
            (((040, 040), (TXRX_NULL, 041), (041, 042),  (TXRX_NULL, 043),  (042, 044),   (TXRX_NULL, 045),  (043, 046),  (TXRX_NULL, 047)), (LINK_NULL, LINK_NULL)), -- OH4, SLR 1
            (((048, 048), (TXRX_NULL, 049), (049, 050),  (TXRX_NULL, 051),  (050, 052),   (TXRX_NULL, 053),  (051, 054),  (TXRX_NULL, 055)), (LINK_NULL, LINK_NULL)), -- OH5, SLR 1
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))
        ),
        ( ------------------------------------------------ SLR2 ------------------------------------------------
            (((056, 056), (TXRX_NULL, 057), (057, 058),  (TXRX_NULL, 059),  (058, 060),   (TXRX_NULL, 061),  (059, 062),  (TXRX_NULL, 063)), (LINK_NULL, LINK_NULL)), -- OH6, SLR 2
            (((064, 064), (TXRX_NULL, 065), (065, 066),  (TXRX_NULL, 067),  (066, 068),   (TXRX_NULL, 069),  (067, 070),  (TXRX_NULL, 071)), (LINK_NULL, LINK_NULL)), -- OH7, SLR 2
            (((072, 072), (TXRX_NULL, 073), (073, 074),  (TXRX_NULL, 075),  (074, 076),   (TXRX_NULL, 077),  (075, 078),  (TXRX_NULL, 079)), (LINK_NULL, LINK_NULL)), -- OH8, SLR 2
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))
        ),
        ( ------------------------------------------------ SLR3 ------------------------------------------------
            (((088, 088), (TXRX_NULL, 089), (089, 090),  (TXRX_NULL, 091),  (090, 092),   (TXRX_NULL, 093),  (091, 094),  (TXRX_NULL, 095)), (LINK_NULL, LINK_NULL)), -- OH9, SLR 3
            (((096, 096), (TXRX_NULL, 097), (097, 098),  (TXRX_NULL, 099),  (098, 100),   (TXRX_NULL, 101),  (099, 102),  (TXRX_NULL, 103)), (LINK_NULL, LINK_NULL)), -- OH10, SLR 3
            (((104, 104), (TXRX_NULL, 105), (105, 106),  (TXRX_NULL, 107),  (106, 108),   (TXRX_NULL, 109),  (107, 110),  (TXRX_NULL, 111)), (LINK_NULL, LINK_NULL)), -- OH11, SLR 3
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
            ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
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
    
    constant CFG_USE_SPY_LINK : t_spy_link_enable_arr := (others => false);
    constant CFG_SPY_LINK : t_spy_link_config := (0, 0, 0, 0);

    --================================--
    -- MGT configuration
    --================================--    

    constant CFG_MGT_LINK_CONFIG : t_mgt_config_arr := (
        ----------------------------- quad 120 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 121 (SLR 0) -----------------------------                                                                            
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 122 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 123 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 124 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 1, is_master => false, ibert_inst => false),
        ----------------------------- quad 125 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 1, is_master => false, ibert_inst => false),
        ----------------------------- quad 128 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 2, is_master => false, ibert_inst => false),
        ----------------------------- quad 129 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 2, is_master => false, ibert_inst => false),
        ----------------------------- quad 130 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 2, is_master => false, ibert_inst => false),
        ----------------------------- quad 131 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 2, is_master => false, ibert_inst => false),
        ----------------------------- quad 132 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 3, is_master => false, ibert_inst => false),
        ----------------------------- quad 133 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 3, is_master => false, ibert_inst => false),
        ----------------------------- quad 134 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 3, is_master => false, ibert_inst => false),
        ----------------------------- quad 135 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 3, is_master => false, ibert_inst => false),
        ----------------------------- quad 220 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 4, is_master => false, ibert_inst => false),
        ----------------------------- quad 221 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 4, is_master => false, ibert_inst => false),
        ----------------------------- quad 222 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 4, is_master => false, ibert_inst => false),
        ----------------------------- quad 223 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 4, is_master => false, ibert_inst => false),
        ----------------------------- quad 224 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 5, is_master => false, ibert_inst => false),
        ----------------------------- quad 225 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 5, is_master => false, ibert_inst => false),
        ----------------------------- quad 226 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 5, is_master => TRUE , ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 5, is_master => false, ibert_inst => false),
        ----------------------------- quad 227 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, ibert_inst => false),
        ----------------------------- quad 228 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 6, is_master => false, ibert_inst => false),
        ----------------------------- quad 229 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 6, is_master => false, ibert_inst => false),
        ----------------------------- quad 231 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 096, refclk0_idx => 25, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 096, refclk0_idx => 25, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 096, refclk0_idx => 25, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 096, refclk0_idx => 25, refclk1_idx => 6, is_master => false, ibert_inst => false),
        ----------------------------- quad 232 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 100, refclk0_idx => 26, refclk1_idx => 7, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 100, refclk0_idx => 26, refclk1_idx => 7, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 100, refclk0_idx => 26, refclk1_idx => 7, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 100, refclk0_idx => 26, refclk1_idx => 7, is_master => false, ibert_inst => false),
        ----------------------------- quad 233 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 104, refclk0_idx => 27, refclk1_idx => 7, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 104, refclk0_idx => 27, refclk1_idx => 7, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 104, refclk0_idx => 27, refclk1_idx => 7, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 104, refclk0_idx => 27, refclk1_idx => 7, is_master => false, ibert_inst => false),
        ----------------------------- quad 234 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 108, refclk0_idx => 28, refclk1_idx => 7, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 108, refclk0_idx => 28, refclk1_idx => 7, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 108, refclk0_idx => 28, refclk1_idx => 7, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 108, refclk0_idx => 28, refclk1_idx => 7, is_master => false, ibert_inst => false),
        ----------------------------- quad 235 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 112, refclk0_idx => 29, refclk1_idx => 7, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 112, refclk0_idx => 29, refclk1_idx => 7, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 112, refclk0_idx => 29, refclk1_idx => 7, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 112, refclk0_idx => 29, refclk1_idx => 7, is_master => false, ibert_inst => false)
    );

end package project_config;

