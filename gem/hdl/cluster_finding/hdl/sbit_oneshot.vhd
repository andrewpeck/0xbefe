library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

entity sbit_oneshot is
  generic(
    DEADTIME : natural := 0
    );
  port(
    clk : in  std_logic;
    d   : in  std_logic;
    q   : out std_logic
    );
end sbit_oneshot;

architecture behavioral of sbit_oneshot is
  signal busy     : std_logic                   := '0';
  signal busy_cnt : natural range 0 to DEADTIME := 0;
begin

  os : if (DEADTIME = 0) generate
    process (clk) is
    begin
      if (rising_edge(clk)) then
        if (d = '1') then
          busy <= '1';
        else
          busy <= '0';
        end if;
      end if;
    end process;
  end generate;

  dead : if (DEADTIME > 0) generate

    busy <= '0' when (busy_cnt = 0) else '1';

    process (clk) is
    begin
      if (rising_edge(clk)) then
        if (busy = '0' and d = '1') then
          busy_cnt <= DEADTIME;
        elsif (busy_cnt > 0) then
          busy_cnt <= busy_cnt - 1;
        end if;
      end if;
    end process;
  end generate;

  q <= d and not busy;

end behavioral;
