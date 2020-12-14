------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2019-08-29
-- Module Name:    LPGBT 
-- Description:    Multilink LPGBT wrapper  
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;

use work.gem_pkg.all;
use work.lpgbtfpga_package.all;

entity lpgbt is
    generic(
        g_NUM_LINKS             : integer;
        g_SKIP_ODD_TX           : boolean := true; -- when set to true, only even numbered TX cores will be instantiated (this is what we need for ME0 since every other LpGBT link is only in the direction to the backend)
        g_RX_RATE               : integer := DATARATE_10G24; -- dynamic not supported
        g_RX_ENCODING           : integer := FEC5;
        g_RESET_MGT_ON_EVEN     : integer := 0;
        g_USE_RX_SYNC_FIFOS     : boolean := true; -- when set to true the MGT RX data will be taken through a FIFO to transfer to rx_word_common_clk_i before even connecting to LpGBT RX core (this will cause RX latency to not be deterministic, but it's useful if all rx_word_clk_arr_i clocks cannot be put on BUFGs, and will synthesize even if they're on BUFHs, while it would be very tight if not using the FIFOs). When false, rx_word_common_clk_i is not used
        g_USE_RX_CORRECTION_CNT : boolean := true
    );
    port(
        reset_i                     : in  std_logic;
        reset_tx_i                  : in  std_logic;
        reset_rx_i                  : in  std_logic;
        cnt_reset_i                 : in  std_logic;

        --========--
        -- Clocks --     
        --========--

        tx_frame_clk_i              : in  std_logic; -- expect 40MHz
        rx_frame_clk_i              : in  std_logic; -- expect 40MHz
        tx_word_clk_arr_i           : in  std_logic_vector(g_NUM_LINKS - 1 downto 0); -- MGT 320MHz TXUSRCLK
        rx_word_clk_arr_i           : in  std_logic_vector(g_NUM_LINKS - 1 downto 0); -- MGT 320MHz RXUSRCLK
        rx_word_common_clk_i        : in  std_logic; -- Common RX clock to transfer data from all MGTs to; this is only used when deterministic latency is not important and g_USE_RX_SYNC_FIFOS is set to true

        --========--
        --  MGTs  --     
        --========--
        
        mgt_status_arr_i            : in  t_mgt_status_arr(g_NUM_LINKS - 1 downto 0);
        mgt_ctrl_arr_o              : out t_mgt_ctrl_arr(g_NUM_LINKS - 1 downto 0);
        mgt_tx_data_arr_o           : out t_std40_array(g_NUM_LINKS - 1 downto 0); -- only 32 out of the 40 bits are used
        mgt_rx_data_arr_i           : in  t_std40_array(g_NUM_LINKS - 1 downto 0); -- only 32 out of the 40 bits are used
        
        --========--
        -- GBT TX --
        --========--
        
        tx_data_arr_i               : in  t_lpgbt_tx_frame_array(g_NUM_LINKS - 1 downto 0);

        --========--              
        -- GBT RX --              
        --========-- 

        rx_data_arr_o               : out t_lpgbt_rx_frame_array(g_NUM_LINKS - 1 downto 0);

        --===========--              
        --   Status  --              
        --===========-- 
        
        link_status_arr_o           : out t_gbt_link_status_arr(g_NUM_LINKS - 1 downto 0)

    );
end lpgbt;

architecture lpgbt_arch of lpgbt is
    
    component sync_fifo_gbt_mgt_33
        port (
            rst       : in  std_logic;
            wr_clk    : in  std_logic;
            rd_clk    : in  std_logic;
            din       : in  std_logic_vector(32 downto 0);
            wr_en     : in  std_logic;
            rd_en     : in  std_logic;
            dout      : out std_logic_vector(32 downto 0);
            full      : out std_logic;
            overflow  : out std_logic;
            empty     : out std_logic;
            valid     : out std_logic;
            underflow : out std_logic
        );
    end component;    
    
    --------- TX datapath ---------
    signal tx_dp_reset      : std_logic_vector(g_NUM_LINKS - 1 downto 0);
    signal tx_dp_ready      : std_logic_vector(g_NUM_LINKS - 1 downto 0);
    signal tx_frames        : t_std64_array(g_NUM_LINKS - 1 downto 0);
    
    --------- TX gearbox ---------
    signal tx_gb_reset      : std_logic_vector(g_NUM_LINKS - 1 downto 0);
    signal tx_gb_ready      : std_logic_vector(g_NUM_LINKS - 1 downto 0);
    signal tx_gb_out_data   : t_std32_array(g_NUM_LINKS - 1 downto 0);
    
    --------- RX sync FIFOs ---------
    signal rx_sync_reset    : std_logic_vector(g_NUM_LINKS - 1 downto 0);
    signal rx_sync_valid    : std_logic_vector(g_NUM_LINKS - 1 downto 0);
    signal rx_sync_ovf      : std_logic_vector(g_NUM_LINKS - 1 downto 0);
    signal rx_sync_unf      : std_logic_vector(g_NUM_LINKS - 1 downto 0);
    signal rx_mgt_data      : t_std32_array(g_NUM_LINKS - 1 downto 0);
    signal rx_mgt_data_sync : t_std33_array(g_NUM_LINKS - 1 downto 0); -- top bit is header flag, and lower 32 bits is mgt data
    signal rx_mgt_clk_sync  : std_logic_vector(g_NUM_LINKS - 1 downto 0);

    --------- TX gearbox ---------
    signal rx_gb_reset      : std_logic_vector(g_NUM_LINKS - 1 downto 0);
    signal rx_gb_ready      : std_logic_vector(g_NUM_LINKS - 1 downto 0);
    signal rx_gb_out_data   : t_std256_array(g_NUM_LINKS - 1 downto 0);

    --------- RX datapath ---------
    signal rx_dp_reset      : std_logic_vector(g_NUM_LINKS - 1 downto 0);
    signal rx_dp_ready      : std_logic_vector(g_NUM_LINKS - 1 downto 0);
    signal rx_corr_flags    : t_std234_array(g_NUM_LINKS - 1 downto 0);
    signal rx_corr_flag     : std_logic_vector(g_NUM_LINKS - 1 downto 0);
    signal rx_corr_cnt      : t_std8_array(g_NUM_LINKS - 1 downto 0);

    --------- RX frame aligner ---------
    signal rx_fa_reset      : std_logic_vector(g_NUM_LINKS - 1 downto 0);
    signal rx_header_locked : std_logic_vector(g_NUM_LINKS - 1 downto 0);
    signal rx_header_flag   : std_logic_vector(g_NUM_LINKS - 1 downto 0);
    signal rx_mgt_reset     : std_logic_vector(g_NUM_LINKS - 1 downto 0);
    
begin 

    --============================================================--
    --                         LpGBT TX                           --
    --============================================================--

    g_gbt_tx_link : for i in 0 to g_NUM_LINKS - 1 generate

        gen_skip_even_tx : if (not g_SKIP_ODD_TX) or (i mod 2 = 0) generate

            --------- Resets ---------
            tx_gb_reset(i) <= (not (mgt_status_arr_i(i).tx_reset_done and mgt_status_arr_i(i).tx_cpll_locked)) or reset_tx_i;
            tx_dp_reset(i) <= not tx_gb_ready(i);

            --------- Status ---------
            link_status_arr_o(i).gbt_tx_ready <= tx_gb_ready(i) and tx_dp_ready(i);
            link_status_arr_o(i).gbt_tx_gearbox_ready <= tx_gb_ready(i); 
            
            i_tx_not_ready_latch : entity work.latch
                port map(
                    reset_i => reset_i or cnt_reset_i,
                    clk_i   => tx_frame_clk_i,
                    input_i => not (tx_gb_ready(i) and tx_dp_ready(i)),
                    latch_o => link_status_arr_o(i).gbt_tx_had_not_ready
                );            

            --------- TX datapath ---------

            i_tx_datapath : entity work.LpGBT_FPGA_Downlink_datapath
                    generic map (
                        MULTICYCLE_DELAY => 0
                    )
                port map(
                    donwlinkClk_i               => tx_frame_clk_i,
                    downlinkClkEn_i             => '1',
                    downlinkRst_i               => tx_dp_reset(i),
                    
                    downlinkUserData_i          => tx_data_arr_i(i).tx_data,
                    downlinkEcData_i            => tx_data_arr_i(i).tx_ec_data,
                    downlinkIcData_i            => tx_data_arr_i(i).tx_ic_data,
                    
                    downLinkFrame_o             => tx_frames(i),
                    
                    downLinkBypassInterleaver_i => '0',
                    downLinkBypassFECEncoder_i  => '0',
                    downLinkBypassScrambler_i   => '0',
                    
                    downlinkReady_o             => tx_dp_ready(i)
                );

            --------- TX gearbox ---------
                
            i_tx_gearbox : entity work.txGearbox
                generic map(
                    c_clockRatio  => 8,
                    c_inputWidth  => 64,
                    c_outputWidth => 32
                )
                port map(
                    clk_inClk_i    => tx_frame_clk_i,
                    clk_clkEn_i    => '1',
                    clk_outClk_i   => tx_word_clk_arr_i(i),
                    
                    rst_gearbox_i  => tx_gb_reset(i),
                    
                    dat_inFrame_i  => tx_frames(i),
                    dat_outFrame_o => tx_gb_out_data(i),
                    
                    sta_gbRdy_o    => tx_gb_ready(i)
                );
                
            mgt_tx_data_arr_o(i)(31 downto 0) <= tx_gb_out_data(i);
            
        end generate;
        
        --------- Status for skipped TXs ---------
        
        g_skipped_tx : if g_SKIP_ODD_TX and (i mod 2 /= 0) generate
            link_status_arr_o(i).gbt_tx_ready <= '0';
            link_status_arr_o(i).gbt_tx_gearbox_ready <= '0'; 
        end generate;
        
    end generate;

    --============================================================--
    --                     LpGBT RX SYNC FIFOS                    --
    --============================================================--

    g_gbt_rx_sync_fifos : for i in 0 to g_NUM_LINKS - 1 generate
        
        rx_mgt_data(i) <= mgt_rx_data_arr_i(i)(31 downto 0);
        
        gen_use_rx_sync_fifos : if g_USE_RX_SYNC_FIFOS generate
        
            rx_sync_reset(i) <= reset_i or not (mgt_status_arr_i(i).rx_reset_done and mgt_status_arr_i(i).rx_cpll_locked and rx_header_locked(i)); -- TODO: consider resetting this on other conditions too e.g. overflow
            rx_mgt_clk_sync(i) <= rx_word_common_clk_i;
        
            i_rx_sync_fifo : component sync_fifo_gbt_mgt_33
                port map(
                    rst       => rx_sync_reset(i),
                    wr_clk    => rx_word_clk_arr_i(i),
                    rd_clk    => rx_word_common_clk_i,
                    din       => rx_header_flag(i) & rx_mgt_data(i),
                    wr_en     => '1',
                    rd_en     => '1',
                    dout      => rx_mgt_data_sync(i),
                    full      => open,
                    overflow  => rx_sync_ovf(i),
                    empty     => open,
                    valid     => rx_sync_valid(i),
                    underflow => rx_sync_unf(i)
                );
                
            i_gbt_rx_sync_ovf_latch : entity work.latch
                port map(
                    reset_i => reset_i or cnt_reset_i,
                    clk_i   => rx_word_clk_arr_i(i),
                    input_i => rx_sync_ovf(i),
                    latch_o => link_status_arr_o(i).gbt_rx_sync_status.had_ovf
                );
    
            i_gbt_rx_sync_unf_latch : entity work.latch
                port map(
                    reset_i => reset_i or cnt_reset_i,
                    clk_i   => rx_word_common_clk_i,
                    input_i => rx_sync_unf(i),
                    latch_o => link_status_arr_o(i).gbt_rx_sync_status.had_unf
                );
                
        end generate;

        gen_no_rx_sync_fifos : if not g_USE_RX_SYNC_FIFOS generate
            rx_mgt_clk_sync(i) <= rx_word_clk_arr_i(i);
            rx_mgt_data_sync(i)(32) <= rx_header_flag(i);
            rx_mgt_data_sync(i)(31 downto 0) <= rx_mgt_data(i);
            rx_sync_valid(i) <= '1';
            link_status_arr_o(i).gbt_rx_sync_status.had_ovf <= '0';
            link_status_arr_o(i).gbt_rx_sync_status.had_unf <= '0';
        end generate;
    
    end generate;

    --============================================================--
    --                         LpGBT RX                           --
    --============================================================--
    
    g_gbt_rx_link : for i in 0 to g_NUM_LINKS - 1 generate

        --------- Resets ---------
        rx_fa_reset(i) <= (not (mgt_status_arr_i(i).rx_reset_done and mgt_status_arr_i(i).rx_cpll_locked)) or reset_rx_i;
        rx_gb_reset(i) <= not (rx_header_locked(i) and rx_sync_valid(i));
        rx_dp_reset(i) <= not rx_gb_ready(i);

        --------- Status ---------
        link_status_arr_o(i).gbt_rx_ready <= rx_gb_ready(i) and rx_dp_ready(i);
        link_status_arr_o(i).gbt_rx_gearbox_ready <= rx_gb_ready(i);
        link_status_arr_o(i).gbt_rx_header_locked <= rx_header_locked(i);
        link_status_arr_o(i).gbt_rx_correction_flag <= rx_corr_flag(i);
        link_status_arr_o(i).gbt_rx_correction_cnt <= rx_corr_cnt(i);
        
        i_rx_not_ready_latch : entity work.latch
            port map(
                reset_i => reset_i or cnt_reset_i,
                clk_i   => rx_frame_clk_i,
                input_i => not (rx_gb_ready(i) and rx_dp_ready(i)),
                latch_o => link_status_arr_o(i).gbt_rx_had_not_ready
            );

        i_rx_header_unlock_latch : entity work.latch
            port map(
                reset_i => reset_i or cnt_reset_i,
                clk_i   => rx_word_clk_arr_i(i),
                input_i => not rx_header_locked(i),
                latch_o => link_status_arr_o(i).gbt_rx_header_had_unlock
            );
                         
        --------- RX gearbox ---------
        
        i_rx_gearbox : entity work.rxGearbox
            generic map(
                c_clockRatio       => 8,
                c_inputWidth       => 32,
                c_outputWidth      => 256,
                c_counterInitValue => 2
            )
            port map(
                clk_inClk_i    => rx_mgt_clk_sync(i),
                clk_outClk_i   => rx_frame_clk_i,
                clk_clkEn_i    => rx_mgt_data_sync(i)(32),
                clk_dataFlag_o => open,
                
                rst_gearbox_i  => rx_gb_reset(i),
                
                dat_inFrame_i  => rx_mgt_data_sync(i)(31 downto 0),
                dat_outFrame_o => rx_gb_out_data(i),
                
                sta_gbRdy_o    => rx_gb_ready(i)
            );

        --------- RX datapath ---------
        
        i_rx_datapath : entity work.LpGBT_FPGA_Uplink_datapath
            generic map(
                DATARATE         => g_RX_RATE,
                FEC              => g_RX_ENCODING,
                MULTICYCLE_DELAY => 0
            )
            port map(
                uplinkClk_i                     => rx_frame_clk_i,
                uplinkClkInEn_i                 => '1',
                uplinkClkOutEn_o                => open,
                uplinkRst_i                     => rx_dp_reset(i),
                
                uplinkFrame_i                   => rx_gb_out_data(i),
                
                uplinkUserData_o(229 downto 224)=> open,
                uplinkUserData_o(223 downto 0)  => rx_data_arr_o(i).rx_data,
                uplinkEcData_o                  => rx_data_arr_o(i).rx_ec_data,
                uplinkIcData_o                  => rx_data_arr_o(i).rx_ic_data,

                uplinkSelectDataRate_i          => '1',
                uplinkSelectFEC_i               => '0',
                uplinkBypassInterleaver_i       => '0',
                uplinkBypassFECEncoder_i        => '0',
                uplinkBypassScrambler_i         => '0',
                
                uplinkDataCorrected_o           => rx_corr_flags(i)(229 downto 0),
                uplinkIcCorrected_o             => rx_corr_flags(i)(231 downto 230),
                uplinkEcCorrected_o             => rx_corr_flags(i)(233 downto 232),
                uplinkReady_o                   => rx_dp_ready(i)
            );

        --------- Bit correction counter ---------
                
        g_corr_cnt : if g_USE_RX_CORRECTION_CNT generate
            
            i_corr_cnt : entity work.counter
                generic map(
                    g_COUNTER_WIDTH  => 8,
                    g_ALLOW_ROLLOVER => false
                )
                port map(
                    ref_clk_i => rx_frame_clk_i,
                    reset_i   => reset_i or cnt_reset_i,
                    en_i      => rx_corr_flag(i),
                    count_o   => rx_corr_cnt(i)
                );

            rx_corr_flag(i) <= or_reduce(rx_corr_flags(i));
            
        end generate;

        g_no_corr_cnt : if not g_USE_RX_CORRECTION_CNT generate
            rx_corr_cnt(i) <= (others => '0');
            rx_corr_flag(i) <= '0';
        end generate;

        --------- Frame aligner ---------
        
        i_frame_aligner : entity work.mgt_framealigner
            generic map(
                c_wordRatio               => 8,
                c_headerPattern           => "01",
                c_wordSize                => 32,
                c_allowedFalseHeader      => 32,
                c_allowedFalseHeaderOverN => 40,
                c_requiredTrueHeader      => 30,
                c_resetOnEven             => g_RESET_MGT_ON_EVEN,
                c_resetDuration           => 10,
                c_bitslip_mindly          => 40
            )
            port map(
                clk_pcsRx_i             => rx_word_clk_arr_i(i),
                clk_freeRunningClk_i    => tx_frame_clk_i,
                
                rst_pattsearch_i        => rx_fa_reset(i),
                rst_mgtctrler_i         => rx_fa_reset(i),
                rst_rstoneven_o         => rx_mgt_reset(i),
                
                cmd_bitslipCtrl_o       => mgt_ctrl_arr_o(i).rxslide,
                cmd_rstonevenoroddsel_i => '0',
                
                sta_headerLocked_o      => rx_header_locked(i),
                sta_headerFlag_o        => rx_header_flag(i),
                
                dat_word_i              => rx_mgt_data(i)(1 downto 0)
            );

        mgt_ctrl_arr_o(i).txreset <= '0';

        g_use_mgt_reset_on_even : if g_RESET_MGT_ON_EVEN = 1 generate
            mgt_ctrl_arr_o(i).rxreset <= rx_mgt_reset(i);
        end generate;

        g_no_mgt_reset_on_even : if g_RESET_MGT_ON_EVEN = 0 generate
            mgt_ctrl_arr_o(i).rxreset <= '0';
        end generate;
        
    end generate;    
    
end lpgbt_arch;
