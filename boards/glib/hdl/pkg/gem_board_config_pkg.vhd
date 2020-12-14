-------------------------------------------------------------------------------
--                                                                            
--       Unit Name: gem_board_config_package
--                                                                            
--     Description: Configuration for CTP7 board
--
--                                                                            
-------------------------------------------------------------------------------
--                                                                            
--           Notes:                                                           
--                                                                            
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

--============================================================================
--                                                         Package declaration
--============================================================================
package gem_board_config_package is

    constant g_NUM_OF_GTX       : positive := 4;

    constant CFG_BOARD_TYPE     : std_logic_vector(3 downto 0) := x"0"; 
    
    constant CFG_USE_GBT        : boolean := false;  -- if this is true, GBT links will be used for communicationa with OH, if false 3.2Gbs 8b10b links will be used instead (remember to instanciate the correct links!)
    constant CFG_USE_3x_GBTs    : boolean := false;  -- if this is true, each OH will use 3 GBT links - this will be default in the future with OH v3, but for now it's a good test
    constant CFG_USE_TRIG_LINKS : boolean := false; -- this should be TRUE by default, but could be set to false for tests or quicker compilation if not needed
    constant CFG_NUM_OF_OHs     : integer := 4;    -- total number of OHs to instanciate (remember to adapt the CFG_OH_LINK_CONFIG_ARR accordingly)


    --========================--
    --== Link configuration ==--
    --========================--

    -- defines the GT index for each type of OH link
    type t_oh_link_config is record
        track_8b10b_link: integer range 0 to 79; -- fallback link on OH v2b (can be used instead of GBT) and default for OH v2a
        gbt0_link       : integer range 0 to 79; -- main GBT link on OH v2b
        gbt1_link       : integer range 0 to 79; -- with OH v2b this is just for test, this will be needed with OH v3
        gbt2_link       : integer range 0 to 79; -- with OH v2b this is just for test, this will be needed with OH v3
        trig0_rx_link   : integer range 0 to 79; -- trigger RX link for clusters 0, 1, 2, 3
        trig1_rx_link   : integer range 0 to 79; -- trigger RX link for clusters 4, 5, 6, 7
    end record t_oh_link_config;
    
    type t_oh_link_config_arr is array (0 to CFG_NUM_OF_OHs - 1) of t_oh_link_config;
	
	constant CFG_OH_LINK_CONFIG_ARR : t_oh_link_config_arr := (

    -- two OH config with one trigger link per OH
--        (0, 0, 0, 0, 1, 1),
--        (2, 2, 2, 2, 3, 3)

    -- four OH config with no trigger links
        (0, 0, 0, 0, 0, 0),
        (1, 1, 1, 1, 1, 1),
        (2, 2, 2, 2, 2, 2),
        (3, 3, 3, 3, 3, 3) 
        
	);

end package gem_board_config_package;
--============================================================================
--                                                                 Package end 
--============================================================================

