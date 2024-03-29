----------------------------------------------------------------------------------
-- Company: Texas A&M University
-- Engineer: Evaldas Juska (Evaldas.Juska@cern.ch)
--
-- Create Date:    14:00:00 11-Jan-2016
-- Design Name:    GLIB v2
-- Module Name:    Track Input Processor
-- Project Name:
-- Target Devices: xc6vlx130t-1ff1156
-- Tool versions:  ISE  P.20131013
-- Description:    This module buffers track data from one OH, builds events, analyses the data for consistency and provides the events to the DAQ module for merging with other chambers and shipping to AMC13
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
use work.ipbus.all;
use work.board_config_package.all;

entity track_input_processor is
generic(
    g_NUM_VFATS_PER_OH : integer
);
port(
    -- Reset
    reset_i                     : in std_logic;

    -- Config
    input_enable_i              : in std_logic; -- shuts off input for this module if 0

    -- FIFOs
    fifo_rd_clk_i               : in std_logic;
    infifo_dout_o               : out std_logic_vector(191 downto 0);
    infifo_rd_en_i              : in std_logic;
    infifo_empty_o              : out std_logic;
    infifo_valid_o              : out std_logic;
    infifo_underflow_o          : out std_logic;
    infifo_data_cnt_o           : out std_logic_vector(CFG_DAQ_INFIFO_DATA_CNT_WIDTH - 1 downto 0);
    evtfifo_dout_o              : out std_logic_vector(91 downto 0);
    evtfifo_rd_en_i             : in std_logic;
    evtfifo_empty_o             : out std_logic;
    evtfifo_valid_o             : out std_logic;
    evtfifo_underflow_o         : out std_logic;
    evtfifo_data_cnt_o          : out std_logic_vector(CFG_DAQ_EVTFIFO_DATA_CNT_WIDTH - 1 downto 0);

    -- VFAT data links
    data_clk_i                  : in std_logic;
    data_processor_clk_i        : in std_logic; -- recommended to have a higher frequency than the data_clk_i e.g. 2x higher (which would be 80MHz TTC clk)
    oh_daq_links_i              : in t_vfat_daq_link_arr(23 downto 0);

    -- Status and control
    status_o                    : out t_daq_input_status;
    control_i                   : in t_daq_input_control
);

end track_input_processor;

architecture Behavioral of track_input_processor is

    -- Reset
    signal reset_proc_clk           : std_logic;
    signal reset_rd_clk             : std_logic;
    signal reset_data_clk           : std_logic;

    -- TTS
    signal tts_state                : std_logic_vector(3 downto 0) := "1000";
    signal tts_critical_error       : std_logic := '0'; -- critical error detected - RESYNC/RESET NEEDED
    signal tts_warning              : std_logic := '0'; -- overflow warning - STOP TRIGGERS
    signal tts_out_of_sync          : std_logic := '0'; -- out-of-sync - RESYNC NEEDED
    signal tts_busy                 : std_logic := '0'; -- I'm busy - NO TRIGGERS FOR NOW, PLEASE

    -- Counters
    signal cnt_invalid_crc_vfat_block : unsigned(31 downto 0) := (others => '0');
    signal cnt_invalid_bc_vfat_block  : unsigned(31 downto 0) := (others => '0');

    -- Error/warning flags (latched)
    signal err_infifo_full            : std_logic := '0';
    signal err_infifo_near_full       : std_logic := '0';
    signal err_infifo_underflow       : std_logic := '0'; -- tried to read too many blocks from the input fifo when sending events to the DAQlink (indicates a problem in the vfat block counter)
    signal err_evtfifo_full           : std_logic := '0';
    signal err_evtfifo_near_full      : std_logic := '0';
    signal err_evtfifo_underflow      : std_logic := '0'; -- tried to read too many events from the event fifo (indicates a problem in the AMC event builder)
    signal err_invalid_crc_vfat_block : std_logic := '0'; -- detected at least one VFAT block with an invalid CRC
    signal err_invalid_bc_vfat_block  : std_logic := '0'; -- detected at least one VFAT block with an invalid BC
    signal err_event_too_big          : std_logic := '0'; -- detected an event with too many VFAT blocks (more than 4095 blocks!)
    signal err_event_too_many_vfat    : std_logic := '0'; -- there was an event which had more than g_NUM_VFATS_PER_OH VFAT blocks
    signal err_mixed_vfat_bc          : std_logic := '0'; -- different VFAT BCs found in one event
    signal err_mixed_vfat_ec          : std_logic := '0'; -- different VFAT ECs found in one event

    -- Input data concatenator
    signal inconcat_din             : std_logic_vector(191 downto 0) := (others => '0');
    signal inconcat_bytes           : std_logic_vector(4 downto 0) := "1" & x"8";
    signal inconcat_valid           : std_logic := '0';
    signal inconcat_word_cnt        : unsigned(11 downto 0);
    signal inconcat_word_ovf        : std_logic;
    signal inconcat_buf_empty       : std_logic;

    -- Input FIFO
    signal infifo_din               : std_logic_vector(191 downto 0) := (others => '0');
    signal infifo_wr_en             : std_logic := '0';
    signal infifo_full              : std_logic := '0';
    signal infifo_prog_full         : std_logic := '0';
    signal infifo_prog_empty        : std_logic := '0';
    signal infifo_prog_empty_wrclk  : std_logic := '0';
    signal infifo_almost_full       : std_logic := '0';
    signal infifo_empty             : std_logic := '0';
    signal infifo_underflow         : std_logic := '0';

    -- Event FIFO
    signal evtfifo_din              : std_logic_vector(91 downto 0) := (others => '0');
    signal evtfifo_wr_en            : std_logic := '0';
    signal evtfifo_full             : std_logic := '0';
    signal evtfifo_prog_full        : std_logic := '0';
    signal evtfifo_prog_empty       : std_logic := '0';
    signal evtfifo_prog_empty_wrclk : std_logic := '0';
    signal evtfifo_almost_full      : std_logic := '0';
    signal evtfifo_empty            : std_logic := '0';
    signal evtfifo_underflow        : std_logic := '0';

    -- VFAT input status
    signal vfat_fifo_ovf            : std_logic := '0';
    signal vfat_fifo_unf            : std_logic := '0';

    -- Event processor
    signal ep_vfat_block_data        : std_logic_vector(191 downto 0) := (others => '0');
    signal ep_vfat_block_en          : std_logic := '0';
    signal ep_vfat_word              : integer range 0 to 14 := 14;
    signal ep_zero_packet            : std_logic;
    signal ep_last_ec                : std_logic_vector(7 downto 0) := (others => '0');
    signal ep_last_bc                : std_logic_vector(11 downto 0) := (others => '0');
    signal ep_first_ever_block       : std_logic := '1'; -- it's the first ever event
    signal ep_end_of_event           : std_logic := '0';
    signal ep_event_num              : unsigned(7 downto 0) := x"01"; -- used to cross-check the VFAT EC
    signal ep_last_rx_data           : std_logic_vector(191 downto 0) := (others => '0');
    signal ep_last_rx_data_valid     : std_logic := '0';
    signal ep_last_rx_data_zero      : std_logic := '0';
    signal ep_last_rx_data_suppress  : std_logic := '0';
    signal ep_invalid_crc_vfat_block : std_logic := '0';
    signal ep_invalid_bc_vfat_block  : std_logic := '0';

    -- Event builder
    signal eb_vfat_words_64         : unsigned(11 downto 0) := (others => '0');
    signal eb_vfat_bc               : std_logic_vector(11 downto 0) := (others => '0');
    signal eb_vfat_ec               : std_logic_vector(7 downto 0) := (others => '0');
    signal eb_counters_valid        : std_logic := '0';
    signal eb_event_num             : unsigned(23 downto 0) := x"000001";
    signal eb_zs_flags              : std_logic_vector(23 downto 0) := (others => '0');

    signal eb_invalid_crc_vfat_block : std_logic := '0';
    signal eb_invalid_bc_vfat_block  : std_logic := '0';
    signal eb_event_too_big          : std_logic := '0';
    signal eb_event_too_many_vfat    : std_logic := '0';
    signal eb_mixed_vfat_bc          : std_logic := '0';
    signal eb_mixed_vfat_ec          : std_logic := '0';

    -- Event processor timeout
    signal eb_timer                 : unsigned(23 downto 0) := (others => '0');
    signal eb_timeout_flag          : std_logic := '0';
    signal eb_last_timer            : unsigned(23 downto 0) := (others => '0');
    signal eb_max_timer             : unsigned(23 downto 0) := (others => '0');

begin

    i_sync_reset_proc_clk : entity work.synch generic map(N_STAGES => 3, IS_RESET => true) port map(async_i => reset_i, clk_i => data_processor_clk_i, sync_o => reset_proc_clk);
    i_sync_reset_rd_clk : entity work.synch generic map(N_STAGES => 3, IS_RESET => true) port map(async_i => reset_i, clk_i => fifo_rd_clk_i, sync_o => reset_rd_clk);
    i_sync_reset_data_clk : entity work.synch generic map(N_STAGES => 3, IS_RESET => true) port map(async_i => reset_i, clk_i => data_clk_i, sync_o => reset_data_clk);

    --================================--
    -- TTS
    --================================--

    tts_critical_error <= err_event_too_big or
                          err_evtfifo_full or
                          err_evtfifo_underflow or
                          err_infifo_full or
                          err_infifo_underflow;

    tts_warning <= err_infifo_near_full or err_evtfifo_near_full;

    tts_out_of_sync <= '0'; -- no condition for now for setting OOS at the chamber event builder level (this will be used in AMC event builder)

    tts_busy <= reset_i; -- not used for now except for reset at this level

    tts_state <= x"8" when (input_enable_i = '0') else
                 x"4" when (tts_busy = '1') else
                 x"c" when (tts_critical_error = '1') else
                 x"2" when (tts_out_of_sync = '1') else
                 x"1" when (tts_warning = '1') else
                 x"8";

    --================================--
    -- Counters
    --================================--
    i_infifo_near_full_counter : entity work.counter
    generic map(
        g_COUNTER_WIDTH  => 16,
        g_ALLOW_ROLLOVER => FALSE
    )
    port map(
        ref_clk_i => data_processor_clk_i,
        reset_i   => reset_proc_clk,
        en_i      => err_infifo_near_full,
        count_o   => status_o.infifo_near_full_cnt
    );

    i_evtfifo_near_full_counter : entity work.counter
    generic map(
        g_COUNTER_WIDTH  => 16,
        g_ALLOW_ROLLOVER => FALSE
    )
    port map(
        ref_clk_i => data_processor_clk_i,
        reset_i   => reset_proc_clk,
        en_i      => err_evtfifo_near_full,
        count_o   => status_o.evtfifo_near_full_cnt
    );

    --================================--
    -- FIFOs
    --================================--

    -- input data concatenator
    i_input_concatenator : entity work.data_concatenator
        generic map(
            g_INPUT_BYTES_SIZE      => 5,
            g_FIFO_WORD_SIZE_BYTES  => 24,
            g_FILLER_BIT            => '1'
        )
        port map(
            reset_i          => reset_proc_clk,
            clk_i            => data_processor_clk_i,
            input_data_i     => inconcat_din,
            input_bytes_i    => inconcat_bytes,
            input_valid_i    => inconcat_valid,
            new_event_i      => ep_end_of_event or eb_timeout_flag,
            fifo_din_o       => infifo_din,
            fifo_wr_en_o     => infifo_wr_en,
            event_word_cnt_o => inconcat_word_cnt,
            word_cnt_ovf_o   => inconcat_word_ovf,
            buf_empty_o      => inconcat_buf_empty
        );

    -- Input FIFO
    i_input_fifo : xpm_fifo_async
        generic map(
            FIFO_MEMORY_TYPE    => "block",
            FIFO_WRITE_DEPTH    => CFG_DAQ_INFIFO_DEPTH,
            RELATED_CLOCKS      => 0,
            WRITE_DATA_WIDTH    => 192,
            READ_MODE           => "fwft",
            FIFO_READ_LATENCY   => 0,
            FULL_RESET_VALUE    => 0,
            USE_ADV_FEATURES    => "1F0A", -- VALID(12) = 1 ; AEMPTY(11) = 1; RD_DATA_CNT(10) = 1; PROG_EMPTY(9) = 1; UNDERFLOW(8) = 1; -- WR_ACK(4) = 0; AFULL(3) = 1; WR_DATA_CNT(2) = 0; PROG_FULL(1) = 1; OVERFLOW(0) = 0
            READ_DATA_WIDTH     => 192,
            CDC_SYNC_STAGES     => 2,
            PROG_FULL_THRESH    => CFG_DAQ_INFIFO_PROG_FULL_SET,
            RD_DATA_COUNT_WIDTH => CFG_DAQ_INFIFO_DATA_CNT_WIDTH,
            PROG_EMPTY_THRESH   => CFG_DAQ_INFIFO_PROG_FULL_RESET,
            DOUT_RESET_VALUE    => "BAAD",
            ECC_MODE            => "no_ecc"
        )
        port map(
            sleep         => '0',
            rst           => reset_proc_clk,
            wr_clk        => data_processor_clk_i,
            wr_en         => infifo_wr_en,
            din           => infifo_din,
            full          => infifo_full,
            prog_full     => infifo_prog_full,
            wr_data_count => open,
            overflow      => open,
            wr_rst_busy   => open,
            almost_full   => infifo_almost_full,
            wr_ack        => open,
            rd_clk        => fifo_rd_clk_i,
            rd_en         => infifo_rd_en_i,
            dout          => infifo_dout_o,
            empty         => infifo_empty,
            prog_empty    => infifo_prog_empty,
            rd_data_count => infifo_data_cnt_o,
            underflow     => infifo_underflow,
            rd_rst_busy   => open,
            almost_empty  => open,
            data_valid    => infifo_valid_o,
            injectsbiterr => '0',
            injectdbiterr => '0',
            sbiterr       => open,
            dbiterr       => open
        );

    i_sync_infifo_prog_empty : entity work.synch generic map(N_STAGES => 3) port map(async_i => infifo_prog_empty, clk_i => data_processor_clk_i, sync_o => infifo_prog_empty_wrclk);
    i_latch_infifo_near_full : entity work.latch port map(
            reset_i => infifo_prog_empty_wrclk,
            clk_i   => data_processor_clk_i,
            input_i => infifo_prog_full,
            latch_o => err_infifo_near_full
        );

    infifo_empty_o <= infifo_empty;
    infifo_underflow_o <= infifo_underflow;

    -- Event FIFO
    i_event_fifo : xpm_fifo_async
        generic map(
            FIFO_MEMORY_TYPE    => "block",
            FIFO_WRITE_DEPTH    => CFG_DAQ_EVTFIFO_DEPTH,
            RELATED_CLOCKS      => 0,
            WRITE_DATA_WIDTH    => 92,
            READ_MODE           => "fwft",
            FIFO_READ_LATENCY   => 0,
            FULL_RESET_VALUE    => 0,
            USE_ADV_FEATURES    => "170A", -- VALID(12) = 1 ; AEMPTY(11) = 0; RD_DATA_CNT(10) = 1; PROG_EMPTY(9) = 1; UNDERFLOW(8) = 1; -- WR_ACK(4) = 0; AFULL(3) = 1; WR_DATA_CNT(2) = 0; PROG_FULL(1) = 1; OVERFLOW(0) = 0
            READ_DATA_WIDTH     => 92,
            CDC_SYNC_STAGES     => 2,
            PROG_FULL_THRESH    => CFG_DAQ_EVTFIFO_PROG_FULL_SET,
            RD_DATA_COUNT_WIDTH => CFG_DAQ_EVTFIFO_DATA_CNT_WIDTH,
            PROG_EMPTY_THRESH   => CFG_DAQ_EVTFIFO_PROG_FULL_RESET,
            DOUT_RESET_VALUE    => "0",
            ECC_MODE            => "no_ecc"
        )
        port map(
            sleep         => '0',
            rst           => reset_proc_clk,
            wr_clk        => data_processor_clk_i,
            wr_en         => evtfifo_wr_en,
            din           => evtfifo_din,
            full          => evtfifo_full,
            prog_full     => evtfifo_prog_full,
            wr_data_count => open,
            overflow      => open,
            wr_rst_busy   => open,
            almost_full   => evtfifo_almost_full,
            wr_ack        => open,
            rd_clk        => fifo_rd_clk_i,
            rd_en         => evtfifo_rd_en_i,
            dout          => evtfifo_dout_o,
            empty         => evtfifo_empty,
            prog_empty    => evtfifo_prog_empty,
            rd_data_count => evtfifo_data_cnt_o,
            underflow     => evtfifo_underflow,
            rd_rst_busy   => open,
            almost_empty  => open,
            data_valid    => evtfifo_valid_o,
            injectsbiterr => '0',
            injectdbiterr => '0',
            sbiterr       => open,
            dbiterr       => open
        );

    i_sync_evtfifo_prog_empty : entity work.synch generic map(N_STAGES => 3) port map(async_i => evtfifo_prog_empty, clk_i => data_processor_clk_i, sync_o => evtfifo_prog_empty_wrclk);
    i_latch_evtfifo_near_full : entity work.latch port map(
            reset_i => evtfifo_prog_empty_wrclk,
            clk_i   => data_processor_clk_i,
            input_i => evtfifo_prog_full,
            latch_o => err_evtfifo_near_full
        );

    evtfifo_empty_o <= evtfifo_empty;
    evtfifo_underflow_o <= evtfifo_underflow;

    -- Check for underflows
    process(fifo_rd_clk_i)
    begin
        if (rising_edge(fifo_rd_clk_i)) then
            if (reset_rd_clk = '1') then
                err_infifo_underflow <= '0';
                err_evtfifo_underflow <= '0';
            else
                if (evtfifo_underflow = '1') then
                    err_evtfifo_underflow <= '1';
                end if;
                if (infifo_underflow = '1') then
                    err_infifo_underflow <= '1';
                end if;
            end if;
        end if;
    end process;

    -- InFIFO write rate counter
    i_infifo_write_rate : entity work.rate_counter
    generic map(
        g_CLK_FREQUENCY => std_logic_vector(to_unsigned(80_000_000, 32)),
        g_COUNTER_WIDTH => 15
    )
    port map(
        clk_i   => data_processor_clk_i,
        reset_i => reset_proc_clk,
        en_i    => infifo_wr_en,
        rate_o  => status_o.infifo_wr_rate
    );

    -- EvtFIFO write rate counter
    i_evtfifo_write_rate : entity work.rate_counter
    generic map(
        g_CLK_FREQUENCY => std_logic_vector(to_unsigned(80_000_000, 32)),
        g_COUNTER_WIDTH => 17
    )
    port map(
        clk_i   => data_processor_clk_i,
        reset_i => reset_proc_clk,
        en_i    => evtfifo_wr_en,
        rate_o  => status_o.evtfifo_wr_rate
    );

    --================================--
    -- Read the serialized VFAT data input
    --================================--

    i_vfat_input_serializer: entity work.vfat_input_serializer
        port map(
            reset_i        => reset_i,
            daq_data_clk_i => data_clk_i,
            oh_daq_links_i => oh_daq_links_i,
            rd_clk_i       => data_processor_clk_i,
            data_valid_o   => ep_vfat_block_en,
            data_o         => ep_vfat_block_data,
            zero_packet_o  => ep_zero_packet,
            overflow_o     => vfat_fifo_ovf,
            underflow_o    => vfat_fifo_unf
        );


    --================================--
    -- Input processor
    --================================--

    process(data_processor_clk_i)
        variable rx_data_suppress : std_logic;
        variable boundary_bc      : boolean;
        variable boundary_ec      : boolean;
        variable boundary_ec_next : boolean;
    begin
        if (rising_edge(data_processor_clk_i)) then

            if (reset_proc_clk = '1') then
                ep_last_rx_data            <= (others => '0');
                ep_last_rx_data_valid      <= '0';
                ep_last_rx_data_zero       <= '0';
                ep_last_rx_data_suppress   <= '0';
                err_infifo_full            <= '0';
                inconcat_din               <= (others => '0');
                inconcat_bytes             <= "1" & x"8";
                inconcat_valid             <= '0';
                ep_end_of_event            <= '0';
                err_invalid_crc_vfat_block <= '0';
                cnt_invalid_crc_vfat_block <= (others => '0');
                err_invalid_bc_vfat_block  <= '0';
                cnt_invalid_bc_vfat_block  <= (others => '0');
                ep_invalid_crc_vfat_block  <= '0';
                ep_invalid_bc_vfat_block   <= '0';
                ep_last_ec                 <= (others => '0');
                ep_last_bc                 <= (others => '0');
                ep_first_ever_block        <= '1';
                ep_event_num               <= x"01";
            else

                -- VFAT data suppression
                --   - on valid packets, perform zero-suppression
                --   - on invalid packets, suppress according to user configuration
                rx_data_suppress :=
                    (not ep_vfat_block_data(177) and not ep_vfat_block_data(176) and control_i.eb_zero_supression_en and ep_zero_packet) or
                    ((ep_vfat_block_data(177) or ep_vfat_block_data(176)) and not
                        ((control_i.eb_keep_invalid_bc and ep_vfat_block_data(177)) or
                         (control_i.eb_keep_invalid_crc and ep_vfat_block_data(176))));

                -- fill in last data
                ep_last_rx_data          <= ep_vfat_block_data;
                ep_last_rx_data_valid    <= ep_vfat_block_en;
                ep_last_rx_data_zero     <= ep_zero_packet;
                ep_last_rx_data_suppress <= rx_data_suppress;

                if (eb_timeout_flag = '1') then
                    ep_first_ever_block <= '1';
                    ep_event_num        <= ep_event_num + 1;
                end if;

                if ((ep_vfat_block_en = '1') and (reset_proc_clk = '0')) then

                    -- monitor the input FIFO
                    if (infifo_full = '1') then
                        err_infifo_full <= '1';
                    end if;

                    -- push to the input FIFO if we do not suppress the VFAT block
                    if (rx_data_suppress = '0') then
                        if (control_i.eb_calib_mode = '0') then
                            inconcat_din <= ep_vfat_block_data(191 downto 0);
                            inconcat_valid <= '1';
                            inconcat_bytes <= "1" & x"8";
                        else
                            inconcat_din(7 downto 0) <= ep_vfat_block_data(16 + to_integer(unsigned(control_i.eb_calib_channel))) & ep_vfat_block_data(161 downto 160) & ep_vfat_block_data(188 downto 184);
                            inconcat_din(191 downto 8) <= (others => '0');
                            inconcat_valid <= '1';
                            inconcat_bytes <= "0" & x"1";
                        end if;
                    -- do not push data to the input FIFO otherwise
                    else
                        inconcat_valid <= '0';
                    end if;

                    -- check for invalid VFAT block
                    if (ep_vfat_block_data(176) = '1' or ep_vfat_block_data(177) = '1') then
                        ep_end_of_event <= '0'; -- a invalid block will never be an end of event - just attach it to current event

                        if (ep_vfat_block_data(176) = '1') then
                            ep_invalid_crc_vfat_block  <= '1';
                            err_invalid_crc_vfat_block <= '1';
                            cnt_invalid_crc_vfat_block <= cnt_invalid_crc_vfat_block + 1;
                        else
                            ep_invalid_crc_vfat_block <= '0';
                        end if;

                        if (ep_vfat_block_data(177) = '1') then
                            ep_invalid_bc_vfat_block <= '1';
                            err_invalid_bc_vfat_block <= '1';
                            cnt_invalid_bc_vfat_block <= cnt_invalid_bc_vfat_block + 1;
                        else
                            ep_invalid_bc_vfat_block <= '0';
                        end if;
                    -- valid block
                    else
                        ep_invalid_bc_vfat_block  <= '0';
                        ep_invalid_crc_vfat_block <= '0';

                        ep_last_ec <= ep_vfat_block_data(167 downto 160);
                        ep_last_bc <= ep_vfat_block_data(155 downto 144);

                        if (ep_first_ever_block = '1') then
                            ep_first_ever_block <= '0';
                        end if;

                        boundary_bc      := (ep_last_bc /= ep_vfat_block_data(155 downto 144)) or (control_i.eb_evt_boundary_bc = '0');
                        boundary_ec      := (ep_last_ec /= ep_vfat_block_data(167 downto 160)) or (control_i.eb_evt_boundary_ec = '0');
                        boundary_ec_next := (std_logic_vector(ep_event_num + 1) = ep_vfat_block_data(167 downto 160)) or (control_i.eb_evt_boundary_ec_next = '0');

                        if ((ep_first_ever_block = '0') and (eb_timeout_flag = '0') and boundary_bc and boundary_ec and boundary_ec_next) then
                            ep_end_of_event <= '1';
                            ep_event_num    <= ep_event_num + 1;
                        else
                            ep_end_of_event <= '0';
                        end if;

                    end if;

                -- no data
                else
                    inconcat_valid <= '0';
                end if;

            end if;
        end if;
    end process;

    --================================--
    -- Event Builder
    --================================--
    process(data_processor_clk_i)
    begin
        if (rising_edge(data_processor_clk_i)) then

            if (reset_proc_clk = '1') then
                evtfifo_din <= (others => '0');
                evtfifo_wr_en <= '0';
                eb_invalid_crc_vfat_block <= '0';
                eb_invalid_bc_vfat_block <= '0';
                eb_vfat_words_64 <= (others => '0');
                eb_vfat_bc <= (others => '0');
                eb_vfat_ec <= (others => '0');
                eb_counters_valid <= '0';
                eb_event_num <= x"000001";
                eb_mixed_vfat_bc <= '0';
                err_mixed_vfat_bc <= '0';
                eb_mixed_vfat_ec <= '0';
                err_mixed_vfat_ec <= '0';
                eb_event_too_big <= '0';
                err_event_too_big <= '0';
                eb_event_too_many_vfat <= '0';
                err_event_too_many_vfat <= '0';
                err_evtfifo_full <= '0';
                eb_timer <= (others => '0');
                eb_timeout_flag <= '0';
                eb_zs_flags <= (others => '0');
            else

                if (eb_timer >= unsigned(control_i.eb_timeout_delay)) then
                    eb_timeout_flag <= '1';
                end if;

                -- no data coming, but we are already building an event with valid VFAT block(s), manage the timeout timer
                if ((ep_last_rx_data_valid = '0') and (eb_counters_valid = '1') and (eb_timeout_flag = '0')) then
                    eb_timer <= eb_timer + 1;
                end if;

                -- continuation of the current event - update flags and counters
                if ((ep_last_rx_data_valid = '1') and (ep_end_of_event = '0')) then
                    -- collect the timer stats and reset it along with the timeout flag
                    eb_last_timer <= eb_timer;
                    if (eb_timer > eb_max_timer) then
                        eb_max_timer <= eb_timer;
                    end if;
                    eb_timer <= (others => '0');
                    eb_timeout_flag <= '0';

                    -- do not write to event fifo
                    evtfifo_wr_en <= '0';

                    -- is this block a valid VFAT block?
                    if (ep_invalid_crc_vfat_block = '1') then
                        eb_invalid_crc_vfat_block <= '1';
                    end if;

                    if (ep_invalid_bc_vfat_block = '1') then
                        eb_invalid_bc_vfat_block <= '1';
                    end if;

                    -- increment the word counter if the counter is not full yet and we didn't suppress this data
                    if (eb_vfat_words_64 < x"fff") and (ep_last_rx_data_suppress = '0') then
                        eb_vfat_words_64 <= eb_vfat_words_64 + 3;
                    elsif (eb_vfat_words_64 = x"fff") then
                        eb_event_too_big  <= '1';
                        err_event_too_big <= '1';
                    end if;

                    -- do we have more than g_NUM_VFATS_PER_OH VFAT blocks?
                    if (eb_vfat_words_64 > to_unsigned(3*(g_NUM_VFATS_PER_OH-1), eb_vfat_words_64'length)) then
                        eb_event_too_many_vfat  <= '1';
                        err_event_too_many_vfat <= '1';
                    end if;

                    -- if we don't have yet valid BC and EC, fill them in now (this is the case of first ever vfat block or after a timeout)
                    if (eb_counters_valid = '0' and ep_invalid_crc_vfat_block = '0' and ep_invalid_bc_vfat_block = '0') then
                        eb_vfat_bc        <= ep_last_rx_data(155 downto 144);
                        eb_vfat_ec        <= ep_last_rx_data(167 downto 160);
                        eb_counters_valid <= '1';
                    -- use only valid VFAT blocks
                    elsif (ep_invalid_crc_vfat_block = '0' and ep_invalid_bc_vfat_block = '0') then

                        -- is the current vfat BC different than the previous (in the same event)?
                        if (eb_vfat_bc /= ep_last_rx_data(155 downto 144)) then
                            eb_mixed_vfat_bc  <= '1';
                            err_mixed_vfat_bc <= '1';
                        end if;

                        -- is the current VFAT EC different than the previous (in the same event)?
                        if (eb_vfat_ec /= ep_last_rx_data(167 downto 160)) then
                            eb_mixed_vfat_ec  <= '1';
                            err_mixed_vfat_ec <= '1';
                        end if;

                    end if;

                    -- fill in the zero suppression flags
                    eb_zs_flags(to_integer(unsigned(ep_last_rx_data(188 downto 184)))) <= ep_last_rx_data_suppress and ep_last_rx_data_zero;

                -- end of event - push to event fifo, reset the flags and populate the new event ids (event num, bx, etc)
                elsif (((ep_last_rx_data_valid = '1') and (ep_end_of_event = '1')) or (eb_timeout_flag = '1')) then

                    -- push to event FIFO
                    if (evtfifo_full = '0') then
                        evtfifo_wr_en <= '1';
                        evtfifo_din <= eb_vfat_ec &
                                       eb_zs_flags &
                                       std_logic_vector(eb_event_num) &
                                       eb_vfat_bc &
                                       std_logic_vector(eb_vfat_words_64) &
                                       evtfifo_almost_full &
                                       err_evtfifo_full &
                                       err_infifo_full &
                                       err_evtfifo_near_full &
                                       err_infifo_near_full &
                                       err_infifo_underflow &
                                       eb_event_too_big &
                                       eb_invalid_crc_vfat_block &
                                       eb_event_too_many_vfat &
                                       eb_invalid_bc_vfat_block &
                                       eb_mixed_vfat_bc &
                                       eb_mixed_vfat_ec;
                    else
                        err_evtfifo_full <= '1';
                    end if;

                    -- increment the event number
                    eb_event_num <= eb_event_num + 1;

                    -- we can receive a new VFAT block while closing the previous event
                    -- fill the "unsafe" flags and statuses accordingly
                    if (ep_last_rx_data_valid = '1') then
                        if (ep_last_rx_data_suppress = '0') then
                            eb_vfat_words_64 <= x"003"; -- we already have one VFAT block in the next event (that's the one that marked the end of the previous event)
                        else
                            eb_vfat_words_64 <= x"000"; -- the current VFAT block which belongs to the next event is zero suppressed
                        end if;

                        -- is this block a valid VFAT block? should the BC and EC be used?
                        if (ep_invalid_crc_vfat_block = '0') and (ep_invalid_bc_vfat_block = '0') then
                            eb_counters_valid <= '1';
                            eb_vfat_bc        <= ep_last_rx_data(155 downto 144);
                            eb_vfat_ec        <= ep_last_rx_data(167 downto 160);
                        else
                            eb_counters_valid <= '0';
                            eb_vfat_bc        <= (others => '0');
                            eb_vfat_ec        <= (others => '0');
                        end if;

                        -- is this block a valid VFAT block?
                        if (ep_invalid_crc_vfat_block = '1') then
                            eb_invalid_crc_vfat_block <= '1';
                        else
                            eb_invalid_crc_vfat_block <= '0';
                        end if;

                        if (ep_invalid_bc_vfat_block = '1') then
                            eb_invalid_bc_vfat_block <= '1';
                        else
                            eb_invalid_bc_vfat_block <= '0';
                        end if;
                    else
                        eb_vfat_words_64          <= x"000";
                        eb_counters_valid         <= '0';
                        eb_vfat_bc                <= (others => '0');
                        eb_vfat_ec                <= (others => '0');
                        eb_invalid_crc_vfat_block <= '0';
                        eb_invalid_bc_vfat_block  <= '0';
                    end if;

                    -- reset the "safe" event flags and statuses
                    eb_mixed_vfat_bc       <= '0';
                    eb_mixed_vfat_ec       <= '0';
                    eb_event_too_big       <= '0';
                    eb_event_too_many_vfat <= '0';
                    eb_zs_flags            <= (others => '0');
                    eb_zs_flags(to_integer(unsigned(ep_last_rx_data(188 downto 184)))) <= ep_last_rx_data_valid and ep_last_rx_data_suppress and ep_last_rx_data_zero;

                    -- reset the timeout
                    eb_timeout_flag <= '0';
                    eb_timer <= (others => '0');

                else

                    -- hmm
                    evtfifo_wr_en <= '0';

                end if;

            end if;
        end if;
    end process;

    --================================--
    -- Monitoring & Control
    --================================--

    status_o.vfat_fifo_ovf              <= vfat_fifo_ovf;
    status_o.vfat_fifo_unf              <= vfat_fifo_unf;

    status_o.evtfifo_empty              <= evtfifo_empty;
    status_o.evtfifo_near_full          <= err_evtfifo_near_full;
    status_o.evtfifo_full               <= evtfifo_full;
    status_o.evtfifo_underflow          <= evtfifo_underflow;
    status_o.infifo_empty               <= infifo_empty;
    status_o.infifo_near_full           <= err_infifo_near_full;
    status_o.infifo_full                <= infifo_full;
    status_o.infifo_underflow           <= infifo_underflow;
    status_o.tts_state                  <= tts_state;
    status_o.err_event_too_big          <= err_event_too_big;
    status_o.err_evtfifo_full           <= err_evtfifo_full;
    status_o.err_infifo_underflow       <= err_infifo_underflow;
    status_o.err_infifo_full            <= err_infifo_full;
    status_o.err_invalid_crc_vfat_block <= err_invalid_crc_vfat_block;
    status_o.err_invalid_bc_vfat_block  <= err_invalid_bc_vfat_block;
    status_o.err_event_too_many_vfat    <= err_event_too_many_vfat;
    status_o.err_mixed_vfat_bc          <= err_mixed_vfat_bc;
    status_o.err_mixed_vfat_ec          <= err_mixed_vfat_ec;

    status_o.cnt_invalid_crc_vfat_block <= std_logic_vector(cnt_invalid_crc_vfat_block);
    status_o.cnt_invalid_bc_vfat_block  <= std_logic_vector(cnt_invalid_bc_vfat_block);
    status_o.eb_event_num               <= std_logic_vector(eb_event_num);
    status_o.eb_max_timer               <= std_logic_vector(eb_max_timer);
    status_o.eb_last_timer              <= std_logic_vector(eb_last_timer);

end Behavioral;

