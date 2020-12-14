------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    23:40 2016-12-18
-- Module Name:    oneshot (generic variant)
-- Description:    given an input signal, the output is asserted high for one clock cycle when input goes from low to high.
--                 Even if the input signal stays high for longe that one clock cycle, the output is only asserted high for one cycle.
--                 Both input and output signals are on the same clock domain. Use oneshot_cross_domain if you need them to be on separate domains.
------------------------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity oneshot_cross_domain is
    generic(
        G_N_STAGES    : integer := 3
    );
    port(
        reset_i         : in  std_logic;
        input_clk_i     : in  std_logic;
        oneshot_clk_i   : in  std_logic;
        input_i         : in  std_logic;
        oneshot_o       : out std_logic
    );
end oneshot_cross_domain;

architecture generic_arch of oneshot_cross_domain is
    
    signal last_input       : std_logic := '0';
    signal oneshot_req      : std_logic := '0';
    signal oneshot_req_sync : std_logic := '0';
    signal oneshot_req_last : std_logic := '0';
    signal oneshot_ack      : std_logic := '0';
    signal oneshot_ack_sync : std_logic := '0';
        
begin

    process (input_clk_i) is
    begin
        if rising_edge(input_clk_i) then
            if reset_i = '1' then
                last_input <= '0';
                oneshot_req <= '0';
            else
                last_input <= input_i;
                
                if (oneshot_req = '0') then
                    if ((last_input = '0') and (input_i = '1')) then
                        oneshot_req <= '1';
                    else
                        oneshot_req <= '0';
                    end if; 
                elsif (oneshot_ack_sync = '1') then
                    oneshot_req <= '0';
                else
                    oneshot_req <= '1';
                end if;
            end if;
        end if;
    end process;

    i_req_sync : entity work.synch
        generic map(
            N_STAGES => 2
        )
        port map(
            async_i => oneshot_req,
            clk_i   => oneshot_clk_i,
            sync_o  => oneshot_req_sync
        );

    i_ack_sync : entity work.synch
        generic map(
            N_STAGES => 2
        )
        port map(
            async_i => oneshot_ack,
            clk_i   => input_clk_i,
            sync_o  => oneshot_ack_sync
        );
    
    process (oneshot_clk_i)
    begin
        if (rising_edge(oneshot_clk_i)) then
            if (reset_i = '1') then
                oneshot_o <= '0';
                oneshot_ack <= '0';
                oneshot_req_last <= '0';
            else
                oneshot_req_last <= oneshot_req_sync;
                
                if ((oneshot_req_last = '0') and (oneshot_req_sync = '1')) then
                    oneshot_o <= '1';
                else
                    oneshot_o <= '0';
                end if;
                
                if (oneshot_req_sync = '1') then
                    oneshot_ack <= '1';
                else
                    oneshot_ack <= '0';
                end if;
            end if;
        end if;
    end process;
    
end generic_arch;
