------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    15:03:00 2017-02-03
-- Module Name:    GEARBOX
-- Description:    Serializer / deserializer module with compile time programmable input/output widths (must be divisible)
------------------------------------------------------------------------------------------------------------------------------------------------------

library xpm;
use xpm.vcomponents.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gearbox is
    generic(
        g_IMPL_TYPE         : string := "FIFO"; -- for now only a FIFO implementation is available, a more latency optimized version will be implemented later if needed
        g_INPUT_DATA_WIDTH  : integer := 8;
        g_OUTPUT_DATA_WIDTH : integer := 16
    );
    port(
        reset_i     : in  std_logic;
        wr_clk_i    : in  std_logic;
        rd_clk_i    : in  std_logic;
        din_i       : in  std_logic_vector(g_INPUT_DATA_WIDTH - 1 downto 0);
        valid_i     : in  std_logic;
        dout_o      : out std_logic_vector(g_OUTPUT_DATA_WIDTH - 1 downto 0);
        valid_o     : out std_logic;
        overflow_o  : out std_logic;
        underflow_o : out std_logic
    );
end gearbox;

architecture gearbox_arch of gearbox is

begin

    g_fifo_impl: if g_IMPL_TYPE = "FIFO" generate
        i_serdes_fifo : xpm_fifo_async
            generic map(
                FIFO_MEMORY_TYPE    => "block",
                FIFO_WRITE_DEPTH    => 64,
                WRITE_DATA_WIDTH    => g_INPUT_DATA_WIDTH,
                READ_MODE           => "std",
                FIFO_READ_LATENCY   => 1,
                FULL_RESET_VALUE    => 0,
                USE_ADV_FEATURES    => "1101", -- VALID(12) = 1 ; AEMPTY(11) = 0; RD_DATA_CNT(10) = 0; PROG_EMPTY(9) = 0; UNDERFLOW(8) = 1; -- WR_ACK(4) = 0; AFULL(3) = 0; WR_DATA_CNT(2) = 0; PROG_FULL(1) = 0; OVERFLOW(0) = 1
                READ_DATA_WIDTH     => g_OUTPUT_DATA_WIDTH,
                CDC_SYNC_STAGES     => 2,
                DOUT_RESET_VALUE    => "0"
            )
            port map(
                sleep         => '0',
                rst           => reset_i,
                wr_clk        => wr_clk_i,
                wr_en         => valid_i,
                din           => din_i,
                full          => open,
                prog_full     => open,
                wr_data_count => open,
                overflow      => overflow_o,
                wr_rst_busy   => open,
                almost_full   => open,
                wr_ack        => open,
                rd_clk        => rd_clk_i,
                rd_en         => '1',
                dout          => dout_o,
                empty         => open,
                prog_empty    => open,
                rd_data_count => open,
                underflow     => underflow_o,
                rd_rst_busy   => open,
                almost_empty  => open,
                data_valid    => valid_o,
                injectsbiterr => '0',
                injectdbiterr => '0',
                sbiterr       => open,
                dbiterr       => open
            );
    end generate;

end gearbox_arch;