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

package mgt_pkg is

    type t_mgt_link_type is (MGT_NULL, MGT_GBTX, MGT_LPGBT, MGT_3P2G_8B10B, MGT_TX_LPGBT_RX_3P2G_8B10B);

    type t_mgt_config is record
        link_type               : t_mgt_link_type;
        use_refclk_01           : integer range 0 to 1;
        use_qpll                : boolean;
        use_qpll_01             : integer range 0 to 1;
        tx_bus_width            : integer range 16 to 64;
        tx_multilane_phalign    : boolean; -- set to true if you want this channel to use a multi-lane phase alignment (with the master channel driving it) 
        rx_use_buf              : boolean;
    --mgt_rx_bus_width     : integer range 16 to 64;
    end record;

    -- NOTE t_mgt_config_arr type should be defined in the board package with the correct length

    type t_drp_in is record
        addr : std_logic_vector(9 downto 0);
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

    type t_mgt_qpll_refclks is record
        gtrefclk0      : std_logic;
        gtrefclk1      : std_logic;
    end record;

    type t_mgt_qpll_clk_out is record
        qpllclk    : std_logic;
        qpllrefclk : std_logic;
    end record;

    type t_mgt_qpll_status is record
        qplllock       : std_logic;
        qpllrefclklost : std_logic;
    end record;

    type t_mgt_refclks is record
        gtrefclk0      : std_logic;
        gtrefclk1      : std_logic;
    end record;

    type t_mgt_clk_in is record
        refclks     : t_mgt_refclks;   
        qpll0clk    : t_mgt_qpll_clk_out;
        qpll1clk    : t_mgt_qpll_clk_out;
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
    end record;

    type t_mgt_rx_fast_ctrl is record
        rxslide        : std_logic;
    end record;

    type t_mgt_rx_init is record
        gtrxreset       : std_logic;
        rxuserrdy       : std_logic;
        rxdfeagchold    : std_logic;
        rxdfeagcovrden  : std_logic;
        rxdfelfhold     : std_logic;
        rxdfelpmreset   : std_logic;
        rxlpmlfklovrden : std_logic;
        rxdfelfovrden   : std_logic;
        rxlpmhfhold     : std_logic;
        rxlpmhfovrden   : std_logic;
        rxlpmlfhold     : std_logic;
        rxdlyen         : std_logic;
        rxdlysreset     : std_logic;
        rxphalign       : std_logic;
        rxphalignen     : std_logic;
        rxphdlyreset    : std_logic;
        rxsyncallin     : std_logic;
        rxsyncin        : std_logic;
        rxsyncmode      : std_logic;
        rxcdrhold       : std_logic;
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
    type t_mgt_qpll_clk_in_arr is array (integer range <>) of t_mgt_qpll_refclks;
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