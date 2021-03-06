library IEEE;
use IEEE.STD_LOGIC_1164.all;

package ipbus is

    -- The signals going from master to slaves
    type ipb_wbus is record
        ipb_addr   : std_logic_vector(31 downto 0);
        ipb_wdata  : std_logic_vector(31 downto 0);
        ipb_strobe : std_logic;
        ipb_write  : std_logic;
    end record;

    type ipb_wbus_array is array (natural range <>) of ipb_wbus;

    -- The signals going from slaves to master     
    type ipb_rbus is record
        ipb_rdata : std_logic_vector(31 downto 0);
        ipb_ack   : std_logic;
        ipb_err   : std_logic;
    end record;

    type ipb_rbus_array is array (natural range <>) of ipb_rbus;

    constant IPB_S2M_NULL : ipb_rbus := (ipb_rdata => (others => '0'), ipb_ack => '0', ipb_err => '0');
    constant IPB_M2S_NULL : ipb_wbus := (ipb_addr => (others => '0'), ipb_wdata => (others => '0'), ipb_strobe => '0', ipb_write => '0');

end ipbus;
