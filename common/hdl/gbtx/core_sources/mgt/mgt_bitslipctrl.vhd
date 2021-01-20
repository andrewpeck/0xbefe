-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - MGT BitSlip controller
-------------------------------------------------------

--! IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Custom libraries and packages:
use work.vendor_specific_gbt_bank_package.all;

--! @brief MGT_latopt_bitslipctrl - BitSlip controller
--! @details 
--! The MGT_latopt_bitslipctrl controls the transceiver's bitslip input in order to shift
--! the Rx clock and data.
entity mgt_bitslipctrl is
   port (   
      
		--============--
		-- Resets     --
		--============--
		RX_RESET_I			: in  std_logic;
		
		--============--
		-- Clocks     --
		--============--
		RX_WORDCLK_I		: in  std_logic;
		MGT_CLK_I         : in  std_logic;
		
		--============--
		-- Control    --
		--============--
		RX_BITSLIPCMD_i	: in  std_logic;
		RX_BITSLIPCMD_o	: out std_logic;
		
		RX_HEADERLOCKED_i : in  std_logic;
		RX_BITSLIPISEVEN_i: in  std_logic;
		RX_RSTONBITSLIP_o : out std_logic;
		RX_ENRST_i        : in  std_logic;
		RX_RSTONEVEN_i    : in  std_logic;
		
		--============--
		-- Status     --
		--============--
		DONE_o				: out std_logic;
		READY_o				: out std_logic
					
   );
end mgt_bitslipctrl;

--! @brief MGT_latopt_bitslipctrl - BitSlip controller
--! @details The MGT_latopt_bitslipctrl controls the bitslip using a state machine that asserts the
--! command and wait for a specified time before releasing the busy flag.
architecture structural of mgt_bitslipctrl is
  
	type rxBitSlipCtrlStateLatOpt_T is (e0_idle, e4_doBitslip, e5_waitNcycles);
		
	signal bitSlitRst			: std_logic;
	signal bitSlitRst_sync 	: std_logic;
	
--=================================================================================================--
begin                 --========####   Architecture Body   ####========-- 
--=================================================================================================--
   
   --============================ User Logic =============================--		
	clkSlipProcess: process(RX_RESET_I, RX_WORDCLK_I)
		variable state                            : rxBitSlipCtrlStateLatOpt_T;
		variable timer                            : integer range 0 to GBTRX_BITSLIP_MIN_DLY;
	begin
	
		if RX_RESET_I = '1' then
			state 		:= e0_idle;
			RX_BITSLIPCMD_o 	<= '0';
			READY_o		<= '0';
			
		elsif rising_edge(RX_WORDCLK_I) then
			case state is
			
				when e0_idle =>				READY_o		<= '1';
				
													if RX_BITSLIPCMD_i = '1' then
														state 	:= e4_doBitslip;
														timer    := 0;
														READY_o	<= '0';
													end if;
				
				when e4_doBitslip =>			RX_BITSLIPCMD_o <= '1';
				                           if timer >= GBTRX_BITSLIP_MIN_DLY-1 then
													    state := e5_waitNcycles;
													    timer := 0;
													else
														timer := timer + 1;
													end if;
				
				when e5_waitNcycles =>		RX_BITSLIPCMD_o <= '0';
													if timer >= GBTRX_BITSLIP_MIN_DLY-1 then
														state := e0_idle;
													else
														timer := timer + 1;
													end if;

			end case;
		end if;
		
	end process;
	
	rstOnBitSlip_process: process(RX_RESET_I, MGT_CLK_I)
	begin
	
		if RX_RESET_I = '1' then
			RX_RSTONBITSLIP_o <= '0';
			DONE_o <= '0';
			
		elsif rising_edge(MGT_CLK_I) then
		
			RX_RSTONBITSLIP_o <= '0';
			
			if RX_ENRST_i = '0' then
			   DONE_o <= RX_HEADERLOCKED_i;
				
			elsif RX_ENRST_i = '1' and RX_BITSLIPISEVEN_i = RX_RSTONEVEN_i and RX_HEADERLOCKED_i = '1' then
				DONE_o <= '0';
				RX_RSTONBITSLIP_o <= '1';
			
			elsif RX_ENRST_i = '1' and RX_BITSLIPISEVEN_i /= RX_RSTONEVEN_i and RX_HEADERLOCKED_i = '1'  then
				DONE_o <= '1';
				
			else
				DONE_o <= RX_HEADERLOCKED_i;
			
			end if;
			
		end if;
	end process;
   --=====================================================================--   
end structural;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--