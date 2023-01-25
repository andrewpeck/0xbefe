library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.common_pkg.all;
use work.gem_pkg.all;
use work.ttc_pkg.all;
use work.ipbus.all;
use work.registers.all;

entity queso_tests is
    generic(
        g_IPB_CLK_PERIOD_NS : integer;
        g_NUM_OF_OHs        : integer;
        g_NUM_VFATS_PER_OH  : integer;
        g_QUESO_PRBS       : boolean
    );
    port(
        -- reset
        reset_i                          : in std_logic;
	    counter_reset                    : in std_logic;
                
        -- Test enable
        queso_test_en_i                  : in std_logic;

        --==lpGBT signals==--
        --clock
        gbt_frame_clk_i                  : in  std_logic;
        
        -- elinks
        test_vfat3_rx_data_arr_i         : in t_vfat3_queso_arr(g_NUM_OF_OHs - 1 downto 0);
        test_vfat3_tx_data_arr_o         : out std_logic_vector(7 downto 0);

        elink_mapping_arr_i              : in t_vfat3_queso_arr(g_NUM_OF_OHs - 1 downto 0); -- bitslip count for each elink
        --prbs error counter
        elink_error_cnt_arr_o            : out t_vfat3_queso_arr(g_NUM_OF_OHs - 1 downto 0) -- counts up to ff errors per elink
    );
end queso_tests;

architecture Behavioral of queso_tests is

    signal tx_prbs_err_data  : std_logic_vector(7 downto 0) := x"ff";
    signal tx_prbs_data      : std_logic_vector(7 downto 0);
    signal tx_crawl_data     : std_logic_vector(7 downto 0) := x"00";


    -- unmasked elinks
    signal elink_unmasked    : t_vfat3_queso_arr(g_NUM_OF_OHs - 1 downto 0);
    signal elink_mapped      : t_vfat3_queso_arr(g_NUM_OF_OHs - 1 downto 0);
    -- error counter for prbs
    signal rx_err_cnt_arr    : t_vfat3_queso_arr(g_NUM_OF_OHs - 1 downto 0);
    signal rx_prbs_err_arr   : t_std8_array(g_NUM_OF_OHs * 216 - 1 downto 0);
    
begin


    g_QUESO_COUNT_EN : if not g_QUESO_PRBS generate
        --===Generate TX data===--
        -- generator (fanned out to all elinks)
       i_crawl_gen : entity work.counter
                generic map(
                    g_COUNTER_WIDTH  => 8,
                    g_ALLOW_ROLLOVER => true
                )
                port map(
                    ref_clk_i => gbt_frame_clk_i,
                    reset_i   => counter_reset or reset_i,
                    en_i      => '1',
                    count_o   => tx_crawl_data
                );
        
        test_vfat3_tx_data_arr_o <= tx_crawl_data;

        --===Rx send directly to registers===--
        each_oh : for OH in 0 to g_NUM_OF_OHs - 1 generate
            each_elink : for ELINK in 0 to 215 generate

                --send raw test data directly to error counting registers(now just displays count)
                elink_unmasked(OH)(ELINK) <= test_vfat3_rx_data_arr_i(OH)(ELINK); 

            end generate;
        end generate;

    end generate;


    g_QUESO_PRBS_EN : if g_QUESO_PRBS generate
        --===Generate TX data===--
        -- generator (fanned out to all elinks)
        i_tx_prbs_gen : entity work.PRBS_ANY
            generic map(
                CHK_MODE    => false,
                INV_PATTERN => true,
                POLY_LENGHT => 7,
                POLY_TAP    => 6,
                NBITS       => 8
            )
            port map(
                RST      => reset_i,
                CLK      => gbt_frame_clk_i,
                DATA_IN  => (others => '0'),
                EN       => queso_test_en_i,
                DATA_OUT => tx_prbs_data
            );
            
        test_vfat3_tx_data_arr_o <= tx_prbs_data;
        
        --===Take in RX and apply prbs checker + error counter===--
        each_oh : for OH in 0 to g_NUM_OF_OHs - 1 generate
            each_elink : for ELINK in 0 to 215 generate

                --unmask each rx elink with unique xor 
                elink_error_cnt_arr_o(OH)(ELINK) <= test_vfat3_rx_data_arr_i(OH)(ELINK); --xor std_logic_vector(to_unsigned(OH*24 + ELINK,8)) --needs fixing

                g_rotate : entity work.bitslip
                    generic map(
                        g_DATA_WIDTH              => 8,
                        g_SLIP_CNT_WIDTH          => 8,
                        g_TRANSMIT_LOW_TO_HIGH    => TRUE
                    )
                    port map(
                        clk_i       => gbt_frame_clk_i,
                        slip_cnt_i  => elink_mapping_arr_i(OH)(ELINK),
                        data_i      => elink_unmasked(OH)(ELINK),
                        data_o      => elink_mapped(OH)(ELINK)
                    );


                --instantiate prbs7 8 bit checker
                i_rx_prbs_check : entity work.PRBS_ANY
                    generic map(
                        CHK_MODE    => true,
                        INV_PATTERN => true,
                        POLY_LENGHT => 7,
                        POLY_TAP    => 6,
                        NBITS       => 8
                    )
                    port map(
                        RST      => reset_i,
                        CLK      => gbt_frame_clk_i,
                        DATA_IN  => elink_mapped(OH)(ELINK),
                        EN       => queso_test_en_i,
                        DATA_OUT => rx_prbs_err_arr(OH*216 + ELINK)
                    );

                --instantiate error counter for each prbs checker
                i_prbs7_err_cnt : entity work.counter
                    generic map(
                        g_COUNTER_WIDTH  => 8,
                        g_ALLOW_ROLLOVER => false
                    )
                    port map(
                        ref_clk_i => gbt_frame_clk_i,
                        reset_i   => counter_reset or reset_i,
                        en_i      => or_reduce(rx_prbs_err_arr(OH * 216 + ELINK)),
                        count_o   => rx_err_cnt_arr(OH)(ELINK)
                    );
                
                elink_error_cnt_arr_o(OH)(ELINK) <= rx_err_cnt_arr(OH)(ELINK);

            end generate;
        end generate;
    end generate;


end Behavioral;

