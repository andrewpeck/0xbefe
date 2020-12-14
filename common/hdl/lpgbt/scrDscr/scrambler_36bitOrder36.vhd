-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 1.0
--! @brief 36bit Order 36 scrambler
-------------------------------------------------------

--! Include the IEEE VHDL standard library
library ieee;
use ieee.std_logic_1164.all;

--! Include the LpGBT-FPGA specific package
use work.lpgbtfpga_package.all;

--! @brief scrambler36bitOrder36 - 36bit Order 36 scrambler
ENTITY scrambler36bitOrder36 IS
   GENERIC (
        INIT_SEED                        : in std_logic_vector(35 downto 0)    := x"1fba847af"
   );
   PORT (
        -- Clocks & reset
        clk_i                             : in  std_logic;
        clkEn_i                           : in  std_logic;
        
        reset_i                           : in  std_logic;
        
        -- Data
        data_i                            : in  std_logic_vector(35 downto 0);
        data_o                            : out std_logic_vector(35 downto 0);
        
        -- Control
        bypass                            : in  std_logic        
   );   
END scrambler36bitOrder36;

--! @brief scrambler36bitOrder36 architecture - 36bit Order 36 scrambler
ARCHITECTURE behabioral of scrambler36bitOrder36 IS

    signal scrambledData        : std_logic_vector(35 downto 0);
    
BEGIN                 --========####   Architecture Body   ####========-- 
        
    -- Scrambler output register
    reg_proc: process(clk_i, reset_i)
    begin
    
        if rising_edge(clk_i) then
            if reset_i = '1' then
                scrambledData    <= INIT_SEED;
                
            elsif clkEn_i = '1' then
                scrambledData(35 downto 25) <=  data_i(35 downto 25) xnor 
                                                data_i(10 downto 0)  xnor 
                                                scrambledData(21 downto 11) xnor 
                                                scrambledData(10 downto 0)  xnor 
                                                scrambledData(35 downto 25);
                                                
                                       
                scrambledData(24 downto 0)  <=  data_i(24 downto 0) xnor 
                                                scrambledData(35 downto 11) xnor 
                                                scrambledData(24 downto 0);
                
            end if;
            
        end if;
        
    end process;
    
    data_o    <= scrambledData when bypass = '0' else
                 data_i;
    
END behabioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--