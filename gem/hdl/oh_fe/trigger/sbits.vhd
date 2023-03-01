----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid v3 Firmware -- S-Bits
-- A. Peck
----------------------------------------------------------------------------------
-- Description:
--
--   This module wraps up all the functionality for deserializing 320 MHz S-bits
--   as well as the cluster packer
--
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
  port(
    clocks : in clocks_t;

    cyclic_inject_en : std_logic := '1';

    reset_i : in std_logic;

    ttc : in ttc_t;

    l1a_mask_delay   : in std_logic_vector(4 downto 0);
    l1a_mask_bitmask : in std_logic_vector(31 downto 0);

    reverse_partitions_i : in std_logic                     := '0';
    sbit_map_sel         : in std_logic_vector (1 downto 0) := (others => '0');

    vfat_mask_i : in std_logic_vector (NUM_VFATS-1 downto 0);

    inject_sbits_mask_i : in std_logic_vector (NUM_VFATS-1 downto 0);
    inject_sbits_i      : in std_logic;

    sot_invert_i : in std_logic_vector (NUM_VFATS-1 downto 0);    -- 24 or 12
    tu_invert_i  : in std_logic_vector (NUM_VFATS*8-1 downto 0);  -- 192 or 96
    tu_mask_i    : in std_logic_vector (NUM_VFATS*8-1 downto 0);  -- 192 or 96

    aligned_count_to_ready : in std_logic_vector (11 downto 0);

    sbits_p : in std_logic_vector (NUM_VFATS*8-1 downto 0);
    sbits_n : in std_logic_vector (NUM_VFATS*8-1 downto 0);

    start_of_frame_p : in std_logic_vector (NUM_VFATS-1 downto 0);
    start_of_frame_n : in std_logic_vector (NUM_VFATS-1 downto 0);


    active_vfats_o : out std_logic_vector (NUM_VFATS-1 downto 0);

    clusters_o               : out sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);
    cluster_count_masked_o   : out std_logic_vector (10 downto 0);
    cluster_count_unmasked_o : out std_logic_vector (10 downto 0);
    overflow_o               : out std_logic;

    sot_is_aligned_o      : out std_logic_vector (NUM_VFATS-1 downto 0) := (others => '0');
    sot_unstable_o        : out std_logic_vector (NUM_VFATS-1 downto 0) := (others => '0');
    sot_invalid_bitskip_o : out std_logic_vector (NUM_VFATS-1 downto 0) := (others => '0');

    sot_tap_delay  : in t_std5_array (NUM_VFATS-1 downto 0);
    trig_tap_delay : in t_std5_array (NUM_VFATS*8-1 downto 0);

    hitmap_reset_i   : in  std_logic;
    hitmap_acquire_i : in  std_logic;
    hitmap_sbits_o   : out sbits_array_t(NUM_VFATS-1 downto 0);

    tmr_err_inj_i            : in  std_logic := '0';
    cluster_tmr_err_o        : out std_logic := '0';
    sbit_tmr_err_o           : out std_logic := '0';
    sot_tmr_err_o            : out std_logic := '0';
    frame_aligner_tmr_err_o  : out std_logic := '0';
    trig_alignment_tmr_err_o : out std_logic := '0';

    sbit_bx_dlys_enable_i : in std_logic_vector (NUM_VFATS*MXSBITS/SBIT_BX_DELAY_GRP_SIZE-1 downto 0);
    sbit_bx_dlys_i        : in sbit_bx_dly_array_t (NUM_VFATS*64/SBIT_BX_DELAY_GRP_SIZE-1 downto 0)

    );
end sbits;

architecture Behavioral of sbits is

  signal l1a_pipeline : std_logic_vector (31 downto 0) := (others => '0');
  signal l1a_delayed  : std_logic;
  signal mask_l1a     : std_logic;
  signal l1a_bitmask  : std_logic_vector (31 downto 0) := (others => '0');

  signal inject_sbits   : std_logic_vector (NUM_VFATS-1 downto 0) := (others => '0');

  signal vfat_sbits_strip_mapped : sbits_array_t(NUM_VFATS-1 downto 0);
  signal vfat_sbits_raw          : sbits_array_t(NUM_VFATS-1 downto 0);
  signal vfat_sbits_40m          : sbits_array_t(NUM_VFATS-1 downto 0);
  signal vfat_sbits_160m         : sbits_array_t(NUM_VFATS-1 downto 0);
  signal vfat_sbits_injected     : sbits_array_t(NUM_VFATS-1 downto 0);
  signal vfat_sbits_delayed      : sbits_array_t(NUM_VFATS-1 downto 0);

  signal sbits : std_logic_vector (MXSBITS_CHAMBER-1 downto 0) := (others => '0');

  -- multiplex together the 1536 s-bits into a single chip-scope accessible register
  -- don't want to affect timing, so do it through a couple of flip-flop stages

  -- function to replicate a std_logic bit some number of times
  -- equivalent to verilog's built in {n{x}} operator
  function repeat(B : std_logic; N : integer)
    return std_logic_vector
  is
    variable result : std_logic_vector(1 to N);
  begin
    for i in 1 to N loop
      result(i) := B;
    end loop;
    return result;
  end;

begin

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

      sbits => sbits,

      sbit_tmr_err_o          => sbit_tmr_err_o,
      sot_tmr_err_o           => sot_tmr_err_o,
      frame_aligner_tmr_err_o => frame_aligner_tmr_err_o,
      tmr_err_o               => trig_alignment_tmr_err_o
      );

  --------------------------------------------------------------------------------------------------------------------
  -- Channel to Strip Mapping
  --------------------------------------------------------------------------------------------------------------------

  process (clocks.clk160_0) is
  begin
    if (rising_edge(clocks.clk160_0)) then
      vfat_sbits_160m <= vfat_sbits_raw;
    end if;
  end process;

  process (clocks.clk40) is
  begin
    if (rising_edge(clocks.clk40)) then
      vfat_sbits_40m <= vfat_sbits_raw;
    end if;
  end process;

  sbit_reverse : for I in 0 to (NUM_VFATS-1) generate
  begin

    -- deserializer --> sbits --> reverse? --> vfat_sbits_raw -->
    --
    --  raw --> vfat_sbits_40m --> active vfats / hitmap
    --
    --  raw --> vfat_sbits_160m --> vfat_sbits_strip_mapped --> vfat_sbits_injected --> clusterizer
    --

    -- optionally reverse the sbit order... needed for some slots on ge11 ?

    vfat_sbits_raw (I) <= sbits ((I+1)*MXSBITS-1 downto (I)*MXSBITS)
                          when REVERSE_VFAT_SBITS(I) = '0'
                          else reverse_vector(sbits ((I+1)*MXSBITS-1 downto (I)*MXSBITS));

    -- inject sbits into the 0th channel

    stripgen : for J in 0 to 63 generate
    begin
      inj : if (J = 23 or J=24 or J=25) generate
        vfat_sbits_injected(I)(J) <= vfat_sbits_strip_mapped(I)(J) or inject_sbits(I);
      end generate;
      noinj : if (J /= 23 and J/=24 and J/=25) generate
        vfat_sbits_injected(I)(J) <= vfat_sbits_strip_mapped(I)(J);
      end generate;
    end generate;

  end generate;

  channel_to_strip_inst : entity work.channel_to_strip
    generic map (
      USE_DYNAMIC_MAPPING => true,
      REGISTER_INPUT      => false,
      REGISTER_OUTPUT     => true
      )
    port map (
      clock       => clocks.clk160_0,
      mapping     => to_integer (unsigned (sbit_map_sel)),
      channels_in => vfat_sbits_160m,
      strips_out  => vfat_sbits_strip_mapped
      );

  --------------------------------------------------------------------------------
  -- S-bit injector
  --------------------------------------------------------------------------------

  sbit_inject_gen : for I in 0 to (NUM_VFATS-1) generate
    process (clocks.clk40) is
      variable inj_cnt : integer range 0 to 296 := 0;
    begin

      if (rising_edge(clocks.clk40)) then
        if (inj_cnt = 296 or ttc.bc0='1') then
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
      sbits_i        => vfat_sbits_40m,
      active_vfats_o => active_vfats_o
      );

  --------------------------------------------------------------------------------------------------------------------
  -- Sbits hitmap
  --------------------------------------------------------------------------------------------------------------------

  sbits_hitmap_inst : entity work.sbits_hitmap
    port map (
      clock_i   => clocks.clk40,
      reset_i   => hitmap_reset_i,
      acquire_i => hitmap_acquire_i,
      sbits_i   => vfat_sbits_40m,
      hitmap_o  => hitmap_sbits_o
      );

  --------------------------------------------------------------------------------
  -- L1A Delay
  --------------------------------------------------------------------------------

  l1a_pipeline(0) <= ttc.l1a;
  l1a_delayed     <= l1a_pipeline(to_integer(unsigned(l1a_mask_delay)));

  process (clocks.clk40) is
  begin
    if (rising_edge(clocks.clk40)) then
      for I in 1 to l1a_pipeline'left loop
        l1a_pipeline(I) <= l1a_pipeline(I-1);
      end loop;
    end if;
  end process;

  process (clocks.clk40) is
  begin
    if (rising_edge(clocks.clk40)) then
        l1a_bitmask <= '0' & l1a_bitmask(31 downto 1) or
                       (l1a_mask_bitmask and repeat(l1a_delayed, l1a_mask_bitmask'length));
    end if;
  end process;

  mask_l1a <= l1a_bitmask(0);

  --------------------------------------------------------------------------------
  -- Sbit Delays
  --------------------------------------------------------------------------------

  sbit_delay_inst : entity work.sbit_delay
    generic map (
      NUM_VFATS      => NUM_VFATS
      )
    port map (
      clock          => clocks.clk160_0,
      sbits_i        => vfat_sbits_injected,
      sbits_o        => vfat_sbits_delayed,
      dly_enable     => sbit_bx_dlys_enable_i,
      sbit_bx_dlys_i => sbit_bx_dlys_i
      );

  --------------------------------------------------------------------------------------------------------------------
  -- Cluster Packer
  --------------------------------------------------------------------------------------------------------------------

  cluster_packer_tmr : if (true) generate  -- generate for local scoped signals

    type sbit_cluster_array_array_t is array(integer range<>)
      of sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);

    signal clusters_unmasked_tmr : sbit_cluster_array_array_t (2 downto 0);
    signal clusters_masked_tmr   : sbit_cluster_array_array_t (2 downto 0);

    signal clusters_masked   : sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);
    signal clusters_unmasked : sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);
    signal clusters_rev      : sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);
    signal clusters_norev    : sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);

    signal cluster_count_masked   : t_std11_array (2 downto 0);
    signal cluster_count_unmasked : t_std11_array (2 downto 0);

    signal overflow : std_logic_vector (2 downto 0);

    signal reverse_partitions : std_logic := '0';

    attribute DONT_TOUCH                           : string;
    attribute DONT_TOUCH of clusters_unmasked_tmr  : signal is "true";
    attribute DONT_TOUCH of clusters_masked_tmr    : signal is "true";
    attribute DONT_TOUCH of cluster_count_masked   : signal is "true";
    attribute DONT_TOUCH of cluster_count_unmasked : signal is "true";
    attribute DONT_TOUCH of overflow               : signal is "true";

    signal cluster_tmr_err     : std_logic_vector (3+NUM_FOUND_CLUSTERS-1 downto 0);
    signal cluster_tmr_err_reg : std_logic;

    signal tmr_err_inj : std_logic := '0';

  begin

    cluster_packer_loop : for I in 0 to 2*EN_TMR_CLUSTER_PACKER generate
    begin

      errinj : if (I = 0) generate
        tmr_err_inj <= tmr_err_inj_i;
      end generate;

      cluster_packer_inst : entity work.cluster_packer
        generic map (
          ONESHOT        => true,
          NUM_VFATS      => NUM_VFATS,
          NUM_PARTITIONS => NUM_PARTITIONS,
          STATION        => STATION
          )
        port map (
          clk_40   => clocks.clk40,
          clk_fast => clocks.clk160_0,
          reset    => reset_i,

          mask_output_i => mask_l1a,

          sbits_i => vfat_sbits_delayed,

          clusters_o      => clusters_unmasked_tmr(I),
          cluster_count_o => cluster_count_unmasked(I),

          clusters_masked_o      => clusters_masked_tmr(I),
          cluster_count_masked_o => cluster_count_masked(I),

          overflow_o => overflow(I),
          valid_o    => open
          );
    end generate;

    tmr_gen : if (EN_TMR_CLUSTER_PACKER = 1) generate
    begin

      majority_err (overflow_o, cluster_tmr_err(0), tmr_err_inj xor overflow(0), overflow(1), overflow(2));

      majority_err (cluster_count_masked_o, cluster_tmr_err(1), cluster_count_masked(0), cluster_count_masked(1), cluster_count_masked(2));
      majority_err (cluster_count_unmasked_o, cluster_tmr_err(2), cluster_count_unmasked(0), cluster_count_unmasked(1), cluster_count_unmasked(2));

      cluster_assign_loop : for I in 0 to NUM_FOUND_CLUSTERS-1 generate
        signal err : std_logic_vector (7 downto 0) := (others => '0');

        component ila_cluster_tmr
          port (
            clk    : in std_logic;
            probe0 : in std_logic_vector(8 downto 0);
            probe1 : in std_logic_vector(8 downto 0);
            probe2 : in std_logic_vector(8 downto 0);
            probe3 : in std_logic_vector(2 downto 0);
            probe4 : in std_logic_vector(2 downto 0);
            probe5 : in std_logic_vector(2 downto 0);
            probe6 : in std_logic_vector(2 downto 0);
            probe7 : in std_logic_vector(2 downto 0);
            probe8 : in std_logic_vector(2 downto 0);
            probe9 : in std_logic_vector(0 downto 0);
            probe10: in std_logic_vector(0 downto 0);
            probe11: in std_logic_vector(0 downto 0);
            probe12: in std_logic_vector(7 downto 0)
            );
        end component;

      begin

        ila_gen : if (GE21 = 1 and I=0) generate
          i_ila_cluster_tmr : ila_cluster_tmr
            port map(
              clk                 => clocks.clk40,
              probe0(8 downto 0)  => clusters_unmasked_tmr(0)(I).adr,
              probe1(8 downto 0)  => clusters_unmasked_tmr(1)(I).adr,
              probe2(8 downto 0)  => clusters_unmasked_tmr(2)(I).adr,
              probe3(2 downto 0)  => clusters_unmasked_tmr(0)(I).cnt,
              probe4(2 downto 0)  => clusters_unmasked_tmr(1)(I).cnt,
              probe5(2 downto 0)  => clusters_unmasked_tmr(2)(I).cnt,
              probe6(2 downto 0)  => clusters_unmasked_tmr(0)(I).prt,
              probe7(2 downto 0)  => clusters_unmasked_tmr(1)(I).prt,
              probe8(2 downto 0)  => clusters_unmasked_tmr(2)(I).prt,
              probe9(0)           => clusters_unmasked_tmr(0)(I).vpf,
              probe10(0)          => clusters_unmasked_tmr(1)(I).vpf,
              probe11(0)          => clusters_unmasked_tmr(2)(I).vpf,
              probe12(7 downto 0) => err
              );
        end generate;

        majority_err (clusters_unmasked(I).adr, err(0), clusters_unmasked_tmr(0)(I).adr, clusters_unmasked_tmr(1)(I).adr, clusters_unmasked_tmr(2)(I).adr);
        majority_err (clusters_unmasked(I).cnt, err(1), clusters_unmasked_tmr(0)(I).cnt, clusters_unmasked_tmr(1)(I).cnt, clusters_unmasked_tmr(2)(I).cnt);
        majority_err (clusters_unmasked(I).prt, err(2), clusters_unmasked_tmr(0)(I).prt, clusters_unmasked_tmr(1)(I).prt, clusters_unmasked_tmr(2)(I).prt);
        majority_err (clusters_unmasked(I).vpf, err(3), clusters_unmasked_tmr(0)(I).vpf, clusters_unmasked_tmr(1)(I).vpf, clusters_unmasked_tmr(2)(I).vpf);

        majority_err (clusters_masked(I).adr, err(4), clusters_masked_tmr(0)(I).adr, clusters_masked_tmr(1)(I).adr, clusters_masked_tmr(2)(I).adr);
        majority_err (clusters_masked(I).cnt, err(5), clusters_masked_tmr(0)(I).cnt, clusters_masked_tmr(1)(I).cnt, clusters_masked_tmr(2)(I).cnt);
        majority_err (clusters_masked(I).prt, err(6), clusters_masked_tmr(0)(I).prt, clusters_masked_tmr(1)(I).prt, clusters_masked_tmr(2)(I).prt);
        majority_err (clusters_masked(I).vpf, err(7), clusters_masked_tmr(0)(I).vpf, clusters_masked_tmr(1)(I).vpf, clusters_masked_tmr(2)(I).vpf);

        cluster_tmr_err(3+I) <= or_reduce(err);
      end generate;
    end generate;

    notmr_gen : if (EN_TMR_CLUSTER_PACKER /= 1) generate
      clusters_masked          <= clusters_masked_tmr(0);
      clusters_unmasked        <= clusters_unmasked_tmr(0);
      overflow_o               <= overflow(0);
      cluster_count_masked_o   <= cluster_count_masked(0);
      cluster_count_unmasked_o <= cluster_count_unmasked(0);
    end generate;

    reverse_gen : for I in clusters_o'range generate

      --------------------------------------------------------------------------------
      -- Reversed
      --------------------------------------------------------------------------------

      clusters_rev(I).vpf <= clusters_masked(I).vpf;
      clusters_rev(I).cnt <= clusters_masked(I).cnt;
      clusters_rev(I).prt <= clusters_masked(I).prt;
      --new_address = 384 - (address + size)  (GE21)
      --new_address = 191 - (address + size)  (GE11)
      clusters_rev(I).adr <=
        std_logic_vector(to_unsigned(MXSBITS*PARTITION_SIZE-1 -
                                     (to_integer(unsigned(clusters_masked(I).adr)) +
                                      to_integer(unsigned(clusters_masked(I).cnt))), clusters_rev(I).adr'length));

      --------------------------------------------------------------------------------
      -- Non-reversed
      --------------------------------------------------------------------------------

      clusters_norev(I) <= clusters_masked(I);

    end generate;

    --------------------------------------------------------------------------------
    -- Cluster Outputs
    --------------------------------------------------------------------------------

    process (clocks.clk160_0) is
    begin
      if (rising_edge(clocks.clk160_0)) then
        reverse_partitions <= reverse_partitions_i;
      end if;
    end process;

    process (clocks.clk160_0) is
    begin
      if (rising_edge(clocks.clk160_0)) then
        if (reverse_partitions = '1') then
          clusters_o <= clusters_rev;
        else
          clusters_o <=  clusters_norev;
        end if;
      end if;
    end process;

    ila_gen : if (GE21 = 1) generate
      component ila_cluster
        port (
          clk    : in std_logic;
          probe0 : in std_logic_vector(1+3+3+8 downto 0);
          probe1 : in std_logic_vector(1+3+3+8 downto 0);
          probe2 : in std_logic_vector(1+3+3+8 downto 0);
          probe3 : in std_logic_vector(1+3+3+8 downto 0);
          probe4 : in std_logic_vector(1+3+3+8 downto 0);
          probe5 : in std_logic_vector(1+3+3+8 downto 0);
          probe6 : in std_logic_vector(1+3+3+8 downto 0);
          probe7 : in std_logic_vector(1+3+3+8 downto 0)
          );
      end component;
    begin

      i_ila_cluster : ila_cluster
        port map (
          clk                  => clocks.clk40,
          probe0(8 downto 0)   => clusters_norev(0).adr,
          probe0(11 downto 9)  => clusters_norev(0).cnt,
          probe0(14 downto 12) => clusters_norev(0).prt,
          probe0(15)           => clusters_norev(0).vpf,
          probe1(8 downto 0)   => clusters_norev(1).adr,
          probe1(11 downto 9)  => clusters_norev(1).cnt,
          probe1(14 downto 12) => clusters_norev(1).prt,
          probe1(15)           => clusters_norev(1).vpf,
          probe2(8 downto 0)   => clusters_norev(2).adr,
          probe2(11 downto 9)  => clusters_norev(2).cnt,
          probe2(14 downto 12) => clusters_norev(2).prt,
          probe2(15)           => clusters_norev(2).vpf,
          probe3(8 downto 0)   => clusters_norev(3).adr,
          probe3(11 downto 9)  => clusters_norev(3).cnt,
          probe3(14 downto 12) => clusters_norev(3).prt,
          probe3(15)           => clusters_norev(3).vpf,
          probe4(8 downto 0)   => clusters_norev(4).adr,
          probe4(11 downto 9)  => clusters_norev(4).cnt,
          probe4(14 downto 12) => clusters_norev(4).prt,
          probe4(15)           => clusters_norev(4).vpf,
          probe5(8 downto 0)   => clusters_norev(5).adr,
          probe5(11 downto 9)  => clusters_norev(5).cnt,
          probe5(14 downto 12) => clusters_norev(5).prt,
          probe5(15)           => clusters_norev(5).vpf,
          probe6(8 downto 0)   => clusters_norev(6).adr,
          probe6(11 downto 9)  => clusters_norev(6).cnt,
          probe6(14 downto 12) => clusters_norev(6).prt,
          probe6(15)           => clusters_norev(6).vpf,
          probe7(8 downto 0)   => clusters_norev(7).adr,
          probe7(11 downto 9)  => clusters_norev(7).cnt,
          probe7(14 downto 12) => clusters_norev(7).prt,
          probe7(15)           => clusters_norev(7).vpf
          );

    end generate;

    --------------------------------------------------------------------------------
    -- Cluster TMR Output
    --------------------------------------------------------------------------------

    -- register on the 160 MHz clock the or_reduce
    -- then transfer to the 40MHz clock

    process (clocks.clk160_0) is
    begin
      if (rising_edge(clocks.clk160_0)) then
        cluster_tmr_err_reg <= or_reduce(cluster_tmr_err);
      end if;
    end process;

    process (clocks.clk40) is
    begin
      if (rising_edge(clocks.clk40)) then
        cluster_tmr_err_o <= cluster_tmr_err_reg;
      end if;
    end process;

  end generate;

end Behavioral;
