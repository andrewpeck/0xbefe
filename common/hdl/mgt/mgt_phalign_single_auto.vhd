------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2020-06-16
-- Module Name:    MGT_PHALIGN_SINGLE_AUTO 
-- Description:    Handles the MGT phase alignment procedure which is needed when the elastic buffer is bypassed. This variant uses the single-lane auto mode (e.g. good for RX using recovered clock).   
--                 Requires these parameters to be set on the MGTs: (TX/RX)SYNC_MULTILANE = 0 and (TX/RX)SYNC_OVRD = 0
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;

entity mgt_phalign_single_auto is
    generic(
        g_STABLE_CLK_PERIOD     : integer -- ns
    );
    port(
        
        clk_stable_i            : in  std_logic;
        
        -- this should come from the reset FSM (expected that it's on the clk_stable_i domain)
        channel_reset_done_i    : in  std_logic; -- the phase alignment is (re)started whenever this transitions from low to high
        
        -- MGT signals
        mgt_syncallin_o         : out std_logic;
        mgt_syncin_o            : out std_logic;
        mgt_syncmode_o          : out std_logic;
        mgt_dlysreset_o         : out std_logic;
        
        mgt_phaligndone_i       : in  std_logic;
        mgt_syncdone_i          : in  std_logic;
        
        -- this output indicates that the phalign fsm has completed and the MGT phaligndone is high
        phase_align_done_o      : out std_logic        
    );
end mgt_phalign_single_auto;

architecture mgt_phalign_single_auto_arch of mgt_phalign_single_auto is

    type t_state is (INIT, WAIT_SYNC_DONE, DONE);

    signal state            : t_state := INIT;
    
    signal mgt_phaligndone  : std_logic;
    signal mgt_syncdone     : std_logic;
    
    constant TIMER_DLYSRESET    : integer := 100 / g_STABLE_CLK_PERIOD; -- 100ns
    constant TIMER_MAX          : integer := TIMER_DLYSRESET; 
    signal timer                : integer range 0 to TIMER_MAX := 0;

begin

    -------- some general wirings and synchronizers --------
    mgt_syncmode_o <= '1';
    mgt_syncin_o <= '0';
    mgt_syncallin_o <= mgt_phaligndone_i;
    
    phase_align_done_o <= '1' when state = DONE and mgt_phaligndone = '1' else '0';

    i_sync_phaligndone : entity work.synch generic map(N_STAGES => 3, IS_RESET => false) port map(async_i => mgt_phaligndone_i, clk_i => clk_stable_i, sync_o  => mgt_phaligndone);
    i_sync_syncdone : entity work.synch generic map(N_STAGES => 3, IS_RESET => false) port map(async_i => mgt_syncdone_i, clk_i => clk_stable_i, sync_o  => mgt_syncdone);

    -------- the FSM --------
    --   1) reset the FSM and go to INIT whenever channel_reset_done_i goes low
    --   2) assert the DLYSRESET for TIMER_DLYSRESET
    --   3) release the DLYSRESET, and wait for SYNCDONE to go high (don't care about dlysresetdone, or counting the phaligndone pulses)
    --   4) voila

    process(clk_stable_i)
    begin
        if rising_edge(clk_stable_i) then
            if channel_reset_done_i = '0' then
                state <= INIT;
                timer <= 0;
                mgt_dlysreset_o <= '0';
            else
                
                if timer /= TIMER_MAX then
                    timer <= timer + 1;
                end if;
                
                case state is
                    
                    when INIT =>
                        mgt_dlysreset_o <= '1';
                        
                        if timer = TIMER_DLYSRESET then
                            state <= WAIT_SYNC_DONE;
                            timer <= 0;
                        end if;
                    
                    when WAIT_SYNC_DONE =>
                        mgt_dlysreset_o <= '0';
                        
                        if mgt_syncdone = '1' then
                            state <= DONE;
                        end if;
                        
                    when DONE =>
                        mgt_dlysreset_o <= '0';
                        state <= DONE;
                        
                    when others =>
                        mgt_dlysreset_o <= '0';
                        state <= INIT;
                        
                end case;
                
            end if;
        end if;
    end process;


end mgt_phalign_single_auto_arch;
