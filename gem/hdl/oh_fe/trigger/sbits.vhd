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
use work.cluster_pkg.all;

entity sbits is
  generic (STANDALONE_MODE : boolean := false);
  port(
    clocks : in clocks_t;

    cyclic_inject_en : std_logic := '1';

    reset_i : in std_logic;

    vfat_mask_i : in std_logic_vector (NUM_VFATS-1 downto 0);

    inject_sbits_mask_i : in std_logic_vector (NUM_VFATS-1 downto 0);
    inject_sbits_i      : in std_logic;

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
    hitmap_sbits_o   : out sbits_array_t(NUM_VFATS-1 downto 0);

    tmr_err_inj_i            : in  std_logic := '0';
    cluster_tmr_err_o        : out std_logic := '0';
    trig_alignment_tmr_err_o : out std_logic := '0'

    );
end sbits;

architecture Behavioral of sbits is

  signal inject_sbits   : std_logic_vector (NUM_VFATS-1 downto 0) := (others => '0');
  signal inject_sbits_r : std_logic_vector (NUM_VFATS-1 downto 0) := (others => '0');

  signal vfat_sbits_strip_mapped : sbits_array_t(NUM_VFATS-1 downto 0);
  signal vfat_sbits              : sbits_array_t(NUM_VFATS-1 downto 0);
  signal vfat_sbits_raw          : sbits_array_t(NUM_VFATS-1 downto 0);
  signal vfat_sbits_injected     : sbits_array_t(NUM_VFATS-1 downto 0);

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


  notstandalone_gen : if (not STANDALONE_MODE) generate

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

        sbits => sbits,

        tmr_err_o => trig_alignment_tmr_err_o
        );

  end generate;

  --------------------------------------------------------------------------------------------------------------------
  -- Channel to Strip Mapping
  --------------------------------------------------------------------------------------------------------------------

  sbit_reverse : for I in 0 to (NUM_VFATS-1) generate
  begin


    -- optionally reverse the sbit order... needed for some slots on ge11 ?

    vfat_sbits_raw (I) <= sbits ((I+1)*MXSBITS-1 downto (I)*MXSBITS)
                          when REVERSE_VFAT_SBITS(I) = '0'
                          else reverse_vector(sbits ((I+1)*MXSBITS-1 downto (I)*MXSBITS));

    -- inject sbits into the 0th channel

    stripgen : for J in 0 to 63 generate
    begin
      inj : if (J = 0) generate
        vfat_sbits_injected(I)(J) <= vfat_sbits_strip_mapped(I)(J) or inject_sbits(I);
      end generate;
      noinj : if (J /= 0) generate
        vfat_sbits_injected(I)(J) <= vfat_sbits_strip_mapped(I)(J);
      end generate;
    end generate;

  end generate;

  channel_to_strip_inst : entity work.channel_to_strip
    port map (
      channels_in => vfat_sbits_raw,
      strips_out  => vfat_sbits_strip_mapped
      );

  vfat_sbits <= vfat_sbits_injected;

  --------------------------------------------------------------------------------
  -- S-bit injector
  --------------------------------------------------------------------------------

  sbit_inject_gen : for I in 0 to (NUM_VFATS-1) generate
    process (clocks.clk40) is
      variable inj_cnt : integer range 0 to 255 := 0;
    begin

      if (rising_edge(clocks.clk40)) then
        if (inj_cnt = 255) then
          inj_cnt := 0;
        else
          inj_cnt := inj_cnt + 1;
        end if;
      end if;

      if (rising_edge(clocks.clk40)) then

        if ((inject_sbits_i = '1' and inject_sbits_mask_i(I) = '1') or
            ((cyclic_inject_en = '1' and inj_cnt = 0) and inject_sbits_mask_i(I) = '1'))
        then
          inject_sbits(I) <= '1';
        else
          inject_sbits(I) <= '0';
        end if;

      end if;
    end process;

  end generate;

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
      sbits_mux_s0 <= vfat_sbits(to_integer(unsigned(sbits_mux_sel)));
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
      sbits_i   => vfat_sbits,
      hitmap_o  => hitmap_sbits_o
      );

  --------------------------------------------------------------------------------------------------------------------
  -- Cluster Packer
  --------------------------------------------------------------------------------------------------------------------


  cluster_packer_tmr : if (true) generate

    type sbit_cluster_array_array_t is array(integer range<>)
      of sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);

    signal clusters      : sbit_cluster_array_array_t (2 downto 0);
    signal cluster_count : t_std11_array (2 downto 0);
    signal overflow      : std_logic_vector (2 downto 0);

    attribute DONT_TOUCH                  : string;
    attribute DONT_TOUCH of clusters      : signal is "true";
    attribute DONT_TOUCH of cluster_count : signal is "true";
    attribute DONT_TOUCH of overflow      : signal is "true";

    signal cluster_tmr_err : std_logic_vector (2+NUM_FOUND_CLUSTERS-1 downto 0);

    signal tmr_err_inj : std_logic := '0';

  begin

    cluster_packer_loop : for I in 0 to 2*EN_TMR_CLUSTER_PACKER generate
    begin

      errinj : if (I = 0) generate
        tmr_err_inj <= tmr_err_inj_i;
      end generate;

      cluster_packer_inst : entity work.cluster_packer
        generic map (
          DEADTIME       => 0,
          ONESHOT        => true,
          NUM_VFATS      => NUM_VFATS,
          NUM_PARTITIONS => NUM_PARTITIONS,
          STATION        => STATION
          )
        port map (
          clk_40   => clocks.clk40,
          clk_fast => clocks.clk160_0,
          reset    => reset_i or tmr_err_inj,

          sbits_i => vfat_sbits,

          cluster_count_o => cluster_count(I),
          clusters_o      => clusters(I),
          clusters_ena_o  => open,
          overflow_o      => overflow(I)
          );
    end generate;

    tmr_gen : if (EN_TMR = 1) generate
    begin

      majority_err (overflow_o, cluster_tmr_err(0), overflow(0), overflow(1), overflow(2));
      majority_err (cluster_count_o, cluster_tmr_err(1), cluster_count(0), cluster_count(1), cluster_count(2));

      cluster_assign_loop : for I in 0 to NUM_FOUND_CLUSTERS-1 generate
        signal err : std_logic_vector (3 downto 0) := (others => '0');
      begin

        majority_err (clusters_o(I).adr, err(0), clusters(0)(I).adr, clusters(1)(I).adr, clusters(2)(I).adr);
        majority_err (clusters_o(I).cnt, err(1), clusters(0)(I).cnt, clusters(1)(I).cnt, clusters(2)(I).cnt);
        majority_err (clusters_o(I).prt, err(2), clusters(0)(I).prt, clusters(1)(I).prt, clusters(2)(I).prt);
        majority_err (clusters_o(I).vpf, err(3), clusters(0)(I).vpf, clusters(1)(I).vpf, clusters(2)(I).vpf);

        cluster_tmr_err(2+I) <= or_reduce(err);
      end generate;
    end generate;

    notmr_gen : if (EN_TMR /= 1) generate
      clusters_o      <= clusters(0);
      overflow_o      <= overflow(0);
      cluster_count_o <= cluster_count(0);
    end generate;

    process (clocks.clk40) is
    begin
      if (rising_edge(clocks.clk40)) then
        cluster_tmr_err_o <= or_reduce(cluster_tmr_err);
      end if;
    end process;

  end generate;

end Behavioral;
