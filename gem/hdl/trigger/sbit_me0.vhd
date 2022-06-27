------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: UCLA
-- Engineer: Joseph Carlson (jecarlson30@gmail.com)
-- 
-- Create Date:    2019-11-13
-- Module Name:    sbit_me0
-- Description:    This module handles everything related to ME0 VFAT3 sbit data clusterization and mapping to legacy clusters
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

use work.common_pkg.all;
use work.gem_pkg.all;
use work.ttc_pkg.all;
use work.ipbus.all;
use work.registers.all;
use work.cluster_pkg.all;

entity sbit_me0 is
    generic(
        g_NUM_OF_OHs         : integer;
        g_NUM_VFATS_PER_OH   : integer;
        g_IPB_CLK_PERIOD_NS  : integer;
        g_DEBUG              : boolean
    );
    port(
        -- reset
        reset_i             : in  std_logic;

        -- TTC
        ttc_clk_i           : in  t_ttc_clks;
        ttc_cmds_i          : in  t_ttc_cmds;

        -- Sbit inputs
        vfat3_sbits_arr_i    : in  t_vfat3_sbits_arr(g_NUM_OF_OHs - 1 downto 0);

        -- Cluster outputs
        me0_cluster_count_o : out std_logic_vector(10 downto 0);
        me0_clusters_o      : out t_oh_clusters_arr(g_NUM_OF_OHs - 1 downto 0);

        -- IPbus
        ipb_reset_i         : in  std_logic;
        ipb_clk_i           : in  std_logic;
        ipb_miso_o          : out ipb_rbus;
        ipb_mosi_i          : in  ipb_wbus

    );
end sbit_me0;

architecture sbit_me0_arch of sbit_me0 is

    -- Components --
    -- ila debugger for sbit_me0 --
    COMPONENT ila_sbit_me0

        PORT (
            clk : IN STD_LOGIC;

            probe0  : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
            probe1  : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
            probe2  : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
            probe3  : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
            probe4  : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
            probe5  : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
            probe6  : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
            probe7  : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
            probe8  : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
            probe9  : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
            probe10 : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
            probe11 : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
            probe12 : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
            probe13 : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
            probe14 : IN STD_LOGIC;
            probe15 : IN STD_LOGIC;
            probe16 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
            probe17 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
            probe18 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
            probe19 : IN STD_LOGIC_VECTOR(15 DOWNTO 0)
        );
    END COMPONENT  ;

    -- resets
    signal reset_global         : std_logic;
    signal reset_local          : std_logic;
    signal reset                : std_logic;
    signal reset_cnt            : std_logic;

    -- control signals
    signal vfat_sbit_mask_arr   : t_vfat3_sbits_arr(g_NUM_OF_OHs - 1 downto 0) := (others => (others => (others => '0')));

    -- trigger signals
    signal vfat_sbits_arr       : t_vfat3_sbits_arr(g_NUM_OF_OHs - 1 downto 0); -- sbits after masking
    signal vfat_trigger_arr     : t_std24_array(g_NUM_OF_OHs - 1 downto 0); -- trigger per vfat (or of all unmasked sbits)
    signal vfat_sbits_or_arr    : t_std24_array(g_NUM_OF_OHs - 1 downto 0);

    -- probe signal for raw sbits --
    signal sbits_probe : sbits_t;

    -- counters
    signal vfat_trigger_cnt_arr  : t_vfat_trigger_cnt_arr(g_NUM_OF_OHs - 1 downto 0);
    signal vfat_trigger_rate_arr : t_vfat_trigger_rate_arr(g_NUM_OF_OHs - 1 downto 0);

    constant  g_CLK_FREQUENCY : std_logic_vector(31 downto 0) := C_TTC_CLK_FREQUENCY_SLV;


    -- signals for raw sbit registers    
    signal sbit_test_reset         : std_logic := '0' ;

    signal test_sbit0xe_presum       : t_std32_array(7 downto 0);
    signal test_sbit0xe_count_me0    : std_logic_vector(31 downto 0);
    signal vfat3_sbit0xe_test        : std_logic_vector(7 downto 0);
    signal test_sbit0xs_count_me0    : std_logic_vector(31 downto 0);
    signal vfat3_sbit0xs_test        : std_logic;
    signal test_sel_oh_sbit_me0      : std_logic_vector(31 downto 0);
    signal test_sel_vfat_sbit_me0    : std_logic_vector(31 downto 0);
    signal test_sel_elink_sbit_me0   : std_logic_vector(31 downto 0);
    signal test_sel_sbit_me0         : std_logic_vector(31 downto 0);

    -- cluster mapping from new to legacy clusters
    function get_adr (partition : in std_logic_vector; strip : in std_logic_vector)
    return std_logic_vector is
        variable s : integer;
        variable p : integer;
    begin
        s := to_integer(unsigned(strip));
        p := to_integer(unsigned(partition));

        return std_logic_vector(to_unsigned(p*192+s, 11));
    end;


    signal me0_clusters_probe_raw : sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);
    signal me0_cluster_count      : t_std11_array(g_NUM_OF_OHs -1 downto 0);
    signal me0_overflow           : std_logic_vector(g_NUM_OF_OHs -1 downto 0);

    ------ Register signals begin (this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py -- do not edit)
    signal regs_read_arr        : t_std32_array(REG_TRIGGER_NUM_REGS - 1 downto 0);
    signal regs_write_arr       : t_std32_array(REG_TRIGGER_NUM_REGS - 1 downto 0);
    signal regs_addresses       : t_std32_array(REG_TRIGGER_NUM_REGS - 1 downto 0);
    signal regs_defaults        : t_std32_array(REG_TRIGGER_NUM_REGS - 1 downto 0) := (others => (others => '0'));
    signal regs_read_pulse_arr  : std_logic_vector(REG_TRIGGER_NUM_REGS - 1 downto 0);
    signal regs_write_pulse_arr : std_logic_vector(REG_TRIGGER_NUM_REGS - 1 downto 0);
    signal regs_read_ready_arr  : std_logic_vector(REG_TRIGGER_NUM_REGS - 1 downto 0) := (others => '1');
    signal regs_write_done_arr  : std_logic_vector(REG_TRIGGER_NUM_REGS - 1 downto 0) := (others => '1');
    signal regs_writable_arr    : std_logic_vector(REG_TRIGGER_NUM_REGS - 1 downto 0) := (others => '0');
    ------ Register signals end ----------------------------------------------

begin

    --== Resets ==--

    i_reset_sync : entity work.synch
        generic map(
            N_STAGES => 3
        )
        port map(
            async_i => reset_i,
            clk_i   => ttc_clk_i.clk_40,
            sync_o  => reset_global
        );

    reset <= reset_global or reset_local;

    --== Control ==--

    -- apply the sbit masks, and set per-vfat trigger bits
    process (ttc_clk_i.clk_40)
    begin
        if rising_edge(ttc_clk_i.clk_40) then
            for oh in 0 to g_NUM_OF_OHs - 1 loop
                for vfat in 0 to 23 loop
                    vfat_sbits_arr(oh)(vfat) <= vfat3_sbits_arr_i(oh)(vfat) and not vfat_sbit_mask_arr(oh)(vfat);
                    vfat_trigger_arr(oh)(vfat) <= or_reduce(vfat_sbits_arr(oh)(vfat)); -- note that this will be 1 clock late compared to the vfat_sbits_arr (!) not a problem if used only in the counters, so will keep it like this for now to have relaxed timing
                    vfat_sbits_or_arr(oh)(vfat) <= or_reduce(vfat_sbits_arr(oh)(vfat));
                end loop;
            end loop;
        end if;
    end process;

    --== Counters ==--

    g_oh_counters: for oh in 0 to g_NUM_OF_OHs - 1 generate

        --- rate counter for each vfat OR of sbits ---
        i_vfat_rate_count: entity work.rate_counter32_multi
            generic map(
                g_CLK_FREQUENCY => g_CLK_FREQUENCY,
                g_NUM_COUNTERS  => 24
            )
            port map(
                clk_i   => ttc_clk_i.clk_40,
                reset_i => reset,
                en_i    => vfat_sbits_or_arr(oh),
                rate_o  => vfat_trigger_rate_arr(oh)
            );


        g_vfat_counters: for vfat in 0 to 23 generate

            i_vfat_trigger_cnt : entity work.counter
                generic map(
                    g_COUNTER_WIDTH  => 16,
                    g_ALLOW_ROLLOVER => FALSE
                )
                port map(
                    ref_clk_i => ttc_clk_i.clk_40,
                    reset_i   => reset or reset_cnt,
                    en_i      => vfat_trigger_arr(oh)(vfat),
                    count_o   => vfat_trigger_cnt_arr(oh)(vfat)
                );
        end generate;

    end generate;

    --== Debug me0 sbits ==--

    ila_enable : if g_DEBUG generate
        me0_cluster_debug : ila_sbit_me0
            PORT MAP (
                clk => ttc_clk_i.clk_40,

                probe0 => me0_clusters_o(0)(0).size & me0_clusters_o(0)(0).address,
                probe1 => me0_clusters_o(0)(1).size & me0_clusters_o(0)(1).address,
                probe2 => me0_clusters_o(0)(2).size & me0_clusters_o(0)(2).address,
                probe3 => me0_clusters_o(0)(3).size & me0_clusters_o(0)(3).address,
                probe4 => me0_clusters_o(0)(4).size & me0_clusters_o(0)(4).address,
                probe5 => me0_clusters_o(0)(5).size & me0_clusters_o(0)(5).address,
                probe6 => me0_clusters_o(0)(6).size & me0_clusters_o(0)(6).address,
                probe7 => me0_clusters_o(0)(7).size & me0_clusters_o(0)(7).address,
                probe8 => sbits_probe,
                probe9 => vfat_sbits_arr(0)(1),
                probe10 => vfat_sbits_arr(0)(8),
                probe11 => vfat_sbits_arr(0)(9),
                probe12 => vfat_sbits_arr(0)(16),
                probe13 => vfat_sbits_arr(0)(17),
                probe14 => ttc_cmds_i.calpulse,
                probe15 => ttc_cmds_i.l1a,
                probe16 => me0_clusters_probe_raw(0).cnt & me0_clusters_probe_raw(0).adr & me0_clusters_probe_raw(0).prt & me0_clusters_probe_raw(0).vpf,
                probe17 => me0_clusters_probe_raw(1).cnt & me0_clusters_probe_raw(1).adr & me0_clusters_probe_raw(1).prt & me0_clusters_probe_raw(1).vpf,
                probe18 => me0_clusters_probe_raw(2).cnt & me0_clusters_probe_raw(2).adr & me0_clusters_probe_raw(2).prt & me0_clusters_probe_raw(2).vpf,
                probe19 => me0_clusters_probe_raw(3).cnt & me0_clusters_probe_raw(3).adr & me0_clusters_probe_raw(3).prt & me0_clusters_probe_raw(3).vpf
            );

    end generate;

    --== COUNT of summed sbits on selectable elink ==--
    -- assigned array of sbits for selected vfat (x) and elink (e)
    vfat3_sbit0xe_test <= vfat3_sbits_arr_i(to_integer(unsigned(test_sel_oh_sbit_me0)))(to_integer(unsigned(test_sel_vfat_sbit_me0)))((((to_integer(unsigned(test_sel_elink_sbit_me0 )) + 1) * 8) - 1) downto (to_integer(unsigned(test_sel_elink_sbit_me0)) * 8));

    elink_i: for i in 0 to 7 generate
        me0_sbit0xe_count : entity work.counter
            generic map(
                g_COUNTER_WIDTH  => 32,
                g_ALLOW_ROLLOVER => false
            )
            port map(
                ref_clk_i => ttc_clk_i.clk_40,
                reset_i   => sbit_test_reset,
                en_i      => vfat3_sbit0xe_test(i),
                count_o   => test_sbit0xe_presum(i)
            );
    end generate;

    -- assigned sum of all sbit counts on a selected vfat (x) and elink (e)
    test_sbit0xe_count_me0 <= std_logic_vector(unsigned(test_sbit0xe_presum(0)) + unsigned(test_sbit0xe_presum(1)) + unsigned(test_sbit0xe_presum(2)) + unsigned(test_sbit0xe_presum(3)) + unsigned(test_sbit0xe_presum(4)) + unsigned(test_sbit0xe_presum(5)) + unsigned(test_sbit0xe_presum(6)) + unsigned(test_sbit0xe_presum(7)));

    --== COUNTER for selectable sbit ==--
    -- assigned sbit of selected vfat (x) and sbit (s) 
    vfat3_sbit0xs_test <= vfat3_sbits_arr_i(to_integer(unsigned(test_sel_oh_sbit_me0)))(to_integer(unsigned(test_sel_vfat_sbit_me0)))(to_integer(unsigned(test_sel_sbit_me0)));

    me0_sbit0xs_count : entity work.counter
        generic map(
            g_COUNTER_WIDTH  => 32,
            g_ALLOW_ROLLOVER => false
        )
        port map(
            ref_clk_i => ttc_clk_i.clk_40,
            reset_i   => sbit_test_reset,
            en_i      => vfat3_sbit0xs_test,
            count_o   => test_sbit0xs_count_me0
        );


    ---------------------------------------------------------------------------------
    -- Clusterizer 
    ---------------------------------------------------------------------------------
    cluster_packer_me0 : if (true) generate

    begin
        each_oh: for oh in 0 to g_NUM_OF_OHs - 1 generate

            signal vfat_sbits_type_change : sbits_array_t(24 -1 downto 0);
            signal me0_clusters      : sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);

        begin
            each_vfat: for vfat in 0 to 23 generate

                each_sbit: for sbit in 0 to 63 generate
                    vfat_sbits_type_change(vfat)(sbit) <= vfat_sbits_arr(oh)(vfat)(sbit); --map onto self (t_vfat3_sbits_arr to sbits_array_t)

                end generate;
            end generate;
            --sbits_probe <= vfat_sbits_type_change(17); --17 selected arbitrarily, can change if want to probe other vfat

            cluster_packer_inst : entity work.cluster_packer
              generic map (
                DEADTIME          => 0,
                ONESHOT           => true,
                SPLIT_CLUSTERS    => 0,
                INVERT_PARTITIONS => false,
                NUM_VFATS         => 24,
                NUM_PARTITIONS    => 8,
                STATION           => 0
                )
              port map (
                reset                  => reset_i,
                clk_40                 => ttc_clk_i.clk_40,
                clk_fast               => ttc_clk_i.clk_160,
                mask_output_i          => '0',
                sbits_i                => vfat_sbits_type_change,
                cluster_count_o        => me0_cluster_count(oh),
                cluster_count_masked_o => open,
                clusters_o             => me0_clusters,
                clusters_masked_o      => open,
                overflow_o             => me0_overflow(oh)
                );
       
    --------------------------------------------------------------------------------
    -- Cluster mapping to ports
    --------------------------------------------------------------------------------
        cluster_loop : for I in 0 to 7 generate

        process (ttc_clk_i.clk_40)
        begin
            if (rising_edge(ttc_clk_i.clk_40)) then

                --me0_clusters_probe_raw <= me0_clusters;
                me0_clusters <= me0_clusters;

                if (me0_clusters(I).vpf = '1') then
                    me0_clusters_o(oh)(I).address <= get_adr(me0_clusters(I).prt, me0_clusters(I).adr);
                    me0_clusters_o(oh)(I).size    <= me0_clusters(I).cnt;
                else
                    me0_clusters_o(oh)(I).address <= (others => '1');
                    me0_clusters_o(oh)(I).size <= (others => '1');
                end if;
            end if;
        end process;
        end generate;
        end generate;
    end generate;

    --===============================================================================================
    -- this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py (do not edit) 
    --==== Registers begin ==========================================================================


    --==== Registers end ============================================================================

end sbit_me0_arch;
