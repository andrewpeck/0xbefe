----------------------------------------------------------------------------------
-- Company:        IIHE - ULB
-- Engineer:       Thomas Lenzi (thomas.lenzi@cern.ch)
-- 
-- Create Date:    15:17:59 07/09/2015 
-- Design Name:    OptoHybrid v2
-- Module Name:    counter - Behavioral 
-- Project Name:
-- Target Devices: xc6vlx130t-1ff1156
-- Tool versions:  ISE  P.20131013
-- Description: 
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

entity counter is
    generic(
        g_COUNTER_WIDTH     : integer := 32;
        g_ALLOW_ROLLOVER    : boolean := false;
        g_INCREMENT_STEP    : integer := 1;
        g_INPUT_REG_STAGES  : integer := 0;
        g_INCLUDE_CDC       : boolean := false -- if set to true, the output data will be transfered to the optionally provided output_clk_i domain using a gray coding CDC (output clk should be faster than the input)
    );
    port(
        ref_clk_i       : in  std_logic;
        reset_i         : in  std_logic;
        en_i            : in  std_logic;
        count_o         : out std_logic_vector(g_COUNTER_WIDTH - 1 downto 0);
        output_clk_i    : in  std_logic := '0'
    );
end counter;

architecture counter_arch of counter is

    constant max_count : unsigned(g_COUNTER_WIDTH - 1 downto 0) := (others => '1');
    
    signal en       : std_logic := '0';
    signal reset    : std_logic := '0';        
    signal count    : unsigned(g_COUNTER_WIDTH - 1 downto 0);

begin

    i_en_pipe : entity work.pipe generic map(WIDTH => 1, DEPTH => g_INPUT_REG_STAGES) port map(clk_i => ref_clk_i, data_i(0) => en_i, data_o(0) => en);
    i_reset_pipe : entity work.pipe generic map(WIDTH => 1, DEPTH => g_INPUT_REG_STAGES) port map(clk_i => ref_clk_i, data_i(0) => reset_i, data_o(0) => reset);

    process(ref_clk_i)
    begin
        if rising_edge(ref_clk_i) then
            if reset = '1' then
                count <= (others => '0');
            else
                if en = '1' and (count /= max_count or g_ALLOW_ROLLOVER) then
                    count <= count + g_INCREMENT_STEP;
                end if;
            end if;
        end if;
    end process;

    g_output_reg_no_cdc : if not g_INCLUDE_CDC generate
        
        process(ref_clk_i)
        begin
            if rising_edge(ref_clk_i) then
                if reset = '1' then
                    count_o <= (others => '0');
                else
                    count_o <= std_logic_vector(count);
                end if;
            end if;
        end process;
        
    end generate;

    g_output_cdc : if g_INCLUDE_CDC generate
        
        i_output_cdc : xpm_cdc_gray
            generic map(
                DEST_SYNC_FF          => 4,
                REG_OUTPUT            => 1,
                WIDTH                 => g_COUNTER_WIDTH
            )
            port map(
                src_clk      => ref_clk_i,
                src_in_bin   => std_logic_vector(count),
                dest_clk     => output_clk_i,
                dest_out_bin => count_o
            );
        
    end generate;

end counter_arch;