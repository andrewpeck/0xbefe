----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid v3 Firmware -- GBT Link Parser
-- T. Lenzi, E. Juska, A. Peck
----------------------------------------------------------------------------------
-- Description:
--   This module counts receives builds wishbone requests received from the GBT
--   and puts them into a FIFO for handling in the OH, and takes wishbone responses
--   from the OH and builds packets to send out to the GBTx
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library work;
use work.types_pkg.all;

library work;
use work.ipbus_pkg.all;

entity gbt_link is
  generic (g_TMR_INSTANCE : integer := 0);
  port(

    -- reset
    reset_i : in std_logic;

    -- clock inputs
    clock : in std_logic;

    -- parallel data to/from serdes
    data_i : in  std_logic_vector (7 downto 0);
    data_o : out std_logic_vector(7 downto 0);

    -- wishbone
    ipb_mosi_o : out ipb_wbus;
    ipb_miso_i : in  ipb_rbus;

    -- decoded ttc
    l1a_o    : out std_logic;
    bc0_o    : out std_logic;
    resync_o : out std_logic;

    -- status
    ready_o     : out std_logic;
    error_o     : out std_logic;
    crc_error_o : out std_logic;
    unstable_o  : out std_logic

    );
end gbt_link;

architecture Behavioral of gbt_link is

  signal l1a, bc0, resync : std_logic := '0';

  signal ready       : std_logic := '0';  -- gbt rx link is good
  signal rx_unstable : std_logic := '1';  -- gbt rx link was good then went bad
  signal rx_error    : std_logic := '0';  -- error on gbt rx link
  signal crc_error   : std_logic := '0';  -- crc error on gbt rx link

  signal gbt_rx_req_valid : std_logic                                 := '0';  -- rx fifo write request
  signal gbt_rx_req       : std_logic_vector(IPB_REQ_BITS-1 downto 0) := (others => '0');

  signal gbt_rx_req_valid_reg : std_logic                                 := '0';  -- rx fifo write request
  signal gbt_rx_req_reg       : std_logic_vector(IPB_REQ_BITS-1 downto 0) := (others => '0');

  signal oh_tx_busy  : std_logic                     := '0';  -- tx fifo read request
  signal oh_tx_valid : std_logic                     := '0';  -- tx fifo data available
  signal oh_tx_data  : std_logic_vector(31 downto 0) := (others => '0');

  signal reset : std_logic := '1';

begin

  l1a_o    <= l1a;
  bc0_o    <= bc0;
  resync_o <= resync;

  -- outputs

  -- reset fanout
  process (clock)
  begin
    if (rising_edge(clock)) then
      reset <= reset_i;
    end if;
  end process;

  ready_o     <= ready;
  error_o     <= rx_error;
  crc_error_o <= crc_error;

  process (clock)
  begin
    if (rising_edge(clock)) then

      if (reset = '1') then
        rx_unstable <= '0';
      elsif (ready = '1' and (crc_error = '1' or rx_error = '1')) then
        rx_unstable <= '1';
      end if;

      unstable_o <= rx_unstable;
    end if;
  end process;

  --============--
  --== GBT RX ==--
  --============--

  gbt_rx : entity work.link_oh_fpga_rx
    port map(
      -- clock & reset
      clock   => clock,
      reset_i => reset,

      -- parallel data input from deserializer
      elink_data_i => data_i,

      -- decoded ttc commands
      l1a_o    => l1a,
      bc0_o    => bc0,
      resync_o => resync,

      req_en_o   => gbt_rx_req_valid,  -- 1 bit, wishbone request recevied from GBTx
      req_data_o => gbt_rx_req(31 downto 0),  -- 49 bit packet (1 bit we + 16 bit addr + 32 bit data)
      req_addr_o => gbt_rx_req(47 downto 32),  -- 49 bit packet (1 bit we + 16 bit addr + 32 bit data)
      req_wr_o   => gbt_rx_req(48),  -- 49 bit packet (1 bit we + 16 bit addr + 32 bit data)

      -- status
      ready_o     => ready,
      error_o     => rx_error,
      crc_error_o => crc_error
      );

  --============--
  --== GBT TX ==--
  --============--

  gbt_tx : entity work.link_oh_fpga_tx
    port map(
      -- clock & reset
      reset_i => reset,
      clock   => clock,

      --
      l1a_i    => l1a,
      bc0_i    => bc0,
      resync_i => resync,

      -- parallel data output to serializer
      elink_data_o => data_o,

      -- parallel data input from fifo
      req_valid_i => oh_tx_valid,  -- 1  bit write req from OH logic (through req fifo)
      req_write_i => gbt_rx_req(48),
      req_addr_i  => gbt_rx_req(47 downto 32),
      req_data_i  => oh_tx_data,        -- 32 bit data from OH logic

      busy_o => oh_tx_busy              -- fifo read enable

      );

  --========================--
  --== Request forwarding ==--
  --========================--

  -- create fifos to buffer between GBT and wishbone

  process (clock)
  begin
    if (rising_edge(clock)) then
      gbt_rx_req_valid_reg <= gbt_rx_req_valid;
      gbt_rx_req_reg       <= gbt_rx_req;
    end if;
  end process;

  link_request : entity work.link_request
    port map(
      -- clock & reset
      clock   => clock,                 -- 40 MHz logic clock
      reset_i => reset,

      -- rx parallel data (from GBT)
      ipb_mosi_o => ipb_mosi_o,         -- 16 bit adr + 32 bit data + we
      rx_en_i    => gbt_rx_req_valid_reg,
      rx_data_i  => gbt_rx_req_reg,     -- 16 bit adr + 32 bit data

      -- tx parallel data (to GBT)

      -- input
      ipb_miso_i => ipb_miso_i,         -- 32 bit data
      tx_en_i    => not oh_tx_busy,     -- read enable

      -- output
      tx_valid_o => oh_tx_valid,        -- data available
      tx_data_o  => oh_tx_data          -- 32 bit data
      );
end Behavioral;
