----------------------------------------------------------------------------------
-- Company: TAMU, a lot of this is taken from WU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date: 04/24/2016 04:52:35 AM
-- Module Name: TTC
-- Project Name: GEM_AMC
-- Description: Locks to TTC clock and decodes TTC commands from the backplane link. Also provides various controls and counters to be used for configuration, diagnostics and daq   
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library UNISIM;
use UNISIM.VComponents.all;

--use work.ctp7_utils_pkg.all;
use work.ttc_pkg.all;
use work.ipbus.all;
use work.common_pkg.all;
use work.ipb_addr_decode.all;
use work.registers.all;

--============================================================================
--                                                          Entity declaration
--============================================================================

entity ttc is
    generic(
        g_DISABLE_TTC_DATA   : boolean := false; -- set this to true when ttc_data_p_i / ttc_data_n_i are not connected to anything, this will disable ttc data completely (generator can still be used though)
        g_IPB_CLK_PERIOD_NS  : integer
    );
    port(
        -- reset
        reset_i             : in  std_logic;

        -- TTC clocks
        ttc_clks_i          : in  t_ttc_clks;
        ttc_clks_status_i   : in  t_ttc_clk_status;
        ttc_clks_ctrl_o     : out t_ttc_clk_ctrl;

        -- TTC backplane data signals
        ttc_data_p_i        : in  std_logic;
        ttc_data_n_i        : in  std_logic;

        -- TTC commands
        local_l1a_req_i     : in  std_logic; -- this is an edge triggered async input, and can be used to request local L1As
        ttc_cmds_o          : out t_ttc_cmds;
    
        -- DAQ counters (L1A ID, Orbit ID, BX ID)
        ttc_daq_cntrs_o     : out t_ttc_daq_cntrs;

        -- TTC status
        ttc_status_o        : out t_ttc_status;
        
        -- L1A LED
        l1a_led_o           : out std_logic;

        -- IPbus
        ipb_reset_i         : in  std_logic;
        ipb_clk_i           : in  std_logic;
        ipb_mosi_i          : in  ipb_wbus;
        ipb_miso_o          : out ipb_rbus
    );

end ttc;

--============================================================================
--                                                        Architecture section
--============================================================================
architecture ttc_arch of ttc is

    --============================================================================
    --                                                         Signal declarations
    --============================================================================

    signal reset_global             : std_logic;
    signal reset                    : std_logic;

    -- commands
    signal ttc_cmd                  : std_logic_vector(7 downto 0);
    signal ttc_l1a                  : std_logic;

    signal l1a_cmd                  : std_logic;
    signal bc0_cmd                  : std_logic;
    signal ec0_cmd                  : std_logic;
    signal resync_cmd               : std_logic;
    signal oc0_cmd                  : std_logic;
    signal start_cmd                : std_logic;
    signal stop_cmd                 : std_logic;
    signal hard_reset_cmd           : std_logic;
    signal calpulse_cmd             : std_logic;
    signal test_sync_cmd            : std_logic;

    signal l1a_cmd_real             : std_logic;
    signal bc0_cmd_real             : std_logic;
    signal ec0_cmd_real             : std_logic;
    signal resync_cmd_real          : std_logic;
    signal oc0_cmd_real             : std_logic;
    signal start_cmd_real           : std_logic;
    signal stop_cmd_real            : std_logic;
    signal hard_reset_cmd_real      : std_logic;
    signal calpulse_cmd_real        : std_logic;
    signal test_sync_cmd_real       : std_logic;

    -- ttc generator
    signal gen_enable               : std_logic;
    signal gen_enable_cal_only      : std_logic; -- for synthetic tests, this will use only the calpulse signal from the generator while all the other commands will come from AMC13
    signal gen_reset                : std_logic;
    signal gen_ttc_cmds             : t_ttc_cmds;
    signal gen_single_hard_reset    : std_logic;
    signal gen_single_resync        : std_logic;
    signal gen_single_ec0           : std_logic;
    signal gen_cyclic_l1a_gap       : std_logic_vector(15 downto 0);
    signal gen_cyclic_l1a_cnt       : std_logic_vector(31 downto 0);
    signal gen_cyclic_cal_l1a_gap   : std_logic_vector(11 downto 0);
    signal gen_cyclic_cal_prescale  : std_logic_vector(11 downto 0);
    signal gen_cyclic_l1a_start     : std_logic;
    signal gen_cyclic_l1a_running   : std_logic;

    -- daq counters
    signal l1id_cnt                 : std_logic_vector(23 downto 0);
    signal orbit_cnt                : std_logic_vector(15 downto 0);
    signal bx_cnt                   : std_logic_vector(11 downto 0);

    -- control and status
    signal ttc_ctrl                 : t_ttc_ctrl;
    signal ttc_status               : t_ttc_status;
    signal ttc_conf                 : t_ttc_conf; 
    
    -- stats
    constant C_NUM_OF_DECODED_TTC_CMDS : integer := 10;
    signal ttc_cmds_arr             : std_logic_vector(C_NUM_OF_DECODED_TTC_CMDS - 1 downto 0);
    signal ttc_cmds_cnt_arr         : t_std32_array(C_NUM_OF_DECODED_TTC_CMDS - 1 downto 0);
    
    signal l1a_rate                 : std_logic_vector(31 downto 0); 

    -- l1a request
    signal l1a_req_sync             : std_logic;
    signal l1a_req                  : std_logic;

    -- ttc mini spy
    signal ttc_spy_buffer           : std_logic_vector(31 downto 0) := (others => '1');
    signal ttc_spy_pointer          : integer range 0 to 31         := 0;
    signal ttc_spy_reset            : std_logic                     := '0';

    ------ Register signals begin (this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py -- do not edit)
    ------ Register signals end ----------------------------------------------
    
--============================================================================
--                                                          Architecture begin
--============================================================================

begin

    ------------- Wiring and resets -------------

    ttc_ctrl.clk_ctrl.reset_cnt <= ttc_ctrl.cnt_reset or ttc_ctrl.reset_local;
    ttc_clks_ctrl_o <= ttc_ctrl.clk_ctrl;
    
    ttc_status.clk_status <= ttc_clks_status_i;
    ttc_status_o <= ttc_status;

    i_reset_sync: 
    entity work.synch
        generic map(
            N_STAGES => 3
        )
        port map(
            async_i => reset_i,
            clk_i   => ttc_clks_i.clk_40,
            sync_o  => reset_global
        );

    reset <= reset_global or ttc_ctrl.reset_local;

    ------------- LEDs -------------

    i_l1a_led_pulse : entity work.pulse_extend
        generic map(
            DELAY_CNT_LENGTH => C_LED_PULSE_LENGTH_TTC_CLK'length
        )
        port map(
            clk_i          => ttc_clks_i.clk_40,
            rst_i          => reset,
            pulse_length_i => C_LED_PULSE_LENGTH_TTC_CLK,
            pulse_i        => l1a_cmd,
            pulse_o        => l1a_led_o
        );

    ------------- TTC commands -------------
    
    g_ttc_cmd : if not g_DISABLE_TTC_DATA generate
        i_ttc_cmd: entity work.ttc_cmd
            port map(
                clk_40_i             => ttc_clks_i.clk_40,
                ttc_data_p_i         => ttc_data_p_i,
                ttc_data_n_i         => ttc_data_n_i,
                ttc_cmd_o            => ttc_cmd,
                ttc_l1a_o            => ttc_l1a,
                tcc_err_cnt_rst_i    => ttc_ctrl.cnt_reset or reset,
                ttc_err_single_cnt_o => ttc_status.single_err,
                ttc_err_double_cnt_o => ttc_status.double_err
            );
    end generate;

    g_no_ttc_cmd : if g_DISABLE_TTC_DATA generate
        ttc_cmd <= (others => '0');
        ttc_l1a <= '0';
        ttc_status.single_err <= (others => '0');
        ttc_status.double_err <= (others => '0');
    end generate;
    
    p_cmd:
    process(ttc_clks_i.clk_40) is
    begin
        if (rising_edge(ttc_clks_i.clk_40)) then
            if (reset = '1') or (ttc_ctrl.cmd_enable = '0') then
                bc0_cmd_real        <= '0';
                ec0_cmd_real        <= '0';
                resync_cmd_real     <= '0';
                oc0_cmd_real        <= '0';
                start_cmd_real      <= '0';
                stop_cmd_real       <= '0';
                test_sync_cmd_real  <= '0';
                hard_reset_cmd_real <= '0';
                calpulse_cmd_real   <= '0';
            else
                if (ttc_cmd = ttc_conf.cmd_bc0) then
                    bc0_cmd_real <= '1';
                else
                    bc0_cmd_real <= '0';
                end if;
                if (ttc_cmd = ttc_conf.cmd_ec0) then
                    ec0_cmd_real <= '1';
                else
                    ec0_cmd_real <= '0';
                end if;
                if (ttc_cmd = ttc_conf.cmd_resync) then
                    resync_cmd_real <= '1';
                else
                    resync_cmd_real <= '0';
                end if;
                if (ttc_cmd = ttc_conf.cmd_oc0) then
                    oc0_cmd_real <= '1';
                else
                    oc0_cmd_real <= '0';
                end if;
                if (ttc_cmd = ttc_conf.cmd_hard_reset) then
                    hard_reset_cmd_real <= '1';
                else
                    hard_reset_cmd_real <= '0';
                end if;
                if (ttc_cmd = ttc_conf.cmd_start) then
                    start_cmd_real <= '1';
                else
                    start_cmd_real <= '0';
                end if;
                if (ttc_cmd = ttc_conf.cmd_stop) then
                    stop_cmd_real <= '1';
                else
                    stop_cmd_real <= '0';
                end if;
                if (ttc_cmd = ttc_conf.cmd_test_sync) then
                    test_sync_cmd_real <= '1';
                else
                    test_sync_cmd_real <= '0';
                end if;

                if (ttc_ctrl.calib_mode = '0') then
                    if (ttc_cmd = ttc_conf.cmd_calpulse) then
                        calpulse_cmd_real <= '1';
                    else
                        calpulse_cmd_real <= '0';
                    end if;
                else
                    if (ttc_l1a = '1' and ttc_ctrl.l1a_enable = '1') then  
                        calpulse_cmd_real <= '1';
                    else
                        calpulse_cmd_real <= '0';
                    end if;                    
                        end if;
                        
                    end if;
                    
                end if;
    end process p_cmd;

    i_l1a_delay : entity work.shift_reg
        generic map(
            TAP_DELAY_WIDTH => 10,
            DATA_WIDTH      => 0,
            OUTPUT_REG      => false,
            SUPPORT_RESET   => false
        )
        port map(
            clk_i       => ttc_clks_i.clk_40,
            tap_delay_i => ttc_ctrl.l1a_delay,
            data_i      => ttc_l1a and ttc_ctrl.l1a_enable,
            data_o      => l1a_cmd_real
        );

    ------------- L1A request -------------
    
    i_l1a_req_sync : entity work.synch generic map(N_STAGES => 10, IS_RESET => false) port map(async_i => local_l1a_req_i, clk_i => ttc_clks_i.clk_40, sync_o  => l1a_req_sync);
    i_l1a_req_oneshot : entity work.oneshot
        port map(
            reset_i   => reset,
            clk_i     => ttc_clks_i.clk_40,
            input_i   => l1a_req_sync,
            oneshot_o => l1a_req
        );
    
    ------------- TTC generator -------------

    i_ttc_generator : entity work.ttc_generator
        port map(
            reset_i              => reset or gen_reset,
            ttc_clks_i           => ttc_clks_i,
            ttc_cmds_o           => gen_ttc_cmds,
            single_hard_reset_i  => gen_single_hard_reset,
            single_resync_i      => gen_single_resync,
            single_ec0_i         => gen_single_ec0,
            cyclic_l1a_gap_i     => gen_cyclic_l1a_gap,
            cyclic_l1a_cnt_i     => gen_cyclic_l1a_cnt,
            cyclic_cal_l1a_gap_i => gen_cyclic_cal_l1a_gap,
            cyclic_cal_prescale_i=> gen_cyclic_cal_prescale,
            cyclic_l1a_start_i   => gen_cyclic_l1a_start,
            cyclic_l1a_running_o => gen_cyclic_l1a_running
        );

    ------------- MUX between real and generated TTC commands -------------    
    
    bc0_cmd        <= bc0_cmd_real when gen_enable = '0' else gen_ttc_cmds.bc0;
    ec0_cmd        <= ec0_cmd_real when gen_enable = '0' else gen_ttc_cmds.ec0;
    resync_cmd     <= resync_cmd_real when gen_enable = '0' else gen_ttc_cmds.resync;
    oc0_cmd        <= oc0_cmd_real when gen_enable = '0' else '0';
    start_cmd      <= start_cmd_real when gen_enable = '0' else gen_ttc_cmds.start;
    stop_cmd       <= stop_cmd_real when gen_enable = '0' else gen_ttc_cmds.stop;
    test_sync_cmd  <= test_sync_cmd_real when gen_enable = '0' else gen_ttc_cmds.test_sync;
    hard_reset_cmd <= hard_reset_cmd_real when gen_enable = '0' else gen_ttc_cmds.hard_reset;
    calpulse_cmd   <= calpulse_cmd_real when gen_enable = '0' and gen_enable_cal_only = '0' else gen_ttc_cmds.calpulse;
    l1a_cmd        <= l1a_cmd_real or l1a_req when gen_enable = '0' else gen_ttc_cmds.l1a or l1a_req;

    ------------- TTC counters -------------
    
    p_orbit_cnt:
    process(ttc_clks_i.clk_40) is
    begin
        if (rising_edge(ttc_clks_i.clk_40)) then
            if (reset = '1') then
                orbit_cnt <= (others => '0');
            else
                if (oc0_cmd = '1') then
                    orbit_cnt <= (others => '0');
                elsif (bc0_cmd = '1') then
                    orbit_cnt <= std_logic_vector(unsigned(orbit_cnt) + 1);
                end if;
            end if;

        end if;
    end process p_orbit_cnt;

    p_l1id_cnt:
    process(ttc_clks_i.clk_40) is
    begin
        if (rising_edge(ttc_clks_i.clk_40)) then
            if (reset = '1') then
                l1id_cnt <= x"000001";
            else
                if (ec0_cmd = '1' or resync_cmd = '1') then
                    l1id_cnt <= x"000001";
                elsif (l1a_cmd = '1') then
                    l1id_cnt <= std_logic_vector(unsigned(l1id_cnt) + 1);
                end if;
            end if;

        end if;
    end process p_l1id_cnt;

    p_bx_cnt:
    process(ttc_clks_i.clk_40) is
    begin
        if (rising_edge(ttc_clks_i.clk_40)) then
            if (reset = '1') then
                bx_cnt <= x"001";
            else
                if (bc0_cmd = '1') then
                    bx_cnt <= x"001";
                else
                    bx_cnt <= std_logic_vector(unsigned(bx_cnt) + 1);
                end if;
            end if;

        end if;
    end process p_bx_cnt;

    ------------- Monitoring -------------
    
    p_bc0_monitoring:
    process(ttc_clks_i.clk_40) is
    begin
        if (rising_edge(ttc_clks_i.clk_40)) then
            if (reset = '1' or ttc_ctrl.cnt_reset = '1') then
                ttc_status.bc0_status.err <= '0';
                ttc_status.bc0_status.locked <= '0';
                ttc_status.bc0_status.ovf_cnt <= (others => '0');
                ttc_status.bc0_status.udf_cnt <= (others => '0');
                ttc_status.bc0_status.unlocked_cnt <= (others => '0');
            elsif (bc0_cmd = '1') then            
                if (unsigned(bx_cnt) < unsigned(C_TTC_NUM_BXs)) then
                    ttc_status.bc0_status.err <= '1';
                    ttc_status.bc0_status.locked <= '0';
                    if (ttc_status.bc0_status.unlocked_cnt /= x"ffff") then
                        ttc_status.bc0_status.unlocked_cnt <= std_logic_vector(unsigned(ttc_status.bc0_status.unlocked_cnt) + 1);
                    end if; 
                    if (ttc_status.bc0_status.udf_cnt /= x"ffff") then
                        ttc_status.bc0_status.udf_cnt <= std_logic_vector(unsigned(ttc_status.bc0_status.udf_cnt) + 1);
                    end if; 
                elsif (unsigned(bx_cnt) > unsigned(C_TTC_NUM_BXs)) then
                    ttc_status.bc0_status.err <= '1';
                    ttc_status.bc0_status.locked <= '0';
                    if (ttc_status.bc0_status.unlocked_cnt /= x"ffff") then
                        ttc_status.bc0_status.unlocked_cnt <= std_logic_vector(unsigned(ttc_status.bc0_status.unlocked_cnt) + 1);
                    end if; 
                    if (ttc_status.bc0_status.ovf_cnt /= x"ffff") then
                        ttc_status.bc0_status.ovf_cnt <= std_logic_vector(unsigned(ttc_status.bc0_status.ovf_cnt) + 1);
                    end if; 
                else
                    ttc_status.bc0_status.err <= '0';
                    ttc_status.bc0_status.locked <= '1';
                end if;
            end if;
        end if;
    end process p_bc0_monitoring;

--    p_mini_spy:
--    process(clk_40) is
--    begin
--        if rising_edge(clk_40) then
--            if ttc_spy_reset = '1' then
--                ttc_spy_buffer <= (others => '0');
--            else
--            end if;
--        end if;
--    end process p_mini_spy;

    ttc_cmds_arr(0) <= l1a_cmd;
    ttc_cmds_arr(1) <= bc0_cmd;
    ttc_cmds_arr(2) <= ec0_cmd;
    ttc_cmds_arr(3) <= resync_cmd;
    ttc_cmds_arr(4) <= oc0_cmd;
    ttc_cmds_arr(5) <= hard_reset_cmd;
    ttc_cmds_arr(6) <= calpulse_cmd;
    ttc_cmds_arr(7) <= start_cmd;
    ttc_cmds_arr(8) <= stop_cmd;
    ttc_cmds_arr(9) <= test_sync_cmd;

    gen_ttc_cmd_cnt:
    for i in 0 to C_NUM_OF_DECODED_TTC_CMDS - 1 generate
        process(ttc_clks_i.clk_40) is
        begin
            if (rising_edge(ttc_clks_i.clk_40)) then
                if (ttc_ctrl.cnt_reset = '1' or reset = '1') then
                    ttc_cmds_cnt_arr(i) <= (others => '0');
                elsif (ttc_cmds_arr(i) = '1') then
                    ttc_cmds_cnt_arr(i) <= std_logic_vector(unsigned(ttc_cmds_cnt_arr(i)) + 1);
                end if;
            end if;
        end process;
    end generate;

    -- L1A rate counter
    i_l1a_rate_counter : entity work.rate_counter
    generic map(
        g_CLK_FREQUENCY => C_TTC_CLK_FREQUENCY_SLV,
        g_COUNTER_WIDTH => 32
    )
    port map(
        clk_i   => ttc_clks_i.clk_40,
        reset_i => reset,
        en_i    => l1a_cmd,
        rate_o  => l1a_rate
    );

    -- wiring
    ttc_daq_cntrs_o.orbit <= orbit_cnt;
    ttc_daq_cntrs_o.l1id  <= l1id_cnt;
    ttc_daq_cntrs_o.bx    <= bx_cnt;

    ttc_cmds_o.l1a        <= l1a_cmd;
    ttc_cmds_o.bc0        <= bc0_cmd;
    ttc_cmds_o.ec0        <= ec0_cmd;
    ttc_cmds_o.resync     <= resync_cmd;
    ttc_cmds_o.hard_reset <= hard_reset_cmd;
    ttc_cmds_o.calpulse   <= calpulse_cmd;
    ttc_cmds_o.start      <= start_cmd;
    ttc_cmds_o.stop       <= stop_cmd;
    ttc_cmds_o.test_sync  <= test_sync_cmd;

    --===============================================================================================
    -- this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py (do not edit) 
    --==== Registers begin ==========================================================================

    --==== Registers end ============================================================================

end ttc_arch;
--============================================================================
--                                                            Architecture end
--============================================================================
