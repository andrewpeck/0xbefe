----------------------------------------------------------------------------------
-- Company: Texas A&M University
-- Engineer: Evaldas Juska (Evaldas.Juska@cern.ch)
-- 
-- Create Date:    14:00:00 11-Jan-2016 
-- Design Name:    GLIB v2
-- Module Name:    Track Input Processor
-- Project Name:   GLIB v2
-- Target Devices: xc6vlx130t-1ff1156
-- Tool versions:  ISE  P.20131013
-- Description:    This module buffers track data from one OH, builds events, analyses the data for consistency and provides the events to the DAQ module for merging with other chambers and shipping to AMC13
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.gem_pkg.all;
use work.ipbus.all;

entity track_input_processor is
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
    infifo_data_cnt_o           : out std_logic_vector(11 downto 0);
    evtfifo_dout_o              : out std_logic_vector(59 downto 0);
    evtfifo_rd_en_i             : in std_logic;
    evtfifo_empty_o             : out std_logic;
    evtfifo_valid_o             : out std_logic;
    evtfifo_underflow_o         : out std_logic;
    evtfifo_data_cnt_o          : out std_logic_vector(11 downto 0);

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

    --================== COMPONENTS ==================--

    component daq_input_fifo is
        port(
            rst           : in  std_logic;
            wr_clk        : in  std_logic;
            rd_clk        : in  std_logic;
            din           : in  std_logic_vector(191 downto 0);
            wr_en         : in  std_logic;
            rd_en         : in  std_logic;
            dout          : out std_logic_vector(191 downto 0);
            full          : out std_logic;
            almost_full   : out std_logic;
            empty         : out std_logic;
            almost_empty  : out std_logic;
            valid         : out std_logic;
            underflow     : out std_logic;
            prog_full     : out std_logic;
            rd_data_count : out std_logic_vector(11 downto 0)
        );
    end component daq_input_fifo;
    
    component daq_event_fifo is
        port(
            rst           : in  std_logic;
            wr_clk        : in  std_logic;
            rd_clk        : in  std_logic;
            din           : in  std_logic_vector(59 downto 0);
            wr_en         : in  std_logic;
            rd_en         : in  std_logic;
            dout          : out std_logic_vector(59 downto 0);
            full          : out std_logic;
            almost_full   : out std_logic;
            empty         : out std_logic;
            valid         : out std_logic;
            underflow     : out std_logic;
            prog_full     : out std_logic;
            rd_data_count : out std_logic_vector(11 downto 0)
        );
    end component daq_event_fifo;
        
    --================== SIGNALS ==================--

    -- Constants (TODO: should be moved to package)
    constant vfat3_header_i         : std_logic_vector(7 downto 0) := x"1E";
    constant vfat3_header_iw        : std_logic_vector(7 downto 0) := x"5E";

    -- TTS
    signal tts_state                : std_logic_vector(3 downto 0) := "1000";
    signal tts_critical_error       : std_logic := '0'; -- critical error detected - RESYNC/RESET NEEDED
    signal tts_warning              : std_logic := '0'; -- overflow warning - STOP TRIGGERS
    signal tts_out_of_sync          : std_logic := '0'; -- out-of-sync - RESYNC NEEDED
    signal tts_busy                 : std_logic := '0'; -- I'm busy - NO TRIGGERS FOR NOW, PLEASE

    -- Counters
    signal cnt_corrupted_vfat       : unsigned(31 downto 0) := (others => '0');

    -- Error/warning flags (latched)
    signal err_infifo_full          : std_logic := '0';
    signal err_infifo_near_full     : std_logic := '0';
    signal err_infifo_underflow     : std_logic := '0'; -- Tried to read too many blocks from the input fifo when sending events to the DAQlink (indicates a problem in the vfat block counter)
    signal err_evtfifo_full         : std_logic := '0';
    signal err_evtfifo_near_full    : std_logic := '0';
    signal err_evtfifo_underflow    : std_logic := '0'; -- Tried to read too many events from the event fifo (indicates a problem in the AMC event builder)
    signal err_corrupted_vfat_data  : std_logic := '0'; -- detected at least one invalid VFAT block
    signal err_event_too_big        : std_logic := '0'; -- detected an event with too many VFAT blocks (more than 4095 blocks!)
    signal err_event_bigger_than_24 : std_logic := '0'; -- there was an event which had more than 24 VFAT blocks
    signal err_vfat_block_too_small : std_logic := '0'; -- didn't get the full 14 VFAT words for some block
    signal err_vfat_block_too_big   : std_logic := '0'; -- got more than 14 VFAT words for one block
    signal err_mixed_vfat_bc        : std_logic := '0'; -- different VFAT BCs found in one event
    signal err_mixed_vfat_ec        : std_logic := '0'; -- different VFAT ECs found in one event
    signal err_mixed_oh_bc          : std_logic := '0'; -- different OH BCs found in one event

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
    signal infifo_almost_full       : std_logic := '0';
    signal infifo_empty             : std_logic := '0';
    signal infifo_underflow         : std_logic := '0';

    -- Event FIFO
    signal evtfifo_din              : std_logic_vector(59 downto 0) := (others => '0');
    signal evtfifo_wr_en            : std_logic := '0';
    signal evtfifo_full             : std_logic := '0';
    signal evtfifo_almost_full      : std_logic := '0';
    signal evtfifo_empty            : std_logic := '0';
    signal evtfifo_underflow        : std_logic := '0';
    
    -- VFAT input status
    signal vfat_fifo_ovf            : std_logic := '0';
    signal vfat_fifo_unf            : std_logic := '0';
    
    -- Event processor
    signal ep_vfat_block_data       : std_logic_vector(191 downto 0) := (others => '0');
    signal ep_vfat_block_en         : std_logic := '0';
    signal ep_vfat_word             : integer range 0 to 14 := 14;
    signal ep_zero_packet           : std_logic;
    signal ep_last_ec               : std_logic_vector(7 downto 0) := (others => '0');
    signal ep_last_bc               : std_logic_vector(11 downto 0) := (others => '0');
    signal ep_first_ever_block      : std_logic := '1'; -- it's the first ever event
    signal ep_end_of_event          : std_logic := '0';
    signal ep_last_rx_data          : std_logic_vector(191 downto 0) := (others => '0');
    signal ep_last_rx_data_valid    : std_logic := '0';
    signal ep_last_rx_data_suppress : std_logic := '0';
    signal ep_invalid_vfat_block    : std_logic := '0';
    
    -- Event builder
    signal eb_vfat_words_64         : unsigned(11 downto 0) := (others => '0');
    signal eb_vfat_bc               : std_logic_vector(11 downto 0) := (others => '0');
    signal eb_oh_bc                 : std_logic_vector(31 downto 0) := (others => '0');
    signal eb_vfat_ec               : std_logic_vector(7 downto 0) := (others => '0');
    signal eb_counters_valid        : std_logic := '0';
    signal eb_event_num             : unsigned(23 downto 0) := x"000001";
    signal eb_event_num_short       : unsigned(7 downto 0) := x"00"; -- used to double check with VFAT EC
    
    signal eb_invalid_vfat_block    : std_logic := '0';
    signal eb_event_too_big         : std_logic := '0';
    signal eb_event_bigger_than_24  : std_logic := '0';
    signal eb_mixed_vfat_bc         : std_logic := '0';
    signal eb_mixed_vfat_ec         : std_logic := '0';
    signal eb_mixed_oh_bc           : std_logic := '0';

    -- Event processor timeout
    signal eb_timer                 : unsigned(23 downto 0) := (others => '0');
    signal eb_timeout_delay         : unsigned(23 downto 0) := x"03d090"; -- 10ms (very large)
    signal eb_timeout_flag          : std_logic := '0';
    signal eb_last_timer            : unsigned(23 downto 0) := (others => '0');
    signal eb_max_timer             : unsigned(23 downto 0) := (others => '0');

    -- Debug flags for ChipScope
--    attribute MARK_DEBUG : string;
--    attribute MARK_DEBUG of tk_data_link_i              : signal is "TRUE";
--    attribute MARK_DEBUG of eb_timer                    : signal is "TRUE";
--    attribute MARK_DEBUG of eb_last_timer               : signal is "TRUE";
--    attribute MARK_DEBUG of eb_max_timer                : signal is "TRUE";
--    attribute MARK_DEBUG of eb_timeout_flag             : signal is "TRUE";
--    attribute MARK_DEBUG of eb_invalid_vfat_block       : signal is "TRUE";
--    attribute MARK_DEBUG of eb_vfat_words_64            : signal is "TRUE";
--    attribute MARK_DEBUG of eb_vfat_bc                  : signal is "TRUE";
--    attribute MARK_DEBUG of eb_oh_bc                    : signal is "TRUE";
--    attribute MARK_DEBUG of eb_vfat_ec                  : signal is "TRUE";
--    attribute MARK_DEBUG of eb_counters_valid           : signal is "TRUE";
--    attribute MARK_DEBUG of eb_event_num_short          : signal is "TRUE";
--    attribute MARK_DEBUG of ep_vfat_block_en            : signal is "TRUE";
--    attribute MARK_DEBUG of ep_end_of_event             : signal is "TRUE";
--    attribute MARK_DEBUG of ep_last_rx_data_valid       : signal is "TRUE";
--    attribute MARK_DEBUG of tts_state                   : signal is "TRUE";
--    
--    attribute MARK_DEBUG of infifo_din                  : signal is "TRUE";
--    attribute MARK_DEBUG of infifo_wr_en                : signal is "TRUE";
--    attribute MARK_DEBUG of infifo_empty                : signal is "TRUE";
--
--    attribute MARK_DEBUG of evtfifo_din                 : signal is "TRUE";
--    attribute MARK_DEBUG of evtfifo_wr_en               : signal is "TRUE";
--    attribute MARK_DEBUG of evtfifo_empty               : signal is "TRUE";
--    
--    attribute MARK_DEBUG of fifo_rd_clk_i               : signal is "TRUE";
--    attribute MARK_DEBUG of infifo_rd_en_i              : signal is "TRUE";
--    attribute MARK_DEBUG of evtfifo_rd_en_i             : signal is "TRUE";

begin

    --================================--
    -- TTS
    --================================--
    
    tts_critical_error <= err_event_too_big or 
                          err_evtfifo_full or 
                          err_evtfifo_underflow or 
                          err_infifo_full or
                          err_infifo_underflow;
--                          vfat_fifo_ovf or
--                          vfat_fifo_unf;
                          
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
        ref_clk_i => data_processor_clk_i,
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
        ref_clk_i => data_processor_clk_i,
        reset_i   => reset_i,
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
            reset_i          => reset_i,
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
    i_input_fifo : component daq_input_fifo
    port map(
        rst           => reset_i,
        wr_clk        => data_processor_clk_i,
        rd_clk        => fifo_rd_clk_i,
        din           => infifo_din,
        wr_en         => infifo_wr_en,
        rd_en         => infifo_rd_en_i,
        dout          => infifo_dout_o,
        full          => infifo_full,
        almost_full   => infifo_almost_full,
        empty         => infifo_empty,
        almost_empty  => open,
        valid         => infifo_valid_o,
        underflow     => infifo_underflow,
        prog_full     => err_infifo_near_full,
        rd_data_count => infifo_data_cnt_o
    );

    infifo_empty_o <= infifo_empty;
    infifo_underflow_o <= infifo_underflow;

    -- Event FIFO
    i_event_fifo : component daq_event_fifo
    port map(
        rst           => reset_i,
        wr_clk        => data_processor_clk_i,
        rd_clk        => fifo_rd_clk_i,
        din           => evtfifo_din,
        wr_en         => evtfifo_wr_en,
        rd_en         => evtfifo_rd_en_i,
        dout          => evtfifo_dout_o,
        full          => evtfifo_full,
        almost_full   => evtfifo_almost_full,
        empty         => evtfifo_empty,
        valid         => evtfifo_valid_o,
        underflow     => evtfifo_underflow,
        prog_full     => err_evtfifo_near_full,
        rd_data_count => evtfifo_data_cnt_o
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
        g_CLK_FREQUENCY => std_logic_vector(to_unsigned(160_000_000, 32)),
        g_COUNTER_WIDTH => 15
    )
    port map(
        clk_i   => data_processor_clk_i,
        reset_i => reset_i,
        en_i    => infifo_wr_en,
        rate_o  => status_o.infifo_wr_rate
    );

    -- EvtFIFO write rate counter
    i_evtfifo_write_rate : entity work.rate_counter
    generic map(
        g_CLK_FREQUENCY => std_logic_vector(to_unsigned(160_000_000, 32)),
        g_COUNTER_WIDTH => 17
    )
    port map(
        clk_i   => data_processor_clk_i,
        reset_i => reset_i,
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
            crc_err_o      => open,
            zero_packet_o  => ep_zero_packet,
            overflow_o     => vfat_fifo_ovf,
            underflow_o    => vfat_fifo_unf
        );

    err_vfat_block_too_big <= '0';
    err_vfat_block_too_small <= '0';
    

    --================================--
    -- Input processor
    --================================--
    
    process(data_processor_clk_i)
    begin
        if (rising_edge(data_processor_clk_i)) then

            if (reset_i = '1') then
                ep_last_rx_data <= (others => '0');
                ep_last_rx_data_valid <= '0';
                err_infifo_full <= '0';
                inconcat_din <= (others => '0');
                inconcat_bytes <= "1" & x"8";
                inconcat_valid <= '0';
                ep_end_of_event <= '0';
                err_corrupted_vfat_data <= '0';
                cnt_corrupted_vfat <= (others => '0');
                ep_invalid_vfat_block <= '0';
                ep_last_ec <= (others => '0');
                ep_last_bc <= (others => '0');
                ep_first_ever_block <= '1';
                ep_last_rx_data_suppress <= '0';
            else

                -- fill in last data
                ep_last_rx_data <= ep_vfat_block_data; -- TOTO Optimization: instead of duplicating all the data you could only retain the OH 32bits, others you can get form infifo_din
                ep_last_rx_data_valid <= ep_vfat_block_en;
                ep_last_rx_data_suppress <= ep_zero_packet and control_i.eb_zero_supression_en;
            
                if (eb_timeout_flag = '1') then
                    ep_first_ever_block <= '1';
                end if;
                
                if ((ep_vfat_block_en = '1') and (reset_i = '0')) then
                
                    -- monitor the input FIFO
                    if (infifo_full = '1') then
                        err_infifo_full <= '1';
                    end if;
                    
                    -- push to input FIFO if it's not full and we don't zero suppress it
                    if (ep_zero_packet = '0' or control_i.eb_zero_supression_en = '0') then
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
                    end if;
                    
                    -- check the header and the crc error flag. invalid vfat block? if yes, then just attach it to the current event
                    if (((ep_vfat_block_data(175 downto 168) /= vfat3_header_i) and (ep_vfat_block_data(175 downto 168) /= vfat3_header_iw)) or (ep_vfat_block_data(176) = '1')) then
                        ep_invalid_vfat_block <= '1';
                        ep_end_of_event <= '0'; -- a corrupt block will never be an end of event - just attach it to current event
                        err_corrupted_vfat_data <= '1';
                        cnt_corrupted_vfat <= cnt_corrupted_vfat + 1;
                    else -- valid block
                        ep_invalid_vfat_block <= '0';
                        ep_last_ec <= ep_vfat_block_data(167 downto 160);
                        ep_last_bc <= ep_vfat_block_data(155 downto 144);
                        
                        if (ep_first_ever_block = '1') then
                            ep_first_ever_block <= '0';
                        end if;
                        
--                        if ((ep_first_ever_block = '0') and (ep_last_ec /= ep_vfat_block_data(171 downto 164))) then
-- for now checking for end of event using BC, but later should use an L1A counter or OH orbit counter + OH BC (on VFAT2 EC is reset with BC0, so we can't use that for now)
                        if ((ep_first_ever_block = '0') and (eb_timeout_flag = '0') and (ep_last_bc /= ep_vfat_block_data(155 downto 144))) then
                            ep_end_of_event <= '1';
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
        
            if (reset_i = '1') then
                evtfifo_din <= (others => '0');
                evtfifo_wr_en <= '0';
                eb_invalid_vfat_block <= '0';
                eb_vfat_words_64 <= (others => '0');
                eb_vfat_bc <= (others => '0');
                eb_oh_bc <= (others => '0');
                eb_vfat_ec <= (others => '0');
                eb_counters_valid <= '0';
                eb_event_num <= (others => '0');
                eb_event_num_short <= (others => '0');
                eb_mixed_vfat_bc <= '0';
                err_mixed_vfat_bc <= '0';
                eb_mixed_vfat_ec <= '0';
                err_mixed_vfat_ec <= '0';
                eb_mixed_oh_bc <= '0';
                err_mixed_oh_bc <= '0';
                eb_event_too_big <= '0';
                err_event_too_big <= '0';
                eb_event_bigger_than_24 <= '0';
                err_event_bigger_than_24 <= '0';
                err_evtfifo_full <= '0';
                eb_timer <= (others => '0');
                eb_timeout_flag <= '0';
            else
                
                if (eb_timer >= eb_timeout_delay) then
                    eb_timeout_flag <= '1';                   
                end if;
                
                -- No data coming, but we do have data in the buffer, manage the timeout timer
                if ((ep_last_rx_data_valid = '0') and (eb_vfat_words_64 /= x"000") and (eb_timeout_flag = '0')) then
                    eb_timer <= eb_timer + 1;
                end if;
                
                -- Continuation of the current event - update flags and counters
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
                    if (ep_invalid_vfat_block = '1') then
                        eb_invalid_vfat_block <= '1';
                    end if;
                    
                    -- increment the word counter if the counter is not full yet and we didn't zero suppress this data
                    if (eb_vfat_words_64 < x"fff") and (ep_last_rx_data_suppress = '0') then
                        eb_vfat_words_64 <= eb_vfat_words_64 + 3;
                    elsif (eb_vfat_words_64 = x"fff") then
                        eb_event_too_big <= '1';
                        err_event_too_big <= '1';
                    end if;
                    
                    -- do we have more than 24 VFAT blocks?
                    if (eb_vfat_words_64 > x"45") then
                        eb_event_bigger_than_24 <= '1';
                        err_event_bigger_than_24 <= '1';
                    end if;
                          
                    -- if we don't have valid bc, fill them in now (this is the case of first ever vfat block or after a timeout)
                    if (eb_counters_valid = '0') then
                        eb_vfat_bc <= ep_last_rx_data(155 downto 144);
--                        eb_oh_bc <= ep_last_rx_data(223 downto 192);
                        eb_vfat_ec <= ep_last_rx_data(167 downto 160);
                        eb_counters_valid <= '1';
                    else -- we do have a valid bc
                        
                    -- is the current vfat bc different than the previous (in the same event)
                    if (eb_vfat_bc /= ep_last_rx_data(155 downto 144)) then
                        eb_mixed_vfat_bc <= '1';
                        err_mixed_vfat_bc <= '1';
                    end if;
                    
                    -- is the current VFAT ec different than the previous (in the same event)
                    if (eb_vfat_ec /= ep_last_rx_data(167 downto 160)) then
                        eb_mixed_vfat_ec <= '1';
                        err_mixed_vfat_ec <= '1';
                    end if;
                        
                    end if;
                    
                -- End of event - push to event fifo, reset the flags and populate the new event ids (event num, bx, etc)
                elsif (((ep_last_rx_data_valid = '1') and (ep_end_of_event = '1')) or (eb_timeout_flag = '1')) then
                
                    -- Push to event FIFO
                    if (evtfifo_full = '0') then
                        evtfifo_wr_en <= '1';
                        evtfifo_din <= std_logic_vector(eb_event_num) & 
                                       eb_vfat_bc & 
                                       std_logic_vector(eb_vfat_words_64) & 
                                       evtfifo_almost_full & 
                                       err_evtfifo_full & 
                                       err_infifo_full & 
                                       err_evtfifo_near_full & 
                                       err_infifo_near_full & 
                                       err_infifo_underflow &
                                       eb_event_too_big &
                                       eb_invalid_vfat_block & 
                                       eb_event_bigger_than_24 &
                                       eb_mixed_oh_bc & 
                                       eb_mixed_vfat_bc & 
                                       eb_mixed_vfat_ec;
                    else
                        err_evtfifo_full <= '1';
                    end if;

                    if (ep_last_rx_data_valid = '1') then
                        eb_vfat_bc <= ep_last_rx_data(155 downto 144);
--                        eb_oh_bc <= ep_last_rx_data(223 downto 192);
                        eb_vfat_ec <= ep_last_rx_data(167 downto 160);
                        eb_counters_valid <= '1';
                        if (ep_last_rx_data_suppress = '0') then
                            eb_vfat_words_64 <= x"003"; -- we already have one VFAT block in the next event (that's the one that marked the end of the previous event)
                        else
                            eb_vfat_words_64 <= x"000"; -- the current VFAT block which belongs to the next event is zero suppressed
                        end if;
                    else
                        eb_counters_valid <= '0';
                        eb_vfat_words_64 <= x"000"; -- no data yet after timeout
                    end if;
                    
                    -- Increment the event number, set bx
                    eb_event_num <= eb_event_num + 1;
                    eb_event_num_short <= eb_event_num_short + 1;
                    
                    -- reset event flags
                    eb_invalid_vfat_block <= '0';
                    eb_mixed_vfat_bc <= '0';
                    eb_mixed_vfat_ec <= '0';
                    eb_mixed_oh_bc <= '0';
                    eb_event_too_big <= '0';
                    eb_event_bigger_than_24 <= '0';
                    
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
    status_o.err_corrupted_vfat_data    <= err_corrupted_vfat_data;
    status_o.err_vfat_block_too_big     <= err_vfat_block_too_big;
    status_o.err_vfat_block_too_small   <= err_vfat_block_too_small;
    status_o.err_event_bigger_than_24   <= err_event_bigger_than_24;
    status_o.err_mixed_oh_bc            <= err_mixed_oh_bc;
    status_o.err_mixed_vfat_bc          <= err_mixed_vfat_bc;
    status_o.err_mixed_vfat_ec          <= err_mixed_vfat_ec;

    status_o.cnt_corrupted_vfat         <= std_logic_vector(cnt_corrupted_vfat);
    status_o.eb_event_num               <= std_logic_vector(eb_event_num);
    status_o.eb_max_timer               <= std_logic_vector(eb_max_timer);
    status_o.eb_last_timer              <= std_logic_vector(eb_last_timer);

    eb_timeout_delay <= unsigned(control_i.eb_timeout_delay);

end Behavioral;

