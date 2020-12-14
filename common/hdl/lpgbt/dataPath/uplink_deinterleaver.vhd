-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 1.0
--! @brief LpGBT-FPGA Uplink data de-interleaver
-------------------------------------------------------

--! Include the IEEE VHDL standard library
library ieee;
use ieee.std_logic_1164.all;

--! Include the LpGBT-FPGA specific package
use work.lpgbtfpga_package.all;

--! @brief upLinkDeinterleaver - Uplink data de-interleaver
--! @details De-interleaves the data to extract the encoded message from
--! the received frame. Interleaving data improves the decoding efficiency 
--! by increasing the number of consecutive bits with errors that can be
--! corrected.
ENTITY upLinkDeinterleaver IS
   GENERIC(
        DATARATE                        : integer range 0 to 2 := DYNAMIC;      --! Datarate selection can be: DYNAMIC, DATARATE_10G24 or DATARATE_5G12
        FEC                             : integer range 0 to 2 := DYNAMIC       --! FEC selection can be: DYNAMIC, FEC5 or FEC12
   );
   PORT (
        -- Data
        data_i                          : in  std_logic_vector(255 downto 0);   --! Input frame from the Rx gearbox (data shall be duplicated in upper/lower part of the frame @5.12Gbps)

        fec5_data_o                     : out std_logic_vector(233 downto 0);   --! Output data for FEC5 encoding (data is duplicated in upper/lower part of the frame @5.12Gbps)
        fec5_fec_o                      : out std_logic_vector(19 downto 0);    --! Output FEC for FEC5 encoding (data is duplicated in upper/lower part of the frame @5.12Gbps)
        fec12_data_o                    : out std_logic_vector(205 downto 0);   --! Output data for FEC12 encoding (data is duplicated in upper/lower part of the frame @5.12Gbps)
        fec12_fec_o                     : out std_logic_vector(47 downto 0);    --! Output FEC for FEC12 encoding (data is duplicated in upper/lower part of the frame @5.12Gbps)

        -- Control
        datarate_select_i               : in  std_logic;                        --! Datarate selection (only in DYNAMIC mode) -> '0': 5.12Gbps / '1': 10.24Gbps
        bypass                          : in  std_logic                         --! Bypass uplink interleaver (test purpose only)
   );  
END upLinkDeinterleaver;

--! @brief upLinkDeinterleaver - Uplink data de-interleaver
--! @details The upLinkDeinterleaver routes the data from the MGT to recover
--! the message (symbols) and FEC. It implements both FEC5 and FEC12 
--! de-interleaver modules to reconstruct the data for both configuration.
ARCHITECTURE behavioral of upLinkDeinterleaver IS
        
    --! FEC5 de-interleaver component
    COMPONENT upLinkDeinterleaver_fec5
       GENERIC(
            DATARATE                        : integer range 0 to 2 := DYNAMIC
       );
       PORT (
            -- Data
            data_i                          : in  std_logic_vector(255 downto 0);

            data_o                          : out std_logic_vector(233 downto 0);
            fec_o                           : out std_logic_vector(19 downto 0);

            -- Control
            datarate_select_i               : in  std_logic;  -- '0': 5.12Gbps / '1': 10.24Gbps
            bypass                          : in  std_logic
       );  
    END COMPONENT;
    
    --! FEC12 de-interleaver component
    COMPONENT upLinkDeinterleaver_fec12
       GENERIC(
            DATARATE                        : integer range 0 to 2 := DYNAMIC
       );
       PORT (
            -- Data
            data_i                          : in  std_logic_vector(255 downto 0);

            data_o                          : out std_logic_vector(205 downto 0);
            fec_o                           : out std_logic_vector(47 downto 0);

            -- Control
            datarate_select_i               : in  std_logic;  -- '0': 5.12Gbps / '1': 10.24Gbps
            bypass                          : in  std_logic
       );
    END COMPONENT;
    
    signal fec5_data_s       : std_logic_vector(233 downto 0);  --! FEC5 data from de-interleaver
    signal fec5_fec_s        : std_logic_vector(19 downto 0);   --! FEC5 FEC from de-interleaver
    signal fec12_data_s      : std_logic_vector(205 downto 0);  --! FEC12 data from de-interleaver
    signal fec12_fec_s       : std_logic_vector(47 downto 0);   --! FEC12 FEC from de-interleaver
    
BEGIN                 --========####   Architecture Body   ####========-- 
        
    fec5_gen: if FEC = FEC5 or FEC = DYNAMIC generate
        upLinkDeinterleaver_fec5_inst: upLinkDeinterleaver_fec5
            generic map(
                DATARATE             => DATARATE
            )
            port map (
                data_i               => data_i,
                
                data_o               => fec5_data_s,
                fec_o                => fec5_fec_s,
                
                datarate_select_i    => datarate_select_i,
                bypass               => bypass   
            );
    end generate;

    fec12_gen: if FEC = FEC12 or FEC = DYNAMIC generate
        upLinkDeinterleaver_fec12_inst: upLinkDeinterleaver_fec12
            generic map(
                DATARATE             => DATARATE
            )
            port map (
                data_i               => data_i,
                
                data_o               => fec12_data_s,
                fec_o                => fec12_fec_s,
                
                datarate_select_i    => datarate_select_i,
                bypass               => bypass   
            );
    end generate;
    
    fec5_data_o  <= fec5_data_s when FEC = FEC5 or FEC = DYNAMIC else (others => '0');
    fec5_fec_o   <= fec5_fec_s when FEC = FEC5 or FEC = DYNAMIC else (others => '0');
    
    fec12_data_o <= fec12_data_s when FEC = FEC12 or FEC = DYNAMIC else (others => '0');
    fec12_fec_o  <= fec12_fec_s when FEC = FEC12 or FEC = DYNAMIC else (others => '0');
    
END behavioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--