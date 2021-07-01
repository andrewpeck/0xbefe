------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    23:45:21 2016-04-20
-- Module Name:    GEM_AMC 
-- Description:    This is the top module of all the common GEM AMC logic. It is board-agnostic and can be used in different FPGA / board designs 
--                 Note: the GBT MGT data and clocks must be ordered in groups of 3 for each OH: OH0 GBT0, OH0 GBT1, OH0 GBT2, OH1 GBT0, OH1 GTB1, OH1 GBT2, OH2 GBT0, etc... 
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;

use work.common_pkg.all;
use work.gem_pkg.all;
use work.board_config_package.all;
use work.ipb_addr_decode.all;
use work.ipbus.all;
use work.ttc_pkg.all;
use work.lpgbtfpga_package.all;

entity gem_amc is
    generic(
        g_GEM_STATION        : integer;
        g_NUM_OF_OHs         : integer;
        g_NUM_GBTS_PER_OH    : integer;
        g_NUM_VFATS_PER_OH   : integer;
        g_USE_TRIG_TX_LINKS  : boolean := true;  -- if true, then trigger output links will be instantiated
        g_NUM_TRIG_TX_LINKS  : integer;
        
        g_NUM_IPB_SLAVES     : integer;
        g_IPB_CLK_PERIOD_NS  : integer; 
        g_DAQ_CLK_FREQ       : integer;
        g_DISABLE_TTC_DATA   : boolean := false; -- set this to true when ttc_data_p_i / ttc_data_n_i are not connected to anything, this will disable ttc data completely (generator can still be used though)
        
        -- Firmware version, date, time, git sha
        g_FW_DATE            : std_logic_vector (31 downto 0);
        g_FW_TIME            : std_logic_vector (31 downto 0);
        g_FW_VER             : std_logic_vector (31 downto 0);
        g_FW_SHA             : std_logic_vector (31 downto 0)        
    );
    port(
        reset_i                 : in   std_logic;
        reset_pwrup_o           : out  std_logic;

        -- TTC
        ttc_clocks_i            : in  t_ttc_clks;
        ttc_clk_status_i        : in  t_ttc_clk_status;
        ttc_clk_ctrl_o          : out t_ttc_clk_ctrl;
        ttc_data_p_i            : in  std_logic;      -- TTC protocol backplane signals
        ttc_data_n_i            : in  std_logic;
        
        -- Trigger RX GTX / GTH links (3.2Gbs, 16bit @ 160MHz w/ 8b10b encoding)
        gt_trig0_rx_clk_arr_i   : in  std_logic_vector(g_NUM_OF_OHs - 1 downto 0);
        gt_trig0_rx_data_arr_i  : in  t_mgt_16b_rx_data_arr(g_NUM_OF_OHs - 1 downto 0);
        gt_trig1_rx_clk_arr_i   : in  std_logic_vector(g_NUM_OF_OHs - 1 downto 0);
        gt_trig1_rx_data_arr_i  : in  t_mgt_16b_rx_data_arr(g_NUM_OF_OHs - 1 downto 0);

        -- Trigger TX GTH links (10.24Gbs, 32bit @ 320MHz with LpGBT encoding)
        gt_trig_tx_data_arr_o   : out t_std64_array(g_NUM_TRIG_TX_LINKS - 1 downto 0);
        gt_trig_tx_clk_i        : in  std_logic;
        gt_trig_tx_status_arr_i : in  t_mgt_status_arr(g_NUM_TRIG_TX_LINKS - 1 downto 0);
        trig_tx_data_raw_arr_o  : out t_std234_array(g_NUM_TRIG_TX_LINKS - 1 downto 0); -- this raw data before lpgbt encoding, and is only meant for debugging

        -- GBT DAQ + Control GTX / GTH links (4.8Gbs, 40bit @ 120MHz without encoding when using GBTX, and 10.24Gbp, lower 32bit @ 320MHz without encoding when using LpGBT)
        gt_gbt_rx_data_arr_i    : in  t_std40_array(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);
        gt_gbt_tx_data_arr_o    : out t_std40_array(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);
        gt_gbt_rx_clk_arr_i     : in  std_logic_vector(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);
        gt_gbt_tx_clk_arr_i     : in  std_logic_vector(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);
        gt_gbt_rx_common_clk_i  : in  std_logic;
        
        gt_gbt_status_arr_i     : in  t_mgt_status_arr(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);
        gt_gbt_ctrl_arr_o       : out t_mgt_ctrl_arr(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);

        -- IPbus
        ipb_reset_i             : in  std_logic;
        ipb_clk_i               : in  std_logic;
        ipb_miso_arr_o          : out ipb_rbus_array(g_NUM_IPB_SLAVES - 1 downto 0);
        ipb_mosi_arr_i          : in  ipb_wbus_array(g_NUM_IPB_SLAVES - 1 downto 0);
        
        -- LEDs
        led_l1a_o               : out std_logic;
        led_trigger_o           : out std_logic;
        
        -- DAQLink
        daq_data_clk_i          : in  std_logic;
        daq_data_clk_locked_i   : in  std_logic;
        daq_to_daqlink_o        : out t_daq_to_daqlink;
        daqlink_to_daq_i        : in  t_daqlink_to_daq;
        
        -- Board serial number
        board_id_i              : in std_logic_vector(15 downto 0);
      
        -- PROMless
        to_promless_o           : out t_to_promless;
        from_promless_i         : in  t_from_promless
        
    );
end gem_amc;

architecture gem_amc_arch of gem_amc is

    --================================--
    -- Components  
    --================================--

    component ila_gbt
        port(
            clk     : in std_logic;
            probe0  : in std_logic_vector(83 downto 0);
            probe1  : in std_logic_vector(83 downto 0);
            probe2  : in std_logic_vector(31 downto 0);
            probe3  : in std_logic;
            probe4  : in std_logic;
            probe5  : in std_logic;
            probe6  : in std_logic;
            probe7  : in std_logic;
            probe8  : in std_logic_vector(5 downto 0)
        );
    end component;

    component ila_lpgbt
        port(
            clk     : in std_logic;
            probe0  : in std_logic_vector(31 downto 0);
            probe1  : in std_logic_vector(223 downto 0);
            probe2  : in std_logic;
            probe3  : in std_logic;
            probe4  : in std_logic;
            probe5  : in std_logic;
            probe6  : in std_logic;
            probe7  : in std_logic_vector(1 downto 0);
            probe8  : in std_logic_vector(1 downto 0);
            probe9  : in std_logic_vector(1 downto 0);
            probe10 : in std_logic_vector(1 downto 0);
            probe11  : in std_logic
        );
    end component;

    component vio_debug_link_selector
        port(
            clk        : in  std_logic;
            probe_out0 : out std_logic_vector(5 downto 0);
            probe_out1 : out std_logic_vector(4 downto 0);
            probe_out2 : out std_logic;
            probe_out3 : out std_logic
        );
    end component;

    --================================--
    -- Signals
    --================================--

    --== General ==--
    signal reset                : std_logic;
    signal reset_pwrup          : std_logic;
    signal ipb_reset            : std_logic;
    signal link_reset           : std_logic;
    signal manual_link_reset    : std_logic;
    signal manual_gbt_reset     : std_logic;
    signal manual_global_reset  : std_logic;
    signal manual_ipbus_reset   : std_logic;

    --== TTC signals ==--
    signal ttc_cmd              : t_ttc_cmds;
    signal ttc_counters         : t_ttc_daq_cntrs;
    signal ttc_status           : t_ttc_status;

    --== Trigger signals ==--    
    signal sbit_clusters_arr        : t_oh_clusters_arr(g_NUM_OF_OHs - 1 downto 0);
    signal sbit_links_status_arr    : t_oh_sbit_links_arr(g_NUM_OF_OHs - 1 downto 0);
    signal emtf_data_arr            : t_std234_array(g_NUM_TRIG_TX_LINKS - 1 downto 0);

    signal vfat3_sbits_arr          : t_vfat3_sbits_arr(g_NUM_OF_OHs - 1 downto 0);
    
    --== GBT ==--
    signal gbt_tx_data_arr              : t_gbt_frame_array(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);    
    signal lpgbt_tx_data_arr            : t_lpgbt_tx_frame_array(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);    
            
    signal gbt_rx_data_arr              : t_gbt_frame_array(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);    
    signal gbt_rx_data_widebus_arr      : t_std32_array(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);    
    signal lpgbt_rx_data_arr            : t_lpgbt_rx_frame_array(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);    
    signal gbt_rx_valid_arr             : std_logic_vector(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);
    
    signal gbt_tx_bitslip_arr           : t_std7_array(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);
    
    signal gbt_link_status_arr          : t_gbt_link_status_arr(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);
    signal gbt_ready_arr                : std_logic_vector(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);
    
    signal lpgbt_reset_tx               : std_logic;
    signal lpgbt_reset_rx               : std_logic;

    --== GBT elinks ==--
    signal sca_tx_data_arr              : t_std2_array(g_NUM_OF_OHs - 1 downto 0);
    signal sca_rx_data_arr              : t_std2_array(g_NUM_OF_OHs - 1 downto 0);
    signal gbt_ic_tx_data_arr           : t_std2_array(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);
    signal gbt_ic_rx_data_arr           : t_std2_array(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);
    signal promless_tx_data             : std_logic_vector(15 downto 0);
    signal oh_fpga_tx_data_arr          : t_std8_array(g_NUM_OF_OHs - 1 downto 0);
    signal oh_fpga_rx_data_arr          : t_std8_array(g_NUM_OF_OHs - 1 downto 0);
    signal vfat3_tx_data_arr            : t_vfat3_elinks_arr(g_NUM_OF_OHs - 1 downto 0);
    signal vfat3_rx_data_arr            : t_vfat3_elinks_arr(g_NUM_OF_OHs - 1 downto 0);
    signal me0_vfat3_sbits_arr          : t_vfat3_sbits_arr(g_NUM_OF_OHs - 1 downto 0);
    signal ge21_gbt_trig_data_arr       : t_std88_array(g_NUM_OF_OHs - 1 downto 0);
    
    --== VFAT3 ==--
    signal vfat3_sc_only_mode           : std_logic;
    signal vfat3_tx_stream              : std_logic_vector(7 downto 0);
    signal vfat3_tx_idle                : std_logic;
    signal vfat3_sync                   : std_logic;
    signal vfat3_sync_verify            : std_logic;
    signal vfat3_link_status_arr        : t_oh_vfat_link_status_arr(g_NUM_OF_OHs - 1 downto 0);
    
    signal vfat3_sc_tx_data             : std_logic;
    signal vfat3_sc_tx_rd_en            : std_logic;
    signal vfat3_sc_tx_rd_en_per_oh     : std_logic_vector(g_NUM_OF_OHs - 1 downto 0);
    signal vfat3_sc_tx_empty            : std_logic;
    signal vfat3_sc_tx_oh_idx           : std_logic_vector(3 downto 0);
    signal vfat3_sc_tx_vfat_idx         : std_logic_vector(4 downto 0);
    signal vfat3_sc_rx_data             : t_std24_array(g_NUM_OF_OHs - 1 downto 0);
    signal vfat3_sc_rx_data_en          : t_std24_array(g_NUM_OF_OHs - 1 downto 0);
    signal vfat3_sc_status              : t_vfat_slow_control_status;    
    
    signal vfat3_daq_link_arr           : t_oh_vfat_daq_link_arr(g_NUM_OF_OHs - 1 downto 0);
    signal vfat3_gbt_ready_arr          : t_std24_array(g_NUM_OF_OHs - 1 downto 0);
    
    signal vfat_mask_arr                : t_std24_array(g_NUM_OF_OHs - 1 downto 0);
    
    signal use_v3b_elink_mapping        : std_logic;
    signal vfat_hdlc_address_arr        : t_std4_array(23 downto 0);

    -- test module links
    signal test_gbt_wide_rx_data_arr    : t_gbt_wide_frame_array((g_NUM_OF_OHs * g_NUM_GBTS_PER_OH) - 1 downto 0);
    signal test_gbt_tx_data_arr         : t_gbt_frame_array((g_NUM_OF_OHs * g_NUM_GBTS_PER_OH) - 1 downto 0);
    signal test_gbt_ready_arr           : std_logic_vector((g_NUM_OF_OHs * g_NUM_GBTS_PER_OH) - 1 downto 0);
        
    --== TEST module ==--
    signal loopback_gbt_test_en         : std_logic; 
    
    --== Other ==--
    signal promless_stats               : t_promless_stats;
    signal promless_cfg                 : t_promless_cfg;
    signal ipb_miso_arr                 : ipb_rbus_array(g_NUM_IPB_SLAVES - 1 downto 0) := (others => (ipb_rdata => (others => '0'), ipb_ack => '0', ipb_err => '0'));
    
    --== Debug ==--
    signal dbg_lpgbt_tx_data            : t_lpgbt_tx_frame;
    signal dbg_lpgbt_rx_data            : t_lpgbt_rx_frame;
    signal dbg_gbt_tx_data              : std_logic_vector(83 downto 0);
    signal dbg_gbt_rx_data              : std_logic_vector(83 downto 0);
    signal dbg_gbt_wide_rx_data         : std_logic_vector(31 downto 0);
    signal dbg_gbt_rx_valid             : std_logic;
    signal dbg_gbt_link_status          : t_gbt_link_status;

    signal dbg_gbt_link_select          : std_logic_vector(5 downto 0);
    signal dbg_vfat_link_select         : std_logic_vector(4 downto 0);

begin

    --================================--
    -- Wiring
    --================================--
    
    reset_pwrup_o <= reset_pwrup;
    reset <= reset_i or reset_pwrup or manual_global_reset;
    ipb_reset <= ipb_reset_i or reset_pwrup or manual_ipbus_reset;
    ipb_miso_arr_o <= ipb_miso_arr;
    link_reset <= manual_link_reset or ttc_cmd.hard_reset;

    -- select the GBT link to debug
    dbg_gbt_tx_data               <= gbt_tx_data_arr(to_integer(unsigned(dbg_gbt_link_select)));
    dbg_gbt_rx_data               <= gbt_rx_data_arr(to_integer(unsigned(dbg_gbt_link_select)));
    dbg_gbt_wide_rx_data          <= gbt_rx_data_widebus_arr(to_integer(unsigned(dbg_gbt_link_select)));
    dbg_lpgbt_tx_data             <= lpgbt_tx_data_arr(to_integer(unsigned(dbg_gbt_link_select)));
    dbg_lpgbt_rx_data             <= lpgbt_rx_data_arr(to_integer(unsigned(dbg_gbt_link_select)));
    dbg_gbt_rx_valid              <= gbt_rx_valid_arr(to_integer(unsigned(dbg_gbt_link_select)));
    dbg_gbt_link_status           <= gbt_link_status_arr(to_integer(unsigned(dbg_gbt_link_select)));
    
    --================================--
    -- Power-on reset  
    --================================--
    
    process(ttc_clocks_i.clk_40) -- NOTE: using TTC clock, no nothing will work if there's no TTC clock
        variable countdown : integer := 40_000_000; -- 1s - probably way too long, but ok for now (this is only used after powerup)
    begin
        if (rising_edge(ttc_clocks_i.clk_40)) then
            if (countdown > 0) then
              reset_pwrup <= '1';
              countdown := countdown - 1;
            else
              reset_pwrup <= '0';
            end if;
        end if;
    end process;    
    
    --================================--
    -- TTC  
    --================================--

    i_ttc : entity work.ttc
        generic map (
            g_DISABLE_TTC_DATA  => g_DISABLE_TTC_DATA,
            g_IPB_CLK_PERIOD_NS => g_IPB_CLK_PERIOD_NS
        )
        port map(
            reset_i             => reset,
            ttc_clks_i          => ttc_clocks_i,
            ttc_clks_status_i   => ttc_clk_status_i,
            ttc_clks_ctrl_o     => ttc_clk_ctrl_o,
            ttc_data_p_i        => ttc_data_p_i,
            ttc_data_n_i        => ttc_data_n_i,
            local_l1a_req_i     => '0',
            ttc_cmds_o          => ttc_cmd,
            ttc_daq_cntrs_o     => ttc_counters,
            ttc_status_o        => ttc_status,
            l1a_led_o           => led_l1a_o,
            ipb_reset_i         => ipb_reset,
            ipb_clk_i           => ipb_clk_i,
            ipb_mosi_i          => ipb_mosi_arr_i(C_IPB_SLV.ttc),
            ipb_miso_o          => ipb_miso_arr(C_IPB_SLV.ttc)
        );
    
    --================================--
    -- VFAT3 TX stream  
    --================================--

    i_vfat3_tx_stream : entity work.vfat3_tx_stream
        port map(
            reset_i        => reset or link_reset,
            ttc_clk_i      => ttc_clocks_i,
            ttc_cmds_i     => ttc_cmd,
            sc_only_mode_i => vfat3_sc_only_mode,
            data_o         => vfat3_tx_stream,
            idle_o         => vfat3_tx_idle,
            sync_o         => vfat3_sync,
            sync_verify_o  => vfat3_sync_verify
        );

    --================================--
    -- VFAT3 Slow Control    TODO: move into slow control module 
    --================================--
    
    i_vfat3_slow_control : entity work.vfat3_slow_control
        generic map(
            g_NUM_OF_OHs => g_NUM_OF_OHs,
            g_IPB_CLK_PERIOD_NS => g_IPB_CLK_PERIOD_NS
        )
        port map(
            reset_i                 => reset or link_reset,
            ttc_clk_i               => ttc_clocks_i,
            ipb_clk_i               => ipb_clk_i,
            ipb_mosi_i              => ipb_mosi_arr_i(C_IPB_SLV.vfat3),
            ipb_miso_o              => ipb_miso_arr(C_IPB_SLV.vfat3),
            tx_data_o               => vfat3_sc_tx_data,
            tx_rd_en_i              => vfat3_sc_tx_rd_en,
            tx_empty_o              => vfat3_sc_tx_empty,
            tx_oh_idx_o             => vfat3_sc_tx_oh_idx,
            tx_vfat_idx_o           => vfat3_sc_tx_vfat_idx,
            rx_data_en_i            => vfat3_sc_rx_data_en,
            rx_data_i               => vfat3_sc_rx_data,
            status_o                => vfat3_sc_status,
            vfat_hdlc_address_arr_i => vfat_hdlc_address_arr
        );

    --================================--
    -- Optohybrids  
    --================================--
    
    i_optohybrids : for i in 0 to g_NUM_OF_OHs - 1 generate

        i_optohybrid_single : entity work.optohybrid
            generic map(
                g_GEM_STATION       => g_GEM_STATION,
                g_OH_VERSION        => CFG_OH_VERSION,
                g_OH_IDX            => std_logic_vector(to_unsigned(i, 4)),
                g_IPB_CLK_PERIOD_NS => g_IPB_CLK_PERIOD_NS,
                g_DEBUG             => CFG_DEBUG_OH and (i = 0)
            )
            port map(
                reset_i                 => reset or link_reset,
                ttc_clk_i               => ttc_clocks_i,
                ttc_cmds_i              => ttc_cmd,

                vfat3_tx_datastream_i   => vfat3_tx_stream,
                vfat3_tx_idle_i         => vfat3_tx_idle,
                vfat3_sync_i            => vfat3_sync,
                vfat3_sync_verify_i     => vfat3_sync_verify,

                fpga_tx_data_o          => oh_fpga_tx_data_arr(i),
                fpga_rx_data_i          => oh_fpga_rx_data_arr(i),

                vfat3_tx_data_o         => vfat3_tx_data_arr(i),
                vfat3_rx_data_i         => vfat3_rx_data_arr(i),
                vfat3_link_status_o     => vfat3_link_status_arr(i),
                vfat_mask_arr_i         => vfat_mask_arr(i),
                vfat_gbt_ready_arr_i    => vfat3_gbt_ready_arr(i),

                vfat3_sc_tx_data_i      => vfat3_sc_tx_data,
                vfat3_sc_tx_empty_i     => vfat3_sc_tx_empty,
                vfat3_sc_tx_oh_idx_i    => vfat3_sc_tx_oh_idx,
                vfat3_sc_tx_vfat_idx_i  => vfat3_sc_tx_vfat_idx,
                vfat3_sc_tx_rd_en_o     => vfat3_sc_tx_rd_en_per_oh(i),
                
                vfat3_sc_rx_data_o      => vfat3_sc_rx_data(i),
                vfat3_sc_rx_data_en_o   => vfat3_sc_rx_data_en(i),

                vfat3_daq_links_o       => vfat3_daq_link_arr(i),
                                
                sbit_clusters_o         => sbit_clusters_arr(i), 
                sbit_links_status_o     => sbit_links_status_arr(i), 
                ge21_gbt_trig_data_i    => ge21_gbt_trig_data_arr(i),
                gth_rx_trig_data_i      => (gt_trig0_rx_data_arr_i(i), gt_trig1_rx_data_arr_i(i)),
                gth_rx_trig_usrclk_i    => (gt_trig0_rx_clk_arr_i(i), gt_trig1_rx_clk_arr_i(i)),

                oh_reg_ipb_reset_i      => ipb_reset,
                oh_reg_ipb_clk_i        => ipb_clk_i,
                oh_reg_ipb_miso_o       => ipb_miso_arr(C_IPB_SLV.oh_reg(i)),
                oh_reg_ipb_mosi_i       => ipb_mosi_arr_i(C_IPB_SLV.oh_reg(i)),
                
                debug_vfat_select_i     => dbg_vfat_link_select
            );    
    
    end generate;

    vfat3_sc_tx_rd_en <= or_reduce(vfat3_sc_tx_rd_en_per_oh);

    --================================--
    -- Trigger  
    --================================--

    i_trigger : entity work.trigger
        generic map(
            g_NUM_OF_OHs        => g_NUM_OF_OHs,
            g_NUM_TRIG_TX_LINKS => g_NUM_TRIG_TX_LINKS,
            g_USE_TRIG_TX_LINKS => g_USE_TRIG_TX_LINKS,
            g_IPB_CLK_PERIOD_NS => g_IPB_CLK_PERIOD_NS,
            g_DEBUG             => CFG_DEBUG_TRIGGER
        )
        port map(
            reset_i            => reset or link_reset,
            ttc_clk_i          => ttc_clocks_i,
            ttc_cmds_i         => ttc_cmd,
            sbit_clusters_i    => sbit_clusters_arr,
            sbit_link_status_i => sbit_links_status_arr,
            trig_led_o         => led_trigger_o,
            trig_tx_data_arr_o => emtf_data_arr,      
            ipb_reset_i        => ipb_reset,
            ipb_clk_i          => ipb_clk_i,
            ipb_miso_o         => ipb_miso_arr(C_IPB_SLV.trigger),
            ipb_mosi_i         => ipb_mosi_arr_i(C_IPB_SLV.trigger),

	    vfat3_sbits_arr_i  => vfat3_sbits_arr
        );

    --================================--
    -- EMTF Transmitters (LpGBT TX)  
    --================================--
    
    g_emtf_links_enabled : if g_USE_TRIG_TX_LINKS generate
        g_emtf_links : for i in 0 to g_NUM_TRIG_TX_LINKS - 1 generate
            
            i_emtf_lpgbt_tx : entity work.lpgbt_10g_tx
                generic map (
                    g_MGT_TX_BUS_WIDTH => 64,
                    g_TXUSRCLK_TO_TTC40_RATIO => 4
                )
                port map(
                    reset_i            => reset,
                    clk40_i            => ttc_clocks_i.clk_40,
                    mgt_tx_usrclk_i    => gt_trig_tx_clk_i,
                    mgt_tx_ready_i     => gt_trig_tx_status_arr_i(i).tx_reset_done,
                    mgt_tx_data_o      => gt_trig_tx_data_arr_o(i),
                    tx_data_i          => emtf_data_arr(i),
                    tx_ready_o         => open,
                    tx_had_not_ready_o => open
                );
            
        end generate;
    end generate;
    
    trig_tx_data_raw_arr_o <= emtf_data_arr;
    
    g_emtf_links_disabled : if not g_USE_TRIG_TX_LINKS generate
        gt_trig_tx_data_arr_o <= (others => (others => '0'));
    end generate;
    
    --================================--
    -- ME0 Trigger  
    --================================--

--    i_trigger : entity work.trigger
--        generic map(
--            g_NUM_OF_OHs => g_NUM_OF_OHs,
--            g_NUM_TRIG_TX_LINKS => g_NUM_TRIG_TX_LINKS,
--            g_USE_TRIG_TX_LINKS => g_USE_TRIG_TX_LINKS
--        )
--        port map(
--            reset_i            => reset or link_reset,
--            ttc_clk_i          => ttc_clocks_i,
--            ttc_cmds_i         => ttc_cmd,
--            sbit_clusters_i    => sbit_clusters_arr,
--            sbit_link_status_i => sbit_links_status_arr,
--            trig_led_o         => led_trigger_o,
--            tx_link_clk_i      => gt_trig_tx_clk_i,
--            trig_tx_data_arr_o => gt_trig_tx_data_arr_o,      
--            ipb_reset_i        => ipb_reset,
--            ipb_clk_i          => ipb_clk_i,
--            ipb_miso_o         => ipb_miso_arr(C_IPB_SLV.trigger),
--            ipb_mosi_i         => ipb_mosi_arr_i(C_IPB_SLV.trigger)
--        );
--
--me0_vfat3_sbits_arr

    --================================--
    -- DAQ  
    --================================--

    i_daq : entity work.daq
        generic map(
            g_NUM_OF_OHs        => g_NUM_OF_OHs,
            g_DAQ_CLK_FREQ      => g_DAQ_CLK_FREQ,
            g_INCLUDE_SPY_FIFO  => false,
            g_IPB_CLK_PERIOD_NS => g_IPB_CLK_PERIOD_NS,
            g_DEBUG             => CFG_DEBUG_DAQ
        )
        port map(
            reset_i                 => reset,
            daq_clk_i               => daq_data_clk_i,
            daq_clk_locked_i        => daq_data_clk_locked_i,
            daq_to_daqlink_o        => daq_to_daqlink_o,
            daqlink_to_daq_i        => daqlink_to_daq_i,
            ttc_clks_i              => ttc_clocks_i,
            ttc_cmds_i              => ttc_cmd,
            ttc_daq_cntrs_i         => ttc_counters,
            ttc_status_i            => ttc_status,
            vfat3_daq_clk_i         => ttc_clocks_i.clk_40,
            vfat3_daq_links_arr_i   => vfat3_daq_link_arr,
            ipb_reset_i             => ipb_reset,
            ipb_clk_i               => ipb_clk_i,
            ipb_mosi_i              => ipb_mosi_arr_i(C_IPB_SLV.daq),
            ipb_miso_o              => ipb_miso_arr(C_IPB_SLV.daq),
            board_sn_i              => board_id_i
        );    

    ------------ DEBUG - fanout DAQ data from OH1 to all DAQ inputs --------------
--    g_fake_daq_links : for i in 0 to g_NUM_OF_OHs - 1 generate
--        fake_tk_data_links(i) <= tk_data_links(1);
--    end generate;

    --================================--
    -- GEM System
    --================================--

    i_gem_system : entity work.gem_system_regs
        generic map(
            g_NUM_IPB_MON_SLAVES => g_NUM_IPB_SLAVES,
            g_IPB_CLK_PERIOD_NS  => g_IPB_CLK_PERIOD_NS,
            g_FW_DATE            => g_FW_DATE,
            g_FW_TIME            => g_FW_TIME,
            g_FW_VER             => g_FW_VER,
            g_FW_SHA             => g_FW_SHA
        )
        port map(
            ttc_clks_i                  => ttc_clocks_i,            
            reset_i                     => reset,
            ipb_clk_i                   => ipb_clk_i,
            ipb_reset_i                 => ipb_reset,
            ipb_mosi_i                  => ipb_mosi_arr_i(C_IPB_SLV.system),
            ipb_miso_o                  => ipb_miso_arr(C_IPB_SLV.system),
            ipb_mon_miso_arr_i          => ipb_miso_arr,
            board_id_o                  => open,
            loopback_gbt_test_en_o      => loopback_gbt_test_en,
            vfat3_sc_only_mode_o        => vfat3_sc_only_mode,
            use_v3b_elink_mapping_o     => use_v3b_elink_mapping,
            vfat_hdlc_address_arr_o     => vfat_hdlc_address_arr,
            manual_link_reset_o         => manual_link_reset,
            global_reset_o              => manual_global_reset,
            manual_ipbus_reset_o        => manual_ipbus_reset,
            gbt_reset_o                 => manual_gbt_reset,
            promless_stats_i            => promless_stats,
            promless_cfg_o              => promless_cfg
        );

    --===============================--
    -- OH Link Counters and settings --
    --===============================--

    i_oh_link_registers : entity work.oh_link_regs
        generic map(
            g_NUM_OF_OHs        => g_NUM_OF_OHs,
            g_NUM_GBTS_PER_OH   => g_NUM_GBTS_PER_OH,
            g_IPB_CLK_PERIOD_NS => g_IPB_CLK_PERIOD_NS
        )
        port map(
            reset_i                 => reset,
            clk_i                   => ttc_clocks_i.clk_40,

            gbt_link_status_arr_i   => gbt_link_status_arr,
            vfat3_link_status_arr_i => vfat3_link_status_arr,

            vfat_mask_arr_o         => vfat_mask_arr,
            gbt_tx_bitslip_arr_o    => gbt_tx_bitslip_arr,

            ipb_reset_i             => ipb_reset,
            ipb_clk_i               => ipb_clk_i,
            ipb_miso_o              => ipb_miso_arr(C_IPB_SLV.oh_links),
            ipb_mosi_i              => ipb_mosi_arr_i(C_IPB_SLV.oh_links)
        );

    --===================--
    --    Slow Control   --
    --===================--

    i_slow_control : entity work.slow_control
        generic map(
            g_NUM_OF_OHs        => g_NUM_OF_OHs,
            g_NUM_GBTS_PER_OH   => g_NUM_GBTS_PER_OH,
            g_IPB_CLK_PERIOD_NS => g_IPB_CLK_PERIOD_NS,
            g_DEBUG             => false
        )
        port map(
            reset_i             => reset,
            ttc_clk_i           => ttc_clocks_i,
            ttc_cmds_i          => ttc_cmd,
            gbt_rx_ready_i      => gbt_ready_arr,
            gbt_rx_sca_elinks_i => sca_rx_data_arr,
            gbt_tx_sca_elinks_o => sca_tx_data_arr,
            gbt_rx_ic_elinks_i  => gbt_ic_rx_data_arr,
            gbt_tx_ic_elinks_o  => gbt_ic_tx_data_arr,
            vfat3_sc_status_i   => vfat3_sc_status,
            ipb_reset_i         => ipb_reset,
            ipb_clk_i           => ipb_clk_i,
            ipb_miso_o          => ipb_miso_arr(C_IPB_SLV.slow_control),
            ipb_mosi_i          => ipb_mosi_arr_i(C_IPB_SLV.slow_control)
        );

    --=============--
    --    Tests    --
    --=============--
    
    i_gem_tests : entity work.gem_tests
        generic map(
            g_NUM_OF_OHs        => g_NUM_OF_OHs,
            g_NUM_GBTS_PER_OH   => g_NUM_GBTS_PER_OH,
            g_GEM_STATION       => g_GEM_STATION,
            g_IPB_CLK_PERIOD_NS => g_IPB_CLK_PERIOD_NS
        )
        port map(
            reset_i                     => reset_i,
            ttc_clk_i                   => ttc_clocks_i,
            ttc_cmds_i                  => ttc_cmd,
            loopback_gbt_test_en_i      => loopback_gbt_test_en,
            gbt_link_ready_i            => test_gbt_ready_arr,
            gbt_tx_data_arr_o           => test_gbt_tx_data_arr,
            gbt_wide_rx_data_arr_i      => test_gbt_wide_rx_data_arr,
            vfat3_daq_links_arr_i       => vfat3_daq_link_arr,
            ipb_reset_i                 => ipb_reset,
            ipb_clk_i                   => ipb_clk_i,
            ipb_mosi_i                  => ipb_mosi_arr_i(C_IPB_SLV.test),
            ipb_miso_o                  => ipb_miso_arr(C_IPB_SLV.test)
        );
        
    --==========--
    --    GBT   --
    --==========--
    
    g_gbtx : if (g_GEM_STATION = 1) or (g_GEM_STATION = 2) generate
        i_gbt : entity work.gbt
            generic map(
                NUM_LINKS           => g_NUM_OF_OHs * g_NUM_GBTS_PER_OH,
                TX_OPTIMIZATION     => 1,
                RX_OPTIMIZATION     => 0,
                TX_ENCODING         => 0,
                RX_ENCODING_EVEN    => 0,
                RX_ENCODING_ODD     => CFG_GBT_WIDEBUS,
                g_USE_RX_SYNC_FIFOS => false
            )
            port map(
                reset_i                     => reset or manual_gbt_reset,
                cnt_reset_i                 => link_reset,
                
                tx_frame_clk_i              => ttc_clocks_i.clk_40,
                rx_frame_clk_i              => ttc_clocks_i.clk_40,
                rx_word_common_clk_i        => gt_gbt_rx_common_clk_i,
                tx_word_clk_arr_i           => gt_gbt_tx_clk_arr_i,
                rx_word_clk_arr_i           => gt_gbt_rx_clk_arr_i,
                
                tx_we_arr_i                 => (others => '1'),
                tx_data_arr_i               => gbt_tx_data_arr,
                tx_bitslip_cnt_i            => gbt_tx_bitslip_arr,
                
                rx_data_valid_arr_o         => gbt_rx_valid_arr,
                rx_data_arr_o               => gbt_rx_data_arr,
                rx_data_widebus_arr_o       => gbt_rx_data_widebus_arr,
                
                mgt_status_arr_i            => gt_gbt_status_arr_i,
                mgt_ctrl_arr_o              => gt_gbt_ctrl_arr_o,
                mgt_tx_data_arr_o           => gt_gbt_tx_data_arr_o,
                mgt_rx_data_arr_i           => gt_gbt_rx_data_arr_i,
                
                link_status_arr_o           => gbt_link_status_arr
            );
    end generate;

    g_lbgbt : if g_GEM_STATION = 0 generate
        i_gbt : entity work.lpgbt
            generic map(
                g_NUM_LINKS             => g_NUM_OF_OHs * g_NUM_GBTS_PER_OH,
                g_SKIP_ODD_TX           => false,
                g_RX_RATE               => DATARATE_10G24,
                g_RX_ENCODING           => FEC5,
                g_RESET_MGT_ON_EVEN     => 0,
                g_USE_RX_SYNC_FIFOS     => false,
                g_USE_RX_CORRECTION_CNT => true
            )
            port map(
                reset_i              => reset_i or manual_gbt_reset,
                reset_tx_i           => lpgbt_reset_tx or manual_gbt_reset,
                reset_rx_i           => lpgbt_reset_rx or manual_gbt_reset,
                cnt_reset_i          => link_reset,
                tx_frame_clk_i       => ttc_clocks_i.clk_40,
                rx_frame_clk_i       => ttc_clocks_i.clk_40,
                tx_word_clk_arr_i    => gt_gbt_tx_clk_arr_i,
                rx_word_clk_arr_i    => gt_gbt_rx_clk_arr_i,
                rx_word_common_clk_i => gt_gbt_rx_common_clk_i,
                mgt_status_arr_i     => gt_gbt_status_arr_i,
                mgt_ctrl_arr_o       => gt_gbt_ctrl_arr_o,
                mgt_tx_data_arr_o    => gt_gbt_tx_data_arr_o,
                mgt_rx_data_arr_i    => gt_gbt_rx_data_arr_i,
                tx_data_arr_i        => lpgbt_tx_data_arr,
                rx_data_arr_o        => lpgbt_rx_data_arr,
                link_status_arr_o    => gbt_link_status_arr
            );
    end generate;

    g_gbt_link_mux_ge11 : if g_GEM_STATION = 1 generate
        i_gbt_link_mux_ge11 : entity work.gbt_link_mux_ge11
            generic map(
                g_NUM_OF_OHs        => g_NUM_OF_OHs,
                g_NUM_GBTS_PER_OH   => g_NUM_GBTS_PER_OH
            )
            port map(
                gbt_frame_clk_i             => ttc_clocks_i.clk_40,
                
                gbt_rx_data_arr_i           => gbt_rx_data_arr,
                gbt_tx_data_arr_o           => gbt_tx_data_arr,
                gbt_link_status_arr_i       => gbt_link_status_arr,
    
                link_test_mode_i            => loopback_gbt_test_en,
                use_v3b_mapping_i           => use_v3b_elink_mapping,
    
                sca_tx_data_arr_i           => sca_tx_data_arr,
                sca_rx_data_arr_o           => sca_rx_data_arr,
                gbt_ic_tx_data_arr_i        => gbt_ic_tx_data_arr,
                gbt_ic_rx_data_arr_o        => gbt_ic_rx_data_arr,
                promless_tx_data_i          => promless_tx_data,
                oh_fpga_tx_data_arr_i       => oh_fpga_tx_data_arr,
                oh_fpga_rx_data_arr_o       => oh_fpga_rx_data_arr,
                vfat3_tx_data_arr_i         => vfat3_tx_data_arr,
                vfat3_rx_data_arr_o         => vfat3_rx_data_arr,
                gbt_ready_arr_o             => gbt_ready_arr,
                vfat3_gbt_ready_arr_o       => vfat3_gbt_ready_arr,
                
                tst_gbt_wide_rx_data_arr_o  => test_gbt_wide_rx_data_arr,
                tst_gbt_tx_data_arr_i       => test_gbt_tx_data_arr,
                tst_gbt_ready_arr_o         => test_gbt_ready_arr
            );    
    end generate;

    g_gbt_link_mux_ge21 : if g_GEM_STATION = 2 generate
        i_gbt_link_mux_ge21 : entity work.gbt_link_mux_ge21
            generic map(
                g_NUM_OF_OHs        => g_NUM_OF_OHs,
                g_NUM_GBTS_PER_OH   => g_NUM_GBTS_PER_OH,
                g_OH_VERSION        => CFG_OH_VERSION
            )
            port map(
                gbt_frame_clk_i             => ttc_clocks_i.clk_40,
                
                gbt_rx_data_arr_i           => gbt_rx_data_arr,
                gbt_rx_data_widebus_arr_i   => gbt_rx_data_widebus_arr,
                gbt_tx_data_arr_o           => gbt_tx_data_arr,
                gbt_link_status_arr_i       => gbt_link_status_arr,
    
                link_test_mode_i            => loopback_gbt_test_en,
    
                sca_tx_data_arr_i           => sca_tx_data_arr,
                sca_rx_data_arr_o           => sca_rx_data_arr,
                gbt_ic_tx_data_arr_i        => gbt_ic_tx_data_arr,
                gbt_ic_rx_data_arr_o        => gbt_ic_rx_data_arr,
                promless_tx_data_i          => promless_tx_data,
                oh_fpga_tx_data_arr_i       => oh_fpga_tx_data_arr,
                oh_fpga_rx_data_arr_o       => oh_fpga_rx_data_arr,
                vfat3_tx_data_arr_i         => vfat3_tx_data_arr,
                vfat3_rx_data_arr_o         => vfat3_rx_data_arr,
                trig_rx_data_arr_o          => ge21_gbt_trig_data_arr,
                gbt_ready_arr_o             => gbt_ready_arr,
                vfat3_gbt_ready_arr_o       => vfat3_gbt_ready_arr,
                
                tst_gbt_wide_rx_data_arr_o  => test_gbt_wide_rx_data_arr,
                tst_gbt_tx_data_arr_i       => test_gbt_tx_data_arr,
                tst_gbt_ready_arr_o         => test_gbt_ready_arr
            );    
    end generate;

    g_gbt_link_mux_me0 : if g_GEM_STATION = 0 generate
        i_gbt_link_mux_me0 : entity work.gbt_link_mux_me0
            generic map(
                g_NUM_OF_OHs      => g_NUM_OF_OHs,
                g_NUM_GBTS_PER_OH => g_NUM_GBTS_PER_OH
            )
            port map(
                gbt_frame_clk_i       => ttc_clocks_i.clk_40,
                
                gbt_rx_data_arr_i     => lpgbt_rx_data_arr,
                gbt_tx_data_arr_o     => lpgbt_tx_data_arr,
                gbt_link_status_arr_i => gbt_link_status_arr,
                
                gbt_ic_tx_data_arr_i  => gbt_ic_tx_data_arr,
                gbt_ic_rx_data_arr_o  => gbt_ic_rx_data_arr,
                vfat3_tx_data_arr_i   => vfat3_tx_data_arr,
                vfat3_rx_data_arr_o   => vfat3_rx_data_arr,
                vfat3_sbits_arr_o     => me0_vfat3_sbits_arr,

                gbt_ready_arr_o       => gbt_ready_arr,
                vfat3_gbt_ready_arr_o => vfat3_gbt_ready_arr
            );
    end generate;
    
    --===========================--
    --    OH FPGA programming    --
    --===========================--

    g_use_oh_fpga_loader : if (g_GEM_STATION = 1) or (g_GEM_STATION = 2) generate
        i_oh_fpga_loader : entity work.promless_fpga_loader
            generic map(
                g_LOADER_CLK_80_MHZ => true
            )
            port map(
                reset_i          => reset_i,
                gbt_clk_i        => ttc_clocks_i.clk_40,
                loader_clk_i     => ttc_clocks_i.clk_80,
                to_promless_o    => to_promless_o,
                from_promless_i  => from_promless_i,
                elink_data_o     => promless_tx_data,
                hard_reset_i     => ttc_cmd.hard_reset,
                promless_stats_o => promless_stats,
                promless_cfg_i   => promless_cfg
            );
    end generate;
        
    --================================--
    -- Configuration Blaster  
    --================================--
    
    i_config_blaster : entity work.config_blaster
        generic map(
            g_NUM_OF_OHs => g_NUM_OF_OHs,
            g_DEBUG      => false
        )
        port map(
            reset_i     => reset,
            ttc_clks_i  => ttc_clocks_i,
            ttc_cmds_i  => ttc_cmd,
            ipb_reset_i => ipb_reset,
            ipb_clk_i   => ipb_clk_i,
            ipb_miso_o  => ipb_miso_arr(C_IPB_SLV.config_blaster),
            ipb_mosi_i  => ipb_mosi_arr_i(C_IPB_SLV.config_blaster)
        );
        
    --=============--
    --    Debug    --
    --=============--    
    
    i_debug_link_selector : vio_debug_link_selector
        port map(
            clk        => ttc_clocks_i.clk_40,
            probe_out0 => dbg_gbt_link_select,
            probe_out1 => dbg_vfat_link_select,
            probe_out2 => lpgbt_reset_tx,
            probe_out3 => lpgbt_reset_rx
        );

    g_gbt_debug : if CFG_DEBUG_GBT generate
        g_gbtx_ila : if (g_GEM_STATION = 1) or (g_GEM_STATION = 2) generate
            i_ila_gbt : component ila_gbt
                port map(
                    clk     => ttc_clocks_i.clk_40,
                    probe0  => dbg_gbt_tx_data,
                    probe1  => dbg_gbt_rx_data,
                    probe2  => dbg_gbt_wide_rx_data,
                    probe3  => dbg_gbt_link_status.gbt_tx_gearbox_ready,
                    probe4  => dbg_gbt_link_status.gbt_rx_ready,
                    probe5  => dbg_gbt_link_status.gbt_rx_header_locked,
                    probe6  => dbg_gbt_link_status.gbt_rx_gearbox_ready,
                    probe7  => dbg_gbt_link_status.gbt_rx_correction_flag,
                    probe8  => dbg_gbt_link_status.gbt_rx_num_bitslips(5 downto 0)
                );
        end generate;
    
        g_lpgbt_ila : if g_GEM_STATION = 0 generate
            i_ila_lpgbt : component ila_lpgbt
                port map(
                    clk     => ttc_clocks_i.clk_40,
                    probe0  => dbg_lpgbt_tx_data.tx_data,
                    probe1  => dbg_lpgbt_rx_data.rx_data,
                    probe2  => dbg_gbt_link_status.gbt_rx_ready,
                    probe3  => dbg_gbt_link_status.gbt_rx_gearbox_ready,
                    probe4  => dbg_gbt_link_status.gbt_rx_header_locked,
                    probe5  => dbg_gbt_link_status.gbt_tx_ready,
                    probe6  => dbg_gbt_link_status.gbt_tx_gearbox_ready,
                    probe7  => dbg_lpgbt_tx_data.tx_ic_data,
                    probe8  => dbg_lpgbt_tx_data.tx_ec_data,
                    probe9  => dbg_lpgbt_rx_data.rx_ic_data,
                    probe10 => dbg_lpgbt_rx_data.rx_ec_data,
                    probe11 => dbg_gbt_link_status.gbt_rx_correction_flag
                );
        end generate;
    end generate;

end gem_amc_arch;
