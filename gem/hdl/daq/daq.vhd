----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Evaldas Juska (Evaldas.Juska@cern.ch)
-- 
-- Create Date:    20:18:40 09/17/2015 
-- Design Name:    GLIB v2
-- Module Name:    DAQ
-- Project Name:   GLIB v2
-- Target Devices: xc6vlx130t-1ff1156
-- Tool versions:  ISE  P.20131013
-- Description:    This module buffers track data, builds events, analyses the data for consistency and ships off the events with all the needed headers and trailers to AMC13 over DAQLink
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

use work.common_pkg.all;
use work.gem_pkg.all;
use work.ttc_pkg.all;
use work.ipbus.all;
use work.registers.all;

use work.board_config_package.all;

entity daq is
generic(
    g_NUM_OF_OHs         : integer;
    g_DAQ_CLK_FREQ       : integer;
    g_INCLUDE_SPY_FIFO   : boolean := false;
    g_DEBUG              : boolean := false
);
port(

    -- Reset
    reset_i                     : in std_logic;

    -- Clocks
    daq_clk_i                   : in std_logic; -- for now use 25MHz, but could try 50MHz
    daq_clk_locked_i            : in std_logic;

    -- DAQLink
    daq_to_daqlink_o            : out t_daq_to_daqlink;
    daqlink_to_daq_i            : in  t_daqlink_to_daq;
        
    -- TTC
    ttc_clks_i                  : in t_ttc_clks;
    ttc_cmds_i                  : in t_ttc_cmds;
    ttc_daq_cntrs_i             : in t_ttc_daq_cntrs;
    ttc_status_i                : in t_ttc_status;

    resync_frontend_o           : out std_logic;

    -- Track data
    vfat3_daq_clk_i             : in std_logic;
    vfat3_daq_links_arr_i       : in t_oh_vfat_daq_link_arr(g_NUM_OF_OHs - 1 downto 0);
    
    -- IPbus
    ipb_reset_i                 : in  std_logic;
    ipb_clk_i                   : in std_logic;
	ipb_mosi_i                  : in ipb_wbus;
	ipb_miso_o                  : out ipb_rbus;
    
    -- Other
    board_sn_i                  : in std_logic_vector(15 downto 0) -- board serial ID, needed for the header to AMC13
    
);
end daq;

architecture Behavioral of daq is

    --================== COMPONENTS ==================--

    component ila_daq
        port(
            clk    : in std_logic;
            probe0 : in std_logic_vector(3 downto 0);
            probe1 : in std_logic_vector(3 downto 0);
            probe2 : in std_logic;
            probe3 : in std_logic;
            probe4 : in std_logic;
            probe5 : in std_logic_vector(63 downto 0);
            probe6 : in std_logic;
            probe7 : in std_logic
        );
    end component;
    
    --================== SIGNALS ==================--

    -- Reset
    signal reset_global         : std_logic := '1';
    signal reset_daq_async      : std_logic := '1';
    signal reset_daq_async_dly  : std_logic := '1';
    signal reset_daq            : std_logic := '1';
    signal reset_daqlink        : std_logic := '1'; -- should only be done once at powerup
    signal reset_pwrup          : std_logic := '1';
    signal reset_local          : std_logic := '1';
    signal reset_daqlink_ipb    : std_logic := '0';

    -- Input links
    signal vfat3_daq_links_arr  : t_oh_vfat_daq_link_arr(g_NUM_OF_OHs - 1 downto 0);

    -- DAQlink
    signal daq_event_data       : std_logic_vector(63 downto 0) := (others => '0');
    signal daq_event_write_en   : std_logic := '0';
    signal daq_event_header     : std_logic := '0';
    signal daq_event_trailer    : std_logic := '0';
    signal daq_ready            : std_logic := '0';
    signal daq_almost_full      : std_logic := '0';
    signal dbg_daqlink_ignore   : std_logic := '0';
  
    signal daq_disper_err_cnt   : std_logic_vector(15 downto 0) := (others => '0');
    signal daq_notintable_err_cnt: std_logic_vector(15 downto 0) := (others => '0');
    signal daqlink_afull_cnt    : std_logic_vector(15 downto 0) := (others => '0');

    -- DAQ Error Flags
    signal err_l1afifo_full     : std_logic := '0';
    signal err_daqfifo_full     : std_logic := '0';

    -- TTS
    signal tts_state            : std_logic_vector(3 downto 0) := "1000";
    signal tts_critical_error   : std_logic := '0'; -- critical error detected - RESYNC/RESET NEEDED
    signal tts_warning          : std_logic := '0'; -- overflow warning - STOP TRIGGERS
    signal tts_out_of_sync      : std_logic := '0'; -- out-of-sync - RESYNC NEEDED
    signal tts_busy             : std_logic := '0'; -- I'm busy - NO TRIGGERS FOR NOW, PLEASE
    signal tts_override         : std_logic_vector(3 downto 0) := x"0"; -- this can be set via IPbus and will override the TTS state if it's not x"0" (regardless of reset_daq and daq_enable)
    
    signal tts_chmb_critical    : std_logic := '0'; -- input critical error detected - RESYNC/RESET NEEDED
    signal tts_chmb_warning     : std_logic := '0'; -- input overflow warning - STOP TRIGGERS
    signal tts_chmb_out_of_sync : std_logic := '0'; -- input out-of-sync - RESYNC NEEDED

    signal tts_start_cntdwn_chmb: unsigned(7 downto 0) := x"ff";
    signal tts_start_cntdwn     : unsigned(7 downto 0) := x"ff";

    signal tts_warning_cnt      : std_logic_vector(15 downto 0);

    -- Resync
    signal resync_mode          : std_logic := '0'; -- when this signal is asserted it means that we received a resync and we're still processing the L1A fifo and holding TTS in BUSY
    signal resync_done          : std_logic := '0'; -- when this is asserted it means that L1As have been drained and we're ready to reset the DAQ and tell AMC13 that we're done
    signal resync_done_delayed  : std_logic := '0';

    -- Error signals transfered to TTS clk domain
    signal tts_chmb_critical_tts_clk    : std_logic := '0'; -- tts_chmb_critical transfered to TTS clock domain
    signal tts_chmb_warning_tts_clk     : std_logic := '0'; -- tts_chmb_warning transfered to TTS clock domain
    signal tts_chmb_out_of_sync_tts_clk : std_logic := '0'; -- tts_chmb_out_of_sync transfered to TTS clock domain
    signal err_daqfifo_full_tts_clk     : std_logic := '0'; -- err_daqfifo_full transfered to TTS clock domain
    
    -- DAQ conf
    signal daq_enable           : std_logic := '1'; -- enable sending data to DAQLink
    signal input_mask           : std_logic_vector(23 downto 0) := x"000000";
    signal run_type             : std_logic_vector(3 downto 0) := x"0"; -- run type (set by software and included in the AMC header)
    signal run_params           : std_logic_vector(23 downto 0) := x"000000"; -- optional run parameters (set by software and included in the AMC header)
    signal zero_suppression_en  : std_logic;
    
    -- DAQ counters
    signal cnt_sent_events      : unsigned(31 downto 0) := (others => '0');
    signal cnt_corrupted_vfat   : unsigned(31 downto 0) := (others => '0');

    -- DAQ event sending state machine
    signal daq_state            : unsigned(3 downto 0) := (others => '0');
    signal daq_curr_vfat_block  : unsigned(11 downto 0) := (others => '0');
    signal daq_curr_block_word  : integer range 0 to 2 := 0;
        
    -- DAQ data format selection (mostly for VFAT payload 
    signal format_calib_mode    : std_logic := '0';
    signal format_calib_chan    : std_logic_vector(6 downto 0);
        
    -- L1A FIFO
    signal l1afifo_din              : std_logic_vector(51 downto 0) := (others => '0');
    signal l1afifo_wr_en            : std_logic := '0';
    signal l1afifo_rd_en            : std_logic := '0';
    signal l1afifo_dout             : std_logic_vector(51 downto 0);
    signal l1afifo_full             : std_logic;
    signal l1afifo_overflow         : std_logic;
    signal l1afifo_empty            : std_logic;
    signal l1afifo_valid            : std_logic;
    signal l1afifo_underflow        : std_logic;
    signal l1afifo_prog_full        : std_logic;
    signal l1afifo_prog_empty       : std_logic;
    signal l1afifo_prog_empty_wrclk : std_logic;
    signal l1afifo_near_full        : std_logic;
    signal l1afifo_near_full_daqclk : std_logic;
    signal l1afifo_data_cnt         : std_logic_vector(CFG_DAQ_L1AFIFO_DATA_CNT_WIDTH - 1 downto 0);
    signal l1afifo_near_full_cnt    : std_logic_vector(15 downto 0);
    
    -- DAQ output FIFO
    signal daqfifo_din              : std_logic_vector(65 downto 0) := (others => '0');
    signal daqfifo_wr_en            : std_logic := '0';
    signal daqfifo_rd_en            : std_logic := '0';
    signal daqfifo_dout             : std_logic_vector(65 downto 0);
    signal daqfifo_full             : std_logic;
    signal daqfifo_empty            : std_logic;
    signal daqfifo_valid            : std_logic;
    signal daqfifo_prog_full        : std_logic;
    signal daqfifo_prog_empty       : std_logic;
    signal daqfifo_near_full        : std_logic;
    signal daqfifo_data_cnt         : std_logic_vector(CFG_DAQ_OUTPUT_DATA_CNT_WIDTH - 1 downto 0);
    signal daqfifo_near_full_cnt    : std_logic_vector(15 downto 0);
                            
    -- Timeouts
    signal dav_timer                : unsigned(23 downto 0) := (others => '0'); -- TODO: probably don't need this to be so large.. (need to test)
    signal max_dav_timer            : unsigned(23 downto 0) := (others => '0'); -- TODO: probably don't need this to be so large.. (need to test)
    signal last_dav_timer           : unsigned(23 downto 0) := (others => '0'); -- TODO: probably don't need this to be so large.. (need to test)
    signal dav_timeout              : std_logic_vector(23 downto 0) := x"03d090"; -- 10ms (very large)
    signal dav_timeout_flags        : std_logic_vector(23 downto 0) := (others => '0'); -- inputs which have timed out
    
    ---=== AMC Event Builder signals ===---
    
    -- index of the input currently being processed
    signal e_input_idx                : integer range 0 to 23 := 0;
    
    -- word count of the event being sent
    signal e_word_count               : unsigned(19 downto 0) := (others => '0');

    -- bitmask indicating chambers with data for the event being sent
    signal e_dav_mask                 : std_logic_vector(23 downto 0) := (others => '0');
    -- number of chambers with data for the event being sent
    signal e_dav_count                : integer range 0 to 24;
           
    ---=== Chamber Event Builder signals ===---
    
    signal input_processor_clk  : std_logic;
    signal chamber_infifos      : t_chamber_infifo_rd_array(0 to g_NUM_OF_OHs - 1);
    signal chamber_evtfifos     : t_chamber_evtfifo_rd_array(0 to g_NUM_OF_OHs - 1);
    signal chmb_evtfifos_empty  : std_logic_vector(g_NUM_OF_OHs - 1 downto 0) := (others => '1'); -- you should probably just move this flag out of the t_chamber_evtfifo_rd_array struct 
    signal chmb_evtfifos_rd_en  : std_logic_vector(g_NUM_OF_OHs - 1 downto 0) := (others => '0'); -- you should probably just move this flag out of the t_chamber_evtfifo_rd_array struct 
    signal chmb_infifos_rd_en   : std_logic_vector(g_NUM_OF_OHs - 1 downto 0) := (others => '0'); -- you should probably just move this flag out of the t_chamber_evtfifo_rd_array struct 
    signal chmb_tts_states      : t_std4_array(0 to g_NUM_OF_OHs - 1);
    signal chmb_infifo_underflow: std_logic;
    
    signal err_event_too_big    : std_logic;
    signal err_evtfifo_underflow: std_logic;

    --=== Input processor status and control ===--
    signal input_status_arr     : t_daq_input_status_arr(g_NUM_OF_OHs -1 downto 0);
    signal input_control_arr    : t_daq_input_control_arr(g_NUM_OF_OHs -1 downto 0);

    --=== Rate counters ===--
    signal daq_word_rate        : std_logic_vector(31 downto 0) := (others => '0');
    signal daq_evt_rate         : std_logic_vector(31 downto 0) := (others => '0');

    --=== Debug features ===--
    -- the fanout feature if enabled will take data from one selected input and fan it out to all inputs
    signal dbg_fanout_enable    : std_logic := '0';
    signal dbg_fanout_input     : std_logic_vector(3 downto 0) := (others => '0'); -- comes from ipbus
    signal dbg_fanout_input_real: std_logic_vector(3 downto 0) := (others => '0'); -- same as above, except it's set to 0 when dbg_fanout_input is above the number of available links

    ------ Register signals begin (this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py -- do not edit)
    ------ Register signals end ----------------------------------------------

    
    -- Debug flags for ChipScope
--    attribute MARK_DEBUG : string;
--    attribute MARK_DEBUG of reset_daq           : signal is "TRUE";
--    attribute MARK_DEBUG of daq_clk_i           : signal is "TRUE";
--
--    attribute MARK_DEBUG of dav_timer           : signal is "TRUE";
--    attribute MARK_DEBUG of max_dav_timer       : signal is "TRUE";
--    attribute MARK_DEBUG of last_dav_timer      : signal is "TRUE";
--    attribute MARK_DEBUG of dav_timeout         : signal is "TRUE";
--    attribute MARK_DEBUG of dav_timeout_flags   : signal is "TRUE";
--
--    attribute MARK_DEBUG of daq_state           : signal is "TRUE";
--    attribute MARK_DEBUG of daq_curr_vfat_block : signal is "TRUE";
--    attribute MARK_DEBUG of daq_curr_block_word : signal is "TRUE";
--
--    attribute MARK_DEBUG of daq_event_data      : signal is "TRUE";
--    attribute MARK_DEBUG of daq_event_write_en  : signal is "TRUE";
--    attribute MARK_DEBUG of daq_event_header    : signal is "TRUE";
--    attribute MARK_DEBUG of daq_event_trailer   : signal is "TRUE";
--    attribute MARK_DEBUG of daq_ready           : signal is "TRUE";
--    attribute MARK_DEBUG of daq_almost_full     : signal is "TRUE";
--    
--    attribute MARK_DEBUG of input_mask          : signal is "TRUE";
--    attribute MARK_DEBUG of e_input_idx         : signal is "TRUE";
--    attribute MARK_DEBUG of e_word_count        : signal is "TRUE";
--    attribute MARK_DEBUG of e_dav_mask          : signal is "TRUE";
--    attribute MARK_DEBUG of e_dav_count         : signal is "TRUE";
--    
--    attribute MARK_DEBUG of l1afifo_dout        : signal is "TRUE";
--    attribute MARK_DEBUG of l1afifo_rd_en       : signal is "TRUE";
--    attribute MARK_DEBUG of l1afifo_empty       : signal is "TRUE";
--    
--    attribute MARK_DEBUG of chmb_evtfifos_empty : signal is "TRUE";
--    attribute MARK_DEBUG of chmb_evtfifos_rd_en : signal is "TRUE";
--    attribute MARK_DEBUG of chmb_infifos_rd_en  : signal is "TRUE";
    
begin

    -- TODO DAQ main tasks:
    --   * Handle OOS
    --   * Implement buffer status in the AMC header
    --   * Check for VFAT and OH BX vs L1A bx mismatches
    --   * Resync handling

    --================================--
    -- DAQLink interface
    --================================--
    
    daq_to_daqlink_o.reset <= '0'; -- will need to investigate this later
    daq_to_daqlink_o.resync <= resync_done_delayed;
    daq_to_daqlink_o.trig <= x"00";
    daq_to_daqlink_o.ttc_clk <= ttc_clks_i.clk_40;
    daq_to_daqlink_o.ttc_bc0 <= ttc_cmds_i.bc0;
    daq_to_daqlink_o.tts_clk <= ttc_clks_i.clk_40;
    daq_to_daqlink_o.tts_state <= tts_state;
    daq_to_daqlink_o.event_clk <= daq_clk_i; -- TODO: check if the TTS state is transfered to the TTC clock domain correctly, if not, maybe use a different clock
    daq_to_daqlink_o.event_data <= daqfifo_dout(63 downto 0);
    daq_to_daqlink_o.event_header <= daqfifo_dout(65);
    daq_to_daqlink_o.event_trailer <= daqfifo_dout(64);
    daq_to_daqlink_o.event_valid <= daqfifo_valid;

    daq_ready <= daqlink_to_daq_i.ready or dbg_daqlink_ignore;
    daq_almost_full <= daqlink_to_daq_i.almost_full and not dbg_daqlink_ignore;
    daq_disper_err_cnt <= daqlink_to_daq_i.disperr_cnt;
    daq_notintable_err_cnt <= daqlink_to_daq_i.notintable_cnt;
    
    i_resync_frontend : entity work.oneshot
        port map(
            reset_i   => reset_pwrup or reset_global or reset_local,
            clk_i     => ttc_clks_i.clk_40,
            input_i   => resync_done_delayed,
            oneshot_o => resync_frontend_o
        );
    
    i_resync_delay : entity work.synch
        generic map(
            N_STAGES => 4
        )
        port map(
            async_i => resync_done,
            clk_i   => ttc_clks_i.clk_40,
            sync_o  => resync_done_delayed
        );
    
    --================================--
    -- Resets
    --================================--

    i_reset_sync : entity work.synch
        generic map(
            N_STAGES => 3
        )
        port map(
            async_i => reset_i,
            clk_i   => ttc_clks_i.clk_40,
            sync_o  => reset_global
        );
    
    reset_daq_async <= reset_pwrup or reset_global or reset_local or resync_done_delayed;
    reset_daqlink <= reset_pwrup or reset_global or reset_daqlink_ipb;
    
    -- Reset after powerup
    
    process(ttc_clks_i.clk_40)
        variable countdown : integer := 40_000_000; -- probably way too long, but ok for now (this is only used after powerup)
    begin
        if (rising_edge(ttc_clks_i.clk_40)) then
            if (countdown > 0) then
              reset_pwrup <= '1';
              countdown := countdown - 1;
            else
              reset_pwrup <= '0';
            end if;
        end if;
    end process;

    i_rst_delay : entity work.synch
        generic map(
            N_STAGES => 4
        )
        port map(
            async_i => reset_daq_async,
            clk_i   => ttc_clks_i.clk_40,
            sync_o  => reset_daq_async_dly
        );

    i_rst_extend : entity work.pulse_extend
        generic map(
            DELAY_CNT_LENGTH => 3
        )
        port map(
            clk_i          => ttc_clks_i.clk_40,
            rst_i          => '0',
            pulse_length_i => "111",
            pulse_i        => reset_daq_async_dly,
            pulse_o        => reset_daq -- TODO: need to also sync this to the daqclk, and use that signal on the daqclk domain  
        );

    --================================--
    -- Input links and fanout feature for rate testing
    --================================--
    
    dbg_fanout_input_real <= dbg_fanout_input when unsigned(dbg_fanout_input) < g_NUM_OF_OHs else (others => '0');
    
    g_inputs : for i in 0 to g_NUM_OF_OHs - 1 generate
        vfat3_daq_links_arr(i) <= vfat3_daq_links_arr_i(i) when dbg_fanout_enable = '0' else vfat3_daq_links_arr_i(to_integer(unsigned(dbg_fanout_input_real)));
    end generate;

    --================================--
    -- DAQ output FIFO
    --================================--
    
    i_daq_output_fifo : xpm_fifo_sync
        generic map(
            FIFO_MEMORY_TYPE    => "block",
            FIFO_WRITE_DEPTH    => CFG_DAQ_OUTPUT_DEPTH,
            WRITE_DATA_WIDTH    => 66,
            READ_MODE           => "std",
            FIFO_READ_LATENCY   => 1,
            FULL_RESET_VALUE    => 0,
            USE_ADV_FEATURES    => "1307", -- VALID(12) = 1 ; AEMPTY(11) = 0; RD_DATA_CNT(10) = 0; PROG_EMPTY(9) = 1; UNDERFLOW(8) = 1; -- WR_ACK(4) = 0; AFULL(3) = 0; WR_DATA_CNT(2) = 1; PROG_FULL(1) = 1; OVERFLOW(0) = 1
            READ_DATA_WIDTH     => 66,
            WR_DATA_COUNT_WIDTH => CFG_DAQ_OUTPUT_DATA_CNT_WIDTH,
            PROG_FULL_THRESH    => CFG_DAQ_OUTPUT_PROG_FULL_SET,
            RD_DATA_COUNT_WIDTH => CFG_DAQ_OUTPUT_DATA_CNT_WIDTH,
            PROG_EMPTY_THRESH   => CFG_DAQ_OUTPUT_PROG_FULL_RESET,
            DOUT_RESET_VALUE    => "0",
            ECC_MODE            => "no_ecc"
        )
        port map(
            sleep         => '0',
            rst           => reset_daq,
            wr_clk        => daq_clk_i,
            wr_en         => daqfifo_wr_en,
            din           => daqfifo_din,
            full          => daqfifo_full,
            prog_full     => daqfifo_prog_full,
            wr_data_count => daqfifo_data_cnt,
            overflow      => open, -- TODO: have to monitor this!
            wr_rst_busy   => open,
            almost_full   => open,
            wr_ack        => open,
            rd_en         => daqfifo_rd_en,
            dout          => daqfifo_dout,
            empty         => daqfifo_empty,
            prog_empty    => daqfifo_prog_empty,
            rd_data_count => open,
            underflow     => open, -- TODO: have to monitor this!
            rd_rst_busy   => open,
            almost_empty  => open,
            data_valid    => daqfifo_valid,
            injectsbiterr => '0',
            injectdbiterr => '0',
            sbiterr       => open,
            dbiterr       => open
        );

    i_latch_evtfifo_near_full : entity work.latch port map(
            reset_i => daqfifo_prog_empty,
            clk_i   => daq_clk_i,
            input_i => daqfifo_prog_full,
            latch_o => daqfifo_near_full
        );

    daqfifo_din <= daq_event_header & daq_event_trailer & daq_event_data;
    daqfifo_wr_en <= daq_event_write_en;
    
    -- daq fifo read logic
    process(daq_clk_i)
    begin
        if (rising_edge(daq_clk_i)) then
            if (reset_daq = '1') then
                err_daqfifo_full <= '0';
            else
                daqfifo_rd_en <= (not daq_almost_full) and (not daqfifo_empty) and daq_ready;
                if (daqfifo_full = '1') then
                    err_daqfifo_full <= '1';
                end if; 
            end if;
        end if;
    end process;

    -- Near-full counter
    i_daqfifo_near_full_counter : entity work.counter
    generic map(
        g_COUNTER_WIDTH  => 16,
        g_ALLOW_ROLLOVER => FALSE
    )
    port map(
        ref_clk_i => daq_clk_i,
        reset_i   => reset_daq,
        en_i      => daqfifo_near_full,
        count_o   => daqfifo_near_full_cnt
    );

    -- DAQLink almost-full counter
    i_daqlink_afull_counter : entity work.counter
    generic map(
        g_COUNTER_WIDTH  => 16,
        g_ALLOW_ROLLOVER => FALSE
    )
    port map(
        ref_clk_i => daq_clk_i,
        reset_i   => reset_daq,
        en_i      => daq_almost_full,
        count_o   => daqlink_afull_cnt
    );

    -- DAQ word rate
    i_daq_word_rate_counter : entity work.rate_counter
    generic map(
        g_CLK_FREQUENCY => std_logic_vector(to_unsigned(g_DAQ_CLK_FREQ, 32)),
        g_COUNTER_WIDTH => 32
    )
    port map(
        clk_i   => daq_clk_i,
        reset_i => reset_daq,
        en_i    => daqfifo_wr_en,
        rate_o  => daq_word_rate
    );

    --================================--
    -- L1A FIFO
    --================================--
    
    i_l1a_fifo : xpm_fifo_async
        generic map(
            FIFO_MEMORY_TYPE    => "block",
            FIFO_WRITE_DEPTH    => CFG_DAQ_L1AFIFO_DEPTH,
            RELATED_CLOCKS      => 0,
            WRITE_DATA_WIDTH    => 52,
            READ_MODE           => "fwft",
            FIFO_READ_LATENCY   => 0,
            FULL_RESET_VALUE    => 0,
            USE_ADV_FEATURES    => "170B", -- VALID(12) = 1 ; AEMPTY(11) = 0; RD_DATA_CNT(10) = 1; PROG_EMPTY(9) = 1; UNDERFLOW(8) = 1; -- WR_ACK(4) = 0; AFULL(3) = 1; WR_DATA_CNT(2) = 0; PROG_FULL(1) = 1; OVERFLOW(0) = 1
            READ_DATA_WIDTH     => 52,
            CDC_SYNC_STAGES     => 2,
            PROG_FULL_THRESH    => CFG_DAQ_L1AFIFO_PROG_FULL_SET,
            RD_DATA_COUNT_WIDTH => CFG_DAQ_L1AFIFO_DATA_CNT_WIDTH,
            PROG_EMPTY_THRESH   => CFG_DAQ_L1AFIFO_PROG_FULL_RESET,
            DOUT_RESET_VALUE    => "0",
            ECC_MODE            => "no_ecc"
        )
        port map(
            sleep         => '0',
            rst           => reset_daq,
            wr_clk        => ttc_clks_i.clk_40,
            wr_en         => l1afifo_wr_en,
            din           => l1afifo_din,
            full          => l1afifo_full,
            prog_full     => l1afifo_prog_full,
            wr_data_count => open,
            overflow      => l1afifo_overflow,
            wr_rst_busy   => open,
            almost_full   => open,
            wr_ack        => open,
            rd_clk        => daq_clk_i,
            rd_en         => l1afifo_rd_en,
            dout          => l1afifo_dout,
            empty         => l1afifo_empty,
            prog_empty    => l1afifo_prog_empty,
            rd_data_count => l1afifo_data_cnt,
            underflow     => l1afifo_underflow,
            rd_rst_busy   => open,
            almost_empty  => open,
            data_valid    => l1afifo_valid,
            injectsbiterr => '0',
            injectdbiterr => '0',
            sbiterr       => open,
            dbiterr       => open
        );    

    i_sync_l1afifo_prog_empty : entity work.synch generic map(N_STAGES => 3) port map(async_i => l1afifo_prog_empty, clk_i => ttc_clks_i.clk_40, sync_o => l1afifo_prog_empty_wrclk);
    i_latch_l1afifo_near_full : entity work.latch port map(
            reset_i => l1afifo_prog_empty_wrclk,
            clk_i   => ttc_clks_i.clk_40,
            input_i => l1afifo_prog_full,
            latch_o => l1afifo_near_full
        );    
    i_sync_l1afifo_near_full_daq_clk : entity work.synch generic map(N_STAGES => 3) port map(async_i => l1afifo_near_full, clk_i => daq_clk_i, sync_o => l1afifo_near_full_daqclk);
    
    -- fill the L1A FIFO
    process(ttc_clks_i.clk_40)
    begin
        if (rising_edge(ttc_clks_i.clk_40)) then
            if (reset_daq = '1') then
                err_l1afifo_full <= '0';
                l1afifo_wr_en <= '0';
            else
                if (ttc_cmds_i.l1a = '1') then
                    if (l1afifo_full = '0') then
                        l1afifo_din <= ttc_daq_cntrs_i.l1id & ttc_daq_cntrs_i.orbit & ttc_daq_cntrs_i.bx;
                        l1afifo_wr_en <= '1';
                    else
                        err_l1afifo_full <= '1';
                        l1afifo_wr_en <= '0';
                    end if;
                else
                    l1afifo_wr_en <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Near-full counter    
    i_l1afifo_near_full_counter : entity work.counter
    generic map(
        g_COUNTER_WIDTH  => 16,
        g_ALLOW_ROLLOVER => FALSE
    )
    port map(
        ref_clk_i => ttc_clks_i.clk_40,
        reset_i   => reset_daq,
        en_i      => l1afifo_near_full,
        count_o   => l1afifo_near_full_cnt
    );
    
    --================================--
    -- Chamber Event Builders
    --================================--

    -- twice faster than the vfat data clock -- this allows for easier buffering of vfat data
    input_processor_clk <= ttc_clks_i.clk_80;

    g_chamber_evt_builders : for i in 0 to (g_NUM_OF_OHs - 1) generate
    begin

        i_track_input_processor : entity work.track_input_processor
        port map
        (
            -- Reset
            reset_i                     => reset_daq,

            -- Config
            input_enable_i              => input_mask(i),

            -- FIFOs
            fifo_rd_clk_i               => daq_clk_i,
            infifo_dout_o               => chamber_infifos(i).dout,
            infifo_rd_en_i              => chamber_infifos(i).rd_en,
            infifo_empty_o              => chamber_infifos(i).empty,
            infifo_valid_o              => chamber_infifos(i).valid,
            infifo_underflow_o          => chamber_infifos(i).underflow,
            infifo_data_cnt_o           => chamber_infifos(i).data_cnt,
            evtfifo_dout_o              => chamber_evtfifos(i).dout,
            evtfifo_rd_en_i             => chamber_evtfifos(i).rd_en,
            evtfifo_empty_o             => chamber_evtfifos(i).empty,
            evtfifo_valid_o             => chamber_evtfifos(i).valid,
            evtfifo_underflow_o         => chamber_evtfifos(i).underflow,
            evtfifo_data_cnt_o          => chamber_evtfifos(i).data_cnt,

            -- VFAT data links
            data_clk_i                  => vfat3_daq_clk_i,
            data_processor_clk_i        => input_processor_clk,
            oh_daq_links_i              => vfat3_daq_links_arr(i),
            
            -- Status and control
            status_o                    => input_status_arr(i),
            control_i                   => input_control_arr(i)
        );
    
        input_control_arr(i).eb_zero_supression_en <= zero_suppression_en;
        input_control_arr(i).eb_calib_mode <= format_calib_mode;
        input_control_arr(i).eb_calib_channel <= format_calib_chan;
        chmb_evtfifos_empty(i) <= chamber_evtfifos(i).empty;
        chamber_evtfifos(i).rd_en <= chmb_evtfifos_rd_en(i);
        chamber_infifos(i).rd_en <= chmb_infifos_rd_en(i);
        chmb_tts_states(i) <= input_status_arr(i).tts_state;
        
    end generate;
        
    --================================--
    -- TTS
    --================================--

    process (input_processor_clk)
    begin
        if (rising_edge(input_processor_clk)) then
            if (reset_daq = '1') then
                tts_chmb_critical <= '0';
                tts_chmb_out_of_sync <= '0';
                tts_chmb_warning <= '0';
                tts_start_cntdwn_chmb <= x"ff";
            else
                if (tts_start_cntdwn_chmb /= x"00") then
                    for I in 0 to (g_NUM_OF_OHs - 1) loop
                        tts_chmb_critical <= tts_chmb_critical or (chmb_tts_states(I)(2) and input_mask(I));
                        tts_chmb_out_of_sync <= tts_chmb_out_of_sync or (chmb_tts_states(I)(1) and input_mask(I));
                        tts_chmb_warning <= tts_chmb_warning or (chmb_tts_states(I)(0) and input_mask(I));
                    end loop;                
                else
                    tts_start_cntdwn_chmb <= tts_start_cntdwn_chmb - 1;
                end if;
            end if;
        end if;
    end process;

    i_tts_sync_chmb_error   : entity work.synch generic map(N_STAGES => 2) port map(async_i => tts_chmb_critical,    clk_i => ttc_clks_i.clk_40, sync_o  => tts_chmb_critical_tts_clk);
    i_tts_sync_chmb_warn    : entity work.synch generic map(N_STAGES => 2) port map(async_i => tts_chmb_warning,     clk_i => ttc_clks_i.clk_40, sync_o  => tts_chmb_warning_tts_clk);
    i_tts_sync_chmb_oos     : entity work.synch generic map(N_STAGES => 2) port map(async_i => tts_chmb_out_of_sync, clk_i => ttc_clks_i.clk_40, sync_o  => tts_chmb_out_of_sync_tts_clk);
    i_tts_sync_daqfifo_full : entity work.synch generic map(N_STAGES => 2) port map(async_i => err_daqfifo_full,     clk_i => ttc_clks_i.clk_40, sync_o  => err_daqfifo_full_tts_clk);

    process (ttc_clks_i.clk_40)
    begin
        if (rising_edge(ttc_clks_i.clk_40)) then
            if (reset_daq = '1') then
                tts_critical_error <= '0';
                tts_out_of_sync <= '0';
                tts_warning <= '0';
                tts_busy <= '1';
                tts_start_cntdwn <= x"ff";
            else
                if (tts_start_cntdwn /= x"00") then
                    tts_busy <= '0';
                    tts_critical_error <= err_l1afifo_full or tts_chmb_critical_tts_clk or err_daqfifo_full_tts_clk;
                    tts_out_of_sync <= tts_chmb_out_of_sync_tts_clk;
                    tts_warning <= l1afifo_near_full or tts_chmb_warning_tts_clk;
                else
                    tts_start_cntdwn <= tts_start_cntdwn - 1;
                end if;
            end if;
        end if;
    end process;

    tts_state <= tts_override when (tts_override /= x"0") else
                 x"8" when (daq_enable = '0') else
                 x"4" when (tts_busy = '1' or resync_mode = '1') else
                 x"c" when (tts_critical_error = '1') else
                 x"2" when (tts_out_of_sync = '1') else
                 x"1" when (tts_warning = '1') else
                 x"8"; 
        
    -- warning counter
    i_tts_warning_counter : entity work.counter
    generic map(
        g_COUNTER_WIDTH  => 16,
        g_ALLOW_ROLLOVER => FALSE
    )
    port map(
        ref_clk_i => ttc_clks_i.clk_40,
        reset_i   => reset_daq,
        en_i      => tts_warning,
        count_o   => tts_warning_cnt
    );

    -- resync handling
    process(ttc_clks_i.clk_40)
    begin
        if (rising_edge(ttc_clks_i.clk_40)) then
            if (reset_daq = '1') then
                resync_mode <= '0';
                resync_done <= '0';
            else
                if (ttc_cmds_i.resync = '1') then
                    resync_mode <= '1';
                end if;
                
                -- wait for all L1As to be processed and output buffer drained and then reset everything (resync_done triggers the reset_daq)
                if (resync_mode = '1' and l1afifo_empty = '1' and daq_state = x"0" and daqfifo_empty = '1') then
                    resync_done <= '1';
                end if;
            end if;
        end if;
    end process;
     
    --================================--
    -- Event shipping to DAQLink
    --================================--
    
    process(daq_clk_i)
    
        -- event info
        variable e_l1a_id                   : std_logic_vector(23 downto 0) := (others => '0');        
        variable e_bx_id                    : std_logic_vector(11 downto 0) := (others => '0');        
        variable e_orbit_id                 : std_logic_vector(15 downto 0) := (others => '0');        

        -- event chamber info; TODO: convert these to signals (but would require additional state)
        variable e_chmb_l1a_id              : std_logic_vector(23 downto 0) := (others => '0');
        variable e_chmb_bx_id               : std_logic_vector(11 downto 0) := (others => '0');
        variable e_chmb_payload_size        : unsigned(19 downto 0) := (others => '0');
        variable e_chmb_evtfifo_afull       : std_logic := '0';
        variable e_chmb_evtfifo_full        : std_logic := '0';
        variable e_chmb_infifo_full         : std_logic := '0';
        variable e_chmb_evtfifo_near_full   : std_logic := '0';
        variable e_chmb_infifo_near_full    : std_logic := '0';
        variable e_chmb_infifo_underflow    : std_logic := '0';
        variable e_chmb_invalid_vfat_block  : std_logic := '0';
        variable e_chmb_evt_too_big         : std_logic := '0';
        variable e_chmb_evt_bigger_24       : std_logic := '0';
        variable e_chmb_mixed_oh_bc         : std_logic := '0';
        variable e_chmb_mixed_vfat_bc       : std_logic := '0';
        variable e_chmb_mixed_vfat_ec       : std_logic := '0';
              
    begin
    
        if (rising_edge(daq_clk_i)) then
        
            if (reset_daq = '1') then
                daq_state <= x"0";
                daq_event_data <= (others => '0');
                daq_event_header <= '0';
                daq_event_trailer <= '0';
                daq_event_write_en <= '0';
                chmb_evtfifos_rd_en <= (others => '0');
                l1afifo_rd_en <= '0';
                daq_curr_vfat_block <= (others => '0');
                chmb_infifos_rd_en <= (others => '0');
                daq_curr_block_word <= 0;
                cnt_sent_events <= (others => '0');
                e_word_count <= (others => '0');
                dav_timer <= (others => '0');
                max_dav_timer <= (others => '0');
                last_dav_timer <= (others => '0');
                dav_timeout_flags <= (others => '0');
                chmb_infifo_underflow <= '0';
            else
            
                chmb_evtfifos_rd_en <= (others => '0');
                chmb_infifos_rd_en <= (others => '0');
                l1afifo_rd_en <= '0';
            
                -- state machine for sending data
                -- state 0: idle
                -- state 1: send the first AMC header
                -- state 2: send the second AMC header
                -- state 3: send the GEM Event header
                -- state 4: send the GEM Chamber header
                -- state 5: send the payload
                -- state 6: send the GEM Chamber trailer
                -- state 7: send the GEM Event trailer
                -- state 8: send the AMC trailer
                if (daq_state = x"0") then
                
                    -- zero out everything, especially the write enable :)
                    daq_event_data <= (others => '0');
                    daq_event_header <= '0';
                    daq_event_trailer <= '0';
                    daq_event_write_en <= '0';
                    e_word_count <= (others => '0');
                    e_input_idx <= 0;
                    
                    
                    -- have an L1A and data from all enabled inputs is ready (or these inputs have timed out)
                    if (l1afifo_empty = '0' and ((input_mask(g_NUM_OF_OHs - 1 downto 0) and ((not chmb_evtfifos_empty) or dav_timeout_flags(g_NUM_OF_OHs - 1 downto 0))) = input_mask(g_NUM_OF_OHs - 1 downto 0))) then
                        if (daq_ready = '1' and daqfifo_near_full = '0' and daq_enable = '1') then -- everybody ready?.... GO! :)
                            -- start the DAQ state machine
                            daq_state <= x"1";
                            
                            -- set the DAV mask
                            e_dav_mask(g_NUM_OF_OHs - 1 downto 0) <= input_mask(g_NUM_OF_OHs - 1 downto 0) and ((not chmb_evtfifos_empty) and (not dav_timeout_flags(g_NUM_OF_OHs - 1 downto 0)));
                            
                            -- save timer stats
                            dav_timer <= (others => '0');
                            last_dav_timer <= dav_timer;
                            if ((dav_timer > max_dav_timer) and (or_reduce(dav_timeout_flags) = '0')) then
                                max_dav_timer <= dav_timer;
                            end if;
                        end if;
                    -- have an L1A, but waiting for data -- start counting the time
                    elsif (l1afifo_empty = '0') then
                        dav_timer <= dav_timer + 1;
                    end if;
                    
                    -- set the timeout flags if the timer has reached the dav_timeout value
                    if (dav_timer >= unsigned(dav_timeout)) then
                        dav_timeout_flags(g_NUM_OF_OHs - 1 downto 0) <= chmb_evtfifos_empty and input_mask(g_NUM_OF_OHs - 1 downto 0);
                    end if;
                
                ----==== send the first AMC header ====----
                elsif (daq_state = x"1") then
                    
                    -- wait for the valid flag from the L1A FIFO and then populate the variables and AMC header
                    if (l1afifo_valid = '1') then
                    
                        -- pop out this L1A (this is a fall-through fifo)
                        l1afifo_rd_en <= '1';
                        
                        -- fetch the L1A data
                        e_l1a_id        := l1afifo_dout(51 downto 28);
                        e_orbit_id      := l1afifo_dout(27 downto 12);
                        e_bx_id         := l1afifo_dout(11 downto 0);

                        -- send the data
                        daq_event_data <= x"00" & 
                                          e_l1a_id &   -- L1A ID
                                          e_bx_id &   -- BX ID
                                          x"fffff";
                        daq_event_header <= '1';
                        daq_event_trailer <= '0';
                        daq_event_write_en <= '1';
                        
                        -- move to the next state
                        e_word_count <= e_word_count + 1;
                        daq_state <= x"2";
                        
                    end if;
                    
                ----==== send the second AMC header ====----
                elsif (daq_state = x"2") then
                
                    -- calculate the DAV count (I know it's ugly...)
                    e_dav_count <= to_integer(unsigned(e_dav_mask(0 downto 0))) + to_integer(unsigned(e_dav_mask(1 downto 1))) + to_integer(unsigned(e_dav_mask(2 downto 2))) + to_integer(unsigned(e_dav_mask(3 downto 3))) + to_integer(unsigned(e_dav_mask(4 downto 4))) + to_integer(unsigned(e_dav_mask(5 downto 5))) + to_integer(unsigned(e_dav_mask(6 downto 6))) + to_integer(unsigned(e_dav_mask(7 downto 7))) + to_integer(unsigned(e_dav_mask(8 downto 8))) + to_integer(unsigned(e_dav_mask(9 downto 9))) + to_integer(unsigned(e_dav_mask(10 downto 10))) + to_integer(unsigned(e_dav_mask(11 downto 11))) + to_integer(unsigned(e_dav_mask(12 downto 12))) + to_integer(unsigned(e_dav_mask(13 downto 13))) + to_integer(unsigned(e_dav_mask(14 downto 14))) + to_integer(unsigned(e_dav_mask(15 downto 15))) + to_integer(unsigned(e_dav_mask(16 downto 16))) + to_integer(unsigned(e_dav_mask(17 downto 17))) + to_integer(unsigned(e_dav_mask(18 downto 18))) + to_integer(unsigned(e_dav_mask(19 downto 19))) + to_integer(unsigned(e_dav_mask(20 downto 20))) + to_integer(unsigned(e_dav_mask(21 downto 21))) + to_integer(unsigned(e_dav_mask(22 downto 22))) + to_integer(unsigned(e_dav_mask(23 downto 23)));
                    
                    -- send the data
                    daq_event_data <= C_DAQ_FORMAT_VERSION &
                                      run_type &
                                      run_params &
                                      e_orbit_id & 
                                      board_sn_i;
                    daq_event_header <= '0';
                    daq_event_trailer <= '0';
                    daq_event_write_en <= '1';
                    
                    -- move to the next state
                    e_word_count <= e_word_count + 1;
                    daq_state <= x"3";
                
                ----==== send the GEM Event header ====----
                elsif (daq_state = x"3") then
                    
                    -- if this input doesn't have data and we're not at the last input yet, then go to the next input
                    if ((e_input_idx < g_NUM_OF_OHs - 1) and (e_dav_mask(e_input_idx) = '0')) then 
                    
                        daq_event_write_en <= '0';
                        e_input_idx <= e_input_idx + 1;
                        
                    else

                        -- send the data
                        daq_event_data <= e_dav_mask & -- DAV mask
                                          -- buffer status (set if we've ever had a buffer overflow)
                                          x"000000" & -- TODO: implement buffer status flag
                                          --(err_event_too_big or e_chmb_evtfifo_full or e_chmb_infifo_underflow or e_chmb_infifo_full) &
                                          std_logic_vector(to_unsigned(e_dav_count, 5)) &   -- DAV count
                                          -- GLIB status
                                          "000" & -- Not used yet
                                          (3 downto 0 => format_calib_mode) & -- set all these bits to 1 if calibration mode is enabled
                                          tts_state;
                        daq_event_header <= '0';
                        daq_event_trailer <= '0';
                        daq_event_write_en <= '1';
                        e_word_count <= e_word_count + 1;
                        
                        -- if we have data then read the event fifo and send the chamber data
                        if (e_dav_mask(e_input_idx) = '1') then
                            -- move to the next state
                            daq_state <= x"4";
                        
                        -- no data on this input - skip to event trailer                            
                        else
                        
                            daq_state <= x"7";
                            
                        end if;
                    
                    end if;
                
                ----==== send the GEM Chamber header ====----
                elsif (daq_state = x"4") then
                                        
                    -- wait for the valid flag and then fetch the chamber event data
                    if (chamber_evtfifos(e_input_idx).valid = '1') then

                        -- pop this event out (this is a fall-through fifo, so the data is already available)
                        chmb_evtfifos_rd_en(e_input_idx) <= '1';
                    
                        e_chmb_l1a_id                       := chamber_evtfifos(e_input_idx).dout(59 downto 36);
                        e_chmb_bx_id                        := chamber_evtfifos(e_input_idx).dout(35 downto 24);
                        e_chmb_payload_size(11 downto 0)    := unsigned(chamber_evtfifos(e_input_idx).dout(23 downto 12));
                        e_chmb_evtfifo_afull                := chamber_evtfifos(e_input_idx).dout(11);
                        e_chmb_evtfifo_full                 := chamber_evtfifos(e_input_idx).dout(10);
                        e_chmb_infifo_full                  := chamber_evtfifos(e_input_idx).dout(9);
                        e_chmb_evtfifo_near_full            := chamber_evtfifos(e_input_idx).dout(8);
                        e_chmb_infifo_near_full             := chamber_evtfifos(e_input_idx).dout(7);
                        e_chmb_infifo_underflow             := chamber_evtfifos(e_input_idx).dout(6);
                        e_chmb_evt_too_big                  := chamber_evtfifos(e_input_idx).dout(5);
                        e_chmb_invalid_vfat_block           := chamber_evtfifos(e_input_idx).dout(4);
                        e_chmb_evt_bigger_24                := chamber_evtfifos(e_input_idx).dout(3);
                        e_chmb_mixed_oh_bc                  := chamber_evtfifos(e_input_idx).dout(2);
                        e_chmb_mixed_vfat_bc                := chamber_evtfifos(e_input_idx).dout(1);
                        e_chmb_mixed_vfat_ec                := chamber_evtfifos(e_input_idx).dout(0);
                        
                        -- send the data
                        daq_event_data <= x"0000" & -- Zero suppression flags
                                          "0" & format_calib_chan &
                                          std_logic_vector(to_unsigned(e_input_idx, 5)) &    -- Input ID
                                          -- OH word count
                                          std_logic_vector(e_chmb_payload_size(11 downto 0)) &
                                          -- input status
                                          e_chmb_evtfifo_full &
                                          e_chmb_infifo_full &
                                          err_l1afifo_full &
                                          e_chmb_evt_too_big &
                                          e_chmb_evtfifo_near_full &
                                          e_chmb_infifo_near_full &
                                          l1afifo_near_full_daqclk &
                                          e_chmb_evt_bigger_24 &
                                          e_chmb_invalid_vfat_block &
                                          "0" & -- OOS AMC-VFAT
                                          e_chmb_mixed_vfat_ec & -- OOS VFAT-VFAT
                                          "0" & -- AMC-VFAT BX mismatch
                                          e_chmb_mixed_vfat_bc & -- VFAT-VFAT BX mismatch
                                          x"00" & "00"; -- Not used

                        daq_event_header <= '0';
                        daq_event_trailer <= '0';
                        daq_event_write_en <= '1';
                        
                        chmb_infifo_underflow <= '0';
                        e_word_count <= e_word_count + 1;
                        
                        -- if we do have any VFAT data in this event then go on to send that, otherwise just jump to the chamber trailer
                        if (unsigned(chamber_evtfifos(e_input_idx).dout(23 downto 12)) /= x"000") then
                            daq_curr_vfat_block <= unsigned(chamber_evtfifos(e_input_idx).dout(23 downto 12)) - 3;
                            daq_curr_block_word <= 2;
                            -- note that infifo is a fall-through fifo so no need to read it here since the first vfat block is already available on the dout
                            
                            daq_state <= x"5";               
                        else
                            daq_state <= x"6";
                        end if;
                        
                    
                    else
                    
                        daq_event_write_en <= '0';
                        
                    end if; 

                ----==== send the payload ====----
                elsif (daq_state = x"5") then

                    -- keep decreasing and rolling over the word counter, as well as decrease the block counter when the word counter reaches 0
                    if (daq_curr_block_word = 0) then
                        daq_curr_block_word <= 2;
                        daq_curr_vfat_block <= daq_curr_vfat_block - 3;
                    else
                        daq_curr_block_word <= daq_curr_block_word - 1;
                        daq_curr_vfat_block <= daq_curr_vfat_block;
                    end if;
                
                    -- readout the fifo if we are 1 word away from reading the current block so that the new block is ready once we are back at word 2
                    -- note this is a fall-through fifo
                    if ((daq_curr_block_word = 1)) then
                        chmb_infifos_rd_en(e_input_idx) <= '1';
                    end if;

                    -- go to the next state if we're at the last word of the last block                    
                    if ((daq_curr_block_word = 0) and (daq_curr_vfat_block = x"000")) then
                        daq_state <= x"6";
                    else
                        daq_state <= x"5";
                    end if;

                    -- send the data!
                    daq_event_header <= '0';
                    daq_event_trailer <= '0';
                    daq_event_write_en <= '1';                        
                    e_word_count <= e_word_count + 1;

                    if (chamber_infifos(e_input_idx).valid = '1') then
                        daq_event_data <= chamber_infifos(e_input_idx).dout((((daq_curr_block_word + 1) * 64) - 1) downto (daq_curr_block_word * 64));
                        chmb_infifo_underflow <= chmb_infifo_underflow;
                    else
                        daq_event_data <= x"ffffffffffff0000"; -- a placeholder for an underflow condition (this should be easily detectable by unpacker since BC is above max, and chip id is ffff)
                        chmb_infifo_underflow <= '1';
                    end if;

                ----==== send the GEM Chamber trailer ====----
                elsif (daq_state = x"6") then
                    
                    -- increment the input index if it hasn't maxed out yet
                    if (e_input_idx < g_NUM_OF_OHs - 1) then
                        e_input_idx <= e_input_idx + 1;
                    end if;
                    
                    -- if we have data for the next input or if we've reached the last input
                    if ((e_input_idx >= g_NUM_OF_OHs - 1) or (e_dav_mask(e_input_idx + 1) = '1')) then
                    
                        -- send the data
                        daq_event_data <= x"0000" & -- OH CRC
                                          std_logic_vector(e_chmb_payload_size(11 downto 0)) & -- OH word count
                                          -- GEM chamber status
                                          err_evtfifo_underflow &
                                          "0" &  -- stuck data
                                          chmb_infifo_underflow & -- this input had an infifo underflow
                                          "0" & x"00000000";
                        daq_event_header <= '0';
                        daq_event_trailer <= '0';
                        daq_event_write_en <= '1';
                        e_word_count <= e_word_count + 1;
                            
                        -- if we have data for the next input then read the infifo and go to chamber data sending
                        if (e_dav_mask(e_input_idx + 1) = '1') then
                            daq_state <= x"4";                            
                        else -- if next input doesn't have data we can only get here if we're at the last input, so move to the event trailer
                            daq_state <= x"7";
                        end if;
                     
                    else
                    
                        daq_event_write_en <= '0';
                        
                    end if;
                    
                ----==== send the GEM Event trailer ====----
                elsif (daq_state = x"7") then

                    daq_event_data <= dav_timeout_flags & -- Chamber timeout
                                      -- Event status (hmm)
                                      x"0" & "000" &
                                      "0" & -- GLIB OOS (different L1A IDs for different inputs)
                                      x"000000" &   -- Chamber error flag (hmm)
                                      -- GLIB status
                                      daq_almost_full &
                                      ttc_status_i.clk_status.mmcm_locked & 
                                      daq_clk_locked_i & 
                                      daq_ready &
                                      ttc_status_i.bc0_status.locked &
                                      "000";         -- Reserved
                    daq_event_header <= '0';
                    daq_event_trailer <= '0';
                    daq_event_write_en <= '1';
                    e_word_count <= e_word_count + 1;
                    daq_state <= x"8";
                    
                ----==== send the AMC trailer ====----
                elsif (daq_state = x"8") then
                
                    -- send the AMC trailer data
                    daq_event_data <= x"00000000" & e_l1a_id(7 downto 0) & x"0" & std_logic_vector(e_word_count + 1);
                    daq_event_header <= '0';
                    daq_event_trailer <= '1';
                    daq_event_write_en <= '1';
                    
                    -- go back to DAQ idle state
                    daq_state <= x"0";
                    
                    -- reset things
                    e_word_count <= (others => '0');
                    e_input_idx <= 0;
                    cnt_sent_events <= cnt_sent_events + 1;
                    dav_timeout_flags <= x"000000";
                    
                -- hmm
                else
                
                    daq_state <= x"0";
                    
                end if;

            end if;
        end if;        
    end process;

    ------------------------- DEBUG -----------------------
    gen_debug:
    if g_DEBUG generate
        
        i_daq_ila : ila_daq
            port map(
                clk    => daq_clk_i,
                probe0 => std_logic_vector(daq_state),
                probe1 => tts_state,
                probe2 => daq_ready,
                probe3 => daq_almost_full,
                probe4 => daqfifo_valid,
                probe5 => daqfifo_dout(63 downto 0),
                probe6 => daqfifo_dout(65),
                probe7 => daqfifo_dout(64)
            );
        
    end generate;
    -------------------------------------------------------

    --===============================================================================================
    -- this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py (do not edit) 
    --==== Registers begin ==========================================================================

    --==== Registers end ============================================================================

    
end Behavioral;

