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
        g_NUM_GBTS_PER_OH   : integer;
        g_NUM_VFATS_PER_OH  : integer;
        g_QUESO_PRBS        : boolean;
        g_BITMASK_EN        : boolean
    );
    port(
        -- reset
        reset_i       : in std_logic;
	    counter_reset : in std_logic;
                
        -- Test enable
        queso_test_en_i : in std_logic;

        --==lpGBT signals==--
        --clock
        gbt_frame_clk_i : in  std_logic;
        
        -- elinks
        test_vfat3_rx_data_arr_i : in t_vfat3_queso_arr(g_NUM_OF_OHs - 1 downto 0);
        test_vfat3_tx_data_arr_o : out std_logic_vector(7 downto 0);

        elink_mapping_arr_i      : in t_vfat3_queso_arr(g_NUM_OF_OHs - 1 downto 0); -- bitslip count for each elink
        --prbs error counter
        elink_error_cnt_arr_o    : out t_vfat3_queso_arr(g_NUM_OF_OHs - 1 downto 0) -- counts up to ff errors per elink
    );
end queso_tests;

architecture Behavioral of queso_tests is

    signal tx_prbs_err_data  : std_logic_vector(7 downto 0) := x"ff";
    signal tx_prbs_data      : std_logic_vector(7 downto 0);
    signal tx_crawl_data     : std_logic_vector(7 downto 0) := x"00";


    -- unmasked elinks
    signal elink_mapped_unmasked : t_vfat3_queso_arr(g_NUM_OF_OHs - 1 downto 0);
    signal elink_mapped          : t_vfat3_queso_arr(g_NUM_OF_OHs - 1 downto 0);
    -- error counter for prbs
    signal rx_err_cnt_arr    : t_vfat3_queso_arr(g_NUM_OF_OHs - 1 downto 0);
    signal rx_prbs_err_arr_o : t_std8_array(g_NUM_OF_OHs * 216 - 1 downto 0);
    signal rx_prbs_err_arr   : t_std8_array(g_NUM_OF_OHs * 216 - 1 downto 0);
   

	COMPONENT ila_queso
	PORT (
		clk : IN STD_LOGIC;

		probe0 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
		probe1 : IN STD_LOGIC_VECTOR(63 DOWNTO 0); 
		probe2 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		probe3 : IN STD_LOGIC_VECTOR(31 DOWNTO 0)
	);
	END COMPONENT;

 
begin

    --=======QUESO Full PRBS test=======--
    g_QUESO_PRBS_COUNT_EN : if g_QUESO_PRBS generate
    ----====Generate TX data====-----
        -- generator (fanned out to all elinks)
        i_tx_prbs_gen : entity work.PRBS_ANY
            generic map(
                CHK_MODE    => false, --generate mode
                INV_PATTERN => true,
                POLY_LENGTH => 31, --prbs31
                POLY_TAP    => 28,
                NBITS       => 8
            )
            port map(
                RST      => reset_i,
                CLK      => gbt_frame_clk_i,
                DATA_IN  => (others => '0'), --error injection possible here
                EN       => queso_test_en_i, 
                DATA_OUT => tx_prbs_data --prbs word
            );
        
        -- Send prbs word to tx fannout in ME0 mux
        test_vfat3_tx_data_arr_o <= tx_prbs_data;
        
        g_BITMASK : if g_BITMASK_EN generate
            -- Unmasking of data for each elink (done after bitslipping)
            g_queso_link_unmask : entity work.queso_link_unmask
                generic map(
                    g_NUM_OF_OHs => g_NUM_OF_OHs
                )
                port map(
                    -- clock
                    clk_i => gbt_frame_clk_i,
                    -- links
                    queso_rx_data_arr_i       => elink_mapped,
                    queso_data_unmasked_arr_o => elink_mapped_unmasked
                );
        else generate
            elink_mapped_unmasked <= elink_mapped;
        end generate g_BITMASK;
            
        ----====Take in RX and apply prbs checker + error counter====------
        each_oh : for OH in 0 to g_NUM_OF_OHs - 1 generate
            each_elink : for ELINK in 0 to 215 generate

                --bitslip logic vector to account for any rotation in data packet
                g_rotate : entity work.bitslip
                    generic map(
                        g_DATA_WIDTH              => 8,
                        g_SLIP_CNT_WIDTH          => 8,
                        g_TRANSMIT_LOW_TO_HIGH    => false
                    )
                    port map(
                        clk_i       => gbt_frame_clk_i,
                        slip_cnt_i  => elink_mapping_arr_i(OH)(ELINK),
                        data_i      => test_vfat3_rx_data_arr_i(OH)(ELINK),
                        data_o      => elink_mapped(OH)(ELINK)
                    );


                --instantiate prbs31 8 bit checker
                i_rx_prbs_check : entity work.PRBS_ANY
                    generic map(
                        CHK_MODE    => true, --check mode
                        INV_PATTERN => true,
                        POLY_LENGTH => 31, --prbs31
                        POLY_TAP    => 28,
                        NBITS       => 8
                    )
                    port map(
                        RST      => reset_i,
                        CLK      => gbt_frame_clk_i,
                        DATA_IN  => elink_mapped_unmasked(OH)(ELINK), --unmasked & mapped data is checked
                        EN       => queso_test_en_i, 
                        DATA_OUT => rx_prbs_err_arr_o(OH*216 + ELINK) --error array (each bit)
                    );

                process(gbt_frame_clk_i) is
                begin
                    if (rising_edge(gbt_frame_clk_i)) then
                        rx_prbs_err_arr(OH*216 + ELINK) <= rx_prbs_err_arr_o(OH*216 + ELINK) when (queso_test_en_i = '1') else (others => '0');
                    end if;
                end process;

                --instantiate error counter for each prbs checker
                i_prbs_err_cnt : entity work.counter
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

            end generate each_elink;
        end generate each_oh;

    --=======QUESO Crawl Counter, no PRBS=======--
    else generate
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
                elink_error_cnt_arr_o(OH)(ELINK) <= test_vfat3_rx_data_arr_i(OH)(ELINK); 

            end generate each_elink;
        end generate each_oh;
    end generate g_QUESO_PRBS_COUNT_EN;

--	ila_queso_debug : ila_queso
--	PORT MAP (
--		clk                    => gbt_frame_clk_i,
--
--		probe0                 => tx_prbs_data, 
--		probe1(63 downto 56)   => elink_unmasked(0)(0),
--		probe1(55 downto 48)   => elink_unmasked(0)(1),
--		probe1(47 downto 40)   => elink_unmasked(0)(2),
--		probe1(39 downto 32)   => elink_unmasked(0)(3),
--		probe1(31 downto 24)   => elink_mapped(0)(0),
--		probe1(23 downto 16)   => elink_mapped(0)(1),
--		probe1(15 downto 8)    => elink_mapped(0)(2),
--		probe1(7 downto 0)     => elink_mapped(0)(3), 
--		probe2(15 downto 8)    => rx_prbs_err_arr(0),
--		probe2(7 downto 0)     => rx_prbs_err_arr(1),
--		probe3(31 downto 24)   => rx_err_cnt_arr(0)(0),
--		probe3(23 downto 16)   => rx_err_cnt_arr(0)(1),
--		probe3(15)             => queso_test_en_i,
--		probe3(14 downto 8)    => (others => '0'),
--		probe3(7 downto 0)     => tx_crawl_data
--	);

end Behavioral;

