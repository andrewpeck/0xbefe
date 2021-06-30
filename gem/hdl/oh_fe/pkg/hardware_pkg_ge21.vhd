library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.tmr_pkg.all;

package hardware_pkg is

  -- Configuration
  constant STATION   : integer := 2;
  constant GE21      : integer := 1;
  constant GE11      : integer := 0;
  constant FPGA_TYPE : string  := "A7";

  -- I/O Settings
  constant HAS_ELINK_OUTPUTS : boolean := true;
  constant MXELINKS          : integer := 11;
  constant MXLED             : integer := 1;
  constant MXRESET           : integer := 0;
  constant MXREADY           : integer := 2;
  constant MXEXT             : integer := 0;
  constant MXADC             : integer := 0;
  constant NUM_GT_TX         : integer := 4;
  constant NUM_GT_REFCLK     : integer := 2;

  -- Chamber Parameters
  constant MXSBITS         : integer := 64;
  constant PARTITION_SIZE  : integer := 6;
  constant NUM_PARTITIONS  : integer := 2;
  constant NUM_VFATS       : integer := PARTITION_SIZE * NUM_PARTITIONS;  --12
  constant MXSBITS_CHAMBER : integer := NUM_VFATS*MXSBITS;

  -- Cluster finding Settings

  constant REMAP_STRIPS      : boolean := false;
  constant INVERT_PARTITIONS : boolean := false;

  constant REVERSE_VFAT_SBITS : std_logic_vector (NUM_VFATS-1 downto 0) := x"000";

  constant PACKET_SIZE         : integer := 5;  -- # of clusters per packet
  constant NUM_OPTICAL_PACKETS : integer := 1;  -- # of different optical link packets
  constant NUM_ELINK_PACKETS   : integer := 1;  -- # of different copper link packets

  constant ENABLE_ECC : integer := 1;

  constant USE_LEGACY_OPTICS : boolean := true;
  constant USE_NEW_FORMAT_WITH_OLD_OPTICS : boolean := true;

  -- TMR Enables
  constant EN_TMR_TRIG_FORMATTER     : integer := 1*EN_TMR;
  constant EN_TMR_GBT_DRU            : integer := 1*EN_TMR;
  constant EN_TMR_SBIT_DRU           : integer := 1*EN_TMR;
  constant EN_TMR_SOT_DRU            : integer := 1*EN_TMR;
  constant EN_TMR_CLUSTER_PACKER     : integer := 1*EN_TMR;
  constant EN_TMR_FRAME_ALIGNER      : integer := 1*EN_TMR;
  constant EN_TMR_FRAME_BITSLIP      : integer := 1*EN_TMR;
  constant EN_TMR_GBT_LINK           : integer := 1*EN_TMR;
  constant EN_TMR_IPB_SWITCH         : integer := 1*EN_TMR;
  constant EN_TMR_IPB_SLAVE_TRIG     : integer := 1*EN_TMR;
  constant EN_TMR_IPB_SLAVE_CONTROL  : integer := 1*EN_TMR;
  constant EN_TMR_IPB_SLAVE_GBT      : integer := 1*EN_TMR;
  constant EN_TMR_IPB_SLAVE_ADC      : integer := 1*EN_TMR;
  constant EN_TMR_IPB_SLAVE_CLOCKING : integer := 1*EN_TMR;
  constant EN_TMR_IPB_SLAVE_MGT      : integer := 1*EN_TMR;

end hardware_pkg;
