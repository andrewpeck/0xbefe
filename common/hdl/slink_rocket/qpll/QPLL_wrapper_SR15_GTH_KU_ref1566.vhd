----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11.03.2019 17:11:11
-- Design Name: 
-- Module Name: QPLL_wrapper - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity QPLL_wrapper_SR15_GTH_KU_ref1566 is
 Port ( 
	gtrefclk00_in		: in std_logic;
	gtrefclk01_in       : in std_logic;
	qpll0reset_in       : in std_logic;
	qpll1reset_in       : in std_logic;
	                      
	qpll0lock_out       : out std_logic;
	qpll0outclk_out     : out std_logic;
	qpll0outrefclk_out  : out std_logic;
	                      
	qpll1lock_out       : out std_logic;
	qpll1outclk_out     : out std_logic;
	qpll1outrefclk_out  : out std_logic
 );
end QPLL_wrapper_SR15_GTH_KU_ref1566;

architecture Behavioral of QPLL_wrapper_SR15_GTH_KU_ref1566 is


component SR15_qpll_wrapper_gthe3_KU_REF1566 is
	Port (
		GTHE3_COMMON_BGBYPASSB		  		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_BGMONITORENB     		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_BGPDB            		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_BGRCALOVRD       		: in std_logic_vector(4 downto 0);
		GTHE3_COMMON_BGRCALOVRDENB    		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_DRPADDR          		: in std_logic_vector(8 downto 0);
		GTHE3_COMMON_DRPCLK           		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_DRPDI            		: in std_logic_vector(15 downto 0);
		GTHE3_COMMON_DRPEN            		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_DRPWE            		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_GTGREFCLK0       		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_GTGREFCLK1       		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_GTNORTHREFCLK00  		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_GTNORTHREFCLK01  		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_GTNORTHREFCLK10  		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_GTNORTHREFCLK11  		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_GTREFCLK00       		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_GTREFCLK01       		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_GTREFCLK10       		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_GTREFCLK11       		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_GTSOUTHREFCLK00  		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_GTSOUTHREFCLK01  		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_GTSOUTHREFCLK10  		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_GTSOUTHREFCLK11  		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_PMARSVD0         		: in std_logic_vector(7 downto 0);
		GTHE3_COMMON_PMARSVD1         		: in std_logic_vector(7 downto 0);
		GTHE3_COMMON_QPLL0CLKRSVD0    		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_QPLL0CLKRSVD1    		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_QPLL0LOCKDETCLK  		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_QPLL0LOCKEN      		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_QPLL0PD          		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_QPLL0REFCLKSEL   		: in std_logic_vector(2 downto 0);
		GTHE3_COMMON_QPLL0RESET       		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_QPLL1CLKRSVD0    		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_QPLL1CLKRSVD1    		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_QPLL1LOCKDETCLK  		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_QPLL1LOCKEN      		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_QPLL1PD          		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_QPLL1REFCLKSEL   		: in std_logic_vector(2 downto 0);
		GTHE3_COMMON_QPLL1RESET       		: in std_logic_vector(0 downto 0);
		GTHE3_COMMON_QPLLRSVD1        		: in std_logic_vector(7 downto 0);
		GTHE3_COMMON_QPLLRSVD2        		: in std_logic_vector(4 downto 0);
		GTHE3_COMMON_QPLLRSVD3        		: in std_logic_vector(4 downto 0);
		GTHE3_COMMON_QPLLRSVD4        		: in std_logic_vector(7 downto 0);
		GTHE3_COMMON_RCALENB          		: in std_logic_vector(0 downto 0);
											
		GTHE3_COMMON_DRPDO            		: out std_logic_vector(15 downto 0);
		GTHE3_COMMON_DRPRDY           		: out std_logic_vector(0 downto 0);
		GTHE3_COMMON_PMARSVDOUT0      		: out std_logic_vector(7 downto 0);
		GTHE3_COMMON_PMARSVDOUT1      		: out std_logic_vector(7 downto 0);
		GTHE3_COMMON_QPLL0FBCLKLOST   		: out std_logic_vector(0 downto 0);
		GTHE3_COMMON_QPLL0LOCK        		: out std_logic_vector(0 downto 0);
		GTHE3_COMMON_QPLL0OUTCLK      		: out std_logic_vector(0 downto 0);
		GTHE3_COMMON_QPLL0OUTREFCLK   		: out std_logic_vector(0 downto 0);
		GTHE3_COMMON_QPLL0REFCLKLOST  		: out std_logic_vector(0 downto 0);
		GTHE3_COMMON_QPLL1FBCLKLOST   		: out std_logic_vector(0 downto 0);
		GTHE3_COMMON_QPLL1LOCK        		: out std_logic_vector(0 downto 0);
		GTHE3_COMMON_QPLL1OUTCLK      		: out std_logic_vector(0 downto 0);
		GTHE3_COMMON_QPLL1OUTREFCLK   		: out std_logic_vector(0 downto 0);
		GTHE3_COMMON_QPLL1REFCLKLOST  		: out std_logic_vector(0 downto 0);
		GTHE3_COMMON_QPLLDMONITOR0    		: out std_logic_vector(7 downto 0);
		GTHE3_COMMON_QPLLDMONITOR1    		: out std_logic_vector(7 downto 0);
		GTHE3_COMMON_REFCLKOUTMONITOR0		: out std_logic_vector(0 downto 0);
		GTHE3_COMMON_REFCLKOUTMONITOR1		: out std_logic_vector(0 downto 0);
		GTHE3_COMMON_RXRECCLK0_SEL    		: out std_logic_vector(1 downto 0);
		GTHE3_COMMON_RXRECCLK1_SEL			: out std_logic_vector(1 downto 0) 
);
end component;

--#############################################################################
-- Code start here
--#############################################################################
begin

qpll_inst:SR15_qpll_wrapper_gthe3_KU_REF1566 
	Port Map(
		GTHE3_COMMON_BGBYPASSB		  		=> "1"          ,
		GTHE3_COMMON_BGMONITORENB     		=> "1"          ,
		GTHE3_COMMON_BGPDB            		=> "1"          ,
		GTHE3_COMMON_BGRCALOVRD       		=> "11111"      ,
		GTHE3_COMMON_BGRCALOVRDENB    		=> "1"          ,
		GTHE3_COMMON_DRPADDR          		=> "000000000"  ,
		GTHE3_COMMON_DRPCLK           		=> "0"          ,
		GTHE3_COMMON_DRPDI            		=> x"0000"      ,
		GTHE3_COMMON_DRPEN            		=> "0"          ,
		GTHE3_COMMON_DRPWE            		=> "0"          ,
		GTHE3_COMMON_GTGREFCLK0       		=> "0"          ,
		GTHE3_COMMON_GTGREFCLK1       		=> "0"          ,
		GTHE3_COMMON_GTNORTHREFCLK00  		=> "0"          ,
		GTHE3_COMMON_GTNORTHREFCLK01  		=> "0"          ,
		GTHE3_COMMON_GTNORTHREFCLK10  		=> "0"          ,
		GTHE3_COMMON_GTNORTHREFCLK11  		=> "0"          ,
		GTHE3_COMMON_GTREFCLK00(0)     		=> gtrefclk00_in,
		GTHE3_COMMON_GTREFCLK01(0)     		=> gtrefclk01_in,
		GTHE3_COMMON_GTREFCLK10       		=> "0"          ,
		GTHE3_COMMON_GTREFCLK11       		=> "0"          ,
		GTHE3_COMMON_GTSOUTHREFCLK00  		=> "0"          ,
		GTHE3_COMMON_GTSOUTHREFCLK01  		=> "0"          ,
		GTHE3_COMMON_GTSOUTHREFCLK10  		=> "0"          ,
		GTHE3_COMMON_GTSOUTHREFCLK11  		=> "0"          ,
		GTHE3_COMMON_PMARSVD0         		=> x"00"        ,
		GTHE3_COMMON_PMARSVD1         		=> x"00"        ,
		GTHE3_COMMON_QPLL0CLKRSVD0    		=> "0"          ,
		GTHE3_COMMON_QPLL0CLKRSVD1    		=> "0"          ,
		GTHE3_COMMON_QPLL0LOCKDETCLK  		=> "0"          ,
		GTHE3_COMMON_QPLL0LOCKEN      		=> "1"          ,
		GTHE3_COMMON_QPLL0PD          		=> "0"          ,
		GTHE3_COMMON_QPLL0REFCLKSEL   		=> "001"        ,
		GTHE3_COMMON_QPLL0RESET(0)     		=> qpll0reset_in,
		GTHE3_COMMON_QPLL1CLKRSVD0    		=> "0"          ,
		GTHE3_COMMON_QPLL1CLKRSVD1    		=> "0"          ,
		GTHE3_COMMON_QPLL1LOCKDETCLK  		=> "0"          ,
		GTHE3_COMMON_QPLL1LOCKEN      		=> "0"          ,
		GTHE3_COMMON_QPLL1PD          		=> "1"          ,
		GTHE3_COMMON_QPLL1REFCLKSEL   		=> "001"        ,
		GTHE3_COMMON_QPLL1RESET(0)     		=> qpll1reset_in,
		GTHE3_COMMON_QPLLRSVD1        		=> x"00"        ,
		GTHE3_COMMON_QPLLRSVD2        		=> "00000"      ,
		GTHE3_COMMON_QPLLRSVD3        		=> "00000"      ,
		GTHE3_COMMON_QPLLRSVD4        		=> x"00"        ,
		GTHE3_COMMON_RCALENB          		=> "1"          ,
											
		-- GTHE3_COMMON_DRPDO            		=> ,
		-- GTHE3_COMMON_DRPRDY           		=> ,
		-- GTHE3_COMMON_PMARSVDOUT0      		=> ,
		-- GTHE3_COMMON_PMARSVDOUT1      		=> ,
		-- GTHE3_COMMON_QPLL0FBCLKLOST   		=> ,
		GTHE3_COMMON_QPLL0LOCK(0)   		=> qpll0lock_out,
		GTHE3_COMMON_QPLL0OUTCLK(0)   		=> qpll0outclk_out,
		GTHE3_COMMON_QPLL0OUTREFCLK(0) 		=> qpll0outrefclk_out,
		-- GTHE3_COMMON_QPLL0REFCLKLOST  		=> , 
		-- GTHE3_COMMON_QPLL1FBCLKLOST   		=> , 
		GTHE3_COMMON_QPLL1LOCK(0)     		=> qpll1lock_out,
		GTHE3_COMMON_QPLL1OUTCLK(0)    		=> qpll1outclk_out,
		GTHE3_COMMON_QPLL1OUTREFCLK(0) 		=> qpll1outrefclk_out
		-- GTHE3_COMMON_QPLL1REFCLKLOST  		=> ,
		-- GTHE3_COMMON_QPLLDMONITOR0    		=> ,
		-- GTHE3_COMMON_QPLLDMONITOR1    		=> ,
		-- GTHE3_COMMON_REFCLKOUTMONITOR0		=> ,
		-- GTHE3_COMMON_REFCLKOUTMONITOR1		=> ,
		-- GTHE3_COMMON_RXRECCLK0_SEL    		=> ,
		-- GTHE3_COMMON_RXRECCLK1_SEL			=> ,
);

end Behavioral;
