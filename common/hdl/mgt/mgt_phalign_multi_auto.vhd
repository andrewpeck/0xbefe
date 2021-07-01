------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2020-06-16
-- Module Name:    MGT_PHALIGN_MULTI_AUTO 
-- Description:    Handles the MGT phase alignment procedure which is needed when the elastic buffer is bypassed. This variant uses the multi-lane auto mode (e.g. good for TXs using a common user clock).   
--                 Requires these parameters to be set on the MGTs: (TX/RX)SYNC_MULTILANE = 1 and (TX/RX)SYNC_OVRD = 0
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;

use work.mgt_pkg.all;
use work.board_config_package.all;

entity mgt_phalign_multi_auto is
    generic(
        g_STABLE_CLK_PERIOD     : integer; -- ns
        g_NUM_CHANNELS          : integer;
        g_LINK_CONFIG           : t_mgt_config_arr
    );
    port(
        
        clk_stable_i                : in  std_logic;
        
        -- this should come from the reset FSM (expected that it's on the clk_stable_i domain)
        channel_reset_done_arr_i    : in  std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
        
        -- MGT signals
        mgt_syncallin_arr_o         : out std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
        mgt_syncin_arr_o            : out std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
        mgt_syncmode_arr_o          : out std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
        mgt_dlysreset_arr_o         : out std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
        
        mgt_phaligndone_arr_i       : in  std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
        mgt_syncdone_arr_i          : in  std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
        mgt_syncout_arr_i           : in  std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
        
        -- this output indicates that the phalign fsm has completed and the MGT phaligndone is high
        phase_align_done_arr_o      : out std_logic_vector(g_NUM_CHANNELS - 1 downto 0)        
    );
end mgt_phalign_multi_auto;

architecture mgt_phalign_multi_auto_arch of mgt_phalign_multi_auto is

    type t_state is (INIT, WAIT_SYNC_DONE, DONE);

    signal state                    : t_state := INIT;
    
    signal channel_reset_done_all   : std_logic;
    signal mgt_phaligndone_arr      : std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
    signal mgt_phaligndone_all      : std_logic;
    signal mgt_master_syncdone      : std_logic;
    signal mgt_master_syncout       : std_logic;
    
    signal dlysreset                : std_logic;
    
    constant TIMER_DLYSRESET        : integer := 100 / g_STABLE_CLK_PERIOD;
    constant TIMER_MAX              : integer := TIMER_DLYSRESET; 
    signal timer                    : integer range 0 to TIMER_MAX := 0;

begin

    -------- some general wirings and synchronizers --------
    
    channel_reset_done_all <= and_reduce(channel_reset_done_arr_i);
    mgt_phaligndone_all <= and_reduce(mgt_phaligndone_arr_i);
    
    g_channels : for chan in 0 to g_NUM_CHANNELS - 1 generate
    
        g_master : if g_LINK_CONFIG(chan).tx_multilane_phalign and g_LINK_CONFIG(chan).is_master generate
            mgt_syncmode_arr_o(chan) <= '1';
            mgt_master_syncout <= mgt_syncout_arr_i(chan);
            i_sync_syncdone : entity work.synch generic map(N_STAGES => 3, IS_RESET => false) port map(async_i => mgt_syncdone_arr_i(chan), clk_i => clk_stable_i, sync_o  => mgt_master_syncdone);
        end generate;
        
        g_slave : if not g_LINK_CONFIG(chan).is_master generate
            mgt_syncmode_arr_o(chan) <= '0';
        end generate;
        
        mgt_syncin_arr_o(chan) <= mgt_master_syncout;
        mgt_dlysreset_arr_o(chan) <= dlysreset;
        mgt_syncallin_arr_o(chan) <= mgt_phaligndone_all;
        
        i_sync_phaligndone : entity work.synch generic map(N_STAGES => 3, IS_RESET => false) port map(async_i => mgt_phaligndone_arr_i(chan), clk_i => clk_stable_i, sync_o  => mgt_phaligndone_arr(chan));        
        phase_align_done_arr_o(chan) <= '1' when state = DONE and mgt_phaligndone_arr(chan) = '1' else '0';
        
    end generate;
    
    -------- the FSM --------
    --   1) reset the FSM and go to INIT whenever channel_reset_done_i goes low
    --   2) assert the DLYSRESET on all channels for TIMER_DLYSRESET
    --   3) release the DLYSRESET, and wait for the master SYNCDONE to go high (don't care about dlysresetdone, or counting the phaligndone pulses)
    --   4) voila

    process(clk_stable_i)
    begin
        if rising_edge(clk_stable_i) then
            if channel_reset_done_all = '0' then
                state <= INIT;
                timer <= 0;
                dlysreset <= '0';
            else
                
                if timer /= TIMER_MAX then
                    timer <= timer + 1;
                end if;
                
                case state is
                    
                    when INIT =>
                        dlysreset <= '1';
                        
                        if timer = TIMER_DLYSRESET then
                            state <= WAIT_SYNC_DONE;
                            timer <= 0;
                        end if;
                    
                    when WAIT_SYNC_DONE =>
                        dlysreset <= '0';
                        
                        if mgt_master_syncdone = '1' then
                            state <= DONE;
                        end if;
                        
                    when DONE =>
                        dlysreset <= '0';
                        state <= DONE;
                        
                    when others =>
                        dlysreset <= '0';
                        state <= INIT;
                        
                end case;
                
            end if;
        end if;
    end process;


end mgt_phalign_multi_auto_arch;
