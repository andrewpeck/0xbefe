-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @date April, 2017
--! @version 1.0
--! @brief IC control - RX FIFO
-------------------------------------------------------

--! Include the IEEE VHDL standard library
library ieee;
--! Use STD_Logic to define vector types
use ieee.std_logic_1164.all;
--! Used to convert std_logic_vector to integer and manage fifo pointer
use ieee.numeric_std.all;

--! @brief IC_rx_fifo Entity - RX FIFO
--! @details
--! The IC_rx_fifo is used to store the reply from the GBTx
--! following a read/write command. It extracts the header
--! details (GBTx address, number of words, etc.) and provide
--! a generic fifo interface to get the data.
-- IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--============================================================================--
--############################   Entity   ####################################--
--============================================================================--
entity ic_rx_fifo is
    generic (
        g_FIFO_DEPTH    : integer := 10;                                    --! Depth of the internal FIFO used to improve the timming performance
        g_WORD_SIZE     : integer := 8                                      --! Size of the words to be stored
    );
    port (
        wr_clk_i        : in  std_logic;                                    --! Rx clock (Rx_frameclk_o from GBT-FPGA IP): must be a multiple of the LHC frequency
        wr_clk_en_i     : in  std_logic;                                    --! Rx clock enable signal must be used in case of multi-cycle path(rx_clk_i > LHC frequency). By default: always enabled
        rd_clk_i        : in  std_logic;
        reset_i         : in  std_logic;                                    --! Reset all of the RX processes

        -- Data
        data_i          : in  std_logic_vector((g_WORD_SIZE-1) downto 0);   --! Input data (from deserializer)
        data_o          : out std_logic_vector((g_WORD_SIZE-1) downto 0);   --! Data from the FIFO (read by the user)

        -- Control
        write_i         : in  std_logic;                                    --! Request a write into the FIFO (from deserializer)
        read_i          : in  std_logic;                                    --! Request a read (from user)

        --Status
        rx_empty_o      : out std_logic                                     --! FIFO is empty
    );
end ic_rx_fifo;


--! @brief IC_rx_fifo Architecture - RX FIFO
--! @details
--! The IC_rx_fifo architecture implements the logic to store the received byte
--! and extract the header when a new_word_i flag is received.
architecture behavioral of ic_rx_fifo is

    -- Types
    subtype reg_t   is std_logic_vector((g_WORD_SIZE-1) downto 0);
    type ramreg_t   is array(integer range<>) of reg_t;
    constant zero_ram_s   : std_logic_vector((g_WORD_SIZE-1) downto 0) := (others => '0');

    -- Signals
    signal mem_arr              : ramreg_t(g_FIFO_DEPTH downto 0);

    signal wr_ptr               : integer range 0 to g_FIFO_DEPTH;
    signal word_in_mem_size     : integer range 0 to g_FIFO_DEPTH;
    signal rd_ptr               : integer range 0 to g_FIFO_DEPTH;

begin                 --========####   Architecture Body   ####========--

    ram_proc_rd: process(reset_i, rd_clk_i)
    begin
        if reset_i = '1' then
            rd_ptr              <= 0;
            rx_empty_o          <= '1';

        elsif rising_edge(rd_clk_i) then
            if read_i = '1' and rd_ptr < word_in_mem_size then
                rd_ptr          <= rd_ptr + 1;
            end if;

            if word_in_mem_size > rd_ptr then
                rx_empty_o         <= '0';
            else
                rx_empty_o         <= '1';
            end if;

            data_o          <= mem_arr(rd_ptr);
        end if;
    end process;

    ram_proc_wr: process(reset_i, wr_clk_i)
    begin
        if reset_i = '1' then
            wr_ptr              <= 0;
            word_in_mem_size    <= 0;
            mem_arr             <= (others => zero_ram_s);

        elsif rising_edge(wr_clk_i) then
            if write_i = '1' and wr_clk_en_i = '1' then
                mem_arr(wr_ptr) <= data_i;
                wr_ptr <= wr_ptr + 1;
                word_in_mem_size  <= word_in_mem_size + 1;
            end if;
        end if;
    end process;
end architecture;
--============================================================================--
--############################################################################--
--============================================================================--
