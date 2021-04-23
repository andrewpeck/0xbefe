library ieee;
use ieee.std_logic_1164.all;

entity clock_strobe is
  port(
    fast_clk_i : in  std_logic;
    slow_clk_i : in  std_logic;
    strobe_o   : out std_logic
    );
end clock_strobe;

architecture behavioral of clock_strobe is
  signal reg     : std_logic_vector (2 downto 0) := "000";
  signal reg_dly : std_logic_vector (2 downto 0) := "000";

  attribute DONT_TOUCH            : string;
  attribute DONT_TOUCH of reg     : signal is "true";
  attribute DONT_TOUCH of reg_dly : signal is "true";

  function majority (a : std_logic; b : std_logic; c : std_logic)
    return std_logic is
    variable tmp : std_logic;
  begin
    tmp := (a and b) or (b and c) or (a and c);
    return tmp;
  end function;

begin
  --------------------------------------------------------------------------------
  -- Valid
  --------------------------------------------------------------------------------

  -- Create a 1 of n high signal synced to the slow clock, e.g.
  --            ________________              _____________
  -- clk40    __|              |______________|
  --            _______________________________
  -- r        __|                             |_____________
  --                   _______________________________
  -- r_dly    ___________|                             |_____________
  --            __________                    __________
  -- valid    __|        |____________________|        |______

  process (slow_clk_i)
  begin
    if (rising_edge(slow_clk_i)) then
      reg <= not reg after 0.1 ns; -- need delay in simulation to prevent race condition
    end if;
  end process;

  process (fast_clk_i)
  begin
    if (rising_edge(fast_clk_i)) then
      reg_dly <= reg;
    end if;
  end process;

  strobe_o <= majority (
    (reg_dly(0) xor reg(0)),
    (reg_dly(1) xor reg(1)),
    (reg_dly(2) xor reg(2))
    );

end behavioral;
