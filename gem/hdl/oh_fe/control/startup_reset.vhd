library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.types_pkg.all;

entity startup_reset is
  port(

    clock_i : in std_logic;

    mmcms_locked_i : in std_logic;
    idlyrdy_i      : in std_logic;
    gbt_rxready_i  : in std_logic;
    gbt_rxvalid_i  : in std_logic;
    gbt_txready_i  : in std_logic;

    reset_o : out std_logic
    );

end startup_reset;

architecture behavioral of startup_reset is

  constant STARTUP_RESET_CNT_MAX : integer := 1023;
  signal startup_reset_cnt : int_array_t (2 downto 0):= (others => 0);

  signal reset : std_logic_vector (2 downto 0);
  signal ready : std_logic;

  attribute DONT_TOUCH : string;
  attribute DONT_TOUCH of startup_reset_cnt  : signal is "true";

begin

  ready <= (idlyrdy_i  and mmcms_locked_i  and gbt_rxready_i  and gbt_rxvalid_i  and gbt_txready_i);

  tmr_loop : for I in 0 to 2 generate
  begin
    process(clock_i)
    begin
      if rising_edge(clock_i) then
        if (ready='0') then
          startup_reset_cnt(I) <= 0;
        elsif (startup_reset_cnt(I) < STARTUP_RESET_CNT_MAX) then
          startup_reset_cnt(I) <= startup_reset_cnt(I)+ 1;
        else
          startup_reset_cnt(I) <= startup_reset_cnt(I);
        end if;

        if (startup_reset_cnt(I) < STARTUP_RESET_CNT_MAX) then
          reset(I) <= '1';
        else
          reset(I) <= '0';
        end if;

      end if;
    end process;
  end generate;

  reset_o <= majority(reset(0), reset(1), reset(2));

end behavioral;
