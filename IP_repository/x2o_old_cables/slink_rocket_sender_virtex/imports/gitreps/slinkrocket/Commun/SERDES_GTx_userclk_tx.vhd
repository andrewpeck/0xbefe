----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10.11.2017 11:32:58
-- Design Name: 
-- Module Name: SR_xxgtx_serdes_tx_clk - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;
use IEEE.std_logic_signed.all;
use IEEE.std_logic_unsigned.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity SERDES_GTx_userclk_tx is
	 generic(
		P_CONTENTS                     		: integer:= 0;
		P_FREQ_RATIO_SOURCE_TO_USRCLK  		: integer:= 1;
		P_FREQ_RATIO_USRCLK_TO_USRCLK2 		: integer:= 2
	 );
	 Port ( 
		gtwiz_userclk_tx_srcclk_in  		: in  std_logic;	
		gtwiz_userclk_tx_reset_in   		: in  std_logic;	
		gtwiz_userclk_tx_usrclk_out 		: out std_logic;	
		gtwiz_userclk_tx_usrclk2_out		: out std_logic;	
		gtwiz_userclk_tx_usrclk4_out		: out std_logic;	
		gtwiz_userclk_tx_active_out			: out std_logic 
 );
end SERDES_GTx_userclk_tx;

--///////////////////////// Architecture \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
architecture Behavioral of SERDES_GTx_userclk_tx is

  --Convert integer parameters with known, limited legal range to a 3-bit local parameter values
	signal P_USRCLK_INT_DIV  				: integer							:= P_FREQ_RATIO_SOURCE_TO_USRCLK - 1;
	signal P_USRCLK_DIV      				: std_logic_vector(2 downto 0);
	signal P_USRCLK2_INT_DIV 				: integer							:= (P_FREQ_RATIO_SOURCE_TO_USRCLK * P_FREQ_RATIO_USRCLK_TO_USRCLK2) - 1;
	signal P_USRCLK2_DIV     				: std_logic_vector(2 downto 0);
	signal P_USRCLK4_INT_DIV 				: integer							:= (P_FREQ_RATIO_SOURCE_TO_USRCLK * P_FREQ_RATIO_USRCLK_TO_USRCLK2 *2) - 1;
	signal P_USRCLK4_DIV     				: std_logic_vector(2 downto 0);

	signal gtwiz_userclk_tx_usrclk_cell		: std_logic;
	signal gtwiz_userclk_tx_usrclk2_cell	: std_logic;
	signal gtwiz_userclk_tx_usrclk4_cell	: std_logic;
	signal gtwiz_userclk_tx_active_meta		: std_logic;
	signal gtwiz_userclk_tx_active_sync 	: std_logic;

--#############################################################################
-- Code start here
--#############################################################################
begin

P_USRCLK_DIV		<= STD_LOGIC_VECTOR(TO_UNSIGNED(P_USRCLK_INT_DIV,3));
P_USRCLK2_DIV		<= STD_LOGIC_VECTOR(TO_UNSIGNED(P_USRCLK2_INT_DIV,3));
P_USRCLK4_DIV       <= STD_LOGIC_VECTOR(TO_UNSIGNED(P_USRCLK4_INT_DIV,3));

BUFG_GT_inst0 : BUFG_GT 
	port map (
		O       		=> gtwiz_userclk_tx_usrclk_cell, -- 1-bit output: Buffer
		CE      		=> '1',                         -- 1-bit input: Buffer enable
		CEMASK  		=> '0',                         -- 1-bit input: CE Mask
		CLR     		=> gtwiz_userclk_tx_reset_in,   -- 1-bit input: Asynchronous clear 
		CLRMASK 		=> '0',                         -- 1-bit input: CLR Mask
		DIV     		=> P_USRCLK_DIV,                -- 3-bit input: Dymanic divide Value 
		I       		=> gtwiz_userclk_tx_srcclk_in   -- 1-bit input: Buffer
);

gtwiz_userclk_tx_usrclk_out		<= gtwiz_userclk_tx_usrclk_cell;

  -- If TXUSRCLK and TXUSRCLK2 frequencies are identical, drive both from the same BUFG_GT. Otherwise, drive
  -- TXUSRCLK2 from a second BUFG_GT instance, dividing the source clock down to the TXUSRCLK2 frequency.
BUFG_GT_inst1 : BUFG_GT 
	port map (
		O       		=> gtwiz_userclk_tx_usrclk2_cell, -- 1-bit output: Buffer
		CE      		=> '1',                         -- 1-bit input: Buffer enable
		CEMASK  		=> '0',                         -- 1-bit input: CE Mask
		CLR     		=> gtwiz_userclk_tx_reset_in,   -- 1-bit input: Asynchronous clear 
		CLRMASK 		=> '0',                         -- 1-bit input: CLR Mask
		DIV     		=> P_USRCLK2_DIV,                -- 3-bit input: Dymanic divide Value 
		I       		=> gtwiz_userclk_tx_srcclk_in   -- 1-bit input: Buffer
);

gtwiz_userclk_tx_usrclk2_out		<= gtwiz_userclk_tx_usrclk2_cell;

  -- create a clock /2 to convert 64bit bus to 128 bit bus
  -- TXUSRCLK2 from a second BUFG_GT instance, dividing the source clock down to the TXUSRCLK2 frequency.
BUFG_GT_inst2 : BUFG_GT 
	port map (
		O       		=> gtwiz_userclk_tx_usrclk4_cell, -- 1-bit output: Buffer
		CE      		=> '1',                         -- 1-bit input: Buffer enable
		CEMASK  		=> '0',                         -- 1-bit input: CE Mask
		CLR     		=> gtwiz_userclk_tx_reset_in,   -- 1-bit input: Asynchronous clear 
		CLRMASK 		=> '0',                         -- 1-bit input: CLR Mask
		DIV     		=> P_USRCLK4_DIV,                -- 3-bit input: Dymanic divide Value 
		I       		=> gtwiz_userclk_tx_srcclk_in   -- 1-bit input: Buffer
);

gtwiz_userclk_tx_usrclk4_out		<= gtwiz_userclk_tx_usrclk4_cell;

-- Indicate active helper block functionality when the BUFG_GT divider is not held in reset
process(gtwiz_userclk_tx_reset_in,gtwiz_userclk_tx_usrclk2_cell)
begin
	if gtwiz_userclk_tx_reset_in = '1' then
		gtwiz_userclk_tx_active_meta <= '0';
		gtwiz_userclk_tx_active_sync <= '0';
	elsif rising_edge(gtwiz_userclk_tx_usrclk2_cell) then
		gtwiz_userclk_tx_active_meta <= '1';
		gtwiz_userclk_tx_active_sync <= gtwiz_userclk_tx_active_meta;
	end if;
end process;

gtwiz_userclk_tx_active_out <= gtwiz_userclk_tx_active_sync;

end Behavioral;
