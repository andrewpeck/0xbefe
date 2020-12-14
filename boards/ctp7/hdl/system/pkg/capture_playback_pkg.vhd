-------------------------------------------------------------------------------
--                                                                            
--       Unit Name: capture_playback_pkg                                            
--                                                                            
--     Description: 
--
--                                                                            
-------------------------------------------------------------------------------
--                                                                            
--           Notes:                                                           
--                                                                            
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

--============================================================================
--                                                         Package declaration
--============================================================================
package capture_playback_pkg is

  type t_capture_ctrl is record
    rst : std_logic;
    arm : std_logic;
  end record;

  type t_capture_status is record
    done      : std_logic;
    fsm_state : std_logic_vector(3 downto 0);
  end record;

  type t_capture_ctrl_arr is array(integer range <>) of t_capture_ctrl;
  type t_capture_status_arr is array(integer range <>) of t_capture_status;

end package capture_playback_pkg;

--============================================================================
--                                                                 Package end 
--============================================================================

