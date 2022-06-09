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

use work.common_pkg.all;

entity gbt_ic_controller is
    generic(
        g_DEBUG			: boolean
        --        g_GBTX_I2C_ADDRESS      : std_logic_vector(3 downto 0) := x"1"
    );
    port(
        -- reset
        reset_i                 : in  std_logic;

        -- clocks
        gbt_clk_i               : in std_logic;

        -- lpGBT version 0 or 1
        gbt_version_i             : in std_logic;

        -- GBTx I2C address (for OHv2b it should be always 0x1 because that's hardwired on the board), but 0 can be used for broadcast
        gbtx_i2c_address        : in std_logic_vector(6 downto 0);

        -- GBTx IC elinks
        gbt_rx_ic_elink_i       : in  std_logic_vector(1 downto 0);
        gbt_tx_ic_elink_o       : out std_logic_vector(1 downto 0);

        -- Control
        ic_rw_address_i         : in  std_logic_vector(15 downto 0);
        ic_w_data_i             : in  std_logic_vector(31 downto 0);
        ic_r_data_o             : out std_logic_vector(31 downto 0);
        ic_rw_length_i          : in std_logic_vector(2 downto 0);
        ic_write_req_i          : in std_logic;
        ic_write_done_o         : out std_logic;
        ic_read_req_i           : in std_logic;
        ic_read_valid_o         : out std_logic;
        ic_read_done_o          : out std_logic;
        ic_read_stat_o          : out std_logic_vector(5 downto 0)

    );
end gbt_ic_controller;

architecture Behavioral of gbt_ic_controller is

    COMPONENT ila_ic_rx

        PORT (
            clk : IN STD_LOGIC;

            probe0 : IN STD_LOGIC;
            probe1 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            probe2 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            probe3 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            probe4 : IN STD_LOGIC;
            probe5 : IN STD_LOGIC;
            probe6 : IN STD_LOGIC;
            probe7 : IN STD_LOGIC;
            probe8 : IN STD_LOGIC;
            probe9 : IN STD_LOGIC;
            probe10 : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
            probe11 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
            probe12 : IN STD_LOGIC_VECTOR(15 DOWNTO 0)
        );
    END COMPONENT  ;

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

    -------------- rx IC -----------------
    signal rx_data_from_gbtx     : std_logic_vector(7 downto 0);
    signal ic_r_valid            : std_logic;
    signal ic_rx_empty           : std_logic;
    signal ic_r_data           : std_logic_vector(31 downto 0);
    -- IC rx error status
    signal wr                    : std_logic;
    signal ic_err                : std_logic;
    signal ic_uplink_parity_ok   : std_logic;
    signal ic_downlink_parity_ok : std_logic;
    signal ic_chip_adr           : std_logic_vector(6 downto 0);
    signal ic_length             : std_logic_vector(15 downto 0);
    signal ic_reg_adr            : std_logic_vector(15 downto 0);

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
                            -- Frames are different for lpGBT version 0 and 1
                            if gbt_version_i = '0' then
                                tx_frame(47 downto 0) <= x"000" & "0" & ic_rw_length_i &                     -- LENGTH
                                                         x"01" &                                             -- CMD
                                                         gbtx_i2c_address & not ic_write_req_i &             -- I2C ADDRESS + read flag
                                                         x"00" &                                             -- RSVD, reserved byte should be set to 0
                                                         SOF_EOF;                                            -- SOF
                                tx_frame(127 downto 48) <= (others => '1');
                                ser_frame_pos <= 48;
                                ser_parity <= ((x"01" xor ("00000" & ic_rw_length_i)) xor ic_rw_address_i(7 downto 0)) xor ic_rw_address_i(15 downto 8) ;
                            else
                                tx_frame(39 downto 0) <= x"000" & "0" & ic_rw_length_i &                     -- LENGTH
                                                         x"01" &                                             -- CMD
                                                         gbtx_i2c_address & not ic_write_req_i &             -- I2C ADDRESS + read flag
                                                         SOF_EOF;                                            -- SOF                           
                                tx_frame(127 downto 40) <= (others => '1');
                                ser_frame_pos <= 40;
                                ser_parity <= ((((gbtx_i2c_address & not ic_write_req_i) xor x"01") xor ("00000" & ic_rw_length_i)) xor ic_rw_address_i(7 downto 0)) xor ic_rw_address_i(15 downto 8) ;
                            end if;
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
    --========= IC RX =========--

    -- ILA Debug IC RX --
    ila_enable : if g_DEBUG generate

        i_gbt_ila_ix_rx : ila_ic_rx
            PORT MAP (
                clk => gbt_clk_i,

                probe0 => ic_rx_empty,
                probe1 => gbt_rx_ic_elink_i,
                probe2 => rx_data_from_gbtx,
                probe3 => ic_r_data,
                probe4 => ic_r_valid,
                probe5 => ic_read_req_i,
                probe6 => ic_write_req_i,
                probe7 => ic_err,
                probe8 => ic_uplink_parity_ok,
                probe9 => ic_downlink_parity_ok,
                probe10 => ic_chip_adr,
                probe11 => ic_length,
                probe12 => ic_reg_adr
            );

    end generate;


    -- instantiate ic rx module (CERN module) to desirialize 2 elink bits to 8 bit words

    i_ic_rx     : entity work.ic_rx
        generic map (
            g_FIFO_DEPTH    => 20
        )
        port map(
            -- Clock and reset
            rx_clk_i        => gbt_clk_i,
            rx_clk_en       => '1',

            reset_i         => reset_i,

            -- Status>
            --rx_empty_o      => ic_rx_empty,
            wr_o            => wr,

            -- Internal FIFO
            rd_clk_i        => gbt_clk_i,
            rd_i            => '1',
            data_o          => rx_data_from_gbtx,

            -- IC line
            rx_data_i       => gbt_rx_ic_elink_i(0) & gbt_rx_ic_elink_i(1)

        );
    -- gbt_ic_rx module is finite state machine for rx frame
    i_gbt_ic_rx : entity work.gbt_ic_rx
        port map(
            clock_i                 => gbt_clk_i,
            reset_i                 => reset_i,

            frame_i                 => rx_data_from_gbtx,
            valid_i                 => wr,

            lpgbt_version           => gbt_version_i,

            -- Control
            chip_adr_o              => ic_chip_adr,
            data_o                  => ic_r_data,
            length_o                => ic_length,
            reg_adr_o               => ic_reg_adr,
            uplink_parity_ok_o      => ic_uplink_parity_ok,
            downlink_parity_ok_o    => ic_downlink_parity_ok,
            err_o                   => ic_err,
            valid_o                 => ic_r_valid
        );

    ic_r_data_o <= ic_r_data;

    -- IC rx error control
    process(gbt_clk_i)
    begin
        if (rising_edge(gbt_clk_i)) then

            if (ic_write_req_i = '1' or ic_read_req_i = '1') then
                ic_read_done_o    <= '0';
                ic_read_stat_o    <= (others => '0');
            end if;

            if (ic_r_valid = '1') then
                ic_read_done_o    <= '1';
                ic_read_stat_o(0) <= not ic_err;
                ic_read_stat_o(1) <= ic_uplink_parity_ok;
                ic_read_stat_o(2) <= ic_downlink_parity_ok;

                if (ic_chip_adr = gbtx_i2c_address) then
                    ic_read_stat_o(3) <= '1';
                end if;
    
                if (ic_length(2 downto 0) = ic_rw_length_i) then
                    ic_read_stat_o(4) <= '1';
                end if;
    
                if (ic_reg_adr = ic_rw_address_i) then
                    ic_read_stat_o(5) <= '1';
                end if;
                
            end if;
            
        end if;
    end process;

    ic_read_valid_o <= ic_read_done_o and ic_read_stat_o(0) and ic_read_stat_o(1) and ic_read_stat_o(3) and ic_read_stat_o(4) and ic_read_stat_o(5);

end Behavioral;
