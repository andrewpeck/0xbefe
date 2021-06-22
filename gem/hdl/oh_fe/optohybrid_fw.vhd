---------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid Firmware -- Top Logic
-- E. Juska, T. Lenzi, A. Peck, L. Petre
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.types_pkg.all;
use work.ipbus_pkg.all;
use work.hardware_pkg.all;
use work.tmr_pkg.all;
use work.cluster_pkg.all;

library unisim;
use unisim.vcomponents.all;

entity optohybrid_fw is
  generic (

    -- turn off to disable the MGTs (for simulation and such)
    GEN_TRIG_PHY : boolean := true;

    -- these generics get set by hog at synthesis
    GLOBAL_DATE : std_logic_vector (31 downto 0) := x"00000000";
    GLOBAL_TIME : std_logic_vector (31 downto 0) := x"00000000";
    GLOBAL_VER  : std_logic_vector (31 downto 0) := x"00000000";
    GLOBAL_SHA  : std_logic_vector (31 downto 0) := x"00000000";

    TOP_SHA : std_logic_vector (31 downto 0) := x"00000000";
    TOP_VER : std_logic_vector (31 downto 0) := x"00000000";

    XML_VER : std_logic_vector (31 downto 0) := x"00000000";
    XML_SHA : std_logic_vector (31 downto 0) := x"00000000";

    HOG_SHA : std_logic_vector (31 downto 0) := x"00000000";
    HOG_VER : std_logic_vector (31 downto 0) := x"00000000";

    OPTOHYBRID_VER : std_logic_vector (31 downto 0) := x"00000000";
    OPTOHYBRID_SHA : std_logic_vector (31 downto 0) := x"00000000";

    CON_VER : std_logic_vector (31 downto 0) := x"00000000";
    CON_SHA : std_logic_vector (31 downto 0) := x"00000000";

    FLAVOUR : integer := 0
    );
  port(

    --------------------------------------------------------------------------------
    -- Clocking
    --------------------------------------------------------------------------------
    clock_p : in std_logic;
    clock_n : in std_logic;

    --------------------------------------------------------------------------------
    -- GBT
    --------------------------------------------------------------------------------
    elink_i_p : in std_logic;
    elink_i_n : in std_logic;

    elink_o_p : out std_logic;
    elink_o_n : out std_logic;

    gbt_trig_o_p : out std_logic_vector (MXELINKS-1 downto 0);
    gbt_trig_o_n : out std_logic_vector (MXELINKS-1 downto 0);

    -- only 1 connected in GE11, 2 in GE21
    gbt_txready_i : in std_logic_vector (MXREADY-1 downto 0);
    gbt_rxvalid_i : in std_logic_vector (MXREADY-1 downto 0);
    gbt_rxready_i : in std_logic_vector (MXREADY-1 downto 0);

    --------------------------------------------------------------------------------
    -- GE11 Signals
    --------------------------------------------------------------------------------
    ext_sbits_o : out std_logic_vector (MXEXT-1 downto 0);
    ext_reset_o : out std_logic_vector (MXRESET-1 downto 0);
    adc_vp      : in  std_logic_vector (MXADC-1 downto 0);
    adc_vn      : in  std_logic_vector (MXADC-1 downto 0);

    --------------------------------------------------------------------------------
    -- GE21 Signals
    --------------------------------------------------------------------------------

    --gbt_txvalid_o  : out   std_logic_vector (MXREADY*GE21-1 downto 0);
    master_slave   : in    std_logic_vector (1*GE21-1 downto 0);
    master_slave_p : inout std_logic_vector (5*GE21-1 downto 0);
    master_slave_n : inout std_logic_vector (5*GE21-1 downto 0);
    vtrx_mabs_i    : in    std_logic_vector (1*GE21 downto 0);

    --------------------------------------------------------------------------------
    -- LEDs
    --------------------------------------------------------------------------------
    led_o : out std_logic_vector (MXLED-1 downto 0);

    --------------------------------------------------------------------------------
    -- MGTS
    --------------------------------------------------------------------------------
    mgt_clk_p_i : in std_logic_vector (1 downto 0);
    mgt_clk_n_i : in std_logic_vector (1 downto 0);

    mgt_tx_p_o : out std_logic_vector(3 downto 0);
    mgt_tx_n_o : out std_logic_vector(3 downto 0);

    --------------------------------------------------------------------------------
    -- VFAT Trigger Data
    --------------------------------------------------------------------------------
    vfat_sot_p : in std_logic_vector (NUM_VFATS-1 downto 0);
    vfat_sot_n : in std_logic_vector (NUM_VFATS-1 downto 0);

    vfat_sbits_p : in std_logic_vector ((NUM_VFATS*8)-1 downto 0);
    vfat_sbits_n : in std_logic_vector ((NUM_VFATS*8)-1 downto 0)

    );
end optohybrid_fw;

architecture Behavioral of optohybrid_fw is

  -- Trigger Data Packets
  signal fiber_packets : t_fiber_packet_array (NUM_OPTICAL_PACKETS-1 downto 0);
  signal elink_packets : t_elink_packet_array (NUM_ELINK_PACKETS-1 downto 0);
  signal fiber_kchars  : t_std10_array (NUM_OPTICAL_PACKETS-1 downto 0);

  -- Clusters
  signal sbit_overflow : std_logic;
  signal cluster_count : std_logic_vector (10 downto 0);
  signal active_vfats  : std_logic_vector (NUM_VFATS-1 downto 0);
  signal sbit_clusters : sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);

  -- Global signals
  signal idlyrdy     : std_logic;
  signal mmcm_locked : std_logic;
  signal clocks      : clocks_t;
  signal ttc         : ttc_t;

  signal vtrx_mabs : std_logic_vector (1 downto 0);

  -- GBT Link
  signal gbt_link_ready       : std_logic;
  signal gbt_link_error       : std_logic;
  signal gbt_request_received : std_logic;

  signal mgts_ready : std_logic;
  signal pll_lock   : std_logic;
  signal txfsm_done : std_logic;

  signal trigger_reset : std_logic;
  signal system_reset  : std_logic;
  signal cnt_snap      : std_logic;

  signal trigger_prbs_en  : std_logic;

  attribute MAX_FANOUT                 : string;
  attribute MAX_FANOUT of system_reset : signal is "50";

  -- TTC
  signal bxn_counter : std_logic_vector(11 downto 0);

  -- Outputs
  signal ext_sbits : std_logic_vector (7 downto 0);
  signal led       : std_logic_vector (15 downto 0);
  signal ext_reset : std_logic_vector (11 downto 0);

  signal adc_vp_int : std_logic;
  signal adc_vn_int : std_logic;

  --------------------------------------------------------------------------------
  -- Wishbone
  --------------------------------------------------------------------------------

  -- Master
  signal ipb_mosi_gbt : ipb_wbus;
  signal ipb_miso_gbt : ipb_rbus;

  -- Master
  signal ipb_mosi_masters : ipb_wbus_array (WB_MASTERS-1 downto 0);
  signal ipb_miso_masters : ipb_rbus_array (WB_MASTERS-1 downto 0);

  -- Slaves
  signal ipb_mosi_slaves : ipb_wbus_array (WB_SLAVES-1 downto 0);
  signal ipb_miso_slaves : ipb_rbus_array (WB_SLAVES-1 downto 0);

  signal trigger_data_formatter_tmr_err : std_logic := '0';
  signal ipb_switch_tmr_err             : std_logic := '0';

begin

  assert_fpga_type :
  if (FPGA_TYPE /= "V6" and FPGA_TYPE /= "A7") generate
    assert false report "Unknown FPGA TYPE" severity error;
  end generate assert_fpga_type;

  gbt_request_received <= ipb_mosi_gbt.ipb_strobe;
  ext_reset_o          <= ext_reset(MXRESET-1 downto 0);
  ext_sbits_o          <= ext_sbits (MXEXT-1 downto 0);
  led_o                <= led (MXLED-1 downto 0);

  --------------------------------------------------------------------------------
  -- Clocking
  --------------------------------------------------------------------------------

  clocking_inst : entity work.clocking
    port map(
      clock_p       => clock_p,
      clock_n       => clock_n,
      mmcm_locked_o => mmcm_locked,
      clocks_o      => clocks
      );

  --------------------------------------------------------------------------------
  -- Reset
  --------------------------------------------------------------------------------

  reset_inst : entity work.startup_reset
    port map (
      clock_i        => clocks.clk40,
      mmcms_locked_i => mmcm_locked,
      gbt_rxready_i  => gbt_rxready_i(0),
      gbt_rxvalid_i  => gbt_rxvalid_i(0),
      gbt_txready_i  => gbt_txready_i(0),
      idlyrdy_i      => idlyrdy,
      reset_o        => system_reset
      );

  --------------------------------------------------------------------------------
  -- GBT
  --------------------------------------------------------------------------------

  gbt_inst : entity work.gbt
    port map(
      -- clock and reset
      reset_i => system_reset,
      clocks  => clocks,

      -- wishbone
      ipb_mosi_o => ipb_mosi_gbt,
      ipb_miso_i => ipb_miso_gbt,

      -- wishbone slave
      ipb_mosi_i  => ipb_mosi_slaves (IPB_SLAVE.GBT),
      ipb_miso_o  => ipb_miso_slaves (IPB_SLAVE.GBT),
      ipb_reset_i => system_reset,

      cnt_snap => cnt_snap,

      -- GBT Status
      gbt_rxready_i    => gbt_rxready_i(0),
      gbt_rxvalid_i    => gbt_rxvalid_i(0),
      gbt_txready_i    => gbt_txready_i(0),
      gbt_link_error_o => gbt_link_error,
      gbt_link_ready_o => gbt_link_ready,

      -- elinks
      elink_i_p => elink_i_p,
      elink_i_n => elink_i_n,
      elink_o_p => elink_o_p,
      elink_o_n => elink_o_n,

      -- decoded TTC
      ttc_o => ttc
      );

  --------------------------------------------------------------------------------
  -- Wishbone
  --------------------------------------------------------------------------------

  -- This module is the Wishbone switch which redirects requests from the masters to the slaves.

  ipb_mosi_masters(0) <= ipb_mosi_gbt;
  ipb_miso_gbt        <= ipb_miso_masters(0);

  ipb_switch_inst : entity work.ipb_switch_tmr
    generic map (EN_TMR_IPB_SWITCH)
    port map(
      clock_i => clocks.clk40,
      reset_i => system_reset,

      -- connect to master
      mosi_masters => ipb_mosi_masters,
      miso_masters => ipb_miso_masters,

      -- connect to slaves
      mosi_slaves => ipb_mosi_slaves,
      miso_slaves => ipb_miso_slaves,

      tmr_err_o => ipb_switch_tmr_err
      );

  --------------------------------------------------------------------------------
  -- ADC
  --------------------------------------------------------------------------------

  adc_vp_int <= if_then_else (GE11 = 1, adc_vp(0), '1');
  adc_vn_int <= if_then_else (GE11 = 1, adc_vn(0), '0');

  adc_inst : entity work.adc port map(
    clock_i => clocks.clk40,
    reset_i => system_reset,

    cnt_snap => cnt_snap,

    ipb_mosi_i  => ipb_mosi_slaves (IPB_SLAVE.ADC),
    ipb_miso_o  => ipb_miso_slaves (IPB_SLAVE.ADC),
    ipb_reset_i => system_reset,
    ipb_clk_i   => clocks.clk40,

    adc_vp => adc_vp_int,
    adc_vn => adc_vn_int
    );

  --------------------------------------------------------------------------------
  -- Control
  --------------------------------------------------------------------------------

  control_inst : entity work.control
    generic map (
      GLOBAL_DATE    => GLOBAL_DATE,
      GLOBAL_TIME    => GLOBAL_TIME,
      GLOBAL_VER     => GLOBAL_VER,
      GLOBAL_SHA     => GLOBAL_SHA,
      TOP_SHA        => TOP_SHA,
      TOP_VER        => TOP_VER,
      HOG_SHA        => HOG_SHA,
      XML_VER        => XML_VER,
      XML_SHA        => XML_SHA,
      HOG_VER        => HOG_VER,
      OPTOHYBRID_VER => OPTOHYBRID_VER,
      OPTOHYBRID_SHA => OPTOHYBRID_SHA,
      FLAVOUR        => FLAVOUR)
    port map (

      -- wishbone
      ipb_mosi_i => ipb_mosi_slaves (IPB_SLAVE.CONTROL),
      ipb_miso_o => ipb_miso_slaves (IPB_SLAVE.CONTROL),

      ipb_switch_tmr_err => ipb_switch_tmr_err,

      -- clock and reset
      clocks => clocks,
      reset  => system_reset,
      ttc_i  => ttc,

      -- to drive LED controller only
      mgts_ready => mgts_ready,
      pll_lock   => pll_lock,
      txfsm_done => txfsm_done,

      -- status inputs --
      mmcms_locked_i => mmcm_locked,

      -- GBT status
      gbt_link_ready_i       => gbt_link_ready,
      gbt_rxready_i          => gbt_rxready_i(0),
      gbt_rxvalid_i          => gbt_rxvalid_i(0),
      gbt_txready_i          => gbt_txready_i(0),
      gbt_request_received_i => gbt_request_received,
      gbt_link_error_i       => gbt_link_error,

      -- Trigger
      active_vfats_i  => active_vfats,
      sbit_overflow_i => sbit_overflow,
      cluster_count_i => cluster_count,

      -- Outputs
      bxn_counter_o => bxn_counter,
      vfat_reset_o  => ext_reset,
      ext_sbits_o   => ext_sbits,
      led_o         => led,
      cnt_snap_o    => cnt_snap
      );

  --------------------------------------------------------------------------------
  -- Trigger & Sbits
  --------------------------------------------------------------------------------

  trigger_inst : entity work.trigger
    port map (

      -- wishbone
      ipb_mosi_i => ipb_mosi_slaves(IPB_SLAVE.TRIG),
      ipb_miso_o => ipb_miso_slaves(IPB_SLAVE.TRIG),

      -- clock and reset
      clocks  => clocks,
      reset_i => system_reset,

      -- ttc
      bxn_counter_i => bxn_counter,
      ttc           => ttc,

      cnt_snap               => cnt_snap,
      trig_formatter_tmr_err => trigger_data_formatter_tmr_err,

      -- sbits inputs
      vfat_sbits_p => vfat_sbits_p,
      vfat_sbits_n => vfat_sbits_n,
      vfat_sot_p   => vfat_sot_p,
      vfat_sot_n   => vfat_sot_n,

      -- cluster finding outputs
      sbit_clusters_o => sbit_clusters,
      cluster_count_o => cluster_count,
      overflow_o      => sbit_overflow,
      active_vfats_o  => active_vfats,

      --
      trigger_prbs_en_o => trigger_prbs_en
      );

  --------------------------------------------------------------------------------
  -- Trigger Data Formatter
  --------------------------------------------------------------------------------


  trigger_data_formatter_tmr : if (true) generate
    signal cluster_count : t_std11_array (2 downto 0);
    signal overflow      : std_logic_vector (2 downto 0);

    type t_fiber_packets_tmr is array (2 downto 0) of t_fiber_packet_array (NUM_OPTICAL_PACKETS-1 downto 0);
    type t_elink_packets_tmr is array (2 downto 0) of t_elink_packet_array (NUM_ELINK_PACKETS-1 downto 0);
    type t_fiber_kchars_tmr is array (2 downto 0) of t_std10_array (NUM_OPTICAL_PACKETS-1 downto 0);

    signal fiber_packets_tmr : t_fiber_packets_tmr;
    signal elink_packets_tmr : t_elink_packets_tmr;
    signal fiber_kchars_tmr  : t_fiber_kchars_tmr;

    attribute DONT_TOUCH                      : string;
    attribute DONT_TOUCH of fiber_packets_tmr : signal is "true";
    attribute DONT_TOUCH of elink_packets_tmr : signal is "true";
    attribute DONT_TOUCH of fiber_kchars_tmr  : signal is "true";


  begin

    formatter_loop : for I in 0 to 2*EN_TMR_TRIG_FORMATTER generate
    begin
      trigger_data_formatter_inst : entity work.trigger_data_formatter
        generic map (g_TMR_INST => I)
        port map (
          clocks          => clocks,
          reset_i         => system_reset,
          ttc_i           => ttc,
          prbs_en_i       => trigger_prbs_en,
          clusters_i      => sbit_clusters,
          overflow_i      => sbit_overflow,
          bxn_counter_i   => bxn_counter,
          error_i         => '0',
          fiber_packets_o => fiber_packets_tmr(I),
          fiber_kchars_o  => fiber_kchars_tmr(I),
          elink_packets_o => elink_packets_tmr(I)
          );
    end generate;

    tmr_gen : if (EN_TMR = 1) generate
      signal fiber_packets_tmr_err : std_logic_vector (NUM_OPTICAL_PACKETS-1 downto 0) := (others => '0');
      signal fiber_kchars_tmr_err  : std_logic_vector (NUM_OPTICAL_PACKETS-1 downto 0) := (others => '0');
      signal elink_packets_tmr_err : std_logic_vector (NUM_ELINK_PACKETS-1 downto 0)   := (others => '0');
    begin
      fiber_assign_loop : for I in 0 to NUM_OPTICAL_PACKETS-1 generate
        majority_err (fiber_packets(I), fiber_packets_tmr_err(I), fiber_packets_tmr(0)(I), fiber_packets_tmr(1)(I), fiber_packets_tmr(2)(I));
        majority_err (fiber_kchars(I), fiber_kchars_tmr_err(I), fiber_kchars_tmr(0)(I), fiber_kchars_tmr(1)(I), fiber_kchars_tmr(2)(I));
      end generate;
      elink_assign_loop : for I in 0 to NUM_ELINK_PACKETS-1 generate
        majority_err (elink_packets(I), elink_packets_tmr_err(I), elink_packets_tmr(0)(I), elink_packets_tmr(1)(I), elink_packets_tmr(2)(I));
      end generate;

      process (clocks.clk40) is
      begin
        if (rising_edge(clocks.clk40)) then
          trigger_data_formatter_tmr_err <= or_reduce(fiber_packets_tmr_err) or
                                            or_reduce(fiber_kchars_tmr_err) or
                                            or_reduce(elink_packets_tmr_err);
        end if;
      end process;

    end generate;


    notmr_gen : if (EN_TMR = 0) generate
      fiber_packets <= fiber_packets_tmr(0);
      elink_packets <= elink_packets_tmr(0);
      fiber_kchars  <= fiber_kchars_tmr(0);
    end generate;

  end generate;

  --------------------------------------------------------------------------------
  -- Trigger Link Physical Interface
  --------------------------------------------------------------------------------

  phygen : if (GEN_TRIG_PHY) generate
    trigger_data_phy_inst : entity work.trigger_data_phy
      port map (
        -- wishbone
        ipb_mosi_i      => ipb_mosi_slaves(IPB_SLAVE.MGT),
        ipb_miso_o      => ipb_miso_slaves(IPB_SLAVE.MGT),
        clocks          => clocks,
        reset_i         => system_reset,
        ipb_reset_i     => system_reset,
        trg_tx_p        => mgt_tx_p_o,
        trg_tx_n        => mgt_tx_n_o,
        refclk_p        => mgt_clk_p_i,
        refclk_n        => mgt_clk_n_i,
        gbt_trig_p      => gbt_trig_o_p,
        gbt_trig_n      => gbt_trig_o_n,
        fiber_packets_i => fiber_packets,
        fiber_kchars_i  => fiber_kchars,
        elink_packets_i => elink_packets,

        -- legacy phy ports
        clusters_i    => sbit_clusters,
        overflow_i    => sbit_overflow,
        bxn_counter_i => bxn_counter,
        bc0_i         => ttc.bc0,
        resync_i      => ttc.resync

        );
  end generate;

  --------------------------------------------------------------------------------
  -- IDELAYCTRL
  --------------------------------------------------------------------------------

  delayctrl_inst : IDELAYCTRL
    port map (
      RDY    => idlyrdy,
      REFCLK => clocks.clk200,
      RST    => not mmcm_locked
      );

end Behavioral;
