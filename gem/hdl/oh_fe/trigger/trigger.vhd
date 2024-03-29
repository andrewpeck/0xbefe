----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid v3 Firmware -- Trigger
-- A. Peck
----------------------------------------------------------------------------------
-- Description:
--   This module holds all the required functionality for the trigger S-bit alignment
--   and cluster building
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;


library work;
use work.types_pkg.all;
use work.ipbus_pkg.all;
use work.hardware_pkg.all;
use work.cluster_pkg.all;
use work.registers.all;

entity trigger is
  generic(STANDALONE_MODE : boolean := false);
  port(

    -- ipbus wishbone

    ipb_mosi_i : in  ipb_wbus;
    ipb_miso_o : out ipb_rbus;

    clocks : in clocks_t;
    ttc    : in ttc_t;

    sbit_clusters_o : out sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);

    reset_i : in std_logic;

    -- ttc

    bxn_counter_i : in std_logic_vector(11 downto 0);

    -- cluster packer

    cluster_count_masked_o   : out std_logic_vector (10 downto 0);
    cluster_count_unmasked_o : out std_logic_vector (10 downto 0);
    overflow_o               : out std_logic;

    active_vfats_o : out std_logic_vector (NUM_VFATS-1 downto 0);

    -- sbits
    vfat_sot_p : in std_logic_vector (NUM_VFATS-1 downto 0);
    vfat_sot_n : in std_logic_vector (NUM_VFATS-1 downto 0);

    vfat_sbits_p : in std_logic_vector ((NUM_VFATS*8)-1 downto 0);
    vfat_sbits_n : in std_logic_vector ((NUM_VFATS*8)-1 downto 0);

    -- sbits

    master_slave_p : inout std_logic_vector (11 downto 0);
    master_slave_n : inout std_logic_vector (11 downto 0);

    trigger_prbs_en_o : out std_logic;

    trig_formatter_tmr_err : in std_logic;

    cnt_snap : in std_logic

    );
end trigger;

architecture Behavioral of trigger is

  signal trigger_prbs_en : std_logic;

  signal sbitmon_l1a_delay       : std_logic_vector (31 downto 0);
  signal sbitmon_trig_on_invalid : std_logic := '0';

  signal l1a_mask_delay : std_logic_vector(4 downto 0);
  signal l1a_mask_bitmask : std_logic_vector(31 downto 0);

  signal sbit_overflow   : std_logic;
  signal sbit_clusters, sbit_clusters_ff   : sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);
  signal frozen_clusters : sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);
  signal valid_clusters  : std_logic_vector (NUM_FOUND_CLUSTERS downto 0);

  signal valid_clusters_or : std_logic;

  signal cluster_count_ff       : std_logic_vector (10 downto 0);
  signal cluster_count_masked   : std_logic_vector (10 downto 0);
  signal cluster_count_unmasked : std_logic_vector (10 downto 0);

  signal active_vfats : std_logic_vector (NUM_VFATS-1 downto 0);

  signal vfat_mask     : std_logic_vector (NUM_VFATS-1 downto 0);

  signal sbits_comparator_over_threshold : std_logic_vector (NUM_VFATS-1 downto 0);

  signal sot_invert : std_logic_vector (NUM_VFATS-1 downto 0);      -- 24 or 12
  signal tu_invert  : std_logic_vector ((NUM_VFATS*8)-1 downto 0);  -- 192 or 96
  signal tu_mask    : std_logic_vector ((NUM_VFATS*8)-1 downto 0);  -- 192 or 96

  signal aligned_count_to_ready : std_logic_vector (11 downto 0);

  signal reset_monitor : std_logic;
  signal ipb_reset     : std_logic;

  attribute EQUIVALENT_REGISTER_REMOVAL              : string;
  attribute EQUIVALENT_REGISTER_REMOVAL of ipb_reset : signal is "NO";

  signal sot_is_aligned      : std_logic_vector (NUM_VFATS-1 downto 0);
  signal sot_unstable        : std_logic_vector (NUM_VFATS-1 downto 0);
  signal sot_invalid_bitskip : std_logic_vector (NUM_VFATS-1 downto 0);

  signal sot_tap_delay  : t_std5_array (NUM_VFATS-1 downto 0);
  signal trig_tap_delay : t_std5_array ((NUM_VFATS*8)-1 downto 0);

  signal inject_sbits_mask : std_logic_vector (23 downto 0) := (others => '0');
  signal inject_sbits      : std_logic;
  signal cyclic_inject_en  : std_logic;

  signal hitmap_reset   : std_logic;
  signal hitmap_acquire : std_logic;
  signal hitmap_sbits   : sbits_array_t(NUM_VFATS-1 downto 0);

  signal sbit_bx_dlys : sbit_bx_dly_array_t (NUM_VFATS*64/SBIT_BX_DELAY_GRP_SIZE-1 downto 0) := (others => (others => '0'));
  signal sbit_bx_dlys_enable : std_logic_vector (NUM_VFATS*MXSBITS/SBIT_BX_DELAY_GRP_SIZE-1 downto 0);

  -- control signals from gbt (verb, object)
  signal reset_counters    : std_logic;
  signal sbit_cnt_persist  : std_logic;
  signal sbit_cnt_time_max : std_logic_vector (31 downto 0);

  signal sbit_cnt_snap    : std_logic;
  signal sbit_timer_snap  : std_logic;
  signal sbit_timer_reset : std_logic;

  signal sbit_time_counter : unsigned (31 downto 0);

  -- reset signal (ORed with global reset)
  signal cnt_reset         : std_logic;
  signal cnt_reset_strobed : std_logic;

  signal tmr_err_inj            : std_logic;
  signal tmr_cnt_reset          : std_logic;
  signal cluster_tmr_err        : std_logic;
  signal trig_alignment_tmr_err : std_logic;
  signal ipb_slave_tmr_err      : std_logic;

  signal reverse_partitions : std_logic := '0';
  signal sbit_map_sel : std_logic_vector (1 downto 0) := (others => '0');

  ------ Register signals begin (this section is generated by <optohybrid_top>/tools/generate_registers.py -- do not edit)
    signal regs_read_arr        : t_std32_array(REG_TRIG_NUM_REGS - 1 downto 0) := (others => (others => '0'));
    signal regs_write_arr       : t_std32_array(REG_TRIG_NUM_REGS - 1 downto 0) := (others => (others => '0'));
    signal regs_addresses       : t_std32_array(REG_TRIG_NUM_REGS - 1 downto 0) := (others => (others => '0'));
    signal regs_defaults        : t_std32_array(REG_TRIG_NUM_REGS - 1 downto 0) := (others => (others => '0'));
    signal regs_read_pulse_arr  : std_logic_vector(REG_TRIG_NUM_REGS - 1 downto 0) := (others => '0');
    signal regs_write_pulse_arr : std_logic_vector(REG_TRIG_NUM_REGS - 1 downto 0) := (others => '0');
    signal regs_read_ready_arr  : std_logic_vector(REG_TRIG_NUM_REGS - 1 downto 0) := (others => '1');
    signal regs_write_done_arr  : std_logic_vector(REG_TRIG_NUM_REGS - 1 downto 0) := (others => '1');
    signal regs_writable_arr    : std_logic_vector(REG_TRIG_NUM_REGS - 1 downto 0) := (others => '0');
    -- Connect counter signal declarations
    signal cnt_sbit_overflow : std_logic_vector (15 downto 0) := (others => '0');
    signal cnt_vfat0 : std_logic_vector (31 downto 0) := (others => '0');
    signal cnt_vfat1 : std_logic_vector (31 downto 0) := (others => '0');
    signal cnt_vfat2 : std_logic_vector (31 downto 0) := (others => '0');
    signal cnt_vfat3 : std_logic_vector (31 downto 0) := (others => '0');
    signal cnt_vfat4 : std_logic_vector (31 downto 0) := (others => '0');
    signal cnt_vfat5 : std_logic_vector (31 downto 0) := (others => '0');
    signal cnt_vfat6 : std_logic_vector (31 downto 0) := (others => '0');
    signal cnt_vfat7 : std_logic_vector (31 downto 0) := (others => '0');
    signal cnt_vfat8 : std_logic_vector (31 downto 0) := (others => '0');
    signal cnt_vfat9 : std_logic_vector (31 downto 0) := (others => '0');
    signal cnt_vfat10 : std_logic_vector (31 downto 0) := (others => '0');
    signal cnt_vfat11 : std_logic_vector (31 downto 0) := (others => '0');
    signal cnt_clusters : std_logic_vector (31 downto 0) := (others => '0');
    signal cnt_over_threshold0 : std_logic_vector (15 downto 0) := (others => '0');
    signal cnt_over_threshold1 : std_logic_vector (15 downto 0) := (others => '0');
    signal cnt_over_threshold2 : std_logic_vector (15 downto 0) := (others => '0');
    signal cnt_over_threshold3 : std_logic_vector (15 downto 0) := (others => '0');
    signal cnt_over_threshold4 : std_logic_vector (15 downto 0) := (others => '0');
    signal cnt_over_threshold5 : std_logic_vector (15 downto 0) := (others => '0');
    signal cnt_over_threshold6 : std_logic_vector (15 downto 0) := (others => '0');
    signal cnt_over_threshold7 : std_logic_vector (15 downto 0) := (others => '0');
    signal cnt_over_threshold8 : std_logic_vector (15 downto 0) := (others => '0');
    signal cnt_over_threshold9 : std_logic_vector (15 downto 0) := (others => '0');
    signal cnt_over_threshold10 : std_logic_vector (15 downto 0) := (others => '0');
    signal cnt_over_threshold11 : std_logic_vector (15 downto 0) := (others => '0');
    signal cluster_tmr_err_cnt : std_logic_vector (15 downto 0) := (others => '0');
    signal trig_alignment_tmr_err_cnt : std_logic_vector (15 downto 0) := (others => '0');
    signal ipb_slave_tmr_err_cnt : std_logic_vector (15 downto 0) := (others => '0');
    signal trig_formatter_tmr_err_cnt : std_logic_vector (15 downto 0) := (others => '0');
  ------ Register signals end ----------------------------------------------

begin

  --------------------------------------------------------------------------------------------------------------------
  -- Resets
  --------------------------------------------------------------------------------------------------------------------

  ipb_reset <= reset_i;

  process (clocks.clk40)
  begin
    if (rising_edge(clocks.clk40)) then
      cnt_reset         <= reset_i or ttc.resync or reset_counters;
      cnt_reset_strobed <= reset_i or ttc.resync or reset_counters or (sbit_timer_reset and not sbit_cnt_persist);
    end if;
  end process;

  --------------------------------------------------------------------------------------------------------------------
  -- Outputs
  --------------------------------------------------------------------------------------------------------------------

  trigger_prbs_en_o        <= trigger_prbs_en;
  overflow_o               <= sbit_overflow;
  active_vfats_o           <= active_vfats;
  cluster_count_masked_o   <= cluster_count_masked;
  cluster_count_unmasked_o <= cluster_count_unmasked;

  --------------------------------------------------------------------------------------------------------------------
  -- Counter Snap
  --------------------------------------------------------------------------------------------------------------------

  process (clocks.clk40)
  begin
    if (rising_edge(clocks.clk40)) then

      sbit_cnt_snap <= (sbit_timer_snap or sbit_cnt_persist);

      if (reset_i = '1' or reset_counters = '1') then
        sbit_time_counter <= (others => '0');
        sbit_timer_reset  <= '1';
        sbit_timer_snap   <= '1';
      else
        if (sbit_time_counter = unsigned(sbit_cnt_time_max)) then
          sbit_time_counter <= (others => '0');
          sbit_timer_reset  <= '1';
          sbit_timer_snap   <= '1';
        else
          sbit_time_counter <= sbit_time_counter + 1;
          sbit_timer_reset  <= '0';
          sbit_timer_snap   <= '0';
        end if;
      end if;

    end if;
  end process;

  --------------------------------------------------------------------------------------------------------------------
  -- S-bit overflow comparator
  --------------------------------------------------------------------------------------------------------------------

  process (clocks.clk40)
  begin
    if (rising_edge(clocks.clk40)) then

      if (unsigned(cluster_count_ff) > 0) then
        sbits_comparator_over_threshold(0) <= '1';
      else
        sbits_comparator_over_threshold(0) <= '0';
      end if;
    end if;
  end process;

  clusters_over_threshold_loop : for I in 1 to (NUM_VFATS-1) generate
  begin

    process (clocks.clk40)
    begin
      if (rising_edge(clocks.clk40)) then
        if (unsigned(cluster_count_ff) > 63*I) then
          sbits_comparator_over_threshold(I) <= '1';
        else
          sbits_comparator_over_threshold(I) <= '0';
        end if;
      end if;
    end process;

  end generate;

  --------------------------------------------------------------------------------------------------------------------
  -- S-bit deserilization and cluster building
  --------------------------------------------------------------------------------------------------------------------

  sbits : entity work.sbits
    generic map (STANDALONE_MODE => STANDALONE_MODE)
    port map (

      -- clock and reset
      clocks  => clocks,
      reset_i => reset_i,

      ttc            => ttc,
      l1a_mask_delay => l1a_mask_delay,
      l1a_mask_bitmask => l1a_mask_bitmask,

      -- sbit inputs
      sbits_p => vfat_sbits_p,
      sbits_n => vfat_sbits_n,

      start_of_frame_p => vfat_sot_p,
      start_of_frame_n => vfat_sot_n,

      -- control

      reverse_partitions_i   => reverse_partitions,
      sbit_map_sel           => sbit_map_sel,
      aligned_count_to_ready => aligned_count_to_ready,
      vfat_mask_i            => vfat_mask (NUM_VFATS -1 downto 0),
      cyclic_inject_en       => cyclic_inject_en,
      inject_sbits_i         => inject_sbits,
      inject_sbits_mask_i    => inject_sbits_mask (NUM_VFATS -1 downto 0),
      sot_invert_i           => sot_invert (NUM_VFATS-1 downto 0),
      tu_invert_i            => tu_invert,
      tu_mask_i              => tu_mask,
      sot_tap_delay          => sot_tap_delay,
      trig_tap_delay         => trig_tap_delay,

      -- hitmap
      hitmap_reset_i   => hitmap_reset,
      hitmap_acquire_i => hitmap_acquire,
      hitmap_sbits_o   => hitmap_sbits,

      -- sbit outputs
      active_vfats_o           => active_vfats,
      clusters_o               => sbit_clusters,
      cluster_count_masked_o   => cluster_count_masked,
      cluster_count_unmasked_o => cluster_count_unmasked,
      overflow_o               => sbit_overflow,

      -- status outputs
      sot_is_aligned_o      => sot_is_aligned,
      sot_unstable_o        => sot_unstable,
      sot_invalid_bitskip_o => sot_invalid_bitskip,

      tmr_err_inj_i            => tmr_err_inj,
      cluster_tmr_err_o        => cluster_tmr_err,
      trig_alignment_tmr_err_o => trig_alignment_tmr_err,

      -- sbit bx delays
      sbit_bx_dlys_i        => sbit_bx_dlys,
      sbit_bx_dlys_enable_i => sbit_bx_dlys_enable

      );

  -- make a copy to use for counters etc..
  -- the other "fast" copy goes to the trigger link
  process (clocks.clk40) is
  begin
    if (rising_edge(clocks.clk40)) then
      sbit_clusters_ff <= sbit_clusters;
      cluster_count_ff <= cluster_count_masked;
    end if;
  end process;

  sbit_clusters_o <= sbit_clusters;

  --------------------------------------------------------------------------------------------------------------------
  -- Sbit Monitor
  --------------------------------------------------------------------------------------------------------------------

  sbit_monitor_inst : entity work.sbit_monitor
    generic map (
        g_NUM_OF_OHs      => 1,
        g_PARTITION_WIDTH => PARTITION_SIZE*MXSBITS
      )
    port map (
        reset_i               => (reset_i or reset_monitor),
        ttc_clk_i             => clocks.clk40,
        trig_on_invalid_addrs => sbitmon_trig_on_invalid,
        l1a_i                 => ttc.l1a,
        clusters_i            => sbit_clusters_ff,
        frozen_clusters_o     => frozen_clusters,
        l1a_delay_o           => sbitmon_l1a_delay
      );

  --------------------------------------------------------------------------------------------------------------------
  -- Fixed latency trigger links
  --------------------------------------------------------------------------------------------------------------------

  valid_clusters_or <= or_reduce (valid_clusters);

  validmap : for I in 0 to NUM_FOUND_CLUSTERS-1 generate
    valid_clusters (I) <= sbit_clusters_ff(I).vpf;
  end generate validmap;

  --===============================================================================================
  -- (this section is generated by <optohybrid_top>/tools/generate_registers.py -- do not edit)
  --==== Registers begin ==========================================================================

    -- IPbus slave instanciation
    ipbus_slave_inst : entity work.ipbus_slave_tmr
        generic map(
           g_ENABLE_TMR           => EN_TMR_IPB_SLAVE_TRIG,
           g_NUM_REGS             => REG_TRIG_NUM_REGS,
           g_ADDR_HIGH_BIT        => REG_TRIG_ADDRESS_MSB,
           g_ADDR_LOW_BIT         => REG_TRIG_ADDRESS_LSB,
           g_USE_INDIVIDUAL_ADDRS => true,
           g_IPB_CLK_PERIOD_NS    => 25
       )
       port map(
           ipb_reset_i            => ipb_reset,
           ipb_clk_i              => clocks.clk40,
           ipb_mosi_i             => ipb_mosi_i,
           ipb_miso_o             => ipb_miso_o,
           usr_clk_i              => clocks.clk40,
           tmr_err_o              => ipb_slave_tmr_err,
           regs_read_arr_i        => regs_read_arr,
           regs_write_arr_o       => regs_write_arr,
           read_pulse_arr_o       => regs_read_pulse_arr,
           write_pulse_arr_o      => regs_write_pulse_arr,
           regs_read_ready_arr_i  => regs_read_ready_arr,
           regs_write_done_arr_i  => regs_write_done_arr,
           individual_addrs_arr_i => regs_addresses,
           regs_defaults_arr_i    => regs_defaults,
           writable_regs_i        => regs_writable_arr
      );

    -- Addresses
    regs_addresses(0)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"00";
    regs_addresses(1)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"01";
    regs_addresses(2)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"02";
    regs_addresses(3)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"03";
    regs_addresses(4)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"04";
    regs_addresses(5)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"05";
    regs_addresses(6)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"06";
    regs_addresses(7)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"07";
    regs_addresses(8)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"08";
    regs_addresses(9)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"09";
    regs_addresses(10)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"12";
    regs_addresses(11)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"13";
    regs_addresses(12)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"14";
    regs_addresses(13)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"18";
    regs_addresses(14)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"20";
    regs_addresses(15)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"21";
    regs_addresses(16)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"22";
    regs_addresses(17)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"23";
    regs_addresses(18)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"24";
    regs_addresses(19)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"25";
    regs_addresses(20)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"26";
    regs_addresses(21)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"27";
    regs_addresses(22)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"28";
    regs_addresses(23)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"29";
    regs_addresses(24)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"2a";
    regs_addresses(25)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"2b";
    regs_addresses(26)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"38";
    regs_addresses(27)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"39";
    regs_addresses(28)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"3a";
    regs_addresses(29)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"3b";
    regs_addresses(30)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"3f";
    regs_addresses(31)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"40";
    regs_addresses(32)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"41";
    regs_addresses(33)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"42";
    regs_addresses(34)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"43";
    regs_addresses(35)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"44";
    regs_addresses(36)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"45";
    regs_addresses(37)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"46";
    regs_addresses(38)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"47";
    regs_addresses(39)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"48";
    regs_addresses(40)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"49";
    regs_addresses(41)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"4a";
    regs_addresses(42)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"60";
    regs_addresses(43)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"61";
    regs_addresses(44)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"62";
    regs_addresses(45)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"63";
    regs_addresses(46)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"64";
    regs_addresses(47)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"65";
    regs_addresses(48)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"66";
    regs_addresses(49)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"67";
    regs_addresses(50)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"68";
    regs_addresses(51)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"69";
    regs_addresses(52)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"6a";
    regs_addresses(53)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"6b";
    regs_addresses(54)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"6c";
    regs_addresses(55)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"6d";
    regs_addresses(56)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"6e";
    regs_addresses(57)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"6f";
    regs_addresses(58)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"70";
    regs_addresses(59)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"71";
    regs_addresses(60)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"90";
    regs_addresses(61)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"92";
    regs_addresses(62)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"a0";
    regs_addresses(63)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"a1";
    regs_addresses(64)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"a2";
    regs_addresses(65)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"a3";
    regs_addresses(66)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"a4";
    regs_addresses(67)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"a5";
    regs_addresses(68)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"a6";
    regs_addresses(69)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"a7";
    regs_addresses(70)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"a8";
    regs_addresses(71)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"b0";
    regs_addresses(72)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"b1";
    regs_addresses(73)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"c0";
    regs_addresses(74)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"c1";
    regs_addresses(75)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"c2";
    regs_addresses(76)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"c3";
    regs_addresses(77)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"c4";
    regs_addresses(78)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"c5";
    regs_addresses(79)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"c6";
    regs_addresses(80)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"c7";
    regs_addresses(81)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"c8";
    regs_addresses(82)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"c9";
    regs_addresses(83)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"ca";
    regs_addresses(84)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"cb";
    regs_addresses(85)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"cc";
    regs_addresses(86)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"cd";
    regs_addresses(87)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"ce";
    regs_addresses(88)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"cf";
    regs_addresses(89)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"d0";
    regs_addresses(90)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"d1";
    regs_addresses(91)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"d2";
    regs_addresses(92)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"d3";
    regs_addresses(93)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"d4";
    regs_addresses(94)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"d5";
    regs_addresses(95)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"d6";
    regs_addresses(96)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"d7";
    regs_addresses(97)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"d8";
    regs_addresses(98)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"d9";
    regs_addresses(99)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"f9";
    regs_addresses(100)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"fa";
    regs_addresses(101)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "00" & x"fb";
    regs_addresses(102)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "01" & x"00";
    regs_addresses(103)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "01" & x"01";
    regs_addresses(104)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "01" & x"02";
    regs_addresses(105)(REG_TRIG_ADDRESS_MSB downto REG_TRIG_ADDRESS_LSB) <= "01" & x"03";

    -- Connect read signals
    regs_read_arr(0)(REG_TRIG_CTRL_VFAT_MASK_MSB downto REG_TRIG_CTRL_VFAT_MASK_LSB) <= vfat_mask;
    regs_read_arr(1)(REG_TRIG_CTRL_ACTIVE_VFATS_MSB downto REG_TRIG_CTRL_ACTIVE_VFATS_LSB) <= active_vfats;
    regs_read_arr(2)(REG_TRIG_CTRL_CNT_OVERFLOW_MSB downto REG_TRIG_CTRL_CNT_OVERFLOW_LSB) <= cnt_sbit_overflow;
    regs_read_arr(2)(REG_TRIG_CTRL_ALIGNED_COUNT_TO_READY_MSB downto REG_TRIG_CTRL_ALIGNED_COUNT_TO_READY_LSB) <= aligned_count_to_ready;
    regs_read_arr(3)(REG_TRIG_CTRL_SBIT_SOT_READY_MSB downto REG_TRIG_CTRL_SBIT_SOT_READY_LSB) <= sot_is_aligned;
    regs_read_arr(4)(REG_TRIG_CTRL_SBIT_SOT_UNSTABLE_MSB downto REG_TRIG_CTRL_SBIT_SOT_UNSTABLE_LSB) <= sot_unstable;
    regs_read_arr(5)(REG_TRIG_CTRL_SBIT_SOT_INVALID_BITSKIP_MSB downto REG_TRIG_CTRL_SBIT_SOT_INVALID_BITSKIP_LSB) <= sot_invalid_bitskip;
    regs_read_arr(6)(REG_TRIG_CTRL_INVERT_SOT_INVERT_MSB downto REG_TRIG_CTRL_INVERT_SOT_INVERT_LSB) <= sot_invert;
    regs_read_arr(7)(REG_TRIG_CTRL_INVERT_VFAT0_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT0_TU_INVERT_LSB) <= TU_INVERT (7 downto 0);
    regs_read_arr(7)(REG_TRIG_CTRL_INVERT_VFAT1_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT1_TU_INVERT_LSB) <= TU_INVERT (15 downto 8);
    regs_read_arr(7)(REG_TRIG_CTRL_INVERT_VFAT2_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT2_TU_INVERT_LSB) <= TU_INVERT (23 downto 16);
    regs_read_arr(7)(REG_TRIG_CTRL_INVERT_VFAT3_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT3_TU_INVERT_LSB) <= TU_INVERT (31 downto 24);
    regs_read_arr(8)(REG_TRIG_CTRL_INVERT_VFAT4_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT4_TU_INVERT_LSB) <= TU_INVERT (39 downto 32);
    regs_read_arr(8)(REG_TRIG_CTRL_INVERT_VFAT5_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT5_TU_INVERT_LSB) <= TU_INVERT (47 downto 40);
    regs_read_arr(8)(REG_TRIG_CTRL_INVERT_VFAT6_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT6_TU_INVERT_LSB) <= TU_INVERT (55 downto 48);
    regs_read_arr(8)(REG_TRIG_CTRL_INVERT_VFAT7_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT7_TU_INVERT_LSB) <= TU_INVERT (63 downto 56);
    regs_read_arr(9)(REG_TRIG_CTRL_INVERT_VFAT8_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT8_TU_INVERT_LSB) <= TU_INVERT (71 downto 64);
    regs_read_arr(9)(REG_TRIG_CTRL_INVERT_VFAT9_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT9_TU_INVERT_LSB) <= TU_INVERT (79 downto 72);
    regs_read_arr(9)(REG_TRIG_CTRL_INVERT_VFAT10_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT10_TU_INVERT_LSB) <= TU_INVERT (87 downto 80);
    regs_read_arr(9)(REG_TRIG_CTRL_INVERT_VFAT11_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT11_TU_INVERT_LSB) <= TU_INVERT (95 downto 88);
    regs_read_arr(10)(REG_TRIG_CTRL_TU_MASK_VFAT0_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT0_TU_MASK_LSB) <= TU_MASK (7 downto 0);
    regs_read_arr(10)(REG_TRIG_CTRL_TU_MASK_VFAT1_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT1_TU_MASK_LSB) <= TU_MASK (15 downto 8);
    regs_read_arr(10)(REG_TRIG_CTRL_TU_MASK_VFAT2_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT2_TU_MASK_LSB) <= TU_MASK (23 downto 16);
    regs_read_arr(10)(REG_TRIG_CTRL_TU_MASK_VFAT3_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT3_TU_MASK_LSB) <= TU_MASK (31 downto 24);
    regs_read_arr(11)(REG_TRIG_CTRL_TU_MASK_VFAT4_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT4_TU_MASK_LSB) <= TU_MASK (39 downto 32);
    regs_read_arr(11)(REG_TRIG_CTRL_TU_MASK_VFAT5_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT5_TU_MASK_LSB) <= TU_MASK (47 downto 40);
    regs_read_arr(11)(REG_TRIG_CTRL_TU_MASK_VFAT6_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT6_TU_MASK_LSB) <= TU_MASK (55 downto 48);
    regs_read_arr(11)(REG_TRIG_CTRL_TU_MASK_VFAT7_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT7_TU_MASK_LSB) <= TU_MASK (63 downto 56);
    regs_read_arr(12)(REG_TRIG_CTRL_TU_MASK_VFAT8_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT8_TU_MASK_LSB) <= TU_MASK (71 downto 64);
    regs_read_arr(12)(REG_TRIG_CTRL_TU_MASK_VFAT9_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT9_TU_MASK_LSB) <= TU_MASK (79 downto 72);
    regs_read_arr(12)(REG_TRIG_CTRL_TU_MASK_VFAT10_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT10_TU_MASK_LSB) <= TU_MASK (87 downto 80);
    regs_read_arr(12)(REG_TRIG_CTRL_TU_MASK_VFAT11_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT11_TU_MASK_LSB) <= TU_MASK (95 downto 88);
    regs_read_arr(13)(REG_TRIG_CTRL_SBIT_MAP_SEL_MSB downto REG_TRIG_CTRL_SBIT_MAP_SEL_LSB) <= sbit_map_sel;
    regs_read_arr(13)(REG_TRIG_CTRL_REVERSE_PARTITIONS_BIT) <= reverse_partitions;
    regs_read_arr(14)(REG_TRIG_CNT_VFAT0_SBITS_MSB downto REG_TRIG_CNT_VFAT0_SBITS_LSB) <= cnt_vfat0;
    regs_read_arr(15)(REG_TRIG_CNT_VFAT1_SBITS_MSB downto REG_TRIG_CNT_VFAT1_SBITS_LSB) <= cnt_vfat1;
    regs_read_arr(16)(REG_TRIG_CNT_VFAT2_SBITS_MSB downto REG_TRIG_CNT_VFAT2_SBITS_LSB) <= cnt_vfat2;
    regs_read_arr(17)(REG_TRIG_CNT_VFAT3_SBITS_MSB downto REG_TRIG_CNT_VFAT3_SBITS_LSB) <= cnt_vfat3;
    regs_read_arr(18)(REG_TRIG_CNT_VFAT4_SBITS_MSB downto REG_TRIG_CNT_VFAT4_SBITS_LSB) <= cnt_vfat4;
    regs_read_arr(19)(REG_TRIG_CNT_VFAT5_SBITS_MSB downto REG_TRIG_CNT_VFAT5_SBITS_LSB) <= cnt_vfat5;
    regs_read_arr(20)(REG_TRIG_CNT_VFAT6_SBITS_MSB downto REG_TRIG_CNT_VFAT6_SBITS_LSB) <= cnt_vfat6;
    regs_read_arr(21)(REG_TRIG_CNT_VFAT7_SBITS_MSB downto REG_TRIG_CNT_VFAT7_SBITS_LSB) <= cnt_vfat7;
    regs_read_arr(22)(REG_TRIG_CNT_VFAT8_SBITS_MSB downto REG_TRIG_CNT_VFAT8_SBITS_LSB) <= cnt_vfat8;
    regs_read_arr(23)(REG_TRIG_CNT_VFAT9_SBITS_MSB downto REG_TRIG_CNT_VFAT9_SBITS_LSB) <= cnt_vfat9;
    regs_read_arr(24)(REG_TRIG_CNT_VFAT10_SBITS_MSB downto REG_TRIG_CNT_VFAT10_SBITS_LSB) <= cnt_vfat10;
    regs_read_arr(25)(REG_TRIG_CNT_VFAT11_SBITS_MSB downto REG_TRIG_CNT_VFAT11_SBITS_LSB) <= cnt_vfat11;
    regs_read_arr(27)(REG_TRIG_CNT_SBIT_CNT_PERSIST_BIT) <= sbit_cnt_persist;
    regs_read_arr(28)(REG_TRIG_CNT_SBIT_CNT_TIME_MAX_MSB downto REG_TRIG_CNT_SBIT_CNT_TIME_MAX_LSB) <= sbit_cnt_time_max;
    regs_read_arr(29)(REG_TRIG_CNT_CLUSTER_COUNT_MSB downto REG_TRIG_CNT_CLUSTER_COUNT_LSB) <= cnt_clusters;
    regs_read_arr(30)(REG_TRIG_CNT_SBITS_OVER_64x0_MSB downto REG_TRIG_CNT_SBITS_OVER_64x0_LSB) <= cnt_over_threshold0;
    regs_read_arr(31)(REG_TRIG_CNT_SBITS_OVER_64x1_MSB downto REG_TRIG_CNT_SBITS_OVER_64x1_LSB) <= cnt_over_threshold1;
    regs_read_arr(32)(REG_TRIG_CNT_SBITS_OVER_64x2_MSB downto REG_TRIG_CNT_SBITS_OVER_64x2_LSB) <= cnt_over_threshold2;
    regs_read_arr(33)(REG_TRIG_CNT_SBITS_OVER_64x3_MSB downto REG_TRIG_CNT_SBITS_OVER_64x3_LSB) <= cnt_over_threshold3;
    regs_read_arr(34)(REG_TRIG_CNT_SBITS_OVER_64x4_MSB downto REG_TRIG_CNT_SBITS_OVER_64x4_LSB) <= cnt_over_threshold4;
    regs_read_arr(35)(REG_TRIG_CNT_SBITS_OVER_64x5_MSB downto REG_TRIG_CNT_SBITS_OVER_64x5_LSB) <= cnt_over_threshold5;
    regs_read_arr(36)(REG_TRIG_CNT_SBITS_OVER_64x6_MSB downto REG_TRIG_CNT_SBITS_OVER_64x6_LSB) <= cnt_over_threshold6;
    regs_read_arr(37)(REG_TRIG_CNT_SBITS_OVER_64x7_MSB downto REG_TRIG_CNT_SBITS_OVER_64x7_LSB) <= cnt_over_threshold7;
    regs_read_arr(38)(REG_TRIG_CNT_SBITS_OVER_64x8_MSB downto REG_TRIG_CNT_SBITS_OVER_64x8_LSB) <= cnt_over_threshold8;
    regs_read_arr(39)(REG_TRIG_CNT_SBITS_OVER_64x9_MSB downto REG_TRIG_CNT_SBITS_OVER_64x9_LSB) <= cnt_over_threshold9;
    regs_read_arr(40)(REG_TRIG_CNT_SBITS_OVER_64x10_MSB downto REG_TRIG_CNT_SBITS_OVER_64x10_LSB) <= cnt_over_threshold10;
    regs_read_arr(41)(REG_TRIG_CNT_SBITS_OVER_64x11_MSB downto REG_TRIG_CNT_SBITS_OVER_64x11_LSB) <= cnt_over_threshold11;
    regs_read_arr(42)(REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT0_LSB) <= trig_tap_delay(0);
    regs_read_arr(42)(REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT1_LSB) <= trig_tap_delay(1);
    regs_read_arr(42)(REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT2_LSB) <= trig_tap_delay(2);
    regs_read_arr(42)(REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT3_LSB) <= trig_tap_delay(3);
    regs_read_arr(42)(REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT4_LSB) <= trig_tap_delay(4);
    regs_read_arr(42)(REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT5_LSB) <= trig_tap_delay(5);
    regs_read_arr(43)(REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT6_LSB) <= trig_tap_delay(6);
    regs_read_arr(43)(REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT7_LSB) <= trig_tap_delay(7);
    regs_read_arr(43)(REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT0_LSB) <= trig_tap_delay(8);
    regs_read_arr(43)(REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT1_LSB) <= trig_tap_delay(9);
    regs_read_arr(43)(REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT2_LSB) <= trig_tap_delay(10);
    regs_read_arr(43)(REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT3_LSB) <= trig_tap_delay(11);
    regs_read_arr(44)(REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT4_LSB) <= trig_tap_delay(12);
    regs_read_arr(44)(REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT5_LSB) <= trig_tap_delay(13);
    regs_read_arr(44)(REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT6_LSB) <= trig_tap_delay(14);
    regs_read_arr(44)(REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT7_LSB) <= trig_tap_delay(15);
    regs_read_arr(44)(REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT0_LSB) <= trig_tap_delay(16);
    regs_read_arr(44)(REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT1_LSB) <= trig_tap_delay(17);
    regs_read_arr(45)(REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT2_LSB) <= trig_tap_delay(18);
    regs_read_arr(45)(REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT3_LSB) <= trig_tap_delay(19);
    regs_read_arr(45)(REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT4_LSB) <= trig_tap_delay(20);
    regs_read_arr(45)(REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT5_LSB) <= trig_tap_delay(21);
    regs_read_arr(45)(REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT6_LSB) <= trig_tap_delay(22);
    regs_read_arr(45)(REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT7_LSB) <= trig_tap_delay(23);
    regs_read_arr(46)(REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT0_LSB) <= trig_tap_delay(24);
    regs_read_arr(46)(REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT1_LSB) <= trig_tap_delay(25);
    regs_read_arr(46)(REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT2_LSB) <= trig_tap_delay(26);
    regs_read_arr(46)(REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT3_LSB) <= trig_tap_delay(27);
    regs_read_arr(46)(REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT4_LSB) <= trig_tap_delay(28);
    regs_read_arr(46)(REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT5_LSB) <= trig_tap_delay(29);
    regs_read_arr(47)(REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT6_LSB) <= trig_tap_delay(30);
    regs_read_arr(47)(REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT7_LSB) <= trig_tap_delay(31);
    regs_read_arr(47)(REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT0_LSB) <= trig_tap_delay(32);
    regs_read_arr(47)(REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT1_LSB) <= trig_tap_delay(33);
    regs_read_arr(47)(REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT2_LSB) <= trig_tap_delay(34);
    regs_read_arr(47)(REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT3_LSB) <= trig_tap_delay(35);
    regs_read_arr(48)(REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT4_LSB) <= trig_tap_delay(36);
    regs_read_arr(48)(REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT5_LSB) <= trig_tap_delay(37);
    regs_read_arr(48)(REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT6_LSB) <= trig_tap_delay(38);
    regs_read_arr(48)(REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT7_LSB) <= trig_tap_delay(39);
    regs_read_arr(48)(REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT0_LSB) <= trig_tap_delay(40);
    regs_read_arr(48)(REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT1_LSB) <= trig_tap_delay(41);
    regs_read_arr(49)(REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT2_LSB) <= trig_tap_delay(42);
    regs_read_arr(49)(REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT3_LSB) <= trig_tap_delay(43);
    regs_read_arr(49)(REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT4_LSB) <= trig_tap_delay(44);
    regs_read_arr(49)(REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT5_LSB) <= trig_tap_delay(45);
    regs_read_arr(49)(REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT6_LSB) <= trig_tap_delay(46);
    regs_read_arr(49)(REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT7_LSB) <= trig_tap_delay(47);
    regs_read_arr(50)(REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT0_LSB) <= trig_tap_delay(48);
    regs_read_arr(50)(REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT1_LSB) <= trig_tap_delay(49);
    regs_read_arr(50)(REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT2_LSB) <= trig_tap_delay(50);
    regs_read_arr(50)(REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT3_LSB) <= trig_tap_delay(51);
    regs_read_arr(50)(REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT4_LSB) <= trig_tap_delay(52);
    regs_read_arr(50)(REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT5_LSB) <= trig_tap_delay(53);
    regs_read_arr(51)(REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT6_LSB) <= trig_tap_delay(54);
    regs_read_arr(51)(REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT7_LSB) <= trig_tap_delay(55);
    regs_read_arr(51)(REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT0_LSB) <= trig_tap_delay(56);
    regs_read_arr(51)(REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT1_LSB) <= trig_tap_delay(57);
    regs_read_arr(51)(REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT2_LSB) <= trig_tap_delay(58);
    regs_read_arr(51)(REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT3_LSB) <= trig_tap_delay(59);
    regs_read_arr(52)(REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT4_LSB) <= trig_tap_delay(60);
    regs_read_arr(52)(REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT5_LSB) <= trig_tap_delay(61);
    regs_read_arr(52)(REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT6_LSB) <= trig_tap_delay(62);
    regs_read_arr(52)(REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT7_LSB) <= trig_tap_delay(63);
    regs_read_arr(52)(REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT0_LSB) <= trig_tap_delay(64);
    regs_read_arr(52)(REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT1_LSB) <= trig_tap_delay(65);
    regs_read_arr(53)(REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT2_LSB) <= trig_tap_delay(66);
    regs_read_arr(53)(REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT3_LSB) <= trig_tap_delay(67);
    regs_read_arr(53)(REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT4_LSB) <= trig_tap_delay(68);
    regs_read_arr(53)(REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT5_LSB) <= trig_tap_delay(69);
    regs_read_arr(53)(REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT6_LSB) <= trig_tap_delay(70);
    regs_read_arr(53)(REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT7_LSB) <= trig_tap_delay(71);
    regs_read_arr(54)(REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT0_LSB) <= trig_tap_delay(72);
    regs_read_arr(54)(REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT1_LSB) <= trig_tap_delay(73);
    regs_read_arr(54)(REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT2_LSB) <= trig_tap_delay(74);
    regs_read_arr(54)(REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT3_LSB) <= trig_tap_delay(75);
    regs_read_arr(54)(REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT4_LSB) <= trig_tap_delay(76);
    regs_read_arr(54)(REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT5_LSB) <= trig_tap_delay(77);
    regs_read_arr(55)(REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT6_LSB) <= trig_tap_delay(78);
    regs_read_arr(55)(REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT7_LSB) <= trig_tap_delay(79);
    regs_read_arr(55)(REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT0_LSB) <= trig_tap_delay(80);
    regs_read_arr(55)(REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT1_LSB) <= trig_tap_delay(81);
    regs_read_arr(55)(REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT2_LSB) <= trig_tap_delay(82);
    regs_read_arr(55)(REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT3_LSB) <= trig_tap_delay(83);
    regs_read_arr(56)(REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT4_LSB) <= trig_tap_delay(84);
    regs_read_arr(56)(REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT5_LSB) <= trig_tap_delay(85);
    regs_read_arr(56)(REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT6_LSB) <= trig_tap_delay(86);
    regs_read_arr(56)(REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT7_LSB) <= trig_tap_delay(87);
    regs_read_arr(56)(REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT0_LSB) <= trig_tap_delay(88);
    regs_read_arr(56)(REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT1_LSB) <= trig_tap_delay(89);
    regs_read_arr(57)(REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT2_LSB) <= trig_tap_delay(90);
    regs_read_arr(57)(REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT3_LSB) <= trig_tap_delay(91);
    regs_read_arr(57)(REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT4_LSB) <= trig_tap_delay(92);
    regs_read_arr(57)(REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT5_LSB) <= trig_tap_delay(93);
    regs_read_arr(57)(REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT6_LSB) <= trig_tap_delay(94);
    regs_read_arr(57)(REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT7_LSB) <= trig_tap_delay(95);
    regs_read_arr(58)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT0_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT0_LSB) <= sot_tap_delay(0);
    regs_read_arr(58)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT1_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT1_LSB) <= sot_tap_delay(1);
    regs_read_arr(58)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT2_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT2_LSB) <= sot_tap_delay(2);
    regs_read_arr(58)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT3_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT3_LSB) <= sot_tap_delay(3);
    regs_read_arr(58)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT4_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT4_LSB) <= sot_tap_delay(4);
    regs_read_arr(58)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT5_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT5_LSB) <= sot_tap_delay(5);
    regs_read_arr(59)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT6_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT6_LSB) <= sot_tap_delay(6);
    regs_read_arr(59)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT7_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT7_LSB) <= sot_tap_delay(7);
    regs_read_arr(59)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT8_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT8_LSB) <= sot_tap_delay(8);
    regs_read_arr(59)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT9_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT9_LSB) <= sot_tap_delay(9);
    regs_read_arr(59)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT10_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT10_LSB) <= sot_tap_delay(10);
    regs_read_arr(59)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT11_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT11_LSB) <= sot_tap_delay(11);
    regs_read_arr(60)(REG_TRIG_SBIT_INJECT_MASK_MSB downto REG_TRIG_SBIT_INJECT_MASK_LSB) <= inject_sbits_mask;
    regs_read_arr(60)(REG_TRIG_CYCLIC_INJECT_EN_BIT) <= cyclic_inject_en;
    regs_read_arr(63)(REG_TRIG_SBIT_MONITOR_CLUSTER0_MSB downto REG_TRIG_SBIT_MONITOR_CLUSTER0_LSB) <= cluster_to_vector(frozen_clusters(0),16);
    regs_read_arr(64)(REG_TRIG_SBIT_MONITOR_CLUSTER1_MSB downto REG_TRIG_SBIT_MONITOR_CLUSTER1_LSB) <= cluster_to_vector(frozen_clusters(1),16);
    regs_read_arr(65)(REG_TRIG_SBIT_MONITOR_CLUSTER2_MSB downto REG_TRIG_SBIT_MONITOR_CLUSTER2_LSB) <= cluster_to_vector(frozen_clusters(2),16);
    regs_read_arr(66)(REG_TRIG_SBIT_MONITOR_CLUSTER3_MSB downto REG_TRIG_SBIT_MONITOR_CLUSTER3_LSB) <= cluster_to_vector(frozen_clusters(3),16);
    regs_read_arr(67)(REG_TRIG_SBIT_MONITOR_CLUSTER4_MSB downto REG_TRIG_SBIT_MONITOR_CLUSTER4_LSB) <= cluster_to_vector(frozen_clusters(4),16);
    regs_read_arr(68)(REG_TRIG_SBIT_MONITOR_CLUSTER5_MSB downto REG_TRIG_SBIT_MONITOR_CLUSTER5_LSB) <= cluster_to_vector(frozen_clusters(5),16);
    regs_read_arr(69)(REG_TRIG_SBIT_MONITOR_CLUSTER6_MSB downto REG_TRIG_SBIT_MONITOR_CLUSTER6_LSB) <= cluster_to_vector(frozen_clusters(6),16);
    regs_read_arr(70)(REG_TRIG_SBIT_MONITOR_CLUSTER7_MSB downto REG_TRIG_SBIT_MONITOR_CLUSTER7_LSB) <= cluster_to_vector(frozen_clusters(7),16);
    regs_read_arr(71)(REG_TRIG_SBIT_MONITOR_L1A_DELAY_MSB downto REG_TRIG_SBIT_MONITOR_L1A_DELAY_LSB) <= sbitmon_l1a_delay;
    regs_read_arr(72)(REG_TRIG_SBIT_MONITOR_TRIG_ON_INVALID_BIT) <= sbitmon_trig_on_invalid;
    regs_read_arr(74)(REG_TRIG_SBIT_HITMAP_ACQUIRE_BIT) <= hitmap_acquire;
    regs_read_arr(75)(REG_TRIG_SBIT_HITMAP_VFAT0_MSB_MSB downto REG_TRIG_SBIT_HITMAP_VFAT0_MSB_LSB) <= hitmap_sbits(0)(63 downto 32);
    regs_read_arr(76)(REG_TRIG_SBIT_HITMAP_VFAT0_LSB_MSB downto REG_TRIG_SBIT_HITMAP_VFAT0_LSB_LSB) <= hitmap_sbits(0)(31 downto 0);
    regs_read_arr(77)(REG_TRIG_SBIT_HITMAP_VFAT1_MSB_MSB downto REG_TRIG_SBIT_HITMAP_VFAT1_MSB_LSB) <= hitmap_sbits(1)(63 downto 32);
    regs_read_arr(78)(REG_TRIG_SBIT_HITMAP_VFAT1_LSB_MSB downto REG_TRIG_SBIT_HITMAP_VFAT1_LSB_LSB) <= hitmap_sbits(1)(31 downto 0);
    regs_read_arr(79)(REG_TRIG_SBIT_HITMAP_VFAT2_MSB_MSB downto REG_TRIG_SBIT_HITMAP_VFAT2_MSB_LSB) <= hitmap_sbits(2)(63 downto 32);
    regs_read_arr(80)(REG_TRIG_SBIT_HITMAP_VFAT2_LSB_MSB downto REG_TRIG_SBIT_HITMAP_VFAT2_LSB_LSB) <= hitmap_sbits(2)(31 downto 0);
    regs_read_arr(81)(REG_TRIG_SBIT_HITMAP_VFAT3_MSB_MSB downto REG_TRIG_SBIT_HITMAP_VFAT3_MSB_LSB) <= hitmap_sbits(3)(63 downto 32);
    regs_read_arr(82)(REG_TRIG_SBIT_HITMAP_VFAT3_LSB_MSB downto REG_TRIG_SBIT_HITMAP_VFAT3_LSB_LSB) <= hitmap_sbits(3)(31 downto 0);
    regs_read_arr(83)(REG_TRIG_SBIT_HITMAP_VFAT4_MSB_MSB downto REG_TRIG_SBIT_HITMAP_VFAT4_MSB_LSB) <= hitmap_sbits(4)(63 downto 32);
    regs_read_arr(84)(REG_TRIG_SBIT_HITMAP_VFAT4_LSB_MSB downto REG_TRIG_SBIT_HITMAP_VFAT4_LSB_LSB) <= hitmap_sbits(4)(31 downto 0);
    regs_read_arr(85)(REG_TRIG_SBIT_HITMAP_VFAT5_MSB_MSB downto REG_TRIG_SBIT_HITMAP_VFAT5_MSB_LSB) <= hitmap_sbits(5)(63 downto 32);
    regs_read_arr(86)(REG_TRIG_SBIT_HITMAP_VFAT5_LSB_MSB downto REG_TRIG_SBIT_HITMAP_VFAT5_LSB_LSB) <= hitmap_sbits(5)(31 downto 0);
    regs_read_arr(87)(REG_TRIG_SBIT_HITMAP_VFAT6_MSB_MSB downto REG_TRIG_SBIT_HITMAP_VFAT6_MSB_LSB) <= hitmap_sbits(6)(63 downto 32);
    regs_read_arr(88)(REG_TRIG_SBIT_HITMAP_VFAT6_LSB_MSB downto REG_TRIG_SBIT_HITMAP_VFAT6_LSB_LSB) <= hitmap_sbits(6)(31 downto 0);
    regs_read_arr(89)(REG_TRIG_SBIT_HITMAP_VFAT7_MSB_MSB downto REG_TRIG_SBIT_HITMAP_VFAT7_MSB_LSB) <= hitmap_sbits(7)(63 downto 32);
    regs_read_arr(90)(REG_TRIG_SBIT_HITMAP_VFAT7_LSB_MSB downto REG_TRIG_SBIT_HITMAP_VFAT7_LSB_LSB) <= hitmap_sbits(7)(31 downto 0);
    regs_read_arr(91)(REG_TRIG_SBIT_HITMAP_VFAT8_MSB_MSB downto REG_TRIG_SBIT_HITMAP_VFAT8_MSB_LSB) <= hitmap_sbits(8)(63 downto 32);
    regs_read_arr(92)(REG_TRIG_SBIT_HITMAP_VFAT8_LSB_MSB downto REG_TRIG_SBIT_HITMAP_VFAT8_LSB_LSB) <= hitmap_sbits(8)(31 downto 0);
    regs_read_arr(93)(REG_TRIG_SBIT_HITMAP_VFAT9_MSB_MSB downto REG_TRIG_SBIT_HITMAP_VFAT9_MSB_LSB) <= hitmap_sbits(9)(63 downto 32);
    regs_read_arr(94)(REG_TRIG_SBIT_HITMAP_VFAT9_LSB_MSB downto REG_TRIG_SBIT_HITMAP_VFAT9_LSB_LSB) <= hitmap_sbits(9)(31 downto 0);
    regs_read_arr(95)(REG_TRIG_SBIT_HITMAP_VFAT10_MSB_MSB downto REG_TRIG_SBIT_HITMAP_VFAT10_MSB_LSB) <= hitmap_sbits(10)(63 downto 32);
    regs_read_arr(96)(REG_TRIG_SBIT_HITMAP_VFAT10_LSB_MSB downto REG_TRIG_SBIT_HITMAP_VFAT10_LSB_LSB) <= hitmap_sbits(10)(31 downto 0);
    regs_read_arr(97)(REG_TRIG_SBIT_HITMAP_VFAT11_MSB_MSB downto REG_TRIG_SBIT_HITMAP_VFAT11_MSB_LSB) <= hitmap_sbits(11)(63 downto 32);
    regs_read_arr(98)(REG_TRIG_SBIT_HITMAP_VFAT11_LSB_MSB downto REG_TRIG_SBIT_HITMAP_VFAT11_LSB_LSB) <= hitmap_sbits(11)(31 downto 0);
    regs_read_arr(99)(REG_TRIG_TRIGGER_PRBS_EN_BIT) <= trigger_prbs_en;
    regs_read_arr(100)(REG_TRIG_L1A_MASK_L1A_MASK_DELAY_MSB downto REG_TRIG_L1A_MASK_L1A_MASK_DELAY_LSB) <= l1a_mask_delay;
    regs_read_arr(101)(REG_TRIG_L1A_MASK_L1A_MASK_BITMASK_MSB downto REG_TRIG_L1A_MASK_L1A_MASK_BITMASK_LSB) <= l1a_mask_bitmask;
    regs_read_arr(102)(REG_TRIG_TMR_CLUSTER_TMR_ERR_CNT_MSB downto REG_TRIG_TMR_CLUSTER_TMR_ERR_CNT_LSB) <= cluster_tmr_err_cnt;
    regs_read_arr(102)(REG_TRIG_TMR_SBIT_RX_TMR_ERR_CNT_MSB downto REG_TRIG_TMR_SBIT_RX_TMR_ERR_CNT_LSB) <= trig_alignment_tmr_err_cnt;
    regs_read_arr(103)(REG_TRIG_TMR_IPB_SLAVE_TMR_ERR_CNT_MSB downto REG_TRIG_TMR_IPB_SLAVE_TMR_ERR_CNT_LSB) <= ipb_slave_tmr_err_cnt;
    regs_read_arr(103)(REG_TRIG_TMR_TRIG_FORMATTER_TMR_ERR_CNT_MSB downto REG_TRIG_TMR_TRIG_FORMATTER_TMR_ERR_CNT_LSB) <= trig_formatter_tmr_err_cnt;

    -- Connect write signals
    vfat_mask <= regs_write_arr(0)(REG_TRIG_CTRL_VFAT_MASK_MSB downto REG_TRIG_CTRL_VFAT_MASK_LSB);
    aligned_count_to_ready <= regs_write_arr(2)(REG_TRIG_CTRL_ALIGNED_COUNT_TO_READY_MSB downto REG_TRIG_CTRL_ALIGNED_COUNT_TO_READY_LSB);
    sot_invert <= regs_write_arr(6)(REG_TRIG_CTRL_INVERT_SOT_INVERT_MSB downto REG_TRIG_CTRL_INVERT_SOT_INVERT_LSB);
    TU_INVERT (7 downto 0) <= regs_write_arr(7)(REG_TRIG_CTRL_INVERT_VFAT0_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT0_TU_INVERT_LSB);
    TU_INVERT (15 downto 8) <= regs_write_arr(7)(REG_TRIG_CTRL_INVERT_VFAT1_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT1_TU_INVERT_LSB);
    TU_INVERT (23 downto 16) <= regs_write_arr(7)(REG_TRIG_CTRL_INVERT_VFAT2_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT2_TU_INVERT_LSB);
    TU_INVERT (31 downto 24) <= regs_write_arr(7)(REG_TRIG_CTRL_INVERT_VFAT3_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT3_TU_INVERT_LSB);
    TU_INVERT (39 downto 32) <= regs_write_arr(8)(REG_TRIG_CTRL_INVERT_VFAT4_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT4_TU_INVERT_LSB);
    TU_INVERT (47 downto 40) <= regs_write_arr(8)(REG_TRIG_CTRL_INVERT_VFAT5_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT5_TU_INVERT_LSB);
    TU_INVERT (55 downto 48) <= regs_write_arr(8)(REG_TRIG_CTRL_INVERT_VFAT6_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT6_TU_INVERT_LSB);
    TU_INVERT (63 downto 56) <= regs_write_arr(8)(REG_TRIG_CTRL_INVERT_VFAT7_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT7_TU_INVERT_LSB);
    TU_INVERT (71 downto 64) <= regs_write_arr(9)(REG_TRIG_CTRL_INVERT_VFAT8_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT8_TU_INVERT_LSB);
    TU_INVERT (79 downto 72) <= regs_write_arr(9)(REG_TRIG_CTRL_INVERT_VFAT9_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT9_TU_INVERT_LSB);
    TU_INVERT (87 downto 80) <= regs_write_arr(9)(REG_TRIG_CTRL_INVERT_VFAT10_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT10_TU_INVERT_LSB);
    TU_INVERT (95 downto 88) <= regs_write_arr(9)(REG_TRIG_CTRL_INVERT_VFAT11_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT11_TU_INVERT_LSB);
    TU_MASK (7 downto 0) <= regs_write_arr(10)(REG_TRIG_CTRL_TU_MASK_VFAT0_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT0_TU_MASK_LSB);
    TU_MASK (15 downto 8) <= regs_write_arr(10)(REG_TRIG_CTRL_TU_MASK_VFAT1_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT1_TU_MASK_LSB);
    TU_MASK (23 downto 16) <= regs_write_arr(10)(REG_TRIG_CTRL_TU_MASK_VFAT2_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT2_TU_MASK_LSB);
    TU_MASK (31 downto 24) <= regs_write_arr(10)(REG_TRIG_CTRL_TU_MASK_VFAT3_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT3_TU_MASK_LSB);
    TU_MASK (39 downto 32) <= regs_write_arr(11)(REG_TRIG_CTRL_TU_MASK_VFAT4_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT4_TU_MASK_LSB);
    TU_MASK (47 downto 40) <= regs_write_arr(11)(REG_TRIG_CTRL_TU_MASK_VFAT5_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT5_TU_MASK_LSB);
    TU_MASK (55 downto 48) <= regs_write_arr(11)(REG_TRIG_CTRL_TU_MASK_VFAT6_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT6_TU_MASK_LSB);
    TU_MASK (63 downto 56) <= regs_write_arr(11)(REG_TRIG_CTRL_TU_MASK_VFAT7_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT7_TU_MASK_LSB);
    TU_MASK (71 downto 64) <= regs_write_arr(12)(REG_TRIG_CTRL_TU_MASK_VFAT8_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT8_TU_MASK_LSB);
    TU_MASK (79 downto 72) <= regs_write_arr(12)(REG_TRIG_CTRL_TU_MASK_VFAT9_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT9_TU_MASK_LSB);
    TU_MASK (87 downto 80) <= regs_write_arr(12)(REG_TRIG_CTRL_TU_MASK_VFAT10_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT10_TU_MASK_LSB);
    TU_MASK (95 downto 88) <= regs_write_arr(12)(REG_TRIG_CTRL_TU_MASK_VFAT11_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT11_TU_MASK_LSB);
    sbit_map_sel <= regs_write_arr(13)(REG_TRIG_CTRL_SBIT_MAP_SEL_MSB downto REG_TRIG_CTRL_SBIT_MAP_SEL_LSB);
    reverse_partitions <= regs_write_arr(13)(REG_TRIG_CTRL_REVERSE_PARTITIONS_BIT);
    sbit_cnt_persist <= regs_write_arr(27)(REG_TRIG_CNT_SBIT_CNT_PERSIST_BIT);
    sbit_cnt_time_max <= regs_write_arr(28)(REG_TRIG_CNT_SBIT_CNT_TIME_MAX_MSB downto REG_TRIG_CNT_SBIT_CNT_TIME_MAX_LSB);
    trig_tap_delay(0) <= regs_write_arr(42)(REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT0_LSB);
    trig_tap_delay(1) <= regs_write_arr(42)(REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT1_LSB);
    trig_tap_delay(2) <= regs_write_arr(42)(REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT2_LSB);
    trig_tap_delay(3) <= regs_write_arr(42)(REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT3_LSB);
    trig_tap_delay(4) <= regs_write_arr(42)(REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT4_LSB);
    trig_tap_delay(5) <= regs_write_arr(42)(REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT5_LSB);
    trig_tap_delay(6) <= regs_write_arr(43)(REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT6_LSB);
    trig_tap_delay(7) <= regs_write_arr(43)(REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT7_LSB);
    trig_tap_delay(8) <= regs_write_arr(43)(REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT0_LSB);
    trig_tap_delay(9) <= regs_write_arr(43)(REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT1_LSB);
    trig_tap_delay(10) <= regs_write_arr(43)(REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT2_LSB);
    trig_tap_delay(11) <= regs_write_arr(43)(REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT3_LSB);
    trig_tap_delay(12) <= regs_write_arr(44)(REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT4_LSB);
    trig_tap_delay(13) <= regs_write_arr(44)(REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT5_LSB);
    trig_tap_delay(14) <= regs_write_arr(44)(REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT6_LSB);
    trig_tap_delay(15) <= regs_write_arr(44)(REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT7_LSB);
    trig_tap_delay(16) <= regs_write_arr(44)(REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT0_LSB);
    trig_tap_delay(17) <= regs_write_arr(44)(REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT1_LSB);
    trig_tap_delay(18) <= regs_write_arr(45)(REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT2_LSB);
    trig_tap_delay(19) <= regs_write_arr(45)(REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT3_LSB);
    trig_tap_delay(20) <= regs_write_arr(45)(REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT4_LSB);
    trig_tap_delay(21) <= regs_write_arr(45)(REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT5_LSB);
    trig_tap_delay(22) <= regs_write_arr(45)(REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT6_LSB);
    trig_tap_delay(23) <= regs_write_arr(45)(REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT7_LSB);
    trig_tap_delay(24) <= regs_write_arr(46)(REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT0_LSB);
    trig_tap_delay(25) <= regs_write_arr(46)(REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT1_LSB);
    trig_tap_delay(26) <= regs_write_arr(46)(REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT2_LSB);
    trig_tap_delay(27) <= regs_write_arr(46)(REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT3_LSB);
    trig_tap_delay(28) <= regs_write_arr(46)(REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT4_LSB);
    trig_tap_delay(29) <= regs_write_arr(46)(REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT5_LSB);
    trig_tap_delay(30) <= regs_write_arr(47)(REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT6_LSB);
    trig_tap_delay(31) <= regs_write_arr(47)(REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT7_LSB);
    trig_tap_delay(32) <= regs_write_arr(47)(REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT0_LSB);
    trig_tap_delay(33) <= regs_write_arr(47)(REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT1_LSB);
    trig_tap_delay(34) <= regs_write_arr(47)(REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT2_LSB);
    trig_tap_delay(35) <= regs_write_arr(47)(REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT3_LSB);
    trig_tap_delay(36) <= regs_write_arr(48)(REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT4_LSB);
    trig_tap_delay(37) <= regs_write_arr(48)(REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT5_LSB);
    trig_tap_delay(38) <= regs_write_arr(48)(REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT6_LSB);
    trig_tap_delay(39) <= regs_write_arr(48)(REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT7_LSB);
    trig_tap_delay(40) <= regs_write_arr(48)(REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT0_LSB);
    trig_tap_delay(41) <= regs_write_arr(48)(REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT1_LSB);
    trig_tap_delay(42) <= regs_write_arr(49)(REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT2_LSB);
    trig_tap_delay(43) <= regs_write_arr(49)(REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT3_LSB);
    trig_tap_delay(44) <= regs_write_arr(49)(REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT4_LSB);
    trig_tap_delay(45) <= regs_write_arr(49)(REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT5_LSB);
    trig_tap_delay(46) <= regs_write_arr(49)(REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT6_LSB);
    trig_tap_delay(47) <= regs_write_arr(49)(REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT7_LSB);
    trig_tap_delay(48) <= regs_write_arr(50)(REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT0_LSB);
    trig_tap_delay(49) <= regs_write_arr(50)(REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT1_LSB);
    trig_tap_delay(50) <= regs_write_arr(50)(REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT2_LSB);
    trig_tap_delay(51) <= regs_write_arr(50)(REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT3_LSB);
    trig_tap_delay(52) <= regs_write_arr(50)(REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT4_LSB);
    trig_tap_delay(53) <= regs_write_arr(50)(REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT5_LSB);
    trig_tap_delay(54) <= regs_write_arr(51)(REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT6_LSB);
    trig_tap_delay(55) <= regs_write_arr(51)(REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT7_LSB);
    trig_tap_delay(56) <= regs_write_arr(51)(REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT0_LSB);
    trig_tap_delay(57) <= regs_write_arr(51)(REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT1_LSB);
    trig_tap_delay(58) <= regs_write_arr(51)(REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT2_LSB);
    trig_tap_delay(59) <= regs_write_arr(51)(REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT3_LSB);
    trig_tap_delay(60) <= regs_write_arr(52)(REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT4_LSB);
    trig_tap_delay(61) <= regs_write_arr(52)(REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT5_LSB);
    trig_tap_delay(62) <= regs_write_arr(52)(REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT6_LSB);
    trig_tap_delay(63) <= regs_write_arr(52)(REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT7_LSB);
    trig_tap_delay(64) <= regs_write_arr(52)(REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT0_LSB);
    trig_tap_delay(65) <= regs_write_arr(52)(REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT1_LSB);
    trig_tap_delay(66) <= regs_write_arr(53)(REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT2_LSB);
    trig_tap_delay(67) <= regs_write_arr(53)(REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT3_LSB);
    trig_tap_delay(68) <= regs_write_arr(53)(REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT4_LSB);
    trig_tap_delay(69) <= regs_write_arr(53)(REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT5_LSB);
    trig_tap_delay(70) <= regs_write_arr(53)(REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT6_LSB);
    trig_tap_delay(71) <= regs_write_arr(53)(REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT7_LSB);
    trig_tap_delay(72) <= regs_write_arr(54)(REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT0_LSB);
    trig_tap_delay(73) <= regs_write_arr(54)(REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT1_LSB);
    trig_tap_delay(74) <= regs_write_arr(54)(REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT2_LSB);
    trig_tap_delay(75) <= regs_write_arr(54)(REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT3_LSB);
    trig_tap_delay(76) <= regs_write_arr(54)(REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT4_LSB);
    trig_tap_delay(77) <= regs_write_arr(54)(REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT5_LSB);
    trig_tap_delay(78) <= regs_write_arr(55)(REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT6_LSB);
    trig_tap_delay(79) <= regs_write_arr(55)(REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT7_LSB);
    trig_tap_delay(80) <= regs_write_arr(55)(REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT0_LSB);
    trig_tap_delay(81) <= regs_write_arr(55)(REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT1_LSB);
    trig_tap_delay(82) <= regs_write_arr(55)(REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT2_LSB);
    trig_tap_delay(83) <= regs_write_arr(55)(REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT3_LSB);
    trig_tap_delay(84) <= regs_write_arr(56)(REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT4_LSB);
    trig_tap_delay(85) <= regs_write_arr(56)(REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT5_LSB);
    trig_tap_delay(86) <= regs_write_arr(56)(REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT6_LSB);
    trig_tap_delay(87) <= regs_write_arr(56)(REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT7_LSB);
    trig_tap_delay(88) <= regs_write_arr(56)(REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT0_LSB);
    trig_tap_delay(89) <= regs_write_arr(56)(REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT1_LSB);
    trig_tap_delay(90) <= regs_write_arr(57)(REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT2_LSB);
    trig_tap_delay(91) <= regs_write_arr(57)(REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT3_LSB);
    trig_tap_delay(92) <= regs_write_arr(57)(REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT4_LSB);
    trig_tap_delay(93) <= regs_write_arr(57)(REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT5_LSB);
    trig_tap_delay(94) <= regs_write_arr(57)(REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT6_LSB);
    trig_tap_delay(95) <= regs_write_arr(57)(REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT7_LSB);
    sot_tap_delay(0) <= regs_write_arr(58)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT0_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT0_LSB);
    sot_tap_delay(1) <= regs_write_arr(58)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT1_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT1_LSB);
    sot_tap_delay(2) <= regs_write_arr(58)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT2_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT2_LSB);
    sot_tap_delay(3) <= regs_write_arr(58)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT3_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT3_LSB);
    sot_tap_delay(4) <= regs_write_arr(58)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT4_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT4_LSB);
    sot_tap_delay(5) <= regs_write_arr(58)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT5_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT5_LSB);
    sot_tap_delay(6) <= regs_write_arr(59)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT6_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT6_LSB);
    sot_tap_delay(7) <= regs_write_arr(59)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT7_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT7_LSB);
    sot_tap_delay(8) <= regs_write_arr(59)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT8_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT8_LSB);
    sot_tap_delay(9) <= regs_write_arr(59)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT9_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT9_LSB);
    sot_tap_delay(10) <= regs_write_arr(59)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT10_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT10_LSB);
    sot_tap_delay(11) <= regs_write_arr(59)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT11_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT11_LSB);
    inject_sbits_mask <= regs_write_arr(60)(REG_TRIG_SBIT_INJECT_MASK_MSB downto REG_TRIG_SBIT_INJECT_MASK_LSB);
    cyclic_inject_en <= regs_write_arr(60)(REG_TRIG_CYCLIC_INJECT_EN_BIT);
    sbitmon_trig_on_invalid <= regs_write_arr(72)(REG_TRIG_SBIT_MONITOR_TRIG_ON_INVALID_BIT);
    hitmap_acquire <= regs_write_arr(74)(REG_TRIG_SBIT_HITMAP_ACQUIRE_BIT);
    trigger_prbs_en <= regs_write_arr(99)(REG_TRIG_TRIGGER_PRBS_EN_BIT);
    l1a_mask_delay <= regs_write_arr(100)(REG_TRIG_L1A_MASK_L1A_MASK_DELAY_MSB downto REG_TRIG_L1A_MASK_L1A_MASK_DELAY_LSB);
    l1a_mask_bitmask <= regs_write_arr(101)(REG_TRIG_L1A_MASK_L1A_MASK_BITMASK_MSB downto REG_TRIG_L1A_MASK_L1A_MASK_BITMASK_LSB);

    -- Connect write pulse signals
    reset_counters <= regs_write_pulse_arr(26);
    inject_sbits <= regs_write_pulse_arr(61);
    reset_monitor <= regs_write_pulse_arr(62);
    hitmap_reset <= regs_write_pulse_arr(73);
    tmr_cnt_reset <= regs_write_pulse_arr(104);
    tmr_err_inj <= regs_write_pulse_arr(105);

    -- Connect write done signals

    -- Connect read pulse signals

    -- Connect counter instances

    COUNTER_TRIG_CTRL_CNT_OVERFLOW : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 16
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset,
        en_i      => sbit_overflow,
        snap_i    => cnt_snap,
        count_o   => cnt_sbit_overflow
    );


    COUNTER_TRIG_CNT_VFAT0_SBITS : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 32
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset_strobed,
        en_i      => active_vfats(0),
        snap_i    => sbit_cnt_snap,
        count_o   => cnt_vfat0
    );


    COUNTER_TRIG_CNT_VFAT1_SBITS : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 32
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset_strobed,
        en_i      => active_vfats(1),
        snap_i    => sbit_cnt_snap,
        count_o   => cnt_vfat1
    );


    COUNTER_TRIG_CNT_VFAT2_SBITS : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 32
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset_strobed,
        en_i      => active_vfats(2),
        snap_i    => sbit_cnt_snap,
        count_o   => cnt_vfat2
    );


    COUNTER_TRIG_CNT_VFAT3_SBITS : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 32
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset_strobed,
        en_i      => active_vfats(3),
        snap_i    => sbit_cnt_snap,
        count_o   => cnt_vfat3
    );


    COUNTER_TRIG_CNT_VFAT4_SBITS : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 32
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset_strobed,
        en_i      => active_vfats(4),
        snap_i    => sbit_cnt_snap,
        count_o   => cnt_vfat4
    );


    COUNTER_TRIG_CNT_VFAT5_SBITS : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 32
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset_strobed,
        en_i      => active_vfats(5),
        snap_i    => sbit_cnt_snap,
        count_o   => cnt_vfat5
    );


    COUNTER_TRIG_CNT_VFAT6_SBITS : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 32
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset_strobed,
        en_i      => active_vfats(6),
        snap_i    => sbit_cnt_snap,
        count_o   => cnt_vfat6
    );


    COUNTER_TRIG_CNT_VFAT7_SBITS : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 32
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset_strobed,
        en_i      => active_vfats(7),
        snap_i    => sbit_cnt_snap,
        count_o   => cnt_vfat7
    );


    COUNTER_TRIG_CNT_VFAT8_SBITS : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 32
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset_strobed,
        en_i      => active_vfats(8),
        snap_i    => sbit_cnt_snap,
        count_o   => cnt_vfat8
    );


    COUNTER_TRIG_CNT_VFAT9_SBITS : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 32
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset_strobed,
        en_i      => active_vfats(9),
        snap_i    => sbit_cnt_snap,
        count_o   => cnt_vfat9
    );


    COUNTER_TRIG_CNT_VFAT10_SBITS : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 32
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset_strobed,
        en_i      => active_vfats(10),
        snap_i    => sbit_cnt_snap,
        count_o   => cnt_vfat10
    );


    COUNTER_TRIG_CNT_VFAT11_SBITS : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 32
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset_strobed,
        en_i      => active_vfats(11),
        snap_i    => sbit_cnt_snap,
        count_o   => cnt_vfat11
    );


    COUNTER_TRIG_CNT_CLUSTER_COUNT : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 32
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset_strobed,
        en_i      => valid_clusters_or,
        snap_i    => sbit_cnt_snap,
        count_o   => cnt_clusters
    );


    COUNTER_TRIG_CNT_SBITS_OVER_64x0 : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 16
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset_strobed,
        en_i      => sbits_comparator_over_threshold(0),
        snap_i    => sbit_cnt_snap,
        count_o   => cnt_over_threshold0
    );


    COUNTER_TRIG_CNT_SBITS_OVER_64x1 : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 16
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset_strobed,
        en_i      => sbits_comparator_over_threshold(1),
        snap_i    => sbit_cnt_snap,
        count_o   => cnt_over_threshold1
    );


    COUNTER_TRIG_CNT_SBITS_OVER_64x2 : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 16
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset_strobed,
        en_i      => sbits_comparator_over_threshold(2),
        snap_i    => sbit_cnt_snap,
        count_o   => cnt_over_threshold2
    );


    COUNTER_TRIG_CNT_SBITS_OVER_64x3 : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 16
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset_strobed,
        en_i      => sbits_comparator_over_threshold(3),
        snap_i    => sbit_cnt_snap,
        count_o   => cnt_over_threshold3
    );


    COUNTER_TRIG_CNT_SBITS_OVER_64x4 : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 16
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset_strobed,
        en_i      => sbits_comparator_over_threshold(4),
        snap_i    => sbit_cnt_snap,
        count_o   => cnt_over_threshold4
    );


    COUNTER_TRIG_CNT_SBITS_OVER_64x5 : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 16
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset_strobed,
        en_i      => sbits_comparator_over_threshold(5),
        snap_i    => sbit_cnt_snap,
        count_o   => cnt_over_threshold5
    );


    COUNTER_TRIG_CNT_SBITS_OVER_64x6 : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 16
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset_strobed,
        en_i      => sbits_comparator_over_threshold(6),
        snap_i    => sbit_cnt_snap,
        count_o   => cnt_over_threshold6
    );


    COUNTER_TRIG_CNT_SBITS_OVER_64x7 : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 16
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset_strobed,
        en_i      => sbits_comparator_over_threshold(7),
        snap_i    => sbit_cnt_snap,
        count_o   => cnt_over_threshold7
    );


    COUNTER_TRIG_CNT_SBITS_OVER_64x8 : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 16
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset_strobed,
        en_i      => sbits_comparator_over_threshold(8),
        snap_i    => sbit_cnt_snap,
        count_o   => cnt_over_threshold8
    );


    COUNTER_TRIG_CNT_SBITS_OVER_64x9 : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 16
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset_strobed,
        en_i      => sbits_comparator_over_threshold(9),
        snap_i    => sbit_cnt_snap,
        count_o   => cnt_over_threshold9
    );


    COUNTER_TRIG_CNT_SBITS_OVER_64x10 : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 16
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset_strobed,
        en_i      => sbits_comparator_over_threshold(10),
        snap_i    => sbit_cnt_snap,
        count_o   => cnt_over_threshold10
    );


    COUNTER_TRIG_CNT_SBITS_OVER_64x11 : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 16
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset_strobed,
        en_i      => sbits_comparator_over_threshold(11),
        snap_i    => sbit_cnt_snap,
        count_o   => cnt_over_threshold11
    );


    COUNTER_TRIG_TMR_CLUSTER_TMR_ERR_CNT : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 16
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => reset_i or tmr_cnt_reset,
        en_i      => cluster_tmr_err,
        snap_i    => cnt_snap,
        count_o   => cluster_tmr_err_cnt
    );


    COUNTER_TRIG_TMR_SBIT_RX_TMR_ERR_CNT : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 16
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => reset_i or tmr_cnt_reset,
        en_i      => trig_alignment_tmr_err,
        snap_i    => cnt_snap,
        count_o   => trig_alignment_tmr_err_cnt
    );


    COUNTER_TRIG_TMR_IPB_SLAVE_TMR_ERR_CNT : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 16
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => reset_i or tmr_cnt_reset,
        en_i      => ipb_slave_tmr_err,
        snap_i    => cnt_snap,
        count_o   => ipb_slave_tmr_err_cnt
    );


    COUNTER_TRIG_TMR_TRIG_FORMATTER_TMR_ERR_CNT : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 16
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => reset_i or tmr_cnt_reset,
        en_i      => trig_formatter_tmr_err,
        snap_i    => cnt_snap,
        count_o   => trig_formatter_tmr_err_cnt
    );


    -- Connect rate instances

    -- Connect read ready signals

    -- Defaults
    regs_defaults(0)(REG_TRIG_CTRL_VFAT_MASK_MSB downto REG_TRIG_CTRL_VFAT_MASK_LSB) <= REG_TRIG_CTRL_VFAT_MASK_DEFAULT;
    regs_defaults(2)(REG_TRIG_CTRL_ALIGNED_COUNT_TO_READY_MSB downto REG_TRIG_CTRL_ALIGNED_COUNT_TO_READY_LSB) <= REG_TRIG_CTRL_ALIGNED_COUNT_TO_READY_DEFAULT;
    regs_defaults(6)(REG_TRIG_CTRL_INVERT_SOT_INVERT_MSB downto REG_TRIG_CTRL_INVERT_SOT_INVERT_LSB) <= REG_TRIG_CTRL_INVERT_SOT_INVERT_DEFAULT;
    regs_defaults(7)(REG_TRIG_CTRL_INVERT_VFAT0_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT0_TU_INVERT_LSB) <= REG_TRIG_CTRL_INVERT_VFAT0_TU_INVERT_DEFAULT;
    regs_defaults(7)(REG_TRIG_CTRL_INVERT_VFAT1_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT1_TU_INVERT_LSB) <= REG_TRIG_CTRL_INVERT_VFAT1_TU_INVERT_DEFAULT;
    regs_defaults(7)(REG_TRIG_CTRL_INVERT_VFAT2_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT2_TU_INVERT_LSB) <= REG_TRIG_CTRL_INVERT_VFAT2_TU_INVERT_DEFAULT;
    regs_defaults(7)(REG_TRIG_CTRL_INVERT_VFAT3_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT3_TU_INVERT_LSB) <= REG_TRIG_CTRL_INVERT_VFAT3_TU_INVERT_DEFAULT;
    regs_defaults(8)(REG_TRIG_CTRL_INVERT_VFAT4_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT4_TU_INVERT_LSB) <= REG_TRIG_CTRL_INVERT_VFAT4_TU_INVERT_DEFAULT;
    regs_defaults(8)(REG_TRIG_CTRL_INVERT_VFAT5_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT5_TU_INVERT_LSB) <= REG_TRIG_CTRL_INVERT_VFAT5_TU_INVERT_DEFAULT;
    regs_defaults(8)(REG_TRIG_CTRL_INVERT_VFAT6_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT6_TU_INVERT_LSB) <= REG_TRIG_CTRL_INVERT_VFAT6_TU_INVERT_DEFAULT;
    regs_defaults(8)(REG_TRIG_CTRL_INVERT_VFAT7_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT7_TU_INVERT_LSB) <= REG_TRIG_CTRL_INVERT_VFAT7_TU_INVERT_DEFAULT;
    regs_defaults(9)(REG_TRIG_CTRL_INVERT_VFAT8_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT8_TU_INVERT_LSB) <= REG_TRIG_CTRL_INVERT_VFAT8_TU_INVERT_DEFAULT;
    regs_defaults(9)(REG_TRIG_CTRL_INVERT_VFAT9_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT9_TU_INVERT_LSB) <= REG_TRIG_CTRL_INVERT_VFAT9_TU_INVERT_DEFAULT;
    regs_defaults(9)(REG_TRIG_CTRL_INVERT_VFAT10_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT10_TU_INVERT_LSB) <= REG_TRIG_CTRL_INVERT_VFAT10_TU_INVERT_DEFAULT;
    regs_defaults(9)(REG_TRIG_CTRL_INVERT_VFAT11_TU_INVERT_MSB downto REG_TRIG_CTRL_INVERT_VFAT11_TU_INVERT_LSB) <= REG_TRIG_CTRL_INVERT_VFAT11_TU_INVERT_DEFAULT;
    regs_defaults(10)(REG_TRIG_CTRL_TU_MASK_VFAT0_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT0_TU_MASK_LSB) <= REG_TRIG_CTRL_TU_MASK_VFAT0_TU_MASK_DEFAULT;
    regs_defaults(10)(REG_TRIG_CTRL_TU_MASK_VFAT1_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT1_TU_MASK_LSB) <= REG_TRIG_CTRL_TU_MASK_VFAT1_TU_MASK_DEFAULT;
    regs_defaults(10)(REG_TRIG_CTRL_TU_MASK_VFAT2_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT2_TU_MASK_LSB) <= REG_TRIG_CTRL_TU_MASK_VFAT2_TU_MASK_DEFAULT;
    regs_defaults(10)(REG_TRIG_CTRL_TU_MASK_VFAT3_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT3_TU_MASK_LSB) <= REG_TRIG_CTRL_TU_MASK_VFAT3_TU_MASK_DEFAULT;
    regs_defaults(11)(REG_TRIG_CTRL_TU_MASK_VFAT4_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT4_TU_MASK_LSB) <= REG_TRIG_CTRL_TU_MASK_VFAT4_TU_MASK_DEFAULT;
    regs_defaults(11)(REG_TRIG_CTRL_TU_MASK_VFAT5_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT5_TU_MASK_LSB) <= REG_TRIG_CTRL_TU_MASK_VFAT5_TU_MASK_DEFAULT;
    regs_defaults(11)(REG_TRIG_CTRL_TU_MASK_VFAT6_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT6_TU_MASK_LSB) <= REG_TRIG_CTRL_TU_MASK_VFAT6_TU_MASK_DEFAULT;
    regs_defaults(11)(REG_TRIG_CTRL_TU_MASK_VFAT7_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT7_TU_MASK_LSB) <= REG_TRIG_CTRL_TU_MASK_VFAT7_TU_MASK_DEFAULT;
    regs_defaults(12)(REG_TRIG_CTRL_TU_MASK_VFAT8_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT8_TU_MASK_LSB) <= REG_TRIG_CTRL_TU_MASK_VFAT8_TU_MASK_DEFAULT;
    regs_defaults(12)(REG_TRIG_CTRL_TU_MASK_VFAT9_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT9_TU_MASK_LSB) <= REG_TRIG_CTRL_TU_MASK_VFAT9_TU_MASK_DEFAULT;
    regs_defaults(12)(REG_TRIG_CTRL_TU_MASK_VFAT10_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT10_TU_MASK_LSB) <= REG_TRIG_CTRL_TU_MASK_VFAT10_TU_MASK_DEFAULT;
    regs_defaults(12)(REG_TRIG_CTRL_TU_MASK_VFAT11_TU_MASK_MSB downto REG_TRIG_CTRL_TU_MASK_VFAT11_TU_MASK_LSB) <= REG_TRIG_CTRL_TU_MASK_VFAT11_TU_MASK_DEFAULT;
    regs_defaults(13)(REG_TRIG_CTRL_SBIT_MAP_SEL_MSB downto REG_TRIG_CTRL_SBIT_MAP_SEL_LSB) <= REG_TRIG_CTRL_SBIT_MAP_SEL_DEFAULT;
    regs_defaults(13)(REG_TRIG_CTRL_REVERSE_PARTITIONS_BIT) <= REG_TRIG_CTRL_REVERSE_PARTITIONS_DEFAULT;
    regs_defaults(27)(REG_TRIG_CNT_SBIT_CNT_PERSIST_BIT) <= REG_TRIG_CNT_SBIT_CNT_PERSIST_DEFAULT;
    regs_defaults(28)(REG_TRIG_CNT_SBIT_CNT_TIME_MAX_MSB downto REG_TRIG_CNT_SBIT_CNT_TIME_MAX_LSB) <= REG_TRIG_CNT_SBIT_CNT_TIME_MAX_DEFAULT;
    regs_defaults(42)(REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT0_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT0_DEFAULT;
    regs_defaults(42)(REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT1_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT1_DEFAULT;
    regs_defaults(42)(REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT2_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT2_DEFAULT;
    regs_defaults(42)(REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT3_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT3_DEFAULT;
    regs_defaults(42)(REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT4_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT4_DEFAULT;
    regs_defaults(42)(REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT5_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT5_DEFAULT;
    regs_defaults(43)(REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT6_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT6_DEFAULT;
    regs_defaults(43)(REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT7_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT0_BIT7_DEFAULT;
    regs_defaults(43)(REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT0_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT0_DEFAULT;
    regs_defaults(43)(REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT1_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT1_DEFAULT;
    regs_defaults(43)(REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT2_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT2_DEFAULT;
    regs_defaults(43)(REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT3_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT3_DEFAULT;
    regs_defaults(44)(REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT4_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT4_DEFAULT;
    regs_defaults(44)(REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT5_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT5_DEFAULT;
    regs_defaults(44)(REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT6_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT6_DEFAULT;
    regs_defaults(44)(REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT7_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT1_BIT7_DEFAULT;
    regs_defaults(44)(REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT0_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT0_DEFAULT;
    regs_defaults(44)(REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT1_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT1_DEFAULT;
    regs_defaults(45)(REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT2_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT2_DEFAULT;
    regs_defaults(45)(REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT3_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT3_DEFAULT;
    regs_defaults(45)(REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT4_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT4_DEFAULT;
    regs_defaults(45)(REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT5_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT5_DEFAULT;
    regs_defaults(45)(REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT6_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT6_DEFAULT;
    regs_defaults(45)(REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT7_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT2_BIT7_DEFAULT;
    regs_defaults(46)(REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT0_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT0_DEFAULT;
    regs_defaults(46)(REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT1_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT1_DEFAULT;
    regs_defaults(46)(REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT2_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT2_DEFAULT;
    regs_defaults(46)(REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT3_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT3_DEFAULT;
    regs_defaults(46)(REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT4_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT4_DEFAULT;
    regs_defaults(46)(REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT5_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT5_DEFAULT;
    regs_defaults(47)(REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT6_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT6_DEFAULT;
    regs_defaults(47)(REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT7_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT3_BIT7_DEFAULT;
    regs_defaults(47)(REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT0_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT0_DEFAULT;
    regs_defaults(47)(REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT1_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT1_DEFAULT;
    regs_defaults(47)(REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT2_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT2_DEFAULT;
    regs_defaults(47)(REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT3_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT3_DEFAULT;
    regs_defaults(48)(REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT4_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT4_DEFAULT;
    regs_defaults(48)(REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT5_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT5_DEFAULT;
    regs_defaults(48)(REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT6_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT6_DEFAULT;
    regs_defaults(48)(REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT7_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT4_BIT7_DEFAULT;
    regs_defaults(48)(REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT0_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT0_DEFAULT;
    regs_defaults(48)(REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT1_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT1_DEFAULT;
    regs_defaults(49)(REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT2_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT2_DEFAULT;
    regs_defaults(49)(REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT3_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT3_DEFAULT;
    regs_defaults(49)(REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT4_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT4_DEFAULT;
    regs_defaults(49)(REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT5_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT5_DEFAULT;
    regs_defaults(49)(REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT6_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT6_DEFAULT;
    regs_defaults(49)(REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT7_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT5_BIT7_DEFAULT;
    regs_defaults(50)(REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT0_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT0_DEFAULT;
    regs_defaults(50)(REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT1_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT1_DEFAULT;
    regs_defaults(50)(REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT2_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT2_DEFAULT;
    regs_defaults(50)(REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT3_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT3_DEFAULT;
    regs_defaults(50)(REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT4_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT4_DEFAULT;
    regs_defaults(50)(REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT5_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT5_DEFAULT;
    regs_defaults(51)(REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT6_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT6_DEFAULT;
    regs_defaults(51)(REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT7_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT6_BIT7_DEFAULT;
    regs_defaults(51)(REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT0_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT0_DEFAULT;
    regs_defaults(51)(REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT1_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT1_DEFAULT;
    regs_defaults(51)(REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT2_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT2_DEFAULT;
    regs_defaults(51)(REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT3_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT3_DEFAULT;
    regs_defaults(52)(REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT4_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT4_DEFAULT;
    regs_defaults(52)(REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT5_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT5_DEFAULT;
    regs_defaults(52)(REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT6_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT6_DEFAULT;
    regs_defaults(52)(REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT7_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT7_BIT7_DEFAULT;
    regs_defaults(52)(REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT0_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT0_DEFAULT;
    regs_defaults(52)(REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT1_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT1_DEFAULT;
    regs_defaults(53)(REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT2_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT2_DEFAULT;
    regs_defaults(53)(REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT3_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT3_DEFAULT;
    regs_defaults(53)(REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT4_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT4_DEFAULT;
    regs_defaults(53)(REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT5_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT5_DEFAULT;
    regs_defaults(53)(REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT6_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT6_DEFAULT;
    regs_defaults(53)(REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT7_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT8_BIT7_DEFAULT;
    regs_defaults(54)(REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT0_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT0_DEFAULT;
    regs_defaults(54)(REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT1_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT1_DEFAULT;
    regs_defaults(54)(REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT2_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT2_DEFAULT;
    regs_defaults(54)(REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT3_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT3_DEFAULT;
    regs_defaults(54)(REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT4_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT4_DEFAULT;
    regs_defaults(54)(REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT5_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT5_DEFAULT;
    regs_defaults(55)(REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT6_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT6_DEFAULT;
    regs_defaults(55)(REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT7_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT9_BIT7_DEFAULT;
    regs_defaults(55)(REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT0_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT0_DEFAULT;
    regs_defaults(55)(REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT1_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT1_DEFAULT;
    regs_defaults(55)(REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT2_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT2_DEFAULT;
    regs_defaults(55)(REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT3_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT3_DEFAULT;
    regs_defaults(56)(REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT4_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT4_DEFAULT;
    regs_defaults(56)(REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT5_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT5_DEFAULT;
    regs_defaults(56)(REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT6_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT6_DEFAULT;
    regs_defaults(56)(REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT7_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT10_BIT7_DEFAULT;
    regs_defaults(56)(REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT0_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT0_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT0_DEFAULT;
    regs_defaults(56)(REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT1_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT1_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT1_DEFAULT;
    regs_defaults(57)(REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT2_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT2_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT2_DEFAULT;
    regs_defaults(57)(REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT3_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT3_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT3_DEFAULT;
    regs_defaults(57)(REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT4_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT4_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT4_DEFAULT;
    regs_defaults(57)(REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT5_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT5_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT5_DEFAULT;
    regs_defaults(57)(REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT6_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT6_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT6_DEFAULT;
    regs_defaults(57)(REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT7_MSB downto REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT7_LSB) <= REG_TRIG_TIMING_TAP_DELAY_VFAT11_BIT7_DEFAULT;
    regs_defaults(58)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT0_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT0_LSB) <= REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT0_DEFAULT;
    regs_defaults(58)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT1_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT1_LSB) <= REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT1_DEFAULT;
    regs_defaults(58)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT2_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT2_LSB) <= REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT2_DEFAULT;
    regs_defaults(58)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT3_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT3_LSB) <= REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT3_DEFAULT;
    regs_defaults(58)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT4_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT4_LSB) <= REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT4_DEFAULT;
    regs_defaults(58)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT5_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT5_LSB) <= REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT5_DEFAULT;
    regs_defaults(59)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT6_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT6_LSB) <= REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT6_DEFAULT;
    regs_defaults(59)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT7_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT7_LSB) <= REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT7_DEFAULT;
    regs_defaults(59)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT8_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT8_LSB) <= REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT8_DEFAULT;
    regs_defaults(59)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT9_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT9_LSB) <= REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT9_DEFAULT;
    regs_defaults(59)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT10_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT10_LSB) <= REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT10_DEFAULT;
    regs_defaults(59)(REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT11_MSB downto REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT11_LSB) <= REG_TRIG_TIMING_SOT_TAP_DELAY_VFAT11_DEFAULT;
    regs_defaults(60)(REG_TRIG_SBIT_INJECT_MASK_MSB downto REG_TRIG_SBIT_INJECT_MASK_LSB) <= REG_TRIG_SBIT_INJECT_MASK_DEFAULT;
    regs_defaults(60)(REG_TRIG_CYCLIC_INJECT_EN_BIT) <= REG_TRIG_CYCLIC_INJECT_EN_DEFAULT;
    regs_defaults(72)(REG_TRIG_SBIT_MONITOR_TRIG_ON_INVALID_BIT) <= REG_TRIG_SBIT_MONITOR_TRIG_ON_INVALID_DEFAULT;
    regs_defaults(74)(REG_TRIG_SBIT_HITMAP_ACQUIRE_BIT) <= REG_TRIG_SBIT_HITMAP_ACQUIRE_DEFAULT;
    regs_defaults(99)(REG_TRIG_TRIGGER_PRBS_EN_BIT) <= REG_TRIG_TRIGGER_PRBS_EN_DEFAULT;
    regs_defaults(100)(REG_TRIG_L1A_MASK_L1A_MASK_DELAY_MSB downto REG_TRIG_L1A_MASK_L1A_MASK_DELAY_LSB) <= REG_TRIG_L1A_MASK_L1A_MASK_DELAY_DEFAULT;
    regs_defaults(101)(REG_TRIG_L1A_MASK_L1A_MASK_BITMASK_MSB downto REG_TRIG_L1A_MASK_L1A_MASK_BITMASK_LSB) <= REG_TRIG_L1A_MASK_L1A_MASK_BITMASK_DEFAULT;

    -- Define writable regs
    regs_writable_arr(0) <= '1';
    regs_writable_arr(2) <= '1';
    regs_writable_arr(6) <= '1';
    regs_writable_arr(7) <= '1';
    regs_writable_arr(8) <= '1';
    regs_writable_arr(9) <= '1';
    regs_writable_arr(10) <= '1';
    regs_writable_arr(11) <= '1';
    regs_writable_arr(12) <= '1';
    regs_writable_arr(13) <= '1';
    regs_writable_arr(27) <= '1';
    regs_writable_arr(28) <= '1';
    regs_writable_arr(42) <= '1';
    regs_writable_arr(43) <= '1';
    regs_writable_arr(44) <= '1';
    regs_writable_arr(45) <= '1';
    regs_writable_arr(46) <= '1';
    regs_writable_arr(47) <= '1';
    regs_writable_arr(48) <= '1';
    regs_writable_arr(49) <= '1';
    regs_writable_arr(50) <= '1';
    regs_writable_arr(51) <= '1';
    regs_writable_arr(52) <= '1';
    regs_writable_arr(53) <= '1';
    regs_writable_arr(54) <= '1';
    regs_writable_arr(55) <= '1';
    regs_writable_arr(56) <= '1';
    regs_writable_arr(57) <= '1';
    regs_writable_arr(58) <= '1';
    regs_writable_arr(59) <= '1';
    regs_writable_arr(60) <= '1';
    regs_writable_arr(72) <= '1';
    regs_writable_arr(74) <= '1';
    regs_writable_arr(99) <= '1';
    regs_writable_arr(100) <= '1';
    regs_writable_arr(101) <= '1';

  --==== Registers end ============================================================================

end Behavioral;
