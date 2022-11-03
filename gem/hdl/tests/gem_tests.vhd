------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    20:38:00 2016-08-30
-- Module Name:    GEM_TESTS
-- Description:    This module is the entry point for hardware tests e.g. fiber loopback testing with generated data 
------------------------------------------------------------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common_pkg.all;
use work.gem_pkg.all;
use work.ttc_pkg.all;
use work.ipbus.all;
use work.registers.all;

entity gem_tests is
    generic(
        g_NUM_OF_OHs        : integer;
        g_NUM_GBTS_PER_OH   : integer;
        g_GEM_STATION       : integer;
        g_IPB_CLK_PERIOD_NS : integer;
        g_QUESO_EN          : boolean
    );
    port(
        -- reset
        reset_i                     : in  std_logic;
        
        -- TTC
        ttc_clk_i                   : in  t_ttc_clks;        
        ttc_cmds_i                  : in  t_ttc_cmds;
        
        -- Test control
        loopback_gbt_test_en_i      : in std_logic;
        
        -- GBT links
        gbt_link_ready_i            : in  std_logic_vector(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);
        gbt_tx_data_arr_o           : out t_gbt_frame_array(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);
        gbt_wide_rx_data_arr_i      : in  t_gbt_wide_frame_array(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);
        
        -- VFAT3 daq input for channel monitoring
        vfat3_daq_links_arr_i       : in t_oh_vfat_daq_link_arr(g_NUM_OF_OHs - 1 downto 0);

        -- GbE link
        gbe_clk_i                   : in  std_logic;
        gbe_tx_data_o               : out t_mgt_64b_tx_data;
        gbe_test_enable_o           : out std_logic; 
        
        -- IPbus
        ipb_reset_i                 : in  std_logic;
        ipb_clk_i                   : in  std_logic;
        ipb_miso_o                  : out ipb_rbus;
        ipb_mosi_i                  : in  ipb_wbus;
        
        -- QUESO Test
        queso_prbs_en               : in std_logic;
        gbt_frame_clk_i             : in std_logic;
        test_vfat3_rx_data_arr_i    : in t_vfat3_queso_arr(g_NUM_OF_OHs - 1 downto 0);
        test_vfat3_tx_data_arr_o    : out std_logic_vector(7 downto 0)
    );
end gem_tests;

architecture Behavioral of gem_tests is

    -- reset
    signal reset_global                 : std_logic;
    signal reset_local                  : std_logic;
    signal reset                        : std_logic;

    -- control
    signal gbt_loop_reset               : std_logic;
    signal gbt_loop_oh_select           : std_logic_vector(3 downto 0);
    signal gbt_loop_err_inject          : std_logic;

    -- gbt loopback oh links
    signal gbt_loop_oh_tx_links_arr     : t_gbt_frame_array(g_NUM_GBTS_PER_OH - 1 downto 0);
    signal gbt_loop_oh_rx_links_arr     : t_gbt_wide_frame_array(g_NUM_GBTS_PER_OH - 1 downto 0);
    
    -- gbt loopback status
    signal gbt_loop_locked_arr          : std_logic_vector(g_NUM_GBTS_PER_OH * 14 - 1 downto 0);
    signal gbt_loop_mega_word_cnt_arr   : t_std32_array(g_NUM_GBTS_PER_OH * 14 - 1 downto 0);
    signal gbt_loop_error_cnt_arr       : t_std32_array(g_NUM_GBTS_PER_OH * 14 - 1 downto 0);
    
    -- VFAT3 DAQ monitor
    signal vfat_daq_links24             : t_vfat_daq_link_arr(23 downto 0);
    signal vfat_daqmon_reset            : std_logic;
    signal vfat_daqmon_enable           : std_logic;
    signal vfat_daqmon_oh_select        : std_logic_vector(3 downto 0);
    signal vfat_daqmon_chan_select      : std_logic_vector(6 downto 0);
    signal vfat_daqmon_chan_global_or   : std_logic;
    signal vfat_daqmon_good_evt_cnt_arr : t_std16_array(23 downto 0); 
    signal vfat_daqmon_chan_fire_cnt_arr: t_std16_array(23 downto 0); 
    
    -- GbE test
    signal gbe_tx_data                  : t_mgt_16b_tx_data;

    signal gbe_test_enable              : std_logic;
    signal gbe_user_data                : std_logic_vector(17 downto 0);
    signal gbe_user_data_en             : std_logic;
    signal gbe_send_en                  : std_logic;
    signal gbe_busy                     : std_logic;
    signal gbe_empty                    : std_logic;
                                        
    signal gbe_manual_rd_enabled        : std_logic;
    signal gbe_manual_rd_en             : std_logic;
    signal gbe_manual_rd_valid          : std_logic;
    signal gbe_manual_rd_data           : std_logic_vector(17 downto 0);


    --QUESO TESTS
    signal elink_mapping_arr          : t_vfat3_queso_arr(g_NUM_OF_OHs - 1 downto 0);
    signal elink_error_cnt_arr        : t_vfat3_queso_arr(g_NUM_OF_OHs - 1 downto 0);
    signal queso_reset                : std_logic;

    
    ------ Register signals begin ge11 (this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py -- do not edit)
    ------ Register signals end ge11 ----------------------------------------------    

    ------ Register signals begin ge21 (this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py -- do not edit)
    ------ Register signals end ge21 ----------------------------------------------    

    ------ Register signals begin me0 (this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py -- do not edit)
    ------ Register signals end me0 ----------------------------------------------    

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
    
    --== GBT loopback test ==--
    
    g_use_gbtx : if (g_GEM_STATION = 1) or (g_GEM_STATION = 2) generate
        
        -- instantiate the OH tester
        i_oh_prbs_test : entity work.gbt_prbs_loopback_test
            generic map(
                g_NUM_GBTS_PER_OH => g_NUM_GBTS_PER_OH,
                g_TX_ELINKS_PER_GBT  => 10,
                g_RX_ELINKS_PER_GBT  => 14
            )
            port map(
                reset_i                 => reset or gbt_loop_reset,
                enable_i                => loopback_gbt_test_en_i,
                gbt_clk_i               => ttc_clk_i.clk_40,
                gbt_tx_data_arr_o       => gbt_loop_oh_tx_links_arr,
                gbt_wide_rx_data_arr_i  => gbt_loop_oh_rx_links_arr,
                error_inject_en_i       => gbt_loop_err_inject,
                elink_prbs_locked_arr_o => gbt_loop_locked_arr,
                elink_mwords_cnt_arr_o  => gbt_loop_mega_word_cnt_arr,
                elink_error_cnt_arr_o   => gbt_loop_error_cnt_arr
            );
        
        -- fanout the tester TX to all OHs
        g_tx_ohs : for oh in 0 to g_NUM_OF_OHs - 1 generate
            g_tx_gbt : for gbt in 0 to g_NUM_GBTS_PER_OH - 1 generate
                gbt_tx_data_arr_o(oh * g_NUM_GBTS_PER_OH + gbt) <= gbt_loop_oh_tx_links_arr(gbt);
            end generate;
        end generate;
        
        -- MUX the gbt RX links, and route the selected OH to the tester
        g_rx_gbt : for gbt in 0 to g_NUM_GBTS_PER_OH - 1 generate
            gbt_loop_oh_rx_links_arr(gbt) <= gbt_wide_rx_data_arr_i(to_integer(unsigned(gbt_loop_oh_select)) * g_NUM_GBTS_PER_OH + gbt);
        end generate;
        
    end generate;

    --== VFAT3 DAQ monitor ==--
    
    vfat_daq_links24 <= vfat3_daq_links_arr_i(to_integer(unsigned(vfat_daqmon_oh_select)));
    
    g_vfat3_daq_monitors : for i in 0 to 23 generate
        
        i_vfat3_daq_monitor : entity work.vfat3_daq_monitor
            port map(
                reset_i           => reset or vfat_daqmon_reset,
                enable_i          => vfat_daqmon_enable,
                ttc_clk_i         => ttc_clk_i,
                data_en_i         => vfat_daq_links24(i).data_en,
                data_i            => vfat_daq_links24(i).data,
                event_done_i      => vfat_daq_links24(i).event_done,
                crc_error_i       => vfat_daq_links24(i).crc_error,
                chan_global_or_i  => vfat_daqmon_chan_global_or,
                chan_single_idx_i => vfat_daqmon_chan_select,
                cnt_good_events_o => vfat_daqmon_good_evt_cnt_arr(i),
                cnt_chan_fired_o  => vfat_daqmon_chan_fire_cnt_arr(i)
            );
        
    end generate; 
    
    --== GbE test ==--
    
    gbe_test_enable_o <= gbe_test_enable;
    
    i_gbe_test : entity work.eth_test
        port map(
            reset_i                     => reset,
            gbe_clk_i                   => gbe_clk_i,
            gbe_tx_data_o               => gbe_tx_data,
            user_data_clk_i             => ipb_clk_i,
            user_data_i                 => gbe_user_data(15 downto 0),
            user_data_charisk_i         => gbe_user_data(17 downto 16),
            user_data_en_i              => gbe_user_data_en,
            send_en_i                   => gbe_send_en,
            busy_o                      => gbe_busy,
            empty_o                     => gbe_empty,
            manual_reading_enabled_i    => gbe_manual_rd_enabled,
            manual_read_en_i            => gbe_manual_rd_en,
            manual_read_data_o          => gbe_manual_rd_data,
            manual_read_valid_o         => gbe_manual_rd_valid
        );

    gbe_tx_data_o.txdata(15 downto 0) <= gbe_tx_data.txdata;
    gbe_tx_data_o.txcharisk(1 downto 0) <= gbe_tx_data.txcharisk;
    gbe_tx_data_o.txchardispval(1 downto 0) <= gbe_tx_data.txchardispval;
    gbe_tx_data_o.txchardispmode(1 downto 0) <= gbe_tx_data.txchardispmode;
    
    queso_test_en_o <= queso_enable

    i_queso_test : entity work.queso_tests
        generic map(
            g_IPB_CLK_PERIOD_NS => g_IPB_CLK_PERIOD_NS,
            g_NUM_OF_OHs        => g_NUM_OF_OHs,
            g_NUM_VFATS_PER_OH  => 24,
            g_QUESO_EN          => g_QUESO_EN 
        );
        port map(
            reset_i                     => reset, --resets prbs generator
            counter_reset               => queso_reset, --resets prbs counter
            queso_test_en_i             => queso_prbs_en, --enables prbs generator
            gbt_frame_clk_i             => ttc_clocks_i.clk_40,
            test_vfat3_rx_data_arr_i    => queso_vfat3_rx_data_arr,
            test_vfat3_tx_data_arr_o    => queso_vfat3_tx_data_arr,
            elink_mapping_arr_i         => elink_mapping_arr,
            elink_error_cnt_arr_o       => queso_prbs_err_arr-- counts up to ff errors per elink
        );

    g_reg_ge11 : if g_GEM_STATION = 1 generate
    --==== Registers begin ge11 ==========================================================================
    --==== Registers end ge11 ============================================================================
    end generate;

    g_reg_ge21 : if g_GEM_STATION = 2 generate
    --==== Registers begin ge21 ==========================================================================
    --==== Registers end ge21 ============================================================================
    end generate;

    g_reg_me0 : if g_GEM_STATION = 0 generate
    --==== Registers begin me0 ==========================================================================
    --==== Registers end me0 ============================================================================
    end generate;

end Behavioral;
