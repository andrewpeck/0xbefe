library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

entity sbit_oneshot is
  port(
    clk : in  std_logic;
    d   : in  std_logic;
    q   : out std_logic
    );
end sbit_oneshot;

architecture behavioral of sbit_oneshot is
  signal last : std_logic := '0';
begin

  --            ┌────────────────────┐
  -- d         ─┘                    └──────
  --               ┌────────────────────┐
  -- last   ───────┘                    └──────
  --            ┌───┐
  -- d&!last ───┘   └────────────────────

  process (clk) is
  begin
    if (rising_edge(clk)) then
      last <= d;
    end if;
  end process;

  q <= d and not last;

end behavioral;
