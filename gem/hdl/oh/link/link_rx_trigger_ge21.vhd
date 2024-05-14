------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    00:01 2016-05-10
-- Module Name:    link_rx_trigger
-- Description:    This module takes two GTX/GTH trigger RX links and outputs sbit cluster data synchronous to the TTC clk  
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.common_pkg.all;
use work.gem_pkg.all;

entity link_rx_trigger_ge21 is
    generic(
        g_DEBUG         : boolean := false; -- if this is set to true, some chipscope cores will be inserted
        g_REGISTER_IN   : boolean := false;
        g_REGISTER_OUT  : boolean := false
    );
    port(
        reset_i             : in  std_logic;

        ttc_clk_40_i        : in  std_logic;        
        rx_data_i           : in  std_logic_vector(87 downto 0);
        
        sbit_clusters_o     : out t_oh_clusters;
        
        bc0_o               : out std_logic;
        resync_o            : out std_logic;
        sbit_overflow_o     : out std_logic;
        ecc_err_o           : out std_logic;
        crc_err_o           : out std_logic := '0';
        oh_err_o            : out std_logic;
        protocol_err_o      : out std_logic
    );
end link_rx_trigger_ge21;

architecture Behavioral of link_rx_trigger_ge21 is    

    component ila_ge21_trigger_link
        port(
            clk     : in std_logic;
            probe0  : in std_logic_vector(87 downto 0);
            probe1  : in std_logic_vector(12 downto 0);
            probe2  : in std_logic_vector(12 downto 0);
            probe3  : in std_logic_vector(12 downto 0);
            probe4  : in std_logic_vector(12 downto 0);
            probe5  : in std_logic_vector(12 downto 0);
            probe6  : in std_logic_vector(2 downto 0);
            probe7  : in std_logic;
            probe8  : in std_logic;
            probe9  : in std_logic_vector(1 downto 0)
        );
    end component;

    signal data_pre_ecc     : std_logic_vector(87 downto 0);
    signal data_post_ecc    : std_logic_vector(87 downto 0);
    signal clusters         : t_oh_clusters;
    signal status_word      : std_logic_vector(2 downto 0); 
    signal bc0              : std_logic; 
    signal next_bxn_valid   : std_logic; 
    signal next_bxn         : std_logic_vector(1 downto 0);

begin  

    -- register input
    g_reg_in : if g_REGISTER_IN generate
        process(ttc_clk_40_i)
        begin
            if rising_edge(ttc_clk_40_i) then
                data_pre_ecc <= rx_data_i;
            end if;
        end process;
    end generate;

    g_no_reg_in : if not g_REGISTER_IN generate
        data_pre_ecc <= rx_data_i;
    end generate;
    
    -- TODO: implement ECC here
    data_post_ecc <= data_pre_ecc;
    
    -- data mapping --
    g_clusters : for i in 0 to 4 generate
        clusters(i).address <= '0' & data_post_ecc(i * 16 + 9 downto i * 16);
        clusters(i).size <= data_post_ecc(i * 16 + 12 downto i * 16 + 10);
    end generate;
    g_dummy_clusters : for i in 5 to 7 generate
        clusters(i) <= NULL_SBIT_CLUSTER;
    end generate;
    
    bc0 <= data_post_ecc(14);
    status_word <= data_post_ecc(3 * 16 + 14) & data_post_ecc(2 * 16 + 14) & data_post_ecc(1 * 16 + 14); 
    
    -- BX counter
    process(ttc_clk_40_i)
    begin
        if rising_edge(ttc_clk_40_i) then
            if (reset_i = '1') then
                next_bxn_valid <= '0';
                next_bxn <= "00"; 
            else
                if status_word(2) = '0' then -- transmitting a BXN
                    next_bxn_valid <= '1';
                    if status_word(1 downto 0) = "11" then
                        next_bxn <= "00";
                    else
                        next_bxn <= std_logic_vector(unsigned(status_word(1 downto 0)) + 1);
                    end if;
                else -- transmitting some other status word
                    next_bxn_valid <= '0';
                    next_bxn <= "00";
                end if;
            end if;
        end if;
    end process;
    
    -- output
    g_reg_out : if g_REGISTER_OUT generate
        process(ttc_clk_40_i)
        begin
            if rising_edge(ttc_clk_40_i) then
                if (reset_i = '1') then
                    sbit_clusters_o <= (others => NULL_SBIT_CLUSTER); 
                    bc0_o           <= '0';
                    sbit_overflow_o <= '0';
                    resync_o        <= '0';
                    ecc_err_o       <= '0';
                    oh_err_o        <= '0';
                    protocol_err_o  <= '0';                    
                else
                    sbit_clusters_o <= clusters;
                    bc0_o <= bc0;
                    ecc_err_o <= '0'; -- TODO: implement ECC
                    
                    if status_word(2) = '0' then -- transmitting a BXN
                        if next_bxn_valid = '1' and next_bxn /= status_word(1 downto 0) then
                            protocol_err_o <= '1';
                        else
                            protocol_err_o <= '0';
                        end if;

                        sbit_overflow_o <= '0';
                        resync_o <= '0';
                        oh_err_o <= '0';
                    else -- transmitting some other status word

                        protocol_err_o <= '0';
                        case status_word(1 downto 0) is
                            -- overflow
                            when "00" =>
                                sbit_overflow_o <= '1';
                                resync_o <= '0';
                                oh_err_o <= '0';
                            -- resync
                            when "01" =>
                                sbit_overflow_o <= '0';
                                resync_o <= '1';
                                oh_err_o <= '0';
                            -- reserved
                            when "10" =>
                                sbit_overflow_o <= '0';
                                resync_o <= '0';
                                oh_err_o <= '0';
                            -- error
                            when "11" =>
                                sbit_overflow_o <= '0';
                                resync_o <= '0';
                                oh_err_o <= '1';
                            when others =>
                                sbit_overflow_o <= '0';
                                resync_o <= '0';
                                oh_err_o <= '0';
                        end case;
                    end if;
                     
                end if;
            end if;
        end process;
    end generate;
    
    g_no_reg_out : if not g_REGISTER_OUT generate
        sbit_clusters_o <= clusters;
        bc0_o <= bc0;
        ecc_err_o <= '0'; -- TODO: implement ECC
        
        protocol_err_o <= '1' when status_word(2) = '0' and next_bxn_valid = '1' and next_bxn /= status_word(1 downto 0) else '0';
        sbit_overflow_o <= '1' when status_word = "100" else '0';
        resync_o <= '1' when status_word = "101" else '0';
        oh_err_o <= '1' when status_word = "111" else '0';
    end generate;
    
    -- debug
    g_debug_ila : if g_DEBUG generate
        i_debug_ila : ila_ge21_trigger_link
            port map(
                clk    => ttc_clk_40_i,
                probe0 => rx_data_i,
                probe1 => clusters(0).size & clusters(0).address(9 downto 0),
                probe2 => clusters(1).size & clusters(1).address(9 downto 0),
                probe3 => clusters(2).size & clusters(2).address(9 downto 0),
                probe4 => clusters(3).size & clusters(3).address(9 downto 0),
                probe5 => clusters(4).size & clusters(4).address(9 downto 0),
                probe6 => status_word,
                probe7 => bc0,
                probe8 => next_bxn_valid,
                probe9 => next_bxn
            ); 
    end generate;
    
end Behavioral;
