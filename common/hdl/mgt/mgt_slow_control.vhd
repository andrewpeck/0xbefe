------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2020-06-16
-- Module Name:    MGT_SLOW_CONTROL 
-- Description:    Slow control interface for MGTs    
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;

library xpm;
use xpm.vcomponents.all;

use work.common_pkg.all;
use work.mgt_pkg.all;
use work.board_config_package.all;
use work.ipbus.all;
use work.registers.all;

entity mgt_slow_control is
    generic(
        g_NUM_CHANNELS          : integer;
        g_LINK_CONFIG           : t_mgt_config_arr;
        g_ENABLE_CHAN_DRP       : boolean;        
        g_ENABLE_QPLL_DRP       : boolean;        
        g_IPB_CLK_PERIOD_NS     : integer;
        g_STABLE_CLK_PERIOD_NS  : integer
    );
    port(
        
        clk_stable_i            : in  std_logic;

        channel_refclk_arr_i    : in  t_mgt_refclks_arr(g_NUM_CHANNELS-1 downto 0);
        
        mgt_clks_arr_i          : in  t_mgt_clk_in_arr(g_NUM_CHANNELS - 1 downto 0);

        tx_reset_arr_o          : out std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
        rx_reset_arr_o          : out std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
        cpll_reset_arr_o        : out std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
        
        tx_slow_ctrl_arr_o      : out t_mgt_tx_slow_ctrl_arr(g_NUM_CHANNELS - 1 downto 0);
        rx_slow_ctrl_arr_o      : out t_mgt_rx_slow_ctrl_arr(g_NUM_CHANNELS - 1 downto 0);
        misc_ctrl_arr_o         : out t_mgt_misc_ctrl_arr(g_NUM_CHANNELS - 1 downto 0);
        qpll_ctrl_arr_o         : out t_mgt_qpll_ctrl_arr(g_NUM_CHANNELS - 1 downto 0);

        tx_status_arr_i         : in  t_mgt_tx_status_arr(g_NUM_CHANNELS - 1 downto 0);
        rx_status_arr_i         : in  t_mgt_rx_status_arr(g_NUM_CHANNELS - 1 downto 0);
        misc_status_arr_i       : in  t_mgt_misc_status_arr(g_NUM_CHANNELS - 1 downto 0);
        ibert_eyescanreset_i    : in  std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
        qpll_status_arr_i       : in  t_mgt_qpll_status_arr(g_NUM_CHANNELS - 1 downto 0);
        
        tx_reset_done_arr_i     : in  std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
        rx_reset_done_arr_i     : in  std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
        tx_phalign_done_arr_i   : in  std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
        rx_phalign_done_arr_i   : in  std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
        
        cpll_status_arr_i       : in  t_mgt_cpll_status_arr(g_NUM_CHANNELS - 1 downto 0);
        
        chan_drp_mosi_arr_o     : out t_drp_mosi_arr(g_NUM_CHANNELS - 1 downto 0);
        chan_drp_miso_arr_i     : in  t_drp_miso_arr(g_NUM_CHANNELS - 1 downto 0);

        qpll_drp_mosi_arr_o     : out t_drp_mosi_arr(g_NUM_CHANNELS - 1 downto 0);
        qpll_drp_miso_arr_i     : in  t_drp_miso_arr(g_NUM_CHANNELS - 1 downto 0);
        
        ipb_clk_i               : in  std_logic;
        ipb_reset_i             : in  std_logic;
        ipb_mosi_i              : in  ipb_wbus;
        ipb_miso_o              : out ipb_rbus
    );
end mgt_slow_control;

architecture mgt_slow_control_arch of mgt_slow_control is

    constant CPLLPD_PULSE_LENGTH    : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(2_000 / g_STABLE_CLK_PERIOD_NS, 12)); -- 2us

    signal tx_slow_ctrl_arr         : t_mgt_tx_slow_ctrl_arr(g_NUM_CHANNELS - 1 downto 0);
    signal rx_slow_ctrl_arr         : t_mgt_rx_slow_ctrl_arr(g_NUM_CHANNELS - 1 downto 0);
    signal misc_ctrl_arr            : t_mgt_misc_ctrl_arr(g_NUM_CHANNELS - 1 downto 0) := (others => (loopback => "000", eyescanreset => '0', eyescantrigger => '0'));
        
    signal cpll_reset_arr           : std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
    signal loopback_arr             : std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
    signal txpd_arr                 : std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
    signal rxpd_arr                 : std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
    signal prbs_err_reset_arr       : std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
    signal prbs_err_reset_sync_arr  : std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
    signal prbs_err_cnt_arr         : t_std32_array(g_NUM_CHANNELS - 1 downto 0);    
    signal prbs_err_cnt_sync_arr    : t_std32_array(g_NUM_CHANNELS - 1 downto 0);    

    -- eyescan signals
    signal es_reset_arr             : std_logic_vector(g_NUM_CHANNELS - 1 downto 0) := (others => '0');
    signal es_err_cnt_async_arr     : t_std32_array(g_NUM_CHANNELS - 1 downto 0) := (others => (others => '0'));
    signal es_err_cnt_arr           : t_std32_array(g_NUM_CHANNELS - 1 downto 0) := (others => (others => '0'));
    signal es_err_reset_async_arr   : std_logic_vector(g_NUM_CHANNELS - 1 downto 0) := (others => '0');
    signal es_err_reset_arr         : std_logic_vector(g_NUM_CHANNELS - 1 downto 0) := (others => '0');

    -- control signals that need to be transfered to another clk domain
    signal rxpolarity_arr_async     : std_logic_vector(g_NUM_CHANNELS - 1 downto 0) := (others => '0');
    signal rxprbssel_arr_async      : t_std3_array(g_NUM_CHANNELS - 1 downto 0) := (others => (others => '0'));
    signal txinhibit_arr_async      : std_logic_vector(g_NUM_CHANNELS - 1 downto 0) := (others => '0');
    signal txpolarity_arr_async     : std_logic_vector(g_NUM_CHANNELS - 1 downto 0) := (others => '0');
    signal txprbssel_arr_async      : t_std4_array(g_NUM_CHANNELS - 1 downto 0) := (others => (others => '0'));
    signal txprbsforceerr_arr_async : std_logic_vector(g_NUM_CHANNELS - 1 downto 0) := (others => '0');
    signal txpd_arr_async           : std_logic_vector(g_NUM_CHANNELS - 1 downto 0) := (others => '0');
    
    -- status signals that need to be transfered to another clk domain
    signal rxchanisaligned          : std_logic_vector(g_NUM_CHANNELS - 1 downto 0) := (others => '0'); 

    -- channel DRP
    signal chan_drp_mgt_select      : std_logic_vector(6 downto 0);
    signal chan_drp_write_strobe    : std_logic;
    signal chan_drp_read_strobe     : std_logic;
    signal chan_drp_mosi            : t_drp_mosi;
    signal chan_drp_miso            : t_drp_miso;

    -- channel DRP
    signal qpll_drp_mgt_select      : std_logic_vector(6 downto 0);
    signal qpll_drp_write_strobe    : std_logic;
    signal qpll_drp_read_strobe     : std_logic;
    signal qpll_drp_mosi            : t_drp_mosi;
    signal qpll_drp_miso            : t_drp_miso;

    ------ Register signals begin (this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py -- do not edit)
    ------ Register signals end ----------------------------------------------

begin

    tx_slow_ctrl_arr_o <= tx_slow_ctrl_arr;
    rx_slow_ctrl_arr_o <= rx_slow_ctrl_arr;
    misc_ctrl_arr_o <= misc_ctrl_arr;
    
    g_channels : for chan in 0 to g_NUM_CHANNELS - 1 generate
        -- ibert
        misc_ctrl_arr(chan).eyescanreset <= ibert_eyescanreset_i(chan) or es_reset_arr(chan);
    
        -- loopback and PD controll
        misc_ctrl_arr(chan).loopback <= "000" when loopback_arr(chan) = '0' else "010";
        tx_slow_ctrl_arr(chan).txpd <= "00" when txpd_arr(chan) = '0' else "11";
        rx_slow_ctrl_arr(chan).rxpd <= "00" when rxpd_arr(chan) = '0' else "11";
        rx_slow_ctrl_arr(chan).rxbufreset <= '0';
        rx_slow_ctrl_arr(chan).rxrate <= "000";

        -- prbs error counting
        i_sync_prbs_err_reset : entity work.synch generic map(N_STAGES => 8, IS_RESET => false) port map(async_i => prbs_err_reset_arr(chan), clk_i => mgt_clks_arr_i(chan).rxusrclk2, sync_o  => prbs_err_reset_sync_arr(chan));
                
        i_prbs_cnt : entity work.counter
            generic map(
                g_COUNTER_WIDTH  => 32,
                g_ALLOW_ROLLOVER => false,
                g_INPUT_REG_STAGES => 1
            )
            port map(
                ref_clk_i => mgt_clks_arr_i(chan).rxusrclk2,
                reset_i   => prbs_err_reset_sync_arr(chan),
                en_i      => rx_status_arr_i(chan).rxprbserr,
                count_o   => prbs_err_cnt_arr(chan)
            );
        
        i_sync_prbs_err_cnt : xpm_cdc_gray
            generic map(
                DEST_SYNC_FF          => 8,
                REG_OUTPUT            => 1,
                WIDTH                 => 32
            )
            port map(
                src_clk      => mgt_clks_arr_i(chan).rxusrclk2,
                src_in_bin   => prbs_err_cnt_arr(chan),
                dest_clk     => clk_stable_i,
                dest_out_bin => prbs_err_cnt_sync_arr(chan)
            );
        
        i_eyescan_err_cnt : entity work.counter
            generic map(
                g_COUNTER_WIDTH    => 32,
                g_ALLOW_ROLLOVER   => false,
                g_INPUT_REG_STAGES => 1
            )
            port map(
                ref_clk_i => mgt_clks_arr_i(chan).rxusrclk2,
                reset_i   => es_err_reset_arr(chan),
                en_i      => misc_status_arr_i(chan).eyescandataerror,
                count_o   => es_err_cnt_async_arr(chan)
            );

        i_sync_eyescan_err_cnt : xpm_cdc_gray
            generic map(
                DEST_SYNC_FF          => 8,
                REG_OUTPUT            => 1,
                WIDTH                 => 32
            )
            port map(
                src_clk      => mgt_clks_arr_i(chan).rxusrclk2,
                src_in_bin   => es_err_cnt_async_arr(chan),
                dest_clk     => clk_stable_i,
                dest_out_bin => es_err_cnt_arr(chan)
            );

        
        -- CPLL is reset using the CPLLPD port, which has a required pulse length of 2us or more
        i_cpll_reset_pulse_extend : entity work.pulse_extend
            generic map(
                DELAY_CNT_LENGTH => 12
            )
            port map(
                clk_i          => clk_stable_i,
                rst_i          => '0',
                pulse_length_i => CPLLPD_PULSE_LENGTH,
                pulse_i        => cpll_reset_arr(chan),
                pulse_o        => cpll_reset_arr_o(chan)
            );
       
        -- control CDC
        i_sync_rxpolarity:     entity work.synch generic map(N_STAGES => 8, IS_RESET => false) port map(async_i => rxpolarity_arr_async(chan), clk_i => mgt_clks_arr_i(chan).rxusrclk2, sync_o  => rx_slow_ctrl_arr(chan).rxpolarity);
        i_sync_rxprbssel0:     entity work.synch generic map(N_STAGES => 8, IS_RESET => false) port map(async_i => rxprbssel_arr_async(chan)(0), clk_i => mgt_clks_arr_i(chan).rxusrclk2, sync_o  => rx_slow_ctrl_arr(chan).rxprbssel(0));
        i_sync_rxprbssel1:     entity work.synch generic map(N_STAGES => 8, IS_RESET => false) port map(async_i => rxprbssel_arr_async(chan)(1), clk_i => mgt_clks_arr_i(chan).rxusrclk2, sync_o  => rx_slow_ctrl_arr(chan).rxprbssel(1));
        i_sync_rxprbssel2:     entity work.synch generic map(N_STAGES => 8, IS_RESET => false) port map(async_i => rxprbssel_arr_async(chan)(2), clk_i => mgt_clks_arr_i(chan).rxusrclk2, sync_o  => rx_slow_ctrl_arr(chan).rxprbssel(2));
        i_sync_txinhibit:      entity work.synch generic map(N_STAGES => 8, IS_RESET => false) port map(async_i => txinhibit_arr_async(chan), clk_i => mgt_clks_arr_i(chan).txusrclk2, sync_o  => tx_slow_ctrl_arr(chan).txinhibit);
        i_sync_txpolarity:     entity work.synch generic map(N_STAGES => 8, IS_RESET => false) port map(async_i => txpolarity_arr_async(chan), clk_i => mgt_clks_arr_i(chan).txusrclk2, sync_o  => tx_slow_ctrl_arr(chan).txpolarity);
        i_sync_txprbssel0:     entity work.synch generic map(N_STAGES => 8, IS_RESET => false) port map(async_i => txprbssel_arr_async(chan)(0), clk_i => mgt_clks_arr_i(chan).txusrclk2, sync_o  => tx_slow_ctrl_arr(chan).txprbssel(0));
        i_sync_txprbssel1:     entity work.synch generic map(N_STAGES => 8, IS_RESET => false) port map(async_i => txprbssel_arr_async(chan)(1), clk_i => mgt_clks_arr_i(chan).txusrclk2, sync_o  => tx_slow_ctrl_arr(chan).txprbssel(1));
        i_sync_txprbssel2:     entity work.synch generic map(N_STAGES => 8, IS_RESET => false) port map(async_i => txprbssel_arr_async(chan)(2), clk_i => mgt_clks_arr_i(chan).txusrclk2, sync_o  => tx_slow_ctrl_arr(chan).txprbssel(2));
        i_sync_txprbssel3:     entity work.synch generic map(N_STAGES => 8, IS_RESET => false) port map(async_i => txprbssel_arr_async(chan)(3), clk_i => mgt_clks_arr_i(chan).txusrclk2, sync_o  => tx_slow_ctrl_arr(chan).txprbssel(3));
        i_sync_txprbsforceerr: entity work.synch generic map(N_STAGES => 8, IS_RESET => false) port map(async_i => txprbsforceerr_arr_async(chan), clk_i => mgt_clks_arr_i(chan).txusrclk2, sync_o  => tx_slow_ctrl_arr(chan).txprbsforceerr);
        i_sync_txpd:           entity work.synch generic map(N_STAGES => 8, IS_RESET => false) port map(async_i => txpd_arr_async(chan), clk_i => mgt_clks_arr_i(chan).txusrclk2, sync_o  => txpd_arr(chan));
        i_sync_es_err_cnt_rst: entity work.synch generic map(N_STAGES => 8, IS_RESET => true ) port map(async_i => es_err_reset_async_arr(chan), clk_i => mgt_clks_arr_i(chan).rxusrclk2, sync_o  => es_err_reset_arr(chan));

        -- status CDC
        i_sync_rxchanisaligned: entity work.synch generic map(N_STAGES => 8, IS_RESET => false) port map(async_i => rx_status_arr_i(chan).rxchanisaligned, clk_i => clk_stable_i, sync_o  => rxchanisaligned(chan));
        	                       
    end generate;

    -- channel DRP
    g_chan_drp: if g_ENABLE_CHAN_DRP generate
        chan_drp_mosi.en <= chan_drp_read_strobe or chan_drp_write_strobe;
        chan_drp_mosi.we <= chan_drp_write_strobe;
        
        i_chan_drp_mux : entity work.drp_mux
            generic map(
                g_NUM_DRP_SEL_BITS => 7,
                g_NUM_DRP_BUSES    => g_NUM_CHANNELS
            )
            port map(
                drp_clk_i        => ipb_clk_i,
                drp_bus_select_i => chan_drp_mgt_select,
                drp_mosi_i       => chan_drp_mosi,
                drp_miso_o       => chan_drp_miso,
                drp_mosi_arr_o   => chan_drp_mosi_arr_o,
                drp_miso_arr_i   => chan_drp_miso_arr_i
            );
    end generate;

    g_no_chan_drp: if not g_ENABLE_CHAN_DRP generate
        chan_drp_mosi_arr_o <= (others => DRP_MOSI_NULL);
    end generate;

    -- QPLL DRP
    g_qpll_drp: if g_ENABLE_QPLL_DRP generate
        qpll_drp_mosi.en <= qpll_drp_read_strobe or qpll_drp_write_strobe;
        qpll_drp_mosi.we <= qpll_drp_write_strobe;
        
        i_qpll_drp_mux : entity work.drp_mux
            generic map(
                g_NUM_DRP_SEL_BITS => 7,
                g_NUM_DRP_BUSES    => g_NUM_CHANNELS
            )
            port map(
                drp_clk_i        => ipb_clk_i,
                drp_bus_select_i => qpll_drp_mgt_select,
                drp_mosi_i       => qpll_drp_mosi,
                drp_miso_o       => qpll_drp_miso,
                drp_mosi_arr_o   => qpll_drp_mosi_arr_o,
                drp_miso_arr_i   => qpll_drp_miso_arr_i
            );
    end generate;                   

    g_no_qpll_drp: if not g_ENABLE_QPLL_DRP generate
        qpll_drp_mosi_arr_o <= (others => DRP_MOSI_NULL);
    end generate;


    --===============================================================================================
    -- this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py (do not edit) 
    --==== Registers begin ==========================================================================

    --==== Registers end ============================================================================

end mgt_slow_control_arch;
