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

use work.gem_pkg.all;

entity gt_rx_link_ila_wrapper is
  port (
      
      clk_i   : in std_logic;
      kchar_i : in std_logic_vector(1 downto 0);
      comma_i           : in std_logic_vector(1 downto 0);
      not_in_table_i    : in std_logic_vector(1 downto 0);
      disperr_i         : in std_logic_vector(1 downto 0);
      data_i            : in std_logic_vector(15 downto 0)      
  );
end gt_rx_link_ila_wrapper;

architecture Behavioral of gt_rx_link_ila_wrapper is
    
    component gt_rx_link_ila is
        PORT(
            clk    : IN STD_LOGIC;
            probe0 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
            probe1 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            probe2 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            probe3 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            probe4 : IN STD_LOGIC_VECTOR(1 DOWNTO 0)
        );
    end component gt_rx_link_ila;
        
begin

    i_gt_rx_link_ila : component gt_rx_link_ila
        port map(
            clk         => clk_i,
            probe0      => data_i,
            probe1      => kchar_i,
            probe2      => comma_i,
            probe3      => not_in_table_i,
            probe4      => disperr_i
        );
        
end Behavioral;
