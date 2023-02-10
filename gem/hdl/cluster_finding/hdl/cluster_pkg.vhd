library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

package cluster_pkg is

  constant NUM_ENCODERS        : integer := 4;
  constant NUM_CYCLES          : integer := 4;                          -- number of clocks (4 for 160MHz, 5 for 200MHz)
  constant NUM_FOUND_CLUSTERS  : integer := NUM_ENCODERS * NUM_CYCLES;  -- 16
  constant NUM_OUTPUT_CLUSTERS : integer := 10;

  -- FIXME: these numbers are different for ge21 and ge11 and me0
  constant MXADRB : integer := 9;       -- bits for addr in partition
  constant MXCNTB : integer := 3;       -- bits for size of cluster
  constant MXPRTB : integer := 3;       -- bits for # of partitions

  subtype sbits_t is std_logic_vector(63 downto 0);

  constant SBIT_BX_DELAY_NBITS : integer := 3;
  constant SBIT_BX_DELAY_GRP_SIZE : integer := 8;
  type sbit_bx_dly_array_t is array(integer range <>) of std_logic_vector(SBIT_BX_DELAY_NBITS-1 downto 0);

  type sbits_array_t is array(integer range <>) of sbits_t;

  type sbit_cluster_t is record
    adr : std_logic_vector (MXADRB-1 downto 0);
    cnt : std_logic_vector (MXCNTB-1 downto 0);
    prt : std_logic_vector (MXPRTB-1 downto 0);
    vpf : std_logic;                    -- high for full 25ns
  end record;

  type sbit_cluster_array_t is array(integer range<>) of sbit_cluster_t;

  constant NULL_CLUSTER : sbit_cluster_t := (
    adr => (others => '1'),
    cnt => (others => '1'),
    prt => (others => '1'),
    vpf => '0');

  function cluster_to_vector (a : sbit_cluster_t; size : integer)
    return std_logic_vector;

  function if_then_else (bool : boolean; a : integer; b : integer)
    return integer;

  function invalid_clusterp (cluster : sbit_cluster_t; adr_max : integer)
    return boolean;

end package cluster_pkg;

package body cluster_pkg is

  function cluster_to_vector (a : sbit_cluster_t; size : integer)
    return std_logic_vector is
    variable tmp  : std_logic_vector (a.cnt'length + a.prt'length + a.adr'length-1 downto 0);
    variable tmp2 : std_logic_vector (size-1 downto 0);
  begin
    tmp  := a.cnt & a.prt & a.adr;
    tmp2 := std_logic_vector(resize(unsigned(tmp), size));
    return tmp2;
  end function;

  function invalid_clusterp (cluster : sbit_cluster_t; adr_max : integer)
    return boolean is
  begin
    if ((cluster.vpf = '0' and cluster.adr /= NULL_CLUSTER.adr) or
        (cluster.vpf = '0' and cluster.cnt /= NULL_CLUSTER.cnt) or
        (cluster.vpf = '0' and cluster.prt /= NULL_CLUSTER.prt) or
        (to_integer(unsigned(cluster.adr)) >= adr_max and cluster.adr /= NULL_CLUSTER.adr))
    then
      return true;
  else
    return false;
  end if;

  end function;

  function if_then_else (bool : boolean; a : integer; b : integer) return integer is
  begin
    if (bool) then
      return a;
    else
      return b;
    end if;
  end if_then_else;

end package body cluster_pkg;
