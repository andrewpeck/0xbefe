-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Rx descrambler
-------------------------------------------------------

--! Include the IEEE VHDL standard library
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Include the GBT-FPGA specific packages
use work.gbt_bank_package.all;
use work.vendor_specific_gbt_bank_package.all;

--! @brief GBT_rx_descrambler - Rx descrambler
--! @details 
--! The GBT_rx_descrambler module restores the scrambled data using the algorithm specified
--! by the GBTx.
entity gbt_rx_descrambler is 
  generic (   
    RX_ENCODING                               : integer range 0 to 2 := GBT_FRAME    --! RX_ENCODING: Encoding scheme for the Rx datapath (GBT_FRAME or WIDE_BUS)
  );
  port (
    --===============--
    -- Reset & Clock --
    --===============--
    RX_RESET_I                                : in  std_logic;                       --! Reset the descrambler (Asynchronous)
    RX_FRAMECLK_I                             : in  std_logic;                       --! Rx frame clock used to clock the descrambler logic
    RX_CLKEN_i                                : in  std_logic;
	 
    --=========--
    -- Control --
    --=========--
    RX_ENCODING_SEL_i                         : in  std_logic;                       --! Select the Rx encoding in dynamic mode ('1': GBT / '0': WideBus)
    RX_DECODER_READY_I                        : in  std_logic;                       --! Ready status from the gbt rx decoder
    READY_O                                   : out std_logic;                       --! Ready status from the descrambler

    RX_ISDATA_FLAG_I                          : in  std_logic;                       --! DataFlag recovered from the header by the gbt_rx_decoder
    RX_ISDATA_FLAG_O                          : out std_logic;                       --! DataFlag aligned with the word

    --==============--
    -- Frame & Data --
    --==============--
    RX_COMMON_FRAME_I                         : in  std_logic_vector(83 downto 0);   --! GBT decoded frame to be descrambled
    RX_DATA_O                                 : out std_logic_vector(83 downto 0);   --! GBT frame decoded and descrambled (ready to be used)

    RX_EXTRA_FRAME_WIDEBUS_I                  : in  std_logic_vector(31 downto 0);   --! Wide bus extra data (32bit) to be descrambled
    RX_EXTRA_DATA_WIDEBUS_O                   : out std_logic_vector(31 downto 0)    --! Wide bus extra data descrambled (ready to be used)
  );
end gbt_rx_descrambler;

--! @brief GBT_rx_descrambler architecture - Rx descrambler
--! @details The GBT_rx_descrambler architecture instantiates 4 times 21bit descrambler for the GBT encoded data (84bit)
--! and 2 times 16bit descrambler for the 32bit Widebus extra data when the Widebus encoding scheme is selected.
architecture structural of gbt_rx_descrambler is 

    signal RX_EXTRA_DATA_WIDEBUS_wb_s     : std_logic_vector(31 downto 0);
    signal RX_EXTRA_DATA_WIDEBUS_gbt_s    : std_logic_vector(31 downto 0);
    
begin

   --==================================== User Logic =====================================--
   
   --! Alignes the flags and status with the RX_FRAMECLK
   regs: process(RX_FRAMECLK_I, RX_RESET_I)
   begin
      if RX_RESET_I = '1' then
         RX_ISDATA_FLAG_O                       <= '0';
         READY_O                                <= '0';
      elsif rising_edge(RX_FRAMECLK_I) then
		   if RX_CLKEN_i = '1' then
				RX_ISDATA_FLAG_O                       <= RX_ISDATA_FLAG_I;
				READY_O                                <= RX_DECODER_READY_I;
			end if;
      end if;
   end process;
   
   --============--
   -- Scramblers --
   --============--
   
   --! 84 bit descrambler used in GBT-Frame and WideBus mode:
   gbtRxDescrambler84bit_gen: for i in 0 to 3 generate
     gbtRxDescrambler21bit: entity work.gbt_rx_descrambler_21bit
        port map(
           RX_RESET_I                       => RX_RESET_I,
           RX_FRAMECLK_I                    => RX_FRAMECLK_I,
           RX_CLKEN_i                       => RX_CLKEN_i,
           RX_COMMON_FRAME_I                => RX_COMMON_FRAME_I(((21*i)+20) downto (21*i)),
           RX_DATA_O                        => RX_DATA_O(((21*i)+20) downto (21*i))
        );
   end generate;
   
    --! 32 bit descrambler used in widebus mode only:
    wideBus_gen: if RX_ENCODING = WIDE_BUS or RX_ENCODING = GBT_DYNAMIC generate
      gbtRxDescrambler32bit_gen: for i in 0 to 1 generate
         gbtRxDescrambler16bit: entity work.gbt_rx_descrambler_16bit
            port map(
               RX_RESET_I                       => RX_RESET_I,
               RX_FRAMECLK_I                    => RX_FRAMECLK_I,
			   RX_CLKEN_i                       => RX_CLKEN_i,
               RX_EXTRA_FRAME_WIDEBUS_I         => RX_EXTRA_FRAME_WIDEBUS_I(((16*i)+15) downto (16*i)),
               RX_EXTRA_DATA_WIDEBUS_O          => RX_EXTRA_DATA_WIDEBUS_wb_s(((16*i)+15) downto (16*i))
            );
      end generate;
   end generate;
   
   RX_EXTRA_DATA_WIDEBUS_gbt_s               <= (others => '0');   
       
    -- Encoding select.    
    wbsel_gen: if RX_ENCODING = WIDE_BUS generate      
        RX_EXTRA_DATA_WIDEBUS_O                <= RX_EXTRA_DATA_WIDEBUS_wb_s;
    end generate; 
    
    gbtsel_gen: if RX_ENCODING = GBT_FRAME generate
        RX_EXTRA_DATA_WIDEBUS_O                <= RX_EXTRA_DATA_WIDEBUS_gbt_s;
    end generate;

    dynsel_gen: if RX_ENCODING = GBT_DYNAMIC generate
        RX_EXTRA_DATA_WIDEBUS_O                <= RX_EXTRA_DATA_WIDEBUS_gbt_s when RX_ENCODING_SEL_i = '1' else RX_EXTRA_DATA_WIDEBUS_wb_s;
    end generate;   
   --=====================================================================================--
end structural;