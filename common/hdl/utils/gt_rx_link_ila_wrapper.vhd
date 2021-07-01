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

entity gt_rx_link_ila_wrapper is
  port (
      
      clk_i         : in std_logic;
      rx_data_i     : in t_mgt_16b_rx_data;
      mgt_status_i  : in t_mgt_status      
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
            probe4 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            probe5 : IN STD_LOGIC;
            probe6 : IN STD_LOGIC;
            probe7 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
            probe8 : IN STD_LOGIC_VECTOR(1 DOWNTO 0)
        );
    end component gt_rx_link_ila;
        
begin

    i_gt_rx_link_ila : component gt_rx_link_ila
        port map(
            clk         => clk_i,
            probe0      => rx_data_i.rxdata,
            probe1      => rx_data_i.rxcharisk,
            probe2      => rx_data_i.rxchariscomma,
            probe3      => rx_data_i.rxnotintable,
            probe4      => rx_data_i.rxdisperr,
            probe5      => rx_data_i.rxbyteisaligned,
            probe6      => rx_data_i.rxbyterealign,
            probe7      => mgt_status_i.rxbufstatus,
            probe8      => mgt_status_i.rxclkcorcnt
        );
        
end Behavioral;
