library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

entity gem_loader_virtex is
    generic (
        -- Parameters of the user interface
        C_FIFO_ENDIAN_CONV_ENABLE : boolean := false;

        -- Parameters of the AXI C2C slave bus interface
        C_S_C2C_AXI_ID_WIDTH     : integer := 0;
        C_S_C2C_AXI_DATA_WIDTH   : integer := 32;
        C_S_C2C_AXI_ADDR_WIDTH   : integer := 32;
        C_S_C2C_AXI_AWUSER_WIDTH : integer := 0;
        C_S_C2C_AXI_ARUSER_WIDTH : integer := 0;
        C_S_C2C_AXI_WUSER_WIDTH  : integer := 0;
        C_S_C2C_AXI_RUSER_WIDTH  : integer := 0;
        C_S_C2C_AXI_BUSER_WIDTH  : integer := 0;

        -- Parameters of the AXI CFG slave bus interface
        C_S_CFG_AXI_DATA_WIDTH : integer := 32;
        C_S_CFG_AXI_ADDR_WIDTH : integer := 6
    );
    port (
        -- User interface
        gem_loader_clk_i   : in std_logic;
        gem_loader_req_i   : in std_logic;
        gem_loader_data_o  : out std_logic_vector(7 downto 0);
        gem_loader_valid_o : out std_logic;
        gem_loader_error_o : out std_logic;

        -- AXI C2C interrupts
        s_c2c_request_remote   : out std_logic;
        s_c2c_fifo_full_remote : out std_logic;

        -- AXI C2C slave bus interface
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

        -- AXI configuration slave bus interface
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
end gem_loader_virtex;

architecture arch_imp of gem_loader_virtex is

    -- Configuration
    signal enable_aclk : std_logic;
    signal enable      : std_logic;
    signal bytes_requested_cnt : std_logic_vector(31 downto 0);

    -- Loader logic
    signal wr_rst_send     : std_logic := '0';
    signal wr_rst_recv     : std_logic := '0';
    signal fifo_read_ready : std_logic;

    signal wr_rst_req       : std_logic := '0';
    signal wr_rst_ack       : std_logic := '0';
    signal fifo_write_ready : std_logic;

    signal gem_loader_request_cnt : std_logic_vector(7 downto 0) := x"FF";
    signal gem_loader_request     : std_logic;
    signal gem_loader_fifo_full   : std_logic;

    signal gem_loader_byte_cnt  : std_logic_vector(31 downto 0) := (others => '0');
    signal gem_loader_error     : std_logic := '0';

    -- FIFO - write clock domain
    signal fifo_rst              : std_logic;
    signal fifo_wr_rst_busy      : std_logic;
    signal fifo_wr_en            : std_logic;
    signal fifo_din              : std_logic_vector(31 downto 0);
    signal fifo_din_endian_conv  : std_logic_vector(31 downto 0);
    signal fifo_wr_data_count    : std_logic_vector(9 downto 0);
    signal fifo_prog_full        : std_logic;
    signal fifo_overflow         : std_logic;

    -- FIFO - read clock domain
    signal fifo_rd_rst_busy : std_logic;
    signal fifo_rd_en       : std_logic;
    signal fifo_dout        : std_logic_vector(7 downto 0);
    signal fifo_prog_empty  : std_logic;
    signal fifo_underflow   : std_logic;

    -- Monitoring counters and flags
    signal c2c_axi_awready : std_logic;
    signal c2c_axi_wready  : std_logic;
    signal c2c_axi_bvalid  : std_logic;

    signal wr_rst_send_d1    : std_logic;
    signal fifo_overflow_d1  : std_logic;
    signal fifo_underflow_d1 : std_logic;

    signal status             : std_logic_vector(31 downto 0);
    signal request_cnt        : std_logic_vector(31 downto 0);
    signal axi_aw_cnt         : std_logic_vector(31 downto 0);
    signal axi_w_cnt          : std_logic_vector(31 downto 0);
    signal axi_b_cnt          : std_logic_vector(31 downto 0);
    signal fifo_wren_cnt      : std_logic_vector(31 downto 0);
    signal fifo_rden_cnt      : std_logic_vector(31 downto 0);
    signal fifo_overflow_cnt  : std_logic_vector(31 downto 0);
    signal fifo_underflow_cnt : std_logic_vector(31 downto 0);

begin

    -- Loader logic
    gem_loader_error_o <= gem_loader_error;

    process (gem_loader_clk_i)
    begin
        if rising_edge(gem_loader_clk_i) then
            -- Register outputs
            gem_loader_data_o  <= fifo_dout;
            gem_loader_valid_o <= fifo_rd_en;

            -- Keep signals constant
            fifo_rd_en          <= fifo_rd_en;
            wr_rst_send         <= wr_rst_send;
            gem_loader_error    <= gem_loader_error;
            gem_loader_byte_cnt <= gem_loader_byte_cnt;

            -- IDLE
            if (to_integer(unsigned(gem_loader_byte_cnt)) = 0 and wr_rst_send = '0') then
                fifo_rd_en <= '0';

                -- External request
                if (gem_loader_req_i = '1' and enable = '1') then
                    wr_rst_send      <= '1';
                    gem_loader_error <= '0';
                end if;

            -- WRITE RESETTING ACK
            elsif (to_integer(unsigned(gem_loader_byte_cnt)) = 0 and wr_rst_send = '1') then
                -- Reset is ack
                if (wr_rst_recv = '1') then
                    wr_rst_send         <= '0';
                    gem_loader_byte_cnt <= x"00000001";
                end if;

            -- WRITE RESETTING COMPLETION
            elsif (to_integer(unsigned(gem_loader_byte_cnt)) = 1) then
                -- Reset is done and data available
                if (wr_rst_recv = '0' and fifo_prog_empty = '0') then
                    fifo_rd_en          <= '1';
                    gem_loader_byte_cnt <= std_logic_vector(unsigned(gem_loader_byte_cnt) + 1);
                end if;

            -- RUNNING
            elsif (gem_loader_byte_cnt /= std_logic_vector(unsigned(bytes_requested_cnt) + 1)) then
                gem_loader_byte_cnt <= std_logic_vector(unsigned(gem_loader_byte_cnt) + 1);

                -- FIFO monitoring
                if (fifo_overflow = '1' or fifo_underflow = '1') then
                    gem_loader_error <= '1';
                end if;

            -- DONE
            else
                fifo_rd_en          <= '0';
                gem_loader_byte_cnt <= (others => '0');

            end if;
        end if;
    end process;

    fifo_read_ready <= not (wr_rst_send or wr_rst_recv);

    -- FIFO reset
    process (s_c2c_axi_aclk)
    begin
        if rising_edge(s_c2c_axi_aclk) then
            wr_rst_ack <= wr_rst_ack;
            fifo_rst   <= fifo_rst;

            -- IDLE
            if (wr_rst_ack = '0') then
                -- reset
                if (wr_rst_req = '1') then
                    wr_rst_ack <= '1';
                    fifo_rst <= '1';
                else
                    wr_rst_ack <= '0';
                    fifo_rst <= '0';
                end if;

            -- RESETTING
            else
                -- lift FIFO reset as soon as it is ack
                if (fifo_wr_rst_busy = '1') then
                    fifo_rst <= '0';
                end if;

                -- the FIFO reset is done, go back to IDLE
                if (wr_rst_req = '0' and fifo_rst = '0' and fifo_wr_rst_busy = '0') then
                    wr_rst_ack <= '0';
                end if;
            end if;
        end if;
    end process;

    fifo_write_ready <= not (wr_rst_req or wr_rst_ack);

    i_wr_rst_req_cdc : xpm_cdc_single
    generic map (
        DEST_SYNC_FF   => 4,
        INIT_SYNC_FF   => 1,
        SIM_ASSERT_CHK => 1,
        SRC_INPUT_REG  => 1
    )
    port map (
        src_clk  => gem_loader_clk_i,
        src_in   => wr_rst_send,
        dest_clk => s_c2c_axi_aclk,
        dest_out => wr_rst_req
    );

    i_wr_rst_ack_cdc : xpm_cdc_single
    generic map (
        DEST_SYNC_FF   => 4,
        INIT_SYNC_FF   => 1,
        SIM_ASSERT_CHK => 1,
        SRC_INPUT_REG  => 1
    )
    port map (
        src_clk  => s_c2c_axi_aclk,
        src_in   => wr_rst_ack,
        dest_clk => gem_loader_clk_i,
        dest_out => wr_rst_recv
    );

    -- Data streaming
    process (s_c2c_axi_aclk)
    begin
        if rising_edge(s_c2c_axi_aclk) then
            -- Start over whenever the FIFO is reset/not ready for writes
            if (fifo_write_ready = '0') then
                gem_loader_request_cnt <= x"00";
            elsif (gem_loader_request_cnt /= x"FF") then
                gem_loader_request_cnt <= std_logic_vector(unsigned(gem_loader_request_cnt) + 1);
            else
                gem_loader_request_cnt <= gem_loader_request_cnt;
            end if;
        end if;
    end process;

    gem_loader_request   <= '1' when to_integer(unsigned(gem_loader_request_cnt)) < 127 else '0';
    gem_loader_fifo_full <= '1' when to_integer(unsigned(gem_loader_request_cnt)) < 255 else '0';

    s_c2c_request_remote   <= gem_loader_request;
    s_c2c_fifo_full_remote <= (not fifo_write_ready) or gem_loader_fifo_full or fifo_prog_full;

    -- Monitoring counters and flags
    status <= fifo_wr_data_count -- 10 bits
            & gem_loader_error & gem_loader_request & gem_loader_fifo_full & fifo_prog_full -- 4 bits
            & gem_loader_request_cnt -- 8 bits
            & fifo_wr_rst_busy & fifo_rd_rst_busy -- 2 bits
            & wr_rst_recv & wr_rst_ack & wr_rst_req & wr_rst_send -- 4 bits
            & fifo_write_ready & fifo_read_ready & fifo_rst & fifo_prog_empty; -- 4 bits

    process (s_c2c_axi_aclk)
    begin
        if rising_edge(s_c2c_axi_aclk) then
            if (s_c2c_axi_aresetn = '0') then
                axi_aw_cnt <= (others => '0');
                axi_w_cnt <= (others => '0');
                axi_b_cnt <= (others => '0');
                fifo_wren_cnt <= (others => '0');
                fifo_overflow_cnt <= (others => '0');
            else
                if (s_c2c_axi_awvalid = '1' and c2c_axi_awready = '1') then
                    axi_aw_cnt <= std_logic_vector(unsigned(axi_aw_cnt) + 1);
                end if;

                if (s_c2c_axi_wvalid = '1' and c2c_axi_wready = '1') then
                    axi_w_cnt <= std_logic_vector(unsigned(axi_w_cnt) + 1);
                end if;

                if (c2c_axi_bvalid = '1' and s_c2c_axi_bready = '1') then
                    axi_b_cnt <= std_logic_vector(unsigned(axi_b_cnt) + 1);
                end if;

                if (fifo_wr_en = '1' and fifo_write_ready = '1') then
                    fifo_wren_cnt <= std_logic_vector(unsigned(fifo_wren_cnt) + 1);
                end if;

                fifo_overflow_d1 <= fifo_overflow;
                if (fifo_overflow_d1 = '0' and fifo_overflow = '1') then
                    fifo_overflow_cnt <= std_logic_vector((unsigned(fifo_overflow_cnt) + 1));
                end if;
            end if;
        end if;
    end process;

    process (gem_loader_clk_i)
    begin
        if rising_edge(gem_loader_clk_i) then
            wr_rst_send_d1 <= wr_rst_send;
            if (wr_rst_send = '1' and wr_rst_send_d1 = '0')  then
                request_cnt <= std_logic_vector(unsigned(request_cnt) + 1);
            end if;

            if (fifo_rd_en = '1') then
                fifo_rden_cnt <= std_logic_vector(unsigned(fifo_rden_cnt) + 1);
            end if;

            fifo_underflow_d1 <= fifo_underflow;
            if (fifo_underflow_d1 = '0' and fifo_underflow = '1') then
                fifo_underflow_cnt <= std_logic_vector((unsigned(fifo_underflow_cnt) + 1));
            end if;
        end if;
    end process;

    -- Bytes ordering
    gen_endian_conv_true: if C_FIFO_ENDIAN_CONV_ENABLE = true  generate
        fifo_din_endian_conv(7 downto 0)   <= fifo_din(31 downto 24);
        fifo_din_endian_conv(15 downto 8)  <= fifo_din(23 downto 16);
        fifo_din_endian_conv(23 downto 16) <= fifo_din(15 downto 8);
        fifo_din_endian_conv(31 downto 24) <= fifo_din(7 downto 0);
    end generate;

    gen_endian_conv_false: if C_FIFO_ENDIAN_CONV_ENABLE = false  generate
        fifo_din_endian_conv   <= fifo_din;
    end generate;

    -- Components
    i_gem_loader_virtex_s_c2c_axi : entity work.gem_loader_virtex_s_c2c_axi
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
        -- AXI bus
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
        S_AXI_AWREADY  => c2c_axi_awready,
        S_AXI_WDATA    => s_c2c_axi_wdata,
        S_AXI_WSTRB    => s_c2c_axi_wstrb,
        S_AXI_WLAST    => s_c2c_axi_wlast,
        S_AXI_WUSER    => s_c2c_axi_wuser,
        S_AXI_WVALID   => s_c2c_axi_wvalid,
        S_AXI_WREADY   => c2c_axi_wready,
        S_AXI_BID      => s_c2c_axi_bid,
        S_AXI_BRESP    => s_c2c_axi_bresp,
        S_AXI_BUSER    => s_c2c_axi_buser,
        S_AXI_BVALID   => c2c_axi_bvalid,
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
        S_AXI_RREADY   => s_c2c_axi_rready,

        -- Outputs
        fifo_wr_en_o   => fifo_wr_en,
        fifo_wr_data_o => fifo_din
    );

    s_c2c_axi_awready <= c2c_axi_awready;
    s_c2c_axi_wready  <= c2c_axi_wready;
    s_c2c_axi_bvalid  <= c2c_axi_bvalid;

    i_gem_loader_virtex_s_cfg_axi : entity work.gem_loader_virtex_s_cfg_axi
    generic map (
        C_S_AXI_DATA_WIDTH => C_S_CFG_AXI_DATA_WIDTH,
        C_S_AXI_ADDR_WIDTH => C_S_CFG_AXI_ADDR_WIDTH
    )
    port map (
        -- AXI bus
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

        -- Outputs
        enable_o              => enable_aclk,
        bytes_requested_cnt_o => bytes_requested_cnt,

        -- Inputs
        status_i             => status,
        request_cnt_i        => request_cnt,
        axi_aw_cnt_i         => axi_aw_cnt,
        axi_w_cnt_i          => axi_w_cnt,
        axi_b_cnt_i          => axi_b_cnt,
        fifo_wren_cnt_i      => fifo_wren_cnt,
        fifo_rden_cnt_i      => fifo_rden_cnt,
        fifo_overflow_cnt_i  => fifo_overflow_cnt,
        fifo_underflow_cnt_i => fifo_underflow_cnt
    );

    i_enable_cdc : xpm_cdc_single
    generic map (
        DEST_SYNC_FF   => 4,
        INIT_SYNC_FF   => 1,
        SIM_ASSERT_CHK => 1,
        SRC_INPUT_REG  => 1
    )
    port map (
        src_clk  => s_cfg_axi_aclk,
        src_in   => enable_aclk,
        dest_clk => gem_loader_clk_i,
        dest_out => enable
    );


    i_gem_loader_virtex_fifo : xpm_fifo_async
    generic map(
        FIFO_MEMORY_TYPE    => "block",
        FIFO_WRITE_DEPTH    => 4096,
        WR_DATA_COUNT_WIDTH => 10,
        RELATED_CLOCKS      => 0,
        WRITE_DATA_WIDTH    => 32,
        READ_MODE           => "fwft",
        FIFO_READ_LATENCY   => 0,
        FULL_RESET_VALUE    => 0,
        USE_ADV_FEATURES    => "0207", -- VALID(12) = 0 ; AEMPTY(11) = 0; RD_DATA_CNT(10) = 0; PROG_EMPTY(9) = 1; UNDERFLOW(8) = 1; -- WR_ACK(4) = 0; AFULL(3) = 0; WR_DATA_CNT(2) = 1; PROG_FULL(1) = 1; OVERFLOW(0) = 1
        READ_DATA_WIDTH     => 8,
        CDC_SYNC_STAGES     => 2,
        PROG_FULL_THRESH    => 2048,
        PROG_EMPTY_THRESH   => 2048,
        DOUT_RESET_VALUE    => "0",
        ECC_MODE            => "no_ecc"
    )
    port map(
        sleep         => '0',
        rst           => fifo_rst,
        wr_clk        => s_c2c_axi_aclk,
        wr_en         => fifo_wr_en and fifo_write_ready,
        din           => fifo_din_endian_conv,
        full          => open,
        prog_full     => fifo_prog_full,
        wr_data_count => fifo_wr_data_count,
        overflow      => fifo_overflow,
        wr_rst_busy   => fifo_wr_rst_busy,
        almost_full   => open,
        wr_ack        => open,
        rd_clk        => gem_loader_clk_i,
        rd_en         => fifo_rd_en,
        dout          => fifo_dout,
        empty         => open,
        prog_empty    => fifo_prog_empty,
        rd_data_count => open,
        underflow     => fifo_underflow,
        rd_rst_busy   => fifo_rd_rst_busy,
        almost_empty  => open,
        data_valid    => open,
        injectsbiterr => '0',
        injectdbiterr => '0',
        sbiterr       => open,
        dbiterr       => open
    );

end arch_imp;
