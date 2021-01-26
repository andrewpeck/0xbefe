----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid v3 Firmware -- Rate Counter
-- E. Juska, A. Peck
----------------------------------------------------------------------------------
-- Description:
--   This module counts the rate in Hz of a given signal
--   the rate is output both as a rate (in Hertz) as well as a "thermometer" style
--   output with indicator corresponding to a generic-defined step size
----------------------------------------------------------------------------------
-- 2017/08/02 -- Initial working version with thermometer adapted from CTP-7
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity progress_bar is
  generic(
    g_LOGARITHMIC        : natural := 1;
    g_CLK_FREQUENCY      : natural := 40079000;
    g_COUNTER_WIDTH      : natural := 26;  --
    g_INCREMENTER_WIDTH  : natural := 11;  -- allow for incrementing more than 1 step per clock
    g_PROGRESS_BAR_WIDTH : natural := 13;  -- number of indicators in the bar (FULLSCALE = WIDTH*STEP)
    g_PROGRESS_BAR_STEP  : natural := 20_000;  -- hertz per indicator
    g_SPEEDUP_FACTOR     : natural := 19  -- changes the "refresh" rate of the indicator by sampling at a higher rate
                                          -- each step is a power-of-two speedup 0=1hz, 1=2hz, 2=4hz, 3=8hz, etc
    );
  port(
    clk_i          : in  std_logic;
    reset_i        : in  std_logic;
    increment_i    : in  std_logic_vector(g_INCREMENTER_WIDTH - 1 downto 0)  := (others => '0');  -- step size input
    rate_o         : out std_logic_vector(g_COUNTER_WIDTH - 1 downto 0)      := (others => '0');  -- rate in Hz
    progress_bar_o : out std_logic_vector(g_PROGRESS_BAR_WIDTH - 1 downto 0) := (others => '0')  -- thermometer of rate
    );
end progress_bar;

architecture progress_bar_arch of progress_bar is

  constant max_count : unsigned(g_COUNTER_WIDTH - 1 downto 0)     := (others => '1');
  signal count       : unsigned(31 downto 0)                      := (others => '0');
  signal increment   : unsigned(g_INCREMENTER_WIDTH - 1 downto 0) := (others => '0');
  signal timer       : unsigned(31 downto 0)                      := x"ffffffff";
  signal time_max    : unsigned(31 downto 0);

  -- cast to unsigned to use in ISIM (isim doesn't support Radix on integers / naturals
  constant clk_frequency     : unsigned (31 downto 0) := to_unsigned(g_CLK_FREQUENCY, 32);
  constant speedup_factor    : unsigned (31 downto 0) := to_unsigned(g_SPEEDUP_FACTOR, 32);
  constant progress_bar_step : unsigned (31 downto 0) := to_unsigned(g_PROGRESS_BAR_STEP, 32);

  signal rate : unsigned (g_COUNTER_WIDTH-1 downto 0) := (others => '0');

begin


  time_max <= shift_right(clk_frequency, g_SPEEDUP_FACTOR);  -- sll divides by speedup

  increment <= unsigned(increment_i);

  p_count :
  process (clk_i) is
  begin
    if rising_edge(clk_i) then

      if reset_i = '1' then
        count <= (others => '0');
        timer <= (others => '0');
        rate  <= (others => '0');
      else
        if (timer < time_max) then
          timer <= timer + 1;
          count <= count + increment;
        else

          -- restart counter
          timer <= (others => '0');
          count <= (others => '0');

          -- rate output
          rate <= shift_left(count, g_SPEEDUP_FACTOR) (g_COUNTER_WIDTH-1 downto 0);

        end if;
      end if;

      -- progress bar indicators
      for i in 0 to (g_PROGRESS_BAR_WIDTH - 1) loop
        if (g_LOGARITHMIC > 0) then
          if (rate >= (10**i)) then
            progress_bar_o(i) <= '1';
          else
            progress_bar_o(i) <= '0';
          end if;
        else
          if (rate > (progress_bar_step * (i + 1))) then
            progress_bar_o(i) <= '1';
          else
            progress_bar_o(i) <= '0';
          end if;
        end if;
      end loop;

    end if;
  end process;

  rate_o <= std_logic_vector(rate);

end progress_bar_arch;
