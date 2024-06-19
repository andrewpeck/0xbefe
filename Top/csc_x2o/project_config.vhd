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

    constant CFG_NUM_SLRS       : integer := 4;    -- number of full CSC blocks to instantiate (typically one per SLR)

    --================================--
    -- CSC configuration                
    --================================--

    constant CFG_NUM_DMBS       : t_int_array(0 to CFG_NUM_SLRS - 1) := (others => 24);
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

    constant CFG_SPY_LINKS : t_int_array_2d(0 to CFG_NUM_SLRS -1)(0 downto 0) := (0 => (0 => 100), 1 => (0 => 101), 2 => (0 => 102), 3 => (0 => 103)); -- each SLR can optionally have multiple spy links transmitting the same data (useful for development at 904), but if the RX is used, it's only taken from the first link

    constant CFG_TTC_LINKS : t_int_array(0 to 3) := (16, 17, 18, 19);

    constant CFG_DMB_CONFIG_ARR : t_dmb_config_arr_per_slr(0 to CFG_NUM_SLRS - 1)(0 to CFG_DAQ_MAX_DMBS - 1) := (
        0 =>
        ( ------------------------------------------------ SLR0 ------------------------------------------------
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (8, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB0, SLR 0
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (9, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB1, SLR 0
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (10, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB2, SLR 0
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (11, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB3, SLR 0
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (12, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB4, SLR 0
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (13, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB5, SLR 0
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (14, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB6, SLR 0
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (15, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB7, SLR 0
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (0, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB8, SLR 0
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (1, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB9, SLR 0
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (2, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB10, SLR 0
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (3, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB11, SLR 0
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (4, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB12, SLR 0
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (5, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB13, SLR 0
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (6, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB14, SLR 0
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (7, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB15, SLR 0
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (116, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB16, SLR 0
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (117, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB17, SLR 0
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (118, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB18, SLR 0
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (119, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB19, SLR 0
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (112, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB20, SLR 0
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (113, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB21, SLR 0
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (114, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB22, SLR 0
            (dmb_type => DMB, num_fibers => 1, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (115, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS)), -- DMB23, SLR 0
            others => DMB_CONFIG_NULL
        ),
        1 =>
        ( ------------------------------------------------ SLR1 ------------------------------------------------
            (dmb_type => ODMB7, num_fibers => 4, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (20, 21, 22, 23)), -- DMB0, SLR 1
            (dmb_type => ODMB7, num_fibers => 4, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (28, 29, 30, 31)), -- DMB1, SLR 1
            (dmb_type => ODMB7, num_fibers => 4, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (92, 93, 94, 95)), -- DMB2, SLR 1
            (dmb_type => ODMB7, num_fibers => 4, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (96, 97, 98, 99)), -- DMB3, SLR 1
            others => DMB_CONFIG_NULL
        ),
        2 =>
        ( ------------------------------------------------ SLR2 ------------------------------------------------
            (dmb_type => ODMB7, num_fibers => 4, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (36, 37, 38, 39)), -- DMB0, SLR 2
            (dmb_type => ODMB7, num_fibers => 4, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (40, 41, 42, 43)), -- DMB1, SLR 2
            (dmb_type => ODMB7, num_fibers => 4, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (76, 77, 78, 79)), -- DMB2, SLR 2
            (dmb_type => ODMB7, num_fibers => 4, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (84, 85, 86, 87)), -- DMB3, SLR 2
            others => DMB_CONFIG_NULL
        ),
        3 =>
        ( ------------------------------------------------ SLR3 ------------------------------------------------
            (dmb_type => ODMB7, num_fibers => 4, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (44, 45, 46, 47)), -- DMB0, SLR 3
            (dmb_type => ODMB7, num_fibers => 4, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (48, 49, 50, 51)), -- DMB1, SLR 3
            (dmb_type => ODMB7, num_fibers => 4, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (52, 53, 54, 55)), -- DMB2, SLR 3
            (dmb_type => ODMB7, num_fibers => 4, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (56, 57, 58, 59)), -- DMB3, SLR 3
            (dmb_type => ODMB7, num_fibers => 4, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (60, 61, 62, 63)), -- DMB4, SLR 3
            (dmb_type => ODMB7, num_fibers => 4, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (64, 65, 66, 67)), -- DMB5, SLR 3
            (dmb_type => ODMB7, num_fibers => 4, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (68, 69, 70, 71)), -- DMB6, SLR 3
            others => DMB_CONFIG_NULL
        )
    );

    constant CFG_GBT_LINK_CONFIG_ARR : t_gbt_link_config_arr_per_slr(0 to CFG_NUM_SLRS - 1)(0 to CFG_MAX_GBTS - 1) := (
        0 =>
        ( ------------------------------------------------ SLR0 ------------------------------------------------
            (tx_fiber => 92, rx_fiber => CFG_BOARD_MAX_LINKS), -- GBT0, SLR 0
            (tx_fiber => 93, rx_fiber => CFG_BOARD_MAX_LINKS), -- GBT1, SLR 0
            (tx_fiber => 94, rx_fiber => CFG_BOARD_MAX_LINKS), -- GBT2, SLR 0
            (tx_fiber => 95, rx_fiber => CFG_BOARD_MAX_LINKS), -- GBT3, SLR 0
            others => (tx_fiber => CFG_BOARD_MAX_LINKS, rx_fiber => CFG_BOARD_MAX_LINKS)
        ),
        1 =>
        ( ------------------------------------------------ SLR1 ------------------------------------------------
            (tx_fiber => 20, rx_fiber => CFG_BOARD_MAX_LINKS), -- GBT0, SLR 1
            (tx_fiber => 21, rx_fiber => CFG_BOARD_MAX_LINKS), -- GBT1, SLR 1
            (tx_fiber => 22, rx_fiber => CFG_BOARD_MAX_LINKS), -- GBT2, SLR 1
            (tx_fiber => 23, rx_fiber => CFG_BOARD_MAX_LINKS), -- GBT3, SLR 1
            others => (tx_fiber => CFG_BOARD_MAX_LINKS, rx_fiber => CFG_BOARD_MAX_LINKS)
        ),
        2 =>
        ( ------------------------------------------------ SLR2 ------------------------------------------------
            (tx_fiber => 36, rx_fiber => CFG_BOARD_MAX_LINKS), -- GBT0, SLR 2
            (tx_fiber => 37, rx_fiber => CFG_BOARD_MAX_LINKS), -- GBT1, SLR 2
            (tx_fiber => 38, rx_fiber => CFG_BOARD_MAX_LINKS), -- GBT2, SLR 2
            (tx_fiber => 39, rx_fiber => CFG_BOARD_MAX_LINKS), -- GBT3, SLR 2
            others => (tx_fiber => CFG_BOARD_MAX_LINKS, rx_fiber => CFG_BOARD_MAX_LINKS)
        ),
        3 =>
        ( ------------------------------------------------ SLR3 ------------------------------------------------
            (tx_fiber => 44, rx_fiber => CFG_BOARD_MAX_LINKS), -- GBT0, SLR 3
            (tx_fiber => 45, rx_fiber => CFG_BOARD_MAX_LINKS), -- GBT1, SLR 3
            (tx_fiber => 46, rx_fiber => CFG_BOARD_MAX_LINKS), -- GBT2, SLR 3
            (tx_fiber => 47, rx_fiber => CFG_BOARD_MAX_LINKS), -- GBT3, SLR 3
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
        ----------------------------- quad 120 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156          , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => true , chbond_master => 0, ibert_inst => false), -- MGT 0 RX: SLR0 DMB 10 chan 0
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL                 , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 1 RX: SLR0 DMB 13 chan 0
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL                 , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 2 RX: SLR0 DMB 8 chan 0
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL                 , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 3 RX: SLR0 DMB 11 chan 0
        ----------------------------- quad 121 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156          , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 4 RX: SLR0 DMB 12 chan 0
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL                 , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 5 RX: SLR0 DMB 9 chan 0
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL                 , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 6 RX: SLR0 DMB 14 chan 0
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL                 , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 7 RX: SLR0 DMB 15 chan 0
        ----------------------------- quad 122 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156          , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 8 RX: SLR0 DMB 3 chan 0
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL                 , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 9 RX: SLR0 DMB 4 chan 0
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL                 , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 10 RX: SLR0 DMB 1 chan 0
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL                 , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 11 RX: SLR0 DMB 0 chan 0
        ----------------------------- quad 123 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156          , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 12 RX: SLR0 DMB 7 chan 0
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL                 , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 13 RX: SLR0 DMB 2 chan 0
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL                 , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 14 RX: SLR0 DMB 5 chan 0
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL                 , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 1, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 15 RX: SLR0 DMB 6 chan 0
        ----------------------------- quad 124 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_TTC      , qpll_inst_type => QPLL_LPGBT                , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 16
        (mgt_type => CFG_MGT_TTC      , qpll_inst_type => QPLL_NULL                 , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 17
        (mgt_type => CFG_MGT_TTC      , qpll_inst_type => QPLL_NULL                 , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 18
        (mgt_type => CFG_MGT_TTC      , qpll_inst_type => QPLL_NULL                 , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 2, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 19
        ----------------------------- quad 125 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_ODMB57_156           , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 2, is_master => true , chbond_master => 20, ibert_inst => false), -- MGT 20 TX: SLR1 GBT chan 0 RX: SLR1 ODMB 0 chan 0
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 2, is_master => false, chbond_master => 20, ibert_inst => false), -- MGT 21 TX: SLR1 GBT chan 1 RX: SLR1 ODMB 0 chan 1
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 2, is_master => false, chbond_master => 20, ibert_inst => false), -- MGT 22 TX: SLR1 GBT chan 2 RX: SLR1 ODMB 0 chan 2
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 2, is_master => false, chbond_master => 20, ibert_inst => false), -- MGT 23 TX: SLR1 GBT chan 3 RX: SLR1 ODMB 0 chan 3
        ----------------------------- quad 128 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 4, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 24
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 4, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 25
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 4, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 26
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 4, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 27
        ----------------------------- quad 129 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_ODMB57_156           , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 4, is_master => false, chbond_master => 28, ibert_inst => false), -- MGT 28 RX: SLR1 ODMB 1 chan 0
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 4, is_master => false, chbond_master => 28, ibert_inst => false), -- MGT 29 RX: SLR1 ODMB 1 chan 1
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 4, is_master => false, chbond_master => 28, ibert_inst => false), -- MGT 30 RX: SLR1 ODMB 1 chan 2
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 4, is_master => false, chbond_master => 28, ibert_inst => false), -- MGT 31 RX: SLR1 ODMB 1 chan 3
        ----------------------------- quad 130 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 5, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 32
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 5, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 33
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 5, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 34
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 5, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 35
        ----------------------------- quad 131 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_ODMB57_156           , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 5, is_master => false, chbond_master => 39, ibert_inst => false), -- MGT 36 TX: SLR2 GBT chan 3 RX: SLR2 ODMB 0 chan 3
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 5, is_master => false, chbond_master => 39, ibert_inst => false), -- MGT 37 TX: SLR2 GBT chan 2 RX: SLR2 ODMB 0 chan 2
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 5, is_master => false, chbond_master => 39, ibert_inst => false), -- MGT 38 TX: SLR2 GBT chan 1 RX: SLR2 ODMB 0 chan 1
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 5, is_master => false, chbond_master => 39, ibert_inst => false), -- MGT 39 TX: SLR2 GBT chan 0 RX: SLR2 ODMB 0 chan 0
        ----------------------------- quad 132 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_ODMB57_156           , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 6, is_master => false, chbond_master => 40, ibert_inst => false), -- MGT 40 RX: SLR2 ODMB 1 chan 0
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 6, is_master => false, chbond_master => 40, ibert_inst => false), -- MGT 41 RX: SLR2 ODMB 1 chan 1
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 6, is_master => false, chbond_master => 40, ibert_inst => false), -- MGT 42 TX: SLR3 GBT chan 0 RX: SLR2 ODMB 1 chan 2
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 6, is_master => false, chbond_master => 40, ibert_inst => false), -- MGT 43 RX: SLR2 ODMB 1 chan 3
        ----------------------------- quad 133 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_ODMB57_156           , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 6, is_master => false, chbond_master => 44, ibert_inst => false), -- MGT 44 TX: SLR3 GBT chan 2 RX: SLR3 ODMB 0 chan 0
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 6, is_master => false, chbond_master => 44, ibert_inst => false), -- MGT 45 TX: SLR3 GBT chan 1 RX: SLR3 ODMB 0 chan 1
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 6, is_master => false, chbond_master => 44, ibert_inst => false), -- MGT 46 RX: SLR3 ODMB 0 chan 2
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 6, is_master => false, chbond_master => 44, ibert_inst => false), -- MGT 47 TX: SLR3 GBT chan 3 RX: SLR3 ODMB 0 chan 3
        ----------------------------- quad 134 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_ODMB57_156           , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 7, is_master => false, chbond_master => 53, ibert_inst => false), -- MGT 48 RX: SLR3 ODMB 1 chan 3
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 7, is_master => false, chbond_master => 49, ibert_inst => false), -- MGT 49 RX: SLR3 ODMB 2 chan 0
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 7, is_master => false, chbond_master => 49, ibert_inst => false), -- MGT 50 RX: SLR3 ODMB 2 chan 1
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 7, is_master => false, chbond_master => 49, ibert_inst => false), -- MGT 51 RX: SLR3 ODMB 2 chan 2
        ----------------------------- quad 135 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_ODMB57_156           , qpll_idx => 052, refclk0_idx => 12, refclk1_idx => 7, is_master => false, chbond_master => 49, ibert_inst => false), -- MGT 52 RX: SLR3 ODMB 2 chan 3
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 052, refclk0_idx => 12, refclk1_idx => 7, is_master => false, chbond_master => 53, ibert_inst => false), -- MGT 53 RX: SLR3 ODMB 1 chan 0
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 052, refclk0_idx => 12, refclk1_idx => 7, is_master => false, chbond_master => 53, ibert_inst => false), -- MGT 54 RX: SLR3 ODMB 1 chan 1
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 052, refclk0_idx => 12, refclk1_idx => 7, is_master => false, chbond_master => 53, ibert_inst => false), -- MGT 55 RX: SLR3 ODMB 1 chan 2
        ----------------------------- quad 220 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156          , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 8, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 56 RX: SLR0 DMB 17 chan 0
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL                 , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 8, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 57 RX: SLR0 DMB 20 chan 0
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL                 , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 8, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 58 RX: SLR0 DMB 19 chan 0
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL                 , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 8, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 59 RX: SLR0 DMB 18 chan 0
        ----------------------------- quad 221 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156          , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 8, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 60 RX: SLR0 DMB 21 chan 0
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL                 , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 8, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 61 RX: SLR0 DMB 16 chan 0
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL                 , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 8, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 62 RX: SLR0 DMB 23 chan 0
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_NULL                 , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 8, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 63 RX: SLR0 DMB 22 chan 0
        ----------------------------- quad 222 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 9, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 64
        (mgt_type => CFG_MGT_DMB      , qpll_inst_type => QPLL_DMB_GBE_156          , qpll_idx => 065, refclk0_idx => 16, refclk1_idx => 9, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 65
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 065, refclk0_idx => 16, refclk1_idx => 9, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 66
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 065, refclk0_idx => 16, refclk1_idx => 9, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 67
        ----------------------------- quad 223 (SLR 0) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 9, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 68
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 9, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 69
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 9, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 70
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 9, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 71
        ----------------------------- quad 224 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_GBE      , qpll_inst_type => QPLL_GBE_156              , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 10, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 72
        (mgt_type => CFG_MGT_GBE      , qpll_inst_type => QPLL_NULL                 , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 10, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 73
        (mgt_type => CFG_MGT_GBE      , qpll_inst_type => QPLL_NULL                 , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 10, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 74
        (mgt_type => CFG_MGT_GBE      , qpll_inst_type => QPLL_NULL                 , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 10, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 75
        ----------------------------- quad 225 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_ODMB57_156           , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 10, is_master => false, chbond_master => 77, ibert_inst => false), -- MGT 76 RX: SLR1 ODMB 3 chan 1
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 10, is_master => false, chbond_master => 77, ibert_inst => false), -- MGT 77 RX: SLR1 ODMB 3 chan 0
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 10, is_master => false, chbond_master => 77, ibert_inst => false), -- MGT 78 RX: SLR1 ODMB 3 chan 3
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 10, is_master => false, chbond_master => 77, ibert_inst => false), -- MGT 79 RX: SLR1 ODMB 3 chan 2
        ----------------------------- quad 226 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_ODMB57_156           , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 11, is_master => false, chbond_master => 82, ibert_inst => false), -- MGT 80 TX: SLR0 GBT chan 2 RX: SLR1 ODMB 2 chan 2
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 11, is_master => false, chbond_master => 82, ibert_inst => false), -- MGT 81 TX: SLR0 GBT chan 3 RX: SLR1 ODMB 2 chan 3
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 11, is_master => false, chbond_master => 82, ibert_inst => false), -- MGT 82 TX: SLR0 GBT chan 0 RX: SLR1 ODMB 2 chan 0
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 11, is_master => false, chbond_master => 82, ibert_inst => false), -- MGT 83 TX: SLR0 GBT chan 1 RX: SLR1 ODMB 2 chan 1
        ----------------------------- quad 227 (SLR 1) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 84
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 85
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 86
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 11, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 87
        ----------------------------- quad 228 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_ODMB57_156           , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 12, is_master => false, chbond_master => 89, ibert_inst => false), -- MGT 88 RX: SLR2 ODMB 3 chan 1
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 12, is_master => false, chbond_master => 89, ibert_inst => false), -- MGT 89 RX: SLR2 ODMB 3 chan 0
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 12, is_master => false, chbond_master => 89, ibert_inst => false), -- MGT 90 RX: SLR2 ODMB 3 chan 3
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 12, is_master => false, chbond_master => 89, ibert_inst => false), -- MGT 91 RX: SLR2 ODMB 3 chan 2
        ----------------------------- quad 229 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 12, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 92
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 12, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 93
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 12, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 94
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 12, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 95
        ----------------------------- quad 230 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_ODMB57_156           , qpll_idx => 096, refclk0_idx => 24, refclk1_idx => 13, is_master => false, chbond_master => 98, ibert_inst => false), -- MGT 96 RX: SLR2 ODMB 2 chan 2
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 096, refclk0_idx => 24, refclk1_idx => 13, is_master => false, chbond_master => 98, ibert_inst => false), -- MGT 97 RX: SLR2 ODMB 2 chan 3
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 096, refclk0_idx => 24, refclk1_idx => 13, is_master => false, chbond_master => 98, ibert_inst => false), -- MGT 98 RX: SLR2 ODMB 2 chan 0
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 096, refclk0_idx => 24, refclk1_idx => 13, is_master => false, chbond_master => 98, ibert_inst => false), -- MGT 99 RX: SLR2 ODMB 2 chan 1
        ----------------------------- quad 231 (SLR 2) -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 100, refclk0_idx => 25, refclk1_idx => 13, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 100
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 100, refclk0_idx => 25, refclk1_idx => 13, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 101
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 100, refclk0_idx => 25, refclk1_idx => 13, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 102
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL                 , qpll_idx => 100, refclk0_idx => 25, refclk1_idx => 13, is_master => false, chbond_master => 0, ibert_inst => false), -- MGT 103
        ----------------------------- quad 232 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_ODMB57_156           , qpll_idx => 104, refclk0_idx => 26, refclk1_idx => 14, is_master => false, chbond_master => 105, ibert_inst => false), -- MGT 104 RX: SLR3 ODMB 6 chan 1
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 104, refclk0_idx => 26, refclk1_idx => 14, is_master => false, chbond_master => 105, ibert_inst => false), -- MGT 105 RX: SLR3 ODMB 6 chan 0
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 104, refclk0_idx => 26, refclk1_idx => 14, is_master => false, chbond_master => 105, ibert_inst => false), -- MGT 106 RX: SLR3 ODMB 6 chan 3
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 104, refclk0_idx => 26, refclk1_idx => 14, is_master => false, chbond_master => 105, ibert_inst => false), -- MGT 107 RX: SLR3 ODMB 6 chan 2
        ----------------------------- quad 233 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_ODMB57_156           , qpll_idx => 108, refclk0_idx => 27, refclk1_idx => 14, is_master => false, chbond_master => 109, ibert_inst => false), -- MGT 108 RX: SLR3 ODMB 5 chan 1
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 108, refclk0_idx => 27, refclk1_idx => 14, is_master => false, chbond_master => 109, ibert_inst => false), -- MGT 109 RX: SLR3 ODMB 5 chan 0
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 108, refclk0_idx => 27, refclk1_idx => 14, is_master => false, chbond_master => 109, ibert_inst => false), -- MGT 110 RX: SLR3 ODMB 5 chan 3
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 108, refclk0_idx => 27, refclk1_idx => 14, is_master => false, chbond_master => 109, ibert_inst => false), -- MGT 111 RX: SLR3 ODMB 5 chan 2
        ----------------------------- quad 234 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_ODMB57_156           , qpll_idx => 112, refclk0_idx => 28, refclk1_idx => 15, is_master => false, chbond_master => 114, ibert_inst => false), -- MGT 112 RX: SLR3 ODMB 4 chan 2
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 112, refclk0_idx => 28, refclk1_idx => 15, is_master => false, chbond_master => 118, ibert_inst => false), -- MGT 113 RX: SLR3 ODMB 3 chan 1
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 112, refclk0_idx => 28, refclk1_idx => 15, is_master => false, chbond_master => 114, ibert_inst => false), -- MGT 114 RX: SLR3 ODMB 4 chan 0
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 112, refclk0_idx => 28, refclk1_idx => 15, is_master => false, chbond_master => 118, ibert_inst => false), -- MGT 115 RX: SLR3 ODMB 3 chan 3
        ----------------------------- quad 235 (SLR 3) -----------------------------
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_ODMB57_156           , qpll_idx => 116, refclk0_idx => 28, refclk1_idx => 15, is_master => false, chbond_master => 118, ibert_inst => false), -- MGT 116 RX: SLR3 ODMB 3 chan 2
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 116, refclk0_idx => 28, refclk1_idx => 15, is_master => false, chbond_master => 114, ibert_inst => false), -- MGT 117 RX: SLR3 ODMB 4 chan 1
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 116, refclk0_idx => 28, refclk1_idx => 15, is_master => false, chbond_master => 118, ibert_inst => false), -- MGT 118 RX: SLR3 ODMB 3 chan 0
        (mgt_type => CFG_MGT_ODMB57   , qpll_inst_type => QPLL_NULL                 , qpll_idx => 116, refclk0_idx => 28, refclk1_idx => 15, is_master => false, chbond_master => 114, ibert_inst => false) -- MGT 119 RX: SLR3 ODMB 4 chan 3
    );
    
end package project_config;

