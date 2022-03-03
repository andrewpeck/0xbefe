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

use work.common_pkg.all;
use work.mgt_pkg.all;
use work.board_config_package.all;

entity mgt_phalign_multi_auto is
    generic(
        g_STABLE_CLK_PERIOD     : integer; -- ns
        g_NUM_CHANNELS          : integer;
        g_LINK_CONFIG           : t_mgt_config_arr;
        g_DEBUG                 : boolean
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
        
        mgt_dlysresetdone_arr_i     : in  std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
        mgt_phaligndone_arr_i       : in  std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
        mgt_syncdone_arr_i          : in  std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
        mgt_syncout_arr_i           : in  std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
        
        -- this output indicates that the phalign fsm has completed and the MGT phaligndone is high
        phase_align_done_arr_o      : out std_logic_vector(g_NUM_CHANNELS - 1 downto 0)        
    );
end mgt_phalign_multi_auto;

architecture mgt_phalign_multi_auto_arch of mgt_phalign_multi_auto is

    type t_state is (WAIT_AFTER_RESET, INIT, WAIT_SYNC_DONE, DONE);

    signal state                    : t_state := INIT;
    
    signal channel_reset_done_arr   : std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
    signal channel_reset_done_all   : std_logic;
    signal dlysreset_done_arr       : std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
    signal dlysreset_done_all       : std_logic;
    signal mgt_phaligndone_arr      : std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
    signal mgt_phaligndone_all      : std_logic;
    signal mgt_master_syncdone      : std_logic;
    signal mgt_master_syncout       : std_logic;
    
    signal dlysreset                : std_logic;
    
    constant TIMER_DLYSRESET        : integer := 100 / g_STABLE_CLK_PERIOD;
--    constant TIMER_WAIT_AFTER_RESET : integer := 50000 / g_STABLE_CLK_PERIOD;
    constant TIMER_WAIT_AFTER_RESET : integer := 0;
    constant TIMER_MAX              : integer := max(TIMER_DLYSRESET, TIMER_WAIT_AFTER_RESET); 
    signal timer                    : integer range 0 to TIMER_MAX := 0;

begin

    -------- some general wirings and synchronizers --------
    
    channel_reset_done_all <= and_reduce(channel_reset_done_arr);
    mgt_phaligndone_all <= and_reduce(mgt_phaligndone_arr);
    dlysreset_done_all <= and_reduce(dlysreset_done_arr); 
    
    g_channels : for chan in 0 to g_NUM_CHANNELS - 1 generate
        
        g_master : if g_LINK_CONFIG(chan).mgt_type.tx_multilane_phalign and g_LINK_CONFIG(chan).is_master generate
            mgt_syncmode_arr_o(chan) <= '1';
            mgt_master_syncout <= mgt_syncout_arr_i(chan);
            i_sync_syncdone : entity work.synch generic map(N_STAGES => 3, IS_RESET => false) port map(async_i => mgt_syncdone_arr_i(chan), clk_i => clk_stable_i, sync_o  => mgt_master_syncdone);
        end generate;
        
        g_slave : if not g_LINK_CONFIG(chan).is_master generate
            mgt_syncmode_arr_o(chan) <= '0';
        end generate;

        g_use_phalign : if g_LINK_CONFIG(chan).mgt_type.tx_multilane_phalign generate
            channel_reset_done_arr(chan) <= channel_reset_done_arr_i(chan);
            mgt_syncin_arr_o(chan) <= mgt_master_syncout;
            mgt_dlysreset_arr_o(chan) <= dlysreset;
            mgt_syncallin_arr_o(chan) <= mgt_phaligndone_all;
            phase_align_done_arr_o(chan) <= '1' when state = DONE and mgt_phaligndone_arr(chan) = '1' else '0';
            i_sync_phaligndone : entity work.synch generic map(N_STAGES => 3, IS_RESET => false) port map(async_i => mgt_phaligndone_arr_i(chan), clk_i => clk_stable_i, sync_o  => mgt_phaligndone_arr(chan));
            i_sync_dlysresetdone : entity work.synch generic map(N_STAGES => 3, IS_RESET => false) port map(async_i => mgt_dlysresetdone_arr_i(chan), clk_i => clk_stable_i, sync_o  => dlysreset_done_arr(chan));                    
        end generate;

        g_no_phalign : if not g_LINK_CONFIG(chan).mgt_type.tx_multilane_phalign generate
            channel_reset_done_arr(chan) <= '1';
            mgt_phaligndone_arr(chan) <= '1';
            dlysreset_done_arr(chan) <= '1';
            mgt_syncin_arr_o(chan) <= '0';
            mgt_dlysreset_arr_o(chan) <= '0';
            mgt_syncallin_arr_o(chan) <= '1';
            phase_align_done_arr_o(chan) <= mgt_phaligndone_arr(chan);
        end generate;
    
        
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
                if TIMER_WAIT_AFTER_RESET = 0 then
                    state <= INIT;
                else
                    state <= WAIT_AFTER_RESET;
                end if;
                timer <= 0;
                dlysreset <= '0';
            else
                
                if timer /= TIMER_MAX then
                    timer <= timer + 1;
                end if;
                
                case state is
                    
                    when WAIT_AFTER_RESET =>                    
                        dlysreset <= '0';
                        
                        if timer = TIMER_WAIT_AFTER_RESET then
                            state <= INIT;
                            timer <= 0;
                        end if;
                    
                    when INIT =>
                        dlysreset <= '1';
                        
                        if timer = TIMER_DLYSRESET or dlysreset_done_all = '1' then
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

    gen_debug : if g_DEBUG generate
        component ila_mgt_phasealign_multi_auto
            port(
                clk    : in std_logic;
                probe0 : in std_logic_vector(1 downto 0);
                probe1 : in std_logic_vector(7 downto 0);
                probe2 : in std_logic;
                probe3 : in std_logic;
                probe4 : in std_logic;
                probe5 : in std_logic;
                probe6 : in std_logic;
                probe7 : in std_logic_vector(15 downto 0);
                probe8 : in std_logic_vector(15 downto 0);
                probe9 : in std_logic_vector(15 downto 0)
            );
        end component;        
        
        signal dbg_phalign_done_arr     : std_logic_vector(15 downto 0) := (others => '0');
        signal dbg_reset_done_arr       : std_logic_vector(15 downto 0) := (others => '0');
        signal dbg_dlysresetdone_arr    : std_logic_vector(15 downto 0) := (others => '0');
        
        constant MAX_IDX : integer := min(g_NUM_CHANNELS - 1, 15);
        
    begin
        
        dbg_phalign_done_arr(MAX_IDX downto 0) <= mgt_phaligndone_arr_i(MAX_IDX downto 0);
        dbg_reset_done_arr(MAX_IDX downto 0) <= channel_reset_done_arr_i(MAX_IDX downto 0);
        dbg_dlysresetdone_arr(MAX_IDX downto 0) <= mgt_dlysresetdone_arr_i(MAX_IDX downto 0);
        
        i_ila_phalign : ila_mgt_phasealign_multi_auto
            port map(
                clk    => clk_stable_i,
                probe0 => std_logic_vector(to_unsigned(t_state'pos(state), 2)),
                probe1 => std_logic_vector(to_unsigned(timer, 8)),
                probe2 => mgt_master_syncdone,
                probe3 => dlysreset,
                probe4 => mgt_phaligndone_all,
                probe5 => channel_reset_done_all,
                probe6 => mgt_master_syncout,
                probe7 => dbg_phalign_done_arr,
                probe8 => dbg_reset_done_arr,
                probe9 => dbg_dlysresetdone_arr
            );
        
    end generate;

end mgt_phalign_multi_auto_arch;
