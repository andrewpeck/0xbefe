library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

entity gbt_link_tb is
  port(

    clock : in std_logic;
    reset : in std_logic;

    l1a_i, bc0_i, resync_i : in  std_logic;
    l1a_o, bc0_o, resync_o : out std_logic;

    oh_rx_ready : out std_logic;
    oh_rx_err   : out std_logic;
    be_rx_err   : out std_logic;

    request_valid_i : in  std_logic;
    request_write_i : in  std_logic;
    request_addr_i  : in  std_logic_vector(15 downto 0);
    request_data_i  : in  std_logic_vector(31 downto 0);
    busy_o          : out std_logic;

    reg_data_valid_o : out std_logic;
    reg_data_o       : out std_logic_vector(31 downto 0)

    );
end gbt_link_tb;

architecture behavioral of gbt_link_tb is

  signal backend_to_oh_elink : std_logic_vector (7 downto 0) := (others => '0');
  signal oh_to_backend_elink : std_logic_vector (7 downto 0) := (others => '0');

  -- 49 bit output packet to fifo
  signal req_en_o   : std_logic;
  signal req_data_o : std_logic_vector(48 downto 0) := (others => '0');

  signal ipb_strobe : std_logic;
  signal ipb_write  : std_logic;
  signal ipb_wdata  : std_logic_vector(31 downto 0);
  signal ipb_addr   : std_logic_vector(15 downto 0);

  signal req_valid : std_logic                      := '0';
  signal req_data  : std_logic_vector (31 downto 0) := (others => '0');

  type mem_array_t is array (integer range <>) of std_logic_vector(31 downto 0);

  signal mem : mem_array_t (2**16-1 downto 0) := (others => (others => '0'));

begin

  --------------------------------------------------------------------------------
  -- backend ~> oh tx
  --------------------------------------------------------------------------------

  link_oh_fpga_tx_inst : entity work.link_oh_fpga_tx
    port map (
      reset_i      => reset,
      ttc_clk_40_i => clock,

      l1a_i    => l1a_i,
      bc0_i    => bc0_i,
      resync_i => resync_i,

      elink_data_o => backend_to_oh_elink,

      request_valid_i => request_valid_i,
      request_write_i => request_write_i,
      request_addr_i  => request_addr_i,
      request_data_i  => request_data_i,
      busy_o          => busy_o
      );

  --------------------------------------------------------------------------------
  -- backend ~> oh rx
  --------------------------------------------------------------------------------

  gbt_rx_1 : entity work.gbt_rx
    port map (
      reset_i => reset,
      clock   => clock,

      data_i => backend_to_oh_elink,

      l1a_o    => l1a_o,
      bc0_o    => bc0_o,
      resync_o => resync_o,

      req_en_o   => req_en_o,
      req_data_o => req_data_o,
      ready_o    => oh_rx_ready,

      error_o => oh_rx_err
      );

  ipb_strobe <= req_en_o;
  ipb_write  <= req_data_o(48);
  ipb_addr   <= req_data_o(47 downto 32);
  ipb_wdata  <= req_data_o(31 downto 0);

  process (clock) is
  begin
    if (rising_edge(clock)) then

      if (ipb_strobe = '1' and ipb_write = '1') then
        mem(to_integer(unsigned(ipb_addr))) <= ipb_wdata;
      end if;

      req_valid <= ipb_strobe;

    end if;
  end process;

  req_data <= mem(to_integer(unsigned(ipb_addr)));

  --------------------------------------------------------------------------------
  -- oh ~> backend tx
  --------------------------------------------------------------------------------

  gbt_tx_1 : entity work.gbt_tx
    port map (
      clock       => clock,
      reset_i     => reset,
      data_o      => oh_to_backend_elink,
      req_en_o    => open,
      req_valid_i => req_valid,
      req_data_i  => req_data
      );

  --------------------------------------------------------------------------------
  -- oh ~> backend rx
  --------------------------------------------------------------------------------

  link_oh_fpga_rx_1 : entity work.link_oh_fpga_rx
    port map (
      reset_i          => reset,
      ttc_clk_40_i     => clock,
      elink_data_i     => oh_to_backend_elink,
      reg_data_valid_o => reg_data_valid_o,
      reg_data_o       => reg_data_o,
      error_o          => be_rx_err
      );

end behavioral;
