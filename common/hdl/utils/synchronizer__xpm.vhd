------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    23:40 2016-12-18
-- Module Name:    synchronizer (Xilinx XPM version, works with any device in vivado, but not in ise)
-- Description:    A synchronizer unit for crossing clock domains with a single signal 
------------------------------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library xpm;
use xpm.vcomponents.all;

entity synch is
    generic(
        N_STAGES    : integer := 3;
        IS_RESET    : boolean := false
    );
    port(
        async_i : in  std_logic;
        clk_i   : in  std_logic;
        sync_o  : out std_logic
    );
end synch;

architecture xilinx_xpm_arch of synch is
begin

    g_reset_sync : if IS_RESET generate
        i_xilinx_cdc_reset : xpm_cdc_async_rst
            generic map(
                DEST_SYNC_FF    => N_STAGES,
                RST_ACTIVE_HIGH => 1
            )
            port map(
                src_arst  => async_i,
                dest_clk  => clk_i,
                dest_arst => sync_o
            );
    end generate;

    g_sync_single : if not IS_RESET generate
        i_xilinx_cdc_single : xpm_cdc_single
            generic map(
                DEST_SYNC_FF   => N_STAGES,
                SRC_INPUT_REG  => 0
            )
            port map(
                src_clk  => '0',
                src_in   => async_i,
                dest_clk => clk_i,
                dest_out => sync_o
            );
    end generate;

end xilinx_xpm_arch;
