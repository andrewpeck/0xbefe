----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid v3 Firmware -- S-bit monitor
-- E. Juska, A. Peck
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.types_pkg.all;
use work.cluster_pkg.all;

entity sbit_monitor is
  generic(
    g_PARTITION_WIDTH : integer := 192
    );
  port(
    -- reset
    reset_i : in std_logic;

    -- TTC
    ttc_clk_i : in std_logic;
    l1a_i     : in std_logic;

    trig_on_invalid_addrs : in std_logic;
    trig_on_duplicates    : in std_logic;

    -- Sbit cluster inputs
    clusters_i : in sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);

    -- output
    frozen_clusters_o : out sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);

    l1a_delay_o : out std_logic_vector(31 downto 0)

    );
end sbit_monitor;

architecture sbit_monitor_arch of sbit_monitor is

  signal clusters : sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);

  signal cluster_valid      : std_logic_vector (NUM_FOUND_CLUSTERS-1 downto 0);
  signal cluster_duplicated : std_logic_vector (NUM_FOUND_CLUSTERS-1 downto 0);
  signal armed              : std_logic := '1';
  signal link_trigger       : std_logic;

  signal l1a_delay_run : std_logic := '0';
  signal l1a_delay     : unsigned(31 downto 0);

  signal cluster_corrupted : std_logic_vector (NUM_FOUND_CLUSTERS-1 downto 0);

begin

  -- vhdl93 outputs

  l1a_delay_o <= std_logic_vector(l1a_delay);

  --------------------------------------------------------------------------------
  -- Copy of input
  --------------------------------------------------------------------------------

  process (ttc_clk_i) is
  begin
    if (rising_edge(ttc_clk_i)) then
      clusters <= clusters_i;
    end if;
  end process;

  --------------------------------------------------------------------------------
  -- Cluster Valid
  --------------------------------------------------------------------------------

  process (ttc_clk_i) is
  begin
    if (rising_edge(ttc_clk_i)) then
      for I in 0 to NUM_FOUND_CLUSTERS-1 loop
        cluster_valid (I) <= clusters_i(I).vpf;
      end loop;
    end if;
  end process;


  --------------------------------------------------------------------------------
  -- Corrupted Cluster Logic
  --------------------------------------------------------------------------------

  process (ttc_clk_i) is
  begin
    if (rising_edge(ttc_clk_i)) then
      for I in 0 to NUM_FOUND_CLUSTERS-1 loop
        if (invalid_clusterp(clusters_i(I), g_PARTITION_WIDTH)) then
          cluster_corrupted(I) <= '1';
        else
          cluster_corrupted(I) <= '0';
        end if;
      end loop;
    end if;
  end process;

  --------------------------------------------------------------------------------
  -- Duplicate Cluster Logic
  --------------------------------------------------------------------------------

  process (ttc_clk_i) is
  begin

    if (rising_edge(ttc_clk_i)) then

      cluster_duplicated <= (others => '0');

      for I in 0 to NUM_FOUND_CLUSTERS-1 loop
        for J in 0 to NUM_FOUND_CLUSTERS-1 loop
          -- its a duplicate if different clusters have adr/cnt/prt are equal
          -- (but skip NULL clusters since they are all equal anyway)
          if (I /= J and
              clusters_i(I).adr = clusters_i(J).adr and
              clusters_i(I).cnt = clusters_i(J).cnt and
              clusters_i(I).prt = clusters_i(J).prt and
              clusters_i(I).adr /= NULL_CLUSTER.adr) then
            cluster_duplicated(I) <= '1';
          end if;
        end loop;
      end loop;

    end if;
  end process;

  --------------------------------------------------------------------------------
  -- Link trigger multiplexer
  --------------------------------------------------------------------------------

  process (cluster_valid, cluster_corrupted, cluster_duplicated) is
  begin
    if (trig_on_invalid_addrs = '1' and trig_on_duplicates = '1') then
      link_trigger <= or_reduce(cluster_corrupted) or
                      or_reduce(cluster_duplicated);
    elsif (trig_on_invalid_addrs = '1') then
      link_trigger <= or_reduce(cluster_corrupted);
    elsif (trig_on_duplicates = '1') then
      link_trigger <= or_reduce(cluster_duplicated);
    else
      link_trigger <= or_reduce(cluster_valid);
    end if;
  end process;

  --------------------------------------------------------------------------------
  -- S-bit Freezer
  --
  -- freeze the sbits on the output when a trigger comes
  --------------------------------------------------------------------------------

  freezeloop : for I in 0 to NUM_FOUND_CLUSTERS-1 generate
    process(ttc_clk_i)
    begin
      if (rising_edge(ttc_clk_i)) then
        if (reset_i = '1') then
          frozen_clusters_o(I) <= NULL_CLUSTER;
          armed                <= '1';
        else
          if (link_trigger = '1' and armed = '1') then
            frozen_clusters_o(I) <= clusters(I);
            armed                <= '0';
          end if;
        end if;
      end if;
    end process;
  end generate;

  --------------------------------------------------------------------------------
  -- L1A Latency Measurement
  --
  -- count the gap between this sbit cluster and the following L1A
  --------------------------------------------------------------------------------

  process(ttc_clk_i)
  begin
    if (rising_edge(ttc_clk_i)) then
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

end sbit_monitor_arch;
