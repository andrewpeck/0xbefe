------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    12:12 2016-10-19
-- Module Name:    SCA TX
-- Description:    This module accepts SCA command requests and outputs 1 bit serial stream at 80MHz (this should be deserialized to 2 bit 40MHz stream and sent to GBT EC field).
--                 Command request is initiated by the command_en_i strobe. No new commands are accepted until the busy_o flag goes low.    
------------------------------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.gem_pkg.all;
use work.sca_pkg.all;

entity sca_tx is
    port(
        -- reset
        reset_i                 : in  std_logic;

        -- clocks
        clk_80_i                : in  std_logic; -- 80MHz
        
        -- serial output
        sd_tx_o                 : out std_logic;
        
        -- SCA command data
        transaction_id_i        : std_logic_vector(7 downto 0);
        sca_command_i           : in t_sca_command;

        -- control signals
        rx_ready_i              : in  std_logic;
        rx_seq_num_i            : in  std_logic_vector(2 downto 0);
        sca_reset_i             : in  std_logic;
        command_en_i            : in  std_logic;
        busy_o                  : out std_logic;
        
        -- debug
        raw_last_cmd_o          : out std_logic_vector(95 downto 0)
        
    );
end sca_tx;

architecture sca_tx_arch of sca_tx is

    -- CRC component --
--    component crc16ccitt
--        port(
--            BITVAL  : in std_logic;
--            BITSTRB : in std_logic;
--            CLEAR   : in std_logic;
--            CRC     : out std_logic_vector(15 downto 0)
--        );
--    end component;
    -------------------

    constant HDLC_ADDRESS   : std_logic_vector(7 downto 0) := x"00";
    constant RESET_FRAME    : std_logic_vector(15 downto 0) := x"8f00"; -- includes hdlc address and hdlc control

    type state_t is (IDLE, SOF, SHIFT_FRAME, SHIFT_RESET_FRAME, CRC, EOF);

    -- fsm signals
    signal state            : state_t;
    signal set_bit_cnt      : integer range 0 to 8;
    signal word_pos         : integer range 0 to 79;
    signal start_frame      : std_logic;
    signal num_stuffed_bits : unsigned(4 downto 0);

    -- frame data
    signal frame_data       : std_logic_vector(79 downto 0);
    signal frame_length     : integer range 0 to 80;
    signal tx_seq_num       : std_logic_vector(2 downto 0);

    -- crc
    signal calc_crc         : std_logic_vector(15 downto 0);
    signal crc_din          : std_logic;
    signal crc_en           : std_logic;
    signal crc_init         : std_logic;
    
begin

    --========= Some wiring =========--
    
    busy_o <= '0' when (state = IDLE) and (reset_i = '0') and (rx_ready_i = '1') and (start_frame = '0') else '1';

    --========= TX FSM =========--

    process(clk_80_i)
    begin
        if (rising_edge(clk_80_i)) then
            if ((reset_i = '1') or (rx_ready_i = '0')) then
                state <= IDLE;
                word_pos <= 0;
                start_frame <= '0';
                tx_seq_num <= "000";
                sd_tx_o <= '1';
                --raw_last_cmd_o <= (others => '0');
                set_bit_cnt <= 0;
                crc_init <= '1';
                crc_en <= '0';
                num_stuffed_bits <= (others => '0');
            else
                
                crc_en <= '0';
                crc_init <= '0';
                
                case state is
                    
                    -- sending idles (7 set bits and a zero) and checking for command request
                    when IDLE =>
                        if (word_pos < 7) then
                            sd_tx_o <= '1';
                            word_pos <= word_pos + 1;
                        else
                            sd_tx_o <= '0';
                            word_pos <= 0;
                            if (start_frame = '1') then
                                state <= SOF;
                            end if;
                        end if;
                        
                        -- sca reset request
                        if (sca_reset_i = '1') then
                            start_frame <= '1';
                            frame_length <= 16;
                            frame_data(15 downto 0) <= RESET_FRAME;
                        -- sca command request
                        elsif ((command_en_i = '1') and (start_frame = '0')) then
                            start_frame <= '1';
                            frame_length <= 48 + (to_integer((unsigned(sca_command_i.length) + 1) srl 1) * 16); -- for data take 2 bytes if length is 1 or 2 and take 4 bytes if length is 3 or 4
                            frame_data <= sca_command_i.data(23 downto 16) &
                                          sca_command_i.data(31 downto 24) &
                                          sca_command_i.data(7 downto 0) &
                                          sca_command_i.data(15 downto 8) &
                                          sca_command_i.command &
                                          sca_command_i.length &
                                          sca_command_i.channel &
                                          transaction_id_i &
                                          rx_seq_num_i & "0" & rx_seq_num_i & "0" & -- may consider running your own sequence counter for TX part [3:1]
                                          HDLC_ADDRESS;
                        end if;
                                
                        crc_init <= '1';
                        set_bit_cnt <= 0;
                        num_stuffed_bits <= (others => '0');
                                        
                    -- sending start-of-frame sequence (01111110)
                    when SOF =>
                        if (word_pos = 7) then
                            state <= SHIFT_FRAME;
                            word_pos <= 0;
                            -- start calculating CRC one clock early to have it ready on state = CRC
                            crc_en <= '1';
                            crc_din <= frame_data(0);
                        else
                            word_pos <= word_pos + 1;
                        end if;

                        if ((word_pos = 0) or (word_pos = 7)) then
                            sd_tx_o <= '0';
                        else
                            sd_tx_o <= '1';
                        end if;
                        
                        start_frame <= '0';
                        raw_last_cmd_o <= (others => '0');
                        
                    -- sending frame data
                    when SHIFT_FRAME =>
                        -- if there are 5 set bits in a row, then we will stuff a zero which will get ignored on the other side
                        if (set_bit_cnt < 5) then 
                            sd_tx_o <= frame_data(word_pos);
                            
                            if (frame_data(word_pos) = '1') then
                                set_bit_cnt <= set_bit_cnt + 1; 
                            else
                                set_bit_cnt <= 0;
                            end if;

                            if (word_pos = frame_length - 1) then
                                state <= CRC;
                                word_pos <= 15;
                            else
                                word_pos <= word_pos + 1;
                                -- calculate CRC one bit in ahead to have it ready on state = CRC (first bit is done in state = SOF)
                                crc_din <= frame_data(word_pos + 1);
                                crc_en <= '1';
                            end if;
                        else
                            sd_tx_o <= '0';
                            set_bit_cnt <= 0;
                            num_stuffed_bits <= num_stuffed_bits + 1;
                        end if;
                        
                        start_frame <= '0';

                    -- receiving SCA Transaction ID word (8bits)
                    when CRC =>
                        -- if there are 5 set bits in a row, then we will stuff a zero which will get ignored on the other side
                        if (set_bit_cnt < 5) then
                            sd_tx_o <= calc_crc(word_pos);
                            
                            if (calc_crc(word_pos) = '1') then
                                set_bit_cnt <= set_bit_cnt + 1; 
                            else
                                set_bit_cnt <= 0;
                            end if;
                                                        
                            if (word_pos = 0) then
                                state <= EOF;
                                word_pos <= 0;
                                raw_last_cmd_o(frame_length - 1 downto 0) <= frame_data(frame_length - 1 downto 0);
                                raw_last_cmd_o(frame_length + 15 downto frame_length) <= calc_crc;
                            else
                                word_pos <= word_pos - 1;
                            end if;
                        else
                            sd_tx_o <= '0';
                            set_bit_cnt <= 0;
                            num_stuffed_bits <= num_stuffed_bits + 1;
                        end if;

                        start_frame <= '0';

                    when EOF =>
                        -- stuff in an extra one if we stuffed an odd number of zeros
                        if ((word_pos = 7) and (num_stuffed_bits(0) = '0')) or ((word_pos = 8) and (num_stuffed_bits(0) = '1')) then
                            state <= IDLE;
                            word_pos <= 0;
                        else
                            word_pos <= word_pos + 1;
                        end if;

                        if ((word_pos = 0) or (word_pos = 7)) then
                            sd_tx_o <= '0';
                        else
                            sd_tx_o <= '1';
                        end if;
                        
                        start_frame <= '0';
                        
                    when others =>
                        state <= IDLE;
                        
                end case;
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
            crc_o        => calc_crc
        );
        
end sca_tx_arch;
