------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    12:00 2017-08-09
-- Module Name:    VFAT3_TX_STREAM
-- Description:    This module generates a datastream for all VFAT3s based on TTC commands, also initiates sync procedure, and periodic sync checks
------------------------------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.ttc_pkg.all;
use work.gem_pkg.all;

entity vfat3_tx_stream is
    port(
        -- reset
        reset_i                 : in  std_logic;

        -- TTC
        ttc_clk_i               : in  t_ttc_clks;
        ttc_cmds_i              : in  t_ttc_cmds;
        
        -- control
        sc_only_mode_i          : in  std_logic;
        
        -- output
        data_o                  : out std_logic_vector(7 downto 0);
        idle_o                  : out std_logic; -- indicates whether or not the current data frame is an idle frame and thus can be substituted with slow control data down the line
        sync_o                  : out std_logic; -- indicates that a sync word has been sent out
        sync_verify_o           : out std_logic  -- indicates that a sync verify word has been sent out
    );
end vfat3_tx_stream;

architecture vfat3_tx_stream_arch of vfat3_tx_stream is

    constant SYNC_WORD          : std_logic_vector(7 downto 0) := x"17";
    constant SYNC_VERIFY_WORD   : std_logic_vector(7 downto 0) := x"e8";
    constant RESYNC_WORD        : std_logic_vector(7 downto 0) := x"55";
    constant L1A_WORD           : std_logic_vector(7 downto 0) := x"69";
    constant L1A_EC0_WORD       : std_logic_vector(7 downto 0) := x"aa";
    constant L1A_BC0_WORD       : std_logic_vector(7 downto 0) := x"c3";
    constant EC0_WORD           : std_logic_vector(7 downto 0) := x"0f";
    constant BC0_WORD           : std_logic_vector(7 downto 0) := x"33";
    constant CALPULSE_WORD      : std_logic_vector(7 downto 0) := x"3c";
    constant NORMAL_MODE_WORD   : std_logic_vector(7 downto 0) := x"66";
    constant SC_ONLY_WORD       : std_logic_vector(7 downto 0) := x"5a";
    
    constant SYNC_VERIFY_TIMEOUT: unsigned(11 downto 0) := unsigned(C_TTC_NUM_BXs);
    constant BEFORE_SYNC_TIMEOUT: unsigned(11 downto 0) := x"fff";
    
    type t_state is (WAIT_BEFORE_SYNC, SYNC, SET_COMMPORT_MODE, RUNNING);
    
    signal state                : t_state := SYNC;
    signal sync_countdown       : unsigned(1 downto 0) := "10";
    signal before_sync_countdown: unsigned(11 downto 0) := BEFORE_SYNC_TIMEOUT;
    signal sync_verify_countdown: unsigned(11 downto 0) := SYNC_VERIFY_TIMEOUT;
    
    signal idle_word            : std_logic_vector(7 downto 0) := x"00";
    signal current_sc_only_mode : std_logic := '0';
    
    
begin

    process(ttc_clk_i.clk_40)
    begin
        if (rising_edge(ttc_clk_i.clk_40)) then
            if (reset_i = '1') then
                state <= SYNC;
                data_o <= (others => '0');
                idle_o <= '0';
                sync_o <= '0';
                sync_verify_o <= '0';
                sync_countdown <= "10";
                current_sc_only_mode <= '0';
                sync_verify_countdown <= SYNC_VERIFY_TIMEOUT;
                before_sync_countdown <= BEFORE_SYNC_TIMEOUT;
            else
                if (state = WAIT_BEFORE_SYNC) then
                    data_o <= idle_word;
                    before_sync_countdown <= before_sync_countdown - 1;
                    if (before_sync_countdown = x"000") then
                        state <= SYNC;
                    end if;
                elsif (state = SYNC) then
                    data_o <= SYNC_WORD;
                    idle_o <= '0';
                    sync_o <= '1';
                    sync_verify_o <= '0';
                                    
                    sync_countdown <= sync_countdown - 1;
                    if (sync_countdown = "00") then
                        state <= SET_COMMPORT_MODE;
                    end if;
                elsif (state = SET_COMMPORT_MODE) then
                    if (sc_only_mode_i = '0') then
                        data_o <= NORMAL_MODE_WORD;
                        current_sc_only_mode <= '0';
                    else
                        data_o <= SC_ONLY_WORD;
                        current_sc_only_mode <= '1';
                    end if;
                    state <= RUNNING;
                elsif (state = RUNNING) then
                    idle_o <= '0';
                    sync_o <= '0';
                    sync_verify_o <= '0';
                    
                    if (ttc_cmds_i.hard_reset = '1') then
                        data_o <= idle_word;
                        sync_countdown <= "10";
                        before_sync_countdown <= BEFORE_SYNC_TIMEOUT;
                        state <= WAIT_BEFORE_SYNC;
                    elsif (ttc_cmds_i.resync = '1') then
                        data_o <= RESYNC_WORD;
                    elsif (ttc_cmds_i.l1a = '1' and ttc_cmds_i.ec0 = '1') then
                        data_o <= L1A_EC0_WORD;
                    elsif (ttc_cmds_i.l1a = '1' and ttc_cmds_i.bc0 = '1') then
                        data_o <= L1A_BC0_WORD;
                    elsif (ttc_cmds_i.l1a = '1') then
                        data_o <= L1A_WORD;
                    elsif (ttc_cmds_i.ec0 = '1') then
                        data_o <= EC0_WORD;
                    elsif (ttc_cmds_i.bc0 = '1') then
                        data_o <= BC0_WORD;
                    elsif (ttc_cmds_i.calpulse = '1') then
                        data_o <= CALPULSE_WORD;
                    elsif (current_sc_only_mode = '1' and sc_only_mode_i = '0') then
                        data_o <= NORMAL_MODE_WORD;
                        current_sc_only_mode <= '0';
                    elsif (current_sc_only_mode = '0' and sc_only_mode_i = '1') then
                        data_o <= SC_ONLY_WORD;
                        current_sc_only_mode <= '1';
                    elsif (sync_verify_countdown = x"000") then
                        data_o <= SYNC_VERIFY_WORD;
                        sync_verify_countdown <= SYNC_VERIFY_TIMEOUT;
                        sync_verify_o <= '1';
                    else
                        data_o <= idle_word;
                        idle_o <= '1';
                    end if;
                    
                    if (sync_verify_countdown > x"000") then
                        sync_verify_countdown <= sync_verify_countdown - 1;
                    end if;
                else
                    idle_o <= '0';
                    sync_o <= '0';
                    sync_verify_o <= '0';
                    data_o <= idle_word;
                    
                    before_sync_countdown <= BEFORE_SYNC_TIMEOUT;
                    sync_countdown <= "10";
                    state <= SYNC;
                end if;
            end if;
        end if;
    end process;

    process(ttc_clk_i.clk_40)
    begin
        if (rising_edge(ttc_clk_i.clk_40)) then
            idle_word <= not idle_word;
        end if;
    end process;

end vfat3_tx_stream_arch;
