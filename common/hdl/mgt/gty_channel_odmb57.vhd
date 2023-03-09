------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2021-03-09
-- Module Name:    GTY_CHANNEL_ODMB57
-- Description:    This is a wrapper for a single GTY channel that can be used with ODMB5 and ODMB7 boards:
--                 Receiver is 8b10b encoded 12.5Gb/s with elastic buffers
--                 Transmitter is a GBTX link (4.8Gb/s raw without buffers)
--                 This MGT should be used with a QPLL0 for the receiver, and QPLL1 or CPLL for the transmitter (refclk is a multiple of LHC freq)
--                 Receiver user data bus width is 64 bits @ 156.25MHz (note rxusrclk is 312.5MHz, rxusrclk2 is 156.25MHz)
--                 Transmitter user data bus witdth is 40 bits @ 120MHz 
------------------------------------------------------------------------------------------------------------------------------------------------------

-- expected refclk is 160MHz
-- txoutclk 

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

use work.common_pkg.all;
use work.mgt_pkg.all;

entity gty_channel_odmb57 is
    generic(
        g_CPLL_REFCLK_01    : integer range 0 to 1 := 0;
        g_TX_USE_QPLL       : boolean := FALSE; -- when set to true the QPLL is used for TX
        g_RX_USE_QPLL       : boolean := FALSE; -- when set to true the QPLL is used for RX
        g_TX_QPLL_01        : integer range 0 to 1 := 0; -- defines whether QPLL0 or QPLL1 is used for TX
        g_RX_QPLL_01        : integer range 0 to 1 := 0; -- defines whether QPLL0 or QPLL1 is used for RX
        g_TXOUTCLKSEL       : std_logic_vector(2 downto 0) := "011"; -- straight refclk by default
        g_RXOUTCLKSEL       : std_logic_vector(2 downto 0) := "010"; -- recovered clock by default
        g_TX_REFCLK_FREQ    : integer; -- RX refclk frequency
        g_RX_REFCLK_FREQ    : integer; -- TX refclk frequency
        g_USE_TX_SYNC       : boolean := true -- set to true if using tx multilane phase alignment (default)
    );
    port(
        
        clk_stable_i    : in  std_logic;
        
        clks_i          : in  t_mgt_clk_in;
        clks_o          : out t_mgt_clk_out;
        
        cpllreset_i     : in  std_logic;
        cpll_status_o   : out t_mgt_cpll_status;
        
        drp_clk_i       : in  std_logic;
        drp_i           : in  t_drp_mosi;
        drp_o           : out t_drp_miso;
        
        tx_slow_ctrl_i  : in  t_mgt_tx_slow_ctrl;
        tx_init_i       : in  t_mgt_tx_init;
        tx_status_o     : out t_mgt_tx_status;
        
        rx_slow_ctrl_i  : in  t_mgt_rx_slow_ctrl;
        rx_fast_ctrl_i  : in  t_mgt_rx_fast_ctrl;
        rx_init_i       : in  t_mgt_rx_init;
        rx_status_o     : out t_mgt_rx_status;
        
        misc_ctrl_i     : in  t_mgt_misc_ctrl;
        misc_status_o   : out t_mgt_misc_status;
        
        tx_data_i       : in  t_mgt_64b_tx_data;
        rx_data_o       : out t_mgt_64b_rx_data
    );
end gty_channel_odmb57;

architecture gty_channel_odmb57_arch of gty_channel_odmb57 is

    -- selects the TX_CLK25_DIV and RX_CLK25_DIV based on the refclk frequency
    function get_txrx_clk25_div(rx_refclk_freq : integer) return integer is
    begin
        if rx_refclk_freq <= 25_000_000 then
            return 1;
        elsif rx_refclk_freq <= 50_000_000 then
            return 2;  
        elsif rx_refclk_freq <= 75_000_000 then
            return 3;  
        elsif rx_refclk_freq <= 100_000_000 then
            return 4;  
        elsif rx_refclk_freq <= 125_000_000 then
            return 5;  
        elsif rx_refclk_freq <= 150_000_000 then
            return 6;  
        elsif rx_refclk_freq <= 175_000_000 then
            return 7;  
        elsif rx_refclk_freq <= 200_000_000 then
            return 8;  
        elsif rx_refclk_freq <= 225_000_000 then
            return 9;  
        elsif rx_refclk_freq <= 250_000_000 then
            return 10;  
        elsif rx_refclk_freq <= 275_000_000 then
            return 11;  
        elsif rx_refclk_freq <= 300_000_000 then
            return 12;  
        elsif rx_refclk_freq <= 325_000_000 then
            return 13;  
        elsif rx_refclk_freq <= 350_000_000 then
            return 14;  
        elsif rx_refclk_freq <= 375_000_000 then
            return 15;  
        elsif rx_refclk_freq <= 400_000_000 then
            return 16;  
        end if;
    end function get_txrx_clk25_div;  
    
    -- selects the TXOUT_DIV based on if we're using a CPLL or a QPLL
    function get_txout_div(use_qpll : boolean) return integer is
    begin
        if use_qpll then
            return 2;
        else
            return 1;  
        end if;
    end function get_txout_div;    

    -- selects the TX_PROGDIV_CFG based on if we're using a CPLL or a QPLL
    function get_tx_progdiv_cfg(use_qpll : boolean) return real is
    begin
        if use_qpll then
            return 40.0;
        else
            return 20.0;  
        end if;
    end function get_tx_progdiv_cfg;    

    -- selects various std_logic_vector parameters based on if we're using a CPLL or a QPLL
    function get_slv_param(param_name : string; use_qpll : boolean) return std_logic_vector is
    begin
        if use_qpll then
            if param_name = "TXPH_CFG" then
                return "0000011100100011";
            elsif param_name = "TXPI_CFG1" then
                return "0001000000000000";
            end if;
        else
            if param_name = "TXPH_CFG" then
                return "0000001100100011";
            elsif param_name = "TXPI_CFG1" then
                return "0111010101010101";
            end if;
        end if;
    end function get_slv_param;    


    constant TX_CLK25_DIV       : integer := get_txrx_clk25_div(g_TX_REFCLK_FREQ);
    constant RX_CLK25_DIV       : integer := get_txrx_clk25_div(g_RX_REFCLK_FREQ);
    constant TXOUT_DIV          : integer := get_txout_div(g_TX_USE_QPLL);
    constant TX_PROGDIV_CFG     : real := get_tx_progdiv_cfg(g_TX_USE_QPLL);
    constant TXPH_CFG           : std_logic_vector(15 downto 0) := get_slv_param("TXPH_CFG", g_TX_USE_QPLL);
    constant TXPI_CFG1          : std_logic_vector(15 downto 0) := get_slv_param("TXPI_CFG1", g_TX_USE_QPLL);
    
    -- clocking
    signal refclks              : std_logic_vector(1 downto 0);
    signal qpllclks             : std_logic_vector(1 downto 0);
    signal qpllrefclks          : std_logic_vector(1 downto 0);
    signal rxsysclksel          : std_logic_vector(1 downto 0);
    signal txsysclksel          : std_logic_vector(1 downto 0);
    signal txpllclksel          : std_logic_vector(1 downto 0);
    signal rxpllclksel          : std_logic_vector(1 downto 0);
    signal cpllpd               : std_logic;
    signal cpllreset            : std_logic;
    signal cplllocken           : std_logic;
    signal txprogdivreset       : std_logic;
    signal txprogdivresetdone   : std_logic;
    signal rxprogdivreset       : std_logic;
    signal rxprogdivresetdone   : std_logic;

    -- fake floating clock
    signal float_clk            : std_logic;
                                
    -- tx data                  
    signal txdata               : std_logic_vector(127 downto 0);
    signal txctrl0              : std_logic_vector(15 downto 0);
    signal txctrl1              : std_logic_vector(15 downto 0);
    signal txctrl2              : std_logic_vector(7 downto 0);
                                
    -- rx data                  
    signal rxdata               : std_logic_vector(127 downto 0);
    signal rxctrl0              : std_logic_vector(15 downto 0);
    signal rxctrl1              : std_logic_vector(15 downto 0);
    signal rxctrl2              : std_logic_vector(7 downto 0);
    signal rxctrl3              : std_logic_vector(7 downto 0);
    
begin

    -- Do not support RXPROGDIV, this is because it's sourced from CDR, so generally we don't want to use it, and also this requires updating the reset FSM to reset the RXPROGDIV after CDRLOCK goes high (this of course can be implemented later if needed)
    assert g_RXOUTCLKSEL /= "101" report "Using RXPROGDIV is not supported, because it's sourced from CDR, so normally we don't want to use it" severity failure;

    -- CPLL clock selection
    g_cpll_ref_clk0 : if g_CPLL_REFCLK_01 = 0 generate
        refclks(0) <= clks_i.refclks.gtrefclk0;
    end generate;
    
    g_cpll_ref_clk1 : if g_CPLL_REFCLK_01 = 1 generate
        refclks(1) <= clks_i.refclks.gtrefclk1;
    end generate;

    -- CPLL is used
    g_cpll_used : if (not g_TX_USE_QPLL) or (not g_RX_USE_QPLL) generate
        cpllreset <= '0';
        cplllocken <= '1';
        cpllpd <= cpllreset_i;
    end generate;

    -- CPLL not used
    g_cpll_not_used : if g_TX_USE_QPLL and g_RX_USE_QPLL generate
        cpllpd <= '1';
        cpllreset <= '1';
        cplllocken <= '0';
    end generate;

    -- QPLL is used
    g_qpll_used : if g_TX_USE_QPLL or g_RX_USE_QPLL generate
        qpllclks(0) <= clks_i.qpllclks.qpllclk(0);
        qpllrefclks(0) <= clks_i.qpllclks.qpllrefclk(0);
        qpllclks(1) <= clks_i.qpllclks.qpllclk(1);
        qpllrefclks(1) <= clks_i.qpllclks.qpllrefclk(1);
    end generate;

    -- TX CPLL
    g_tx_cpll : if not g_TX_USE_QPLL generate
        txsysclksel <= "00";
        txpllclksel <= "00";
    end generate;

    -- RX CPLL
    g_rx_cpll : if not g_RX_USE_QPLL generate
        rxsysclksel <= "00";
        rxpllclksel <= "00";
    end generate;

    -- TX QPLL0
    g_tx_qpll0 : if g_TX_USE_QPLL and g_TX_QPLL_01 = 0 generate
        txsysclksel <= "10";
        txpllclksel <= "11";
    end generate;

    -- RX QPLL0
    g_rx_qpll0 : if g_RX_USE_QPLL and g_RX_QPLL_01 = 0 generate
        rxsysclksel <= "10";
        rxpllclksel <= "11";
    end generate;

    -- TX QPLL1
    g_tx_qpll1 : if g_TX_USE_QPLL and g_TX_QPLL_01 = 1 generate
        txsysclksel <= "11";
        txpllclksel <= "10";
    end generate;

    -- RX QPLL1
    g_rx_qpll1 : if g_RX_USE_QPLL and g_RX_QPLL_01 = 1 generate
        rxsysclksel <= "11";
        rxpllclksel <= "10";
    end generate;

    -- TXPROGDIV is used
    g_txprogdiv_used : if g_TXOUTCLKSEL = "101" generate
        txprogdivreset <= tx_init_i.txprogdivreset;
        tx_status_o.txprogdivresetdone <= txprogdivresetdone;
    end generate;

    -- TXPROGDIV is not used
    g_txprogdiv_not_used : if g_TXOUTCLKSEL /= "101" generate
        txprogdivreset <= '0';
        tx_status_o.txprogdivresetdone <= '1';
    end generate;

    -- RXPROGDIV is used
    g_rxprogdiv_used : if g_RXOUTCLKSEL = "101" generate
        rxprogdivreset <= rx_init_i.rxprogdivreset;
        rx_status_o.rxprogdivresetdone <= rxprogdivresetdone;
    end generate;

    -- RXPROGDIV is not used
    g_rxprogdiv_not_used : if g_RXOUTCLKSEL /= "101" generate
        rxprogdivreset <= '0';
        rx_status_o.rxprogdivresetdone <= '1';
    end generate;

    -- TX: raw encoding 40 bit wide data bus
    txdata(31 downto 0) <= tx_data_i.txdata(37 downto 30) &
                           tx_data_i.txdata(27 downto 20) &
                           tx_data_i.txdata(17 downto 10) &
                           tx_data_i.txdata(7 downto 0);
                           
    txctrl0(3 downto 0) <= tx_data_i.txdata(38) &
                           tx_data_i.txdata(28) &
                           tx_data_i.txdata(18) &
                           tx_data_i.txdata(8);

    txctrl1(3 downto 0) <= tx_data_i.txdata(39) &
                           tx_data_i.txdata(29) &
                           tx_data_i.txdata(19) &
                           tx_data_i.txdata(9);
    
    txdata(127 downto 32) <= (others => '0');
    txctrl0(15 downto 4) <= (others => '0');
    txctrl1(15 downto 4) <= (others => '0');
    txctrl2 <= (others => '0');        
        
    -- RX: 8b10b encoding 64bit wide data bus
    rx_data_o.rxdata(63 downto 0) <= rxdata(63 downto 0);
    
    rx_data_o.rxcharisk(7 downto 0) <= rxctrl0(7 downto 0);
    rx_data_o.rxdisperr(7 downto 0) <= rxctrl1(7 downto 0);
    rx_data_o.rxchariscomma(7 downto 0) <= rxctrl2(7 downto 0);
    rx_data_o.rxnotintable(7 downto 0) <= rxctrl3(7 downto 0);

    i_gty_channel : GTYE4_CHANNEL
        generic map(
            ACJTAG_DEBUG_MODE            => '0',
            ACJTAG_MODE                  => '0',
            ACJTAG_RESET                 => '0',
            ADAPT_CFG0                   => "0000000000000000",
            ADAPT_CFG1                   => "1111101100011100",
            ADAPT_CFG2                   => "0000000000000000",
            ALIGN_COMMA_DOUBLE           => "FALSE",
            ALIGN_COMMA_ENABLE           => "1111111111",
            ALIGN_COMMA_WORD             => 2,
            ALIGN_MCOMMA_DET             => "TRUE",
            ALIGN_MCOMMA_VALUE           => "1010000011",
            ALIGN_PCOMMA_DET             => "TRUE",
            ALIGN_PCOMMA_VALUE           => "0101111100",
            A_RXOSCALRESET               => '0',
            A_RXPROGDIVRESET             => '0',
            A_RXTERMINATION              => '1',
            A_TXDIFFCTRL                 => "01100",
            A_TXPROGDIVRESET             => '0',
            CBCC_DATA_SOURCE_SEL         => "DECODED",
            CDR_SWAP_MODE_EN             => '0',
            CFOK_PWRSVE_EN               => '1',
            CHAN_BOND_KEEP_ALIGN         => "FALSE",
            CHAN_BOND_MAX_SKEW           => 1,
            CHAN_BOND_SEQ_1_1            => "0000000000",
            CHAN_BOND_SEQ_1_2            => "0000000000",
            CHAN_BOND_SEQ_1_3            => "0000000000",
            CHAN_BOND_SEQ_1_4            => "0000000000",
            CHAN_BOND_SEQ_1_ENABLE       => "1111",
            CHAN_BOND_SEQ_2_1            => "0000000000",
            CHAN_BOND_SEQ_2_2            => "0000000000",
            CHAN_BOND_SEQ_2_3            => "0000000000",
            CHAN_BOND_SEQ_2_4            => "0000000000",
            CHAN_BOND_SEQ_2_ENABLE       => "1111",
            CHAN_BOND_SEQ_2_USE          => "FALSE",
            CHAN_BOND_SEQ_LEN            => 1,
            CH_HSPMUX                    => "0010000001000000",
            CKCAL1_CFG_0                 => "1100000011000000",
            CKCAL1_CFG_1                 => "0001000011000000",
            CKCAL1_CFG_2                 => "0010000000001000",
            CKCAL1_CFG_3                 => "0000000000000000",
            CKCAL2_CFG_0                 => "1100000011000000",
            CKCAL2_CFG_1                 => "1000000011000000",
            CKCAL2_CFG_2                 => "0001000000000000",
            CKCAL2_CFG_3                 => "0000000000000000",
            CKCAL2_CFG_4                 => "0000000000000000",
            CLK_CORRECT_USE              => "TRUE",
            CLK_COR_KEEP_IDLE            => "FALSE",
            CLK_COR_MAX_LAT              => 29,
            CLK_COR_MIN_LAT              => 24,
            CLK_COR_PRECEDENCE           => "TRUE",
            CLK_COR_REPEAT_WAIT          => 0,
            CLK_COR_SEQ_1_1              => "0110111100",
            CLK_COR_SEQ_1_2              => "0001010000",
            CLK_COR_SEQ_1_3              => "0000000000",
            CLK_COR_SEQ_1_4              => "0000000000",
            CLK_COR_SEQ_1_ENABLE         => "1111",
            CLK_COR_SEQ_2_1              => "0000000000",
            CLK_COR_SEQ_2_2              => "0000000000",
            CLK_COR_SEQ_2_3              => "0000000000",
            CLK_COR_SEQ_2_4              => "0000000000",
            CLK_COR_SEQ_2_ENABLE         => "1111",
            CLK_COR_SEQ_2_USE            => "FALSE",
            CLK_COR_SEQ_LEN              => 2,
            CPLL_CFG0                    => "0000000111111010",
            CPLL_CFG1                    => "0000000000101011",
            CPLL_CFG2                    => "0000000000000010",
            CPLL_CFG3                    => "0000000000000000",
            CPLL_FBDIV                   => 3, -- keep
            CPLL_FBDIV_45                => 5, -- keep
            CPLL_INIT_CFG0               => "0000001010110010",
            CPLL_LOCK_CFG                => "0000000111101000",
            CPLL_REFCLK_DIV              => 1, -- keep
            CTLE3_OCAP_EXT_CTRL          => "000",
            CTLE3_OCAP_EXT_EN            => '0',
            DDI_CTRL                     => "00",
            DDI_REALIGN_WAIT             => 15,
            DEC_MCOMMA_DETECT            => "TRUE",
            DEC_PCOMMA_DETECT            => "TRUE",
            DEC_VALID_COMMA_ONLY         => "FALSE",
            DELAY_ELEC                   => '0',
            DMONITOR_CFG0                => "0000000000",
            DMONITOR_CFG1                => "00000000",
            ES_CLK_PHASE_SEL             => '0',
            ES_CONTROL                   => "000000",
            ES_ERRDET_EN                 => "FALSE",
            ES_EYE_SCAN_EN               => "FALSE",
            ES_HORZ_OFFSET               => "000000000000",
            ES_PRESCALE                  => "00000",
            ES_QUALIFIER0                => "0000000000000000",
            ES_QUALIFIER1                => "0000000000000000",
            ES_QUALIFIER2                => "0000000000000000",
            ES_QUALIFIER3                => "0000000000000000",
            ES_QUALIFIER4                => "0000000000000000",
            ES_QUALIFIER5                => "0000000000000000",
            ES_QUALIFIER6                => "0000000000000000",
            ES_QUALIFIER7                => "0000000000000000",
            ES_QUALIFIER8                => "0000000000000000",
            ES_QUALIFIER9                => "0000000000000000",
            ES_QUAL_MASK0                => "0000000000000000",
            ES_QUAL_MASK1                => "0000000000000000",
            ES_QUAL_MASK2                => "0000000000000000",
            ES_QUAL_MASK3                => "0000000000000000",
            ES_QUAL_MASK4                => "0000000000000000",
            ES_QUAL_MASK5                => "0000000000000000",
            ES_QUAL_MASK6                => "0000000000000000",
            ES_QUAL_MASK7                => "0000000000000000",
            ES_QUAL_MASK8                => "0000000000000000",
            ES_QUAL_MASK9                => "0000000000000000",
            ES_SDATA_MASK0               => "0000000000000000",
            ES_SDATA_MASK1               => "0000000000000000",
            ES_SDATA_MASK2               => "0000000000000000",
            ES_SDATA_MASK3               => "0000000000000000",
            ES_SDATA_MASK4               => "0000000000000000",
            ES_SDATA_MASK5               => "0000000000000000",
            ES_SDATA_MASK6               => "0000000000000000",
            ES_SDATA_MASK7               => "0000000000000000",
            ES_SDATA_MASK8               => "0000000000000000",
            ES_SDATA_MASK9               => "0000000000000000",
            EYESCAN_VP_RANGE             => 0,
            EYE_SCAN_SWAP_EN             => '0',
            FTS_DESKEW_SEQ_ENABLE        => "1111",
            FTS_LANE_DESKEW_CFG          => "1111",
            FTS_LANE_DESKEW_EN           => "FALSE",
            GEARBOX_MODE                 => "00000",
            ISCAN_CK_PH_SEL2             => '0',
            LOCAL_MASTER                 => '1',
            LPBK_BIAS_CTRL               => 4,
            LPBK_EN_RCAL_B               => '0',
            LPBK_EXT_RCAL                => "1000",
            LPBK_IND_CTRL0               => 5,
            LPBK_IND_CTRL1               => 5,
            LPBK_IND_CTRL2               => 5,
            LPBK_RG_CTRL                 => 2,
            OOBDIVCTL                    => "00",
            OOB_PWRUP                    => '0',
            PCI3_AUTO_REALIGN            => "OVR_1K_BLK",
            PCI3_PIPE_RX_ELECIDLE        => '0',
            PCI3_RX_ASYNC_EBUF_BYPASS    => "00",
            PCI3_RX_ELECIDLE_EI2_ENABLE  => '0',
            PCI3_RX_ELECIDLE_H2L_COUNT   => "000000",
            PCI3_RX_ELECIDLE_H2L_DISABLE => "000",
            PCI3_RX_ELECIDLE_HI_COUNT    => "000000",
            PCI3_RX_ELECIDLE_LP4_DISABLE => '0',
            PCI3_RX_FIFO_DISABLE         => '0',
            PCIE3_CLK_COR_EMPTY_THRSH    => "00000",
            PCIE3_CLK_COR_FULL_THRSH     => "010000",
            PCIE3_CLK_COR_MAX_LAT        => "00100",
            PCIE3_CLK_COR_MIN_LAT        => "00000",
            PCIE3_CLK_COR_THRSH_TIMER    => "001000",
            PCIE_64B_DYN_CLKSW_DIS       => "FALSE",
            PCIE_BUFG_DIV_CTRL           => "0001000000000000",
            PCIE_GEN4_64BIT_INT_EN       => "FALSE",
            PCIE_PLL_SEL_MODE_GEN12      => "11",
            PCIE_PLL_SEL_MODE_GEN3       => "11",
            PCIE_PLL_SEL_MODE_GEN4       => "10",
            PCIE_RXPCS_CFG_GEN3          => "0000101010100101",
            PCIE_RXPMA_CFG               => "0010100000001010",
            PCIE_TXPCS_CFG_GEN3          => "0010010010100100",
            PCIE_TXPMA_CFG               => "0010100000001010",
            PCS_PCIE_EN                  => "FALSE",
            PCS_RSVD0                    => "0000000000000000",
            PD_TRANS_TIME_FROM_P2        => "000000111100",
            PD_TRANS_TIME_NONE_P2        => "00011001",
            PD_TRANS_TIME_TO_P2          => "01100100",
            PREIQ_FREQ_BST               => 1,
            RATE_SW_USE_DRP              => '1',
            RCLK_SIPO_DLY_ENB            => '0',
            RCLK_SIPO_INV_EN             => '0',
            RTX_BUF_CML_CTRL             => "100",
            RTX_BUF_TERM_CTRL            => "00",
            RXBUFRESET_TIME              => "00011",
            RXBUF_ADDR_MODE              => "FULL",
            RXBUF_EIDLE_HI_CNT           => "1000",
            RXBUF_EIDLE_LO_CNT           => "0000",
            RXBUF_EN                     => "TRUE",
            RXBUF_RESET_ON_CB_CHANGE     => "TRUE",
            RXBUF_RESET_ON_COMMAALIGN    => "FALSE",
            RXBUF_RESET_ON_EIDLE         => "FALSE",
            RXBUF_RESET_ON_RATE_CHANGE   => "TRUE",
            RXBUF_THRESH_OVFLW           => 0,
            RXBUF_THRESH_OVRD            => "FALSE",
            RXBUF_THRESH_UNDFLW          => 4,
            RXCDRFREQRESET_TIME          => "00001",
            RXCDRPHRESET_TIME            => "00001",
            RXCDR_CFG0                   => "0000000000000011",
            RXCDR_CFG0_GEN3              => "0000000000000011",
            RXCDR_CFG1                   => "0000000000000000",
            RXCDR_CFG1_GEN3              => "0000000000000000",
            RXCDR_CFG2                   => "0000000111101001",
            RXCDR_CFG2_GEN2              => "1001101001",
            RXCDR_CFG2_GEN3              => "0000001001101001",
            RXCDR_CFG2_GEN4              => "0000000101100100",
            RXCDR_CFG3                   => "0000000000100011",
            RXCDR_CFG3_GEN2              => "100011",
            RXCDR_CFG3_GEN3              => "0000000000100011",
            RXCDR_CFG3_GEN4              => "0000000000100011",
            RXCDR_CFG4                   => "0101110011110110",
            RXCDR_CFG4_GEN3              => "0101110011110110",
            RXCDR_CFG5                   => "1011010001101011",
            RXCDR_CFG5_GEN3              => "0001010001101011",
            RXCDR_FR_RESET_ON_EIDLE      => '0',
            RXCDR_HOLD_DURING_EIDLE      => '0',
            RXCDR_LOCK_CFG0              => "0010001000000001",
            RXCDR_LOCK_CFG1              => "1001111111111111",
            RXCDR_LOCK_CFG2              => "0000000000000000",
            RXCDR_LOCK_CFG3              => "0000000000000000",
            RXCDR_LOCK_CFG4              => "0000000000000000",
            RXCDR_PH_RESET_ON_EIDLE      => '0',
            RXCFOK_CFG0                  => "0000000000000000",
            RXCFOK_CFG1                  => "1000000000010101",
            RXCFOK_CFG2                  => "0000001010101110",
            RXCKCAL1_IQ_LOOP_RST_CFG     => "0000000000000000",
            RXCKCAL1_I_LOOP_RST_CFG      => "0000000000000000",
            RXCKCAL1_Q_LOOP_RST_CFG      => "0000000000000000",
            RXCKCAL2_DX_LOOP_RST_CFG     => "0000000000000000",
            RXCKCAL2_D_LOOP_RST_CFG      => "0000000000000000",
            RXCKCAL2_S_LOOP_RST_CFG      => "0000000000000000",
            RXCKCAL2_X_LOOP_RST_CFG      => "0000000000000000",
            RXDFELPMRESET_TIME           => "0001111",
            RXDFELPM_KL_CFG0             => "0000000000000000",
            RXDFELPM_KL_CFG1             => "1010000010000010",
            RXDFELPM_KL_CFG2             => "0000000100000000",
            RXDFE_CFG0                   => "0000101000000000",
            RXDFE_CFG1                   => "0000000000000000",
            RXDFE_GC_CFG0                => "0000000000000000",
            RXDFE_GC_CFG1                => "1000000000000000",
            RXDFE_GC_CFG2                => "1111111111100000",
            RXDFE_H2_CFG0                => "0000000000000000",
            RXDFE_H2_CFG1                => "0000000000000010",
            RXDFE_H3_CFG0                => "0000000000000000",
            RXDFE_H3_CFG1                => "1000000000000010",
            RXDFE_H4_CFG0                => "0000000000000000",
            RXDFE_H4_CFG1                => "1000000000000010",
            RXDFE_H5_CFG0                => "0000000000000000",
            RXDFE_H5_CFG1                => "1000000000000010",
            RXDFE_H6_CFG0                => "0000000000000000",
            RXDFE_H6_CFG1                => "1000000000000010",
            RXDFE_H7_CFG0                => "0000000000000000",
            RXDFE_H7_CFG1                => "1000000000000010",
            RXDFE_H8_CFG0                => "0000000000000000",
            RXDFE_H8_CFG1                => "1000000000000010",
            RXDFE_H9_CFG0                => "0000000000000000",
            RXDFE_H9_CFG1                => "1000000000000010",
            RXDFE_HA_CFG0                => "0000000000000000",
            RXDFE_HA_CFG1                => "1000000000000010",
            RXDFE_HB_CFG0                => "0000000000000000",
            RXDFE_HB_CFG1                => "1000000000000010",
            RXDFE_HC_CFG0                => "0000000000000000",
            RXDFE_HC_CFG1                => "1000000000000010",
            RXDFE_HD_CFG0                => "0000000000000000",
            RXDFE_HD_CFG1                => "1000000000000010",
            RXDFE_HE_CFG0                => "0000000000000000",
            RXDFE_HE_CFG1                => "1000000000000010",
            RXDFE_HF_CFG0                => "0000000000000000",
            RXDFE_HF_CFG1                => "1000000000000010",
            RXDFE_KH_CFG0                => "1000000000000000",
            RXDFE_KH_CFG1                => "1111111000000000",
            RXDFE_KH_CFG2                => "0000001000000000",
            RXDFE_KH_CFG3                => "0100000100000001",
            RXDFE_OS_CFG0                => "0010000000000000",
            RXDFE_OS_CFG1                => "1000000000000000",
            RXDFE_UT_CFG0                => "0000000000000000",
            RXDFE_UT_CFG1                => "0000000000000011",
            RXDFE_UT_CFG2                => "0000000000000000",
            RXDFE_VP_CFG0                => "0000000000000000",
            RXDFE_VP_CFG1                => "0000000000110011",
            RXDLY_CFG                    => "0000000000010000",
            RXDLY_LCFG                   => "0000000000110000",
            RXELECIDLE_CFG               => "SIGCFG_4",
            RXGBOX_FIFO_INIT_RD_ADDR     => 4,
            RXGEARBOX_EN                 => "FALSE",
            RXISCANRESET_TIME            => "00001",
            RXLPM_CFG                    => "0000000000000000",
            RXLPM_GC_CFG                 => "1111100000000000",
            RXLPM_KH_CFG0                => "0000000000000000",
            RXLPM_KH_CFG1                => "1010000000000010",
            RXLPM_OS_CFG0                => "0000000000000000",
            RXLPM_OS_CFG1                => "1000000000000010",
            RXOOB_CFG                    => "000000110",
            RXOOB_CLK_CFG                => "PMA",
            RXOSCALRESET_TIME            => "00011",
            RXOUT_DIV                    => 1,
            RXPCSRESET_TIME              => "00011",
            RXPHBEACON_CFG               => "0000000000000000",
            RXPHDLY_CFG                  => "0010000001110000",
            RXPHSAMP_CFG                 => "0010000100000000",
            RXPHSLIP_CFG                 => "1001100100110011",
            RXPH_MONITOR_SEL             => "00000",
            RXPI_CFG0                    => "0000000100000010",
            RXPI_CFG1                    => "0000000001010100",
            RXPMACLK_SEL                 => "DATA",
            RXPMARESET_TIME              => "00011",
            RXPRBS_ERR_LOOPBACK          => '0',
            RXPRBS_LINKACQ_CNT           => 15,
            RXREFCLKDIV2_SEL             => '0',
            RXSLIDE_AUTO_WAIT            => 7,
            RXSLIDE_MODE                 => "PMA",
            RXSYNC_MULTILANE             => '0',
            RXSYNC_OVRD                  => '0',
            RXSYNC_SKIP_DA               => '0',
            RX_AFE_CM_EN                 => '0',
            RX_BIAS_CFG0                 => "0001001010110000",
            RX_BUFFER_CFG                => "000000",
            RX_CAPFF_SARC_ENB            => '0',
            RX_CLK25_DIV                 => RX_CLK25_DIV, -- keep
            RX_CLKMUX_EN                 => '1',
            RX_CLK_SLIP_OVRD             => "00000",
            RX_CM_BUF_CFG                => "1010",
            RX_CM_BUF_PD                 => '0',
            RX_CM_SEL                    => 3,
            RX_CM_TRIM                   => 10,
            RX_CTLE_PWR_SAVING           => '0',
            RX_CTLE_RES_CTRL             => "0000",
            RX_DATA_WIDTH                => 80,
            RX_DDI_SEL                   => "000000",
            RX_DEFER_RESET_BUF_EN        => "TRUE",
            RX_DEGEN_CTRL                => "100",
            RX_DFELPM_CFG0               => 10,
            RX_DFELPM_CFG1               => '1',
            RX_DFELPM_KLKH_AGC_STUP_EN   => '1',
            RX_DFE_AGC_CFG1              => 2,
            RX_DFE_KL_LPM_KH_CFG0        => 3,
            RX_DFE_KL_LPM_KH_CFG1        => 2,
            RX_DFE_KL_LPM_KL_CFG0        => "11",
            RX_DFE_KL_LPM_KL_CFG1        => 2,
            RX_DFE_LPM_HOLD_DURING_EIDLE => '0',
            RX_DISPERR_SEQ_MATCH         => "TRUE",
            RX_DIVRESET_TIME             => "00001",
            RX_EN_CTLE_RCAL_B            => '0',
            RX_EN_SUM_RCAL_B             => 0,
            RX_EYESCAN_VS_CODE           => "0000000",
            RX_EYESCAN_VS_NEG_DIR        => '0',
            RX_EYESCAN_VS_RANGE          => "10",
            RX_EYESCAN_VS_UT_SIGN        => '0',
            RX_FABINT_USRCLK_FLOP        => '0',
            RX_I2V_FILTER_EN             => '1',
            RX_INT_DATAWIDTH             => 1,
            RX_PMA_POWER_SAVE            => '0',
            RX_PMA_RSV0                  => "0000000000101111",
            RX_PROGDIV_CFG               => 20.0,
            RX_PROGDIV_RATE              => "0000000000000001",
            RX_RESLOAD_CTRL              => "0000",
            RX_RESLOAD_OVRD              => '0',
            RX_SAMPLE_PERIOD             => "111",
            RX_SIG_VALID_DLY             => 11,
            RX_SUM_DEGEN_AVTT_OVERITE    => 0,
            RX_SUM_DFETAPREP_EN          => '0',
            RX_SUM_IREF_TUNE             => "0000",
            RX_SUM_PWR_SAVING            => 0,
            RX_SUM_RES_CTRL              => "0000",
            RX_SUM_VCMTUNE               => "1001",
            RX_SUM_VCM_BIAS_TUNE_EN      => '1',
            RX_SUM_VCM_OVWR              => '0',
            RX_SUM_VREF_TUNE             => "100",
            RX_TUNE_AFE_OS               => "10",
            RX_VREG_CTRL                 => "010",
            RX_VREG_PDB                  => '1',
            RX_WIDEMODE_CDR              => "01",
            RX_WIDEMODE_CDR_GEN3         => "00",
            RX_WIDEMODE_CDR_GEN4         => "01",
            RX_XCLK_SEL                  => "RXDES",
            RX_XMODE_SEL                 => '0',
            SAMPLE_CLK_PHASE             => '0',
            SAS_12G_MODE                 => '0',
            SATA_BURST_SEQ_LEN           => "1111",
            SATA_BURST_VAL               => "100",
            SATA_CPLL_CFG                => "VCO_3000MHZ",
            SATA_EIDLE_VAL               => "100",
            SHOW_REALIGN_COMMA           => "TRUE",
            SIM_DEVICE                   => "ULTRASCALE_PLUS",
            SIM_MODE                     => "FAST",
            SIM_RECEIVER_DETECT_PASS     => "TRUE",
            SIM_RESET_SPEEDUP            => "TRUE",
            SIM_TX_EIDLE_DRIVE_LEVEL     => "Z",
            SRSTMODE                     => '0',
            TAPDLY_SET_TX                => "00",
            TERM_RCAL_CFG                => "100001000000010",
            TERM_RCAL_OVRD               => "001",
            TRANS_TIME_RATE              => "00001110",
            TST_RSV0                     => "00000000",
            TST_RSV1                     => "00000000",
            TXBUF_EN                     => "FALSE",
            TXBUF_RESET_ON_RATE_CHANGE   => "TRUE",
            TXDLY_CFG                    => "1000000000010000",
            TXDLY_LCFG                   => "0000000000110000",
            TXDRV_FREQBAND               => 0,
            TXFE_CFG0                    => "0000001111000010",
            TXFE_CFG1                    => "0110110000000000",
            TXFE_CFG2                    => "0110110000000000",
            TXFE_CFG3                    => "0110110000000000",
            TXFIFO_ADDR_CFG              => "LOW",
            TXGBOX_FIFO_INIT_RD_ADDR     => 4,
            TXGEARBOX_EN                 => "FALSE",
            TXOUT_DIV                    => TXOUT_DIV, -- keep
            TXPCSRESET_TIME              => "00011",
            TXPHDLY_CFG0                 => "0110000001110000",
            TXPHDLY_CFG1                 => "0000000000001111",
            TXPH_CFG                     => TXPH_CFG, -- keep
            TXPH_CFG2                    => "0000000000000000",
            TXPH_MONITOR_SEL             => "00000",
            TXPI_CFG0                    => "0000001100000000",
            TXPI_CFG1                    => TXPI_CFG1, -- keep
            TXPI_GRAY_SEL                => '0',
            TXPI_INVSTROBE_SEL           => '0',
            TXPI_PPM                     => '0',
            TXPI_PPM_CFG                 => "00000000",
            TXPI_SYNFREQ_PPM             => "001",
            TXPMARESET_TIME              => "00011",
            TXREFCLKDIV2_SEL             => '0',
            TXSWBST_BST                  => 1,
            TXSWBST_EN                   => 0,
            TXSWBST_MAG                  => 4,
            TXSYNC_MULTILANE             => bool_to_bit(g_USE_TX_SYNC), -- keep
            TXSYNC_OVRD                  => '0',
            TXSYNC_SKIP_DA               => '0',
            TX_CLK25_DIV                 => TX_CLK25_DIV, -- keep
            TX_CLKMUX_EN                 => '1',
            TX_DATA_WIDTH                => 40,
            TX_DCC_LOOP_RST_CFG          => "0000000000000100",
            TX_DEEMPH0                   => "000000",
            TX_DEEMPH1                   => "000000",
            TX_DEEMPH2                   => "000000",
            TX_DEEMPH3                   => "000000",
            TX_DIVRESET_TIME             => "00001",
            TX_DRIVE_MODE                => "DIRECT",
            TX_EIDLE_ASSERT_DELAY        => "100",
            TX_EIDLE_DEASSERT_DELAY      => "011",
            TX_FABINT_USRCLK_FLOP        => '0',
            TX_FIFO_BYP_EN               => '1',
            TX_IDLE_DATA_ZERO            => '0',
            TX_INT_DATAWIDTH             => 1,
            TX_LOOPBACK_DRIVE_HIZ        => "FALSE",
            TX_MAINCURSOR_SEL            => '0',
            TX_MARGIN_FULL_0             => "1011000",
            TX_MARGIN_FULL_1             => "1010111",
            TX_MARGIN_FULL_2             => "1010101",
            TX_MARGIN_FULL_3             => "1010011",
            TX_MARGIN_FULL_4             => "1010001",
            TX_MARGIN_LOW_0              => "1001100",
            TX_MARGIN_LOW_1              => "1001011",
            TX_MARGIN_LOW_2              => "1001000",
            TX_MARGIN_LOW_3              => "1000010",
            TX_MARGIN_LOW_4              => "1000000",
            TX_PHICAL_CFG0               => "0000000000100000",
            TX_PHICAL_CFG1               => "0000000001000000",
            TX_PI_BIASSET                => 0,
            TX_PMADATA_OPT               => '0',
            TX_PMA_POWER_SAVE            => '0',
            TX_PMA_RSV0                  => "0000000000000000",
            TX_PMA_RSV1                  => "0000000000000000",
            TX_PROGCLK_SEL               => "PREPI",
            TX_PROGDIV_CFG               => TX_PROGDIV_CFG, -- keep
            TX_PROGDIV_RATE              => "0000000000000001",
            TX_RXDETECT_CFG              => "00000000110010",
            TX_RXDETECT_REF              => 5,
            TX_SAMPLE_PERIOD             => "111",
            TX_SW_MEAS                   => "00",
            TX_VREG_CTRL                 => "011",
            TX_VREG_PDB                  => '1',
            TX_VREG_VREFSEL              => "10",
            TX_XCLK_SEL                  => "TXUSR",
            USB_BOTH_BURST_IDLE          => '0',
            USB_BURSTMAX_U3WAKE          => "1111111",
            USB_BURSTMIN_U3WAKE          => "1100011",
            USB_CLK_COR_EQ_EN            => '0',
            USB_EXT_CNTL                 => '1',
            USB_IDLEMAX_POLLING          => "1010111011",
            USB_IDLEMIN_POLLING          => "0100101011",
            USB_LFPSPING_BURST           => "000000101",
            USB_LFPSPOLLING_BURST        => "000110001",
            USB_LFPSPOLLING_IDLE_MS      => "000000100",
            USB_LFPSU1EXIT_BURST         => "000011101",
            USB_LFPSU2LPEXIT_BURST_MS    => "001100011",
            USB_LFPSU3WAKE_BURST_MS      => "111110011",
            USB_LFPS_TPERIOD             => "0011",
            USB_LFPS_TPERIOD_ACCURATE    => '1',
            USB_MODE                     => '0',
            USB_PCIE_ERR_REP_DIS         => '0',
            USB_PING_SATA_MAX_INIT       => 21,
            USB_PING_SATA_MIN_INIT       => 12,
            USB_POLL_SATA_MAX_BURST      => 8,
            USB_POLL_SATA_MIN_BURST      => 4,
            USB_RAW_ELEC                 => '0',
            USB_RXIDLE_P0_CTRL           => '1',
            USB_TXIDLE_TUNE_ENABLE       => '1',
            USB_U1_SATA_MAX_WAKE         => 7,
            USB_U1_SATA_MIN_WAKE         => 4,
            USB_U2_SAS_MAX_COM           => 64,
            USB_U2_SAS_MIN_COM           => 36,
            USE_PCS_CLK_PHASE_SEL        => '0',
            Y_ALL_MODE                   => '0'
        )
        port map(
            BUFGTCE              => open,
            BUFGTCEMASK          => open,
            BUFGTDIV             => open,
            BUFGTRESET           => open,
            BUFGTRSTMASK         => open,
            CPLLFBCLKLOST        => cpll_status_o.cpllfbclklost,
            CPLLLOCK             => cpll_status_o.cplllock,
            CPLLREFCLKLOST       => cpll_status_o.cpllrefclklost,
            DMONITOROUT          => open,
            DMONITOROUTCLK       => open,
            DRPDO                => drp_o.do,
            DRPRDY               => drp_o.rdy,
            EYESCANDATAERROR     => misc_status_o.eyescandataerror,
            GTPOWERGOOD          => misc_status_o.powergood,
            GTREFCLKMONITOR      => open,
            GTYTXN               => open,
            GTYTXP               => open,
            PCIERATEGEN3         => open,
            PCIERATEIDLE         => open,
            PCIERATEQPLLPD       => open,
            PCIERATEQPLLRESET    => open,
            PCIESYNCTXSYNCDONE   => open,
            PCIEUSERGEN3RDY      => open,
            PCIEUSERPHYSTATUSRST => open,
            PCIEUSERRATESTART    => open,
            PCSRSVDOUT           => open,
            PHYSTATUS            => open,
            PINRSRVDAS           => open,
            POWERPRESENT         => open,
            RESETEXCEPTION       => open,
            RXBUFSTATUS          => rx_status_o.rxbufstatus,
            RXBYTEISALIGNED      => rx_data_o.rxbyteisaligned,
            RXBYTEREALIGN        => rx_data_o.rxbyterealign,
            RXCDRLOCK            => open,
            RXCDRPHDONE          => open,
            RXCHANBONDSEQ        => open,
            RXCHANISALIGNED      => open,
            RXCHANREALIGN        => open,
            RXCHBONDO            => open,
            RXCKCALDONE          => open,
            RXCLKCORCNT          => rx_status_o.rxclkcorcnt,
            RXCOMINITDET         => open,
            RXCOMMADET           => rx_data_o.rxcommadet,
            RXCOMSASDET          => open,
            RXCOMWAKEDET         => open,
            RXCTRL0              => rxctrl0,
            RXCTRL1              => rxctrl1,
            RXCTRL2              => rxctrl2,
            RXCTRL3              => rxctrl3,
            RXDATA               => rxdata,
            RXDATAEXTENDRSVD     => open,
            RXDATAVALID          => open,
            RXDLYSRESETDONE      => rx_status_o.rxdlysresetdone,
            RXELECIDLE           => open,
            RXHEADER             => open,
            RXHEADERVALID        => open,
            RXLFPSTRESETDET      => open,
            RXLFPSU2LPEXITDET    => open,
            RXLFPSU3WAKEDET      => open,
            RXMONITOROUT         => open,
            RXOSINTDONE          => open,
            RXOSINTSTARTED       => open,
            RXOSINTSTROBEDONE    => open,
            RXOSINTSTROBESTARTED => open,
            RXOUTCLK             => clks_o.rxoutclk,
            RXOUTCLKFABRIC       => open,
            RXOUTCLKPCS          => open,
            RXPHALIGNDONE        => rx_status_o.rxphaligndone,
            RXPHALIGNERR         => open,
            RXPMARESETDONE       => rx_status_o.rxpmaresetdone,
            RXPRBSERR            => rx_status_o.rxprbserr,
            RXPRBSLOCKED         => open,
            RXPRGDIVRESETDONE    => rxprogdivresetdone,
            RXRATEDONE           => open,
            RXRECCLKOUT          => open,
            RXRESETDONE          => rx_status_o.rxresetdone,
            RXSLIDERDY           => open,
            RXSLIPDONE           => open,
            RXSLIPOUTCLKRDY      => open,
            RXSLIPPMARDY         => open,
            RXSTARTOFSEQ         => open,
            RXSTATUS             => open,
            RXSYNCDONE           => rx_status_o.rxsyncdone,
            RXSYNCOUT            => rx_status_o.rxsyncout,
            RXVALID              => open,
            TXBUFSTATUS          => tx_status_o.txbufstatus,
            TXCOMFINISH          => open,
            TXDCCDONE            => open,
            TXDLYSRESETDONE      => tx_status_o.txdlysresetdone,
            TXOUTCLK             => clks_o.txoutclk,
            TXOUTCLKFABRIC       => clks_o.txoutfabric,
            TXOUTCLKPCS          => clks_o.txoutpcs,
            TXPHALIGNDONE        => tx_status_o.txphaligndone,
            TXPHINITDONE         => tx_status_o.txphinitdone,
            TXPMARESETDONE       => tx_status_o.txpmaresetdone,
            TXPRGDIVRESETDONE    => txprogdivresetdone,
            TXRATEDONE           => open,
            TXRESETDONE          => tx_status_o.txresetdone,
            TXSYNCDONE           => tx_status_o.txsyncdone,
            TXSYNCOUT            => tx_status_o.txsyncout,
            CDRSTEPDIR           => '0',
            CDRSTEPSQ            => '0',
            CDRSTEPSX            => '0',
            CFGRESET             => '0',
            CLKRSVD0             => '0',
            CLKRSVD1             => '0',
            CPLLFREQLOCK         => '0',
            CPLLLOCKDETCLK       => clk_stable_i,
            CPLLLOCKEN           => cplllocken,
            CPLLPD               => cpllpd,
            CPLLREFCLKSEL        => "001",
            CPLLRESET            => cpllreset,
            DMONFIFORESET        => '0',
            DMONITORCLK          => '0',
            DRPADDR              => drp_i.addr(9 downto 0),
            DRPCLK               => drp_clk_i,
            DRPDI                => drp_i.di,
            DRPEN                => drp_i.en,
            DRPRST               => drp_i.rst,
            DRPWE                => drp_i.we,
            EYESCANRESET         => misc_ctrl_i.eyescanreset,
            EYESCANTRIGGER       => misc_ctrl_i.eyescantrigger,
            FREQOS               => '0',
            GTGREFCLK            => float_clk,
            GTNORTHREFCLK0       => float_clk,
            GTNORTHREFCLK1       => float_clk,
            GTREFCLK0            => refclks(0),
            GTREFCLK1            => refclks(1),
            GTRSVD               => "0000000000000000",
            GTRXRESET            => rx_init_i.gtrxreset,
            GTRXRESETSEL         => '0',
            GTSOUTHREFCLK0       => float_clk,
            GTSOUTHREFCLK1       => float_clk,
            GTTXRESET            => tx_init_i.gttxreset,
            GTTXRESETSEL         => '0',
            GTYRXN               => '0',
            GTYRXP               => '1',
            INCPCTRL             => '0',
            LOOPBACK             => misc_ctrl_i.loopback,
            PCIEEQRXEQADAPTDONE  => '0',
            PCIERSTIDLE          => '0',
            PCIERSTTXSYNCSTART   => '0',
            PCIEUSERRATEDONE     => '0',
            PCSRSVDIN            => "0000000000000000",
            QPLL0CLK             => qpllclks(0),
            QPLL0FREQLOCK        => '0',
            QPLL0REFCLK          => qpllrefclks(0),
            QPLL1CLK             => qpllclks(1),
            QPLL1FREQLOCK        => '0',
            QPLL1REFCLK          => qpllrefclks(1),
            RESETOVRD            => '0',
            RX8B10BEN            => '1',
            RXAFECFOKEN          => '1',
            RXBUFRESET           => rx_slow_ctrl_i.rxbufreset,
            RXCDRFREQRESET       => '0',
            RXCDRHOLD            => '0',
            RXCDROVRDEN          => '0',
            RXCDRRESET           => '0',
            RXCHBONDEN           => '0',
            RXCHBONDI            => "00000",
            RXCHBONDLEVEL        => "000",
            RXCHBONDMASTER       => '0',
            RXCHBONDSLAVE        => '0',
            RXCKCALRESET         => '0',
            RXCKCALSTART         => "0000000",
            RXCOMMADETEN         => '1',
            RXDFEAGCHOLD         => '0',
            RXDFEAGCOVRDEN       => '0',
            RXDFECFOKFCNUM       => "1101",
            RXDFECFOKFEN         => '0',
            RXDFECFOKFPULSE      => '0',
            RXDFECFOKHOLD        => '0',
            RXDFECFOKOVREN       => '0',
            RXDFEKHHOLD          => '0',
            RXDFEKHOVRDEN        => '0',
            RXDFELFHOLD          => '0',
            RXDFELFOVRDEN        => '0',
            RXDFELPMRESET        => '0',
            RXDFETAP10HOLD       => '0',
            RXDFETAP10OVRDEN     => '0',
            RXDFETAP11HOLD       => '0',
            RXDFETAP11OVRDEN     => '0',
            RXDFETAP12HOLD       => '0',
            RXDFETAP12OVRDEN     => '0',
            RXDFETAP13HOLD       => '0',
            RXDFETAP13OVRDEN     => '0',
            RXDFETAP14HOLD       => '0',
            RXDFETAP14OVRDEN     => '0',
            RXDFETAP15HOLD       => '0',
            RXDFETAP15OVRDEN     => '0',
            RXDFETAP2HOLD        => '0',
            RXDFETAP2OVRDEN      => '0',
            RXDFETAP3HOLD        => '0',
            RXDFETAP3OVRDEN      => '0',
            RXDFETAP4HOLD        => '0',
            RXDFETAP4OVRDEN      => '0',
            RXDFETAP5HOLD        => '0',
            RXDFETAP5OVRDEN      => '0',
            RXDFETAP6HOLD        => '0',
            RXDFETAP6OVRDEN      => '0',
            RXDFETAP7HOLD        => '0',
            RXDFETAP7OVRDEN      => '0',
            RXDFETAP8HOLD        => '0',
            RXDFETAP8OVRDEN      => '0',
            RXDFETAP9HOLD        => '0',
            RXDFETAP9OVRDEN      => '0',
            RXDFEUTHOLD          => '0',
            RXDFEUTOVRDEN        => '0',
            RXDFEVPHOLD          => '0',
            RXDFEVPOVRDEN        => '0',
            RXDFEXYDEN           => '1',
            RXDLYBYPASS          => '1',
            RXDLYEN              => '0',
            RXDLYOVRDEN          => '0',
            RXDLYSRESET          => '0',
            RXELECIDLEMODE       => "11",
            RXEQTRAINING         => '0',
            RXGEARBOXSLIP        => '0',
            RXLATCLK             => '0',
            RXLPMEN              => rx_slow_ctrl_i.rxlpmen,
            RXLPMGCHOLD          => '0',
            RXLPMGCOVRDEN        => '0',
            RXLPMHFHOLD          => '0',
            RXLPMHFOVRDEN        => '0',
            RXLPMLFHOLD          => '0',
            RXLPMLFKLOVRDEN      => '0',
            RXLPMOSHOLD          => '0',
            RXLPMOSOVRDEN        => '0',
            RXMCOMMAALIGNEN      => '1',
            RXMONITORSEL         => "00",
            RXOOBRESET           => '0',
            RXOSCALRESET         => '0',
            RXOSHOLD             => '0',
            RXOSOVRDEN           => '0',
            RXOUTCLKSEL          => g_RXOUTCLKSEL,
            RXPCOMMAALIGNEN      => '1',
            RXPCSRESET           => '0',
            RXPD                 => rx_slow_ctrl_i.rxpd,
            RXPHALIGN            => '0',
            RXPHALIGNEN          => '0',
            RXPHDLYPD            => '1',
            RXPHDLYRESET         => '0',
            RXPLLCLKSEL          => rxpllclksel,
            RXPMARESET           => '0',
            RXPOLARITY           => rx_slow_ctrl_i.rxpolarity,
            RXPRBSCNTRESET       => '0',
            RXPRBSSEL            => '0' & rx_slow_ctrl_i.rxprbssel,
            RXPROGDIVRESET       => rxprogdivreset,
            RXRATE               => rx_slow_ctrl_i.rxrate,
            RXRATEMODE           => '0',
            RXSLIDE              => rx_fast_ctrl_i.rxslide,
            RXSLIPOUTCLK         => '0',
            RXSLIPPMA            => '0',
            RXSYNCALLIN          => '0',
            RXSYNCIN             => '0',
            RXSYNCMODE           => '0',
            RXSYSCLKSEL          => rxsysclksel,
            RXTERMINATION        => '0',
            RXUSERRDY            => rx_init_i.rxuserrdy,
            RXUSRCLK             => clks_i.rxusrclk,
            RXUSRCLK2            => clks_i.rxusrclk2,
            SIGVALIDCLK          => '0',
            TSTIN                => "00000000000000000000",
            TX8B10BBYPASS        => "00000000",
            TX8B10BEN            => '0',
            TXCOMINIT            => '0',
            TXCOMSAS             => '0',
            TXCOMWAKE            => '0',
            TXCTRL0              => txctrl0,
            TXCTRL1              => txctrl1,
            TXCTRL2              => txctrl2,
            TXDATA               => txdata,
            TXDATAEXTENDRSVD     => "00000000",
            TXDCCFORCESTART      => '0',
            TXDCCRESET           => '0',
            TXDEEMPH             => "00",
            TXDETECTRX           => '0',
            TXDIFFCTRL           => tx_slow_ctrl_i.txdiffctrl,
            TXDLYBYPASS          => '0',
            TXDLYEN              => tx_init_i.txdlyen,
            TXDLYHOLD            => '0',
            TXDLYOVRDEN          => '0',
            TXDLYSRESET          => tx_init_i.txdlysreset,
            TXDLYUPDOWN          => '0',
            TXELECIDLE           => '0',
            TXHEADER             => "000000",
            TXINHIBIT            => tx_slow_ctrl_i.txinhibit,
            TXLATCLK             => '0',
            TXLFPSTRESET         => '0',
            TXLFPSU2LPEXIT       => '0',
            TXLFPSU3WAKE         => '0',
            TXMAINCURSOR         => tx_slow_ctrl_i.txmaincursor,
            TXMARGIN             => "000",
            TXMUXDCDEXHOLD       => '0',
            TXMUXDCDORWREN       => '0',
            TXONESZEROS          => '0',
            TXOUTCLKSEL          => g_TXOUTCLKSEL,
            TXPCSRESET           => '0',
            TXPD                 => tx_slow_ctrl_i.txpd,
            TXPDELECIDLEMODE     => '0',
            TXPHALIGN            => tx_init_i.txphalign,
            TXPHALIGNEN          => tx_init_i.txphalignen,
            TXPHDLYPD            => '0',
            TXPHDLYRESET         => tx_init_i.txphdlyreset,
            TXPHDLYTSTCLK        => '0',
            TXPHINIT             => tx_init_i.txphinit,
            TXPHOVRDEN           => '0',
            TXPIPPMEN            => '0',
            TXPIPPMOVRDEN        => '0',
            TXPIPPMPD            => '1',
            TXPIPPMSEL           => '0',
            TXPIPPMSTEPSIZE      => "00000",
            TXPISOPD             => '0',
            TXPLLCLKSEL          => txpllclksel,
            TXPMARESET           => '0',
            TXPOLARITY           => tx_slow_ctrl_i.txpolarity,
            TXPOSTCURSOR         => tx_slow_ctrl_i.txpostcursor,
            TXPRBSFORCEERR       => tx_slow_ctrl_i.txprbsforceerr,
            TXPRBSSEL            => '0' & tx_slow_ctrl_i.txprbssel,
            TXPRECURSOR          => tx_slow_ctrl_i.txprecursor,
            TXPROGDIVRESET       => txprogdivreset,
            TXRATE               => "000",
            TXRATEMODE           => '0',
            TXSEQUENCE           => "0000000",
            TXSWING              => '0',
            TXSYNCALLIN          => tx_init_i.txsyncallin,
            TXSYNCIN             => tx_init_i.txsyncin,
            TXSYNCMODE           => tx_init_i.txsyncmode,
            TXSYSCLKSEL          => txsysclksel,
            TXUSERRDY            => tx_init_i.txuserrdy,
            TXUSRCLK             => clks_i.txusrclk,
            TXUSRCLK2            => clks_i.txusrclk2
        );
                 
end gty_channel_odmb57_arch;
