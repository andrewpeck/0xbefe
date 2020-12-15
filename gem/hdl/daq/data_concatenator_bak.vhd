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
use work.common_pkg.all;
use work.gem_pkg.all;

entity data_concatenator is
    generic(
        g_FIFO_WORD_SIZE        : integer := 192;
        g_FIFO_WORD_SIZE_BITS   : integer := 8;
        g_FILLER_BIT            : std_logic := '1'
    );
    port(
        reset_i         : in  std_logic;
        clk_i           : in  std_logic; -- should be the same as the fifo write clock

        input_data_i    : in  std_logic_vector(g_FIFO_WORD_SIZE - 1 downto 0); -- input data (the number of bits used is given in input_size_i, see below)
        input_size_i    : in  std_logic_vector(g_FIFO_WORD_SIZE_BITS - 1 downto 0); -- number of lower bits to use from input_data_i (the width of this port is intentionally oversized by one bit)
        input_valid_i   : in  std_logic; -- input data is pushed when this is high
        new_word_i      : in  std_logic; -- setting this to 1 forces a "flush", meaning that the data currently accumulated is pushed to the fifo no matter how much of the word is filled currently. And if the input_valid_i is high, then the current input_data_i will not be in this push, but rather accumulated as usual for the next push.
        
        fifo_din_o      : out std_logic_vector(g_FIFO_WORD_SIZE - 1 downto 0); -- control of the external fifo: connect to din port
        fifo_wr_en_o    : out std_logic -- control of the external fifo: connect to we_en port
    );
end data_concatenator;

architecture data_concatenator_arch of data_concatenator is
    
    type t_buf_arr is array(integer range <>) of std_logic_vector(g_FIFO_WORD_SIZE - 1 downto 0);
    
    signal buf          : t_buf_arr(1 downto 0) := (others => (others => g_FILLER_BIT)); -- two buffers of the same size
    signal buf_idx      : unsigned(0 downto 0) := "0"; -- current buffer index
    signal buf_idx_prev : unsigned(0 downto 0) := "0"; -- buffer index in the previous clk cycle
    
    signal pos          : integer range 0 to g_FIFO_WORD_SIZE := g_FIFO_WORD_SIZE; -- current position within the buffer
    signal fifo_wr_en   : std_logic := '0';
    
begin

    fifo_din_o <= buf(to_integer(buf_idx_prev));
    fifo_wr_en_o <= fifo_wr_en;

    process(clk_i)
    begin
        if (rising_edge(clk_i)) then
            if (reset_i = '1') then
                buf <= (others => (others => g_FILLER_BIT));
                pos <= g_FIFO_WORD_SIZE;
                fifo_wr_en <= '0';
                buf_idx <= "0";
                buf_idx_prev <= "0";
            else
                
                buf_idx_prev <= buf_idx; -- delay the buf idx for use on the output ports to be in sync with the wr_en
                
                -- we have to push the current data if any, and write to the other buffer if input_valid_i is high (actually the logic is also the same if the current position is 0, meaning that the current buffer is exhausted)
                if (new_word_i = '1' or pos = 0) then
                    -- push data if the buffer is not empty
                    if (pos /= g_FIFO_WORD_SIZE) then
                        fifo_wr_en <= '1';
                    else
                        fifo_wr_en <= '0';
                    end if;
                    
                    -- switch buffers
                    buf_idx <= not buf_idx;
                    
                    -- record any currently valid input data, and update the position 
                    if (input_valid_i = '1') then
                        buf(to_integer(not buf_idx))(g_FIFO_WORD_SIZE - 1 downto g_FIFO_WORD_SIZE - to_integer(unsigned(input_size_i))) <= input_data_i(to_integer(unsigned(input_size_i)) - 1 downto 0);
                        pos <= g_FIFO_WORD_SIZE - to_integer(unsigned(input_size_i));
                        -- clear the rest of the buffer if the input size is lower than the buffer size
                        if (to_integer(unsigned(input_size_i)) < g_FIFO_WORD_SIZE) then
                            buf(to_integer(not buf_idx))(g_FIFO_WORD_SIZE - to_integer(unsigned(input_size_i)) - 1 downto 0) <= (others => g_FILLER_BIT);
                        end if;
                    -- otherwise reset the position and clear the entire buffer
                    else 
                        pos <= g_FIFO_WORD_SIZE;
                        buf(to_integer(not buf_idx)) <= (others => g_FILLER_BIT);
                    end if;
                
                -- the new_word_i is low, so handle any incoming data as usual - push to the main buffer with overflow to the other buffer, and if the overflow happens also assert the write enable and switch buffers
                elsif (input_valid_i = '1') then
                
                    -- the data fits into the current buffer, no switch or push necessary 
                    if (pos >= to_integer(unsigned(input_size_i))) then
                        buf(to_integer(buf_idx))(pos - 1 downto pos - to_integer(unsigned(input_size_i))) <= input_data_i(to_integer(unsigned(input_size_i)) - 1 downto 0);
                        pos <= pos - to_integer(unsigned(input_size_i));
                        fifo_wr_en <= '0';
                        
                    -- the data doesn't fit into the current buffer, so split it between the two buffers, switch them, and push the current one
                    else
                        buf(to_integer(buf_idx))(pos - 1 downto 0) <= input_data_i(to_integer(unsigned(input_size_i)) - 1 downto to_integer(unsigned(input_size_i)) - pos);
                        buf(to_integer(not buf_idx))(g_FIFO_WORD_SIZE - 1 downto g_FIFO_WORD_SIZE - (to_integer(unsigned(input_size_i)) - pos)) <= input_data_i(to_integer(unsigned(input_size_i) - pos) - 1 downto 0);
                        buf_idx <= not buf_idx;
                        fifo_wr_en <= '1';
                        pos <= g_FIFO_WORD_SIZE - (to_integer(unsigned(input_size_i)) - pos);
                        -- clear the rest of the buffer if the input size is lower than the buffer size
                        if (to_integer(unsigned(input_size_i)) - pos < g_FIFO_WORD_SIZE) then
                            buf(to_integer(not buf_idx))(g_FIFO_WORD_SIZE - (to_integer(unsigned(input_size_i)) - pos) - 1 downto 0) <= (others => g_FILLER_BIT);
                        end if;                        
                    end if;
                    
                -- nothing to do, just make sure the write enable is set low
                else
                    fifo_wr_en <= '0';
                end if;
                
            end if;
        end if;
    end process;

end data_concatenator_arch;
