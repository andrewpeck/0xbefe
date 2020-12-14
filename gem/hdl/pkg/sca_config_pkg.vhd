library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use work.ipbus.all;

use work.sca_pkg;
use work.gem_board_config_package.CFG_GEM_STATION;

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

    function select_slv32_by_station(gem_station : integer; ge11_slv32, ge21_slv32 : std_logic_vector(31 downto 0)) return std_logic_vector;

    constant SCA_DEFAULT_GPIO_DIR           : std_logic_vector(31 downto 0) := select_slv32_by_station(CFG_GEM_STATION, SCA_DEFAULT_GPIO_DIR_GE11, SCA_DEFAULT_GPIO_DIR_GE21);
    constant SCA_DEFAULT_GPIO_OUT           : std_logic_vector(31 downto 0) := select_slv32_by_station(CFG_GEM_STATION, SCA_DEFAULT_GPIO_OUT_GE11, SCA_DEFAULT_GPIO_OUT_GE21);
    constant SCA_DEFAULT_GPIO_OUT_HR        : std_logic_vector(31 downto 0) := select_slv32_by_station(CFG_GEM_STATION, SCA_DEFAULT_GPIO_OUT_HR_GE11, SCA_DEFAULT_GPIO_OUT_HR_GE21);

    -- the messages in this array are executed in sequence after SCA CONTOLLER reset followed by SCA chip reset
    constant SCA_CONFIG_SEQUENCE : t_sca_command_array(0 to 6) := (
        (channel => SCA_CHANNEL_CONFIG, command => SCA_CMD_CONFIG_WRITE_CRB, length => x"01", data => x"00000004"),         -- enable GPIO
        (channel => SCA_CHANNEL_CONFIG, command => SCA_CMD_CONFIG_WRITE_CRC, length => x"01", data => x"00000000"),         -- disable I2C
        (channel => SCA_CHANNEL_CONFIG, command => SCA_CMD_CONFIG_WRITE_CRD, length => x"01", data => x"00000018"),         -- 0x18 enable JTAG and ADC
        (channel => SCA_CHANNEL_GPIO, command => SCA_CMD_GPIO_SET_DIR, length => x"04", data => SCA_DEFAULT_GPIO_DIR),      -- set GPIO direction to default
        (channel => SCA_CHANNEL_GPIO, command => SCA_CMD_GPIO_SET_OUT, length => x"04", data => SCA_DEFAULT_GPIO_OUT),      -- set GPIO ouputs to default
        (channel => SCA_CHANNEL_JTAG, command => SCA_CMD_JTAG_SET_CTRL_REG, length => x"04", data => SCA_CFG_JTAG_CTRL_REG),-- set JTAG control reg defaults
        (channel => SCA_CHANNEL_JTAG, command => SCA_CMD_JTAG_SET_FREQ, length => x"04", data => SCA_CFG_JTAG_FREQ)         -- set default JTAG clk frequency
    );
    
end sca_config_pkg;

package body sca_config_pkg is

    function select_slv32_by_station(gem_station : integer; ge11_slv32, ge21_slv32 : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        if gem_station = 2 then
            return ge21_slv32;
        else 
            return ge11_slv32;  
        end if;
    end function select_slv32_by_station;
    
end sca_config_pkg;
