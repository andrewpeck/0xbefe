library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

entity truncate_lsb is
  generic(
    WIDTH    : integer := 768;
    CYCLEB   : integer := 3;
    SEGMENTS : integer := 16
    );
  port(

    clock : in std_logic;
    en    : in std_logic;

    pass_o : out std_logic_vector (CYCLEB-1 downto 0);
    data_i : in  std_logic_vector (WIDTH-1 downto 0);
    data_o : out std_logic_vector(WIDTH-1 downto 0)
    );
end truncate_lsb;

architecture behavioral of truncate_lsb is

  constant SEGSIZE : integer := WIDTH/SEGMENTS;

  type seg_array_t is array (integer range 0 to SEGMENTS-1) of std_logic_vector(SEGSIZE-1 downto 0);

  signal segment      : seg_array_t := (others => (others => '0'));
  signal segment_copy : seg_array_t := (others => (others => '0'));
  signal segment_ff   : seg_array_t := (others => (others => '0'));
  signal segment_out  : seg_array_t := (others => (others => '0'));

  signal segment_keep   : std_logic_vector (SEGMENTS-1 downto 0);
  signal segment_active : std_logic_vector (SEGMENTS-1 downto 0);

begin

  process (clock) is
  begin
    if (rising_edge(clock)) then
      if (en = '1') then
        pass_o <= (others => '0');
      else
        pass_o <= std_logic_vector(unsigned(pass_o) + 1);
      end if;
    end if;
  end process;

  seggen : for I in 0 to SEGMENTS-1 generate
  begin
    -- remap cluster inputs into Segments
    segment(iseg) <= vpfs_in ((iseg+1)*SEGSIZE-1 downto iseg*SEGSIZE);

    -- mark segment as active it has any clusters
    segment_active(iseg) <= reduce_or (segment_ff(iseg));

    -- copy of segment with least significant 1 removed
    -- ~ copy = ff & (keep or ~(~ff+1))
    segment_copy(iseg) <= segment_ff(iseg) and
                          ((segment_ff'range => segment_keep(iseg))
                           or not (not std_logic_vector(unsigned(segment_ff(iseg)) +1)));


    -- with en, our ff latches the incoming clusters, otherwise we latch the copied segments
    process (clock) is
    begin
      if (rising_edge(clock)) then
        if (en) then
          segment_ff(iseg) <= segment (iseg);
        else
          segment_ff(iseg) <= segment_copy (iseg);
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

  keepgen : for I in 0 to SEGMENTS-1 generate
  begin
    segment_keep (iseg)                               <= reduce_or (segment_active(iseg-1 downto 0));
    vpfs_out ((iseg+1)*SEGSIZE-1 downto iseg*SEGSIZE) <= segment_out(iseg);
  end generate;

end behavioral;
