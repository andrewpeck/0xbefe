----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid v3 Firmware -- GBT Rx Parser
-- A. Peck
----------------------------------------------------------------------------------
-- Description:
--   This module decodes received GBT frames and outputs a wishbone request
----------------------------------------------------------------------------------
-- 2017/07/24 -- Removal of VFAT2 event building
-- 2017/08/03 -- Addition of 10 bit decoding for OHv3a w/ 1x 80Mhz + 1x 320 Mhz
-- 2017/11/07 -- Add idle state
-- 2018/09/27 -- Conversion to single-link 6b8b format
-- 2018/09/28 -- Cleanup of module and conversion to generic frame sizes
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity gbt_rx is
  generic(
    WB_REQ_BITS       : integer := 49;  -- number of bits in a wishbone request
    g_FRAME_COUNT_MAX : integer := 8;   -- number of frames in a request packet
    g_FRAME_WIDTH     : integer := 6;   -- number of data bits per frame
    g_READY_COUNT_MAX : integer := 64   -- number of good consecutive frames to mark the output as ready
    );
  port(

    -- reset
    reset_i : in std_logic;

    -- 40 MHz fabric clock
    clock : in std_logic;

    -- parallel data input from deserializer
    data_i : in std_logic_vector(7 downto 0);

    -- decoded ttc commands
    l1a_o    : out std_logic;
    bc0_o    : out std_logic;
    resync_o : out std_logic;

    -- 49 bit output packet to fifo
    req_en_o   : out std_logic;
    req_data_o : out std_logic_vector(WB_REQ_BITS-1 downto 0) := (others => '0');

    -- status
    ready_o : out std_logic;
    error_o : out std_logic

    );
end gbt_rx;

architecture Behavioral of gbt_rx is

  type state_t is (ERR, SYNCING, IDLE, HEADER, START, DATA);

  signal req_valid    : std_logic;
  signal req_data_buf : std_logic_vector(WB_REQ_BITS-1 downto 0) := (others => '0');

  signal state : state_t := SYNCING;

  signal data_frame_cnt : integer range 0 to g_FRAME_COUNT_MAX-1 := 0;

  signal ready_cnt : integer range 0 to g_READY_COUNT_MAX-1 := 0;
  signal ready     : std_logic;

  signal frame_data       : std_logic_vector (5 downto 0);
  signal frame_data_delay : std_logic_vector (5 downto 0);

  signal char_is_data   : std_logic;
  signal char_is_ttc    : std_logic;
  signal char_is_header : std_logic;
  signal not_in_table   : std_logic;

  signal reset : std_logic;

  signal last_data_frame : std_logic;

  signal l1a     : std_logic;
  signal bc0     : std_logic;
  signal idle_rx : std_logic;
  signal resync  : std_logic;

begin

  -- fanout reset tree

  process (clock)
  begin
    if (rising_edge(clock)) then
      reset <= reset_i;
    end if;
  end process;

  --== ERROR ==--

  process(clock)
  begin
    if (rising_edge(clock)) then

      if (ready = '1') then
        if (STATE = ERR) then error_o <= '1';
        else error_o                  <= '0';
        end if;
      else
        if (idle_rx = '1' or char_is_ttc = '1') then error_o <= '0';
        else error_o                                         <= '1';
        end if;
      end if;

    end if;
  end process;

  --== TTC ==--

  process(clock)
  begin
    if (rising_edge(clock)) then
      if (reset = '1') then
        l1a_o    <= '0';
        resync_o <= '0';
        bc0_o    <= '0';
      else
        l1a_o    <= ready and l1a;
        resync_o <= ready and resync;
        bc0_o    <= ready and bc0;
      end if;
    end if;
  end process;

  process (clock)
  begin
    if (rising_edge(clock)) then

      if (reset = '1' or state = ERR) then
        ready_cnt <= 0;
      elsif ((idle_rx = '1' or char_is_ttc = '1') and (ready_cnt < g_READY_COUNT_MAX-1)) then
        ready_cnt <= ready_cnt + 1;
      end if;

    end if;
  end process;

  ready <= '1' when (ready_cnt = g_READY_COUNT_MAX-1) else '0';

  ready_o <= ready;

  -- 8b to 6b conversion
  eightbit_sixbit_inst : entity work.eightbit_sixbit
    port map (
      clock          => clock,
      eightbit       => data_i,
      sixbit         => frame_data,
      not_in_table   => not_in_table,
      char_is_data   => char_is_data,
      char_is_ttc    => char_is_ttc,
      char_is_header => char_is_header,
      l1a            => l1a,
      bc0            => bc0,
      resync         => resync,
      idle           => idle_rx
      );

  process (clock)
  begin
    if (rising_edge(clock)) then
      -- only latch if char_is_data so that we can "pause" the sequencer if a ttc command is received
      -- during a packet
      if (char_is_data = '1') then frame_data_delay <= frame_data;
      else frame_data_delay                         <= frame_data_delay;
      end if;
    end if;
  end process;

  process(clock)
  begin
    if (rising_edge(clock)) then

      if (reset = '1') then
        state          <= SYNCING;
        data_frame_cnt <= 0;
      elsif (not_in_table = '1') then
        state          <= ERR;
        data_frame_cnt <= 0;
      else
        case state is

          when ERR =>

            if (not_in_table = '0') then
              state          <= SYNCING;
              data_frame_cnt <= 0;
            end if;

          when SYNCING =>

            if (ready = '1') then
              state <= IDLE;
            end if;
            data_frame_cnt <= 0;

          when IDLE =>

            if (char_is_header = '1') then
              state <= HEADER;
            end if;
            data_frame_cnt <= 0;

          when HEADER =>

            if (char_is_ttc = '1') then state     <= HEADER;
            elsif (char_is_data = '1') then state <= START;
            else state                            <= ERR;
            end if;
            data_frame_cnt                        <= 0;

          when START =>

            if (char_is_ttc = '1') then state     <= START;
            elsif (char_is_data = '1') then state <= DATA;
            else state                            <= ERR;
            end if;
            data_frame_cnt                        <= 0;

          when DATA =>

            if (char_is_ttc = '1') then

              state <= DATA;

            elsif (data_frame_cnt = g_FRAME_COUNT_MAX-1) then

              data_frame_cnt <= 0;

              if (char_is_data = '1') then state <= START;  -- process consecutive frames
              elsif (idle_rx = '1') then state   <= IDLE;  -- or go back to idle
              end if;

            else
              if (char_is_data = '0') then
                state          <= ERR;
                data_frame_cnt <= 0;
              else
                data_frame_cnt <= data_frame_cnt + 1;
              end if;

            end if;

          when others => state <= ERR;

        end case;
      end if;
    end if;
  end process;

  --== REQUEST ==--

  process(clock)
  begin
    if (rising_edge(clock)) then

      -- latch request after data frame 4
      if (state = DATA and ((g_FRAME_COUNT_MAX-1) = data_frame_cnt) and char_is_ttc = '0') then
        last_data_frame <= '1';
      else
        last_data_frame <= '0';
      end if;

      if (last_data_frame = '1') then
        req_en_o   <= req_valid;        -- fifo_wr
        req_data_o <= req_data_buf;  -- 49 bit stable output (1 bit WE, 16 bit adr, 32 bit data)
      else
        req_en_o <= '0';
      end if;

      if (reset = '1' or ready = '0') then
        req_valid <= '0';
      else
        case state is
          when SYNCING => req_valid <= '0';
          when IDLE    => req_valid <= '0';
          when HEADER  => req_valid <= '0';
          when START   => req_valid <= frame_data_delay(5);  -- request valid
                        req_data_buf(WB_REQ_BITS-1) <= frame_data_delay(4);  -- write enable
          -- reserved                    <= frame_data(3 downto 0);
          when DATA => req_data_buf (
            (g_FRAME_COUNT_MAX - data_frame_cnt) * g_FRAME_WIDTH - 1 downto
            (g_FRAME_COUNT_MAX-1-data_frame_cnt) * g_FRAME_WIDTH) <= frame_data_delay;
          when others => req_valid <= '0';

        end case;
      end if;
    end if;
  end process;


end Behavioral;
