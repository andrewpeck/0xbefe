------------------------------------------------------
-- Component FIFO
--
--  Ver 1.00
--
-- Dominique Gigi May 2015
------------------------------------------------------
--   This file contain un instatiation of a FIFO (ALTERA  or XILINX)
--  with he almost FUll signal 
--   
--  
------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 

entity FIFO_sync is
generic (	fifo_deep : integer := 6
	);
port 
	(
		resetp		: in std_logic; -- active high
		clk_w		: in std_logic;
		wen			: in std_logic;
		dataw		: in std_logic_vector(129 downto 0);
		almost_f	: out std_logic;	-- active low
		clk_r		: in std_logic;
		datar		: out std_logic_vector(129 downto 0);
		ren			: in std_logic;
		empty		: out std_logic  -- active low
	);
end FIFO_sync;

architecture behavioral of FIFO_sync is



--***********************************************************
--**********************  XILINX DC FIFO  *******************
--***********************************************************

 
COMPONENT SR_FIFO_sender      
  PORT (
    rst           : IN STD_LOGIC;
    wr_clk        : IN STD_LOGIC;
    rd_clk        : IN STD_LOGIC;
    din           : IN STD_LOGIC_VECTOR(129 DOWNTO 0);
    wr_en         : IN STD_LOGIC;
    rd_en         : IN STD_LOGIC;
    dout          : OUT STD_LOGIC_VECTOR(129 DOWNTO 0);
    full          : OUT STD_LOGIC;
    empty         : OUT STD_LOGIC;
    wr_data_count : OUT STD_LOGIC_VECTOR(5 DOWNTO 0)
  );
END COMPONENT;

COMPONENT resetp_resync is
port (
	aresetp				: in std_logic;
	clock				: in std_logic; 

	Resetp_sync			: out std_logic
	);
END COMPONENT ;



signal resetp_resync_clk_w		: std_logic; 

signal almost_full_reg			: std_logic; 
signal word_used				: std_logic_vector(5 downto 0);


--***********************************************************
--**********************  BEGIN  ****************************
--***********************************************************
begin 

--resync Reset to clock write
resync_rst:resetp_resync  
port map(
	aresetp				=> resetp,
	clock				=> clk_w,
						 
	Resetp_sync			=> resetp_resync_clk_w 
	);




 -- !!!!!!!!!!!!!!!  XILINX ISE and Vivado VERSION  !!!!!!!!!!!!!
fifo_dc : SR_FIFO_sender 
  PORT MAP (
    rst           => resetp,
    wr_clk        => clk_w,
    din           => dataw,	 
    wr_en         => wen,	 
    wr_data_count => word_used,	 
    rd_clk        => clk_r,
    rd_en         => ren,
    dout          => datar,
  -- full         => full,
    empty         => empty
  );

process(resetp_resync_clk_w,clk_w)
begin
	if resetp_resync_clk_w = '1' then
		almost_full_reg 		<= '0';
	elsif rising_edge(clk_w) then
		if 		word_used >= "110000" then  --enable almostFull when reaches   48 data in FIFO of 64
			almost_full_reg 	<= '1';
		elsif	word_used < "100101" then -- realize almostFull below 37 data in FIFO of 64
			almost_full_reg 	<= '0';
		end if;
	end if;
end process;

almost_f <= almost_full_reg;

end behavioral;