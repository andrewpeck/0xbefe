----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- E. Juska, A. Peck
----------------------------------------------------------------------------------
-- This module formats transmit packets in the slow control path from
--  backend -> OH and from OH -> backend
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity link_oh_fpga_tx is
    generic(
        g_FRAME_COUNT_MAX : integer := 8;
        g_FRAME_WIDTH     : integer := 6
        );
    port(

        reset_i : in std_logic;
        clock   : in std_logic;

        l1a_i    : in std_logic;
        bc0_i    : in std_logic;
        resync_i : in std_logic;

        elink_data_o : out std_logic_vector(7 downto 0);

        req_valid_i : in std_logic;
        req_write_i : in std_logic;
        req_addr_i  : in std_logic_vector(15 downto 0);
        req_data_i  : in std_logic_vector(31 downto 0);

        busy_o : out std_logic

        );
end link_oh_fpga_tx;

architecture link_oh_fpga_tx_arch of link_oh_fpga_tx is

    signal special : std_logic := '0';

    type state_t is (IDLE, DATA, CRC_CALC, CRC);
    signal state : state_t := IDLE;


    signal frame_data : std_logic_vector (3 downto 0) := (others => '0');

    signal req_data : std_logic_vector(51 downto 0);

    constant FRAME_CNT_MAX : integer := req_data'length / 4;

    signal data_frame_cnt : integer range 0 to FRAME_CNT_MAX-1 := 0;

    signal idle_counter : integer range 0 to 15 := 0;

    signal elink_data : std_logic_vector (7 downto 0);

    signal crc_data : std_logic_vector (7 downto 0) := (others => '0');
    signal crc_en   : std_logic                     := '0';
    signal crc_rst  : std_logic                     := '0';

begin


    oh_gbt_crc_inst : entity work.oh_gbt_crc
        port map (
            data_in => elink_data,
            crc_en  => crc_en,
            rst     => crc_rst,
            clk     => clock,
            crc_out => crc_data
            );

    process (clock) is
    begin
        if (rising_edge(clock)) then
            if (state = IDLE) then
                if (idle_counter = 15) then
                    idle_counter <= 0;
                else
                    idle_counter <= idle_counter + 1;
                end if;
            end if;
        end if;
    end process;

    busy_o <= '0' when state = IDLE else '1';

    process (clock)
    begin
        if (rising_edge(clock)) then

            crc_en  <= '0';
            crc_rst <= '0';

            case state is

                when IDLE =>

                    special        <= '1';
                    frame_data     <= std_logic_vector(to_unsigned(idle_counter, 4));
                    data_frame_cnt <= 0;
                    crc_rst        <= '1';

                    if (req_valid_i = '1') then
                        req_data <= "000" & req_write_i &
                                    req_addr_i &
                                    req_data_i;
                        state <= DATA;
                    end if;

                when DATA =>

                    special    <= '0';
                    frame_data <= req_data((data_frame_cnt+1)*4 -1 downto data_frame_cnt * 4);
                    crc_en     <= '1';

                    if (data_frame_cnt = FRAME_CNT_MAX - 1) then
                        data_frame_cnt <= 0;
                        state          <= CRC_CALC;
                    else
                        data_frame_cnt <= data_frame_cnt + 1;
                        state          <= DATA;
                    end if;

                when CRC_CALC =>
                    state      <= CRC;
                    frame_data <= x"0";

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

    elink_data(7)          <= special;
    elink_data(6)          <= l1a_i;
    elink_data(5)          <= bc0_i;
    elink_data(4)          <= resync_i;
    elink_data(3 downto 0) <= frame_data;

    elink_data_o <= elink_data;

end link_oh_fpga_tx_arch;
