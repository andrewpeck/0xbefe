-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Tx gearbox (Latency-optimized)
-------------------------------------------------------

-- IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Custom libraries and packages:
use work.vendor_specific_gbt_bank_package.all;
use work.gbt_bank_package.all;

--! @brief GBT_tx_gearbox_latopt - Tx gearbox (Latency-optimized)
--! @details 
--! The GBT_tx_gearbox_latopt module ensure the frameclock to transceiver's wordclock
--! clock domain crossing with fixed and low latency.
entity gbt_tx_gearbox_latopt is
   port (
  
      --================--
      -- Reset & Clocks --
      --================--    
      
      -- Reset:
      ---------
      
      TX_RESET_I                                : in  std_logic;
  
      -- Clocks:
      ----------
      
      TX_WORDCLK_I                              : in  std_logic;
      TX_FRAMECLK_I                             : in  std_logic;
      TX_CLKEN_i                                : in  std_logic;
      
		--=========--
		-- Status  --
		--=========--
		TX_GEARBOX_READY_O								: out std_logic;
		TX_PHALIGNED_O										: out std_logic;
		TX_PHCOMPUTED_O									: out std_logic;
		
      --==============--
      -- Frame & Word --
      --==============--
      
      TX_FRAME_I                                : in  std_logic_vector(119 downto 0);
      TX_WORD_O                                 : out std_logic_vector(WORD_WIDTH-1 downto 0)
   
   );
end gbt_tx_gearbox_latopt;

--! @brief GBT_tx_gearbox_latopt - Tx gearbox (Standard - Read/Write control)
--! @details The GBT_tx_gearbox_latopt uses a single register to ensure the clock domain crossing
--! The reset signal is used to synchronize the counter with the rising edge of the frameclock. It
--! also implements a process to check the clock phase and the data integrety.
architecture behavioral of gbt_tx_gearbox_latopt is

   --================================ Signal Declarations ================================--

   signal txFrame_from_frameInverter            : std_logic_vector (119 downto 0);
   signal txFrame_from_frameInverter_reg        : std_logic_vector (119 downto 0);
      
   signal txMgtReady_r2                         : std_logic;  
   signal txMgtReady_r                          : std_logic;  
   signal gearboxSyncReset                      : std_logic;  
  
	--Monitoring
	signal txFrame_from_frameInverter_for_mon		: std_logic_vector (WORD_WIDTH-1 downto 0);
	signal txFrame_built_from_word					: std_logic_vector (119 downto 0);
		
	signal TX_PHALIGNED_s							: std_logic;
	signal TX_PHCOMPUTED_s							: std_logic;
		
   --=====================================================================================--  

--=================================================================================================--
begin                 --========####   Architecture Body   ####========-- 
--=================================================================================================--  
   
   --==================================== User Logic =====================================--   
   
   --==============--
   -- Common logic --
   --==============--
   gbt_gb_phasemon_inst: entity work.gbt_tx_gearbox_phasemon
    Generic map(
		TX_OPTIMIZATION	 => LATENCY_OPTIMIZED
	)
	Port map(
		-- RESET
		RESET_I			=> TX_RESET_I,
		CLK				=> TX_WORDCLK_I,
		
		-- MONITORING
		PHCOMPUTED_I	=> TX_PHCOMPUTED_s,
		PHALIGNED_I		=> TX_PHALIGNED_s,
		
		-- OUTPUT
		GOOD_O			=> TX_PHALIGNED_O,
		DONE_O			=> TX_PHCOMPUTED_O
	);
	
   -- Comment: Bits are inverted to transmit the MSB first on the MGT.
   
   frameInverter: for i in 119 downto 0 generate
      txFrame_from_frameInverter(i)             <= TX_FRAME_I(119-i);
   end generate;

	
   -- Comment: Note!! The reset of the gearbox is synchronous to TX_FRAMECLK in order to align the address 0 
   --                 of the gearbox with the rising edge of TX_FRAMECLK after reset.   
	TX_GEARBOX_READY_O	<= not(TX_RESET_I);
	
   -- Sync reset
   gbRstSynch_proc: process(TX_RESET_I, TX_FRAMECLK_I)
   begin
   
       if TX_RESET_I = '1' then
           gearboxSyncReset  <= '1';
           
       elsif rising_edge(TX_FRAMECLK_I) then
       
        if TX_CLKEN_i = '1' then
           gearboxSyncReset <= '0';
        end if;
           
       end if;
   
   end process;
   
   --=====================--
   -- Word width (20 Bit) --
   --=====================--
   
   gbLatOpt20b_gen: if WORD_WIDTH = 20 generate   	
		
      gbLatOpt20b: process(gearboxSyncReset, TX_WORDCLK_I)
         variable address                       : integer range 0 to 5;
      begin
         if gearboxSyncReset = '1' then
            TX_WORD_O                           <= (others => '0');
            address                             := 0;
				TX_PHCOMPUTED_s							<= '0';
				TX_PHALIGNED_s 							<= '0';
				
         elsif rising_edge(TX_WORDCLK_I) then
            case address is
               when 0 =>
                  TX_WORD_O                      <= txFrame_from_frameInverter( 19 downto   0);
						txFrame_from_frameInverter_reg <= txFrame_from_frameInverter;
						
                  address                       := 1;
						--
						TX_PHCOMPUTED_s	<= '0';
						
               when 1 => 
                  TX_WORD_O                     <= txFrame_from_frameInverter_reg( 39 downto  20);
                  address                       := 2;
												
               when 2 =>                 
                  TX_WORD_O                     <= txFrame_from_frameInverter_reg( 59 downto  40);
                  address                       := 3;
						
               when 3 =>                 
                  TX_WORD_O                     <= txFrame_from_frameInverter_reg( 79 downto  60);
                  address                       := 4;
						
               when 4 =>                 
                  TX_WORD_O                     <= txFrame_from_frameInverter_reg( 99 downto  80);
                  address                       := 5;
						
						
               when 5 =>                 
                  TX_WORD_O                     <= txFrame_from_frameInverter_reg(119 downto 100);
                  address                       := 0;
						
						TX_PHCOMPUTED_s	<= '1';
						--
						if (txFrame_from_frameInverter(119 downto 100) = txFrame_from_frameInverter_reg(119 downto 100)) then
							TX_PHALIGNED_s <= '1';
						else
							TX_PHALIGNED_s <= '0';
						end if;
						
               when others =>
                  null;
            end case;
         end if;
      end process;

   end generate;  
  
   --=====================--
   -- Word width (40 Bit) --
   --=====================--   
   gbLatOpt40b_gen: if WORD_WIDTH = 40 generate   

      gbLatOpt40b: process(gearboxSyncReset, TX_WORDCLK_I)
         variable address                       : integer range 0 to 2;
      begin
         if gearboxSyncReset = '1' then
            TX_WORD_O                           <= (others => '0');
            address                             := 0;
				TX_PHCOMPUTED_s							<= '0';
				TX_PHALIGNED_s 							<= '0';
				
         elsif rising_edge(TX_WORDCLK_I) then
            case address is
               when 0 =>					
                  TX_WORD_O                     		   <= txFrame_from_frameInverter( 39 downto   0);
						txFrame_from_frameInverter_reg         <= txFrame_from_frameInverter;	
						-- Monitoring
						TX_PHCOMPUTED_s	<= '0';
						
						-- Control
                  address                       		 := 1;
						
               when 1 => 
                  TX_WORD_O                     <= txFrame_from_frameInverter_reg( 79 downto  40);
						
						-- Control
                  address                       :=2;
						
               when 2 =>                 
                  TX_WORD_O                     <= txFrame_from_frameInverter_reg(119 downto  80);
                  address                       := 0;
						
						TX_PHCOMPUTED_s	<= '1';
						
						if (txFrame_from_frameInverter(119 downto 80) = txFrame_from_frameInverter_reg(119 downto 80)) then
							TX_PHALIGNED_s <= '1';
						else
							TX_PHALIGNED_s <= '0';
						end if;
						
               when others =>
                  null;
            end case;
         end if;
      end process;

   end generate;  
   
   --=====================================================================================--
end behavioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--