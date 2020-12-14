------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    12:12 2016-10-19
-- Module Name:    SCA RX
-- Description:    This module accepts 1 bit serial stream and decodes incoming SCA packets (note SCA 2bit 40MHz stream has to be serialized to 1bit 80MHz) 
------------------------------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.gem_pkg.all;
use work.sca_pkg.all;

entity sca_rx is
    port(
        -- reset
        reset_i                 : in  std_logic;

        -- clocks
        clk_80_i                : in  std_logic; -- 80MHz
        
        -- serial input
        sd_rx_i                 : in  std_logic;
        
        -- monitoring
        ready_o                 : out std_logic;
        seq_num_o               : out std_logic_vector(2 downto 0);
        rx_err_cnt_o            : out std_logic_vector(15 downto 0);
        seq_num_err_cnt_o       : out std_logic_vector(15 downto 0);
        crc_err_cnt_o           : out std_logic_vector(15 downto 0);
        
        -- frame data outputs
        sca_reply_o             : out t_sca_reply;
        transaction_id_o        : out std_logic_vector(7 downto 0);
        packet_valid_o          : out std_logic;
        
        -- debug
        calc_crc_o              : out std_logic_vector(15 downto 0);              
        raw_last_reply_o        : out std_logic_vector(95 downto 0)        
    );
end sca_rx;

architecture sca_rx_arch of sca_rx is

    type state_t is (WAITING_FOR_IDLE, IDLE, RECEIVING);

    -- fsm signals
    signal state            : state_t;
    signal set_bit_cnt      : integer range 0 to 11;
    signal packet_pos       : integer range 0 to 104;
    signal rx_error         : std_logic;
    signal seq_num          : std_logic_vector(2 downto 0);
    signal seq_num_init_done: std_logic;
    signal seq_num_err      : std_logic;
    signal crc_err          : std_logic; 

    -- frame data
    signal packet           : std_logic_vector(103 downto 0);
    signal packet_length    : integer range 0 to 104;
    signal packet_crc       : std_logic_vector(15 downto 0);

    -- crc
    signal crc              : std_logic_vector(15 downto 0);
    signal crc_din          : std_logic;
    signal crc_en           : std_logic;
    signal crc_init         : std_logic;
    signal crc_latch		: std_logic;

    -- monitoring
    signal rx_err_cnt       : std_logic_vector(15 downto 0);
    signal seq_num_err_cnt  : std_logic_vector(15 downto 0);
    signal crc_err_cnt      : std_logic_vector(15 downto 0);

begin

    --========= Some wiring =========--
    
    rx_err_cnt_o <= rx_err_cnt;
    seq_num_o <= seq_num;
    seq_num_err_cnt_o <= seq_num_err_cnt;
    crc_err_cnt_o <= crc_err_cnt;
    ready_o <= '0' when state = WAITING_FOR_IDLE else '1';
    
    raw_last_reply_o <= packet(95 downto 0);
    calc_crc_o <= packet_crc;

    --========= RX FSM =========--

    process(clk_80_i)
    begin
        if (rising_edge(clk_80_i)) then
            if (reset_i = '1') then
                state <= WAITING_FOR_IDLE;
                rx_error <= '0';
                packet_valid_o <= '0';
                packet_pos <= 0;
                seq_num <= "000";
                seq_num_init_done <= '0';
                packet_length <= 0;
                crc_init <= '1';
                crc_latch <= '0';
            else
                rx_error <= '0';
                seq_num_err <= '0';
                packet_valid_o <= '0';
                crc_en <= '0';
                crc_init <= '0';       
                crc_err <= '0';
                crc_latch <= '0';
                
                case state is
                    
                    -- wait for idle frame (7 set bits and a zero)
                    when WAITING_FOR_IDLE =>
                        if ((set_bit_cnt = 7) and (sd_rx_i = '0')) then
                            state <= IDLE;
                        end if;
                        
                    -- receiving idle frames (7 set bits and a zero)
                    when IDLE =>
                        if ((set_bit_cnt = 6) and (sd_rx_i = '0')) then -- start of frame received (6 set bits followed by a 0)
                            state <= RECEIVING;
                        elsif (set_bit_cnt > 9) then -- if there's more than 9 set bits, then something is wrong, go back to wait for an idle frame
                            state <= WAITING_FOR_IDLE;
                            rx_error <= '1';
                        end if;
                        
                        packet_pos <= 0;
                        packet_length <= 0;
                        crc_init <= '1';
                        
                    -- receiving an active frame
                    when RECEIVING =>
                        
                        -- if there are 5 set bits in a row, then next will be a stuffed zero which should be ignored
                        if (set_bit_cnt < 5) then
                            packet(packet_pos) <= sd_rx_i;
                            crc_din <= sd_rx_i;
                            crc_en <= '1';

                            packet_pos <= packet_pos + 1;
                            
                            -- byte boundary
                            if (packet_pos = packet_length + 8) then
                            	packet_length <= packet_pos;
                            	crc_latch <= '1';
                            end if;
                            
                            -- frame shouldn't be that long, go and wait for idle
                            if (packet_pos = 103) then
                                state <= WAITING_FOR_IDLE;
                                rx_error <= '1';
                            end if;
                            
                        -- end of frame (EOF)
                        elsif ((set_bit_cnt = 6) and (sd_rx_i = '0')) then
                            state <= IDLE;
                            
                            -- check the crc
                            -- TODO: might want to not assert packet_valid if crc check fails (for now just monitoring crc fail rate)
                            if (packet_crc /= x"0000") then
                                crc_err <= '1';
                            end if;   
                            
                            -- if the packet has payload, then great, otherwise ignore it (also shoot an error if it's even smaller than an empty hdlc packet)
                            if (packet_length >= 64) then
                                packet_valid_o <= '1';
                                
                                transaction_id_o <= packet(23 downto 16);
                                sca_reply_o.channel <= packet(31 downto 24);
                                sca_reply_o.error <= packet(47 downto 40);
                                sca_reply_o.length <= packet(39 downto 32); -- note that SCA doesn't really always send the correct length... but we put it here as is..
                                -- data is transmitted as DATA[15:8], DATA[7:0], DATA[31:24], DATA[23:16]
                                -- note that depending on the packet length, some of the data we're writing to sca_reply_o.data will be invalid, so user should check LENGTH!
                                sca_reply_o.data(7 downto 0) <= packet(63 downto 56);
                                sca_reply_o.data(15 downto 8) <= packet(55 downto 48);
                                sca_reply_o.data(23 downto 16) <= packet(79 downto 72);
                                sca_reply_o.data(31 downto 24) <= packet(71 downto 64);
                                
                                -- check the received packet sequence number
                                seq_num <= packet(15 downto 13); -- hdlc control [7:5]
                                seq_num_init_done <= '1'; -- don't check the first ever seq number
                                if ((seq_num_init_done = '1') and (seq_num /= std_logic_vector(unsigned(packet(15 downto 13)) - 1))) then
                                    seq_num_err <= '1';
                                end if;                                
                            elsif (packet_length < 32) then
                                rx_error <= '1';
                            end if;

							if (crc_latch = '1') then
								packet_crc <= crc;
							end if;

                        -- if it's not EOF and we have more than 5 set bits in a row, there's something wrong -- go and wait for an idle word
                        elsif (set_bit_cnt > 5) then
                            state <= WAITING_FOR_IDLE;
                            rx_error <= '1';
                        end if;
                        
                    -- hmm don't know how I got here, but lets go look for an idle frame :)    
                    when others =>
                        state <= WAITING_FOR_IDLE;
                        
                end case;
            end if;
        end if;
    end process;

    --========= Set bits counter =========--

    process(clk_80_i)
    begin
        if (rising_edge(clk_80_i)) then
            if (reset_i = '1') then
                set_bit_cnt <= 0;
            else
                if (sd_rx_i = '0') then
                    set_bit_cnt <= 0;
                elsif (set_bit_cnt < 10) then
                    set_bit_cnt <= set_bit_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    --========= CRC =========--
    
    i_crc : entity work.crc16_ccitt
        port map(
            clk_i        => clk_80_i,
            sync_reset_i => crc_init,
            data_i       => crc_din,
            data_en_i    => crc_en,
            crc_o        => crc
        );

    --========= Error counters =========--
    
    i_rx_err_cnt : entity work.counter
        generic map(
            g_COUNTER_WIDTH  => 16,
            g_ALLOW_ROLLOVER => false
        )
        port map(
            ref_clk_i => clk_80_i,
            reset_i   => reset_i,
            en_i      => rx_error,
            count_o   => rx_err_cnt
        );

    i_seq_num_err_cnt : entity work.counter
        generic map(
            g_COUNTER_WIDTH  => 16,
            g_ALLOW_ROLLOVER => false
        )
        port map(
            ref_clk_i => clk_80_i,
            reset_i   => reset_i,
            en_i      => seq_num_err,
            count_o   => seq_num_err_cnt
        );

    i_crc_err_cnt : entity work.counter
        generic map(
            g_COUNTER_WIDTH  => 16,
            g_ALLOW_ROLLOVER => false
        )
        port map(
            ref_clk_i => clk_80_i,
            reset_i   => reset_i,
            en_i      => crc_err,
            count_o   => crc_err_cnt
        );

end sca_rx_arch;
