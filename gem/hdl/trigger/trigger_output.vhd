------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    00:11 2019-01-16
-- Module Name:    trigger_output
-- Description:    This module formats the trigger data for output to EMTF  
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

use work.common_pkg.all;
use work.gem_pkg.all;
use work.ttc_pkg.all;

entity trigger_output is
    generic(
        g_NUM_OF_OHs        : integer;
        g_NUM_TRIG_TX_LINKS : integer
    );
    port(
        -- reset
        reset_i                 : in  std_logic;
        
        -- TTC
        ttc_clk_i               : in  t_ttc_clks;
        ttc_cmds_i              : in  t_ttc_cmds;

        -- Sbit cluster inputs
        sbit_clusters_i         : in  t_oh_clusters_arr(g_NUM_OF_OHs - 1 downto 0);
        sbit_num_valid_i        : in  t_std4_array(g_NUM_OF_OHs - 1 downto 0);
        oh_triggers_i           : in  std_logic_vector(g_NUM_OF_OHs - 1 downto 0);
        oh_mask_i               : in  std_logic_vector(g_NUM_OF_OHs - 1 downto 0);
        sbit_link_status_i      : in  t_oh_sbit_links_arr(g_NUM_OF_OHs - 1 downto 0);
        sector_id_i             : in  std_logic_vector(3 downto 0);

        -- Outputs
        trig_tx_data_arr_o      : out t_std234_array(g_NUM_TRIG_TX_LINKS - 1 downto 0)
        
    );
end trigger_output;

architecture trigger_output_arch of trigger_output is

    signal trig_tx_data_arr     : t_std234_array(g_NUM_TRIG_TX_LINKS - 1 downto 0);

    signal oh_triggers          : std_logic_vector(g_NUM_OF_OHs - 1 downto 0);
    signal bc0_markers          : std_logic_vector(g_NUM_OF_OHs - 1 downto 0);
    signal sbit_num_valid       : t_std4_array(g_NUM_OF_OHs - 1 downto 0);
    signal sbit_clusters        : t_oh_clusters_arr(g_NUM_OF_OHs - 1 downto 0);

begin

    trig_tx_data_arr_o <= trig_tx_data_arr;

    g_oh_mask : for i in 0 to g_NUM_OF_OHs - 1 generate
        oh_triggers(i) <= oh_triggers_i(i) and not oh_mask_i(i);
        bc0_markers(i) <= sbit_link_status_i(i)(0).bc0_marker and not oh_mask_i(i); -- take the BC0 marker from the first link, alignment of the two links is checked elsewhere
        sbit_num_valid(i) <= sbit_num_valid_i(i) when oh_mask_i(i) = '0' else x"0";
        sbit_clusters(i) <= sbit_clusters_i(i) when oh_mask_i(i) = '0' else (others => NULL_SBIT_CLUSTER);
    end generate;

    -- generate one link for each available pair of OHs
    g_links : for i in 0 to (g_NUM_OF_OHs / 2) - 1 generate

        process (ttc_clk_i.clk_40)
        begin
            if (rising_edge(ttc_clk_i.clk_40)) then
                if (reset_i = '1') then
                    trig_tx_data_arr(i) <= "01" & sector_id_i & std_logic_vector(to_unsigned(i, 4)) & x"ffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
                else
                    -- BC0
                    trig_tx_data_arr(i)(0) <= bc0_markers(i*2 + 0);
                    trig_tx_data_arr(i)(1) <= bc0_markers(i*2 + 1);
                    
                    -- if there are no valid clusters from both chambers, transmit link ID
                    if (oh_triggers(i*2 + 1 downto i*2) = "00") or (ttc_cmds_i.resync = '1') then
                        trig_tx_data_arr(i)(9 downto 2) <= (others => '1'); -- this marks the frame as metadata frame
                        trig_tx_data_arr(i)(13 downto 10) <= sector_id_i;
                        trig_tx_data_arr(i)(17 downto 14) <= std_logic_vector(to_unsigned(i, 4));
                        trig_tx_data_arr(i)(233 downto 18) <= (others => '1'); -- unused
                        
                    -- otherwise transmit cluster counts
                    else
                        trig_tx_data_arr(i)(5 downto 2) <= sbit_num_valid(i*2);
                        trig_tx_data_arr(i)(9 downto 6) <= sbit_num_valid(i*2+1);
                        
                        -- sbits for layer 1                    
                        for sbit in 0 to 7 loop
                            trig_tx_data_arr(i)(sbit * 14 + 23 downto sbit * 14 + 10) <= sbit_clusters(i*2)(sbit).size & sbit_clusters(i*2)(sbit).address;
                        end loop;
    
                        -- sbits for layer 2
                        for sbit in 0 to 7 loop
                            trig_tx_data_arr(i)(sbit * 14 + 135 downto sbit * 14 + 122) <= sbit_clusters(i*2+1)(sbit).size & sbit_clusters(i*2+1)(sbit).address;
                        end loop;
                        
                    end if;
                     
                end if;
            end if;
        end process;

    end generate;
    
    -- if there are more TX links than g_NUM_OF_OHs / 2, then fill them with data from the 2nd link, which will be used for EMTF overlap
    g_extra_links_exist : if g_NUM_TRIG_TX_LINKS > g_NUM_OF_OHs / 2 generate
        g_extra_links : for i in g_NUM_OF_OHs / 2 to g_NUM_TRIG_TX_LINKS - 1 generate
            trig_tx_data_arr(i) <= trig_tx_data_arr(1);
        end generate; 
    end generate;
    
end trigger_output_arch;
