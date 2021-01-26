----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid v3 Firmware -- FIFO
-- A. Peck
----------------------------------------------------------------------------------
-- Wrapper around 7 series FIFO to avoid library problems in ISE
----------------------------------------------------------------------------------

library xpm;
use xpm.vcomponents.all;

library ieee;
use ieee.std_logic_1164.all;

entity fifo is
  generic (
    DEPTH    : integer := 512;
    WR_WIDTH : integer := 64;
    RD_WIDTH : integer := 64
    );
  port (
    rst     : in  std_logic;
    clk     : in  std_logic;
    wr_en   : in  std_logic;
    rd_en   : in  std_logic;
    din     : in  std_logic_vector(WR_WIDTH-1 downto 0);
    dout    : out std_logic_vector(RD_WIDTH-1 downto 0);
    valid   : out std_logic;
    full    : out std_logic;
    empty   : out std_logic;
    sbiterr : out std_logic;
    dbiterr : out std_logic
    );
end fifo;

architecture Behavioral of fifo is
begin

  xpm_fifo_sync_inst : xpm_fifo_sync
    generic map (
      DOUT_RESET_VALUE    => "0",       -- String
      ECC_MODE            => "en_ecc",  -- String
      FIFO_MEMORY_TYPE    => "block",   -- String
      FIFO_READ_LATENCY   => 2,         -- DECIMAL
      FULL_RESET_VALUE    => 0,         -- DECIMAL
      PROG_EMPTY_THRESH   => 3,         -- DECIMAL
      PROG_FULL_THRESH    => 3,         -- DECIMAL
      read_mode           => "std",     -- String
      USE_ADV_FEATURES    => "0707",    -- String
      WAKEUP_TIME         => 0,         -- DECIMAL
      FIFO_WRITE_DEPTH    => DEPTH,     -- DECIMAL
      READ_DATA_WIDTH     => RD_WIDTH,  -- DECIMAL
      WRITE_DATA_WIDTH    => WR_WIDTH,  -- DECIMAL
      RD_DATA_COUNT_WIDTH => 1,         -- DECIMAL
      WR_DATA_COUNT_WIDTH => 1          -- DECIMAL
      )
    port map (
      almost_empty  => open,  -- 1-bit output: Almost Empty : When asserted, this signal indicates that only one more read can be performed before the FIFO goes to empty.
      almost_full   => open,  -- 1-bit output: Almost Full: When asserted, this signal indicates that only one more write can be performed before the FIFO is full.
      data_valid    => valid, -- 1-bit output: Read Data Valid: When asserted, this signal indicates that valid data is available on the output bus (dout).
      dbiterr       => open,  -- 1-bit output: Double Bit Error: Indicates that the ECC decoder detected a double-bit error and data in the FIFO core is corrupted.
      dout          => dout,  -- READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven when reading the FIFO.
      empty         => open,  -- 1-bit output: Empty Flag: When asserted, this signal indicates that the FIFO is empty. Read requests are ignored when the FIFO is empty, initiating a read while empty is not destructive to the FIFO.
      full          => open,  -- 1-bit output: Full Flag: When asserted, this signal indicates that the FIFO is full. Write requests are ignored when the FIFO is full, initiating a write when the FIFO is full is not destructive to the contents of the FIFO.
      overflow      => open,  -- 1-bit output: Overflow: This signal indicates that a write request (wren) during the prior clock cycle was rejected, because the FIFO is full. Overflowing the FIFO is not destructive to the contents of the FIFO.
      prog_empty    => open,  -- 1-bit output: Programmable Empty: This signal is asserted when the number of words in the FIFO is less than or equal to the programmable empty threshold value. It is de-asserted when the number of words in the FIFO exceeds the programmable empty threshold value.
      prog_full     => open,  -- 1-bit output: Programmable Full: This signal is asserted when the number of words in the FIFO is greater than or equal to the programmable full threshold value. It is de-asserted when the number of words in the FIFO is less than the programmable full threshold value.
      rd_data_count => open,  -- RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates the number of words read from the FIFO.
      rd_rst_busy   => open,  -- 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read domain is currently in a reset state.
      sbiterr       => open,  -- 1-bit output: Single Bit Error: Indicates that the ECC decoder detected and fixed a single-bit error.
      underflow     => open,  -- 1-bit output: Underflow: Indicates that the read request (rd_en) during the previous clock cycle was rejected because the FIFO is empty. Under flowing the FIFO is not destructive to the FIFO.
      wr_ack        => open,  -- 1-bit output: Write Acknowledge: This signal indicates that a write request (wr_en) during the prior clock cycle is succeeded.
      wr_data_count => open,  -- WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates the number of words written into the FIFO.
      wr_rst_busy   => open,  -- 1-bit output: Write Reset Busy: Active-High indicator that the FIFO write domain is currently in a reset state.
      din           => din,   -- WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when writing the FIFO.
      injectdbiterr => '0',   -- 1-bit input: Double Bit Error Injection: Injects a double bit error if the ECC feature is used on block RAMs or UltraRAM macros.
      injectsbiterr => '0',   -- 1-bit input: Single Bit Error Injection: Injects a single bit error if the ECC feature is used on block RAMs or UltraRAM macros.
      rd_en         => rd_en, -- 1-bit input: Read Enable: If the FIFO is not empty, asserting this signal causes data (on dout) to be read from the FIFO. Must be held active-low when rd_rst_busy is active high. .
      rst           => rst,   -- 1-bit input: Reset: Must be synchronous to wr_clk. Must be applied only when wr_clk is stable and free-running.
      sleep         => '0',   -- 1-bit input: Dynamic power saving- If sleep is High, the memory/fifo block is in power saving mode.
      wr_clk        => clk,   -- 1-bit input: Write clock: Used for write operation. wr_clk must be a free running clock.
      wr_en         => wr_en  -- 1-bit input: Write Enable: If the FIFO is not full, asserting this signal causes data (on din) to be written to the FIFO Must be held active-low when rst or wr_rst_busy or rd_rst_busy is active high
      );

end Behavioral;
