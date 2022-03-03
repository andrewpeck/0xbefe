------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2021-03-19
-- Module Name:    SLINK_ROCKET 
-- Description:    This is a wrapper of the slink rocket IP from the CMS DAQ group + the required bits and pieces like QPLL, and slow control 
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;

use work.common_pkg.all;
use work.ipbus.all;
use work.registers.all;

entity slink_rocket is
    generic(
        g_NUM_CHANNELS          : integer;
        g_LINE_RATE             : string := "25.78125";   --possible choices are 15.66 or 25.78125
        q_REF_CLK_FREQ          : string := "322.265625"; --possible choices are 156.25 or 322.265625 
        g_MGT_TYPE              : string := "GTY";        -- possible choices are GTY or GTH or GTH_KU
        g_IPB_CLK_PERIOD_NS     : integer
    );
    port(
        
        reset_i                 : in  std_logic;
        clk_stable_100_i        : in  std_logic;
        
        mgt_ref_clk_i           : in  std_logic;

        daq_to_daqlink_i        : in  t_daq_to_daqlink_arr(g_NUM_CHANNELS - 1 downto 0);
        daqlink_to_daq_o        : out t_daqlink_to_daq_arr(g_NUM_CHANNELS - 1 downto 0);
        
        ipb_reset_i             : in  std_logic;
        ipb_clk_i               : in  std_logic;
        ipb_mosi_i              : in  ipb_wbus;
        ipb_miso_o              : out ipb_rbus
        
    );
end slink_rocket;

architecture slink_rocket_arch of slink_rocket is

    component slink_rocket_master
        port(
            aresetn                    : in  std_logic;
            txdiffctrl_in              : in  std_logic_vector(4 downto 0);
            txpostcursor_in            : in  std_logic_vector(4 downto 0);
            txprecursor_in             : in  std_logic_vector(4 downto 0);
            srds_loopback_in           : in  std_logic;
            core_status_addr           : in  std_logic_vector(15 downto 0);
            core_status_data_out       : out std_logic_vector(63 downto 0);
            user_100mhz_clk            : in  std_logic;
            fed_clock                  : in  std_logic;
            event_data_word            : in  std_logic_vector(127 downto 0);
            event_ctrl                 : in  std_logic;
            event_data_wen             : in  std_logic;
            backpressure               : out std_logic;
            link_down_n                : out std_logic;
            ext_trigger                : in  std_logic;
            ext_veto_out               : out std_logic;
            qpll_lock_in               : in  std_logic;
            qpll_reset_out             : out std_logic;
            qpll_clkin                 : in  std_logic;
            qpll_ref_clkin             : in  std_logic;
            gtm_reset_tx_clock_in_0    : in  std_logic;
            gtm_reset_tx_clock_in_1    : in  std_logic;
            gtm_reset_tx_clock_in_2    : in  std_logic;
            gtm_userclk_tx_active_out  : out std_logic;
            gtm_userclk_tx_usrclk_out  : out std_logic;
            gtm_userclk_tx_usrclk2_out : out std_logic;
            gtm_userclk_tx_usrclk4_out : out std_logic;
            snd_gt_rxn_in              : in  std_logic;
            snd_gt_rxp_in              : in  std_logic;
            snd_gt_txn_out             : out std_logic;
            snd_gt_txp_out             : out std_logic;
            rst_hrd_sim                : in  std_logic
        );
    end component;
    
    component slink_rocket_slave
        port(
            aresetn                   : in  std_logic;
            txdiffctrl_in             : in  std_logic_vector(4 downto 0);
            txpostcursor_in           : in  std_logic_vector(4 downto 0);
            txprecursor_in            : in  std_logic_vector(4 downto 0);
            srds_loopback_in          : in  std_logic;
            core_status_addr          : in  std_logic_vector(15 downto 0);
            core_status_data_out      : out std_logic_vector(63 downto 0);
            user_100mhz_clk           : in  std_logic;
            fed_clock                 : in  std_logic;
            event_data_word           : in  std_logic_vector(127 downto 0);
            event_ctrl                : in  std_logic;
            event_data_wen            : in  std_logic;
            backpressure              : out std_logic;
            link_down_n               : out std_logic;
            ext_trigger               : in  std_logic;
            ext_veto_out              : out std_logic;
            qpll_lock_in              : in  std_logic;
            qpll_reset_out            : out std_logic;
            qpll_clkin                : in  std_logic;
            qpll_ref_clkin            : in  std_logic;
            gts_reset_tx_clock_out    : out std_logic;
            gts_userclk_tx_active_in  : in  std_logic;
            gts_userclk_tx_usrclk_in  : in  std_logic;
            gts_userclk_tx_usrclk2_in : in  std_logic;
            gts_userclk_tx_usrclk4_in : in  std_logic;
            snd_gt_rxn_in             : in  std_logic;
            snd_gt_rxp_in             : in  std_logic;
            snd_gt_txn_out            : out std_logic;
            snd_gt_txp_out            : out std_logic;
            rst_hrd_sim               : in  std_logic
        );
    end component;    
    
    --------------------------------------------------------------------------
    
    constant HEADER_BOE         : std_logic_vector(7 downto 0) := x"55";
    constant HEADER_EOE         : std_logic_vector(7 downto 0) := x"AA";
    constant HEADER_VERSION     : std_logic_vector(3 downto 0) := x"1";
                                
    signal reset                : std_logic;
    signal reset_local          : std_logic;
                                
    signal fed_clk              : std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
                                
    signal txdiffctrl           : std_logic_vector(4 downto 0);
    signal txprecursor          : std_logic_vector(4 downto 0);
    signal txpostcursor         : std_logic_vector(4 downto 0);
                                
    signal qpll_lock            : std_logic;
    signal qpll_reset           : std_logic;
    signal qpll_clk             : std_logic;
    signal qpll_ref_clk         : std_logic;
                                
    signal gtm_reset_tx_clock   : std_logic_vector(2 downto 0);
    signal gtm_usrclk_tx_active : std_logic;
    signal gtm_tx_usrclk        : std_logic_vector(2 downto 0);
                                
    signal status_addr          : t_std16_array(g_NUM_CHANNELS - 1 downto 0);
    signal status_data          : t_std64_array(g_NUM_CHANNELS - 1 downto 0);
                                
    signal fed_data             : t_std128_array(g_NUM_CHANNELS - 1 downto 0);
    signal fed_data_head        : std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
    signal fed_data_trail       : std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
    signal fed_data_we          : std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
                                
    signal fed_data_d           : t_std128_array(g_NUM_CHANNELS - 1 downto 0);
    signal fed_data_head_d      : std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
    signal fed_data_trail_d     : std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
    signal fed_data_we_d        : std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
                                
    signal backpressure         : std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
    signal link_up              : std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
                                
    signal crc                  : t_std16_array(g_NUM_CHANNELS - 1 downto 0);
    signal crc_data_in          : t_std128_array(g_NUM_CHANNELS - 1 downto 0);
    signal crc_clear            : std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
    signal crc_en               : std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
                                
    signal daq_data             : t_std128_array(g_NUM_CHANNELS - 1 downto 0);
    signal daq_data_head        : std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
    signal daq_data_trail       : std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
    signal daq_data_we          : std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
    signal daq_crc_clear        : std_logic_vector(g_NUM_CHANNELS - 1 downto 0);
    
    ---------- simple event generator ----------
    type t_state is (IDLE, HEAD, DATA, TRAIL);
    
    signal gen_enable           : std_logic;
    signal gen_ignore_chans     : std_logic_vector(15 downto 0);
    signal gen_event_gap        : std_logic_vector(31 downto 0);
    signal gen_data_msg         : std_logic_vector(127 downto 0);
                                
    signal gen_state            : t_state := IDLE;
    signal gen_evt_cnt          : unsigned(43 downto 0);
    signal gen_data             : std_logic_vector(127 downto 0);
    signal gen_data_head        : std_logic;
    signal gen_data_trail       : std_logic;
    signal gen_data_we          : std_logic;
    signal gen_crc_clear        : std_logic;
        
    ------ Register signals begin (this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py -- do not edit)
    ------ Register signals end ----------------------------------------------
    
begin

    ------------ wiring ------------

    reset <= reset_i or reset_local;

    ------------ QPLL ------------
    
    i_qpll : entity work.QPLL_wrapper_select
        generic map(
            throughput => g_LINE_RATE,
            ref_clock  => q_REF_CLK_FREQ,
            technology => g_MGT_TYPE
        )
        port map(
            gtrefclk00_in      => mgt_ref_clk_i,
            gtrefclk01_in      => '0',
            qpll0reset_in      => qpll_reset,
            qpll1reset_in      => reset,
            
            qpll0lock_out      => qpll_lock,
            qpll0outclk_out    => qpll_clk,
            qpll0outrefclk_out => qpll_ref_clk
        );
    
    g_channels : for chan in 0 to g_NUM_CHANNELS - 1 generate
        
        daqlink_to_daq_o(chan).backpressure <= backpressure(chan);
        daqlink_to_daq_o(chan).ready <= link_up(chan);
        daqlink_to_daq_o(chan).disperr_cnt <= (others => '0');
        daqlink_to_daq_o(chan).notintable_cnt <= (others => '0');
    
        fed_clk(chan) <= daq_to_daqlink_i(chan).event_clk;
        daq_data(chan) <= daq_to_daqlink_i(chan).event_data;
        daq_data_head(chan) <= daq_to_daqlink_i(chan).event_header;
        daq_data_trail(chan) <= daq_to_daqlink_i(chan).event_trailer;
        daq_data_we(chan) <= daq_to_daqlink_i(chan).event_valid;
        
        ------------ slink inst ------------
        
        g_master_chan : if chan = 0 generate
            i_slink_master : slink_rocket_master
                port map(
                    aresetn                    => not reset,
                    txdiffctrl_in              => txdiffctrl,
                    txpostcursor_in            => txprecursor,
                    txprecursor_in             => txpostcursor,
                    srds_loopback_in           => '0',
                    core_status_addr           => status_addr(chan),
                    core_status_data_out       => status_data(chan),
                    user_100mhz_clk            => clk_stable_100_i,
                    fed_clock                  => fed_clk(chan),
                    event_data_word            => fed_data(chan),
                    event_ctrl                 => fed_data_head(chan) or fed_data_trail(chan),
                    event_data_wen             => fed_data_we(chan),
                    backpressure               => backpressure(chan),
                    link_down_n                => link_up(chan),
                    ext_trigger                => '0',
                    ext_veto_out               => open,
                    qpll_lock_in               => qpll_lock,
                    qpll_reset_out             => qpll_reset,
                    qpll_clkin                 => qpll_clk,
                    qpll_ref_clkin             => qpll_ref_clk,
                    
                    gtm_reset_tx_clock_in_0    => gtm_reset_tx_clock(0),
                    gtm_reset_tx_clock_in_1    => gtm_reset_tx_clock(1),
                    gtm_reset_tx_clock_in_2    => gtm_reset_tx_clock(2),
                    gtm_userclk_tx_active_out  => gtm_usrclk_tx_active,
                    gtm_userclk_tx_usrclk_out  => gtm_tx_usrclk(0),
                    gtm_userclk_tx_usrclk2_out => gtm_tx_usrclk(1),
                    gtm_userclk_tx_usrclk4_out => gtm_tx_usrclk(2),
                    
                    snd_gt_rxn_in              => '0',
                    snd_gt_rxp_in              => '1',
                    snd_gt_txn_out             => open,
                    snd_gt_txp_out             => open,
                    rst_hrd_sim                => '0'
                );            
        end generate;

        g_slave_chan : if chan /= 0 generate
            i_slink_slave : slink_rocket_slave
                port map(
                    aresetn                    => not reset,
                    txdiffctrl_in              => txdiffctrl,
                    txpostcursor_in            => txprecursor,
                    txprecursor_in             => txpostcursor,
                    srds_loopback_in           => '0',
                    core_status_addr           => status_addr(chan),
                    core_status_data_out       => status_data(chan),
                    user_100mhz_clk            => clk_stable_100_i,
                    fed_clock                  => fed_clk(chan),
                    event_data_word            => fed_data(chan),
                    event_ctrl                 => fed_data_head(chan) or fed_data_trail(chan),
                    event_data_wen             => fed_data_we(chan),
                    backpressure               => backpressure(chan),
                    link_down_n                => link_up(chan),
                    ext_trigger                => '0',
                    ext_veto_out               => open,
                    qpll_lock_in               => qpll_lock,
                    qpll_reset_out             => open,
                    qpll_clkin                 => qpll_clk,
                    qpll_ref_clkin             => qpll_ref_clk,

                    gts_reset_tx_clock_out     => gtm_reset_tx_clock(chan - 1),
                    gts_userclk_tx_active_in   => gtm_usrclk_tx_active,
                    gts_userclk_tx_usrclk_in   => gtm_tx_usrclk(0),
                    gts_userclk_tx_usrclk2_in  => gtm_tx_usrclk(1),
                    gts_userclk_tx_usrclk4_in  => gtm_tx_usrclk(2),

                    snd_gt_rxn_in              => '0',
                    snd_gt_rxp_in              => '1',
                    snd_gt_txn_out             => open,
                    snd_gt_txp_out             => open,
                    rst_hrd_sim                => '0'
                );            
        end generate;      
           
        --============ Select the data source and calculate CRC ====================
            
        process(fed_clk(chan))
        begin
            if rising_edge(fed_clk(chan)) then
                if gen_enable = '1' then
                    fed_data_d(chan)       <= gen_data;
                    fed_data_head_d(chan)  <= gen_data_head;
                    fed_data_trail_d(chan) <= gen_data_trail;
                    fed_data_we_d(chan)    <= gen_data_we;
                else
                    fed_data_d(chan)       <= daq_data(chan);
                    fed_data_head_d(chan)  <= daq_data_head(chan);
                    fed_data_trail_d(chan) <= daq_data_trail(chan);
                    fed_data_we_d(chan)    <= daq_data_we(chan);
                    daq_crc_clear(chan)    <= daq_to_daqlink_i(chan).event_trailer;
                end if;
                
                -- substitute the CRC
                if fed_data_trail_d(chan) = '1' then
                    fed_data(chan)(31 downto 16) <= crc(chan);
                else
                    fed_data(chan)(31 downto 16) <= fed_data_d(chan)(31 downto 16);
                end if;
                fed_data(chan)(127 downto 32) <= fed_data_d(chan)(127 downto 32);
                fed_data(chan)(15 downto 0) <= fed_data_d(chan)(15 downto 0);
                fed_data_head(chan)    <= fed_data_head_d(chan);
                fed_data_trail(chan)   <= fed_data_trail_d(chan);
                fed_data_we(chan)      <= fed_data_we_d(chan);            
            end if;
        end process;
        
        ------------ CRC ------------
    
        crc_en(chan) <= gen_data_we when gen_enable = '1' else daq_data_we(chan);
        crc_data_in(chan) <= gen_data when gen_enable = '1' else daq_data(chan);
        crc_clear(chan) <= gen_crc_clear when gen_enable = '1' else daq_crc_clear(chan) or daq_to_daqlink_i(chan).reset;
        
        i_crc : entity work.FED_fragment_CRC16_D128b
            port map ( 
                clear_p  => crc_clear(chan) or reset,
                clk      => fed_clk(chan),
                enable   => crc_en(chan),
                Data     => crc_data_in(chan),
                CRC_out  => crc(chan)
            );

    end generate;
    
    g_fake_slave_signals : if g_NUM_CHANNELS = 1 generate
        gtm_reset_tx_clock <= (others => '0');
    end generate;
    
    ------------ Event generator ------------
    
    process(fed_clk(0))
        variable cntdown    : unsigned(31 downto 0) := (others => '0');
    begin
        if rising_edge(fed_clk(0)) then
            if reset = '1' then
                gen_state <= IDLE;
                gen_crc_clear <= '1';
                gen_data <= (others => '0');
                gen_data_head <= '0';
                gen_data_trail <= '0';
                gen_data_we <= '0';
                gen_evt_cnt <= (others => '0');
            else
                
                if or_reduce(link_up or gen_ignore_chans(g_NUM_CHANNELS - 1 downto 0)) = '1' and or_reduce(backpressure or gen_ignore_chans(g_NUM_CHANNELS - 1 downto 0))= '0' then 
                    
                    case gen_state is
                        
                        when IDLE =>
                            if gen_enable = '1' then
                                if cntdown = x"00000000" then
                                    gen_state <= HEAD;
                                else
                                    cntdown := cntdown - 1;
                                end if;
                            end if;
                        
                            gen_crc_clear <= '1';
                            gen_data <= (others => '0');
                            gen_data_head <= '0';
                            gen_data_trail <= '0';
                            gen_data_we <= '0';
                            gen_evt_cnt <= gen_evt_cnt;
                        
                        when HEAD =>
                            
                            gen_data( 127 downto 120 ) <= HEADER_BOE;    
                            gen_data( 119 downto 116 ) <= HEADER_VERSION;
                            gen_data( 115 downto 108 ) <= x"00"; 
                            gen_data( 107 downto 064 ) <= std_logic_vector(gen_evt_cnt);
                            gen_data( 063 downto 032 ) <= x"02000000";
                            gen_data( 031 downto 000 ) <= x"01010101";
                            gen_data_head <= '1';
                            gen_data_trail <= '0';
                            gen_data_we <= '1';
                            gen_evt_cnt <= gen_evt_cnt;
                            gen_crc_clear <= '0';

                            gen_state <= DATA;
                            cntdown := (others => '0');

                        when DATA =>

                            gen_data <= gen_data_msg;    
                            gen_data_head <= '0';
                            gen_data_trail <= '0';
                            gen_data_we <= '1';
                            gen_evt_cnt <= gen_evt_cnt;
                            gen_crc_clear <= '0';

                            gen_state <= TRAIL;
                            cntdown := (others => '0');

                        when TRAIL =>

                            gen_data( 127 downto 120 ) <= x"AA";
                            gen_data( 119 downto 096 ) <= x"000000";
                            gen_data( 095 downto 076 ) <= "00000000000000000011";
                            gen_data( 075 downto 064 ) <= x"123";      -- 12b BX ID
                            gen_data( 063 downto 032 ) <= x"00000000"; -- orbit ID
                            gen_data( 031 downto 000 ) <= x"00000000"; -- 16b crc and 16b status
                            gen_data_head <= '0';
                            gen_data_trail <= '1';
                            gen_data_we <= '1';
                            gen_evt_cnt <= gen_evt_cnt + 1;
                            gen_crc_clear <= '0';

                            gen_state <= IDLE;
                            cntdown := unsigned(gen_event_gap);

                    end case;
                
                -- backpressure or link down
                else
                    gen_crc_clear <= gen_crc_clear;
                    gen_data <= (others => '0');
                    gen_data_head <= '0';
                    gen_data_trail <= '0';
                    gen_data_we <= '0';
                    gen_evt_cnt <= gen_evt_cnt;
                end if;
            
            end if;
        end if;
    end process;
    
    --===============================================================================================
    -- this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py (do not edit) 
    --==== Registers begin ==========================================================================
    --==== Registers end ============================================================================
    
end slink_rocket_arch;
