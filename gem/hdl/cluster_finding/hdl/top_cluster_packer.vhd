library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.cluster_pkg.all;

entity cluster_packer is
  generic (
    DEADTIME          : integer := 0;
    ONESHOT           : boolean := false;
    SPLIT_CLUSTERS    : integer := 0;
    INVERT_PARTITIONS : boolean := false;

    NUM_VFATS           : integer := 24;
    NUM_PARTITIONS      : integer := 8;
    NUM_FOUND_CLUSTERS  : integer := 0;
    NUM_OUTPUT_CLUSTERS : integer := 0;
    STATION             : integer := 0
    );
  port(

    reset : in std_logic;

    clk_40   : in std_logic;
    clk_fast : in std_logic;

    sbits_i : in sbits_array_t (NUM_VFATS-1 downto 0);

    cluster_count_o : out std_logic_vector (10 downto 0);
    clusters_o      : out sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);
    clusters_ena_o  : out std_logic;
    overflow_o      : out std_logic
    );
end cluster_packer;

architecture behavioral of cluster_packer is

  constant MXSBITS         : integer := 64;
  constant PARTITION_WIDTH : integer := NUM_VFATS/NUM_PARTITIONS;

  subtype partition_t is std_logic_vector(PARTITION_WIDTH*MXSBITS-1 downto 0);
  type partition_array_t is array(integer range <>) of partition_t;

  signal latch_pulse_s0 : std_logic;
  signal latch_pulse_s1 : std_logic;

  signal sbits_os : sbits_array_t (NUM_VFATS-1 downto 0);


  signal partitions_i  : partition_array_t (NUM_PARTITIONS-1 downto 0);
  signal partitions_os : partition_array_t (NUM_PARTITIONS-1 downto 0);

  signal sbits_s0 : std_logic_vector (NUM_VFATS*MXSBITS-1 downto 0);
  signal vpfs     : std_logic_vector (NUM_VFATS*MXSBITS-1 downto 0);
  signal cnts     : std_logic_vector (NUM_VFATS*MXSBITS*MXCNTB-1 downto 0);

  signal overflow           : std_logic;
  signal cluster_count      : std_logic_vector (10 downto 0);
  constant OVERFLOW_LATENCY : natural := 1;

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
      deadtime : in  std_logic_vector (3 downto 0);
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

  process (clk_fast)
  begin
    if (rising_edge(clk_fast)) then
      latch_pulse_s1 <= latch_pulse_s0;
    end if;
  end process;

  clock_strobe_inst : entity work.clock_strobe
    port map (
      fast_clk_i => clk_fast,
      slow_clk_i => clk_40,
      strobe_o   => latch_pulse_s0
      );

  ------------------------------------------------------------------------------------------------------------------------
  -- remap vfats into partitions
  ------------------------------------------------------------------------------------------------------------------------

  ge21_partition_map_gen : if (station = 2) generate
    invert_gen : if (INVERT_PARTITIONS) generate
      partitions_i(0) <= sbits_i(5) & sbits_i(4) & sbits_i(3) & sbits_i(2) & sbits_i(1) & sbits_i(0);
      partitions_i(1) <= sbits_i(11) & sbits_i(10) & sbits_i(9) & sbits_i(8) & sbits_i(7) & sbits_i(6);
    --partitions_i(0) <= sbits_i(0) & sbits_i(1) & sbits_i(2) & sbits_i(3) & sbits_i(4) & sbits_i(5);
    --partitions_i(1) <= sbits_i(6) & sbits_i(7) & sbits_i(8) & sbits_i(9) & sbits_i(10) & sbits_i(11);
    end generate;
    noninvert_gen : if (not INVERT_PARTITIONS) generate
      --partitions_i(1) <= sbits_i(0) & sbits_i(1) & sbits_i(2) & sbits_i(3) & sbits_i(4) & sbits_i(5);
      --partitions_i(0) <= sbits_i(6) & sbits_i(7) & sbits_i(8) & sbits_i(9) & sbits_i(10) & sbits_i(11);
      partitions_i(1) <= sbits_i(5) & sbits_i(4) & sbits_i(3) & sbits_i(2) & sbits_i(1) & sbits_i(0);
      partitions_i(0) <= sbits_i(11) & sbits_i(10) & sbits_i(9) & sbits_i(8) & sbits_i(7) & sbits_i(6);
    end generate;
  end generate;

  ge11_and_me0_partition_map_gen : if (station = 0 or station = 1) generate
    invert_gen : if (INVERT_PARTITIONS) generate
      partitions_i(0) <= sbits_i(23) & sbits_i(15) & sbits_i(7);
      partitions_i(1) <= sbits_i(22) & sbits_i(14) & sbits_i(6);
      partitions_i(2) <= sbits_i(21) & sbits_i(13) & sbits_i(5);
      partitions_i(3) <= sbits_i(20) & sbits_i(12) & sbits_i(4);
      partitions_i(4) <= sbits_i(19) & sbits_i(11) & sbits_i(3);
      partitions_i(5) <= sbits_i(18) & sbits_i(10) & sbits_i(2);
      partitions_i(6) <= sbits_i(17) & sbits_i(9) & sbits_i(1);
      partitions_i(7) <= sbits_i(16) & sbits_i(8) & sbits_i(0);
    end generate;
    noninvert_gen : if (not INVERT_PARTITIONS) generate
      partitions_i(0) <= sbits_i(16) & sbits_i(8) & sbits_i(0);
      partitions_i(1) <= sbits_i(17) & sbits_i(9) & sbits_i(1);
      partitions_i(2) <= sbits_i(18) & sbits_i(10) & sbits_i(2);
      partitions_i(3) <= sbits_i(19) & sbits_i(11) & sbits_i(3);
      partitions_i(4) <= sbits_i(20) & sbits_i(12) & sbits_i(4);
      partitions_i(5) <= sbits_i(21) & sbits_i(13) & sbits_i(5);
      partitions_i(6) <= sbits_i(22) & sbits_i(14) & sbits_i(6);
      partitions_i(7) <= sbits_i(23) & sbits_i(15) & sbits_i(7);
    end generate;
  end generate;
  --------------------------------------------------------------------------------
  -- Oneshot
  --------------------------------------------------------------------------------

  -- without the oneshot we can save 6.25 ns latency and make this transparent
  nos_gen : if (not ONESHOT) generate
    partitions_os <= partitions_i;
  end generate;

  -- Optional oneshot to keep VFATs from re-firing the same channel
  os_gen : if (ONESHOT) generate
    os_vfatloop : for ipartition in 0 to (NUM_PARTITIONS - 1) generate
      os_sbitloop : for isbit in 0 to (MXSBITS*PARTITION_WIDTH - 1) generate
        sbit_oneshot : x_oneshot
          port map (
            d        => partitions_i(ipartition)(isbit),
            q        => partitions_os(ipartition)(isbit),
            deadtime => std_logic_vector(to_unsigned(DEADTIME, 4)),
            clk      => clk_fast,
            slowclk  => clk_40
            );
      end generate;

    end generate;

  end generate;

  flatten_partitions : for iprt in 0 to NUM_PARTITIONS-1 generate
    sbits_s0 ((iprt+1)*PARTITION_WIDTH*MXSBITS-1 downto iprt*PARTITION_WIDTH*MXSBITS) <= partitions_os(iprt);
  end generate;

  ----------------------------------------------------------------------------------
  -- assign valid pattern flags
  ----------------------------------------------------------------------------------

  find_cluster_primaries_inst : find_cluster_primaries
    generic map (
      MXPADS         => NUM_VFATS*MXSBITS,
      MXROWS         => NUM_PARTITIONS,
      MXKEYS         => PARTITION_WIDTH*MXSBITS,
      SPLIT_CLUSTERS => SPLIT_CLUSTERS  -- 1=long clusters will be split in two (0=the tails are dropped)
     -- resource usage will be quite a bit less if you just truncate clusters
      )
    port map (
      clock => clk_fast,
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
      clock      => clk_fast,
      vpfs_i     => vpfs,
      cnt_o      => cluster_count,
      overflow_o => overflow
      );

  count_delay : entity work.fixed_delay
    generic map (
      DELAY => OVERFLOW_LATENCY,
      WIDTH => cluster_count'length)
    port map (
      clock  => clk_fast,
      data_i => cluster_count,
      data_o => cluster_count_o
      );

  overflow_delay : entity work.fixed_delay
    generic map (
      DELAY => OVERFLOW_LATENCY,
      WIDTH => 1)
    port map (
      clock  => clk_fast,
      data_i(0) => overflow,
      data_o(0) => overflow_o
      );

  ------------------------------------------------------------------------------------------------------------------------
  -- priority encoding
  ------------------------------------------------------------------------------------------------------------------------

  find_clusters_inst : entity work.find_clusters
    generic map (
      MXSBITS                 => MXSBITS,
      NUM_VFATS               => NUM_VFATS,
      NUM_FOUND_CLUSTERS      => NUM_FOUND_CLUSTERS,
      STATION                 => STATION
      )
    port map (
      clock      => clk_fast,
      vpfs_in    => vpfs,
      cnts_in    => cnts,
      clusters_o => clusters,
      latch_in   => latch_pulse_s1,
      latch_out  => cluster_latch
      );

  ------------------------------------------------------------------------------------------------------------------------
  -- Assign cluster outputs
  ------------------------------------------------------------------------------------------------------------------------

  process (clk_fast)
  begin
    if (rising_edge(clk_fast)) then
      if (reset = '1') then
        clusters_o <= (others => NULL_CLUSTER);
      else
        clusters_o <= clusters;
      end if;
    end if;
    clusters_ena_o <= cluster_latch;
  end process;

end behavioral;
