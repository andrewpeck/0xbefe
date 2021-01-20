-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Rx Gearbox DPRAM wrapper
-------------------------------------------------------

--! IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Xilinx devices library:
library unisim;
use unisim.vcomponents.all;

--! @brief GBT_rx_gearbox_std_dpram - Rx Gearbox DPRAM wrapper
--! @details 
--! The GBT_rx_gearbox_std_dpram module is a generic wrapper to encapsulate the device specific IP
entity gbt_rx_gearbox_std_dpram is
   port (
    
      --=================--
      -- Write interface --
      --=================--
      
      WR_EN_I                                   : in  std_logic;
      WR_CLK_I                                  : in  std_logic;
      WR_ADDRESS_I                              : in  std_logic_vector(  4 downto 0);
      WR_DATA_I                                 : in  std_logic_vector( 39 downto 0);
      
      --================--
      -- Read interface --
      --================--
      
      RD_CLK_I                                  : in  std_logic;
      RX_CLKEN_i                                : in  std_logic;
      RD_ADDRESS_I                              : in  std_logic_vector(  2 downto 0);
      RD_DATA_O                                 : out std_logic_vector(119 downto 0)
      
   );
end gbt_rx_gearbox_std_dpram;

--! @brief GBT_rx_gearbox_std_dpram architecture - Rx Gearbox DPRAM wrapper
--! @details 
--! The GBT_rx_gearbox_std_dpram module implements the device specific IP.
architecture structural of gbt_rx_gearbox_std_dpram is

   --================================ Signal Declarations ================================--   

   signal dOutB_from_dpram                      : std_logic_vector(159 downto 0);
   
   --=====================================================================================--
   
      COMPONENT xlx_k7v7_rx_dpram
        PORT (
          clka : IN STD_LOGIC;
          wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
          addra : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
          dina : IN STD_LOGIC_VECTOR(39 DOWNTO 0);
          clkb : IN STD_LOGIC;
          enb : IN STD_LOGIC;
          addrb : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
          doutb : OUT STD_LOGIC_VECTOR(159 DOWNTO 0)
        );
      END COMPONENT;
      
--=================================================================================================--
begin                 --========####   Architecture Body   ####========-- 
--=================================================================================================--  

   --==================================== User Logic =====================================--    

   dpram: xlx_k7v7_rx_dpram
      port map (
         CLKA                                   => WR_CLK_I,
         WEA(0)                                 => WR_EN_I,
         ADDRA                                  => WR_ADDRESS_I,
         DINA                                   => WR_DATA_I,
         CLKB                                   => RD_CLK_I,
         ENB                                    => RX_CLKEN_i,
         ADDRB                                  => RD_ADDRESS_I,
         DOUTB                                  => dOutB_from_dpram
      );
   
   RD_DATA_O                                    <= dOutB_from_dpram(119 downto 0);

   --=====================================================================================--   
end structural;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--