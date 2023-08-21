------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    14:19 2016-10-05
-- Module Name:    slow_control
-- Description:    This module is mainly responsible for communication with Optohybrid SCA and reading/writing GBTx registers
------------------------------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.common_pkg.all;
use work.gem_pkg.all;
use work.sca_pkg.all;
use work.sca_config_pkg.all;
use work.ttc_pkg.all;
use work.ipbus.all;
use work.registers.all;

entity slow_control is
    generic(
        g_GEM_STATION       : integer;
        g_NUM_OF_OHs        : integer;
        g_NUM_GBTS_PER_OH   : integer;
        g_IPB_CLK_PERIOD_NS : integer;
        g_DEBUG             : boolean := false;
        g_DEBUG_IC          : boolean -- if this is set to true, some chipscope cores will be inserted in gbt_ic_controller.vhd
    );
    port(
        -- reset
        reset_i                 : in  std_logic;

        -- TTC
        ttc_clk_i               : in  t_ttc_clks;
        ttc_cmds_i              : in  t_ttc_cmds;
        
        -- SCA elinks
        gbt_rx_ready_i          : in  std_logic_vector(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0); 
        gbt_rx_sca_elinks_i     : in  t_std2_array(g_NUM_OF_OHs - 1 downto 0);
        gbt_tx_sca_elinks_o     : out t_std2_array(g_NUM_OF_OHs - 1 downto 0);
        
        -- GBTx IC elinks
        gbt_rx_ic_elinks_i      : in  t_std2_array(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);
        gbt_tx_ic_elinks_o      : out t_std2_array(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);
        
        -- VFAT3 slow control status
        vfat3_sc_status_i       : in t_vfat_slow_control_status; 
        
        -- IPbus
        ipb_reset_i             : in  std_logic;
        ipb_clk_i               : in  std_logic;
        ipb_miso_o              : out ipb_rbus;
        ipb_mosi_i              : in  ipb_wbus
        
    );
end slow_control;

architecture slow_control_arch of slow_control is

    --------------------------------- constants ---------------------------------    

    constant SCA_DEFAULT_GPIO_DIR           : std_logic_vector(31 downto 0) := select_slv32_by_station(g_GEM_STATION, x"00000000", SCA_DEFAULT_GPIO_DIR_GE11, SCA_DEFAULT_GPIO_DIR_GE21);
    constant SCA_DEFAULT_GPIO_OUT           : std_logic_vector(31 downto 0) := select_slv32_by_station(g_GEM_STATION, x"00000000", SCA_DEFAULT_GPIO_OUT_GE11, SCA_DEFAULT_GPIO_OUT_GE21);
    constant SCA_DEFAULT_GPIO_OUT_HR        : std_logic_vector(31 downto 0) := select_slv32_by_station(g_GEM_STATION, x"00000000", SCA_DEFAULT_GPIO_OUT_HR_GE11, SCA_DEFAULT_GPIO_OUT_HR_GE21);

    -- the messages in this array are executed in sequence after SCA CONTOLLER reset followed by SCA chip reset
    constant SCA_CONFIG_SEQUENCE : t_sca_command_array(0 to 6) := (
        (channel => SCA_CHANNEL_CONFIG, command => SCA_CMD_CONFIG_WRITE_CRB, length => x"01", data => x"00000004"),         -- enable GPIO
        (channel => SCA_CHANNEL_CONFIG, command => SCA_CMD_CONFIG_WRITE_CRC, length => x"01", data => x"00000000"),         -- disable I2C
        (channel => SCA_CHANNEL_CONFIG, command => SCA_CMD_CONFIG_WRITE_CRD, length => x"01", data => x"00000018"),         -- 0x18 enable JTAG and ADC
        (channel => SCA_CHANNEL_GPIO, command => SCA_CMD_GPIO_SET_DIR, length => x"04", data => SCA_DEFAULT_GPIO_DIR),      -- set GPIO direction to default
        (channel => SCA_CHANNEL_GPIO, command => SCA_CMD_GPIO_SET_OUT, length => x"04", data => SCA_DEFAULT_GPIO_OUT),      -- set GPIO ouputs to default
        (channel => SCA_CHANNEL_JTAG, command => SCA_CMD_JTAG_SET_CTRL_REG, length => x"04", data => SCA_CFG_JTAG_CTRL_REG),-- set JTAG control reg defaults
        (channel => SCA_CHANNEL_JTAG, command => SCA_CMD_JTAG_SET_FREQ, length => x"04", data => SCA_CFG_JTAG_FREQ)         -- set default JTAG clk frequency
    );
    
    --------------------------------- signals ---------------------------------    

    --============ SCA ============--
    
    -- general
    signal sca_reset                : std_logic;
    signal sca_reset_mask           : std_logic_vector(31 downto 0);
    signal sca_ready_arr            : std_logic_vector(31 downto 0);
    signal sca_critical_error_arr   : std_logic_vector(31 downto 0);
    signal sca_ttc_hr_enable        : std_logic_vector(31 downto 0);
    
    -- manual commands
    signal manual_hard_reset            : std_logic;
    signal sca_user_command             : t_sca_command;
    signal sca_user_command_en          : std_logic;
    signal sca_user_command_en_mask     : std_logic_vector(31 downto 0); -- command_en signal will only be sent to the channels that are enabled in this bitmask
    signal sca_user_command_done_arr    : std_logic_vector(g_NUM_OF_OHs - 1 downto 0);
    signal sca_user_command_done_latch  : std_logic_vector(g_NUM_OF_OHs - 1 downto 0) := (others => '0');
    signal sca_user_command_done_all    : std_logic;
    signal sca_user_reply_arr           : t_sca_reply_array(g_NUM_OF_OHs - 1 downto 0);
    
    -- core monitoring
    signal sca_not_ready_cnt_arr: t_std16_array(g_NUM_OF_OHs - 1 downto 0);
    signal sca_rx_err_cnt       : std_logic_vector(15 downto 0);
    signal sca_seq_num_err_cnt  : std_logic_vector(15 downto 0);
    signal sca_crc_err_cnt      : std_logic_vector(15 downto 0);
    signal sca_tr_timeout_cnt   : std_logic_vector(15 downto 0);
    signal sca_tr_fail_cnt      : std_logic_vector(15 downto 0);
    signal sca_tr_done_cnt      : std_logic_vector(31 downto 0);
    signal sca_last_sca_error   : std_logic_vector(6 downto 0);
    
    -- jtag
    signal jtag_enabled_mask        : std_logic_vector(31 downto 0);
    signal jtag_cmd_length          : std_logic_vector(6 downto 0);
    signal jtag_tdo                 : std_logic_vector(31 downto 0);
    signal jtag_tms                 : std_logic_vector(31 downto 0);
    signal jtag_tdi_arr             : t_std32_array(g_NUM_OF_OHs - 1 downto 0);
    signal jtag_shift_tdo_en        : std_logic; 
    signal jtag_shift_tms_en        : std_logic;
    signal jtag_shift_tdi_en_arr    : std_logic_vector(g_NUM_OF_OHs - 1 downto 0);
    signal jtag_shift_done_arr      : std_logic_vector(g_NUM_OF_OHs - 1 downto 0); 
    signal jtag_shift_done_latch    : std_logic_vector(g_NUM_OF_OHs - 1 downto 0) := (others => '0'); 
    signal jtag_shift_done_all      : std_logic; 
    signal jtag_shift_msb_first     : std_logic; -- tell SCA to shift out MSB first instead of the default LSB first
    signal jtag_exec_on_every_tdo   : std_logic; -- EXPERT ONLY: used to optimize firmware downloading, when set high the controller will execute JTAG_GO after every TDO shift (even if length is higher than 32)
    signal jtag_no_length_update    : std_logic; -- EXPERT ONLY: used to optimize firmware downloading, when set high the controller will assume that SCA already has the correct length and will not update it before each JTAG_GO
    signal jtag_shift_tdo_async     : std_logic; -- kindof expert: if this is set high then JTAG controller will assert jtag_shift_done_o immediately after TDO shift command, but if the second command is received while it's still busy it won't assert jtag_shift_done_o until the previous command is done
    
            
    -- debug
    signal sca_tx_raw_last_cmd  : std_logic_vector(95 downto 0);
    signal sca_rx_raw_last_reply: std_logic_vector(95 downto 0);
    signal sca_rx_last_calc_crc : std_logic_vector(15 downto 0);

    ------------- GBTx IC -------------

    signal ic_link_select       : std_logic_vector(5 downto 0);
    signal ic_rx_elink          : std_logic_vector(1 downto 0);
    signal ic_tx_elink          : std_logic_vector(1 downto 0);
    signal ic_rw_address        : std_logic_vector(15 downto 0);
    signal ic_write_data        : std_logic_vector(31 downto 0);
    signal ic_read_data         : std_logic_vector(31 downto 0);
    signal ic_rw_length         : std_logic_vector(2 downto 0);
    signal ic_write_req         : std_logic;
    signal ic_write_req_done    : std_logic;
    signal ic_read_req          : std_logic;
    signal ic_read_data_valid   : std_logic;
    signal ic_read_req_done     : std_logic;
    signal ic_read_stat         : std_logic_vector(6 downto 0);
    signal ic_gbt_i2c_addr      : std_logic_vector(6 downto 0);
    signal ic_gbt_frame_format  : std_logic_vector(1 downto 0);

    ------ Register signals begin (this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py -- do not edit)
    ------ Register signals end ----------------------------------------------

begin

    --======== SCA controller ========--
    
    g_sca_controllers : for i in 0 to g_NUM_OF_OHs - 1 generate
        i_sca_controller : entity work.sca_controller
            generic map (
                g_SCA_CONFIG_SEQUENCE     => SCA_CONFIG_SEQUENCE,
                g_SCA_DEFAULT_GPIO_OUT    => SCA_DEFAULT_GPIO_OUT,
                g_SCA_DEFAULT_GPIO_OUT_HR => SCA_DEFAULT_GPIO_OUT_HR,
                g_DEBUG => false --(i = 0)
            )
            port map(
                reset_i                     => reset_i or (sca_reset and sca_reset_mask(i)),
                gbt_clk_40_i                => ttc_clk_i.clk_40,
                clk_80_i                    => ttc_clk_i.clk_80,
            
                gbt_rx_ready_i              => gbt_rx_ready_i(i * g_NUM_GBTS_PER_OH),
                gbt_rx_sca_elink_i          => gbt_rx_sca_elinks_i(i),
                gbt_tx_sca_elink_o          => gbt_tx_sca_elinks_o(i),
            
                hard_reset_i                => manual_hard_reset or (ttc_cmds_i.hard_reset and sca_ttc_hr_enable(i)),
            
                user_command_i              => sca_user_command,
                user_command_en_i           => sca_user_command_en and sca_user_command_en_mask(i),
                user_reply_o                => sca_user_reply_arr(i),
                user_reply_valid_o          => sca_user_command_done_arr(i),
            
                jtag_enabled_i              => jtag_enabled_mask(i),
                jtag_cmd_length_i           => unsigned(jtag_cmd_length),
                jtag_tdo_i                  => jtag_tdo,
                jtag_tms_i                  => jtag_tms,
                jtag_tdi_o                  => jtag_tdi_arr(i),
                jtag_shift_tdo_en_i         => jtag_shift_tdo_en,
                jtag_shift_tms_en_i         => jtag_shift_tms_en,
                jtag_shift_tdi_en_i         => jtag_shift_tdi_en_arr(i),
                jtag_shift_done_o           => jtag_shift_done_arr(i),            
                jtag_shift_msb_first_i      => jtag_shift_msb_first,
                
                jtag_exec_on_every_tdo_i    => jtag_exec_on_every_tdo,
                jtag_no_length_update_i     => jtag_no_length_update,
                jtag_shift_tdo_async_i      => jtag_shift_tdo_async,
                                    
                ready_o                     => sca_ready_arr(i),
                critical_error_o            => sca_critical_error_arr(i),
                not_ready_cnt_o             => sca_not_ready_cnt_arr(i),
                rx_err_cnt_o                => open, --sca_rx_err_cnt,
                rx_seq_num_err_cnt_o        => open, --sca_seq_num_err_cnt,
                rx_crc_err_cnt_o            => open, --sca_crc_err_cnt,
                trans_timeout_cnt_o         => open, --sca_tr_timeout_cnt,
                trans_fail_cnt_o            => open, --sca_tr_fail_cnt,
                trans_done_cnt_o            => open, --sca_tr_done_cnt,
                last_sca_error_o            => open, --sca_last_sca_error,
                tx_raw_last_cmd_o           => open, --sca_tx_raw_last_cmd,
                rx_raw_last_reply_o         => open, --sca_rx_raw_last_reply,
                rx_last_calc_crc_o          => open  --sca_rx_last_calc_crc
            );
    end generate;

    ------------------- SCA done signal aggregation based on enabled channels -------------------
    
    -- manual command
    process(ttc_clk_i.clk_40)
    begin
        if (rising_edge(ttc_clk_i.clk_40)) then
            if (sca_user_command_en = '1') then
                sca_user_command_done_latch <= (others => '0');
            else
                sca_user_command_done_latch <= sca_user_command_done_latch or sca_user_command_done_arr;
            end if;
            
            if (sca_user_command_done_latch = sca_user_command_en_mask(g_NUM_OF_OHs - 1 downto 0)) then
                sca_user_command_done_all <= '1';
                sca_user_command_done_latch <= (others => '0');
            else
                sca_user_command_done_all <= '0';
            end if;
        end if;
    end process; 

    -- JTAG command
    process(ttc_clk_i.clk_40)
    begin
        if (rising_edge(ttc_clk_i.clk_40)) then
            if ((jtag_shift_tdo_en = '1') or (jtag_shift_tms_en = '1')) then
                jtag_shift_done_latch <= (others => '0');
            else
                jtag_shift_done_latch <= jtag_shift_done_latch or jtag_shift_done_arr;
            end if;
            
            if (jtag_shift_done_latch = jtag_enabled_mask(g_NUM_OF_OHs - 1 downto 0)) then
                jtag_shift_done_all <= '1';
                jtag_shift_done_latch <= (others => '0');
            else
                jtag_shift_done_all <= '0';
            end if;
        end if;
    end process;

    --======== GBTx IC ========--

    i_ic_controller : entity work.gbt_ic_controller
        generic map(
            g_DEBUG            => true
        )
        port map(
            reset_i             => reset_i,
            gbt_clk_i           => ttc_clk_i.clk_40,
            gbt_frame_format_i  => ic_gbt_frame_format,
            gbt_i2c_address     => ic_gbt_i2c_addr,
            gbt_rx_ic_elink_i   => ic_rx_elink,
            gbt_tx_ic_elink_o   => ic_tx_elink,
            ic_rw_address_i     => ic_rw_address,
            ic_rw_length_i      => ic_rw_length,
            ic_w_data_i         => ic_write_data,
            ic_r_data_o         => ic_read_data,
            ic_r_data_valid_o   => ic_read_data_valid,
            ic_r_stat_o         => ic_read_stat,
            ic_write_req_i      => ic_write_req,
            ic_write_req_done_o => ic_write_req_done,
            ic_read_req_i       => ic_read_req,
            ic_read_req_done_o  => ic_read_req_done
        );

    ic_rx_elink <= gbt_rx_ic_elinks_i(to_integer(unsigned(ic_link_select)));
    g_ic_tx_generate: for i in 0 to g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 generate
        gbt_tx_ic_elinks_o(i) <= ic_tx_elink when to_integer(unsigned(ic_link_select)) = i else (others => '1'); 
    end generate;

    --===============================================================================================
    -- this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py (do not edit) 
    --==== Registers begin ==========================================================================

    --==== Registers end ============================================================================
        
end slow_control_arch;
