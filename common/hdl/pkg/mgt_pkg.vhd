------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2020-06-08
-- Module Name:    MGT_PKG
-- Description:    This package defines various types used by the MGT wrappers  
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ttc_pkg.C_TTC_CLK_FREQUENCY;

package mgt_pkg is

    type t_mgt_link_type is (MGT_NULL, MGT_GBTX, MGT_LPGBT, MGT_3P2G_8B10B, MGT_TX_LPGBT_RX_3P2G_8B10B, MGT_DMB, MGT_ODMB57, MGT_GBE);
    type t_mgt_qpll_type is (QPLL_NULL, QPLL_GBTX, QPLL_LPGBT, QPLL_ODMB57_200, QPLL_ODMB57_156, QPLL_DMB_GBE_156, QPLL_GBE_156);

    type t_mgt_type_config is record
        link_type               : t_mgt_link_type;          -- type of MGT to instantiate
        cpll_refclk_01          : integer range 0 to 1;     -- CPLL refclk source to use (0: refclk0, 1: refclk1) 
        qpll0_refclk_01         : integer range 0 to 1;     -- QPLL0 refclk source to use (0: refclk0, 1: refclk1)
        qpll1_refclk_01         : integer range 0 to 1;     -- QPLL1 refclk source to use (0: refclk0, 1: refclk1)
        tx_use_qpll             : boolean;                  -- if true, this MGT channel TX uses QPLL, otherwise CPLL 
        rx_use_qpll             : boolean;                  -- if true, this MGT channel RX uses QPLL, otherwise CPLL
        tx_qpll_01              : integer range 0 to 1;     -- when tx_use_qpll is true, this defines if TX is using QPLL0 or QPLL1
        rx_qpll_01              : integer range 0 to 1;     -- when rx_use_qpll is true, this defines if RX is using QPLL0 or QPLL1
        tx_refclk_freq          : integer;                  -- expected refclk frequency for the TX CPLL or QPLL
        rx_refclk_freq          : integer;                  -- expected refclk frequency for the TX CPLL or QPLL
        tx_bus_width            : integer range 16 to 64;   -- the width of the TX user data bus
        tx_multilane_phalign    : boolean;                  -- set to true if you want this channel to use a multi-lane phase alignment (with the master channel driving it) 
        rx_use_buf              : boolean;                  -- defines if the MGT RX is using elastic buffer or not
        --mgt_rx_bus_width     : integer range 16 to 64;
    end record;

    constant CFG_MGT_TYPE_NULL : t_mgt_type_config := (link_type => MGT_NULL, cpll_refclk_01 => 0, qpll0_refclk_01 => 0, qpll1_refclk_01 => 0, tx_use_qpll => false, rx_use_qpll => false, tx_qpll_01 => 0, rx_qpll_01 => 0, tx_refclk_freq => C_TTC_CLK_FREQUENCY * 4, rx_refclk_freq => C_TTC_CLK_FREQUENCY * 4, tx_bus_width => 16, tx_multilane_phalign => false, rx_use_buf => false); 

    type t_mgt_config is record
        mgt_type                : t_mgt_type_config;    -- MGT type configuration
        qpll_inst_type          : t_mgt_qpll_type;      -- defines which type of QPLL should be instantiated on this MGT channel number (only one per quad should be set to a non QPLL_NULL value)
        qpll_idx                : integer;              -- defines which QPLL index to use on this channel (e.g. if MGT #4 has a non QPLL_NULL value for qpll_inst_type, this should be set to 4 on that channel and also 4 on the other 3 channels that belong to the same quad)
        is_master               : boolean;              -- if true, the TXOUTCLK from this MGT is used to drive the TXUSRCLK of all the other MGTs of the same type (this can only be set to true on one channel of any given type)
        ibert_inst              : boolean;              -- if true, an in-system ibert will be instantiated for this channel
    end record;

    constant CFG_MGT_NULL : t_mgt_config := (mgt_type => CFG_MGT_TYPE_NULL, qpll_inst_type => QPLL_NULL, qpll_idx => 0, is_master => false, ibert_inst => false);

    -- NOTE t_mgt_config_arr type should be defined in the board package with the correct length

    type t_mgt_master_clks is record
        gbt    : std_logic;
        dmb    : std_logic;
        odmb57 : std_logic;
        gbe    : std_logic;
    end record;

    type t_drp_in is record
        addr : std_logic_vector(15 downto 0);
        clk  : std_logic;
        di   : std_logic_vector(15 downto 0);
        en   : std_logic;
        rst  : std_logic;
        we   : std_logic;
    end record;

    constant DRP_IN_NULL : t_drp_in := (addr => (others => '0'), clk => '0', di => (others => '0'), en => '0', rst => '0', we => '0');

    type t_drp_out is record
        do  : std_logic_vector(15 downto 0);
        rdy : std_logic;
    end record;

    type t_mgt_cpll_status is record
        cpllfbclklost  : std_logic;
        cplllock       : std_logic;
        cpllrefclklost : std_logic;
    end record;

    type t_mgt_qpll_clk_out is record
        qpllclk    : std_logic_vector(1 downto 0);
        qpllrefclk : std_logic_vector(1 downto 0);
    end record;

    constant MGT_QPLL_CLK_NULL : t_mgt_qpll_clk_out := (qpllclk => "00", qpllrefclk => "00");

    type t_mgt_qpll_status is record
        qplllock       : std_logic_vector(1 downto 0);
        qpllrefclklost : std_logic_vector(1 downto 0);
        qpllfbclklost  : std_logic_vector(1 downto 0);
    end record;
    
    constant MGT_QPLL_STATUS_NULL : t_mgt_qpll_status := (qplllock => "00", qpllrefclklost => "00", qpllfbclklost => "00");

    type t_mgt_qpll_ctrl is record
        power_down     : std_logic_vector(1 downto 0);
        reset          : std_logic_vector(1 downto 0);
    end record;

    type t_mgt_refclks is record
        gtrefclk0      : std_logic;
        gtrefclk1      : std_logic;
        gtrefclk0_freq : std_logic_vector(31 downto 0);
        gtrefclk1_freq : std_logic_vector(31 downto 0);
    end record;

    type t_mgt_clk_in is record
        refclks     : t_mgt_refclks;   
        qpllclks    : t_mgt_qpll_clk_out;
        rxusrclk    : std_logic;
        rxusrclk2   : std_logic;
        txusrclk    : std_logic;
        txusrclk2   : std_logic;
    end record;

    type t_mgt_clk_out is record
        rxoutclk    : std_logic;
        txoutclk    : std_logic;
        txoutpcs    : std_logic;
        txoutfabric : std_logic;
    end record;

    type t_mgt_tx_slow_ctrl is record
        txpostcursor   : std_logic_vector(4 downto 0);
        txprecursor    : std_logic_vector(4 downto 0);
        txdiffctrl     : std_logic_vector(4 downto 0);
        txinhibit      : std_logic;
        txmaincursor   : std_logic_vector(6 downto 0);
        txpolarity     : std_logic;
        txprbssel      : std_logic_vector(2 downto 0);
        txprbsforceerr : std_logic;
        txpd           : std_logic_vector(1 downto 0);
    end record;

    type t_mgt_tx_init is record
        gttxreset    : std_logic;
        txuserrdy    : std_logic;
        txdlyen      : std_logic;
        txdlysreset  : std_logic;
        txphalign    : std_logic;
        txphalignen  : std_logic;
        txphdlyreset : std_logic;
        txphinit     : std_logic;
        txsyncallin  : std_logic;
        txsyncin     : std_logic;
        txsyncmode   : std_logic;
    end record;

    type t_mgt_tx_status is record
        txresetdone     : std_logic;
        txbufstatus     : std_logic_vector(1 downto 0);
        txpmaresetdone  : std_logic;
        txdlysresetdone : std_logic;
        txphaligndone   : std_logic;
        txphinitdone    : std_logic;
        txsyncout       : std_logic;
        txsyncdone      : std_logic;
    end record;

    type t_mgt_rx_slow_ctrl is record
        rxpolarity     : std_logic;
        rxlpmen        : std_logic;
        rxbufreset     : std_logic;
        rxprbssel      : std_logic_vector(2 downto 0);
        rxpd           : std_logic_vector(1 downto 0);
        rxrate         : std_logic_vector(2 downto 0);
    end record;

    type t_mgt_rx_fast_ctrl is record
        rxslide        : std_logic;
    end record;

    type t_mgt_rx_init is record
        gtrxreset       : std_logic;
        rxuserrdy       : std_logic;
        rxdlysreset     : std_logic;
        rxphalign       : std_logic;
        rxphalignen     : std_logic;
        rxphdlyreset    : std_logic;
        rxsyncallin     : std_logic;
        rxsyncin        : std_logic;
        rxsyncmode      : std_logic;
    end record;

    type t_mgt_rx_status is record
        rxprbserr       : std_logic;
        rxbufstatus     : std_logic_vector(2 downto 0);
        rxclkcorcnt     : std_logic_vector(1 downto 0);
        rxresetdone     : std_logic;
        rxpmaresetdone  : std_logic;
        rxdlysresetdone : std_logic;
        rxphaligndone   : std_logic;
        rxsyncdone      : std_logic;
        rxsyncout       : std_logic;
    end record;

    type t_mgt_misc_ctrl is record
        loopback       : std_logic_vector(2 downto 0);
        eyescanreset   : std_logic;
        eyescantrigger : std_logic;
    end record;

    type t_mgt_misc_status is record
        eyescandataerror : std_logic;
        powergood        : std_logic;
    end record;

    type t_drp_in_arr is array (integer range <>) of t_drp_in;
    type t_drp_out_arr is array (integer range <>) of t_drp_out;

    type t_mgt_qpll_clk_out_arr is array (integer range <>) of t_mgt_qpll_clk_out;
    type t_mgt_qpll_ctrl_arr is array (integer range <>) of t_mgt_qpll_ctrl;
    type t_mgt_qpll_status_arr is array (integer range <>) of t_mgt_qpll_status;

    type t_mgt_cpll_status_arr is array (integer range <>) of t_mgt_cpll_status;

    type t_mgt_refclks_arr is array (integer range <>) of t_mgt_refclks;
    type t_mgt_clk_in_arr is array (integer range <>) of t_mgt_clk_in;
    type t_mgt_clk_out_arr is array (integer range <>) of t_mgt_clk_out;
    type t_mgt_tx_slow_ctrl_arr is array (integer range <>) of t_mgt_tx_slow_ctrl;
    type t_mgt_tx_status_arr is array (integer range <>) of t_mgt_tx_status;
    type t_mgt_rx_slow_ctrl_arr is array (integer range <>) of t_mgt_rx_slow_ctrl;
    type t_mgt_rx_fast_ctrl_arr is array (integer range <>) of t_mgt_rx_fast_ctrl;
    type t_mgt_rx_status_arr is array (integer range <>) of t_mgt_rx_status;
    type t_mgt_misc_ctrl_arr is array (integer range <>) of t_mgt_misc_ctrl;
    type t_mgt_misc_status_arr is array (integer range <>) of t_mgt_misc_status;
    type t_mgt_tx_init_arr is array (integer range <>) of t_mgt_tx_init;
    type t_mgt_rx_init_arr is array (integer range <>) of t_mgt_rx_init;

end mgt_pkg;