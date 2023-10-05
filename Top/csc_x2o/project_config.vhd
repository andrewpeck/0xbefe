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

    constant CFG_NUM_DMBS       : t_int_array(0 to CFG_NUM_SLRS - 1) := (others => 3);
    constant CFG_NUM_GBT_LINKS  : t_int_array(0 to CFG_NUM_SLRS - 1) := (others => 4);
    constant CFG_USE_SPY_LINK_TX : t_bool_array(0 to CFG_NUM_SLRS - 1) := (others => true);
    constant CFG_USE_SPY_LINK_RX : t_bool_array(0 to CFG_NUM_SLRS - 1) := (others => true);
    constant CFG_TTC_TX_SOURCE_SLR : integer := 0;
    constant CFG_USE_TTC_TX_LINK : boolean := true;
    constant CFG_USE_TTC_GBTX_LINK  : boolean := false;
    constant CFG_TTC_GBTX_LINK      : integer := CFG_BOARD_MAX_LINKS;   

    --================================--
    -- Link configuration               
    --================================--

    constant CFG_SPY_LINKS : t_int_array_2d(0 to CFG_NUM_SLRS -1)(1 downto 0) := (0 => (0 => 15, 1 => 14)); -- each SLR can optionally have multiple spy links transmitting the same data (useful for development at 904), but if the RX is used, it's only taken from the first link

    constant CFG_TTC_LINKS : t_int_array(0 to 3) := (4, 5, 6, 7);

    constant CFG_DMB_CONFIG_ARR : t_dmb_config_arr_per_slr(0 to CFG_NUM_SLRS - 1)(0 to CFG_DAQ_MAX_DMBS - 1) := (
        0 =>
        ( ------------------------------------------------ SLR0 ------------------------------------------------
--        (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (36, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB0, SLR 0
--        (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (37, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB1, SLR 0
--        (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (38, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB2, SLR 0
--        (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (39, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB3, SLR 0
--        (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (16, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB4, SLR 0
--        (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (17, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB5, SLR 0
        (dmb_type => ODMB7, num_fibers => 4, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (8, 9, 10, 11)), -- DMB0, SLR 0
        (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (12, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB1, SLR 0
        (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (13, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB2, SLR 0
            others => DMB_CONFIG_NULL
        )
    );

    constant CFG_GBT_LINK_CONFIG_ARR : t_gbt_link_config_arr_per_slr(0 to CFG_NUM_SLRS - 1)(0 to CFG_MAX_GBTS - 1) := (
        0 =>
        ( ------------------------------------------------ SLR0 ------------------------------------------------
            (tx_fiber => 0, rx_fiber => 0), -- GBT0, SLR 0
            (tx_fiber => 1, rx_fiber => 1), -- GBT1, SLR 0
            (tx_fiber => 2, rx_fiber => 2), -- GBT2, SLR 0
            (tx_fiber => 3, rx_fiber => 3), -- GBT3, SLR 0
            others => (tx_fiber => CFG_BOARD_MAX_LINKS, rx_fiber => CFG_BOARD_MAX_LINKS)
        )
    );

    constant CFG_ODMB57_BIDIR_TEST : boolean := false;
    constant CFG_ODMB7_BIDIR_TX_LINK : t_int_array(0 to 3) := (12, 13, 14, 15);
    constant CFG_ODMB7_BIDIR_RX_LINK : t_int_array(0 to 3) := (12, 13, 14, 15);
    
    constant CFG_USE_ETH_SWITCH         : boolean := false;
    constant CFG_ETH_SWITCH_NUM_PORTS   : integer := 16;
    constant CFG_ETH_SWITCH_LINKS       : t_int_array(0 to CFG_ETH_SWITCH_NUM_PORTS - 1) := (20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35);
    constant CFG_ETH_SWITCH_PORT_ROUTES : t_int_array_2d(0 to CFG_ETH_SWITCH_NUM_PORTS - 1)(0 to CFG_ETH_SWITCH_NUM_PORTS - 1) :=
        (
            (8, 9, 10, 11, 12, 13, 14, 15, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS),
            (8, 9, 10, 11, 12, 13, 14, 15, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS),
            (8, 9, 10, 11, 12, 13, 14, 15, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS),
            (8, 9, 10, 11, 12, 13, 14, 15, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS),
            (8, 9, 10, 11, 12, 13, 14, 15, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS),
            (8, 9, 10, 11, 12, 13, 14, 15, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS),
            (8, 9, 10, 11, 12, 13, 14, 15, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS),
            (8, 9, 10, 11, 12, 13, 14, 15, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS),
            (0, 1, 2, 3, 4, 5, 6, 7, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS),
            (0, 1, 2, 3, 4, 5, 6, 7, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS),
            (0, 1, 2, 3, 4, 5, 6, 7, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS),
            (0, 1, 2, 3, 4, 5, 6, 7, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS),
            (0, 1, 2, 3, 4, 5, 6, 7, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS),
            (0, 1, 2, 3, 4, 5, 6, 7, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS),
            (0, 1, 2, 3, 4, 5, 6, 7, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS),
            (0, 1, 2, 3, 4, 5, 6, 7, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS)
        );    

--    constant CFG_ETH_SWITCH_PORT_ROUTES : t_int_array_2d(0 to CFG_ETH_SWITCH_NUM_PORTS - 1)(0 to CFG_ETH_SWITCH_NUM_PORTS - 1) :=
--        (
--            (2, 3, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS),
--            (2, 3, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS),
--            (0, 1, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS),
--            (0, 1, CFG_ETH_SWITCH_NUM_PORTS, CFG_ETH_SWITCH_NUM_PORTS)
--        );    
    
    --================================--
    -- MGT configuration
    --================================--   
    
    constant CFG_MGT_LINK_CONFIG : t_mgt_config_arr := (
        ----------------------------- quad 224 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_DMB,          qpll_inst_type => QPLL_DMB_GBE_156, qpll_idx => 0, refclk0_idx => 18, refclk1_idx => 10, is_master => true,  chbond_master => 0, ibert_inst => true), -- MGT 72
        (mgt_type => CFG_MGT_DMB,          qpll_inst_type => QPLL_NULL       , qpll_idx => 0, refclk0_idx => 18, refclk1_idx => 10, is_master => false, chbond_master => 0, ibert_inst => true), -- MGT 73
        (mgt_type => CFG_MGT_GBE,          qpll_inst_type => QPLL_NULL       , qpll_idx => 0, refclk0_idx => 18, refclk1_idx => 10, is_master => false, chbond_master => 0, ibert_inst => true), -- MGT 74
        (mgt_type => CFG_MGT_GBE,          qpll_inst_type => QPLL_NULL       , qpll_idx => 0, refclk0_idx => 18, refclk1_idx => 10, is_master => false, chbond_master => 0, ibert_inst => true), -- MGT 75
        ----------------------------- quad 225 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_ODMB57_BIDIR, qpll_inst_type => QPLL_ODMB57_156 , qpll_idx => 4, refclk0_idx => 19, refclk1_idx => 10, is_master => false, chbond_master => 5, ibert_inst => true), -- MGT 76
        (mgt_type => CFG_MGT_ODMB57_BIDIR, qpll_inst_type => QPLL_NULL       , qpll_idx => 4, refclk0_idx => 19, refclk1_idx => 10, is_master => true,  chbond_master => 5, ibert_inst => true), -- MGT 77
        (mgt_type => CFG_MGT_ODMB57_BIDIR, qpll_inst_type => QPLL_NULL       , qpll_idx => 4, refclk0_idx => 19, refclk1_idx => 10, is_master => false, chbond_master => 5, ibert_inst => true), -- MGT 78
        (mgt_type => CFG_MGT_ODMB57_BIDIR, qpll_inst_type => QPLL_NULL       , qpll_idx => 4, refclk0_idx => 19, refclk1_idx => 10, is_master => false, chbond_master => 5, ibert_inst => true), -- MGT 79
        ----------------------------- quad 226 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_TTC,          qpll_inst_type => QPLL_LPGBT      , qpll_idx => 8, refclk0_idx => 20, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 80
        (mgt_type => CFG_MGT_TTC,          qpll_inst_type => QPLL_NULL       , qpll_idx => 8, refclk0_idx => 20, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 81
        (mgt_type => CFG_MGT_TTC,          qpll_inst_type => QPLL_NULL       , qpll_idx => 8, refclk0_idx => 20, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 82
        (mgt_type => CFG_MGT_TTC,          qpll_inst_type => QPLL_NULL       , qpll_idx => 8, refclk0_idx => 20, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 83
        ----------------------------- quad 227 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_GBTX,         qpll_inst_type => QPLL_GBTX       , qpll_idx => 12, refclk0_idx => 21, refclk1_idx => 11, is_master => true,  chbond_master => 0, ibert_inst => false), -- MGT 84
        (mgt_type => CFG_MGT_GBTX,         qpll_inst_type => QPLL_NULL       , qpll_idx => 12, refclk0_idx => 21, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 85
        (mgt_type => CFG_MGT_GBTX,         qpll_inst_type => QPLL_NULL       , qpll_idx => 12, refclk0_idx => 21, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 86
        (mgt_type => CFG_MGT_GBTX,         qpll_inst_type => QPLL_NULL       , qpll_idx => 12, refclk0_idx => 21, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false) -- MGT 87
    ); 

end package project_config;

