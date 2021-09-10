------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2021-09-10
-- Module Name:    PCIE_SLOW_CONTROL 
-- Description:    Slow control interface for PCIe    
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.common_pkg.all;
use work.ipbus.all;
use work.registers.all;

entity pcie_slow_control is
    generic(
        g_IPB_CLK_PERIOD_NS     : integer
    );
    port(
        
        axi_clk                 : in  std_logic;

        -- PCIe DAQ control and status
        pcie_daq_control_o      : out t_pcie_daq_control;
        pcie_daq_status_i       : in  t_pcie_daq_status;        
                
        ipb_clk_i               : in  std_logic;
        ipb_reset_i             : in  std_logic;
        ipb_mosi_i              : in  ipb_wbus;
        ipb_miso_o              : out ipb_rbus
    );
end pcie_slow_control;

architecture pcie_slow_control_arch of pcie_slow_control is

    signal pcie_daq_control     : t_pcie_daq_control;
    signal pcie_daq_status      : t_pcie_daq_status;        

    ------ Register signals begin (this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py -- do not edit)
    ------ Register signals end ----------------------------------------------

begin

    pcie_daq_control_o <= pcie_daq_control;
    pcie_daq_status <= pcie_daq_status_i;
    
    --===============================================================================================
    -- this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py (do not edit) 
    --==== Registers begin ==========================================================================

    --==== Registers end ============================================================================

end pcie_slow_control_arch;
