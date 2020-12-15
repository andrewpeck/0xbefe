------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2020-06-10
-- Module Name:    GTY_CHANNEL_RESET 
-- Description:    Drives the reset sequence for one GTY channel, and the associated PLL. This can be used for either a TX or an RX channel.  
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;

use work.common_pkg.all;
use work.gem_pkg.all;
use work.mgt_pkg.all;

entity gty_channel_reset is
    generic(
        g_STABLE_CLK_PERIOD     : integer; -- ns
        g_USRCLK_WAIT_TIME      : integer; -- number of ns to wait for the user clock after the check_usrclk_i has been asserted
        g_CPLL_USED             : boolean; -- set this to true if CPLL is used for this TX or RX channel (NOTE: only one of g_CPLL_USED, g_QPLL0_USED, g_QPLL1_USED should be set to true!!)
        g_QPLL0_USED            : boolean; -- set this to true if QPLL0 is used for this TX or RX channel (NOTE: only one of g_CPLL_USED, g_QPLL0_USED, g_QPLL1_USED should be set to true!!)
        g_QPLL1_USED            : boolean  -- set this to true if QPLL1 is used for this TX or RX channel (NOTE: only one of g_CPLL_USED, g_QPLL0_USED, g_QPLL1_USED should be set to true!!)
    );
    port(
        
        reset_i                 : in  std_logic;
        clk_stable_i            : in  std_logic;
        
        power_good_i            : in  std_logic;
        check_usrclk_i          : in  std_logic;
        txrxresetdone_i         : in  std_logic;
        usrclk_locked_i         : in  std_logic;
                
        cpll_locked_i           : in  std_logic;
        qpll0_locked_i          : in  std_logic;
        qpll1_locked_i          : in  std_logic;
        
        gtreset_o               : out std_logic;
        usrclkrdy_o             : out std_logic;
        cpllreset_o             : out std_logic;
        qpll0_reset_o           : out std_logic;
        qpll1_reset_o           : out std_logic;
        
        reset_done_o            : out std_logic
    );
end gty_channel_reset;

architecture gty_channel_reset_arch of gty_channel_reset is

    COMPONENT ila_gty_reset
        PORT(
            clk    : IN STD_LOGIC;
            probe0 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
            probe1 : IN STD_LOGIC_VECTOR(22 DOWNTO 0);
            probe2 : IN STD_LOGIC;
            probe3 : IN STD_LOGIC
        );
    END COMPONENT;

    type t_state is (INIT, WAIT_AFTER_POWER_GOOD, WAIT_PLL_LOCK, WAIT_USRCLK, WAIT_AFTER_USRCLK, WAIT_GT_RESET_DONE, DONE);

    signal state            : t_state := INIT;
    
    signal gtreset        : std_logic := '1';
    signal usrclkrdy        : std_logic := '0';
    signal pll_reset        : std_logic := '1';

    signal pll_locked       : std_logic := '0';
    signal powergood        : std_logic := '0';
    signal checkusrclk      : std_logic := '0';
    signal resetdone        : std_logic := '0';
    signal usrclk_locked    : std_logic := '0';

    constant TIMER_WAIT_USRCLK  : integer := g_USRCLK_WAIT_TIME / g_STABLE_CLK_PERIOD;
    constant TIMER_2_US         : integer := 2_000 / g_STABLE_CLK_PERIOD;
    constant TIMER_10_US        : integer := 10_000 / g_STABLE_CLK_PERIOD;
    constant TIMER_300_US       : integer := 300_000 / g_STABLE_CLK_PERIOD;
    constant TIMER_500_US       : integer := 500_000 / g_STABLE_CLK_PERIOD;
    constant TIMER_5_MS         : integer := 5_000_000 / g_STABLE_CLK_PERIOD;
    constant TIMER_MAX          : integer := TIMER_5_MS; 
    signal timer                : integer range 0 to TIMER_MAX := 0;

begin

    -------- some general wirings and synchronizers --------
    gtreset_o <= gtreset;
    usrclkrdy_o <= usrclkrdy;
    reset_done_o <= '1' when state = DONE else '0';

    i_sync_powergood : entity work.synch generic map(N_STAGES => 3, IS_RESET => false) port map(async_i => power_good_i, clk_i => clk_stable_i, sync_o  => powergood);
    i_sync_check_usrclk : entity work.synch generic map(N_STAGES => 3, IS_RESET => false) port map(async_i => check_usrclk_i, clk_i => clk_stable_i, sync_o  => checkusrclk);
    i_sync_resetdone : entity work.synch generic map(N_STAGES => 3, IS_RESET => false) port map(async_i => txrxresetdone_i, clk_i => clk_stable_i, sync_o  => resetdone);
    i_sync_usrclk_locked : entity work.synch generic map(N_STAGES => 3, IS_RESET => false) port map(async_i => usrclk_locked_i, clk_i => clk_stable_i, sync_o  => usrclk_locked);

    -------- wire up the PLL lock and reset signals --------
       
    g_cpll: if g_CPLL_USED and (not g_QPLL0_USED) and (not g_QPLL1_USED) generate
        cpllreset_o <= pll_reset;
        qpll0_reset_o <= '0';
        qpll1_reset_o <= '0';
        i_sync_pll_locked : entity work.synch generic map(N_STAGES => 3, IS_RESET => false) port map(async_i => cpll_locked_i, clk_i => clk_stable_i, sync_o  => pll_locked);
    end generate; 

    g_qpll0: if (not g_CPLL_USED) and g_QPLL0_USED and (not g_QPLL1_USED) generate
        cpllreset_o <= '0';
        qpll0_reset_o <= pll_reset;
        qpll1_reset_o <= '0';
        i_sync_pll_locked : entity work.synch generic map(N_STAGES => 3, IS_RESET => false) port map(async_i => qpll0_locked_i, clk_i => clk_stable_i, sync_o  => pll_locked);
    end generate; 

    g_qpll1: if (not g_CPLL_USED) and (not g_QPLL0_USED) and g_QPLL1_USED generate
        cpllreset_o <= '0';
        qpll0_reset_o <= '0';
        qpll1_reset_o <= pll_reset;
        i_sync_pll_locked : entity work.synch generic map(N_STAGES => 3, IS_RESET => false) port map(async_i => qpll1_locked_i, clk_i => clk_stable_i, sync_o  => pll_locked);
    end generate; 

    -------- the FSM --------
    --   1) assert all resets at init and wait for power good to go high
    --   2) wait additional 300us after power good (a minimum of 250us is recommended by UG578). Note this is also enough for CPLLPD to be asserted (UG578 says minimum is 2us)
    --   3) release the PLL reset and wait for the PLL to lock
    --   4) release the GTRESET
    --   5) wait for checkusrclk to go high (on tx it's txpmaresetdone), as well as usrclk to lock, plus a configurable amount (g_USRCLK_WAIT_TIME)
    --   6) assert usrclk_locked_i, and wait for the resetdone to go high
    --   8) decalre the reset done

    process(clk_stable_i)
    begin
        if rising_edge(clk_stable_i) then
            if reset_i = '1' then
                state <= INIT;
                gtreset <= '1';
                pll_reset <= '1';
                usrclkrdy <= '0';
                timer <= 0;
            else
                
                if timer /= TIMER_MAX then
                    timer <= timer + 1;
                end if;
                
                case state is
                    
                    -- wait for power good
                    when INIT =>
                        gtreset <= '1';
                        pll_reset <= '1';
                        usrclkrdy <= '0';
                        
                        if powergood = '1' then
                            state <= WAIT_AFTER_POWER_GOOD;
                            timer <= 0;
                        end if;
                    
                    when WAIT_AFTER_POWER_GOOD =>
                        gtreset <= '1';
                        pll_reset <= '1';
                        usrclkrdy <= '0';

                        if powergood = '0' then
                            state <= INIT;
                        elsif timer = TIMER_300_US then
                            state <= WAIT_PLL_LOCK;
                            timer <= 0;
                        end if;

                    when WAIT_PLL_LOCK =>
                        gtreset <= '1';
                        pll_reset <= '0';
                        usrclkrdy <= '0';
                        
                        if pll_locked = '1' then
                            state <= WAIT_USRCLK;
                            timer <= 0;
                        elsif timer = TIMER_5_MS then
                            state <= INIT;
                        end if;
                        
                    when WAIT_USRCLK =>
                        gtreset <= '0';
                        pll_reset <= '0';
                        usrclkrdy <= '0';
                        
                        if checkusrclk = '1' and usrclk_locked = '1' then
                            state <= WAIT_AFTER_USRCLK;
                            timer <= 0;
                        elsif timer = TIMER_5_MS then
                            state <= INIT;
                        end if;
                        
                    when WAIT_AFTER_USRCLK =>
                        gtreset <= '0';
                        pll_reset <= '0';
                        usrclkrdy <= '0';
                        
                        if timer = TIMER_WAIT_USRCLK then
                            state <= WAIT_GT_RESET_DONE;
                            timer <= 0;
                        end if;

                    when WAIT_GT_RESET_DONE =>
                        gtreset <= '0';
                        pll_reset <= '0';
                        usrclkrdy <= '1';
                        
                        if resetdone = '1' then
                            state <= DONE;
                        elsif timer = TIMER_5_MS then
                            state <= INIT;
                        end if;
                        
                    when DONE =>
                        gtreset <= '0';
                        pll_reset <= '0';
                        usrclkrdy <= '1';
                        state <= DONE;
                        
                    when others =>
                        gtreset <= '0';
                        pll_reset <= '0';
                        usrclkrdy <= '0';
                        state <= INIT;
                        
                end case;
                
            end if;
        end if;
    end process;

end gty_channel_reset_arch;
