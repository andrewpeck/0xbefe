------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    14:00 2018-01-16
-- Module Name:    VFAT_INPUT_BUFFER
-- Description:    This module creates full VFAT3 events from the 8bit daq data stream and buffers them in a fifo (or just local signals).
--                 Though keep in mind that the depth of this buffer is very small, so it must be readout frequently (this is done every 24th cycle on the daq_clk by an arbiter in the vfat_input_serializer)
--                 It uses a first word fall-through model, which means that if empty_o is 0 then data_o has valid data 
------------------------------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.ttc_pkg.all;
use work.common_pkg.all;
use work.gem_pkg.all;

entity vfat_input_buffer is
    port(
        -- reset
        reset_i             : in  std_logic;
        
        -- clock and data
        daq_data_clk_i      : in  std_logic;
        daq_link_i          : in  t_vfat_daq_link;
        fifo_rd_clk_i       : in  std_logic;
        
        -- outputs
        empty_o             : out std_logic;
        overflow_o          : out std_logic;
        underflow_o         : out std_logic;
        read_en_i           : in  std_logic;
        data_o              : out std_logic_vector(175 downto 0);
        crc_err_o           : out std_logic
    );
end vfat_input_buffer;

architecture vfat_input_buffer_arch of vfat_input_buffer is

    -- currently we only handle lossless packets with default config, later on this can be configurable to accomodate other data formats
    constant PACKET_NUM_WORDS   : integer := 22;

    signal reset_data_clk   : std_logic;
    signal reset_rd_clk     : std_logic;    
    
    signal packet_buf   : std_logic_vector(175 downto 0) := (others => '0'); -- our fake 1-deep fifo :)
    signal packet       : std_logic_vector(175 downto 0) := (others => '0');
    signal word_cnt     : integer range 0 to 31 := 0;
    signal crc_err_buf  : std_logic;
    
    signal fifo_wr_en   : std_logic := '0';
    signal fifo_empty   : std_logic := '1';
    signal fifo_empty_rd: std_logic := '1';
    signal fifo_ovf     : std_logic := '0';
    signal fifo_unf     : std_logic := '0';
    signal fifo_pop_req : std_logic := '0';
    signal fifo_pop_ack : std_logic := '0';

begin
    
    --======== Wiring ========--
    
    i_sync_reset_rd_clk : entity work.synch generic map(N_STAGES => 3, IS_RESET => true) port map(async_i => reset_i, clk_i => fifo_rd_clk_i, sync_o => reset_rd_clk);
    i_sync_reset_data_clk : entity work.synch generic map(N_STAGES => 3, IS_RESET => true) port map(async_i => reset_i, clk_i => daq_data_clk_i, sync_o => reset_data_clk);
    
    empty_o <= fifo_empty_rd;
    overflow_o <= fifo_ovf;
    underflow_o <= fifo_unf;
    data_o <= packet_buf;
    crc_err_o <= crc_err_buf;
    
    --======== Packet construction ========--
    
    fifo_wr_en <= daq_link_i.event_done;
    
    process(daq_data_clk_i)
    begin
        if (rising_edge(daq_data_clk_i)) then
            if (reset_data_clk = '1') then
                packet <= (others => '0');
                word_cnt <= 0;
            else
                
                if (daq_link_i.data_en = '1') then
                    
                    packet((175 - (word_cnt * 8)) downto (176 - ((word_cnt + 1) * 8))) <= daq_link_i.data; 
                    
                    if (word_cnt = PACKET_NUM_WORDS - 1) then
                        word_cnt <= 0;
                    else
                        word_cnt <= word_cnt + 1;
                    end if;                    
                else
                    word_cnt <= 0;
                end if;
            end if;
        end if;
    end process;
    
    --======== Fake FIFO writing ========--
    
    process(daq_data_clk_i)
    begin
        if (rising_edge(daq_data_clk_i)) then
            if (reset_data_clk = '1') then
                fifo_empty <= '1';
                fifo_pop_ack <= '0';
            else
                if ((fifo_wr_en = '1') and (fifo_empty = '0')) then
                    fifo_ovf <= '1';
                elsif (fifo_wr_en = '1') then
                    packet_buf <= packet;
                    crc_err_buf <= daq_link_i.crc_error;
                    fifo_empty <= '0';
                end if;
                
                if (fifo_pop_req = '1') then
                    fifo_empty <= '1';
                    fifo_pop_ack <= '1';
                else
                    fifo_pop_ack <= '0';
                end if;
                
            end if;
        end if;
    end process;
    
    --======== Fake FIFO reading ========--
    
    process(fifo_rd_clk_i)
    begin
        if (rising_edge(fifo_rd_clk_i)) then
            if (reset_rd_clk = '1') then
                fifo_unf <= '0';
                fifo_pop_req <= '0';
            else
                if ((read_en_i = '1') and ((fifo_empty = '1') or (fifo_pop_req = '1'))) then
                    fifo_unf <= '1';
                elsif (read_en_i = '1') then
                    fifo_pop_req <= '1';
                end if;
                
                if ((fifo_pop_req = '1') and (fifo_pop_ack = '1')) then
                    fifo_pop_req <= '0';
                end if;
            end if;
        end if;
    end process;

    i_fifo_empty_sync : entity work.synch
        generic map(
            N_STAGES => 2
        )
        port map(
            async_i => fifo_empty,
            clk_i   => fifo_rd_clk_i,
            sync_o  => fifo_empty_rd
        );
    
end vfat_input_buffer_arch;
