------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    15:04 2016-05-10
-- Module Name:    System Registers
-- Description:    this module provides registers for CSC FED system-wide setting  
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.ipbus.all;
use work.common_pkg.all;
use work.csc_pkg.all;
use work.registers.all;
use work.ttc_pkg.all;
use work.project_config.all;

entity system_regs is
    generic(
        g_SLR                    : integer;
        g_NUM_OF_DMBs            : integer;
        g_NUM_IPB_MON_SLAVES     : integer;
        g_IPB_CLK_PERIOD_NS      : integer
    );
    port(
        reset_i                     : in std_logic;
    
        ttc_clks_i                  : in t_ttc_clks;
    
        ipb_clk_i                   : in std_logic;
        ipb_reset_i                 : in std_logic;
        ipb_mosi_i                  : in ipb_wbus;
        ipb_miso_o                  : out ipb_rbus;
        ipb_mon_miso_arr_i          : in ipb_rbus_array(g_NUM_IPB_MON_SLAVES - 1 downto 0);
                
        global_reset_o              : out std_logic;
        gbt_reset_o                 : out std_logic;
        manual_ipbus_reset_o        : out std_logic;
        manual_link_reset_o         : out std_logic;
        
        loopback_gbt_test_en_o      : out std_logic;

        xdcfeb_switches_o           : out t_xdcfeb_switches;
        xdcfeb_rx_data_i            : in  std_logic_vector(31 downto 0);
        
        promless_stats_i            : in  t_promless_stats;
        promless_cfg_o              : out t_promless_cfg        
    );
end system_regs;

architecture system_regs_arch of system_regs is

    signal reset_cnt                : std_logic := '0';

    signal loopback_gbt_test_en     : std_logic;
    
    signal global_reset_timer       : integer range 0 to 100 := 0;
    signal global_reset_trig        : std_logic;

    signal ipbus_reset_timer        : integer range 0 to 100 := 0;
    signal ipbus_reset_trig         : std_logic;

    signal ipb_mon_miso_ack_arr     : std_logic_vector(g_NUM_IPB_MON_SLAVES - 1 downto 0);
    signal ipb_mon_miso_err_arr     : std_logic_vector(g_NUM_IPB_MON_SLAVES - 1 downto 0);
    signal ipb_mon_miso_ack_or      : std_logic;
    signal ipb_mon_miso_err_or      : std_logic;
    signal ipb_mon_last_trans_err   : std_logic;
    signal ipb_mon_trans_cnt        : std_logic_vector(15 downto 0);
    signal ipb_mon_err_cnt          : std_logic_vector(14 downto 0);

    signal promless_fw_size         : std_logic_vector(31 downto 0);

    ----------- XDCFEB -----------------
    signal xdcfeb_switches          : t_xdcfeb_switches;
    signal xdcfeb_rx_select         : std_logic_vector(3 downto 0);

    ------ Register signals begin (this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py -- do not edit)
    ------ Register signals end ----------------------------------------------
    
begin

    --=== Tests === --
    loopback_gbt_test_en_o <= loopback_gbt_test_en; 

    --=== PROMless === --
    promless_cfg_o.firmware_size <= promless_fw_size;

    --=== XDCFEB === --
    xdcfeb_switches_o <= xdcfeb_switches;
    xdcfeb_switches.rx_select <= to_integer(unsigned(xdcfeb_rx_select));

    --=== Global resets === --
    process (ttc_clks_i.clk_40)
    begin
        if rising_edge(ttc_clks_i.clk_40) then
            if (global_reset_trig = '1') then
                global_reset_timer <= 100;
                global_reset_o <= '0';
            else
                -- wait for 50 cycles after the trigger, and then keep the reset on for 50 cycles
                if (global_reset_timer = 0) then
                    global_reset_o <= '0';
                    global_reset_timer <= 0;
                elsif (global_reset_timer > 50) then
                    global_reset_o <= '0';
                    global_reset_timer <= global_reset_timer - 1; 
                else
                    global_reset_o <= '1';
                    global_reset_timer <= global_reset_timer - 1;
                end if;
            end if;
        end if;
    end process;

    --=== IPB reset === --
    process (ttc_clks_i.clk_40)
    begin
        if rising_edge(ttc_clks_i.clk_40) then
            if (ipbus_reset_trig = '1') then
                ipbus_reset_timer <= 100;
                manual_ipbus_reset_o <= '0';
            else
                -- wait for 50 cycles after the trigger, and then keep the reset on for 50 cycles
                if (ipbus_reset_timer = 0) then
                    manual_ipbus_reset_o <= '0';
                    ipbus_reset_timer <= 0;
                elsif (ipbus_reset_timer > 50) then
                    manual_ipbus_reset_o <= '0';
                    ipbus_reset_timer <= ipbus_reset_timer - 1; 
                else
                    manual_ipbus_reset_o <= '1';
                    ipbus_reset_timer <= ipbus_reset_timer - 1;
                end if;
            end if;
        end if;
    end process;

    --=== IPB monitor === --
    process (ipb_clk_i)
    begin
        if rising_edge(ipb_clk_i) then
            for i in 0 to g_NUM_IPB_MON_SLAVES - 1 loop
                ipb_mon_miso_ack_arr(i) <= ipb_mon_miso_arr_i(i).ipb_ack;
                ipb_mon_miso_err_arr(i) <= ipb_mon_miso_arr_i(i).ipb_err;
            end loop;
            ipb_mon_miso_ack_or <= or_reduce(ipb_mon_miso_ack_arr);
            ipb_mon_miso_err_or <= or_reduce(ipb_mon_miso_err_arr);
            
            if (ipb_mon_miso_ack_or = '1') then
                ipb_mon_last_trans_err <= ipb_mon_miso_err_or;
            end if; 
        end if;
    end process;

    i_ipb_mon_trans_cnt : entity work.counter
        generic map(
            g_COUNTER_WIDTH  => 16,
            g_ALLOW_ROLLOVER => true
        )
        port map(
            ref_clk_i => ipb_clk_i,
            reset_i   => reset_i,
            en_i      => ipb_mon_miso_ack_or,
            count_o   => ipb_mon_trans_cnt
        );

    i_ipb_mon_err_cnt : entity work.counter
        generic map(
            g_COUNTER_WIDTH  => 15,
            g_ALLOW_ROLLOVER => true
        )
        port map(
            ref_clk_i => ipb_clk_i,
            reset_i   => reset_i,
            en_i      => ipb_mon_miso_err_or,
            count_o   => ipb_mon_err_cnt
        );

    --===============================================================================================
    -- this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py (do not edit) 
    --==== Registers begin ==========================================================================

    --==== Registers end ============================================================================

end system_regs_arch;