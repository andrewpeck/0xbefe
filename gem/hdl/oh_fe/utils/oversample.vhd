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
    g_DDR_MODE           : integer := 0
    );
  port(
    clk40     : in std_logic;
    clk80     : in std_logic := '0';
    clk160_0  : in std_logic := '0';
    clk160_90 : in std_logic := '0';
    clk320_0  : in std_logic := '0';
    clk320_90 : in std_logic := '0';
    clk40_lac : in std_logic := '0';

    reset_i : in std_logic;

    rxd_p    : in  std_logic;
    rxd_n    : in  std_logic;
    rxdata_o : out std_logic_vector (8*(g_DDR_MODE+1)-1 downto 0);

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

  signal clk_io_0  : std_logic;         -- 160 MHz for SDR; 320MHz for DDR
  signal clk_io_90 : std_logic;         -- 160 MHz for SDR; 320MHz for DDR

  signal clk_1x_dru : std_logic := '0';  --  40 MHz for SDR; 80  MHz for DDR
  signal clk_4x_dru : std_logic := '0';  -- 160 MHz for SDR; 320 MHz for DDR

  -- ISERDES does not support x16, so for DDR mode we need to run the DRU
  -- at 80MHz and then pack 2 80 MHz words into 1 40 MHz word
  -- 8 bits / bx for SDR; 16 bits / bx for DDR
  signal rxdata_demux : std_logic_vector (8*(g_DDR_MODE+1)-1 downto 0)
    := (others => '0');

  -- number of taps for 45 degrees is 10 for 320 MHz, 5 for 640 Mhz
  constant NUM_TAPS_45 : integer := 10 / (1 + g_DDR_MODE);

  signal reset_serdes    : std_logic;
  signal reset_output_sr : std_logic_vector(3 downto 0);
  signal reset_output    : std_logic;

  signal data_p, data_n : std_logic;                     -- outputs from the ibufds_diff_out
  signal data           : std_logic_vector(1 downto 0);  -- output from iodelay

  signal q : std_logic_vector(7 downto 0);  -- outputs from iserdes

  signal rxdata     : std_logic_vector(7 downto 0) := (others => '0');  -- output from dru
  signal rxdata_inv : std_logic_vector(7 downto 0) := (others => '0');  -- optionally inverted output from dru

  -- tap delay settings for 0/45 degress + offset
  signal tap_delay    : std_logic_vector (tap_delay_i'high downto 0);
  signal tap_delay_0  : std_logic_vector (tap_delay_i'high downto 0);
  signal tap_delay_45 : std_logic_vector (tap_delay_i'high downto 0);

begin

  sdr_clks : if (g_DDR_MODE = 0) generate
    clk_1x_dru <= clk40;
    clk_4x_dru <= clk160_0;
    clk_io_0   <= clk160_0;
    clk_io_90  <= clk160_90;
  end generate;

  ddr_clks : if (g_DDR_MODE = 1) generate
    clk_1x_dru <= clk80;
    clk_4x_dru <= clk320_0;
    clk_io_0   <= clk320_0;
    clk_io_90  <= clk320_90;
  end generate;

  ----------------------------------------------------------------------------------------------------------------------
  -- Reset
  ----------------------------------------------------------------------------------------------------------------------

  process(clk_io_0)
  begin
    if rising_edge(clk_io_0) then
      reset_serdes <= reset_i;
    end if;
  end process;

  process(clk40)
  begin
    if rising_edge(clk40) then
      if reset_i = '1' then
        reset_output_sr <= (others => '1');
      else
        reset_output_sr <= reset_output_sr(reset_output_sr'high-1 downto reset_output_sr'low) & '0';
      end if;
    end if;
  end process;

  ----------------------------------------------------------------------------------------------------------------------
  -- Tap Delay Addition
  ----------------------------------------------------------------------------------------------------------------------

  process(clk40)
  begin
    if rising_edge(clk40) then
      tap_delay   <= tap_delay_i;
      tap_delay_0 <= tap_delay;
      tap_delay_45 <= std_logic_vector (unsigned(tap_delay)
                                        + to_unsigned(NUM_TAPS_45, tap_delay'length));
    end if;
  end process;

  ----------------------------------------------------------------------------------------------------------------------
  -- IBUFDS
  ----------------------------------------------------------------------------------------------------------------------

  rx_ibuf_d : ibufds_diff_out
    generic map(
      IBUF_LOW_PWR => true,
      DIFF_TERM    => true,
      IOSTANDARD   => "LVDS_25"
      )
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
      clock       => clk40,
      tap_delay_i => tap_delay_0,
      data_i      => data_p,
      data_o      => data(0)
      );

  delay_slave : entity work.iodelay
    port map(
      clock       => clk40,
      tap_delay_i => tap_delay_45,
      data_i      => data_n,
      data_o      => data(1)
      );

  ----------------------------------------------------------------------------------------------------------------------
  -- ISERDES in FPGA agnostic wrapper
  ----------------------------------------------------------------------------------------------------------------------

  ise1_m : entity work.iserdes
    port map(
      clk_i     => clk_io_0,
      clk_90_i  => clk_io_90,
      reset_i   => reset_serdes,
      data_i    => data(0),
      data_o(0) => q(1),
      data_o(1) => q(5),
      data_o(2) => q(3),
      data_o(3) => q(7)
      );

  ise1_s : entity work.iserdes
    port map(
      clk_i     => clk_io_0,
      clk_90_i  => clk_io_90,
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

      clk1x => clk_1x_dru,
      clk4x => clk_4x_dru,

      i => q,                           -- the even bits are inverted!
      o => rxdata,                      -- 8-bit deserialized data

      e4_in         => e4_in,
      e4_out        => e4_out,
      phase_sel_in  => phase_sel_in,
      phase_sel_out => phase_sel_out,

      invalid_bitskip_o => invalid_bitskip_o,

      tmr_err_o => tmr_err_o
      );

  -- optionally invert the data, since some of the s-bit pairs are polarity swapped
  rxdata_inv <= rxdata when invert = '0' else not rxdata;

  -- for sdr mode, output width is the same as dru width
  sdr_o : if (g_DDR_MODE = 0) generate
    rxdata_demux <= rxdata_inv;
  end generate;

  -- for ddr mode, convert from 8 bits at 80Mhz to 16 bits at 40MHz
  ddr_o : if (g_DDR_MODE = 1) generate
    process (clk_1x_dru) is              -- 80MHz
    begin
      if (rising_edge(clk_1x_dru)) then  -- 80MHz
        if (clk40 = '1') then
          rxdata_demux(15 downto 8) <= rxdata_inv;
        else
          rxdata_demux(7 downto 0) <= rxdata_inv;
        end if;
      end if;
    end process;
  end generate;

  reset_output <= '1' when reset_output_sr(reset_output_sr'high) = '1' else '0';

  -- reset for the output ffs
  process (clk40) is
  begin
    if (rising_edge(clk40)) then
      if (reset_output = '1') then
        rxdata_o <= (others => '0');
      else
        rxdata_o <= rxdata_demux;
      end if;
      -- rxdata_o <= q;
    end if;
  end process;

end behavioral;
