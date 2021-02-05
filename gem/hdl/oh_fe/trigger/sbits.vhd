----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid v3 Firmware -- S-Bits
-- A. Peck
----------------------------------------------------------------------------------
-- Description:
--   This module wraps up all the functionality for deserializing 320 MHz S-bits
--   as well as the cluster packer
----------------------------------------------------------------------------------
-- 2017/11/01 -- Add description / comments
-- 2018/04/17 -- Add options for "light" oh firmware
-- 2018/09/18 -- Add module for S-bit remapping in firmware
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;


library work;
use work.types_pkg.all;
use work.tmr_pkg.all;
use work.hardware_pkg.all;

entity sbits is
  port(
    clocks : in clocks_t;

    reset_i : in std_logic;

    vfat_mask_i : in std_logic_vector (NUM_VFATS-1 downto 0);

    sbits_mux_sel_i : in  std_logic_vector (4 downto 0);
    sbits_mux_o     : out std_logic_vector (63 downto 0);

    sot_invert_i : in std_logic_vector (NUM_VFATS-1 downto 0);    -- 24 or 12
    tu_invert_i  : in std_logic_vector (NUM_VFATS*8-1 downto 0);  -- 192 or 96
    tu_mask_i    : in std_logic_vector (NUM_VFATS*8-1 downto 0);  -- 192 or 96

    aligned_count_to_ready : in std_logic_vector (11 downto 0);


    trigger_deadtime_i : in std_logic_vector (3 downto 0);

    sbits_p : in std_logic_vector (NUM_VFATS*8-1 downto 0);
    sbits_n : in std_logic_vector (NUM_VFATS*8-1 downto 0);

    start_of_frame_p : in std_logic_vector (NUM_VFATS-1 downto 0);
    start_of_frame_n : in std_logic_vector (NUM_VFATS-1 downto 0);


    active_vfats_o : out std_logic_vector (NUM_VFATS-1 downto 0);

    clusters_o      : out sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);
    cluster_count_o : out std_logic_vector (10 downto 0);
    overflow_o      : out std_logic;

    sot_is_aligned_o      : out std_logic_vector (NUM_VFATS-1 downto 0);
    sot_unstable_o        : out std_logic_vector (NUM_VFATS-1 downto 0);
    sot_invalid_bitskip_o : out std_logic_vector (NUM_VFATS-1 downto 0);

    sot_tap_delay  : in t_std5_array (NUM_VFATS-1 downto 0);
    trig_tap_delay : in t_std5_array (NUM_VFATS*8-1 downto 0);

    hitmap_reset_i   : in  std_logic;
    hitmap_acquire_i : in  std_logic;
    hitmap_sbits_o   : out sbits_array_t(NUM_VFATS-1 downto 0)

    );
end sbits;

architecture Behavioral of sbits is

  signal vfat_sbits_strip_mapped : sbits_array_t(NUM_VFATS-1 downto 0);
  signal vfat_sbits              : sbits_array_t(NUM_VFATS-1 downto 0);

  constant empty_vfat : std_logic_vector (63 downto 0) := x"0000000000000000";

  signal active_vfats : std_logic_vector (NUM_VFATS-1 downto 0);

  signal sbits : std_logic_vector (MXSBITS_CHAMBER-1 downto 0);

  signal active_vfats_s1 : std_logic_vector (NUM_VFATS*8-1 downto 0);

  signal sbits_mux_s0 : std_logic_vector (63 downto 0);
  signal sbits_mux_s1 : std_logic_vector (63 downto 0);
  signal sbits_mux    : std_logic_vector (63 downto 0);
  signal aff_mux      : std_logic;

  signal sbits_mux_sel : std_logic_vector (4 downto 0);

  -- multiplex together the 1536 s-bits into a single chip-scope accessible register
  -- don't want to affect timing, so do it through a couple of flip-flop stages

  attribute mark_debug              : string;
  attribute mark_debug of sbits_mux : signal is "TRUE";
  attribute mark_debug of aff_mux   : signal is "TRUE";

begin

  process (clocks.clk40)
  begin
    if (rising_edge(clocks.clk40)) then
      if (unsigned(sbits_mux_sel_i) > to_unsigned(NUM_VFATS, sbits_mux_sel_i'length)-1) then
        sbits_mux_sel <= (others => '0');
      else
        sbits_mux_sel <= sbits_mux_sel_i;
      end if;
    end if;
  end process;

  active_vfats_o <= active_vfats;

  --------------------------------------------------------------------------------------------------------------------
  -- S-bit Deserialization and Alignment
  --------------------------------------------------------------------------------------------------------------------

  -- deserializes and aligns the 192 320 MHz s-bits into 1536 40MHz s-bits

  trig_alignment : entity work.trig_alignment
    port map (

      vfat_mask_i => vfat_mask_i,

      reset_i => reset_i,

      sbits_p => sbits_p,
      sbits_n => sbits_n,

      sot_invert_i => sot_invert_i,
      tu_invert_i  => tu_invert_i,
      tu_mask_i    => tu_mask_i,

      aligned_count_to_ready => aligned_count_to_ready,

      start_of_frame_p => start_of_frame_p,
      start_of_frame_n => start_of_frame_n,

      clock     => clocks.clk40,
      clk160_0  => clocks.clk160_0,
      clk160_90 => clocks.clk160_90,

      sot_is_aligned      => sot_is_aligned_o,
      sot_unstable        => sot_unstable_o,
      sot_invalid_bitskip => sot_invalid_bitskip_o,

      sot_tap_delay  => sot_tap_delay,
      trig_tap_delay => trig_tap_delay,

      sbits => sbits
      );

  --------------------------------------------------------------------------------------------------------------------
  -- Channel to Strip Mapping
  --------------------------------------------------------------------------------------------------------------------

  sbit_reverse : for I in 0 to (NUM_VFATS-1) generate
  begin
    vfat_sbits (I) <= sbits ((I+1)*MXSBITS-1 downto (I)*MXSBITS) when REVERSE_VFAT_SBITS(I) = '0' else reverse_vector(sbits ((I+1)*MXSBITS-1 downto (I)*MXSBITS));
  end generate;

  channel_to_strip_inst : entity work.channel_to_strip
    port map (
      channels_in => vfat_sbits,
      strips_out  => vfat_sbits_strip_mapped
      );

  --------------------------------------------------------------------------------------------------------------------
  -- Active VFAT Flags
  --------------------------------------------------------------------------------------------------------------------

  active_vfats_inst : entity work.active_vfats
    port map (
      clock          => clocks.clk40,
      sbits_i        => sbits,
      active_vfats_o => active_vfats
      );

  --------------------------------------------------------------------------------------------------------------------
  -- Sbits Monitor Multiplexer
  --------------------------------------------------------------------------------------------------------------------

  process (clocks.clk40)
  begin
    if (rising_edge(clocks.clk40)) then
      sbits_mux_s0 <= vfat_sbits_strip_mapped(to_integer(unsigned(sbits_mux_sel)));
      sbits_mux_s1 <= sbits_mux_s0;
      sbits_mux    <= sbits_mux_s1;
      sbits_mux_o  <= sbits_mux;

      aff_mux <= active_vfats(to_integer(unsigned(sbits_mux_sel)));

    end if;
  end process;

  --------------------------------------------------------------------------------------------------------------------
  -- Sbits hitmap
  --------------------------------------------------------------------------------------------------------------------

  sbits_hitmap_inst : entity work.sbits_hitmap
    port map (
      clock_i   => clocks.clk40,
      reset_i   => hitmap_reset_i,
      acquire_i => hitmap_acquire_i,
      sbits_i   => vfat_sbits_strip_mapped,
      hitmap_o  => hitmap_sbits_o
      );

  --------------------------------------------------------------------------------------------------------------------
  -- Cluster Packer
  --------------------------------------------------------------------------------------------------------------------

  cluster_packer_tmr : if (true) generate
    signal clusters      : sbit_cluster_array_array_t (2 downto 0);
    signal cluster_count : t_std11_array (2 downto 0);
    signal overflow      : std_logic_vector (2 downto 0);

    attribute DONT_TOUCH                  : string;
    attribute DONT_TOUCH of clusters      : signal is "true";
    attribute DONT_TOUCH of cluster_count : signal is "true";
    attribute DONT_TOUCH of overflow      : signal is "true";
  begin

    cluster_packer_loop : for I in 0 to 2*EN_TMR_CLUSTER_PACKER generate
    begin

      cluster_packer_inst : entity work.cluster_packer
        generic map (
          DEADTIME => 0,
          ONESHOT  => false
          )
        port map (
          clocks      => clocks,
          reset       => reset_i,
          sbits_i     => vfat_sbits_strip_mapped,

          cluster_count_o => cluster_count(I),
          clusters_o      => clusters(I),
          clusters_ena_o  => open,
          overflow_o      => overflow(I)
          );
    end generate;

    tmr_gen : if (EN_TMR = 1) generate
    begin
      cluster_assign_loop : for I in 0 to NUM_FOUND_CLUSTERS-1 generate
        clusters_o(I).adr <= majority (clusters(0)(I).adr, clusters(1)(I).adr, clusters(2)(I).adr);
        clusters_o(I).cnt <= majority (clusters(0)(I).cnt, clusters(1)(I).cnt, clusters(2)(I).cnt);
        clusters_o(I).prt <= majority (clusters(0)(I).prt, clusters(1)(I).prt, clusters(2)(I).prt);
        clusters_o(I).vpf <= majority (clusters(0)(I).vpf, clusters(1)(I).vpf, clusters(2)(I).vpf);
      end generate;
      overflow_o      <= majority (overflow(0), overflow(1), overflow(2));
      cluster_count_o <= majority (cluster_count(0), cluster_count(1), cluster_count(2));
    end generate;

    notmr_gen : if (EN_TMR /= 1) generate
      clusters_o      <= clusters(0);
      overflow_o      <= overflow(0);
      cluster_count_o <= cluster_count(0);
    end generate;

  end generate;

end Behavioral;
