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
        sbit_clusters_i         : in  t_oh_sbits_arr(g_NUM_OF_OHs - 1 downto 0);
        sbit_num_valid_i        : in  t_std4_array(g_NUM_OF_OHs - 1 downto 0);
        oh_triggers_i           : in  std_logic_vector(g_NUM_OF_OHs - 1 downto 0);
        oh_mask_i               : in  std_logic_vector(g_NUM_OF_OHs - 1 downto 0);
        sbit_link_status_i      : in  t_oh_sbit_links_arr(g_NUM_OF_OHs - 1 downto 0);

        -- Outputs
        trig_tx_data_arr_o      : out t_std234_array(g_NUM_TRIG_TX_LINKS - 1 downto 0)
        
    );
end trigger_output;

architecture trigger_output_arch of trigger_output is

    constant SECTOR_ID : std_logic_vector(3 downto 0) := x"3"; -- TODO: this is a constant sector ID for debugging, should come from register though 

    signal trig_tx_data_arr     : t_std234_array(g_NUM_TRIG_TX_LINKS - 1 downto 0);

begin

    trig_tx_data_arr_o <= trig_tx_data_arr;

    -- generate one link for each available pair of OHs
    g_links : for i in 0 to (g_NUM_OF_OHs / 2) - 1 generate

        process (ttc_clk_i.clk_40)
        begin
            if (rising_edge(ttc_clk_i.clk_40)) then
                if (reset_i = '1') then
                    trig_tx_data_arr(i) <= "01" & SECTOR_ID & std_logic_vector(to_unsigned(i, 4)) & x"ffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
                else
                    -- BC0
                    trig_tx_data_arr(i)(0) <= ttc_cmds_i.bc0;
                    
                    -- if there are no valid clusters from both chambers, transmit link ID
                    if (oh_triggers_i(i*2 + 1 downto i*2) = "00") then
                        trig_tx_data_arr(i)(1) <= '1';
                        trig_tx_data_arr(i)(5 downto 2) <= SECTOR_ID;
                        trig_tx_data_arr(i)(9 downto 6) <= std_logic_vector(to_unsigned(i, 4));
                    else -- otherwise transmit cluster counts
                        trig_tx_data_arr(i)(1) <= '0';
                        trig_tx_data_arr(i)(5 downto 2) <= sbit_num_valid_i(i*2);
                        trig_tx_data_arr(i)(9 downto 6) <= sbit_num_valid_i(i*2+1);
                    end if;

                    -- sbits for layer 1                    
                    for sbit in 0 to 7 loop
                        trig_tx_data_arr(i)(sbit * 14 + 23 downto sbit * 14 + 10) <= sbit_clusters_i(i*2)(sbit).size & sbit_clusters_i(i*2)(sbit).address;
                    end loop;

                    -- sbits for layer 2
                    for sbit in 0 to 7 loop
                        trig_tx_data_arr(i)(sbit * 14 + 135 downto sbit * 14 + 122) <= sbit_clusters_i(i*2+1)(sbit).size & sbit_clusters_i(i*2+1)(sbit).address;
                    end loop;
                     
                end if;
            end if;
        end process;

    end generate;
    
    -- if there are more TX links than g_NUM_OF_OHs / 2, then fill them with data from the last link (typically you'll have at least one of those for overlap)
    g_extra_links_exist : if g_NUM_TRIG_TX_LINKS > g_NUM_OF_OHs / 2 generate
        g_extra_links : for i in g_NUM_OF_OHs / 2 to g_NUM_TRIG_TX_LINKS - 1 generate
            trig_tx_data_arr(i) <= trig_tx_data_arr((g_NUM_OF_OHs / 2) - 1);
        end generate; 
    end generate;
    
end trigger_output_arch;