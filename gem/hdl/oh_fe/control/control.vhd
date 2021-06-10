----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid v3 Firmware -- Control
-- A. Peck
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library work;
use work.types_pkg.all;
use work.ipbus_pkg.all;
use work.hardware_pkg.all;
use work.registers.all;

entity control is
  generic (
    -- these generics get set by hog at synthesis
    GLOBAL_DATE : std_logic_vector (31 downto 0) := x"00000000";
    GLOBAL_TIME : std_logic_vector (31 downto 0) := x"00000000";
    GLOBAL_VER  : std_logic_vector (31 downto 0) := x"00000000";
    GLOBAL_SHA  : std_logic_vector (31 downto 0) := x"00000000";

    XML_VER : std_logic_vector (31 downto 0) := x"00000000";
    XML_SHA : std_logic_vector (31 downto 0) := x"00000000";

    TOP_SHA : std_logic_vector (31 downto 0) := x"00000000";
    TOP_VER : std_logic_vector (31 downto 0) := x"00000000";

    HOG_SHA : std_logic_vector (31 downto 0) := x"00000000";
    HOG_VER : std_logic_vector (31 downto 0) := x"00000000";

    OPTOHYBRID_VER : std_logic_vector (31 downto 0) := x"00000000";
    OPTOHYBRID_SHA : std_logic_vector (31 downto 0) := x"00000000";

    FLAVOUR : integer := 0
    );
  port(

    mgts_ready : in std_logic;
    pll_lock   : in std_logic;
    txfsm_done : in std_logic;

    --== TTC ==--

    clocks : in clocks_t;
    ttc_i  : in ttc_t;
    reset  : in std_logic;

    ipb_mosi_i : in  ipb_wbus;
    ipb_miso_o : out ipb_rbus;

    ipb_switch_tmr_err : in std_logic;

    -------------------
    -- status inputs --
    -------------------

    -- MMCM
    mmcms_locked_i : in std_logic;

    -- GBT

    gbt_rxready_i    : in std_logic;
    gbt_link_ready_i : in std_logic;
    gbt_rxvalid_i    : in std_logic;
    gbt_txready_i    : in std_logic;

    -- Trigger

    active_vfats_i  : in std_logic_vector (NUM_VFATS-1 downto 0);
    sbit_overflow_i : in std_logic;
    cluster_count_i : in std_logic_vector (10 downto 0);

    -- GBT
    gbt_link_error_i       : in std_logic;
    gbt_request_received_i : in std_logic;

    --------------------
    -- config outputs --
    --------------------

    -- VFAT
    vfat_reset_o : out std_logic_vector (11 downto 0);
    ext_sbits_o  : out std_logic_vector(7 downto 0);

    -- LEDs
    led_o : out std_logic_vector(15 downto 0);

    -- pulse to synchronously snap all counters for readout
    -- freeze high to make counters transparent (asynchronous readout)
    cnt_snap_o : out std_logic;

    -------------
    -- outputs --
    -------------

    bxn_counter_o : out std_logic_vector (11 downto 0)
    );

end control;

architecture Behavioral of control is

  signal tmr_cnt_reset     : std_logic;
  signal tmr_err_inj       : std_logic;
  signal ttc_tmr_err       : std_logic;
  signal ipb_slave_tmr_err : std_logic;

  component device_dna
    port (
      clock : in  std_logic;
      reset : in  std_logic;
      dna   : out std_logic_vector (56 downto 0)
      );
  end component;

  component USR_ACCESSE2
    port (
      cfgclk    : out std_logic;
      datavalid : out std_logic;
      data      : out std_logic_vector (31 downto 0)
      );
  end component;

  component USR_ACCESS_VIRTEX6
    port (
      cfgclk    : out std_logic;
      datavalid : out std_logic;
      data      : out std_logic_vector (31 downto 0)
      );
  end component;

  component external
    generic (GE21      : integer;
             NUM_VFATS : integer);
    port (
      clock : in std_logic;

      reset_i : in std_logic;

      active_vfats_i : in std_logic_vector (NUM_VFATS-1 downto 0);

      sbit_mode0 : in std_logic_vector (1 downto 0);
      sbit_mode1 : in std_logic_vector (1 downto 0);
      sbit_mode2 : in std_logic_vector (1 downto 0);
      sbit_mode3 : in std_logic_vector (1 downto 0);
      sbit_mode4 : in std_logic_vector (1 downto 0);
      sbit_mode5 : in std_logic_vector (1 downto 0);
      sbit_mode6 : in std_logic_vector (1 downto 0);
      sbit_mode7 : in std_logic_vector (1 downto 0);
      sbit_sel0  : in std_logic_vector (4 downto 0);
      sbit_sel1  : in std_logic_vector (4 downto 0);
      sbit_sel2  : in std_logic_vector (4 downto 0);
      sbit_sel3  : in std_logic_vector (4 downto 0);
      sbit_sel4  : in std_logic_vector (4 downto 0);
      sbit_sel5  : in std_logic_vector (4 downto 0);
      sbit_sel6  : in std_logic_vector (4 downto 0);
      sbit_sel7  : in std_logic_vector (4 downto 0);

      ext_sbits_o : out std_logic_vector (7 downto 0)
      );
  end component;


  signal uptime : unsigned (19 downto 0);

  -- SEM

  signal sem_initialization : std_logic;
  signal sem_classification : std_logic;
  signal sem_observation    : std_logic;
  signal sem_correction     : std_logic;
  signal sem_uncorrectable  : std_logic;
  signal sem_injection      : std_logic;
  signal sem_essential      : std_logic;
  signal sem_idle           : std_logic;

  signal sem_inject_strobe       : std_logic;
  signal sem_inject_address      : std_logic_vector(39 downto 0);
  signal sem_critical_pulse      : std_logic;
  signal sem_correction_pulse    : std_logic;
  signal sem_uncorrectable_pulse : std_logic;
  signal sem_essential_pulse     : std_logic;

  -- Sbits

  signal sbit_sel0 : std_logic_vector(4 downto 0);
  signal sbit_sel1 : std_logic_vector(4 downto 0);
  signal sbit_sel2 : std_logic_vector(4 downto 0);
  signal sbit_sel3 : std_logic_vector(4 downto 0);
  signal sbit_sel4 : std_logic_vector(4 downto 0);
  signal sbit_sel5 : std_logic_vector(4 downto 0);
  signal sbit_sel6 : std_logic_vector(4 downto 0);
  signal sbit_sel7 : std_logic_vector(4 downto 0);

  signal sbit_mode0 : std_logic_vector(1 downto 0);
  signal sbit_mode1 : std_logic_vector(1 downto 0);
  signal sbit_mode2 : std_logic_vector(1 downto 0);
  signal sbit_mode3 : std_logic_vector(1 downto 0);
  signal sbit_mode4 : std_logic_vector(1 downto 0);
  signal sbit_mode5 : std_logic_vector(1 downto 0);
  signal sbit_mode6 : std_logic_vector(1 downto 0);
  signal sbit_mode7 : std_logic_vector(1 downto 0);

  signal cluster_rate : std_logic_vector(31 downto 0);

  -- Loopback

  signal loopback : std_logic_vector(31 downto 0);

  -- TTC Sync

  signal bx0_local                  : std_logic;
  attribute mark_debug              : string;
  attribute mark_debug of bx0_local : signal is "TRUE";

  signal cnt_snap         : std_logic;
  signal cnt_snap_pulse   : std_logic;
  signal cnt_snap_disable : std_logic;

  signal ttc_bxn_offset  : std_logic_vector (11 downto 0);
  signal ttc_bxn_counter : std_logic_vector (11 downto 0);

  signal ttc_bx0_sync_err : std_logic;
  signal ttc_bxn_sync_err : std_logic;

  signal vfat_startup_reset           : std_logic_vector (11 downto 0);
  signal vfat_startup_reset_timer     : unsigned (31 downto 0);
  signal vfat_startup_reset_timer_max : natural := 32;
  signal vfat_reset                   : std_logic_vector (11 downto 0);

  signal cnt_reset : std_logic;

  signal dna : std_logic_vector (56 downto 0);

  signal usr_access : std_logic_vector (31 downto 0);

  component led_control
    port(
      mgts_ready           : in  std_logic;
      txfsm_done           : in  std_logic;
      pll_lock             : in  std_logic;
      clock                : in  std_logic;
      mmcm_locked          : in  std_logic;
      ttc_l1a              : in  std_logic;
      ttc_bc0              : in  std_logic;
      ttc_resync           : in  std_logic;
      gbt_rxready          : in  std_logic;
      gbt_rxvalid          : in  std_logic;
      gbt_link_ready       : in  std_logic;
      gbt_request_received : in  std_logic;
      reset                : in  std_logic;
      cluster_count_i      : in  std_logic_vector(10 downto 0);
      cluster_rate         : out std_logic_vector(31 downto 0);
      led_out              : out std_logic_vector(15 downto 0)
      );
  end component;

  ------ Register signals begin (this section is generated by <optohybrid_top>/tools/generate_registers.py -- do not edit)
    signal regs_read_arr        : t_std32_array(REG_CONTROL_NUM_REGS - 1 downto 0) := (others => (others => '0'));
    signal regs_write_arr       : t_std32_array(REG_CONTROL_NUM_REGS - 1 downto 0) := (others => (others => '0'));
    signal regs_addresses       : t_std32_array(REG_CONTROL_NUM_REGS - 1 downto 0) := (others => (others => '0'));
    signal regs_defaults        : t_std32_array(REG_CONTROL_NUM_REGS - 1 downto 0) := (others => (others => '0'));
    signal regs_read_pulse_arr  : std_logic_vector(REG_CONTROL_NUM_REGS - 1 downto 0) := (others => '0');
    signal regs_write_pulse_arr : std_logic_vector(REG_CONTROL_NUM_REGS - 1 downto 0) := (others => '0');
    signal regs_read_ready_arr  : std_logic_vector(REG_CONTROL_NUM_REGS - 1 downto 0) := (others => '1');
    signal regs_write_done_arr  : std_logic_vector(REG_CONTROL_NUM_REGS - 1 downto 0) := (others => '1');
    signal regs_writable_arr    : std_logic_vector(REG_CONTROL_NUM_REGS - 1 downto 0) := (others => '0');
    -- Connect counter signal declarations
    signal cnt_sem_uncorrectable : std_logic_vector (15 downto 0) := (others => '0');
    signal cnt_sem_correction : std_logic_vector (15 downto 0) := (others => '0');
    signal cnt_sem_injection : std_logic_vector (15 downto 0) := (others => '0');
    signal cnt_bx0_lcl : std_logic_vector (23 downto 0) := (others => '0');
    signal cnt_bx0_rxd : std_logic_vector (23 downto 0) := (others => '0');
    signal cnt_l1a : std_logic_vector (23 downto 0) := (others => '0');
    signal cnt_bxn_sync_err : std_logic_vector (15 downto 0) := (others => '0');
    signal cnt_bx0_sync_err : std_logic_vector (15 downto 0) := (others => '0');
    signal ttc_tmr_err_cnt : std_logic_vector (15 downto 0) := (others => '0');
    signal ipb_switch_tmr_err_cnt : std_logic_vector (15 downto 0) := (others => '0');
    signal ipb_slave_tmr_err_cnt : std_logic_vector (15 downto 0) := (others => '0');
  ------ Register signals end ----------------------------------------------

begin

  --------------------------------------------------------------------------------------------------------------------
  -- Outputs
  --------------------------------------------------------------------------------------------------------------------

  vfat_reset_o  <= vfat_reset or vfat_startup_reset;
  bxn_counter_o <= ttc_bxn_counter;
  cnt_snap_o    <= cnt_snap;

  --------------------------------------------------------------------------------------------------------------------
  -- Startup
  --------------------------------------------------------------------------------------------------------------------

  process (clocks.clk40)
  begin
    if (rising_edge(clocks.clk40)) then

      -- startup timer; count to max then deassert the startup reset
      if (reset = '1') then
        vfat_startup_reset_timer <= (others => '0');
      elsif (vfat_startup_reset_timer < vfat_startup_reset_timer_max) then
        vfat_startup_reset_timer <= vfat_startup_reset_timer + 1;
      end if;

      if (vfat_startup_reset_timer < vfat_startup_reset_timer_max) then
        vfat_startup_reset <= (others => '1');
      else
        vfat_startup_reset <= (others => '0');
      end if;

    end if;
  end process;

  --------------------------------------------------------------------------------------------------------------------
  -- Reset
  --------------------------------------------------------------------------------------------------------------------

  process (clocks.clk40)
  begin
    if (rising_edge(clocks.clk40)) then
      cnt_reset <= reset or ttc_i.resync;
    end if;
  end process;

  --------------------------------------------------------------------------------------------------------------------
  -- Count Snap
  --------------------------------------------------------------------------------------------------------------------

  -- clock the OR for fanout
  process (clocks.clk40)
  begin
    if (rising_edge(clocks.clk40)) then
      cnt_snap <= cnt_snap_pulse or cnt_snap_disable;
    end if;
  end process;

  --------------------------------------------------------------------------------------------------------------------
  -- Uptime
  --------------------------------------------------------------------------------------------------------------------

  process (clocks.clk40) is
    variable uptime_cnt : unsigned (29 downto 0) := (others => '0');
  begin
    if (rising_edge(clocks.clk40)) then
      if (reset = '1') then
        uptime_cnt := (others => '0');
        uptime     <= (others => '0');
      elsif (uptime_cnt < x"2638e98") then
        uptime_cnt := uptime_cnt + 1;
      else
        uptime_cnt := (others => '0');
        uptime     <= uptime + 1;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------------------------------------------------------
  -- LED Control
  --------------------------------------------------------------------------------------------------------------------

  led_control_inst : led_control
    port map (

      -- clock
      clock       => clocks.clk40,
      mmcm_locked => mmcms_locked_i,
      reset       => reset,

      -- mgt
      mgts_ready => mgts_ready,
      pll_lock   => pll_lock,
      txfsm_done => txfsm_done,

      -- ttc commands

      ttc_l1a    => ttc_i.l1a,
      ttc_bc0    => ttc_i.bc0,
      ttc_resync => ttc_i.resync,

      -- signals
      gbt_rxready          => gbt_rxready_i,
      gbt_rxvalid          => gbt_rxvalid_i,
      gbt_link_ready       => gbt_link_ready_i,
      gbt_request_received => gbt_request_received_i,

      cluster_count_i => cluster_count_i (10 downto 0),

      cluster_rate => cluster_rate (31 downto 0),

      -- led outputs
      led_out => led_o
      );

  --------------------------------------------------------------------------------------------------------------------
  -- USR_ACCESS Readout
  --------------------------------------------------------------------------------------------------------------------

  ge11_usr_access : if (ge11 = 1) generate
    usr_access_inst : USR_ACCESS_VIRTEX6 port map (
      CFGCLK    => open,                -- Not utilized in the static use case in this application note
      DATA      => usr_access,          -- 32-bit output Configuration Data output
      DATAVALID => open                 -- Not utilized in the static use case in this application note
      );
  end generate;
  ge21_usr_access : if (ge21 = 1) generate
    usr_access_inst : USR_ACCESSE2 port map (
      CFGCLK    => open,                -- Not utilized in the static use case in this application note
      DATA      => usr_access,          -- 32-bit output Configuration Data output
      DATAVALID => open                 -- Not utilized in the static use case in this application note
      );
  end generate;

  --------------------------------------------------------------------------------------------------------------------
  -- Device DNA
  --------------------------------------------------------------------------------------------------------------------

  device_dna_inst : device_dna
    port map (
      clock => clocks.clk40,
      reset => reset,
      dna   => dna
      );

  --------------------------------------------------------------------------------------------------------------------
  -- HDMI Signals
  --------------------------------------------------------------------------------------------------------------------

  -- This module handles the external signals: the input trigger and the output SBits.

  external_inst : external
    generic map (GE21 => GE21, NUM_VFATS => NUM_VFATS)
    port map(
      clock => clocks.clk40,

      reset_i => reset,

      active_vfats_i => active_vfats_i,

      sbit_mode0 => sbit_mode0,
      sbit_mode1 => sbit_mode1,
      sbit_mode2 => sbit_mode2,
      sbit_mode3 => sbit_mode3,
      sbit_mode4 => sbit_mode4,
      sbit_mode5 => sbit_mode5,
      sbit_mode6 => sbit_mode6,
      sbit_mode7 => sbit_mode7,

      sbit_sel0 => sbit_sel0,
      sbit_sel1 => sbit_sel1,
      sbit_sel2 => sbit_sel2,
      sbit_sel3 => sbit_sel3,
      sbit_sel4 => sbit_sel4,
      sbit_sel5 => sbit_sel5,
      sbit_sel6 => sbit_sel6,
      sbit_sel7 => sbit_sel7,

      ext_sbits_o => ext_sbits_o
      );

  --------------------------------------------------------------------------------------------------------------------
  -- TTC
  --------------------------------------------------------------------------------------------------------------------

  ttc_inst : entity work.ttc_tmr

    port map (

      -- clock & reset
      clock => clocks.clk40,
      reset => reset,

      -- ttc commands
      ttc_bx0    => ttc_i.bc0,
      bx0_local  => bx0_local,
      ttc_resync => ttc_i.resync,

      -- control
      bxn_offset => ttc_bxn_offset,

      -- output
      bxn_counter  => ttc_bxn_counter,
      bx0_sync_err => ttc_bx0_sync_err,
      bxn_sync_err => ttc_bxn_sync_err,

      tmr_err_inj_i => tmr_err_inj,
      tmr_err_o     => ttc_tmr_err

      );

  --------------------------------------------------------------------------------------------------------------------
  -- SEU Monitoring
  --------------------------------------------------------------------------------------------------------------------

  sem_mon_inst : entity work.sem_mon
    port map(
      clk_i            => clocks.clk80,
      sysclk_i         => clocks.clk40,
      heartbeat_o      => open,
      inject_strobe    => sem_inject_strobe,
      inject_address   => sem_inject_address,

      initialization_o => sem_initialization,
      observation_o    => sem_observation,
      correction_o     => sem_correction,
      classification_o => sem_classification,
      injection_o      => sem_injection,
      idle_o           => sem_idle,

      essential_o      => sem_essential,
      uncorrectable_o  => sem_uncorrectable,

      correction_pulse_o    => sem_correction_pulse,
      uncorrectable_pulse_o => sem_uncorrectable_pulse,
      essential_pulse_o     => sem_essential_pulse
      );

  --===============================================================================================
  -- (this section is generated by <optohybrid_top>/tools/generate_registers.py -- do not edit)
  --==== Registers begin ==========================================================================

    -- IPbus slave instanciation
    ipbus_slave_inst : entity work.ipbus_slave_tmr
        generic map(
           g_ENABLE_TMR           => EN_TMR_IPB_SLAVE_CONTROL,
           g_NUM_REGS             => REG_CONTROL_NUM_REGS,
           g_ADDR_HIGH_BIT        => REG_CONTROL_ADDRESS_MSB,
           g_ADDR_LOW_BIT         => REG_CONTROL_ADDRESS_LSB,
           g_USE_INDIVIDUAL_ADDRS => true
       )
       port map(
           ipb_reset_i            => reset,
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
    regs_addresses(0)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "00" & x"0";
    regs_addresses(1)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "00" & x"3";
    regs_addresses(2)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "00" & x"4";
    regs_addresses(3)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "00" & x"5";
    regs_addresses(4)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "00" & x"6";
    regs_addresses(5)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "00" & x"7";
    regs_addresses(6)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "00" & x"8";
    regs_addresses(7)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "00" & x"9";
    regs_addresses(8)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "00" & x"a";
    regs_addresses(9)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "00" & x"b";
    regs_addresses(10)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "00" & x"c";
    regs_addresses(11)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "00" & x"d";
    regs_addresses(12)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "00" & x"e";
    regs_addresses(13)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "00" & x"f";
    regs_addresses(14)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "01" & x"0";
    regs_addresses(15)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "01" & x"1";
    regs_addresses(16)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "01" & x"2";
    regs_addresses(17)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "01" & x"3";
    regs_addresses(18)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "01" & x"4";
    regs_addresses(19)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "01" & x"5";
    regs_addresses(20)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "01" & x"6";
    regs_addresses(21)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "01" & x"8";
    regs_addresses(22)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "01" & x"9";
    regs_addresses(23)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "01" & x"a";
    regs_addresses(24)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "10" & x"0";
    regs_addresses(25)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "10" & x"2";
    regs_addresses(26)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "10" & x"3";
    regs_addresses(27)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "10" & x"4";
    regs_addresses(28)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "10" & x"5";
    regs_addresses(29)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "10" & x"6";
    regs_addresses(30)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "10" & x"7";
    regs_addresses(31)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "10" & x"8";
    regs_addresses(32)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "10" & x"9";
    regs_addresses(33)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "10" & x"a";
    regs_addresses(34)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "10" & x"b";
    regs_addresses(35)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "10" & x"c";
    regs_addresses(36)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "11" & x"0";
    regs_addresses(37)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "11" & x"1";
    regs_addresses(38)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "11" & x"2";
    regs_addresses(39)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "11" & x"3";
    regs_addresses(40)(REG_CONTROL_ADDRESS_MSB downto REG_CONTROL_ADDRESS_LSB) <= "11" & x"4";

    -- Connect read signals
    regs_read_arr(0)(REG_CONTROL_LOOPBACK_DATA_MSB downto REG_CONTROL_LOOPBACK_DATA_LSB) <= loopback;
    regs_read_arr(1)(REG_CONTROL_SEM_CNT_SEM_CRITICAL_MSB downto REG_CONTROL_SEM_CNT_SEM_CRITICAL_LSB) <= cnt_sem_uncorrectable;
    regs_read_arr(2)(REG_CONTROL_SEM_CNT_SEM_CORRECTION_MSB downto REG_CONTROL_SEM_CNT_SEM_CORRECTION_LSB) <= cnt_sem_correction;
    regs_read_arr(4)(REG_CONTROL_SEM_INJ_ADDR_LSBS_MSB downto REG_CONTROL_SEM_INJ_ADDR_LSBS_LSB) <= sem_inject_address(31 downto 0);
    regs_read_arr(5)(REG_CONTROL_SEM_INJ_ADDR_MSBS_MSB downto REG_CONTROL_SEM_INJ_ADDR_MSBS_LSB) <= sem_inject_address(39 downto 32);
    regs_read_arr(5)(REG_CONTROL_SEM_CNT_SEM_INJECTIONS_MSB downto REG_CONTROL_SEM_CNT_SEM_INJECTIONS_LSB) <= cnt_sem_injection;
    regs_read_arr(6)(REG_CONTROL_SEM_SEM_STATUS_INITIALIZATION_BIT) <= sem_initialization;
    regs_read_arr(6)(REG_CONTROL_SEM_SEM_STATUS_OBSERVATION_BIT) <= sem_observation;
    regs_read_arr(6)(REG_CONTROL_SEM_SEM_STATUS_CORRECTION_BIT) <= sem_correction;
    regs_read_arr(6)(REG_CONTROL_SEM_SEM_STATUS_CLASSIFICATION_BIT) <= sem_classification;
    regs_read_arr(6)(REG_CONTROL_SEM_SEM_STATUS_INJECTION_BIT) <= sem_injection;
    regs_read_arr(6)(REG_CONTROL_SEM_SEM_STATUS_ESSENTIAL_BIT) <= sem_essential;
    regs_read_arr(6)(REG_CONTROL_SEM_SEM_STATUS_UNCORRECTABLE_BIT) <= sem_uncorrectable;
    regs_read_arr(6)(REG_CONTROL_SEM_SEM_STATUS_IDLE_BIT) <= sem_idle;
    regs_read_arr(7)(REG_CONTROL_VFAT_RESET_MSB downto REG_CONTROL_VFAT_RESET_LSB) <= vfat_reset(11 downto 0);
    regs_read_arr(8)(REG_CONTROL_TTC_BX0_CNT_LOCAL_MSB downto REG_CONTROL_TTC_BX0_CNT_LOCAL_LSB) <= cnt_bx0_lcl;
    regs_read_arr(9)(REG_CONTROL_TTC_BX0_CNT_TTC_MSB downto REG_CONTROL_TTC_BX0_CNT_TTC_LSB) <= cnt_bx0_rxd;
    regs_read_arr(10)(REG_CONTROL_TTC_BXN_CNT_LOCAL_MSB downto REG_CONTROL_TTC_BXN_CNT_LOCAL_LSB) <= ttc_bxn_counter;
    regs_read_arr(11)(REG_CONTROL_TTC_BXN_SYNC_ERR_BIT) <= ttc_bxn_sync_err;
    regs_read_arr(12)(REG_CONTROL_TTC_BX0_SYNC_ERR_BIT) <= ttc_bx0_sync_err;
    regs_read_arr(13)(REG_CONTROL_TTC_BXN_OFFSET_MSB downto REG_CONTROL_TTC_BXN_OFFSET_LSB) <= ttc_bxn_offset;
    regs_read_arr(14)(REG_CONTROL_TTC_L1A_CNT_MSB downto REG_CONTROL_TTC_L1A_CNT_LSB) <= cnt_l1a;
    regs_read_arr(15)(REG_CONTROL_TTC_BXN_SYNC_ERR_CNT_MSB downto REG_CONTROL_TTC_BXN_SYNC_ERR_CNT_LSB) <= cnt_bxn_sync_err;
    regs_read_arr(16)(REG_CONTROL_TTC_BX0_SYNC_ERR_CNT_MSB downto REG_CONTROL_TTC_BX0_SYNC_ERR_CNT_LSB) <= cnt_bx0_sync_err;
    regs_read_arr(16)(REG_CONTROL_SBITS_CLUSTER_RATE_MSB downto REG_CONTROL_SBITS_CLUSTER_RATE_LSB) <= cluster_rate;
    regs_read_arr(17)(REG_CONTROL_HDMI_SBIT_SEL0_MSB downto REG_CONTROL_HDMI_SBIT_SEL0_LSB) <= sbit_sel0;
    regs_read_arr(17)(REG_CONTROL_HDMI_SBIT_SEL1_MSB downto REG_CONTROL_HDMI_SBIT_SEL1_LSB) <= sbit_sel1;
    regs_read_arr(17)(REG_CONTROL_HDMI_SBIT_SEL2_MSB downto REG_CONTROL_HDMI_SBIT_SEL2_LSB) <= sbit_sel2;
    regs_read_arr(17)(REG_CONTROL_HDMI_SBIT_SEL3_MSB downto REG_CONTROL_HDMI_SBIT_SEL3_LSB) <= sbit_sel3;
    regs_read_arr(17)(REG_CONTROL_HDMI_SBIT_SEL4_MSB downto REG_CONTROL_HDMI_SBIT_SEL4_LSB) <= sbit_sel4;
    regs_read_arr(17)(REG_CONTROL_HDMI_SBIT_SEL5_MSB downto REG_CONTROL_HDMI_SBIT_SEL5_LSB) <= sbit_sel5;
    regs_read_arr(18)(REG_CONTROL_HDMI_SBIT_SEL6_MSB downto REG_CONTROL_HDMI_SBIT_SEL6_LSB) <= sbit_sel6;
    regs_read_arr(18)(REG_CONTROL_HDMI_SBIT_SEL7_MSB downto REG_CONTROL_HDMI_SBIT_SEL7_LSB) <= sbit_sel7;
    regs_read_arr(18)(REG_CONTROL_HDMI_SBIT_MODE0_MSB downto REG_CONTROL_HDMI_SBIT_MODE0_LSB) <= sbit_mode0;
    regs_read_arr(18)(REG_CONTROL_HDMI_SBIT_MODE1_MSB downto REG_CONTROL_HDMI_SBIT_MODE1_LSB) <= sbit_mode1;
    regs_read_arr(18)(REG_CONTROL_HDMI_SBIT_MODE2_MSB downto REG_CONTROL_HDMI_SBIT_MODE2_LSB) <= sbit_mode2;
    regs_read_arr(18)(REG_CONTROL_HDMI_SBIT_MODE3_MSB downto REG_CONTROL_HDMI_SBIT_MODE3_LSB) <= sbit_mode3;
    regs_read_arr(18)(REG_CONTROL_HDMI_SBIT_MODE4_MSB downto REG_CONTROL_HDMI_SBIT_MODE4_LSB) <= sbit_mode4;
    regs_read_arr(18)(REG_CONTROL_HDMI_SBIT_MODE5_MSB downto REG_CONTROL_HDMI_SBIT_MODE5_LSB) <= sbit_mode5;
    regs_read_arr(18)(REG_CONTROL_HDMI_SBIT_MODE6_MSB downto REG_CONTROL_HDMI_SBIT_MODE6_LSB) <= sbit_mode6;
    regs_read_arr(18)(REG_CONTROL_HDMI_SBIT_MODE7_MSB downto REG_CONTROL_HDMI_SBIT_MODE7_LSB) <= sbit_mode7;
    regs_read_arr(20)(REG_CONTROL_CNT_SNAP_DISABLE_BIT) <= cnt_snap_disable;
    regs_read_arr(21)(REG_CONTROL_DNA_DNA_LSBS_MSB downto REG_CONTROL_DNA_DNA_LSBS_LSB) <= dna(31 downto 0);
    regs_read_arr(22)(REG_CONTROL_DNA_DNA_MSBS_MSB downto REG_CONTROL_DNA_DNA_MSBS_LSB) <= dna(56 downto 32);
    regs_read_arr(23)(REG_CONTROL_UPTIME_MSB downto REG_CONTROL_UPTIME_LSB) <= std_logic_vector(uptime);
    regs_read_arr(24)(REG_CONTROL_USR_ACCESS_MSB downto REG_CONTROL_USR_ACCESS_LSB) <= usr_access;
    regs_read_arr(25)(REG_CONTROL_HOG_GLOBAL_DATE_MSB downto REG_CONTROL_HOG_GLOBAL_DATE_LSB) <= GLOBAL_DATE;
    regs_read_arr(26)(REG_CONTROL_HOG_GLOBAL_TIME_MSB downto REG_CONTROL_HOG_GLOBAL_TIME_LSB) <= GLOBAL_TIME;
    regs_read_arr(27)(REG_CONTROL_HOG_GLOBAL_VER_MSB downto REG_CONTROL_HOG_GLOBAL_VER_LSB) <= GLOBAL_VER;
    regs_read_arr(28)(REG_CONTROL_HOG_GLOBAL_SHA_MSB downto REG_CONTROL_HOG_GLOBAL_SHA_LSB) <= GLOBAL_SHA;
    regs_read_arr(29)(REG_CONTROL_HOG_TOP_SHA_MSB downto REG_CONTROL_HOG_TOP_SHA_LSB) <= TOP_SHA;
    regs_read_arr(30)(REG_CONTROL_HOG_TOP_VER_MSB downto REG_CONTROL_HOG_TOP_VER_LSB) <= TOP_VER;
    regs_read_arr(31)(REG_CONTROL_HOG_HOG_SHA_MSB downto REG_CONTROL_HOG_HOG_SHA_LSB) <= HOG_SHA;
    regs_read_arr(32)(REG_CONTROL_HOG_HOG_VER_MSB downto REG_CONTROL_HOG_HOG_VER_LSB) <= HOG_VER;
    regs_read_arr(33)(REG_CONTROL_HOG_OH_SHA_MSB downto REG_CONTROL_HOG_OH_SHA_LSB) <= OPTOHYBRID_SHA;
    regs_read_arr(34)(REG_CONTROL_HOG_OH_VER_MSB downto REG_CONTROL_HOG_OH_VER_LSB) <= OPTOHYBRID_VER;
    regs_read_arr(35)(REG_CONTROL_HOG_FLAVOUR_MSB downto REG_CONTROL_HOG_FLAVOUR_LSB) <= std_logic_vector(to_unsigned(FLAVOUR,32));
    regs_read_arr(36)(REG_CONTROL_TMR_TTC_TMR_ERR_CNT_MSB downto REG_CONTROL_TMR_TTC_TMR_ERR_CNT_LSB) <= ttc_tmr_err_cnt;
    regs_read_arr(37)(REG_CONTROL_TMR_IPB_SWITCH_TMR_ERR_CNT_MSB downto REG_CONTROL_TMR_IPB_SWITCH_TMR_ERR_CNT_LSB) <= ipb_switch_tmr_err_cnt;
    regs_read_arr(38)(REG_CONTROL_TMR_IPB_SLAVE_TMR_ERR_CNT_MSB downto REG_CONTROL_TMR_IPB_SLAVE_TMR_ERR_CNT_LSB) <= ipb_slave_tmr_err_cnt;

    -- Connect write signals
    loopback <= regs_write_arr(0)(REG_CONTROL_LOOPBACK_DATA_MSB downto REG_CONTROL_LOOPBACK_DATA_LSB);
    sem_inject_address(31 downto 0) <= regs_write_arr(4)(REG_CONTROL_SEM_INJ_ADDR_LSBS_MSB downto REG_CONTROL_SEM_INJ_ADDR_LSBS_LSB);
    sem_inject_address(39 downto 32) <= regs_write_arr(5)(REG_CONTROL_SEM_INJ_ADDR_MSBS_MSB downto REG_CONTROL_SEM_INJ_ADDR_MSBS_LSB);
    vfat_reset(11 downto 0) <= regs_write_arr(7)(REG_CONTROL_VFAT_RESET_MSB downto REG_CONTROL_VFAT_RESET_LSB);
    ttc_bxn_offset <= regs_write_arr(13)(REG_CONTROL_TTC_BXN_OFFSET_MSB downto REG_CONTROL_TTC_BXN_OFFSET_LSB);
    sbit_sel0 <= regs_write_arr(17)(REG_CONTROL_HDMI_SBIT_SEL0_MSB downto REG_CONTROL_HDMI_SBIT_SEL0_LSB);
    sbit_sel1 <= regs_write_arr(17)(REG_CONTROL_HDMI_SBIT_SEL1_MSB downto REG_CONTROL_HDMI_SBIT_SEL1_LSB);
    sbit_sel2 <= regs_write_arr(17)(REG_CONTROL_HDMI_SBIT_SEL2_MSB downto REG_CONTROL_HDMI_SBIT_SEL2_LSB);
    sbit_sel3 <= regs_write_arr(17)(REG_CONTROL_HDMI_SBIT_SEL3_MSB downto REG_CONTROL_HDMI_SBIT_SEL3_LSB);
    sbit_sel4 <= regs_write_arr(17)(REG_CONTROL_HDMI_SBIT_SEL4_MSB downto REG_CONTROL_HDMI_SBIT_SEL4_LSB);
    sbit_sel5 <= regs_write_arr(17)(REG_CONTROL_HDMI_SBIT_SEL5_MSB downto REG_CONTROL_HDMI_SBIT_SEL5_LSB);
    sbit_sel6 <= regs_write_arr(18)(REG_CONTROL_HDMI_SBIT_SEL6_MSB downto REG_CONTROL_HDMI_SBIT_SEL6_LSB);
    sbit_sel7 <= regs_write_arr(18)(REG_CONTROL_HDMI_SBIT_SEL7_MSB downto REG_CONTROL_HDMI_SBIT_SEL7_LSB);
    sbit_mode0 <= regs_write_arr(18)(REG_CONTROL_HDMI_SBIT_MODE0_MSB downto REG_CONTROL_HDMI_SBIT_MODE0_LSB);
    sbit_mode1 <= regs_write_arr(18)(REG_CONTROL_HDMI_SBIT_MODE1_MSB downto REG_CONTROL_HDMI_SBIT_MODE1_LSB);
    sbit_mode2 <= regs_write_arr(18)(REG_CONTROL_HDMI_SBIT_MODE2_MSB downto REG_CONTROL_HDMI_SBIT_MODE2_LSB);
    sbit_mode3 <= regs_write_arr(18)(REG_CONTROL_HDMI_SBIT_MODE3_MSB downto REG_CONTROL_HDMI_SBIT_MODE3_LSB);
    sbit_mode4 <= regs_write_arr(18)(REG_CONTROL_HDMI_SBIT_MODE4_MSB downto REG_CONTROL_HDMI_SBIT_MODE4_LSB);
    sbit_mode5 <= regs_write_arr(18)(REG_CONTROL_HDMI_SBIT_MODE5_MSB downto REG_CONTROL_HDMI_SBIT_MODE5_LSB);
    sbit_mode6 <= regs_write_arr(18)(REG_CONTROL_HDMI_SBIT_MODE6_MSB downto REG_CONTROL_HDMI_SBIT_MODE6_LSB);
    sbit_mode7 <= regs_write_arr(18)(REG_CONTROL_HDMI_SBIT_MODE7_MSB downto REG_CONTROL_HDMI_SBIT_MODE7_LSB);
    cnt_snap_disable <= regs_write_arr(20)(REG_CONTROL_CNT_SNAP_DISABLE_BIT);

    -- Connect write pulse signals
    sem_inject_strobe <= regs_write_pulse_arr(3);
    cnt_snap_pulse <= regs_write_pulse_arr(19);
    tmr_cnt_reset <= regs_write_pulse_arr(39);
    tmr_err_inj <= regs_write_pulse_arr(40);

    -- Connect write done signals

    -- Connect read pulse signals

    -- Connect counter instances

    COUNTER_CONTROL_SEM_CNT_SEM_CRITICAL : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 16
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => reset,
        en_i      => sem_uncorrectable_pulse,
        snap_i    => cnt_snap,
        count_o   => cnt_sem_uncorrectable
    );


    COUNTER_CONTROL_SEM_CNT_SEM_CORRECTION : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 16
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => reset,
        en_i      => sem_correction_pulse,
        snap_i    => cnt_snap,
        count_o   => cnt_sem_correction
    );


    COUNTER_CONTROL_SEM_CNT_SEM_INJECTIONS : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 16
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => reset,
        en_i      => sem_injection,
        snap_i    => cnt_snap,
        count_o   => cnt_sem_injection
    );


    COUNTER_CONTROL_TTC_BX0_CNT_LOCAL : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 24
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset,
        en_i      => bx0_local,
        snap_i    => cnt_snap,
        count_o   => cnt_bx0_lcl
    );


    COUNTER_CONTROL_TTC_BX0_CNT_TTC : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 24
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset,
        en_i      => ttc_i.bc0,
        snap_i    => cnt_snap,
        count_o   => cnt_bx0_rxd
    );


    COUNTER_CONTROL_TTC_L1A_CNT : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 24
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset,
        en_i      => ttc_i.l1a,
        snap_i    => cnt_snap,
        count_o   => cnt_l1a
    );


    COUNTER_CONTROL_TTC_BXN_SYNC_ERR_CNT : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 16
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset,
        en_i      => ttc_bxn_sync_err,
        snap_i    => cnt_snap,
        count_o   => cnt_bxn_sync_err
    );


    COUNTER_CONTROL_TTC_BX0_SYNC_ERR_CNT : entity work.counter_snap_tmr
    generic map (
        g_COUNTER_WIDTH  => 16
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => cnt_reset,
        en_i      => ttc_bx0_sync_err,
        snap_i    => cnt_snap,
        count_o   => cnt_bx0_sync_err
    );


    COUNTER_CONTROL_TMR_TTC_TMR_ERR_CNT : entity work.counter
    generic map (
        g_COUNTER_WIDTH  => 16
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => reset or tmr_cnt_reset,
        en_i      => ttc_tmr_err,
        count_o   => ttc_tmr_err_cnt
    );


    COUNTER_CONTROL_TMR_IPB_SWITCH_TMR_ERR_CNT : entity work.counter
    generic map (
        g_COUNTER_WIDTH  => 16
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => reset or tmr_cnt_reset,
        en_i      => ipb_switch_tmr_err,
        count_o   => ipb_switch_tmr_err_cnt
    );


    COUNTER_CONTROL_TMR_IPB_SLAVE_TMR_ERR_CNT : entity work.counter
    generic map (
        g_COUNTER_WIDTH  => 16
    )
    port map (
        ref_clk_i => clocks.clk40,
        reset_i   => reset or tmr_cnt_reset,
        en_i      => ipb_slave_tmr_err,
        count_o   => ipb_slave_tmr_err_cnt
    );


    -- Connect rate instances

    -- Connect read ready signals

    -- Defaults
    regs_defaults(0)(REG_CONTROL_LOOPBACK_DATA_MSB downto REG_CONTROL_LOOPBACK_DATA_LSB) <= REG_CONTROL_LOOPBACK_DATA_DEFAULT;
    regs_defaults(4)(REG_CONTROL_SEM_INJ_ADDR_LSBS_MSB downto REG_CONTROL_SEM_INJ_ADDR_LSBS_LSB) <= REG_CONTROL_SEM_INJ_ADDR_LSBS_DEFAULT;
    regs_defaults(5)(REG_CONTROL_SEM_INJ_ADDR_MSBS_MSB downto REG_CONTROL_SEM_INJ_ADDR_MSBS_LSB) <= REG_CONTROL_SEM_INJ_ADDR_MSBS_DEFAULT;
    regs_defaults(7)(REG_CONTROL_VFAT_RESET_MSB downto REG_CONTROL_VFAT_RESET_LSB) <= REG_CONTROL_VFAT_RESET_DEFAULT;
    regs_defaults(13)(REG_CONTROL_TTC_BXN_OFFSET_MSB downto REG_CONTROL_TTC_BXN_OFFSET_LSB) <= REG_CONTROL_TTC_BXN_OFFSET_DEFAULT;
    regs_defaults(17)(REG_CONTROL_HDMI_SBIT_SEL0_MSB downto REG_CONTROL_HDMI_SBIT_SEL0_LSB) <= REG_CONTROL_HDMI_SBIT_SEL0_DEFAULT;
    regs_defaults(17)(REG_CONTROL_HDMI_SBIT_SEL1_MSB downto REG_CONTROL_HDMI_SBIT_SEL1_LSB) <= REG_CONTROL_HDMI_SBIT_SEL1_DEFAULT;
    regs_defaults(17)(REG_CONTROL_HDMI_SBIT_SEL2_MSB downto REG_CONTROL_HDMI_SBIT_SEL2_LSB) <= REG_CONTROL_HDMI_SBIT_SEL2_DEFAULT;
    regs_defaults(17)(REG_CONTROL_HDMI_SBIT_SEL3_MSB downto REG_CONTROL_HDMI_SBIT_SEL3_LSB) <= REG_CONTROL_HDMI_SBIT_SEL3_DEFAULT;
    regs_defaults(17)(REG_CONTROL_HDMI_SBIT_SEL4_MSB downto REG_CONTROL_HDMI_SBIT_SEL4_LSB) <= REG_CONTROL_HDMI_SBIT_SEL4_DEFAULT;
    regs_defaults(17)(REG_CONTROL_HDMI_SBIT_SEL5_MSB downto REG_CONTROL_HDMI_SBIT_SEL5_LSB) <= REG_CONTROL_HDMI_SBIT_SEL5_DEFAULT;
    regs_defaults(18)(REG_CONTROL_HDMI_SBIT_SEL6_MSB downto REG_CONTROL_HDMI_SBIT_SEL6_LSB) <= REG_CONTROL_HDMI_SBIT_SEL6_DEFAULT;
    regs_defaults(18)(REG_CONTROL_HDMI_SBIT_SEL7_MSB downto REG_CONTROL_HDMI_SBIT_SEL7_LSB) <= REG_CONTROL_HDMI_SBIT_SEL7_DEFAULT;
    regs_defaults(18)(REG_CONTROL_HDMI_SBIT_MODE0_MSB downto REG_CONTROL_HDMI_SBIT_MODE0_LSB) <= REG_CONTROL_HDMI_SBIT_MODE0_DEFAULT;
    regs_defaults(18)(REG_CONTROL_HDMI_SBIT_MODE1_MSB downto REG_CONTROL_HDMI_SBIT_MODE1_LSB) <= REG_CONTROL_HDMI_SBIT_MODE1_DEFAULT;
    regs_defaults(18)(REG_CONTROL_HDMI_SBIT_MODE2_MSB downto REG_CONTROL_HDMI_SBIT_MODE2_LSB) <= REG_CONTROL_HDMI_SBIT_MODE2_DEFAULT;
    regs_defaults(18)(REG_CONTROL_HDMI_SBIT_MODE3_MSB downto REG_CONTROL_HDMI_SBIT_MODE3_LSB) <= REG_CONTROL_HDMI_SBIT_MODE3_DEFAULT;
    regs_defaults(18)(REG_CONTROL_HDMI_SBIT_MODE4_MSB downto REG_CONTROL_HDMI_SBIT_MODE4_LSB) <= REG_CONTROL_HDMI_SBIT_MODE4_DEFAULT;
    regs_defaults(18)(REG_CONTROL_HDMI_SBIT_MODE5_MSB downto REG_CONTROL_HDMI_SBIT_MODE5_LSB) <= REG_CONTROL_HDMI_SBIT_MODE5_DEFAULT;
    regs_defaults(18)(REG_CONTROL_HDMI_SBIT_MODE6_MSB downto REG_CONTROL_HDMI_SBIT_MODE6_LSB) <= REG_CONTROL_HDMI_SBIT_MODE6_DEFAULT;
    regs_defaults(18)(REG_CONTROL_HDMI_SBIT_MODE7_MSB downto REG_CONTROL_HDMI_SBIT_MODE7_LSB) <= REG_CONTROL_HDMI_SBIT_MODE7_DEFAULT;
    regs_defaults(20)(REG_CONTROL_CNT_SNAP_DISABLE_BIT) <= REG_CONTROL_CNT_SNAP_DISABLE_DEFAULT;

    -- Define writable regs
    regs_writable_arr(0) <= '1';
    regs_writable_arr(4) <= '1';
    regs_writable_arr(5) <= '1';
    regs_writable_arr(7) <= '1';
    regs_writable_arr(13) <= '1';
    regs_writable_arr(17) <= '1';
    regs_writable_arr(18) <= '1';
    regs_writable_arr(20) <= '1';

  --==== Registers end ============================================================================

end Behavioral;
