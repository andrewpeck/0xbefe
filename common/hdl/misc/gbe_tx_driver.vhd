------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    01:33:00 2018-10-04
-- Module Name:    GBE_TX_DRIVER
-- Description:    This module is reading event data from an external FWFT FIFO and constructs ethernet packets to be sent out of the 1.25Gb/s GbE port 
------------------------------------------------------------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

use work.common_pkg.all;

entity gbe_tx_driver is
    generic (
        g_MAX_EVT_WORDS         : integer := 50000;-- maximum event size (nothing really gets done when this size is reached, but an error is asserted on the output port)
        g_NUM_IDLES_SMALL_EVT   : integer := 2;    -- minimum number of idle words after a "small" event
        g_NUM_IDLES_BIG_EVT     : integer := 7;    -- minimum number of idle words after a "big" event
        g_SMALL_EVT_MAX_WORDS   : integer := 24;   -- above this number of words, the event is considered "big", thus requiring g_NUM_IDLES_BIG_EVT of idles after the packet
        g_USE_TRAILER_FLAG_EOE  : boolean;         -- uses data_trailer_i as an end-of-event indicator if this is set to true, otherwise it tries to find the end of event based on the data (only works for CSC)
        g_USE_GEM_FORMAT        : boolean          -- if set to true, the payload will be wrapped into extra header and trailer words indicating event number, packet size and number, and first/last flags
    );
    port (
        -- reset
        reset_i                 : in  std_logic;
        
        -- GbE link
        gbe_clk_i               : in  std_logic;
        gbe_tx_data_o           : out t_mgt_16b_tx_data;
        
        -- config
        skip_eth_header_i       : in  std_logic; -- if this is set high, the eth header will be skipped, just like in DDU, otherwise this will produce normal ETH frames of eth type 0x8870
        dest_mac_i              : in  std_logic_vector(47 downto 0);
        source_mac_i            : in  std_logic_vector(47 downto 0);
        ether_type_i            : in  std_logic_vector(15 downto 0);
        min_payload_words_i     : in  std_logic_vector(13 downto 0); -- minimum payload size in 16bit words
        max_payload_words_i     : in  std_logic_vector(13 downto 0); -- max payload size in 16bit words, excluding the header and trailer (if present)

        -- control
        data_empty_i            : in  std_logic;
        data_i                  : in  std_logic_vector(15 downto 0);
        data_trailer_i          : in  std_logic;
        data_rd_en              : out std_logic;
        last_valid_word_i       : in  std_logic; -- this indicates that this is the last valid word (almost_empty flag of the external FWFT FIFO)
        
        -- status
        err_event_too_big_o     : out std_logic; -- this is asserted if an event exceeding g_MAX_EVT_WORDS was seen since last reset
        err_eoe_not_found_o     : out std_logic; -- this is asserted if the fifo became empty before an end of event was found (latched till reset)
        word_rate_o             : out std_logic_vector(31 downto 0); -- word rate in Hz (including the ethernet frame words)
        evt_cnt_o               : out std_logic_vector(31 downto 0) -- event count

    );
end gbe_tx_driver;

architecture gbe_tx_driver_arch of gbe_tx_driver is

    component crc32_gbe is
        port(
            data_in          : in  std_logic_vector(15 downto 0);
            crc_en, rst, clk : in  std_logic;
            crc_reg          : out std_logic_vector(31 downto 0);
            crc_current      : out std_logic_vector(31 downto 0));
    end component;

    constant ETH_IDLE           : std_logic_vector(15 downto 0) := x"50BC";
    constant ETH_PREAMBLE_SOF   : t_std16_array(0 to 3) := (x"55FB", x"5555", x"5555", x"D555");
--    constant ETH_HEADER         : t_std16_array(0 to 6) := (x"CFED", x"CFED", x"CFED", x"9E80", x"1417", x"1500", x"7088");
    constant ETH_EOF            : t_std16_array(0 to 1) := (x"F7FD", x"C5BC");
    constant DDU_EOE_WORD64     : std_logic_vector(63 downto 0) := x"8000ffff80008000";

    type t_eth_state is (IDLE, PREAMBLE_SOF, HEADER, GEM_HEADER, PAYLOAD, FILLER, GEM_TRAILER, PACKET_CNT, CRC, EOF);
    
    signal reset                : std_logic;
    
    signal eth_header           : t_std16_array(0 to 6) := (others => (others => '0'));
    
    signal state                : t_eth_state;
    signal state_prev           : t_eth_state;
    signal word_idx             : integer range 0 to 16383 := 0;
    signal packet_idx           : unsigned(15 downto 0) := (others => '0');
    signal min_idle_cnt         : integer range 0 to g_NUM_IDLES_BIG_EVT := 0;
    signal first_filler_word    : std_logic := '0';
    signal not_idle             : std_logic;

    signal evt_cnt              : unsigned(31 downto 0) := (others => '0');
    signal evt_word_cnt         : unsigned(15 downto 0) := (others => '0');
    signal evt_pkt_payload_size : unsigned(11 downto 0) := (others => '0');
    signal evt_pkt_cnt          : unsigned(3 downto 0) := (others => '0');
    signal evt_pkt_first        : std_logic := '1';
    signal evt_pkt_last        : std_logic := '0';
    signal word64               : std_logic_vector(63 downto 0) := (others => '0');
    signal eoe_countdown        : unsigned(2 downto 0) := (others => '0'); 
    signal eoe                  : std_logic := '0';
    signal eoe_prev             : std_logic := '0';
    
    signal crc_reset            : std_logic := '0';
    signal crc_en               : std_logic := '0';
    signal crc_reg              : std_logic_vector(31 downto 0);
    signal crc_current          : std_logic_vector(31 downto 0);
    
    signal err_evt_too_big      : std_logic := '0';
    signal err_eoe_not_found    : std_logic := '0';
    
    signal data                 : std_logic_vector(15 downto 0) := ETH_IDLE;
    signal charisk              : std_logic_vector(1 downto 0) := "01";

    -- temporary debug
    signal min_payload_words    : std_logic_vector(13 downto 0);
    signal max_payload_words    : std_logic_vector(13 downto 0);

begin

    i_reset_sync : entity work.synch
        generic map(
            N_STAGES => 4,
            IS_RESET => true
        )
        port map(
            async_i => reset_i,
            clk_i   => gbe_clk_i,
            sync_o  => reset
        );

    -- bytes are swapped back at the MGT level
    eth_header(0) <= dest_mac_i(7 downto 0) & dest_mac_i(15 downto 8);
    eth_header(1) <= dest_mac_i(23 downto 16) & dest_mac_i(31 downto 24);
    eth_header(2) <= dest_mac_i(39 downto 32) & dest_mac_i(47 downto 40);
    eth_header(3) <= source_mac_i(7 downto 0) & source_mac_i(15 downto 8);
    eth_header(4) <= source_mac_i(23 downto 16) & source_mac_i(31 downto 24);
    eth_header(5) <= source_mac_i(39 downto 32) & source_mac_i(47 downto 40);
    eth_header(6) <= ether_type_i(7 downto 0) & ether_type_i(15 downto 8);

    gbe_tx_data_o.txchardispmode <= (others => '0');
    gbe_tx_data_o.txchardispval <= (others => '0');
    gbe_tx_data_o.txcharisk <= charisk;
    gbe_tx_data_o.txdata <= data;
    
    err_event_too_big_o <= err_evt_too_big;
    err_eoe_not_found_o <= err_eoe_not_found;
    evt_cnt_o <= std_logic_vector(evt_cnt);

    process(gbe_clk_i)
    begin
        if (rising_edge(gbe_clk_i)) then
            if (reset = '1') then
                state <= IDLE;
                word_idx <= 0;
                min_idle_cnt <= 0;
                data <= ETH_IDLE;
                charisk <= "01";
                data_rd_en <= '0';
                first_filler_word <= '0';
                crc_reset <= '1';
                crc_en <= '0';
            else
                case state is
                    
                    --=== Send IDLEs and check for available data ===--evt_word_cnt
                    when IDLE =>
                
                        first_filler_word <= '0';
                        word_idx <= 0;
                        crc_reset <= '1';
                        crc_en <= '0';
                        data <= ETH_IDLE;
                        charisk <= "01";
                        data_rd_en <= '0';
                        
                        if (data_empty_i = '0' and min_idle_cnt = 0) then
                            state <= PREAMBLE_SOF;
                        else
                            state <= IDLE;
                        end if;
                        
                        if (min_idle_cnt /= 0) then
                            min_idle_cnt <= min_idle_cnt - 1;
                        else
                            min_idle_cnt <= 0;
                        end if;
                        
                    --=== Send the preamble and start of frame sequence ===--        
                    when PREAMBLE_SOF =>
                        
                        first_filler_word <= '0';
                        min_idle_cnt <= 0;
                        crc_reset <= '0';
                        crc_en <= '0';
                        data <= ETH_PREAMBLE_SOF(word_idx);
                        
                        if (word_idx = 0) then
                            charisk <= "01";
                        else
                            charisk <= "00";
                        end if;
                        
                        if (word_idx = ETH_PREAMBLE_SOF'length - 1) then
                            word_idx <= 0;
                            if (skip_eth_header_i = '0') then
                                data_rd_en <= '0';
                                state <= HEADER;
                            else
                                data_rd_en <= '1';
                                state <= PAYLOAD;
                            end if;
                        else
                            word_idx <= word_idx + 1;
                            data_rd_en <= '0';
                            state <= PREAMBLE_SOF;
                        end if;

                    --=== Send the ethernet header (source MAC, destination MAC, and ethernet type) ===--        
                    when HEADER =>

                        first_filler_word <= '0';
                        min_idle_cnt <= 0;
                        crc_reset <= '0';
                        crc_en <= '1';
                        data <= eth_header(word_idx);
                        charisk <= "00";
                        
                        if (word_idx = eth_header'length - 1) then
                            word_idx <= 0;
                            if g_USE_GEM_FORMAT then
                                state <= GEM_HEADER;
                                data_rd_en <= '0';
                            else
                                state <= PAYLOAD;
                                data_rd_en <= '1';
                            end if;
                        else
                            word_idx <= word_idx + 1;
                            data_rd_en <= '0';
                            state <= HEADER;
                        end if;                        

                    --=== Send GEM header ===--        
                    when GEM_HEADER =>
                    
                        first_filler_word <= '0';
                        min_idle_cnt <= 0;
                        crc_reset <= '0';
                        crc_en <= '1';
                        data <= evt_pkt_first & "000" & std_logic_vector(evt_pkt_cnt) & std_logic_vector(evt_cnt(7 downto 0));
                        charisk <= "00";
                        
                        data_rd_en <= '1';
                        word_idx <= 0;
                        state <= PAYLOAD;
                    
                    --=== Send the ethernet payload ===--        
                    when PAYLOAD =>

                        data <= data_i;
                        charisk <= "00";
                        word_idx <= word_idx + 1;
                        first_filler_word <= '1';
                        crc_reset <= '0';
                        crc_en <= '1';

                        -- end of packet (either due to end of event detection, empty fifo, or packet size limit)
                        if (eoe = '1') or (last_valid_word_i = '1') or (word_idx = to_integer(unsigned(max_payload_words_i)) - 1) then
                            data_rd_en <= '0';
                            if (word_idx < to_integer(unsigned(min_payload_words_i)) - 1) then
                                state <= FILLER;
                            elsif g_USE_GEM_FORMAT then
                                state <= GEM_TRAILER;
                            else
                                state <= PACKET_CNT;
                            end if;
                            
                        else
                            data_rd_en <= '1';
                            state <= PAYLOAD;
                        end if;

                        if (word_idx < g_SMALL_EVT_MAX_WORDS) then
                            min_idle_cnt <= g_NUM_IDLES_SMALL_EVT;
                        else
                            min_idle_cnt <= g_NUM_IDLES_BIG_EVT;
                        end if;

                    --=== Send the filler words to satisfy the minimum packet length requirement (first word contains an 8bit valid word counter) ===--        
                    when FILLER =>
                        
                        charisk <= "00";
                        word_idx <= word_idx + 1;
                        first_filler_word <= '0';
                        min_idle_cnt <= min_idle_cnt;
                        data_rd_en <= '0';
                        crc_reset <= '0';
                        crc_en <= '1';
                                               
                        if (first_filler_word = '1') then
                            data <= x"ff" & std_logic_vector(to_unsigned(word_idx*2, 8));
                        else
                            data <= x"ffff";
                        end if;
                                   
                        if (word_idx < to_integer(unsigned(min_payload_words_i)) - 1) then
                            state <= FILLER;
                        elsif g_USE_GEM_FORMAT then
                            state <= GEM_TRAILER;
                        else
                            state <= PACKET_CNT;
                        end if;

                    --=== Send the GEM trailer ===--        
                    when GEM_TRAILER =>
                        
                        data <= std_logic_vector(evt_pkt_payload_size) & "000" & evt_pkt_last;
                        charisk <= "00";
                        word_idx <= 0;
                        first_filler_word <= '0';
                        min_idle_cnt <= min_idle_cnt;
                        crc_reset <= '0';
                        crc_en <= '1';
                        data_rd_en <= '0';
                        state <= CRC;

                    --=== Send the packet counter ===--        
                    when PACKET_CNT =>
                        
                        data <= std_logic_vector(packet_idx);
                        charisk <= "00";
                        word_idx <= 0;
                        first_filler_word <= '0';
                        min_idle_cnt <= min_idle_cnt;
                        crc_reset <= '0';
                        crc_en <= '1';
                        data_rd_en <= '0';
                        state <= CRC;

                    --=== Send the CRC ===--        
                    when CRC =>

                        charisk <= "00";
                        first_filler_word <= '0';
                        min_idle_cnt <= min_idle_cnt;
                        crc_reset <= '0';
                        crc_en <= '0';
                        data_rd_en <= '0';

                        if (word_idx = 0) then
                            data <= crc_current(15 downto 0);
                            word_idx <= 1;
                            state <= CRC;
                        else
                            data <= crc_reg(31 downto 16);
                            word_idx <= 0;
                            state <= EOF;
                        end if;

                    --=== Send the EOF ===--        
                    when EOF =>

                        first_filler_word <= '0';
                        min_idle_cnt <= min_idle_cnt;
                        crc_reset <= '0';
                        crc_en <= '0';
                        data_rd_en <= '0';

                        if (word_idx = 0) then
                            charisk <= "11";
                            data <= ETH_EOF(0);
                            word_idx <= 1;
                            state <= EOF;
                        else
                            charisk <= "01";
                            data <= ETH_EOF(1);
                            word_idx <= 0;
                            state <= IDLE;
                        end if;
                                            
                    --=== For completeness ===--        
                    when others =>
                        state <= IDLE;
                        word_idx <= 0;
                        min_idle_cnt <= 0;
                        data <= ETH_IDLE;
                        charisk <= "01";
                        data_rd_en <= '0';
                        first_filler_word <= '0';
                        crc_reset <= '1';
                        crc_en <= '0';

                end case;
            end if;
        end if;
    end process;

    -- packet counter
    process(gbe_clk_i)
    begin
        if (rising_edge(gbe_clk_i)) then
            if (reset = '1') then
                packet_idx <= (others => '0');
            else
                if (state = EOF) and (word_idx = 0) then
                    packet_idx <= packet_idx + 1;
                else
                    packet_idx <= packet_idx;
                end if;
            end if;
        end if;
    end process;

    -- end of event detection based on the trailer flag
    g_eoe_from_trailer : if g_USE_TRAILER_FLAG_EOE generate
        
        eoe <= data_trailer_i;
        err_eoe_not_found <= '0';
        
    end generate;

    -- end of event detection based on data
    g_eoe_from_data : if not g_USE_TRAILER_FLAG_EOE generate        
        process(gbe_clk_i)
        begin
            if (rising_edge(gbe_clk_i)) then
                if (reset = '1') then
                    word64 <= (others => '0');
                    eoe_countdown <= (others => '0');     
                    err_eoe_not_found <= '0';
                    eoe <= '0';
                else
    
                    if (state = PAYLOAD) then
                        word64 <= data_i & word64(63 downto 16);
                        
                        if (word64 = DDU_EOE_WORD64) then
                            eoe_countdown <= "111";
                            eoe <= '0';
                        elsif (eoe_countdown = "001") then
                            eoe <= '1';
                            eoe_countdown <= (others => '0');
                        elsif (eoe_countdown = "000") then
                            eoe <= '0';
                            eoe_countdown <= (others => '0');
                        else
                            eoe <= '0';
                            eoe_countdown <= eoe_countdown - 1;
                        end if;
                        
                        if (eoe = '0') and (last_valid_word_i = '1') then
                            err_eoe_not_found <= '1';
                        else
                            err_eoe_not_found <= err_eoe_not_found;
                        end if;
                    else
                        word64 <= (others => '0');
                        eoe <= '0';
                        eoe_countdown <= (others => '0');     
                        err_eoe_not_found <= err_eoe_not_found;                          
                    end if;
    
                end if;
            end if;
        end process;
    end generate;

    -- event count and size check
    process(gbe_clk_i)
    begin
        if (rising_edge(gbe_clk_i)) then
            if (reset = '1') then
                evt_word_cnt <= (others => '0');
                err_evt_too_big <= '0';  
                evt_cnt <= (others => '0');
                evt_pkt_cnt <= (others => '0');
                evt_pkt_payload_size <= (others => '0');
                evt_pkt_first <= '1';
                evt_pkt_last <= '0';
            else

                state_prev <= state;
                eoe_prev <= eoe;

                if (state = PAYLOAD) then
                    
                    if (eoe = '1') then
                        evt_word_cnt <= (others => '0');
                        evt_cnt <= evt_cnt + 1;
                        evt_pkt_cnt <= (others => '0');
                        evt_pkt_last <= '1';
                    else
                        evt_word_cnt <= evt_word_cnt + 1;
                        evt_cnt <= evt_cnt;
                    end if;
                    
                    if (evt_word_cnt > to_unsigned(g_MAX_EVT_WORDS, 16)) then
                        err_evt_too_big <= '1';
                    else
                        err_evt_too_big <= err_evt_too_big;
                    end if;
                    
                    evt_pkt_payload_size <= evt_pkt_payload_size + 1;
                    evt_pkt_first <= '0';
                    
                else
                    
                    if (state_prev = PAYLOAD and eoe_prev = '0') then
                        evt_pkt_cnt <= evt_pkt_cnt + 1;
                    end if;
                    
                    if (state = GEM_TRAILER) then
                        evt_pkt_payload_size <= (others => '0');
                        evt_pkt_first <= evt_pkt_last;
                        evt_pkt_last <= '0';
                    end if;
                    
                    evt_cnt <= evt_cnt;
                    evt_word_cnt <= evt_word_cnt;
                    err_evt_too_big <= err_evt_too_big;
                    
                end if;

            end if;
        end if;
    end process;

    -- word rate
    
    not_idle <= '0' when state = IDLE else '1';
    
    i_word_rate : entity work.rate_counter
        generic map(
            g_CLK_FREQUENCY => x"03b9aca0", -- 62.5MHz
            g_COUNTER_WIDTH => 32
        )
        port map(
            clk_i   => gbe_clk_i,
            reset_i => reset,
            en_i    => not_idle,
            rate_o  => word_rate_o
        );
    
    -- crc
    
    i_crc : crc32_gbe
        port map(
            data_in     => data,
            crc_en      => crc_en,
            rst         => crc_reset,
            clk         => gbe_clk_i,
            crc_reg     => crc_reg,
            crc_current => crc_current
        );

end gbe_tx_driver_arch;
