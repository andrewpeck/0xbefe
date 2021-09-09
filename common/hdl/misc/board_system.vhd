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
        
        board_id_o              : out std_logic_vector(15 downto 0);        
        ext_trig_en_o           : out std_logic;
        ext_trig_deadtime_o     : out std_logic_vector(11 downto 0);        
        pcie_packet_size_o      : out std_logic_vector(23 downto 0);
        pcie_packet_timeout_o   : out std_logic_vector(31 downto 0);
        
        -- IPbus
        ipb_reset_i             : in  std_logic;
        ipb_clk_i               : in  std_logic;
        ipb_miso_o              : out ipb_rbus;
        ipb_mosi_i              : in  ipb_wbus                
    );
end board_system;

architecture board_system_arch of board_system is

    signal board_id             : std_logic_vector(15 downto 0);
    signal ext_trig_en          : std_logic;
    signal ext_trig_deadtime    : std_logic_vector(11 downto 0);        
    signal pcie_packet_size     : std_logic_vector(23 downto 0);
    signal pcie_packet_timeout  : std_logic_vector(31 downto 0);

    ------ Register signals begin (this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py -- do not edit)
    ------ Register signals end ----------------------------------------------
        
begin

    board_id_o <= board_id;
    ext_trig_en_o <= ext_trig_en;
    ext_trig_deadtime_o <= ext_trig_deadtime;
    pcie_packet_size_o <= pcie_packet_size;
    pcie_packet_timeout_o <= pcie_packet_timeout;

    --===============================================================================================
    -- this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py (do not edit) 
    --==== Registers begin ==========================================================================

    --==== Registers end ============================================================================
    
end board_system_arch;
