library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use work.ipbus.all;

package sca_pkg is

    -- channels
    constant SCA_CHANNEL_CONFIG   : std_logic_vector(7 downto 0) := x"00";
    constant SCA_CHANNEL_GPIO     : std_logic_vector(7 downto 0) := x"02";
    constant SCA_CHANNEL_JTAG     : std_logic_vector(7 downto 0) := x"13";
    constant SCA_CHANNEL_ADC      : std_logic_vector(7 downto 0) := x"14";

    -- config reg commands
    constant SCA_CMD_CONFIG_WRITE_CRB   : std_logic_vector(7 downto 0) := x"02"; 
    constant SCA_CMD_CONFIG_WRITE_CRC   : std_logic_vector(7 downto 0) := x"04"; 
    constant SCA_CMD_CONFIG_WRITE_CRD   : std_logic_vector(7 downto 0) := x"06"; 

    -- GPIO commands
    constant SCA_CMD_GPIO_SET_DIR       : std_logic_vector(7 downto 0) := x"20"; 
    constant SCA_CMD_GPIO_READ_DIR      : std_logic_vector(7 downto 0) := x"21"; 
    constant SCA_CMD_GPIO_SET_OUT       : std_logic_vector(7 downto 0) := x"10"; 

    -- ADC commands
    constant SCA_CMD_ADC_SET_MUX        : std_logic_vector(7 downto 0) := x"30"; 
    constant SCA_CMD_ADC_READ_MUX       : std_logic_vector(7 downto 0) := x"31"; 
    constant SCA_CMD_ADC_READ           : std_logic_vector(7 downto 0) := x"b2"; 

    -- JTAG commands and constants
    constant SCA_CMD_JTAG_SET_FREQ      : std_logic_vector(7 downto 0) := x"90"; 
    constant SCA_CMD_JTAG_SET_CTRL_REG  : std_logic_vector(7 downto 0) := x"80"; 
    constant SCA_CMD_JTAG_SET_TDO0      : std_logic_vector(7 downto 0) := x"00";
    constant SCA_CMD_JTAG_SET_TMS0      : std_logic_vector(7 downto 0) := x"40";
    constant SCA_CMD_JTAG_READ_TDI0     : std_logic_vector(7 downto 0) := x"01";
    constant SCA_CMD_JTAG_GO            : std_logic_vector(7 downto 0) := x"a2";

    type t_sca_reply is record
        channel           : std_logic_vector(7 downto 0);
        error             : std_logic_vector(7 downto 0);
        length            : std_logic_vector(7 downto 0);
        data              : std_logic_vector(31 downto 0);
    end record;

    type t_sca_command is record
        channel           : std_logic_vector(7 downto 0);
        command           : std_logic_vector(7 downto 0);
        length            : std_logic_vector(7 downto 0);
        data              : std_logic_vector(31 downto 0);
    end record;

    type t_sca_command_array is array(integer range <>) of t_sca_command;
    type t_sca_reply_array is array(integer range <>) of t_sca_reply;
    
end sca_pkg;

