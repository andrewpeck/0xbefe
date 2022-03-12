------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2020-06-04
-- Module Name:    REFCLK_BUFS
-- Description:    Reference clock buffers 
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;

use work.common_pkg.all;
use work.mgt_pkg.all;

entity refclk_bufs is
    generic(
        g_NUM_REFCLK0           : integer; -- number of refclk0 clocks
        g_NUM_REFCLK1           : integer; -- number of refclk1 clocks
        g_FREQ_METER_CLK_FREQ   : std_logic_vector(31 downto 0) -- the frequency of the freq_meter_clk_i
    );    
    port (
        refclk0_p_i             : in  std_logic_vector(g_NUM_REFCLK0 - 1 downto 0);
        refclk0_n_i             : in  std_logic_vector(g_NUM_REFCLK0 - 1 downto 0);
        refclk1_p_i             : in  std_logic_vector(g_NUM_REFCLK1 - 1 downto 0);
        refclk1_n_i             : in  std_logic_vector(g_NUM_REFCLK1 - 1 downto 0);

        refclk0_o               : out std_logic_vector(g_NUM_REFCLK0 - 1 downto 0);
        refclk1_o               : out std_logic_vector(g_NUM_REFCLK1 - 1 downto 0);
        refclk0_div2_o          : out std_logic_vector(g_NUM_REFCLK0 - 1 downto 0);
        refclk1_div2_o          : out std_logic_vector(g_NUM_REFCLK1 - 1 downto 0);
        
        freq_meter_clk_i        : in  std_logic;
        refclk0_freq_o          : out t_std32_array(g_NUM_REFCLK0 - 1 downto 0);
        refclk1_freq_o          : out t_std32_array(g_NUM_REFCLK1 - 1 downto 0)
    );
end refclk_bufs;

architecture refclk_bufs_arch of refclk_bufs is

    component freq_meter is
        generic(
            REF_F       : std_logic_vector(31 downto 0);
            N           : integer
        );
        port(
            ref_clk     : in  std_logic;
            f           : in  std_logic_vector(N - 1 downto 0);
            freq        : out t_std32_array(N - 1 downto 0)
        );
    end component freq_meter;

    signal refclk0              : std_logic_vector(g_NUM_REFCLK0 - 1 downto 0);
    signal refclk1              : std_logic_vector(g_NUM_REFCLK1 - 1 downto 0);
    signal refclk0_div2_tmp     : std_logic_vector(g_NUM_REFCLK0 - 1 downto 0);
    signal refclk1_div2_tmp     : std_logic_vector(g_NUM_REFCLK1 - 1 downto 0);
    signal refclk0_div2         : std_logic_vector(g_NUM_REFCLK0 - 1 downto 0);
    signal refclk1_div2         : std_logic_vector(g_NUM_REFCLK1 - 1 downto 0);

begin

    --================================--
    -- refclk0 buffers
    --================================--

    g_refclk0_bufs : for i in 0 to g_NUM_REFCLK0 - 1 generate

        i_refclk0_buf : IBUFDS_GTE4
            port map(
                O     => refclk0(i),
                ODIV2 => refclk0_div2_tmp(i),
                CEB   => '0',
                I     => refclk0_p_i(i),
                IB    => refclk0_n_i(i)
            );

        i_refclk0_div2_bufg : BUFG_GT
            port map(
                O       => refclk0_div2(i),
                CE      => '1',
                CEMASK  => '0',
                CLR     => '0',
                CLRMASK => '0',
                DIV     => "000",
                I       => refclk0_div2_tmp(i)
            );    

    end generate;

    refclk0_o <= refclk0;
    refclk0_div2_o <= refclk0_div2;

    --================================--
    -- refclk1 buffers
    --================================--

    g_refclk1_bufs : for i in 0 to g_NUM_REFCLK1 - 1 generate

        i_refclk1_buf : IBUFDS_GTE4
            port map(
                O     => refclk1(i),
                ODIV2 => refclk1_div2_tmp(i),
                CEB   => '0',
                I     => refclk1_p_i(i),
                IB    => refclk1_n_i(i)
            );

        i_refclk1_div2_bufg : BUFG_GT
            port map(
                O       => refclk1_div2(i),
                CE      => '1',
                CEMASK  => '0',
                CLR     => '0',
                CLRMASK => '0',
                DIV     => "000",
                I       => refclk1_div2_tmp(i)
            );    

    end generate;

    refclk1_o <= refclk1;
    refclk1_div2_o <= refclk1_div2;

    --================================--
    -- Frequency meters
    --================================--

    i_refclk0_freq_meter : freq_meter
        generic map(
            REF_F => g_FREQ_METER_CLK_FREQ,
            N     => g_NUM_REFCLK0
        )
        port map(
            ref_clk => freq_meter_clk_i,
            f       => refclk0_div2,
            freq    => refclk0_freq_o
        );

    i_refclk1_freq_meter : freq_meter
        generic map(
            REF_F => g_FREQ_METER_CLK_FREQ,
            N     => g_NUM_REFCLK1
        )
        port map(
            ref_clk => freq_meter_clk_i,
            f       => refclk1_div2,
            freq    => refclk1_freq_o
        );

end refclk_bufs_arch;
