library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.cluster_pkg.all;

-- latency = 4.25 bx as of 2022/02/24

entity cluster_packer is
  generic (
    DEADTIME          : integer := 0;
    ONESHOT           : boolean := false;
    SPLIT_CLUSTERS    : integer := 0;
    INVERT_PARTITIONS : boolean := false;

    NUM_VFATS      : integer := 0;
    NUM_PARTITIONS : integer := 0;
    STATION        : integer := 0
    );
  port(

    reset : in std_logic;

    clk_40   : in std_logic;
    clk_fast : in std_logic;

    mask_output_i : in std_logic;

    sbits_i : in sbits_array_t (NUM_VFATS-1 downto 0);

    cluster_count_o        : out std_logic_vector (10 downto 0);
    cluster_count_masked_o : out std_logic_vector (10 downto 0);
    clusters_o             : out sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);
    clusters_masked_o      : out sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);
    overflow_o             : out std_logic
    );
end cluster_packer;

architecture behavioral of cluster_packer is

  constant MXSBITS         : integer := 64;
  constant PARTITION_WIDTH : integer := NUM_VFATS/NUM_PARTITIONS;

  subtype partition_t is std_logic_vector(PARTITION_WIDTH*MXSBITS-1 downto 0);
  type partition_array_t is array(integer range <>) of partition_t;

  signal latch_pulse_s0 : std_logic;
  signal latch_pulse_s1 : std_logic;
  signal latch_pulse_s2 : std_logic;

  signal sbits_os : sbits_array_t (NUM_VFATS-1 downto 0);


  signal partitions_i  : partition_array_t (NUM_PARTITIONS-1 downto 0);
  signal partitions_os : partition_array_t (NUM_PARTITIONS-1 downto 0);

  signal sbits_s0 : std_logic_vector (NUM_VFATS*MXSBITS-1 downto 0);
  signal vpfs     : std_logic_vector (NUM_VFATS*MXSBITS-1 downto 0);
  signal cnts     : std_logic_vector (NUM_VFATS*MXSBITS*MXCNTB-1 downto 0);

  signal overflow                           : std_logic;
  signal cluster_count, cluster_count_delay : std_logic_vector (10 downto 0);
  constant OVERFLOW_LATENCY                 : natural := 5;

  signal cluster_latch : std_logic;

  signal clusters : sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);

  component count_clusters
    generic (
      SIZE            : integer;
      OVERFLOW_THRESH : integer
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
      MXPADS         : integer;
      MXROWS         : integer;
      MXKEYS         : integer;
      MXCNTBITS      : integer;
      SPLIT_CLUSTERS : integer
      );
    port (
      clock : in  std_logic;
      sbits : in  std_logic_vector;
      vpfs  : out std_logic_vector;
      cnts  : out std_logic_vector
      );
  end component;

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
      latch_pulse_s2 <= latch_pulse_s1;
    end if;
  end process;

  clock_strobe_inst : entity work.clock_strobe
    generic map (
      RATIO => 4
      )
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

  nos_gen : if (not ONESHOT) generate
    partitions_os <= partitions_i;
  end generate;

  -- Optional zero-delay oneshot to keep VFATs from re-firing the same channel
  os_gen : if (ONESHOT) generate
    os_vfatloop : for ipartition in 0 to (NUM_PARTITIONS - 1) generate
      os_sbitloop : for isbit in 0 to (MXSBITS*PARTITION_WIDTH - 1) generate
        sbit_oneshot : entity work.sbit_oneshot
          generic map (DEADTIME => DEADTIME)
          port map (
            d   => partitions_i(ipartition)(isbit),
            q   => partitions_os(ipartition)(isbit),
            clk => clk_40
            );
      end generate;
    end generate;
  end generate;

  -- without the oneshot, just have a ff
  flatten_partitions : for iprt in 0 to NUM_PARTITIONS-1 generate
    process (clk_fast) is
    begin
      if (rising_edge(clk_fast)) then
        sbits_s0 ((iprt+1)*PARTITION_WIDTH*MXSBITS-1 downto iprt*PARTITION_WIDTH*MXSBITS)
          <= partitions_os(iprt);
      end if;
    end process;
  end generate;

  ----------------------------------------------------------------------------------
  -- assign valid pattern flags
  ----------------------------------------------------------------------------------

  find_cluster_primaries_inst : find_cluster_primaries
    generic map (
      MXCNTBITS      => 3,
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
  -- Timed in on 2022/02/24
  count_clusters_inst : count_clusters
    generic map (
      overflow_thresh => NUM_OUTPUT_CLUSTERS,
      size            => NUM_VFATS*MXSBITS

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
      data_o => cluster_count_delay
      );

  cluster_count_o <= cluster_count_delay;
  cluster_count_masked_o <= (others => '0') when mask_output_i = '1' else cluster_count_delay;

  overflow_delay : entity work.fixed_delay
    generic map (
      DELAY => OVERFLOW_LATENCY,
      WIDTH => 1)
    port map (
      clock     => clk_fast,
      data_i(0) => overflow,
      data_o(0) => overflow_o
      );

  ------------------------------------------------------------------------------------------------------------------------
  -- priority encoding
  ------------------------------------------------------------------------------------------------------------------------

  find_clusters_inst : entity work.find_clusters
    generic map (
      MXSBITS            => MXSBITS,
      NUM_VFATS          => NUM_VFATS,
      NUM_FOUND_CLUSTERS => NUM_FOUND_CLUSTERS,
      STATION            => STATION
      )
    port map (
      clock      => clk_fast,
      vpfs_i     => vpfs,
      cnts_i     => cnts,
      clusters_o => clusters,
      latch_i    => latch_pulse_s2,
      latch_o    => cluster_latch
      );

  ------------------------------------------------------------------------------------------------------------------------
  -- Assign cluster outputs
  ------------------------------------------------------------------------------------------------------------------------

  process (clk_fast) is
  begin
    if (rising_edge(clk_fast)) then

      if (reset = '1') then
        clusters_o <= (others => NULL_CLUSTER);
      else
        clusters_o <= clusters;
      end if;

      if (reset = '1' or mask_output_i = '1') then
        clusters_masked_o <= (others => NULL_CLUSTER);
      else
        clusters_masked_o <= clusters;
      end if;

    end if;
  end process;

end behavioral;
