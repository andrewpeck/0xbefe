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

library unisim;
use unisim.vcomponents.all;

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

  type state_t is (IDLE, HEADER, START, DATA);


  signal state          : state_t                                := IDLE;
  signal data_frame_cnt : integer range 0 to g_FRAME_COUNT_MAX-1 := 0;

  signal elink_data : std_logic_vector(7 downto 0);
  signal frame_data : std_logic_vector(g_FRAME_WIDTH-1 downto 0);

  signal reg_data : std_logic_vector(47 downto 0);

  signal send_idle       : std_logic;
  signal send_header     : std_logic;
  signal send_idle_reg   : std_logic;
  signal send_header_reg : std_logic;
  signal ttc_cmd_rx      : std_logic;

  signal l1a    : std_logic;
  signal bc0    : std_logic;
  signal resync : std_logic;

begin

  busy_o     <= '0' when state = IDLE                                   else '1';
  ttc_cmd_rx <= '1' when (l1a_i = '1' or resync_i = '1' or bc0_i = '1') else '0';

  process(ttc_clk_40_i)
  begin
    if (rising_edge(ttc_clk_40_i)) then
      if (state = START) then
        reg_data <= request_addr_i & request_data_i;
      end if;
    end if;
  end process;

  -- need to delay ttc signals to encoder so that state machine has time to "pause" while
  -- ttc signals are being sent

  process(ttc_clk_40_i)
  begin
    if (rising_edge(ttc_clk_40_i)) then
      l1a    <= l1a_i;
      bc0    <= bc0_i;
      resync <= resync_i;
    end if;
  end process;

  --== State FSM ==--

  process(ttc_clk_40_i)
  begin
    if (rising_edge(ttc_clk_40_i)) then
      if (reset_i = '1') then
        state          <= IDLE;
        data_frame_cnt <= 0;
      else
        case state is

          when IDLE =>

            data_frame_cnt <= 0;

            if (request_valid_i = '1') then
              state <= HEADER;
            end if;

          when HEADER =>

            data_frame_cnt <= 0;

            -- ttc command not received; send header on next available cycle
            if (ttc_cmd_rx = '0') then
              state <= START;
            end if;


          when START =>

            data_frame_cnt <= 0;

            -- ttc command not received; send start on next available cycle
            if (ttc_cmd_rx = '0') then
              state <= DATA;
            end if;

          when DATA =>

            -- ttc command received; send data frame on next available cycle
            if (ttc_cmd_rx = '0') then
              if (data_frame_cnt = g_FRAME_COUNT_MAX-1) then
                data_frame_cnt <= 0;
                if (request_valid_i = '1') then
                  state <= START;
                else
                  state <= IDLE;
                end if;
              else
                data_frame_cnt <= data_frame_cnt + 1;
              end if;
            end if;

          when others =>
            state          <= IDLE;
            data_frame_cnt <= 0;
        end case;
      end if;
    end if;
  end process;

  --== Data transmission ==--

  send_header <= '1' when state = HEADER else '0';
  send_idle   <= '1' when state = IDLE   else '0';

  process(ttc_clk_40_i)
  begin
    if (rising_edge(ttc_clk_40_i)) then

      send_header_reg <= send_header;
      send_idle_reg   <= send_idle;

      if (reset_i = '1') then
        frame_data <= (others => '0');
      else
        case state is
          when IDLE =>
            frame_data <= "000000";
          when HEADER =>
            frame_data <= "000000";
          when START =>
            frame_data <= "1" & request_write_i & x"b";
          when DATA =>
            frame_data <= reg_data(((g_FRAME_COUNT_MAX - data_frame_cnt) * g_FRAME_WIDTH) - 1 downto (g_FRAME_COUNT_MAX-1-data_frame_cnt)*g_FRAME_WIDTH);
          when others =>
            frame_data <= (others => '0');
        end case;
      end if;
    end if;
  end process;

  -- 8b to 6b conversion
  sixbit_eightbit_inst : entity work.sixbit_eightbit
    port map (
      clock    => ttc_clk_40_i,
      sixbit   => frame_data,           -- 6 bit data input
      eightbit => elink_data,           -- 8 bit encoded output
      l1a      => l1a,                  -- send l1a
      bc0      => bc0,                  -- send bc0
      resync   => resync,               -- send resync character
      header   => send_header_reg,      -- send header character
      idle     => send_idle_reg         -- send idle
      );

  process(ttc_clk_40_i)
  begin
    if (rising_edge(ttc_clk_40_i)) then
      elink_data_o <= elink_data;
    end if;
  end process;

end link_oh_fpga_tx_arch;
