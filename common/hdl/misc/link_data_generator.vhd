------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2022-09-02
-- Module Name:    LINK_DATA_GENERATOR
-- Description:    This module accepts AXI stream, and produces frontend DAQ optical link data, multiple links of various widths are supported (supported protocols are: VFAT and DMB).
--                 It is intended to be used to feed the DAQ module with raw CSC or GEM data either directly through the fabric or through the optical links
--                 Note: all user registers are on AXI clk domain, so it's expected that the ipb_user_clk will be set to axi_clk_i
------------------------------------------------------------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

library unisim;
use unisim.vcomponents.all;

use work.common_pkg.all;
use work.mgt_pkg.all;
use work.axi_pkg.all;
use work.ttc_pkg.all;
use work.board_config_package.all;
use work.ipbus.all;
use work.registers.all;

entity link_data_generator is
    generic(
        g_AXIS_WIDTH            : integer;
        g_NUM_LINKS             : integer;
        g_LINK_WIDTHS           : t_int_array(0 to g_NUM_LINKS - 1);
        g_LINK_FIFO_DEPTHS      : t_int_array(0 to g_NUM_LINKS - 1);
        g_FW_FLAVOR             : std_logic_vector(3 downto 0); -- 0 = GEM; 1 = CSC

        g_IPB_CLK_PERIOD_NS     : integer
    );
    port (
        reset_i                 : in  std_logic;

        -- axi stream interface
        axi_clk_i               : in  std_logic;
        axi_reset_b_i           : in  std_logic;        
        axis_tdata_i            : in  std_logic_vector(g_AXIS_WIDTH - 1 downto 0);
        axis_tlast_i            : in  std_logic;
        axis_tvalid_i           : in  std_logic;
        axis_mty_i              : in  std_logic_vector(5 downto 0);
        axis_zero_byte_i        : in  std_logic;
        axis_qid_i              : in  std_logic_vector(10 downto 0);
        axis_tready_o            : out std_logic;
        
        -- link interface
        link_clk_arr_i          : in  std_logic_vector(g_NUM_LINKS-1 downto 0);
        link_data_arr_o         : out t_mgt_64b_tx_data_arr(g_NUM_LINKS-1 downto 0);

        -- TTC
        ttc_clks_i              : in  t_ttc_clks;
        ttc_cmds_o              : out t_ttc_cmds;

        -- IPbus
        ipb_reset_i             : in  std_logic;
        ipb_clk_i               : in  std_logic;
        ipb_miso_o              : out ipb_rbus;
        ipb_mosi_i              : in  ipb_wbus
    );
end link_data_generator;

architecture link_data_generator_arch of link_data_generator is

    constant FIFO_READ_WIDTH        : integer := 64;
    constant TTC_FIFO_WIDTH         : integer := 42;
    constant TTC_FIFO_DEPTH         : integer := 512;
    constant TTC_FIFO_DATA_CNT_WIDTH: integer := log2ceil(TTC_FIFO_DEPTH);
    constant CONTROL_WORD_MARKER    : std_logic_vector(63 downto 0) := x"befebefebefebefe";
    constant LINK_WORD_MARKER       : std_logic_vector(7 downto 0) := x"bc";

    --==== resets ====--
    signal reset_axi_tmp        : std_logic; -- combined reset on the AXI clk domain
    signal reset_axi            : std_logic; -- combined reset on the AXI clk domain
    signal reset_link_clk       : std_logic_vector(g_NUM_LINKS - 1 downto 0); -- combined reset on each of the links clk domain
    signal reset_ttc            : std_logic; -- combined reset on the TTC clk40 domain
    signal reset_local          : std_logic := '0'; -- reset from regs
    signal reset_local_axi      : std_logic; -- reset from regs synched to AXI clk
    signal reset_i_axi          : std_logic; -- reset_i port synched to AXI clk
    
    --==== axi related signals ====--
    signal axis_ready           : std_logic;
    signal axi_link_num_err     : std_logic;

    --==== general controls ====--
    signal daq_latency          : std_logic_vector(7 downto 0) := (others => '0');
    signal daq_cnt              : std_logic_vector(39 downto 0);
    signal daq_cnt_delayed      : std_logic_vector(39 downto 0);
    
    --==== TTC fifo controls ====--    
    signal ttc_fifo_wr_en           : std_logic;
    signal ttc_fifo_din             : std_logic_vector(TTC_FIFO_WIDTH - 1 downto 0);
    signal ttc_fifo_full            : std_logic;
    signal ttc_fifo_wr_data_cnt     : std_logic_vector(15 downto 0) := (others => '0');
    signal ttc_fifo_ovf             : std_logic;
    signal ttc_fifo_ovf_latch       : std_logic;

    signal ttc_fifo_rd_en           : std_logic;
    signal ttc_fifo_dout            : std_logic_vector(TTC_FIFO_WIDTH - 1 downto 0);
    signal ttc_fifo_empty           : std_logic;
    signal ttc_fifo_unf             : std_logic;
    signal ttc_fifo_unf_latch       : std_logic;
    signal ttc_fifo_unf_latch_axi   : std_logic;
    
    --==== TTC control logic ====--
    signal ttc_first_resync_done    : std_logic;
    signal ttc_reset_bc0            : std_logic;
    signal ttc_first_resync_done_axi: std_logic;
    signal ttc_dout_resync          : std_logic;
    signal ttc_dout_l1a             : std_logic;
    signal ttc_dout_orbit           : std_logic_vector(27 downto 0);
    signal ttc_dout_bx              : std_logic_vector(11 downto 0);

    signal ttc_daq_cntrs            : t_ttc_daq_cntrs := TTC_DAQ_CNTRS_NULL;
    signal ttc_cmds                 : t_ttc_cmds := TTC_CMDS_NULL;
    
    --==== link fifo controls ====--    
    signal fifo_wr_en           : std_logic_vector(g_NUM_LINKS - 1 downto 0);
    signal fifo_din             : std_logic_vector(g_AXIS_WIDTH - 1 downto 0);
    signal fifo_full            : std_logic_vector(g_NUM_LINKS - 1 downto 0);
    signal fifo_wr_data_cnt     : t_std16_array(g_NUM_LINKS - 1 downto 0) := (others => (others => '0'));
    signal fifo_ovf             : std_logic_vector(g_NUM_LINKS - 1 downto 0);
    signal fifo_ovf_latch       : std_logic_vector(g_NUM_LINKS - 1 downto 0);

    signal fifo_rd_en           : std_logic_vector(g_NUM_LINKS - 1 downto 0);
    signal fifo_dout            : t_std64_array(g_NUM_LINKS - 1 downto 0);
    signal fifo_empty           : std_logic_vector(g_NUM_LINKS - 1 downto 0);
    signal fifo_aempty          : std_logic_vector(g_NUM_LINKS - 1 downto 0);
    signal fifo_unf             : std_logic_vector(g_NUM_LINKS - 1 downto 0);
    signal fifo_unf_latch       : std_logic_vector(g_NUM_LINKS - 1 downto 0);
    signal fifo_unf_latch_axi   : std_logic_vector(g_NUM_LINKS - 1 downto 0);

    --==== link status and controls ====--    
    signal link_word_err_axi    : std_logic_vector(g_NUM_LINKS - 1 downto 0) := (others => '0');
    signal link_evt_cnt_arr_axi : t_std32_array(g_NUM_LINKS - 1 downto 0) := (others => (others => '0'));

    ------ Register signals begin (this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py -- do not edit)
    ------ Register signals end ----------------------------------------------

begin

    ---------------------- wiring and CDC ---------------------- 

    g_synch_reset_i_axi :     entity work.synch generic map(N_STAGES => 4, IS_RESET => true) port map(async_i => reset_i, clk_i => axi_clk_i, sync_o => reset_i_axi);
    g_synch_reset_local_axi : entity work.synch generic map(N_STAGES => 4, IS_RESET => true) port map(async_i => reset_local, clk_i => axi_clk_i, sync_o => reset_local_axi);

    reset_axi_tmp <= reset_i_axi or reset_local_axi or not axi_reset_b_i;
    
    i_reset_stretch : entity work.pulse_extend
        generic map(
            DELAY_CNT_LENGTH => 4
        )
        port map(
            clk_i          => axi_clk_i,
            rst_i          => '0',
            pulse_length_i => x"f",
            pulse_i        => reset_axi_tmp,
            pulse_o        => reset_axi
        );

    g_synch_reset_ttc: entity work.synch generic map(N_STAGES => 4, IS_RESET => true) port map(async_i => reset_axi, clk_i => ttc_clks_i.clk_40, sync_o => reset_ttc);
    
    axis_tready_o <= axis_ready;
    ttc_cmds_o <= ttc_cmds;

    ---------------------- axi stream section ---------------------- 

    -- we can either receive a "control" word, or a DAQ word
    -- "control" words are g_AXIS_WIDTH bits wide and have top 64 bits filled with 0xbefebefebefebefe, and are used:
    --     * select the link FIFO to write subsequent DAQ words to
    --     * schedule L1A and resync commands to be requested from the TTC module
    -- the format of the "control" word is as follows:
    --     * [g_AXIS_WIDTH - 1 : g_AXIS_WIDTH - 64] -- constant 0xbefebefebefebefe
    --     * [63:50] -- unused / reserved
    --     * [49]    -- Insert resync (if this bit is set, a resync will be inserted at the given Orbit/BX)
    --     * [48]    -- Insert L1A (if this bit is set, an L1A will be inserted at the given Orbit/BX)
    --     * [47:20] -- Orbit number (only used for L1A/resync insertion, or for inserting empty events if "insert empty" feature is implemented)
    --     * [19:8]  -- BX number (only used for L1A/resync insertion, or for inserting empty events if "insert empty" feature is implemented)
    --     * [7:0]   -- link FIFO select
    --     * it could be nice to use some of the upper bits (which are filled with befe now) to have a link bitmask instructing to which links an empty event should be inserted for the given Orbit/BX
    --       this would save on transactions to insert empty events, which can be quite costly
    --       TODO: implement "insert empty" feature in the link_data_generator
    -- NEW NEW NEW
    -- The "control" word idea was dropped and qid is used instead to select the FIFO to write to:
    -- qid = 0 refers to the TTC fifo, where the data format remains the same as described above
    -- qid > 0 select a corresponding link fifo where link id = qid - 1 
    --
    -- DAQ words are just directly written to the pre-selected link FIFO
    -- before the actual DAQ data for every event there must always be a 64bit special "link" word (at the top of the AXI word), which also gets written in the FIFO
    -- the "link" word follows this format:
    --     * [63:56] -- constant 0xbc
    --     * [55]    -- if this bit is set, it means that this event is empty (note to self: could just use [11:0] = 0 for this condition, so this bit is not really necessary)
    --     * [54:52] -- number of extra 64bit words to skip at the end (given that AXI bus side can be up to 8x wider, there may be "null" data at the end)
    --     * [51:24] -- Orbit number
    --     * [23:12] -- BX number
    --     * [11:0]  -- number of 64bit words in this event

    process(axi_clk_i)
    begin
        if rising_edge(axi_clk_i) then
            if reset_axi = '1' then
                axis_ready <= '0';
                ttc_fifo_wr_en <= '0';
                ttc_fifo_din <= axis_tdata_i(49 downto 8);
                fifo_wr_en <= (others => '0');
                fifo_din <= axis_tdata_i;
                axi_link_num_err <= '0';
            else
                axis_ready <= '1';
                ttc_fifo_din <= axis_tdata_i(49 downto 8);
                fifo_din <= axis_tdata_i;

                if to_integer(unsigned(axis_qid_i)) = 0 then
                    ttc_fifo_wr_en <= axis_tvalid_i and axis_ready;
                else
                    ttc_fifo_wr_en <= '0';
                end if;

                for link in 0 to g_NUM_LINKS - 1 loop
                    if to_integer(unsigned(axis_qid_i)) = link + 1 then
                        fifo_wr_en(link) <= axis_tvalid_i and axis_ready;
                    else
                        fifo_wr_en(link) <= '0';
                    end if;
                end loop;
                
            end if;
        end if;
    end process;

    ---------------------- DAQ counters delay for latency emulation ---------------------- 

    daq_cnt <= ttc_daq_cntrs.orbit(27 downto 0) & ttc_daq_cntrs.bx when ttc_first_resync_done = '1' else (others => '0');
    
    g_daq_cnt_dly_bits : for i in 0 to 39 generate
        i_daq_cnt_shift_reg : entity work.shift_reg
            generic map(
                DEPTH           => 256,
                TAP_DELAY_WIDTH => 8,
                OUTPUT_REG      => false,
                SUPPORT_RESET   => false
            )
            port map(
                clk_i       => ttc_clks_i.clk_40,
                reset_i     => '0',
                tap_delay_i => daq_latency,
                data_i      => daq_cnt(i),
                data_o      => daq_cnt_delayed(i)
            );
    end generate;
    
    ---------------------- link section ---------------------- 

    g_links : for link in 0 to g_NUM_LINKS - 1 generate
        
        constant LINK_WIDTH             : integer := g_LINK_WIDTHS(link);
        constant NUM_SUBWORDS           : integer := FIFO_READ_WIDTH / LINK_WIDTH;
    
        constant FIFO_DATA_CNT_WIDTH    : integer := log2ceil(g_LINK_FIFO_DEPTHS(link));
    
        -- daq cnt sync fifo
        signal daq_cnt_dout             : std_logic_vector(39 downto 0);
        signal daq_cnt_orbit            : std_logic_vector(27 downto 0);
        signal daq_cnt_bx               : std_logic_vector(11 downto 0);
        signal daq_cnt_empty            : std_logic;
        signal daq_cnt_wr_rst_busy      : std_logic;
        signal daq_cnt_rd_rst_busy      : std_logic;
                
        signal dout_marker              : std_logic_vector(7 downto 0);
        signal dout_empty_evt           : std_logic;
        signal dout_num_extra           : std_logic_vector(2 downto 0);
        signal dout_orbit               : std_logic_vector(27 downto 0);
        signal dout_bx                  : std_logic_vector(11 downto 0);
        signal dout_num_words           : std_logic_vector(11 downto 0);
                
        signal word_cntdown             : unsigned(11 downto 0) := (others => '0');
        signal subword_cntdown          : unsigned(2 downto 0) := (others => '0');
        signal words_extra              : unsigned(2 downto 0) := (others => '0');
        signal link_data                : std_logic_vector(FIFO_READ_WIDTH - 1 downto 0) := (others => '0');
        signal link_data_valid          : std_logic := '0';
        signal link_empty_evt           : std_logic := '0';
        signal link_word_err            : std_logic := '0';
        signal link_evt_cnt             : unsigned(31 downto 0) := (others => '0');
        
        signal odd_cycle                : std_logic := '0';
        
    begin
    
        assert LINK_WIDTH <= FIFO_READ_WIDTH report "link data generator: link widths must be less than or equal to FIFO_READ_WIDTH" severity failure;
        assert LINK_WIDTH mod 8 = 0 report "link data generator: link widths must be divisible by 8" severity failure;
    
        g_synch_reset_link_clk: entity work.synch generic map(N_STAGES => 4, IS_RESET => true) port map(async_i => reset_axi, clk_i => link_clk_arr_i(link), sync_o => reset_link_clk(link));
        
        -- daq counters sync fifo (link clk must always be faster than ttc clk40)
        g_daqcnt_fifo : xpm_fifo_async
            generic map(
                FIFO_MEMORY_TYPE    => "block", -- TODO: probably best to switch to distributed here
                FIFO_WRITE_DEPTH    => 16,
                RELATED_CLOCKS      => 0,
                WRITE_DATA_WIDTH    => 40,
                READ_MODE           => "fwft",
                FIFO_READ_LATENCY   => 0,
                FULL_RESET_VALUE    => 0,
                USE_ADV_FEATURES    => "0000",
                READ_DATA_WIDTH     => 40,
                CDC_SYNC_STAGES     => 4,
                WR_DATA_COUNT_WIDTH => 1, -- not used
                PROG_FULL_THRESH    => 10, -- not used
                RD_DATA_COUNT_WIDTH => 1, -- not used
                PROG_EMPTY_THRESH   => 10, -- not used
                DOUT_RESET_VALUE    => "0",
                ECC_MODE            => "no_ecc"
            )
            port map(
                sleep         => '0',
                rst           => reset_ttc,
                wr_clk        => ttc_clks_i.clk_40,
                wr_en         => not (reset_ttc or daq_cnt_wr_rst_busy),
                din           => daq_cnt_delayed,
                wr_rst_busy   => daq_cnt_wr_rst_busy,
                rd_clk        => link_clk_arr_i(link),
                rd_en         => not daq_cnt_rd_rst_busy,
                dout          => daq_cnt_dout,
                empty         => daq_cnt_empty,
                rd_rst_busy   => daq_cnt_rd_rst_busy,
                injectsbiterr => '0',
                injectdbiterr => '0'
            );        

        process(link_clk_arr_i(link))
        begin
            if rising_edge(link_clk_arr_i(link)) then
                if reset_link_clk(link) = '1' then
                    daq_cnt_orbit <= (others => '0');
                    daq_cnt_bx <= (others => '0');
                else
                    if daq_cnt_empty = '0' then
                        daq_cnt_orbit <= daq_cnt_dout(39 downto 12);
                        daq_cnt_bx <= daq_cnt_dout(11 downto 0);
                    end if;
                end if;
            end if;
        end process;
        
        -- link DAQ fifo
        g_link_fifo : xpm_fifo_async
            generic map(
                FIFO_MEMORY_TYPE    => "block",
                FIFO_WRITE_DEPTH    => g_LINK_FIFO_DEPTHS(link),
                RELATED_CLOCKS      => 0,
                WRITE_DATA_WIDTH    => g_AXIS_WIDTH,
                READ_MODE           => "fwft",
                FIFO_READ_LATENCY   => 0,
                FULL_RESET_VALUE    => 0,
                USE_ADV_FEATURES    => "0905", -- VALID(12) = 0 ; AEMPTY(11) = 1; RD_DATA_CNT(10) = 0; PROG_EMPTY(9) = 0; UNDERFLOW(8) = 1; -- WR_ACK(4) = 0; AFULL(3) = 0; WR_DATA_CNT(2) = 1; PROG_FULL(1) = 0; OVERFLOW(0) = 1,
                READ_DATA_WIDTH     => FIFO_READ_WIDTH,
                CDC_SYNC_STAGES     => 4,
                WR_DATA_COUNT_WIDTH => FIFO_DATA_CNT_WIDTH,
                PROG_FULL_THRESH    => 10, -- not used
                RD_DATA_COUNT_WIDTH => 1, -- not used
                PROG_EMPTY_THRESH   => 10, -- not used
                DOUT_RESET_VALUE    => "0",
                ECC_MODE            => "no_ecc"
            )
            port map(
                sleep         => '0',
                rst           => reset_axi,
                wr_clk        => axi_clk_i,
                wr_en         => fifo_wr_en(link),
                din           => fifo_din,
                full          => fifo_full(link),
                prog_full     => open,
                wr_data_count => fifo_wr_data_cnt(link)(FIFO_DATA_CNT_WIDTH - 1 downto 0),
                overflow      => fifo_ovf(link),
                wr_rst_busy   => open,
                almost_full   => open,
                wr_ack        => open,
                rd_clk        => link_clk_arr_i(link),
                rd_en         => fifo_rd_en(link),
                dout          => fifo_dout(link),
                empty         => fifo_empty(link),
                prog_empty    => open,
                rd_data_count => open,
                underflow     => fifo_unf(link),
                rd_rst_busy   => open,
                almost_empty  => fifo_aempty(link),
                data_valid    => open,
                injectsbiterr => '0',
                injectdbiterr => '0'
            );
    
        -- link word:
        --     * [63:56] -- constant 0xbc
        --     * [55]    -- if this bit is set, it means that this event is empty (note to self: could just use [11:0] = 0 for this condition, so this bit is not really necessary)
        --     * [54:52] -- number of extra 64bit words to skip at the end (given that AXI bus side can be up to 8x wider, there may be "null" data at the end)
        --     * [51:24] -- Orbit number
        --     * [23:12] -- BX number
        --     * [11:0]  -- number of 64bit words in this event      
        dout_marker    <= fifo_dout(link)(63 downto 56);
        dout_empty_evt <= fifo_dout(link)(55);
        dout_num_extra <= fifo_dout(link)(54 downto 52);
        dout_orbit     <= fifo_dout(link)(51 downto 24);
        dout_bx        <= fifo_dout(link)(23 downto 12);
        dout_num_words <= fifo_dout(link)(11 downto 0);
    
        g_ovf_latch : entity work.latch
            port map(
                reset_i => reset_axi,
                clk_i   => axi_clk_i,
                input_i => fifo_ovf(link),
                latch_o => fifo_ovf_latch(link)
            );

        g_unf_latch : entity work.latch
            port map(
                reset_i => reset_link_clk(link),
                clk_i   => link_clk_arr_i(link),
                input_i => fifo_unf(link),
                latch_o => fifo_unf_latch(link)
            );
    
        g_synch_unf_axi: entity work.synch generic map(N_STAGES => 4, IS_RESET => false) port map(async_i => fifo_unf_latch(link), clk_i => axi_clk_i, sync_o => fifo_unf_latch_axi(link));      
    
        ---------------------- link logic ----------------------
       
        process(link_clk_arr_i(link))
        begin
            if rising_edge(link_clk_arr_i(link)) then
                if reset_link_clk(link) = '1' then
                    word_cntdown <= (others => '0');
                    subword_cntdown <= (others => '0');
                    link_data_valid <= '0';
                    link_data <= (others => '0');
                    link_word_err <= '0';
                    fifo_rd_en(link) <= '0';
                    odd_cycle <= '0';
                    link_evt_cnt <= (others => '0');
                else
                    
                    fifo_rd_en(link) <= '0';
                    link_empty_evt <= '0';
                    odd_cycle <= not odd_cycle;
                    
                    -- IDLE
                    if word_cntdown = x"000" and subword_cntdown = "000" then
                        
                        -- new event is ready
                        if fifo_empty(link) = '0' then
                            if dout_marker /= LINK_WORD_MARKER then
                                link_word_err <= '1';
                            end if;
                            
                            -- start sending the new event
                            if (unsigned(daq_cnt_orbit) >= unsigned(dout_orbit)) and (unsigned(daq_cnt_bx) >= unsigned(dout_bx)) then
                                fifo_rd_en(link) <= '1';
                                link_empty_evt <= dout_empty_evt;
                                word_cntdown <= unsigned(dout_num_words);
                                words_extra <= unsigned(dout_num_extra);
                                link_evt_cnt <= link_evt_cnt + 1;
                                if unsigned(dout_num_words) > unsigned(dout_num_extra) then
                                    subword_cntdown <= to_unsigned(NUM_SUBWORDS - 1, 3);
                                else
                                    subword_cntdown <= (others => '0');
                                end if;
                            end if; 
                            
                        end if;
                        
                        link_data_valid <= '0';
                        link_data <= (others => '0');
                        
                    -- SENDING DATA
                    else
                        
                        if subword_cntdown = 0 then
                            fifo_rd_en(link) <= '1';
                            word_cntdown <= word_cntdown - 1;
                            subword_cntdown <= to_unsigned(NUM_SUBWORDS - 1, 3);
                            link_data <= std_logic_vector(shift_right(unsigned(link_data), LINK_WIDTH));
                        elsif subword_cntdown = to_unsigned(NUM_SUBWORDS - 1, 3) then
                            link_data <= fifo_dout(link);
                            subword_cntdown <= subword_cntdown - 1;
                        else
                            link_data <= std_logic_vector(shift_right(unsigned(link_data), LINK_WIDTH));
                            subword_cntdown <= subword_cntdown - 1;
                        end if;
                        
                        if word_cntdown > words_extra then
                            link_data_valid <= '1';
                        else
                            link_data_valid <= '0';
                        end if;
                        
                        
                    end if;
                end if;
            end if;
        end process;
    
        g_synch_link_word_err: entity work.synch generic map(N_STAGES => 4, IS_RESET => false) port map(async_i => link_word_err, clk_i => axi_clk_i, sync_o => link_word_err_axi(link));
            
        g_synch_evt_cnt : xpm_cdc_gray
            generic map(
                DEST_SYNC_FF          => 4,
                WIDTH                 => 32
            )
            port map(
                src_clk      => link_clk_arr_i(link),
                src_in_bin   => std_logic_vector(link_evt_cnt),
                dest_clk     => axi_clk_i,
                dest_out_bin => link_evt_cnt_arr_axi(link)
            );
    
        ---------------------- link sender ----------------------

        assert g_FW_FLAVOR /= x"1" or LINK_WIDTH = 16 or LINK_WIDTH = 32 report "Link data generator error: In CSC flavor supported link widths are 16 (DMB) or 32 (ODMB7/5), but got LINK_WIDTH = " & integer'image(LINK_WIDTH) & " for link #" & integer'image(link) severity failure;
    
        process(link_clk_arr_i(link))
        begin
            if rising_edge(link_clk_arr_i(link)) then
                
                if LINK_WIDTH < 64 then
                    link_data_arr_o(link).txdata(63 downto LINK_WIDTH) <= (others => '0');
                end if;
                link_data_arr_o(link).txchardispval <= (others => '0');
                link_data_arr_o(link).txchardispmode <= (others => '0');
                link_data_arr_o(link).txheader <= (others => '0');
                link_data_arr_o(link).txsequence <= (others => '0');
                
                -- send DAQ data
                if link_data_valid = '1' then
                    link_data_arr_o(link).txdata(LINK_WIDTH - 1 downto 0) <= link_data(LINK_WIDTH - 1 downto 0);
                    link_data_arr_o(link).txcharisk <= (others => '0');
                
                -- send an empty event
--                elsif link_empty_evt = '1' then
                -- send IDLEs
                else
                    -- CSC
                    if g_FW_FLAVOR = x"1" then
                        -- TODO: implement ODMB7/5 IDLE patterns here
                        if LINK_WIDTH = 16 then
                            -- DMB
                            link_data_arr_o(link).txdata(LINK_WIDTH - 1 downto 0) <= x"50bc";
                            link_data_arr_o(link).txcharisk(1 downto 0) <= "01";
                        elsif LINK_WIDTH = 32 then
                            -- ODMB7/5
                            if odd_cycle = '0' then
                                link_data_arr_o(link).txdata(LINK_WIDTH - 1 downto 0) <= x"505050bc";
                            else
                                link_data_arr_o(link).txdata(LINK_WIDTH - 1 downto 0) <= x"606060bc";
                            end if;
                            link_data_arr_o(link).txcharisk(3 downto 0) <= "0001";
                        else
                        end if;
                        
                    -- GEM
                    elsif g_FW_FLAVOR = x"0" then
--                      TODO: implement VFAT idle patterns here
                        link_data_arr_o(link).txdata(LINK_WIDTH - 1 downto 0) <= (others => '0');
                        link_data_arr_o(link).txcharisk <= (others => '0');
                    -- ?
                    else
                        link_data_arr_o(link).txdata(LINK_WIDTH - 1 downto 0) <= (others => '0');
                        link_data_arr_o(link).txcharisk <= (others => '0');
                    end if;                    
                end if;
                
            end if;
        end process;    
    
    end generate;

    ---------------------- TTC control section ----------------------
    
    g_ttc_fifo : xpm_fifo_async
        generic map(
            FIFO_MEMORY_TYPE    => "block",
            FIFO_WRITE_DEPTH    => TTC_FIFO_DEPTH,
            RELATED_CLOCKS      => 0,
            WRITE_DATA_WIDTH    => TTC_FIFO_WIDTH,
            READ_MODE           => "fwft",
            FIFO_READ_LATENCY   => 0,
            FULL_RESET_VALUE    => 0,
            USE_ADV_FEATURES    => "0105", -- VALID(12) = 0 ; AEMPTY(11) = 0; RD_DATA_CNT(10) = 0; PROG_EMPTY(9) = 0; UNDERFLOW(8) = 1; -- WR_ACK(4) = 0; AFULL(3) = 0; WR_DATA_CNT(2) = 1; PROG_FULL(1) = 0; OVERFLOW(0) = 1,
            READ_DATA_WIDTH     => TTC_FIFO_WIDTH,
            CDC_SYNC_STAGES     => 4,
            WR_DATA_COUNT_WIDTH => TTC_FIFO_DATA_CNT_WIDTH,
            PROG_FULL_THRESH    => 10, -- not used
            RD_DATA_COUNT_WIDTH => 1, -- not used
            PROG_EMPTY_THRESH   => 10, -- not used
            DOUT_RESET_VALUE    => "0",
            ECC_MODE            => "no_ecc"
        )
        port map(
            sleep         => '0',
            rst           => reset_axi,
            wr_clk        => axi_clk_i,
            wr_en         => ttc_fifo_wr_en,
            din           => ttc_fifo_din,
            full          => ttc_fifo_full,
            prog_full     => open,
            wr_data_count => ttc_fifo_wr_data_cnt(TTC_FIFO_DATA_CNT_WIDTH - 1 downto 0),
            overflow      => ttc_fifo_ovf,
            wr_rst_busy   => open,
            almost_full   => open,
            wr_ack        => open,
            rd_clk        => ttc_clks_i.clk_40,
            rd_en         => ttc_fifo_rd_en,
            dout          => ttc_fifo_dout,
            empty         => ttc_fifo_empty,
            prog_empty    => open,
            rd_data_count => open,
            underflow     => ttc_fifo_unf,
            rd_rst_busy   => open,
            almost_empty  => open,
            data_valid    => open,
            injectsbiterr => '0',
            injectdbiterr => '0'
        );  

    ttc_dout_resync <= ttc_fifo_dout(41);
    ttc_dout_l1a <= ttc_fifo_dout(40);
    ttc_dout_orbit <= ttc_fifo_dout(39 downto 12);
    ttc_dout_bx <= ttc_fifo_dout(11 downto 0);

    g_ovf_latch : entity work.latch
        port map(
            reset_i => reset_axi,
            clk_i   => axi_clk_i,
            input_i => ttc_fifo_ovf,
            latch_o => ttc_fifo_ovf_latch
        );

    g_unf_latch : entity work.latch
        port map(
            reset_i => reset_ttc,
            clk_i   => ttc_clks_i.clk_40,
            input_i => ttc_fifo_unf,
            latch_o => ttc_fifo_unf_latch
        );

    g_synch_unf_axi: entity work.synch generic map(N_STAGES => 4, IS_RESET => false) port map(async_i => ttc_fifo_unf_latch, clk_i => axi_clk_i, sync_o => ttc_fifo_unf_latch_axi);
    g_synch_first_resync_axi: entity work.synch generic map(N_STAGES => 4, IS_RESET => false) port map(async_i => ttc_first_resync_done, clk_i => axi_clk_i, sync_o => ttc_first_resync_done_axi);

    -- TTC control logic
    process(ttc_clks_i.clk_40)
        variable time_match     : std_logic := '0';
    begin
        if rising_edge(ttc_clks_i.clk_40) then
            if reset_ttc = '1' then
                ttc_first_resync_done <= '0';
                ttc_daq_cntrs <= TTC_DAQ_CNTRS_NULL;
                ttc_cmds <= TTC_CMDS_NULL;
                ttc_fifo_rd_en <= '0';
                ttc_reset_bc0 <= '0';
            else
                ttc_cmds <= TTC_CMDS_NULL;
                ttc_fifo_rd_en <= '0';

                if ttc_reset_bc0 = '1' then
                    ttc_reset_bc0 <= '0';
                    ttc_daq_cntrs <= TTC_DAQ_CNTRS_NULL;
                    ttc_cmds.bc0 <= '1';
                elsif ttc_daq_cntrs.bx = std_logic_vector(unsigned(C_TTC_NUM_BXs) - 1) then
                    ttc_cmds.bc0 <= '1';
                    ttc_daq_cntrs.bx <= (others => '0');
                    ttc_daq_cntrs.orbit <= std_logic_vector(unsigned(ttc_daq_cntrs.orbit) + 1);
                else
                    ttc_daq_cntrs.bx <= std_logic_vector(unsigned(ttc_daq_cntrs.bx) + 1);
                end if;

                -- TODO: rework the reading of the TTC fifo, because this cannot handle consecutive L1As
                -- whenever the is a time match, it sets the rd_en, but the dout will only change one clock after that, at which point it's already too late -- the counters have moved on
                if (ttc_dout_orbit = ttc_daq_cntrs.orbit(27 downto 0)) and (ttc_dout_bx = ttc_daq_cntrs.bx) then
                    time_match := '1';
                else
                    time_match := '0';
                end if; 

                if ttc_fifo_empty = '0' then
                    -- for the first ever resync after reset we do not require a time match
                    if  ttc_dout_resync = '1' and (time_match = '1' or ttc_first_resync_done = '0') then
                        ttc_first_resync_done <= '1';
                        if ttc_first_resync_done = '0' then
                            ttc_reset_bc0 <= '1'; 
                            ttc_cmds.oc0 <= '1';
                            ttc_daq_cntrs <= TTC_DAQ_CNTRS_NULL;
                        end if;
                        ttc_cmds.resync <= '1';
                        ttc_fifo_rd_en <= '1';
                    end if;
                    
                    if ttc_dout_l1a = '1' and time_match = '1' then
                        ttc_cmds.l1a <= '1';
                        ttc_fifo_rd_en <= '1'; 
                    end if;
                end if;
            end if;
        end if;
    end process;

    --===============================================================================================
    -- this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py (do not edit)
    --==== Registers begin ==========================================================================

    --==== Registers end ============================================================================

end link_data_generator_arch;
