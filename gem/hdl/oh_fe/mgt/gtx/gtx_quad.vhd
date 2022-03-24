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
    -- rx loopback
    loopback_mode_0 : in  std_logic_vector(2 downto 0);
    loopback_mode_1 : in  std_logic_vector(2 downto 0);
    loopback_mode_2 : in  std_logic_vector(2 downto 0);
    loopback_mode_3 : in  std_logic_vector(2 downto 0);
    rxpowerdown_in  : in  std_logic_vector(1 downto 0);
    rxreset_in      : in  std_logic;
    gtxrxreset_in   : in  std_logic;
    pllrxreset_in   : in  std_logic;
    rx_notintable_0 : out std_logic_vector (1 downto 0);
    rx_notintable_1 : out std_logic_vector (1 downto 0);
    rx_notintable_2 : out std_logic_vector (1 downto 0);
    rx_notintable_3 : out std_logic_vector (1 downto 0);
    rxvalid_out     : out std_logic_vector (3 downto 0);
    --
    plltxreset_in : in std_logic;

    refclk_p : in std_logic_vector (1 downto 0);
    refclk_n : in std_logic_vector (1 downto 0);

    userclk : in std_logic_vector (3 downto 0);

    gttx_reset_in : in  std_logic_vector(3 downto 0);
    TXN_OUT       : out std_logic_vector(3 downto 0);
    TXP_OUT       : out std_logic_vector(3 downto 0);

    gtx_txoutclk : out std_logic_vector(3 downto 0);

    pll_lock : out std_logic_vector (3 downto 0);

    gtx0_txcharisk_in : in std_logic_vector(1 downto 0);
    gtx1_txcharisk_in : in std_logic_vector(1 downto 0);
    gtx2_txcharisk_in : in std_logic_vector(1 downto 0);
    gtx3_txcharisk_in : in std_logic_vector(1 downto 0);

    gtx0_txdata_in : in std_logic_vector(15 downto 0);
    gtx1_txdata_in : in std_logic_vector(15 downto 0);
    gtx2_txdata_in : in std_logic_vector(15 downto 0);
    gtx3_txdata_in : in std_logic_vector(15 downto 0);

    tx_prbs_mode_0 : in std_logic_vector (2 downto 0);
    tx_prbs_mode_1 : in std_logic_vector (2 downto 0);
    tx_prbs_mode_2 : in std_logic_vector (2 downto 0);
    tx_prbs_mode_3 : in std_logic_vector (2 downto 0);

    txreset_in : in std_logic;

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

  signal gtx_txcharisk_in : t_std2_array (3 downto 0);

  signal tx_prbs_mode : t_std3_array(3 downto 0);

  signal rx_notintable : t_std2_array(3 downto 0);

  signal gtx_txdata_in : t_std16_array (3 downto 0);

  signal loopback_mode : t_std3_array (3 downto 0);

begin

  rx_notintable_0 <= rx_notintable(0);
  rx_notintable_1 <= rx_notintable(1);
  rx_notintable_2 <= rx_notintable(2);
  rx_notintable_3 <= rx_notintable(3);

  tx_prbs_mode(0) <= tx_prbs_mode_0;
  tx_prbs_mode(1) <= tx_prbs_mode_1;
  tx_prbs_mode(2) <= tx_prbs_mode_2;
  tx_prbs_mode(3) <= tx_prbs_mode_3;

  gtx_txcharisk_in(0) <= gtx0_txcharisk_in;
  gtx_txcharisk_in(1) <= gtx1_txcharisk_in;
  gtx_txcharisk_in(2) <= gtx2_txcharisk_in;
  gtx_txcharisk_in(3) <= gtx3_txcharisk_in;

  gtx_txdata_in(0) <= gtx0_txdata_in;
  gtx_txdata_in(1) <= gtx1_txdata_in;
  gtx_txdata_in(2) <= gtx2_txdata_in;
  gtx_txdata_in(3) <= gtx3_txdata_in;

  loopback_mode(0) <= loopback_mode_0;
  loopback_mode(1) <= loopback_mode_1;
  loopback_mode(2) <= loopback_mode_2;
  loopback_mode(3) <= loopback_mode_3;

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
        ------------------------ Loopback and Powerdown Ports ----------------------
        LOOPBACK_IN           => loopback_mode(I),
        RXPOWERDOWN_IN        => rxpowerdown_in,
        ----------------------- Receive Ports - 8b10b Decoder ----------------------
        RXCHARISK_OUT         => open,
        RXDISPERR_OUT         => open,
        RXNOTINTABLE_OUT      => rx_notintable(I),
        --------------- Receive Ports - Comma Detection and Alignment --------------
        RXENMCOMMAALIGN_IN    => '0',
        RXENPCOMMAALIGN_IN    => '0',
        ------------------- Receive Ports - RX Data Path interface -----------------
        RXDATA_OUT            => open,
        RXRESET_IN            => rxreset_in,
        RXUSRCLK2_IN          => userclk(I),
        ------- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
        RXN_IN                => '0',
        RXP_IN                => '1',
        -------- Receive Ports - RX Elastic Buffer and Phase Alignment Ports -------
        RXSTATUS_OUT          => open,
        ------------------------ Receive Ports - RX PLL Ports ----------------------
        GTXRXRESET_IN         => gtxrxreset_in,
        MGTREFCLKRX_IN        => mgt_refclk_i,
        PLLRXRESET_IN         => pllrxreset_in,
        RXPLLLKDET_OUT        => open,
        RXRESETDONE_OUT       => open,
        -------------- Receive Ports - RX Pipe Control for PCI Express -------------
        RXVALID_OUT           => rxvalid_out(i),
        ---------------- Transmit Ports - 8b10b Encoder Control Ports --------------
        TXCHARISK_IN          => gtx_txcharisk_in(i),
        ------------------------- Transmit Ports - GTX Ports -----------------------
        GTXTEST_IN            => gtxtest_in,
        ------------------ Transmit Ports - TX Data Path interface -----------------
        TXDATA_IN             => gtx_txdata_in(i),
        TXOUTCLK_OUT          => gtx_txoutclk_i(I),
        TXRESET_IN            => txreset_in,
        TXUSRCLK2_IN          => userclk(I),
        ---------------- Transmit Ports - TX Driver and OOB signaling --------------
        TXDIFFCTRL_IN         => "1101",
        TXN_OUT               => txn_out(i),
        TXP_OUT               => txp_out(I),
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
        TXENPRBSTST_IN        => tx_prbs_mode(I),
        -- resets
        TXPOWERDOWN_IN        => txpowerdown,
        TXPLLPOWERDOWN        => txpllpowerdown
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
