library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;
library work;
use work.types_pkg.all;
use work.hardware_pkg.all;

entity iodelay is
  port(
    clock       : in  std_logic;
    data_i      : in  std_logic;
    data_o      : out std_logic;
    tap_delay_i : in  std_logic_vector (4 downto 0) := "00000"
    );
end iodelay;

architecture behavioral of iodelay is

begin

  ----------------------------------------------------------------------------------------------------------------------
  -- IODELAY
  ----------------------------------------------------------------------------------------------------------------------

  iodelay_v6 : if (FPGA_TYPE = "V6") generate

    iodelay : iodelaye1
      generic map(
        IDELAY_TYPE           => "VAR_LOADABLE",
        IDELAY_VALUE          => 0,     -- ignored in var_loadable
        HIGH_PERFORMANCE_MODE => true,
        REFCLK_FREQUENCY      => 200.803)
      port map(
        c           => clock,
        t           => '1',
        rst         => '1',
        ce          => '0',
        inc         => '0',
        cinvctrl    => '0',
        cntvaluein  => tap_delay_i,     -- 45 degree phase shift in 160 MHz clocks, using 78 ps taps
        clkin       => '0',
        idatain     => data_i,
        datain      => '0',
        odatain     => '0',
        dataout     => data_o,
        cntvalueout => open
        );
  end generate iodelay_v6;

  iodelay_a7 : if (FPGA_TYPE = "A7") generate

    iodelay_a7 : idelaye2
      generic map (
        CINVCTRL_SEL          => "FALSE",     -- Enable dynamic clock inversion (FALSE, TRUE)
        DELAY_SRC             => "IDATAIN",   -- Delay input (IDATAIN, DATAIN)
        HIGH_PERFORMANCE_MODE => "FALSE",     -- Reduced jitter ("TRUE"), Reduced power ("FALSE")
        IDELAY_TYPE           => "VAR_LOAD",  -- FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
        IDELAY_VALUE          => 0,           -- Input delay tap setting (0-31)
        PIPE_SEL              => "FALSE",     -- Select pipelined mode, FALSE, TRUE
        REFCLK_FREQUENCY      => 200.803,     -- IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
        SIGNAL_PATTERN        => "DATA"       -- DATA, CLOCK input signal
        )
      port map (
        CNTVALUEOUT => open,                  -- 5-bit output: Counter value output
        DATAOUT     => data_o,                -- 1-bit output: Delayed data output
        C           => clock,                 -- 1-bit input: Clock input
        CE          => '0',                   -- 1-bit input: Active high enable increment/decrement input
        CINVCTRL    => '0',                   -- 1-bit input: Dynamic clock inversion input
        CNTVALUEIN  => tap_delay_i,           -- 5-bit input: Counter value input
        DATAIN      => '0',                   -- 1-bit input: Internal delay data input
        IDATAIN     => data_i,                -- 1-bit input: Data input from the I/O
        INC         => '0',                   -- 1-bit input: Increment / Decrement tap delay input
        LD          => '1',                   -- 1-bit input: Load IDELAY_VALUE input
        LDPIPEEN    => '0',                   -- 1-bit input: Enable PIPELINE register to load data input
        REGRST      => '1'                    -- 1-bit input: Active-high reset tap-delay input
        );

  end generate iodelay_a7;

end behavioral;
