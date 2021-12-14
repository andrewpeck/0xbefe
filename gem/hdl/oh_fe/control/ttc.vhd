
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

entity ttc is
  generic (
    MXBXN : integer := 12
    );
  port(
    clock             : in  std_logic;
    sync_on_resync    : in  std_logic := '0';
    reset             : in  std_logic;
    ttc_bx0           : in  std_logic;
    ttc_resync        : in  std_logic;
    bxn_offset_i      : in  std_logic_vector (MXBXN-1 downto 0);
    bxn_read_offset_o : out std_logic_vector (MXBXN-1 downto 0) := (others => '0');
    bx0_local_o       : out std_logic                           := '0';
    bxn_counter_o     : out std_logic_vector (MXBXN-1 downto 0) := (others => '0');
    bx0_sync_err_o    : out std_logic                           := '0';
    bxn_sync_err_o    : out std_logic                           := '0'
    );
end ttc;

architecture behavioral of ttc is
  constant LHC_CYCLE : integer := 3564;

  signal bxn_counter : integer range 0 to LHC_CYCLE-1 := 0;

  -- Restrict bxn offsets to be in the interval 0 < LHC_CYCLE to prevent non-physical bxns
  signal bxn_offset_lim : std_logic_vector (MXBXN-1 downto 0) := (others => '0');

  -- save a resync request until the next bx0
  signal resync_request : std_logic := '0';

  signal bxn_preset : std_logic := '0';
  signal bxn_ovf    : std_logic := '0';

begin

  process (clock) is
  begin
    if (rising_edge(clock)) then
      if (to_integer(unsigned(bxn_offset_i)) >= LHC_CYCLE) then
        bxn_offset_lim <= std_logic_vector(to_unsigned(LHC_CYCLE-2, MXBXN));
      else
        bxn_offset_lim <= bxn_offset_i;
      end if;
    end if;
  end process;


  process (clock) is
  begin
    if (rising_edge(clock)) then
      if (reset = '1') then
        resync_request <= '1';
      elsif (ttc_bx0 = '1') then
        resync_request <= '0';
      elsif (ttc_resync = '1') then
        resync_request <= '1';
      end if;
    end if;
  end process;

  -- Load bxn offset value when a resync is received
  -- allow resync and bx0 in the same bx
  bxn_preset <= reset or ((not sync_on_resync or ttc_resync or resync_request) and ttc_bx0);

  --------------------------------------------------------------------------------
  -- BXN Counter
  --------------------------------------------------------------------------------

  -- BXN maximum count for pretrig bxn counter
  bxn_ovf <= '1' when bxn_counter = LHC_CYCLE-1 else '0';

  process (clock) is
  begin
    if (rising_edge(clock)) then
      if (bxn_preset = '1') then
        bxn_counter <= to_integer(unsigned(bxn_offset_lim))+1;  -- Counter
      elsif (bxn_ovf = '1') then
        bxn_counter <= 0;
      else
        bxn_counter <= bxn_counter+1;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------------------
  -- Synchronization
  --------------------------------------------------------------------------------

  process (clock) is
  begin
    if (rising_edge(clock)) then
      -- ok
      if (ttc_bx0 = '1' and bxn_counter  = to_integer(unsigned(bxn_offset_lim))) then
        bxn_sync_err_o <= '0'; -- good
      end if;
      if (ttc_bx0 = '1' and bxn_counter /= to_integer(unsigned(bxn_offset_lim))) then
        bxn_sync_err_o <= '1'; -- err
      end if;
    end if;
  end process;

  bx0_local_o <= '1' when bxn_counter = 0 else '0';  -- This TMBs bxn is at 0

  -- single clock strobe of sync error at bx0
  bx0_sync_err_o <= '1' when
                    -- at the time a bx0 is received from the backend, the local counter should be at its offset limit
                    (bxn_counter = to_integer(unsigned(bxn_offset_lim)) and ttc_bx0 = '0') or
                    (bxn_counter /= to_integer(unsigned(bxn_offset_lim)) and ttc_bx0 = '1')
                    else '0';

  process (clock) is
  begin
    if (rising_edge(clock)) then
      if (ttc_bx0 = '1') then
        bxn_read_offset_o <= std_logic_vector(to_unsigned(bxn_counter, bxn_read_offset_o'length));
      end if;
    end if;
  end process;

  bxn_counter_o <= std_logic_vector(to_unsigned(bxn_counter, bxn_counter_o'length));

end behavioral;
