------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    12:00 2017-08-09
-- Module Name:    VFAT3_RX_LINK
-- Description:    This module decodes the aligned VFAT3 datastream, watches for errors, and separates the DAQ data from the slow control data 
------------------------------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.ttc_pkg.all;
use work.gem_pkg.all;

entity vfat3_rx_link is
    port(
        -- reset
        reset_i             : in  std_logic;
        
        -- clocks
        ttc_clk_i           : in  t_ttc_clks;
        
        -- control
        mask_i              : in std_logic;
        
        -- aligned data link
        data_i              : in  std_logic_vector(7 downto 0);
        sync_ok_i           : in  std_logic;
                
        -- outputs
        ready_o             : out std_logic;
        daq_data_o          : out std_logic_vector(7 downto 0);
        daq_data_en_o       : out std_logic;
        daq_crc_error_o     : out std_logic;
        daq_event_done_o    : out std_logic;
        slow_ctrl_data_o    : out std_logic;
        slow_ctrl_data_en_o : out std_logic;

        -- counters
        cnt_events_o        : out std_logic_vector(7 downto 0);
        cnt_crc_errors_o    : out std_logic_vector(7 downto 0)
        
    );
end vfat3_rx_link;

architecture vfat3_rx_link_arch of vfat3_rx_link is

    component crc_vfat3_daq
--        generic(
--            CRC_WIDTH  => 16,
--            DATA_WIDTH => 8,
--            INIT_VAL   => x"ffff",
--            POLY       => x"1021"
--        )
        port (
            clk           : in std_logic;
            reset         : in std_logic;
            ReSync        : in std_logic;
            SLEEP         : in std_logic;
            Data_in       : in std_logic_vector(7 downto 0);
            Init_in       : in std_logic;
            Data_valid_in : in std_logic;
            CRC_out       : out std_logic_vector(15 downto 0);
            CRC_ok_out    : out std_logic
        );
    end component;

    constant VFAT3_SC0_WORD         : std_logic_vector(7 downto 0) := x"96";
    constant VFAT3_SC1_WORD         : std_logic_vector(7 downto 0) := x"99";

    constant VFAT3_DAQ_HEADER_I     : std_logic_vector(7 downto 0) := x"1e";
    constant VFAT3_DAQ_HEADER_IW    : std_logic_vector(7 downto 0) := x"5e";

    -- hardcoded fixed length of the default non-zero-suppressed DAQ packet
    -- TODO: make this configurable with registers (should come from higher level)
    -- TODO: support also zero suppressed packets
    constant VFAT3_DAQ_PACKET_WORDS : unsigned(4 downto 0) := "1" & x"5";

    constant TIED_TO_GND        : std_logic := '0';

    signal daq_data_en          : std_logic := '0';
    signal daq_word_cntdown     : unsigned(4 downto 0) := (others => '0');
    signal event_done           : std_logic := '0';
    
    signal crc_init             : std_logic := '1';
    signal crc_ok               : std_logic;
    
    signal cnt_events           : unsigned(7 downto 0) := (others => '0');
    signal cnt_crc_errors       : unsigned(7 downto 0) := (others => '0');
    
begin
    
    --======== Wiring ========--
    
    ready_o <= sync_ok_i and not reset_i;

    daq_data_en <= '1' when ((daq_word_cntdown /= "00000") or (data_i = VFAT3_DAQ_HEADER_I) or (data_i = VFAT3_DAQ_HEADER_IW)) else '0';
    daq_data_o <= data_i; -- when daq_data_en = '1' else (others => '0');
    daq_data_en_o <= daq_data_en and not mask_i;
    daq_crc_error_o <= event_done and not crc_ok;
    daq_event_done_o <= event_done;
    slow_ctrl_data_o <= '1' when data_i = VFAT3_SC1_WORD else '0';
    slow_ctrl_data_en_o <= '1' when (data_i = VFAT3_SC1_WORD or data_i = VFAT3_SC0_WORD) and (daq_data_en = '0') and (mask_i = '0') else '0';

    cnt_events_o <= std_logic_vector(cnt_events);
    cnt_crc_errors_o  <= std_logic_vector(cnt_crc_errors);

    --======== DAQ ========--
    
    process (ttc_clk_i.clk_40)
    begin
        if (rising_edge(ttc_clk_i.clk_40)) then
            if (reset_i = '1' or mask_i = '1') then
                daq_word_cntdown <= (others => '0');
                event_done <= '0';
                crc_init <= '1';
            else
                if (daq_word_cntdown = "00000") and ((data_i = VFAT3_DAQ_HEADER_I) or (data_i = VFAT3_DAQ_HEADER_IW)) then
                    daq_word_cntdown <= VFAT3_DAQ_PACKET_WORDS;
                    crc_init <= '0';
                end if;
                
                if (daq_word_cntdown /= "00000") then
                    daq_word_cntdown <= daq_word_cntdown - 1;
                end if;
                
                if (daq_word_cntdown = "00001") then
                    event_done <= '1';
                    crc_init <= '1';
                else 
                    event_done <= '0';
                end if;
                
            end if;
        end if;
    end process;

    i_crc : component crc_vfat3_daq
--        generic map(
--            CRC_WIDTH  => 16,
--            DATA_WIDTH => 8,
--            INIT_VAL   => x"ffff",
--            POLY       => x"1021"
--        )
        port map(
            clk           => ttc_clk_i.clk_40,
            reset         => reset_i,
            ReSync        => TIED_TO_GND,
            SLEEP         => TIED_TO_GND,
            Data_in       => data_i,
            Init_in       => crc_init,
            Data_valid_in => daq_data_en,
            CRC_out       => open,
            CRC_ok_out    => crc_ok
        );
        
    --======== Counters ========--
    
    process(ttc_clk_i.clk_40)
    begin
        if (rising_edge(ttc_clk_i.clk_40)) then
            if (reset_i = '1') then
                cnt_events <= (others => '0');
                cnt_crc_errors <= (others => '0');
            else
                if (event_done = '1') then
                    cnt_events <= cnt_events + 1;
                end if;

                if (event_done = '1' and crc_ok = '0') then
                    cnt_crc_errors <= cnt_crc_errors + 1;
                end if;                
            end if;
        end if;
    end process;
       
end vfat3_rx_link_arch;
