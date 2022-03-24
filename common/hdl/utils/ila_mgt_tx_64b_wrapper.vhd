------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    20:10:11 2016-05-02
-- Module Name:    A simple ILA wrapper for a GTH or GTX RX link 
-- Description:     
------------------------------------------------------------------------------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use work.common_pkg.all;

entity ila_mgt_tx_64b_wrapper is
  port (
      
      clk_i             : in std_logic;
      kchar_i           : in std_logic_vector(7 downto 0);
      data_i            : in std_logic_vector(63 downto 0)
  );
end ila_mgt_tx_64b_wrapper;

architecture Behavioral of ila_mgt_tx_64b_wrapper is
    
    component ila_mgt_tx_64b is
        PORT(
            clk    : IN STD_LOGIC;
            probe0 : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
            probe1 : IN STD_LOGIC_VECTOR(7 DOWNTO 0)
        );
    end component ila_mgt_tx_64b;
        
begin

    i_ila_mgt_tx_64b : component ila_mgt_tx_64b
        port map(
            clk    => clk_i,
            probe0 => data_i,
            probe1 => kchar_i
        );
        
end Behavioral;
