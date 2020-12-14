-------------------------------------------------------------------------------
--                                                                            
--       Unit Name: gth_wrapper                                            
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
use ieee.std_logic_misc.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

library work;
use work.gth_pkg.all;
use work.gem_pkg.all;
use work.ttc_pkg.all;

use work.system_package.all;

--============================================================================
--                                                          Entity declaration
--============================================================================
entity gth_wrapper is
  generic
    (
      g_EXAMPLE_SIMULATION     : integer                := 0;
      g_STABLE_CLOCK_PERIOD    : integer range 4 to 250 := 20;  --Period of the stable clock driving this state-machine, unit is [ns]
      g_NUM_OF_GTH_GTs         : integer                := 64;
      g_NUM_OF_GTH_COMMONs     : integer                := 16;
      g_GT_SIM_GTRESET_SPEEDUP : string                 := "FALSE"  -- Set to "TRUE" to speed up sim reset

      );
  port (

    clk_stable_i : in std_logic;

    refclk_F_0_p_i : in std_logic_vector (3 downto 0);
    refclk_F_0_n_i : in std_logic_vector (3 downto 0);
    refclk_F_1_p_i : in std_logic_vector (3 downto 0);
    refclk_F_1_n_i : in std_logic_vector (3 downto 0);
    refclk_B_0_p_i : in std_logic_vector (3 downto 1);
    refclk_B_0_n_i : in std_logic_vector (3 downto 1);
    refclk_B_1_p_i : in std_logic_vector (3 downto 1);
    refclk_B_1_n_i : in std_logic_vector (3 downto 1);

    clk_gth_tx_usrclk_arr_o : out std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
    clk_gth_rx_usrclk_arr_o : out std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);

    ----------------- TTC ------------------------
    ttc_clks_i        : in  t_ttc_clks;
    ttc_clks_locked_i : in  std_logic;
    ttc_clks_reset_o  : out std_logic;
    
    ------------------------

    gth_cpll_reset_arr_i  : in  std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
    gth_cpll_status_arr_o : out t_gth_cpll_status_arr(g_NUM_OF_GTH_GTs-1 downto 0);

    ------------------------
    -- GTH common

    gth_common_reset_i      : in  std_logic_vector(g_NUM_OF_GTH_COMMONs-1 downto 0);
    gth_common_status_arr_o : out t_gth_common_status_arr(g_NUM_OF_GTH_COMMONs-1 downto 0);

    gth_common_drp_arr_i : in  t_gth_common_drp_in_arr(g_NUM_OF_GTH_COMMONs-1 downto 0);
    gth_common_drp_arr_o : out t_gth_common_drp_out_arr(g_NUM_OF_GTH_COMMONs-1 downto 0);
    ------------------------

    gth_gt_txreset_i : in std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
    gth_gt_rxreset_i : in std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);

    gth_gt_txreset_done_o : out std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
    gth_gt_rxreset_done_o : out std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);

    gth_rx_serial_arr_i : in  t_gth_rx_serial_arr(g_NUM_OF_GTH_GTs-1 downto 0);
    gth_tx_serial_arr_o : out t_gth_tx_serial_arr(g_NUM_OF_GTH_GTs-1 downto 0);

    gth_gt_drp_arr_i : in  t_gth_gt_drp_in_arr(g_NUM_OF_GTH_GTs-1 downto 0);
    gth_gt_drp_arr_o : out t_gth_gt_drp_out_arr(g_NUM_OF_GTH_GTs-1 downto 0);

    gth_tx_ctrl_arr_i   : in  t_gth_tx_ctrl_arr(g_NUM_OF_GTH_GTs-1 downto 0);
    gth_tx_status_arr_o : out t_gth_tx_status_arr(g_NUM_OF_GTH_GTs-1 downto 0);

    gth_rx_ctrl_arr_i   : in t_gth_rx_ctrl_arr(g_NUM_OF_GTH_GTs-1 downto 0);
    gth_rx_ctrl_2_arr_i : in t_gth_rx_ctrl_2_arr(g_NUM_OF_GTH_GTs-1 downto 0);

    gth_rx_status_arr_o : out t_gth_rx_status_arr(g_NUM_OF_GTH_GTs-1 downto 0);

    gth_misc_ctrl_arr_i   : in  t_gth_misc_ctrl_arr(g_NUM_OF_GTH_GTs-1 downto 0);
    gth_misc_status_arr_o : out t_gth_misc_status_arr(g_NUM_OF_GTH_GTs-1 downto 0);

    gth_tx_data_arr_i : in  t_mgt_64b_tx_data_arr(g_NUM_OF_GTH_GTs-1 downto 0);
    gth_rx_data_arr_o : out t_mgt_64b_rx_data_arr(g_NUM_OF_GTH_GTs-1 downto 0);

    gth_gbt_common_rxusrclk_o : out std_logic;
    gth_gbt_common_txoutclk_o : out std_logic
    
    );
end gth_wrapper;

--============================================================================
--                                                        Architecture section
--============================================================================
architecture gth_wrapper_arch of gth_wrapper is

--============================================================================
--                                                         Signal declarations
--============================================================================

  signal s_refclk_F_0 : std_logic_vector (3 downto 0);
  signal s_refclk_F_1 : std_logic_vector (3 downto 0);
  signal s_refclk_B_0 : std_logic_vector (3 downto 1);
  signal s_refclk_B_1 : std_logic_vector (3 downto 1);

  attribute syn_noclockbuf : boolean;

  attribute syn_noclockbuf of s_refclk_F_0 : signal is true;
  attribute syn_noclockbuf of s_refclk_F_1 : signal is true;
  attribute syn_noclockbuf of s_refclk_B_0 : signal is true;
  attribute syn_noclockbuf of s_refclk_B_1 : signal is true;


  signal s_gth_rx_serial_arr : t_gth_rx_serial_arr(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_gth_tx_serial_arr : t_gth_tx_serial_arr(g_NUM_OF_GTH_GTs-1 downto 0);

  signal s_gth_gt_clk_in_arr  : t_gth_gt_clk_in_arr(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_gth_gt_clk_out_arr : t_gth_gt_clk_out_arr(g_NUM_OF_GTH_GTs-1 downto 0);

  signal s_gth_cpll_ctrl_arr   : t_gth_cpll_ctrl_arr(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_gth_cpll_init_arr   : t_gth_cpll_init_arr(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_gth_cpll_status_arr : t_gth_cpll_status_arr(g_NUM_OF_GTH_GTs-1 downto 0);

  signal s_gth_gt_drp_in_arr  : t_gth_gt_drp_in_arr(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_gth_gt_drp_out_arr : t_gth_gt_drp_out_arr(g_NUM_OF_GTH_GTs-1 downto 0);

  signal s_gth_tx_ctrl_arr   : t_gth_tx_ctrl_arr(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_gth_tx_init_arr   : t_gth_tx_init_arr(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_gth_tx_status_arr : t_gth_tx_status_arr(g_NUM_OF_GTH_GTs-1 downto 0);

  signal s_gth_rx_ctrl_arr   : t_gth_rx_ctrl_arr(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_gth_rx_ctrl_2_arr : t_gth_rx_ctrl_2_arr(g_NUM_OF_GTH_GTs-1 downto 0);

  signal s_gth_rx_init_arr : t_gth_rx_init_arr(g_NUM_OF_GTH_GTs-1 downto 0);

  signal s_gth_rx_status_arr : t_gth_rx_status_arr(g_NUM_OF_GTH_GTs-1 downto 0);

  signal s_gth_misc_ctrl_arr   : t_gth_misc_ctrl_arr(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_gth_misc_status_arr : t_gth_misc_status_arr(g_NUM_OF_GTH_GTs-1 downto 0);

  signal s_gth_tx_data_arr : t_mgt_64b_tx_data_arr(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_gth_rx_data_arr : t_mgt_64b_rx_data_arr(g_NUM_OF_GTH_GTs-1 downto 0);

  ---------------------
    
  signal s_gth_gbt_common_rxusrclk : std_logic;

  signal s_gth_common_clk_in_arr  : t_gth_common_clk_in_arr(g_NUM_OF_GTH_COMMONs-1 downto 0);
  signal s_gth_common_clk_out_arr : t_gth_common_clk_out_arr(g_NUM_OF_GTH_COMMONs-1 downto 0);

  signal s_gth_common_ctrl_arr   : t_gth_common_ctrl_arr(g_NUM_OF_GTH_COMMONs-1 downto 0);
  signal s_gth_common_status_arr : t_gth_common_status_arr(g_NUM_OF_GTH_COMMONs-1 downto 0);

  signal s_gth_common_drp_in_arr  : t_gth_common_drp_in_arr(g_NUM_OF_GTH_COMMONs-1 downto 0);
  signal s_gth_common_drp_out_arr : t_gth_common_drp_out_arr(g_NUM_OF_GTH_COMMONs-1 downto 0);

  ---------------------
  function get_cdrlock_time(is_sim : in integer) return integer is
    variable lock_time : integer;
  begin
    if (is_sim = 1) then
      lock_time := 1000;
    else
      lock_time := 50000 / integer(3.2);  --Typical CDR lock time is 50,000UI as per DS183
    end if;
    return lock_time;
  end function;

  constant C_RX_CDRLOCK_TIME   : integer := get_cdrlock_time(g_EXAMPLE_SIMULATION);  -- 200us
  constant C_WAIT_TIME_CDRLOCK : integer := C_RX_CDRLOCK_TIME / g_STABLE_CLOCK_PERIOD;  -- 200 us time-out

  type t_rx_cdr_lock_counter_arr is array(integer range <>) of integer range 0 to C_WAIT_TIME_CDRLOCK;

  signal s_gth_tx_run_phalignment       : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_gth_tx_run_phalignment_done  : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_gth_tx_rst_phalignment       : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);

  signal s_gth_rx_run_phalignment       : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_gth_rx_run_phalignment_done  : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_gth_rx_rst_phalignment       : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);

  signal s_gth_recclk_stable            : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_gth_rx_cdrlocked             : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_gth_rx_cdrlock_counter       : t_rx_cdr_lock_counter_arr(g_NUM_OF_GTH_GTs-1 downto 0);

  signal s_clk_gth_tx_usrclk_arr        : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_clk_gth_tx_usrclk2_arr       : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_clk_gth_rx_usrclk_arr        : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);

  signal s_tx_startup_fsm_mmcm_reset    : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_tx_startup_fsm_mmcm_lock     : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0) := (others => '1');


  signal s_gth_gbt_tx_mmcm_reset        : std_logic;
  signal s_gth_gbt_tx_mmcm_locked       : std_logic;


--============================================================================
--                                                          Architecture begin
--============================================================================

begin

  gen_tx_mmcm_sigs : for n in 0 to g_NUM_OF_GTH_GTs-1 generate

    s_tx_startup_fsm_mmcm_lock(n) <= s_gth_gbt_tx_mmcm_locked;

    gen_gth_gbt_txuserclk : if c_gth_config_arr(n).gth_link_type = gth_4p8g or c_gth_config_arr(n).gth_link_type = gth_10p24g generate

      gen_gth_gbt_txuserclk_master : if c_gth_config_arr(n).gth_txclk_out_master = true generate

        s_gth_gbt_tx_mmcm_reset <= s_tx_startup_fsm_mmcm_reset(n);
        
--        i_pcs_clk_phase_check : entity work.clk_phase_check_v7
--            generic map(
--                FREQ_MHZ => 120.000
--            )
--            port map(
--                reset => s_GTH_4p8g_TX_MMCM_reset,
--                clk1  => ttc_clks_i.clk_120,
--                clk2  => s_gth_gt_clk_out_arr(n).txoutpcs
--            );

      end generate;
    end generate;
  end generate;

  i_gth_clk_bufs : entity work.gth_clk_bufs
    generic map
    (
      g_NUM_OF_GTH_GTs => g_NUM_OF_GTH_GTs
      )
    port map
    (
      ttc_clks_i                => ttc_clks_i,
      ttc_clks_locked_i         => ttc_clks_locked_i,

      refclk_F_0_p_i => refclk_F_0_p_i,
      refclk_F_0_n_i => refclk_F_0_n_i,
      refclk_F_1_p_i => refclk_F_1_p_i,
      refclk_F_1_n_i => refclk_F_1_n_i,
      refclk_B_0_p_i => refclk_B_0_p_i,
      refclk_B_0_n_i => refclk_B_0_n_i,
      refclk_B_1_p_i => refclk_B_1_p_i,
      refclk_B_1_n_i => refclk_B_1_n_i,

      refclk_F_0_o => s_refclk_F_0,
      refclk_F_1_o => s_refclk_F_1,
      refclk_B_0_o => s_refclk_B_0,
      refclk_B_1_o => s_refclk_B_1,

      gth_gt_clk_out_arr_i      => s_gth_gt_clk_out_arr,

      clk_gth_tx_usrclk_arr_o   => s_clk_gth_tx_usrclk_arr,
      clk_gth_tx_usrclk2_arr_o  => s_clk_gth_tx_usrclk2_arr,
      clk_gth_rx_usrclk_arr_o   => s_clk_gth_rx_usrclk_arr,

      gth_gbt_tx_mmcm_locked_o  => s_gth_gbt_tx_mmcm_locked,
      clk_gth_gbt_common_rxusrclk_o => s_gth_gbt_common_rxusrclk,
      clk_gth_gbt_common_txoutclk_o => gth_gbt_common_txoutclk_o
      
      );

  ttc_clks_reset_o <= s_gth_gbt_tx_mmcm_reset;
  clk_gth_tx_usrclk_arr_o <= s_clk_gth_tx_usrclk2_arr;
  clk_gth_rx_usrclk_arr_o <= s_clk_gth_rx_usrclk_arr;
  gth_gbt_common_rxusrclk_o <= s_gth_gbt_common_rxusrclk;
  
------------------------

  gen_qpll_refclk_assign_Q110_to_Q111 : for i in 0 to 1 generate
  begin
    gen_qpll_inner : for j in 0 to 3 generate
    begin
      s_gth_gt_clk_in_arr(i*4+j).GTREFCLK0  <= s_refclk_F_0(3);
      s_gth_gt_clk_in_arr(i*4+j).GTREFCLK1  <= s_refclk_F_1(3);
      s_gth_gt_clk_in_arr(i*4+j).qpllclk    <= s_gth_common_clk_out_arr(i).QPLLCLK;
      s_gth_gt_clk_in_arr(i*4+j).qpllrefclk <= s_gth_common_clk_out_arr(i).QPLLREFCLK;
    end generate;
  end generate;

  gen_qpll_refclk_assign_Q112_to_Q114 : for i in 2 to 4 generate
  begin
    gen_qpll_inner : for j in 0 to 3 generate
    begin
      s_gth_gt_clk_in_arr(i*4+j).GTREFCLK0  <= s_refclk_F_0(2);
      s_gth_gt_clk_in_arr(i*4+j).GTREFCLK1  <= s_refclk_F_1(2);
      s_gth_gt_clk_in_arr(i*4+j).qpllclk    <= s_gth_common_clk_out_arr(i).QPLLCLK;
      s_gth_gt_clk_in_arr(i*4+j).qpllrefclk <= s_gth_common_clk_out_arr(i).QPLLREFCLK;
    end generate;
  end generate;

  gen_qpll_refclk_assign_Q115_to_Q117 : for i in 5 to 7 generate
  begin
    gen_qpll_inner : for j in 0 to 3 generate
    begin
      s_gth_gt_clk_in_arr(i*4+j).GTREFCLK0  <= s_refclk_F_0(1);
      s_gth_gt_clk_in_arr(i*4+j).GTREFCLK1  <= s_refclk_F_1(1);
      s_gth_gt_clk_in_arr(i*4+j).qpllclk    <= s_gth_common_clk_out_arr(i).QPLLCLK;
      s_gth_gt_clk_in_arr(i*4+j).qpllrefclk <= s_gth_common_clk_out_arr(i).QPLLREFCLK;
    end generate;
  end generate;

  gen_qpll_refclk_assign_Q118_to_Q119 : for i in 8 to 9 generate
  begin
    gen_qpll_inner : for j in 0 to 3 generate
    begin
      s_gth_gt_clk_in_arr(i*4+j).GTREFCLK0  <= s_refclk_F_0(0);
      s_gth_gt_clk_in_arr(i*4+j).GTREFCLK1  <= s_refclk_F_1(0);
      s_gth_gt_clk_in_arr(i*4+j).qpllclk    <= s_gth_common_clk_out_arr(i).QPLLCLK;
      s_gth_gt_clk_in_arr(i*4+j).qpllrefclk <= s_gth_common_clk_out_arr(i).QPLLREFCLK;
    end generate;
  end generate;

  gen_qpll_refclk_assign_Q218_to_Q219 : for i in 10 to 11 generate
  begin
    gen_qpll_inner : for j in 0 to 3 generate
    begin
      s_gth_gt_clk_in_arr(i*4+j).GTREFCLK0  <= s_refclk_B_0(3);
      s_gth_gt_clk_in_arr(i*4+j).GTREFCLK1  <= s_refclk_B_1(3);
      s_gth_gt_clk_in_arr(i*4+j).qpllclk    <= s_gth_common_clk_out_arr(i).QPLLCLK;
      s_gth_gt_clk_in_arr(i*4+j).qpllrefclk <= s_gth_common_clk_out_arr(i).QPLLREFCLK;
    end generate;
  end generate;

  gen_qpll_refclk_assign_Q215_to_Q217 : for i in 12 to 14 generate
  begin
    gen_qpll_inner : for j in 0 to 3 generate
    begin
      s_gth_gt_clk_in_arr(i*4+j).GTREFCLK0  <= s_refclk_B_0(2);
      s_gth_gt_clk_in_arr(i*4+j).GTREFCLK1  <= s_refclk_B_1(2);
      s_gth_gt_clk_in_arr(i*4+j).qpllclk    <= s_gth_common_clk_out_arr(i).QPLLCLK;
      s_gth_gt_clk_in_arr(i*4+j).qpllrefclk <= s_gth_common_clk_out_arr(i).QPLLREFCLK;
    end generate;
  end generate;

  gen_qpll_refclk_assign_Q213_to_Q214 : for i in 15 to 16 generate
  begin
    gen_qpll_inner : for j in 0 to 3 generate
    begin
      s_gth_gt_clk_in_arr(i*4+j).GTREFCLK0  <= s_refclk_B_0(1);
      s_gth_gt_clk_in_arr(i*4+j).GTREFCLK1  <= s_refclk_B_1(1);
      s_gth_gt_clk_in_arr(i*4+j).qpllclk    <= s_gth_common_clk_out_arr(i).QPLLCLK;
      s_gth_gt_clk_in_arr(i*4+j).qpllrefclk <= s_gth_common_clk_out_arr(i).QPLLREFCLK;
    end generate;
  end generate;

--------

  s_gth_rx_serial_arr <= gth_rx_serial_arr_i;
  gth_tx_serial_arr_o <= s_gth_tx_serial_arr;

  s_gth_gt_drp_in_arr <= gth_gt_drp_arr_i;
  gth_gt_drp_arr_o    <= s_gth_gt_drp_out_arr;

  s_gth_tx_ctrl_arr     <= gth_tx_ctrl_arr_i;
  gth_tx_status_arr_o   <= s_gth_tx_status_arr;
  s_gth_rx_ctrl_arr     <= gth_rx_ctrl_arr_i;
  s_gth_rx_ctrl_2_arr   <= gth_rx_ctrl_2_arr_i;
  gth_rx_status_arr_o   <= s_gth_rx_status_arr;
  s_gth_misc_ctrl_arr   <= gth_misc_ctrl_arr_i;
  gth_misc_status_arr_o <= s_gth_misc_status_arr;


  gen_gth_single : for n in 0 to (g_NUM_OF_GTH_GTs-1) generate
  begin

-- From Xilinx UG476
-- The CPLLREFCLKSEL port is required when multiple reference clock sources are 
-- connected to this multiplexer. A single reference clock is most commonly used. 
-- In this case, the CPLLREFCLKSEL port can be tied to 3'b001, and the Xilinx software 
-- tools handle the complexity of the multiplexers and associated routing.
    s_gth_cpll_ctrl_arr(n).CPLLREFCLKSEL  <= "001";  -- Let the tool figure out proper reference clock routing
    s_gth_cpll_ctrl_arr(n).cplllockdetclk <= clk_stable_i;

    s_gth_gt_clk_in_arr(n).rxusrclk  <= s_clk_gth_rx_usrclk_arr(n);
    s_gth_gt_clk_in_arr(n).rxusrclk2 <= s_clk_gth_rx_usrclk_arr(n);
    s_gth_gt_clk_in_arr(n).txusrclk  <= s_clk_gth_tx_usrclk_arr(n);
    s_gth_gt_clk_in_arr(n).txusrclk2 <= s_clk_gth_tx_usrclk2_arr(n);


    gen_gth_3p2g : if c_gth_config_arr(n).gth_link_type = gth_3p2g generate

      s_gth_tx_data_arr(n) <= gth_tx_data_arr_i(n);
      gth_rx_data_arr_o(n) <= s_gth_rx_data_arr(n);
      s_gth_rx_status_arr(n).rxnotintable(1 downto 0) <= s_gth_rx_data_arr(n).rxnotintable(1 downto 0);
      s_gth_rx_status_arr(n).rxnotintable(3 downto 2) <= "00";
      s_gth_rx_status_arr(n).rxdisperr(1 downto 0) <= s_gth_rx_data_arr(n).rxdisperr(1 downto 0);
      s_gth_rx_status_arr(n).rxdisperr(3 downto 2) <= "00";

      i_gth_single_3p2g : entity work.gth_single_3p2g
        generic map
        (
          g_REFCLK_01 => 0,
                                        -- Simulation attributes
          g_GT_SIM_GTRESET_SPEEDUP => g_GT_SIM_GTRESET_SPEEDUP
          )
        port map
        (
          gth_rx_serial_i => s_gth_rx_serial_arr(n),
          gth_tx_serial_o => s_gth_tx_serial_arr(n),
          gth_gt_clk_i    => s_gth_gt_clk_in_arr(n),
          gth_gt_clk_o    => s_gth_gt_clk_out_arr(n),

          gth_cpll_ctrl_i   => s_gth_cpll_ctrl_arr(n),
          gth_cpll_init_i   => s_gth_cpll_init_arr(n),
          gth_cpll_status_o => s_gth_cpll_status_arr(n),

          gth_gt_drp_i      => s_gth_gt_drp_in_arr(n),
          gth_gt_drp_o      => s_gth_gt_drp_out_arr(n),
          gth_tx_ctrl_i     => s_gth_tx_ctrl_arr(n),
          gth_tx_init_i     => s_gth_tx_init_arr(n),
          gth_tx_status_o   => s_gth_tx_status_arr(n),
          gth_rx_ctrl_i     => s_gth_rx_ctrl_arr(n),
          gth_rx_ctrl_2_i   => s_gth_rx_ctrl_2_arr(n),
          gth_rx_init_i     => s_gth_rx_init_arr(n),
          gth_rx_status_o   => s_gth_rx_status_arr(n),
          gth_misc_ctrl_i   => s_gth_misc_ctrl_arr(n),
          gth_misc_status_o => s_gth_misc_status_arr(n),
          gth_tx_data_i     => s_gth_tx_data_arr(n),
          gth_rx_data_o     => s_gth_rx_data_arr(n)
          );
        
    end generate;


    gen_gth_4p8g : if c_gth_config_arr(n).gth_link_type = gth_4p8g generate

      -------------  GT txdata_i Assignments for 20 bit datapath  -------  
      s_gth_tx_data_arr(n).txdata(31 downto 0)  <=       gth_tx_data_arr_i(n).txdata(37 downto 30) &
                                                         gth_tx_data_arr_i(n).txdata(27 downto 20) &
                                                         gth_tx_data_arr_i(n).txdata(17 downto 10) &
                                                         gth_tx_data_arr_i(n).txdata(7 downto 0);

      s_gth_tx_data_arr(n).txchardispmode(3 downto 0) <= gth_tx_data_arr_i(n).txdata(39) &
                                                         gth_tx_data_arr_i(n).txdata(29) &
                                                         gth_tx_data_arr_i(n).txdata(19) &
                                                         gth_tx_data_arr_i(n).txdata(9);

      s_gth_tx_data_arr(n).txchardispval(3 downto 0) <=  gth_tx_data_arr_i(n).txdata(38) &
                                                         gth_tx_data_arr_i(n).txdata(28) &
                                                         gth_tx_data_arr_i(n).txdata(18) &
                                                         gth_tx_data_arr_i(n).txdata(8);

      --s_gth_tx_data_arr(n).txcharisk <= gth_tx_data_arr_i(n).txcharisk;

      -------------  GT RXDATA Assignments for 20 bit datapath  -------  

      gth_rx_data_arr_o(n).rxdata(39 downto 0) <=        s_gth_rx_data_arr(n).rxdisperr(3) &
                                                         s_gth_rx_data_arr(n).rxcharisk(3) &
                                                         s_gth_rx_data_arr(n).rxdata(31 downto 24) &
                                                         s_gth_rx_data_arr(n).rxdisperr(2) &
                                                         s_gth_rx_data_arr(n).rxcharisk(2) &
                                                         s_gth_rx_data_arr(n).rxdata(23 downto 16) &
                                                         s_gth_rx_data_arr(n).rxdisperr(1) &
                                                         s_gth_rx_data_arr(n).rxcharisk(1) &
                                                         s_gth_rx_data_arr(n).rxdata(15 downto 8) &
                                                         s_gth_rx_data_arr(n).rxdisperr(0) &
                                                         s_gth_rx_data_arr(n).rxcharisk(0) &
                                                         s_gth_rx_data_arr(n).rxdata(7 downto 0);


--      gth_rx_data_arr_o(n).rxbyteisaligned <= s_gth_rx_data_arr(n).rxbyteisaligned;
--      gth_rx_data_arr_o(n).rxbyterealign   <= s_gth_rx_data_arr(n).rxbyterealign;
--      gth_rx_data_arr_o(n).rxcommadet      <= s_gth_rx_data_arr(n).rxcommadet;
--      gth_rx_data_arr_o(n).rxdisperr       <= s_gth_rx_data_arr(n).rxdisperr;
--      gth_rx_data_arr_o(n).rxnotintable    <= s_gth_rx_data_arr(n).rxnotintable;
--      gth_rx_data_arr_o(n).rxchariscomma   <= s_gth_rx_data_arr(n).rxchariscomma;
--      gth_rx_data_arr_o(n).rxcharisk       <= s_gth_rx_data_arr(n).rxcharisk;

      i_gth_single_4p8g : entity work.gth_single_4p8g
        generic map
        (
          g_REFCLK_01 => 0,
                                        -- Simulation attributes
          g_GT_SIM_GTRESET_SPEEDUP => g_GT_SIM_GTRESET_SPEEDUP
          )
        port map
        (
          gth_rx_serial_i => s_gth_rx_serial_arr(n),
          gth_tx_serial_o => s_gth_tx_serial_arr(n),
          gth_gt_clk_i    => s_gth_gt_clk_in_arr(n),
          gth_gt_clk_o    => s_gth_gt_clk_out_arr(n),

          gth_cpll_ctrl_i   => s_gth_cpll_ctrl_arr(n),
          gth_cpll_init_i   => s_gth_cpll_init_arr(n),
          gth_cpll_status_o => s_gth_cpll_status_arr(n),

          gth_gt_drp_i      => s_gth_gt_drp_in_arr(n),
          gth_gt_drp_o      => s_gth_gt_drp_out_arr(n),
          gth_tx_ctrl_i     => s_gth_tx_ctrl_arr(n),
          gth_tx_init_i     => s_gth_tx_init_arr(n),
          gth_tx_status_o   => s_gth_tx_status_arr(n),
          gth_rx_ctrl_i     => s_gth_rx_ctrl_arr(n),
          gth_rx_ctrl_2_i   => s_gth_rx_ctrl_2_arr(n),
          gth_rx_init_i     => s_gth_rx_init_arr(n),
          gth_rx_status_o   => s_gth_rx_status_arr(n),
          gth_misc_ctrl_i   => s_gth_misc_ctrl_arr(n),
          gth_misc_status_o => s_gth_misc_status_arr(n),
          gth_tx_data_i     => s_gth_tx_data_arr(n),
          gth_rx_data_o     => s_gth_rx_data_arr(n)
          );

    end generate;
    
    gen_gth_10p24g : if c_gth_config_arr(n).gth_link_type = gth_10p24g generate
      
      gth_rx_data_arr_o(n).rxdata <= s_gth_rx_data_arr(n).rxdata;
      s_gth_tx_data_arr(n).txdata <= gth_tx_data_arr_i(n).txdata;
            
      i_gth_single_10p24g : entity work.gth_single_10p24g
        generic map
        (
          g_USE_QPLL => TRUE,
          g_REFCLK_01 => 1,
          g_RX_BUS_WIDTH => 32,
          g_TX_BUS_WIDTH => 32,
                                        -- Simulation attributes
          g_GT_SIM_GTRESET_SPEEDUP => g_GT_SIM_GTRESET_SPEEDUP
          )
        port map
        (
          gth_rx_serial_i => s_gth_rx_serial_arr(n),
          gth_tx_serial_o => s_gth_tx_serial_arr(n),
          gth_gt_clk_i    => s_gth_gt_clk_in_arr(n),
          gth_gt_clk_o    => s_gth_gt_clk_out_arr(n),

          gth_cpll_ctrl_i   => s_gth_cpll_ctrl_arr(n),
          gth_cpll_init_i   => s_gth_cpll_init_arr(n),
          gth_cpll_status_o => s_gth_cpll_status_arr(n),

          gth_gt_drp_i      => s_gth_gt_drp_in_arr(n),
          gth_gt_drp_o      => s_gth_gt_drp_out_arr(n),
          gth_tx_ctrl_i     => s_gth_tx_ctrl_arr(n),
          gth_tx_init_i     => s_gth_tx_init_arr(n),
          gth_tx_status_o   => s_gth_tx_status_arr(n),
          gth_rx_ctrl_i     => s_gth_rx_ctrl_arr(n),
          gth_rx_ctrl_2_i   => s_gth_rx_ctrl_2_arr(n),
          gth_rx_init_i     => s_gth_rx_init_arr(n),
          gth_rx_status_o   => s_gth_rx_status_arr(n),
          gth_misc_ctrl_i   => s_gth_misc_ctrl_arr(n),
          gth_misc_status_o => s_gth_misc_status_arr(n),
          gth_tx_data_i     => s_gth_tx_data_arr(n),
          gth_rx_data_o     => s_gth_rx_data_arr(n)
          );        
    end generate;

    gen_gth_tx_10p24g_rx_3p2g : if c_gth_config_arr(n).gth_link_type = gth_tx_10p24g_rx_3p2g generate
      
      gth_rx_data_arr_o(n) <= s_gth_rx_data_arr(n);
      s_gth_rx_status_arr(n).rxnotintable(1 downto 0) <= s_gth_rx_data_arr(n).rxnotintable(1 downto 0);
      s_gth_rx_status_arr(n).rxnotintable(3 downto 2) <= "00";
      s_gth_rx_status_arr(n).rxdisperr(1 downto 0) <= s_gth_rx_data_arr(n).rxdisperr(1 downto 0);
      s_gth_rx_status_arr(n).rxdisperr(3 downto 2) <= "00";
            
      s_gth_tx_data_arr(n).txdata <= gth_tx_data_arr_i(n).txdata;
            
      i_gth_single_tx_10p24g_rx_3p2g : entity work.gth_single_tx_10p24g_rx_3p2g
        generic map
        (
          g_RX_REFCLK_01 => 0,
          g_TX_BUS_WIDTH => 64,
                                        -- Simulation attributes
          g_GT_SIM_GTRESET_SPEEDUP => g_GT_SIM_GTRESET_SPEEDUP
          )
        port map
        (
          gth_rx_serial_i => s_gth_rx_serial_arr(n),
          gth_tx_serial_o => s_gth_tx_serial_arr(n),
          gth_gt_clk_i    => s_gth_gt_clk_in_arr(n),
          gth_gt_clk_o    => s_gth_gt_clk_out_arr(n),

          gth_cpll_ctrl_i   => s_gth_cpll_ctrl_arr(n),
          gth_cpll_init_i   => s_gth_cpll_init_arr(n),
          gth_cpll_status_o => s_gth_cpll_status_arr(n),

          gth_gt_drp_i      => s_gth_gt_drp_in_arr(n),
          gth_gt_drp_o      => s_gth_gt_drp_out_arr(n),
          gth_tx_ctrl_i     => s_gth_tx_ctrl_arr(n),
          gth_tx_init_i     => s_gth_tx_init_arr(n),
          gth_tx_status_o   => s_gth_tx_status_arr(n),
          gth_rx_ctrl_i     => s_gth_rx_ctrl_arr(n),
          gth_rx_ctrl_2_i   => s_gth_rx_ctrl_2_arr(n),
          gth_rx_init_i     => s_gth_rx_init_arr(n),
          gth_rx_status_o   => s_gth_rx_status_arr(n),
          gth_misc_ctrl_i   => s_gth_misc_ctrl_arr(n),
          gth_misc_status_o => s_gth_misc_status_arr(n),
          gth_tx_data_i     => s_gth_tx_data_arr(n),
          gth_rx_data_o     => s_gth_rx_data_arr(n)
          );        
    end generate;

    gen_gth_2p56g : if c_gth_config_arr(n).gth_link_type = gth_2p56g generate

      gth_rx_data_arr_o(n).rxdata <= s_gth_rx_data_arr(n).rxdata;
      s_gth_tx_data_arr(n).txdata <= gth_tx_data_arr_i(n).txdata;

      i_gth_single_2p56g : entity work.gth_single_2p56g
        generic map
        (
          g_REFCLK_01 => 1,
                                        -- Simulation attributes
          g_GT_SIM_GTRESET_SPEEDUP => g_GT_SIM_GTRESET_SPEEDUP
          )
        port map
        (
          gth_rx_serial_i => s_gth_rx_serial_arr(n),
          gth_tx_serial_o => s_gth_tx_serial_arr(n),
          gth_gt_clk_i    => s_gth_gt_clk_in_arr(n),
          gth_gt_clk_o    => s_gth_gt_clk_out_arr(n),

          gth_cpll_ctrl_i   => s_gth_cpll_ctrl_arr(n),
          gth_cpll_init_i   => s_gth_cpll_init_arr(n),
          gth_cpll_status_o => s_gth_cpll_status_arr(n),

          gth_gt_drp_i      => s_gth_gt_drp_in_arr(n),
          gth_gt_drp_o      => s_gth_gt_drp_out_arr(n),
          gth_tx_ctrl_i     => s_gth_tx_ctrl_arr(n),
          gth_tx_init_i     => s_gth_tx_init_arr(n),
          gth_tx_status_o   => s_gth_tx_status_arr(n),
          gth_rx_ctrl_i     => s_gth_rx_ctrl_arr(n),
          gth_rx_ctrl_2_i   => s_gth_rx_ctrl_2_arr(n),
          gth_rx_init_i     => s_gth_rx_init_arr(n),
          gth_rx_status_o   => s_gth_rx_status_arr(n),
          gth_misc_ctrl_i   => s_gth_misc_ctrl_arr(n),
          gth_misc_status_o => s_gth_misc_status_arr(n),
          gth_tx_data_i     => s_gth_tx_data_arr(n),
          gth_rx_data_o     => s_gth_rx_data_arr(n)
          );        
    end generate;
    
  end generate;


  s_gth_common_drp_in_arr <= gth_common_drp_arr_i;
  gth_common_drp_arr_o    <= s_gth_common_drp_out_arr;

  s_gth_common_clk_in_arr(0).GTREFCLK1 <= s_refclk_F_1(3);
  s_gth_common_clk_in_arr(1).GTREFCLK1 <= s_refclk_F_1(3);

  s_gth_common_clk_in_arr(2).GTREFCLK1 <= s_refclk_F_1(2);
  s_gth_common_clk_in_arr(3).GTREFCLK1 <= s_refclk_F_1(2);
  s_gth_common_clk_in_arr(4).GTREFCLK1 <= s_refclk_F_1(2);

  s_gth_common_clk_in_arr(5).GTREFCLK1 <= s_refclk_F_1(1);
  s_gth_common_clk_in_arr(6).GTREFCLK1 <= s_refclk_F_1(1);
  s_gth_common_clk_in_arr(7).GTREFCLK1 <= s_refclk_F_1(1);

  s_gth_common_clk_in_arr(8).GTREFCLK1 <= s_refclk_F_1(0);
  s_gth_common_clk_in_arr(9).GTREFCLK1 <= s_refclk_F_1(0);


  s_gth_common_clk_in_arr(10).GTREFCLK1 <= s_refclk_B_1(3);
  s_gth_common_clk_in_arr(11).GTREFCLK1 <= s_refclk_B_1(3);

  s_gth_common_clk_in_arr(12).GTREFCLK1 <= s_refclk_B_1(2);
  s_gth_common_clk_in_arr(13).GTREFCLK1 <= s_refclk_B_1(2);
  s_gth_common_clk_in_arr(14).GTREFCLK1 <= s_refclk_B_1(2);

  s_gth_common_clk_in_arr(15).GTREFCLK1 <= s_refclk_B_1(1);
  s_gth_common_clk_in_arr(16).GTREFCLK1 <= s_refclk_B_1(1);

  gth_common_status_arr_o <= s_gth_common_status_arr;
  gth_cpll_status_arr_o   <= s_gth_cpll_status_arr;


  gen_gth_common : for n in 0 to (g_NUM_OF_GTH_GTs/4-1) generate
  begin

    s_gth_common_ctrl_arr(n).QPLLRESET <= gth_common_reset_i(n);

    -- From Xilinx UG476
    -- The QPLLREFCLKSEL port is required when multiple reference clock sources are 
    -- connected to this multiplexer. A single reference clock is most commonly used. 
    -- In this case, the QPLLREFCLKSEL port can be tied to 3'b001, and the Xilinx software 
    -- tools handle the complexity of the multiplexers and associated routing.
    s_gth_common_ctrl_arr(n).QPLLREFCLKSEL <= "001";  -- Let the tool figure out proper reference clock routing

    i_gth_common : entity work.gth_common
      generic map
      (
                                        -- Simulation attributes
        g_QPLL_FBDIV_TOP => 32,
        g_REFCLK_01 => 1,
        g_GT_SIM_GTRESET_SPEEDUP => g_GT_SIM_GTRESET_SPEEDUP,  -- Set to "true" to speed up sim reset
        g_STABLE_CLOCK_PERIOD    => g_STABLE_CLOCK_PERIOD  -- Period of the stable clock driving this state-machine, unit is [ns]
        )
      port map
      (
        clk_stable_i        => clk_stable_i,
        gth_common_clk_i    => s_gth_common_clk_in_arr(n),
        gth_common_clk_o    => s_gth_common_clk_out_arr(n),
        gth_common_ctrl_i   => s_gth_common_ctrl_arr(n),
        gth_common_status_o => s_gth_common_status_arr(n),
        gth_common_drp_i    => s_gth_common_drp_in_arr(n),
        gth_common_drp_o    => s_gth_common_drp_out_arr(n)
        );

  end generate;

  gen_gt_resetfsm : for i in 0 to (g_NUM_OF_GTH_GTs/4-1) generate
  begin
    gen_txresetfsm_inner : for j in 0 to 3 generate
    begin

      i_gt_txresetfsm : entity work.gth_single_TX_STARTUP_FSM

        generic map(
          EXAMPLE_SIMULATION     => g_EXAMPLE_SIMULATION,
          STABLE_CLOCK_PERIOD    => g_STABLE_CLOCK_PERIOD,  -- Period of the stable clock driving this state-machine, unit is [ns]
          RETRY_COUNTER_BITWIDTH => 8,
          TX_QPLL_USED           => (c_gth_config_arr(i*4+j).gth_link_type = gth_10p24g) or (c_gth_config_arr(i*4+j).gth_link_type = gth_tx_10p24g_rx_3p2g),  -- the TX and RX Reset FSMs must
          RX_QPLL_USED           => c_gth_config_arr(i*4+j).gth_link_type = gth_10p24g,  -- share these two generic values
          PHASE_ALIGNMENT_MANUAL => true  -- Decision if a manual phase-alignment is necessary or the automatic
                                          -- is enough. For single-lane applications the automatic alignment is
                                          -- sufficient
          )
        port map (
          STABLE_CLOCK      => clk_stable_i,
          TXUSERCLK         => s_clk_gth_tx_usrclk_arr(i*4+j),
          SOFT_RESET        => gth_gt_txreset_i(i*4+j),
          QPLLREFCLKLOST    => s_gth_common_status_arr(i).QPLLREFCLKLOST,
          CPLLREFCLKLOST    => '0',
          QPLLLOCK          => s_gth_common_status_arr(i).QPLLLOCK,
          CPLLLOCK          => s_gth_cpll_status_arr(i*4+j).CPLLLOCK,
          TXRESETDONE       => s_gth_tx_status_arr(i*4+j).txresetdone,
          MMCM_LOCK         => s_tx_startup_fsm_mmcm_lock(i*4+j),
          GTTXRESET         => s_gth_tx_init_arr(i*4+j).gttxreset,
          MMCM_RESET        => s_tx_startup_fsm_mmcm_reset(i*4+j),
          QPLL_RESET        => open,
          CPLL_RESET        => open,
          TX_FSM_RESET_DONE => gth_gt_txreset_done_o(i*4+j),
          TXUSERRDY         => s_gth_tx_init_arr(i*4+j).txuserrdy,
          RUN_PHALIGNMENT   => s_gth_tx_run_phalignment(i*4+j),
          RESET_PHALIGNMENT => s_gth_tx_rst_phalignment(i*4+j),
          PHALIGNMENT_DONE  => s_gth_tx_run_phalignment_done(i*4+j),
          RETRY_COUNTER     => open
          );

      i_gt_rxresetfsm : entity work.gth_single_RX_STARTUP_FSM

        generic map(
          EXAMPLE_SIMULATION     => g_EXAMPLE_SIMULATION,
          EQ_MODE                => "LPM",  --Rx Equalization Mode - Set to DFE or LPM
          STABLE_CLOCK_PERIOD    => g_STABLE_CLOCK_PERIOD,  --Period of the stable clock driving this state-machine, unit is [ns]
          RETRY_COUNTER_BITWIDTH => 8,
          TX_QPLL_USED           => (c_gth_config_arr(i*4+j).gth_link_type = gth_10p24g) or (c_gth_config_arr(i*4+j).gth_link_type = gth_tx_10p24g_rx_3p2g),  -- the TX and RX Reset FSMs must
          RX_QPLL_USED           => c_gth_config_arr(i*4+j).gth_link_type = gth_10p24g,  -- share these two generic values
          PHASE_ALIGNMENT_MANUAL => false  -- Decision if a manual phase-alignment is necessary or the automatic
                                           -- is enough. For single-lane applications the automatic alignment is
                                           -- sufficient
          )
        port map (
          STABLE_CLOCK             => clk_stable_i,
          RXUSERCLK                => s_clk_gth_rx_usrclk_arr(i*4+j),
          SOFT_RESET               => gth_gt_rxreset_i(i*4+j),
          DONT_RESET_ON_DATA_ERROR => '1',
          RXPMARESETDONE           => s_gth_rx_status_arr(i*4+j).RXPMARESETDONE,
          RXOUTCLK                 => s_gth_gt_clk_out_arr(i*4+j).rxoutclk,
          QPLLREFCLKLOST           => s_gth_common_status_arr(i).QPLLREFCLKLOST,
          CPLLREFCLKLOST           => s_gth_cpll_status_arr(i*4+j).CPLLREFCLKLOST,
          QPLLLOCK                 => s_gth_common_status_arr(i).QPLLLOCK,
          CPLLLOCK                 => s_gth_cpll_status_arr(i*4+j).CPLLLOCK,
          RXRESETDONE              => s_gth_rx_status_arr(i*4+j).rxresetdone,
          MMCM_LOCK                => '1',
          RECCLK_STABLE            => s_gth_recclk_stable(i*4+j),
          RECCLK_MONITOR_RESTART   => '0',
          DATA_VALID               => '1',
          TXUSERRDY                => '1',
          GTRXRESET                => s_gth_rx_init_arr(i*4+j).gtrxreset,
          MMCM_RESET               => open,
          QPLL_RESET               => open,
          CPLL_RESET               => open,
          RX_FSM_RESET_DONE        => gth_gt_rxreset_done_o(i*4+j),
          RXUSERRDY                => s_gth_rx_init_arr(i*4+j).rxuserrdy,
          RUN_PHALIGNMENT          => s_gth_rx_run_phalignment(i*4+j),
          RESET_PHALIGNMENT        => s_gth_rx_rst_phalignment(i*4+j),
          PHALIGNMENT_DONE         => s_gth_rx_run_phalignment_done(i*4+j),
          RXDFEAGCHOLD             => s_gth_rx_init_arr(i*4+j).RXDFEAGCHOLD,
          RXDFELFHOLD              => s_gth_rx_init_arr(i*4+j).RXDFELFHOLD,
          RXLPMLFHOLD              => s_gth_rx_init_arr(i*4+j).RXLPMLFHOLD,
          RXLPMHFHOLD              => s_gth_rx_init_arr(i*4+j).RXLPMHFHOLD,
          RETRY_COUNTER            => open
          );

      s_gth_rx_init_arr(i*4+j).rxdfeagcovrden  <= '0';
      s_gth_rx_init_arr(i*4+j).rxdfelpmreset   <= '0';
      s_gth_rx_init_arr(i*4+j).rxlpmlfklovrden <= '0';
      s_gth_rx_init_arr(i*4+j).RXDFELFOVRDEN   <= '0';
      s_gth_rx_init_arr(i*4+j).RXLPMHFOVRDEN   <= '0';

      s_gth_cpll_init_arr(i*4+j).cpllreset <= gth_cpll_reset_arr_i(i*4+j);

      --------------------------------------------------------------------------
      gt_cdrlock_timeout : process(clk_stable_i)
      begin
        if rising_edge(clk_stable_i) then
          if(gth_gt_rxreset_i(i*4+j) = '1') then
            s_gth_rx_cdrlocked(i*4+j)       <= '0';
            s_gth_rx_cdrlock_counter(i*4+j) <= 0;
          elsif (s_gth_rx_cdrlock_counter(i*4+j) = C_WAIT_TIME_CDRLOCK) then
            s_gth_rx_cdrlocked(i*4+j)       <= '1';
            s_gth_rx_cdrlock_counter(i*4+j) <= s_gth_rx_cdrlock_counter(i*4+j);
          else
            s_gth_rx_cdrlock_counter(i*4+j) <= s_gth_rx_cdrlock_counter(i*4+j) + 1;
          end if;
        end if;
      end process;

      s_gth_recclk_stable(i*4+j) <= s_gth_rx_cdrlocked(i*4+j);

      --------------------------- TX Buffer Bypass Logic --------------------
      -- The TX SYNC Module drives the ports needed to Bypass the TX Buffer.
      -- Include the TX SYNC module in your own design if TX Buffer is bypassed.

      --Manual
      i_gth_single_tx_manual_phase_align : entity work.gth_single_TX_MANUAL_PHASE_ALIGN
        generic map
        (
          NUMBER_OF_LANES => 1,
          MASTER_LANE_ID  => 0
          )
        port map
        (
          STABLE_CLOCK         => clk_stable_i,
          RESET_PHALIGNMENT    => s_gth_tx_rst_phalignment(i*4+j),  --TODO
          RUN_PHALIGNMENT      => s_gth_tx_run_phalignment(i*4+j),  --TODO
          PHASE_ALIGNMENT_DONE => s_gth_tx_run_phalignment_done(i*4+j),
          TXDLYSRESET(0)       => s_gth_tx_init_arr(i*4+j).TXDLYSRESET,
          TXDLYSRESETDONE(0)   => s_gth_tx_status_arr(i*4+j).TXDLYSRESETDONE,
          TXPHINIT(0)          => s_gth_tx_init_arr(i*4+j).TXPHINIT,
          TXPHINITDONE(0)      => s_gth_tx_status_arr(i*4+j).TXPHINITDONE,
          TXPHALIGN(0)         => s_gth_tx_init_arr(i*4+j).TXPHALIGN,
          TXPHALIGNDONE(0)     => s_gth_tx_status_arr(i*4+j).TXPHALIGNDONE,
          TXDLYEN(0)           => s_gth_tx_init_arr(i*4+j).TXDLYEN
          );
      s_gth_tx_init_arr(i*4+j).TXPHALIGNEN  <= '1';
      s_gth_tx_init_arr(i*4+j).TXPHDLYRESET <= '0';

      i_rx_auto_phase_align : entity work.gth_single_AUTO_PHASE_ALIGN
        port map (
          STABLE_CLOCK         => clk_stable_i,
          RUN_PHALIGNMENT      => s_gth_rx_run_phalignment(i*4+j),
          PHASE_ALIGNMENT_DONE => s_gth_rx_run_phalignment_done(i*4+j),
          PHALIGNDONE          => s_gth_rx_status_arr(i*4+j).RXSYNCDONE,
          DLYSRESET            => s_gth_rx_init_arr(i*4+j).RXDLYSRESET,
          DLYSRESETDONE        => s_gth_rx_status_arr(i*4+j).RXDLYSRESETDONE,
          RECCLKSTABLE         => s_gth_recclk_stable(i*4+j)
          );

      s_gth_rx_init_arr(i*4+j).RXCDRHOLD    <= '0';
      s_gth_rx_init_arr(i*4+j).RXPHDLYRESET <= '0';
      s_gth_rx_init_arr(i*4+j).RXPHALIGNEN  <= '0';
      s_gth_rx_init_arr(i*4+j).RXDLYEN      <= '0';
      s_gth_rx_init_arr(i*4+j).RXPHALIGN    <= '0';
      s_gth_rx_init_arr(i*4+j).RXSYNCMODE   <= '1';
      s_gth_rx_init_arr(i*4+j).RXSYNCIN     <= '0';
      s_gth_rx_init_arr(i*4+j).RXSYNCALLIN  <= s_gth_rx_status_arr(i*4+j).RXPHALIGNDONE;


    end generate;
  end generate;

end gth_wrapper_arch;
--============================================================================
--                                                            Architecture end
--============================================================================
