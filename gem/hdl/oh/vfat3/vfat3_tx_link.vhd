------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    12:00 2017-08-09
-- Module Name:    VFAT3_TX_LINK
-- Description:    This module generates a datastream for individual VFAT3s based on data stream received from VFAT3_TX_STREAM and VFAT3_SLOW_CONTROL requests
------------------------------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.ttc_pkg.all;
use work.gem_pkg.all;

entity vfat3_tx_link is
    port(
        
        -- reset
        reset_i             : in  std_logic;
        
        -- clocks
        ttc_clk_i           : in  t_ttc_clks;
        
        -- VFAT3 common tx data stream
        datastream_i        : in  std_logic_vector(7 downto 0);
        datastream_idle_i   : in  std_logic;
        
        -- control
        num_bitslips_i      : in  std_logic_vector(2 downto 0);
        rx_ready_i          : in  std_logic;
        
        -- slow control
        sc_data_i           : in  std_logic;
        sc_valid_i          : in  std_logic;
        sc_en_i             : in  std_logic;
        sc_rd_en_o          : out std_logic;
        
        -- output
        elink_data_o        : out std_logic_vector(7 downto 0)
        
    );
end vfat3_tx_link;

architecture vfat3_tx_link_arch of vfat3_tx_link is

    constant VFAT3_SC0_WORD : std_logic_vector(7 downto 0) := x"96";
    constant VFAT3_SC1_WORD : std_logic_vector(7 downto 0) := x"99";

    signal sc_data_encoded  : std_logic_vector(7 downto 0);
    
begin
    
    elink_data_o <= datastream_i when datastream_idle_i = '0' or sc_en_i = '0' or sc_valid_i = '0' else sc_data_encoded;
    
    sc_rd_en_o <= '1' when datastream_idle_i = '1' and sc_en_i = '1' and sc_valid_i = '1' else '0';

    sc_data_encoded <= VFAT3_SC0_WORD when sc_data_i = '0' else VFAT3_SC1_WORD;

end vfat3_tx_link_arch;
