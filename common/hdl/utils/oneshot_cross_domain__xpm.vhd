------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    23:40 2016-12-18
-- Module Name:    oneshot (Xilinx XPM version, works with any device in vivado, but not in ise)
-- Description:    given an input signal, the output is asserted high for one clock cycle when input goes from low to high.
--                 Even if the input signal stays high for longe that one clock cycle, the output is only asserted high for one cycle.
--                 Both input and output signals are on the same clock domain. Use oneshot_cross_domain if you need them to be on separate domains.
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

entity oneshot_cross_domain is
    generic(
        G_N_STAGES    : integer := 3
    );
    port(
        reset_i         : in  std_logic;
        input_clk_i     : in  std_logic;
        oneshot_clk_i   : in  std_logic;
        input_i         : in  std_logic;
        oneshot_o       : out std_logic
    );
end oneshot_cross_domain;

architecture xilinx_xpm_arch of oneshot_cross_domain is
begin

    i_xilinx_cdc_pulse : xpm_cdc_pulse
        generic map(
            DEST_SYNC_FF   => G_N_STAGES,
            REG_OUTPUT     => 0,
            RST_USED       => 1
        )
        port map(
            src_clk    => input_clk_i,
            src_rst    => reset_i,
            src_pulse  => input_i,
            dest_clk   => oneshot_clk_i,
            dest_rst   => '0',
            dest_pulse => oneshot_o
        );

end xilinx_xpm_arch;