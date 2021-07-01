----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid v3 Firmware -- Counter
-- T. Lenzi, A. Peck
----------------------------------------------------------------------------------
-- Description:
--   This module implements base level functionality for a single counter
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.types_pkg.all;

entity counter_snap_tmr is
  generic (
    g_COUNTER_WIDTH  : integer := 32;
    g_ALLOW_ROLLOVER : boolean := false;
    g_INCREMENT_STEP : integer := 1
    );
  port(

    ref_clk_i : in std_logic;
    reset_i   : in std_logic;

    en_i : in std_logic;

    snap_i : in std_logic;

    count_o : out std_logic_vector(g_COUNTER_WIDTH-1 downto 0)

    );
end counter_snap_tmr;

architecture Behavioral of counter_snap_tmr is
  type count_array_t is array (integer range 0 to 2)
    of std_logic_vector(g_COUNTER_WIDTH-1 downto 0);
  signal count : count_array_t;
begin

  tmrgen : for I in 0 to 2 generate
  begin
    counter_snap_inst : entity work.counter_snap
      generic map (
        g_TMR_INST       => I,
        g_COUNTER_WIDTH  => g_COUNTER_WIDTH,
        g_ALLOW_ROLLOVER => g_ALLOW_ROLLOVER,
        g_INCREMENT_STEP => g_INCREMENT_STEP)
      port map (
        ref_clk_i => ref_clk_i,
        reset_i   => reset_i,
        en_i      => en_i,
        snap_i    => snap_i,
        count_o   => count(I)
        );
  end generate;

  count_o <= majority(count(0), count(1), count(2));

end Behavioral;
