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
    port (
        qsfp_refclk0_p_i            : in  std_logic_vector(3 downto 0);
        qsfp_refclk0_n_i            : in  std_logic_vector(3 downto 0);
        qsfp_refclk1_p_i            : in  std_logic_vector(3 downto 0);
        qsfp_refclk1_n_i            : in  std_logic_vector(3 downto 0);

        pcie_refclk0_p_i            : in  std_logic;
        pcie_refclk0_n_i            : in  std_logic;

        sysclk_100_p_i              : in  std_logic;
        sysclk_100_n_i              : in  std_logic;
        
        qsfp_refclk0_o              : out std_logic_vector(3 downto 0);
        qsfp_refclk1_o              : out std_logic_vector(3 downto 0);
        qsfp_refclk0_div2_o         : out std_logic_vector(3 downto 0);
        qsfp_refclk1_div2_o         : out std_logic_vector(3 downto 0);
        
        qsfp_mgt_refclks_o          : out t_mgt_refclks_arr(15 downto 0);
        
        pcie_refclk0_o              : out std_logic;
        pcie_refclk0_div2_o         : out std_logic;
        
        sysclk_100_o                : out std_logic
    );
end clk_bufs;

architecture clk_bufs_arch of clk_bufs is

    signal sysclk100                : std_logic;
    signal sysclk100_bufg           : std_logic;

    -- per quad refclks
    signal qsfp_refclk0             : std_logic_vector(3 downto 0);
    signal qsfp_refclk1             : std_logic_vector(3 downto 0);
    signal qsfp_refclk0_div2        : std_logic_vector(3 downto 0);
    signal qsfp_refclk1_div2        : std_logic_vector(3 downto 0);

    signal pcie_refclk0             : std_logic;
    signal pcie_refclk0_div2        : std_logic;

begin

    --================================--
    -- QSFP refclks
    --================================--

    g_qsfp_refclk_bufs : for i in 0 to 3 generate

        i_qsfp_refclk0_buf : IBUFDS_GTE4
            port map(
                O     => qsfp_refclk0(i),
                ODIV2 => qsfp_refclk0_div2(i),
                CEB   => '0',
                I     => qsfp_refclk0_p_i(i),
                IB    => qsfp_refclk0_n_i(i)
            );

        i_qsfp_refclk1_buf : IBUFDS_GTE4
            port map(
                O     => qsfp_refclk1(i),
                ODIV2 => qsfp_refclk1_div2(i),
                CEB   => '0',
                I     => qsfp_refclk1_p_i(i),
                IB    => qsfp_refclk1_n_i(i)
            );

        g_channel : for chan in 0 to 3 generate
            qsfp_mgt_refclks_o(i * 4 + chan).gtrefclk0 <= qsfp_refclk0(i);
            qsfp_mgt_refclks_o(i * 4 + chan).gtrefclk1 <= qsfp_refclk1(i);
        end generate;

    end generate;

    qsfp_refclk0_o <= qsfp_refclk0;
    qsfp_refclk1_o <= qsfp_refclk1;
    qsfp_refclk0_div2_o <= qsfp_refclk0_div2;
    qsfp_refclk1_div2_o <= qsfp_refclk1_div2;

-- can use the refclk on the fabric like this if needed:
--    i_ibert_sysclk_buf : BUFG_GT
--        port map(
--            O       => ibert_sysclk,
--            CE      => '1',
--            CEMASK  => '0',
--            CLR     => '0',
--            CLRMASK => '0',
--            DIV     => "000",
--            I       => qsfp_refclk_div2(3)
--        );

    --================================--
    -- PCIe refclk
    --================================--

    i_qsfp_refclk0_buf : IBUFDS_GTE4
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
    
    i_sysclk100_buf : IBUFDS
        port map(
            O  => sysclk100,
            I  => sysclk_100_p_i,
            IB => sysclk_100_n_i
        );
   
    i_sysclk100_bufg : BUFG
        port map(
            O => sysclk100_bufg,
            I => sysclk100
        );
    
    sysclk_100_o <= sysclk100_bufg;


end clk_bufs_arch;
