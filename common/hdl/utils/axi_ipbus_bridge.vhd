------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    20:10:11 2016-04-20
-- Module Name:    AXI_IPBUS_BRIDGE 
-- Description:    This module is acting as an AXI4-lite slave and translates the read and write requests to an IPBus protocol effectively 
--                 acting as IPbus master which can drive multiple IPbus slaves. It only adds 2 clocks of latency. 
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ipbus.all;
use work.ipb_addr_decode.all;

entity axi_ipbus_bridge is
	generic (
	    C_NUM_IPB_SLAVES : integer := 64;
		-- Width of S_AXI data bus
		C_S_AXI_DATA_WIDTH	: integer	:= 32;
		-- Width of S_AXI address bus
		C_S_AXI_ADDR_WIDTH	: integer	:= 26;
        C_DEBUG : boolean := false
	);
	port (
	    -- IPbus reset (active high)
	    ipb_reset_o : out std_logic;
        -- IPbus clock
        ipb_clk_o   : out std_logic;        
        -- slave to master IPbus
        ipb_miso_i  : in ipb_rbus_array(C_NUM_IPB_SLAVES-1 downto 0);
        -- master to slave IPbus
        ipb_mosi_o  : out ipb_wbus_array(C_NUM_IPB_SLAVES-1 downto 0);  
    
        read_active_o : out std_logic;
        write_active_o : out std_logic;
    
		-- Global Clock Signal
		S_AXI_ACLK	: in std_logic;
		-- Global Reset Signal. This Signal is Active LOW
		S_AXI_ARESETN	: in std_logic;
		-- Write address (issued by master, acceped by Slave)
		S_AXI_AWADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		-- Write channel Protection type. This signal indicates the
    		-- privilege and security level of the transaction, and whether
    		-- the transaction is a data access or an instruction access.
		S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
		-- Write address valid. This signal indicates that the master signaling
    		-- valid write address and control information.
		S_AXI_AWVALID	: in std_logic;
		-- Write address ready. This signal indicates that the slave is ready
    		-- to accept an address and associated control signals.
		S_AXI_AWREADY	: out std_logic;
		-- Write data (issued by master, acceped by Slave) 
		S_AXI_WDATA	: in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		-- Write strobes. This signal indicates which byte lanes hold
    		-- valid data. There is one write strobe bit for each eight
    		-- bits of the write data bus.    
		S_AXI_WSTRB	: in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
		-- Write valid. This signal indicates that valid write
    		-- data and strobes are available.
		S_AXI_WVALID	: in std_logic;
		-- Write ready. This signal indicates that the slave
    		-- can accept the write data.
		S_AXI_WREADY	: out std_logic;
		-- Write response. This signal indicates the status
    		-- of the write transaction.
		S_AXI_BRESP	: out std_logic_vector(1 downto 0);
		-- Write response valid. This signal indicates that the channel
    		-- is signaling a valid write response.
		S_AXI_BVALID	: out std_logic;
		-- Response ready. This signal indicates that the master
    		-- can accept a write response.
		S_AXI_BREADY	: in std_logic;
		-- Read address (issued by master, acceped by Slave)
		S_AXI_ARADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		-- Protection type. This signal indicates the privilege
    		-- and security level of the transaction, and whether the
    		-- transaction is a data access or an instruction access.
		S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
		-- Read address valid. This signal indicates that the channel
    		-- is signaling valid read address and control information.
		S_AXI_ARVALID	: in std_logic;
		-- Read address ready. This signal indicates that the slave is
    		-- ready to accept an address and associated control signals.
		S_AXI_ARREADY	: out std_logic;
		-- Read data (issued by slave)
		S_AXI_RDATA	: out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		-- Read response. This signal indicates the status of the
    		-- read transfer.
		S_AXI_RRESP	: out std_logic_vector(1 downto 0);
		-- Read valid. This signal indicates that the channel is
    		-- signaling the required read data.
		S_AXI_RVALID	: out std_logic;
		-- Read ready. This signal indicates that the master can
    		-- accept the read data and response information.
		S_AXI_RREADY	: in std_logic
	);
end axi_ipbus_bridge;

architecture arch_imp of axi_ipbus_bridge is

  component ila_axi_ipbus_bridge is
    port (
      clk         : in std_logic;
      probe0      : in std_logic;
      probe1      : in std_logic_vector(31 downto 0);
      probe2      : in std_logic_vector(2 downto 0);
      probe3      : in std_logic;
      probe4      : in std_logic_vector(31 downto 0);
      probe5      : in std_logic_vector(3 downto 0);
      probe6      : in std_logic;
      probe7      : in std_logic;
      probe8      : in std_logic_vector(31 downto 0);
      probe9      : in std_logic_vector(2 downto 0);
      probe10     : in std_logic;
      probe11     : in std_logic;
      probe12     : in std_logic_vector(31 downto 0);
      probe13     : in std_logic;
      probe14     : in std_logic;
      probe15     : in std_logic_vector(1 downto 0);
      probe16     : in std_logic;
      probe17     : in std_logic_vector(31 downto 0);
      probe18     : in std_logic;
      probe19     : in std_logic_vector(31 downto 0);
      probe20     : in std_logic_vector(1 downto 0);
      probe21     : in std_logic;
      probe22     : in std_logic_vector(31 downto 0);
      probe23     : in std_logic_vector(31 downto 0);
      probe24     : in std_logic;
      probe25     : in std_logic;
      probe26     : in std_logic_vector(31 downto 0);
      probe27     : in std_logic;
      probe28     : in std_logic;
      probe29     : in std_logic_vector(7 downto 0)
    );
  end component ila_axi_ipbus_bridge;

    signal transaction_cnt  : unsigned(15 downto 0) := (others => '0');

	-- AXI4LITE signals
    signal axi_awready     : std_logic;
    signal axi_wready      : std_logic;
    signal axi_wdata       : std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
    signal axi_bresp       : std_logic_vector(1 downto 0);
    signal axi_bvalid      : std_logic;
    signal axi_arready     : std_logic;
    signal axi_rdata       : std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
    signal axi_rresp       : std_logic_vector(1 downto 0);
    signal axi_rvalid      : std_logic;
    signal axi_word_araddr : std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);
    signal axi_word_awaddr : std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);

    signal debug_awaddr : std_logic_vector(31 downto 0) := (others => '0');
    signal debug_araddr : std_logic_vector(31 downto 0) := (others => '0');

	------------------------------------------------
	---- IPBus
	--------------------------------------------------

  constant ipb_timeout      : unsigned(23 downto 0) := x"000bb8"; --x"0000f5"; -- 254 clocks to ~match the 255 cycle limit on the Zynq fw --x"027100"; -- 3000 clock cycles = ~60us
  signal ipb_clk            : std_logic;
  signal ipb_state          : t_axi_ipb_state;
  signal ipb_timer          : unsigned(23 downto 0) := (others => '0');
  signal ipb_mosi           : ipb_wbus_array(C_NUM_IPB_SLAVES-1 downto 0);-- := (others => (ipb_addr => (others => '0'), ipb_wdata => (others => '0'), ipb_strobe => '0', ipb_write => '0'));
  signal ipb_slv_select     : integer range 0 to C_NUM_IPB_SLAVES-1 := 0; -- ipbus slave select

begin
	-- I/O Connections assignments
    ipb_clk_o <= ipb_clk; 
    ipb_clk <= S_AXI_ACLK;
    ipb_mosi_o <= ipb_mosi;
    ipb_reset_o <= not S_AXI_ARESETN;

	S_AXI_AWREADY	<= axi_awready;
	S_AXI_WREADY	<= axi_wready;
	S_AXI_BRESP	<= axi_bresp;
	S_AXI_BVALID	<= axi_bvalid;
	S_AXI_ARREADY	<= axi_arready;
	S_AXI_RDATA	<= axi_rdata;
	S_AXI_RRESP	<= axi_rresp;
	S_AXI_RVALID	<= axi_rvalid;

    axi_word_araddr <= "00" & S_AXI_ARADDR(C_S_AXI_ADDR_WIDTH-1 downto 2);
    axi_word_awaddr <= "00" & S_AXI_AWADDR(C_S_AXI_ADDR_WIDTH-1 downto 2);

    read_active_o <= '1' when ipb_state = READ else '0';
    write_active_o <= '1' when ipb_state = WRITE else '0';

  -- main FSM
  process(ipb_clk)   
  begin    
    if (rising_edge(ipb_clk)) then    
      -- reset  
      if (S_AXI_ARESETN = '0') then    
        ipb_mosi    <= (others => (ipb_addr => (others => '0'), ipb_wdata => (others => '0'), ipb_strobe => '0', ipb_write => '0')); 
        ipb_state   <= IDLE;
        ipb_timer   <= (others => '0');
        axi_arready <= '0';
        axi_rdata   <= (others => '0');
        axi_rvalid  <= '0';
        axi_rresp   <= "00";
        axi_awready <= '0';
        axi_wready  <= '0';
        ipb_slv_select <= 0;
        transaction_cnt <= (others => '0');
      else    
        -- main state machine     
        case ipb_state is
        
          -- check for read and write requests
          when IDLE =>
            ipb_mosi(ipb_slv_select) <= (ipb_addr => (others => '0'), ipb_wdata => (others => '0'), ipb_strobe => '0', ipb_write => '0'); 
            ipb_timer <= (others => '0');
            axi_wdata <= (others => '0');
            
            -- axi read request
            if (S_AXI_ARVALID = '1') then
              axi_arready <= '1';
              ipb_slv_select <= ipb_addr_sel(axi_word_araddr);
              ipb_state <= READ;
              transaction_cnt <= transaction_cnt + 1;
            
            -- axi write request
            elsif (S_AXI_AWVALID = '1' and S_AXI_WVALID = '1') then
              axi_awready <= '1';
              axi_wready <= '1';
              ipb_slv_select <= ipb_addr_sel(axi_word_awaddr);
              transaction_cnt <= transaction_cnt + 1;
              
              -- Respective byte enables are asserted as per write strobes                   
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  axi_wdata(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
              
              ipb_state <= WRITE;
            end if;
          
--          -- initiate IPBus read request
          when READ =>
            -- address ok
            if (ipb_slv_select /= 999) then
              axi_arready <= '0';
              ipb_mosi(ipb_slv_select).ipb_addr(C_S_AXI_ADDR_WIDTH-3 downto 0) <= S_AXI_ARADDR(C_S_AXI_ADDR_WIDTH-1 downto 2);
              ipb_mosi(ipb_slv_select).ipb_strobe <= '1';
              ipb_mosi(ipb_slv_select).ipb_write <= '0';
              ipb_state <= WAIT_FOR_READ_ACK;
              
            -- addressing error - no IPBus slave at this address
            else
              ipb_mosi(ipb_slv_select) <= (ipb_addr => (others => '0'), ipb_wdata => (others => '0'), ipb_strobe => '0', ipb_write => '0'); 
              ipb_state <= AXI_READ_HANDSHAKE;
              ipb_timer <= (others => '0');
              axi_rdata <= (others => '0');
              axi_rvalid <= '1';
              axi_rresp <= "11"; -- DECERR: decode error response              
            end if;
        
          -- wait for IPbus read ack
          when WAIT_FOR_READ_ACK =>
            -- got ack from IPBus
            if (ipb_miso_i(ipb_slv_select).ipb_ack = '1') then
              ipb_mosi(ipb_slv_select) <= (ipb_addr => (others => '0'), ipb_wdata => (others => '0'), ipb_strobe => '0', ipb_write => '0'); 
              ipb_state <= AXI_READ_HANDSHAKE;
              ipb_timer <= (others => '0');
              axi_rdata <= ipb_miso_i(ipb_slv_select).ipb_rdata;
              axi_rvalid <= '1';
              if (ipb_miso_i(ipb_slv_select).ipb_err = '0') then
                axi_rresp <= "00"; -- OKAY response
              else
                axi_rresp <= "10"; -- SLVERR: slave error response
              end if;
              
            -- IPbus timed out
            elsif (ipb_timer > ipb_timeout) then
              ipb_state <= AXI_READ_HANDSHAKE;
              ipb_timer <= (others => '0');
              axi_rdata <= (others => '0');
              axi_rvalid <= '1';
              axi_rresp <= "10"; -- SLVERR: slave error response
              
            -- still waiting for IPbus
            else
              ipb_timer <= ipb_timer + 1;
            end if;
          
          -- IPBus read transaction finished and axi response is set, so lets finish the axi transaction here
          when AXI_READ_HANDSHAKE =>
            if (S_AXI_RREADY = '1') then
              ipb_state <= IDLE;
              axi_rvalid <= '0';
            end if;

          -- initiate IPBus write request
          when WRITE =>
            -- address ok
            if (ipb_slv_select /= 999) then          
              axi_awready <= '0';
              axi_wready <= '0';
              ipb_mosi(ipb_slv_select).ipb_addr(C_S_AXI_ADDR_WIDTH-3 downto 0) <= S_AXI_AWADDR(C_S_AXI_ADDR_WIDTH-1 downto 2);
              ipb_mosi(ipb_slv_select).ipb_wdata(C_S_AXI_DATA_WIDTH - 1 downto 0) <= axi_wdata;
              ipb_mosi(ipb_slv_select).ipb_strobe <= '1';
              ipb_mosi(ipb_slv_select).ipb_write <= '1';
              ipb_state <= WAIT_FOR_WRITE_ACK;

            -- addressing error - no IPBus slave at this address              
            else
              ipb_state <= AXI_WRITE_HANDSHAKE;
              ipb_timer <= (others => '0');
              axi_bvalid <= '1';
              axi_bresp <= "11"; -- DECERR: decode error response
            end if;
                      
          -- wait for IPBus write ack
          when WAIT_FOR_WRITE_ACK =>          
            -- got ack from IPBus
            if (ipb_miso_i(ipb_slv_select).ipb_ack = '1') then
              ipb_mosi(ipb_slv_select) <= (ipb_addr => (others => '0'), ipb_wdata => (others => '0'), ipb_strobe => '0', ipb_write => '0'); 
              ipb_state <= AXI_WRITE_HANDSHAKE;
              ipb_timer <= (others => '0');
              axi_bvalid <= '1';
              if (ipb_miso_i(ipb_slv_select).ipb_err = '0') then
                axi_bresp <= "00"; -- OKAY response
              else
                axi_bresp <= "10"; -- SLVERR: slave error response
              end if;
              
            -- IPbus timed out
            elsif (ipb_timer > ipb_timeout) then
              ipb_mosi(ipb_slv_select) <= (ipb_addr => (others => '0'), ipb_wdata => (others => '0'), ipb_strobe => '0', ipb_write => '0'); 
              ipb_state <= AXI_WRITE_HANDSHAKE;
              ipb_timer <= (others => '0');
              axi_bvalid <= '1';
              axi_bresp <= "10"; -- SLVERR: slave error response
              
            -- still waiting for IPbus
            else
              ipb_timer <= ipb_timer + 1;
            end if;
            
          -- IPBus write transaction finished and axi response is set, so lets finish the axi transaction here
          when AXI_WRITE_HANDSHAKE =>
            if (S_AXI_BREADY = '1') then
              ipb_state <= IDLE;
              axi_bvalid <= '0';
            end if;
           
          -- hmm           
          when others =>
            ipb_mosi    <= (others => (ipb_addr => (others => '0'), ipb_wdata => (others => '0'), ipb_strobe => '0', ipb_write => '0')); 
            ipb_state   <= IDLE;
            ipb_timer   <= (others => '0');
            axi_arready <= '0';
            axi_rdata   <= (others => '0');
            axi_rvalid  <= '0';
            axi_rresp   <= "00";
            axi_awready <= '0';
            axi_wready  <= '0';
        end case;                      
      end if;        
    end if;        
  end process;

  -- ================================= DEBUG ====================================

  g_debug : if C_DEBUG generate
      
    debug_awaddr(C_S_AXI_ADDR_WIDTH-1 downto 0) <= S_AXI_AWADDR;
    debug_araddr(C_S_AXI_ADDR_WIDTH-1 downto 0) <= S_AXI_ARADDR;
      
    ila_axi_ipbus_bridge_inst : ila_axi_ipbus_bridge
      port map (
        clk         => S_AXI_ACLK,
        probe0      => S_AXI_ARESETN,
        probe1      => debug_awaddr,
        probe2      => S_AXI_AWPROT,
        probe3      => S_AXI_AWVALID,
        probe4      => S_AXI_WDATA,
        probe5      => S_AXI_WSTRB,
        probe6      => S_AXI_WVALID,
        probe7      => S_AXI_BREADY,
        probe8      => debug_araddr,
        probe9      => S_AXI_ARPROT,
        probe10     => S_AXI_ARVALID,
        probe11     => S_AXI_RREADY,
        probe12     => x"0000" & std_logic_vector(transaction_cnt),
        probe13     => axi_awready,
        probe14     => axi_wready,
        probe15     => axi_bresp,
        probe16     => axi_bvalid,
        probe17     => x"00000000",
        probe18     => axi_arready,
        probe19     => axi_rdata,
        probe20     => axi_rresp,
        probe21     => axi_rvalid,
        probe22     => ipb_mosi(C_IPB_SLV.system).ipb_addr,
        probe23     => ipb_mosi(C_IPB_SLV.system).ipb_wdata,
        probe24     => ipb_mosi(C_IPB_SLV.system).ipb_strobe,
        probe25     => ipb_mosi(C_IPB_SLV.system).ipb_write,
        probe26     => ipb_miso_i(C_IPB_SLV.system).ipb_rdata,
        probe27     => ipb_miso_i(C_IPB_SLV.system).ipb_ack,
        probe28     => ipb_miso_i(C_IPB_SLV.system).ipb_err,
        probe29     => std_logic_vector(to_unsigned(ipb_slv_select, 8))
    );
  end generate;

end arch_imp;
