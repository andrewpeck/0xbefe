------------------------------------------------------------------------------------------------------------------------------------------------------
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2021-12-12
-- Module Name:    pipe
-- Description:    bus pipeline / constant depth shift reg
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;

library xpm;
use xpm.vcomponents.all;

use work.common_pkg.all;

entity pipe is
    generic(
        WIDTH   : integer;
        DEPTH   : integer
    );
    port (
        clk_i               : in  std_logic;
        
        data_i              : in  std_logic_vector(WIDTH - 1 downto 0);
        data_o              : out std_logic_vector(WIDTH - 1 downto 0)
    );
end pipe;

architecture pipe_arch of pipe is
    
    type t_input_arr is array(integer range <>) of std_logic_vector(WIDTH - 1 downto 0);
    
    signal pipe     : t_input_arr(DEPTH - 1 downto 0) := (others => (others => '0'));
    
begin
    
    g_null_pipe : if DEPTH = 0 generate
        data_o <= data_i;
    end generate;
    
    g_pipe : if DEPTH /= 0 generate
    
        data_o <= pipe(DEPTH - 1);
        
        process(clk_i) is
        begin
            if rising_edge(clk_i) then
                pipe(0) <= data_i;
                if DEPTH > 1 then
                    for i in 1 to DEPTH - 1 loop
                        pipe(i) <= pipe(i - 1);
                    end loop;
                end if;
            end if;
        end process;

    end generate;

end pipe_arch;
