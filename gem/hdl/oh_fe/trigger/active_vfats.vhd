----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid v3 Firmware -- Active VFATs
-- A. Peck
----------------------------------------------------------------------------------
-- Description:
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;


library work;
use work.types_pkg.all;
use work.hardware_pkg.all;

entity active_vfats is
  port(
    clock          : in  std_logic;
    sbits_i        : in  std_logic_vector (MXSBITS_CHAMBER-1 downto 0);
    active_vfats_o : out std_logic_vector (NUM_VFATS-1 downto 0)
    );
end active_vfats;

architecture Behavioral of active_vfats is

  signal sbits           : std_logic_vector (MXSBITS_CHAMBER-1 downto 0);
  signal active_vfats_s1 : std_logic_vector (NUM_VFATS*8-1 downto 0);

begin

  --------------------------------------------------------------------------------------------------------------------
  -- Active VFAT Flags
  --------------------------------------------------------------------------------------------------------------------

  process (clock)
  begin
    if (rising_edge(clock)) then
      sbits <= sbits_i;
    end if;
  end process;

  -- want to generate 24 bits as active VFAT flags, indicating that at least one s-bit on that VFAT
  -- was active in this 40MHz cycle

  -- I don't want to do 64 bit reduction in 1 clock... split it over 2 to add slack to PAR and timing

  active_vfat_s1 : for I in 0 to (NUM_VFATS*8-1) generate
  begin
    process (clock)
    begin
      if (rising_edge(clock)) then
        active_vfats_s1 (I) <= or_reduce (sbits (8*(I+1)-1 downto (8*I)));
      end if;
    end process;
  end generate;

  active_vfat_s2 : for I in 0 to (NUM_VFATS-1) generate
  begin
    process (clock)
    begin
      if (rising_edge(clock)) then
        active_vfats_o (I) <= or_reduce (active_vfats_s1 (8*(I+1)-1 downto (8*I)));
      end if;
    end process;
  end generate;

end Behavioral;

