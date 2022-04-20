------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
--           Andrew Peck
-- 
-- Create Date:    12:22 2017-11-20
-- Module Name:    sbit_monitor
-- Description:    This module monitors the sbits cluster inputs and freezes a selected
--                 link whenever a valid sbit is detected there
------------------------------------------------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.common_pkg.all;
use work.gem_pkg.all;
use work.ttc_pkg.all;

library xpm;
use xpm.vcomponents.all;

entity sbit_monitor is
  generic(
    g_NUM_OF_OHs : integer := 1;
    g_USE_FIFO   : boolean := true
    );
  port(
    -- reset
    reset_i : in std_logic;

    -- TTC
    clock : in std_logic;
    l1a_i :  in std_logic;

    -- Sbit cluster inputs
    link_select_i   : in std_logic_vector(3 downto 0);
    sbit_clusters_i : in t_oh_clusters_arr(g_NUM_OF_OHs - 1 downto 0);
    sbit_trigger_i  : in std_logic_vector(g_NUM_OF_OHs - 1 downto 0);

    -- output
    frozen_sbits_o : out t_oh_clusters;
    l1a_delay_o    : out std_logic_vector(31 downto 0);

    fifo_en_l1a_trigger_i  : in std_logic;
    fifo_en_sbit_trigger_i : in std_logic;
    fifo_trigger_delay_i   : in std_logic_vector(9 downto 0);

    fifo_rd_en_i : in  std_logic;
    fifo_valid_o : out std_logic := '0';
    fifo_empty_o : out std_logic := '1';
    fifo_data_o  : out std_logic_vector (31 downto 0) := (others => '0')
    );
end sbit_monitor;

architecture sbit_monitor_arch of sbit_monitor is

  constant ZERO_SBITS : t_oh_clusters := (others => (address => "111" & x"ff", size => "000"));

  signal armed        : std_logic := '1';
  signal link_trigger : std_logic;
  signal link_sbits   : t_oh_clusters;

  signal l1a_delay_run : std_logic := '0';
  signal l1a_delay     : unsigned(31 downto 0) := (others => '0');

begin

  l1a_delay_o <= std_logic_vector(l1a_delay);

  -- MUX to select the link
  link_trigger <= sbit_trigger_i(to_integer(unsigned(link_select_i)));
  link_sbits   <= sbit_clusters_i(to_integer(unsigned(link_select_i)));

  -- freeze the sbits on the output when a trigger comes
  process(clock)
  begin
    if (rising_edge(clock)) then
      if (reset_i = '1') then
        frozen_sbits_o <= ZERO_SBITS;
        armed          <= '1';
      else
        if (link_trigger = '1' and armed = '1') then
          frozen_sbits_o <= link_sbits;
          armed          <= '0';
        end if;
      end if;
    end if;
  end process;

  -- count the gap between this sbit cluster and the following L1A
  process(clock)
  begin
    if (rising_edge(clock)) then
      if (reset_i = '1') then
        l1a_delay     <= (others => '0');
        l1a_delay_run <= '0';
      else

        if (link_trigger = '1' and armed = '1' and l1a_delay_run = '0') then
          l1a_delay_run <= '1';
        end if;

        if (l1a_delay_run = '1' and l1a_i = '1') then
          l1a_delay_run <= '0';
        end if;

        if (l1a_delay_run = '1') then
          l1a_delay <= l1a_delay + 1;
        end if;

      end if;
    end if;
  end process;

  gen_fifo : if (g_USE_FIFO) generate

    constant SBIT_FIFO_DEPTH : integer := 512;

    type readout_state_t is (FILLING, RUNNING, TRIGGERED, EMPTY);
    signal readout_state : readout_state_t := FILLING;

    type width_converter_state_t is (IDLE, FETCHING, WORD_0, WORD_1, WORD_2, WORD_3);
    signal width_converter_state : width_converter_state_t := IDLE;

    -- fifo control / data signals
    signal wr_en      : std_logic := '0';
    signal rd_en      : std_logic := '0';
    signal rd_valid   : std_logic := '0';
    signal wr_data    : std_logic_vector (127 downto 0);
    signal rd_data    : std_logic_vector (127 downto 0);
    signal full_next  : std_logic := '0';
    signal empty_next : std_logic := '0';
    signal empty_now  : std_logic := '0';

    -- asserted to 1 when the width converter wants a new 128 bit word
    signal fetch_word      : std_logic := '0';
    signal trigger         : std_logic := '0';
    signal trigger_delayed : std_logic := '0';

  begin

    --------------------------------------------------------------------------------
    -- L1A Delay
    --------------------------------------------------------------------------------

    l1a_delay_sr : entity work.shift_reg
      generic map (
        DEPTH           => 2**fifo_trigger_delay_i'length,
        TAP_DELAY_WIDTH => fifo_trigger_delay_i'length,
        OUTPUT_REG      => false,
        SUPPORT_RESET   => false
        )
      port map (
        clk_i       => clock,
        reset_i     => '0',
        tap_delay_i => fifo_trigger_delay_i,
        data_i      => trigger,
        data_o      => trigger_delayed
        );

    --------------------------------------------------------------------------------
    -- Trigger signal
    --------------------------------------------------------------------------------

    trigger <= (fifo_en_sbit_trigger_i and link_trigger) or (fifo_en_l1a_trigger_i and l1a_i);

    --------------------------------------------------------------------------------
    -- Write data mapping
    --------------------------------------------------------------------------------

    fifo_wr_data_assign : for I in 0 to 7 generate
    begin
      wr_data ((I+1)*16-1 downto I*16) <=
        l1a_i & link_sbits(I).size & '0' & link_sbits(I).address;
    end generate;

    --------------------------------------------------------------------------------
    -- Word fetcher state machine
    --------------------------------------------------------------------------------

    -- listen for a read request from outside the module...
    -- if we get a request, then signal for a single clock that we should fetch
    -- one 128 bit word
    --
    -- once the 128 bit word is fetched, read it out 32 bits at a time
    --
    process (clock) is
    begin
      if (rising_edge(clock)) then

        fetch_word   <= '0';
        fifo_valid_o <= '0';

        case width_converter_state is

          when IDLE =>
            if (empty_now = '0' and fifo_rd_en_i = '1' and readout_state=TRIGGERED) then
              fetch_word            <= '1';
              width_converter_state <= FETCHING;
            end if;
          when FETCHING =>
            if (rd_valid = '1') then
              width_converter_state <= WORD_0;
            end if;
          when WORD_0 =>
            width_converter_state <= WORD_1;
            fifo_data_o           <= rd_data(31 downto 0);
            fifo_valid_o          <= '1';
          when WORD_1 =>
            if (fifo_rd_en_i = '1') then
              width_converter_state <= WORD_2;
              fifo_data_o           <= rd_data(63 downto 32);
              fifo_valid_o          <= '1';
            end if;
          when WORD_2 =>
            if (fifo_rd_en_i = '1') then
              width_converter_state <= WORD_3;
              fifo_data_o           <= rd_data(95 downto 64);
              fifo_valid_o          <= '1';
            end if;
          when WORD_3 =>
            if (fifo_rd_en_i = '1') then
              width_converter_state <= IDLE;
              fifo_data_o           <= rd_data(127 downto 96);
              fifo_valid_o          <= '1';
            end if;

          when others =>
              width_converter_state <= IDLE;

        end case;

        if (reset_i = '1') then
          width_converter_state <= IDLE;
          fetch_word   <= '0';
          fifo_valid_o <= '0';
        end if;

      end if;
    end process;

    --------------------------------------------------------------------------------
    -- Ring Buffer Controller
    --
    -- Fills the ring buffer with data
    --
    -- wait until a trigger is received (either an S-bit or delayed L1A),
    -- when triggered, stop reading and stop writing until the word fetcher
    -- requests a 128 bit word
    --
    -- keep reading out 128 bit words until the state machine is reset, then start
    -- taking data again
    --
    --------------------------------------------------------------------------------

    process (clock)
    begin
      if (rising_edge(clock)) then
        case readout_state is

          -- when we first start, fill the buffer
          when FILLING =>

            wr_en <= '1';
            rd_en <= '0';

            -- only one slot left
            if (full_next = '1') then
              readout_state <= RUNNING;
            end if;

          -- once the buffer is full, need to start throwing out data
          when RUNNING =>

            wr_en <= '1';
            rd_en <= '1';

            -- trigger received, freeze the buffer
            if (trigger_delayed = '1') then
              rd_en         <= '0';
              readout_state <= TRIGGERED;
            end if;

          when TRIGGERED =>

            wr_en <= '0';
            rd_en <= fetch_word;

            if (empty_now = '1') then
              readout_state <= EMPTY;
            end if;

          when EMPTY =>

            -- only leave this state with a reset
            wr_en <= '0';
            rd_en <= '0';

          when others =>

              readout_state <= FILLING;

        end case;

        if (reset_i = '1') then
          readout_state <= FILLING;
        end if;

      end if;
    end process;

    xpm_fifo_sync_inst : xpm_fifo_sync
      generic map (
        DOUT_RESET_VALUE    => "0",       -- String
        ECC_MODE            => "en_ecc",  -- String
        FIFO_MEMORY_TYPE    => "block",   -- String
        FIFO_READ_LATENCY   => 2,         -- DECIMAL
        FULL_RESET_VALUE    => 0,         -- DECIMAL
        PROG_EMPTY_THRESH   => 5,         -- DECIMAL
        PROG_FULL_THRESH    => 5,         -- DECIMAL
        read_mode           => "std",     -- String
        -- VALID(12) = 1 ;
        --
        -- AEMPTY(11) = 1;
        -- RD_DATA_CNT(10) = 0;
        -- PROG_EMPTY(9) = 0;
        -- UNDERFLOW(8) = 0;
        --
        -- WR_ACK(4) = 0;
        --
        -- AFULL(3) = 1;
        -- WR_DATA_CNT(2) = 0;
        -- PROG_FULL(1) = 0;
        -- OVERFLOW(0) = 0

        USE_ADV_FEATURES    => "1808",    -- String
        WAKEUP_TIME         => 0,         -- DECIMAL
        FIFO_WRITE_DEPTH    => SBIT_FIFO_DEPTH,     -- DECIMAL
        READ_DATA_WIDTH     => rd_data'length,  -- DECIMAL
        WRITE_DATA_WIDTH    => wr_data'length,  -- DECIMAL
        RD_DATA_COUNT_WIDTH => 1,         -- DECIMAL
        WR_DATA_COUNT_WIDTH => 1          -- DECIMAL
        )
      port map (
        almost_empty  => empty_next, -- 1-bit output: Almost Empty : When asserted, this signal indicates that only one more read can be performed before the FIFO goes to empty.
        empty         => empty_now,  -- 1-bit output: Empty Flag: When asserted, this signal indicates that the FIFO is empty. Read requests are ignored when the FIFO is empty, initiating a read while empty is not destructive to the FIFO.
        almost_full   => full_next,  -- 1-bit output: Almost Full: When asserted, this signal indicates that only one more write can be performed before the FIFO is full.
        data_valid    => rd_valid,   -- 1-bit output: Read Data Valid: When asserted, this signal indicates that valid data is available on the output bus (dout).
        dout          => rd_data,    -- READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven when reading the FIFO.
        din           => wr_data,    -- WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when writing the FIFO.
        rd_en         => rd_en,      -- 1-bit input: Read Enable: If the FIFO is not empty, asserting this signal causes data (on dout) to be read from the FIFO. Must be held active-low when rd_rst_busy is active high. .
        rst           => reset_i,    -- 1-bit input: Reset: Must be synchronous to wr_clk. Must be applied only when wr_clk is stable and free-running.
        wr_clk        => clock,      -- 1-bit input: Write clock: Used for write operation. wr_clk must be a free running clock.
        wr_en         => wr_en,      -- 1-bit input: Write Enable: If the FIFO is not full, asserting this signal causes data (on din) to be written to the FIFO Must be held active-low when rst or wr_rst_busy or rd_rst_busy is active high

        wr_data_count => open, -- WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates the number of words written into the FIFO.
        rd_data_count => open,  -- RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates the number of words read from the FIFO.
        dbiterr       => open,  -- 1-bit output: Double Bit Error: Indicates that the ECC decoder detected a double-bit error and data in the FIFO core is corrupted.
        full          => open,  -- 1-bit output: Full Flag: When asserted, this signal indicates that the FIFO is full. Write requests are ignored when the FIFO is full, initiating a write when the FIFO is full is not destructive to the contents of the FIFO.
        overflow      => open,  -- 1-bit output: Overflow: This signal indicates that a write request (wren) during the prior clock cycle was rejected, because the FIFO is full. Overflowing the FIFO is not destructive to the contents of the FIFO.
        prog_empty    => open,  -- 1-bit output: Programmable Empty: This signal is asserted when the number of words in the FIFO is less than or equal to the programmable empty threshold value. It is de-asserted when the number of words in the FIFO exceeds the programmable empty threshold value.
        prog_full     => open,  -- 1-bit output: Programmable Full: This signal is asserted when the number of words in the FIFO is greater than or equal to the programmable full threshold value. It is de-asserted when the number of words in the FIFO is less than the programmable full threshold value.
        rd_rst_busy   => open,  -- 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read domain is currently in a reset state.
        sbiterr       => open,  -- 1-bit output: Single Bit Error: Indicates that the ECC decoder detected and fixed a single-bit error.
        underflow     => open,  -- 1-bit output: Underflow: Indicates that the read request (rd_en) during the previous clock cycle was rejected because the FIFO is empty. Under flowing the FIFO is not destructive to the FIFO.
        wr_ack        => open,  -- 1-bit output: Write Acknowledge: This signal indicates that a write request (wr_en) during the prior clock cycle is succeeded.
        wr_rst_busy   => open,  -- 1-bit output: Write Reset Busy: Active-High indicator that the FIFO write domain is currently in a reset state.
        injectdbiterr => '0',   -- 1-bit input: Double Bit Error Injection: Injects a double bit error if the ECC feature is used on block RAMs or UltraRAM macros.
        injectsbiterr => '0',   -- 1-bit input: Single Bit Error Injection: Injects a single bit error if the ECC feature is used on block RAMs or UltraRAM macros.
        sleep         => '0'   -- 1-bit input: Dynamic power saving- If sleep is High, the memory/fifo block is in power saving mode.
        );

    -- don't just directly output the empty signal, since we still have a few 32
    -- bit words to read after the fifo is empty
    fifo_empty_o <= '1' when ((empty_now='1' and width_converter_state=IDLE) or wr_en='1') else '0';

  end generate;

end sbit_monitor_arch;
