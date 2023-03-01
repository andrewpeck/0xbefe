library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.types_pkg.all;
use work.ipbus_pkg.all;

entity dru_tmr is

  generic (
    g_ENABLE_TMR         : integer := 0;
    g_PHASE_SEL_EXTERNAL : boolean := false
    );
  port(

    clk1x : in std_logic;               -- 40 MHz clock
    clk4x : in std_logic;               -- 160 MHz clock

    reset : in std_logic;

    i : in  std_logic_vector(7 downto 0);  -- 8-bit input, the even bits are inverted!
    o : out std_logic_vector(7 downto 0);  -- 8-bit recovered output

    e4_in         : in  std_logic_vector (3 downto 0);
    e4_out        : out std_logic_vector (3 downto 0);
    phase_sel_in  : in  std_logic_vector (1 downto 0);
    phase_sel_out : out std_logic_vector (1 downto 0);

    invalid_bitskip_o : out std_logic;

    tmr_err_o : out std_logic := '0'

    );

end dru_tmr;

architecture behavioral of dru_tmr is
  signal tmr_err : std_logic_vector (3 downto 0) := (others => '0');
begin

  process (clk1x) is
  begin
    if (rising_edge(clk1x)) then
      tmr_err_o <= or_reduce(tmr_err);
    end if;
  end process;

  NO_TMR : if (g_ENABLE_TMR = 0) generate
    dru : entity work.dru
      generic map(
        g_PHASE_SEL_EXTERNAL => g_PHASE_SEL_EXTERNAL
        )
      port map(
        reset => reset,
        clk1x => clk1x,
        clk4x => clk4x,

        i => i,                         -- the even bits are inverted!
        o => o,                         -- 8-bit deserialized data

        e4_in         => e4_in,
        e4_out        => e4_out,
        phase_sel_in  => phase_sel_in,
        phase_sel_out => phase_sel_out,

        invalid_bitskip_o => invalid_bitskip_o
        );
  end generate NO_TMR;

  TMR : if (g_ENABLE_TMR = 1) generate

    signal o_tmr               : t_std8_array (2 downto 0);
    signal phase_sel_tmr       : t_std2_array (2 downto 0);
    signal e4_tmr              : t_std4_array (2 downto 0);
    signal invalid_bitskip_tmr : std_logic_vector (2 downto 0);

    attribute DONT_TOUCH : string;

    attribute DONT_TOUCH of o_tmr               : signal is "true";
    attribute DONT_TOUCH of phase_sel_tmr       : signal is "true";
    attribute DONT_TOUCH of e4_tmr              : signal is "true";
    attribute DONT_TOUCH of invalid_bitskip_tmr : signal is "true";
  begin

    tmr_loop : for J in 0 to 2 generate
    begin
      dru : entity work.dru
        generic map(
          g_TMR_INSTANCE       => J,
          g_PHASE_SEL_EXTERNAL => g_PHASE_SEL_EXTERNAL
          )
        port map(
          reset        => reset,
          clk1x        => clk1x,
          clk4x        => clk4x,
          e4_in        => e4_in,
          i            => i,            -- the even bits are inverted!
          phase_sel_in => phase_sel_in,

          o                 => o_tmr(J),  -- 8-bit deserialized data
          e4_out            => e4_tmr(J),
          phase_sel_out     => phase_sel_tmr(J),
          invalid_bitskip_o => invalid_bitskip_tmr(J)
          );

    end generate;

    majority_err (o, tmr_err(0), o_tmr(0), o_tmr(1), o_tmr(2));
    majority_err (e4_out, tmr_err(1), e4_tmr(0), e4_tmr(1), e4_tmr(2));
    majority_err (phase_sel_out, tmr_err(2), phase_sel_tmr(0), phase_sel_tmr(1), phase_sel_tmr(2));
    majority_err (invalid_bitskip_o, tmr_err(3), invalid_bitskip_tmr(0), invalid_bitskip_tmr(1), invalid_bitskip_tmr(2));

  end generate TMR;

end behavioral;
