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

        daq_to_daqlink_i        : in  t_daq_to_daqlink;
        daqlink_to_daq_o        : out t_daqlink_to_daq;
        
        ipb_reset_i             : in  std_logic;
        ipb_clk_i               : in  std_logic;
        ipb_mosi_i              : in  ipb_wbus;
        ipb_miso_o              : out ipb_rbus
        
    );
end slink_rocket;

architecture slink_rocket_arch of slink_rocket is

    COMPONENT slink_rocket_sender
        PORT(
            aresetn                    : IN  STD_LOGIC;
            txdiffctrl_in              : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
            txpostcursor_in            : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
            txprecursor_in             : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
            Srds_loopback_in           : IN  STD_LOGIC;
            Core_status_addr           : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
            Core_status_data_out       : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
            user_100MHz_clk            : IN  STD_LOGIC;
            FED_CLOCK                  : IN  STD_LOGIC;
            event_data_word            : IN  STD_LOGIC_VECTOR(127 DOWNTO 0);
            event_ctrl                 : IN  STD_LOGIC;
            event_data_wen             : IN  STD_LOGIC;
            backpressure               : OUT STD_LOGIC;
            Link_DOWN_n                : OUT STD_LOGIC;
            ext_trigger                : IN  STD_LOGIC;
            ext_veto_out               : OUT STD_LOGIC;
            qpll_lock_in               : IN  STD_LOGIC;
            qpll_reset_out             : OUT STD_LOGIC;
            qpll_clkin                 : IN  STD_LOGIC;
            qpll_ref_clkin             : IN  STD_LOGIC;
            gtM_Reset_TX_clock_in_0    : IN  STD_LOGIC;
            gtM_Reset_TX_clock_in_1    : IN  STD_LOGIC;
            gtM_Reset_TX_clock_in_2    : IN  STD_LOGIC;
            gtM_userclk_tx_active_out  : OUT STD_LOGIC;
            gtM_userclk_tx_usrclk_out  : OUT STD_LOGIC;
            gtM_userclk_tx_usrclk2_out : OUT STD_LOGIC;
            gtM_userclk_tx_usrclk4_out : OUT STD_LOGIC;
            Snd_gt_rxn_in              : IN  STD_LOGIC;
            Snd_gt_rxp_in              : IN  STD_LOGIC;
            Snd_gt_txn_out             : OUT STD_LOGIC;
            Snd_gt_txp_out             : OUT STD_LOGIC;
            Rst_hrd_sim                : IN  STD_LOGIC
        );
    END COMPONENT;
    
    --------------------------------------------------------------------------
    
    constant HEADER_BOE     : std_logic_vector(7 downto 0) := x"55";
    constant HEADER_EOE     : std_logic_vector(7 downto 0) := x"AA";
    constant HEADER_VERSION : std_logic_vector(3 downto 0) := x"1";
    
    signal reset            : std_logic;
    signal reset_local      : std_logic;

    signal fed_clk          : std_logic;
    
    signal txdiffctrl       : std_logic_vector(4 downto 0);
    signal txprecursor      : std_logic_vector(4 downto 0);
    signal txpostcursor     : std_logic_vector(4 downto 0);
    
    signal qpll_lock        : std_logic;
    signal qpll_reset       : std_logic;
    signal qpll_clk         : std_logic;
    signal qpll_ref_clk     : std_logic;
    
    signal status_addr      : std_logic_vector(15 downto 0);
    signal status_data      : std_logic_vector(63 downto 0);

    signal fed_data         : std_logic_vector(127 downto 0);
    signal fed_data_head    : std_logic;
    signal fed_data_trail   : std_logic;
    signal fed_data_we      : std_logic;
    
    signal fed_data_d       : std_logic_vector(127 downto 0);
    signal fed_data_head_d  : std_logic;
    signal fed_data_trail_d : std_logic;
    signal fed_data_we_d    : std_logic;
    
    signal backpressure     : std_logic;
    signal link_up          : std_logic;
    
    signal crc              : std_logic_vector(15 downto 0);
    signal crc_data_in      : std_logic_vector(127 downto 0);
    signal crc_clear        : std_logic;
    signal crc_en           : std_logic;
    
    ---------- simple event generator ----------
    type t_state is (IDLE, HEAD, DATA, TRAIL);
    
    signal gen_enable       : std_logic;
    signal gen_event_gap    : std_logic_vector(31 downto 0);
    signal gen_data_msg     : std_logic_vector(127 downto 0);
    
    signal gen_state        : t_state := IDLE;
    signal gen_evt_cnt      : unsigned(43 downto 0);
    signal gen_data         : std_logic_vector(127 downto 0);
    signal gen_data_head    : std_logic;
    signal gen_data_trail   : std_logic;
    signal gen_data_we      : std_logic;
    signal gen_crc_clear    : std_logic;

    signal daq_data         : std_logic_vector(127 downto 0);
    signal daq_data_head    : std_logic;
    signal daq_data_trail   : std_logic;
    signal daq_data_we      : std_logic;
    signal daq_crc_clear    : std_logic;
        
    ------ Register signals begin (this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py -- do not edit)
    ------ Register signals end ----------------------------------------------
    
begin

    ------------ wiring ------------

    reset <= reset_i or reset_local;
    
    daqlink_to_daq_o.backpressure <= backpressure;
    daqlink_to_daq_o.ready <= link_up;
    daqlink_to_daq_o.disperr_cnt <= (others => '0');
    daqlink_to_daq_o.notintable_cnt <= (others => '0');

    fed_clk <= daq_to_daqlink_i.event_clk;
    daq_data <= daq_to_daqlink_i.event_data;
    daq_data_head <= daq_to_daqlink_i.event_header;
    daq_data_trail <= daq_to_daqlink_i.event_trailer;
    daq_data_we <= daq_to_daqlink_i.event_valid;
    
    ------------ slink inst ------------
     
    i_slink_sender : slink_rocket_sender
        PORT MAP(
            aresetn                 => not reset,
            txdiffctrl_in           => txdiffctrl,
            txpostcursor_in         => txprecursor,
            txprecursor_in          => txpostcursor,
            Srds_loopback_in        => '0',
            Core_status_addr        => status_addr,
            Core_status_data_out    => status_data,
            user_100MHz_clk         => clk_stable_100_i,
            FED_CLOCK               => fed_clk,
            event_data_word         => fed_data,
            event_ctrl              => fed_data_head or fed_data_trail,
            event_data_wen          => fed_data_we,
            backpressure            => backpressure,
            Link_DOWN_n             => link_up,
            ext_trigger             => '0',
            qpll_lock_in            => qpll_lock,
            qpll_reset_out          => qpll_reset,
            qpll_clkin              => qpll_clk,
            qpll_ref_clkin          => qpll_ref_clk,
            gtM_Reset_TX_clock_in_0 => '0',
            gtM_Reset_TX_clock_in_1 => '0',
            gtM_Reset_TX_clock_in_2 => '0',
            Snd_gt_rxn_in           => '0',
            Snd_gt_rxp_in           => '1',
            Snd_gt_txn_out          => open,
            Snd_gt_txp_out          => open,
            Rst_hrd_sim             => '0'
        );

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
    
    ------------ Event generator ------------
    
    process(fed_clk)
        variable cntdown    : unsigned(31 downto 0) := (others => '0');
    begin
        if rising_edge(fed_clk) then
            if reset = '1' then
                gen_state <= IDLE;
                gen_crc_clear <= '1';
                gen_data <= (others => '0');
                gen_data_head <= '0';
                gen_data_trail <= '0';
                gen_data_we <= '0';
                gen_evt_cnt <= (others => '0');
            else
                
                if link_up = '1' and backpressure = '0' then 
                    
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
        
    --============ Select the data source and calculate CRC ====================
        
    process(fed_clk)
    begin
        if rising_edge(fed_clk) then
            if gen_enable = '1' then
                fed_data_d       <= gen_data;
                fed_data_head_d  <= gen_data_head;
                fed_data_trail_d <= gen_data_trail;
                fed_data_we_d    <= gen_data_we;
            else
                fed_data_d       <= daq_data;
                fed_data_head_d  <= daq_data_head;
                fed_data_trail_d <= daq_data_trail;
                fed_data_we_d    <= daq_data_we;
                daq_crc_clear    <= daq_to_daqlink_i.event_trailer;
            end if;
            
            -- substitute the CRC
            if fed_data_trail_d = '1' then
                fed_data(31 downto 16) <= crc;
            else
                fed_data(31 downto 16) <= fed_data_d(31 downto 16);
            end if;
            fed_data(127 downto 32) <= fed_data_d(127 downto 32);
            fed_data(15 downto 0) <= fed_data_d(15 downto 0);
            fed_data_head    <= fed_data_head_d;
            fed_data_trail   <= fed_data_trail_d;
            fed_data_we      <= fed_data_we_d;            
        end if;
    end process;
    
    ------------ CRC ------------

    crc_en <= gen_data_we when gen_enable = '1' else daq_data_we;
    crc_data_in <= gen_data when gen_enable = '1' else daq_data;
    crc_clear <= gen_crc_clear when gen_enable = '1' else daq_crc_clear or daq_to_daqlink_i.reset;
    
    i_crc : entity work.FED_fragment_CRC16_D128b
        port map ( 
            clear_p  => crc_clear or reset,
            clk      => fed_clk,
            enable   => crc_en,
            Data     => crc_data_in,
            CRC_out  => crc
        );


    --===============================================================================================
    -- this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py (do not edit) 
    --==== Registers begin ==========================================================================
    --==== Registers end ============================================================================
    
end slink_rocket_arch;
