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
use work.cluster_pkg.all;

entity active_vfats is
  port(
    clock          : in  std_logic;
    sbits_i        : in  sbits_array_t(NUM_VFATS-1 downto 0);
    active_vfats_o : out std_logic_vector (NUM_VFATS-1 downto 0)
    );
end active_vfats;

architecture Behavioral of active_vfats is

  type sbits_or_s1_t is array (integer range 0 to NUM_VFATS-1)
    of std_logic_vector(7 downto 0);

  signal active_vfats_s1 : sbits_or_s1_t;

  signal sbits : std_logic_vector (MXSBITS_CHAMBER-1 downto 0);

begin

  --------------------------------------------------------------------------------------------------------------------
  -- Active VFAT Flags
  --------------------------------------------------------------------------------------------------------------------

  -- want to generate 24 bits as active VFAT flags, indicating that at least one s-bit on that VFAT
  -- was active in this 40MHz cycle

  -- I don't want to do 64 bit reduction in 1 clock... split it over 2 to add slack to PAR and timing

  active_vfat_s1_vfat : for I in 0 to NUM_VFATS-1 generate
    active_vfat_s1_sbit : for J in 0 to 7 generate
    begin
      process (clock)
      begin
        if (rising_edge(clock)) then
          active_vfats_s1 (I)(J) <= or_reduce (sbits_i(I)(8*(J+1)-1 downto (8*J)));
        end if;
      end process;
    end generate;
  end generate;

  active_vfat_s2 : for I in 0 to (NUM_VFATS-1) generate
  begin
    process (clock)
    begin
      if (rising_edge(clock)) then
        active_vfats_o (I) <= or_reduce (active_vfats_s1 (I));
      end if;
    end process;
  end generate;

end Behavioral;
