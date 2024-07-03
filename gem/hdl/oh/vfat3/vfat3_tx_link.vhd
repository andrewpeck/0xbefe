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
use work.common_pkg.all;
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
        elink_data_o        : out std_logic_vector(7 downto 0);

        -- local sync
        sync_i              : in  std_logic;
        sync_o              : out std_logic
        
    );
end vfat3_tx_link;

architecture vfat3_tx_link_arch of vfat3_tx_link is

    signal sc_data_encoded  : std_logic_vector(7 downto 0);

    signal sync_reset       : std_logic_vector(2 downto 0);
    
begin

    process(ttc_clk_i.clk_40)
    begin
        if (rising_edge(ttc_clk_i.clk_40)) then
            if (reset_i = '1') then
                sync_reset <= (others => '0'); -- expect global sync
            else
                if (sync_i = '1') then
                    sync_reset <= (others => '1');
                else
                    sync_reset <= sync_reset(1 downto 0) & '0';
                end if;
            end if;
        end if;
    end process;

    sync_o <= sync_reset(2);
    
    elink_data_o <= VFAT3_SYNC_WORD when sync_reset(2) = '1' else datastream_i when datastream_idle_i = '0' or sc_en_i = '0' or sc_valid_i = '0' else sc_data_encoded;
    
    sc_rd_en_o <= '1' when datastream_idle_i = '1' and sc_en_i = '1' and sc_valid_i = '1' else '0';

    sc_data_encoded <= VFAT3_SC0_WORD when sc_data_i = '0' else VFAT3_SC1_WORD;

end vfat3_tx_link_arch;
