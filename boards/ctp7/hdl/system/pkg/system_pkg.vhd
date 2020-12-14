-------------------------------------------------------------------------------
--                                                                            
--       Unit Name: system_package                                           
--                                                                            
--     Description: 
--
--                                                                            
-------------------------------------------------------------------------------
--                                                                            
--           Notes:                                                           
--                                                                            
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use work.gem_board_config_package.CFG_GEM_STATION;
use work.gem_board_config_package.CFG_LPGBT_2P56G_LOOPBACK_TEST;

--============================================================================
--                                                         Package declaration
--============================================================================
package system_package is

  constant g_NUM_OF_GTH_COMMONs : integer := 17;
  constant g_NUM_OF_GTH_GTs     : integer := 68;

  type t_gth_link_type is (gth_null, gth_4p8g, gth_3p2g, gth_10p24g, gth_tx_10p24g_rx_3p2g, gth_9p6g, gth_2p56g); -- the 3.2Gbps and 9.6Gbps are 8b10b, while 4.8, 10.24, and 2.56Gbps are raw (used with GBT core)
  type t_gth_txusrclk is (GTH_USRCLK_40, GTH_USRCLK_80, GTH_USRCLK_120, GTH_USRCLK_160, GTH_USRCLK_320, GTH_USRCLK_NULL);

  type t_gth_config is
  record
    gth_link_type        : t_gth_link_type;
    gth_txclk_out_master : boolean;
    gth_txusrclk         : t_gth_txusrclk;
    gth_txusrclk2        : t_gth_txusrclk;
  end record;

  type t_gth_config_arr is array (0 to 67) of t_gth_config;
  function get_gth_config_arr(gem_station: integer; lpgbt_loopback: boolean; ge11_gth_config, ge21_gth_config, me0_gth_config, lpgbt_loopback_config : t_gth_config_arr) return t_gth_config_arr;

  constant c_ge11_ge21_gth_config_arr : t_gth_config_arr := (
    ---=== CXP 0 ===---
    (gth_4p8g, TRUE, GTH_USRCLK_120, GTH_USRCLK_120),                   -- GTH FW Ch 0
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 1
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 2
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 3
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 4
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 5
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 6
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 7
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 8
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 9
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 10
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 11

    ---=== CXP 1 ===---
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 12
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 13
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 14
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 15
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 16
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 17
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 18
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 19
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 20
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 21
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 22
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 23

    ---=== CXP 2 ===---
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 24
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 25
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 26
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 27
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 28
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 29
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 30
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 31
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 32
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 33
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 34
    (gth_4p8g, false, GTH_USRCLK_120, GTH_USRCLK_120),                  -- GTH FW Ch 35

    ---=== MP 2 ===---
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 36
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 37
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 38
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 39
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 40
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 41
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 42
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 43

    ---=== MP 1 / MP TX ===---
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 44
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 45
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 46
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 47
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 48
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 49
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 50
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 51
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 52
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 53
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 54
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 55

    ---=== MP 2 / MP TX ===---
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 56
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 57
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 58
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 59
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 60
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 61
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 62
    (gth_tx_10p24g_rx_3p2g, false, GTH_USRCLK_320, GTH_USRCLK_160),                  -- GTH FW Ch 63
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                             -- GTH FW Ch 64
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                             -- GTH FW Ch 65
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                             -- GTH FW Ch 66
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320)                              -- GTH FW Ch 67

    );

  constant c_me0_gth_config_arr : t_gth_config_arr := (
    ---=== CXP 0 ===---
    (gth_10p24g, TRUE, GTH_USRCLK_320, GTH_USRCLK_320),                   -- GTH FW Ch 0
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 1
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 2
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 3
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 4
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 5
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 6
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 7
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 8
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 9
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 10
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 11

    ---=== CXP 1 ===---
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 12
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 13
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 14
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 15
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 16
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 17
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 18
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 19
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 20
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 21
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 22
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 23

    ---=== CXP 2 ===---
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 24
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 25
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 26
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 27
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 28
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 29
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 30
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 31
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 32
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 33
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 34
    (gth_10p24g, false, GTH_USRCLK_320, GTH_USRCLK_320),                  -- GTH FW Ch 35

    ---=== MP 2 ===---
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                   -- GTH FW Ch 36
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 37
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 38
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 39
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 40
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 41
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 42
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 43

    ---=== MP 1 / MP TX ===---
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 44
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 45
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 46
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 47
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 48
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 49
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 50
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 51
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 52
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 53
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 54
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 55

    ---=== MP 2 / MP TX ===---
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 56
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 57
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 58
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 59
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 60
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 61
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 62
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 63
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 64
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 65
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 66
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL)                   -- GTH FW Ch 67

    );

  constant c_lpgbt_2p56g_loopback_gth_config_arr : t_gth_config_arr := (
    ---=== CXP 0 ===---
    (gth_2p56g, TRUE, GTH_USRCLK_80, GTH_USRCLK_80),                   -- GTH FW Ch 0
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 1
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 2
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 3
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 4
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 5
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 6
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 7
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 8
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 9
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 10
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 11

    ---=== CXP 1 ===---
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 12
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 13
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 14
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 15
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 16
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 17
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 18
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 19
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 20
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 21
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 22
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 23

    ---=== CXP 2 ===---
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 24
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 25
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 26
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 27
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 28
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 29
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 30
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 31
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 32
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 33
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 34
    (gth_2p56g, false, GTH_USRCLK_80, GTH_USRCLK_80),                  -- GTH FW Ch 35

    ---=== MP 2 ===---
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                   -- GTH FW Ch 36
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 37
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 38
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 39
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 40
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 41
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 42
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 43

    ---=== MP 1 / MP TX ===---
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 44
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 45
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 46
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 47
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 48
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 49
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 50
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 51
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 52
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 53
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 54
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 55

    ---=== MP 2 / MP TX ===---
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 56
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 57
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 58
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 59
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 60
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 61
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 62
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 63
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 64
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 65
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL),                  -- GTH FW Ch 66
    (gth_null, false, GTH_USRCLK_NULL, GTH_USRCLK_NULL)                   -- GTH FW Ch 67

    );

  constant c_gth_config_arr : t_gth_config_arr := get_gth_config_arr(CFG_GEM_STATION, CFG_LPGBT_2P56G_LOOPBACK_TEST, c_ge11_ge21_gth_config_arr, c_ge11_ge21_gth_config_arr, c_me0_gth_config_arr, c_lpgbt_2p56g_loopback_gth_config_arr);

end package system_package;

package body system_package is

    function get_gth_config_arr(gem_station: integer; lpgbt_loopback: boolean; ge11_gth_config, ge21_gth_config, me0_gth_config, lpgbt_loopback_config : t_gth_config_arr) return t_gth_config_arr is
    begin
        if lpgbt_loopback then
            return lpgbt_loopback_config;
        elsif gem_station = 0 then
            return me0_gth_config;
        elsif gem_station = 1 then
            return ge11_gth_config;
        elsif gem_station = 2 then
            return ge21_gth_config;
        else -- hmm whatever, lets say GE1/1
            return ge11_gth_config;  
        end if;
    end function get_gth_config_arr;
    
    
end system_package;
--============================================================================
--                                                                 Package end 
--============================================================================

