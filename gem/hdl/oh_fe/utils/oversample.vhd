-- TODO: fix reset for inverted pairs (outputs burst of 1's)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity oversample is
  generic (
    g_ENABLE_TMR_DRU     : integer := 0;
    g_PHASE_SEL_EXTERNAL : boolean := false;
    g_NUM_TAPS_45        : integer := 10
    );
  port(
    clk1x_logic : in std_logic;
    clk1x       : in std_logic;
    clk4x_0     : in std_logic;
    clk4x_90    : in std_logic;

    reset_i : in std_logic;

    rxd_p    : in  std_logic;
    rxd_n    : in  std_logic;
    rxdata_o : out std_logic_vector (7 downto 0);

    invert      : in std_logic                     := '0';
    tap_delay_i : in std_logic_vector (4 downto 0) := "00000";

    e4_in         : in  std_logic_vector (3 downto 0) := "0000";
    e4_out        : out std_logic_vector (3 downto 0);
    phase_sel_in  : in  std_logic_vector (1 downto 0) := "00";
    phase_sel_out : out std_logic_vector (1 downto 0);

    invalid_bitskip_o : out std_logic;

    tmr_err_o : out std_logic := '0'
    );
end oversample;

architecture behavioral of oversample is

  signal reset_serdes   : std_logic;
  signal reset_output   : std_logic_vector(3 downto 0);
  signal data_p, data_n : std_logic;
  signal q              : std_logic_vector(7 downto 0);
  signal rxdata         : std_logic_vector(7 downto 0) := (others => '0');
  signal rxdata_inv     : std_logic_vector(7 downto 0) := (others => '0');
  signal data           : std_logic_vector(1 downto 0);
  signal tap_delay      : std_logic_vector (tap_delay_i'high downto 0);
  signal tap_delay_0    : std_logic_vector (tap_delay_i'high downto 0);
  signal tap_delay_45   : std_logic_vector (tap_delay_i'high downto 0);

  attribute ASYNC_REG              : string;
  attribute ASYNC_REG of tap_delay : signal is "TRUE";

begin

  ----------------------------------------------------------------------------------------------------------------------
  -- Reset
  ----------------------------------------------------------------------------------------------------------------------

  process(clk4x_0)
  begin
    if rising_edge(clk4x_0) then
      reset_serdes <= reset_i;
    end if;
  end process;

  process(clk1x)
  begin
    if rising_edge(clk1x) then
      if reset_i = '1' then
        reset_output <= (others => '1');
      else
        reset_output <= reset_output(reset_output'high-1 downto reset_output'low) & '0';
      end if;
    end if;
  end process;

  ----------------------------------------------------------------------------------------------------------------------
  -- Tap Delay Addition
  ----------------------------------------------------------------------------------------------------------------------

  process(clk1x_logic)
  begin
    if rising_edge(clk1x_logic) then
      tap_delay    <= tap_delay_i;
      tap_delay_0  <= tap_delay;
      tap_delay_45 <= std_logic_vector (unsigned(tap_delay) + to_unsigned(g_NUM_TAPS_45, tap_delay'length));
    end if;
  end process;

  ----------------------------------------------------------------------------------------------------------------------
  -- IBUFDS
  ----------------------------------------------------------------------------------------------------------------------

  rx_ibuf_d : ibufds_diff_out
    generic map(
      IBUF_LOW_PWR => true,
      DIFF_TERM    => true,
      IOSTANDARD   => "LVDS_25")
    port map(
      i  => rxd_p,
      ib => rxd_n,
      o  => data_p,
      ob => data_n
      );

  ----------------------------------------------------------------------------------------------------------------------
  -- IODELAY in FPGA agnostic wrapper
  ----------------------------------------------------------------------------------------------------------------------

  delay_master : entity work.iodelay
    port map(
      clock       => clk1x_logic,
      tap_delay_i => tap_delay_0,
      data_i      => data_p,
      data_o      => data(0)
      );

  delay_slave : entity work.iodelay
    port map(
      clock       => clk1x_logic,
      tap_delay_i => tap_delay_45,
      data_i      => data_n,
      data_o      => data(1)
      );

  ----------------------------------------------------------------------------------------------------------------------
  -- ISERDES in FPGA agnostic wrapper
  ----------------------------------------------------------------------------------------------------------------------

  ise1_m : entity work.iserdes
    port map(
      clk_i     => clk4x_0,
      clk_90_i  => clk4x_90,
      reset_i   => reset_serdes,
      data_i    => data(0),
      data_o(0) => q(1),
      data_o(1) => q(5),
      data_o(2) => q(3),
      data_o(3) => q(7)
      );

  ise1_s : entity work.iserdes
    port map(
      clk_i     => clk4x_0,
      clk_90_i  => clk4x_90,
      reset_i   => reset_serdes,
      data_i    => data(1),
      data_o(0) => q(0),
      data_o(1) => q(4),
      data_o(2) => q(2),
      data_o(3) => q(6)
      );

  ----------------------------------------------------------------------------------------------------------------------
  -- Data Recovery Unit
  ----------------------------------------------------------------------------------------------------------------------

  dru : entity work.dru_tmr
    generic map(
      g_ENABLE_TMR         => g_ENABLE_TMR_DRU,
      g_PHASE_SEL_EXTERNAL => g_PHASE_SEL_EXTERNAL
      )
    port map(
      clk1x => clk1x,
      clk4x => clk4x_0,

      i => q,                           -- the even bits are inverted!
      o => rxdata,                      -- 8-bit deserialized data

      e4_in         => e4_in,
      e4_out        => e4_out,
      phase_sel_in  => phase_sel_in,
      phase_sel_out => phase_sel_out,

      invalid_bitskip_o => invalid_bitskip_o,

      tmr_err_o => tmr_err_o
      );

  rxdata_inv <= rxdata when invert = '0' else not rxdata;

  rxdata_o <= (others => '0') when reset_output(reset_output'high) = '1' else rxdata_inv(7 downto 0);

end behavioral;
