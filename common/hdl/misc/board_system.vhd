------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2021-07-12
-- Module Name:    BOARD_SYSTEM
-- Description:    This module provides board level system register access
------------------------------------------------------------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common_pkg.all;
use work.mgt_pkg.all;
use work.board_config_package.all;
use work.ipbus.all;
use work.registers.all;

entity board_system is
    generic(
        -- Firmware version, date, time, git sha
        g_FW_DATE            : std_logic_vector (31 downto 0);
        g_FW_TIME            : std_logic_vector (31 downto 0);
        g_FW_VER             : std_logic_vector (31 downto 0);
        g_FW_SHA             : std_logic_vector (31 downto 0);        

        g_IPB_CLK_PERIOD_NS     : integer
    );
    port (
        reset_i                 : in  std_logic;

        ttc_clk40_i             : in std_logic;

        board_id_o              : out std_logic_vector(15 downto 0);
        usr_logic_reset_o       : out std_logic; -- on ttc clk40 domain
        ttc_reset_o             : out std_logic; -- on ttc clk40 domain
        ext_trig_en_o           : out std_logic;
        ext_trig_source_o       : out std_logic_vector(1 downto 0);
        ext_trig_deadtime_o     : out std_logic_vector(11 downto 0);
        ext_clk_out_en_o        : out std_logic;
        ext_trig_phase_mask_o   : out std_logic_vector(15 downto 0);

        -- IPbus
        ipb_reset_i             : in  std_logic;
        ipb_clk_i               : in  std_logic;
        ipb_miso_o              : out ipb_rbus;
        ipb_mosi_i              : in  ipb_wbus
    );
end board_system;

architecture board_system_arch of board_system is

    signal usr_logic_reset      : std_logic := '0';
    signal usr_logic_reset_ext  : std_logic := '0';
    signal usr_logic_reset_clk40: std_logic := '0';
    signal ttc_reset            : std_logic := '0';
    signal ttc_reset_ext        : std_logic := '0';
    signal ttc_reset_clk40      : std_logic := '0';

    signal board_id             : std_logic_vector(15 downto 0);
    signal ext_trig_en          : std_logic;
    signal ext_trig_source      : std_logic_vector(1 downto 0);
    signal ext_trig_deadtime    : std_logic_vector(11 downto 0);
    signal ext_clk_out_en       : std_logic;
    signal ext_trig_phase_mask  : std_logic_vector(15 downto 0);

    ------ Register signals begin (this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py -- do not edit)
    ------ Register signals end ----------------------------------------------

begin

    board_id_o <= board_id;
    ext_trig_en_o <= ext_trig_en;
    ext_trig_source_o <= ext_trig_source;
    ext_trig_deadtime_o <= ext_trig_deadtime;
    ext_clk_out_en_o <= ext_clk_out_en;
    ext_trig_phase_mask_o <= ext_trig_phase_mask;

    usr_logic_reset_o <= usr_logic_reset_clk40;
    ttc_reset_o <= ttc_reset_clk40;

    -- user logic reset
    i_usr_logic_rst_ext : entity work.pulse_extend
        generic map(
            DELAY_CNT_LENGTH => 4
        )
        port map(
            clk_i          => ipb_clk_i,
            rst_i          => '0',
            pulse_length_i => x"f",
            pulse_i        => usr_logic_reset,
            pulse_o        => usr_logic_reset_ext
        );

    i_usr_logic_rst_sync : entity work.synch
        generic map(
            N_STAGES => 8,
            IS_RESET => true
        )
        port map(
            async_i => usr_logic_reset_ext,
            clk_i   => ttc_clk40_i,
            sync_o  => usr_logic_reset_clk40
        );

    -- TTC reset
    i_ttc_rst_ext : entity work.pulse_extend
        generic map(
            DELAY_CNT_LENGTH => 4
        )
        port map(
            clk_i          => ipb_clk_i,
            rst_i          => '0',
            pulse_length_i => x"f",
            pulse_i        => ttc_reset,
            pulse_o        => ttc_reset_ext
        );

    i_ttc_rst_sync : entity work.synch
        generic map(
            N_STAGES => 8,
            IS_RESET => true
        )
        port map(
            async_i => ttc_reset_ext,
            clk_i   => ttc_clk40_i,
            sync_o  => ttc_reset_clk40
        );

    --===============================================================================================
    -- this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py (do not edit)
    --==== Registers begin ==========================================================================

    --==== Registers end ============================================================================

end board_system_arch;
