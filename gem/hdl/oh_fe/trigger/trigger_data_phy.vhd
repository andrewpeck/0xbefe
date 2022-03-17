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
use work.cluster_pkg.all;

entity trigger_data_phy is
  port(
    ----------------------------------------------------------------------------------------------------------------------
    -- Core
    ----------------------------------------------------------------------------------------------------------------------

    clocks           : in  clocks_t;
    reset_i          : in  std_logic;
    mgt_mmcm_reset_o : out std_logic_vector (3 downto 0);

    -- ipbus

    ipb_mosi_i  : in  ipb_wbus;
    ipb_miso_o  : out ipb_rbus;
    ipb_reset_i : in  std_logic;

    ----------------------------------------------------------------------------------------------------------------------
    -- Legacy Ports
    ----------------------------------------------------------------------------------------------------------------------

    overflow_i    : in std_logic;                       -- 1 bit gem has more than 8 clusters
    bxn_counter_i : in std_logic_vector (11 downto 0);  -- 12 bit bxn counter
    bc0_i         : in std_logic;                       -- 1  bit bx0 flag
    resync_i      : in std_logic;                       -- 1  bit bx0 flag

    ----------------------------------------------------------------------------------------------------------------------
    -- Physical
    ----------------------------------------------------------------------------------------------------------------------

    -- gtp/gtx
    trg_tx_n : out std_logic_vector(NUM_GT_TX-1 downto 0);
    trg_tx_p : out std_logic_vector(NUM_GT_TX-1 downto 0);

    -- refclk
    refclk_p : in std_logic_vector(NUM_GT_REFCLK-1 downto 0);
    refclk_n : in std_logic_vector(NUM_GT_REFCLK-1 downto 0);

    -- gbtx trigger data (ge21)
    gbt_trig_p : out std_logic_vector(MXELINKS-1 downto 0);
    gbt_trig_n : out std_logic_vector(MXELINKS-1 downto 0);

    ----------------------------------------------------------------------------------------------------------------------
    -- Data
    ----------------------------------------------------------------------------------------------------------------------

    fiber_kchars_i    : in t_std10_array (NUM_OPTICAL_PACKETS-1 downto 0);
    fiber_packets_i   : in t_fiber_packet_array (NUM_OPTICAL_PACKETS-1 downto 0);
    elink_packets_i   : in t_elink_packet_array (NUM_ELINK_PACKETS-1 downto 0);

    legacy_clusters_i : in t_std14_array (7 downto 0);
    legacy_overflow_i : in std_logic

    );
end trigger_data_phy;

architecture Behavioral of trigger_data_phy is

  constant NUM_GTS : integer := 4;

  signal ipb_slave_tmr_err : std_logic;

  signal strobe    : std_logic;         -- 200MHz strobe
  signal tx_usrclk : std_logic;         -- 200MHz userclk
  signal is_kchar  : t_std2_array (NUM_OPTICAL_PACKETS-1 downto 0);
  signal mgt_words : t_std16_array (NUM_OPTICAL_PACKETS-1 downto 0);

  constant c_LINK_FRAME_CNT_MAX : integer                                 := 4;
  signal link_frame_cnt         : integer range 0 to c_LINK_FRAME_CNT_MAX := 0;

  signal soft_reset_tx : std_logic                := '0';
  signal pll_lock      : std_logic;
  signal status        : mgt_status_array (3 downto 0);
  signal control       : mgt_control_array (3 downto 0);
  signal drp_i         : drp_i_array (3 downto 0) := (others => drp_i_null);
  signal drp_o         : drp_o_array (3 downto 0);

  ------ Register signals begin (this section is generated by <optohybrid_top>/tools/generate_registers.py -- do not edit)
    signal regs_read_arr        : t_std32_array(REG_MGT_NUM_REGS - 1 downto 0) := (others => (others => '0'));
    signal regs_write_arr       : t_std32_array(REG_MGT_NUM_REGS - 1 downto 0) := (others => (others => '0'));
    signal regs_addresses       : t_std32_array(REG_MGT_NUM_REGS - 1 downto 0) := (others => (others => '0'));
    signal regs_defaults        : t_std32_array(REG_MGT_NUM_REGS - 1 downto 0) := (others => (others => '0'));
    signal regs_read_pulse_arr  : std_logic_vector(REG_MGT_NUM_REGS - 1 downto 0) := (others => '0');
    signal regs_write_pulse_arr : std_logic_vector(REG_MGT_NUM_REGS - 1 downto 0) := (others => '0');
    signal regs_read_ready_arr  : std_logic_vector(REG_MGT_NUM_REGS - 1 downto 0) := (others => '1');
    signal regs_write_done_arr  : std_logic_vector(REG_MGT_NUM_REGS - 1 downto 0) := (others => '1');
    signal regs_writable_arr    : std_logic_vector(REG_MGT_NUM_REGS - 1 downto 0) := (others => '0');
  ------ Register signals end ----------------------------------------------

begin

  --------------------------------------------------------------------------------
  -- GE2/1 Copper Output
  --------------------------------------------------------------------------------

  ge21_elink_gen : if (GE21 = 1) and HAS_ELINK_OUTPUTS generate
    signal elink_packets : t_elink_packet_array (NUM_ELINK_PACKETS-1 downto 0);
  begin

    -- copy onto 40MHz clock, make sure it is stable... there might be a better
    -- (lower latency way to do this but at least this is safe)
    process (clocks.clk40)
    begin
      if (rising_edge(clocks.clk40)) then
        elink_packets <= elink_packets_i;
      end if;
    end process;

    elink_outputs : for I in 0 to (MXELINKS-1) generate
    begin
      to_gbt_ser_inst : entity work.to_gbt_ser
        port map (
          data_out_from_device  => elink_packets_i(0)(8*(I+1)-1 downto 8*I),
          data_out_to_pins_p(0) => gbt_trig_p(I),
          data_out_to_pins_n(0) => gbt_trig_n(I),
          clk_in                => clocks.clk160_0,
          clk_div_in            => clocks.clk40,
          io_reset              => reset_i
          );
    end generate;
  end generate;

  --------------------------------------------------------------------------------
  -- Optical Data Frames
  --------------------------------------------------------------------------------

  -- Create a 1 of n high signal synced to the slow clock, e.g.
  --             ______________                ____________
  -- clk40    __|              |______________|
  --             _____________________________
  -- r        __|                             |_____________
  --                ______________________________
  -- r_dly    ______|                             |_____________
  --             ___                           ___
  -- valid    __|   |_________________________|   |______
  --
  -- cnt        < 0 >< 1 >< 2 >< 3 >< 4 >< 5 >< 0>

  -- tx_usrclk <= clocks.clk200;

  -- clock_strobe_200_inst : entity work.clock_strobe
  --   port map (
  --     fast_clk_i => tx_usrclk,
  --     slow_clk_i => clocks.clk40,
  --     strobe_o   => strobe
  --     );

  -- process (tx_usrclk)
  -- begin
  --   if (rising_edge(tx_usrclk)) then
  --     if (strobe = '1') then
  --       link_frame_cnt <= 1;
  --     elsif (link_frame_cnt = c_LINK_FRAME_CNT_MAX) then
  --       link_frame_cnt <= 0;
  --     else
  --       link_frame_cnt <= link_frame_cnt + 1;
  --     end if;
  --   end if;
  -- end process;

  -- optical_outputs : for I in 0 to (NUM_OPTICAL_PACKETS-1) generate
  --   signal cnt : integer;
  -- begin
  --   cnt <= link_frame_cnt;
  --   process (tx_usrclk)
  --   begin
  --     if (rising_edge(tx_usrclk)) then
  --       mgt_words (I) <= fiber_packets_i(I)((cnt+1)*16-1 downto cnt*16);
  --       is_kchar  (I) <= fiber_kchars_i (I)((cnt+1)*2 -1 downto cnt*2);
  --     end if;
  --   end process;
  -- end generate;

  --------------------------------------------------------------------------------
  --
  --------------------------------------------------------------------------------

  -- optics_gen : if (NUM_OPTICAL_PACKETS > 0 and not USE_LEGACY_OPTICS) generate
  --   signal common_drp_i : drp_i_t;
  --   signal common_drp_o : drp_o_t;
  -- begin

  --   mgt_wrapper_inst : entity work.mgt_wrapper
  --     port map (

  --       refclk_in_p => refclk_p,
  --       refclk_in_n => refclk_n,

  --       sysclk_in => clocks.clk40,

  --       soft_reset_tx_in => '0',

  --       pll_lock_out => pll_lock,

  --       status_o  => status,
  --       control_i => control,

  --       txusrclk_in => clocks.clk200,

  --       txp_out => trg_tx_p,
  --       txn_out => trg_tx_n,

  --       drp_i => drp_i,
  --       drp_o => drp_o,

  --       common_drp_i => common_drp_i,
  --       common_drp_o => common_drp_o,

  --       mmcm_lock_i => clocks.locked,

  --       txcharisk_i(0) => is_kchar(0),
  --       txcharisk_i(1) => is_kchar(0),
  --       txcharisk_i(2) => is_kchar(NUM_OPTICAL_PACKETS-1),
  --       txcharisk_i(3) => is_kchar(NUM_OPTICAL_PACKETS-1),

  --       txdata_i(0) => mgt_words(0),
  --       txdata_i(1) => mgt_words(0),
  --       txdata_i(2) => mgt_words(NUM_OPTICAL_PACKETS-1),
  --       txdata_i(3) => mgt_words(NUM_OPTICAL_PACKETS-1)
  --       );

  -- end generate;

  --------------------------------------------------------------------------------
  -- Wrapper to generate the "Legacy" 3.2 Gbps format
  --------------------------------------------------------------------------------

  legacy_optics_gen : if (NUM_OPTICAL_PACKETS > 0 and USE_LEGACY_OPTICS) generate

    component gem_data_out
      generic (
        FPGA_TYPE_IS_VIRTEX6 : integer := 0;
        FPGA_TYPE_IS_ARTIX7  : integer := 1
        );
      port (
        trg_tx_n : out std_logic_vector (3 downto 0);
        trg_tx_p : out std_logic_vector (3 downto 0);

        refclk_n : in std_logic_vector (1 downto 0);
        refclk_p : in std_logic_vector (1 downto 0);

        tx_prbs_mode_0 : in std_logic_vector (2 downto 0);
        tx_prbs_mode_1 : in std_logic_vector (2 downto 0);
        tx_prbs_mode_2 : in std_logic_vector (2 downto 0);
        tx_prbs_mode_3 : in std_logic_vector (2 downto 0);

        loopback_mode_0 : in std_logic_vector (2 downto 0);
        loopback_mode_1 : in std_logic_vector (2 downto 0);
        loopback_mode_2 : in std_logic_vector (2 downto 0);
        loopback_mode_3 : in std_logic_vector (2 downto 0);

        gem_data      : in std_logic_vector (111 downto 0);  -- 56 bit gem data
        overflow_i    : in std_logic;                        -- 1 bit gem has more than 8 clusters
        bxn_counter_i : in std_logic_vector (11 downto 0);   -- 12 bit bxn counter
        bc0_i         : in std_logic;                        -- 1  bit bx0 flag
        resync_i      : in std_logic;                        -- 1  bit bx0 flag

        force_not_ready    : in std_logic;
        pll_reset_i        : in std_logic;
        mgt_reset_i        : in std_logic_vector(3 downto 0);
        gtxtest_start_i    : in std_logic;
        txreset_i          : in std_logic;
        mgt_realign_i      : in std_logic;
        txpowerdown_i      : in std_logic;
        txpowerdown_mode_i : in std_logic_vector (1 downto 0);
        txpllpowerdown_i   : in std_logic;

        clock_40  : in std_logic;
        clock_160 : in std_logic;
        clock_200 : in std_logic;

        ready_o      : out std_logic;
        pll_lock_o   : out std_logic;
        txfsm_done_o : out std_logic;

        reset_i : in std_logic
        );
    end component;

  begin

    gem_data_out_inst : gem_data_out
      generic map (
        FPGA_TYPE_IS_VIRTEX6 => GE11,
        FPGA_TYPE_IS_ARTIX7  => GE21
        )
      port map (

        refclk_p => refclk_p,           -- 160 MHz Reference Clock Positive
        refclk_n => refclk_n,           -- 160 MHz Reference Clock Negative

        clock_40  => clocks.clk40,      -- 40 MHz  Logic Clock
        clock_160 => clocks.clk160_0,   -- 160 MHz  Logic Clock
        clock_200 => clocks.clk200,     -- 200 MHz  Logic Clock

        bxn_counter_i => bxn_counter_i,
        bc0_i         => bc0_i,
        resync_i      => resync_i,

        -- this reset must be aligned to the data
        -- the phase of the data itself matters
        reset_i => reset_i,

        force_not_ready => '0',

        ready_o      => open,
        pll_lock_o   => open,
        txfsm_done_o => open,

        tx_prbs_mode_0 => control(0).txprbssel,
        tx_prbs_mode_1 => control(1).txprbssel,
        tx_prbs_mode_2 => control(2).txprbssel,
        tx_prbs_mode_3 => control(3).txprbssel,

        loopback_mode_0 => control(0).txloopback,
        loopback_mode_1 => control(1).txloopback,
        loopback_mode_2 => control(2).txloopback,
        loopback_mode_3 => control(3).txloopback,

        pll_reset_i        => '0',

        mgt_reset_i(0)     => control(0).gttxreset,
        mgt_reset_i(1)     => control(1).gttxreset,
        mgt_reset_i(2)     => control(2).gttxreset,
        mgt_reset_i(3)     => control(3).gttxreset,

        gtxtest_start_i    => '0',
        txreset_i          => '0',
        mgt_realign_i      => '0',
        txpowerdown_i      => '0',
        txpowerdown_mode_i => (others => '0'),
        txpllpowerdown_i   => '0',

        trg_tx_p => trg_tx_p (3 downto 0),
        trg_tx_n => trg_tx_n (3 downto 0),

        gem_data => legacy_clusters_i(7) & legacy_clusters_i(6) & legacy_clusters_i(5) &
                    legacy_clusters_i(4) & legacy_clusters_i(3) & legacy_clusters_i(2) &
                    legacy_clusters_i(1) & legacy_clusters_i(0),

        overflow_i => legacy_overflow_i
        );

  end generate;

  --===============================================================================================
  -- (this section is generated by <optohybrid_top>/tools/generate_registers.py -- do not edit)
  --==== Registers begin ==========================================================================

    -- IPbus slave instanciation
    ipbus_slave_inst : entity work.ipbus_slave_tmr
        generic map(
           g_ENABLE_TMR           => EN_TMR_IPB_SLAVE_MGT,
           g_NUM_REGS             => REG_MGT_NUM_REGS,
           g_ADDR_HIGH_BIT        => REG_MGT_ADDRESS_MSB,
           g_ADDR_LOW_BIT         => REG_MGT_ADDRESS_LSB,
           g_USE_INDIVIDUAL_ADDRS => true,
           g_IPB_CLK_PERIOD_NS    => 25
       )
       port map(
           ipb_reset_i            => ipb_reset_i,
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
    regs_addresses(0)(REG_MGT_ADDRESS_MSB downto REG_MGT_ADDRESS_LSB) <= '0' & x"0";
    regs_addresses(1)(REG_MGT_ADDRESS_MSB downto REG_MGT_ADDRESS_LSB) <= '0' & x"1";
    regs_addresses(2)(REG_MGT_ADDRESS_MSB downto REG_MGT_ADDRESS_LSB) <= '0' & x"2";
    regs_addresses(3)(REG_MGT_ADDRESS_MSB downto REG_MGT_ADDRESS_LSB) <= '0' & x"3";
    regs_addresses(4)(REG_MGT_ADDRESS_MSB downto REG_MGT_ADDRESS_LSB) <= '0' & x"4";
    regs_addresses(5)(REG_MGT_ADDRESS_MSB downto REG_MGT_ADDRESS_LSB) <= '0' & x"5";
    regs_addresses(6)(REG_MGT_ADDRESS_MSB downto REG_MGT_ADDRESS_LSB) <= '0' & x"6";
    regs_addresses(7)(REG_MGT_ADDRESS_MSB downto REG_MGT_ADDRESS_LSB) <= '0' & x"7";
    regs_addresses(8)(REG_MGT_ADDRESS_MSB downto REG_MGT_ADDRESS_LSB) <= '0' & x"8";
    regs_addresses(9)(REG_MGT_ADDRESS_MSB downto REG_MGT_ADDRESS_LSB) <= '0' & x"9";
    regs_addresses(10)(REG_MGT_ADDRESS_MSB downto REG_MGT_ADDRESS_LSB) <= '0' & x"a";
    regs_addresses(11)(REG_MGT_ADDRESS_MSB downto REG_MGT_ADDRESS_LSB) <= '0' & x"b";
    regs_addresses(12)(REG_MGT_ADDRESS_MSB downto REG_MGT_ADDRESS_LSB) <= '0' & x"c";
    regs_addresses(13)(REG_MGT_ADDRESS_MSB downto REG_MGT_ADDRESS_LSB) <= '0' & x"d";
    regs_addresses(14)(REG_MGT_ADDRESS_MSB downto REG_MGT_ADDRESS_LSB) <= '0' & x"e";
    regs_addresses(15)(REG_MGT_ADDRESS_MSB downto REG_MGT_ADDRESS_LSB) <= '0' & x"f";
    regs_addresses(16)(REG_MGT_ADDRESS_MSB downto REG_MGT_ADDRESS_LSB) <= '1' & x"0";
    regs_addresses(17)(REG_MGT_ADDRESS_MSB downto REG_MGT_ADDRESS_LSB) <= '1' & x"1";
    regs_addresses(18)(REG_MGT_ADDRESS_MSB downto REG_MGT_ADDRESS_LSB) <= '1' & x"2";
    regs_addresses(19)(REG_MGT_ADDRESS_MSB downto REG_MGT_ADDRESS_LSB) <= '1' & x"3";
    regs_addresses(20)(REG_MGT_ADDRESS_MSB downto REG_MGT_ADDRESS_LSB) <= '1' & x"4";
    regs_addresses(21)(REG_MGT_ADDRESS_MSB downto REG_MGT_ADDRESS_LSB) <= '1' & x"5";
    regs_addresses(22)(REG_MGT_ADDRESS_MSB downto REG_MGT_ADDRESS_LSB) <= '1' & x"6";
    regs_addresses(23)(REG_MGT_ADDRESS_MSB downto REG_MGT_ADDRESS_LSB) <= '1' & x"7";
    regs_addresses(24)(REG_MGT_ADDRESS_MSB downto REG_MGT_ADDRESS_LSB) <= '1' & x"8";

    -- Connect read signals
    regs_read_arr(0)(REG_MGT_PLL_LOCK_BIT) <= pll_lock;
    regs_read_arr(1)(REG_MGT_CONTROL0_TX_PRBS_MODE0_MSB downto REG_MGT_CONTROL0_TX_PRBS_MODE0_LSB) <= control(0).txprbssel;
    regs_read_arr(1)(REG_MGT_CONTROL0_RX_PRBS_MODE0_MSB downto REG_MGT_CONTROL0_RX_PRBS_MODE0_LSB) <= control(0).rxprbssel;
    regs_read_arr(1)(REG_MGT_CONTROL0_LOOPBACK_MODE0_MSB downto REG_MGT_CONTROL0_LOOPBACK_MODE0_LSB) <= control(0).txloopback;
    regs_read_arr(1)(REG_MGT_CONTROL0_TX_DIFFCTRL0_MSB downto REG_MGT_CONTROL0_TX_DIFFCTRL0_LSB) <= control(0).txdiffctrl;
    regs_read_arr(6)(REG_MGT_CONTROL1_TX_PRBS_MODE1_MSB downto REG_MGT_CONTROL1_TX_PRBS_MODE1_LSB) <= control(1).txprbssel;
    regs_read_arr(6)(REG_MGT_CONTROL1_RX_PRBS_MODE1_MSB downto REG_MGT_CONTROL1_RX_PRBS_MODE1_LSB) <= control(1).rxprbssel;
    regs_read_arr(6)(REG_MGT_CONTROL1_LOOPBACK_MODE1_MSB downto REG_MGT_CONTROL1_LOOPBACK_MODE1_LSB) <= control(1).txloopback;
    regs_read_arr(6)(REG_MGT_CONTROL1_TX_DIFFCTRL1_MSB downto REG_MGT_CONTROL1_TX_DIFFCTRL1_LSB) <= control(1).txdiffctrl;
    regs_read_arr(11)(REG_MGT_CONTROL2_TX_PRBS_MODE2_MSB downto REG_MGT_CONTROL2_TX_PRBS_MODE2_LSB) <= control(2).txprbssel;
    regs_read_arr(11)(REG_MGT_CONTROL2_RX_PRBS_MODE2_MSB downto REG_MGT_CONTROL2_RX_PRBS_MODE2_LSB) <= control(2).rxprbssel;
    regs_read_arr(11)(REG_MGT_CONTROL2_LOOPBACK_MODE2_MSB downto REG_MGT_CONTROL2_LOOPBACK_MODE2_LSB) <= control(2).txloopback;
    regs_read_arr(11)(REG_MGT_CONTROL2_TX_DIFFCTRL2_MSB downto REG_MGT_CONTROL2_TX_DIFFCTRL2_LSB) <= control(2).txdiffctrl;
    regs_read_arr(16)(REG_MGT_CONTROL3_TX_PRBS_MODE3_MSB downto REG_MGT_CONTROL3_TX_PRBS_MODE3_LSB) <= control(3).txprbssel;
    regs_read_arr(16)(REG_MGT_CONTROL3_RX_PRBS_MODE3_MSB downto REG_MGT_CONTROL3_RX_PRBS_MODE3_LSB) <= control(3).rxprbssel;
    regs_read_arr(16)(REG_MGT_CONTROL3_LOOPBACK_MODE3_MSB downto REG_MGT_CONTROL3_LOOPBACK_MODE3_LSB) <= control(3).txloopback;
    regs_read_arr(16)(REG_MGT_CONTROL3_TX_DIFFCTRL3_MSB downto REG_MGT_CONTROL3_TX_DIFFCTRL3_LSB) <= control(3).txdiffctrl;
    regs_read_arr(21)(REG_MGT_STATUS0_TXFSM_RESET_DONE0_BIT) <= status(0).txfsm_reset_done;
    regs_read_arr(21)(REG_MGT_STATUS0_TXRESET_DONE0_BIT) <= status(0).txreset_done;
    regs_read_arr(21)(REG_MGT_STATUS0_TX_PMA_RESET_DONE0_BIT) <= status(0).txpmaresetdone;
    regs_read_arr(21)(REG_MGT_STATUS0_TX_PHALIGN_DONE0_BIT) <= status(0).txphaligndone;
    regs_read_arr(22)(REG_MGT_STATUS1_TXFSM_RESET_DONE1_BIT) <= status(1).txfsm_reset_done;
    regs_read_arr(22)(REG_MGT_STATUS1_TXRESET_DONE1_BIT) <= status(1).txreset_done;
    regs_read_arr(22)(REG_MGT_STATUS1_TX_PMA_RESET_DONE1_BIT) <= status(1).txpmaresetdone;
    regs_read_arr(22)(REG_MGT_STATUS1_TX_PHALIGN_DONE1_BIT) <= status(1).txphaligndone;
    regs_read_arr(23)(REG_MGT_STATUS2_TXFSM_RESET_DONE2_BIT) <= status(2).txfsm_reset_done;
    regs_read_arr(23)(REG_MGT_STATUS2_TXRESET_DONE2_BIT) <= status(2).txreset_done;
    regs_read_arr(23)(REG_MGT_STATUS2_TX_PMA_RESET_DONE2_BIT) <= status(2).txpmaresetdone;
    regs_read_arr(23)(REG_MGT_STATUS2_TX_PHALIGN_DONE2_BIT) <= status(2).txphaligndone;
    regs_read_arr(24)(REG_MGT_STATUS3_TXFSM_RESET_DONE3_BIT) <= status(3).txfsm_reset_done;
    regs_read_arr(24)(REG_MGT_STATUS3_TXRESET_DONE3_BIT) <= status(3).txreset_done;
    regs_read_arr(24)(REG_MGT_STATUS3_TX_PMA_RESET_DONE3_BIT) <= status(3).txpmaresetdone;
    regs_read_arr(24)(REG_MGT_STATUS3_TX_PHALIGN_DONE3_BIT) <= status(3).txphaligndone;

    -- Connect write signals
    control(0).txprbssel <= regs_write_arr(1)(REG_MGT_CONTROL0_TX_PRBS_MODE0_MSB downto REG_MGT_CONTROL0_TX_PRBS_MODE0_LSB);
    control(0).rxprbssel <= regs_write_arr(1)(REG_MGT_CONTROL0_RX_PRBS_MODE0_MSB downto REG_MGT_CONTROL0_RX_PRBS_MODE0_LSB);
    control(0).txloopback <= regs_write_arr(1)(REG_MGT_CONTROL0_LOOPBACK_MODE0_MSB downto REG_MGT_CONTROL0_LOOPBACK_MODE0_LSB);
    control(0).txdiffctrl <= regs_write_arr(1)(REG_MGT_CONTROL0_TX_DIFFCTRL0_MSB downto REG_MGT_CONTROL0_TX_DIFFCTRL0_LSB);
    control(1).txprbssel <= regs_write_arr(6)(REG_MGT_CONTROL1_TX_PRBS_MODE1_MSB downto REG_MGT_CONTROL1_TX_PRBS_MODE1_LSB);
    control(1).rxprbssel <= regs_write_arr(6)(REG_MGT_CONTROL1_RX_PRBS_MODE1_MSB downto REG_MGT_CONTROL1_RX_PRBS_MODE1_LSB);
    control(1).txloopback <= regs_write_arr(6)(REG_MGT_CONTROL1_LOOPBACK_MODE1_MSB downto REG_MGT_CONTROL1_LOOPBACK_MODE1_LSB);
    control(1).txdiffctrl <= regs_write_arr(6)(REG_MGT_CONTROL1_TX_DIFFCTRL1_MSB downto REG_MGT_CONTROL1_TX_DIFFCTRL1_LSB);
    control(2).txprbssel <= regs_write_arr(11)(REG_MGT_CONTROL2_TX_PRBS_MODE2_MSB downto REG_MGT_CONTROL2_TX_PRBS_MODE2_LSB);
    control(2).rxprbssel <= regs_write_arr(11)(REG_MGT_CONTROL2_RX_PRBS_MODE2_MSB downto REG_MGT_CONTROL2_RX_PRBS_MODE2_LSB);
    control(2).txloopback <= regs_write_arr(11)(REG_MGT_CONTROL2_LOOPBACK_MODE2_MSB downto REG_MGT_CONTROL2_LOOPBACK_MODE2_LSB);
    control(2).txdiffctrl <= regs_write_arr(11)(REG_MGT_CONTROL2_TX_DIFFCTRL2_MSB downto REG_MGT_CONTROL2_TX_DIFFCTRL2_LSB);
    control(3).txprbssel <= regs_write_arr(16)(REG_MGT_CONTROL3_TX_PRBS_MODE3_MSB downto REG_MGT_CONTROL3_TX_PRBS_MODE3_LSB);
    control(3).rxprbssel <= regs_write_arr(16)(REG_MGT_CONTROL3_RX_PRBS_MODE3_MSB downto REG_MGT_CONTROL3_RX_PRBS_MODE3_LSB);
    control(3).txloopback <= regs_write_arr(16)(REG_MGT_CONTROL3_LOOPBACK_MODE3_MSB downto REG_MGT_CONTROL3_LOOPBACK_MODE3_LSB);
    control(3).txdiffctrl <= regs_write_arr(16)(REG_MGT_CONTROL3_TX_DIFFCTRL3_MSB downto REG_MGT_CONTROL3_TX_DIFFCTRL3_LSB);

    -- Connect write pulse signals
    control(0).gttxreset <= regs_write_pulse_arr(2);
    control(0).txprbsforceerr <= regs_write_pulse_arr(3);
    control(0).txpcsreset <= regs_write_pulse_arr(4);
    control(0).txpmareset <= regs_write_pulse_arr(5);
    control(1).gttxreset <= regs_write_pulse_arr(7);
    control(1).txprbsforceerr <= regs_write_pulse_arr(8);
    control(1).txpcsreset <= regs_write_pulse_arr(9);
    control(1).txpmareset <= regs_write_pulse_arr(10);
    control(2).gttxreset <= regs_write_pulse_arr(12);
    control(2).txprbsforceerr <= regs_write_pulse_arr(13);
    control(2).txpcsreset <= regs_write_pulse_arr(14);
    control(2).txpmareset <= regs_write_pulse_arr(15);
    control(3).gttxreset <= regs_write_pulse_arr(17);
    control(3).txprbsforceerr <= regs_write_pulse_arr(18);
    control(3).txpcsreset <= regs_write_pulse_arr(19);
    control(3).txpmareset <= regs_write_pulse_arr(20);

    -- Connect write done signals

    -- Connect read pulse signals

    -- Connect counter instances

    -- Connect rate instances

    -- Connect read ready signals

    -- Defaults
    regs_defaults(1)(REG_MGT_CONTROL0_TX_PRBS_MODE0_MSB downto REG_MGT_CONTROL0_TX_PRBS_MODE0_LSB) <= REG_MGT_CONTROL0_TX_PRBS_MODE0_DEFAULT;
    regs_defaults(1)(REG_MGT_CONTROL0_RX_PRBS_MODE0_MSB downto REG_MGT_CONTROL0_RX_PRBS_MODE0_LSB) <= REG_MGT_CONTROL0_RX_PRBS_MODE0_DEFAULT;
    regs_defaults(1)(REG_MGT_CONTROL0_LOOPBACK_MODE0_MSB downto REG_MGT_CONTROL0_LOOPBACK_MODE0_LSB) <= REG_MGT_CONTROL0_LOOPBACK_MODE0_DEFAULT;
    regs_defaults(1)(REG_MGT_CONTROL0_TX_DIFFCTRL0_MSB downto REG_MGT_CONTROL0_TX_DIFFCTRL0_LSB) <= REG_MGT_CONTROL0_TX_DIFFCTRL0_DEFAULT;
    regs_defaults(6)(REG_MGT_CONTROL1_TX_PRBS_MODE1_MSB downto REG_MGT_CONTROL1_TX_PRBS_MODE1_LSB) <= REG_MGT_CONTROL1_TX_PRBS_MODE1_DEFAULT;
    regs_defaults(6)(REG_MGT_CONTROL1_RX_PRBS_MODE1_MSB downto REG_MGT_CONTROL1_RX_PRBS_MODE1_LSB) <= REG_MGT_CONTROL1_RX_PRBS_MODE1_DEFAULT;
    regs_defaults(6)(REG_MGT_CONTROL1_LOOPBACK_MODE1_MSB downto REG_MGT_CONTROL1_LOOPBACK_MODE1_LSB) <= REG_MGT_CONTROL1_LOOPBACK_MODE1_DEFAULT;
    regs_defaults(6)(REG_MGT_CONTROL1_TX_DIFFCTRL1_MSB downto REG_MGT_CONTROL1_TX_DIFFCTRL1_LSB) <= REG_MGT_CONTROL1_TX_DIFFCTRL1_DEFAULT;
    regs_defaults(11)(REG_MGT_CONTROL2_TX_PRBS_MODE2_MSB downto REG_MGT_CONTROL2_TX_PRBS_MODE2_LSB) <= REG_MGT_CONTROL2_TX_PRBS_MODE2_DEFAULT;
    regs_defaults(11)(REG_MGT_CONTROL2_RX_PRBS_MODE2_MSB downto REG_MGT_CONTROL2_RX_PRBS_MODE2_LSB) <= REG_MGT_CONTROL2_RX_PRBS_MODE2_DEFAULT;
    regs_defaults(11)(REG_MGT_CONTROL2_LOOPBACK_MODE2_MSB downto REG_MGT_CONTROL2_LOOPBACK_MODE2_LSB) <= REG_MGT_CONTROL2_LOOPBACK_MODE2_DEFAULT;
    regs_defaults(11)(REG_MGT_CONTROL2_TX_DIFFCTRL2_MSB downto REG_MGT_CONTROL2_TX_DIFFCTRL2_LSB) <= REG_MGT_CONTROL2_TX_DIFFCTRL2_DEFAULT;
    regs_defaults(16)(REG_MGT_CONTROL3_TX_PRBS_MODE3_MSB downto REG_MGT_CONTROL3_TX_PRBS_MODE3_LSB) <= REG_MGT_CONTROL3_TX_PRBS_MODE3_DEFAULT;
    regs_defaults(16)(REG_MGT_CONTROL3_RX_PRBS_MODE3_MSB downto REG_MGT_CONTROL3_RX_PRBS_MODE3_LSB) <= REG_MGT_CONTROL3_RX_PRBS_MODE3_DEFAULT;
    regs_defaults(16)(REG_MGT_CONTROL3_LOOPBACK_MODE3_MSB downto REG_MGT_CONTROL3_LOOPBACK_MODE3_LSB) <= REG_MGT_CONTROL3_LOOPBACK_MODE3_DEFAULT;
    regs_defaults(16)(REG_MGT_CONTROL3_TX_DIFFCTRL3_MSB downto REG_MGT_CONTROL3_TX_DIFFCTRL3_LSB) <= REG_MGT_CONTROL3_TX_DIFFCTRL3_DEFAULT;

    -- Define writable regs
    regs_writable_arr(1) <= '1';
    regs_writable_arr(6) <= '1';
    regs_writable_arr(11) <= '1';
    regs_writable_arr(16) <= '1';

  --==== Registers end ============================================================================

end Behavioral;
