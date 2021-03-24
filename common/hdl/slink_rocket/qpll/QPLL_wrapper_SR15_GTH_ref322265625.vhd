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

entity QPLL_wrapper_SR15_GTH_ref322265625 is
 Port ( 
	gtrefclk00_in		: in std_logic;
	gtrefclk01_in       : in std_logic;
	qpll0reset_in       : in std_logic;
	qpll1reset_in       : in std_logic;
	                      
	qpll0lock_out	    : out std_logic;
	qpll0outclk_out     : out std_logic;
	qpll0outrefclk_out  : out std_logic;
	                      
	qpll1lock_out       : out std_logic;
	qpll1outclk_out     : out std_logic;
	qpll1outrefclk_out  : out std_logic
 );
end QPLL_wrapper_SR15_GTH_ref322265625;

architecture Behavioral of QPLL_wrapper_SR15_GTH_ref322265625 is


component SR15_qpll_wrapper_gthe4_REF322265625 is
	Port (
		GTHE4_COMMON_BGBYPASSB        	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_BGMONITORENB     	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_BGPDB            	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_BGRCALOVRD       	: in std_logic_vector(4 downto 0) ;
		GTHE4_COMMON_BGRCALOVRDENB    	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_DRPADDR          	: in std_logic_vector(15 downto 0);
		GTHE4_COMMON_DRPCLK           	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_DRPDI            	: in std_logic_vector(15 downto 0);
		GTHE4_COMMON_DRPEN            	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_DRPWE            	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_GTGREFCLK0       	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_GTGREFCLK1       	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_GTNORTHREFCLK00  	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_GTNORTHREFCLK01  	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_GTNORTHREFCLK10  	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_GTNORTHREFCLK11  	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_GTREFCLK00       	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_GTREFCLK01       	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_GTREFCLK10       	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_GTREFCLK11       	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_GTSOUTHREFCLK00  	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_GTSOUTHREFCLK01  	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_GTSOUTHREFCLK10  	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_GTSOUTHREFCLK11  	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_PCIERATEQPLL0    	: in std_logic_vector(2 downto 0) ;
		GTHE4_COMMON_PCIERATEQPLL1    	: in std_logic_vector(2 downto 0) ;
		GTHE4_COMMON_PMARSVD0         	: in std_logic_vector(7 downto 0) ;
		GTHE4_COMMON_PMARSVD1         	: in std_logic_vector(7 downto 0) ;
		GTHE4_COMMON_QPLL0CLKRSVD0    	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_QPLL0CLKRSVD1    	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_QPLL0FBDIV       	: in std_logic_vector(7 downto 0) ;
		GTHE4_COMMON_QPLL0LOCKDETCLK  	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_QPLL0LOCKEN      	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_QPLL0PD          	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_QPLL0REFCLKSEL   	: in std_logic_vector(2 downto 0) ;
		GTHE4_COMMON_QPLL0RESET       	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_QPLL1CLKRSVD0    	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_QPLL1CLKRSVD1    	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_QPLL1FBDIV       	: in std_logic_vector(7 downto 0) ;
		GTHE4_COMMON_QPLL1LOCKDETCLK  	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_QPLL1LOCKEN      	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_QPLL1PD          	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_QPLL1REFCLKSEL   	: in std_logic_vector(2 downto 0) ;
		GTHE4_COMMON_QPLL1RESET       	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_QPLLRSVD1        	: in std_logic_vector(7 downto 0) ;
		GTHE4_COMMON_QPLLRSVD2        	: in std_logic_vector(4 downto 0) ;
		GTHE4_COMMON_QPLLRSVD3        	: in std_logic_vector(4 downto 0) ;
		GTHE4_COMMON_QPLLRSVD4        	: in std_logic_vector(7 downto 0) ;
		GTHE4_COMMON_RCALENB          	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_SDM0DATA         	: in std_logic_vector(24 downto 0);
		GTHE4_COMMON_SDM0RESET        	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_SDM0TOGGLE       	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_SDM0WIDTH        	: in std_logic_vector(1 downto 0) ;
		GTHE4_COMMON_SDM1DATA         	: in std_logic_vector(24 downto 0);
		GTHE4_COMMON_SDM1RESET        	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_SDM1TOGGLE       	: in std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_SDM1WIDTH        	: in std_logic_vector(1 downto 0) ; 
		GTHE4_COMMON_TCONGPI    		: in std_logic_vector(9 downto 0);
		GTHE4_COMMON_TCONPOWERUP		: in std_logic_vector(0 downto 0);
		GTHE4_COMMON_TCONRESET  		: in std_logic_vector(1 downto 0);
		GTHE4_COMMON_TCONRSVDIN1		: in std_logic_vector(1 downto 0);		 
										
		GTHE4_COMMON_DRPDO            	: out std_logic_vector(15 downto 0);
		GTHE4_COMMON_DRPRDY           	: out std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_PMARSVDOUT0      	: out std_logic_vector(7 downto 0) ;
		GTHE4_COMMON_PMARSVDOUT1      	: out std_logic_vector(7 downto 0) ;
		GTHE4_COMMON_QPLL0FBCLKLOST   	: out std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_QPLL0LOCK        	: out std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_QPLL0OUTCLK      	: out std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_QPLL0OUTREFCLK   	: out std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_QPLL0REFCLKLOST  	: out std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_QPLL1FBCLKLOST   	: out std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_QPLL1LOCK        	: out std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_QPLL1OUTCLK      	: out std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_QPLL1OUTREFCLK   	: out std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_QPLL1REFCLKLOST  	: out std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_QPLLDMONITOR0    	: out std_logic_vector(7 downto 0) ;
		GTHE4_COMMON_QPLLDMONITOR1    	: out std_logic_vector(7 downto 0) ;
		GTHE4_COMMON_REFCLKOUTMONITOR0	: out std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_REFCLKOUTMONITOR1	: out std_logic_vector(0 downto 0) ;
		GTHE4_COMMON_RXRECCLK0SEL     	: out std_logic_vector(1 downto 0) ;
		GTHE4_COMMON_RXRECCLK1SEL     	: out std_logic_vector(1 downto 0) ;
		GTHE4_COMMON_SDM0FINALOUT     	: out std_logic_vector(3 downto 0) ;
		GTHE4_COMMON_SDM0TESTDATA     	: out std_logic_vector(14 downto 0);
		GTHE4_COMMON_SDM1FINALOUT     	: out std_logic_vector(3 downto 0) ;
		GTHE4_COMMON_SDM1TESTDATA     	: out std_logic_vector(14 downto 0);		
		GTHE4_COMMON_TCONGPO			: out std_logic_vector(9 downto 0) ;
		GTHE4_COMMON_TCONRSVDOUT0   	: out std_logic_vector(0 downto 0)
);
end component;

--#############################################################################
-- Code start here
--#############################################################################
begin

qpll_inst:SR15_qpll_wrapper_gthe4_REF322265625  
	Port Map(
		GTHE4_COMMON_BGBYPASSB        		=> "1",
		GTHE4_COMMON_BGMONITORENB     		=> "1",
		GTHE4_COMMON_BGPDB            		=> "1",
		GTHE4_COMMON_BGRCALOVRD       		=> "11111",
		GTHE4_COMMON_BGRCALOVRDENB    		=> "1",
		GTHE4_COMMON_DRPADDR          		=> x"0000",
		GTHE4_COMMON_DRPCLK           		=> "0",
		GTHE4_COMMON_DRPDI            		=> x"0000",
		GTHE4_COMMON_DRPEN            		=> "0",
		GTHE4_COMMON_DRPWE            		=> "0",
		GTHE4_COMMON_GTGREFCLK0       		=> "0",
		GTHE4_COMMON_GTGREFCLK1       		=> "0",
		GTHE4_COMMON_GTNORTHREFCLK00  		=> "0",
		GTHE4_COMMON_GTNORTHREFCLK01  		=> "0",
		GTHE4_COMMON_GTNORTHREFCLK10  		=> "0",
		GTHE4_COMMON_GTNORTHREFCLK11  		=> "0",
		GTHE4_COMMON_GTREFCLK00(0)     		=> gtrefclk00_in,
		GTHE4_COMMON_GTREFCLK01(0)    		=> gtrefclk01_in,
		GTHE4_COMMON_GTREFCLK10       		=> "0",
		GTHE4_COMMON_GTREFCLK11       		=> "0",
		GTHE4_COMMON_GTSOUTHREFCLK00  		=> "0",
		GTHE4_COMMON_GTSOUTHREFCLK01  		=> "0",
		GTHE4_COMMON_GTSOUTHREFCLK10  		=> "0",
		GTHE4_COMMON_GTSOUTHREFCLK11  		=> "0",
		GTHE4_COMMON_PCIERATEQPLL0    		=> "000",
		GTHE4_COMMON_PCIERATEQPLL1    		=> "000",
		GTHE4_COMMON_PMARSVD0         		=> x"00",
		GTHE4_COMMON_PMARSVD1         		=> x"00",
		GTHE4_COMMON_QPLL0CLKRSVD0    		=> "0",
		GTHE4_COMMON_QPLL0CLKRSVD1    		=> "0",
		GTHE4_COMMON_QPLL0FBDIV       		=> x"00",
		GTHE4_COMMON_QPLL0LOCKDETCLK  		=> "0",
		GTHE4_COMMON_QPLL0LOCKEN      		=> "1",
		GTHE4_COMMON_QPLL0PD          		=> "0",
		GTHE4_COMMON_QPLL0REFCLKSEL   		=> "001",
		GTHE4_COMMON_QPLL0RESET(0)    		=> qpll0reset_in,
		GTHE4_COMMON_QPLL1CLKRSVD0    		=> "0",
		GTHE4_COMMON_QPLL1CLKRSVD1    		=> "0",
		GTHE4_COMMON_QPLL1FBDIV       		=> x"00",
		GTHE4_COMMON_QPLL1LOCKDETCLK  		=> "0",
		GTHE4_COMMON_QPLL1LOCKEN      		=> "0",
		GTHE4_COMMON_QPLL1PD          		=> "1",
		GTHE4_COMMON_QPLL1REFCLKSEL   		=> "001",
		GTHE4_COMMON_QPLL1RESET(0)   		=> qpll1reset_in,
		GTHE4_COMMON_QPLLRSVD1        		=> x"00",
		GTHE4_COMMON_QPLLRSVD2        		=> "00000",
		GTHE4_COMMON_QPLLRSVD3        		=> "00000",
		GTHE4_COMMON_QPLLRSVD4        		=> x"00",
		GTHE4_COMMON_RCALENB          		=> "1",
		GTHE4_COMMON_SDM0DATA         		=> "0110010001100000011101111",
		GTHE4_COMMON_SDM0RESET        		=> "0",
		GTHE4_COMMON_SDM0TOGGLE       		=> "0",
		GTHE4_COMMON_SDM0WIDTH        		=> "00",
		GTHE4_COMMON_SDM1DATA         		=> "0000000000000000000000000",
		GTHE4_COMMON_SDM1RESET        		=> "0",
		GTHE4_COMMON_SDM1TOGGLE       		=> "0",
		GTHE4_COMMON_SDM1WIDTH        		=> "00",
		GTHE4_COMMON_TCONGPI    			=> "0000000000",
		GTHE4_COMMON_TCONPOWERUP			=> "0",
		GTHE4_COMMON_TCONRESET  			=> "00",
		GTHE4_COMMON_TCONRSVDIN1			=> "00",
											 
		-- GTHE4_COMMON_DRPDO            		=> ,
		-- GTHE4_COMMON_DRPRDY           		=> ,
		-- GTHE4_COMMON_PMARSVDOUT0      		=> ,
		-- GTHE4_COMMON_PMARSVDOUT1      		=> ,
		-- GTHE4_COMMON_QPLL0FBCLKLOST   		=> ,
		GTHE4_COMMON_QPLL0LOCK(0)      		=> qpll0lock_out,
		GTHE4_COMMON_QPLL0OUTCLK(0)   		=> qpll0outclk_out,
		GTHE4_COMMON_QPLL0OUTREFCLK(0) 		=> qpll0outrefclk_out,
		-- GTHE4_COMMON_QPLL0REFCLKLOST  		=> ,
		-- GTHE4_COMMON_QPLL1FBCLKLOST   		=> ,
		GTHE4_COMMON_QPLL1LOCK(0)     		=> qpll1lock_out,
		GTHE4_COMMON_QPLL1OUTCLK(0)   		=> qpll1outclk_out,
		GTHE4_COMMON_QPLL1OUTREFCLK(0) 		=> qpll1outrefclk_out 
		-- GTHE4_COMMON_QPLL1REFCLKLOST  		=> ,
		-- GTHE4_COMMON_QPLLDMONITOR0    		=> ,
		-- GTHE4_COMMON_QPLLDMONITOR1    		=> ,
		-- GTHE4_COMMON_REFCLKOUTMONITOR0		=> ,
		-- GTHE4_COMMON_REFCLKOUTMONITOR1		=> ,
		-- GTHE4_COMMON_RXRECCLK0SEL     		=> ,
		-- GTHE4_COMMON_RXRECCLK1SEL     		=> ,
		-- GTHE4_COMMON_SDM0FINALOUT     		=> ,
		-- GTHE4_COMMON_SDM0TESTDATA     		=> ,
		-- GTHE4_COMMON_SDM1FINALOUT     		=> ,
		-- GTHE4_COMMON_SDM1TESTDATA     		=> , 
		-- GTHE4_COMMON_TCONGPO					=> ,
		-- GTHE4_COMMON_TCONRSVDOUT0   			=> 
);

end Behavioral;
