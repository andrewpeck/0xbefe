------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: UCLA
-- Engineer: David Gotler
-- 
-- Create Date:    2023-03-06
-- Module Name:    sbit_me0_injection
-- Description:    This module handles sbit injection for bypassing VFATs in ME0
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

use work.common_pkg.all;
use work.ttc_pkg.all;

entity sbit_inj_me0 is
    generic(
        g_NUM_VFATS_PER_OH    : integer;
        g_FIFO_DATA_DEPTH     : integer;  -- write depth must be power of 2 (min value of 16). Optimal to initialize an entire Block RAM (depth = 512 for one block)
        g_FIFO_DATA_CNT_WIDTH : integer;
        g_NUM_BXS             : integer;
        g_DEBUG               : boolean
        );
    port(
        -- reset
        reset_i : in std_logic;

        -- TTC
        ttc_clk_i  : in t_ttc_clks;
        ttc_cmds_i : in t_ttc_cmds;

        -- sbit inject fifo inputs
        fifo_din_i        : in  std_logic_vector(63 downto 0);  -- shared 64-bit data bus input to fifos
        fifo_rd_en_i      : in  std_logic;
        fifo_wr_en_i      : in  std_logic_vector(g_NUM_VFATS_PER_OH-1 downto 0);

        -- sbit inject fifo outputs
        fifo_dout_o       : out t_std64_array(g_NUM_VFATS_PER_OH-1 downto 0);     -- all vfat data outputs from fifos
        fifo_empty_and_o  : out std_logic;
        fifo_full_and_o   : out std_logic;
        fifo_prog_full_o  : out std_logic_vector(g_NUM_VFATS_PER_OH-1 downto 0);
        fifo_valid_and_o  : out std_logic;
        fifo_rd_busy_or_o : out std_logic;
        fifo_wr_busy_or_o : out std_logic;
        fifo_wr_cnt_o     : out t_std16_array(g_NUM_VFATS_PER_OH-1 downto 0) := (others => (others => '0'))
        );
end sbit_inj_me0;

architecture sbit_inj_me0_arch of sbit_inj_me0 is

    -- resets
    signal reset : std_logic;

    -- fifo signals
    signal fifo_empty_arr      : std_logic_vector(g_NUM_VFATS_PER_OH-1 downto 0);
    signal fifo_full_arr       : std_logic_vector(g_NUM_VFATS_PER_OH-1 downto 0);
    signal fifo_data_valid_arr : std_logic_vector(g_NUM_VFATS_PER_OH-1 downto 0);
    signal fifo_rd_busy_arr    : std_logic_vector(g_NUM_VFATS_PER_OH-1 downto 0);
    signal fifo_wr_busy_arr    : std_logic_vector(g_NUM_VFATS_PER_OH-1 downto 0);

begin

    --== Resets ==--

    i_reset_sync : entity work.synch
        generic map(
            N_STAGES => 3
            )
        port map(
            async_i => reset_i,
            clk_i   => ttc_clk_i.clk_40,
            sync_o  => reset
            );

    --== FIFO synchronous instantiation ==--
    g_vfat3_loop : for vfat in 0 to g_NUM_VFATS_PER_OH -1 generate
        i_sbit_inj_fifo : xpm_fifo_sync
            generic map (
                CASCADE_HEIGHT      => 0,                      -- DECIMAL
                DOUT_RESET_VALUE    => "0",                    -- String
                ECC_MODE            => "no_ecc",               -- String
                FIFO_MEMORY_TYPE    => "block",                -- String
                FIFO_READ_LATENCY   => 1,                      -- DECIMAL
                FIFO_WRITE_DEPTH    => g_FIFO_DATA_DEPTH,      -- DECIMAL
                FULL_RESET_VALUE    => 0,                      -- DECIMAL
                PROG_EMPTY_THRESH   => 10,                     -- DECIMAL
                PROG_FULL_THRESH    => g_NUM_BXS,              -- DECIMAL
                RD_DATA_COUNT_WIDTH => g_FIFO_DATA_CNT_WIDTH,  -- DECIMAL
                READ_DATA_WIDTH     => 64,                     -- DECIMAL
                READ_MODE           => "std",                  -- String
                SIM_ASSERT_CHK      => 0,                      -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
                USE_ADV_FEATURES    => "1406",                 -- String
                WAKEUP_TIME         => 0,                      -- DECIMAL
                WRITE_DATA_WIDTH    => 64,                     -- DECIMAL
                WR_DATA_COUNT_WIDTH => g_FIFO_DATA_CNT_WIDTH   -- DECIMAL
                )
            port map (
                almost_empty  => open,
                almost_full   => open,
                data_valid    => fifo_data_valid_arr(vfat),
                dbiterr       => open,
                dout          => fifo_dout_o(vfat),
                empty         => fifo_empty_arr(vfat),
                full          => fifo_full_arr(vfat),
                overflow      => open,
                prog_empty    => open,
                prog_full     => fifo_prog_full_o(vfat),
                rd_data_count => open,
                rd_rst_busy   => fifo_rd_busy_arr(vfat),
                sbiterr       => open,
                underflow     => open,
                wr_ack        => open,
                wr_data_count => fifo_wr_cnt_o(vfat)(g_FIFO_DATA_CNT_WIDTH - 1 downto 0),
                wr_rst_busy   => fifo_wr_busy_arr(vfat),
                din           => fifo_din_i,
                injectdbiterr => '0',
                injectsbiterr => '0',
                rd_en         => fifo_rd_en_i,
                rst           => reset,
                sleep         => '0',
                wr_clk        => ttc_clk_i.clk_40,
                wr_en         => fifo_wr_en_i(vfat)
                );
    end generate;

    fifo_empty_and_o <= and fifo_empty_arr;
    fifo_full_and_o  <= and fifo_full_arr;
    fifo_valid_and_o <= and fifo_data_valid_arr;

    fifo_rd_busy_or_o <= or fifo_rd_busy_arr;
    fifo_wr_busy_or_o <= or fifo_rd_busy_arr;

end sbit_inj_me0_arch;
