------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
--
-- Create Date:    23:45:21 2016-04-20
-- Module Name:    GBT
-- Description:    GBTX wrapper: this is a modified version of the original GBT-FPGA top level, but supports arbitrary number of GBT and is not tied to MGT quads.
--                 In fact MGT instantiation and related clocking code has been removed completely, and is instead done in the system layer as usual.
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

-- Xilinx devices library:
library unisim;
use unisim.vcomponents.all;

library xpm;
use xpm.vcomponents.all;

-- Custom libraries and packages:
use work.gbt_bank_package.all;
use work.vendor_specific_gbt_bank_package.all;
use work.common_pkg.all;

--=================================================================================================--
--#######################################   Entity   ##############################################--
--=================================================================================================--

entity gbt is
    generic(
        NUM_LINKS           : integer              := 1;
        TX_OPTIMIZATION     : integer range 0 to 1 := STANDARD;
        RX_OPTIMIZATION     : integer range 0 to 1 := STANDARD;
        TX_ENCODING         : integer range 0 to 1 := GBT_FRAME;
        RX_ENCODING_ODD     : integer range 0 to 1 := GBT_FRAME;
        RX_ENCODING_EVEN    : integer range 0 to 1 := GBT_FRAME;
        g_USE_RX_SYNC_FIFOS : boolean              := true -- when set to true the MGT RX data will be taken through a FIFO to transfer to rx_word_common_clk_i before even connecting to GBTX RX core (this will cause RX latency to not be deterministic, but it's useful if all rx_word_clk_arr_i clocks cannot be put on BUFGs, and will synthesize even if they're on BUFHs, while it would be very tight if not using the FIFOs). When false, rx_word_common_clk_i is not used
    );
    port(
        reset_i                     : in  std_logic;
        cnt_reset_i                 : in  std_logic;

        --========--
        -- Clocks --
        --========--

        tx_frame_clk_i              : in  std_logic;
        rx_frame_clk_i              : in  std_logic;
        tx_word_clk_arr_i           : in  std_logic_vector(NUM_LINKS - 1 downto 0);
        rx_word_clk_arr_i           : in  std_logic_vector(NUM_LINKS - 1 downto 0);
        rx_word_common_clk_i        : in  std_logic;

        --========--
        -- GBT TX --
        --========--

        tx_we_arr_i                 : in  std_logic_vector(NUM_LINKS - 1 downto 0);
        tx_data_arr_i               : in  t_gbt_frame_array(NUM_LINKS - 1 downto 0);
        tx_bitslip_cnt_i            : in  t_std7_array(NUM_LINKS - 1 downto 0);

        --========--
        -- GBT RX --
        --========--

        rx_bitslip_cnt_i            : in  t_std6_array(NUM_LINKS - 1 downto 0);
        rx_bitslip_auto_i           : in  std_logic_vector(NUM_LINKS - 1 downto 0);
        rx_data_valid_arr_o         : out std_logic_vector(NUM_LINKS - 1 downto 0);
        rx_data_arr_o               : out t_gbt_frame_array(NUM_LINKS - 1 downto 0);
        rx_data_widebus_arr_o       : out t_std32_array(NUM_LINKS - 1 downto 0); -- extra 32 bits of data if RX_ENCODING is set to WIDEBUS

        --========--
        --   MGT  --
        --========--

        mgt_status_arr_i            : in  t_mgt_status_arr(NUM_LINKS - 1 downto 0);
        mgt_ctrl_arr_o              : out t_mgt_ctrl_arr(NUM_LINKS - 1 downto 0);
        mgt_tx_data_arr_o           : out t_std40_array(NUM_LINKS - 1 downto 0);
        mgt_rx_data_arr_i           : in  t_std40_array(NUM_LINKS - 1 downto 0);

        --===========--
        --   Status  --
        --===========--

        prbs_mode_en_i              : in  std_logic;
        link_status_arr_o           : out t_gbt_link_status_arr(NUM_LINKS - 1 downto 0)

    );
end gbt;

--=================================================================================================--
--####################################   Architecture   ###########################################--
--=================================================================================================--

architecture gbt_arch of gbt is

    type t_int_array is array (integer range <>) of integer;
    constant RX_ENCODING_EVEN_ODD   : t_int_array(0 to 1) := (RX_ENCODING_EVEN, RX_ENCODING_ODD);
    constant TX_READY_DLY           : std_logic_vector(15 downto 0) := x"2000";

    --================================ Signal Declarations ================================--

    --========--
    -- GBT TX --
    --========--

    -- Comment: TX word width is device dependent.

    signal tx_word_data_arr             : t_std40_array(NUM_LINKS - 1 downto 0);
    signal tx_phaligned                 : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal tx_phalign_done              : std_logic_vector(NUM_LINKS - 1 downto 0);

    signal tx_prbs_data                 : std_logic_vector(79 downto 0);
    signal tx_data_arr                  : t_gbt_frame_array(NUM_LINKS - 1 downto 0);
    signal tx_data_encoded_arr          : t_std120_array(NUM_LINKS - 1 downto 0);
    signal tx_data_encoded_slipped_arr  : t_std120_array(NUM_LINKS - 1 downto 0);

    signal tx_gearbox_aligned           : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal tx_gearbox_align_done        : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal tx_ready                     : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal tx_ready_rx_wordclk          : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal tx_ready_cntdown             : t_std16_array(NUM_LINKS - 1 downto 0);

    --========--
    -- GBT RX --
    --========--

    signal rx_gearbox_clk_en            : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal rx_gearbox_ready             : std_logic_vector(NUM_LINKS - 1 downto 0);

    signal rx_data_encoded_arr          : t_std120_array(NUM_LINKS - 1 downto 0);

    signal rx_word_clk_arr              : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal mgt_rx_data_arr              : t_std40_array(NUM_LINKS - 1 downto 0);
    signal mgt_rx_sync_valid_arr        : std_logic_vector(NUM_LINKS - 1 downto 0);

    signal mgt_rx_slip_cnt_arr          : t_std8_array(NUM_LINKS - 1 downto 0);
    signal mgt_rx_slip_cnt_frameclk_arr : t_std8_array(NUM_LINKS - 1 downto 0);

    signal rx_data_arr                  : t_gbt_frame_array(NUM_LINKS - 1 downto 0);
    signal rx_data_widebus_arr          : t_std32_array(NUM_LINKS - 1 downto 0); -- extra 32 bits of data if RX_ENCODING is set to WIDEBUS
    signal rx_prbs_err_data_arr         : t_std80_array(NUM_LINKS - 1 downto 0);
    signal rx_prbs_err_arr              : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal rx_prbs_err_cnt_arr          : t_std16_array(NUM_LINKS - 1 downto 0);

    signal rx_link_good_arr             : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal rx_ready_arr                 : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal rx_ovf_arr                   : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal rx_ovf_sync_arr              : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal rx_unf_arr                   : std_logic_vector(NUM_LINKS - 1 downto 0);

    signal rx_error_detect_flag         : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal rx_error_cnt                 : t_std16_array(NUM_LINKS - 1 downto 0);

    signal rx_framealign_reset          : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal rx_header_flag               : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal rx_header_locked             : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal rx_header_locked_sync        : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal rx_bitslip_en_to_ctrl        : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal rx_bitslip_en                : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal rx_bitslip_is_even           : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal rx_bitslip_ready             : std_logic_vector(NUM_LINKS - 1 downto 0);
    signal rx_bitslip_en_pulse          : std_logic_vector(NUM_LINKS - 1 downto 0);

--=====================================================================================--

--=================================================================================================--
begin                                   --========####   Architecture Body   ####========--
--=================================================================================================--

   --===============--
   -- RX Sync FIFOs --
   --===============--

    -- put the data from all GBT MGT RXs through sync a FIFO immediately to get it out of the BUFH domain and put it on a common clock domain which is on BUFG
    -- This is to let the GBT cores to be placed more freely (not constrained to the area that the RX BUFHs are spanning)

    g_rx_sync_fifos : for i in 0 to NUM_LINKS - 1 generate

        gen_use_rx_sync_fifos : if g_USE_RX_SYNC_FIFOS generate

            rx_word_clk_arr(i) <= rx_word_common_clk_i;

            i_rx_sync_fifo : entity work.gearbox
                generic map(
                    g_IMPL_TYPE           => "FIFO",
                    g_INPUT_DATA_WIDTH    => 40,
                    g_OUTPUT_DATA_WIDTH   => 40,
                    g_FIFO_WAIT_NOT_EMPTY => true
                )
                port map(
                    reset_i     => reset_i or not mgt_status_arr_i(i).rx_reset_done,
                    wr_clk_i    => rx_word_clk_arr_i(i),
                    rd_clk_i    => rx_word_clk_arr(i),
                    din_i       => mgt_rx_data_arr_i(i),
                    valid_i     => '1',
                    dout_o      => mgt_rx_data_arr(i),
                    valid_o     => mgt_rx_sync_valid_arr(i),
                    overflow_o  => rx_ovf_arr(i),
                    underflow_o => rx_unf_arr(i)
                );

            i_sync_ovf : entity work.synch generic map(N_STAGES => 2) port map(async_i => rx_ovf_arr(i), clk_i   => rx_word_clk_arr(i), sync_o  => rx_ovf_sync_arr(i));

            i_gbt_rx_sync_ovf_latch : entity work.latch
                port map(
                    reset_i => reset_i or cnt_reset_i,
                    clk_i   => rx_word_clk_arr(i),
                    input_i => rx_ovf_sync_arr(i),
                    latch_o => link_status_arr_o(i).gbt_rx_sync_status.had_ovf
                );

            i_gbt_rx_sync_unf_latch : entity work.latch
                port map(
                    reset_i => reset_i or cnt_reset_i,
                    clk_i   => rx_word_clk_arr(i),
                    input_i => rx_unf_arr(i),
                    latch_o => link_status_arr_o(i).gbt_rx_sync_status.had_unf
                );

        end generate;

        gen_no_rx_sync_fifos : if not g_USE_RX_SYNC_FIFOS generate
            signal mgt_rx_data_arr_i_reg    : t_std40_array(NUM_LINKS - 1 downto 0);
        begin

            link_status_arr_o(i).gbt_rx_sync_status.had_ovf <= '0';
            link_status_arr_o(i).gbt_rx_sync_status.had_unf <= '0';
            mgt_rx_sync_valid_arr(i) <= '1';

            -- we use a bitslipper here to delay the data from the MGT, the pattern finder will then use rxslide to shift the user clock to align the frame
            -- so different bitslip settings will result in different RXUSRCLK phase where the frame header is aligned
            -- so we can use the different bitslip values to effectively position the usrclk in the center of the eye of the sampling clock in the gearbox
            --
            -- DISABLE THIS FOR NOW SINCE IT NEEDS MORE TESTING, AND ADDS ONE CLOCK OF LATENCY
--            i_rx_bitslip: entity work.bitslip
--                generic map(
--                    g_DATA_WIDTH           => 40,
--                    g_SLIP_CNT_WIDTH       => 6,
--                    g_TRANSMIT_LOW_TO_HIGH => false
--                )
--                port map(
--                    clk_i      => rx_word_clk_arr(i),
--                    slip_cnt_i => rx_bitslip_cnt_i(i),
--                    data_i     => mgt_rx_data_arr_i_reg(i),
--                    data_o     => mgt_rx_data_arr(i)
--                );
            mgt_rx_data_arr <= mgt_rx_data_arr_i_reg;

            -- if rx is standard, there's a fifo cdc downstream, so keep the mgt clock here
            g_rx_no_opt : if RX_OPTIMIZATION = STANDARD generate
                mgt_rx_data_arr_i_reg(i) <= mgt_rx_data_arr_i(i);
                rx_word_clk_arr(i) <= rx_word_clk_arr_i(i);
            end generate;

            -- if rx is lat optimized, already use the common clock in the bitslipper, and let the rxslide adjust the timing based on the slip count
            g_rx_opt : if RX_OPTIMIZATION = LATENCY_OPTIMIZED generate
                rx_word_clk_arr(i) <= rx_word_common_clk_i;
                process(rx_word_common_clk_i)
                begin
                    if rising_edge(rx_word_common_clk_i) then
                        mgt_rx_data_arr_i_reg(i) <= mgt_rx_data_arr_i(i);
                    end if;
                end process;
            end generate;

        end generate;

    end generate;

   --========--
   -- GBT TX --
   --========--

    gbtTx_gen: for i in 0 to NUM_LINKS -1 generate
        gbt_txdatapath_inst: entity work.gbt_tx
            generic map (
                TX_ENCODING                        => TX_ENCODING
            )
            port map (
                TX_RESET_I                         => reset_i,
                TX_FRAMECLK_I                      => tx_frame_clk_i,
                TX_CLKEN_i                         => '1',

                TX_ENCODING_SEL_i                  => '0', -- only used in dynamic encoding mode, which we don't use
                TX_ISDATA_SEL_I                    => tx_we_arr_i(i),

                TX_DATA_I                          => tx_data_arr(i),
                TX_EXTRA_DATA_WIDEBUS_I            => (others => '0'), -- TX wide bus??

                TX_FRAME_o                         => tx_data_encoded_arr(i)
            );

        i_tx_bitslip: entity work.bitslip
            generic map(
                g_DATA_WIDTH           => 120,
                g_SLIP_CNT_WIDTH       => 7,
                g_TRANSMIT_LOW_TO_HIGH => false
            )
            port map(
                clk_i      => tx_frame_clk_i,
                slip_cnt_i => tx_bitslip_cnt_i(i),
                data_i     => tx_data_encoded_arr(i),
                data_o     => tx_data_encoded_slipped_arr(i)
            );

        gbt_txgearbox_inst : entity work.gbt_tx_gearbox
            generic map(
                TX_OPTIMIZATION => TX_OPTIMIZATION
            )
            port map(
                TX_RESET_I      => reset_i,
                TX_FRAMECLK_I   => tx_frame_clk_i,
                TX_CLKEN_i      => '1',
                TX_WORDCLK_I    => tx_word_clk_arr_i(i),
                ---------------------------------------
                TX_PHALIGNED_o  => tx_phaligned(i),
                TX_PHCOMPUTED_o => tx_phalign_done(i),
                TX_FRAME_I      => tx_data_encoded_slipped_arr(i),
                TX_WORD_O       => tx_word_data_arr(i)
            );

        i_sync_gearbox_aligned : entity work.synch
            generic map(
                N_STAGES => 2
            )
            port map(
                async_i => tx_phaligned(i),
                clk_i   => tx_frame_clk_i,
                sync_o  => tx_gearbox_aligned(i)
            );

        i_sync_gearbox_align_done : entity work.synch
            generic map(
                N_STAGES => 2
            )
            port map(
                async_i => tx_phalign_done(i),
                clk_i   => tx_frame_clk_i,
                sync_o  => tx_gearbox_align_done(i)
            );

        mgt_tx_data_arr_o(i) <= tx_word_data_arr(i);
        tx_data_arr(i) <= tx_data_arr_i(i) when prbs_mode_en_i = '0' else tx_data_arr_i(i)(83 downto 80) & tx_prbs_data;

        link_status_arr_o(i).gbt_tx_gearbox_ready <= tx_gearbox_aligned(i) and tx_gearbox_align_done(i);
        link_status_arr_o(i).gbt_tx_ready <= tx_gearbox_aligned(i) and tx_gearbox_align_done(i);

        i_tx_gearbox_not_ready_latch: entity work.latch
            port map(
                reset_i => reset_i or cnt_reset_i,
                clk_i   => tx_frame_clk_i,
                input_i => not tx_gearbox_aligned(i) or not tx_gearbox_align_done(i),
                latch_o => link_status_arr_o(i).gbt_tx_had_not_ready
            );

        -- delay the tx ready signal (used to release the RX reset)
        process(tx_frame_clk_i)
        begin
            if rising_edge(tx_frame_clk_i) then
                if (tx_gearbox_aligned(i) = '0' or tx_gearbox_align_done(i) = '0') then
                    tx_ready_cntdown(i) <= TX_READY_DLY;
                    tx_ready(i) <= '0';
                else
                    if (tx_ready_cntdown(i) /= x"0000") then
                        tx_ready_cntdown(i) <= std_logic_vector(unsigned(tx_ready_cntdown(i)) - 1);
                        tx_ready(i) <= '0';
                    else
                        tx_ready_cntdown(i) <= x"0000";
                        tx_ready(i) <= '1';
                    end if;
                end if;
            end if;
        end process;

        i_tx_ready_sync : entity work.synch
            generic map(
                N_STAGES => 5,
                IS_RESET => true
            )
            port map(
                async_i => tx_ready(i),
                clk_i   => rx_word_clk_arr(i),
                sync_o  => tx_ready_rx_wordclk(i)
            );

    end generate;

   --========--
   -- GBT RX --
   --========--

    gbtRx_gen: for i in 0 to NUM_LINKS -1 generate

        gbt_rxgearbox_inst : entity work.gbt_rx_gearbox
            generic map(
                RX_OPTIMIZATION => RX_OPTIMIZATION
            )
            port map(
                RX_RESET_I      => reset_i or not rx_header_locked_sync(i),
                RX_WORDCLK_I    => rx_word_clk_arr(i),
                RX_FRAMECLK_I   => rx_frame_clk_i,
                RX_CLKEN_i      => '1',
                RX_CLKEN_o      => rx_gearbox_clk_en(i),
                ---------------------------------------
                RX_HEADERFLAG_i => rx_header_flag(i),
                READY_O         => rx_gearbox_ready(i),
                ---------------------------------------
                RX_WORD_I       => mgt_rx_data_arr(i),
                RX_FRAME_O      => rx_data_encoded_arr(i)
            );

        gbt_rxdatapath_inst: entity work.gbt_rx
            generic map (
                RX_ENCODING                        => RX_ENCODING_EVEN_ODD(i mod 2)
            )
            port map (
                RX_RESET_I                         => not(rx_gearbox_ready(i)),
                RX_FRAMECLK_I                      => rx_frame_clk_i,
                RX_CLKEN_i                         => rx_gearbox_clk_en(i),

                RX_ENCODING_SEL_i                  => '0',   -- only used in dynamic encoding mode, which we don't use
                RX_READY_O                         => rx_ready_arr(i),
                RX_ISDATA_FLAG_O                   => rx_data_valid_arr_o(i),
                RX_ERROR_DETECTED                  => rx_error_detect_flag(i),
                RX_BIT_MODIFIED_FLAG               => open,

                GBT_RXFRAME_i                      => rx_data_encoded_arr(i),
                RX_DATA_O                          => rx_data_arr(i),
                RX_EXTRA_DATA_WIDEBUS_O            => rx_data_widebus_arr(i)
            );

        i_err_cnt: entity work.counter
            generic map(
                g_COUNTER_WIDTH  => 16,
                g_ALLOW_ROLLOVER => false
            )
            port map(
                ref_clk_i => rx_frame_clk_i,
                reset_i   => reset_i or cnt_reset_i,
                en_i      => rx_error_detect_flag(i),
                count_o   => rx_error_cnt(i)
            );

        rx_link_good_arr(i)                           <= rx_ready_arr(i) and rx_gearbox_ready(i) and rx_header_locked_sync(i);
        link_status_arr_o(i).gbt_rx_ready             <= rx_link_good_arr(i);
        link_status_arr_o(i).gbt_rx_correction_cnt    <= rx_error_cnt(i);
        link_status_arr_o(i).gbt_rx_correction_flag   <= rx_error_detect_flag(i);
        link_status_arr_o(i).gbt_rx_gearbox_ready     <= rx_gearbox_ready(i);
        link_status_arr_o(i).gbt_rx_header_locked     <= rx_header_locked_sync(i);
        link_status_arr_o(i).gbt_rx_num_bitslips      <= mgt_rx_slip_cnt_frameclk_arr(i);
        rx_data_arr_o(i)                              <= rx_data_arr(i);
        rx_data_widebus_arr_o(i)                      <= rx_data_widebus_arr(i);

        rx_framealign_reset(i) <= (not mgt_status_arr_i(i).rx_reset_done) or (not tx_ready_rx_wordclk(i)) or reset_i;

        i_patternSearch : entity work.mgt_framealigner_pattsearch
            port map(
                RX_RESET_I         => rx_framealign_reset(i),
                RX_WORDCLK_I       => rx_word_clk_arr(i),
                RX_BITSLIP_CMD_O   => rx_bitslip_en_to_ctrl(i),
                MGT_BITSLIPDONE_i  => rx_bitslip_ready(i),
                RX_HEADER_LOCKED_O => rx_header_locked(i),
                RX_HEADER_FLAG_O   => rx_header_flag(i),
                RX_BITSLIPISEVEN_o => rx_bitslip_is_even(i),
                RX_WORD_I          => mgt_rx_data_arr(i)
            );

        i_bitslip_ctrl : entity work.mgt_bitslipctrl
            port map(
                RX_RESET_I         => rx_framealign_reset(i),
                RX_WORDCLK_I       => rx_word_clk_arr(i),
                MGT_CLK_I          => rx_word_clk_arr(i),
                RX_BITSLIPCMD_i    => rx_bitslip_en_to_ctrl(i),
                RX_BITSLIPCMD_o    => rx_bitslip_en(i),
                RX_HEADERLOCKED_i  => rx_header_locked(i),
                RX_BITSLIPISEVEN_i => rx_bitslip_is_even(i),
                RX_RSTONBITSLIP_o  => open,
                RX_ENRST_i         => '0', -- TODO: try reset on even
                RX_RSTONEVEN_i     => '0',
                DONE_o             => open, -- if no reset on even is done, this is equivalent to header locked
                READY_o            => rx_bitslip_ready(i)
            );

        mgt_ctrl_arr_o(i) <= (txreset => '0', rxreset => '0', rxslide => rx_bitslip_en(i));


        i_sync_header_locked: entity work.synch
            generic map(
                N_STAGES => 2
            )
            port map(
                clk_i   => rx_frame_clk_i,
                async_i => rx_header_locked(i),
                sync_o  => rx_header_locked_sync(i)
            );

        i_rx_bitslip_oneshot : entity work.oneshot
            port map(
                reset_i   => rx_framealign_reset(i),
                clk_i     => rx_word_clk_arr(i),
                input_i   => rx_bitslip_en(i),
                oneshot_o => rx_bitslip_en_pulse(i)
            );

        i_bitslip_cnt : entity work.counter
            generic map(
                g_COUNTER_WIDTH  => 8,
                g_ALLOW_ROLLOVER => false
            )
            port map(
                ref_clk_i => rx_word_clk_arr(i),
                reset_i   => rx_framealign_reset(i),
                en_i      => rx_bitslip_en_pulse(i),
                count_o   => mgt_rx_slip_cnt_arr(i)
            );

        i_bitslip_cnt_sync : xpm_cdc_gray
            generic map(
                DEST_SYNC_FF          => 4,
                REG_OUTPUT            => 0,
                WIDTH                 => 8
            )
            port map(
                src_clk      => rx_word_clk_arr(i),
                src_in_bin   => mgt_rx_slip_cnt_arr(i),
                dest_clk     => rx_frame_clk_i,
                dest_out_bin => mgt_rx_slip_cnt_frameclk_arr(i)
            );

        i_gbt_rx_not_ready_latch : entity work.latch
            port map(
                reset_i => reset_i or cnt_reset_i,
                clk_i   => rx_frame_clk_i,
                input_i => not rx_link_good_arr(i),
                latch_o => link_status_arr_o(i).gbt_rx_had_not_ready
            );

        i_gbt_rx_header_unlock_latch : entity work.latch
            port map(
                reset_i => reset_i or cnt_reset_i,
                clk_i   => rx_frame_clk_i,
                input_i => not rx_header_locked_sync(i),
                latch_o => link_status_arr_o(i).gbt_rx_header_had_unlock
            );

        --------- PRBS31 checker ---------

        i_rx_prbs_check : entity work.PRBS_ANY
            generic map(
                CHK_MODE    => true,
                INV_PATTERN => true,
                POLY_LENGHT => 31,
                POLY_TAP    => 28,
                NBITS       => 80
            )
            port map(
                RST      => reset_i,
                CLK      => rx_frame_clk_i,
                DATA_IN  => rx_data_arr(i)(79 downto 0),
                EN       => '1',
                DATA_OUT => rx_prbs_err_data_arr(i)
            );

        rx_prbs_err_arr(i) <= or_reduce(rx_prbs_err_data_arr(i));

        i_prbs_cnt : entity work.counter
            generic map(
                g_COUNTER_WIDTH    => 16,
                g_ALLOW_ROLLOVER   => false
            )
            port map(
                ref_clk_i => rx_frame_clk_i,
                reset_i   => reset_i or cnt_reset_i,
                en_i      => rx_prbs_err_arr(i),
                count_o   => rx_prbs_err_cnt_arr(i)
            );

        link_status_arr_o(i).gbt_prbs_err_cnt <= rx_prbs_err_cnt_arr(i);


    end generate;

    --============================================================--
    --                       TX PRBS31 generator                  --
    --============================================================--

    i_tx_prbs : entity work.PRBS_ANY
        generic map(
            CHK_MODE    => false,
            INV_PATTERN => true,
            POLY_LENGHT => 31,
            POLY_TAP    => 28,
            NBITS       => 80
        )
        port map(
            RST      => reset_i,
            CLK      => tx_frame_clk_i,
            DATA_IN  => x"00000000000000000000",
            EN       => '1',
            DATA_OUT => tx_prbs_data
        );

   --=====================================================================================--
end gbt_arch;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--
