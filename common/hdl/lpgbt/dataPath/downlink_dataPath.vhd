-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 1.0
--! @brief LpGBT-FPGA Downlink datapath
-------------------------------------------------------

--! Include the IEEE VHDL standard library
library ieee;
use ieee.std_logic_1164.all;

--! Include the LpGBT-FPGA specific package
use work.lpgbtfpga_package.all;

--! @brief LpGBT_FPGA_Downlink_datapath - Downlink datapath top level
--! @details 
--! The LpGBT_FPGA_Downlink_datapath module implements the logic required 
--! for the data encoding as required by the LpGBT for the downlink
--! path (Back-end to Front-end).
entity LpGBT_FPGA_Downlink_datapath is
   GENERIC(
        MULTICYCLE_DELAY                : integer range 0 to 7 := 3              --! Multicycle delay
   );
   port (
        -- Clocks
        donwlinkClk_i                    : in  std_logic;                       --! Downlink datapath clock (either 320 or 40MHz)
        downlinkClkEn_i                  : in  std_logic;                       --! Clock enable (1 over 8 when encoding runs @ 320Mhz, '1' @ 40MHz)
        downlinkRst_i                    : in  std_logic;
        
        -- Down link
        downlinkUserData_i               : in  std_logic_vector(31 downto 0);   --! Downlink data (user)
        downlinkEcData_i                 : in  std_logic_vector(1 downto 0);    --! Downlink EC field
        downlinkIcData_i                 : in  std_logic_vector(1 downto 0);    --! Downlink IC field
        
        -- Output
        downLinkFrame_o                  : out std_logic_vector(63 downto 0);   --! Downlink encoded frame (IC + EC + User Data + FEC)
        
        -- Configuration
        downLinkBypassInterleaver_i      : in  std_logic;                       --! Bypass downlink interleaver (test purpose only)
        downLinkBypassFECEncoder_i       : in  std_logic;                       --! Bypass downlink FEC (test purpose only)
        downLinkBypassScrambler_i        : in  std_logic;                       --! Bypass downlink scrambler (test purpose only)
        
        -- Status
        downlinkReady_o                  : out std_logic                        --! Downlink ready status
   );   
end LpGBT_FPGA_Downlink_datapath;

--! @brief LpGBT_FPGA_Downlink_datapath architecture - Downlink datapath top level
--! @details The LpGBT_FPGA_Downlink_datapath module scrambles, encodes and interleaves the data
--! to provide the encoded bus used in the downlink communication with an LpGBT device. The
--! output bus, which is made of 64 bits running at the LHC clock (about 40MHz) is encoded
--! using a Reed-Solomon scheme and shall be sent using a serial link configured at 2.56Gbps. 
architecture behavioral of LpGBT_FPGA_Downlink_datapath is
    
    signal downLinkData_s             : std_logic_vector(35 downto 0);      --! Data bus made of IC + EC + User Data (used to input the scrambler)
    signal downLinkScrambledData_s    : std_logic_vector(35 downto 0);      --! Scrambled data
    signal downLinkFEC_s              : std_logic_vector(23 downto 0);      --! FEC bus
    signal downLinkFrame_s            : std_logic_vector(63 downto 0);

    ------------- Begin Cut here for COMPONENT Declaration ------ COMP_TAG
    COMPONENT ila_downlink_debug    
        PORT (
            clk : IN STD_LOGIC;    
            probe0 : IN STD_LOGIC_VECTOR(35 DOWNTO 0); 
            probe1 : IN STD_LOGIC_VECTOR(35 DOWNTO 0); 
            probe2 : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
            probe3 : IN STD_LOGIC_VECTOR(63 DOWNTO 0)
        );
    END COMPONENT;
    
    --! Scrambler module used for the downlink encoding
    COMPONENT scrambler36bitOrder36
       GENERIC (
            INIT_SEED                 : in std_logic_vector(35 downto 0)    := x"1fba847af"
       );
       PORT (
            -- Clocks & reset
            clk_i                     : in  std_logic;
            clkEn_i                   : in  std_logic;
            
            reset_i                   : in  std_logic;
            
            -- Data
            data_i                    : in  std_logic_vector(35 downto 0);
            data_o                    : out std_logic_vector(35 downto 0);
            
            -- Control
            bypass                    : in  std_logic        
       );   
    END COMPONENT;
    
    --! FEC calculator used for the downlink encoding
    COMPONENT downLinkFECEncoder IS
       PORT (            
            -- Data
            data_i                    : in  std_logic_vector(35 downto 0);
            FEC_o                     : out std_logic_vector(23 downto 0);
            
            -- Control
            bypass                    : in  std_logic        
       );   
    END COMPONENT;
    
    --! Interleaver used to improve the decoding efficiency
    COMPONENT downLinkInterleaver IS
       GENERIC( 
            HEADER_c                  : in  std_logic_vector(3 downto 0)
       );
       PORT (
            -- Data
            data_i                    : in  std_logic_vector(35 downto 0);
            FEC_i                     : in  std_logic_vector(23 downto 0);
            
            data_o                    : out std_logic_vector(63 downto 0);
            
            -- Control
            bypass                    : in  std_logic
       );   
    END COMPONENT;
    
    signal downlinkClkOutEn_s  : std_logic;
    signal rst_downInitDone_s : std_logic;
    
begin                 --========####   Architecture Body   ####========-
            
        
        --! Multicycle path configuration
        syncShiftReg_proc: process(downlinkRst_i, donwlinkClk_i)
            variable cnter  : integer range 0 to 7;
        begin
        
            if downlinkRst_i = '1' then
                  cnter              := 0;
                  downlinkClkOutEn_s <= '0';
                  rst_downInitDone_s <= '0';
                  
            elsif rising_edge(donwlinkClk_i) then
                if downlinkClkEn_i = '1' then
                    cnter                 := 0;
                    rst_downInitDone_s  <= '1';
                elsif rst_downInitDone_s = '1' then
                    cnter            := cnter + 1;
                end if;
                
                downlinkClkOutEn_s       <= '0';
                if cnter = MULTICYCLE_DELAY then
                    downlinkClkOutEn_s   <= '1';
                end if;
            end if;
        end process;
        
    -- Mapping
    downLinkData_s(31 downto 0)    <= downlinkUserData_i;
    downLinkData_s(33 downto 32)   <= downlinkEcData_i;
    downLinkData_s(35 downto 34)   <= downlinkIcData_i;
    
    --! Scrambler module used for the downlink encoding
    scrambler36bitOrder36_inst: scrambler36bitOrder36
        port map (
            clk_i                => donwlinkClk_i,
            clkEn_i              => downlinkClkOutEn_s,
            
            reset_i              => downlinkRst_i,
            
            data_i               => downLinkData_s,
            data_o               => downLinkScrambledData_s,
            
            bypass               => downLinkBypassScrambler_i   
        );
    
    --! FEC calculator used for the downlink encoding
    downLinkFECEncoder_inst: downLinkFECEncoder
        port map (            
            -- Data
            data_i               => downLinkScrambledData_s,
            FEC_o                => downLinkFEC_s,
            
            -- Control
            bypass               => downLinkBypassFECEncoder_i
        );  
    
    --! Interleaver used to improve the decoding efficiency
    downLinkInterleaver_inst: downLinkInterleaver
        generic map (
            HEADER_c             => "1001"
        )
        port map (
            -- Data
            data_i               => downLinkScrambledData_s,
            FEC_i                => downLinkFEC_s,
            
            data_o               => downLinkFrame_s,
            
            -- Control
            bypass               => downLinkBypassInterleaver_i
        );  
    
    downLinkFrame_o <= downLinkFrame_s;
    downlinkReady_o <= not(downlinkRst_i);
    
end behavioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--