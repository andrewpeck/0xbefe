-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @date April, 2017
--! @version 1.0
--! @brief IC control - Rx deserialization and decoding
-------------------------------------------------------

--! Include the IEEE VHDL standard library
library ieee;
--! Use STD_Logic to define vector types
use ieee.std_logic_1164.all;
--! Used to convert std_logic_vector to integer and manage fifo pointer
use ieee.numeric_std.all;

--! @brief IC_rx Entity - Rx deserialization and decoding
--! @details
--! The IC_rx entity handles the deserialization and decoding
--! of the received frame on the couple of bits dedicated to
--! the IC control.
entity ic_rx is
    generic (
        g_FIFO_DEPTH:  integer := 10                            --! Depth of the internal FIFO used to improve the timming performance
    );
    port (
        -- Clock and reset
        rx_clk_i        : in  std_logic;                        --! Rx clock (Rx_frameclk_o from GBT-FPGA IP): must be a multiple of the LHC frequency
        rx_clk_en       : in  std_logic;                        --! Rx clock enable signal must be used in case of multi-cycle path(rx_clk_i > LHC frequency). By default: always enabled

        reset_i         : in  std_logic;                        --! Reset all of the RX processes

        -- Status
        rx_empty_o      : out std_logic;                        --! Rx FIFO is empty (no reply from GBTx)

        -- Internal FIFO
        rd_clk_i        : in  std_logic;
        rd_i            : in  std_logic;                        --! Request a read operation of the internal FIFO (GBTx reply)
        data_o          : out std_logic_vector(7 downto 0);     --! Data from the FIFO

        -- IC lines
        rx_data_i       : in std_logic_vector(1 downto 0)       --! (RX) Array of bits from the GBT-Frame (bits 83/84) - IC line
   );
end ic_rx;

--! @brief IC_rx Architecture - Rx deserialization and decoding
--! @details
--! The IC_rx architecture implements the two components used to manage the IC line
--! in order to decode the data received from the GBTx and store the information into
--! a FIFO.
architecture behaviour of ic_rx is

    -- Signals
    signal byte_des             : std_logic_vector(7 downto 0);     --! Decoded word from deserializer
    signal wr                   : std_logic;                        --! Write request to saved decoded word into the FIFO (from deserializer)

    -- Components
    --! IC_deserializer component implements a state machine used to deserialize, decode and inform when a new command is received.
    component ic_deserializer is
        generic (
            g_WORD_SIZE     : integer := 8;
            g_DELIMITER     : std_logic_vector(7 downto 0) := "01111110"
        );
        port (
            clk_i           : in std_logic;
            rx_clk_en       : in std_logic;

            reset_i         : in std_logic;

            -- Data
            data_i          : in  std_logic_vector(1 downto 0);
            data_o          : out std_logic_vector((g_WORD_SIZE-1) downto 0);

            -- Status
            write_o         : out std_logic;
            new_word_o      : out std_logic
        );
    end component ic_deserializer;

    --! IC_rx_fifo contains the received data from the GBTx.
    component ic_rx_fifo is
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
            rx_empty_o      : out std_logic                                     --! Ready to be read, FIFO is not empty
        );
    end component ic_rx_fifo;

begin                 --========####   Architecture Body   ####========--

    -- RX Deserializer
    --! Instantiation of the deserializer component
    Deserializer_inst: ic_deserializer
        generic map(
            g_WORD_SIZE         => 8
        )
        port map(
            clk_i               => rx_clk_i,
            rx_clk_en           => rx_clk_en,

            reset_i             => reset_i,

            -- Data
            data_i              => rx_data_i,
            data_o              => byte_des,

            -- Status
            write_o             => wr,
            new_word_o          => open
        );

    -- RX Fifo
    --! Instantiation of the RX FIFO.
    ic_rx_fifo_inst: ic_rx_fifo
        generic map(
            g_WORD_SIZE         => 8,
            g_FIFO_DEPTH        => g_FIFO_DEPTH
        )
        port map(
            wr_clk_i            => rx_clk_i,
            wr_clk_en_i         => rx_clk_en,
            rd_clk_i            => rd_clk_i,

            reset_i             => reset_i,

            -- Data
            data_i              => byte_des,
            data_o              => data_o,

            -- Control
            write_i             => wr,
            read_i              => rd_i,

            -- Status
            rx_empty_o          => rx_empty_o
        );

end behaviour;
--============================================================================--
--############################################################################--
--============================================================================--