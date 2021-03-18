--------------------------------------------------------------------------------
-- This module is designed to Truncate LSB 1s from a 1536 bit number, and is
-- capable of running at well over 160 MHz even on VERY large busses
--
-- The details:
--
-- At each clock cycle, the least-significant 1 becomes 0, using a simple
-- property of integers: subtracting 1 from a number will always affect the
-- least-significant set 1-bit. Using just arithmetic, with this trick we can
-- take some starting number, and generate a copy of it that has the
-- least-significant 1 changed to a zero.
--
-- e.g.
-- let a        = 101100100  // our starting number
--    ~a        = 010011011  // bitwise inversion
--     b = ~a+1 = 010011100  // b is exactly the twos complement of a, which we know to be the same as (-a) ! :)
--    ~b        = 101100011  //
--     a & b    = 000000100  // one hot of first one set
--     a &~b    = 101100000  // copy of a with the first non-zero bit set to zero. Voila!
--
-- or as a one line expression,
--     c = a & ~(~a+1), or equivalently
--     c = a & ~(  -a), or equivalently
--     c = a & ~({1536{1'b1}}-a), etc., I'm sure there are more.
--
-- But alas, the point: we can Zero out bits without knowing the position of
-- the bit, So this so-called cluster-truncator can run independently of
-- a priority encoder that is finding the position of the bit. This allows the
-- cluster truncation to be the timing critical step (running at 160 MHz)
-- while the larger amount of logic in the priority encoder can be pipelined,
-- to run over 2 or 3 clock cycles, which adds an overall latency but still
-- allows the priority encoding to be done at 160MHz without imposing much of
-- any constraint on the priority encoding logic.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

entity truncate_lsb is
  generic(
    WIDTH     : integer := 768;
    MAX_CYCLE : integer := 3;
    SEGMENTS  : integer := 16;
    CYCLEB    : integer := 3
    );
  port(

    clock : in std_logic := '0';
    latch : in std_logic := '0';

    cycle_o : out std_logic_vector (CYCLEB-1 downto 0);
    data_i  : in  std_logic_vector (WIDTH-1 downto 0);
    data_o  : out std_logic_vector (WIDTH-1 downto 0)
    );
end truncate_lsb;

architecture behavioral of truncate_lsb is

  constant SEGSIZE : integer := WIDTH/SEGMENTS;

  type seg_array_t is array (integer range 0 to SEGMENTS-1) of std_logic_vector(SEGSIZE-1 downto 0);

  signal ap1          : seg_array_t := (others => (others => '0'));
  signal segment      : seg_array_t := (others => (others => '0'));
  signal segment_copy : seg_array_t := (others => (others => '0'));
  signal segment_ff   : seg_array_t := (others => (others => '0'));
  signal segment_out  : seg_array_t := (others => (others => '0'));

  signal segment_keep   : std_logic_vector (SEGMENTS-1 downto 0) := (others => '0');
  signal segment_active : std_logic_vector (SEGMENTS-1 downto 0) := (others => '0');

  signal cycle : unsigned (CYCLEB-1 downto 0) := (others => '0');

  -- function to replicate a std_logic bit some number of times
  -- equivalent to verilog's built in {n{x}} operator
  function repeat(B : std_logic; N : integer) return std_logic_vector is
    variable result : std_logic_vector(1 to N);
  begin
    for i in 1 to N loop
      result(i) := B;
    end loop;
    return result;
  end;

begin

  assert WIDTH mod SEGMENTS = 0
    report "Number of WIDTH/SEGMENTS must not have a remainder..." severity error;

  cycle_o <= std_logic_vector(cycle);

  process (clock) is
  begin
    if (rising_edge(clock)) then
      if (latch = '1' or to_integer(cycle) = MAX_CYCLE) then
        cycle <= (others => '0');
      else
        cycle <= cycle + 1;
      end if;
    end if;
  end process;

  seggen : for iseg in 0 to SEGMENTS-1 generate
  begin
    -- remap cluster inputs into Segments
    segment(iseg) <= data_i ((iseg+1)*SEGSIZE-1 downto iseg*SEGSIZE);

    -- mark segment as active it has any clusters
    segment_active(iseg) <= or_reduce (segment_ff(iseg));

    -- copy of segment with least significant 1 removed
    --   copy = ff & (keep or ~(~ff+1))

    segment_copy(iseg) <= segment_ff(iseg) and
                          (repeat (segment_keep(iseg), SEGSIZE)
                           or not (std_logic_vector(unsigned(not segment_ff(iseg)) + 1)));

    -- with latch, our ff latches the incoming clusters, otherwise we latch the copied segments
    process (clock) is
    begin
      if (rising_edge(clock)) then
        if (latch = '1') then
          segment_ff(iseg) <= segment (iseg);
        else
          segment_ff(iseg) <= segment_copy (iseg) after 1 ns;
        end if;
      end if;
    end process;

    segment_out(iseg) <= segment_ff(iseg);

  end generate;

  -- Segments should be kept if any preceeding segment has ANY sbit.. there are
  -- a lot of very different (logically equivalent) ways to write this. But
  -- there is a balance between logic depth and routing time that needs to be
  -- found.
  --
  --    this is the best that I've found so far, but there will probably be
  --    something better. But something to keep in mind: the synthesis speed
  --    estimates are not very accurate for this, since it is so dependent on
  --    the post-PAR routing times.  I've seen many times that a faster
  --    configuration in synthesis will be slower in post-PAR, so if you want to
  --    experiment effectively you have to go through the pain of doing PAR
  --    and looking at the timing report

  keepgen : for iseg in 0 to SEGMENTS-1 generate
  begin
    segment_keep (iseg)                             <= or_reduce (segment_active(iseg-1 downto 0));
    data_o ((iseg+1)*SEGSIZE-1 downto iseg*SEGSIZE) <= segment_out(iseg);
  end generate;

end behavioral;
