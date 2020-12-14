------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    16:05 2016-10-12
-- Module Name:    GBTx Internal Control (IC) controller
-- Description:    This module is handling reading and writing of GBTx registers
------------------------------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.gem_pkg.all;

entity gbt_ic_controller is
--    generic(
--        g_GBTX_I2C_ADDRESS      : std_logic_vector(3 downto 0) := x"1"
--    );
    port(
        -- reset
        reset_i                 : in  std_logic;

        -- clocks
        gbt_clk_i               : in std_logic;
        
        -- GBTx I2C address (for OHv2b it should be always 0x1 because that's hardwired on the board), but 0 can be used for broadcast
        gbtx_i2c_address        : in std_logic_vector(6 downto 0);
        
        -- GBTx IC elinks
        gbt_rx_ic_elink_i       : in  std_logic_vector(1 downto 0);
        gbt_tx_ic_elink_o       : out std_logic_vector(1 downto 0);
        
        -- Control
        ic_rw_address_i         : in  std_logic_vector(15 downto 0);
        ic_w_data_i             : in  std_logic_vector(31 downto 0);
        --ic_r_data_o             : out std_logic_vector(31 downto 0);
        ic_rw_length_i          : in std_logic_vector(2 downto 0);
        ic_write_req_i          : in std_logic;
        ic_write_done_o         : out std_logic;
        ic_read_req_i           : in std_logic
        --ic_read_ready_o         : out std_logic
        
    );
end gbt_ic_controller;

architecture Behavioral of gbt_ic_controller is

    constant SOF_EOF            : std_logic_vector(7 downto 0) := x"7e";

    -------------- tx serializer -------------- 

    type serdes_state_t is (IDLE, REG_ADDR, DATA, PARITY, EOF);
    
    signal ser_state            : serdes_state_t;
    signal ser_word_pos         : integer range 0 to 31 := 0;
    signal ser_data_word_idx    : integer range 0 to 4 := 0;
    signal ser_frame_pos        : integer range 0 to 127 := 0;
    signal ser_parity           : std_logic_vector(7 downto 0) := (others => '0');
    signal ser_set_bit_cnt      : integer range 0 to 7 := 0;
    signal ser_is_write         : std_logic;   
    
    signal tx_frame             : std_logic_vector(127 downto 0) := (others => '0');
    signal tx_sender_en         : std_logic;

    -------------- tx sender --------------
     
    type sender_state_t is (IDLE, SENDING);
    signal sender_state         : sender_state_t;
    signal sender_frame_pos     : integer range 0 to 127 := 0;

begin

    --========= Serializer FSM =========--
     
    process(gbt_clk_i)
    begin
        if (rising_edge(gbt_clk_i)) then
            if (reset_i = '1') then
                ser_state <= IDLE;
                tx_frame <= (others => '1');
                ser_frame_pos <= 0;
                ser_word_pos <= 0;
                ser_parity <= (others => '0');
                ser_set_bit_cnt <= 0;
                ser_data_word_idx <= 0;
                tx_sender_en <= '0';
            else                
                tx_sender_en <= '0';
                
                case ser_state is
                    when IDLE   =>
                        if ((ic_write_req_i = '1' and ic_rw_length_i /= "000") or ic_read_req_i = '1') then
                            ser_state <= REG_ADDR;
                            ser_is_write <= ic_write_req_i;
                            -- we assign the beginning of the frame here because there's no chance of bit stuffing here
                            tx_frame(47 downto 0) <= x"000" & "0" & ic_rw_length_i &                     -- LENGTH
                                                     x"01" &                                             -- CMD
                                                     gbtx_i2c_address & not ic_write_req_i &             -- I2C ADDRESS + read flag
                                                     x"00" & -- ???? hmm, this is not documented, but saw this in another guy's code...
                                                     SOF_EOF;                                            -- SOF
                            tx_frame(127 downto 48) <= (others => '1');
                            ser_parity <= ((x"01" xor ("00000" & ic_rw_length_i)) xor ic_rw_address_i(7 downto 0)) xor ic_rw_address_i(15 downto 8) ;
                            ser_frame_pos <= 48;
                            ser_word_pos <= 0;
                            ser_set_bit_cnt <= 0;
                            ser_data_word_idx <= 0;
                        end if;
                    when REG_ADDR =>
                        ser_frame_pos <= ser_frame_pos + 1;
                        if (ser_set_bit_cnt = 5) then
                            -- we have 5 set bits in a row, insert a 0 here
                            tx_frame(ser_frame_pos) <= '0';
                            ser_set_bit_cnt <= 0;
                        else
                            if (ser_word_pos < 15) then
                                ser_word_pos <= ser_word_pos + 1;
                            else
                                ser_word_pos <= 0;
                                if (ser_is_write = '1') then
                                    ser_state <= DATA;
                                else
                                    ser_state <= PARITY;
                                end if;
                            end if;
                            
                            tx_frame(ser_frame_pos) <= ic_rw_address_i(ser_word_pos);
                            
                            if (ic_rw_address_i(ser_word_pos) = '1') then
                                ser_set_bit_cnt <= ser_set_bit_cnt + 1;
                            else
                                ser_set_bit_cnt <= 0;
                            end if;
                        end if;
                    when DATA =>
                        ser_frame_pos <= ser_frame_pos + 1;
                        if (ser_set_bit_cnt = 5) then
                            -- we have 5 set bits in a row, insert a 0 here
                            tx_frame(ser_frame_pos) <= '0';
                            ser_set_bit_cnt <= 0;
                        else
                            if (ser_word_pos < 7) then
                                ser_word_pos <= ser_word_pos + 1;
                            else
                                ser_word_pos <= 0;
                                ser_data_word_idx <= ser_data_word_idx + 1;
                                -- last data word - move to the next state now
                                if (ser_data_word_idx = to_integer(unsigned(ic_rw_length_i)) - 1) then
                                    ser_state <= PARITY;
                                end if;
                            end if;
                            
                            if (ser_word_pos = 0) then
                                -- update parity once per data word
                                ser_parity <= ser_parity xor ic_w_data_i(((ser_data_word_idx + 1) * 8) - 1 downto (ser_data_word_idx * 8));
                            end if;
                            
                            tx_frame(ser_frame_pos) <= ic_w_data_i((ser_data_word_idx * 8) + ser_word_pos);
                            
                            if (ic_w_data_i((ser_data_word_idx * 8) + ser_word_pos) = '1') then
                                ser_set_bit_cnt <= ser_set_bit_cnt + 1;
                            else
                                ser_set_bit_cnt <= 0;
                            end if;
                        end if;
                    when PARITY =>
                        ser_frame_pos <= ser_frame_pos + 1;
                        if (ser_set_bit_cnt = 5) then
                            -- we have 5 set bits in a row, insert a 0 here
                            tx_frame(ser_frame_pos) <= '0';
                            ser_set_bit_cnt <= 0;
                        else
                            if (ser_word_pos < 7) then
                                ser_word_pos <= ser_word_pos + 1;
                            else
                                ser_word_pos <= 0;
                                ser_state <= EOF;
                            end if;
                            
                            tx_frame(ser_frame_pos) <= ser_parity(ser_word_pos);
                            
                            if (ser_parity(ser_word_pos) = '1') then
                                ser_set_bit_cnt <= ser_set_bit_cnt + 1;
                            else
                                ser_set_bit_cnt <= 0;
                            end if;
                        end if;
                    when EOF =>
                        tx_frame(ser_frame_pos + 7 downto ser_frame_pos) <= x"7e";
                        ser_state <= IDLE;
                        tx_sender_en <= '1';
                    when others =>
                        ser_state <= IDLE;
                end case;
            end if;
        end if;
    end process;

    --========= TX Sender FSM =========--

    process(gbt_clk_i)
    begin
        if (rising_edge(gbt_clk_i)) then
            if (reset_i = '1') then
                gbt_tx_ic_elink_o <= "11";
                sender_frame_pos <= 0;
                ic_write_done_o <= '0';
            else
                
                ic_write_done_o <= '0';
                
                case sender_state is
                    when IDLE =>
                        gbt_tx_ic_elink_o <= "11";
                        sender_frame_pos <= 0;
                        if (tx_sender_en = '1') then
                            sender_state <= SENDING;
                        end if;
                    when SENDING =>
                        if (sender_frame_pos < 125) then
                            sender_frame_pos <= sender_frame_pos + 2;
                        else
                            sender_state <= IDLE;
                            ic_write_done_o <= '1';
                        end if;
                        gbt_tx_ic_elink_o <= tx_frame(sender_frame_pos + 1) & tx_frame(sender_frame_pos);
                    when others =>
                        gbt_tx_ic_elink_o <= "11";
                        sender_state <= IDLE;
                end case;
                
            end if;
        end if;
    end process;

end Behavioral;
