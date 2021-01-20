-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Tx Gearbox DPRAM wrapper
-------------------------------------------------------

--! IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Xilinx devices library:
library unisim;
use unisim.vcomponents.all;

--! @brief GBT_tx_gearbox_std_dpram - Tx Gearbox DPRAM wrapper
--! @details 
--! The GBT_tx_gearbox_std_dpram module is a generic wrapper to encapsulate the device specific IP
entity gbt_tx_gearbox_std_dpram is
   port (
      
      --=================--
      -- Write interface --
      --=================--
      
      WR_CLK_I                                  : in  std_logic;
      TX_CLKEN_i                                : in  std_logic;
      WR_ADDRESS_I                              : in  std_logic_vector(  2 downto 0);
      WR_DATA_I                                 : in  std_logic_vector(119 downto 0);
      
      --================--
      -- Read interface --
      --================--
      
      RD_CLK_I                                  : in  std_logic;
      RD_ADDRESS_I                              : in  std_logic_vector(  4 downto 0);
      RD_DATA_O                                 : out std_logic_vector( 39 downto 0)
      
   );
end gbt_tx_gearbox_std_dpram;


--! @brief GBT_tx_gearbox_std_dpram architecture - Tx Gearbox DPRAM wrapper
--! @details 
--! The GBT_tx_gearbox_std_dpram module implements the device specific IP.
architecture structural of gbt_tx_gearbox_std_dpram is
  
   --================================ Signal Declarations ================================--
  
   signal writeData                             : std_logic_vector(159 downto 0);
   
   --=====================================================================================--
     
     COMPONENT xlx_k7v7_tx_dpram
        PORT (
          clka : IN STD_LOGIC;
          wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
          addra : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
          dina : IN STD_LOGIC_VECTOR(159 DOWNTO 0);
          clkb : IN STD_LOGIC;
          addrb : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
          doutb : OUT STD_LOGIC_VECTOR(39 DOWNTO 0)
        );
      END COMPONENT;
  
--=================================================================================================--
begin                 --========####   Architecture Body   ####========-- 
--=================================================================================================--  
   
   --==================================== User Logic =====================================--

   writeData                                    <= x"0000000000" & WR_DATA_I;

   dpram: xlx_k7v7_tx_dpram
      port map (
         CLKA                                   => WR_CLK_I,
         WEA(0)                                 => TX_CLKEN_i,
         ADDRA                                  => WR_ADDRESS_I,
         DINA                                   => writeData,
         CLKB                                   => RD_CLK_I,
         ADDRB                                  => RD_ADDRESS_I,
         DOUTB                                  => RD_DATA_O
      );

   --=====================================================================================--         
end structural;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--