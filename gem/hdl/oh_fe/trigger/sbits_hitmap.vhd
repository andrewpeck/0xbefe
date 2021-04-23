----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration
-- Optohybrid v3 Firmware -- S-Bits hitmap
-- L. Pétré
----------------------------------------------------------------------------------
-- Description:
--   This module accumulates the full Sbits vector with minimal impact on PAR 
--   thanks to the use of fanouts and pipelines
----------------------------------------------------------------------------------
-- 2019/07/18 -- Initial
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.types_pkg.all;
use work.hardware_pkg.all;
use work.cluster_pkg.all;

entity sbits_hitmap is

  port(

    clock_i   : in  std_logic;
    reset_i   : in  std_logic;
    acquire_i : in  std_logic;
    sbits_i   : in  sbits_array_t(NUM_VFATS-1 downto 0);
    hitmap_o  : out sbits_array_t(NUM_VFATS-1 downto 0)

    );

end sbits_hitmap;

architecture sbits_hitmap of sbits_hitmap is

  -- Signal fanout (1 per IPBus register)
  signal reset   : std_logic_vector(2*NUM_VFATS-1 downto 0);
  signal acquire : std_logic_vector(2*NUM_VFATS-1 downto 0);

  -- Pipeline
  signal sbits_s0 : sbits_array_t(NUM_VFATS-1 downto 0);
  signal sbits_s1 : sbits_array_t(NUM_VFATS-1 downto 0);

  signal hitmap : sbits_array_t(NUM_VFATS-1 downto 0);

  -- Attributes for no simplification logic
  attribute equivalent_register_removal             : string;
  attribute equivalent_register_removal of reset    : signal is "no";
  attribute equivalent_register_removal of acquire  : signal is "no";
  attribute equivalent_register_removal of sbits_s0 : signal is "no";
  attribute equivalent_register_removal of sbits_s1 : signal is "no";

  attribute shreg_extract             : string;
  attribute shreg_extract of sbits_s0 : signal is "no";
  attribute shreg_extract of sbits_s1 : signal is "no";

begin

  -- Fanout
  process(clock_i)
  begin
    if rising_edge(clock_i) then
      reset   <= (others => reset_i);
      acquire <= (others => acquire_i);
    end if;
  end process;

  -- Pipeline
  process(clock_i)
  begin
    if rising_edge(clock_i) then
      sbits_s0 <= sbits_i;
      sbits_s1 <= sbits_s0;
    end if;
  end process;

  hitmap_g : for I in 0 to (NUM_VFATS - 1) generate
  begin
    process(clock_i)
    begin
      if rising_edge(clock_i) then
        for J in 0 to 1 loop
          if reset(2*I+J) = '1' then
            hitmap(I)((J+1)*32-1 downto J*32) <= (others => '0');
          else
            if acquire(2*I+J) = '1' then
              hitmap(I)((J+1)*32-1 downto J*32) <= hitmap(I)((J+1)*32-1 downto J*32) or sbits_s1(I)((J+1)*32-1 downto J*32);
            end if;
          end if;
        end loop;
      end if;
    end process;
  end generate;

  hitmap_o <= hitmap;

end sbits_hitmap;
