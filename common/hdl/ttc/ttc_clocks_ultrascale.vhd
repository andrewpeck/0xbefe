--------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date: 12/13/2016 14:27:30
-- Module Name: TTC_CLOCKS
-- Project Name:
-- Description: Given a jitter cleaned TTC clock (160MHz), this module generates 40MHz, 80MHz, 120MHz, 160MHz TTC clocks.
--              There's also an option to accept the same TXPROGDIVCLK (when g_TXPROGDIVCLK_USED is set to true), which is the same frequency as the MGT user clocks, which are 120MHz for GBTX and 320MHz for LpGBT
--              This version doesn't implement phase alignment with external reference
-- 
--------------------------------------------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library UNISIM;
use UNISIM.VComponents.all;

library xpm;
use xpm.vcomponents.all;

use work.ttc_pkg.all;
use work.common_pkg.all;

--============================================================================
--                                                          Entity declaration
--============================================================================
entity ttc_clocks is
    generic (
        g_GEM_STATION               : integer range 0 to 2;
        g_INPUT_IS_40MHZ            : boolean := false; -- set this to true if the input clock is actually 40MHz
        g_TXPROGDIVCLK_USED         : boolean := false; -- set this to true if TXOUTCLKSEL is set to TXPROGDIVCLK ("101"), which results in the same frequency as the user clock (e.g. for GBTX TXOUTCLK in this case is 120MHz instead of the 160MHz refclk)
        g_INST_BUFG_GT              : boolean := true; -- if set to true then BUFG_GT will be instantiated inside this module, otherwise the clk_gbt_mgt_txout_i should be put on a BUFG_GT outside
        g_LPGBT_2P56G_LOOPBACK_TEST : boolean := false;
        g_CLK_STABLE_FREQ           : integer
    );
    port (
        clk_stable_i            : in  std_logic; -- used for frequency meter
        clk_gbt_mgt_txout_i     : in  std_logic; -- TTC jitter cleaned 160MHz or 320MHz TTC clock, should come from MGT ref (160MHz in GBTX case, and 320MHz in LpGBT case)
        clk_gbt_mgt_ready_i     : in  std_logic;
        clocks_o                : out t_ttc_clks;
        ctrl_i                  : in  t_ttc_clk_ctrl; -- control signals
        status_o                : out t_ttc_clk_status -- status outputs
    );

end ttc_clocks;

--============================================================================
--                                                        Architecture section
--============================================================================
architecture ttc_clocks_arch of ttc_clocks is

    component freq_meter is
        generic(
            REF_F       : std_logic_vector(31 downto 0);
            N           : integer
        );
        port(
            ref_clk     : in  std_logic;
            f           : in  std_logic_vector(N - 1 downto 0);
            freq        : out t_std32_array(N - 1 downto 0)
        );
    end component freq_meter;

    --============================================================================
    --                                                         Signal declarations
    --============================================================================
    signal clkin                : std_logic;

    signal clkfbout             : std_logic;
    signal clkfbin              : std_logic;

    signal clk_40               : std_logic;
    signal clk_80               : std_logic;
    signal clk_120              : std_logic;
    signal clk_160              : std_logic;
    signal clk_320              : std_logic;

    signal ttc_clocks_bufg      : t_ttc_clks;
    
    -- this function determines the feedback clock multiplication factor based on whether the station is using LpGBT or GBTX
    function get_clkfbout_mult(gem_station : integer; is_txprogdivclk, is_lpgbt_loopback, input_is_40mhz : boolean) return real is
    begin
        if input_is_40mhz then
            return 24.0;
        elsif is_lpgbt_loopback then
            return 3.0;
        elsif not is_txprogdivclk then
            return 6.0;
        elsif is_txprogdivclk and ((gem_station = 1) or (gem_station = 2)) then
            return 8.0;
        elsif is_txprogdivclk and gem_station = 0 then
            return 3.0;
        else -- hmm whatever, lets say 6.0
            return 6.0;  
        end if;
    end function get_clkfbout_mult;    

    function get_clkin_period(gem_station : integer; is_txprogdivclk, is_lpgbt_loopback, input_is_40mhz : boolean) return real is
    begin
        if input_is_40mhz then
            return 25.00;
        elsif is_lpgbt_loopback then
            return 3.125;
        elsif not is_txprogdivclk then
            return 6.25;
        elsif is_txprogdivclk and ((gem_station = 1) or (gem_station = 2)) then
            return 8.33;
        elsif is_txprogdivclk and gem_station = 0 then
            return 3.125;
        else -- hmm whatever, lets say 6.25
            return 6.25;  
        end if;
    end function get_clkin_period;    

    function get_clkin_frequency_slv32(gem_station : integer; is_txprogdivclk, is_lpgbt_loopback, input_is_40mhz : boolean) return std_logic_vector is
    begin
        if input_is_40mhz then
            return x"02638e98"; -- 40.079
        elsif is_lpgbt_loopback then
            return x"131c74c0"; -- 320.632
        elsif not is_txprogdivclk then
            return x"098e3a60"; -- 160.316MHz
        elsif is_txprogdivclk and ((gem_station = 1) or (gem_station = 2)) then
            return x"072aabc8"; -- 120.237MHz
        elsif is_txprogdivclk and gem_station = 0 then
            return x"131c74c0"; -- 320.632
        else -- hmm whatever, lets say 160
            return x"098e3a60";  -- 160.316MHz
        end if;
    end function get_clkin_frequency_slv32;    


    constant CFG_CLKFBOUT_MULT : real := get_clkfbout_mult(g_GEM_STATION, g_TXPROGDIVCLK_USED, g_LPGBT_2P56G_LOOPBACK_TEST, g_INPUT_IS_40MHZ);
    constant CFG_CLKIN1_PERIOD : real := get_clkin_period(g_GEM_STATION, g_TXPROGDIVCLK_USED, g_LPGBT_2P56G_LOOPBACK_TEST, g_INPUT_IS_40MHZ);
    constant CFG_CLKIN1_FREQ_SLV32 : std_logic_vector := get_clkin_frequency_slv32(g_GEM_STATION, g_TXPROGDIVCLK_USED, g_LPGBT_2P56G_LOOPBACK_TEST, g_INPUT_IS_40MHZ);
    
    signal mmcm_ps_clk              : std_logic;
    signal mmcm_locked              : std_logic;
    signal mmcm_locked_clk40        : std_logic;
    signal mmcm_unlock_p_clk40      : std_logic;
    signal mmcm_reset_psclk_tmp     : std_logic;
    
    signal mmcm_unlock_cnt          : std_logic_vector(15 downto 0) := (others => '0');
    
    -- control signals moved to mmcm_ps_clk domain
    signal ctrl_psclk               : t_ttc_clk_ctrl;
    
    -- frequency monitor
    signal ttc_freq                 : t_std32_array(0 downto 0);
    signal ttc_freq_sync            : std_logic_vector(31 downto 0);
    
--============================================================================
--                                                          Architecture begin
--============================================================================
begin

    g_clkin_bufg : if g_INST_BUFG_GT generate
        i_bufg_clkin : BUFG_GT
            port map(
                O       => clkin,
                CE      => '1',
                CEMASK  => '0',
                CLR     => '0',
                CLRMASK => '0',
                DIV     => "000",
                I       => clk_gbt_mgt_txout_i
            );  
    end generate;

    -- bufg is instantiated outside this module
    g_clkin_no_bufg : if not g_INST_BUFG_GT generate
        clkin <= clk_gbt_mgt_txout_i;
    end generate;

    mmcm_ps_clk <= clkin;

    -- CDC of the control signals to mmcm_ps_clk domain
    g_sync_reset_cnt :      entity work.synch generic map(N_STAGES => 2) port map(async_i => ctrl_i.reset_cnt, clk_i   => mmcm_ps_clk, sync_o  => ctrl_psclk.reset_cnt);
    g_sync_reset_mmcm :     entity work.synch generic map(N_STAGES => 2) port map(async_i => ctrl_i.reset_mmcm, clk_i   => mmcm_ps_clk, sync_o  => mmcm_reset_psclk_tmp);
    g_sync_man_shift_dir :  entity work.synch generic map(N_STAGES => 2) port map(async_i => ctrl_i.pa_manual_shift_dir, clk_i   => mmcm_ps_clk, sync_o  => ctrl_psclk.pa_manual_shift_dir);
    g_sync_man_shift_ovrd : entity work.synch generic map(N_STAGES => 2) port map(async_i => ctrl_i.pa_manual_shift_ovrd, clk_i   => mmcm_ps_clk, sync_o  => ctrl_psclk.pa_manual_shift_ovrd);

    i_mmcm_reset_oneshot : entity work.oneshot
        port map(
            reset_i   => '0',
            clk_i     => mmcm_ps_clk,
            input_i   => mmcm_reset_psclk_tmp,
            oneshot_o => ctrl_psclk.reset_mmcm
        );

    i_mmcm_ps_en_manual_oneshot : entity work.oneshot_cross_domain
        port map(
            reset_i       => ctrl_i.reset_mmcm,
            input_clk_i   => ttc_clocks_bufg.clk_40,
            oneshot_clk_i => mmcm_ps_clk,
            input_i       => ctrl_i.pa_manual_shift_en,
            oneshot_o     => ctrl_psclk.pa_manual_shift_en
        );

    i_main_mmcm : MMCME4_ADV
        generic map(
            BANDWIDTH            => "OPTIMIZED",
            CLKFBOUT_MULT_F      => CFG_CLKFBOUT_MULT,
            CLKFBOUT_PHASE       => 0.000,
            CLKFBOUT_USE_FINE_PS => "TRUE",
            CLKIN1_PERIOD        => CFG_CLKIN1_PERIOD,
            CLKOUT0_DIVIDE_F     => 24.000,
            CLKOUT0_DUTY_CYCLE   => 0.500,
            CLKOUT0_PHASE        => 0.000,
            CLKOUT0_USE_FINE_PS  => "FALSE",
            CLKOUT1_DIVIDE       => 12,
            CLKOUT1_DUTY_CYCLE   => 0.500,
            CLKOUT1_PHASE        => 0.000,
            CLKOUT1_USE_FINE_PS  => "FALSE",
            CLKOUT2_DIVIDE       => 8,
            CLKOUT2_DUTY_CYCLE   => 0.500,
            CLKOUT2_PHASE        => 0.000,
            CLKOUT2_USE_FINE_PS  => "FALSE",
            CLKOUT3_DIVIDE       => 6,
            CLKOUT3_DUTY_CYCLE   => 0.500,
            CLKOUT3_PHASE        => 0.000,
            CLKOUT3_USE_FINE_PS  => "FALSE",
            CLKOUT4_CASCADE      => "FALSE",
            CLKOUT4_DIVIDE       => 3,
            CLKOUT4_DUTY_CYCLE   => 0.500,
            CLKOUT4_PHASE        => 0.000,
            CLKOUT4_USE_FINE_PS  => "FALSE",
--            COMPENSATION         => "ZHOLD",
            DIVCLK_DIVIDE        => 1,
            REF_JITTER1          => 0.010,
            STARTUP_WAIT         => "FALSE"
        )
        port map(
            -- clock inputs
            CLKFBIN      => clkfbin,
            CLKIN1       => clkin,
            CLKIN2       => '0',
            -- clock outputs
            CLKFBOUT     => clkfbout,
            CLKFBOUTB    => open,
            CLKOUT0      => clk_40,
            CLKOUT0B     => open,
            CLKOUT1      => clk_80,
            CLKOUT1B     => open,
            CLKOUT2      => clk_120,
            CLKOUT2B     => open,
            CLKOUT3      => clk_160,
            CLKOUT3B     => open,
            CLKOUT4      => clk_320,
            CLKOUT5      => open,
            CLKOUT6      => open,
            -- control
            CLKINSEL     => '1', -- always select the primary clock
            PWRDWN       => '0',
            RST          => ctrl_psclk.reset_mmcm or (not clk_gbt_mgt_ready_i),
            -- drp
            DO           => open,
            DRDY         => open,
            DADDR        => (others => '0'),
            DCLK         => '0',
            DEN          => '0',
            DI           => (others => '0'),
            DWE          => '0',
            -- dynamic phase shifting
            PSCLK        => mmcm_ps_clk,
            PSEN         => ctrl_psclk.pa_manual_shift_en and ctrl_psclk.pa_manual_shift_ovrd,
            PSINCDEC     => ctrl_psclk.pa_manual_shift_dir and ctrl_psclk.pa_manual_shift_ovrd,
            PSDONE       => open,
            -- status
            LOCKED       => mmcm_locked,
            CLKFBSTOPPED => open,
            CLKINSTOPPED => open,
            -- dynamic clock divide
            CDDCDONE     => open,
            CDDCREQ      => '0'           
        );

    -- Output buffering
    -------------------------------------

    -- TODO: use BUFGCE_DIV to produce the clk 80 and 40 to minimize skew (must use BUFGCE_DIV on the other clocks too in this case)
    -- reference: https://docs.xilinx.com/r/en-US/ug949-vivado-design-methodology/Synchronous-CDC

    i_bufg_clk_40 : BUFG
        port map(
            O => ttc_clocks_bufg.clk_40,
            I => clk_40
        );

    i_bufg_clk_80 : BUFG
        port map(
            O => ttc_clocks_bufg.clk_80,
            I => clk_80
        );

    i_bufg_clk_120 : BUFG
        port map(
            O => ttc_clocks_bufg.clk_120,
            I => clk_120
        );

    i_bufg_clk_160 : BUFG
        port map(
            O => ttc_clocks_bufg.clk_160,
            I => clk_160
        );

    i_bufg_clk_320 : BUFG
        port map(
            O => ttc_clocks_bufg.clk_320,
            I => clk_320
        );

    clocks_o <= ttc_clocks_bufg;

    -- use a BUFG in the feedback path
    
    i_bufg_clkfb : BUFG
        port map(
            O => clkfbin,
            I => clkfbout
        );
    
    ------------ status monitoring ------------

    g_sync_mmcm_locked : entity work.synch generic map(N_STAGES => 2) port map(async_i => mmcm_locked, clk_i => ttc_clocks_bufg.clk_40, sync_o  => mmcm_locked_clk40);
    
    i_mmcm_unlock_pulse : entity work.oneshot
        port map(
            reset_i   => '0',
            clk_i     => ttc_clocks_bufg.clk_40,
            input_i   => not mmcm_locked_clk40,
            oneshot_o => mmcm_unlock_p_clk40
        );
    
    i_cnt_mmcm_unlock : entity work.counter
        generic map(
            g_COUNTER_WIDTH  => 16,
            g_ALLOW_ROLLOVER => false
        )
        port map(
            ref_clk_i => ttc_clocks_bufg.clk_40,
            reset_i   => ctrl_i.reset_cnt,
            en_i      => mmcm_unlock_p_clk40,
            count_o   => mmcm_unlock_cnt
        );

    i_freq_meter : freq_meter
        generic map(
            REF_F => std_logic_vector(to_unsigned(g_CLK_STABLE_FREQ, 32)),
            N     => 1
        )
        port map(
            ref_clk => clk_stable_i,
            f       => (0 => ttc_clocks_bufg.clk_40),
            freq    => ttc_freq
        );    

    i_ttc_freq_sync : xpm_cdc_array_single
        generic map(
            WIDTH          => 32
        )
        port map(
            src_clk  => clk_stable_i,
            src_in   => ttc_freq(0),
            dest_clk => ttc_clocks_bufg.clk_40,
            dest_out => ttc_freq_sync
        );

    status_o.mmcm_locked <= mmcm_locked_clk40;
    status_o.mmcm_unlock_cnt <= mmcm_unlock_cnt;
    status_o.phase_locked <= '1';
    status_o.phase_unlock_cnt <= (others => '0');
    status_o.phase_unlock_time <= (others => '0');
    status_o.phasemon_mmcm_locked <= '0';
    status_o.sync_done <= '1';
    status_o.sync_done_time <= (others => '0');
    status_o.ttc_clk_loss_cnt <= (others => '0');
    status_o.ttc_clk_loss_time <= (others => '0');
    status_o.ttc_clk_present <= '1';
    status_o.phase_monitor.phase <= (others => '0');
    status_o.phase_monitor.phase_jump_cnt <= (others => '0');
    status_o.phase_monitor.phase_max <= (others => '0');
    status_o.phase_monitor.phase_min <= (others => '0');
    status_o.phase_monitor.sample_counter <= (others => '0');
    status_o.clk40_freq <= ttc_freq_sync;
        
end ttc_clocks_arch;
--============================================================================
--                                                            Architecture end
--============================================================================
