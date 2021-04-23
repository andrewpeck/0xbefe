----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid v3 Firmware -- Control
-- A. Peck
----------------------------------------------------------------------------------
-- 2017/07/25 -- Initial. Wrapper around OH control modules
-- 2017/07/25 -- Clear many synthesis warnings from module
-- 2017/11/14 -- Overhaul with XML derived controls
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

    clocks  : in clocks_t;
    ttc_i   : in ttc_t;
    reset : in std_logic;

    ipb_mosi_i : in  ipb_wbus;
    ipb_miso_o : out ipb_rbus;

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

  --== SEM ==--

  signal sem_correction : std_logic;
  signal sem_critical   : std_logic;
  --== Sbits ==--

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

  ge11_usr_access: if (ge11=1) generate
    usr_access_inst : USR_ACCESS_VIRTEX6 port map (
      CFGCLK    => open,                  -- Not utilized in the static use case in this application note
      DATA      => usr_access,            -- 32-bit output Configuration Data output
      DATAVALID => open                   -- Not utilized in the static use case in this application note
      );
  end generate;
  ge21_usr_access: if (ge21=1) generate
    usr_access_inst : USR_ACCESSE2 port map (
      CFGCLK    => open,                  -- Not utilized in the static use case in this application note
      DATA      => usr_access,            -- 32-bit output Configuration Data output
      DATAVALID => open                   -- Not utilized in the static use case in this application note
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
      bxn_sync_err => ttc_bxn_sync_err

      );

  --------------------------------------------------------------------------------------------------------------------
  -- SEU Monitoring
  --------------------------------------------------------------------------------------------------------------------

  sem_mon_inst : entity work.sem_mon
    port map(
      clk_i            => clocks.clk40,
      heartbeat_o      => open,
      initialization_o => open,
      observation_o    => open,
      correction_o     => sem_correction,
      classification_o => open,
      injection_o      => open,
      essential_o      => open,
      uncorrectable_o  => sem_critical
      );

  --===============================================================================================
  -- (this section is generated by <optohybrid_top>/tools/generate_registers.py -- do not edit)
  --==== Registers begin ==========================================================================
  --==== Registers end ============================================================================

end Behavioral;
