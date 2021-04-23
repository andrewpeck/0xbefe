----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid v3 Firmware -- Link Request
-- T. Lenzi, A. Peck
----------------------------------------------------------------------------------
-- Description:
--   This module buffers wishbone requests to and from the OH
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.types_pkg.all;

library work;
use work.ipbus_pkg.all;
use work.hardware_pkg.all;

entity link_request is
  port(

    clock   : in std_logic;
    reset_i : in std_logic;

    ipb_mosi_o : out ipb_wbus;
    ipb_miso_i : in  ipb_rbus;

    rx_en_i   : in std_logic;
    rx_data_i : in std_logic_vector(IPB_REQ_BITS-1 downto 0);

    tx_en_i    : in  std_logic;
    tx_valid_o : out std_logic;
    tx_data_o  : out std_logic_vector(31 downto 0)

    );
end link_request;

architecture Behavioral of link_request is

  signal rd_valid     : std_logic;
  signal rd_data      : std_logic_vector(IPB_REQ_BITS-1 downto 0);
  signal tx_dout_sump : std_logic_vector(64-32-1 downto 0);
  signal rx_dout_sump : std_logic_vector(64-49-1 downto 0);

  signal rx_din : std_logic_vector (63 downto 0);
  signal tx_din : std_logic_vector (63 downto 0);

  signal rx_dout : std_logic_vector (63 downto 0);
  signal tx_dout : std_logic_vector (63 downto 0);

  component fifo is
    port (
      rst     : in  std_logic;
      clk     : in  std_logic;
      wr_en   : in  std_logic;
      din     : in  std_logic_vector;
      rd_en   : in  std_logic;
      valid   : out std_logic;
      dout    : out std_logic_vector;
      full    : out std_logic;
      empty   : out std_logic;
      sbiterr : out std_logic;
      dbiterr : out std_logic);
  end component fifo;

begin

  -- Rx Request processing

  process(clock)
  begin
    if (rising_edge(clock)) then
      if (reset_i = '1') then
        ipb_mosi_o <= (
          ipb_strobe => '0',
          ipb_write  => '0',
          ipb_addr   => (others => '0'),
          ipb_wdata  => (others => '0')
          );
      else
        if (rd_valid = '1') then
          ipb_mosi_o <= (
            ipb_strobe => '1',
            ipb_write  => rd_data(IPB_REQ_BITS-1),
            ipb_addr   => rd_data(47 downto 32),
            ipb_wdata  => rd_data(31 downto 0)
            );
        else
          ipb_mosi_o.ipb_strobe <= '0';
        end if;
      end if;
    end if;
  end process;

  rx_din(63 downto 49) <= (others => '0');
  rx_din(48 downto 0)  <= rx_data_i;
  rd_data <= rx_dout(48 downto 0);

  fifo_request_rx_inst : fifo
    port map(
      rst     => reset_i,
      clk     => clock,
      din     => rx_din,
      dout    => rx_dout,
      rd_en   => '1',
      wr_en   => rx_en_i,
      valid   => rd_valid,
      full    => open,
      empty   => open,
      sbiterr => open,
      dbiterr => open
      );

  fifo_request_tx_inst : fifo
    port map(
      rst     => reset_i,
      clk     => clock,
      wr_en   => ipb_miso_i.ipb_ack,
      din     => tx_din,
      dout    => tx_dout,
      rd_en   => tx_en_i,
      valid   => tx_valid_o,
      full    => open,
      empty   => open,
      sbiterr => open,
      dbiterr => open
      );

  tx_data_o <= tx_dout(31 downto 0);
  tx_din(31 downto 0)  <= ipb_miso_i.ipb_rdata;
  tx_din(63 downto 32) <= (others => '0');

end Behavioral;
