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
  port (
    CLUSTER0 : out sbit_cluster_t;
    CLUSTER1 : out sbit_cluster_t;
    CLUSTER2 : out sbit_cluster_t;
    CLUSTER3 : out sbit_cluster_t;
    CLUSTER4 : out sbit_cluster_t;
    CL_WORD0 : out std_logic_vector (15 downto 0) ;
    CL_WORD1 : out std_logic_vector (15 downto 0) ;
    CL_WORD2 : out std_logic_vector (15 downto 0) ;
    CL_WORD3 : out std_logic_vector (15 downto 0) ;
    CL_WORD4 : out std_logic_vector (15 downto 0) ;
    ECC8     : out std_logic_vector (7 downto 0) ;
    STATUS   : out std_logic_vector (4 downto 0) ;
    BXN      : out std_logic_vector (2 downto 0) ;
    BC0      : out std_logic
  );
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
  signal overflow_i      : std_logic := '0';
  signal bxn_counter_i   : std_logic_vector (11 downto 0) := (others => '0');
  signal error_i         : std_logic := '0';
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

  signal refclk_p : std_logic_vector(NUM_GT_REFCLK-1 downto 0);
  signal refclk_n : std_logic_vector(NUM_GT_REFCLK-1 downto 0);

begin

  ttc_i.resync  <= '0';
  ttc_i.l1a     <= '0';
  error_i       <= '0';
  overflow_i    <= '0';

  process (clocks.clk40) is
  begin
    if (rising_edge(clocks.clk40)) then
      if (bxn_counter_i = x"FFF") then
        bxn_counter_i <= x"000";
        ttc_i.bc0     <= '1';
      else
        bxn_counter_i <= std_logic_vector (unsigned(bxn_counter_i) + 1);
        ttc_i.bc0     <= '0';
      end if;
    end if;
  end process;


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

  CL_WORD0 <= elink_packets_o(0)(15 downto 0);
  CL_WORD1 <= elink_packets_o(0)(31 downto 16);
  CL_WORD2 <= elink_packets_o(0)(47 downto 32);
  CL_WORD3 <= elink_packets_o(0)(63 downto 48);
  CL_WORD4 <= elink_packets_o(0)(79 downto 64);
  ECC8     <= elink_packets_o(0)(87 downto 80);

  STATUS <= CL_WORD4(14) & CL_WORD3(14) & CL_WORD2(14) & CL_WORD1 (14) & CL_WORD0(14);

  BC0 <= STATUS(0);
  BXN <= STATUS(3 downto 1);

  CLUSTER0.adr <= CL_WORD0(8 downto 0);
  CLUSTER1.adr <= CL_WORD1(8 downto 0);
  CLUSTER2.adr <= CL_WORD2(8 downto 0);
  CLUSTER3.adr <= CL_WORD3(8 downto 0);
  CLUSTER4.adr <= CL_WORD4(8 downto 0);

  CLUSTER0.prt <= "00" & CL_WORD0(9 downto 9);
  CLUSTER1.prt <= "00" & CL_WORD1(9 downto 9);
  CLUSTER2.prt <= "00" & CL_WORD2(9 downto 9);
  CLUSTER3.prt <= "00" & CL_WORD3(9 downto 9);
  CLUSTER4.prt <= "00" & CL_WORD4(9 downto 9);

  CLUSTER0.cnt <= CL_WORD0(12 downto 10);
  CLUSTER1.cnt <= CL_WORD1(12 downto 10);
  CLUSTER2.cnt <= CL_WORD2(12 downto 10);
  CLUSTER3.cnt <= CL_WORD3(12 downto 10);
  CLUSTER4.cnt <= CL_WORD4(12 downto 10);

  trig_rx_data_arr_o(i) <= gbt_rx_data_widebus_arr_i(i * 2 + 1) &
                            real_gbt_rx_data(i * 2 + 1)(71 downto 48) &
                            real_gbt_rx_data(i * 2 + 0)(71 downto 48) &
                            real_gbt_rx_data(i * 2 + 1)(79 downto 72);



  -- trigger_data_phy_1 : entity work.trigger_data_phy
  --   port map (
  --     clocks           => clocks,
  --     reset_i          => reset_i,
  --     mgt_mmcm_reset_o => mgt_mmcm_reset_o,
  --     ipb_mosi_i       => ipb_mosi_i,
  --     ipb_miso_o       => ipb_miso_o,
  --     ipb_reset_i      => ipb_reset_i,
  --     trg_tx_n         => trg_tx_n,
  --     trg_tx_p         => trg_tx_p,
  --     refclk_p         => refclk_p,
  --     refclk_n         => refclk_n,
  --     gbt_trig_p       => gbt_trig_p,
  --     gbt_trig_n       => gbt_trig_n,
  --     fiber_kchars_i   => fiber_kchars_o,
  --     fiber_packets_i  => fiber_packets_o,
  --     elink_packets_i  => elink_packets_o
  --     );

-- Toggle the resets.
  adrsel : process
  begin
    clusters_i     <= (others => NULL_CLUSTER);
    --wait for wait_time;
    wait until reset_i = '0';
    wait until rising_edge(clocks.clk40);
    clusters_i(0)  <= (adr    => slv(0, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(1)  <= (adr    => slv(1, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(2)  <= (adr    => slv(2, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(3)  <= (adr    => slv(3, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(4)  <= (adr    => slv(4, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(5)  <= (adr    => slv(5, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(6)  <= (adr    => slv(6, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(7)  <= (adr    => slv(7, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(8)  <= (adr    => slv(8, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(9)  <= (adr    => slv(9, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(10) <= (adr    => slv(10, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(11) <= (adr    => slv(11, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(12) <= (adr    => slv(12, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(13) <= (adr    => slv(13, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(14) <= (adr    => slv(14, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    clusters_i(15) <= (adr    => slv(15, MXADRB), cnt => "000", vpf => '1', prt => (others => '0'));
    wait until rising_edge(clocks.clk40);
    clusters_i     <= (others => NULL_CLUSTER);
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

  refclk_p <= (others => clocks.clk200);
  refclk_n <= (others => not clocks.clk200);

-- Insert Processes and code here.

end behave;  -- architecture
