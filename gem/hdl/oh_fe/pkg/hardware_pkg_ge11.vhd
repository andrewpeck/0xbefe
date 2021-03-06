library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.tmr_pkg.all;

package hardware_pkg is

  -- Configuration
  constant STATION   : integer := 1;
  constant GE21      : integer := 0;
  constant GE11      : integer := 1;
  constant FPGA_TYPE : string  := "V6";

  -- I/O Settings
  constant HAS_ELINK_OUTPUTS : boolean := false;
  constant MXELINKS          : integer := 0;
  constant MXLED             : integer := 16;
  constant MXRESET           : integer := 12;
  constant MXREADY           : integer := 1;
  constant MXEXT             : integer := 8;
  constant MXADC             : integer := 1;
  constant NUM_GT_TX         : integer := 4;
  constant NUM_GT_REFCLK     : integer := 2;

  -- Chamber Parameters
  constant MXSBITS         : integer := 64;
  constant PARTITION_SIZE  : integer := 3;
  constant NUM_PARTITIONS  : integer := 8;
  constant NUM_VFATS       : integer := PARTITION_SIZE * NUM_PARTITIONS;
  constant MXSBITS_CHAMBER : integer := NUM_VFATS*MXSBITS;

  -- Cluster finding Settings

  constant INVERT_PARTITIONS : boolean := true;

  constant REVERSE_VFAT_SBITS : std_logic_vector (NUM_VFATS-1 downto 0) := x"000000";

  constant MXADRB : integer := 8;       -- bits for addr in partition
  constant MXCNTB : integer := 3;       -- bits for size of cluster
  constant MXPRTB : integer := 3;       -- bits for # of partitions

  constant NUM_OPTICAL_PACKETS : integer := 2;  -- # of different optical link packets
  constant NUM_ELINK_PACKETS   : integer := 0;  -- # of different copper link packets

  constant ENABLE_ECC : integer := 1;

  constant USE_LEGACY_OPTICS : boolean := true;
  constant USE_NEW_FORMAT_WITH_OLD_OPTICS : boolean := true;

  -- TMR Enables
  constant EN_TMR_TRIG_FORMATTER     : integer := 0*EN_TMR;
  constant EN_TMR_GBT_DRU            : integer := 0*EN_TMR;
  constant EN_TMR_SBIT_DRU           : integer := 0*EN_TMR;
  constant EN_TMR_SOT_DRU            : integer := 0*EN_TMR;
  constant EN_TMR_CLUSTER_PACKER     : integer := 0*EN_TMR;
  constant EN_TMR_FRAME_ALIGNER      : integer := 0*EN_TMR;
  constant EN_TMR_FRAME_BITSLIP      : integer := 0*EN_TMR;
  constant EN_TMR_GBT_LINK           : integer := 1*EN_TMR;
  constant EN_TMR_IPB_SWITCH         : integer := 1*EN_TMR;
  constant EN_TMR_IPB_SLAVE_TRIG     : integer := 0*EN_TMR;
  constant EN_TMR_IPB_SLAVE_CONTROL  : integer := 0*EN_TMR;
  constant EN_TMR_IPB_SLAVE_GBT      : integer := 1*EN_TMR;
  constant EN_TMR_IPB_SLAVE_ADC      : integer := 0*EN_TMR;
  constant EN_TMR_IPB_SLAVE_CLOCKING : integer := 0*EN_TMR;
  constant EN_TMR_IPB_SLAVE_MGT      : integer := 0*EN_TMR;

end hardware_pkg;
