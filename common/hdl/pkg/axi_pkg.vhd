------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    2020-06-04
-- Module Name:    axi package
-- Description:    axi related types
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package axi_pkg is

    type t_axi_lite_m2s is record
        awaddr      : std_logic_vector(31 downto 0);
        awprot      : std_logic_vector(2 downto 0);
        awvalid     : std_logic;    
        wdata       : std_logic_vector(31 downto 0);
        wstrb       : std_logic_vector(3 downto 0);
        wvalid      : std_logic;
        bready      : std_logic;
        araddr      : std_logic_vector(31 downto 0);
        arprot      : std_logic_vector(2 downto 0);
        arvalid     : std_logic;
        rready      : std_logic;        
    end record;

    type t_axi_lite_s2m is record
        awready     : std_logic;
        wready      : std_logic;
        bresp       : std_logic_vector(1 downto 0);
        bvalid      : std_logic;
        arready     : std_logic;
        rdata       : std_logic_vector(31 downto 0);
        rresp       : std_logic_vector(1 downto 0);
        rvalid      : std_logic;
    end record;

    type t_axi_full_512_m2s is record
        awaddr      : std_logic_vector(63 downto 0);
        awprot      : std_logic_vector(2 downto 0);
        awvalid     : std_logic;    
        wdata       : std_logic_vector(511 downto 0);
        wstrb       : std_logic_vector(63 downto 0);
        wvalid      : std_logic;
        bready      : std_logic;
        araddr      : std_logic_vector(63 downto 0);
        arprot      : std_logic_vector(2 downto 0);
        arvalid     : std_logic;
        rready      : std_logic;
        -- axi full
        awid        : std_logic_vector(3 downto 0);
        awlen       : std_logic_vector(7 downto 0);
        awsize      : std_logic_vector(2 downto 0);
        awburst     : std_logic_vector(1 downto 0);
        awlock      : std_logic;
        awcache     : std_logic_vector(3 downto 0);
        wlast       : std_logic;
        arid        : std_logic_vector(3 downto 0);
        arlen       : std_logic_vector(7 downto 0);
        arsize      : std_logic_vector(2 downto 0);
        arburst     : std_logic_vector(1 downto 0);
        arlock      : std_logic;
        arcache     : std_logic_vector(3 downto 0);
    end record;

    type t_axi_full_512_s2m is record
        awready     : std_logic;
        wready      : std_logic;
        bresp       : std_logic_vector(1 downto 0);
        bvalid      : std_logic;
        arready     : std_logic;
        rdata       : std_logic_vector(511 downto 0);
        rresp       : std_logic_vector(1 downto 0);
        rvalid      : std_logic;
        -- axi full
        bid         : std_logic_vector(3 downto 0);
        rid         : std_logic_vector(3 downto 0);
        rlast       : std_logic;
    end record;

    type t_axi_full_64_m2s is record
        awaddr      : std_logic_vector(63 downto 0);
        awprot      : std_logic_vector(2 downto 0);
        awvalid     : std_logic;    
        wdata       : std_logic_vector(63 downto 0);
        wstrb       : std_logic_vector(7 downto 0);
        wvalid      : std_logic;
        bready      : std_logic;
        araddr      : std_logic_vector(63 downto 0);
        arprot      : std_logic_vector(2 downto 0);
        arvalid     : std_logic;
        rready      : std_logic;
        -- axi full
        awid        : std_logic_vector(3 downto 0);
        awlen       : std_logic_vector(7 downto 0);
        awsize      : std_logic_vector(2 downto 0);
        awburst     : std_logic_vector(1 downto 0);
        awlock      : std_logic;
        awcache     : std_logic_vector(3 downto 0);
        wlast       : std_logic;
        arid        : std_logic_vector(3 downto 0);
        arlen       : std_logic_vector(7 downto 0);
        arsize      : std_logic_vector(2 downto 0);
        arburst     : std_logic_vector(1 downto 0);
        arlock      : std_logic;
        arcache     : std_logic_vector(3 downto 0);
    end record;

    type t_axi_full_64_s2m is record
        awready     : std_logic;
        wready      : std_logic;
        bresp       : std_logic_vector(1 downto 0);
        bvalid      : std_logic;
        arready     : std_logic;
        rdata       : std_logic_vector(63 downto 0);
        rresp       : std_logic_vector(1 downto 0);
        rvalid      : std_logic;
        -- axi full
        bid         : std_logic_vector(3 downto 0);
        rid         : std_logic_vector(3 downto 0);
        rlast       : std_logic;
    end record;

    constant AXI_FULL_512_MISO_NULL : t_axi_full_512_s2m := (awready => '0', wready => '0', bresp => "10", bvalid => '0', arready => '0', rdata => (others => '0'), rresp => "10", rvalid => '0', bid => (others => '0'), rid => (others => '0'), rlast => '1');
    constant AXI_FULL_64_MISO_NULL : t_axi_full_64_s2m := (awready => '0', wready => '0', bresp => "10", bvalid => '0', arready => '0', rdata => (others => '0'), rresp => "10", rvalid => '0', bid => (others => '0'), rid => (others => '0'), rlast => '1');

end axi_pkg;