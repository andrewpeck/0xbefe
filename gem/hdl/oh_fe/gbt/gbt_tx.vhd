----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid v3 Firmware -- GBT Transmit Packet Builder
-- A. Peck
----------------------------------------------------------------------------------
-- Description:
--   This module generates data packets for transmission to the CTP-7
--   takes 32 bit register data and formats it into frames for transmission on elinks
----------------------------------------------------------------------------------
-- 2017/07/24 -- Initial working version adapted from v2
-- 2017/08/09 -- Add "10 bit" transmit mode for OHv3a
-- 2018/09/27 -- Convert to sixbit_eightbit, single elink encoding
-- 2018/09/28 -- Some cleanup and simplification of the source code
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library work;

entity gbt_tx is
  generic(
    g_FRAME_COUNT_MAX : integer := 6;
    g_FRAME_WIDTH     : integer := 6
    );
  port(
    clock : in std_logic;

    reset_i : in std_logic;

    data_o : out std_logic_vector(7 downto 0);

    req_en_o    : out std_logic;
    req_valid_i : in  std_logic;        --valid request from fifo
    req_data_i  : in  std_logic_vector(31 downto 0)
    );
end gbt_tx;

architecture Behavioral of gbt_tx is

  type state_t is (IDLE, HEADER, DATA);

  signal state : state_t := IDLE;

  signal data_frame_cnt : integer range 0 to (g_FRAME_COUNT_MAX-1) := 0;

  signal req_valid : std_logic;
  signal frame     : std_logic_vector (g_FRAME_COUNT_MAX-1 downto 0);
  signal reg_data  : std_logic_vector (g_FRAME_COUNT_MAX*g_FRAME_WIDTH-1 downto 0);  -- multiples of 6

  signal send_idle   : std_logic;
  signal send_header : std_logic;

  signal reset : std_logic;

begin

  reg_data <= x"0" & req_data_i;

  -- fanout reset tree

  process (clock)
  begin
    if (rising_edge(clock)) then
      reset <= reset_i;
    end if;
  end process;


  process(clock)
  begin
    if (rising_edge(clock)) then
      if (reset = '1') then
        state <= IDLE;
      else
        case state is

          when IDLE =>

            data_frame_cnt <= 0;

            if (req_valid_i = '1') then
              state <= HEADER;
            end if;

          when HEADER =>

            state <= DATA;

          when DATA =>

            if (data_frame_cnt = (g_FRAME_COUNT_MAX-1)) then

              data_frame_cnt <= 0;

              if (req_valid_i = '1') then
                state <= DATA;
              else
                state <= IDLE;
              end if;
            else
              data_frame_cnt <= data_frame_cnt + 1;
            end if;

          when others =>
            state <= IDLE;
        end case;
      end if;
    end if;
  end process;

  --== REQUEST and TRACKING DATA==--

  process(clock)
  begin
    if (rising_edge(clock)) then
      if (reset = '1') then
        req_en_o <= '0'; req_valid <= '0';
      else
        case state is
          when IDLE =>
            send_idle   <= '1';
            send_header <= '0';
            req_en_o    <= '1';
            req_valid   <= req_valid_i;
          when HEADER =>
            send_idle   <= '0';
            send_header <= '1';
            req_en_o    <= '0';
            req_valid   <= req_valid_i;
          when DATA =>
            send_header <= '0';
            send_idle   <= '0';
            req_en_o    <= '0';
            if (data_frame_cnt = (g_FRAME_COUNT_MAX-1)) then
              req_valid <= req_valid_i;
            end if;

          when others => send_idle <= '1'; req_en_o <= '0'; req_valid <= '0'; send_header <= '0';

        end case;
      end if;
    end if;
  end process;

  --== SEND ==--

  process(clock)
  begin
    if (rising_edge(clock)) then
      if (reset = '1') then
        frame <= (others => '0');
      else
        case state is
          when IDLE   => frame <= "00" & x"0";
          when HEADER => frame <= "00" & x"0";
          when DATA   => frame <= reg_data((g_FRAME_COUNT_MAX - data_frame_cnt) * g_FRAME_WIDTH - 1 downto (g_FRAME_COUNT_MAX-1-data_frame_cnt) * g_FRAME_WIDTH);
          when others => frame <= (others => '0');
        end case;
      end if;
    end if;
  end process;

  -- 8b to 6b conversion
  sixbit_eightbit_inst : entity work.sixbit_eightbit
    port map (
      clock    => clock,
      eightbit => data_o,
      sixbit   => frame,
      --ttc
      l1a      => '0',
      bc0      => '0',
      resync   => '0',
      --frame control
      header   => send_header,
      idle     => send_idle
      );

end Behavioral;
