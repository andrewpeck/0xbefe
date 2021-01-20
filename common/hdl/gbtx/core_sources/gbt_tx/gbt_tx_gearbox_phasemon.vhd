-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Tx gearbox phase checker (Latency-optimized)
-------------------------------------------------------

--! IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Custom libraries and packages:
use work.gbt_bank_package.all;
use work.vendor_specific_gbt_bank_package.all;

--! @brief gbt_tx_gearbox_phasemon - Tx gearbox phase checker (Latency-optimized)
--! @details 
--! The gbt_tx_gearbox_phasemon module analyzes the phaligned and phcomputed flags from the 
--! gearbox to generate the status.
entity gbt_tx_gearbox_phasemon is
    Generic(
		TX_OPTIMIZATION									: integer range 0 to 1 := STANDARD );
	Port (
		-- RESET
		RESET_I			: in  std_logic;
		CLK				: in  std_logic;
		
		-- MONITORING
		PHCOMPUTED_I	: in  std_logic;
		PHALIGNED_I		: in  std_logic;
		
		-- OUTPUT
		GOOD_O			: out std_logic;
		DONE_O			: out std_logic
	);
end gbt_tx_gearbox_phasemon;


--! @brief gbt_tx_gearbox_phasemon - Tx gearbox phase checker (Latency-optimized)
--! @details 
--! The gbt_tx_gearbox_phasemon performs statistic analyzes to provide the alignment
--! status.
architecture Behavioral of gbt_tx_gearbox_phasemon is
	
	signal matching_founded:				integer;	
	constant STAT_CSTE:						integer := 50;
	
begin

    latOptFlag_gen: if TX_OPTIMIZATION = LATENCY_OPTIMIZED generate
        main_fsm_proc: process(RESET_I, CLK)
        begin
        
            if (RESET_I = '1') then
                GOOD_O <= '0';
                DONE_O <= '0';			
                matching_founded <= 0;
                
            elsif rising_edge(CLK) then
            
                if (PHCOMPUTED_I = '1' and PHALIGNED_I = '1') then
                    matching_founded <= matching_founded+1;
                    
                    if(matching_founded >= STAT_CSTE) then
                        DONE_O <= '1';
                        GOOD_O <= '1';
                    end if;
                    
                elsif(PHCOMPUTED_I = '1' and PHALIGNED_I = '0') then
                    DONE_O <= '1';
                    GOOD_O <= '0';
                    matching_founded <= 0;
                end if;			
                
            end if;
        end process;
	end generate;
	
	stdFlagGen: if TX_OPTIMIZATION = STANDARD generate
        DONE_O <= '1';
        GOOD_O <= '1';
    end generate;
	   
end Behavioral;