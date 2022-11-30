------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    03:10 2017-11-04
-- Module Name:    link_oh_fpga_tx
-- Description:    this module handles the OH FPGA packet encoding for register access and ttc commands
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity link_oh_fpga_tx is
    generic(
        g_FRAME_COUNT_MAX : integer := 8;
        g_FRAME_WIDTH     : integer := 6
        );
    port(

        reset_i      : in std_logic;
        ttc_clk_40_i : in std_logic;

        l1a_i    : in std_logic;
        bc0_i    : in std_logic;
        resync_i : in std_logic;

        elink_data_o : out std_logic_vector(7 downto 0);

        request_valid_i : in std_logic;
        request_write_i : in std_logic;
        request_addr_i  : in std_logic_vector(15 downto 0);
        request_data_i  : in std_logic_vector(31 downto 0);

        busy_o : out std_logic

        );
end link_oh_fpga_tx;

architecture link_oh_fpga_tx_arch of link_oh_fpga_tx is

    signal special : std_logic := '0';

    type state_t is (IDLE, DATA, CRC);
    signal state : state_t := IDLE;


    signal crc_data   : std_logic_vector (7 downto 0) := (others => '0');
    signal frame_data : std_logic_vector (3 downto 0) := (others => '0');

    signal req_data : std_logic_vector(51 downto 0);

    constant FRAME_CNT_MAX : integer := req_data'length / 4;

    signal data_frame_cnt : integer range 0 to FRAME_CNT_MAX-1 := 0;

begin


    busy_o <= '0' when state = IDLE else '1';

    process (ttc_clk_40_i)
    begin
        if (rising_edge(ttc_clk_40_i)) then
            case state is

                when IDLE =>

                    special        <= '1';
                    frame_data     <= x"0";
                    data_frame_cnt <= 0;

                    if (request_valid_i = '1') then
                        req_data <= "000" & request_write_i &
                                    request_addr_i &
                                    request_data_i;
                        state <= DATA;
                    end if;

                when DATA =>

                    special    <= '0';
                    frame_data <= req_data((data_frame_cnt+1)*4 -1 downto data_frame_cnt * 4);

                    if (data_frame_cnt = FRAME_CNT_MAX - 1) then
                        data_frame_cnt <= 0;
                        state          <= CRC;
                    else
                        data_frame_cnt <= data_frame_cnt + 1;
                        state          <= DATA;
                    end if;

                when CRC =>

                    frame_data <= crc_data((data_frame_cnt+1)*4 -1 downto data_frame_cnt * 4);

                    if (data_frame_cnt = 1) then
                        data_frame_cnt <= 0;
                        state          <= IDLE;
                    else
                        data_frame_cnt <= data_frame_cnt + 1;
                        state          <= CRC;
                    end if;

                when others =>

            end case;

            if (reset_i = '1') then
                state <= IDLE;
            end if;

        end if;
    end process;

    elink_data_o(7)          <= special;
    elink_data_o(6)          <= l1a_i;
    elink_data_o(5)          <= bc0_i;
    elink_data_o(4)          <= resync_i;
    elink_data_o(3 downto 0) <= frame_data;

end link_oh_fpga_tx_arch;
