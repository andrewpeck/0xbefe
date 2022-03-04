------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
--
-- Create Date:    2020-06-04
-- Module Name:    CLK_BUFS
-- Description:    Clock buffers
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;

use work.common_pkg.all;
use work.mgt_pkg.all;

entity clk_bufs is
    generic(
        g_SYSCLK100_SYNTH_B_OUT_SEL : integer range 1 to 5 -- selects which synth_b output should be used as system 100MHz clock
    );
    port (
        pcie_refclk0_p_i            : in  std_logic;
        pcie_refclk0_n_i            : in  std_logic;

        pcie_refclk0_o              : out std_logic;
        pcie_refclk0_div2_o         : out std_logic;

        synth_b_out_p_i             : in  std_logic_vector(4 downto 0);
        synth_b_out_n_i             : in  std_logic_vector(4 downto 0);
        synth_b_clks_o              : out std_logic_vector(4 downto 0);

        sysclk_100_o                : out std_logic
    );
end clk_bufs;

architecture clk_bufs_arch of clk_bufs is

    signal synth_b_clks_tmp         : std_logic_vector(4 downto 0);
    signal synth_b_clks             : std_logic_vector(4 downto 0);
    signal sysclk100                : std_logic;

    signal pcie_refclk0             : std_logic;
    signal pcie_refclk0_div2        : std_logic;

begin

    --================================--
    -- PCIe refclk
    --================================--

    i_pcie_refclk_buf : IBUFDS_GTE4
        port map(
            O     => pcie_refclk0,
            ODIV2 => pcie_refclk0_div2,
            CEB   => '0',
            I     => pcie_refclk0_p_i,
            IB    => pcie_refclk0_n_i
        );

    pcie_refclk0_o <= pcie_refclk0;
    pcie_refclk0_div2_o <= pcie_refclk0_div2;

    --================================--
    -- Sysclk
    --================================--

    g_synth_b_clks : for i in 0 to 4 generate

        i_synth_b_clk_buf : IBUFDS
            port map(
                O  => synth_b_clks_tmp(i),
                I  => synth_b_out_p_i(i),
                IB => synth_b_out_n_i(i)
            );

        i_synth_b_clk_bufg : BUFG
            port map(
                O => synth_b_clks(i),
                I => synth_b_clks_tmp(i)
            );

    end generate;

    synth_b_clks_o <= synth_b_clks;
    sysclk100 <= synth_b_clks(g_SYSCLK100_SYNTH_B_OUT_SEL - 1);
    sysclk_100_o <= sysclk100;

end clk_bufs_arch;
