------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    12:12 2017-08-11
-- Module Name:    VFAT3 SC TX
-- Description:    This module accepts VFAT3 single register read/write requests and generates an encoded serial 8bit steam containing the HDLC and IPbus packet     
------------------------------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.gem_pkg.all;

entity vfat3_sc_tx is
    port(
        -- reset
        reset_i                 : in  std_logic;

        -- clocks
        clk_40_i                : in  std_logic;
        
        -- serial output
        data_o                  : out std_logic;
        data_en_o               : out std_logic;
        
        -- command data
        hdlc_address_i          : in  std_logic_vector(7 downto 0);
        transaction_id_i        : in  std_logic_vector(7 downto 0);
        is_write_i              : in  std_logic;
        reg_addr_i              : in  std_logic_vector(31 downto 0);
        reg_value_i             : in  std_logic_vector(31 downto 0);
        command_en_i            : in  std_logic;
        busy_o                  : out std_logic;
        
        -- debug
        raw_last_packet_o       : out std_logic_vector(111 downto 0);
        calc_crc_o              : out std_logic_vector(15 downto 0)
        
    );
end vfat3_sc_tx;

architecture vfat3_sc_tx_arch of vfat3_sc_tx is

    constant HDLC_CONTROL   : std_logic_vector(7 downto 0) := x"03";
    constant IPBUS_VERSION  : std_logic_vector(3 downto 0) := x"2";

    type state_t is (IDLE, SOF, SHIFT_FRAME, CRC, EOF);

    -- fsm signals
    signal state            : state_t;
    signal set_bit_cnt      : integer range 0 to 8;
    signal word_pos         : integer range 0 to 112;

    -- frame data
    signal frame_data       : std_logic_vector(111 downto 0);
    signal frame_length     : integer range 0 to 112;

    -- serial data
    signal serial_data      : std_logic;

    -- crc
    signal calc_crc         : std_logic_vector(15 downto 0);
    signal crc_din          : std_logic;
    signal crc_en           : std_logic;
    signal crc_init         : std_logic;
    
begin

    --========= Some wiring =========--
    
    busy_o <= '0' when (state = IDLE) and (reset_i = '0') else '1';
    data_o <= serial_data; 

    --========= TX FSM =========--

    process(clk_40_i)
    begin
        if (rising_edge(clk_40_i)) then
            if (reset_i = '1') then
                state <= IDLE;
                word_pos <= 0;
                set_bit_cnt <= 0;
                crc_init <= '1';
                crc_en <= '0';
                serial_data <= '0';
                data_en_o <= '0';
            else
                crc_en <= '0';
                crc_init <= '0';
                
                case state is
                    
                    when IDLE =>
                        if (command_en_i = '1') then
                            if (is_write_i = '1') then
                                frame_length <= 112;
                            else
                                frame_length <= 80;
                            end if;
                            frame_data <= reg_value_i &
                                          reg_addr_i &
                                          IPBUS_VERSION & x"0" &
                                          x"01" & -- num regs in the transaction - for now just support 1 reg transactions
                                          transaction_id_i &
                                          "000" & is_write_i & x"f" &
                                          HDLC_CONTROL &
                                          hdlc_address_i;
                            state <= SOF;
                        end if;

                        crc_init <= '1';
                        set_bit_cnt <= 0;
                        word_pos <= 0;
                        serial_data <= '0';
                        data_en_o <= '0';
                        
                    -- sending start-of-frame sequence (01111110)
                    when SOF =>
                        if (word_pos = 7) then
                            state <= SHIFT_FRAME;
                            word_pos <= 0;
                            -- start calculating CRC one clock early to have it ready on state = CRC
                            crc_en <= '1';
                            crc_din <= frame_data(0);
                            
                            raw_last_packet_o <= frame_data;
                        else
                            word_pos <= word_pos + 1;
                        end if;

                        if ((word_pos = 0) or (word_pos = 7)) then
                            serial_data <= '0';
                        else
                            serial_data <= '1';
                        end if;
                        
                        data_en_o <= '1';
                             
                    -- sending frame data
                    when SHIFT_FRAME =>
                        -- if there are 5 set bits in a row, then we will stuff a zero which will get ignored on the other side
                        if (set_bit_cnt < 5) then 
                            serial_data <= frame_data(word_pos);
                            
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
                            serial_data <= '0';
                            set_bit_cnt <= 0;
                        end if;
                        
                        data_en_o <= '1';

                    -- sending the CRC
                    -- NOTE: CRC is sent MSB and INVERTED!!!
                    when CRC =>
                        -- if there are 5 set bits in a row, then we will stuff a zero which will get ignored on the other side
                        if (set_bit_cnt < 5) then
                            serial_data <= not calc_crc(word_pos);
                            
                            if ((not calc_crc(word_pos)) = '1') then
                                set_bit_cnt <= set_bit_cnt + 1; 
                            else
                                set_bit_cnt <= 0;
                            end if;
                                                        
                            if (word_pos = 0) then
                                state <= EOF;
                                word_pos <= 0;
                                calc_crc_o <= calc_crc;
                            else
                                word_pos <= word_pos - 1;
                            end if;
                        else
                            serial_data <= '0';
                            set_bit_cnt <= 0;
                        end if;

                        data_en_o <= '1';

                    when EOF =>
                        -- stuff in an extra one if we stuffed an odd number of zeros
                        if (word_pos = 7) then
                            state <= IDLE;
                            word_pos <= 0;
                        else
                            word_pos <= word_pos + 1;
                        end if;

                        if ((word_pos = 0) or (word_pos = 7)) then
                            serial_data <= '0';
                        else
                            serial_data <= '1';
                        end if;
                        
                        data_en_o <= '1';
                        
                    when others =>
                        state <= IDLE;

                end case;
                
            end if;
        end if;
    end process;

    --========= CRC =========--
    
    i_crc : entity work.crc16_ccitt
        port map(
            clk_i        => clk_40_i,
            sync_reset_i => crc_init,
            data_i       => crc_din,
            data_en_i    => crc_en,
            crc_o        => calc_crc
        );
        
end vfat3_sc_tx_arch;
