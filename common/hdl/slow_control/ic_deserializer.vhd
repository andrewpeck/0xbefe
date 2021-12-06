-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @date April, 2017
--! @version 1.0
--! @brief IC control - IC Field deserializer/decoder
-------------------------------------------------------

--! Include the IEEE VHDL standard library
library ieee;
--! Use STD_Logic to define vector types
use ieee.std_logic_1164.all;
--! Used to convert std_logic_vector to integer and manage fifo pointer
use ieee.numeric_std.all;

--! @brief IC_Deserializer Entity - IC Field deserializer/decoder
--! @details 
--! The IC_Deserializer deserializes the data and removes the zeros
--! inserted as specified by the HDLC standard (bit stuffing).
--! Additionally, it detects the delimiter pattern to inform the
--! core when a new frame is received.
entity ic_deserializer is
    generic (
        g_WORD_SIZE     : integer := 8;                                     --! Size of the words to be stored
        g_DELIMITER     : std_logic_vector(7 downto 0) := "01111110"        --! Delimiter pattern, defined by the HDLC standard ("01111110")
    );
    port (
        clk_i           : in std_logic;                                     --! Rx clock (Rx_frameclk_o from GBT-FPGA IP): must be a multiple of the LHC frequency
        rx_clk_en       : in std_logic;                                     --! Rx clock enable signal must be used in case of multi-cycle path(rx_clk_i > LHC frequency). By default: always enabled
		  
        reset_i         : in std_logic;                                     --! Reset all of the RX processes

        -- Data
        data_i          : in  std_logic_vector(1 downto 0);                 --! (RX) Array of bits from the GBT-Frame (bits 83/84) - IC line
        data_o          : out std_logic_vector((g_WORD_SIZE-1) downto 0);   --! Deserialized/decoded data

        -- Status
        write_o         : out std_logic;                                    --! Write signal to the FIFO
        new_word_o      : out std_logic                                     --! New frame received (Delimiter detected)
    );
end ic_deserializer;

--! @brief IC_Deserializer Architecture - IC Field deserializer/decoder
--! @details 
--! The IC_Deserializer architecture describes the logic required to
--! deserialize the input and decode the "HDLC" frame. The decoding
--! consists in removing the '0' inserted every 5 consecutive high level bits
--! bits and detecting/removing the delimiter packets (SOF/EOF).
architecture behaviour of ic_deserializer is    
begin                 --========####   Architecture Body   ####========-- 

    --! @brief Deserializer process: manages the decoding/deserialization
    --! @details 
    --! The deserialization is based on a counter, used to control the write_o
    --! signal (set to '1' when cnter value >= to the word size). The counter
    --! is reseted when a delimiter is received to synchronize the system and
    --! incremented when a valid bit is received (not a '0' to be removed).
    --! Finally, because of the size of the serial frame (2 bits and not only one),
    --! the logic of the process is duplicated once.
    --! An on-going signal is used to know wether the delimiter packet received
    --! is a start or end of frame.
    deserializer: process(reset_i, clk_i)

        variable reg                : std_logic_vector(g_WORD_SIZE-1 downto 0);
        variable reg_no_destuffing  : std_logic_vector(g_WORD_SIZE-1 downto 0);
        variable cnter              : integer range 0 to g_WORD_SIZE;
        variable ongoing            : std_logic;

    begin

        if reset_i = '1' then
            cnter                   := 0;
            reg                     := (others => '0');
            reg_no_destuffing       := (others => '0');
            ongoing                 := '0';

        elsif rising_edge(clk_i) then
		  
			if rx_clk_en = '1' then
                write_o         <= '0';
                new_word_o        <= '0';
    
                -- Data(1)
                reg(7 downto 0)     := data_i(1) & reg(7 downto 1);
                reg_no_destuffing   := data_i(1) & reg_no_destuffing(7 downto 1);
    
                if reg_no_destuffing(7 downto 1) = "0111110" then
                    reg(7 downto 0)    := reg(6 downto 0) & '0';
    
                elsif ongoing  = '1' then
                    cnter           := cnter + 1;
    
                end if;
    
                if reg_no_destuffing = g_DELIMITER then
                    cnter                       := 0;
                    ongoing                     := '1';
                    new_word_o                  <= '1';
    
                elsif reg_no_destuffing = x"FF" then
                    ongoing                     := '0';
    
                end if;
    
                if cnter >= g_WORD_SIZE and ongoing  = '1' then
                    cnter                       := 0;
                    data_o                      <= reg;
                    write_o                     <= '1';
                end if;
    
                -- Data(0)
                reg(7 downto 0)        := data_i(0) & reg(7 downto 1);
                reg_no_destuffing   := data_i(0) & reg_no_destuffing(7 downto 1);
    
                if reg_no_destuffing(7 downto 1) = "0111110" then
                    reg(7 downto 0)    := reg(6 downto 0) & '0';
    
                elsif ongoing  = '1' then
                    cnter           := cnter + 1;
    
                end if;
    
                if reg_no_destuffing = g_DELIMITER then
                    cnter                       := 0;
                    ongoing                     := '1';
                    new_word_o                  <= '1';
    
                elsif reg_no_destuffing = x"FF" then
                    ongoing                     := '0';
    
                end if;
    
                if cnter >= g_WORD_SIZE and ongoing  = '1' then
                    cnter                       := 0;
                    data_o                      <= reg;
                    write_o                     <= '1';
                end if;

			end if;
        end if;
        
    end process;
    
end behaviour;
--============================================================================--
--############################################################################--
--============================================================================--
