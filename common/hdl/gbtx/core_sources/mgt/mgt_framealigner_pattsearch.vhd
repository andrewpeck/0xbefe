-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - MGT Frame aligner
-------------------------------------------------------

--! IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Custom libraries and packages:
use work.gbt_bank_package.all; 
use work.vendor_specific_gbt_bank_package.all;

--! @brief MGT_framealigner_pattsearch - MGT Frame Aligner
--! @details 
--! The MGT_framealigner_pattsearch module aligns the RX word in order to get the header on the first
--! bits of the word.
entity mgt_framealigner_pattsearch is
   port ( 

		--===========--
		-- Clocks    --
		--===========--
		RX_WORDCLK_I			: in  std_logic;
		
		--===========--
		-- Resets    --
		--===========--
		RX_RESET_I				: in  std_logic;
		
		--===========--
		-- Control   --
		--===========--
		RX_BITSLIP_CMD_O		: out std_logic;
		MGT_BITSLIPDONE_i    : in  std_logic;
		
		--============--
		-- Data       --
		--============--
		RX_WORD_I				: in  std_logic_vector(WORD_WIDTH-1 downto 0);
		
		--============--
		-- Status     --
		--============--
		RX_BITSLIPISEVEN_o   : out std_logic;
		RX_HEADER_LOCKED_O	: out std_logic;
		RX_HEADER_FLAG_O		: out std_logic	
   );  
end mgt_framealigner_pattsearch;

--! @brief MGT_framealigner_pattsearch - MGT Frame Aligner
--! @details 
--! The MGT_framealigner_pattsearch checks wether the header is aligned or not. When the header
--! is not aligned, the frame aligner request a bitslip and restart the checking procedure. Upon
--! a fixed number of good header, the state machine goes to the locked state.
architecture behavioral of mgt_framealigner_pattsearch is
  
   --================================ Signal Declarations ================================--	
	type machine is (UNLOCKED, GOING_LOCK, LOCKED, GOING_UNLOCK);
	signal state   : machine;
	
	signal psAddress			: integer range 0 to GBT_WORD_RATIO;
	signal shiftPsAddr		    : std_logic;
	signal bitSlipCmd 		    : std_logic;
	signal headerFlag_s		    : std_logic;
	signal RX_HEADER_LOCKED_s   : std_logic;
	signal RX_BITSLIPISEVEN_s   : std_logic;
	
	constant DATA_HEADER_PATTERN_REVERSED        : std_logic_vector(3 downto 0) := DATA_HEADER_PATTERN(0) &
                                                                                  DATA_HEADER_PATTERN(1) &
                                                                                  DATA_HEADER_PATTERN(2) &
                                                                                  DATA_HEADER_PATTERN(3); 
	
	constant IDLE_HEADER_PATTERN_REVERSED        : std_logic_vector(3 downto 0) := IDLE_HEADER_PATTERN(0) &
                                                                                  IDLE_HEADER_PATTERN(1) &
                                                                                  IDLE_HEADER_PATTERN(2) &
                                                                                  IDLE_HEADER_PATTERN(3); 
--=================================================================================================--
begin                 --========####   Architecture Body   ####========-- 
--=================================================================================================--     
   
   --==================================== User Logic =====================================--

	-- Pattern searcher: control the MGT bitslip
   patternSearch_proc: process(RX_RESET_I, RX_WORDCLK_I)
	begin
	
		if RX_RESET_I = '1' then
			bitSlipCmd <= '0';
			
		elsif rising_edge(RX_WORDCLK_I) then
		
			bitSlipCmd <= '0';
			
			if state = UNLOCKED and psAddress = 0 and MGT_BITSLIPDONE_i = '1' then
				
				if (RX_WORD_I(3 downto 0) /= DATA_HEADER_PATTERN_REVERSED) and (RX_WORD_I(3 downto 0) /= IDLE_HEADER_PATTERN_REVERSED) then
					bitSlipCmd <= '1';
					
				end if;
				
			end if;
			
		end if;
		
	end process;
		
	-- Pattern address controller
	patternSearchAddr_proc: process(RX_RESET_I, RX_WORDCLK_I)
	begin
	
		if RX_RESET_I = '1' then
			psAddress 		<= 0;
			headerFlag_s	<= '0';
			
		elsif rising_edge(RX_WORDCLK_I) then
		
			headerFlag_s 	<= '0';
			
			if psAddress = 0 then
				headerFlag_s <= '1';
			end if;
			
			if shiftPsAddr = '0' then
				psAddress <= psAddress + 1;
				
				if psAddress = GBT_WORD_RATIO-1 then
					psAddress <= 0;
				end if;
				
			end if;
			
		end if;
		
	end process;
	
	-- BitSlip counter
	bitSlipCnter_proc: process(RX_RESET_I, RX_WORDCLK_I)
	    variable bitSlipCnt       : integer range 0 to GBTRX_BITSLIP_NBR_MAX;
	begin
	
		if RX_RESET_I = '1' then
			shiftPsAddr		<= '0';
			bitSlipCnt 		:= 0;
			RX_BITSLIPISEVEN_s <= '1';
			
		elsif rising_edge(RX_WORDCLK_I) then
		
			shiftPsAddr		<= '0';
			
			if bitSlipCmd = '1' then
						
				if bitSlipCnt = GBTRX_BITSLIP_NBR_MAX-1 then
					bitSlipCnt 		:= 0;
					shiftPsAddr		<= '1';
				else
					bitSlipCnt := bitSlipCnt + 1;
				end if;
				
				RX_BITSLIPISEVEN_s <= not(RX_BITSLIPISEVEN_s);
				
			end if;
		end if;
	end process;
	
	RX_BITSLIPISEVEN_o <= RX_BITSLIPISEVEN_s;
	
	-- Locking state machine
	lockFSM_proc: process(RX_RESET_I, RX_WORDCLK_I)
		variable consecFalseHeaders		: integer range 0 to NBR_ACCEPTED_FALSE_HEADER+1;
		variable consecCorrectHeaders		: integer range 0 to DESIRED_CONSEC_CORRECT_HEADERS+1;
		variable nbCheckedHeaders       : integer range 0 to NBR_CHECKED_HEADER;
		
	begin
		if RX_RESET_I = '1' then
			state		<= UNLOCKED;
			
		elsif rising_edge(RX_WORDCLK_I) then
		
			if psAddress = 0 then
				case state is
					
					when UNLOCKED 		=> if (RX_WORD_I(3 downto 0) = DATA_HEADER_PATTERN_REVERSED) or (RX_WORD_I(3 downto 0) = IDLE_HEADER_PATTERN_REVERSED) then
													state <= GOING_LOCK;
													consecCorrectHeaders := 0;
												end if;
					
					when GOING_LOCK	=> if (RX_WORD_I(3 downto 0) /= DATA_HEADER_PATTERN_REVERSED) and (RX_WORD_I(3 downto 0) /= IDLE_HEADER_PATTERN_REVERSED) then
													state <= UNLOCKED;
													
												else
													consecCorrectHeaders := consecCorrectHeaders + 1;
													
													if consecCorrectHeaders >= DESIRED_CONSEC_CORRECT_HEADERS then
														state <= LOCKED;
													end if;
												end if;
					
					when LOCKED			=>	if (RX_WORD_I(3 downto 0) /= DATA_HEADER_PATTERN_REVERSED) and (RX_WORD_I(3 downto 0) /= IDLE_HEADER_PATTERN_REVERSED) then
													consecFalseHeaders := 0;
													nbCheckedHeaders   := 0;
													state <= GOING_UNLOCK;
												end if;
					
					when GOING_UNLOCK	=>  if (RX_WORD_I(3 downto 0) = DATA_HEADER_PATTERN_REVERSED) or (RX_WORD_I(3 downto 0) = IDLE_HEADER_PATTERN_REVERSED) then
											
												if nbCheckedHeaders = NBR_CHECKED_HEADER then
											       state <= LOCKED;
												else
													nbCheckedHeaders := nbCheckedHeaders + 1;
												end if;
												
										    else
													
												consecFalseHeaders := consecFalseHeaders + 1;
													
												if consecFalseHeaders >= NBR_ACCEPTED_FALSE_HEADER then
													state <= UNLOCKED;
												end if;
											end if;
					
				end case;
			end if;
		end if;
	end process;

	RX_BITSLIP_CMD_O		<= bitSlipCmd;
	
	RX_HEADER_LOCKED_s	<= '1' when (state = LOCKED or state = GOING_UNLOCK) else '0';
	RX_HEADER_FLAG_O		<= headerFlag_s when state = LOCKED else '0';
    
    -- Glitch protection (Header_Locked signal)
    glitchProt_process: process(RX_RESET_I, RX_WORDCLK_I)
    begin
    
        if RX_RESET_I = '1' then
            RX_HEADER_LOCKED_o     <= '0';
            
        elsif rising_edge(RX_WORDCLK_I) then
            RX_HEADER_LOCKED_o     <= RX_HEADER_LOCKED_s;
        
        end if;
        
    end process;
    
   --=====================================================================================--      
end behavioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--