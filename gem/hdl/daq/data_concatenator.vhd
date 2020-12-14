------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    15:40 2019-06-25
-- Module Name:    data_concatenator
-- Description:    This module is used to drive a FIFO, but accepts input of variable width.
--                 It accumulates the inputs into a bigger word and pushes it into the fifo once it fills the full word size, wrapping around anything that is leftover to another word
--                 It also has an immediate push input, which forces to push to the FIFO even if the current word is not complete -- in this case the word is padded with zeros or ones (depending on configuration) on the lower bits
------------------------------------------------------------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gem_pkg.all;

entity data_concatenator is
    generic(
        g_FIFO_WORD_SIZE_BYTES  : integer := 24;
        g_INPUT_BYTES_SIZE      : integer := 5; -- number of bits needed to encode the input size (in bytes)
        g_FILLER_BIT            : std_logic := '1'
    );
    port(
        reset_i             : in  std_logic;
        clk_i               : in  std_logic; -- should be the same as the fifo write clock

        input_data_i        : in  std_logic_vector((g_FIFO_WORD_SIZE_BYTES * 8) - 1 downto 0); -- input data (the number of bits used is given in input_size_i, see below)
        input_bytes_i       : in  std_logic_vector(g_INPUT_BYTES_SIZE - 1 downto 0); -- number of lower bytes to use from input_data_i
        input_valid_i       : in  std_logic; -- input data is pushed when this is high
        new_event_i         : in  std_logic; -- setting this to 1 forces a "flush", meaning that the data currently accumulated is pushed to the fifo no matter how much of the word is filled currently. And if the input_valid_i is high, then the current input_data_i will not be in this push, but rather accumulated as usual for the next push.
        
        fifo_din_o          : out std_logic_vector((g_FIFO_WORD_SIZE_BYTES * 8) - 1 downto 0); -- control of the external fifo: connect to din port
        fifo_wr_en_o        : out std_logic; -- control of the external fifo: connect to we_en port
        event_word_cnt_o    : out unsigned(11 downto 0); -- number of words in the current event - this is incremented by 1 every time fifo_wr_en is set high, and reset to 0 when new_event_i is set high
        word_cnt_ovf_o      : out std_logic;
        buf_empty_o         : out std_logic -- if set high, this means that the buffer is currently empty (this can be used when new_event_i is high to determine if there is data for the current event that will be still pushed or not)
    );
end data_concatenator;

architecture data_concatenator_arch of data_concatenator is
    
    signal buf              : std_logic_vector((g_FIFO_WORD_SIZE_BYTES * 8) - 1 downto 0);    
    signal pos_byte         : integer range 0 to g_FIFO_WORD_SIZE_BYTES := g_FIFO_WORD_SIZE_BYTES; -- current position within the buffer
    
    signal event_word_cnt   : unsigned(11 downto 0) := (others => '0');
    signal word_cnt_ovf     : std_logic := '0';
    
begin

    event_word_cnt_o <= event_word_cnt;
    word_cnt_ovf_o <= word_cnt_ovf;
    buf_empty_o <= '1' when pos_byte = g_FIFO_WORD_SIZE_BYTES else '0';

    process(clk_i)
--        variable tmp_buf : std_logic_vector((g_FIFO_WORD_SIZE_BYTES * 8) - 1 downto 0);
    begin
        if (rising_edge(clk_i)) then
            if (reset_i = '1') then
                buf <= (others => g_FILLER_BIT);
                pos_byte <= g_FIFO_WORD_SIZE_BYTES;
                event_word_cnt <= (others => '0');
                word_cnt_ovf <= '0';
                fifo_wr_en_o <= '0';
                fifo_din_o <= (others => g_FILLER_BIT);
            else
                
                -- we have to push the current data if any, and write to the other buffer if input_valid_i is high (actually the logic is also the same if the current position is 0, meaning that the current buffer is exhausted)
                if (new_event_i = '1' or pos_byte = 0) then
                    -- push data if the buffer is not empty
                    if (pos_byte /= g_FIFO_WORD_SIZE_BYTES and pos_byte /= 0) then -- filler needed
                        fifo_wr_en_o <= '1';
                        fifo_din_o((g_FIFO_WORD_SIZE_BYTES * 8) - 1 downto pos_byte * 8) <= buf((g_FIFO_WORD_SIZE_BYTES * 8) - 1 downto pos_byte * 8);
                        fifo_din_o((pos_byte * 8) - 1 downto 0) <= (others => g_FILLER_BIT);
                    elsif (pos_byte = 0) then -- filler not needed
                        fifo_wr_en_o <= '1';
                        fifo_din_o <= buf;
                    else
                        fifo_wr_en_o <= '0';
                        fifo_din_o <= (others => g_FILLER_BIT);
                    end if;
                    
                    -- record any currently valid input data, and update the position 
                    if (input_valid_i = '1') then
                        buf <= to_stdlogicvector(to_bitvector(input_data_i) sll ((g_FIFO_WORD_SIZE_BYTES - to_integer(unsigned(input_bytes_i))) * 8));
--                        buf <= input_data_i(to_integer(unsigned(input_size_i)) - 1 downto 0) & (g_FIFO_WORD_SIZE - 1 downto to_integer(unsigned(input_size_i)) => g_FILLER_BIT); -- need to account for the case when input_size = word size
                        pos_byte <= g_FIFO_WORD_SIZE_BYTES - to_integer(unsigned(input_bytes_i));
                    -- otherwise reset the position and clear the entire buffer
                    else 
                        pos_byte <= g_FIFO_WORD_SIZE_BYTES;
                        buf <= (others => g_FILLER_BIT);
                    end if;
                
                    if (new_event_i = '1') then
                        event_word_cnt <= (others => '0');
                        word_cnt_ovf <= '0';
                    elsif (pos_byte = g_FIFO_WORD_SIZE_BYTES) then
                        event_word_cnt <= event_word_cnt;
                        word_cnt_ovf <= word_cnt_ovf;
                    elsif (event_word_cnt /= x"fff") then
                        event_word_cnt <= event_word_cnt + 1;
                    else
                        event_word_cnt <= x"fff";
                        word_cnt_ovf <= '1';
                    end if;
                
                -- the new_word_i is low, so handle any incoming data as usual - record to the buffer, and push it out when filled up, with data overflow to a new buffer
                elsif (input_valid_i = '1') then
                
                    -- the data fits into the current buffer, no push necessary 
                    if (pos_byte >= to_integer(unsigned(input_bytes_i))) then
--                        buf <= buf(g_FIFO_WORD_SIZE - 1 downto pos) & to_stdlogicvector(to_bitvector(input_data_i) sll (pos - to_integer(unsigned(input_size_i))))(pos - 1 downto 0);
                        buf((pos_byte * 8) - 1 downto 0) <= to_stdlogicvector(to_bitvector(input_data_i) sll ((pos_byte - to_integer(unsigned(input_bytes_i))) * 8))((pos_byte * 8) - 1 downto 0);
                        pos_byte <= pos_byte - to_integer(unsigned(input_bytes_i));
                        fifo_wr_en_o <= '0';
                        fifo_din_o <= (others => g_FILLER_BIT);
                        
                    -- the data doesn't fit into the buffer, so push the current buffer plus as much new data as you can fit in the output, and record the rest in a new buffer
                    else
--                        fifo_din_o <= buf(g_FIFO_WORD_SIZE - 1 downto pos) & input_data_i(to_integer(unsigned(input_size_i)) - 1 downto to_integer(unsigned(input_size_i)) - pos);
                    
                        fifo_din_o((g_FIFO_WORD_SIZE_BYTES * 8) - 1 downto (pos_byte * 8)) <= buf((g_FIFO_WORD_SIZE_BYTES * 8) - 1 downto (pos_byte * 8));
--                        fifo_din_o(pos - 1 downto 0) <= input_data_i(to_integer(unsigned(input_size_i)) - 1 downto to_integer(unsigned(input_size_i)) - pos);
                        fifo_din_o((pos_byte * 8) - 1 downto 0) <= to_stdlogicvector(to_bitvector(input_data_i) srl ((to_integer(unsigned(input_bytes_i)) - pos_byte) * 8))((pos_byte * 8) - 1 downto 0);
                        fifo_wr_en_o <= '1';
                        buf <= to_stdlogicvector(to_bitvector(input_data_i) sll ((g_FIFO_WORD_SIZE_BYTES - to_integer(unsigned(input_bytes_i)) - pos_byte) * 8));
                        pos_byte <= g_FIFO_WORD_SIZE_BYTES - to_integer(unsigned(input_bytes_i)) - pos_byte;
                        if (event_word_cnt /= x"fff") then
                            event_word_cnt <= event_word_cnt + 1;
                        else
                            event_word_cnt <= x"fff";
                            word_cnt_ovf <= '1';
                        end if;
                    end if;
                    
                -- nothing to do, just make sure the write enable is set low
                else
                    fifo_wr_en_o <= '0';
                    fifo_din_o <= (others => g_FILLER_BIT);
                end if;
                
            end if;
        end if;
    end process;

end data_concatenator_arch;
