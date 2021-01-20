-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Device specific package
-------------------------------------------------------

--! IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! @brief vendor_specific_gbt_bank_package - Device specific parameter (Package)
--! @details 
--! The vendor_specific_gbt_bank_package package contains the constant values used to configure the device specific parameters
--! and the record used to connect the transceiver's signals, which are device specific
package vendor_specific_gbt_bank_package is
   
   --=================================== GBT Bank setup ==================================--
	
   -- Device dependant configuration
   constant MAX_NUM_GBT_LINK                    : integer := 4;            --! Maximum number of links per bank
   
   constant GBTRX_BITSLIP_MIN_DLY               : integer := 40;           --! Minimum number of clock cycle to wait for a bitslip action
   constant GBTRX_BITSLIP_MGT_RX_RESET_DELAY    : integer := 25e4;         --! Minimum number of clock cycle to wait for an MGT reset action
   
	-- PCS WordSize dependant
   constant WORD_WIDTH                          : integer := 40;           --! MGT word size (20 [240MHz] / 40 [120MHz])
   constant GBT_WORD_RATIO						: integer := 3;            --! Size ratio between GBT-Frame word (120bit) and MGT word size (120/WORD_WIDTH = 6 [240MHz] / 3 [120MHz])
   constant GBTRX_BITSLIP_NBR_MAX               : integer := 39;           --! Maximum number of bitslip before going back to the first position (WORD_WIDTH-1)
   constant GBT_GEARBOXWORDADDR_SIZE            : integer :=  5;           --! Size in bit of the ram address used for the gearbox [Std] : Log2((120 * 8)/WORD_WIDTH)	
	
   constant RX_GEARBOXSYNCSHIFT_COUNT           : integer := 2;            --! Number of clock cycle between the Rx gearbox and the Descrambler (multicyle to allow word decoding in more than one clock cycle). This constant shall be used to fix the multicycle constraint
   
  --================================= Array Declarations ================================--
  type gbt_devspec_reg16_A                      is array (natural range <>) of std_logic_vector(15 downto 0);
  type gbt_devspec_reg9_A                       is array (natural range <>) of std_logic_vector(8 downto 0);
  type gbt_devspec_reg5_A                       is array (natural range <>) of std_logic_vector(4 downto 0);
  type gbt_devspec_reg4_A                       is array (natural range <>) of std_logic_vector(3 downto 0);
  type gbt_devspec_reg3_A                       is array (natural range <>) of std_logic_vector(2 downto 0);
   
   --================================ Record Declarations ================================-- 
    
   type mgtDeviceSpecific_i_R is
   record
        rx_p                                      : std_logic_vector(1 to MAX_NUM_GBT_LINK);                                 
        rx_n                                      : std_logic_vector(1 to MAX_NUM_GBT_LINK);  
        ------------------------------------------
        reset_freeRunningClock                    : std_logic_vector(1 to MAX_NUM_GBT_LINK);
        ------------------------------------------     
        loopBack                                  : gbt_devspec_reg3_A(1 to MAX_NUM_GBT_LINK);
        ------------------------------------------
        tx_reset                                  : std_logic_vector(1 to MAX_NUM_GBT_LINK);
        rx_reset                                  : std_logic_vector(1 to MAX_NUM_GBT_LINK);
        ------------------------------------------               
        conf_diffCtrl                             : gbt_devspec_reg4_A(1 to MAX_NUM_GBT_LINK);
        conf_postCursor                           : gbt_devspec_reg5_A(1 to MAX_NUM_GBT_LINK);
        conf_preCursor                            : gbt_devspec_reg5_A(1 to MAX_NUM_GBT_LINK);
        conf_txPol                                : std_logic_vector(1 to MAX_NUM_GBT_LINK);
        conf_rxPol                                : std_logic_vector(1 to MAX_NUM_GBT_LINK);
        ------------------------------------------      
        drp_addr                                  : gbt_devspec_reg9_A(1 to MAX_NUM_GBT_LINK);  
        drp_clk                                   : std_logic_vector(1 to MAX_NUM_GBT_LINK);  
        drp_en                                    : std_logic_vector(1 to MAX_NUM_GBT_LINK);
        drp_di                                    : gbt_devspec_reg16_A(1 to MAX_NUM_GBT_LINK);
        drp_we                                    : std_logic_vector(1 to MAX_NUM_GBT_LINK);
        ------------------------------------------      
        prbs_txSel                                : gbt_devspec_reg3_A(1 to MAX_NUM_GBT_LINK);
        prbs_rxSel                                : gbt_devspec_reg3_A(1 to MAX_NUM_GBT_LINK);
        prbs_txForceErr                           : std_logic_vector(1 to MAX_NUM_GBT_LINK);
        prbs_rxCntReset                           : std_logic_vector(1 to MAX_NUM_GBT_LINK);
   end record;
    
   type mgtDeviceSpecific_o_R is
   record
        tx_p                                      : std_logic_vector(1 to MAX_NUM_GBT_LINK);
        tx_n                                      : std_logic_vector(1 to MAX_NUM_GBT_LINK);
        ------------------------------------------
        rxCdrLock                                 : std_logic_vector(1 to MAX_NUM_GBT_LINK);
        ------------------------------------------
        rx_phMonitor                              : gbt_devspec_reg5_A(1 to MAX_NUM_GBT_LINK);
        rx_phSlipMonitor                          : gbt_devspec_reg5_A(1 to MAX_NUM_GBT_LINK);
        ------------------------------------------
        rxWordClkReady                            : std_logic_vector(1 to MAX_NUM_GBT_LINK);
        ------------------------------------------                  
        drp_rdy                                   : std_logic_vector(1 to MAX_NUM_GBT_LINK);
        drp_do                                    : gbt_devspec_reg16_A(1 to MAX_NUM_GBT_LINK);      
        ------------------------------------------                  
        prbs_rxErr                                : std_logic_vector(1 to MAX_NUM_GBT_LINK);
   end record;        
   --=====================================================================================-- 
   
end vendor_specific_gbt_bank_package;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--