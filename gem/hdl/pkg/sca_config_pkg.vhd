library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use work.ipbus.all;

use work.sca_pkg.all;

package sca_config_pkg is

    -- default values
    -- for GPIO, note that the bytes are in reverse order, meaning that e.g. 0x00000080 only sets bit 31
    constant SCA_CFG_JTAG_FREQ          : std_logic_vector(31 downto 0) := x"09000000"; -- Use 2MHz JTAG clk frequency by default (can go higher, no prob)  
    constant SCA_CFG_JTAG_CTRL_REG      : std_logic_vector(31 downto 0) := x"00000c00"; -- TX on falling edge, shift out LSB 
    constant SCA_DEFAULT_GPIO_DIR_GE11      : std_logic_vector(31 downto 0) := x"0fffff8f"; -- set PROG_B, those that go to FPGA, and the ones connected to VFAT3 resets in OHv3c as outputs
    constant SCA_DEFAULT_GPIO_DIR_GE21      : std_logic_vector(31 downto 0) := x"00ff0fe0"; -- set PROG_B, EN_HR, EN_GBT_LOAD, and the ones connected to VFAT3 resets as outputs
    constant SCA_DEFAULT_GPIO_OUT_GE11      : std_logic_vector(31 downto 0) := x"f00000f0"; -- PROG_B = high, not driving INIT_B, GPIO that go to FPGA are all set low, and VFAT3 reset in OHv3c are set low
    constant SCA_DEFAULT_GPIO_OUT_GE21      : std_logic_vector(31 downto 0) := x"00000060"; -- PROG_B = high, EN_HR = high, EN_GBT_LOAD = high, VFAT3 resets are all set low
    constant SCA_DEFAULT_GPIO_OUT_HR_GE11   : std_logic_vector(31 downto 0) := x"f0ffff0f"; -- PROG_B = low, and VFAT3 resets in OHv3c are set high, otherwise the same as default
    constant SCA_DEFAULT_GPIO_OUT_HR_GE21   : std_logic_vector(31 downto 0) := x"00ff0fe0"; -- PROG_B = low, and VFAT3 resets are set high, otherwise the same as default
    
end sca_config_pkg;
