------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company:
-- Engineer: Laurent Pétré (laurent.petre@cern.ch)
--
-- Create Date: 2022-09-05
-- Module Name: ten_gbe_tx_data_formatter
-- Description: This module is reading event data from an external FWFT FIFO and constructs Ethernet packets.
------------------------------------------------------------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

use work.common_pkg.all;
use work.board_config_package.all;

entity ten_gbe_tx_data_formatter is
    generic (
        g_MAX_EVT_WORDS     : integer := 2048 -- maximum event size in 64 bits words (nothing really gets done when this size is reached, but an error is asserted on the output port)
    );
    port (
        clk_i               : in  std_logic;
        reset_i             : in  std_logic;

        -- Event input
        event_valid_i       : in  std_logic;
        event_data_i        : in  std_logic_vector(63 downto 0);
        event_end_i         : in  std_logic;
        event_rden_o        : out std_logic;

        -- Packet output
        packet_valid_o      : out std_logic;
        packet_data_o       : out std_logic_vector(63 downto 0);
        packet_end_o        : out std_logic;
        packet_rden_i       : in  std_logic;

        -- Config
        dest_mac_i          : in  std_logic_vector(47 downto 0);
        source_mac_i        : in  std_logic_vector(47 downto 0);
        ether_type_i        : in  std_logic_vector(15 downto 0);
        min_payload_words_i : in  std_logic_vector(13 downto 0); -- minimum payload size in 16 bit words
        max_payload_words_i : in  std_logic_vector(13 downto 0); -- max payload size in 16 bit words, excluding the header and trailer

        -- Status
        evt_cnt_o           : out std_logic_vector(31 downto 0); -- event counter
        err_event_too_big_o : out std_logic -- this is asserted if an event exceeding g_MAX_EVT_WORDS was seen since last reset
    );
end ten_gbe_tx_data_formatter;

architecture ten_gbe_tx_data_formatter_arch of ten_gbe_tx_data_formatter is

    -- wiring
    signal reset                : std_logic;

    signal dest_mac             : std_logic_vector(47 downto 0);
    signal source_mac           : std_logic_vector(47 downto 0);
    signal ether_type           : std_logic_vector(15 downto 0);

    signal event_rden           : std_logic := '0';

    -- FSM
    type t_state is (HEADER1, HEADER2, PAYLOAD, FILLER, TRAILER);

    signal state                : t_state := HEADER1;
    signal word_idx             : integer range 0 to 16383 := 0; -- 16 bits words!

    -- event status
    signal evt_word_cnt         : unsigned(15 downto 0) := (others => '0');
    signal err_evt_too_big      : std_logic := '0';

    signal evt_cnt              : unsigned(31 downto 0) := (others => '0');
    signal evt_pkt_payload_size : unsigned(11 downto 0) := (others => '0');
    signal evt_pkt_cnt          : unsigned(3 downto 0) := (others => '0');
    signal evt_pkt_first        : std_logic := '1';
    signal evt_pkt_last         : std_logic := '0';

    -- output FIFO
    signal read_end             : std_logic;
    signal write_end            : std_logic;
    signal ends_in_packet_fifo  : unsigned(CFG_SPY_PACKETFIFO_DATA_CNT_WIDTH-1 downto 0) := (others => '0'); -- keeps track of the number of ends in the FIFO (i.e. number of complete packets)

    -- output FIFO -- write
    signal packet_fifo_full     : std_logic;
    signal packet_fifo_data     : std_logic_vector(63 downto 0) := (others => '0');
    signal packet_fifo_end      : std_logic := '0';
    signal packet_fifo_wren     : std_logic := '0';

    -- output FIFO -- read
    signal packet_empty         : std_logic;
    signal packet_end           : std_logic;

begin

    -- wiring
    i_reset_sync : entity work.synch
        generic  map(
            N_STAGES => 4,
            IS_RESET => true
        )
        port map(
            async_i => reset_i,
            clk_i   => clk_i,
            sync_o  => reset
        );

    dest_mac   <= dest_mac_i(39 downto 32) & dest_mac_i(47 downto 40) & dest_mac_i(23 downto 16) & dest_mac_i(31 downto 24) & dest_mac_i(7 downto 0) & dest_mac_i(15 downto 8);
    source_mac <= source_mac_i(39 downto 32) & source_mac_i(47 downto 40) & source_mac_i(23 downto 16) & source_mac_i(31 downto 24) & source_mac_i(7 downto 0) & source_mac_i(15 downto 8);
    ether_type <= ether_type_i(7 downto 0) & ether_type_i(15 downto 8);

    event_rden_o <= event_rden and event_valid_i and not packet_fifo_full;

    -- packet FSM
    process(clk_i)
    begin
        if (rising_edge(clk_i)) then
            if (reset = '1') then
                packet_fifo_data <= (others => '0');
                packet_fifo_end  <= '0';
                packet_fifo_wren <= '0';
                event_rden       <= '0';
                state            <= HEADER1;
                word_idx         <= 0;
            elsif (packet_fifo_full = '0') then
                case state is

                    --=== Send the first header (destination MAC, and beginning of the source MAC) ===--
                    when HEADER1 =>

                        packet_fifo_wren <= '0';
                        event_rden       <= '0';
                        state            <= HEADER1;
                        word_idx         <= 0;

                        if (event_valid_i = '1') then
                            packet_fifo_data <= source_mac(15 downto 0) & dest_mac;
                            packet_fifo_end  <= '0';
                            packet_fifo_wren <= '1';
                            state            <= HEADER2;
                        end if;

                    --=== Send the first header (end of the source MAC, EtherType, and GEM header) ===--
                    when HEADER2 =>

                        packet_fifo_data <= evt_pkt_first & "000" & std_logic_vector(evt_pkt_cnt) & std_logic_vector(evt_cnt(7 downto 0)) &
                                            ether_type & source_mac(47 downto 16);
                        packet_fifo_end  <= '0';
                        packet_fifo_wren <= '1';
                        event_rden       <= '1';
                        state            <= PAYLOAD;
                        word_idx         <= 0;

                    --=== Send the payload ===--
                    when PAYLOAD =>

                        state <= PAYLOAD;

                        -- there is data in the FIFO
                        if (event_valid_i = '1') then
                            event_rden <= '1';
                        else
                            event_rden <= '0';
                        end if;

                        -- we got an updated event
                        if (event_rden = '1') and (event_valid_i = '1') then
                            packet_fifo_data <= event_data_i;
                            packet_fifo_end  <= '0';
                            packet_fifo_wren <= '1';
                            word_idx         <= word_idx + 4;

                            -- end of packet (either due to end of event detection or a packet size limit)
                            if (event_end_i = '1') or (word_idx = to_integer(unsigned(max_payload_words_i)) - 7) then
                                event_rden <= '0';

                                if (word_idx < to_integer(unsigned(min_payload_words_i)) - 4) then
                                    state <= FILLER;
                                else
                                    state <= TRAILER;
                                end if;
                            end if;
                        else
                            packet_fifo_wren <= '0';
                        end if;

                    --=== Send filler words to satisfy the minimum packet length requirement ===--
                    when FILLER =>

                        packet_fifo_data <= (others => '1');
                        packet_fifo_end  <= '0';
                        packet_fifo_wren <= '1';
                        event_rden       <= '0';
                        word_idx         <= word_idx + 4;

                        if (word_idx >= to_integer(unsigned(min_payload_words_i)) - 4) then
                            state <= TRAILER;
                        end if;

                    --=== Send the trailer ===--
                    when TRAILER =>

                        -- TODO: Use the 48-bits of filler for DAQ data

                        packet_fifo_data <= std_logic_vector(evt_pkt_payload_size) & "000" & evt_pkt_last & x"ffffffffffff";
                        packet_fifo_end  <= '1';
                        packet_fifo_wren <= '1';
                        event_rden       <= '0';
                        state            <= HEADER1;
                        word_idx         <= 0;

                    --=== For completeness ===--
                    when others =>
                        packet_fifo_data <= (others => '0');
                        packet_fifo_end  <= '0';
                        packet_fifo_wren <= '0';
                        event_rden       <= '0';
                        state            <= HEADER1;
                        word_idx         <= 0;

                end case;
            end if;
        end if;
    end process;

    -- event count and size check
    process(clk_i)
    begin
        if (rising_edge(clk_i)) then
            if (reset = '1') then
                evt_word_cnt         <= (others => '0');
                err_evt_too_big      <= '0';
                evt_pkt_first        <= '1';
                evt_pkt_last         <= '0';
                evt_pkt_payload_size <= (others => '0');
                evt_pkt_cnt          <= (others => '0');
                evt_cnt              <= (others => '0');
            elsif (packet_fifo_full = '0') then
                -- got a new word
                if (state = PAYLOAD) and (event_rden = '1') and (event_valid_i = '1') then
                    evt_pkt_first        <= '0';
                    evt_pkt_payload_size <= evt_pkt_payload_size + 4;

                    -- end of event
                    if (event_end_i = '1') then
                        evt_word_cnt <= (others => '0');
                        evt_pkt_last <= '1';
                    else
                        evt_word_cnt <= evt_word_cnt + 1;
                    end if;

                    -- event size check
                    if (evt_word_cnt > to_unsigned(g_MAX_EVT_WORDS, 16)) then
                        err_evt_too_big <= '1';
                    end if;
                -- update per-packet metadata
                elsif (state = TRAILER) then
                    evt_pkt_first        <= evt_pkt_last;
                    evt_pkt_last         <= '0';
                    evt_pkt_payload_size <= (others => '0');

                    -- end of event
                    if (evt_pkt_last = '1') then
                        evt_pkt_cnt <= (others => '0');
                        evt_cnt     <= evt_cnt + 1;
                    else
                        evt_pkt_cnt <= evt_pkt_cnt + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    evt_cnt_o           <= std_logic_vector(evt_cnt);
    err_event_too_big_o <= err_evt_too_big;

    -- output FIFO
    i_pkt_fifo : xpm_fifo_sync
        generic map(
            FIFO_MEMORY_TYPE    => "block",
            FIFO_WRITE_DEPTH    => 1024,
            WRITE_DATA_WIDTH    => 65,
            READ_MODE           => "fwft",
            FIFO_READ_LATENCY   => 0,
            FULL_RESET_VALUE    => 1,
            USE_ADV_FEATURES    => "0A03", -- VALID(12) = 0 ; AEMPTY(11) = 1; RD_DATA_CNT(10) = 0; PROG_EMPTY(9) = 1; UNDERFLOW(8) = 1; -- WR_ACK(4) = 0; AFULL(3) = 0; WR_DATA_CNT(2) = 0; PROG_FULL(1) = 1; OVERFLOW(0) = 1
            READ_DATA_WIDTH     => 65,
            DOUT_RESET_VALUE    => "0",
            ECC_MODE            => "no_ecc"
        )
        port map(
            sleep              => '0',
            rst                => reset,
            wr_clk             => clk_i,
            wr_en              => packet_fifo_wren and not packet_fifo_full,
            din                => packet_fifo_end & packet_fifo_data,
            full               => packet_fifo_full,
            prog_full          => open,
            wr_data_count      => open,
            overflow           => open,
            wr_rst_busy        => open,
            almost_full        => open,
            wr_ack             => open,
            rd_en              => packet_rden_i,
            dout(64)           => packet_end,
            dout(63 downto 0)  => packet_data_o,
            empty              => packet_empty,
            prog_empty         => open,
            rd_data_count      => open, 
            underflow          => open,
            rd_rst_busy        => open,
            almost_empty       => open, 
            data_valid         => open,
            injectsbiterr      => '0',
            injectdbiterr      => '0',
            sbiterr            => open, 
            dbiterr            => open 
        );

        read_end  <= packet_end and packet_rden_i;
        write_end <= packet_fifo_end and packet_fifo_wren and not packet_fifo_full;

        packet_valid_o <= '1' when (packet_empty = '0' and ends_in_packet_fifo /= 0) else '0';
        packet_end_o   <= packet_end;

        process(clk_i)
        begin
            if (rising_edge(clk_i)) then
                if (reset = '1') then
                    ends_in_packet_fifo <= (others => '0');
                else
                    if (read_end = '1' and write_end = '1') then
                        -- finished sending and writing a packet at the same moment
                        ends_in_packet_fifo <= ends_in_packet_fifo;
                    elsif (read_end = '1') then
                        -- finished sending a packet
                        ends_in_packet_fifo <= ends_in_packet_fifo - 1;
                    elsif (write_end = '1') then
                        -- finished writing a packet
                        ends_in_packet_fifo <= ends_in_packet_fifo + 1;
                    else
                        ends_in_packet_fifo <= ends_in_packet_fifo;
                    end if;
                end if;
            end if;
        end process;

end ten_gbe_tx_data_formatter_arch;
