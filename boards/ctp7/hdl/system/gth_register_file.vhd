-------------------------------------------------------------------------------
--                                                                            
--       Unit Name: gth_register_file                                            
--                                                                            
--     Description: 
--
--                                                                            
-------------------------------------------------------------------------------
--                                                                            
--           Notes:                                                           
--                                                                            
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library UNISIM;
use UNISIM.vcomponents.all;

library work;
use work.ctp7_utils_pkg.all;
use work.gth_pkg.all;
use work.system_package.all;

--============================================================================
--                                                          Entity declaration
--============================================================================
entity gth_register_file is
  generic
    (
      g_NUM_OF_GTH_GTs     : integer := 64;
      g_NUM_OF_GTH_COMMONs : integer := 16
      );
  port (

    BRAM_CTRL_GTH_REG_FILE_en   : in  std_logic;
    BRAM_CTRL_GTH_REG_FILE_dout : out std_logic_vector (31 downto 0);
    BRAM_CTRL_GTH_REG_FILE_din  : in  std_logic_vector (31 downto 0);
    BRAM_CTRL_GTH_REG_FILE_we   : in  std_logic_vector (3 downto 0);
    BRAM_CTRL_GTH_REG_FILE_addr : in  std_logic_vector (16 downto 0);
    BRAM_CTRL_GTH_REG_FILE_clk  : in  std_logic;
    BRAM_CTRL_GTH_REG_FILE_rst  : in  std_logic;

    gth_common_reset_o      : out std_logic_vector(g_NUM_OF_GTH_COMMONs-1 downto 0);
    gth_common_status_arr_i : in  t_gth_common_status_arr(g_NUM_OF_GTH_COMMONs-1 downto 0);

    gth_cpll_status_arr_i : in t_gth_cpll_status_arr(g_NUM_OF_GTH_GTs-1 downto 0);

    gth_gt_txreset_o    : out std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
    gth_gt_rxreset_o    : out std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
    
    gth_cpll_init_arr_o : out t_gth_cpll_init_arr(g_NUM_OF_GTH_GTs-1 downto 0);

    gth_gt_txreset_done_i : in std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
    gth_gt_rxreset_done_i : in std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);

    gth_tx_ctrl_arr_o   : out t_gth_tx_ctrl_arr(g_NUM_OF_GTH_GTs-1 downto 0);
    gth_tx_status_arr_i : in  t_gth_tx_status_arr(g_NUM_OF_GTH_GTs-1 downto 0);

    gth_rx_ctrl_arr_o   : out t_gth_rx_ctrl_arr(g_NUM_OF_GTH_GTs-1 downto 0);
    gth_rx_status_arr_i : in  t_gth_rx_status_arr(g_NUM_OF_GTH_GTs-1 downto 0);

    gth_misc_ctrl_arr_o   : out t_gth_misc_ctrl_arr(g_NUM_OF_GTH_GTs-1 downto 0);
    gth_misc_status_arr_i : in  t_gth_misc_status_arr(g_NUM_OF_GTH_GTs-1 downto 0);

    clk_gth_tx_usrclk_arr_i : in std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
    clk_gth_rx_usrclk_arr_i : in std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0)
    );
end gth_register_file;

--============================================================================
--                                                        Architecture section
--============================================================================
architecture gth_register_file_arch of gth_register_file is

--============================================================================
--                                                         Signal declarations
--============================================================================
  signal s_reg_qppl_rst        : std_logic_vector(g_NUM_OF_GTH_COMMONs-1 downto 0);
  signal s_reg_qppl_lock       : std_logic_vector(g_NUM_OF_GTH_COMMONs-1 downto 0);
  signal s_reg_qppl_refclklost : std_logic_vector(g_NUM_OF_GTH_COMMONs-1 downto 0);

  signal s_tx_reset_done : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_rx_reset_done : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_tx_reset      : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_rx_reset      : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_cpll_reset    : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);

  signal s_gth_loopback : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_rx_pd        : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_tx_pd        : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_rx_polarity  : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_tx_polarity  : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_tx_inhibit   : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_rx_lpmen     : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_cpll_pd      : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);

  signal s_reg_cplllock       : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_reg_cpllrefclklost : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);

  signal s_rx_not_in_table  : t_slv_arr_2(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_rx_disperr       : t_slv_arr_2(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_prbs_err         : std_logic_vector(g_NUM_OF_GTH_GTs-1 downto 0);

  constant C_GTH_STAT_CH0_ADDR              : integer := 0;
  constant C_GTH_RST_CH0_ADDR               : integer := 4;
  constant C_GTH_CTRL_CH0_ADDR              : integer := 8;
  constant C_GTH_PRBS_SEL_CH0_ADDR          : integer := 12;
  constant C_GTH_PRBS_CNT_CH0_ADDR          : integer := 16;
  constant C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR : integer := 20;
  constant C_GTH_RX_DISPERR_CNT_CH0_ADDR    : integer := 24;


  constant C_QPLL_STAT_CH0_ADDR : integer := 16#10000#;
  constant C_QPLL_RST_CH0_ADDR  : integer := 16#10004#;

  constant C_GTH_CH_to_CH_ADDR_OFFSET  : integer := 4 * 64;
  constant C_QPLL_CH_to_CH_ADDR_OFFSET : integer := 4 * 64;

  signal s_gth_stat_reg : t_slv_arr_32(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_gth_rst_reg  : t_slv_arr_32(g_NUM_OF_GTH_GTs-1 downto 0);

  signal s_gth_ctrl_reg : t_slv_arr_32(g_NUM_OF_GTH_GTs-1 downto 0) := (others => (x"00000003"));  -- RXPD = 1, TXPD = 1 

--  signal s_gth_ctrl_reg : t_slv_arr_32(0 to g_NUM_OF_GTH_GTs-1) := (
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000048"),                      --11
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040"),
--    (x"00000040")
--    );

  signal s_gth_prbs_sel_reg         : t_slv_arr_32(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_gth_prbs_cnt_reg         : t_slv_arr_32(g_NUM_OF_GTH_GTs-1 downto 0);
  signal s_gth_prbs_cnt_rst_reg     : t_slv_arr_32(g_NUM_OF_GTH_GTs-1 downto 0);

  signal s_qpll_stat_reg            : t_slv_arr_32(g_NUM_OF_GTH_COMMONs-1 downto 0);
  signal s_qpll_rst_reg             : t_slv_arr_32(g_NUM_OF_GTH_COMMONs-1 downto 0);

  signal s_gth_rxnotintable_cnt_reg : t_slv_arr_32(g_NUM_OF_GTH_GTs-1 downto 0) := (others => (others => '0'));
  signal s_gth_rxdisperr_cnt_reg    : t_slv_arr_32(g_NUM_OF_GTH_GTs-1 downto 0) := (others => (others => '0'));
  signal s_gth_rxerror_rst_reg      : t_slv_arr_32(g_NUM_OF_GTH_GTs-1 downto 0);

--============================================================================
--                                                          Architecture begin
--============================================================================

begin

  gen_gth_rx_usrclk_cnt : for i in 0 to g_NUM_OF_GTH_GTs-1 generate

    -- PRBS error counters
    g_linu_not_null : if c_gth_config_arr(i).gth_link_type /= gth_null generate
      process(clk_gth_rx_usrclk_arr_i(i))is
      begin
        if (rising_edge(clk_gth_rx_usrclk_arr_i(i))) then
          s_prbs_err(i) <= gth_rx_status_arr_i(i).rxprbserr;
      
          if (s_gth_prbs_cnt_rst_reg(i)(0) = '1') then
            s_gth_prbs_cnt_reg(i) <= (others => '0');
          elsif (s_prbs_err(i) = '1' and s_gth_prbs_cnt_reg(i) /= x"FFFFFFFF") then
            s_gth_prbs_cnt_reg(i) <= std_logic_vector(unsigned(s_gth_prbs_cnt_reg(i)) + 1);
          end if;
        end if;
      end process;
    end generate;
  
    -- 8b10b error counters
    g_8b10b_gth : if (c_gth_config_arr(i).gth_link_type = gth_3p2g) or (c_gth_config_arr(i).gth_link_type = gth_tx_10p24g_rx_3p2g) or (c_gth_config_arr(i).gth_link_type = gth_9p6g) generate
      process(clk_gth_rx_usrclk_arr_i(i))is
      begin
        if (rising_edge(clk_gth_rx_usrclk_arr_i(i))) then
      
          s_rx_not_in_table(i) <= gth_rx_status_arr_i(i).rxnotintable(1 downto 0);
          s_rx_disperr(i) <= gth_rx_status_arr_i(i).rxdisperr(1 downto 0);

          -- RX error counters
          if (s_gth_rxerror_rst_reg(i)(0) = '1') then
            s_gth_rxnotintable_cnt_reg(i) <= (others => '0');
            s_gth_rxdisperr_cnt_reg(i) <= (others => '0');
          else
            if ((or_reduce(s_rx_not_in_table(i)) = '1') and (s_gth_rxnotintable_cnt_reg(i) /= x"ffffffff")) then
              s_gth_rxnotintable_cnt_reg(i) <= std_logic_vector(unsigned(s_gth_rxnotintable_cnt_reg(i)) + 1);
            end if;
            if ((or_reduce(s_rx_disperr(i)) = '1') and (s_gth_rxdisperr_cnt_reg(i) /= x"ffffffff")) then
              s_gth_rxdisperr_cnt_reg(i) <= std_logic_vector(unsigned(s_gth_rxdisperr_cnt_reg(i)) + 1);
            end if;
          end if;
    
        end if;
      end process;
    end generate;
  
  end generate;

  process (BRAM_CTRL_GTH_REG_FILE_clk)
  begin
    if(rising_edge(BRAM_CTRL_GTH_REG_FILE_clk)) then

      s_gth_rst_reg          <= (others => (others => '0'));
      s_qpll_rst_reg         <= (others => (others => '0'));
      s_gth_prbs_cnt_rst_reg <= (others => (others => '0'));
      s_gth_rxerror_rst_reg  <= (others => (others => '0'));
      
      
      if(BRAM_CTRL_GTH_REG_FILE_en = '1' and BRAM_CTRL_GTH_REG_FILE_we = "1111") then

        case (BRAM_CTRL_GTH_REG_FILE_addr) is
------------------------------------------------------------------------------------------------------------------------------------------------------
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH0, 17)  => s_gth_rst_reg(C_CH0)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH1, 17)  => s_gth_rst_reg(C_CH1)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH2, 17)  => s_gth_rst_reg(C_CH2)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH3, 17)  => s_gth_rst_reg(C_CH3)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH4, 17)  => s_gth_rst_reg(C_CH4)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH5, 17)  => s_gth_rst_reg(C_CH5)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH6, 17)  => s_gth_rst_reg(C_CH6)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH7, 17)  => s_gth_rst_reg(C_CH7)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH8, 17)  => s_gth_rst_reg(C_CH8)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH9, 17)  => s_gth_rst_reg(C_CH9)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH10, 17)  => s_gth_rst_reg(C_CH10)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH11, 17)  => s_gth_rst_reg(C_CH11)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH12, 17)  => s_gth_rst_reg(C_CH12)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH13, 17)  => s_gth_rst_reg(C_CH13)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH14, 17)  => s_gth_rst_reg(C_CH14)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH15, 17)  => s_gth_rst_reg(C_CH15)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH16, 17)  => s_gth_rst_reg(C_CH16)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH17, 17)  => s_gth_rst_reg(C_CH17)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH18, 17)  => s_gth_rst_reg(C_CH18)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH19, 17)  => s_gth_rst_reg(C_CH19)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH20, 17)  => s_gth_rst_reg(C_CH20)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH21, 17)  => s_gth_rst_reg(C_CH21)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH22, 17)  => s_gth_rst_reg(C_CH22)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH23, 17)  => s_gth_rst_reg(C_CH23)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH24, 17)  => s_gth_rst_reg(C_CH24)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH25, 17)  => s_gth_rst_reg(C_CH25)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH26, 17)  => s_gth_rst_reg(C_CH26)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH27, 17)  => s_gth_rst_reg(C_CH27)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH28, 17)  => s_gth_rst_reg(C_CH28)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH29, 17)  => s_gth_rst_reg(C_CH29)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH30, 17)  => s_gth_rst_reg(C_CH30)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH31, 17)  => s_gth_rst_reg(C_CH31)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH32, 17)  => s_gth_rst_reg(C_CH32)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH33, 17)  => s_gth_rst_reg(C_CH33)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH34, 17)  => s_gth_rst_reg(C_CH34)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH35, 17)  => s_gth_rst_reg(C_CH35)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH36, 17)  => s_gth_rst_reg(C_CH36)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH37, 17)  => s_gth_rst_reg(C_CH37)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH38, 17)  => s_gth_rst_reg(C_CH38)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH39, 17)  => s_gth_rst_reg(C_CH39)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH40, 17)  => s_gth_rst_reg(C_CH40)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH41, 17)  => s_gth_rst_reg(C_CH41)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH42, 17)  => s_gth_rst_reg(C_CH42)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH43, 17)  => s_gth_rst_reg(C_CH43)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH44, 17)  => s_gth_rst_reg(C_CH44)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH45, 17)  => s_gth_rst_reg(C_CH45)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH46, 17)  => s_gth_rst_reg(C_CH46)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH47, 17)  => s_gth_rst_reg(C_CH47)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH48, 17)  => s_gth_rst_reg(C_CH48)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH49, 17)  => s_gth_rst_reg(C_CH49)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH50, 17)  => s_gth_rst_reg(C_CH50)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH51, 17)  => s_gth_rst_reg(C_CH51)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH52, 17)  => s_gth_rst_reg(C_CH52)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH53, 17)  => s_gth_rst_reg(C_CH53)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH54, 17)  => s_gth_rst_reg(C_CH54)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH55, 17)  => s_gth_rst_reg(C_CH55)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH56, 17)  => s_gth_rst_reg(C_CH56)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH57, 17)  => s_gth_rst_reg(C_CH57)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH58, 17)  => s_gth_rst_reg(C_CH58)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH59, 17)  => s_gth_rst_reg(C_CH59)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH60, 17)  => s_gth_rst_reg(C_CH60)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH61, 17)  => s_gth_rst_reg(C_CH61)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH62, 17)  => s_gth_rst_reg(C_CH62)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH63, 17)  => s_gth_rst_reg(C_CH63)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH64, 17)  => s_gth_rst_reg(C_CH64)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH65, 17)  => s_gth_rst_reg(C_CH65)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH66, 17)  => s_gth_rst_reg(C_CH66)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH67, 17)  => s_gth_rst_reg(C_CH67)  <= BRAM_CTRL_GTH_REG_FILE_din;


------------------------------------------------------------------------------------------------------------------------------------------------------
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH0, 17)  => s_gth_ctrl_reg(C_CH0)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH1, 17)  => s_gth_ctrl_reg(C_CH1)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH2, 17)  => s_gth_ctrl_reg(C_CH2)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH3, 17)  => s_gth_ctrl_reg(C_CH3)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH4, 17)  => s_gth_ctrl_reg(C_CH4)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH5, 17)  => s_gth_ctrl_reg(C_CH5)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH6, 17)  => s_gth_ctrl_reg(C_CH6)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH7, 17)  => s_gth_ctrl_reg(C_CH7)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH8, 17)  => s_gth_ctrl_reg(C_CH8)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH9, 17)  => s_gth_ctrl_reg(C_CH9)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH10, 17)  => s_gth_ctrl_reg(C_CH10)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH11, 17)  => s_gth_ctrl_reg(C_CH11)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH12, 17)  => s_gth_ctrl_reg(C_CH12)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH13, 17)  => s_gth_ctrl_reg(C_CH13)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH14, 17)  => s_gth_ctrl_reg(C_CH14)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH15, 17)  => s_gth_ctrl_reg(C_CH15)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH16, 17)  => s_gth_ctrl_reg(C_CH16)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH17, 17)  => s_gth_ctrl_reg(C_CH17)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH18, 17)  => s_gth_ctrl_reg(C_CH18)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH19, 17)  => s_gth_ctrl_reg(C_CH19)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH20, 17)  => s_gth_ctrl_reg(C_CH20)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH21, 17)  => s_gth_ctrl_reg(C_CH21)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH22, 17)  => s_gth_ctrl_reg(C_CH22)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH23, 17)  => s_gth_ctrl_reg(C_CH23)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH24, 17)  => s_gth_ctrl_reg(C_CH24)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH25, 17)  => s_gth_ctrl_reg(C_CH25)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH26, 17)  => s_gth_ctrl_reg(C_CH26)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH27, 17)  => s_gth_ctrl_reg(C_CH27)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH28, 17)  => s_gth_ctrl_reg(C_CH28)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH29, 17)  => s_gth_ctrl_reg(C_CH29)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH30, 17)  => s_gth_ctrl_reg(C_CH30)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH31, 17)  => s_gth_ctrl_reg(C_CH31)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH32, 17)  => s_gth_ctrl_reg(C_CH32)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH33, 17)  => s_gth_ctrl_reg(C_CH33)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH34, 17)  => s_gth_ctrl_reg(C_CH34)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH35, 17)  => s_gth_ctrl_reg(C_CH35)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH36, 17)  => s_gth_ctrl_reg(C_CH36)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH37, 17)  => s_gth_ctrl_reg(C_CH37)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH38, 17)  => s_gth_ctrl_reg(C_CH38)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH39, 17)  => s_gth_ctrl_reg(C_CH39)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH40, 17)  => s_gth_ctrl_reg(C_CH40)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH41, 17)  => s_gth_ctrl_reg(C_CH41)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH42, 17)  => s_gth_ctrl_reg(C_CH42)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH43, 17)  => s_gth_ctrl_reg(C_CH43)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH44, 17)  => s_gth_ctrl_reg(C_CH44)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH45, 17)  => s_gth_ctrl_reg(C_CH45)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH46, 17)  => s_gth_ctrl_reg(C_CH46)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH47, 17)  => s_gth_ctrl_reg(C_CH47)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH48, 17)  => s_gth_ctrl_reg(C_CH48)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH49, 17)  => s_gth_ctrl_reg(C_CH49)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH50, 17)  => s_gth_ctrl_reg(C_CH50)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH51, 17)  => s_gth_ctrl_reg(C_CH51)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH52, 17)  => s_gth_ctrl_reg(C_CH52)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH53, 17)  => s_gth_ctrl_reg(C_CH53)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH54, 17)  => s_gth_ctrl_reg(C_CH54)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH55, 17)  => s_gth_ctrl_reg(C_CH55)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH56, 17)  => s_gth_ctrl_reg(C_CH56)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH57, 17)  => s_gth_ctrl_reg(C_CH57)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH58, 17)  => s_gth_ctrl_reg(C_CH58)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH59, 17)  => s_gth_ctrl_reg(C_CH59)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH60, 17)  => s_gth_ctrl_reg(C_CH60)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH61, 17)  => s_gth_ctrl_reg(C_CH61)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH62, 17)  => s_gth_ctrl_reg(C_CH62)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH63, 17)  => s_gth_ctrl_reg(C_CH63)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH64, 17)  => s_gth_ctrl_reg(C_CH64)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH65, 17)  => s_gth_ctrl_reg(C_CH65)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH66, 17)  => s_gth_ctrl_reg(C_CH66)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH67, 17)  => s_gth_ctrl_reg(C_CH67)  <= BRAM_CTRL_GTH_REG_FILE_din;

------------------------------------------------------------------------------------------------------------------------------------------------------
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH0, 17)  => s_gth_prbs_sel_reg(C_CH0)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH1, 17)  => s_gth_prbs_sel_reg(C_CH1)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH2, 17)  => s_gth_prbs_sel_reg(C_CH2)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH3, 17)  => s_gth_prbs_sel_reg(C_CH3)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH4, 17)  => s_gth_prbs_sel_reg(C_CH4)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH5, 17)  => s_gth_prbs_sel_reg(C_CH5)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH6, 17)  => s_gth_prbs_sel_reg(C_CH6)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH7, 17)  => s_gth_prbs_sel_reg(C_CH7)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH8, 17)  => s_gth_prbs_sel_reg(C_CH8)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH9, 17)  => s_gth_prbs_sel_reg(C_CH9)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH10, 17)  => s_gth_prbs_sel_reg(C_CH10)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH11, 17)  => s_gth_prbs_sel_reg(C_CH11)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH12, 17)  => s_gth_prbs_sel_reg(C_CH12)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH13, 17)  => s_gth_prbs_sel_reg(C_CH13)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH14, 17)  => s_gth_prbs_sel_reg(C_CH14)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH15, 17)  => s_gth_prbs_sel_reg(C_CH15)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH16, 17)  => s_gth_prbs_sel_reg(C_CH16)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH17, 17)  => s_gth_prbs_sel_reg(C_CH17)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH18, 17)  => s_gth_prbs_sel_reg(C_CH18)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH19, 17)  => s_gth_prbs_sel_reg(C_CH19)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH20, 17)  => s_gth_prbs_sel_reg(C_CH20)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH21, 17)  => s_gth_prbs_sel_reg(C_CH21)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH22, 17)  => s_gth_prbs_sel_reg(C_CH22)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH23, 17)  => s_gth_prbs_sel_reg(C_CH23)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH24, 17)  => s_gth_prbs_sel_reg(C_CH24)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH25, 17)  => s_gth_prbs_sel_reg(C_CH25)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH26, 17)  => s_gth_prbs_sel_reg(C_CH26)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH27, 17)  => s_gth_prbs_sel_reg(C_CH27)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH28, 17)  => s_gth_prbs_sel_reg(C_CH28)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH29, 17)  => s_gth_prbs_sel_reg(C_CH29)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH30, 17)  => s_gth_prbs_sel_reg(C_CH30)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH31, 17)  => s_gth_prbs_sel_reg(C_CH31)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH32, 17)  => s_gth_prbs_sel_reg(C_CH32)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH33, 17)  => s_gth_prbs_sel_reg(C_CH33)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH34, 17)  => s_gth_prbs_sel_reg(C_CH34)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH35, 17)  => s_gth_prbs_sel_reg(C_CH35)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH36, 17)  => s_gth_prbs_sel_reg(C_CH36)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH37, 17)  => s_gth_prbs_sel_reg(C_CH37)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH38, 17)  => s_gth_prbs_sel_reg(C_CH38)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH39, 17)  => s_gth_prbs_sel_reg(C_CH39)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH40, 17)  => s_gth_prbs_sel_reg(C_CH40)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH41, 17)  => s_gth_prbs_sel_reg(C_CH41)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH42, 17)  => s_gth_prbs_sel_reg(C_CH42)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH43, 17)  => s_gth_prbs_sel_reg(C_CH43)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH44, 17)  => s_gth_prbs_sel_reg(C_CH44)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH45, 17)  => s_gth_prbs_sel_reg(C_CH45)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH46, 17)  => s_gth_prbs_sel_reg(C_CH46)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH47, 17)  => s_gth_prbs_sel_reg(C_CH47)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH48, 17)  => s_gth_prbs_sel_reg(C_CH48)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH49, 17)  => s_gth_prbs_sel_reg(C_CH49)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH50, 17)  => s_gth_prbs_sel_reg(C_CH50)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH51, 17)  => s_gth_prbs_sel_reg(C_CH51)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH52, 17)  => s_gth_prbs_sel_reg(C_CH52)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH53, 17)  => s_gth_prbs_sel_reg(C_CH53)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH54, 17)  => s_gth_prbs_sel_reg(C_CH54)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH55, 17)  => s_gth_prbs_sel_reg(C_CH55)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH56, 17)  => s_gth_prbs_sel_reg(C_CH56)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH57, 17)  => s_gth_prbs_sel_reg(C_CH57)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH58, 17)  => s_gth_prbs_sel_reg(C_CH58)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH59, 17)  => s_gth_prbs_sel_reg(C_CH59)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH60, 17)  => s_gth_prbs_sel_reg(C_CH60)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH61, 17)  => s_gth_prbs_sel_reg(C_CH61)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH62, 17)  => s_gth_prbs_sel_reg(C_CH62)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH63, 17)  => s_gth_prbs_sel_reg(C_CH63)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH64, 17)  => s_gth_prbs_sel_reg(C_CH64)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH65, 17)  => s_gth_prbs_sel_reg(C_CH65)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH66, 17)  => s_gth_prbs_sel_reg(C_CH66)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH67, 17)  => s_gth_prbs_sel_reg(C_CH67)  <= BRAM_CTRL_GTH_REG_FILE_din;

------------------------------------------------------------------------------------------------------------------------------------------------------
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH0, 17)  => s_gth_prbs_cnt_rst_reg(C_CH0)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH1, 17)  => s_gth_prbs_cnt_rst_reg(C_CH1)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH2, 17)  => s_gth_prbs_cnt_rst_reg(C_CH2)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH3, 17)  => s_gth_prbs_cnt_rst_reg(C_CH3)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH4, 17)  => s_gth_prbs_cnt_rst_reg(C_CH4)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH5, 17)  => s_gth_prbs_cnt_rst_reg(C_CH5)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH6, 17)  => s_gth_prbs_cnt_rst_reg(C_CH6)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH7, 17)  => s_gth_prbs_cnt_rst_reg(C_CH7)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH8, 17)  => s_gth_prbs_cnt_rst_reg(C_CH8)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH9, 17)  => s_gth_prbs_cnt_rst_reg(C_CH9)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH10, 17)  => s_gth_prbs_cnt_rst_reg(C_CH10)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH11, 17)  => s_gth_prbs_cnt_rst_reg(C_CH11)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH12, 17)  => s_gth_prbs_cnt_rst_reg(C_CH12)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH13, 17)  => s_gth_prbs_cnt_rst_reg(C_CH13)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH14, 17)  => s_gth_prbs_cnt_rst_reg(C_CH14)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH15, 17)  => s_gth_prbs_cnt_rst_reg(C_CH15)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH16, 17)  => s_gth_prbs_cnt_rst_reg(C_CH16)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH17, 17)  => s_gth_prbs_cnt_rst_reg(C_CH17)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH18, 17)  => s_gth_prbs_cnt_rst_reg(C_CH18)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH19, 17)  => s_gth_prbs_cnt_rst_reg(C_CH19)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH20, 17)  => s_gth_prbs_cnt_rst_reg(C_CH20)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH21, 17)  => s_gth_prbs_cnt_rst_reg(C_CH21)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH22, 17)  => s_gth_prbs_cnt_rst_reg(C_CH22)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH23, 17)  => s_gth_prbs_cnt_rst_reg(C_CH23)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH24, 17)  => s_gth_prbs_cnt_rst_reg(C_CH24)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH25, 17)  => s_gth_prbs_cnt_rst_reg(C_CH25)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH26, 17)  => s_gth_prbs_cnt_rst_reg(C_CH26)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH27, 17)  => s_gth_prbs_cnt_rst_reg(C_CH27)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH28, 17)  => s_gth_prbs_cnt_rst_reg(C_CH28)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH29, 17)  => s_gth_prbs_cnt_rst_reg(C_CH29)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH30, 17)  => s_gth_prbs_cnt_rst_reg(C_CH30)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH31, 17)  => s_gth_prbs_cnt_rst_reg(C_CH31)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH32, 17)  => s_gth_prbs_cnt_rst_reg(C_CH32)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH33, 17)  => s_gth_prbs_cnt_rst_reg(C_CH33)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH34, 17)  => s_gth_prbs_cnt_rst_reg(C_CH34)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH35, 17)  => s_gth_prbs_cnt_rst_reg(C_CH35)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH36, 17)  => s_gth_prbs_cnt_rst_reg(C_CH36)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH37, 17)  => s_gth_prbs_cnt_rst_reg(C_CH37)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH38, 17)  => s_gth_prbs_cnt_rst_reg(C_CH38)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH39, 17)  => s_gth_prbs_cnt_rst_reg(C_CH39)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH40, 17)  => s_gth_prbs_cnt_rst_reg(C_CH40)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH41, 17)  => s_gth_prbs_cnt_rst_reg(C_CH41)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH42, 17)  => s_gth_prbs_cnt_rst_reg(C_CH42)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH43, 17)  => s_gth_prbs_cnt_rst_reg(C_CH43)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH44, 17)  => s_gth_prbs_cnt_rst_reg(C_CH44)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH45, 17)  => s_gth_prbs_cnt_rst_reg(C_CH45)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH46, 17)  => s_gth_prbs_cnt_rst_reg(C_CH46)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH47, 17)  => s_gth_prbs_cnt_rst_reg(C_CH47)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH48, 17)  => s_gth_prbs_cnt_rst_reg(C_CH48)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH49, 17)  => s_gth_prbs_cnt_rst_reg(C_CH49)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH50, 17)  => s_gth_prbs_cnt_rst_reg(C_CH50)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH51, 17)  => s_gth_prbs_cnt_rst_reg(C_CH51)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH52, 17)  => s_gth_prbs_cnt_rst_reg(C_CH52)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH53, 17)  => s_gth_prbs_cnt_rst_reg(C_CH53)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH54, 17)  => s_gth_prbs_cnt_rst_reg(C_CH54)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH55, 17)  => s_gth_prbs_cnt_rst_reg(C_CH55)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH56, 17)  => s_gth_prbs_cnt_rst_reg(C_CH56)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH57, 17)  => s_gth_prbs_cnt_rst_reg(C_CH57)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH58, 17)  => s_gth_prbs_cnt_rst_reg(C_CH58)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH59, 17)  => s_gth_prbs_cnt_rst_reg(C_CH59)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH60, 17)  => s_gth_prbs_cnt_rst_reg(C_CH60)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH61, 17)  => s_gth_prbs_cnt_rst_reg(C_CH61)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH62, 17)  => s_gth_prbs_cnt_rst_reg(C_CH62)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH63, 17)  => s_gth_prbs_cnt_rst_reg(C_CH63)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH64, 17)  => s_gth_prbs_cnt_rst_reg(C_CH64)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH65, 17)  => s_gth_prbs_cnt_rst_reg(C_CH65)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH66, 17)  => s_gth_prbs_cnt_rst_reg(C_CH66)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH67, 17)  => s_gth_prbs_cnt_rst_reg(C_CH67)  <= BRAM_CTRL_GTH_REG_FILE_din;

------------------------------------------------------------------------------------------------------------------------------------------------------
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH0, 17)  => s_gth_rxerror_rst_reg(C_CH0)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH1, 17)  => s_gth_rxerror_rst_reg(C_CH1)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH2, 17)  => s_gth_rxerror_rst_reg(C_CH2)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH3, 17)  => s_gth_rxerror_rst_reg(C_CH3)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH4, 17)  => s_gth_rxerror_rst_reg(C_CH4)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH5, 17)  => s_gth_rxerror_rst_reg(C_CH5)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH6, 17)  => s_gth_rxerror_rst_reg(C_CH6)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH7, 17)  => s_gth_rxerror_rst_reg(C_CH7)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH8, 17)  => s_gth_rxerror_rst_reg(C_CH8)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH9, 17)  => s_gth_rxerror_rst_reg(C_CH9)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH10, 17)  => s_gth_rxerror_rst_reg(C_CH10)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH11, 17)  => s_gth_rxerror_rst_reg(C_CH11)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH12, 17)  => s_gth_rxerror_rst_reg(C_CH12)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH13, 17)  => s_gth_rxerror_rst_reg(C_CH13)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH14, 17)  => s_gth_rxerror_rst_reg(C_CH14)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH15, 17)  => s_gth_rxerror_rst_reg(C_CH15)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH16, 17)  => s_gth_rxerror_rst_reg(C_CH16)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH17, 17)  => s_gth_rxerror_rst_reg(C_CH17)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH18, 17)  => s_gth_rxerror_rst_reg(C_CH18)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH19, 17)  => s_gth_rxerror_rst_reg(C_CH19)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH20, 17)  => s_gth_rxerror_rst_reg(C_CH20)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH21, 17)  => s_gth_rxerror_rst_reg(C_CH21)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH22, 17)  => s_gth_rxerror_rst_reg(C_CH22)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH23, 17)  => s_gth_rxerror_rst_reg(C_CH23)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH24, 17)  => s_gth_rxerror_rst_reg(C_CH24)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH25, 17)  => s_gth_rxerror_rst_reg(C_CH25)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH26, 17)  => s_gth_rxerror_rst_reg(C_CH26)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH27, 17)  => s_gth_rxerror_rst_reg(C_CH27)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH28, 17)  => s_gth_rxerror_rst_reg(C_CH28)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH29, 17)  => s_gth_rxerror_rst_reg(C_CH29)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH30, 17)  => s_gth_rxerror_rst_reg(C_CH30)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH31, 17)  => s_gth_rxerror_rst_reg(C_CH31)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH32, 17)  => s_gth_rxerror_rst_reg(C_CH32)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH33, 17)  => s_gth_rxerror_rst_reg(C_CH33)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH34, 17)  => s_gth_rxerror_rst_reg(C_CH34)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH35, 17)  => s_gth_rxerror_rst_reg(C_CH35)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH36, 17)  => s_gth_rxerror_rst_reg(C_CH36)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH37, 17)  => s_gth_rxerror_rst_reg(C_CH37)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH38, 17)  => s_gth_rxerror_rst_reg(C_CH38)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH39, 17)  => s_gth_rxerror_rst_reg(C_CH39)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH40, 17)  => s_gth_rxerror_rst_reg(C_CH40)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH41, 17)  => s_gth_rxerror_rst_reg(C_CH41)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH42, 17)  => s_gth_rxerror_rst_reg(C_CH42)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH43, 17)  => s_gth_rxerror_rst_reg(C_CH43)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH44, 17)  => s_gth_rxerror_rst_reg(C_CH44)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH45, 17)  => s_gth_rxerror_rst_reg(C_CH45)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH46, 17)  => s_gth_rxerror_rst_reg(C_CH46)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH47, 17)  => s_gth_rxerror_rst_reg(C_CH47)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH48, 17)  => s_gth_rxerror_rst_reg(C_CH48)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH49, 17)  => s_gth_rxerror_rst_reg(C_CH49)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH50, 17)  => s_gth_rxerror_rst_reg(C_CH50)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH51, 17)  => s_gth_rxerror_rst_reg(C_CH51)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH52, 17)  => s_gth_rxerror_rst_reg(C_CH52)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH53, 17)  => s_gth_rxerror_rst_reg(C_CH53)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH54, 17)  => s_gth_rxerror_rst_reg(C_CH54)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH55, 17)  => s_gth_rxerror_rst_reg(C_CH55)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH56, 17)  => s_gth_rxerror_rst_reg(C_CH56)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH57, 17)  => s_gth_rxerror_rst_reg(C_CH57)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH58, 17)  => s_gth_rxerror_rst_reg(C_CH58)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH59, 17)  => s_gth_rxerror_rst_reg(C_CH59)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH60, 17)  => s_gth_rxerror_rst_reg(C_CH60)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH61, 17)  => s_gth_rxerror_rst_reg(C_CH61)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH62, 17)  => s_gth_rxerror_rst_reg(C_CH62)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH63, 17)  => s_gth_rxerror_rst_reg(C_CH63)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH64, 17)  => s_gth_rxerror_rst_reg(C_CH64)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH65, 17)  => s_gth_rxerror_rst_reg(C_CH65)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH66, 17)  => s_gth_rxerror_rst_reg(C_CH66)  <= BRAM_CTRL_GTH_REG_FILE_din;
          when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH67, 17)  => s_gth_rxerror_rst_reg(C_CH67)  <= BRAM_CTRL_GTH_REG_FILE_din;

-------------------------------------------------------------------------------------------------------------------------------------------------------------
          
          when others => null;

--------------------------------------------------------------------------------
        end case;
      end if;

      --default BRAM dout assignment
      BRAM_CTRL_GTH_REG_FILE_dout <= (others => '0');

      case (BRAM_CTRL_GTH_REG_FILE_addr) is

------------------------------------------------------------------------------------------------------------------------------------------------------
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH0, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH0);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH1, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH1);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH2, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH2);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH3, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH3);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH4, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH4);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH5, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH5);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH6, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH6);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH7, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH7);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH8, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH8);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH9, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH9);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH10, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH10);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH11, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH11);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH12, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH12);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH13, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH13);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH14, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH14);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH15, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH15);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH16, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH16);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH17, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH17);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH18, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH18);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH19, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH19);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH20, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH20);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH21, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH21);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH22, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH22);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH23, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH23);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH24, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH24);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH25, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH25);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH26, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH26);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH27, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH27);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH28, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH28);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH29, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH29);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH30, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH30);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH31, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH31);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH32, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH32);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH33, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH33);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH34, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH34);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH35, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH35);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH36, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH36);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH37, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH37);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH38, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH38);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH39, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH39);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH40, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH40);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH41, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH41);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH42, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH42);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH43, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH43);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH44, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH44);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH45, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH45);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH46, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH46);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH47, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH47);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH48, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH48);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH49, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH49);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH50, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH50);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH51, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH51);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH52, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH52);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH53, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH53);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH54, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH54);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH55, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH55);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH56, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH56);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH57, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH57);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH58, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH58);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH59, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH59);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH60, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH60);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH61, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH61);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH62, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH62);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH63, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH63);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH64, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH64);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH65, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH65);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH66, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH66);
        when addr_encode(C_GTH_STAT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH67, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_stat_reg(C_CH67);

------------------------------------------------------------------------------------------------------------------------------------------------------
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH0, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH0);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH1, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH1);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH2, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH2);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH3, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH3);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH4, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH4);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH5, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH5);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH6, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH6);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH7, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH7);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH8, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH8);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH9, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH9);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH10, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH10);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH11, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH11);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH12, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH12);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH13, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH13);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH14, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH14);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH15, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH15);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH16, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH16);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH17, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH17);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH18, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH18);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH19, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH19);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH20, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH20);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH21, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH21);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH22, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH22);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH23, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH23);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH24, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH24);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH25, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH25);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH26, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH26);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH27, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH27);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH28, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH28);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH29, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH29);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH30, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH30);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH31, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH31);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH32, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH32);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH33, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH33);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH34, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH34);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH35, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH35);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH36, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH36);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH37, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH37);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH38, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH38);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH39, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH39);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH40, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH40);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH41, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH41);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH42, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH42);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH43, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH43);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH44, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH44);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH45, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH45);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH46, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH46);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH47, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH47);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH48, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH48);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH49, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH49);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH50, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH50);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH51, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH51);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH52, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH52);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH53, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH53);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH54, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH54);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH55, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH55);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH56, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH56);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH57, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH57);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH58, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH58);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH59, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH59);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH60, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH60);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH61, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH61);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH62, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH62);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH63, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH63);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH64, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH64);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH65, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH65);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH66, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH66);
        when addr_encode(C_GTH_RST_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH67, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rst_reg(C_CH67);

------------------------------------------------------------------------------------------------------------------------------------------------------
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH0, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH0);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH1, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH1);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH2, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH2);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH3, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH3);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH4, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH4);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH5, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH5);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH6, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH6);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH7, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH7);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH8, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH8);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH9, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH9);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH10, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH10);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH11, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH11);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH12, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH12);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH13, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH13);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH14, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH14);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH15, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH15);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH16, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH16);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH17, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH17);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH18, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH18);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH19, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH19);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH20, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH20);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH21, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH21);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH22, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH22);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH23, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH23);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH24, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH24);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH25, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH25);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH26, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH26);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH27, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH27);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH28, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH28);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH29, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH29);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH30, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH30);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH31, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH31);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH32, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH32);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH33, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH33);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH34, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH34);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH35, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH35);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH36, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH36);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH37, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH37);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH38, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH38);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH39, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH39);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH40, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH40);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH41, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH41);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH42, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH42);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH43, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH43);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH44, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH44);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH45, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH45);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH46, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH46);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH47, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH47);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH48, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH48);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH49, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH49);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH50, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH50);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH51, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH51);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH52, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH52);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH53, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH53);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH54, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH54);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH55, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH55);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH56, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH56);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH57, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH57);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH58, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH58);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH59, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH59);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH60, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH60);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH61, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH61);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH62, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH62);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH63, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH63);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH64, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH64);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH65, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH65);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH66, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH66);
        when addr_encode(C_GTH_CTRL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH67, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_ctrl_reg(C_CH67);

------------------------------------------------------------------------------------------------------------------------------------------------------
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH0, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH0);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH1, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH1);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH2, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH2);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH3, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH3);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH4, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH4);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH5, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH5);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH6, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH6);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH7, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH7);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH8, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH8);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH9, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH9);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH10, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH10);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH11, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH11);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH12, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH12);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH13, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH13);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH14, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH14);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH15, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH15);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH16, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH16);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH17, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH17);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH18, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH18);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH19, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH19);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH20, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH20);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH21, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH21);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH22, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH22);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH23, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH23);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH24, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH24);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH25, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH25);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH26, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH26);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH27, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH27);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH28, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH28);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH29, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH29);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH30, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH30);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH31, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH31);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH32, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH32);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH33, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH33);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH34, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH34);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH35, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH35);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH36, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH36);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH37, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH37);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH38, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH38);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH39, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH39);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH40, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH40);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH41, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH41);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH42, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH42);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH43, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH43);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH44, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH44);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH45, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH45);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH46, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH46);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH47, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH47);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH48, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH48);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH49, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH49);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH50, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH50);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH51, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH51);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH52, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH52);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH53, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH53);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH54, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH54);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH55, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH55);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH56, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH56);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH57, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH57);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH58, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH58);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH59, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH59);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH60, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH60);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH61, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH61);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH62, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH62);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH63, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH63);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH64, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH64);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH65, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH65);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH66, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH66);
        when addr_encode(C_GTH_PRBS_SEL_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH67, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_sel_reg(C_CH67);

------------------------------------------------------------------------------------------------------------------------------------------------------
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH0, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH0);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH1, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH1);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH2, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH2);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH3, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH3);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH4, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH4);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH5, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH5);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH6, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH6);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH7, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH7);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH8, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH8);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH9, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH9);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH10, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH10);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH11, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH11);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH12, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH12);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH13, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH13);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH14, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH14);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH15, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH15);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH16, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH16);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH17, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH17);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH18, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH18);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH19, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH19);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH20, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH20);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH21, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH21);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH22, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH22);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH23, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH23);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH24, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH24);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH25, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH25);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH26, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH26);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH27, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH27);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH28, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH28);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH29, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH29);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH30, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH30);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH31, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH31);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH32, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH32);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH33, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH33);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH34, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH34);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH35, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH35);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH36, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH36);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH37, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH37);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH38, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH38);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH39, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH39);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH40, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH40);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH41, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH41);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH42, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH42);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH43, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH43);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH44, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH44);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH45, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH45);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH46, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH46);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH47, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH47);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH48, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH48);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH49, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH49);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH50, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH50);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH51, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH51);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH52, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH52);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH53, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH53);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH54, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH54);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH55, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH55);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH56, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH56);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH57, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH57);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH58, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH58);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH59, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH59);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH60, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH60);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH61, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH61);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH62, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH62);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH63, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH63);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH64, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH64);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH65, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH65);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH66, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH66);
        when addr_encode(C_GTH_PRBS_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH67, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_prbs_cnt_reg(C_CH67);

------------------------------------------------------------------------------------------------------------------------------------------------------
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH0, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH0);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH1, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH1);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH2, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH2);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH3, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH3);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH4, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH4);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH5, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH5);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH6, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH6);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH7, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH7);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH8, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH8);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH9, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH9);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH10, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH10);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH11, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH11);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH12, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH12);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH13, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH13);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH14, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH14);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH15, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH15);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH16, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH16);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH17, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH17);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH18, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH18);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH19, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH19);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH20, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH20);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH21, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH21);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH22, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH22);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH23, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH23);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH24, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH24);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH25, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH25);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH26, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH26);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH27, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH27);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH28, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH28);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH29, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH29);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH30, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH30);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH31, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH31);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH32, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH32);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH33, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH33);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH34, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH34);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH35, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH35);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH36, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH36);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH37, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH37);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH38, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH38);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH39, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH39);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH40, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH40);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH41, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH41);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH42, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH42);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH43, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH43);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH44, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH44);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH45, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH45);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH46, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH46);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH47, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH47);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH48, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH48);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH49, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH49);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH50, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH50);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH51, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH51);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH52, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH52);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH53, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH53);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH54, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH54);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH55, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH55);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH56, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH56);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH57, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH57);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH58, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH58);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH59, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH59);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH60, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH60);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH61, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH61);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH62, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH62);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH63, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH63);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH64, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH64);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH65, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH65);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH66, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH66);
        when addr_encode(C_GTH_RX_NOTINTABLE_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH67, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxnotintable_cnt_reg(C_CH67);
        
------------------------------------------------------------------------------------------------------------------------------------------------------
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH0, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH0);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH1, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH1);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH2, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH2);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH3, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH3);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH4, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH4);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH5, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH5);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH6, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH6);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH7, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH7);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH8, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH8);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH9, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH9);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH10, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH10);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH11, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH11);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH12, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH12);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH13, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH13);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH14, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH14);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH15, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH15);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH16, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH16);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH17, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH17);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH18, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH18);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH19, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH19);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH20, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH20);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH21, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH21);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH22, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH22);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH23, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH23);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH24, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH24);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH25, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH25);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH26, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH26);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH27, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH27);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH28, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH28);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH29, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH29);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH30, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH30);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH31, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH31);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH32, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH32);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH33, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH33);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH34, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH34);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH35, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH35);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH36, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH36);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH37, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH37);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH38, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH38);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH39, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH39);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH40, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH40);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH41, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH41);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH42, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH42);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH43, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH43);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH44, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH44);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH45, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH45);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH46, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH46);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH47, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH47);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH48, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH48);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH49, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH49);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH50, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH50);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH51, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH51);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH52, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH52);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH53, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH53);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH54, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH54);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH55, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH55);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH56, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH56);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH57, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH57);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH58, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH58);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH59, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH59);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH60, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH60);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH61, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH61);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH62, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH62);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH63, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH63);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH64, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH64);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH65, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH65);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH66, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH66);
        when addr_encode(C_GTH_RX_DISPERR_CNT_CH0_ADDR, C_GTH_CH_to_CH_ADDR_OFFSET, C_CH67, 17)  => BRAM_CTRL_GTH_REG_FILE_dout <= s_gth_rxdisperr_cnt_reg(C_CH67);

------------------------------------------------------------------------------------------------------------------------------------------------------

        when others => BRAM_CTRL_GTH_REG_FILE_dout <= (others => '0');

      end case;

    end if;
  end process;


  gen_gth_sign_assign : for i in 0 to g_NUM_OF_GTH_GTs-1 generate

    s_reg_cplllock(i)       <= gth_cpll_status_arr_i(i).cplllock;
    s_reg_cpllrefclklost(i) <= gth_cpll_status_arr_i(i).cpllrefclklost;

    gth_tx_ctrl_arr_o(i).txsysclksel <= "00";
    gth_tx_ctrl_arr_o(i).TXOUTCLKSEL <= "011";

    gth_rx_ctrl_arr_o(i).rxsysclksel <= "00";
    gth_rx_ctrl_arr_o(i).RXOUTCLKSEL <= "010";

    gth_rx_ctrl_arr_o(i).rxprbscntreset <= '0';

    gth_gt_txreset_o(i)             <= s_tx_reset(i);
    gth_tx_ctrl_arr_o(i).txpolarity <= s_tx_polarity(i);
    gth_tx_ctrl_arr_o(i).txinhibit  <= s_tx_inhibit(i);

    gth_gt_rxreset_o(i)             <= s_rx_reset(i);
    gth_rx_ctrl_arr_o(i).rxpolarity <= s_rx_polarity(i);
    gth_rx_ctrl_arr_o(i).rxlpmen    <= s_rx_lpmen(i);
    gth_misc_ctrl_arr_o(i).loopback <= "000" when s_gth_loopback(i) = '0' else "010";

    gth_cpll_init_arr_o(i).cpllreset <= s_cpll_reset(i);
    gth_cpll_init_arr_o(i).cpllpd    <= s_cpll_pd(i);

    gth_tx_ctrl_arr_o(i).txpd <= "00" when s_tx_pd(i) = '0' else "11";
    gth_rx_ctrl_arr_o(i).rxpd <= "00" when s_rx_pd(i) = '0' else "11";

    gth_tx_ctrl_arr_o(i).txpostcursor <= (others => '0');
    gth_tx_ctrl_arr_o(i).txprecursor  <= (others => '0');
    gth_tx_ctrl_arr_o(i).txdiffctrl   <= "1000";  -- mVPPD = 0.807
    gth_tx_ctrl_arr_o(i).txmaincursor <= (others => '0');

    gth_tx_ctrl_arr_o(i).txprbssel <= s_gth_prbs_sel_reg(i)(6 downto 4);
    gth_rx_ctrl_arr_o(i).rxprbssel <= s_gth_prbs_sel_reg(i)(2 downto 0);

  end generate;

  gen_gth_reg_allocation : for i in 0 to g_NUM_OF_GTH_GTs-1 generate

    s_gth_stat_reg(i)(0) <= gth_gt_txreset_done_i(i);
    s_gth_stat_reg(i)(1) <= gth_gt_rxreset_done_i(i);
    s_gth_stat_reg(i)(2) <= s_reg_cplllock(i);
    s_gth_stat_reg(i)(3) <= s_reg_cpllrefclklost(i);

    s_tx_reset(i)   <= s_gth_rst_reg(i)(0);
    s_rx_reset(i)   <= s_gth_rst_reg(i)(1);
    s_cpll_reset(i) <= s_gth_rst_reg(i)(2);

    s_tx_pd(i)        <= s_gth_ctrl_reg(i)(0);
    s_rx_pd(i)        <= s_gth_ctrl_reg(i)(1);
    s_tx_polarity(i)  <= s_gth_ctrl_reg(i)(2);
    s_rx_polarity(i)  <= s_gth_ctrl_reg(i)(3);
    s_gth_loopback(i) <= s_gth_ctrl_reg(i)(4);
    s_tx_inhibit(i)   <= s_gth_ctrl_reg(i)(5);
    s_rx_lpmen(i)     <= s_gth_ctrl_reg(i)(6);
    s_cpll_pd(i)      <= s_gth_ctrl_reg(i)(7);

  end generate;

  gen_gth_common_qpll : for i in 0 to g_NUM_OF_GTH_COMMONs-1 generate

    gth_common_reset_o(i) <= s_gth_rst_reg(i*4+0)(3) or s_gth_rst_reg(i*4+1)(3) or s_gth_rst_reg(i*4+2)(3) or s_gth_rst_reg(i*4+3)(3);
    
    gen_gth_common_channel : for j in 0 to 3 generate
    
      s_gth_stat_reg(i*4+j)(4) <= gth_common_status_arr_i(i).QPLLLOCK;
      s_gth_stat_reg(i*4+j)(5) <= gth_common_status_arr_i(i).QPLLREFCLKLOST;

    end generate;

  end generate;

end gth_register_file_arch;
--============================================================================
--                                                            Architecture end
--============================================================================
