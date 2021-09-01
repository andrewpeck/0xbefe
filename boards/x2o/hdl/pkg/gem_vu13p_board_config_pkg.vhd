------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2020-06-05
-- Module Name:    GEM_BOARD_CONFIG_PACKAGE 
-- Description:    Configuration for the CVP13 card 
------------------------------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

use work.mgt_pkg.all;
use work.project_config.all;
use work.ttc_pkg.C_TTC_CLK_FREQUENCY;

--============================================================================
--                                                         Package declaration
--============================================================================
package board_config_package is

    function get_num_gbts_per_oh(gem_station : integer) return integer;
    function get_num_vfats_per_oh(gem_station : integer) return integer;
    function get_gbt_widebus(gem_station, oh_version : integer) return integer;
    
    ------------ Firmware flavor and board type  ------------
    constant CFG_FW_FLAVOR          : std_logic_vector(3 downto 0) := x"0"; -- 0 = GEM_AMC; 1 = CSC_FED
    constant CFG_BOARD_TYPE         : std_logic_vector(3 downto 0) := x"4"; -- 0 = GLIB; 1 = CTP7; 2 = CVP13; 3 = APEX; 4 = X2O
    
    ------------ Board specific constants ------------
    constant CFG_BOARD_MAX_LINKS    : integer := 112;

    ------------ GEM specific constants ------------
    constant CFG_GEM_STATION        : integer range 0 to 2 := PRJ_CFG_GEM_STATION; -- Controlled by the project_config.vhd:  0 = ME0; 1 = GE1/1; 2 = GE2/1
    constant CFG_OH_VERSION         : integer := PRJ_CFG_OH_VERSION; -- Controlled by the project_config.vhd:  OH version
    constant CFG_NUM_OF_OHs         : integer := PRJ_CFG_NUM_OF_OHs; -- Controlled by the project_config.vhd:  total number of OHs to instanciate
    constant CFG_NUM_GBTS_PER_OH    : integer := get_num_gbts_per_oh(CFG_GEM_STATION);
    constant CFG_NUM_VFATS_PER_OH   : integer := get_num_vfats_per_oh(CFG_GEM_STATION);
    constant CFG_GBT_WIDEBUS        : integer := get_gbt_widebus(CFG_GEM_STATION, CFG_OH_VERSION);
    
    constant CFG_USE_TRIG_TX_LINKS  : boolean := PRJ_CFG_USE_TRIG_TX_LINKS; -- Controlled by the project_config.vhd:  if true, then trigger transmitters will be instantiated (used to connect to EMTF)
    constant CFG_NUM_TRIG_TX        : integer := PRJ_CFG_NUM_TRIG_TX; -- Controlled by the project_config.vhd:  number of trigger transmitters used to connect to EMTF

    ------------ DAQ configuration ------------
    constant CFG_DAQ_EVTFIFO_DEPTH          : integer := 4096;
    constant CFG_DAQ_EVTFIFO_PROG_FULL_SET  : integer := 3072;
    constant CFG_DAQ_EVTFIFO_PROG_FULL_RESET: integer := 2047;
    constant CFG_DAQ_EVTFIFO_DATA_CNT_WIDTH : integer := 12;
    
    constant CFG_DAQ_INFIFO_DEPTH           : integer := 4096;
    constant CFG_DAQ_INFIFO_PROG_FULL_SET   : integer := 3072;
    constant CFG_DAQ_INFIFO_PROG_FULL_RESET : integer := 2047;
    constant CFG_DAQ_INFIFO_DATA_CNT_WIDTH  : integer := 12;

    constant CFG_DAQ_OUTPUT_DEPTH           : integer := 8192;
    constant CFG_DAQ_OUTPUT_PROG_FULL_SET   : integer := 4045;
    constant CFG_DAQ_OUTPUT_PROG_FULL_RESET : integer := 1365;
    constant CFG_DAQ_OUTPUT_DATA_CNT_WIDTH  : integer := 13;

    constant CFG_DAQ_L1AFIFO_DEPTH          : integer := 8192;
    constant CFG_DAQ_L1AFIFO_PROG_FULL_SET  : integer := 6144;
    constant CFG_DAQ_L1AFIFO_PROG_FULL_RESET: integer := 4096;
    constant CFG_DAQ_L1AFIFO_DATA_CNT_WIDTH : integer := 13;

    constant CFG_DAQ_SPYFIFO_DEPTH          : integer := 32768;
    constant CFG_DAQ_SPYFIFO_PROG_FULL_SET  : integer := 24576;
    constant CFG_DAQ_SPYFIFO_PROG_FULL_RESET: integer := 16384;
    constant CFG_DAQ_SPYFIFO_DATA_CNT_WIDTH : integer := 17;

    constant CFG_DAQ_LASTEVT_FIFO_DEPTH     : integer := 4096;

    constant CFG_ETH_TEST_FIFO_DEPTH        : integer := 16384;

    ------------ DEBUG FLAGS ------------
    constant CFG_DEBUG_GBT                  : boolean := true; -- if set to true, an ILA will be instantiated which allows probing any GBT link
    constant CFG_DEBUG_OH                   : boolean := true; -- if set to true, and ILA will be instantiated on VFATs and OH trigger link
    constant CFG_DEBUG_DAQ                  : boolean := true;
    constant CFG_DEBUG_TRIGGER              : boolean := true;
    
    --========================--
    --== Link configuration ==--
    --========================--

    constant TXRX_NULL : integer := CFG_BOARD_MAX_LINKS;
    
    -- this record represents a single link (TXRX_NULL can be used to represent an unused tx or rx)
    type t_link is record
        tx      : integer range 0 to CFG_BOARD_MAX_LINKS;
        rx      : integer range 0 to CFG_BOARD_MAX_LINKS;
    end record;

    -- this constant can be used to represent an unused link
    constant LINK_NULL : t_link := (tx => TXRX_NULL, rx => TXRX_NULL);

    -- defines the GT index for each type of OH link
    type t_link_arr is array(integer range <>) of t_link;
    
    type t_oh_link_config is record
        gbt_links       : t_link_arr(0 to 7); -- GBT links
        trig_rx_links   : t_link_arr(0 to 1); -- GE1/1 trigger RX links
    end record t_oh_link_config;
    
    type t_oh_link_config_arr is array (0 to 47) of t_oh_link_config;

    constant CFG_OH_LINK_CONFIG_ARR_GE11 : t_oh_link_config_arr := (
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))
    );
    constant CFG_OH_LINK_CONFIG_ARR_GE21 : t_oh_link_config_arr := (
        (((64, 64), (65, 65), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((66, 66), (67, 67), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((68, 68), (69, 69), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((70, 70), (71, 71), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((72, 72), (73, 73), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((74, 74), (75, 75), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((76, 76), (77, 77), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((78, 78), (79, 79), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),

        (((00, 00), (01, 01), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((02, 02), (03, 03), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((04, 04), (05, 05), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((06, 06), (07, 07), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((08, 08), (09, 09), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((10, 10), (11, 11), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((12, 12), (13, 13), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((14, 14), (15, 15), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((16, 16), (17, 17), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((18, 18), (19, 19), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((20, 20), (21, 21), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((22, 22), (23, 23), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((24, 24), (25, 25), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((26, 26), (27, 27), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((28, 28), (29, 29), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((30, 30), (31, 31), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((32, 32), (33, 33), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((34, 34), (35, 35), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((36, 36), (37, 37), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((38, 38), (39, 39), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((40, 40), (41, 41), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((42, 42), (43, 43), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((44, 44), (45, 45), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((46, 46), (47, 47), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((48, 48), (49, 49), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((50, 50), (51, 51), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((52, 52), (53, 53), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((54, 54), (55, 55), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((56, 56), (57, 57), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((58, 58), (59, 59), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((60, 60), (61, 61), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((62, 62), (63, 63), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((80, 80), (81, 81), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((82, 82), (83, 83), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((84, 84), (85, 85), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((86, 86), (87, 87), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((88, 88), (89, 89), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((90, 90), (91, 91), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((92, 92), (93, 93), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        (((94, 94), (95, 95), LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))
    );
    constant CFG_OH_LINK_CONFIG_ARR_ME0 : t_oh_link_config_arr := (
        (((64, 64), (TXRX_NULL, 65), (65, 66),  (TXRX_NULL, 67),  (66, 68),   (TXRX_NULL, 69),  (67, 70),  (TXRX_NULL, 71)), (LINK_NULL, LINK_NULL)),
        (((72, 72), (TXRX_NULL, 73), (73, 74),  (TXRX_NULL, 75),  (74, 76),   (TXRX_NULL, 77),  (75, 78),  (TXRX_NULL, 79)), (LINK_NULL, LINK_NULL)),

        (((00, 00), (TXRX_NULL, 01), (01, 02),  (TXRX_NULL, 03),  (02, 04),   (TXRX_NULL, 05),  (03, 06),  (TXRX_NULL, 07)), (LINK_NULL, LINK_NULL)),
        (((08, 08), (TXRX_NULL, 09), (09, 10),  (TXRX_NULL, 11),  (10, 12),   (TXRX_NULL, 13),  (11, 14),  (TXRX_NULL, 15)), (LINK_NULL, LINK_NULL)),
        (((16, 16), (TXRX_NULL, 17), (17, 18),  (TXRX_NULL, 19),  (18, 20),   (TXRX_NULL, 21),  (19, 22),  (TXRX_NULL, 23)), (LINK_NULL, LINK_NULL)),
        (((24, 24), (TXRX_NULL, 25), (25, 26),  (TXRX_NULL, 27),  (26, 28),   (TXRX_NULL, 29),  (27, 30),  (TXRX_NULL, 31)), (LINK_NULL, LINK_NULL)),
        (((32, 32), (TXRX_NULL, 33), (33, 34),  (TXRX_NULL, 35),  (34, 36),   (TXRX_NULL, 37),  (35, 38),  (TXRX_NULL, 39)), (LINK_NULL, LINK_NULL)),
        (((40, 40), (TXRX_NULL, 41), (41, 42),  (TXRX_NULL, 43),  (42, 44),   (TXRX_NULL, 45),  (43, 46),  (TXRX_NULL, 47)), (LINK_NULL, LINK_NULL)),
        (((48, 48), (TXRX_NULL, 49), (49, 50),  (TXRX_NULL, 51),  (50, 52),   (TXRX_NULL, 53),  (51, 54),  (TXRX_NULL, 55)), (LINK_NULL, LINK_NULL)),
        (((56, 56), (TXRX_NULL, 57), (57, 58),  (TXRX_NULL, 59),  (58, 60),   (TXRX_NULL, 61),  (59, 62),  (TXRX_NULL, 63)), (LINK_NULL, LINK_NULL)),
        (((80, 80), (TXRX_NULL, 81), (81, 82),  (TXRX_NULL, 83),  (82, 84),   (TXRX_NULL, 85),  (83, 86),  (TXRX_NULL, 87)), (LINK_NULL, LINK_NULL)),
        (((88, 88), (TXRX_NULL, 89), (89, 90),  (TXRX_NULL, 91),  (90, 92),   (TXRX_NULL, 93),  (91, 94),  (TXRX_NULL, 95)), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL)),
        ((LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL, LINK_NULL), (LINK_NULL, LINK_NULL))
    );

    function get_oh_link_config_arr(gem_station: integer; ge11_config, ge21_config, me0_config : t_oh_link_config_arr) return t_oh_link_config_arr;
    constant CFG_OH_LINK_CONFIG_ARR : t_oh_link_config_arr := get_oh_link_config_arr(CFG_GEM_STATION, CFG_OH_LINK_CONFIG_ARR_GE11, CFG_OH_LINK_CONFIG_ARR_GE21, CFG_OH_LINK_CONFIG_ARR_ME0);

    type t_trig_tx_link_config_arr is array (0 to CFG_NUM_TRIG_TX - 1) of integer range 0 to CFG_BOARD_MAX_LINKS;
    
    constant CFG_TRIG_TX_LINK_CONFIG_ARR : t_trig_tx_link_config_arr := (CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS, CFG_BOARD_MAX_LINKS);
    
    constant CFG_USE_SPY_LINK : boolean := false;
    constant CFG_SPY_LINK : integer := 0;
    
    --================================--
    -- Fiber to MGT mapping
    --================================--    

    constant CFG_NUM_REFCLK0      : integer := 28;
    constant CFG_NUM_REFCLK1      : integer := 7; 
    constant CFG_MGT_NUM_CHANNELS : integer := 112;--CFG_BOARD_MAX_LINKS;
    
    constant MGT_NULL : integer := CFG_MGT_NUM_CHANNELS;
        
    -- this record is used in fiber to MGT map (holding tx and rx MGT index)
    type t_fiber_to_mgt_link is record
        tx      : integer range 0 to CFG_MGT_NUM_CHANNELS; -- MGT TX index (#CFG_BOARD_MAX_LINKS means disconnected/non-existing)
        rx      : integer range 0 to CFG_MGT_NUM_CHANNELS; -- MGT RX index (#CFG_BOARD_MAX_LINKS means disconnected/non-existing)
        tx_inv  : boolean; -- indicates whether or not the TX is inverted on the board (this is used by software to invert the respective channels)
        rx_inv  : boolean; -- indicates whether or not the RX is inverted on the board (this is used by software to invert the respective channels)
    end record;
    
    -- this array is meant to hold a mapping from fiber index to MGT TX and RX indices
    type t_fiber_to_mgt_link_map is array (0 to CFG_BOARD_MAX_LINKS) of t_fiber_to_mgt_link;

    -- defines the MGT TX and RX index for each fiber index
    -- each line here corresponds to a logical link number (starting at 0), where the first element refers to the TX MGT number, and the second element refers to the RX MGT number (inversions are always noted in the comments)
    -- DUMMY: last fiber - use this for unconnected channels (e.g. the non-existing GBT#2 in GE2/1)
    -- note that MGT_NULL is used as a placeholder for fiber links that are not connected to the FPGA
    constant CFG_FIBER_TO_MGT_MAP : t_fiber_to_mgt_link_map := (
        --========= ARF6 #0 (J19) =========--
        (002, 002, false, true ), -- fiber 0
        (014, 014, false, true ), -- fiber 1
        (004, 000, false, true ), -- fiber 2
        (012, 012, true , true ), -- fiber 3
        (000, 004, false, true ), -- fiber 4
        (010, 010, false, true ), -- fiber 5
        (006, 006, false, true ), -- fiber 6
        (008, 008, false, true ), -- fiber 7
        --========= ARF6 #1 (J20) =========--
        (015, 009, true , false), -- fiber 8
        (003, 005, true , false), -- fiber 9
        (013, 015, true , false), -- fiber 10
        (005, 003, true , false), -- fiber 11
        (011, 011, true , false), -- fiber 12
        (001, 001, true , false), -- fiber 13
        (007, 013, false, false), -- fiber 14
        (009, 007, true , false), -- fiber 15
        --========= ARF6 #4 (J15) =========--
        (016, 016, true , false), -- fiber 16
        (030, 030, true , false), -- fiber 17
        (018, 018, true , false), -- fiber 18
        (028, 028, true , false), -- fiber 19
        (020, 020, true , false), -- fiber 20
        (026, 026, true , false), -- fiber 21
        (022, 022, true , false), -- fiber 22
        (024, 024, true , false), -- fiber 23
        --========= ARF6 #5 (J16) =========--
        (031, 031, true , true ), -- fiber 24
        (017, 017, true , true ), -- fiber 25
        (029, 029, true , true ), -- fiber 26
        (019, 019, true , true ), -- fiber 27
        (027, 027, true , true ), -- fiber 28
        (021, 021, true , true ), -- fiber 29
        (025, 025, true , true ), -- fiber 30
        (023, 023, true , true ), -- fiber 31
        --========= ARF6 #6 (J5) =========--
        (032, 032, true , false), -- fiber 32
        (042, 042, true , false), -- fiber 33
        (046, 034, true , false), -- fiber 34
        (044, 044, true , false), -- fiber 35
        (034, 036, true , false), -- fiber 36
        (040, 046, true , false), -- fiber 37
        (036, 038, true , false), -- fiber 38
        (038, 040, true , false), -- fiber 39
        --========= ARF6 #7 (J6) =========--
        (043, 041, false, true ), -- fiber 40
        (033, 033, false, true ), -- fiber 41
        (045, 043, false, true ), -- fiber 42
        (035, 035, false, true ), -- fiber 43
        (047, 045, false, true ), -- fiber 44
        (037, 037, false, true ), -- fiber 45
        (041, 047, false, true ), -- fiber 46
        (039, 039, false, true ), -- fiber 47
        --========= ARF6 #8 (J18) =========--
        (062, 062, true , false), -- fiber 48
        (050, 048, true , false), -- fiber 49
        (060, 060, false, false), -- fiber 50
        (052, 050, true , false), -- fiber 51
        (058, 058, true , false), -- fiber 52
        (048, 052, true , false), -- fiber 53
        (056, 056, true , false), -- fiber 54
        (054, 054, true , false), -- fiber 55
        --========= ARF6 #9 (J17) =========--
        (051, 053, false, true ), -- fiber 56
        (063, 057, false, true ), -- fiber 57
        (053, 051, false, true ), -- fiber 58
        (061, 063, false, true ), -- fiber 59
        (049, 049, false, true ), -- fiber 60
        (059, 059, false, true ), -- fiber 61
        (057, 055, false, true ), -- fiber 62
        (055, 061, true , true ), -- fiber 63
        --========= ARF6 #10 (J7) =========--
        (078, 078, false, false), -- fiber 64
        (064, 064, false, false), -- fiber 65
        (076, 076, false, false), -- fiber 66
        (066, 066, false, false), -- fiber 67
        (074, 074, false, false), -- fiber 68
        (068, 068, false, false), -- fiber 69
        (072, 072, false, false), -- fiber 70
        (070, 070, false, false), -- fiber 71
        --========= ARF6 #11 (J10) =========--
        (065, 065, false, true ), -- fiber 72
        (079, 079, false, true ), -- fiber 73
        (067, 067, false, true ), -- fiber 74
        (077, 077, false, true ), -- fiber 75
        (069, 069, false, true ), -- fiber 76
        (075, 075, false, true ), -- fiber 77
        (071, 071, false, true ), -- fiber 78
        (073, 073, false, true ), -- fiber 79
        --========= ARF6 #12 (J14) =========--
        (094, 094, false, true ), -- fiber 80
        (080, 080, false, true ), -- fiber 81
        (092, 092, false, true ), -- fiber 82
        (082, 082, false, true ), -- fiber 83
        (090, 090, false, true ), -- fiber 84
        (084, 084, false, true ), -- fiber 85
        (088, 088, false, true ), -- fiber 86
        (086, 086, false, true ), -- fiber 87
        --========= ARF6 #13 (J13) =========--
        (081, 081, false, false), -- fiber 88
        (095, 095, false, false), -- fiber 89
        (083, 083, false, false), -- fiber 90
        (093, 093, false, false), -- fiber 91
        (085, 085, false, false), -- fiber 92
        (091, 091, false, false), -- fiber 93
        (087, 087, false, false), -- fiber 94
        (089, 089, false, false), -- fiber 95
        --========= ARF6 #14 (J4) =========--
        (106, 110, false, true ), -- fiber 96
        (096, 096, false, true ), -- fiber 97
        (108, 108, false, true ), -- fiber 98
        (110, 098, false, true ), -- fiber 99
        (104, 106, false, true ), -- fiber 100
        (098, 100, false, true ), -- fiber 101
        (102, 104, false, true ), -- fiber 102
        (100, 102, false, true ), -- fiber 103
        --========= ARF6 #15 (J3) =========--
        (097, 097, true , false), -- fiber 104
        (107, 105, true , false), -- fiber 105
        (099, 099, true , false), -- fiber 106
        (109, 107, true , false), -- fiber 107
        (101, 101, true , false), -- fiber 108
        (111, 109, true , false), -- fiber 109
        (103, 103, true , false), -- fiber 110
        (105, 111, true , false), -- fiber 111
        --=== DUMMY fiber - use for unconnected channels ===--
        (MGT_NULL, MGT_NULL, false, false)
    );
    
    --================================--
    -- MGT configuration
    --================================--    

    constant CFG_ASYNC_REFCLK_200_FREQ      : integer := 200_000_000;
    constant CFG_ASYNC_REFCLK_156p25_FREQ   : integer := 156_250_000;
    constant CFG_LHC_REFCLK_FREQ            : integer := C_TTC_CLK_FREQUENCY * 4;
    
    constant CFG_MGT_GBE : t_mgt_type_config := (
        link_type               => MGT_GBE,
        cpll_refclk_01          => 0, 
        qpll0_refclk_01         => 0,
        qpll1_refclk_01         => 0,
        tx_use_qpll             => true, 
        rx_use_qpll             => true,
        tx_qpll_01              => 1,
        rx_qpll_01              => 1,
        tx_refclk_freq          => CFG_ASYNC_REFCLK_156p25_FREQ,
        rx_refclk_freq          => CFG_ASYNC_REFCLK_156p25_FREQ,
        tx_bus_width            => 16,
        tx_multilane_phalign    => false, 
        rx_use_buf              => true
    );

    constant CFG_MGT_GBTX : t_mgt_type_config := (
        link_type               => MGT_GBTX,
        cpll_refclk_01          => 1, 
        qpll0_refclk_01         => 1,
        qpll1_refclk_01         => 1,
        tx_use_qpll             => true, 
        rx_use_qpll             => true,
        tx_qpll_01              => 1,
        rx_qpll_01              => 1,
        tx_refclk_freq          => CFG_LHC_REFCLK_FREQ,
        rx_refclk_freq          => CFG_LHC_REFCLK_FREQ,
        tx_bus_width            => 40,
        tx_multilane_phalign    => true, 
        rx_use_buf              => false
    );

    constant CFG_MGT_LPGBT : t_mgt_type_config := (
        link_type               => MGT_LPGBT,
        cpll_refclk_01          => 1, 
        qpll0_refclk_01         => 1,
        qpll1_refclk_01         => 1,
        tx_use_qpll             => true, 
        rx_use_qpll             => true,
        tx_qpll_01              => 0,
        rx_qpll_01              => 0,
        tx_refclk_freq          => CFG_LHC_REFCLK_FREQ,
        rx_refclk_freq          => CFG_LHC_REFCLK_FREQ,
        tx_bus_width            => 32,
        tx_multilane_phalign    => true, 
        rx_use_buf              => false
    );
        
    type t_mgt_config_arr is array (0 to CFG_MGT_NUM_CHANNELS - 1) of t_mgt_config;
    
    
    constant CFG_MGT_LINK_CONFIG_GE11 : t_mgt_config_arr := (
        ----------------------------- quad 120 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 121 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 122 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 123 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 128 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 1, is_master => false, ibert_inst => false),
        ----------------------------- quad 129 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 1, is_master => false, ibert_inst => false),
        ----------------------------- quad 130 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 1, is_master => false, ibert_inst => false),
        ----------------------------- quad 131 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 1, is_master => false, ibert_inst => false),
        ----------------------------- quad 132 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 2, is_master => false, ibert_inst => false),
        ----------------------------- quad 133 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 2, is_master => false, ibert_inst => false),
        ----------------------------- quad 134 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 2, is_master => false, ibert_inst => false),
        ----------------------------- quad 135 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 2, is_master => false, ibert_inst => false),
        ----------------------------- quad 220 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 3, is_master => false, ibert_inst => false),
        ----------------------------- quad 221 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 3, is_master => false, ibert_inst => false),
        ----------------------------- quad 222 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 3, is_master => false, ibert_inst => false),
        ----------------------------- quad 223 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 3, is_master => false, ibert_inst => false),
        ----------------------------- quad 224 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 4, is_master => false, ibert_inst => false),
        ----------------------------- quad 225 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 4, is_master => false, ibert_inst => false),
        ----------------------------- quad 226 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 4, is_master => false, ibert_inst => false),
        ----------------------------- quad 227 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 4, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 4, is_master => false, ibert_inst => false),
        ----------------------------- quad 228 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 5, is_master => false, ibert_inst => false),
        ----------------------------- quad 229 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, ibert_inst => false),
        ----------------------------- quad 230 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 5, is_master => false, ibert_inst => false),
        ----------------------------- quad 231 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 5, is_master => false, ibert_inst => false),
        ----------------------------- quad 232 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 096, refclk0_idx => 24, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 096, refclk0_idx => 24, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 096, refclk0_idx => 24, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 096, refclk0_idx => 24, refclk1_idx => 6, is_master => false, ibert_inst => false),
        ----------------------------- quad 233 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 100, refclk0_idx => 25, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 100, refclk0_idx => 25, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 100, refclk0_idx => 25, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 100, refclk0_idx => 25, refclk1_idx => 6, is_master => false, ibert_inst => false),
        ----------------------------- quad 234 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 104, refclk0_idx => 26, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 104, refclk0_idx => 26, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 104, refclk0_idx => 26, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 104, refclk0_idx => 26, refclk1_idx => 6, is_master => false, ibert_inst => false),
        ----------------------------- quad 235 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 108, refclk0_idx => 27, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 108, refclk0_idx => 27, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 108, refclk0_idx => 27, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 108, refclk0_idx => 27, refclk1_idx => 6, is_master => false, ibert_inst => false)
    );
    constant CFG_MGT_LINK_CONFIG_GE21 : t_mgt_config_arr := (
        ----------------------------- quad 120 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 121 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 122 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 123 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 128 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 1, is_master => false, ibert_inst => false),
        ----------------------------- quad 129 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 1, is_master => false, ibert_inst => false),
        ----------------------------- quad 130 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 1, is_master => false, ibert_inst => false),
        ----------------------------- quad 131 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 1, is_master => false, ibert_inst => false),
        ----------------------------- quad 132 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 2, is_master => false, ibert_inst => false),
        ----------------------------- quad 133 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 2, is_master => false, ibert_inst => false),
        ----------------------------- quad 134 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 2, is_master => false, ibert_inst => false),
        ----------------------------- quad 135 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 2, is_master => false, ibert_inst => false),
        ----------------------------- quad 220 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 3, is_master => false, ibert_inst => false),
        ----------------------------- quad 221 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 3, is_master => false, ibert_inst => false),
        ----------------------------- quad 222 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 3, is_master => false, ibert_inst => false),
        ----------------------------- quad 223 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 3, is_master => false, ibert_inst => false),
        ----------------------------- quad 224 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 4, is_master => false, ibert_inst => TRUE),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 4, is_master => false, ibert_inst => TRUE),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 4, is_master => false, ibert_inst => TRUE),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 4, is_master => false, ibert_inst => TRUE),
        ----------------------------- quad 225 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 4, is_master => TRUE,  ibert_inst => TRUE),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 4, is_master => false, ibert_inst => TRUE),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 4, is_master => false, ibert_inst => TRUE),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 4, is_master => false, ibert_inst => TRUE),
        ----------------------------- quad 226 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 4, is_master => false, ibert_inst => TRUE),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 4, is_master => false, ibert_inst => TRUE),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 4, is_master => false, ibert_inst => TRUE),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 4, is_master => false, ibert_inst => TRUE),
        ----------------------------- quad 227 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 4, is_master => false, ibert_inst => TRUE),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 4, is_master => false, ibert_inst => TRUE),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 4, is_master => false, ibert_inst => TRUE),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 4, is_master => false, ibert_inst => TRUE),
        ----------------------------- quad 228 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 5, is_master => false, ibert_inst => false),
        ----------------------------- quad 229 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, ibert_inst => false),
        ----------------------------- quad 230 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 5, is_master => false, ibert_inst => false),
        ----------------------------- quad 231 -----------------------------
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_GBTX   , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_GBTX     , qpll_inst_type => QPLL_NULL   , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 5, is_master => false, ibert_inst => false),
        ----------------------------- quad 232 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 096, refclk0_idx => 24, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 096, refclk0_idx => 24, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 096, refclk0_idx => 24, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 096, refclk0_idx => 24, refclk1_idx => 6, is_master => false, ibert_inst => false),
        ----------------------------- quad 233 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 100, refclk0_idx => 25, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 100, refclk0_idx => 25, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 100, refclk0_idx => 25, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 100, refclk0_idx => 25, refclk1_idx => 6, is_master => false, ibert_inst => false),
        ----------------------------- quad 234 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 104, refclk0_idx => 26, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 104, refclk0_idx => 26, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 104, refclk0_idx => 26, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 104, refclk0_idx => 26, refclk1_idx => 6, is_master => false, ibert_inst => false),
        ----------------------------- quad 235 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 108, refclk0_idx => 27, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 108, refclk0_idx => 27, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 108, refclk0_idx => 27, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 108, refclk0_idx => 27, refclk1_idx => 6, is_master => false, ibert_inst => false)
    );
    constant CFG_MGT_LINK_CONFIG_ME0 : t_mgt_config_arr := (
        ----------------------------- quad 120 -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 000, refclk0_idx => 00, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 121 -----------------------------                                                                                    
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 004, refclk0_idx => 01, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 122 -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 008, refclk0_idx => 02, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 123 -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 012, refclk0_idx => 03, refclk1_idx => 0, is_master => false, ibert_inst => false),
        ----------------------------- quad 128 -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 016, refclk0_idx => 04, refclk1_idx => 1, is_master => false, ibert_inst => false),
        ----------------------------- quad 129 -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 020, refclk0_idx => 05, refclk1_idx => 1, is_master => false, ibert_inst => false),
        ----------------------------- quad 130 -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 024, refclk0_idx => 06, refclk1_idx => 1, is_master => false, ibert_inst => false),
        ----------------------------- quad 131 -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 1, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 028, refclk0_idx => 07, refclk1_idx => 1, is_master => false, ibert_inst => false),
        ----------------------------- quad 132 -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 032, refclk0_idx => 08, refclk1_idx => 2, is_master => false, ibert_inst => false),
        ----------------------------- quad 133 -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 036, refclk0_idx => 09, refclk1_idx => 2, is_master => false, ibert_inst => false),
        ----------------------------- quad 134 -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 040, refclk0_idx => 10, refclk1_idx => 2, is_master => false, ibert_inst => false),
        ----------------------------- quad 135 -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 2, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 044, refclk0_idx => 11, refclk1_idx => 2, is_master => false, ibert_inst => false),
        ----------------------------- quad 220 -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 048, refclk0_idx => 12, refclk1_idx => 3, is_master => false, ibert_inst => false),
        ----------------------------- quad 221 -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 052, refclk0_idx => 13, refclk1_idx => 3, is_master => false, ibert_inst => false),
        ----------------------------- quad 222 -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 056, refclk0_idx => 14, refclk1_idx => 3, is_master => false, ibert_inst => false),
        ----------------------------- quad 223 -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 3, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 060, refclk0_idx => 15, refclk1_idx => 3, is_master => false, ibert_inst => false),
        ----------------------------- quad 224 -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 4, is_master => false, ibert_inst => TRUE ),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 4, is_master => false, ibert_inst => TRUE ),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 4, is_master => false, ibert_inst => TRUE ),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 064, refclk0_idx => 16, refclk1_idx => 4, is_master => false, ibert_inst => TRUE ),
        ----------------------------- quad 225 -----------------------------                                                                                     
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 4, is_master => TRUE , ibert_inst => TRUE ),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 4, is_master => false, ibert_inst => TRUE ),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 4, is_master => false, ibert_inst => TRUE ),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 068, refclk0_idx => 17, refclk1_idx => 4, is_master => false, ibert_inst => TRUE ),
        ----------------------------- quad 226 -----------------------------                                                                                     
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 4, is_master => false, ibert_inst => TRUE ),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 4, is_master => false, ibert_inst => TRUE ),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 4, is_master => false, ibert_inst => TRUE ),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 072, refclk0_idx => 18, refclk1_idx => 4, is_master => false, ibert_inst => TRUE ),
        ----------------------------- quad 227 -----------------------------                                                                                    
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 4, is_master => false, ibert_inst => TRUE ),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 4, is_master => false, ibert_inst => TRUE ),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 4, is_master => false, ibert_inst => TRUE ),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 076, refclk0_idx => 19, refclk1_idx => 4, is_master => false, ibert_inst => TRUE ),
        ----------------------------- quad 228 -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 080, refclk0_idx => 20, refclk1_idx => 5, is_master => false, ibert_inst => false),
        ----------------------------- quad 229 -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 084, refclk0_idx => 21, refclk1_idx => 5, is_master => false, ibert_inst => false),
        ----------------------------- quad 230 -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 088, refclk0_idx => 22, refclk1_idx => 5, is_master => false, ibert_inst => false),
        ----------------------------- quad 231 -----------------------------
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_LPGBT  , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 5, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_LPGBT    , qpll_inst_type => QPLL_NULL   , qpll_idx => 092, refclk0_idx => 23, refclk1_idx => 5, is_master => false, ibert_inst => false),
        ----------------------------- quad 232 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 096, refclk0_idx => 24, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 096, refclk0_idx => 24, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 096, refclk0_idx => 24, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 096, refclk0_idx => 24, refclk1_idx => 6, is_master => false, ibert_inst => false),
        ----------------------------- quad 233 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 100, refclk0_idx => 25, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 100, refclk0_idx => 25, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 100, refclk0_idx => 25, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 100, refclk0_idx => 25, refclk1_idx => 6, is_master => false, ibert_inst => false),
        ----------------------------- quad 234 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 104, refclk0_idx => 26, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 104, refclk0_idx => 26, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 104, refclk0_idx => 26, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 104, refclk0_idx => 26, refclk1_idx => 6, is_master => false, ibert_inst => false),
        ----------------------------- quad 235 -----------------------------
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 108, refclk0_idx => 27, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 108, refclk0_idx => 27, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 108, refclk0_idx => 27, refclk1_idx => 6, is_master => false, ibert_inst => false),
        (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL   , qpll_idx => 108, refclk0_idx => 27, refclk1_idx => 6, is_master => false, ibert_inst => false)
    );

    function get_mgt_config(gem_station: integer; ge11_config, ge21_config, me0_config : t_mgt_config_arr) return t_mgt_config_arr;
    constant CFG_MGT_LINK_CONFIG : t_mgt_config_arr := get_mgt_config(CFG_GEM_STATION, CFG_MGT_LINK_CONFIG_GE11, CFG_MGT_LINK_CONFIG_GE21, CFG_MGT_LINK_CONFIG_ME0);

end board_config_package;

package body board_config_package is

    function get_num_gbts_per_oh(gem_station : integer) return integer is
    begin
        if gem_station = 0 then
            return 8;
        elsif gem_station = 1 then
            return 3;
        elsif gem_station = 2 then
            return 2;
        else -- hmm whatever, lets say 3
            return 3;  
        end if;
    end function get_num_gbts_per_oh;
    
    function get_num_vfats_per_oh(gem_station : integer) return integer is
    begin
        if gem_station = 0 then
            return 24;
        elsif gem_station = 1 then
            return 24;
        elsif gem_station = 2 then
            return 12;
        else -- hmm whatever, lets say 24
            return 24;  
        end if;
    end function get_num_vfats_per_oh;
    
    function get_oh_link_config_arr(gem_station: integer; ge11_config, ge21_config, me0_config : t_oh_link_config_arr) return t_oh_link_config_arr is
    begin
        if gem_station = 0 then
            return me0_config;
        elsif gem_station = 1 then
            return ge11_config;
        elsif gem_station = 2 then
            return ge21_config;
        else -- hmm whatever, lets say GE1/1
            return ge11_config;  
        end if;
    end function get_oh_link_config_arr;

    function get_mgt_config(gem_station: integer; ge11_config, ge21_config, me0_config : t_mgt_config_arr) return t_mgt_config_arr is
    begin
        if gem_station = 0 then
            return me0_config;
        elsif gem_station = 1 then
            return ge11_config;
        elsif gem_station = 2 then
            return ge21_config;
        else -- hmm whatever, lets say GE1/1
            return ge11_config;  
        end if;
    end function get_mgt_config;
    
    function get_gbt_widebus(gem_station, oh_version : integer) return integer is
    begin
        if gem_station = 2 and oh_version > 1 then
            return 1;
        else
            return 0;
        end if;
    end function get_gbt_widebus;
    
end board_config_package;
--============================================================================
--                                                                 Package end 
--============================================================================

