library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library unisim;
use unisim.vcomponents.all;

entity mmcm is
  generic (
    NUM_CLOCKS : integer := 4;

    CLK_SEL : integer := 1;

    F_VCO_MIN : real := 600.0;
    F_VCO_MAX : real := 1600.0;

    IN1_FREQ : real := 40.0;
    IN2_FREQ : real := 40.0;

    OUT0_FREQ : real := 40.0;
    OUT1_FREQ : real := 80.0;
    OUT2_FREQ : real := 160.0;
    OUT3_FREQ : real := 160.0;
    OUT4_FREQ : real := 200.0;
    OUT5_FREQ : real := 0.0;
    OUT6_FREQ : real := 0.0;

    OUT0_PHASE : real := 0.0;
    OUT1_PHASE : real := 0.0;
    OUT2_PHASE : real := 0.0;
    OUT3_PHASE : real := 90.0;
    OUT4_PHASE : real := 0.0;
    OUT5_PHASE : real := 0.0;
    OUT6_PHASE : real := 0.0;

    CLKOUT4_CASCADE : string := "FALSE";

    COMPENSATION : string := "ZHOLD";
    STARTUP_WAIT : string := "TRUE";
    BANDWIDTH    : string := "HIGH"
    );
  port (
    reset_i  : in  std_logic;
    clk_i    : in  std_logic_vector (1 downto 0);
    clk_o    : out std_logic_vector (NUM_CLOCKS-1 downto 0);
    locked_o : out std_logic
    );
end mmcm;

architecture Behavioral of mmcm is

  constant IN1_PERIOD : real := 1000.0/IN1_FREQ;

  --constant F_VCO : real := IN1_FREQ

  -- f_vco = f_clkin * M / D
  -- f_out = f_clkin * M / (D*O)

  signal clkfbout_logic_clocking     : std_logic;
  signal clkfbout_buf_logic_clocking : std_logic;

  signal do_unused           : std_logic_vector (15 downto 0);
  signal drdy_unused         : std_logic;
  signal psdone_unused       : std_logic;
  signal clkfboutb_unused    : std_logic;
  signal clkout0b_unused     : std_logic;
  signal clkout1b_unused     : std_logic;
  signal clkout2b_unused     : std_logic;
  signal clkout3b_unused     : std_logic;
  signal clkout5_unused      : std_logic;
  signal clkout6_unused      : std_logic;
  signal clkfbstopped_unused : std_logic;
  signal clkinstopped_unused : std_logic;

begin

  MMCME2_ADV_INST : MMCME2_ADV
    generic map (

      BANDWIDTH       => BANDWIDTH,
      CLKOUT4_CASCADE => CLKOUT4_CASCADE,
      COMPENSATION    => COMPENSATION,
      STARTUP_WAIT    => STARTUP_WAIT,

      CLKIN1_PERIOD => IN1_PERIOD,

      DIVCLK_DIVIDE => 1,

      CLKFBOUT_MULT_F      => 20.000,
      CLKFBOUT_PHASE       => 0.000,
      CLKFBOUT_USE_FINE_PS => "FALSE",

      CLKOUT0_DIVIDE_F    => 20.000,
      CLKOUT0_PHASE       => OUT0_PHASE,
      CLKOUT0_DUTY_CYCLE  => 0.500,
      CLKOUT0_USE_FINE_PS => "FALSE",

      CLKOUT1_DIVIDE      => 10,
      CLKOUT1_PHASE       => OUT1_PHASE,
      CLKOUT1_DUTY_CYCLE  => 0.500,
      CLKOUT1_USE_FINE_PS => "FALSE",

      CLKOUT2_DIVIDE      => 5,
      CLKOUT2_PHASE       => OUT2_PHASE,
      CLKOUT2_DUTY_CYCLE  => 0.500,
      CLKOUT2_USE_FINE_PS => "FALSE",

      CLKOUT3_DIVIDE      => 5,
      CLKOUT3_PHASE       => OUT3_PHASE,
      CLKOUT3_DUTY_CYCLE  => 0.500,
      CLKOUT3_USE_FINE_PS => "FALSE",

      CLKOUT4_DIVIDE      => 4,
      CLKOUT4_PHASE       => OUT4_PHASE,
      CLKOUT4_DUTY_CYCLE  => 0.500,
      CLKOUT4_USE_FINE_PS => "FALSE",

      CLKOUT5_DIVIDE      => 4,
      CLKOUT5_PHASE       => OUT4_PHASE,
      CLKOUT5_DUTY_CYCLE  => 0.500,
      CLKOUT5_USE_FINE_PS => "FALSE",

      CLKOUT6_DIVIDE      => 4,
      CLKOUT6_PHASE       => OUT4_PHASE,
      CLKOUT6_DUTY_CYCLE  => 0.500,
      CLKOUT6_USE_FINE_PS => "FALSE"

      )
    port map(
      -- Output clocks
      CLKFBOUT  => clkfbout_logic_clocking,
      CLKFBOUTB => clkfboutb_unused,
      CLKOUT0   => clk(0),
      CLKOUT1   => clk(1),
      CLKOUT2   => clk(2),
      CLKOUT3   => clk(3),
      CLKOUT4   => clk(4),
      CLKOUT5   => clkout5_unused,
      CLKOUT6   => clkout6_unused,
      CLKOUT0B  => clkout0b_unused,
      CLKOUT1B  => clkout1b_unused,
      CLKOUT2B  => clkout2b_unused,
      CLKOUT3B  => clkout3b_unused,
      -- Input clock control
      CLKFBIN   => clkfbout_buf_logic_clocking,
      CLKIN1    => clk_in(0),
      CLKIN2    => clk_in(1),
      -- Tied to always select the primary input clock
      CLKINSEL  => CLK_SEL,             -- high=1, low=2

      -- Ports for dynamic reconfiguration
      DADDR => (others => '0'),
      DCLK  => '0',
      DEN   => '0',
      DI    => (others => '0'),
      DO    => do_unused,
      DRDY  => drdy_unused,
      DWE   => '0',

      -- Ports for dynamic phase shift
      PSCLK    => '0',
      PSEN     => '0',
      PSINCDEC => '0',
      PSDONE   => psdone_unused,

      -- Other control and status signals
      LOCKED       => locked_o,
      CLKINSTOPPED => clkinstopped_unused,
      CLKFBSTOPPED => clkfbstopped_unused,
      PWRDWN       => '0',
      RST          => reset_i
      );

  -- Clock Monitor clock assigning
  ----------------------------------------
  -- Output buffering
  -------------------------------------

  clkf_buf : BUFG
    port map (
      O => clkfbout_buf_logic_clocking,
      I => clkfbout_logic_clocking
      );

  bufg_gen : for I in 0 to NUM_CLOCKS-1 generate
    out_buf : BUFG
      port map (
        I => clk(I),
        O => clk_o(I)
        );
  end generate bufg_gen;

end Behavioral;
