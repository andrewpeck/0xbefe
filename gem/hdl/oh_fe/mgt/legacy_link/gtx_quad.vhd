library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library work;
use work.types_pkg.all;

entity gtx_quad is
  generic (
    RATE0 : string := "3p2";
    RATE1 : string := "3p2";
    RATE2 : string := "3p2";
    RATE3 : string := "3p2"
    );
  port (
    plltxreset_in : in std_logic;

    refclk_p : in std_logic_vector (1 downto 0);
    refclk_n : in std_logic_vector (1 downto 0);

    clock_160 : in std_logic;
    clock_200 : in std_logic;

    gttx_reset_in : in  std_logic_vector(3 downto 0);
    TXN_OUT       : out std_logic_vector(3 downto 0);
    TXP_OUT       : out std_logic_vector(3 downto 0);

    gtx_txoutclk : out std_logic_vector(3 downto 0);

    pll_lock : out std_logic_vector (3 downto 0);

    GTX0_TXCHARISK_IN : in std_logic_vector(1 downto 0);
    GTX1_TXCHARISK_IN : in std_logic_vector(1 downto 0);
    GTX2_TXCHARISK_IN : in std_logic_vector(1 downto 0);
    GTX3_TXCHARISK_IN : in std_logic_vector(1 downto 0);

    GTX0_TXDATA_IN : in std_logic_vector(15 downto 0);
    GTX1_TXDATA_IN : in std_logic_vector(15 downto 0);
    GTX2_TXDATA_IN : in std_logic_vector(15 downto 0);
    GTX3_TXDATA_IN : in std_logic_vector(15 downto 0);

    txenprbstst_in : in std_logic_vector (2 downto 0);
    txreset_in     : in std_logic;

    txpowerdown    : in std_logic_vector (1 downto 0);
    txpllpowerdown : in std_logic;

    realign : in std_logic;

    gtxtest_in : in std_logic_vector (12 downto 0);

    gtx_tx_sync_done : out std_logic_vector (3 downto 0);

    tx_resetdone_o : out std_logic_vector (3 downto 0)

    );

end gtx_quad;

architecture Behavioral of gtx_quad is

  type string_array_t is array (3 downto 0) of string (1 to 3);
  constant RATE : string_array_t := (RATE3, RATE2, RATE1, RATE0);

  signal userclk : std_logic_vector (3 downto 0);

  constant DLY : time := 1 ns;

  signal mgt_refclk0 : std_logic;
  signal mgt_refclk1 : std_logic;

  signal mgt_refclk_i : std_logic_vector (1 downto 0);

  signal gtx_txoutclk_i : std_logic_vector(3 downto 0);

  -------- Transmit Ports - TX Elastic Buffer and Phase Alignment Ports ------

  signal gtx_txdlyaligndisable_i : std_logic_vector (3 downto 0);
  signal gtx_txdlyalignmonenb_i  : std_logic_vector (3 downto 0);
  signal gtx_txdlyalignreset_i   : std_logic_vector (3 downto 0);
  signal gtx_txenpmaphasealign_i : std_logic_vector (3 downto 0);
  signal gtx_txpmasetphase_i     : std_logic_vector (3 downto 0);

  ----------------------- Transmit Ports - TX PLL Ports ----------------------

  signal gtx_gtxtxreset_i  : std_logic_vector (3 downto 0);
  signal gtx_plltxreset_i  : std_logic_vector (3 downto 0);
  signal gtx_txplllkdet_i  : std_logic_vector (3 downto 0);
  signal gtx_txresetdone_i : std_logic_vector (3 downto 0);

  ------------------------- Sync Module Signals -----------------------------

  signal gtx_reset_txsync_c : std_logic_vector (3 downto 0);

  signal tx_sync_reset : std_logic_vector (3 downto 0);

  signal gtx_txresetdone_r  : std_logic_vector (3 downto 0);
  signal gtx_txresetdone_r2 : std_logic_vector (3 downto 0);

  signal GTX_TXCHARISK_IN : t_std2_array (3 downto 0);

  signal GTX_TXDATA_IN : t_std16_array (3 downto 0);

begin

  userclk_assign : for I in 0 to 3 generate
  begin

    g3p2 : if (RATE(I) = "3p2") generate
      userclk(I) <= clock_160;
    end generate;

    g4p0 : if (RATE(I) = "4p0") generate
      userclk(I) <= clock_200;
    end generate;

  end generate;

  GTX_TXCHARISK_IN(0) <= GTX0_TXCHARISK_IN;
  GTX_TXCHARISK_IN(1) <= GTX1_TXCHARISK_IN;
  GTX_TXCHARISK_IN(2) <= GTX2_TXCHARISK_IN;
  GTX_TXCHARISK_IN(3) <= GTX3_TXCHARISK_IN;

  GTX_TXDATA_IN(0) <= GTX0_TXDATA_IN;
  GTX_TXDATA_IN(1) <= GTX1_TXDATA_IN;
  GTX_TXDATA_IN(2) <= GTX2_TXDATA_IN;
  GTX_TXDATA_IN(3) <= GTX3_TXDATA_IN;

  ----------------------------- The GTX Wrapper -----------------------------

  tx_resetdone_o <= gtx_txresetdone_r2;
  mgt_refclk_i   <= ('0' & mgt_refclk1);

  gtx_loop : for I in 0 to 3 generate
  begin
    gtx_single_inst : entity work.gtx_single
      generic map (
        RATE                     => RATE(I),
        GTX_TX_CLK_SOURCE        => "TXPLL",
        GTX_POWER_SAVE           => "0000110000",
        GTX_SIM_GTXRESET_SPEEDUP => 1
        )
      port map
      (
        ------- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
        RXN_IN                => '0',
        RXP_IN                => '1',
        ---------------- Transmit Ports - 8b10b Encoder Control Ports --------------
        TXCHARISK_IN          => GTX_TXCHARISK_IN(I),
        ------------------------- Transmit Ports - GTX Ports -----------------------
        GTXTEST_IN            => gtxtest_in,
        ------------------ Transmit Ports - TX Data Path interface -----------------
        TXDATA_IN             => GTX_TXDATA_IN(I),
        TXOUTCLK_OUT          => gtx_txoutclk_i(I),
        TXRESET_IN            => txreset_in,
        TXUSRCLK2_IN          => userclk(I),
        ---------------- Transmit Ports - TX Driver and OOB signaling --------------
        TXDIFFCTRL_IN         => "1101",
        TXN_OUT               => TXN_OUT(I),
        TXP_OUT               => TXP_OUT(I),
        TXPOSTEMPHASIS_IN     => "00000",
        --------------- Transmit Ports - TX Driver and OOB signalling --------------
        TXPREEMPHASIS_IN      => "0000",
        -------- Transmit Ports - TX Elastic Buffer and Phase Alignment Ports ------
        TXDLYALIGNDISABLE_IN  => gtx_txdlyaligndisable_i(I),
        TXDLYALIGNMONENB_IN   => gtx_txdlyalignmonenb_i(I),
        TXDLYALIGNMONITOR_OUT => open,
        TXDLYALIGNRESET_IN    => gtx_txdlyalignreset_i(I),
        TXENPMAPHASEALIGN_IN  => gtx_txenpmaphasealign_i(I),
        TXPMASETPHASE_IN      => gtx_txpmasetphase_i(I),
        ----------------------- Transmit Ports - TX PLL Ports ----------------------
        GTXTXRESET_IN         => gttx_reset_in(I),
        MGTREFCLKTX_IN        => mgt_refclk_i,
        PLLTXRESET_IN         => plltxreset_in,
        TXPLLLKDET_OUT        => pll_lock(I),
        TXRESETDONE_OUT       => gtx_txresetdone_i(I),
        --------------------- Transmit Ports - TX PRBS Generator -------------------
        TXENPRBSTST_IN        => txenprbstst_in,
        -- resets
        TXPOWERDOWN           => TXPOWERDOWN,
        TXPLLPOWERDOWN        => TXPLLPOWERDOWN
        );
  end generate;

  -------------------------- User Module Resets -----------------------------
  -- All the User Modules i.e. FRAME_GEN, FRAME_CHECK and the sync modules
  -- are held in reset till the RESETDONE goes high.
  -- The RESETDONE is registered a couple of times on USRCLK2 and connected
  -- to the reset of the modules

  reset_loop : for I in 0 to 3 generate
  begin
    gtx_reset_txsync_c(I) <= not gtx_txresetdone_r2(I);
    process(userclk(I), gtx_txresetdone_i(I))
    begin
      if(gtx_txresetdone_i(I) = '0') then
        gtx_txresetdone_r(I)  <= '0' after DLY;
        gtx_txresetdone_r2(I) <= '0' after DLY;
      elsif(userclk(I)'event and userclk(I) = '1') then
        gtx_txresetdone_r(I)  <= gtx_txresetdone_i(I) after DLY;
        gtx_txresetdone_r2(I) <= gtx_txresetdone_r(I) after DLY;
      end if;
    end process;
  end generate;

  sync_loop : for I in 0 to 3 generate
  begin
    gtx_txsync_inst : entity work.gtx_tx_sync
      generic map (
        SIM_TXPMASETPHASE_SPEEDUP => 1
        )
      port map (
        TXENPMAPHASEALIGN => gtx_txenpmaphasealign_i(I),
        TXPMASETPHASE     => gtx_txpmasetphase_i(I),
        TXDLYALIGNDISABLE => gtx_txdlyaligndisable_i(I),
        TXDLYALIGNRESET   => gtx_txdlyalignreset_i(I),
        SYNC_DONE         => gtx_tx_sync_done(I),
        USER_CLK          => userclk(I),
        RESET             => tx_sync_reset(I)
        );

    process (userclk(I)) is
    begin
      if (rising_edge(userclk(I))) then
        tx_sync_reset(I) <= gtx_reset_txsync_c(I) or realign;
      end if;
    end process;

  end generate;

  -----------------------Dedicated GTX Reference Clock Inputs ---------------

  q3_clk0_refclk_ibufds_i : IBUFDS_GTXE1
    port map (
      O     => mgt_refclk0,
      ODIV2 => open,
      CEB   => '0',
      I     => refclk_p(0),             -- Connect to package pin P6
      IB    => refclk_n(0)              -- Connect to package pin P5
      );

  q3_clk1_refclk_ibufds_i : IBUFDS_GTXE1
    port map (
      O     => mgt_refclk1,
      ODIV2 => open,
      CEB   => '0',
      I     => refclk_p(1),
      IB    => refclk_n(1)
      );

  outclkbufg : for I in 0 to 3 generate
  begin
    txoutclk_bufg0_i : BUFG
      port map (
        I => gtx_txoutclk_i(I),
        O => gtx_txoutclk(I)
        );
  end generate;

end Behavioral;
