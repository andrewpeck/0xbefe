------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    12:22 2016-05-10
-- Module Name:    trigger
-- Description:    This module handles everything related to sbit cluster data (link synchronization, monitoring, local triggering, matching to L1A and reporting data to DAQ)  
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

use work.gem_pkg.all;
use work.ttc_pkg.all;
use work.ipbus.all;
use work.registers.all;

entity trigger is
    generic(
        g_NUM_OF_OHs        : integer;
        g_NUM_TRIG_TX_LINKS : integer;
        g_USE_TRIG_TX_LINKS : boolean
    );
    port(
        -- reset
        reset_i             : in  std_logic;
        
        -- TTC
        ttc_clk_i           : in  t_ttc_clks;
        ttc_cmds_i          : in  t_ttc_cmds;

        -- Sbit cluster inputs
        sbit_clusters_i     : in t_oh_sbits_arr(g_NUM_OF_OHs - 1 downto 0);
        sbit_link_status_i  : in t_oh_sbit_links_arr(g_NUM_OF_OHs - 1 downto 0);

        -- Outputs
        trig_led_o          : out std_logic;
        trig_tx_data_arr_o  : out t_std234_array(g_NUM_TRIG_TX_LINKS - 1 downto 0);

        -- IPbus
        ipb_reset_i         : in  std_logic;
        ipb_clk_i           : in  std_logic;
        ipb_miso_o          : out ipb_rbus;
        ipb_mosi_i          : in  ipb_wbus
    );
end trigger;

architecture trigger_arch of trigger is
    
    signal reset_global         : std_logic;
    signal reset_local          : std_logic;
    signal reset                : std_logic;
    signal reset_cnt            : std_logic;
    
    signal oh_mask              : std_logic_vector(23 downto 0) := (others => '0');
    signal oh_triggers          : std_logic_vector(g_NUM_OF_OHs - 1 downto 0) := (others => '0');
    signal oh_num_valid_arr     : t_std4_array(g_NUM_OF_OHs - 1 downto 0);
    signal or_trigger           : std_logic;
        
    signal sbitmon_reset        : std_logic;
    signal sbitmon_sbits        : t_oh_sbits;
    signal sbitmon_l1a_delay    : std_logic_vector(31 downto 0);
    signal sbitmon_link_select  : std_logic_vector(3 downto 0);
    
    -- counters
    signal or_trigger_rate      : std_logic_vector(31 downto 0); 
    signal or_trigger_cnt       : std_logic_vector(31 downto 0); 
    
    -- OH counters
    signal sbit_overflow_cnt    : t_std32_array(g_NUM_OF_OHs - 1 downto 0);
    signal missed_comma_cnt     : t_std32_array(g_NUM_OF_OHs - 1 downto 0);
    signal link_overflow_cnt    : t_std32_array(g_NUM_OF_OHs - 1 downto 0);
    signal link_underflow_cnt   : t_std32_array(g_NUM_OF_OHs - 1 downto 0);
    signal sync_word_cnt        : t_std32_array(g_NUM_OF_OHs - 1 downto 0);
    signal trigger_rate         : t_std32_array(g_NUM_OF_OHs - 1 downto 0);
    signal trigger_cnt          : t_std32_array(g_NUM_OF_OHs - 1 downto 0);
    signal cluster_cnt_rate     : t_std32_array((g_NUM_OF_OHs * 9) - 1 downto 0);
    signal cluster_cnt          : t_std32_array((g_NUM_OF_OHs * 9) - 1 downto 0);
    
    ------ Register signals begin (this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py -- do not edit)
    ------ Register signals end ----------------------------------------------
    
begin

    --== Resets ==--
    
    i_reset_sync : entity work.synch
        generic map(
            N_STAGES => 3
        )
        port map(
            async_i => reset_i,
            clk_i   => ttc_clk_i.clk_40,
            sync_o  => reset_global
        );

    reset <= reset_global or reset_local;

    --== Trigger ==--
    
    or_trigger <= or_reduce(oh_triggers);

    i_or_trigger_rate : entity work.rate_counter
        generic map(
            g_CLK_FREQUENCY => C_TTC_CLK_FREQUENCY_SLV,
            g_COUNTER_WIDTH => 32
        )
        port map(
            clk_i   => ttc_clk_i.clk_40,
            reset_i => reset or reset_cnt,
            en_i    => or_trigger,
            rate_o  => or_trigger_rate
        );

    i_or_trigger_cnt: entity work.counter
        generic map(
            g_COUNTER_WIDTH  => 32,
            g_ALLOW_ROLLOVER => FALSE
        )
        port map(
            ref_clk_i => ttc_clk_i.clk_40,
            reset_i   => reset or reset_cnt,
            en_i      => or_trigger,
            count_o   => or_trigger_cnt
        );
    
    i_led_pulse : entity work.pulse_extend
        generic map(
            DELAY_CNT_LENGTH => C_LED_PULSE_LENGTH_TTC_CLK'length
        )
        port map(
            clk_i          => ttc_clk_i.clk_40,
            rst_i          => reset,
            pulse_length_i => C_LED_PULSE_LENGTH_TTC_CLK,
            pulse_i        => or_trigger,
            pulse_o        => trig_led_o
        );
    
    --== Links ==--
        
    -- TODO: imlpement link synchronization by looking for sync words after each resync and delay the data of all links to match the latest one (use FIFOs for that) 
    g_input_processors:
    for i in 0 to g_NUM_OF_OHs - 1 generate
        
        i_input_processor: entity work.trigger_input_processor
            port map(
                reset_i              => reset,
                reset_cnt_i          => reset_cnt,
                clk_i                => ttc_clk_i.clk_40,
                sbit_clusters_i      => sbit_clusters_i(i),
                link_status_i        => sbit_link_status_i(i),
                masked_i             => oh_mask(i),
                trigger_o            => oh_triggers(i),
                num_valid_clusters_o => oh_num_valid_arr(i),
                sbit_overflow_cnt_o  => sbit_overflow_cnt(i),
                missed_comma_cnt_o   => missed_comma_cnt(i),
                link_overflow_cnt_o  => link_overflow_cnt(i),
                link_underflow_cnt_o => link_underflow_cnt(i),
                sync_word_cnt_o      => sync_word_cnt(i),
                cluster_cnt_rate_o   => cluster_cnt_rate(((i + 1) * 9) - 1 downto i * 9),
                trigger_rate_o       => trigger_rate(i),
                cluster_cnt_o        => cluster_cnt(((i + 1) * 9) - 1 downto i * 9),
                trigger_cnt_o        => trigger_cnt(i)
            );
        
    end generate;

    --== SBit monitor ==--
    
    i_sbit_monitor : entity work.sbit_monitor
        generic map(
            g_NUM_OF_OHs => g_NUM_OF_OHs
        )
        port map(
            reset_i         => sbitmon_reset,
            ttc_clk_i       => ttc_clk_i,
            ttc_cmds_i      => ttc_cmds_i,
            link_select_i   => sbitmon_link_select,
            sbit_clusters_i => sbit_clusters_i,
            sbit_trigger_i  => oh_triggers,
            frozen_sbits_o  => sbitmon_sbits,
            l1a_dealy_o     => sbitmon_l1a_delay
        );
    
    --== Output ==--
    
    g_use_trig_out : if g_USE_TRIG_TX_LINKS generate
        i_trig_output : entity work.trigger_output
            generic map(
                g_NUM_OF_OHs        => g_NUM_OF_OHs,
                g_NUM_TRIG_TX_LINKS => g_NUM_TRIG_TX_LINKS
            )
            port map(
                reset_i            => reset_i,
                ttc_clk_i          => ttc_clk_i,
                ttc_cmds_i         => ttc_cmds_i,
                sbit_clusters_i    => sbit_clusters_i,
                sbit_num_valid_i   => oh_num_valid_arr,
                oh_triggers_i      => oh_triggers,
                oh_mask_i          => oh_mask(g_NUM_OF_OHs - 1 downto 0),
                sbit_link_status_i => sbit_link_status_i,
                trig_tx_data_arr_o => trig_tx_data_arr_o
            );
    end generate;

    g_fake_trig_out : if not g_USE_TRIG_TX_LINKS generate
        g_fake_trig_link : for i in 0 to g_NUM_TRIG_TX_LINKS - 1 generate
            trig_tx_data_arr_o(i) <= (others => '1');
        end generate;
    end generate;    
    
    --===============================================================================================
    -- this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py (do not edit) 
    --==== Registers begin ==========================================================================

    --==== Registers end ============================================================================
        
end trigger_arch;
