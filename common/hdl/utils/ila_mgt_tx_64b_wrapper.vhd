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
      tx_data_i         : in t_mgt_64b_tx_data
  );
end ila_mgt_tx_64b_wrapper;

architecture Behavioral of ila_mgt_tx_64b_wrapper is
    
    component ila_mgt_tx_64b is
        PORT(
            clk    : IN STD_LOGIC;
            probe0 : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
            probe1 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            probe2 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            probe3 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            probe4 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
            probe5 : IN STD_LOGIC_VECTOR(6 DOWNTO 0)
        );
    end component ila_mgt_tx_64b;
        
begin

    i_ila_mgt_tx_64b : component ila_mgt_tx_64b
        port map(
            clk    => clk_i,
            probe0 => tx_data_i.txdata,
            probe1 => tx_data_i.txcharisk,
            probe2 => tx_data_i.txchardispmode,
            probe3 => tx_data_i.txchardispval,
            probe4 => tx_data_i.txheader,
            probe5 => tx_data_i.txsequence
        );
        
end Behavioral;
