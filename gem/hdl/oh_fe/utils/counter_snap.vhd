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

entity counter_snap is
  generic (
    g_TMR_INST       : integer := 0;
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
end counter_snap;

architecture Behavioral of counter_snap is

  constant max_count : unsigned (g_COUNTER_WIDTH - 1 downto 0) := (others => '1');
  signal count       : unsigned (g_COUNTER_WIDTH - 1 downto 0);
  signal reset       : std_logic;
  signal count_copy  : std_logic_vector(g_COUNTER_WIDTH-1 downto 0) := (others => '0');

begin

  count_o <= count_copy;

  process (ref_clk_i)
  begin
    if (rising_edge(ref_clk_i)) then
      reset <= reset_i;
    end if;
  end process;

  process(ref_clk_i)
  begin
    if (rising_edge(ref_clk_i)) then
      if (reset = '1') then
        count      <= (others => '0');
        -- Do NOT reset the count_copy; it needs to be stable across resets
      else
        if en_i = '1' and (count < max_count or g_ALLOW_ROLLOVER) then
          count <= count + g_INCREMENT_STEP;
        end if;

        if (snap_i = '1') then
          count_copy <= std_logic_vector(count);
        else
          count_copy <= count_copy;
        end if;

      end if;
    end if;
  end process;

end Behavioral;
