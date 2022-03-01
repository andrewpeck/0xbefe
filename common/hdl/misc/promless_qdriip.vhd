------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2020-07-16
-- Module Name:    GEM_LOADER
-- Description:    This module implements the so called gemloader module which stores the frontend firmware, and streams it to the gem logic on request.
--                 This version uses a QDR II+ chip for storing the bitfile (this was written for CTP7 that has CY7C1263KV18)
------------------------------------------------------------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.VComponents.all;

use work.ttc_pkg.all;
use work.common_pkg.all;
use work.gem_pkg.all;
use work.ttc_pkg.all;
use work.ipbus.all;
use work.registers.all;

entity promless is
    port (
        reset_i             : in  std_logic;

        clk125_i            : in  std_logic;
        clk200_i            : in  std_logic;
        
        -- QDR interface
        qdriip_cq_p_i       : in  std_logic;
        qdriip_cq_n_i       : in  std_logic;
        qdriip_q_i          : in  std_logic_vector(17 downto 0);
        qdriip_k_p_o        : out std_logic;
        qdriip_k_n_o        : out std_logic;
        qdriip_d_o          : out std_logic_vector(17 downto 0);
        qdriip_sa_o         : out std_logic_vector(18 downto 0);
        qdriip_w_n_o        : out std_logic;
        qdriip_r_n_o        : out std_logic;
        qdriip_bw_n_o       : out std_logic_vector(1 downto 0);
        qdriip_dll_off_n_o  : out std_logic;        
        
        -- user interface
        to_promless_i       : in  t_to_promless;
        from_promless_o     : out t_from_promless;        
        
        -- IPbus
        ipb_reset_i         : in  std_logic;
        ipb_clk_i           : in  std_logic;
        ipb_miso_o          : out ipb_rbus;
        ipb_mosi_i          : in  ipb_wbus                
    );
end promless;

architecture promless_arch of promless is

    component mig_qdr2p
        port(
            -- Single-ended system clock
            sys_clk_i           : in    std_logic;
            -- Single-ended iodelayctrl clk (reference clock)
            clk_ref_i           : in    std_logic; --Memory Interface Ports
            qdriip_cq_p         : in    std_logic;
            qdriip_cq_n         : in    std_logic;
            qdriip_q            : in    std_logic_vector(17 downto 0);
            qdriip_k_p          : inout std_logic;
            qdriip_k_n          : inout std_logic;
            qdriip_d            : out   std_logic_vector(17 downto 0);
            qdriip_sa           : out   std_logic_vector(18 downto 0);
            qdriip_w_n          : out   std_logic;
            qdriip_r_n          : out   std_logic;
            qdriip_bw_n         : out   std_logic_vector(1 downto 0);
            qdriip_dll_off_n    : out   std_logic;
            -- User Interface signals of Channel-0
            app_wr_cmd0         : in    std_logic;
            app_wr_addr0        : in    std_logic_vector(18 downto 0);
            app_wr_data0        : in    std_logic_vector(71 downto 0);
            app_wr_bw_n0        : in    std_logic_vector(7 downto 0);
            app_rd_cmd0         : in    std_logic;
            app_rd_addr0        : in    std_logic_vector(18 downto 0);
            app_rd_valid0       : out   std_logic;
            app_rd_data0        : out   std_logic_vector(71 downto 0);
            -- User Interface signals of Channel-1. It is useful only for BL2 designs.
            -- All inputs of Channel-1 can be grounded for BL4 designs.
            app_wr_cmd1         : in    std_logic;
            app_wr_addr1        : in    std_logic_vector(18 downto 0);
            app_wr_data1        : in    std_logic_vector(35 downto 0);
            app_wr_bw_n1        : in    std_logic_vector(3 downto 0);
            app_rd_cmd1         : in    std_logic;
            app_rd_addr1        : in    std_logic_vector(18 downto 0);
            app_rd_valid1       : out   std_logic;
            app_rd_data1        : out   std_logic_vector(35 downto 0);
            clk                 : out   std_logic;
            rst_clk             : out   std_logic;
            init_calib_complete : out   std_logic;
            sys_rst             : in    std_logic
        );
    end component mig_qdr2p;

    constant RAM_MAX_ADDRESS    : integer := 2097151;
    constant RAM_SC_DATA_WIDTH  : integer := 18;

    --=========== Generic signals ===========--
    signal reset            : std_logic;
    signal reset_local      : std_logic;
    signal ram_reset_cntdwn : unsigned(7 downto 0) := (others => '1');
    
    --=========== RAM signals ===========--
    signal ram_ready        : std_logic;                        
                            
    signal ram_clk          : std_logic;
    signal ram_wr_cmd       : std_logic;
    signal ram_wr_addr      : std_logic_vector(18 downto 0);
    signal ram_wr_data      : std_logic_vector(71 downto 0);
    signal ram_wr_bw        : std_logic_vector(7 downto 0);
    signal ram_rd_cmd       : std_logic;
    signal ram_rd_addr      : std_logic_vector(18 downto 0);
    signal ram_rd_data      : std_logic_vector(71 downto 0);
    signal ram_rd_valid     : std_logic;

    ------ Register signals begin (this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py -- do not edit)
    ------ Register signals end ----------------------------------------------
    
begin

    i_qdr_mig : mig_qdr2p
        port map(
            sys_clk_i           => clk125_i,
            
            clk_ref_i           => clk200_i,
            qdriip_cq_p         => qdriip_cq_p_i,
            qdriip_cq_n         => qdriip_cq_n_i,
            qdriip_q            => qdriip_q_i,
            qdriip_k_p          => qdriip_k_p_o,
            qdriip_k_n          => qdriip_k_n_o,
            qdriip_d            => qdriip_d_o,
            qdriip_sa           => qdriip_sa_o,
            qdriip_w_n          => qdriip_w_n_o,
            qdriip_r_n          => qdriip_r_n_o,
            qdriip_bw_n         => qdriip_bw_n_o,
            qdriip_dll_off_n    => qdriip_dll_off_n_o,
            
            app_wr_cmd0         => ram_wr_cmd,
            app_wr_addr0        => ram_wr_addr,
            app_wr_data0        => ram_wr_data,
            app_wr_bw_n0        => not ram_wr_bw,
            app_rd_cmd0         => ram_rd_cmd,
            app_rd_addr0        => ram_rd_addr,
            app_rd_valid0       => ram_rd_valid,
            app_rd_data0        => ram_rd_data,
            
            app_wr_cmd1         => '0',
            app_wr_addr1        => (others => '0'),
            app_wr_data1        => (others => '0'),
            app_wr_bw_n1        => (others => '0'),
            app_rd_cmd1         => '0',
            app_rd_addr1        => (others => '0'),
            app_rd_valid1       => open,
            app_rd_data1        => open,
            
            clk                 => ram_clk,
            rst_clk             => open,
            init_calib_complete => ram_ready,
            sys_rst             => '0'
        );
    

    
    
    --===============================================================================================
    -- this section is generated by <gem_amc_repo_root>/scripts/generate_registers.py (do not edit) 
    --==== Registers begin ==========================================================================

    --==== Registers end ============================================================================
    
end promless_arch;
