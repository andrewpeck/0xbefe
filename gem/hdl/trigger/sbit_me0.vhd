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
        g_NUM_OF_OHs           : integer;
        g_NUM_VFATS_PER_OH     : integer;
        g_ENABLE_RAW_SBIT_TEST : boolean := true;  -- if true, the raw S-bit testing features will be instanciated
        g_DISABLE_CLUSTERS     : boolean := false; -- if true, the S-bit clusterization algorithm will not be instanciated
        g_IPB_CLK_PERIOD_NS    : integer;
        g_DEBUG                : boolean
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
    signal reset_counters       : std_logic_vector(g_NUM_OF_OHs - 1 downto 0);
    signal cnt_reset_strobed    : std_logic_vector(g_NUM_OF_OHs - 1 downto 0);
    signal reset_fifo           : std_logic;

    -- VFAT constants
    constant g_NUM_ELINKs   : integer:= 8;
    constant g_MAX_SLIP_CNT   : integer:= 8;
    constant g_MAX_SR_DELAY   : integer:= 4;

    -- control signals
    signal sbit_cnt_time_max    : t_std32_array(g_NUM_OF_OHs - 1 downto 0);
    signal sbit_time_counter    : t_std32_array(g_NUM_OF_OHs - 1 downto 0);
    signal sbit_cnt_persist     : std_logic_vector(g_NUM_OF_OHs - 1 downto 0);
    signal sbit_timer_reset     : std_logic_vector(g_NUM_OF_OHs - 1 downto 0);
    signal sbit_cnt_snap        : std_logic_vector(g_NUM_OF_OHs - 1 downto 0);
    signal sbit_timer_snap      : std_logic_vector(g_NUM_OF_OHs - 1 downto 0);
    --signal clk_40_sbit          : std_logic;

    signal vfat_sbit_mask_arr    : t_vfat3_sbits_arr(g_NUM_OF_OHs - 1 downto 0) := (others => (others => (others => '0')));
    signal vfat_sbit_mapping_arr : t_oh_vfat_mapping_arr(g_NUM_OF_OHs - 1 downto 0);
    signal vfat_sbit_delay_arr   : t_oh_vfat_mapping_arr(g_NUM_OF_OHs - 1 downto 0);

    -- trigger signals
    signal vfat_sbits_arr       : t_vfat3_sbits_arr(g_NUM_OF_OHs - 1 downto 0); -- sbits after masking (before mapping & alignment)
    signal vfat_sbits_aligned   : t_vfat3_sbits_arr(g_NUM_OF_OHs - 1 downto 0); -- sbits after mapping & phase alignment
    signal vfat_trigger_arr     : t_std24_array(g_NUM_OF_OHs - 1 downto 0);     -- trigger per vfat (or of all unmasked sbits)
    signal vfat_sbits_or_arr    : t_std24_array(g_NUM_OF_OHs - 1 downto 0);

    -- probe signal for raw sbits --
    signal sbits_probe         : sbits_t;
    signal me0_clusters_probe  : t_oh_clusters_arr(g_NUM_OF_OHs - 1 downto 0);

    -- counters
    signal vfat_trigger_rate_arr : t_vfat_trigger_rate_arr(g_NUM_OF_OHs - 1 downto 0);

    -- clk freq
    constant  g_CLK_FREQUENCY : std_logic_vector(31 downto 0) := C_TTC_CLK_FREQUENCY_SLV;

    -- constol & status signals for raw S-bit testing features
    signal sbit_test_reset           : std_logic := '0';
    signal test_sbit0xe_count_me0    : std_logic_vector(31 downto 0);
    signal test_sbit0xs_count_me0    : std_logic_vector(31 downto 0);
    signal test_sel_oh_sbit_me0      : std_logic_vector(31 downto 0);
    signal test_sel_vfat_sbit_me0    : std_logic_vector(31 downto 0);
    signal test_sel_elink_sbit_me0   : std_logic_vector(31 downto 0);
    signal test_sel_sbit_me0         : std_logic_vector(31 downto 0);

    -- signals for sbit inject
    type t_fifo_cnt_array is array (integer range<>) of t_std16_array(23 downto 0);
    signal sbit_inj_fifo_din            : std_logic_vector(63 downto 0) := (others => '0');
    signal sbit_inj_data_arr            : t_vfat3_sbits_arr(g_NUM_OF_OHs - 1 downto 0);
    signal inject_sbits_en              : std_logic := '0';
    signal sbit_inj_fifo_rd_en          : std_logic := '0'; -- inject_sbits_en + processing
    signal load_sbits_en                : std_logic := '0';
    signal sbit_inj_fifo_wr_en          : t_std24_array(g_NUM_OF_OHs - 1 downto 0); -- load_sbits_en + processing

    signal sbit_inj_fifo_sel            : std_logic_vector (15 downto 0) := (others => '0');
    signal sbit_inj_oh_num              : integer range 0 to 216;
    signal sbit_inj_vfat_num            : integer range 0 to 24;
    signal sbit_inj_fifo_rst_flag       : std_logic;
    signal sbit_inj_fifo_err_flag       : std_logic_vector(3 downto 0);
    signal sbit_inj_fifo_rd_busy_or     : std_logic;
    signal sbit_inj_fifo_wr_busy_or     : std_logic;
    signal sbit_inj_fifo_empty_and      : std_logic;
    signal sbit_inj_fifo_full_and       : std_logic;
    -- signal sbit_inj_fifo_valid_and   : std_logic;
    signal sbit_inj_fifo_rd_busy_arr    : std_logic_vector(g_NUM_OF_OHs - 1 downto 0);
    signal sbit_inj_fifo_wr_busy_arr    : std_logic_vector(g_NUM_OF_OHs - 1 downto 0);
    signal sbit_inj_fifo_empty_arr      : std_logic_vector(g_NUM_OF_OHs - 1 downto 0);
    signal sbit_inj_fifo_full_arr       : std_logic_vector(g_NUM_OF_OHs - 1 downto 0);
    signal sbit_inj_fifo_prog_full_arr  : t_std24_array(g_NUM_OF_OHs - 1 downto 0);
    -- signal sbit_inj_fifo_valid_arr   : std_logic_vector(g_NUM_OF_OHs - 1 downto 0);
    signal sbit_inj_fifo_wr_cnt_arr     : t_fifo_cnt_array(g_NUM_OF_OHs - 1 downto 0);
    signal sbit_inj_fifo_data_cnt       : std_logic_vector(31 downto 0);
    signal sbit_inj_fifo_sync_flag      : std_logic;

    signal me0_clusters_probe_raw : sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);
    signal me0_cluster_count      : t_std11_array(g_NUM_OF_OHs -1 downto 0);
    signal me0_overflow           : std_logic_vector(g_NUM_OF_OHs -1 downto 0);


    ------ Register signals begin (this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py -- do not edit)
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
    g_sbit_control : for OH in 0 to g_NUM_OF_OHs - 1 generate
        process (ttc_clk_i.clk_40)
        begin
        if (rising_edge(ttc_clk_i.clk_40)) then

            cnt_reset_strobed(OH) <= reset_i or reset_counters(OH) or (sbit_timer_reset(OH) and not sbit_cnt_persist(OH));
    
            sbit_cnt_snap(OH) <= (sbit_timer_snap(OH) or sbit_cnt_persist(OH));
    
            if (reset_i = '1' or reset_counters(OH) = '1') then
            sbit_time_counter(OH) <= (others => '0');
            sbit_timer_reset(OH)  <= '1';
            sbit_timer_snap(OH)   <= '1';
            else
            if (sbit_time_counter(OH) = sbit_cnt_time_max(OH)) then
                sbit_time_counter(OH) <= (others => '0');
                sbit_timer_reset(OH)  <= '1';
                sbit_timer_snap(OH)   <= '1';
            else
                sbit_time_counter(OH) <= std_logic_vector(unsigned(sbit_time_counter(OH)) + 1);
                sbit_timer_reset(OH)  <= '0';
                sbit_timer_snap(OH)   <= '0';
            end if;
            end if;
    
        end if;
        end process;
    end generate;

    -- apply the sbit masks, and set per-vfat trigger bits
    process (ttc_clk_i.clk_40)
    begin
        if rising_edge(ttc_clk_i.clk_40) then
            for oh in 0 to g_NUM_OF_OHs - 1 loop
                for vfat in 0 to 23 loop
                    vfat_sbits_arr(oh)(vfat) <= vfat3_sbits_arr_i(oh)(vfat) and not vfat_sbit_mask_arr(oh)(vfat);
                    vfat_trigger_arr(oh)(vfat) <= or_reduce(vfat_sbits_aligned(oh)(vfat)); -- note that this will be 1 clock late compared to the vfat_sbits_arr (!) not a problem if used only in the counters, so will keep it like this for now to have relaxed timing
                    vfat_sbits_or_arr(oh)(vfat) <= or_reduce(vfat_sbits_aligned(oh)(vfat));
                end loop;
            end loop;
        end if;
    end process;

    -- apply me0 sbit phase alignment & mapping
    g_oh_align : for OH in 0 to g_NUM_OF_OHs - 1 generate
        i_sbit_align: entity work.me0_sbit_align
            generic map(
                g_NUM_OF_VFATs => g_NUM_VFATS_PER_OH,
                g_NUM_ELINKs   => g_NUM_ELINKs,
                g_MAX_SLIP_CNT => g_MAX_SLIP_CNT,
                g_MAX_SR_DELAY => g_MAX_SR_DELAY
            )
            port map(
                clk_i              => ttc_clk_i.clk_40,
                rst_i              => reset_i,
        
                vfat_mapping_arr_i =>  vfat_sbit_mapping_arr(OH),
                vfat_delay_arr_i   =>  vfat_sbit_delay_arr(OH),
                
                vfat_sbits_i       =>  vfat_sbits_arr(OH),
                vfat_sbits_o       =>  vfat_sbits_aligned(OH)
            );
    
    end generate;
    

    --== Counters ==--

    g_oh_counters: for oh in 0 to g_NUM_OF_OHs - 1 generate

        --- rate counter for each vfat OR of sbits ---
        g_vfat_counters: for vfat in 0 to 23 generate

            i_counter_snap : entity work.counter_snap

                generic map (
                    g_TMR_INST       => 0,
                    g_COUNTER_WIDTH  => 32,
                    g_ALLOW_ROLLOVER => false,
                    g_INCREMENT_STEP => 1
                    )
                port map (
                    ref_clk_i => ttc_clk_i.clk_40,
                    reset_i   => cnt_reset_strobed(oh),
                    en_i      => vfat_sbits_or_arr(oh)(vfat),
                    snap_i    => sbit_cnt_snap(oh),
                    count_o   => vfat_trigger_rate_arr(oh)(vfat)
                    );


        end generate;

    end generate;

    --== Debug me0 sbits ==--

    ila_enable : if g_DEBUG generate
        me0_cluster_debug : ila_sbit_me0
            PORT MAP (
                clk => ttc_clk_i.clk_40,

                probe0 => me0_clusters_probe(0)(0).size & me0_clusters_probe(0)(0).address,
                probe1 => me0_clusters_probe(0)(1).size & me0_clusters_probe(0)(1).address,
                probe2 => me0_clusters_probe(0)(2).size & me0_clusters_probe(0)(2).address,
                probe3 => me0_clusters_probe(0)(3).size & me0_clusters_probe(0)(3).address,
                probe4 => me0_clusters_probe(0)(4).size & me0_clusters_probe(0)(4).address,
                probe5 => me0_clusters_probe(0)(5).size & me0_clusters_probe(0)(5).address,
                probe6 => me0_clusters_probe(0)(6).size & me0_clusters_probe(0)(6).address,
                probe7 => me0_clusters_probe(0)(7).size & me0_clusters_probe(0)(7).address,
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

    --== Raw S-bit testing features ==--

    g_raw_sbit_test : if not g_ENABLE_RAW_SBIT_TEST generate

        -- per eLink
        signal vfat3_sbit0xe_test_oh   : t_std64_array(23 downto 0);
        signal vfat3_sbit0xe_test_vfat : std_logic_vector(63 downto 0);
        signal vfat3_sbit0xe_test      : std_logic_vector(7 downto 0);
        signal test_sbit0xe_presum     : t_std32_array(7 downto 0);

        -- per S-bit
        signal vfat3_sbit0xs_test_oh   : t_std64_array(23 downto 0);
        signal vfat3_sbit0xs_test_vfat : std_logic_vector(63 downto 0);
        signal vfat3_sbit0xs_test      : std_logic;

    begin

        --== COUNT of summed sbits on selectable elink ==--
        -- assigned array of sbits for selected vfat (x) and elink (e)
        vfat3_sbit0xe_test_oh   <= vfat_sbits_aligned(to_integer(unsigned(test_sel_oh_sbit_me0))) when rising_edge(ttc_clk_i.clk_40);
        vfat3_sbit0xe_test_vfat <= vfat3_sbit0xe_test_oh(to_integer(unsigned(test_sel_vfat_sbit_me0))) when rising_edge(ttc_clk_i.clk_40);
        vfat3_sbit0xe_test      <= vfat3_sbit0xe_test_vfat((((to_integer(unsigned(test_sel_elink_sbit_me0 )) + 1) * 8) - 1) downto (to_integer(unsigned(test_sel_elink_sbit_me0)) * 8)) when rising_edge(ttc_clk_i.clk_40);

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
        vfat3_sbit0xs_test_oh   <= vfat_sbits_aligned(to_integer(unsigned(test_sel_oh_sbit_me0))) when rising_edge(ttc_clk_i.clk_40);
        vfat3_sbit0xs_test_vfat <= vfat3_sbit0xs_test_oh(to_integer(unsigned(test_sel_vfat_sbit_me0))) when rising_edge(ttc_clk_i.clk_40);
        vfat3_sbit0xs_test      <= vfat3_sbit0xs_test_vfat(to_integer(unsigned(test_sel_sbit_me0))) when rising_edge(ttc_clk_i.clk_40);

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

    end generate;

    ------------------------------------------------------
    -- sbit injection signal mapping and process
    ------------------------------------------------------

    -- reset flag logic
    sbit_inj_fifo_rst_flag <= reset_fifo or sbit_inj_fifo_rd_busy_or or sbit_inj_fifo_wr_busy_or;
    -- map fifo select to indexes
    sbit_inj_oh_num <= to_integer(unsigned(sbit_inj_fifo_sel(15 downto 8)));
    sbit_inj_vfat_num <= to_integer(unsigned(sbit_inj_fifo_sel(7 downto 0)));

    process (ttc_clk_i.clk_40)
        variable cnt : std_logic_vector(31 downto 0);
        variable sum : unsigned(31 downto 0);
        variable cnt_eq_arr : t_std24_array(g_NUM_OF_OHs-1 downto 0);
        variable cnt_eq : std_logic_vector(g_NUM_OF_OHs-1 downto 0);
    begin
        if (rising_edge(ttc_clk_i.clk_40)) then
            -- demux wr en bus
            if (load_sbits_en = '1' and sbit_inj_fifo_rst_flag='0') then
                sbit_inj_fifo_wr_en <= (others => (others => '0'));
                sbit_inj_fifo_wr_en(sbit_inj_oh_num)(sbit_inj_vfat_num) <= '1';
            else
                sbit_inj_fifo_wr_en <= (others => (others => '0'));
            end if;
            
            -- rd en signal logic
            if (inject_sbits_en = '1' and sbit_inj_fifo_rst_flag='0') then
                sbit_inj_fifo_rd_en <= '1';
            elsif (sbit_inj_fifo_empty_and = '1' or sbit_inj_fifo_rst_flag='1') then
                sbit_inj_fifo_rd_en <= '0';
            end if;

            ---------------------
            -- error flags
            ---------------------
            if reset_fifo='1' then
                sbit_inj_fifo_err_flag<="0000";
            -- write while all full
            elsif (load_sbits_en='1' and sbit_inj_fifo_full_and='1') then
                sbit_inj_fifo_err_flag<="0001";
            -- read while all empty
            elsif (inject_sbits_en='1' and sbit_inj_fifo_empty_and='1') then
                sbit_inj_fifo_err_flag<="0010";
            -- write while in reset state
            elsif (load_sbits_en='1' and sbit_inj_fifo_rst_flag='1') then
                sbit_inj_fifo_err_flag<="0011";
            -- read while in reset state
            elsif (inject_sbits_en='1' and sbit_inj_fifo_rst_flag='1') then
                sbit_inj_fifo_err_flag<="0100";
            -- read while out of sync
            elsif (sbit_inj_fifo_rd_en='1' and sbit_inj_fifo_sync_flag='0') then
                sbit_inj_fifo_err_flag<="0101";
            end if;

            -- sum all counters to get total data count
            sum := (others => '0');
            for oh in 0 to g_NUM_OF_OHs - 1 loop
                for vfat in 0 to 23 loop
                    -- Sum all count signals
                    cnt := X"0000" & sbit_inj_fifo_wr_cnt_arr(oh)(vfat); -- cast to 32 bit unsigned
                    sum := sum + unsigned(cnt);
                    -- check one vs all for any cnt value out of sync
                    cnt_eq_arr := (others => (others => '1') ); 
                    if sbit_inj_fifo_wr_cnt_arr(0)(0) /= sbit_inj_fifo_wr_cnt_arr(oh)(vfat) then
                        cnt_eq_arr(oh)(vfat) := '0';
                    end if;
                end loop;
                cnt_eq(oh) := and cnt_eq_arr(oh);
            end loop;
            sbit_inj_fifo_data_cnt <= std_logic_vector(sum);
            sbit_inj_fifo_sync_flag <= and cnt_eq;
        end if;
    end process;

    ---------------------------------------------------------------------------------
    -- Clusterizer/sbit injection
    ---------------------------------------------------------------------------------            

    cluster_packer_me0 : if not g_DISABLE_CLUSTERS generate
    begin
        each_oh: for oh in 0 to g_NUM_OF_OHs - 1 generate
            signal vfat_sbits_type_change : sbits_array_t(23 downto 0);
            signal me0_clusters      : sbit_cluster_array_t (NUM_FOUND_CLUSTERS-1 downto 0);
        begin
            i_sbit_inj : entity work.sbit_inj_me0
                generic map(
                    g_NUM_OF_OHs            => g_NUM_OF_OHs,
                    g_NUM_VFATS_PER_OH      => g_NUM_VFATS_PER_OH,
                    g_FIFO_DATA_DEPTH       => 512,
                    g_FIFO_DATA_CNT_WIDTH   => 10,
                    g_IPB_CLK_PERIOD_NS     => g_IPB_CLK_PERIOD_NS,
                    g_NUM_BXS               => 256,
                    g_DEBUG                 => g_DEBUG
                )
                port map(
                    reset_i                 => reset_fifo,
                    ttc_clk_i               => ttc_clk_i,
                    ttc_cmds_i              => ttc_cmds_i,
                    -- sbit inject fifo inputs
                    fifo_din_i     => sbit_inj_fifo_din,
                    fifo_rd_en_i   => sbit_inj_fifo_rd_en,
                    fifo_wr_en_i   => sbit_inj_fifo_wr_en(oh),
                    -- sbit inject fifo outputs
                    fifo_dout_o        => sbit_inj_data_arr(oh),
                    fifo_empty_and_o   => sbit_inj_fifo_empty_arr(oh),
                    fifo_full_and_o    => sbit_inj_fifo_full_arr(oh),
                    fifo_prog_full_o   => sbit_inj_fifo_prog_full_arr(oh),
                    fifo_valid_and_o   => open, -- sbit_inj_fifo_valid_arr(oh),
                    fifo_rd_busy_or_o  => sbit_inj_fifo_rd_busy_arr(oh),
                    fifo_wr_busy_or_o  => sbit_inj_fifo_wr_busy_arr(oh),
                    fifo_wr_cnt_o      => sbit_inj_fifo_wr_cnt_arr(oh)
                );
                
            sbit_inj_fifo_empty_and  <= and sbit_inj_fifo_empty_arr;
            sbit_inj_fifo_full_and   <= and sbit_inj_fifo_full_arr;
            -- sbit_inj_fifo_valid_and  <= and_reduce(sbit_inj_fifo_valid_arr);
            
            sbit_inj_fifo_rd_busy_or <= or sbit_inj_fifo_rd_busy_arr;
            sbit_inj_fifo_wr_busy_or <= or sbit_inj_fifo_wr_busy_arr;

            each_vfat: for vfat in 0 to 23 generate

                each_sbit: for sbit in 0 to 63 generate
                    -- MUX injected or real sbits and map to correct dt for cluster
                    -- map onto self (t_vfat3_sbits_arr to sbits_array_t)
                    vfat_sbits_type_change(vfat)(sbit) <= sbit_inj_data_arr(oh)(vfat)(sbit) when (sbit_inj_fifo_rd_en = '1') else vfat_sbits_aligned(oh)(vfat)(sbit);
                end generate;
            end generate;
            
            g_probe : if oh = 0 generate
                sbits_probe <= vfat_sbits_type_change(1); --1 selected to probe missing clusters, can change if want to probe other vfat
                me0_clusters_probe_raw <= me0_clusters;
            end generate;

            cluster_packer_inst : entity work.cluster_packer
              generic map (
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
                overflow_o             => me0_overflow(oh),
                valid_o                => open
                );
       
            --------------------------------------------------------------------------------
            -- Cluster mapping to ports
            --------------------------------------------------------------------------------
            cluster_loop : for I in 0 to 7 generate
                process (ttc_clk_i.clk_40)
                begin
                    if (rising_edge(ttc_clk_i.clk_40)) then
                        --me0_clusters_probe_raw <= me0_clusters;

                        if (me0_clusters(I).vpf = '1') then
                            me0_clusters_o(oh)(I).address <= me0_clusters(I).prt & me0_clusters(I).adr(7 downto 0);
                            me0_clusters_o(oh)(I).size    <= me0_clusters(I).cnt;
                        else
                            me0_clusters_o(oh)(I) <= NULL_SBIT_CLUSTER;
                        end if;
                        me0_clusters_probe(oh)(I) <= me0_clusters_o(oh)(I);

                    end if;
                end process;
            end generate;

        end generate; -- each_oh loop
    end generate; -- cluster_packer_me0 generate

    --===============================================================================================
    -- this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py (do not edit) 
    --==== Registers begin ==========================================================================


    --==== Registers end ============================================================================

end sbit_me0_arch;
