library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;
use work.types_pkg.all;
use work.hardware_pkg.all;
use work.cluster_pkg.all;

-- Declare module entity. Declare module inputs, inouts, and outputs.
entity trigger_data_formatter_tb is
end trigger_data_formatter_tb;

-- Begin module architecture/code.
architecture behave of trigger_data_formatter_tb is

-- Instantiate Constants
  constant clk_PERIOD    : time := 25.0 ns;
  constant clk160_PERIOD : time := 6.25 ns;
  constant clk200_PERIOD : time := 5.00 ns;

  constant wait_time : time := clk_PERIOD*3465+10 ns;

  signal clocks          : clocks_t;
  signal reset_i         : std_logic := '0';
  signal clusters_i      : sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);
  signal ttc_i           : ttc_t;
  signal overflow_i      : std_logic;
  signal bxn_counter_i   : std_logic_vector (11 downto 0);
  signal error_i         : std_logic;
  signal fiber_kchars_o  : t_std10_array (NUM_OPTICAL_PACKETS-1 downto 0);
  signal fiber_packets_o : t_fiber_packet_array (NUM_OPTICAL_PACKETS-1 downto 0);
  signal elink_packets_o : t_elink_packet_array (NUM_ELINK_PACKETS-1 downto 0);

  function int (vec : std_logic_vector) return integer is
  begin
    return to_integer(unsigned(vec));
  end int;

  function slv (int : integer; len : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(int, len));
  end slv;

  signal mgt_mmcm_reset_o : std_logic_vector (3 downto 0);
  signal trg_tx_n         : std_logic_vector(NUM_GT_TX-1 downto 0);
  signal trg_tx_p         : std_logic_vector(NUM_GT_TX-1 downto 0);
  signal gbt_trig_p       : std_logic_vector(MXELINKS-1 downto 0);
  signal gbt_trig_n       : std_logic_vector(MXELINKS-1 downto 0);
  signal ipb_mosi_i       : ipb_wbus;
  signal ipb_miso_o       : ipb_rbus;
  signal ipb_reset_i      : std_logic := '0';

  signal refclk_p         : std_logic_vector(NUM_GT_REFCLK-1 downto 0);
  signal refclk_n         : std_logic_vector(NUM_GT_REFCLK-1 downto 0);

begin

  ttc_i.resync  <= '0';
  ttc_i.l1a     <= '0';
  ttc_i.bc0     <= '0';
  bxn_counter_i <= (others => '0');
  error_i       <= '0';
  overflow_i    <= '0';

  trigger_data_formatter_1 : entity work.trigger_data_formatter
    port map (
      clocks          => clocks,
      reset_i         => reset_i,
      clusters_i      => clusters_i,
      ttc_i           => ttc_i,
      overflow_i      => overflow_i,
      bxn_counter_i   => bxn_counter_i,
      error_i         => error_i,
      fiber_kchars_o  => fiber_kchars_o,
      fiber_packets_o => fiber_packets_o,
      elink_packets_o => elink_packets_o
      );
  trigger_data_phy_1: entity work.trigger_data_phy
    port map (
      clocks           => clocks,
      reset_i          => reset_i,
      mgt_mmcm_reset_o => mgt_mmcm_reset_o,
      ipb_mosi_i       => ipb_mosi_i,
      ipb_miso_o       => ipb_miso_o,
      ipb_reset_i      => ipb_reset_i,
      trg_tx_n         => trg_tx_n,
      trg_tx_p         => trg_tx_p,
      refclk_p         => refclk_p,
      refclk_n         => refclk_n,
      gbt_trig_p       => gbt_trig_p,
      gbt_trig_n       => gbt_trig_n,
      fiber_kchars_i   => fiber_kchars_o,
      fiber_packets_i  => fiber_packets_o,
      elink_packets_i  => elink_packets_o
      );

-- Toggle the resets.
  adrsel : process
  begin
    clusters_i  <= (others => NULL_CLUSTER);
    --wait for wait_time;
    wait until reset_i = '0';
    wait until rising_edge(clocks.clk40);
    clusters_i(0)  <= (adr => slv(0, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(1)  <= (adr => slv(1, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(2)  <= (adr => slv(2, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(3)  <= (adr => slv(3, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(4)  <= (adr => slv(4, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(5)  <= (adr => slv(5, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(6)  <= (adr => slv(6, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(7)  <= (adr => slv(7, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(8)  <= (adr => slv(8, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(9)  <= (adr => slv(9, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(10) <= (adr => slv(10, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(11) <= (adr => slv(11, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(12) <= (adr => slv(12, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(13) <= (adr => slv(13, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(14) <= (adr => slv(14, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(15) <= (adr => slv(15, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    wait until rising_edge(clocks.clk40);
    clusters_i  <= (others => NULL_CLUSTER);
    wait;
  end process;
  --------------------------------------------------------------------------------
  -- Clocks
  --------------------------------------------------------------------------------

  -- Toggle the resets.
  resetproc : process
  begin
    reset_i <= '1';
    wait for 400 ns;
    reset_i <= '0';
    wait;
  end process;

-- Generate necessary clocks.
  clkgen : process
  begin
    clocks.clk40 <= '1';
    wait for clk_PERIOD / 2;
    clocks.clk40 <= '0';
    wait for clk_PERIOD / 2;
  end process;

  clocks.sysclk <= clocks.clk40;

-- Generate necessary clocks.
  clkgen2 : process
  begin
    clocks.clk160_0 <= '1';
    wait for clk160_PERIOD / 2;
    clocks.clk160_0 <= '0';
    wait for clk160_PERIOD / 2;
  end process;

-- Generate necessary clocks.
  clkgen3 : process
  begin
    clocks.clk200 <= '1';
    wait for clk200_PERIOD / 2;
    clocks.clk200 <= '0';
    wait for clk200_PERIOD / 2;
  end process;

  refclk_p <= (others =>     clocks.clk200);
  refclk_n <= (others => not clocks.clk200);

-- Insert Processes and code here.

end behave;  -- architecture
