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
use work.gem_pkg.all;

entity vfat_input_serializer is
    port(
        -- reset
        reset_i             : in  std_logic;
        
        -- clock and data
        daq_data_clk_i      : in  std_logic;
        oh_daq_links_i      : in t_vfat_daq_link_arr(23 downto 0);
        rd_clk_i            : in  std_logic;
        
        -- outputs
        data_valid_o        : out std_logic;
        data_o              : out std_logic_vector(191 downto 0);
        crc_err_o           : out std_logic;
        zero_packet_o       : out std_logic;
        overflow_o          : out std_logic;
        underflow_o         : out std_logic
    );
end vfat_input_serializer;

architecture vfat_input_serializer_arch of vfat_input_serializer is

    signal buffer_empty_arr : std_logic_vector(23 downto 0);
    signal buffer_ovf_arr   : std_logic_vector(23 downto 0);
    signal buffer_unf_arr   : std_logic_vector(23 downto 0);
    signal buffer_rd_en_arr : std_logic_vector(23 downto 0) := (others => '0');
    signal data_arr         : t_std176_array(23 downto 0);
    signal crc_err_arr      : std_logic_vector(23 downto 0);

    signal vfat_idx         : integer range 0 to 23 := 0;
    signal vfat_idx_prev    : integer range 0 to 23 := 0;

begin

    --======== Wiring ========--
    
    data_valid_o <= not buffer_empty_arr(vfat_idx);
    data_o <= std_logic_vector(to_unsigned(vfat_idx, 8)) & "0000000" & crc_err_arr(vfat_idx) & data_arr(vfat_idx);
    crc_err_o <= crc_err_arr(vfat_idx);
    zero_packet_o <= not or_reduce(data_arr(vfat_idx) and x"00000000111111111111111111111111111111110000");
    
    overflow_o <= or_reduce(buffer_ovf_arr);
    underflow_o <= or_reduce(buffer_unf_arr);
    
    --======== VFAT buffers ========--
    
    g_vfat_buffers: for i in 0 to 23 generate
        i_vfat_input_buffer: entity work.vfat_input_buffer
            port map(
                reset_i        => reset_i,
                daq_data_clk_i => daq_data_clk_i,
                daq_link_i     => oh_daq_links_i(i),
                fifo_rd_clk_i  => rd_clk_i,
                empty_o        => buffer_empty_arr(i),
                overflow_o     => buffer_ovf_arr(i),
                underflow_o    => buffer_unf_arr(i),
                read_en_i      => buffer_rd_en_arr(i),
                data_o         => data_arr(i),
                crc_err_o      => crc_err_arr(i)
            );
    end generate;

    --======== Read arbiter ========--
    
    process(rd_clk_i)
    begin
        if (rising_edge(rd_clk_i)) then
            if (reset_i = '1') then
                vfat_idx <= 0;
                buffer_rd_en_arr <= (others => '0');
            else
                if (vfat_idx = 23) then
                    vfat_idx <= 0;
                else
                    vfat_idx <= vfat_idx + 1;
                end if;
                
                vfat_idx_prev <= vfat_idx;
                
                if (buffer_empty_arr(vfat_idx) = '0') then
                    buffer_rd_en_arr(vfat_idx) <= '1';
                end if;
                
                buffer_rd_en_arr(vfat_idx_prev) <= '0';
                
            end if;
        end if;
    end process;
    
end vfat_input_serializer_arch;
