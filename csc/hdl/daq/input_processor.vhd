------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    14:00 2016-01-11
-- Module Name:    Input Processor
-- Description:    This module buffers input data from one chamber, builds events, analyses the data for consistency and provides the events to the DAQ module for merging with other chambers and shipping to AMC13      
------------------------------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xpm;
use xpm.vcomponents.all;

use work.common_pkg.all;
use work.csc_pkg.all;
use work.ipbus.all;
use work.board_config_package.all;

entity input_processor is
generic(
    g_INPUT_CLK_FREQ            : integer
);    
port(
    -- Reset
    reset_i                     : in std_logic;

    -- Config
    input_enable_i              : in std_logic; -- shuts off input for this module if 0

    -- FIFOs
    fifo_rd_clk_i               : in std_logic;
    infifo_dout_o               : out std_logic_vector(63 downto 0);
    infifo_rd_en_i              : in std_logic;
    infifo_empty_o              : out std_logic;
    infifo_valid_o              : out std_logic;
    infifo_underflow_o          : out std_logic;
    infifo_data_cnt_o           : out std_logic_vector(13 downto 0);
    evtfifo_dout_o              : out std_logic_vector(59 downto 0);
    evtfifo_rd_en_i             : in std_logic;
    evtfifo_empty_o             : out std_logic;
    evtfifo_valid_o             : out std_logic;
    evtfifo_underflow_o         : out std_logic;
    evtfifo_data_cnt_o          : out std_logic_vector(11 downto 0);

    -- Input data
    input_clk_i                 : in std_logic;
    input_data_link_i           : in t_mgt_16b_rx_data;
    
    -- Status and control
    status_o                    : out t_daq_input_status;
    control_i                   : in t_daq_input_control
);

end input_processor;

architecture input_processor_arch of input_processor is

    --================== CONSTANTS ==================--
    -- TODO: should be moved to a package
    
    constant DMB_IDLE_WORD_DATA     : std_logic_vector(15 downto 0) := x"50bc";
    constant DMB_IDLE_WORD_KCHAR    : std_logic_vector(1 downto 0)  := "01";
    
    -- DDU codes concatenated 4 times -- makes it easy to check all 4 positions
    constant DDU_CODE_LONE_WORD_X4      : std_logic_vector(15 downto 0) := x"8888";
    constant DDU_CODE_DMB_HEAD1_X4      : std_logic_vector(15 downto 0) := x"9999";
    constant DDU_CODE_DMB_HEAD2_X4      : std_logic_vector(15 downto 0) := x"AAAA";
    constant DDU_CODE_SCA_FULL_X4       : std_logic_vector(15 downto 0) := x"BBBB";
    constant DDU_CODE_STATUS_X4         : std_logic_vector(15 downto 0) := x"CCCC";
    constant DDU_CODE_TRIG_MARKER_X4    : std_logic_vector(15 downto 0) := x"DDDD";
    constant DDU_CODE_DMB_TRAIL1_X4     : std_logic_vector(15 downto 0) := x"FFFF";
    constant DDU_CODE_DMB_TRAIL2_X4     : std_logic_vector(15 downto 0) := x"EEEE";

    --================== FUNCTIONS ==================--
    -- TODO: should be moved to a package

    -- given a 64bit word it returns the four top bits of each 16bit word concatenated together
    function get_ddu_code_x4(word64 : in std_logic_vector(63 downto 0)) return std_logic_vector is
    begin
        return word64(63 downto 60) & word64(47 downto 44) & word64(31 downto 28) & word64(15 downto 12);
    end function;

    --================== SIGNALS ==================--

    -- TTS
    signal tts_state                : std_logic_vector(3 downto 0) := "1000";
    signal tts_critical_error       : std_logic := '0'; -- critical error detected - RESYNC/RESET NEEDED
    signal tts_warning              : std_logic := '0'; -- overflow warning - STOP TRIGGERS
    signal tts_out_of_sync          : std_logic := '0'; -- out-of-sync - RESYNC NEEDED
    signal tts_busy                 : std_logic := '0'; -- I'm busy - NO TRIGGERS FOR NOW, PLEASE

    -- Error/warning flags (latched)
    signal err_infifo_full          : std_logic := '0';
    signal err_infifo_near_full     : std_logic := '0';
    signal err_infifo_underflow     : std_logic := '0'; -- Tried to read too many blocks from the input fifo when sending events to the DAQlink (indicates a problem in the vfat block counter)
    signal err_evtfifo_full         : std_logic := '0';
    signal err_evtfifo_near_full    : std_logic := '0';
    signal err_evtfifo_underflow    : std_logic := '0'; -- Tried to read too many events from the event fifo (indicates a problem in the AMC event builder)
    signal err_event_too_big        : std_logic := '0'; -- didn't find DMB trailer in more than 4095 words! (event fifo cannot store a size pointer this big -- crash)
    signal err_64bit_misaligned     : std_logic := '0'; -- this flag is latched if a 64bit misaligned packet has been detected

    -- Input FIFO
    signal infifo_din               : std_logic_vector(63 downto 0) := (others => '0');
    signal infifo_wr_en             : std_logic := '0';
    signal infifo_full              : std_logic := '0';
    signal infifo_prog_full         : std_logic := '0';
    signal infifo_prog_empty        : std_logic := '0';
    signal infifo_prog_empty_wrclk  : std_logic := '0';
    signal infifo_almost_full       : std_logic := '0';
    signal infifo_empty             : std_logic := '0';
    signal infifo_underflow         : std_logic := '0';

    -- Event FIFO
    signal evtfifo_din              : std_logic_vector(59 downto 0) := (others => '0');
    signal evtfifo_wr_en            : std_logic := '0';
    signal evtfifo_full             : std_logic := '0';
    signal evtfifo_prog_full        : std_logic := '0';
    signal evtfifo_prog_empty       : std_logic := '0';
    signal evtfifo_prog_empty_wrclk : std_logic := '0';
    signal evtfifo_almost_full      : std_logic := '0';
    signal evtfifo_empty            : std_logic := '0';
    signal evtfifo_underflow        : std_logic := '0';

    -- Link processor
    signal lp_word_pos              : integer range 0 to 3 := 0; -- position in 64bit word
    signal lp_event_in_progress     : std_logic := '0';
    signal lp_end_event             : std_logic := '0';
    signal lp_64bit_misaligned      : std_logic := '0';
        
    -- Event builder
    signal eb_event_size            : unsigned(11 downto 0) := (others => '0');
    signal eb_event_num             : unsigned(23 downto 0) := x"000001";
    
    signal eb_event_too_big         : std_logic := '0';
    signal eb_64bit_misaligned      : std_logic := '0';

begin

    --================================--
    -- TTS
    --================================--
    
    -- err_event_too_big was removed from the critical error list, since this is effectively just an end-of-event timeout
    tts_critical_error <= err_evtfifo_full or 
                          err_evtfifo_underflow or 
                          err_infifo_full or
                          err_infifo_underflow;
                          
    tts_warning <= err_infifo_near_full or err_evtfifo_near_full;
    
    tts_out_of_sync <= '0'; -- No condition for now for setting OOS at the chamber event builder level (this will be used in AMC event builder)
    
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
        ref_clk_i => input_clk_i,
        reset_i   => reset_i,
        en_i      => err_infifo_near_full,
        count_o   => status_o.infifo_near_full_cnt
    );

    i_evtfifo_near_full_counter : entity work.counter
    generic map(
        g_COUNTER_WIDTH  => 16,
        g_ALLOW_ROLLOVER => FALSE
    )
    port map(
        ref_clk_i => input_clk_i,
        reset_i   => reset_i,
        en_i      => err_evtfifo_near_full,
        count_o   => status_o.evtfifo_near_full_cnt
    );

    --================================--
    -- FIFOs
    --================================--

    i_input_fifo : xpm_fifo_async
        generic map(
            FIFO_MEMORY_TYPE    => "block",
            FIFO_WRITE_DEPTH    => CFG_DAQ_INFIFO_DEPTH,
            RELATED_CLOCKS      => 0,
            WRITE_DATA_WIDTH    => 64,
            READ_MODE           => "fwft",
            FIFO_READ_LATENCY   => 0,
            FULL_RESET_VALUE    => 0,
            USE_ADV_FEATURES    => "1F0A", -- VALID(12) = 1 ; AEMPTY(11) = 1; RD_DATA_CNT(10) = 1; PROG_EMPTY(9) = 1; UNDERFLOW(8) = 1; -- WR_ACK(4) = 0; AFULL(3) = 1; WR_DATA_CNT(2) = 0; PROG_FULL(1) = 1; OVERFLOW(0) = 0
            READ_DATA_WIDTH     => 64,
            CDC_SYNC_STAGES     => 2,
            PROG_FULL_THRESH    => CFG_DAQ_INFIFO_PROG_FULL_SET,
            RD_DATA_COUNT_WIDTH => CFG_DAQ_INFIFO_DATA_CNT_WIDTH,
            PROG_EMPTY_THRESH   => CFG_DAQ_INFIFO_PROG_FULL_RESET,
            DOUT_RESET_VALUE    => "BAAD",
            ECC_MODE            => "no_ecc"
        )
        port map(
            sleep         => '0',
            rst           => reset_i,
            wr_clk        => input_clk_i,
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
        
    i_sync_infifo_prog_empty : entity work.synch generic map(N_STAGES => 3) port map(async_i => infifo_prog_empty, clk_i => input_clk_i, sync_o => infifo_prog_empty_wrclk);
    i_latch_infifo_near_full : entity work.latch port map(
            reset_i => infifo_prog_empty_wrclk,
            clk_i   => input_clk_i,
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
            WRITE_DATA_WIDTH    => 60,
            READ_MODE           => "fwft",
            FIFO_READ_LATENCY   => 0,
            FULL_RESET_VALUE    => 0,
            USE_ADV_FEATURES    => "170A", -- VALID(12) = 1 ; AEMPTY(11) = 0; RD_DATA_CNT(10) = 1; PROG_EMPTY(9) = 1; UNDERFLOW(8) = 1; -- WR_ACK(4) = 0; AFULL(3) = 1; WR_DATA_CNT(2) = 0; PROG_FULL(1) = 1; OVERFLOW(0) = 0
            READ_DATA_WIDTH     => 60,
            CDC_SYNC_STAGES     => 2,
            PROG_FULL_THRESH    => CFG_DAQ_EVTFIFO_PROG_FULL_SET,
            RD_DATA_COUNT_WIDTH => CFG_DAQ_EVTFIFO_DATA_CNT_WIDTH,
            PROG_EMPTY_THRESH   => CFG_DAQ_EVTFIFO_PROG_FULL_RESET,
            DOUT_RESET_VALUE    => "0",
            ECC_MODE            => "no_ecc"
        )
        port map(
            sleep         => '0',
            rst           => reset_i,
            wr_clk        => input_clk_i,
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

    i_sync_evtfifo_prog_empty : entity work.synch generic map(N_STAGES => 3) port map(async_i => evtfifo_prog_empty, clk_i => input_clk_i, sync_o => evtfifo_prog_empty_wrclk);
    i_latch_evtfifo_near_full : entity work.latch port map(
            reset_i => evtfifo_prog_empty_wrclk,
            clk_i   => input_clk_i,
            input_i => evtfifo_prog_full,
            latch_o => err_evtfifo_near_full
        );

    evtfifo_empty_o <= evtfifo_empty;
    evtfifo_underflow_o <= evtfifo_underflow;

    -- Check for underflows
    process(fifo_rd_clk_i)
    begin
        if (rising_edge(fifo_rd_clk_i)) then
            if (reset_i = '1') then
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
        g_CLK_FREQUENCY => std_logic_vector(to_unsigned(g_INPUT_CLK_FREQ, 32)),
        g_COUNTER_WIDTH => 15
    )
    port map(
        clk_i   => input_clk_i,
        reset_i => reset_i,
        en_i    => infifo_wr_en,
        rate_o  => status_o.infifo_wr_rate
    );

    -- EvtFIFO write rate counter
    i_evtfifo_write_rate : entity work.rate_counter
    generic map(
        g_CLK_FREQUENCY => std_logic_vector(to_unsigned(g_INPUT_CLK_FREQ, 32)),
        g_COUNTER_WIDTH => 17
    )
    port map(
        clk_i   => input_clk_i,
        reset_i => reset_i,
        en_i    => evtfifo_wr_en,
        rate_o  => status_o.evtfifo_wr_rate
    );
    
    -- monitor input fifo
    process(input_clk_i)
    begin
        if (rising_edge(input_clk_i)) then
            if (reset_i = '1') then
                err_infifo_full <= '0';
            else
                if (infifo_full = '1') then
                    err_infifo_full <= '1'; -- latch in fifo full error
                end if;                
            end if;
        end if;
    end process;

    --================================--
    -- Link input processor (separates events)
    --================================--
    
    process(input_clk_i)
        variable lp_word64 : std_logic_vector(63 downto 0) := (others => '0');
    begin
        if (rising_edge(input_clk_i)) then

            if ((reset_i = '1') or (input_enable_i = '0')) then
                lp_word_pos <= 0;
                lp_word64 := (others => '0');
                lp_event_in_progress <= '0';
                lp_end_event <= '0';
                infifo_wr_en <= '0';
                infifo_din <= (others => '0');
                lp_64bit_misaligned <= '0';
            else

                -- ignore the idle words (they can also be sneaked in by our MGT RX at any time to correct for clock drift)
                -- also just ignore the DDU code C (will have to check these later for stats and headers, but these are not to be recorded)
                if (not ((input_data_link_i.rxcharisk(1 downto 0) = DMB_IDLE_WORD_KCHAR) and (input_data_link_i.rxdata(15 downto 0) = DMB_IDLE_WORD_DATA))) 
                   and (input_data_link_i.rxdata(15 downto 12) /= x"c") then
                
                    lp_word64 := input_data_link_i.rxdata(15 downto 0) & lp_word64(63 downto 16);
                                        
                    -- wait for start of event
                    if (lp_event_in_progress = '0') then
    
                        lp_64bit_misaligned <= '0';
                        
                        if (get_ddu_code_x4(lp_word64) = DDU_CODE_LONE_WORD_X4) then
                            lp_event_in_progress <= '1';
                            lp_end_event <= '1';
                            lp_word_pos <= 0;
                            infifo_wr_en <= '1';
                            infifo_din <= lp_word64;
                        elsif (get_ddu_code_x4(lp_word64) = DDU_CODE_DMB_HEAD1_X4) then
                            lp_event_in_progress <= '1';
                            lp_end_event <= '0';
                            lp_word_pos <= 0;
                            infifo_wr_en <= '1';
                            infifo_din <= lp_word64;
                        else
                            lp_event_in_progress <= '0';
                            lp_end_event <= '0';
                            lp_word_pos <= 0;
                            infifo_wr_en <= '0';
                            infifo_din <= lp_word64;
                        end if;
                    
                    -- event is in progress
                    else
                        
                        -- terminate the event if end of event is signaled from the previous cycle
                        if (lp_end_event = '1') then
                            lp_event_in_progress <= '0';
                            lp_end_event <= '0';
                            lp_word_pos <= 0;
                            infifo_wr_en <= '0';
                            infifo_din <= lp_word64;
                        -- terminate the event if we see the DMB trailer #2 (note that this might not be 64bit aligned, so take care to fix it and pad with zeroes at the end)
                        elsif (get_ddu_code_x4(lp_word64) = DDU_CODE_DMB_TRAIL2_X4) then
                            lp_event_in_progress <= '1';
                            lp_end_event <= '1';
                            lp_word_pos <= 0;
                            infifo_wr_en <= '1';
                            infifo_din <= std_logic_vector(unsigned(lp_word64) srl ((3 - lp_word_pos) * 16));
                            if (lp_word_pos /= 3) then
                                lp_64bit_misaligned <= '1';
                            end if;
                        -- if the event is too big, just close it here (this is an end-of-event-timeout)
                        elsif (eb_event_too_big = '1') then
                            lp_event_in_progress <= '0';
                            lp_end_event <= '0';
                            lp_word_pos <= 0;
                            infifo_wr_en <= '0';
                            infifo_din <= lp_word64;                            
                        -- otherwise, this event is still in progress, so push it to the fifo every 4 cycles (once we have a complete 64bit word ready)
                        elsif (lp_word_pos = 3) then
                            lp_event_in_progress <= '1';
                            lp_end_event <= '0';
                            lp_word_pos <= 0;
                            infifo_wr_en <= '1';
                            infifo_din <= lp_word64;
                        else
                            lp_event_in_progress <= '1';
                            lp_end_event <= '0';
                            lp_word_pos <= lp_word_pos + 1;
                            infifo_wr_en <= '0';
                            infifo_din <= lp_word64;
                        end if;
    
                    end if;
                    
                elsif (lp_end_event = '1') then
                    lp_event_in_progress <= '0';
                    lp_end_event <= '0';
                    lp_word_pos <= 0;
                    infifo_wr_en <= '0';
                    infifo_din <= lp_word64;
                    lp_word64 := (others => '0');
                else                    
                    lp_event_in_progress <= lp_event_in_progress;
                    lp_end_event <= '0';
                    lp_word_pos <= lp_word_pos;
                    infifo_wr_en <= '0';
                    infifo_din <= lp_word64;
                    lp_word64 := lp_word64;
                end if;
                
            end if;
        end if;
    end process;    
    
    --================================--
    -- Event Builder
    --================================--
    process(input_clk_i)
        variable eb_not_empty_event : std_logic := '0';
    begin
        if (rising_edge(input_clk_i)) then
        
            if (reset_i = '1') then
                evtfifo_din <= (others => '0');
                evtfifo_wr_en <= '0';
                eb_event_num <= (others => '0');
                eb_event_size <= (others => '0');
                eb_event_too_big <= '0';
                eb_64bit_misaligned <= '0';
                err_event_too_big <= '0';
                err_evtfifo_full <= '0';
                err_64bit_misaligned <= '0';                
            else
                
                evtfifo_wr_en <= '0';
                
                -- increment event size if the event is in progress and we see an infifo push
                if ((lp_event_in_progress = '1') and (infifo_wr_en = '1')) then

                    if (eb_event_size /= x"fff") then                    
                        eb_event_size <= eb_event_size + 1;
                    end if;
                    
                    -- complain about the size if our size counter is getting full (Event Processor will terminate the event during the next valid 64bit word)
                    if (std_logic_vector(eb_event_size(11 downto 4)) = x"ff") then
                        eb_event_too_big <= '1';
                        err_event_too_big <= '1';
                    else
                        eb_event_too_big <= '0';
                        err_event_too_big <= err_event_too_big;
                    end if;                
                    
                    if (lp_64bit_misaligned = '1') then
                        eb_64bit_misaligned <= '1';
                        err_64bit_misaligned <= '1';
                    end if;
                    
                -- reset things if event is not in progress
                elsif (lp_event_in_progress = '0') then
                    eb_event_size <= (others => '0');
                    eb_event_too_big <= '0';
                    eb_64bit_misaligned <= '0';
                    err_event_too_big <= err_event_too_big; -- keep this latched in - it will propagate to TTS error, so we just wait for reset
                    err_64bit_misaligned <= err_64bit_misaligned;
                    
                -- just to cover all cases and make life easier for the synthesizer
                else
                    eb_event_size <= eb_event_size;
                    eb_event_too_big <= eb_event_too_big;
                    err_event_too_big <= err_event_too_big;
                    err_64bit_misaligned <= err_64bit_misaligned;
                    eb_64bit_misaligned <= eb_64bit_misaligned;
                end if;
                       
                -- event has just ended         
                if ((eb_event_size /= x"000") and (lp_event_in_progress = '0')) then
                    
                    if (eb_event_size = x"000001") then
                        eb_not_empty_event := '0';
                    else
                        eb_not_empty_event := '1';
                    end if;
                    
                    -- Push to event FIFO
                    if (evtfifo_full = '0') then
                        evtfifo_wr_en <= '1';
                        evtfifo_din <= std_logic_vector(eb_event_num) & 
                                       x"000" & -- DMB BX should go here 
                                       std_logic_vector(eb_event_size) & 
                                       evtfifo_almost_full & 
                                       err_evtfifo_full & 
                                       err_infifo_full & 
                                       err_evtfifo_near_full & 
                                       err_infifo_near_full & 
                                       err_infifo_underflow &
                                       eb_event_too_big &
                                       eb_64bit_misaligned & 
                                       eb_not_empty_event &
                                       '0' & -- unused for now
                                       '0' & -- unused for now
                                       '0';  -- unused for now
                    else
                        err_evtfifo_full <= '1';
                    end if;
                    
                    -- update things for next event
                    eb_event_num <= eb_event_num + 1;
                                        
                end if;   
                
            end if;
        end if;
    end process;

    --================================--
    -- Monitoring & Control
    --================================--

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
    status_o.err_64bit_misaligned       <= err_64bit_misaligned;
    status_o.eb_event_num               <= std_logic_vector(eb_event_num);

end input_processor_arch;

