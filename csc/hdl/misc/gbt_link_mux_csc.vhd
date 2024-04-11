------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    20:38:00 2016-08-30
-- Module Name:    GBT_LINK_MUX_CSC
-- Description:    This module is used to map elinks to PROMless and XDCFEB switches, as well as enabling and enabling test mode 
------------------------------------------------------------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common_pkg.all;
use work.csc_pkg.all;

entity gbt_link_mux_csc is
    generic(
        g_NUM_LINKS                 : integer
    );
    port(
        -- clock
        gbt_frame_clk_i             : in  std_logic;
        
        -- links
        gbt_rx_data_arr_i           : in  t_gbt_frame_array(g_NUM_LINKS - 1 downto 0);
        gbt_tx_data_arr_o           : out t_gbt_frame_array(g_NUM_LINKS - 1 downto 0);
        gbt_link_status_arr_i       : in  t_gbt_link_status_arr(g_NUM_LINKS - 1 downto 0);
        
        -- configure
        link_test_mode_i            : in  std_logic;

        -- real elinks
        sca_tx_data_arr_i           : in  t_std2_array(g_NUM_LINKS - 1 downto 0);
        sca_rx_data_arr_o           : out t_std2_array(g_NUM_LINKS - 1 downto 0);
        
        gbt_ic_tx_data_arr_i        : in  t_std2_array(g_NUM_LINKS - 1 downto 0);
        gbt_ic_rx_data_arr_o        : out t_std2_array(g_NUM_LINKS - 1 downto 0);
        
        xdcfeb_hard_reset_i         : in  std_logic; -- setting this high will pull the prog_b low on all the XDCFEBs
        xdcfeb_promless_data_i      : in  std_logic_vector(15 downto 0);
        xdcfeb_switches_i           : in  t_xdcfeb_switches;
        xdcfeb_rx_data_o            : out std_logic_vector(31 downto 0);

        alct_hard_reset_i           : in  std_logic; -- setting this high will pull the prog_b low on all the ALCTs
        alct_promless_data_i        : in  std_logic_vector(7 downto 0);
        alct_switches_i             : in  t_alct_switches;
        
        gbt_ready_arr_o             : out std_logic_vector(g_NUM_LINKS - 1 downto 0);
        
        -- to tests module
        tst_gbt_wide_rx_data_arr_o  : out t_gbt_wide_frame_array(g_NUM_LINKS - 1 downto 0);
        tst_gbt_tx_data_arr_i       : in  t_gbt_frame_array(g_NUM_LINKS - 1 downto 0);
        tst_gbt_ready_arr_o         : out std_logic_vector(g_NUM_LINKS - 1 downto 0)
    );
end gbt_link_mux_csc;

architecture Behavioral of gbt_link_mux_csc is

    component vio_xdcfeb_switches
        port(
            clk        : in  std_logic;
            probe_out0 : out std_logic;
            probe_out1 : out std_logic;
            probe_out2 : out std_logic;
            probe_out3 : out std_logic;
            probe_out4 : out std_logic;
            probe_out5 : out std_logic;
            probe_out6 : out std_logic;
            probe_out7 : out std_logic;
            probe_out8 : out std_logic
        );
    end component;    

    signal real_gbt_tx_data             : t_gbt_frame_array(g_NUM_LINKS - 1 downto 0);
    signal real_gbt_rx_data             : t_gbt_frame_array(g_NUM_LINKS - 1 downto 0);
    signal gbt_rx_ready_arr             : std_logic_vector(g_NUM_LINKS - 1 downto 0);

    signal xdcfeb_promless_data_shuffle : std_logic_vector(15 downto 0);
    signal alct_promless_data_shuffle   : std_logic_vector(15 downto 0);

    signal xdcfeb_switches              : t_xdcfeb_switches;
    signal xdcfeb_switches_vio          : t_xdcfeb_switches;
    signal xdcfeb_switches_vio_override : std_logic;
    signal xdcfeb_hard_reset            : std_logic;
    signal xdcfeb_hard_reset_vio        : std_logic;

begin

    g_tx_data: for i in 0 to g_NUM_LINKS - 1 generate
        gbt_tx_data_arr_o(i) <= real_gbt_tx_data(i) when link_test_mode_i = '0' else real_gbt_tx_data(i)(83 downto 32) & tst_gbt_tx_data_arr_i(i)(31 downto 0);
    end generate;
    
    real_gbt_rx_data <= gbt_rx_data_arr_i when link_test_mode_i = '0' else (others => (others => '0'));
    gbt_ready_arr_o <= gbt_rx_ready_arr when link_test_mode_i = '0' else (others => '0');
    
    g_rx_links : for link in 0 to g_NUM_LINKS - 1 generate
        tst_gbt_wide_rx_data_arr_o(link)(83 downto 0) <= gbt_rx_data_arr_i(link);
        tst_gbt_wide_rx_data_arr_o(link)(115 downto 84) <= (others => '0');
    end generate;    
    tst_gbt_ready_arr_o <= gbt_rx_ready_arr;

    xdcfeb_switches <= xdcfeb_switches_vio when xdcfeb_switches_vio_override = '1' else xdcfeb_switches_i;
    xdcfeb_hard_reset <= xdcfeb_hard_reset_vio when xdcfeb_switches_vio_override = '1' else xdcfeb_hard_reset_i;
    xdcfeb_rx_data_o <= real_gbt_rx_data(xdcfeb_switches_i.rx_select)(31 downto 0);

    g_links : for i in 0 to g_NUM_LINKS - 1 generate
    
        --------- RX ---------
        sca_rx_data_arr_o(i) <= real_gbt_rx_data(i)(81 downto 80);
        
        gbt_ic_rx_data_arr_o(i) <= real_gbt_rx_data(i)(83 downto 82);

        gbt_rx_ready_arr(i) <= gbt_link_status_arr_i(i).gbt_rx_ready;
        
        --------- TX ---------
        real_gbt_tx_data(i)(81 downto 80) <= sca_tx_data_arr_i(i);
        
        real_gbt_tx_data(i)(83 downto 82) <= gbt_ic_tx_data_arr_i(i);
  
        --------- XDCFEB ---------
        xdcfeb_promless_data_shuffle(15) <= xdcfeb_promless_data_i(0);
        xdcfeb_promless_data_shuffle(14) <= xdcfeb_promless_data_i(8);
        xdcfeb_promless_data_shuffle(13) <= xdcfeb_promless_data_i(1);
        xdcfeb_promless_data_shuffle(12) <= xdcfeb_promless_data_i(9);
        xdcfeb_promless_data_shuffle(11) <= xdcfeb_promless_data_i(2);
        xdcfeb_promless_data_shuffle(10) <= xdcfeb_promless_data_i(10);
        xdcfeb_promless_data_shuffle(9)  <= xdcfeb_promless_data_i(3);
        xdcfeb_promless_data_shuffle(8)  <= xdcfeb_promless_data_i(11);
            
        xdcfeb_promless_data_shuffle(7)  <= xdcfeb_promless_data_i(4);
        xdcfeb_promless_data_shuffle(6)  <= xdcfeb_promless_data_i(12);
        xdcfeb_promless_data_shuffle(5)  <= xdcfeb_promless_data_i(5);
        xdcfeb_promless_data_shuffle(4)  <= xdcfeb_promless_data_i(13);
        xdcfeb_promless_data_shuffle(3)  <= xdcfeb_promless_data_i(6);
        xdcfeb_promless_data_shuffle(2)  <= xdcfeb_promless_data_i(14);
        xdcfeb_promless_data_shuffle(1)  <= xdcfeb_promless_data_i(7);
        xdcfeb_promless_data_shuffle(0)  <= xdcfeb_promless_data_i(15);

        real_gbt_tx_data(i)(31 downto 16) <= (others => '1') when xdcfeb_switches.pattern_en = '0' else xdcfeb_switches.pattern_data(31 downto 16); -- these are used only in 16bit mode, but we're only doing 8bit mode here
        real_gbt_tx_data(i)(15 downto 0) <= xdcfeb_promless_data_shuffle when xdcfeb_switches.pattern_en = '0' else xdcfeb_switches.pattern_data(15 downto 0);
        
        -- XDCFEB switches and hard reset (refer to gem_pkg.vhd for documentation)
        real_gbt_tx_data(i)(33 downto 32) <= (others => not xdcfeb_hard_reset);
        real_gbt_tx_data(i)(35 downto 34) <= (others => xdcfeb_switches.prog_en);
        real_gbt_tx_data(i)(37 downto 36) <= (others => xdcfeb_switches.gbt_override);
        real_gbt_tx_data(i)(39 downto 38) <= (others => xdcfeb_switches.sel_gbt);
        real_gbt_tx_data(i)(41 downto 40) <= (others => xdcfeb_switches.sel_8bit);
        real_gbt_tx_data(i)(43 downto 42) <= (others => xdcfeb_switches.sel_master);
        real_gbt_tx_data(i)(45 downto 44) <= (others => xdcfeb_switches.sel_cclk_src);
        real_gbt_tx_data(i)(47 downto 46) <= (others => xdcfeb_switches.sel_gbt_cclk_src);

        --------- ALCT ---------

        alct_promless_data_shuffle(15) <= alct_promless_data_i(2);
        alct_promless_data_shuffle(14) <= alct_promless_data_i(2);
        alct_promless_data_shuffle(13) <= alct_promless_data_i(4);
        alct_promless_data_shuffle(12) <= alct_promless_data_i(4);
        alct_promless_data_shuffle(11) <= alct_promless_data_i(1);
        alct_promless_data_shuffle(10) <= alct_promless_data_i(1);
        alct_promless_data_shuffle(9)  <= alct_promless_data_i(6);
        alct_promless_data_shuffle(8)  <= alct_promless_data_i(6);
        alct_promless_data_shuffle(7)  <= alct_promless_data_i(3);
        alct_promless_data_shuffle(6)  <= alct_promless_data_i(3);
        alct_promless_data_shuffle(5)  <= alct_promless_data_i(7);
        alct_promless_data_shuffle(4)  <= alct_promless_data_i(7);
        alct_promless_data_shuffle(3)  <= alct_promless_data_i(5);
        alct_promless_data_shuffle(2)  <= alct_promless_data_i(5);
        alct_promless_data_shuffle(1)  <= alct_promless_data_i(0);
        alct_promless_data_shuffle(0)  <= alct_promless_data_i(0);

        -- ALCT switches and hard reset (refer to gem_pkg.vhd for documentation)
        real_gbt_tx_data(i)(79 downto 78) <= (others => not alct_hard_reset_i); -- PROGRAM_B
        real_gbt_tx_data(i)(77 downto 76) <= (others => alct_switches_i.prog_dis); -- GBT_PRG_DIS
        real_gbt_tx_data(i)(75 downto 74) <= (others => alct_switches_i.sel_gbt_cclk); -- GBT_SEL_GBT_CCLK_SRC
        real_gbt_tx_data(i)(73 downto 72) <= (others => alct_switches_i.sel_gbt_xprm); -- GBT_SEL_GBT_XPRM 
        real_gbt_tx_data(i)(71 downto 70) <= (others => alct_switches_i.gbt_override); -- GBT_OVERRIDE

        real_gbt_tx_data(i)(69 downto 64) <= (others => '0'); -- UNUSED
        
        real_gbt_tx_data(i)(63 downto 48) <= alct_promless_data_shuffle;
                
    end generate;
    
    i_vio_xdcfeb_switches : component vio_xdcfeb_switches
        port map(
            clk        => gbt_frame_clk_i,
            probe_out0 => xdcfeb_switches_vio_override,
            probe_out1 => xdcfeb_hard_reset_vio,
            probe_out2 => xdcfeb_switches_vio.prog_en,
            probe_out3 => xdcfeb_switches_vio.gbt_override,
            probe_out4 => xdcfeb_switches_vio.sel_gbt,
            probe_out5 => xdcfeb_switches_vio.sel_8bit,
            probe_out6 => xdcfeb_switches_vio.sel_master,
            probe_out7 => xdcfeb_switches_vio.sel_cclk_src,
            probe_out8 => xdcfeb_switches_vio.sel_gbt_cclk_src
        );
    
end Behavioral;
