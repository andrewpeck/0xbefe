------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2021-07-15
-- Module Name:    GTY_QPLL_10GBE_156p25
-- Description:    This is a wrapper for a GTY QPLL that can be used with 10GbE GTY channels.
--                 QPLL1 can be used with 10GbE channels and requires a 156.25MHz refclck
--                 Only one refclk for each QPLL is used based on g_QPLL0_REFCLK_01 and g_QPLL1_REFCLK_01 generics
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

use work.common_pkg.all;
use work.mgt_pkg.all;

entity gty_qpll_10gbe_156p25 is
    generic(
        g_QPLL0_REFCLK_01   : integer range 0 to 1 := 0;
        g_QPLL1_REFCLK_01   : integer range 0 to 1 := 0
    );
    port(
        
        clk_stable_i    : in  std_logic;
        refclks_i       : in  t_mgt_refclks;
        
        ctrl_i          : in  t_mgt_qpll_ctrl;

        clks_o          : out t_mgt_qpll_clk_out;
        status_o        : out t_mgt_qpll_status;

        drp_i           : in  t_drp_in;
        drp_o           : out t_drp_out        
    );
end gty_qpll_10gbe_156p25;

architecture gty_qpll_10gbe_156p25_arch of gty_qpll_10gbe_156p25 is

    signal qpll0_refclks    : std_logic_vector(1 downto 0);
    signal qpll1_refclks    : std_logic_vector(1 downto 0);

begin

    -- Select the ref clock
    g_qpll0_ref_clk0 : if g_QPLL0_REFCLK_01 = 0 generate
        qpll0_refclks(0) <= refclks_i.gtrefclk0;
    end generate;
    
    g_qpll0_ref_clk1 : if g_QPLL0_REFCLK_01 = 1 generate
        qpll0_refclks(1) <= refclks_i.gtrefclk1;
    end generate;

    g_qpll1_ref_clk0 : if g_QPLL1_REFCLK_01 = 0 generate
        qpll1_refclks(0) <= refclks_i.gtrefclk0;
    end generate;
    
    g_qpll1_ref_clk1 : if g_QPLL1_REFCLK_01 = 1 generate
        qpll1_refclks(1) <= refclks_i.gtrefclk1;
    end generate;
    
    i_qpll : GTYE4_COMMON
        generic map(
            AEN_QPLL0_FBDIV       => '1',
            AEN_QPLL1_FBDIV       => '1',
            AEN_SDM0TOGGLE        => '0',
            AEN_SDM1TOGGLE        => '0',
            A_SDM0TOGGLE          => '0',
            A_SDM1DATA_HIGH       => "000000000",
            A_SDM1DATA_LOW        => "0000000000000000",
            A_SDM1TOGGLE          => '0',
            BIAS_CFG0             => "0000000000000000",
            BIAS_CFG1             => "0000000000000000",
            BIAS_CFG2             => "0000000100100100",
            BIAS_CFG3             => "0000000001000001",
            BIAS_CFG4             => "0000000000010000",
            BIAS_CFG_RSVD         => "0000000000000000",
            COMMON_CFG0           => "0000000000000000",
            COMMON_CFG1           => "0000000000000000",
            POR_CFG               => "0000000000000000",
            PPF0_CFG              => "0000011000000000",
            PPF1_CFG              => "0000011000000000",
            QPLL0CLKOUT_RATE      => "HALF",
            QPLL0_CFG0            => "0011001100011100",
            QPLL0_CFG1            => "1101000000111000",
            QPLL0_CFG1_G3         => "1101000000111000",
            QPLL0_CFG2            => "0000111111000000",
            QPLL0_CFG2_G3         => "0000111111000000",
            QPLL0_CFG3            => "0000000100100000",
            QPLL0_CFG4            => "0000000000000010",
            QPLL0_CP              => "0011111111",
            QPLL0_CP_G3           => "0000001111",
            QPLL0_FBDIV           => 66,
            QPLL0_FBDIV_G3        => 160,
            QPLL0_INIT_CFG0       => "0000001010110010",
            QPLL0_INIT_CFG1       => "00000000",
            QPLL0_LOCK_CFG        => "0010010111101000",
            QPLL0_LOCK_CFG_G3     => "0010010111101000",
            QPLL0_LPF             => "1000111111",
            QPLL0_LPF_G3          => "0111010101",
            QPLL0_PCI_EN          => '0',
            QPLL0_RATE_SW_USE_DRP => '1',
            QPLL0_REFCLK_DIV      => 1,
            QPLL0_SDM_CFG0        => "0000000010000000",
            QPLL0_SDM_CFG1        => "0000000000000000",
            QPLL0_SDM_CFG2        => "0000000000000000",
            QPLL1CLKOUT_RATE      => "HALF",
            QPLL1_CFG0            => "0011001100011100",
            QPLL1_CFG1            => "1101000000111000",
            QPLL1_CFG1_G3         => "1101000000111000",
            QPLL1_CFG2            => "0000111111000011",
            QPLL1_CFG2_G3         => "0000111111000011",
            QPLL1_CFG3            => "0000000100100000",
            QPLL1_CFG4            => "0000000000000010",
            QPLL1_CP              => "0011111111",
            QPLL1_CP_G3           => "0001111111",
            QPLL1_FBDIV           => 66,
            QPLL1_FBDIV_G3        => 80,
            QPLL1_INIT_CFG0       => "0000001010110010",
            QPLL1_INIT_CFG1       => "00000000",
            QPLL1_LOCK_CFG        => "0010010111101000",
            QPLL1_LOCK_CFG_G3     => "0010010111101000",
            QPLL1_LPF             => "1000011111",
            QPLL1_LPF_G3          => "0111010100",
            QPLL1_PCI_EN          => '0',
            QPLL1_RATE_SW_USE_DRP => '1',
            QPLL1_REFCLK_DIV      => 1,
            QPLL1_SDM_CFG0        => "0000000010000000",
            QPLL1_SDM_CFG1        => "0000000000000000",
            QPLL1_SDM_CFG2        => "0000000000000000",
            RSVD_ATTR0            => "0000000000000000",
            RSVD_ATTR1            => "0000000000000000",
            RSVD_ATTR2            => "0000000000000000",
            RSVD_ATTR3            => "0000000000000000",
            RXRECCLKOUT0_SEL      => "00",
            RXRECCLKOUT1_SEL      => "00",
            SARC_ENB              => '0',
            SARC_SEL              => '0',
            SDM0INITSEED0_0       => "0000000100010001",
            SDM0INITSEED0_1       => "000010001",
            SDM1INITSEED0_0       => "0000000100010001",
            SDM1INITSEED0_1       => "000010001",
            SIM_DEVICE            => "ULTRASCALE_PLUS",
            SIM_MODE              => "FAST",
            SIM_RESET_SPEEDUP     => "TRUE",
            UB_CFG0               => "0000000000000000",
            UB_CFG1               => "0000000000000000",
            UB_CFG2               => "0000000000000000",
            UB_CFG3               => "0000000000000000",
            UB_CFG4               => "0000000000000000",
            UB_CFG5               => "0000010000000000",
            UB_CFG6               => "0000000000000000"
        )
        port map(
            DRPDO             => drp_o.do,
            DRPRDY            => drp_o.rdy,
            PMARSVDOUT0       => open,
            PMARSVDOUT1       => open,
            QPLL0FBCLKLOST    => status_o.qpllfbclklost(0),
            QPLL0LOCK         => status_o.qplllock(0),
            QPLL0OUTCLK       => clks_o.qpllclk(0),
            QPLL0OUTREFCLK    => clks_o.qpllrefclk(0),
            QPLL0REFCLKLOST   => status_o.qpllrefclklost(0),
            QPLL1FBCLKLOST    => status_o.qpllfbclklost(1),
            QPLL1LOCK         => status_o.qplllock(1),
            QPLL1OUTCLK       => clks_o.qpllclk(1),
            QPLL1OUTREFCLK    => clks_o.qpllrefclk(1),
            QPLL1REFCLKLOST   => status_o.qpllrefclklost(1),
            QPLLDMONITOR0     => open,
            QPLLDMONITOR1     => open,
            REFCLKOUTMONITOR0 => open,
            REFCLKOUTMONITOR1 => open,
            RXRECCLK0SEL      => open,
            RXRECCLK1SEL      => open,
            SDM0FINALOUT      => open,
            SDM0TESTDATA      => open,
            SDM1FINALOUT      => open,
            SDM1TESTDATA      => open,
            UBDADDR           => open,
            UBDEN             => open,
            UBDI              => open,
            UBDWE             => open,
            UBMDMTDO          => open,
            UBRSVDOUT         => open,
            UBTXUART          => open,
            BGBYPASSB         => '1',
            BGMONITORENB      => '1',
            BGPDB             => '1',
            BGRCALOVRD        => "10000",
            BGRCALOVRDENB     => '1',
            DRPADDR           => drp_i.addr,
            DRPCLK            => drp_i.clk,
            DRPDI             => drp_i.di,
            DRPEN             => drp_i.en,
            DRPWE             => drp_i.we,
            GTGREFCLK0        => '0',
            GTGREFCLK1        => '0',
            GTNORTHREFCLK00   => '0',
            GTNORTHREFCLK01   => '0',
            GTNORTHREFCLK10   => '0',
            GTNORTHREFCLK11   => '0',
            GTREFCLK00        => qpll0_refclks(0),
            GTREFCLK01        => qpll1_refclks(0),
            GTREFCLK10        => qpll0_refclks(1),
            GTREFCLK11        => qpll1_refclks(1),
            GTSOUTHREFCLK00   => '0',
            GTSOUTHREFCLK01   => '0',
            GTSOUTHREFCLK10   => '0',
            GTSOUTHREFCLK11   => '0',
            PCIERATEQPLL0     => "000",
            PCIERATEQPLL1     => "000",
            PMARSVD0          => "00000000",
            PMARSVD1          => "00000000",
            QPLL0CLKRSVD0     => '0',
            QPLL0CLKRSVD1     => '0',
            QPLL0FBDIV        => "00000000",
            QPLL0LOCKDETCLK   => clk_stable_i,
            QPLL0LOCKEN       => not ctrl_i.power_down(0),
            QPLL0PD           => ctrl_i.power_down(0),
            QPLL0REFCLKSEL    => "001",
            QPLL0RESET        => ctrl_i.reset(0),
            QPLL1CLKRSVD0     => '0',
            QPLL1CLKRSVD1     => '0',
            QPLL1FBDIV        => "00000000",
            QPLL1LOCKDETCLK   => clk_stable_i,
            QPLL1LOCKEN       => not ctrl_i.power_down(1),
            QPLL1PD           => ctrl_i.power_down(1),
            QPLL1REFCLKSEL    => "001",
            QPLL1RESET        => ctrl_i.reset(1),
            QPLLRSVD1         => "00000000",
            QPLLRSVD2         => "00000",
            QPLLRSVD3         => "00000",
            QPLLRSVD4         => "00000000",
            RCALENB           => '1',
            SDM0DATA          => "0000000000000000000000000",
            SDM0RESET         => '0',
            SDM0TOGGLE        => '0',
            SDM0WIDTH         => "00",
            SDM1DATA          => "0000000000000000000000000",
            SDM1RESET         => '0',
            SDM1TOGGLE        => '0',
            SDM1WIDTH         => "00",
            UBCFGSTREAMEN     => '0',
            UBDO              => "0000000000000000",
            UBDRDY            => '0',
            UBENABLE          => '0',
            UBGPI             => "00",
            UBINTR            => "00",
            UBIOLMBRST        => '0',
            UBMBRST           => '0',
            UBMDMCAPTURE      => '0',
            UBMDMDBGRST       => '0',
            UBMDMDBGUPDATE    => '0',
            UBMDMREGEN        => "0000",
            UBMDMSHIFT        => '0',
            UBMDMSYSRST       => '0',
            UBMDMTCK          => '0',
            UBMDMTDI          => '0'
        );
                 
end gty_qpll_10gbe_156p25_arch;
