library IEEE;
use IEEE.STD_LOGIC_1164.all;

package axi_pkg is

  constant C_IPB_AXI_ADDR_WIDTH : integer := 26; 

	type t_axi_lite_mosi is record
	      -- read
        araddr    : STD_LOGIC_VECTOR ( 31 downto 0 );
        arprot    : STD_LOGIC_VECTOR ( 2 downto 0 );
        arvalid   : STD_LOGIC;
        rready    : STD_LOGIC;

        -- write
        awaddr    : STD_LOGIC_VECTOR ( 31 downto 0 );
        awprot    : STD_LOGIC_VECTOR ( 2 downto 0 );
        awvalid   : STD_LOGIC;
        wdata     : STD_LOGIC_VECTOR ( 31 downto 0 );
        wstrb     : STD_LOGIC_VECTOR ( 3 downto 0 );
        wvalid    : STD_LOGIC;      
        bready    : STD_LOGIC;
  end record;

	type t_axi_lite_miso is record
	      -- read
        arready   : STD_LOGIC;
        rdata     : STD_LOGIC_VECTOR ( 31 downto 0 );
        rresp     : STD_LOGIC_VECTOR ( 1 downto 0 );
        rvalid    : STD_LOGIC;

        -- write
        awready   : STD_LOGIC;
        wready    : STD_LOGIC;
        bresp     : STD_LOGIC_VECTOR ( 1 downto 0 );
        bvalid    : STD_LOGIC;
  end record;

end axi_pkg;
