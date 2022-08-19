------------------------------------------------------
-- Frequency Clock detection
--
--  Ver 1.00
--
-- Dominique Gigi Jan 2015
------------------------------------------------------
--   Measure the clock frequency used by FED
--  
-- 
--  
------------------------------------------------------
LIBRARY ieee;
library work;

USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all; 
 

entity freq_measure is
generic (throughput		: string := "15.66");
port (
	resetn				: in std_logic;
	
	sysclk				: in std_logic;-- clock used by the FED to send data and to measure the backpressure
	base_clk			: in std_logic;-- clock base used to measure the sysclk
	
	frequency			: out std_logic_vector(31 downto 0)-- measure of the frequency)
);
end freq_measure;

architecture behavioral of freq_measure is


component resetn_resync is
port (
	aresetn				: in std_logic;
	clock				: in std_logic; 

	Resetn_sync			: out std_logic
	);
end component;


signal counter_base			: std_logic_vector(31 downto 0);
signal counter_measure		: std_logic_vector(31 downto 0);
signal measure				: std_logic_vector(31 downto 0);
signal latch_value			: std_logic;
signal reset_cnt			: std_logic;
signal reset_cnt_rsyc		: std_logic;

signal freq_used			: std_logic_vector(31 downto 0);
--*********************************************************
--************         CODE START HERE     ****************
--*********************************************************
begin

	-- this constant is defined to have 1 ms with a 195.3125 Mhz               25.78125 GB/s  128b
	-- constant freq_used: std_logic_vector(31 downto 0) := x"0002FAF0"; 
	-- this constant is defined to have 1 ms with a 118.6363 Mhz				15.66 Gb/s  128b
	-- constant freq_used: std_logic_vector(31 downto 0) := x"0001CF6C"; 
freq_used	<=x"0001CF6C" when throughput = "15.66" else x"0002FAF0";

-- counter base
process(base_clk)
begin
	if rising_edge(base_clk) then
		-- check in versioning file to know with freq base is used
		latch_value			<= '0';
		if counter_base = freq_used then 
			counter_base 	<= (others => '0');
			latch_value		<= '1';
		else
			counter_base 	<= counter_base + '1';
		end if;
	end if;
end process;


-- counter measure
process(sysclk,reset_cnt_rsyc)
begin
	if reset_cnt_rsyc = '0' then
		counter_measure <= (others => '0');
	elsif rising_edge(sysclk) then
		counter_measure <= counter_measure + '1';
	end if;
end process;	

resync_rst_i1:resetn_resync
port map(
	aresetn				=> reset_cnt,
	clock				=> sysclk, 
	Resetn_sync			=> reset_cnt_rsyc
	);
	
-- latch the frequency
process(base_clk)
begin
	if rising_edge(base_clk) then
		reset_cnt		<= '1'; -- reset the counter measure when the measure is latched
		if latch_value = '1' then
			measure		<= counter_measure;
			reset_cnt	<= '0';
		end if;
	end if;
end process;
	
frequency	<= measure;
	
end behavioral;



