library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library xil_defaultlib;

library work;
use work.types_pkg.all;
use work.hardware_pkg.all;

library unisim;
use unisim.vcomponents.all;

entity cluster_packer is
  generic (
    DEADTIME         : integer := 0;
    ONESHOT          : boolean := false;
    g_SPLIT_CLUSTERS : integer := 0
    );
  port(
    clocks          : in  clocks_t;
    reset           : in  std_logic;
    cluster_count_o : out std_logic_vector (10 downto 0);

    sbits_i : in sbits_array_t (NUM_VFATS-1 downto 0);

    clusters_o : out sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);

    clusters_ena_o : out std_logic;

    overflow_o : out std_logic

    );
end cluster_packer;

architecture behavioral of cluster_packer is
  signal latch_pulse_s0 : std_logic;
  signal latch_pulse_s1 : std_logic;

  signal sbits_os : sbits_array_t (NUM_VFATS-1 downto 0);

  signal partitions : partition_array_t (NUM_PARTITIONS-1 downto 0);

  signal sbits_s0 : std_logic_vector (NUM_VFATS*MXSBITS-1 downto 0);
  signal vpfs     : std_logic_vector (NUM_VFATS*MXSBITS-1 downto 0);
  signal cnts     : std_logic_vector (NUM_VFATS*MXSBITS*MXCNTB-1 downto 0);

  signal overflow           : std_logic;
  signal cluster_count      : std_logic_vector (10 downto 0);
  constant OVERFLOW_LATENCY : std_logic_vector (3 downto 0) := x"1";

  signal cluster_latch : std_logic;

  signal clusters : sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);

  component count_clusters
    generic (
      overflow_thresh : integer
      );
    port (
      clock      : in  std_logic;
      vpfs_i     : in  std_logic_vector;
      cnt_o      : out std_logic_vector;
      overflow_o : out std_logic
      );
  end component;

  component find_cluster_primaries
    generic (
      MXPADS         : integer := 1536;
      MXROWS         : integer := 8;
      MXKEYS         : integer := 192;
      MXCNTBITS      : integer := 3;
      SPLIT_CLUSTERS : integer := 0
      );
    port (
      clock : in  std_logic;
      sbits : in  std_logic_vector;
      vpfs  : out std_logic_vector;
      cnts  : out std_logic_vector
      );
  end component;

  component x_oneshot is
    port (
      d        : in  std_logic;
      clk      : in  std_logic;
      slowclk  : in  std_logic;
      deadtime : in  std_logic_vector;
      q        : out std_logic
      );
  end component x_oneshot;

begin

  --------------------------------------------------------------------------------
  -- Valid
  --------------------------------------------------------------------------------

  -- Create a 1 of 4 high signal synced to the 40MHZ clock
  --            ________________              _____________
  -- clk40    __|              |______________|
  --            _______________________________
  -- r80      __|                             |_____________
  --                     _______________________________
  -- r80_dly  ___________|                             |_____________
  --            __________                    __________
  -- valid    __|        |____________________|        |______

  process (clocks.clk160_0)
  begin
    if (rising_edge(clocks.clk160_0)) then
      latch_pulse_s1 <= latch_pulse_s0;
    end if;
  end process;

  clock_strobe_inst : entity work.clock_strobe
    port map (
      fast_clk_i => clocks.clk160_0,
      slow_clk_i => clocks.clk40,
      strobe_o   => latch_pulse_s0
      );

  --------------------------------------------------------------------------------
  -- Oneshot
  --------------------------------------------------------------------------------

  os_vfatloop : for os_vfat in 0 to (NUM_VFATS - 1) generate
    os_sbitloop : for os_sbit in 0 to (MXSBITS - 1) generate

      -- Optional oneshot to keep VFATs from re-firing the same channel
      os_gen : if (ONESHOT) generate
        sbit_oneshot : x_oneshot
          port map (
            d        => sbits_i(os_vfat)(os_sbit),
            q        => sbits_os(os_vfat)(os_sbit),
            deadtime => std_logic_vector(to_unsigned(DEADTIME, 4)),
            clk      => clocks.clk160_0,
            slowclk  => clocks.clk40
            );
      end generate;

      -- without the oneshot we can save 6.25 ns latency and make this transparent
      nos_gen : if (not ONESHOT) generate
        sbits_os(os_vfat)(os_sbit) <= sbits_i(os_vfat)(os_sbit);
      end generate;

    end generate;
  end generate;


  ------------------------------------------------------------------------------------------------------------------------
  -- remap vfats into partitions
  ------------------------------------------------------------------------------------------------------------------------

  ge21_partition_map_gen : if (GE21 = 1) generate
    invert_gen : if (INVERT_PARTITIONS) generate
      partitions(0) <= sbits_os(5) & sbits_os(4) & sbits_os(3) & sbits_os(2) & sbits_os(1) & sbits_os(0);
      partitions(1) <= sbits_os(11) & sbits_os(10) & sbits_os(9) & sbits_os(8) & sbits_os(7) & sbits_os(6);
    --partitions(0) <= sbits_os(0) & sbits_os(1) & sbits_os(2) & sbits_os(3) & sbits_os(4) & sbits_os(5);
    --partitions(1) <= sbits_os(6) & sbits_os(7) & sbits_os(8) & sbits_os(9) & sbits_os(10) & sbits_os(11);
    end generate;
    noninvert_gen : if (not INVERT_PARTITIONS) generate
      --partitions(1) <= sbits_os(0) & sbits_os(1) & sbits_os(2) & sbits_os(3) & sbits_os(4) & sbits_os(5);
      --partitions(0) <= sbits_os(6) & sbits_os(7) & sbits_os(8) & sbits_os(9) & sbits_os(10) & sbits_os(11);
      partitions(1) <= sbits_os(5) & sbits_os(4) & sbits_os(3) & sbits_os(2) & sbits_os(1) & sbits_os(0);
      partitions(0) <= sbits_os(11) & sbits_os(10) & sbits_os(9) & sbits_os(8) & sbits_os(7) & sbits_os(6);
    end generate;
  end generate;

  ge11_partition_map_gen : if (GE11 = 1) generate
    invert_gen : if (INVERT_PARTITIONS) generate
      partitions(0) <= sbits_os(23) & sbits_os(15) & sbits_os(7);
      partitions(1) <= sbits_os(22) & sbits_os(14) & sbits_os(6);
      partitions(2) <= sbits_os(21) & sbits_os(13) & sbits_os(5);
      partitions(3) <= sbits_os(20) & sbits_os(12) & sbits_os(4);
      partitions(4) <= sbits_os(19) & sbits_os(11) & sbits_os(3);
      partitions(5) <= sbits_os(18) & sbits_os(10) & sbits_os(2);
      partitions(6) <= sbits_os(17) & sbits_os(9) & sbits_os(1);
      partitions(7) <= sbits_os(16) & sbits_os(8) & sbits_os(0);
    end generate;
    noninvert_gen : if (not INVERT_PARTITIONS) generate
      partitions(0) <= sbits_os(16) & sbits_os(8) & sbits_os(0);
      partitions(1) <= sbits_os(17) & sbits_os(9) & sbits_os(1);
      partitions(2) <= sbits_os(18) & sbits_os(10) & sbits_os(2);
      partitions(3) <= sbits_os(19) & sbits_os(11) & sbits_os(3);
      partitions(4) <= sbits_os(20) & sbits_os(12) & sbits_os(4);
      partitions(5) <= sbits_os(21) & sbits_os(13) & sbits_os(5);
      partitions(6) <= sbits_os(22) & sbits_os(14) & sbits_os(6);
      partitions(7) <= sbits_os(23) & sbits_os(15) & sbits_os(7);
    end generate;
  end generate;

  flatten_partitions : for iprt in 0 to NUM_PARTITIONS-1 generate
    sbits_s0 ((iprt+1)*PARTITION_SIZE*MXSBITS-1 downto iprt*PARTITION_SIZE*MXSBITS) <= partitions(iprt);
  end generate;

  ----------------------------------------------------------------------------------
  -- assign valid pattern flags
  ----------------------------------------------------------------------------------

  find_cluster_primaries_inst : find_cluster_primaries
    generic map (
      MXPADS         => NUM_VFATS*MXSBITS,
      MXROWS         => NUM_PARTITIONS,
      MXKEYS         => PARTITION_SIZE*MXSBITS,
      SPLIT_CLUSTERS => g_SPLIT_CLUSTERS  -- 1=long clusters will be split in two (0=the tails are dropped)
     -- resource usage will be quite a bit less if you just truncate clusters
      )
    port map (
      clock => clocks.clk160_0,
      sbits => sbits_s0,
      vpfs  => vpfs,
      cnts  => cnts
      );

  ----------------------------------------------------------------------------------
  -- count cluster sizes
  --
  -- We count the number of cluster primaries. If it is greater than 8,
  -- generate an overflow flag. This can be used to change the fiber's frame
  -- separator to flag this to the receiving devices
  ----------------------------------------------------------------------------------

  -- NOTE: need to align overflow and cluster count to data
  -- the output of the overflow flag should be delayed to lineup with the
  -- outputs from the priority encoding modules
  --
  -- You should be able to just tweak the # of pipelines stages in the counter module
  --
  -- Timed in for on 2020/06/26
  count_clusters_inst : count_clusters
    generic map (
      overflow_thresh => NUM_OUTPUT_CLUSTERS
      )
    port map (
      clock      => clocks.clk160_0,
      vpfs_i     => vpfs,
      cnt_o      => cluster_count,
      overflow_o => overflow
      );

  cluster_count_dly : for i in cluster_count'range generate
    count_delay_inst : SRL16E
      port map (
        CLK => clocks.clk160_0,
        CE  => '1',
        D   => cluster_count(I),
        Q   => cluster_count_o(I),
        A0  => OVERFLOW_LATENCY(0),
        A1  => OVERFLOW_LATENCY(1),
        A2  => OVERFLOW_LATENCY(2),
        A3  => OVERFLOW_LATENCY(3)
        );
  end generate;

  -- keep a template for an SRL incase we need to delay the overflow more
  overflow_delay_inst : SRL16E
    port map (
      CLK => clocks.clk160_0,
      CE  => '1',
      D   => overflow,
      Q   => overflow_o,
      A0  => OVERFLOW_LATENCY(0),
      A1  => OVERFLOW_LATENCY(1),
      A2  => OVERFLOW_LATENCY(2),
      A3  => OVERFLOW_LATENCY(3)
      );

  ------------------------------------------------------------------------------------------------------------------------
  -- priority encoding
  ------------------------------------------------------------------------------------------------------------------------

  find_clusters_inst : entity work.find_clusters
    port map (
      clock      => clocks.clk160_0,
      vpfs_in    => vpfs,
      cnts_in    => cnts,
      clusters_o => clusters,
      latch_in   => latch_pulse_s1,
      latch_out  => cluster_latch
      );

  ------------------------------------------------------------------------------------------------------------------------
  -- Assign cluster outputs
  ------------------------------------------------------------------------------------------------------------------------

  process (clocks.clk160_0)
  begin
    if (rising_edge(clocks.clk160_0)) then
      if (reset = '1') then
        clusters_o <= (others => NULL_CLUSTER);
      else
        clusters_o <= clusters;
      end if;
    end if;
    clusters_ena_o <= cluster_latch;
  end process;

end behavioral;
