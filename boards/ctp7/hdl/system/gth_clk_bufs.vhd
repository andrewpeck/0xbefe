-------------------------------------------------------------------------------
--                                                                            
--       Unit Name: gth_clk_bufs                                           
--                                                                            
--     Description: 
--
--                                                                            
-------------------------------------------------------------------------------
--                                                                            
--           Notes:                                                           
--                                                                            
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

library work;
use work.gth_pkg.all;
use work.system_package.all;
use work.ttc_pkg.all;

--============================================================================
--                                                          Entity declaration
--============================================================================
entity gth_clk_bufs is
  generic
    (
      g_NUM_OF_GTH_GTs : integer := 36
      );
  port (

    ttc_clks_i                : in t_ttc_clks;
    ttc_clks_locked_i         : in std_logic;

    refclk_F_0_p_i : in std_logic_vector (3 downto 0);
    refclk_F_0_n_i : in std_logic_vector (3 downto 0);
    refclk_F_1_p_i : in std_logic_vector (3 downto 0);
    refclk_F_1_n_i : in std_logic_vector (3 downto 0);
    refclk_B_0_p_i : in std_logic_vector (3 downto 1);
    refclk_B_0_n_i : in std_logic_vector (3 downto 1);
    refclk_B_1_p_i : in std_logic_vector (3 downto 1);
    refclk_B_1_n_i : in std_logic_vector (3 downto 1);

    refclk_F_0_o : out std_logic_vector (3 downto 0);
    refclk_F_1_o : out std_logic_vector (3 downto 0);
    refclk_B_0_o : out std_logic_vector (3 downto 1);
    refclk_B_1_o : out std_logic_vector (3 downto 1);

    gth_gt_clk_out_arr_i : in t_gth_gt_clk_out_arr(g_NUM_OF_GTH_GTs-1 downto 0);

    clk_gth_tx_usrclk_arr_o  : out std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
    clk_gth_tx_usrclk2_arr_o : out std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
    clk_gth_rx_usrclk_arr_o  : out std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);

    gth_gbt_tx_mmcm_locked_o : out std_logic;
    clk_gth_gbt_common_rxusrclk_o : out std_logic;
    clk_gth_gbt_common_txoutclk_o : out std_logic

    );
end gth_clk_bufs;

--============================================================================
architecture gth_clk_bufs_arch of gth_clk_bufs is

--============================================================================
--                                                         Signal declarations
--============================================================================

  signal s_gth_gbt_txoutclk        : std_logic;
  signal s_gth_tx_usrclk_arr       : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_gth_tx_usrclk2_arr      : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
  
--============================================================================
--                                                          Architecture begin
--============================================================================

begin

--============================================================================

  clk_gth_tx_usrclk_arr_o <= s_gth_tx_usrclk_arr;
  clk_gth_tx_usrclk2_arr_o <= s_gth_tx_usrclk2_arr;
  gth_gbt_tx_mmcm_locked_o <= ttc_clks_locked_i;

  gen_ibufds_F_clk_gte2 : for i in 0 to 3 generate

    i_ibufds_F_0 : IBUFDS_GTE2
      port map
      (
        O     => refclk_F_0_o(i),
        ODIV2 => open,
        CEB   => '0',
        I     => refclk_F_0_p_i(i),
        IB    => refclk_F_0_n_i(i)
        );

    i_ibufds_F_1 : IBUFDS_GTE2
      port map
      (
        O     => refclk_F_1_o(i),
        ODIV2 => open,
        CEB   => '0',
        I     => refclk_F_1_p_i(i),
        IB    => refclk_F_1_n_i(i)
        );
  end generate;

  gen_ibufds_B_clk_gte2 : for i in 1 to 3 generate

    i_ibufds_B_0 : IBUFDS_GTE2
      port map
      (
        O     => refclk_B_0_o(i),
        ODIV2 => open,
        CEB   => '0',
        I     => refclk_B_0_p_i(i),
        IB    => refclk_B_0_n_i(i)
        );

    i_ibufds_B_1 : IBUFDS_GTE2
      port map
      (
        O     => refclk_B_1_o(i),
        ODIV2 => open,
        CEB   => '0',
        I     => refclk_B_1_p_i(i),
        IB    => refclk_B_1_n_i(i)
        );

  end generate;

--============================================================================

  gen_bufh_outclks : for n in 0 to g_NUM_OF_GTH_GTs-1 generate

    -- select the TXOUTCLK that feeds to the main MMCM (also use the TXUSRCLK2 as the GBT common RXUSRCLK)
    gen_gth_gbt_txuserclk_master : if c_gth_config_arr(n).gth_txclk_out_master = true generate

      s_gth_gbt_txoutclk <= gth_gt_clk_out_arr_i(n).txoutclk;

      i_bufg_gbt_tx_outclk : BUFG
        port map(
          I => s_gth_gbt_txoutclk,
          O => clk_gth_gbt_common_txoutclk_o
        );

      clk_gth_gbt_common_rxusrclk_o <= s_gth_tx_usrclk_arr(n);

    end generate;

    -- connect the TXUSRCLKs
    gen_gth_txusrclk_40 : if c_gth_config_arr(n).gth_txusrclk = GTH_USRCLK_40 generate
        s_gth_tx_usrclk_arr(n) <= ttc_clks_i.clk_40;
    end generate;

    gen_gth_txusrclk_80 : if c_gth_config_arr(n).gth_txusrclk = GTH_USRCLK_80 generate
        s_gth_tx_usrclk_arr(n) <= ttc_clks_i.clk_80;
    end generate;

    gen_gth_txusrclk_120 : if c_gth_config_arr(n).gth_txusrclk = GTH_USRCLK_120 generate
        s_gth_tx_usrclk_arr(n) <= ttc_clks_i.clk_120;
    end generate;
  
    gen_gth_txusrclk_160 : if c_gth_config_arr(n).gth_txusrclk = GTH_USRCLK_160 generate
        s_gth_tx_usrclk_arr(n) <= ttc_clks_i.clk_160;
    end generate;
  
    gen_gth_txusrclk_320 : if c_gth_config_arr(n).gth_txusrclk = GTH_USRCLK_320 generate
        s_gth_tx_usrclk_arr(n) <= ttc_clks_i.clk_320;
    end generate;
  
  
    -- connect the TXUSRCLK2s
    gen_gth_txusrclk2_40 : if c_gth_config_arr(n).gth_txusrclk2 = GTH_USRCLK_40 generate
        s_gth_tx_usrclk2_arr(n) <= ttc_clks_i.clk_40;
    end generate;

    gen_gth_txusrclk2_80 : if c_gth_config_arr(n).gth_txusrclk2 = GTH_USRCLK_80 generate
        s_gth_tx_usrclk2_arr(n) <= ttc_clks_i.clk_80;
    end generate;

    gen_gth_txusrclk2_120 : if c_gth_config_arr(n).gth_txusrclk2 = GTH_USRCLK_120 generate
        s_gth_tx_usrclk2_arr(n) <= ttc_clks_i.clk_120;
    end generate;
  
    gen_gth_txusrclk2_160 : if c_gth_config_arr(n).gth_txusrclk2 = GTH_USRCLK_160 generate
        s_gth_tx_usrclk2_arr(n) <= ttc_clks_i.clk_160;
    end generate;
  
    gen_gth_txusrclk2_320 : if c_gth_config_arr(n).gth_txusrclk2 = GTH_USRCLK_320 generate
        s_gth_tx_usrclk2_arr(n) <= ttc_clks_i.clk_320;
    end generate;
  
    -- connect the RXOUTCLK to RXUSRCLK through BUFH
    i_bufh_rx_outclk : BUFH
      port map
      (
        I => gth_gt_clk_out_arr_i(n).rxoutclk,
        O => clk_gth_rx_usrclk_arr_o(n)
        );

  end generate;

end gth_clk_bufs_arch;
--============================================================================
--                                                            Architecture end
--============================================================================

