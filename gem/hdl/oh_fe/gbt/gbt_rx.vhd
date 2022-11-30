----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid v3 Firmware -- GBT Rx Parser
-- A. Peck
----------------------------------------------------------------------------------
-- Description:
--   This module decodes received GBT frames and outputs a wishbone request
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

entity gbt_rx is
  generic(
    WB_REQ_BITS         : integer := 49;  -- number of bits in a wishbone request
    g_READY_COUNT_MAX   : integer := 64  -- number of good consecutive frames to mark the output as ready
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

  constant BITSLIP_ERR_CNT_MAX : integer := g_READY_COUNT_MAX*2;

  type state_t is (ERR, SYNCING, IDLE, DATA, CRC, DONE);

  signal req_valid : std_logic;
  signal req_data  : std_logic_vector(51 downto 0) := (others => '0');

  signal state : state_t := SYNCING;

  constant FRAME_CNT_MAX : integer := req_data'length / 4;

  signal data_frame_cnt : integer range 0 to FRAME_CNT_MAX-1 := 0;

  signal ready_cnt : integer range 0 to g_READY_COUNT_MAX-1 := 0;
  signal ready     : std_logic;

  signal reset : std_logic;

  signal crc_rx : std_logic_vector (7 downto 0) := (others => '0');

  signal special_bit : std_logic := '0';

  signal data_slip       : std_logic_vector(7 downto 0);
  signal bitslip_cnt     : integer range 0 to 7                     := 0;
  signal bitslip_err_cnt : integer range 0 to BITSLIP_ERR_CNT_MAX-1 := 0;
  signal bitslip_cnt_slv : std_logic_vector (2 downto 0)            := (others => '0');


  signal error_detect : std_logic := '0';

begin

  special_bit <= data_slip(7);
  reset       <= reset_i;
  error_o     <= error_detect;

  --------------------------------------------------------------------------------
  -- Bitslip
  --------------------------------------------------------------------------------

  process (clock)
  begin
    if (rising_edge(clock)) then
      if (ready = '1') then
        bitslip_err_cnt <= 0;
      elsif (bitslip_err_cnt = BITSLIP_ERR_CNT_MAX-1) then
        bitslip_err_cnt <= 0;
      elsif (state = SYNCING or error_detect = '1') then
        bitslip_err_cnt <= bitslip_err_cnt + 1;
      end if;
    end if;
  end process;

  process (clock)
  begin
    if (rising_edge(clock)) then
      if (bitslip_err_cnt = BITSLIP_ERR_CNT_MAX-1) then
        if (bitslip_cnt = 7) then
          bitslip_cnt <= 0;
        else
          bitslip_cnt <= bitslip_cnt + 1;
        end if;
      end if;
    end if;
  end process;

  bitslip_cnt_slv <= std_logic_vector(to_unsigned(bitslip_cnt, 3));

  bitslip_inst : entity work.bitslip
    generic map (
      g_WORD_SIZE => 8,
      g_EN_TMR    => 1
      )
    port map (
      clock       => clock,
      reset       => reset,
      bitslip_cnt => bitslip_cnt_slv,
      din         => data_i,
      dout        => data_slip
      );

  --------------------------------------------------------------------------------
  -- TTC
  --------------------------------------------------------------------------------

  process(clock)
  begin
    if (rising_edge(clock)) then
      if (ready = '0' or reset = '1') then
        l1a_o    <= '0';
        resync_o <= '0';
        bc0_o    <= '0';
      else
        l1a_o    <= data_slip(6);
        bc0_o    <= data_slip(5);
        resync_o <= data_slip(4);
      end if;
    end if;
  end process;

  -- sync to the special bit 0x80 pattern
  process (clock)
  begin
    if (rising_edge(clock)) then
      if (reset = '1' or state = ERR) then
        ready_cnt <= 0;
      elsif (data_slip = x"80" and (ready_cnt < g_READY_COUNT_MAX-1)) then
        ready_cnt <= ready_cnt + 1;
      end if;
    end if;
  end process;

  ready <= '1' when (ready_cnt = g_READY_COUNT_MAX-1) else '0';

  ready_o <= ready;

  --------------------------------------------------------------------------------
  -- State machine
  --------------------------------------------------------------------------------

  process(clock)
  begin
    if (rising_edge(clock)) then

      error_detect <= '0';
      req_en_o     <= '0';

      case state is


        when ERR =>
          error_detect <= '1';
          state        <= SYNCING;

        when SYNCING =>
          if (ready = '1') then
            state <= IDLE;
          end if;

        when IDLE =>

          if (special_bit = '0') then
            state                 <= DATA;
            req_data (3 downto 0) <= data_slip(3 downto 0);
            data_frame_cnt        <= 1;
          else
            data_frame_cnt <= 0;
          end if;

        when DATA =>

          if (special_bit = '1') then
            state <= ERR;
          elsif (data_frame_cnt = FRAME_CNT_MAX - 1) then
            data_frame_cnt <= 0;
            state          <= CRC;
          else
            data_frame_cnt <= data_frame_cnt + 1;
            state          <= DATA;
          end if;

          req_data((data_frame_cnt+1)*4 -1 downto data_frame_cnt * 4) <= data_slip (3 downto 0);

        when CRC =>

          if (special_bit = '1') then
            state <= ERR;
          elsif (data_frame_cnt = 1) then
            data_frame_cnt <= 0;
            state          <= DONE;
          else
            data_frame_cnt <= data_frame_cnt + 1;
            state          <= CRC;
          end if;

          crc_rx((data_frame_cnt+1)*4 -1 downto data_frame_cnt * 4) <= data_slip (3 downto 0);

        when DONE =>

          if (crc_rx = crc_rx) then
            req_data_o <= req_data(req_data_o'length-1 downto 0);
            req_en_o   <= '1';
            state      <= IDLE;
          else
            state <= ERR;
          end if;

      end case;
    end if;
  end process;

end Behavioral;
