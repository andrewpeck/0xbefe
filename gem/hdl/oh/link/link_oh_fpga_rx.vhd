----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- E. Juska, A. Peck
----------------------------------------------------------------------------------
-- This module decodes packets in the slow control path from
--  backend -> OH and from OH -> backend
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

entity link_oh_fpga_rx is
  generic(
    WB_REQ_BITS       : integer := 49;  -- number of bits in a wishbone request
    g_READY_COUNT_MAX : integer := 64  -- number of good consecutive frames to mark the output as ready
    );
  port(

    -- reset + 40MHz clock
    reset_i : in std_logic;
    clock   : in std_logic;

    -- parallel data input from deserializer
    elink_data_i : in std_logic_vector(7 downto 0);

    -- decoded ttc commands
    l1a_o    : out std_logic;
    bc0_o    : out std_logic;
    resync_o : out std_logic;

    -- 49 bit output packet to fifo
    req_en_o   : out std_logic;
    req_data_o : out std_logic_vector(31 downto 0);
    req_addr_o : out std_logic_vector(15 downto 0);
    req_wr_o   : out std_logic;

    -- status
    ready_o        : out std_logic;
    error_o        : out std_logic;
    crc_error_o    : out std_logic;
    precrc_error_o : out std_logic

    );
end link_oh_fpga_rx;

architecture Behavioral of link_oh_fpga_rx is

  constant BITSLIP_ERR_CNT_MAX : integer := g_READY_COUNT_MAX*2;

  type state_t is (SYNCING, IDLE, PRE_CRC, DATA, CRC_CALC, CRC, DONE);

  signal req_valid : std_logic;
  signal req       : std_logic_vector(51 downto 0) := (others => '0');

  signal state : state_t := SYNCING;

  constant FRAME_CNT_MAX : integer := req'length / 4;

  signal data_frame_cnt : integer range 0 to FRAME_CNT_MAX-1 := 0;

  signal ready_cnt : integer range 0 to g_READY_COUNT_MAX-1 := 0;
  signal ready     : std_logic;

  signal reset : std_logic;

  signal precrc_rdy  : std_logic;  -- during syncing the first precrc will always be bad
  signal precrc_rx   : std_logic_vector (7 downto 0) := (others => '0');
  signal precrc_calc : std_logic_vector (7 downto 0) := (others => '0');
  signal crc_rx      : std_logic_vector (7 downto 0) := (others => '0');
  signal crc_data    : std_logic_vector (7 downto 0) := (others => '0');
  signal crc_data_r  : std_logic_vector (7 downto 0) := (others => '0');
  signal crc_en      : std_logic                     := '0';
  signal crc_rst     : std_logic                     := '0';
  signal crc_ok      : std_logic                     := '0';

  signal special_bit : std_logic := '0';

  signal idle_cnt, idle_cnt_next : integer range 0 to 15;

  signal data_slip       : std_logic_vector(7 downto 0);
  signal data_slip_r1    : std_logic_vector(7 downto 0);
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
      g_DATA_WIDTH     => 8,
      g_SLIP_CNT_WIDTH => 3
      )
    port map (
      clk_i      => clock,
      slip_cnt_i => bitslip_cnt_slv,
      data_i     => elink_data_i,
      data_o     => data_slip
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

  idle_cnt <= to_integer(unsigned(data_slip(3 downto 0)));

  -- sync to the special bit 0x80 pattern
  process (clock)
  begin
    if (rising_edge(clock)) then

      if (idle_cnt = 15) then
        idle_cnt_next <= 0;
      else
        idle_cnt_next <= idle_cnt + 1;
      end if;

      if (reset = '1' or error_detect = '1') then
        ready_cnt <= 0;
      elsif (ready_cnt < g_READY_COUNT_MAX-1) then
        ready_cnt <= ready_cnt + 1;
      end if;
    end if;
  end process;

  ready <= '1' when (ready_cnt = g_READY_COUNT_MAX-1) else '0';

  ready_o <= ready;

  --------------------------------------------------------------------------------
  -- CRC
  --------------------------------------------------------------------------------

  process (clock) is
  begin
    if (rising_edge(clock)) then

      data_slip_r1 <= data_slip;

      if (reset = '1' or state = SYNCING) then
        precrc_rdy <= '0';
      elsif (ready = '1' and state = DONE) then
        precrc_rdy <= '1';
      end if;

    end if;
  end process;

  oh_gbt_crc_inst : entity work.oh_gbt_crc
    port map (
      data_in => data_slip_r1,
      crc_en  => crc_en,
      rst     => crc_rst,
      clk     => clock,
      crc_out => crc_data
      );

  --------------------------------------------------------------------------------
  -- State machine
  --------------------------------------------------------------------------------


  process(clock)
  begin
    if (rising_edge(clock)) then

      error_detect   <= '0';
      req_en_o       <= '0';
      crc_en         <= '0';
      crc_rst        <= '0';
      crc_error_o    <= '0';
      precrc_error_o <= '0';

      case state is

        when SYNCING =>

          crc_rst <= '1';

          if (data_slip(7) /= '1' or idle_cnt /= idle_cnt_next) then
            error_detect <= '1';
          elsif (ready = '1') then
            state <= IDLE;
          end if;

        when IDLE =>

          if (special_bit = '1' and idle_cnt /= idle_cnt_next) then
            state        <= SYNCING;
            error_detect <= '1';
          elsif (special_bit = '0') then
            state                 <= PRE_CRC;
            precrc_rx(3 downto 0) <= data_slip(3 downto 0);
            precrc_calc           <= crc_data;
            data_frame_cnt        <= 1;
          else
            crc_en         <= '1';
            data_frame_cnt <= 0;
          end if;

        when PRE_CRC =>

          crc_rst        <= '1';
          data_frame_cnt <= 0;

          if (special_bit = '1') then
            state        <= SYNCING;
            error_detect <= '1';
          else
            state                  <= DATA;
            precrc_rx (7 downto 4) <= data_slip (3 downto 0);
          end if;


        when DATA =>

          if (precrc_rdy = '1' and data_frame_cnt = 0 and precrc_calc /= precrc_rx) then
            precrc_error_o <= '1';
          end if;

          crc_en <= '1';

          if (special_bit = '1') then
            state        <= SYNCING;
            error_detect <= '1';
          elsif (data_frame_cnt = FRAME_CNT_MAX - 1) then
            data_frame_cnt <= 0;
            state          <= CRC_CALC;
          else
            data_frame_cnt <= data_frame_cnt + 1;
            state          <= DATA;
          end if;

          req((data_frame_cnt+1)*4 -1 downto data_frame_cnt * 4) <= data_slip (3 downto 0);

        when CRC_CALC =>

          state <= CRC;

        when CRC =>

          if (special_bit = '1') then
            state        <= SYNCING;
            error_detect <= '1';
          elsif (data_frame_cnt = 1) then
            data_frame_cnt <= 0;
            state          <= DONE;
            crc_rst        <= '1';
          else
            crc_data_r     <= crc_data;
            data_frame_cnt <= data_frame_cnt + 1;
            state          <= CRC;
          end if;

          crc_rx((data_frame_cnt+1)*4 -1 downto data_frame_cnt * 4) <= data_slip (3 downto 0);

        when DONE =>

          state  <= IDLE;
          crc_en <= '1';

          if (crc_data_r = crc_rx) then
            req_data_o <= req(31 downto 0);
            req_addr_o <= req(47 downto 32);
            req_wr_o   <= req(48);
            req_en_o   <= '1';
          else
            crc_error_o <= '1';
          end if;

      end case;

      if (reset_i = '1') then
        state   <= IDLE;
        crc_rst <= '1';
      end if;

    end if;
  end process;

end Behavioral;
