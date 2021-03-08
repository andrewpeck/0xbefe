library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

Library xpm;
use xpm.vcomponents.all;

entity gem_loader_v_v1_0 is
  generic (

    C_FIFO_ENDIAN_CONV_ENABLE : boolean := true;

    -- Parameters of Axi Slave Bus Interface S_C2C_AXI
    C_S_C2C_AXI_ID_WIDTH     : integer := 0;
    C_S_C2C_AXI_DATA_WIDTH   : integer := 32;
    C_S_C2C_AXI_ADDR_WIDTH   : integer := 32;
    C_S_C2C_AXI_AWUSER_WIDTH : integer := 0;
    C_S_C2C_AXI_ARUSER_WIDTH : integer := 0;
    C_S_C2C_AXI_WUSER_WIDTH  : integer := 0;
    C_S_C2C_AXI_RUSER_WIDTH  : integer := 0;
    C_S_C2C_AXI_BUSER_WIDTH  : integer := 0;

    -- Parameters of Axi Slave Bus Interface S_CFG_AXI
    C_S_CFG_AXI_DATA_WIDTH : integer := 32;
    C_S_CFG_AXI_ADDR_WIDTH : integer := 5
    );
  port (

    clk_reload : in std_logic;

    reload_request : in std_logic;
    reload_start   : in std_logic;

    reload_data        : out std_logic_vector(7 downto 0);
    reload_data_valid  : out std_logic;
    reload_data_first  : out std_logic;
    reload_data_last   : out std_logic;

    reload_ready       : out std_logic;
    reload_error       : out std_logic;
    reload_size        : out std_logic_vector(31 downto 0);

    reload_request_remote   : out std_logic;
    reload_fifo_full_remote : out std_logic;

    -- Ports of Axi Slave Bus Interface S_C2C_AXI
    s_c2c_axi_aclk     : in  std_logic;
    s_c2c_axi_aresetn  : in  std_logic;
    s_c2c_axi_awid     : in  std_logic_vector(C_S_C2C_AXI_ID_WIDTH-1 downto 0);
    s_c2c_axi_awaddr   : in  std_logic_vector(C_S_C2C_AXI_ADDR_WIDTH-1 downto 0);
    s_c2c_axi_awlen    : in  std_logic_vector(7 downto 0);
    s_c2c_axi_awsize   : in  std_logic_vector(2 downto 0);
    s_c2c_axi_awburst  : in  std_logic_vector(1 downto 0);
    s_c2c_axi_awlock   : in  std_logic;
    s_c2c_axi_awcache  : in  std_logic_vector(3 downto 0);
    s_c2c_axi_awprot   : in  std_logic_vector(2 downto 0);
    s_c2c_axi_awqos    : in  std_logic_vector(3 downto 0);
    s_c2c_axi_awregion : in  std_logic_vector(3 downto 0);
    s_c2c_axi_awuser   : in  std_logic_vector(C_S_C2C_AXI_AWUSER_WIDTH-1 downto 0);
    s_c2c_axi_awvalid  : in  std_logic;
    s_c2c_axi_awready  : out std_logic;
    s_c2c_axi_wdata    : in  std_logic_vector(C_S_C2C_AXI_DATA_WIDTH-1 downto 0);
    s_c2c_axi_wstrb    : in  std_logic_vector((C_S_C2C_AXI_DATA_WIDTH/8)-1 downto 0);
    s_c2c_axi_wlast    : in  std_logic;
    s_c2c_axi_wuser    : in  std_logic_vector(C_S_C2C_AXI_WUSER_WIDTH-1 downto 0);
    s_c2c_axi_wvalid   : in  std_logic;
    s_c2c_axi_wready   : out std_logic;
    s_c2c_axi_bid      : out std_logic_vector(C_S_C2C_AXI_ID_WIDTH-1 downto 0);
    s_c2c_axi_bresp    : out std_logic_vector(1 downto 0);
    s_c2c_axi_buser    : out std_logic_vector(C_S_C2C_AXI_BUSER_WIDTH-1 downto 0);
    s_c2c_axi_bvalid   : out std_logic;
    s_c2c_axi_bready   : in  std_logic;
    s_c2c_axi_arid     : in  std_logic_vector(C_S_C2C_AXI_ID_WIDTH-1 downto 0);
    s_c2c_axi_araddr   : in  std_logic_vector(C_S_C2C_AXI_ADDR_WIDTH-1 downto 0);
    s_c2c_axi_arlen    : in  std_logic_vector(7 downto 0);
    s_c2c_axi_arsize   : in  std_logic_vector(2 downto 0);
    s_c2c_axi_arburst  : in  std_logic_vector(1 downto 0);
    s_c2c_axi_arlock   : in  std_logic;
    s_c2c_axi_arcache  : in  std_logic_vector(3 downto 0);
    s_c2c_axi_arprot   : in  std_logic_vector(2 downto 0);
    s_c2c_axi_arqos    : in  std_logic_vector(3 downto 0);
    s_c2c_axi_arregion : in  std_logic_vector(3 downto 0);
    s_c2c_axi_aruser   : in  std_logic_vector(C_S_C2C_AXI_ARUSER_WIDTH-1 downto 0);
    s_c2c_axi_arvalid  : in  std_logic;
    s_c2c_axi_arready  : out std_logic;
    s_c2c_axi_rid      : out std_logic_vector(C_S_C2C_AXI_ID_WIDTH-1 downto 0);
    s_c2c_axi_rdata    : out std_logic_vector(C_S_C2C_AXI_DATA_WIDTH-1 downto 0);
    s_c2c_axi_rresp    : out std_logic_vector(1 downto 0);
    s_c2c_axi_rlast    : out std_logic;
    s_c2c_axi_ruser    : out std_logic_vector(C_S_C2C_AXI_RUSER_WIDTH-1 downto 0);
    s_c2c_axi_rvalid   : out std_logic;
    s_c2c_axi_rready   : in  std_logic;

    -- Ports of Axi Slave Bus Interface S_CFG_AXI
    s_cfg_axi_aclk    : in  std_logic;
    s_cfg_axi_aresetn : in  std_logic;
    s_cfg_axi_awaddr  : in  std_logic_vector(C_S_CFG_AXI_ADDR_WIDTH-1 downto 0);
    s_cfg_axi_awprot  : in  std_logic_vector(2 downto 0);
    s_cfg_axi_awvalid : in  std_logic;
    s_cfg_axi_awready : out std_logic;
    s_cfg_axi_wdata   : in  std_logic_vector(C_S_CFG_AXI_DATA_WIDTH-1 downto 0);
    s_cfg_axi_wstrb   : in  std_logic_vector((C_S_CFG_AXI_DATA_WIDTH/8)-1 downto 0);
    s_cfg_axi_wvalid  : in  std_logic;
    s_cfg_axi_wready  : out std_logic;
    s_cfg_axi_bresp   : out std_logic_vector(1 downto 0);
    s_cfg_axi_bvalid  : out std_logic;
    s_cfg_axi_bready  : in  std_logic;
    s_cfg_axi_araddr  : in  std_logic_vector(C_S_CFG_AXI_ADDR_WIDTH-1 downto 0);
    s_cfg_axi_arprot  : in  std_logic_vector(2 downto 0);
    s_cfg_axi_arvalid : in  std_logic;
    s_cfg_axi_arready : out std_logic;
    s_cfg_axi_rdata   : out std_logic_vector(C_S_CFG_AXI_DATA_WIDTH-1 downto 0);
    s_cfg_axi_rresp   : out std_logic_vector(1 downto 0);
    s_cfg_axi_rvalid  : out std_logic;
    s_cfg_axi_rready  : in  std_logic
    );
end gem_loader_v_v1_0;

architecture arch_imp of gem_loader_v_v1_0 is

  -- component declaration
  component gem_loader_v_v1_0_S_C2C_AXI is
    generic (
      C_S_AXI_ID_WIDTH     : integer := 1;
      C_S_AXI_DATA_WIDTH   : integer := 32;
      C_S_AXI_ADDR_WIDTH   : integer := 6;
      C_S_AXI_AWUSER_WIDTH : integer := 0;
      C_S_AXI_ARUSER_WIDTH : integer := 0;
      C_S_AXI_WUSER_WIDTH  : integer := 0;
      C_S_AXI_RUSER_WIDTH  : integer := 0;
      C_S_AXI_BUSER_WIDTH  : integer := 0
      );
    port (

      fifo_wr_en_o   : out std_logic;
      fifo_wr_data_o : out std_logic_vector(31 downto 0);

      S_AXI_ACLK     : in  std_logic;
      S_AXI_ARESETN  : in  std_logic;
      S_AXI_AWID     : in  std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
      S_AXI_AWADDR   : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
      S_AXI_AWLEN    : in  std_logic_vector(7 downto 0);
      S_AXI_AWSIZE   : in  std_logic_vector(2 downto 0);
      S_AXI_AWBURST  : in  std_logic_vector(1 downto 0);
      S_AXI_AWLOCK   : in  std_logic;
      S_AXI_AWCACHE  : in  std_logic_vector(3 downto 0);
      S_AXI_AWPROT   : in  std_logic_vector(2 downto 0);
      S_AXI_AWQOS    : in  std_logic_vector(3 downto 0);
      S_AXI_AWREGION : in  std_logic_vector(3 downto 0);
      S_AXI_AWUSER   : in  std_logic_vector(C_S_AXI_AWUSER_WIDTH-1 downto 0);
      S_AXI_AWVALID  : in  std_logic;
      S_AXI_AWREADY  : out std_logic;
      S_AXI_WDATA    : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
      S_AXI_WSTRB    : in  std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
      S_AXI_WLAST    : in  std_logic;
      S_AXI_WUSER    : in  std_logic_vector(C_S_AXI_WUSER_WIDTH-1 downto 0);
      S_AXI_WVALID   : in  std_logic;
      S_AXI_WREADY   : out std_logic;
      S_AXI_BID      : out std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
      S_AXI_BRESP    : out std_logic_vector(1 downto 0);
      S_AXI_BUSER    : out std_logic_vector(C_S_AXI_BUSER_WIDTH-1 downto 0);
      S_AXI_BVALID   : out std_logic;
      S_AXI_BREADY   : in  std_logic;
      S_AXI_ARID     : in  std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
      S_AXI_ARADDR   : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
      S_AXI_ARLEN    : in  std_logic_vector(7 downto 0);
      S_AXI_ARSIZE   : in  std_logic_vector(2 downto 0);
      S_AXI_ARBURST  : in  std_logic_vector(1 downto 0);
      S_AXI_ARLOCK   : in  std_logic;
      S_AXI_ARCACHE  : in  std_logic_vector(3 downto 0);
      S_AXI_ARPROT   : in  std_logic_vector(2 downto 0);
      S_AXI_ARQOS    : in  std_logic_vector(3 downto 0);
      S_AXI_ARREGION : in  std_logic_vector(3 downto 0);
      S_AXI_ARUSER   : in  std_logic_vector(C_S_AXI_ARUSER_WIDTH-1 downto 0);
      S_AXI_ARVALID  : in  std_logic;
      S_AXI_ARREADY  : out std_logic;
      S_AXI_RID      : out std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
      S_AXI_RDATA    : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
      S_AXI_RRESP    : out std_logic_vector(1 downto 0);
      S_AXI_RLAST    : out std_logic;
      S_AXI_RUSER    : out std_logic_vector(C_S_AXI_RUSER_WIDTH-1 downto 0);
      S_AXI_RVALID   : out std_logic;
      S_AXI_RREADY   : in  std_logic
      );
  end component gem_loader_v_v1_0_S_C2C_AXI;

  component gem_loader_v_v1_0_S_CFG_AXI is
    generic (
      C_S_AXI_DATA_WIDTH : integer := 32;
      C_S_AXI_ADDR_WIDTH : integer := 5
      );
    port (
      S_AXI_ACLK    : in  std_logic;
      S_AXI_ARESETN : in  std_logic;
      S_AXI_AWADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
      S_AXI_AWPROT  : in  std_logic_vector(2 downto 0);
      S_AXI_AWVALID : in  std_logic;
      S_AXI_AWREADY : out std_logic;
      S_AXI_WDATA   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
      S_AXI_WSTRB   : in  std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
      S_AXI_WVALID  : in  std_logic;
      S_AXI_WREADY  : out std_logic;
      S_AXI_BRESP   : out std_logic_vector(1 downto 0);
      S_AXI_BVALID  : out std_logic;
      S_AXI_BREADY  : in  std_logic;
      S_AXI_ARADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
      S_AXI_ARPROT  : in  std_logic_vector(2 downto 0);
      S_AXI_ARVALID : in  std_logic;
      S_AXI_ARREADY : out std_logic;
      S_AXI_RDATA   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
      S_AXI_RRESP   : out std_logic_vector(1 downto 0);
      S_AXI_RVALID  : out std_logic;
      S_AXI_RREADY  : in  std_logic;
    -- 
      reload_master_en            : out std_logic;                        -- slv_reg0
      reload_byte_cnt_requested   : out std_logic_vector(31 downto 0);    -- slv_reg1
      reload_request_sw           : out std_logic;                        -- slv_reg2
      
      reload_granted_cnt     : in std_logic_vector(31 downto 0);          -- slv_reg3
      fifo_overflow_cnt      : in std_logic_vector(31 downto 0);          -- slv_reg4
      fifo_underflow_cnt     : in std_logic_vector(31 downto 0)           -- slv_reg5

      );
  end component gem_loader_v_v1_0_S_CFG_AXI;

  component gem_loader_v_fifo
    port (
      rst              : in  std_logic;
      wr_clk           : in  std_logic;
      rd_clk           : in  std_logic;
      din              : in  std_logic_vector(31 downto 0);
      wr_en            : in  std_logic;
      rd_en            : in  std_logic;
      prog_full_thresh : in  std_logic_vector(11 downto 0);
      dout             : out std_logic_vector(7 downto 0);
      full             : out std_logic;
      overflow         : out std_logic;
      empty            : out std_logic;
      underflow        : out std_logic;
      wr_data_count    : out std_logic_vector(9 downto 0);
      prog_full        : out std_logic
      );
  end component; 

  signal s_fifo_din              : std_logic_vector(31 downto 0);
  signal s_fifo_din_endian_conv  : std_logic_vector(31 downto 0);
  
  signal s_fifo_wr_en            : std_logic;
  signal s_fifo_rd_en            : std_logic;
  signal s_fifo_rd_en_d1         : std_logic;

  signal s_fifo_prog_full_thresh : std_logic_vector(11 downto 0);
  signal s_fifo_dout             : std_logic_vector(7 downto 0);
  signal s_fifo_full             : std_logic;
  signal s_fifo_overflow         : std_logic;
  signal s_fifo_empty            : std_logic;
  signal s_fifo_underflow        : std_logic;
  signal s_fifo_wr_data_count    : std_logic_vector(9 downto 0);
  signal s_fifo_prog_full        : std_logic;

  signal s_reload_byte_cnt_requested : std_logic_vector(31 downto 0);
  signal s_reload_cnt                : std_logic_vector(31 downto 0);

  signal s_fifo_rst : std_logic;

  signal reload_request_cntup : std_logic_vector(7 downto 0) := x"FF";

  signal s_reload_request_reg  : std_logic;
  signal s_reload_request_d1   : std_logic;
  signal s_reload_request_edge : std_logic;

  signal s_reload_request_remote   : std_logic;
  signal s_reload_fifo_full_remote : std_logic;

  signal s_reload_request_rem   : std_logic;
  signal s_reload_fifo_full_rem : std_logic;

  signal s_reload_start_reg  : std_logic;
  signal s_reload_start_d1   : std_logic;
  signal s_reload_start_edge : std_logic;
  
  signal s_reload_request_sw : std_logic;
  signal s_reload_request_sw_pulse : std_logic;
  
  signal s_reload_master_en  : std_logic;
  
  signal s_fifo_overflow_cnt      : std_logic_vector(31 downto 0);
  signal s_fifo_underflow_cnt     : std_logic_vector(31 downto 0);

  signal s_fifo_overflow_d1         : std_logic;
  signal s_fifo_underflow_d1        : std_logic;
  
  signal s_reload_granted_cnt     : std_logic_vector(31 downto 0);

--  attribute mark_debug : string;
--  attribute keep : string;
  
--  attribute mark_debug of s_fifo_din     : signal is "true";
--  attribute mark_debug of s_fifo_din_endian_conv     : signal is "true";
--  attribute mark_debug of s_fifo_wr_en     : signal is "true";
--  attribute mark_debug of s_fifo_rd_en     : signal is "true";
--  attribute mark_debug of s_fifo_rd_en_d1     : signal is "true";
--  attribute mark_debug of s_fifo_prog_full_thresh     : signal is "true";
--  attribute mark_debug of s_fifo_dout     : signal is "true";
--  attribute mark_debug of s_fifo_full     : signal is "true";
--  attribute mark_debug of s_fifo_overflow     : signal is "true";
--  attribute mark_debug of s_fifo_empty     : signal is "true";
--  attribute mark_debug of s_fifo_underflow     : signal is "true";
--  attribute mark_debug of s_fifo_wr_data_count     : signal is "true";
--  attribute mark_debug of s_fifo_prog_full     : signal is "true";
--  attribute mark_debug of s_reload_byte_cnt_requested     : signal is "true";
--  attribute mark_debug of s_reload_cnt     : signal is "true";
--  attribute mark_debug of s_fifo_rst     : signal is "true";
--  attribute mark_debug of reload_request_cntup     : signal is "true";
--  attribute mark_debug of s_reload_request_reg     : signal is "true";
--  attribute mark_debug of s_reload_request_d1     : signal is "true";
--  attribute mark_debug of s_reload_request_edge     : signal is "true";
--  attribute mark_debug of s_reload_request_remote     : signal is "true";
--  attribute mark_debug of s_reload_fifo_full_remote     : signal is "true";
--  attribute mark_debug of s_reload_request_rem     : signal is "true";
--  attribute mark_debug of s_reload_fifo_full_rem     : signal is "true";
--  attribute mark_debug of s_reload_start_reg     : signal is "true";
--  attribute mark_debug of s_reload_start_d1     : signal is "true";
--  attribute mark_debug of s_reload_start_edge     : signal is "true";
--  attribute mark_debug of s_reload_request_sw     : signal is "true";
--  attribute mark_debug of s_reload_request_sw_pulse     : signal is "true";
--  attribute mark_debug of s_reload_master_en     : signal is "true";
--  attribute mark_debug of s_fifo_overflow_cnt     : signal is "true";
--  attribute mark_debug of s_fifo_underflow_cnt     : signal is "true";
--  attribute mark_debug of s_fifo_overflow_d1     : signal is "true";
--  attribute mark_debug of s_fifo_underflow_d1     : signal is "true";
--  attribute mark_debug of s_reload_granted_cnt     : signal is "true";

begin

  gem_loader_v_v1_0_S_C2C_AXI_inst : gem_loader_v_v1_0_S_C2C_AXI
    generic map (
      C_S_AXI_ID_WIDTH     => C_S_C2C_AXI_ID_WIDTH,
      C_S_AXI_DATA_WIDTH   => C_S_C2C_AXI_DATA_WIDTH,
      C_S_AXI_ADDR_WIDTH   => C_S_C2C_AXI_ADDR_WIDTH,
      C_S_AXI_AWUSER_WIDTH => C_S_C2C_AXI_AWUSER_WIDTH,
      C_S_AXI_ARUSER_WIDTH => C_S_C2C_AXI_ARUSER_WIDTH,
      C_S_AXI_WUSER_WIDTH  => C_S_C2C_AXI_WUSER_WIDTH,
      C_S_AXI_RUSER_WIDTH  => C_S_C2C_AXI_RUSER_WIDTH,
      C_S_AXI_BUSER_WIDTH  => C_S_C2C_AXI_BUSER_WIDTH
      )
    port map (

      fifo_wr_en_o  => s_fifo_wr_en,
      fifo_wr_data_o => s_fifo_din,
 
      S_AXI_ACLK     => s_c2c_axi_aclk,
      S_AXI_ARESETN  => s_c2c_axi_aresetn,
      S_AXI_AWID     => s_c2c_axi_awid,
      S_AXI_AWADDR   => s_c2c_axi_awaddr,
      S_AXI_AWLEN    => s_c2c_axi_awlen,
      S_AXI_AWSIZE   => s_c2c_axi_awsize,
      S_AXI_AWBURST  => s_c2c_axi_awburst,
      S_AXI_AWLOCK   => s_c2c_axi_awlock,
      S_AXI_AWCACHE  => s_c2c_axi_awcache,
      S_AXI_AWPROT   => s_c2c_axi_awprot,
      S_AXI_AWQOS    => s_c2c_axi_awqos,
      S_AXI_AWREGION => s_c2c_axi_awregion,
      S_AXI_AWUSER   => s_c2c_axi_awuser,
      S_AXI_AWVALID  => s_c2c_axi_awvalid,
      S_AXI_AWREADY  => s_c2c_axi_awready,
      S_AXI_WDATA    => s_c2c_axi_wdata,
      S_AXI_WSTRB    => s_c2c_axi_wstrb,
      S_AXI_WLAST    => s_c2c_axi_wlast,
      S_AXI_WUSER    => s_c2c_axi_wuser,
      S_AXI_WVALID   => s_c2c_axi_wvalid,
      S_AXI_WREADY   => s_c2c_axi_wready,
      S_AXI_BID      => s_c2c_axi_bid,
      S_AXI_BRESP    => s_c2c_axi_bresp,
      S_AXI_BUSER    => s_c2c_axi_buser,
      S_AXI_BVALID   => s_c2c_axi_bvalid,
      S_AXI_BREADY   => s_c2c_axi_bready,
      S_AXI_ARID     => s_c2c_axi_arid,
      S_AXI_ARADDR   => s_c2c_axi_araddr,
      S_AXI_ARLEN    => s_c2c_axi_arlen,
      S_AXI_ARSIZE   => s_c2c_axi_arsize,
      S_AXI_ARBURST  => s_c2c_axi_arburst,
      S_AXI_ARLOCK   => s_c2c_axi_arlock,
      S_AXI_ARCACHE  => s_c2c_axi_arcache,
      S_AXI_ARPROT   => s_c2c_axi_arprot,
      S_AXI_ARQOS    => s_c2c_axi_arqos,
      S_AXI_ARREGION => s_c2c_axi_arregion,
      S_AXI_ARUSER   => s_c2c_axi_aruser,
      S_AXI_ARVALID  => s_c2c_axi_arvalid,
      S_AXI_ARREADY  => s_c2c_axi_arready,
      S_AXI_RID      => s_c2c_axi_rid,
      S_AXI_RDATA    => s_c2c_axi_rdata,
      S_AXI_RRESP    => s_c2c_axi_rresp,
      S_AXI_RLAST    => s_c2c_axi_rlast,
      S_AXI_RUSER    => s_c2c_axi_ruser,
      S_AXI_RVALID   => s_c2c_axi_rvalid,
      S_AXI_RREADY   => s_c2c_axi_rready
      );
 
  gem_loader_v_v1_0_S_CFG_AXI_inst : gem_loader_v_v1_0_S_CFG_AXI 
    generic map (
      C_S_AXI_DATA_WIDTH => C_S_CFG_AXI_DATA_WIDTH,
      C_S_AXI_ADDR_WIDTH => C_S_CFG_AXI_ADDR_WIDTH
      )
    port map (
      S_AXI_ACLK    => s_cfg_axi_aclk,
      S_AXI_ARESETN => s_cfg_axi_aresetn,
      S_AXI_AWADDR  => s_cfg_axi_awaddr,
      S_AXI_AWPROT  => s_cfg_axi_awprot,
      S_AXI_AWVALID => s_cfg_axi_awvalid,
      S_AXI_AWREADY => s_cfg_axi_awready,
      S_AXI_WDATA   => s_cfg_axi_wdata,
      S_AXI_WSTRB   => s_cfg_axi_wstrb,
      S_AXI_WVALID  => s_cfg_axi_wvalid,
      S_AXI_WREADY  => s_cfg_axi_wready,
      S_AXI_BRESP   => s_cfg_axi_bresp,
      S_AXI_BVALID  => s_cfg_axi_bvalid,
      S_AXI_BREADY  => s_cfg_axi_bready,
      S_AXI_ARADDR  => s_cfg_axi_araddr,
      S_AXI_ARPROT  => s_cfg_axi_arprot,
      S_AXI_ARVALID => s_cfg_axi_arvalid,
      S_AXI_ARREADY => s_cfg_axi_arready,
      S_AXI_RDATA   => s_cfg_axi_rdata,
      S_AXI_RRESP   => s_cfg_axi_rresp,
      S_AXI_RVALID  => s_cfg_axi_rvalid,
      S_AXI_RREADY  => s_cfg_axi_rready,
      -- 
      reload_master_en            => s_reload_master_en,
      reload_byte_cnt_requested   => s_reload_byte_cnt_requested,
      reload_request_sw           => s_reload_request_sw,
      
      reload_granted_cnt     => s_reload_granted_cnt,
      fifo_overflow_cnt      => s_fifo_overflow_cnt,
      fifo_underflow_cnt     => s_fifo_underflow_cnt   
      
      );

  reload_size <= s_reload_byte_cnt_requested;
  s_fifo_prog_full_thresh <= std_logic_vector(to_unsigned(2048, 12));

  i_gem_loader_v_fifo : gem_loader_v_fifo
    port map (
      rst              => s_fifo_rst,
      wr_clk           => s_c2c_axi_aclk,
      rd_clk           => clk_reload,
      din              => s_fifo_din_endian_conv,
      wr_en            => s_fifo_wr_en,
      rd_en            => s_fifo_rd_en,
      prog_full_thresh => s_fifo_prog_full_thresh,
      dout             => s_fifo_dout,
      full             => s_fifo_full,
      overflow         => s_fifo_overflow,
      empty            => s_fifo_empty,
      underflow        => s_fifo_underflow,
      wr_data_count    => s_fifo_wr_data_count,
      prog_full        => s_fifo_prog_full
      );
            
  process (s_c2c_axi_aclk)
      begin
        if rising_edge(s_c2c_axi_aclk) then
            
          s_fifo_overflow_d1 <= s_fifo_overflow;
            
            if (s_fifo_overflow_d1 = '0' and s_fifo_overflow = '1' and s_reload_master_en = '1') then
              s_fifo_overflow_cnt <= std_logic_vector((unsigned(s_fifo_overflow_cnt) + 1));
            end if;
        end if;
  end process;    
            
  process (clk_reload)
      begin
        if rising_edge(clk_reload) then
        
          s_fifo_underflow_d1 <= s_fifo_underflow;
        
          if (s_fifo_underflow_d1 = '0' and s_fifo_underflow = '1' and s_reload_master_en = '1') then
            s_fifo_underflow_cnt <= std_logic_vector((unsigned(s_fifo_underflow_cnt) + 1));
          end if;
       end if;
  end process;    
  
    
gen_endian_conv_true: if C_FIFO_ENDIAN_CONV_ENABLE = true  generate 
        s_fifo_din_endian_conv(7 downto 0)   <= s_fifo_din(31 downto 24);
        s_fifo_din_endian_conv(15 downto 8)  <= s_fifo_din(23 downto 16);
        s_fifo_din_endian_conv(23 downto 16) <= s_fifo_din(15 downto 8);
        s_fifo_din_endian_conv(31 downto 24) <= s_fifo_din(7 downto 0);
end generate;      

gen_endian_conv_false: if C_FIFO_ENDIAN_CONV_ENABLE = false  generate 
        s_fifo_din_endian_conv   <= s_fifo_din;
end generate;  

  process (clk_reload)
  begin
    if rising_edge(clk_reload) then
      if ((s_reload_request_edge = '1' or s_reload_request_sw_pulse = '1') and s_reload_master_en = '1')  then
        s_fifo_rd_en <= '0';
      elsif (s_reload_cnt = s_reload_byte_cnt_requested) then
        s_fifo_rd_en <= '0';
      elsif (s_reload_start_edge = '1') then
        s_fifo_rd_en <= '1';
      end if;
    end if;
  end process;

  process (clk_reload)
  begin
    if rising_edge(clk_reload) then
      if ((s_reload_request_edge = '1' or s_reload_request_sw_pulse = '1') and s_reload_master_en = '1')  then
           s_reload_granted_cnt <= std_logic_vector(unsigned(s_reload_granted_cnt) + 1);
      end if;
    end if;
  end process;

  process (clk_reload)
  begin
    if rising_edge(clk_reload) then
      if (s_reload_start_edge = '1') then
        s_reload_cnt <= x"00000001";
      elsif (s_fifo_rd_en = '1') then
        s_reload_cnt <= std_logic_vector((unsigned(s_reload_cnt) + 1));
      end if;
    end if;
  end process;


  process (clk_reload)
  begin
    if rising_edge(clk_reload) then
      if (s_reload_request_edge = '1' or s_reload_request_sw_pulse = '1') then
        reload_ready <= '0';
      elsif (s_fifo_prog_full = '1' and s_fifo_rst = '0') then
        reload_ready <= '1';
      end if;
    end if;
  end process;

  process (clk_reload)
  begin
    if rising_edge(clk_reload) then
      if ((s_reload_request_edge = '1' or s_reload_request_sw_pulse = '1') and s_reload_master_en = '1')  then
        reload_error <= '0';
      elsif (s_fifo_overflow = '1' or s_fifo_underflow = '1') then
        reload_error <= '1';    
      end if;
    end if;
  end process;
  
  process (clk_reload)
  begin
    if rising_edge(clk_reload) then

      s_reload_request_reg  <= reload_request;
      s_reload_request_d1   <= s_reload_request_reg;
      s_reload_request_edge <= s_reload_request_reg and not s_reload_request_d1;

      s_reload_start_reg  <= reload_start;
      s_reload_start_d1   <= s_reload_start_reg;
      s_reload_start_edge <= s_reload_start_reg and not s_reload_start_d1;

    end if;
  end process;

process (clk_reload)
  begin
    if rising_edge(clk_reload) then
  
    reload_data       <= s_fifo_dout;
    reload_data_valid <= s_fifo_rd_en;
    s_fifo_rd_en_d1 <= s_fifo_rd_en;
    
    if (s_reload_cnt = x"00000001") then
        reload_data_first <= '1';
    else
         reload_data_first <= '0';
    end if;
    
    if (s_reload_cnt = s_reload_byte_cnt_requested and s_fifo_rd_en = '1') then
       reload_data_last <= '1';
    else
        reload_data_last <= '0';
    end if;          
  end if;
end process;
  
  xpm_cdc_pulse_inst: xpm_cdc_pulse
    generic map (
      -- Common module generics
      DEST_SYNC_FF   => 2, -- integer; range: 2-10
      RST_USED       => 0, -- integer; 0=no reset, 1=implement reset
      SIM_ASSERT_CHK => 1  -- integer; 0=disable simulation messages, 1=enable simulation messages
    )
    port map (
  
      src_clk    => s_c2c_axi_aclk,
      src_rst    => '0',   -- optional; required when RST_USED = 1
      src_pulse  => s_reload_request_sw,
      dest_clk   => clk_reload,
      dest_rst   => '0',  -- optional; required when RST_USED = 1
      dest_pulse => s_reload_request_sw_pulse
    );

  s_reload_request_rem   <= '1' when to_integer(unsigned(reload_request_cntup)) < 80  else '0';
  s_reload_fifo_full_rem <= '1' when to_integer(unsigned(reload_request_cntup)) < 120 else '0';
  s_fifo_rst             <= '1' when to_integer(unsigned(reload_request_cntup)) < 40  else '0';

  process (s_c2c_axi_aclk)
  begin
    if rising_edge(s_c2c_axi_aclk) then
      reload_request_remote   <= s_reload_request_rem;
      reload_fifo_full_remote <= s_fifo_prog_full or s_reload_fifo_full_rem;
    end if;
  end process;

  process (clk_reload)
  begin
    if rising_edge(clk_reload) then
      if ((s_reload_request_edge = '1' or s_reload_request_sw_pulse = '1') and s_reload_master_en = '1')  then
        reload_request_cntup <= x"00";
      elsif (reload_request_cntup = x"FF") then
        reload_request_cntup <= reload_request_cntup;
      else
        reload_request_cntup <= std_logic_vector(unsigned(reload_request_cntup) + 1);
      end if;
    end if;
  end process;

end arch_imp;
