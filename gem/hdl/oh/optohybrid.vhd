------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    10:43 2016-08-04
-- Module Name:    OPTOHYBRID
-- Description:    This module handles all communications with the optohybrid and VFATs
------------------------------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

--use work.gth_pkg.all;
use work.ttc_pkg.all;
use work.gem_pkg.all;
use work.ipbus.all;

entity optohybrid is
    generic(
        g_GEM_STATION   : integer;
        g_OH_IDX        : std_logic_vector(3 downto 0);
        g_DEBUG         : boolean := false -- if this is set to true, some chipscope cores will be inserted
    );
    port(
        -- reset
        reset_i                 : in  std_logic;

        -- TTC
        ttc_clk_i               : in  t_ttc_clks;
        ttc_cmds_i              : in  t_ttc_cmds;
        
        -- VFAT3 common TX data stream
        vfat3_tx_datastream_i   : in std_logic_vector(7 downto 0);
        vfat3_tx_idle_i         : in std_logic;
        vfat3_sync_i            : in std_logic;
        vfat3_sync_verify_i     : in std_logic;
        
        -- FPGA control link
        fpga_tx_data_o          : out std_logic_vector(7 downto 0);
        fpga_rx_data_i          : in  std_logic_vector(7 downto 0);

        -- VFAT3 links
        vfat3_tx_data_o         : out t_std8_array(23 downto 0);
        vfat3_rx_data_i         : in  t_std8_array(23 downto 0);
        vfat3_link_status_o     : out t_vfat_link_status_arr(23 downto 0);
        vfat_mask_arr_i         : in  std_logic_vector(23 downto 0);
        vfat_gbt_ready_arr_i    : in  std_logic_vector(23 downto 0);
        
        -- VFAT3 slow control
        vfat3_sc_tx_data_i      : in std_logic;
        vfat3_sc_tx_empty_i     : in std_logic;
        vfat3_sc_tx_oh_idx_i    : in std_logic_vector(3 downto 0);
        vfat3_sc_tx_vfat_idx_i  : in std_logic_vector(4 downto 0);
        vfat3_sc_tx_rd_en_o     : out std_logic;
        
        vfat3_sc_rx_data_o      : out std_logic_vector(23 downto 0);
        vfat3_sc_rx_data_en_o   : out std_logic_vector(23 downto 0);
        
        -- VFAT3 DAQ output
        vfat3_daq_links_o       : out t_vfat_daq_link_arr(23 downto 0);
        
        -- Trigger links
        gth_rx_trig_usrclk_i    : in std_logic_vector(1 downto 0);
        gth_rx_trig_data_i      : in t_mgt_16b_rx_data_arr(1 downto 0);
        sbit_clusters_o         : out t_oh_sbits;
        sbit_links_status_o     : out t_oh_sbit_links;
        
        -- OH reg forwarding IPbus
        oh_reg_ipb_reset_i      : in  std_logic;
        oh_reg_ipb_clk_i        : in  std_logic;
        oh_reg_ipb_miso_o       : out ipb_rbus;
        oh_reg_ipb_mosi_i       : in  ipb_wbus;

        -- debug
        debug_vfat_select_i     : in std_logic_vector(4 downto 0)
        
    );
end optohybrid;

architecture optohybrid_arch of optohybrid is
    
    component ila_vfat3
        port(
            clk     : in std_logic;
            probe0  : in std_logic_vector(7 DOWNTO 0);
            probe1  : in std_logic;
            probe2  : in std_logic;
            probe3  : in std_logic;
            probe4  : in std_logic;
            probe5  : in std_logic_vector(7 DOWNTO 0);
            probe6  : in std_logic_vector(7 DOWNTO 0);
            probe7  : in std_logic;
            probe8  : in std_logic_vector(2 DOWNTO 0);
            probe9  : in std_logic_vector(3 DOWNTO 0);
            probe10 : in std_logic_vector(7 DOWNTO 0);
            probe11 : in std_logic;
            probe12 : in std_logic;
            probe13 : in std_logic;
            probe14 : in std_logic_vector(7 DOWNTO 0);
            probe15 : in std_logic_vector(7 DOWNTO 0)
        );
    end component;
    
    component sync_fifo_8b10b_16
        port(
            rst       : IN  std_logic;
            wr_clk    : IN  std_logic;
            rd_clk    : IN  std_logic;
            din       : IN  std_logic_vector(23 DOWNTO 0);
            wr_en     : IN  std_logic;
            rd_en     : IN  std_logic;
            dout      : OUT std_logic_vector(23 DOWNTO 0);
            full      : OUT std_logic;
            overflow  : OUT std_logic;
            empty     : OUT std_logic;
            valid     : OUT std_logic;
            underflow : OUT std_logic
        );
    end component;
        
    --== VFAT3 signals ==--
    signal vfat3_rx_ready           : std_logic_vector(23 downto 0);
    signal vfat3_sync_ok            : std_logic_vector(23 downto 0);
    signal vfat3_rx_num_bitslips    : t_std3_array(23 downto 0);
    signal vfat3_rx_sync_err_cnt    : t_std4_array(23 downto 0);
    
    signal vfat3_tx_data            : t_std8_array(23 downto 0);
    signal vfat3_rx_aligned_data    : t_std8_array(23 downto 0);
    
    signal vfat3_sc_tx_en           : std_logic_vector(23 downto 0);
    signal vfat3_sc_tx_rd_en        : std_logic_vector(23 downto 0);
    
    signal vfat3_daq_data           : t_std8_array(23 downto 0);
    signal vfat3_daq_data_en        : std_logic_vector(23 downto 0);
    signal vfat3_daq_crc_err        : std_logic_vector(23 downto 0);
    signal vfat3_daq_event_done     : std_logic_vector(23 downto 0);
    
    signal vfat3_daq_cnt_crc_err_arr: t_std8_array(23 downto 0);
    signal vfat3_daq_cnt_evt_arr    : t_std8_array(23 downto 0);
    
    --== FPGA register access requests ==--

    signal fpga_rx_data             : std_logic_vector(7 downto 0);
    
    --== Trigger RX sync FIFOs ==--

    signal sync_trig_rx_din_arr     : t_std24_array(1 downto 0);
    signal sync_trig_rx_dout_arr    : t_std24_array(1 downto 0);
    signal sync_trig_rx_gth_data_arr: t_mgt_16b_rx_data_arr(1 downto 0);
    signal sync_trig_rx_ovf_arr     : std_logic_vector(1 downto 0);
    signal sync_trig_rx_unf_arr     : std_logic_vector(1 downto 0);

    --== Debug ==--

    signal dbg_vfat3_tx_data            : std_logic_vector(7 downto 0);
    signal dbg_vfat3_rx_data            : std_logic_vector(7 downto 0);
    signal dbg_vfat3_rx_aligned_data    : std_logic_vector(7 downto 0);
    signal dbg_vfat3_sync_ok            : std_logic;
    signal dbg_vfat3_rx_num_bitslips    : std_logic_vector(2 downto 0);
    signal dbg_vfat3_rx_sync_err_cnt    : std_logic_vector(3 downto 0);
    signal dbg_vfat3_daq_data           : std_logic_vector(7 downto 0);
    signal dbg_vfat3_daq_data_en        : std_logic;
    signal dbg_vfat3_daq_crc_err        : std_logic;
    signal dbg_vfat3_daq_event_done     : std_logic;
    signal dbg_vfat3_cnt_events         : std_logic_vector(7 downto 0);
    signal dbg_vfat3_cnt_crc_errors     : std_logic_vector(7 downto 0);    
    
begin

    --==========================--
    --==        Wiring        ==--
    --==========================--
    vfat3_tx_data_o <= vfat3_tx_data;
    fpga_rx_data <= fpga_rx_data_i;

    --==========================--
    --==       VFAT3 TX       ==--
    --==========================--

    g_vfat3_tx_links : for i in 0 to 23 generate
    
        i_vfat3_tx_link : entity work.vfat3_tx_link
            port map(
                reset_i           => reset_i,
                ttc_clk_i         => ttc_clk_i,
                datastream_i      => vfat3_tx_datastream_i,
                datastream_idle_i => vfat3_tx_idle_i,
                num_bitslips_i    => "000",
                rx_ready_i        => vfat3_rx_ready(i),
                sc_data_i         => vfat3_sc_tx_data_i,
                sc_valid_i        => not vfat3_sc_tx_empty_i,
                sc_en_i           => vfat3_sc_tx_en(i),
                sc_rd_en_o        => vfat3_sc_tx_rd_en(i),
                elink_data_o      => vfat3_tx_data(i)
            );
            
            vfat3_sc_tx_en(i) <= '1' when vfat3_sc_tx_oh_idx_i = g_OH_IDX and vfat3_sc_tx_vfat_idx_i = std_logic_vector(to_unsigned(i, 5)) else '0';
            
    end generate;
    
    vfat3_sc_tx_rd_en_o <= or_reduce(vfat3_sc_tx_rd_en);
    
    --==========================--
    --==       VFAT3 RX       ==--
    --==========================--
    
    g_vfat3_rx_links : for i in 0 to 23 generate
    
        i_vfat3_rx_aligner : entity work.vfat3_rx_aligner
            port map(
                reset_i               => reset_i,
                ttc_clk_i             => ttc_clk_i,
                data_i                => vfat3_rx_data_i(i),
                sync_i                => vfat3_sync_i,
                sync_verify_i         => vfat3_sync_verify_i,
                sync_ok_o             => vfat3_sync_ok(i),
                num_bitslips_o        => vfat3_rx_num_bitslips(i),
                sync_verify_err_cnt_o => vfat3_rx_sync_err_cnt(i),
                data_o                => vfat3_rx_aligned_data(i)
            );
    
        i_vfat3_rx_link : entity work.vfat3_rx_link
            port map(
                reset_i             => reset_i,
                ttc_clk_i           => ttc_clk_i,

                mask_i              => vfat_mask_arr_i(i) or not vfat_gbt_ready_arr_i(i),

                data_i              => vfat3_rx_aligned_data(i),
                sync_ok_i           => vfat3_sync_ok(i),

                ready_o             => vfat3_rx_ready(i),

                daq_data_o          => vfat3_daq_data(i),
                daq_data_en_o       => vfat3_daq_data_en(i),
                daq_crc_error_o     => vfat3_daq_crc_err(i),
                daq_event_done_o    => vfat3_daq_event_done(i),

                slow_ctrl_data_o    => vfat3_sc_rx_data_o(i),
                slow_ctrl_data_en_o => vfat3_sc_rx_data_en_o(i),

                cnt_events_o        => vfat3_daq_cnt_evt_arr(i),
                cnt_crc_errors_o    => vfat3_daq_cnt_crc_err_arr(i)
            );
    
        vfat3_link_status_o(i).sync_good        <= vfat3_rx_ready(i);
        vfat3_link_status_o(i).sync_error_cnt   <= vfat3_rx_sync_err_cnt(i);
        vfat3_link_status_o(i).daq_event_cnt    <= vfat3_daq_cnt_evt_arr(i);
        vfat3_link_status_o(i).daq_crc_err_cnt  <= vfat3_daq_cnt_crc_err_arr(i);
            
        vfat3_daq_links_o(i).data_en    <= vfat3_daq_data_en(i);
        vfat3_daq_links_o(i).data       <= vfat3_daq_data(i);
        vfat3_daq_links_o(i).event_done <= vfat3_daq_event_done(i);
        vfat3_daq_links_o(i).crc_error  <= vfat3_daq_crc_err(i);

    end generate;
    
    --=================================--
    --==       OH Slow Control       ==--
    --=================================--
    
    g_use_fpga_links : if (g_GEM_STATION = 1) or (g_GEM_STATION = 2) generate
        i_oh_slow_control : entity work.link_oh_fpga
            port map(
                reset_i    => reset_i or oh_reg_ipb_reset_i,
                ttc_clk_i  => ttc_clk_i,
                ipb_clk_i  => oh_reg_ipb_clk_i,
                ttc_cmds_i => ttc_cmds_i,
                ipb_mosi_i => oh_reg_ipb_mosi_i,
                ipb_miso_o => oh_reg_ipb_miso_o,
                rx_elink_i => fpga_rx_data,
                tx_elink_o => fpga_tx_data_o
            );
    end generate;
    
    g_no_fpga_links : if g_GEM_STATION = 0 generate
        oh_reg_ipb_miso_o <= (ipb_rdata => (others => '0'), ipb_ack => '0', ipb_err => '0');
    end generate;
     
    --=========================--
    --==   RX Trigger Link   ==--
    --=========================--

    g_use_trig_links : if (g_GEM_STATION = 1) or (g_GEM_STATION = 2) generate
    
        gen_trig_links: for i in 0 to 1 generate
    
            -- Sync FIFO
            i_sync_rx_trig : component sync_fifo_8b10b_16
                port map(
                    rst       => reset_i,
                    wr_clk    => gth_rx_trig_usrclk_i(i),
                    rd_clk    => ttc_clk_i.clk_160,
                    din       => sync_trig_rx_din_arr(i),
                    wr_en     => '1',
                    rd_en     => '1',
                    dout      => sync_trig_rx_dout_arr(i),
                    full      => open,
                    overflow  => sync_trig_rx_ovf_arr(i),
                    empty     => open,
                    valid     => open,
                    underflow => sync_trig_rx_unf_arr(i)
                );
                
            sync_trig_rx_din_arr(i) <= gth_rx_trig_data_i(i).rxdisperr(1 downto 0) & 
                                       gth_rx_trig_data_i(i).rxnotintable(1 downto 0) & 
                                       gth_rx_trig_data_i(i).rxchariscomma(1 downto 0) & 
                                       gth_rx_trig_data_i(i).rxcharisk(1 downto 0) & 
                                       gth_rx_trig_data_i(i).rxdata(15 downto 0);
                                       
            sync_trig_rx_gth_data_arr(i).rxdata(15 downto 0) <= sync_trig_rx_dout_arr(i)(15 downto 0);
            sync_trig_rx_gth_data_arr(i).rxcharisk(1 downto 0) <= sync_trig_rx_dout_arr(i)(17 downto 16);
            sync_trig_rx_gth_data_arr(i).rxchariscomma(1 downto 0) <= sync_trig_rx_dout_arr(i)(19 downto 18);
            sync_trig_rx_gth_data_arr(i).rxnotintable(1 downto 0) <= sync_trig_rx_dout_arr(i)(21 downto 20);
            sync_trig_rx_gth_data_arr(i).rxdisperr(1 downto 0) <= sync_trig_rx_dout_arr(i)(23 downto 22);
            
            -- TODO: report rxnotintable and also the overflow/underflow of this fifo
            
            i_link_rx_trigger : entity work.link_rx_trigger
                generic map (
                    g_DEBUG => false
                )
                port map(
                    ttc_clk_i           => ttc_clk_i.clk_40,
                    reset_i             => reset_i,
                    gt_rx_trig_usrclk_i => ttc_clk_i.clk_160,
                    rx_kchar_i          => sync_trig_rx_gth_data_arr(i).rxcharisk(1 downto 0),
                    rx_data_i           => sync_trig_rx_gth_data_arr(i).rxdata(15 downto 0),
                    sbit_cluster0_o     => sbit_clusters_o(i * 4 + 0),
                    sbit_cluster1_o     => sbit_clusters_o(i * 4 + 1),
                    sbit_cluster2_o     => sbit_clusters_o(i * 4 + 2),
                    sbit_cluster3_o     => sbit_clusters_o(i * 4 + 3),
                    link_status_o       => sbit_links_status_o(i)
                );        
        
        end generate;
    end generate;
        
    g_no_trig_links : if g_GEM_STATION = 0 generate
        sbit_links_status_o <= (others => (sbit_overflow => '0', missed_comma => '1', underflow => '1', overflow => '0', sync_word => '0'));
        sbit_clusters_o <= (others => (address => "111" & x"FA", size => "000"));
    end generate;
            
    --============================--
    --==        Debug           ==--
    --============================--
    
    gen_debug:
    if g_DEBUG generate

        dbg_vfat3_tx_data           <= vfat3_tx_data(to_integer(unsigned(debug_vfat_select_i)));
        dbg_vfat3_rx_data           <= vfat3_rx_data_i(to_integer(unsigned(debug_vfat_select_i)));
        dbg_vfat3_rx_aligned_data   <= vfat3_rx_aligned_data(to_integer(unsigned(debug_vfat_select_i)));
        dbg_vfat3_sync_ok           <= vfat3_sync_ok(to_integer(unsigned(debug_vfat_select_i)));
        dbg_vfat3_rx_num_bitslips   <= vfat3_rx_num_bitslips(to_integer(unsigned(debug_vfat_select_i)));
        dbg_vfat3_rx_sync_err_cnt   <= vfat3_rx_sync_err_cnt(to_integer(unsigned(debug_vfat_select_i)));
        dbg_vfat3_daq_data          <= vfat3_daq_data(to_integer(unsigned(debug_vfat_select_i)));
        dbg_vfat3_daq_data_en       <= vfat3_daq_data_en(to_integer(unsigned(debug_vfat_select_i)));
        dbg_vfat3_daq_crc_err       <= vfat3_daq_crc_err(to_integer(unsigned(debug_vfat_select_i)));
        dbg_vfat3_daq_event_done    <= vfat3_daq_event_done(to_integer(unsigned(debug_vfat_select_i)));
        dbg_vfat3_cnt_events        <= vfat3_daq_cnt_evt_arr(to_integer(unsigned(debug_vfat_select_i)));
        dbg_vfat3_cnt_crc_errors    <= vfat3_daq_cnt_crc_err_arr(to_integer(unsigned(debug_vfat_select_i)));
        
        i_vfat_ila : ila_vfat3
            port map(
                clk    => ttc_clk_i.clk_40,
                probe0 => dbg_vfat3_tx_data,
                probe1 => vfat3_tx_idle_i,
                probe2 => reset_i,
                probe3 => vfat3_sync_i,
                probe4 => vfat3_sync_verify_i,
                probe5 => dbg_vfat3_rx_data,
                probe6 => dbg_vfat3_rx_aligned_data,
                probe7 => dbg_vfat3_sync_ok,
                probe8 => dbg_vfat3_rx_num_bitslips,
                probe9 => dbg_vfat3_rx_sync_err_cnt,
                probe10 => dbg_vfat3_daq_data,
                probe11 => dbg_vfat3_daq_data_en,
                probe12 => dbg_vfat3_daq_crc_err,
                probe13 => dbg_vfat3_daq_event_done,
                probe14 => dbg_vfat3_cnt_events,
                probe15 => dbg_vfat3_cnt_crc_errors
            );

        i_ila_trig0_link : entity work.gt_rx_link_ila_wrapper
            port map(
                clk_i          => gth_rx_trig_usrclk_i(0),
                kchar_i        => gth_rx_trig_data_i(0).rxcharisk(1 downto 0),
                comma_i        => gth_rx_trig_data_i(0).rxchariscomma(1 downto 0),
                not_in_table_i => gth_rx_trig_data_i(0).rxnotintable(1 downto 0),
                disperr_i      => gth_rx_trig_data_i(0).rxdisperr(1 downto 0),
                data_i         => gth_rx_trig_data_i(0).rxdata(15 downto 0)
            );

    end generate;     
     
end optohybrid_arch;
