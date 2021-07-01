------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    20:18 2015-09-17
-- Module Name:    DAQ
-- Description:    This module buffers input data, builds events, analyses the data for consistency and ships off the events with all the needed headers and trailers to AMC13 over DAQLink  
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

use work.common_pkg.all;
use work.csc_pkg.all;
use work.ttc_pkg.all;
use work.ipbus.all;
use work.registers.all;

use work.board_config_package.all;

entity daq is
generic(
    g_NUM_OF_DMBs        : integer;
    g_DAQ_CLK_FREQ       : integer;
    g_IPB_CLK_PERIOD_NS  : integer
);
port(

    -- Reset
    reset_i                     : in  std_logic;

    -- DAQ clock
    daq_clk_i                   : in  std_logic;
    daq_clk_locked_i            : in  std_logic;

    -- DAQLink
    daq_to_daqlink_o            : out t_daq_to_daqlink;
    daqlink_to_daq_i            : in  t_daqlink_to_daq;
        
    -- TTC
    ttc_clks_i                  : in  t_ttc_clks;
    ttc_cmds_i                  : in  t_ttc_cmds;
    ttc_daq_cntrs_i             : in  t_ttc_daq_cntrs;
    ttc_status_i                : in  t_ttc_status;
    l1a_request_o               : out std_logic;

    -- Data
    input_clk_arr_i             : in std_logic_vector(g_NUM_OF_DMBs - 1 downto 0);
    input_link_arr_i            : in t_mgt_16b_rx_data_arr(g_NUM_OF_DMBs - 1 downto 0);
    
    -- Spy
    spy_clk_i                   : in  std_logic;
    spy_link_o                  : out t_mgt_16b_tx_data;
    
    -- IPbus
    ipb_reset_i                 : in  std_logic;
    ipb_clk_i                   : in  std_logic;
	ipb_mosi_i                  : in  ipb_wbus;
	ipb_miso_o                  : out ipb_rbus;
    
    -- Other
    board_id_i                  : in  std_logic_vector(15 downto 0); -- board ID
    tts_ready_o                 : out std_logic
    
);
end daq;

architecture Behavioral of daq is

    --================== SIGNALS ==================--

    -- Reset
    signal reset_global         : std_logic := '1';
    signal reset_daq_async      : std_logic := '1';
    signal reset_daq_async_dly  : std_logic := '1';
    signal reset_daq            : std_logic := '1';
    signal reset_daqlink        : std_logic := '1'; -- should only be done once at powerup
    signal reset_pwrup          : std_logic := '1';
    signal reset_local          : std_logic := '1';
    signal reset_local_latched  : std_logic := '0';
    signal reset_daqlink_ipb    : std_logic := '0';

    -- DAQlink
    signal daq_event_data       : std_logic_vector(63 downto 0) := (others => '0');
    signal daq_event_write_en   : std_logic := '0';
    signal daq_event_header     : std_logic := '0';
    signal daq_event_trailer    : std_logic := '0';
    signal daq_ready            : std_logic := '0';
    signal daq_almost_full      : std_logic := '0';

    signal daq_disper_err_cnt   : std_logic_vector(15 downto 0) := (others => '0');
    signal daq_notintable_err_cnt: std_logic_vector(15 downto 0) := (others => '0');
    signal daqlink_afull_cnt    : std_logic_vector(15 downto 0) := (others => '0');

    -- Main DAQ FSM signals
    signal daq_not_empty_event  : std_logic := '0';
    signal ddu_crc              : std_logic_vector(15 downto 0) := (others => '0');
    signal dmb_64bit_misaligned : std_logic := '0';
  
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
    
    signal tts_chmb_critical_arr: std_logic_vector(CFG_DAQ_MAX_DMBS - 1 downto 0) := (others => '0'); -- input critical error detected - RESYNC/RESET NEEDED
    signal tts_chmb_warning_arr : std_logic_vector(CFG_DAQ_MAX_DMBS - 1 downto 0) := (others => '0'); -- input overflow warning - STOP TRIGGERS
    signal tts_chmb_oos_arr     : std_logic_vector(CFG_DAQ_MAX_DMBS - 1 downto 0) := (others => '0'); -- input out-of-sync - RESYNC NEEDED
    signal tts_chmb_critical    : std_logic := '0'; -- input critical error detected - RESYNC/RESET NEEDED
    signal tts_chmb_warning     : std_logic := '0'; -- input overflow warning - STOP TRIGGERS
    signal tts_chmb_oos         : std_logic := '0'; -- input out-of-sync - RESYNC NEEDED

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
    signal ignore_amc13         : std_logic := '0'; -- when this is set to true, DAQLink status is ignored (useful for local spy-only data taking) 
    signal block_last_evt_fifo  : std_logic := '0'; -- if true, then events are not written to the last event fifo (could be useful to toggle this from software in order to know how many events are read exactly because sometimes you may miss empty=true)
    signal freeze_on_error      : std_logic := '0'; -- this is a debug feature which when turned on will start sending only IDLE words to all input processors as soon as TTS error is detected
    signal reset_till_resync    : std_logic := '0'; -- if this is true, then after the user removes the reset, this module will still stay in reset till the resync is received. This is handy for starting to take data in the middle of an active run.
    
    -- DAQ counters
    signal cnt_sent_events      : unsigned(31 downto 0) := (others => '0');

    -- DAQ event sending state machine
    type t_daq_state is (IDLE, AMC13_HEADER_1, AMC13_HEADER_2, FED_HEADER_1, FED_HEADER_2, FED_HEADER_3, PAYLOAD, FED_TRAILER_1, FED_TRAILER_2, FED_TRAILER_3, AMC13_TRAILER);
    signal daq_state            : t_daq_state := IDLE;
    signal daq_curr_infifo_word : unsigned(11 downto 0) := (others => '0');
        
    -- L1A FIFO
    signal l1afifo_din              : std_logic_vector(52 downto 0) := (others => '0');
    signal l1afifo_wr_en            : std_logic := '0';
    signal l1afifo_rd_en            : std_logic := '0';
    signal l1afifo_dout             : std_logic_vector(52 downto 0);
    signal l1afifo_full             : std_logic;
    signal l1afifo_overflow         : std_logic;
    signal l1afifo_empty            : std_logic;
    signal l1afifo_valid            : std_logic;
    signal l1afifo_underflow        : std_logic;
    signal l1afifo_prog_full        : std_logic;
    signal l1afifo_prog_empty       : std_logic;
    signal l1afifo_prog_empty_wrclk : std_logic;
    signal l1afifo_near_full        : std_logic;
    signal l1afifo_data_cnt         : std_logic_vector(12 downto 0);
    signal l1afifo_near_full_cnt    : std_logic_vector(15 downto 0);
    signal l1a_gap_cntdown          : unsigned(7 downto 0) := (others => '0'); -- this is used to detect close L1As (meaning less than 1000ns apart)
    
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
    signal daqfifo_data_cnt         : std_logic_vector(12 downto 0);
    signal daqfifo_near_full_cnt    : std_logic_vector(15 downto 0);
            
    -- Last event spy fifo
    signal last_evt_fifo_en         : std_logic := '0';
    signal last_evt_fifo_rd_en      : std_logic := '0';
    signal last_evt_fifo_dout       : std_logic_vector(31 downto 0);
    signal last_evt_fifo_empty      : std_logic := '0';
    signal last_evt_fifo_valid      : std_logic := '0';
    
    -- Spy path
    signal spy_fifo_wr_en           : std_logic;
    signal spy_fifo_rd_en           : std_logic;
    signal spy_fifo_dout            : std_logic_vector(15 downto 0);
    signal spy_fifo_ovf             : std_logic;
    signal spy_fifo_empty           : std_logic;
    signal spy_fifo_prog_full       : std_logic;
    signal spy_fifo_prog_empty      : std_logic;
    signal spy_fifo_prog_empty_wrclk: std_logic;
    signal spy_fifo_aempty          : std_logic;
    signal spy_fifo_afull           : std_logic;
    signal err_spy_fifo_ovf         : std_logic;
    signal spy_fifo_afull_cnt       : std_logic_vector(15 downto 0);
    
    signal spy_gbe_skip_headers     : std_logic;
    signal spy_prescale             : std_logic_vector(15 downto 0);
    signal spy_skip_empty_evts      : std_logic;
    
    signal spy_err_evt_too_big      : std_logic;
    signal spy_err_eoe_not_found    : std_logic;
    signal spy_word_rate            : std_logic_vector(31 downto 0);
    signal spy_evt_sent             : std_logic_vector(31 downto 0);
    signal spy_prescale_counter     : unsigned(15 downto 0) := x"0001";    
    signal spy_prescale_keep_evt    : std_logic := '0';
                
    -- Timeouts
    signal dav_timer                : unsigned(23 downto 0) := (others => '0'); -- TODO: probably don't need this to be so large.. (need to test)
    signal max_dav_timer            : unsigned(23 downto 0) := (others => '0'); -- TODO: probably don't need this to be so large.. (need to test)
    signal last_dav_timer           : unsigned(23 downto 0) := (others => '0'); -- TODO: probably don't need this to be so large.. (need to test)
    signal dav_timeout              : std_logic_vector(23 downto 0) := x"03d090"; -- 10ms (very large)
    signal dav_timeout_flags        : std_logic_vector(23 downto 0) := (others => '0'); -- inputs which have timed out
    
    -- L1A request
    signal l1a_req_en               : std_logic;
    signal l1a_req_evt_num          : unsigned(23 downto 0) := (others => '0');
    
    ---=== AMC Event Builder signals ===---
    
    -- index of the input currently being processed
    signal e_input_idx                : integer range 0 to 23 := 0;
    -- flag saying if this is the first cycle of payload sending of the current input
    signal e_payload_first_cycle      : std_logic := '1';
    
    -- word count of the event being sent
    signal e_word_count               : unsigned(19 downto 0) := (others => '0');

    -- bitmask indicating chambers with data for the event being sent
    signal e_dav_mask                 : std_logic_vector(23 downto 0) := (others => '0');
    -- number of chambers with data for the event being sent
    signal e_dav_count                : integer range 0 to 24;
           
    ---=== Chamber Event Builder signals ===---
    
    signal chamber_infifos      : t_chamber_infifo_rd_array(0 to g_NUM_OF_DMBs - 1);
    signal chamber_evtfifos     : t_chamber_evtfifo_rd_array(0 to g_NUM_OF_DMBs - 1);
    signal chmb_evtfifos_empty  : std_logic_vector(g_NUM_OF_DMBs - 1 downto 0) := (others => '1'); -- you should probably just move this flag out of the t_chamber_evtfifo_rd_array struct 
    signal chmb_evtfifos_rd_en  : std_logic_vector(g_NUM_OF_DMBs - 1 downto 0) := (others => '0'); -- you should probably just move this flag out of the t_chamber_evtfifo_rd_array struct 
    signal chmb_infifos_rd_en   : std_logic_vector(g_NUM_OF_DMBs - 1 downto 0) := (others => '0'); -- you should probably just move this flag out of the t_chamber_evtfifo_rd_array struct 
    signal chmb_tts_states      : t_std4_array(0 to g_NUM_OF_DMBs - 1);
    
    signal err_event_too_big    : std_logic;
    signal err_evtfifo_underflow: std_logic;

    --=== Input processor status and control ===--
    signal input_status_arr     : t_daq_input_status_arr(g_NUM_OF_DMBs -1 downto 0);
    signal input_control_arr    : t_daq_input_control_arr(g_NUM_OF_DMBs -1 downto 0);

    --=== Rate counters ===--
    signal daq_word_rate        : std_logic_vector(31 downto 0) := (others => '0');
    signal daq_evt_rate         : std_logic_vector(31 downto 0) := (others => '0');

    ------ Register signals begin (this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py -- do not edit)
    ------ Register signals end ----------------------------------------------

begin

    -- TODO DAQ main tasks:
    --   * Handle OOS
    --   * Implement buffer status in the AMC header
    --   * TTS State aggregation
    --   * Check for VFAT and OH BX vs L1A bx mismatches
    --   * Resync handling
    --   * Stop building events if input fifo is full -- let it drain to some level and only then restart building (otherwise you're pointing to inexisting data). I guess it's better to loose some data than to have something that doesn't make any sense..

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
    daq_to_daqlink_o.event_clk <= daq_clk_i;
    daq_to_daqlink_o.event_data <= daqfifo_dout(63 downto 0);
    daq_to_daqlink_o.event_header <= daqfifo_dout(65);
    daq_to_daqlink_o.event_trailer <= daqfifo_dout(64);
    daq_to_daqlink_o.event_valid <= daqfifo_valid;
    tts_ready_o <= '1' when tts_state = x"8" else '0';

    daq_ready <= daqlink_to_daq_i.ready;
    daq_almost_full <= daqlink_to_daq_i.almost_full;
    daq_disper_err_cnt <= daqlink_to_daq_i.disperr_cnt;
    daq_notintable_err_cnt <= daqlink_to_daq_i.notintable_cnt;
    
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
    
    reset_daq_async <= reset_pwrup or reset_global or reset_local or resync_done_delayed or reset_local_latched;
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

    -- delay and extend the reset pulse

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
            pulse_o        => reset_daq
        );

    -- if reset_till_resync option is enabled, latch the user requested reset_local till a resync is received
    
    process(ttc_clks_i.clk_40)
    begin
        if (rising_edge(ttc_clks_i.clk_40)) then
            if (reset_till_resync = '1') then
                if (reset_local = '1') then
                    reset_local_latched <= '1'; 
                elsif (ttc_cmds_i.resync = '1') then
                    reset_local_latched  <= '0';
                else 
                    reset_local_latched <= reset_local_latched;
                end if;
            else
                reset_local_latched <= '0';
            end if;
        end if;
    end process;

    --================================--
    -- Last event spy fifo
    --================================--

    -- this fifo is used to store a single event at a time which can then be read through slow control (it's then filled with the next available event after it's been emptied)
    i_last_event_fifo : xpm_fifo_async
        generic map(
            FIFO_MEMORY_TYPE    => "block",
            FIFO_WRITE_DEPTH    => CFG_DAQ_LASTEVT_FIFO_DEPTH,
            RELATED_CLOCKS      => 0,
            WRITE_DATA_WIDTH    => 64,
            READ_MODE           => "std",
            FIFO_READ_LATENCY   => 1,
            FULL_RESET_VALUE    => 0,
            USE_ADV_FEATURES    => "1001", -- VALID(12) = 1 ; AEMPTY(11) = 0; RD_DATA_CNT(10) = 0; PROG_EMPTY(9) = 0; UNDERFLOW(8) = 0; -- WR_ACK(4) = 0; AFULL(3) = 0; WR_DATA_CNT(2) = 0; PROG_FULL(1) = 0; OVERFLOW(0) = 1
            READ_DATA_WIDTH     => 32,
            CDC_SYNC_STAGES     => 2,
            DOUT_RESET_VALUE    => "0",
            ECC_MODE            => "no_ecc"
        )
        port map(
            sleep         => '0',
            rst           => reset_daq,
            wr_clk        => daq_clk_i,
            wr_en         => daq_event_write_en and last_evt_fifo_en,
            din           => daq_event_data(31 downto 0) & daq_event_data(63 downto 32),
            full          => open,
            prog_full     => open,
            wr_data_count => open,
            overflow      => open,
            wr_rst_busy   => open,
            almost_full   => open,
            wr_ack        => open,
            rd_clk        => ipb_clk_i,
            rd_en         => last_evt_fifo_rd_en,
            dout          => last_evt_fifo_dout,
            empty         => last_evt_fifo_empty,
            prog_empty    => open,
            rd_data_count => open,
            underflow     => open,
            rd_rst_busy   => open,
            almost_empty  => open,
            data_valid    => last_evt_fifo_valid,
            injectsbiterr => '0',
            injectdbiterr => '0',
            sbiterr       => open,
            dbiterr       => open
        );    

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
    daqfifo_wr_en <= daq_event_write_en and (not ignore_amc13);
    
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
            WRITE_DATA_WIDTH    => 53,
            READ_MODE           => "fwft",
            FIFO_READ_LATENCY   => 0,
            FULL_RESET_VALUE    => 0,
            USE_ADV_FEATURES    => "170B", -- VALID(12) = 1 ; AEMPTY(11) = 0; RD_DATA_CNT(10) = 1; PROG_EMPTY(9) = 1; UNDERFLOW(8) = 1; -- WR_ACK(4) = 0; AFULL(3) = 1; WR_DATA_CNT(2) = 0; PROG_FULL(1) = 1; OVERFLOW(0) = 1
            READ_DATA_WIDTH     => 53,
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
    
    -- fill the L1A FIFO
    process(ttc_clks_i.clk_40)
    begin
        if (rising_edge(ttc_clks_i.clk_40)) then
            if (reset_daq = '1') then
                err_l1afifo_full <= '0';
                l1afifo_wr_en <= '0';
                l1a_gap_cntdown <= (others => '0');
            else                
                if ((ttc_cmds_i.l1a = '1') and (freeze_on_error = '0' or tts_critical_error = '0')) then
                    l1a_gap_cntdown <= x"27";
                    
                    l1afifo_din <= or_reduce(std_logic_vector(l1a_gap_cntdown)) & ttc_daq_cntrs_i.l1id & ttc_daq_cntrs_i.orbit & ttc_daq_cntrs_i.bx;
                    if (l1afifo_full = '0') then
                        l1afifo_wr_en <= '1';
                        err_l1afifo_full <= err_l1afifo_full;
                    else
                        l1afifo_wr_en <= '0';
                        err_l1afifo_full <= '1';
                    end if;
                else
                    l1afifo_wr_en <= '0';
                    err_l1afifo_full <= err_l1afifo_full;
                    if l1a_gap_cntdown /= x"00" then
                        l1a_gap_cntdown <= l1a_gap_cntdown - 1;
                    else
                        l1a_gap_cntdown <= x"00";
                    end if;                    
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
    -- Spy Path
    --================================--

    i_spy_fifo : xpm_fifo_async
        generic map(
            FIFO_MEMORY_TYPE    => "block",
            FIFO_WRITE_DEPTH    => CFG_DAQ_SPYFIFO_DEPTH,
            RELATED_CLOCKS      => 0,
            WRITE_DATA_WIDTH    => 64,
            READ_MODE           => "fwft",
            FIFO_READ_LATENCY   => 0,
            FULL_RESET_VALUE    => 1,
            USE_ADV_FEATURES    => "0A03", -- VALID(12) = 0 ; AEMPTY(11) = 1; RD_DATA_CNT(10) = 0; PROG_EMPTY(9) = 1; UNDERFLOW(8) = 1; -- WR_ACK(4) = 0; AFULL(3) = 0; WR_DATA_CNT(2) = 0; PROG_FULL(1) = 1; OVERFLOW(0) = 1
            READ_DATA_WIDTH     => 16,
            CDC_SYNC_STAGES     => 2,
            PROG_FULL_THRESH    => CFG_DAQ_SPYFIFO_PROG_FULL_SET,
            PROG_EMPTY_THRESH   => CFG_DAQ_SPYFIFO_PROG_FULL_RESET,
            DOUT_RESET_VALUE    => "0",
            ECC_MODE            => "no_ecc"
        )
        port map(
            sleep         => '0',
            rst           => reset_daq,
            wr_clk        => daq_clk_i,
            wr_en         => spy_fifo_wr_en and spy_prescale_keep_evt,
            din           => daq_event_data,
            full          => open,
            prog_full     => spy_fifo_prog_full,
            wr_data_count => open,
            overflow      => spy_fifo_ovf,
            wr_rst_busy   => open,
            almost_full   => open,
            wr_ack        => open,
            rd_clk        => spy_clk_i,
            rd_en         => spy_fifo_rd_en,
            dout          => spy_fifo_dout,
            empty         => spy_fifo_empty,
            prog_empty    => spy_fifo_prog_empty,
            rd_data_count => open,
            underflow     => open,
            rd_rst_busy   => open,
            almost_empty  => spy_fifo_aempty,
            data_valid    => open,
            injectsbiterr => '0',
            injectdbiterr => '0',
            sbiterr       => open,
            dbiterr       => open
        );    

    i_sync_spyfifo_prog_empty : entity work.synch generic map(N_STAGES => 3) port map(async_i => spy_fifo_prog_empty, clk_i => daq_clk_i, sync_o => spy_fifo_prog_empty_wrclk);
    i_latch_spyfifo_near_full : entity work.latch port map(
            reset_i => spy_fifo_prog_empty_wrclk,
            clk_i   => daq_clk_i,
            input_i => spy_fifo_prog_full,
            latch_o => spy_fifo_afull
        );        
    
    i_spy_ethernet_driver : entity work.gbe_tx_driver
        generic map(
            g_MAX_PAYLOAD_WORDS   => 3976,
            g_MIN_PAYLOAD_WORDS   => 28, -- should be 32 based on ethernet specification, but hmm looks like DDU is using 56, and actually that's what the driver is expecting too, otherwise some filler words get on disk
            g_MAX_EVT_WORDS       => 50000,
            g_NUM_IDLES_SMALL_EVT => 2,
            g_NUM_IDLES_BIG_EVT   => 7,
            g_SMALL_EVT_MAX_WORDS => 24
        )
        port map(
            reset_i             => reset_daq,
            gbe_clk_i           => spy_clk_i,
            gbe_tx_data_o       => spy_link_o,
            skip_eth_header_i   => spy_gbe_skip_headers,
            data_empty_i        => spy_fifo_empty,
            data_i              => spy_fifo_dout,
            data_rd_en          => spy_fifo_rd_en,
            last_valid_word_i   => spy_fifo_aempty,
            err_event_too_big_o => spy_err_evt_too_big,
            err_eoe_not_found_o => spy_err_eoe_not_found,
            word_rate_o         => spy_word_rate,
            evt_cnt_o           => spy_evt_sent
        );
    
    -- Near-full counter
    i_spy_near_full_counter : entity work.counter
    generic map(
        g_COUNTER_WIDTH  => 16,
        g_ALLOW_ROLLOVER => FALSE
    )
    port map(
        ref_clk_i => daq_clk_i,
        reset_i   => reset_daq,
        en_i      => spy_fifo_afull,
        count_o   => spy_fifo_afull_cnt
    );
        
    -- latch the spy fifo overflow error
    process(daq_clk_i)
    begin
        if (rising_edge(daq_clk_i)) then
            if (reset_daq = '1') then
                err_spy_fifo_ovf <= '0';
            else
                if (spy_fifo_ovf = '1') then
                    err_spy_fifo_ovf <= '1';
                else
                    err_spy_fifo_ovf <= err_spy_fifo_ovf;
                end if;
            end if;
        end if;
    end process;
        
    --================================--
    -- Chamber Event Builders
    --================================--

    g_chamber_evt_builders : for i in 0 to (g_NUM_OF_DMBs - 1) generate
    begin

        i_input_processor : entity work.input_processor
        generic map (
            g_input_clk_freq => 80_000_000
        )
        port map
        (
            -- Reset
            reset_i                     => reset_daq,

            -- Config
            input_enable_i              => input_mask(i) and not (freeze_on_error and tts_critical_error),

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

            -- Track data
            input_clk_i                 => input_clk_arr_i(i),
            input_data_link_i           => input_link_arr_i(i),
            
            -- Status and control
            status_o                    => input_status_arr(i),
            control_i                   => input_control_arr(i)
        );
    
        chmb_evtfifos_empty(i) <= chamber_evtfifos(i).empty;
        chamber_evtfifos(i).rd_en <= chmb_evtfifos_rd_en(i);
        chamber_infifos(i).rd_en <= chmb_infifos_rd_en(i);
        chmb_tts_states(i) <= input_status_arr(i).tts_state;
        
    end generate;
        
    --================================--
    -- L1A request logic
    --================================--
        
    process (daq_clk_i)
    begin
        if rising_edge(daq_clk_i) then
            if (reset_daq = '1') then
                l1a_req_evt_num <= (others => '0');
                l1a_request_o <= '0';
            else
                l1a_req_evt_num <= l1a_req_evt_num;
                l1a_request_o <= '0';
                
                for i in 0 to (g_NUM_OF_DMBs - 1) loop
                    if chamber_evtfifos(i).valid = '1' and input_mask(i) = '1' and (unsigned(chamber_evtfifos(i).dout(59 downto 36)) > l1a_req_evt_num or (chamber_evtfifos(i).dout(59 downto 36) = x"000000" and l1a_req_evt_num = x"ffffff")) then
                        l1a_req_evt_num <= unsigned(chamber_evtfifos(i).dout(59 downto 36));
                        l1a_request_o <= l1a_req_en;
                    end if;
                end loop;
            
            end if;
        end if;
    end process;
        
    --================================--
    -- TTS
    --================================--

    -- TODO: this is a cheat -- using the first input clock to aggregate input TTS states 
    process (input_clk_arr_i(0))
    begin
        if (rising_edge(input_clk_arr_i(0))) then
            if (reset_daq = '1') then
                tts_chmb_critical <= '0';
                tts_chmb_oos <= '0';
                tts_chmb_warning <= '0';
                tts_chmb_critical_arr <= (others => '0');
                tts_chmb_oos_arr <= (others => '0');
                tts_chmb_warning_arr <= (others => '0');
                tts_start_cntdwn_chmb <= x"32";
            else
                if (tts_start_cntdwn_chmb = x"00") then
                    for i in 0 to (g_NUM_OF_DMBs - 1) loop
                        tts_chmb_critical_arr(i) <= chmb_tts_states(i)(2) and input_mask(i);
                        tts_chmb_oos_arr(i) <= chmb_tts_states(i)(1) and input_mask(i);
                        tts_chmb_warning_arr(i) <= chmb_tts_states(i)(0) and input_mask(i);
                    end loop;                
                    
                    if (tts_chmb_critical = '1' or or_reduce(tts_chmb_critical_arr) = '1') then
                        tts_chmb_critical <= '1';
                    else
                        tts_chmb_critical <= '0';
                    end if;
                    
                    if (tts_chmb_oos = '1' or or_reduce(tts_chmb_oos_arr) = '1') then
                        tts_chmb_oos <= '1';
                    else
                        tts_chmb_oos <= '0';
                    end if;
                    
                    if (or_reduce(tts_chmb_warning_arr) = '1') then
                        tts_chmb_warning <= '1';
                    else
                        tts_chmb_warning <= '0';
                    end if;
                else
                    tts_start_cntdwn_chmb <= tts_start_cntdwn_chmb - 1;
                end if;
            end if;
        end if;
    end process;

    i_tts_sync_chmb_error   : entity work.synch generic map(N_STAGES => 2) port map(async_i => tts_chmb_critical,    clk_i => ttc_clks_i.clk_40, sync_o  => tts_chmb_critical_tts_clk);
    i_tts_sync_chmb_warn    : entity work.synch generic map(N_STAGES => 2) port map(async_i => tts_chmb_warning,     clk_i => ttc_clks_i.clk_40, sync_o  => tts_chmb_warning_tts_clk);
    i_tts_sync_chmb_oos     : entity work.synch generic map(N_STAGES => 2) port map(async_i => tts_chmb_oos,         clk_i => ttc_clks_i.clk_40, sync_o  => tts_chmb_out_of_sync_tts_clk);
    i_tts_sync_daqfifo_full : entity work.synch generic map(N_STAGES => 2) port map(async_i => err_daqfifo_full,     clk_i => ttc_clks_i.clk_40, sync_o  => err_daqfifo_full_tts_clk);

    process (ttc_clks_i.clk_40)
    begin
        if (rising_edge(ttc_clks_i.clk_40)) then
            if (reset_daq = '1') then
                tts_critical_error <= '0';
                tts_out_of_sync <= '0';
                tts_warning <= '0';
                tts_busy <= '1';
                tts_start_cntdwn <= x"32";
            else
                if (tts_start_cntdwn = x"00") then
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
                if (resync_mode = '1' and l1afifo_empty = '1' and daq_state = IDLE and (daqfifo_empty = '1' or ignore_amc13 = '1')) then
                    resync_done <= '1';
                end if;
            end if;
        end if;
    end process;
     
    --================================--
    -- DDU CRC16
    --================================--
     
    i_ddu_crc16 : entity work.crc16_usb
        port map(
            data_in     => daq_event_data,
            crc_en      => spy_fifo_wr_en,
            rst         => daq_event_header,
            clk         => daq_clk_i,
            crc_reg     => open,
            crc_current => ddu_crc
        );
     
    --================================--
    -- Event shipping to DAQLink
    --================================--
    
    process(daq_clk_i)
    
        -- event info
        variable e_l1a_id                   : std_logic_vector(23 downto 0) := (others => '0');        
        variable e_bx_id                    : std_logic_vector(11 downto 0) := (others => '0');        
        variable e_orbit_id                 : std_logic_vector(15 downto 0) := (others => '0');
        
        variable e_dmb_full                 : std_logic_vector(23 downto 0) := (others => '0');
        
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
        variable e_chmb_64bit_misaligned    : std_logic := '0';
        variable e_chmb_evt_too_big         : std_logic := '0';
        variable e_chmb_evt_bigger_24       : std_logic := '0';
        variable e_chmb_mixed_oh_bc         : std_logic := '0';
        variable e_chmb_mixed_vfat_bc       : std_logic := '0';
        variable e_chmb_mixed_vfat_ec       : std_logic := '0';
        
        variable e_chmb_not_empty_arr       : std_logic_vector(23 downto 0) := (others => '0');
              
    begin
    
        if (rising_edge(daq_clk_i)) then
        
            if (reset_daq = '1') then
                daq_state <= IDLE;
                daq_event_data <= (others => '0');
                daq_event_header <= '0';
                daq_event_trailer <= '0';
                daq_event_write_en <= '0';
                chmb_evtfifos_rd_en <= (others => '0');
                l1afifo_rd_en <= '0';
                daq_curr_infifo_word <= (others => '0');
                chmb_infifos_rd_en <= (others => '0');
                cnt_sent_events <= (others => '0');
                e_word_count <= (others => '0');
                dav_timer <= (others => '0');
                max_dav_timer <= (others => '0');
                last_dav_timer <= (others => '0');
                dav_timeout_flags <= (others => '0');
                spy_fifo_wr_en <= '0';
                spy_prescale_counter <= x"0002";
                spy_prescale_keep_evt <= '0';
                daq_not_empty_event <= '0';
                dmb_64bit_misaligned <= '0';
            else
            
                -- output formatting state machine

                if (daq_state = IDLE) then
                
                    -- zero out everything, especially the write enable :)
                    daq_event_data <= (others => '0');
                    daq_event_header <= '0';
                    daq_event_trailer <= '0';
                    daq_event_write_en <= '0';
                    spy_fifo_wr_en <= '0';
                    e_word_count <= (others => '0');
                    e_input_idx <= 0;
                    dmb_64bit_misaligned <= '0';
                    
                    
                    -- have an L1A and data from all enabled inputs is ready (or these inputs have timed out)
                    if (l1afifo_empty = '0' and ((input_mask(g_NUM_OF_DMBs - 1 downto 0) and ((not chmb_evtfifos_empty) or dav_timeout_flags(g_NUM_OF_DMBs - 1 downto 0))) = input_mask(g_NUM_OF_DMBs - 1 downto 0))) then
                        if (((daq_ready = '1' and daqfifo_near_full = '0') or (ignore_amc13 = '1')) and daq_enable = '1') then -- everybody ready?.... GO! :)
                            -- start the DAQ state machine
                            daq_state <= AMC13_HEADER_1;
                            
                            -- fetch the data from the L1A FIFO
                            l1afifo_rd_en <= '1';
                            
                            -- set the DAV mask
                            e_dav_mask(g_NUM_OF_DMBs - 1 downto 0) <= input_mask(g_NUM_OF_DMBs - 1 downto 0) and ((not chmb_evtfifos_empty) and (not dav_timeout_flags(g_NUM_OF_DMBs - 1 downto 0)));
                            
                            -- save timer stats
                            dav_timer <= (others => '0');
                            last_dav_timer <= dav_timer;
                            if ((dav_timer > max_dav_timer) and (or_reduce(dav_timeout_flags) = '0')) then
                                max_dav_timer <= dav_timer;
                            end if;
                            
                            -- if last event fifo has already been read by the user then enable writing to this fifo for the current event
                            last_evt_fifo_en <= last_evt_fifo_empty and (not block_last_evt_fifo);
                            
                        end if;
                    -- have an L1A, but waiting for data -- start counting the time
                    elsif (l1afifo_empty = '0') then
                        dav_timer <= dav_timer + 1;
                    end if;
                    
                    -- set the timeout flags if the timer has reached the dav_timeout value
                    if (dav_timer >= unsigned(dav_timeout)) then
                        dav_timeout_flags(g_NUM_OF_DMBs - 1 downto 0) <= chmb_evtfifos_empty and input_mask(g_NUM_OF_DMBs - 1 downto 0);
                    end if;
                                        
                else -- lets send some data!
                
                    l1afifo_rd_en <= '0';
                    
                    ----==== send the first AMC header ====----
                    if (daq_state = AMC13_HEADER_1) then
                        
                        -- L1A fifo is a first-word-fallthrough fifo, so no need to check for valid (not empty is the condition to get here anyway)
                        
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
                        spy_fifo_wr_en <= '0';
                        
                        -- move to the next state
                        e_word_count <= e_word_count + 1;
                        daq_state <= AMC13_HEADER_2;
                        
                        -- check if this event is empty or not
                        for i in 0 to g_NUM_OF_DMBs - 1 loop
                            e_chmb_not_empty_arr(i) := chamber_evtfifos(i).dout(3);
                        end loop;
                        daq_not_empty_event <= or_reduce(e_chmb_not_empty_arr and e_dav_mask);
                        
                    ----==== send the second AMC header ====----
                    elsif (daq_state = AMC13_HEADER_2) then
                    
                        -- calculate the DAV count (I know it's ugly...)
                        e_dav_count <= to_integer(unsigned(e_chmb_not_empty_arr(0 downto 0) and e_dav_mask(0 downto 0))) + to_integer(unsigned(e_chmb_not_empty_arr(1 downto 1) and e_dav_mask(1 downto 1))) + to_integer(unsigned(e_chmb_not_empty_arr(2 downto 2) and e_dav_mask(2 downto 2))) + to_integer(unsigned(e_chmb_not_empty_arr(3 downto 3) and e_dav_mask(3 downto 3))) + to_integer(unsigned(e_chmb_not_empty_arr(4 downto 4) and e_dav_mask(4 downto 4))) + to_integer(unsigned(e_chmb_not_empty_arr(5 downto 5) and e_dav_mask(5 downto 5))) + to_integer(unsigned(e_chmb_not_empty_arr(6 downto 6) and e_dav_mask(6 downto 6))) + to_integer(unsigned(e_chmb_not_empty_arr(7 downto 7) and e_dav_mask(7 downto 7))) + to_integer(unsigned(e_chmb_not_empty_arr(8 downto 8) and e_dav_mask(8 downto 8))) + to_integer(unsigned(e_chmb_not_empty_arr(8 downto 9) and e_dav_mask(9 downto 9))) + to_integer(unsigned(e_chmb_not_empty_arr(10 downto 10) and e_dav_mask(10 downto 10))) + to_integer(unsigned(e_chmb_not_empty_arr(11 downto 11) and e_dav_mask(11 downto 11))) + to_integer(unsigned(e_chmb_not_empty_arr(12 downto 12) and e_dav_mask(12 downto 12))) + to_integer(unsigned(e_chmb_not_empty_arr(13 downto 13) and e_dav_mask(13 downto 13))) + to_integer(unsigned(e_chmb_not_empty_arr(14 downto 14) and e_dav_mask(14 downto 14))) + to_integer(unsigned(e_chmb_not_empty_arr(15 downto 15) and e_dav_mask(15 downto 15))) + to_integer(unsigned(e_chmb_not_empty_arr(16 downto 16) and e_dav_mask(16 downto 16))) + to_integer(unsigned(e_chmb_not_empty_arr(17 downto 17) and e_dav_mask(17 downto 17))) + to_integer(unsigned(e_chmb_not_empty_arr(18 downto 18) and e_dav_mask(18 downto 18))) + to_integer(unsigned(e_chmb_not_empty_arr(19 downto 19) and e_dav_mask(19 downto 19))) + to_integer(unsigned(e_chmb_not_empty_arr(20 downto 20) and e_dav_mask(20 downto 20))) + to_integer(unsigned(e_chmb_not_empty_arr(21 downto 21) and e_dav_mask(21 downto 21))) + to_integer(unsigned(e_chmb_not_empty_arr(22 downto 22) and e_dav_mask(22 downto 22))) + to_integer(unsigned(e_chmb_not_empty_arr(23 downto 23) and e_dav_mask(23 downto 23)));
                        
                        -- send the data
                        daq_event_data <= C_DAQ_FORMAT_VERSION &
                                          run_type &
                                          run_params &
                                          e_orbit_id & 
                                          board_id_i;
                        daq_event_header <= '0';
                        daq_event_trailer <= '0';
                        daq_event_write_en <= '1';
                        spy_fifo_wr_en <= '0';
                        
                        -- move to the next state
                        e_word_count <= e_word_count + 1;
                        daq_state <= FED_HEADER_1;

                        -- trying to match the DDU logic here somewhat.. so it's kindof convoluted..
                        -- the counter starts at 2 after resync, and then events are accepted when it's equal to the set prescale
                        -- once an event is accepted, the counter is reset to 1 (note not 2)
                        -- prescale values of 0 and 1 just allow all events 
                        if (spy_prescale = x"0000" or spy_prescale = x"0001") then
                            spy_prescale_counter <= x"0001";
                            spy_prescale_keep_evt <= (not spy_skip_empty_evts) or daq_not_empty_event;
                        elsif (std_logic_vector(spy_prescale_counter) = spy_prescale) then
                            spy_prescale_counter <= x"0001";
                            spy_prescale_keep_evt <= (not spy_skip_empty_evts) or daq_not_empty_event;
                        else
                            spy_prescale_counter <= spy_prescale_counter + 1;
                            spy_prescale_keep_evt <= '0';
                        end if;
                                            
                    ----==== send the FED header #1 ====----
                    elsif (daq_state = FED_HEADER_1) then
                    
                        -- send the data
                        daq_event_data <= x"50" &
                                          e_l1a_id &
                                          e_bx_id &
                                          board_id_i(11 downto 0) &
                                          C_DAQ_FORMAT_VERSION &
                                          x"0";
                        daq_event_header <= '0';
                        daq_event_trailer <= '0';
                        daq_event_write_en <= '1';
                        spy_fifo_wr_en <= '1';
                        
                        -- move to the next state
                        e_word_count <= e_word_count + 1;
                        daq_state <= FED_HEADER_2;                        

                    ----==== send the FED header #2 ====----
                    elsif (daq_state = FED_HEADER_2) then
                        
                        e_dmb_full(tts_chmb_critical_arr'left downto tts_chmb_critical_arr'right) := tts_chmb_critical_arr; -- TODO: should be synced to the DAQ clock!
                    
                        -- send the data
                        daq_event_data <= x"800000018000" &
                                          e_dmb_full(15 downto 0);
                        daq_event_header <= '0';
                        daq_event_trailer <= '0';
                        daq_event_write_en <= '1';
                        spy_fifo_wr_en <= '1';
                        
                        -- move to the next state
                        e_word_count <= e_word_count + 1;
                        daq_state <= FED_HEADER_3;

                    ----==== send the FED header #2 ====----
                    elsif (daq_state = FED_HEADER_3) then

                        -- send the data
                        daq_event_data <= input_mask(15 downto 0) & -- which DDU Fiber Inputs have a "Live" fiber (High True, 1 Fiber Input per CSC) 
                                          err_daqfifo_full & -- DDU Output-Limited Buffer Overflow occurred
                                          daq_almost_full & -- DAQ Wait was asserted by S-Link or DCC TODO: use a latched flag here
                                          '0' & -- Link Full (LFF) was asserted by S-Link
                                          '0' & -- DDU S-Link Never Ready
                                          '0' & -- GbE/SPY FIFO Overflow occurred TODO: implement this
                                          '0' & -- GbE/SPY Event was skipped to prevent overflow TODO: implement this
                                          '0' & -- GbE/SPY FIFO Always Empty TODO: implement this
                                          '0' & -- Gbe/SPY Fiber Connection Error occurred
                                          (tts_critical_error and daq_almost_full)  & -- DDU Buffer Overflow caused by DAQ Wait
                                          err_daqfifo_full & -- DAQ Wait is set by DCC/S-Link TODO: transfer to DAQ clk
                                          err_daqfifo_full & -- Link Full (LFF) is set by DDU S-Link TODO: transfer to DAQ clk
                                          (not daq_ready) & --Not Ready is set by DDU S-Link
                                          '0' & -- GbE/SPY FIFO is Full TODO: implement this
                                          '0' & -- GbE/SPY Path was Not Enabled for this event TODO: implement this
                                          '0' & -- GbE/SPY FIFO is Not Empty TODO: implement this
                                          '0' & -- DCC Link is Not Ready 
                                          (e_dav_mask(15 downto 0) and e_chmb_not_empty_arr(15 downto 0)) & -- which CSCs have data for this event; one bit allocated per DDU fiber input
                                          '0' & -- NOT USED
                                          '0' & -- DDU single event warning *minor format error, fiber/RX error, or the DDU lost it's clock for some time; possible data loss  * consider RESET if this warning continues for consecutive events
                                          err_l1afifo_full & -- DDU SyncError (bad event, RESET req'd) * Multiple L1A errors or FIFO Full; possible data loss
                                          '0' & -- DDU detected Fiber Error * change of fiber connection status or No Live Fibers; a hardware problem probably exists
                                          tts_critical_error & -- DDU detected Critical Error, irrecoverable * OR of all possible "RESET required" cases TODO: transfer to DAQ clk
                                          '0' & --  DDU detected Single Error (bad event) * OR of all possible "bad" cases at Beginning of Event TODO: figure out what this means
                                          '0' & -- DDU detected DMB L1A Match Error *the DDU L1A event number match failed for 1 or more CSCs; possible one-time bit error TODO: implement this
                                          or_reduce(dav_timeout_flags) & -- DDU Timeout Error *data from a CSC never arrived *an unknowable amount of data has been irrevocably lost
                                          tts_state & -- TODO: should be synced to the DAQ clock
                                          std_logic_vector(to_unsigned(e_dav_count, 4));
                        daq_event_header <= '0';
                        daq_event_trailer <= '0';
                        daq_event_write_en <= '1';
                        spy_fifo_wr_en <= '1';                        
                        e_word_count <= e_word_count + 1;
                        
                        -- if this is an empty event, just pop those lone words and go straight to trailer, otherwise go to payload
                        if (daq_not_empty_event = '1') then
                            daq_state <= PAYLOAD;
                            e_payload_first_cycle <= '1';
                        else
                            daq_state <= FED_TRAILER_1;
                            e_payload_first_cycle <= '1';
                            for i in 0 to g_NUM_OF_DMBs - 1 loop
                                chmb_evtfifos_rd_en(i) <= e_dav_mask(i);
                                chmb_infifos_rd_en(i) <= e_dav_mask(i);
                            end loop;
                        end if;

                    ----==== send the payload ====----
                    elsif (daq_state = PAYLOAD) then

                        daq_event_header <= '0';
                        daq_event_trailer <= '0';
                                            
                        -- if there's no data from the current input (or a lone word)
                        if ((e_dav_mask(e_input_idx) = '0') or ((e_dav_mask(e_input_idx) = '1') and (chamber_evtfifos(e_input_idx).dout(23 downto 12) = x"001"))) then
                            
                            e_word_count <= e_word_count;
                            daq_event_data <= (others => '0');
                            daq_event_write_en <= '0';
                            spy_fifo_wr_en <= '0';
                            e_payload_first_cycle <= '1';
                            
                            -- make sure to reset the read enable of the previous input if we're not at the first one 
                            if (e_input_idx > 0) then
                                chmb_evtfifos_rd_en(e_input_idx - 1) <= '0';
                                chmb_infifos_rd_en(e_input_idx - 1) <= '0';                            
                            end if;
                            
                            -- pop the event fifo if there's an event there (lone event in this case)
                            if (e_dav_mask(e_input_idx) = '1') then
                                chmb_evtfifos_rd_en(e_input_idx) <= '1';
                                chmb_infifos_rd_en(e_input_idx) <= '1';                            
                            end if;
                            
                            -- if we're not at the last input yet, just go to the next one
                            if (e_input_idx < g_NUM_OF_DMBs - 1) then
                                e_input_idx <= e_input_idx + 1;
                                daq_state <= PAYLOAD;
                                
                            -- if we are at the last input, then skip to the trailer                                
                            else
                                e_input_idx <= e_input_idx;
                                daq_state <= FED_TRAILER_1;
                            
                            end if;
                        else

                            if chamber_evtfifos(e_input_idx).dout(4) = '1' then
                                dmb_64bit_misaligned <= '1';
                            else
                                dmb_64bit_misaligned <= dmb_64bit_misaligned;
                            end if;

                            -- keep reading the input fifo
                            daq_event_write_en <= not e_payload_first_cycle;
                            spy_fifo_wr_en <= not e_payload_first_cycle;                        
                            daq_event_data <= chamber_infifos(e_input_idx).dout;

                            -- make sure to reset the read enables of the previous input
                            if (e_input_idx > 0) then
                                chmb_evtfifos_rd_en(e_input_idx - 1) <= '0';
                                chmb_infifos_rd_en(e_input_idx - 1) <= '0';
                            end if;
                            
                            -- if this is the first cycle at this input, take the size here, otherwise just decrease the word countdown
                            if (e_payload_first_cycle = '1') then
                                daq_curr_infifo_word <= unsigned(chamber_evtfifos(e_input_idx).dout(23 downto 12)) - 1;
                                e_payload_first_cycle <= '0';
                                chmb_evtfifos_rd_en(e_input_idx) <= '0';
                                daq_state <= PAYLOAD;
                                e_input_idx <= e_input_idx;
                                chmb_infifos_rd_en(e_input_idx) <= '1';
                            else
                                daq_curr_infifo_word <= daq_curr_infifo_word - 1;
                                e_word_count <= e_word_count + 1;
                                
                                -- end of event for this input
                                if (daq_curr_infifo_word = x"000") then
                                    chmb_evtfifos_rd_en(e_input_idx) <= '1';
                                    e_payload_first_cycle <= '1';
                                    chmb_infifos_rd_en(e_input_idx) <= '0';
                                    
                                    if (e_input_idx = g_NUM_OF_DMBs - 1) then
                                        daq_state <= FED_TRAILER_1;
                                        e_input_idx <= e_input_idx;
                                    else
                                        daq_state <= PAYLOAD;
                                        e_input_idx <= e_input_idx + 1;
                                    end if;
                                -- still sending the current input event
                                else
                                    chmb_evtfifos_rd_en(e_input_idx) <= '0';
                                    e_payload_first_cycle <= '0';
                                    daq_state <= PAYLOAD;
                                    e_input_idx <= e_input_idx;
                                    chmb_infifos_rd_en(e_input_idx) <= '1';
                                end if;
                                
                            end if;
                            
                        end if;

                    ----==== send the FED trailer 1 ====----
                    elsif (daq_state = FED_TRAILER_1) then

                        for i in 0 to g_NUM_OF_DMBs - 1 loop
                            chmb_evtfifos_rd_en(i) <= '0';
                            chmb_infifos_rd_en(i) <= '0';
                        end loop;

                        -- send the data
                        daq_event_data <= x"8000ffff80008000"; -- unique FED trailer word
                        daq_event_header <= '0';
                        daq_event_trailer <= '0';
                        daq_event_write_en <= '1';
                        spy_fifo_wr_en <= '1';                        
                        
                        -- move to the next state
                        e_word_count <= e_word_count + 1;
                        daq_state <= FED_TRAILER_2;

                    ----==== send the FED trailer 2 ====----
                    elsif (daq_state = FED_TRAILER_2) then

                        -- send the data TODO: implement the missing status flags
                        daq_event_data <= '0' & -- CSC LCT/DAV Mismatch occurred (bad event) 
                                          '0' & -- DDU-CFEB L1 Number Mismatch occurred (bad event) 
                                          '0' & -- No Good DMB CRCs were detected in this Event (perfectly normal empty event or possible bad event?) 
                                          '0' & -- CFEB Count Error occurred (bad event)
                                          '0' & --  DDU Bad First Data Word From CSC Error (bad event)
                                          err_l1afifo_full & -- DDU L1A-FIFO Full Error (RESET req'd) *the DDU L1A-event info FIFO went full; some triggers/events may be lost or garbled
                                          '0' & -- DDU Data Stuck in FIFO Error
                                          (not or_reduce(input_mask)) & -- DDU NoLiveFibers Error *no DDU fiber inputs are connected, something is wrong; will cause other errors...
                                          '0' & -- DDU Special Word Inconsistency Warning (possible bad event?) *a bit-vote failure occured on an input fiber channel
                                          '0' & -- DDU Input FPGA Error (bad event) 
                                          daq_almost_full & -- DCC/S-Link Wait is set 
                                          (not daq_ready) & -- DCC Link is Not Ready
                                          '0' & -- DDU detected TMB Error (bad event) *TMB trail word not found or TMB L1A, CRC or wordcount inconsistent
                                          '0' & -- DDU detected ALCT Error (bad event) *ALCT trail word not found or ALCT L1A, CRC or wordcount inconsistent
                                          '0' & -- DDU detected TMB or ALCT Word Count Error (bad event, RESET?) *TMB/ALCT wordcount inconsistent *if error continues for consecutive events then RESET req'd
                                          '0' & -- DDU detected TMB or ALCT L1A Number Error (bad event, RESET?) *TMB/ALCT L1A Number mismatch with DDU *if error continues for consecutive events then RESET req'd
                                          tts_critical_error & -- DDU detected Critical Error, irrecoverable (RESET req'd) *OR of all possible "RESET required" cases
                                          '0' & -- DDU detected Single Error (bad event) *OR of all possible "bad event" cases
                                          '0' & -- DDU Single Warning (possible bad event?) *OR of bit55, bit42
                                          (tts_warning or daq_almost_full) & --  DDU FIFO Near Full Warning or DAQ Wait is set (status only) *OR of all possible "Near Full" cases
                                          '0' & -- DDU detected Data Alignment Error from 1 or more inputs (bad event) *CSC data violated the 64-bit word boundary
                                          '0' & -- DDU Clock-DLL Error (may be OK, RESET?) *the DDU lost it's clock for an unknown period of time; some triggers/events/data may be lost
                                          or_reduce(dav_timeout_flags) & -- DDU detected CSC Error (bad event) *Timeout, DMB CRC, CFEB Sync/Overflow, or missing CFEB data
                                          '0' & -- DDU Lost In Event Error (bad event, but end was found) *the DDU failed to find an expected control word within the event, NOT fatal
                                          '0' & -- DDU Lost In Data Error (bad event, RESET req'd) *usally Fatal; DDU checking algorithms are irrevocably lost in the data stream *mis-sequenced data structure, possible that different events were run together *found at least one of the following in the event data stream, all of which are very bad: -Extra CSC_First_Word before CSC_Last_Word -Extra DMB_Header2 before DMB_Last_Word -Lone Word before DMB_Last_Word -Extra TMB/ALCT_Trailer before DMB_Last_Word -Extra DMB_Trailer1 before DMB_Last_Word -DMB_Trailer2 before DMB_Trailer1 Note:  CSC_Last_Word == DMB_Trailer2
                                          or_reduce(dav_timeout_flags) & -- DDU Timeout Error (bad event, RESET req'd) *data from a fiber input either never started or never finished *an unknowable amount of data has been irrevocably lost
                                          '0' & -- DDU detected TMB or ALCT CRC Error (bad event, RESET?) *CRC check failed on 1 or more TMB/ALCT; possible one-time bit error *if error continues for consecutive events then RESET req'd
                                          '0' & -- DDU Multiple Transmit Errors (bad event, RESET req'd) *one bit-vote failure (or Rx Error) has occured on multiple occassions for the same CSC
                                          (tts_critical_error or tts_out_of_sync) & -- DDU Sync Lost/Buffer Overflow Error (bad event, RESET req'd) *an unknowable amount of data has been irrevocably lost
                                          '0' & -- DDU detected Fiber Error (hardware configuration change, RESET req'd) *change of connection status on 1 or more DDU fiber inputs; a hardware problem probably exists
                                          '0' & -- DDU detected DMB or CFEB L1A Match Error (bad event, RESET?) *the DDU L1A event number match failed for 1 or more CSC boards; possible one-time bit error *if error continues for consecutive events then RESET req'd
                                          '0' & -- DDU detected DMB or CFEB CRC Error (bad event, RESET?) *CRC check failed for ADC data on 1 or more CFEBs; possible one-time bit error *if error continues for consecutive events then RESET req'd
                                          '0' & -- DMB Full Flag (status only) 
                                          tts_chmb_critical_arr(14 downto 0) & -- shows which CSCs are in an Error state 
                                          '0' & tts_chmb_warning_arr(14 downto 0); -- shows which CSCs are in a Warning state
                        daq_event_header <= '0';
                        daq_event_trailer <= '0';
                        daq_event_write_en <= '1';
                        spy_fifo_wr_en <= '1';                        
                        
                        -- move to the next state
                        e_word_count <= e_word_count + 1;
                        daq_state <= FED_TRAILER_3;

                    ----==== send the FED trailer 3 ====----
                    elsif (daq_state = FED_TRAILER_3) then

                        -- send the data
                        daq_event_data <= x"a" &
                                          dmb_64bit_misaligned & "00" & (l1afifo_dout(52) and not l1afifo_empty) & 
                                          x"0" & std_logic_vector(e_word_count - 1) &
                                          ddu_crc & -- DDU CRC
                                          x"0" &
                                          tts_critical_error & -- DDU detected Critical Error, irrecoverable (RESET req'd) *OR of all possible "RESET required" cases
                                          '0' & -- DDU detected Single Error (bad event) *OR of all possible "bad event" cases
                                          '0' & -- DDU Single Warning (possible bad event?) *OR of bit55, bit42
                                          (tts_warning or daq_almost_full) & --  DDU FIFO Near Full Warning or DAQ Wait is set (status only) *OR of all possible "Near Full" cases
                                          tts_state &
                                          x"0";
                        daq_event_header <= '0';
                        daq_event_trailer <= '0';
                        daq_event_write_en <= '1';
                        spy_fifo_wr_en <= '1';                        
                        
                        -- move to the next state
                        e_word_count <= e_word_count + 1;
                        daq_state <= AMC13_TRAILER;

                    ----==== send the AMC trailer ====----
                    elsif (daq_state = AMC13_TRAILER) then
                    
                        -- send the AMC trailer data
                        daq_event_data <= x"00000000" & e_l1a_id(7 downto 0) & x"0" & std_logic_vector(e_word_count + 1);
                        daq_event_header <= '0';
                        daq_event_trailer <= '1';
                        daq_event_write_en <= '1';
                        spy_fifo_wr_en <= '0';                        
                        
                        -- go back to DAQ idle state
                        daq_state <= IDLE;
                        
                        -- reset things
                        e_word_count <= (others => '0');
                        e_input_idx <= 0;
                        cnt_sent_events <= cnt_sent_events + 1;
                        dav_timeout_flags <= x"000000";
                        
                    else
                    
                        daq_state <= IDLE;
                        
                    end if;
                    
                end if;

            end if;
        end if;        
    end process;

    --===============================================================================================
    -- this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py (do not edit) 
    --==== Registers begin ==========================================================================

    --==== Registers end ============================================================================

    
end Behavioral;

