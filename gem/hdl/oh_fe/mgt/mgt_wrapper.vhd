library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;

library work;

use work.types_pkg.all;
use work.hardware_pkg.all;

--***********************************Entity Declaration************************

entity mgt_wrapper is
  generic
    (
      NUM_GTS                     : integer := 4;
      WRAPPER_SIM_GTRESET_SPEEDUP : string  := "TRUE";  -- simulation setting for GT SecureIP model
      WRAPPER_SIMULATION          : integer := 1;       -- Set to 1 for simulation
      STABLE_CLOCK_PERIOD         : integer := 6        -- 160MHz reference clock
      );
  port
    (
      refclk_in_p : in std_logic_vector(1 downto 0);
      refclk_in_n : in std_logic_vector(1 downto 0);

      -- gtp/gtx
      txn_out : out std_logic_vector(NUM_GTS-1 downto 0);
      txp_out : out std_logic_vector(NUM_GTS-1 downto 0);

      sysclk_in        : in  std_logic;
      soft_reset_tx_in : in  std_logic;
      pll_lock_out     : out std_logic;

      status_o  : out mgt_status_array (NUM_GTS-1 downto 0);
      control_i : in  mgt_control_array (NUM_GTS-1 downto 0);

      drp_i : in  drp_i_array (NUM_GTS-1 downto 0);
      drp_o : out drp_o_array (NUM_GTS-1 downto 0);

      common_drp_i : in  drp_i_t;
      common_drp_o : out drp_o_t;

      mmcm_lock_i : in std_logic;

      txusrclk_in : in std_logic;
      txcharisk_i : in t_std2_array (NUM_GTS-1 downto 0);
      txdata_i    : in t_std16_array (NUM_GTS-1 downto 0)
      );

end mgt_wrapper;

architecture behavior of mgt_wrapper is

  constant zero : std_logic := '0';
  constant one  : std_logic := '1';

  signal refclk       : std_logic;
  signal common_reset : std_logic;
  signal txoutclk_buf : std_logic;

  signal gttxreset : std_logic_vector(3 downto 0);
  signal txoutclk  : std_logic_vector(3 downto 0);

  -- use if we are taking the TXOUTCLK --> MMCM
  signal mmcm_reset : std_logic_vector(NUM_GTS-1 downto 0);

begin


  -- 160MHz outclk
  outclk_bufg : BUFG
    port map (
      I => txoutclk(0),
      O => txoutclk_buf
      );

  -- waits 500ns at startup, asserting common_reset
  common_reset_inst : entity work.gtp_common_reset
    generic map (
      STABLE_CLOCK_PERIOD => STABLE_CLOCK_PERIOD  -- Period of the stable clock driving this state-machine, unit is [ns]
      )
    port map (
      STABLE_CLOCK => txoutclk_buf,               -- IN:  Stable Clock, either a stable clock from the PCB
      SOFT_RESET   => soft_reset_tx_in,           -- IN:  User Reset, can be pulled any time
      COMMON_RESET => common_reset                -- OUT: Reset QPLL
      );

  a7gen : if (FPGA_TYPE = "A7") generate
    component gtp_GT is
      generic (
        GT_SIM_GTRESET_SPEEDUP : string;
        EXAMPLE_SIMULATION     : integer;
        TXSYNC_OVRD_IN         : bit;
        TXSYNC_MULTILANE_IN    : bit);
      port (
        TXPMARESETDONE       : out std_logic;
        drpaddr_in           : in  std_logic_vector(8 downto 0);
        drpclk_in            : in  std_logic;
        drpdi_in             : in  std_logic_vector(15 downto 0);
        drpdo_out            : out std_logic_vector(15 downto 0);
        drpen_in             : in  std_logic;
        drprdy_out           : out std_logic;
        drpwe_in             : in  std_logic;
        pll0clk_in           : in  std_logic;
        pll0refclk_in        : in  std_logic;
        pll1clk_in           : in  std_logic;
        pll1refclk_in        : in  std_logic;
        loopback_in          : in  std_logic_vector(2 downto 0);
        eyescanreset_in      : in  std_logic;
        eyescandataerror_out : out std_logic;
        eyescantrigger_in    : in  std_logic;
        rxprbserr_out        : out std_logic;
        rxprbssel_in         : in  std_logic_vector(2 downto 0);
        rxprbscntreset_in    : in  std_logic;
        dmonitorout_out      : out std_logic_vector(14 downto 0);
        gtrxreset_in         : in  std_logic;
        rxlpmreset_in        : in  std_logic;
        gttxreset_in         : in  std_logic;
        txuserrdy_in         : in  std_logic;
        txdata_in            : in  std_logic_vector(15 downto 0);
        txusrclk_in          : in  std_logic;
        txusrclk2_in         : in  std_logic;
        txprbsforceerr_in    : in  std_logic;
        txcharisk_in         : in  std_logic_vector(1 downto 0);
        txdlyen_in           : in  std_logic;
        txdlysreset_in       : in  std_logic;
        txdlysresetdone_out  : out std_logic;
        txphalign_in         : in  std_logic;
        txphaligndone_out    : out std_logic;
        txphalignen_in       : in  std_logic;
        txphdlyreset_in      : in  std_logic;
        txphinit_in          : in  std_logic;
        txphinitdone_out     : out std_logic;
        gtptxn_out           : out std_logic;
        gtptxp_out           : out std_logic;
        txdiffctrl_in        : in  std_logic_vector(3 downto 0);
        txoutclk_out         : out std_logic;
        txoutclkfabric_out   : out std_logic;
        txoutclkpcs_out      : out std_logic;
        txpcsreset_in        : in  std_logic;
        txpmareset_in        : in  std_logic;
        txresetdone_out      : out std_logic;
        txprbssel_in         : in  std_logic_vector(2 downto 0));
    end component gtp_GT;

    signal pll0_lock        : std_logic;
    signal pll0_refclklost  : std_logic;
    signal pll0_reset_array : std_logic_vector(3 downto 0);
    signal pll0_reset       : std_logic;
    signal pll0_clk         : std_logic;
    signal pll0_refclk      : std_logic;
    signal pll1_clk         : std_logic;
    signal pll1_refclk      : std_logic;
    signal cpll_pd          : std_logic;
    signal cpll_reset       : std_logic;

    signal txresetdone : std_logic_vector(3 downto 0);


    signal txuserrdy : std_logic_vector(3 downto 0);

    --------------------------- TX Buffer Bypass Signals --------------------

    signal rst_tx_phalignment       : std_logic;
    signal rst_tx_phalignment_array : std_logic_vector(3 downto 0);
    signal run_tx_phalignment       : std_logic;
    signal run_tx_phalignment_array : std_logic_vector(3 downto 0);

    signal tx_phalignment_done : std_logic;
    signal txdlyen             : std_logic_vector(3 downto 0);
    signal txdlysreset         : std_logic_vector(3 downto 0);
    signal txdlysresetdone     : std_logic_vector(3 downto 0);
    signal txphalign           : std_logic_vector(3 downto 0);
    signal txphaligndone       : std_logic_vector(3 downto 0);
    signal txphalignen         : std_logic_vector(3 downto 0) := (others => '1');
    signal txphdlyreset        : std_logic_vector(3 downto 0) := (others => '0');
    signal txphinit            : std_logic_vector(3 downto 0);
    signal txphinitdone        : std_logic_vector(3 downto 0);
  begin

    gtp_gt_gen : for I in 0 to 3 generate
    begin

      gtp_GT_inst : gtp_GT
        generic map (
          -- Simulation attributes
          GT_SIM_GTRESET_SPEEDUP => WRAPPER_SIM_GTRESET_SPEEDUP,
          EXAMPLE_SIMULATION     => WRAPPER_SIMULATION,
          TXSYNC_OVRD_IN         => ('1'),
          TXSYNC_MULTILANE_IN    => ('0')
          )
        port map (
          drpclk_in  => sysclk_in,
          drpaddr_in => drp_i(I).addr (8 downto 0),
          drpdi_in   => drp_i(I).di,
          drpen_in   => drp_i(I).en,
          drpwe_in   => drp_i(I).we,
          drpdo_out  => drp_o(I).do,
          drprdy_out => drp_o(I).rdy,

          pll0clk_in    => pll0_clk,
          pll0refclk_in => pll0_refclk,
          pll1clk_in    => pll1_clk,
          pll1refclk_in => pll1_refclk,

          -- eyescan
          eyescanreset_in      => zero,
          eyescandataerror_out => open,
          eyescantrigger_in    => zero,
          dmonitorout_out      => open,

          gtrxreset_in => one,          -- rx disabled

          txdata_in    => txdata_i(I),
          txcharisk_in => txcharisk_i(I),

          rxlpmreset_in => zero,

          txusrclk_in  => txusrclk_in,
          txusrclk2_in => txusrclk_in,
          txdlyen_in   => txdlyen(I),

          txdlysreset_in      => txdlysreset(I),      --
          txdlysresetdone_out => txdlysresetdone(I),  --
          txphalign_in        => txphalign(I),        --
          txphaligndone_out   => txphaligndone(I),    --out
          txphalignen_in      => txphalignen(I),
          txphdlyreset_in     => txphdlyreset(I),
          txphinit_in         => txphinit(I),
          txphinitdone_out    => txphinitdone(I),

          gtptxn_out => txn_out(I),
          gtptxp_out => txp_out(I),


          txprbsforceerr_in => control_i(I).txprbsforceerr,

          txuserrdy_in      => txuserrdy(I),
          txprbssel_in      => control_i(I).txprbssel,
          txpcsreset_in     => control_i(I).txpcsreset,
          txpmareset_in     => control_i(I).txpmareset,
          gttxreset_in      => gttxreset(I),
          loopback_in       => control_i(I).txloopback,
          rxprbscntreset_in => control_i(I).rxprbscntreset,
          rxprbssel_in      => control_i(I).rxprbssel,
          txdiffctrl_in     => control_i(I).txdiffctrl,

          rxprbserr_out   => status_o(I).rxprbserr,
          txpmaresetdone  => status_o(I).txpmaresetdone,
          txresetdone_out => txresetdone(I),


          txoutclk_out       => txoutclk(I),
          txoutclkfabric_out => open,
          txoutclkpcs_out    => open
          );


      status_o(I).txphaligndone <= txphaligndone(I);
      status_o(I).txreset_done  <= txresetdone(I);

    end generate;

    --IBUFDS_GTE2
    refclk_ibufds : IBUFDS_GTE2
      port map (
        O     => refclk,
        ODIV2 => open,
        CEB   => zero,
        I     => refclk_in_p(0),
        IB    => refclk_in_n(0)
        );

    cpll_reset_inst : entity work.gtp_cpll_railing
      generic map(USE_BUFG => 0)
      port map (
        cpll_reset_out => cpll_reset,
        cpll_pd_out    => cpll_pd,
        refclk_out     => open,
        refclk_in      => refclk
        );

    gtp_common_inst : entity work.gtp_common
      generic map
      (
        wrapper_sim_gtreset_speedup => WRAPPER_SIM_GTRESET_SPEEDUP,
        sim_pll0refclk_sel          => "001",
        sim_pll1refclk_sel          => "001"
        )
      port map
      (
        drpclk_common_in  => sysclk_in,
        drpaddr_common_in => common_drp_i.addr (7 downto 0),
        drpdi_common_in   => common_drp_i.di,
        drpen_common_in   => common_drp_i.en,
        drpwe_common_in   => common_drp_i.we,
        drpdo_common_out  => common_drp_o.do,
        drprdy_common_out => common_drp_o.rdy,

        pll0outclk_out    => pll0_clk,
        pll0outrefclk_out => pll0_refclk,
        pll1outclk_out    => pll1_clk,
        pll1outrefclk_out => pll1_refclk,

        pll0lockdetclk_in  => txoutclk_buf,
        pll0lock_out       => pll0_lock,
        pll0refclklost_out => pll0_refclklost,
        pll0reset_in       => pll0_reset,

        pll0refclksel_in => "001",

        pll0pd_in => cpll_pd,

        gtrefclk0_in => refclk,
        gtrefclk1_in => zero
        );

    --------------------------- TX Buffer Bypass Logic --------------------
    -- The TX SYNC Module drives the ports needed to Bypass the TX Buffer.
    -- Include the TX SYNC module in your own design if TX Buffer is bypassed.

    run_tx_phalignment <= and_reduce(run_tx_phalignment_array);
    rst_tx_phalignment <= and_reduce(rst_tx_phalignment_array);

    tx_manual_phase_inst : entity work.gtp_tx_manual_phase_align
      generic map (
        number_of_lanes => 4,
        master_lane_id  => 0
        )
      port map (
        stable_clock         => txoutclk_buf,         -- stable clock, either a stable clock from the pcb
        reset_phalignment    => rst_tx_phalignment,   -- in
        run_phalignment      => run_tx_phalignment,   -- in
        txdlysresetdone      => txdlysresetdone,      -- in
        txphinitdone         => txphinitdone,         -- in
        txphaligndone        => txphaligndone,        -- in
        phase_alignment_done => tx_phalignment_done,  --out
        txdlysreset          => txdlysreset,          -- out
        txphinit             => txphinit,             -- out
        txphalign            => txphalign,            -- out
        txdlyen              => txdlyen               -- out
        );

    pll_lock_out <= pll0_lock;
    pll0_reset   <= common_reset or pll0_reset_array(0) or cpll_reset;

    startup_fsm_gen : for I in 0 to 3 generate
    begin
      txresetfsm_i : entity work.gtp_tx_startup_fsm

        generic map (
          EXAMPLE_SIMULATION     => WRAPPER_SIMULATION,
          STABLE_CLOCK_PERIOD    => STABLE_CLOCK_PERIOD,  -- period of the stable clock driving this state-machine, unit is [ns]
          retry_counter_bitwidth => 8,
          tx_pll0_used           => true,                 -- the tx and rx reset fsms must
          rx_pll0_used           => false,                -- share these two generic values
          phase_alignment_manual => true                  -- decision if a manual phase-alignment is necessary or the automatic
                                                          -- is enough. for single-lane applications the automatic alignment is
                                                          -- sufficient
          )
        port map (

          stable_clock => txoutclk_buf,  --stable clock, either a stable clock from the pcb
          txuserclk    => txusrclk_in,
          soft_reset   => soft_reset_tx_in,

          pll0refclklost => pll0_refclklost,
          pll0lock       => pll0_lock,

          pll0_reset        => pll0_reset_array(I),
          txuserrdy         => txuserrdy(I),
          txresetdone       => txresetdone(I),
          mmcm_lock         => mmcm_lock_i,
          mmcm_reset        => mmcm_reset(I),
          gttxreset         => gttxreset(I),
          tx_fsm_reset_done => status_o(I).txfsm_reset_done,
          run_phalignment   => run_tx_phalignment_array(I),
          reset_phalignment => rst_tx_phalignment_array(I),
          phalignment_done  => tx_phalignment_done,

          pll1refclklost => zero,
          pll1lock       => one,
          pll1_reset     => open,
          retry_counter  => open
          );
    end generate;

  end generate;


  v6gen : if (FPGA_TYPE = "V6") generate

    signal pll_txreset : std_logic_vector (3 downto 0);
    signal pll_lock    : std_logic_vector (3 downto 0);
    signal txresetdone : std_logic_vector(3 downto 0);
  begin

    refclk_ibufds : IBUFDS_GTXE1
      port map (
        O     => refclk,
        ODIV2 => open,
        CEB   => zero,
        I     => refclk_in_p(0),
        IB    => refclk_in_n(0)
        );

    gtx_loop : for I in 0 to 3 generate
      signal txenpmaphasealign                    : std_logic;
      signal txpmasetphase                        : std_logic;
      signal txdlyaligndisable                    : std_logic;
      signal txdlyalignreset                      : std_logic;
      signal resetdone, resetdone_r, resetdone_r2 : std_logic;
      signal sync_done                            : std_logic;

      constant GTX_SIM_GTXRESET_SPEEDUP : integer                        := 1;             -- Set to 1 to speed up sim reset
      constant GTX_TX_CLK_SOURCE        : string                         := "TXPLL";       -- Share RX PLL parameter
      constant GTX_POWER_SAVE           : bit_vector                     := "0000110000";  -- Save power parameter
      constant GTXTEST_IN               : std_logic_vector (12 downto 0) := (others => '0');

    begin
      gtx_inst : entity work.mgt_gtx
        generic map (
          GTX_TX_CLK_SOURCE        => GTX_TX_CLK_SOURCE,
          GTX_POWER_SAVE           => GTX_POWER_SAVE,
          GTX_SIM_GTXRESET_SPEEDUP => GTX_SIM_GTXRESET_SPEEDUP
          )
        port map (

          -- Receive Ports - 8b10b Decoder
          rxcharisk_out      => open,
          rxdisperr_out      => open,
          rxnotintable_out   => open,
          -- Receive Ports - Comma Detection and Alignment
          rxenmcommaalign_in => zero,
          rxenpcommaalign_in => zero,
          -- Receive Ports - PRBS Detection
          prbscntreset_in    => control_i(I).rxprbscntreset,
          rxenprbstst_in     => control_i(I).txprbssel,
          rxprbserr_out      => status_o(I).rxprbserr,
          -- Receive Ports - RX Data Path interface
          rxdata_out         => open,
          rxusrclk2_in       => txusrclk_in,
          -- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR
          rxn_in             => zero,
          rxp_in             => one,
          -- Receive Ports - RX PLL Ports
          gtxrxreset_in      => gttxreset(i),
          mgtrefclkrx_in(0)  => refclk,
          mgtrefclkrx_in(1)  => zero,
          pllrxreset_in      => pll_txreset(i),
          rxplllkdet_out     => open,
          rxresetdone_out    => open,

          -- transmit ports - 8b10b encoder control ports
          txcharisk_in => txcharisk_i(I),

          -- transmit ports - gtx ports
          -- GTXTEST[1]: The default is 0. When this bit is set to 1, the TX output clock dividers are reset.
          gtxtest_in => GTXTEST_IN,

          -- transmit ports - tx data path interface
          txdata_in    => txdata_i(I),
          txoutclk_out => txoutclk(I),
          txreset_in   => not mmcm_lock_i,  -- Hold the TX in reset till the TX user clocks are stable
          txusrclk2_in => txusrclk_in,

          -- transmit ports - tx driver and oob signaling
          txn_out => txn_out(i),
          txp_out => txp_out(i),

          txdiffctrl_in => control_i(I).txdiffctrl,

          -- transmit ports - tx elastic buffer and phase alignment ports
          txdlyaligndisable_in  => txdlyaligndisable,
          txdlyalignreset_in    => txdlyalignreset,
          txenpmaphasealign_in  => txenpmaphasealign,
          txpmasetphase_in      => txpmasetphase,
          txdlyalignmonenb_in   => zero,
          txdlyalignmonitor_out => open,

          -- transmit ports - tx pll ports
          gtxtxreset_in     => gttxreset(i),
          mgtrefclktx_in(0) => refclk,
          mgtrefclktx_in(1) => zero,
          plltxreset_in     => pll_txreset(i),
          txplllkdet_out    => pll_lock(i),
          txresetdone_out   => resetdone,
          txprbsforceerr_in => control_i(I).txprbsforceerr,

          -- transmit ports - tx prbs generator
          txenprbstst_in => control_i(i).txprbssel
          );

      txresetfsm_i : entity work.gtp_tx_startup_fsm

        generic map
        (
          example_simulation     => wrapper_simulation,
          STABLE_CLOCK_PERIOD    => STABLE_CLOCK_PERIOD,  -- period of the stable clock driving this state-machine, unit is [ns]
          retry_counter_bitwidth => 8,
          tx_pll0_used           => true,                 -- the tx and rx reset fsms must
          rx_pll0_used           => false,                -- share these two generic values
          phase_alignment_manual => true                  -- decision if a manual phase-alignment is necessary or the automatic
                                                          -- is enough. for single-lane applications the automatic alignment is
                                                          -- sufficient
          )
        port map (

          stable_clock => txoutclk_buf,      --stable clock, either a stable clock from the pcb or reference-clock present at startup.
          txuserclk    => txusrclk_in,       --TXUSERCLK as used in the design
          soft_reset   => soft_reset_tx_in,  --User Reset, can be pulled any time

          pll0refclklost => '0',          --PLL0 Reference-clock for the GT is lost
          pll0lock       => pll_lock(i),  --Lock Detect from the PLL0 of the GT

          pll0_reset        => pll_txreset(I),                --Reset PLL0
          txuserrdy         => open,
          txresetdone       => resetdone,
          mmcm_lock         => mmcm_lock_i,
          mmcm_reset        => mmcm_reset(I),
          gttxreset         => gttxreset(I),
          tx_fsm_reset_done => status_o(I).txfsm_reset_done,  --Reset-sequence has sucessfully been finished.
          run_phalignment   => open,
          reset_phalignment => open,
          phalignment_done  => sync_done,

          pll1refclklost => zero,       --PLL1 Reference-clock for the GT is lost,
          pll1lock       => one,        --Lock Detect from the PLL0 of the GT
          pll1_reset     => open,       --Reset PLL0
          retry_counter  => open
          );

      status_o(I).txreset_done   <= resetdone;
      status_o(I).txpmaresetdone <= '1';
      status_o(I).txphaligndone  <= sync_done;

      gtx_txsync_inst : entity work.gtx_tx_sync
        port map
        (
          txenpmaphasealign => txenpmaphasealign,
          txpmasetphase     => txpmasetphase,
          txdlyaligndisable => txdlyaligndisable,
          txdlyalignreset   => txdlyalignreset,
          sync_done         => sync_done,
          user_clk          => txusrclk_in,
          reset             => not resetdone_r2
          );

      process(txusrclk_in, resetdone)
      begin
        if(resetdone = '0') then
          resetdone_r  <= '0';
          resetdone_r2 <= '0';
        elsif(txusrclk_in'event and txusrclk_in = '1') then
          resetdone_r  <= resetdone;
          resetdone_r2 <= resetdone_r;
        end if;
      end process;


    end generate;  -- gtx loop 0-3

  end generate;  -- if virtex-6

end behavior;
