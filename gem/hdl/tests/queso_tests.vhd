library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common_pkg.all;
use work.gem_pkg.all;
use work.ttc_pkg.all;
use work.ipbus.all;
use work.registers.all;

entity queso_tests is
    generic map(
        g_IPB_CLK_PERIOD_NS : integer;
        g_NUM_OF_OHs        : integer;
        g_NUM_VFATS_PER_OH  : integer
    );
    port map(
        -- reset
        reset_i                     : in  std_logic;
        
        -- TTC
        ttc_clk_i                   : in  t_ttc_clks;        
        ttc_cmds_i                  : in  t_ttc_cmds;
        
        -- Test enable
        queso_test_en_i             : in std_logic;

        -- IPbus
        ipb_reset_i                 : in  std_logic;
        ipb_clk_i                   : in  std_logic;
        ipb_miso_o                  : out ipb_rbus;
        ipb_mosi_i                  : in  ipb_wbus;

        --==lpGBT signals==--
        --clock
        gbt_frame_clk_i                  : in  std_logic;
        
        -- elinks
        test_gbt_ic_rx_data_arr_i        : in t_std2_array(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0);
        test_vfat3_rx_data_arr_i         : in t_vfat3_queso_arr(g_NUM_OF_OHs - 1 downto 0);
        test_vfat3_tx_data_arr_i         : in t_vfat3_elinks_arr(g_NUM_OF_OHs - 1 downto 0);

        --gbt ready
        test_gbt_ready_arr_o             : out std_logic_vector(g_NUM_OF_OHs * g_NUM_GBTS_PER_OH - 1 downto 0)

        elink_error_cnt_arr_o            : out t_vfat3_queso_arr(g_NUM_OF_OHs - 1 downto 0) -- counts up to ff errors per elink
    );
end queso_tests;

architecture Behavioral of queso_tests is

    -- unmasked elinks
    signal elink_unmasked    : t_vfat3_queso_arr(g_NUM_OF_OHs - 1 downto 0);
    -- error counter for prbs
    signal rx_err_cnt_arr    : t_vfat3_queso_arr(g_NUM_OF_OHs - 1 downto 0);
    signal rx_prbs_err_arr   : std_logic_vector(g_NUM_OF_OHs * 108 - 1);
    signal rx_prbs_ready_arr : std_logic_vector(g_NUM_OF_OHs * 108 - 1);
    
begin

    --===Generate TX data===--
    -- generator (fanned out to all elinks)
    i_prbs7_8b_gen : entity work.prbs7_8b_generator
        generic map(
            INIT_c => PRBS_SEED
        )
        port map(
            reset_i       => reset_i,
            clk_i         => gbt_clk_i,
            clken_i       => '1',
            err_pattern_i => tx_prbs_err_data,
            rep_delay_i   => (others => '0'),
            prbs_word_o   => tx_prbs_data,
            rdy_o         => open
        );

    -- fanout data to all tx
    each_oh : for OH in 0 to g_NUM_OF_OHs - 1 generate
        each_vfat : for VFAT in 0 to g_NUM_VFATS_PER_OH - 1 generate       
        -- fanout the PRBS data to all TX elinks
        test_vfat3_tx_data_arr_i(OH)(VFAT) <= tx_prbs_data
        end generate;
    end generate;

    --===Take in RX and apply prbs checker + error counter===--
    each_oh : for OH in 0 to g_NUM_OF_OHs - 1 generate
        each_elink : for ELINK in 0 to 107 generate

            --unmask each rx elink with unique xor 
            elink_unmasked(OH)(ELINK) <= test_vfat3_rx_data_arr_i xor std_logic_vector(to_unsigned(OH*24 + ELINK,8)) --needs fixing

            --instantiate prbs7 8 bit checker
            i_prbs7_checker : entity work.prbs7_8b_checker
                port map(
                    reset_i          => reset_i
                    clk_i            => gbt_frame_clk_i
                    clken_i          => '1'
                    prbs_word_i      => elink_unmasked(OH)(ELINK)
                    err_o            => open
                    err_flag_o       => rx_prbs_err_arr(OH)(ELINK)
                    rdy_o            => rx_prbs_ready_arr(OH)(ELINK)
                );

            --instantiate error counter for each prbs checker
            i_prbs7_err_cnt : entity work.counter
                generic map(
                    g_COUNTER_WIDTH  => 31,
                    g_ALLOW_ROLLOVER => false
                )
                port map(
                    ref_clk_i => gbt_clk_i,
                    reset_i   => reset_i,
                    en_i      => rx_prbs_err_arr((OH * 108) + ELINK) and rx_prbs_ready_arr(OH)(ELINK) and queso_test_en_i,
                    count_o   => rx_err_cnt_arr()(30 downto 0)
                );
            
            elink_error_cnt_arr_o(OH)(ELINK) <= rx_err_cnt_arr;



        end generate;
    end generate;



end Behavioral;

