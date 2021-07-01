library IEEE;
use IEEE.STD_LOGIC_1164.all;

--============================================================================
--                                                         Package declaration
--============================================================================
package ttc_config_pkg is

    -- Default TTC Command Assignment 
    constant C_TTC_BGO_BC0        : std_logic_vector(7 downto 0) := X"01";
    constant C_TTC_BGO_EC0        : std_logic_vector(7 downto 0) := X"02";
    constant C_TTC_BGO_RESYNC     : std_logic_vector(7 downto 0) := X"04";
    constant C_TTC_BGO_OC0        : std_logic_vector(7 downto 0) := X"08";
    constant C_TTC_BGO_HARD_RESET : std_logic_vector(7 downto 0) := X"10";
    constant C_TTC_BGO_CALPULSE   : std_logic_vector(7 downto 0) := X"14";
    constant C_TTC_BGO_START      : std_logic_vector(7 downto 0) := X"18";
    constant C_TTC_BGO_STOP       : std_logic_vector(7 downto 0) := X"1C";
    constant C_TTC_BGO_TEST_SYNC  : std_logic_vector(7 downto 0) := X"20";

end ttc_config_pkg;
--============================================================================
--                                                                 Package end 
--============================================================================
