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
        gth_refclk0_p_i             : in  std_logic_vector(2 downto 0);
        gth_refclk0_n_i             : in  std_logic_vector(2 downto 0);
        gth_refclk1_p_i             : in  std_logic_vector(2 downto 0);
        gth_refclk1_n_i             : in  std_logic_vector(2 downto 0);
        
        gty_refclk0_p_i             : in  std_logic_vector(2 downto 0);
        gty_refclk0_n_i             : in  std_logic_vector(2 downto 0);
        gty_refclk1_p_i             : in  std_logic_vector(2 downto 0);
        gty_refclk1_n_i             : in  std_logic_vector(2 downto 0);

        gth_mgt_refclks_o           : out t_mgt_refclks_arr(75 downto 0);
        gty_mgt_refclks_o           : out t_mgt_refclks_arr(75 downto 0);

        gth_refclk0_o               : out std_logic_vector(2 downto 0);
        gth_refclk1_o               : out std_logic_vector(2 downto 0);
        gth_refclk0_div2_o          : out std_logic_vector(2 downto 0);
        gth_refclk1_div2_o          : out std_logic_vector(2 downto 0);
        gty_refclk0_o               : out std_logic_vector(2 downto 0);
        gty_refclk1_o               : out std_logic_vector(2 downto 0);
        gty_refclk0_div2_o          : out std_logic_vector(2 downto 0);
        gty_refclk1_div2_o          : out std_logic_vector(2 downto 0)
    );
end clk_bufs;

architecture clk_bufs_arch of clk_bufs is

    -- per quad refclks
    signal gth_refclk0              : std_logic_vector(2 downto 0);
    signal gth_refclk1              : std_logic_vector(2 downto 0);
    signal gth_refclk0_div2         : std_logic_vector(2 downto 0);
    signal gth_refclk1_div2         : std_logic_vector(2 downto 0);

    signal gty_refclk0              : std_logic_vector(2 downto 0);
    signal gty_refclk1              : std_logic_vector(2 downto 0);
    signal gty_refclk0_div2         : std_logic_vector(2 downto 0);
    signal gty_refclk1_div2         : std_logic_vector(2 downto 0);

begin

    --================================--
    -- GTH refclks
    --================================--

    g_gth_refclk_bufs : for i in 0 to 2 generate

        i_gth_refclk0_buf : IBUFDS_GTE4
            port map(
                O     => gth_refclk0(i),
                ODIV2 => gth_refclk0_div2(i),
                CEB   => '0',
                I     => gth_refclk0_p_i(i),
                IB    => gth_refclk0_n_i(i)
            );

        i_gth_refclk1_buf : IBUFDS_GTE4
            port map(
                O     => gth_refclk1(i),
                ODIV2 => gth_refclk1_div2(i),
                CEB   => '0',
                I     => gth_refclk1_p_i(i),
                IB    => gth_refclk1_n_i(i)
            );

        --TODO: connect the channel refclks here

    end generate;

    gth_refclk0_o <= gth_refclk0;
    gth_refclk1_o <= gth_refclk1;
    gth_refclk0_div2_o <= gth_refclk0_div2;
    gth_refclk1_div2_o <= gth_refclk1_div2;

    --================================--
    -- GTY refclks
    --================================--

    g_gty_refclk_bufs : for i in 0 to 2 generate

        i_gty_refclk0_buf : IBUFDS_GTE4
            port map(
                O     => gty_refclk0(i),
                ODIV2 => gty_refclk0_div2(i),
                CEB   => '0',
                I     => gty_refclk0_p_i(i),
                IB    => gty_refclk0_n_i(i)
            );

        i_gty_refclk1_buf : IBUFDS_GTE4
            port map(
                O     => gty_refclk1(i),
                ODIV2 => gty_refclk1_div2(i),
                CEB   => '0',
                I     => gty_refclk1_p_i(i),
                IB    => gty_refclk1_n_i(i)
            );

        --TODO: connect the channel refclks here

    end generate;

    gty_refclk0_o <= gty_refclk0;
    gty_refclk1_o <= gty_refclk1;
    gty_refclk0_div2_o <= gty_refclk0_div2;
    gty_refclk1_div2_o <= gty_refclk1_div2;

end clk_bufs_arch;
