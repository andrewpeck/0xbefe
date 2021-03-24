----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 20.11.2017 10:42:34
-- Design Name: 
-- Module Name: Serdes_wrapper_selection
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: This file select the serder in function of GTY GTH  and reference clok
-- 		
-- 		
-- 		
-- 		
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
library IEEE;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
  

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;
 
entity QPLL_wrapper_select is
 Generic ( 	 throughput								: string := "15.66";
				--possible choices are  15.66 or 25.78125
		ref_clock								     : string := "156.25";
				--possible choices are  156.25  or   322.265625 
			technology								: string := "GTY"
				-- possible choices are GTY or GTH or GTH_KU
				);
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
end QPLL_wrapper_select;

--*///////////////////////////////////////////////////////////////////////////////
--*////////////////////////   Behavioral        //////////////////////////////////
--*///////////////////////////////////////////////////////////////////////////////
architecture Behavioral of QPLL_wrapper_select is
	
component QPLL_wrapper_SR15_GTH_KU_ref1566 is
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
end component;
	
component QPLL_wrapper_SR25_GTY_ref15625 is
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
end component;
	
component QPLL_wrapper_SR25_GTY_ref322265625 is
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
end component;
	
component QPLL_wrapper_SR15_GTH_ref15625 is
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
end component;
	
component QPLL_wrapper_SR15_GTH_ref322265625 is
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
end component;
	
component QPLL_wrapper_SR15_GTY_ref15625 is
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
end component;
	
component QPLL_wrapper_SR15_GTY_ref322265625 is
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
end component;


--#############################################################################
-- Code start here
--#############################################################################
begin


--***********************************************************************************************
--
--			GTH Kintex Ultrascale 15.66 Gb/s    156.6 MHz
--
QPLL_16G_156_GTH_KU:if throughput = "15.66"  and technology = "GTH_KU" generate
	i1:QPLL_wrapper_SR15_GTH_KU_ref1566  
		 Port Map( 
			gtrefclk00_in		=> gtrefclk00_in		,
			gtrefclk01_in       => gtrefclk01_in       ,
			qpll0reset_in       => qpll0reset_in       ,
			qpll1reset_in       => qpll1reset_in       ,
			qpll0lock_out        => qpll0lock_out        ,
			qpll0outclk_out     => qpll0outclk_out     ,
			qpll0outrefclk_out  => qpll0outrefclk_out  , 
			qpll1lock_out        => qpll1lock_out        ,
			qpll1outclk_out     => qpll1outclk_out     ,
			qpll1outrefclk_out  => qpll1outrefclk_out  
	);
end generate;	


--***********************************************************************************************
--
--			GTH Ultrascale+ 15.66 Gb/s    156.25 MHz
--
QPLL_16G_156_GTH:if throughput = "15.66"  and ref_clock = "156.25" and technology = "GTH" generate
	i1:QPLL_wrapper_SR15_GTH_ref15625  
		 Port Map( 
			gtrefclk00_in		=> gtrefclk00_in		,
			gtrefclk01_in       => gtrefclk01_in       ,
			qpll0reset_in       => qpll0reset_in       ,
			qpll1reset_in       => qpll1reset_in       ,
			qpll0lock_out        => qpll0lock_out        ,
			qpll0outclk_out     => qpll0outclk_out     ,
			qpll0outrefclk_out  => qpll0outrefclk_out  , 
			qpll1lock_out        => qpll1lock_out        ,
			qpll1outclk_out     => qpll1outclk_out     ,
			qpll1outrefclk_out  => qpll1outrefclk_out  
	);
end generate;	

--***********************************************************************************************
--
--			GTH Ultrascale+ 15.66 Gb/s    322.265625 MHz
--
QPLL_16G_322_GTH:if throughput = "15.66"  and ref_clock = "322.265625" and technology = "GTH" generate
	i2:QPLL_wrapper_SR15_GTH_ref322265625  
		 Port Map( 
			gtrefclk00_in		=> gtrefclk00_in		,
			gtrefclk01_in       => gtrefclk01_in       ,
			qpll0reset_in       => qpll0reset_in       ,
			qpll1reset_in       => qpll1reset_in       ,
			qpll0lock_out        => qpll0lock_out        ,
			qpll0outclk_out     => qpll0outclk_out     ,
			qpll0outrefclk_out  => qpll0outrefclk_out  , 
			qpll1lock_out        => qpll1lock_out        ,
			qpll1outclk_out     => qpll1outclk_out     ,
			qpll1outrefclk_out  => qpll1outrefclk_out  
	);
end generate;	

--***********************************************************************************************
--
--			GTY Ultrascale+ 15.66 Gb/s    156.25 MHz
--
QPLL_16G_156_GTY:if throughput = "15.66"  and ref_clock = "156.25" and technology = "GTY" generate
	i3:QPLL_wrapper_SR15_GTY_ref15625  
		 Port Map( 
			gtrefclk00_in		=> gtrefclk00_in		,
			gtrefclk01_in       => gtrefclk01_in       ,
			qpll0reset_in       => qpll0reset_in       ,
			qpll1reset_in       => qpll1reset_in       ,
			qpll0lock_out        => qpll0lock_out        ,
			qpll0outclk_out     => qpll0outclk_out     ,
			qpll0outrefclk_out  => qpll0outrefclk_out  , 
			qpll1lock_out        => qpll1lock_out        ,
			qpll1outclk_out     => qpll1outclk_out     ,
			qpll1outrefclk_out  => qpll1outrefclk_out  
	);
end generate;	

--***********************************************************************************************
--
--			GTY Ultrascale+ 15.66 Gb/s    322.265625 MHz
--
QPLL_16G_322_GTY:if throughput = "15.66"  and ref_clock = "322.265625" and technology = "GTY" generate
	i4:QPLL_wrapper_SR15_GTY_ref322265625  
		 Port Map( 
			gtrefclk00_in		=> gtrefclk00_in		,
			gtrefclk01_in       => gtrefclk01_in       ,
			qpll0reset_in       => qpll0reset_in       ,
			qpll1reset_in       => qpll1reset_in       ,
			qpll0lock_out        => qpll0lock_out        ,
			qpll0outclk_out     => qpll0outclk_out     ,
			qpll0outrefclk_out  => qpll0outrefclk_out  , 
			qpll1lock_out        => qpll1lock_out        ,
			qpll1outclk_out     => qpll1outclk_out     ,
			qpll1outrefclk_out  => qpll1outrefclk_out  
	);
end generate;	

--***********************************************************************************************
--
--			GTY Ultrascale+ 25.78125 Gb/s    156.25 MHz
--
QPLL_25G_156_GTY:if throughput = "25.78125"  and ref_clock = "156.25" and technology = "GTY" generate
	i5:QPLL_wrapper_SR25_GTY_ref15625  
		 Port Map( 
			gtrefclk00_in		=> gtrefclk00_in		,
			gtrefclk01_in       => gtrefclk01_in       ,
			qpll0reset_in       => qpll0reset_in       ,
			qpll1reset_in       => qpll1reset_in       ,
			qpll0lock_out        => qpll0lock_out        ,
			qpll0outclk_out     => qpll0outclk_out     ,
			qpll0outrefclk_out  => qpll0outrefclk_out  , 
			qpll1lock_out        => qpll1lock_out        ,
			qpll1outclk_out     => qpll1outclk_out     ,
			qpll1outrefclk_out  => qpll1outrefclk_out  
	);
end generate;	

--***********************************************************************************************
--
--			GTY Ultrascale+ 25.78125 Gb/s    322.265625 MHz
--
QPLL_25G_322_GTY:if throughput = "25.78125"  and ref_clock = "322.265625" and technology = "GTY" generate
	i6:QPLL_wrapper_SR25_GTY_ref322265625  
		 Port Map( 
			gtrefclk00_in		=> gtrefclk00_in		,
			gtrefclk01_in       => gtrefclk01_in       ,
			qpll0reset_in       => qpll0reset_in       ,
			qpll1reset_in       => qpll1reset_in       ,
			qpll0lock_out        => qpll0lock_out        ,
			qpll0outclk_out     => qpll0outclk_out     ,
			qpll0outrefclk_out  => qpll0outrefclk_out  , 
			qpll1lock_out        => qpll1lock_out        ,
			qpll1outclk_out     => qpll1outclk_out     ,
			qpll1outrefclk_out  => qpll1outrefclk_out  
	);
end generate;	
	
end Behavioral;