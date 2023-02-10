library ieee;
use ieee.std_logic_1164.all;

entity clock_strobe is
  generic (
    RATIO : natural := 0
    );
  port(
    fast_clk_i : in  std_logic;
    slow_clk_i : in  std_logic;
    strobe_o   : out std_logic
    );
end clock_strobe;

architecture behavioral of clock_strobe is

  signal reg     : std_logic := '0';
  signal reg_dly1 : std_logic := '0';

  signal strobe : std_logic := '0';

  signal reg_delay_line : std_logic_vector (RATIO-1 downto 0);

  signal output_delay_line : std_logic_vector (RATIO-1 downto 0);

  attribute SHREG_EXTRACT               : string;
  attribute SHREG_EXTRACT of output_delay_line : signal is "NO";

begin

  assert RATIO/=0 report "Clock strobe must have its ratio set, can't be zero"
    severity error;

  --------------------------------------------------------------------------------
  -- Valid
  --------------------------------------------------------------------------------

  -- Create a 1 of n high signal synced to the slow clock, e.g.
  --
  --            ┌───────┐       ┌───────┐       ┌───────┐       ┌───
  -- clk40     ─┘       └───────┘       └───────┘       └───────┘
  --            ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐
  -- clk200    ─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─
  --            ┌───────────────┐               ┌───────────────┐
  -- reg       ─┘               └───────────────┘               └───
  --                ┌───────────────┐               ┌───────────────┐
  -- reg_dly   ─────┘               └───────────────┘               └───
  --            ┌───┐           ┌───┐           ┌───┐           ┌───┐
  -- strobe    ─┘   └───────────┘   └───────────┘   └───────────┘   └──
  --                            ┌───┐           ┌───┐           ┌───┐
  -- strobe_o  ─────────────────┘   └───────────┘   └───────────┘   └──

  process (slow_clk_i)
  begin
    if (rising_edge(slow_clk_i)) then
      reg <= not reg after 0.1 ns;      -- need delay in simulation to prevent race condition
    end if;
  end process;

  process (fast_clk_i)
  begin
    if (rising_edge(fast_clk_i)) then

      reg_dly1 <= reg after 0.1 ns;

      output_delay_line(0) <= strobe;
      reg_delay_line(0)    <= reg;

      for I in 1 to RATIO-1 loop
        reg_delay_line(I)    <= reg_delay_line(I-1);
        output_delay_line(I) <= output_delay_line(I-1);
      end loop;

    end if;
  end process;

  strobe <= reg_delay_line(0) xor not reg_delay_line(RATIO-1);

  strobe_o <= output_delay_line(RATIO-1);

end behavioral;
