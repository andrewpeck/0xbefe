------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    00:02 2018-10-03
-- Module Name:    cross_domain_pulse
-- Description:    This utility module transfers a pulse from one clock domain to another. No matter how long the input pulse is, the output pulse is always 1 clock cycle long.
--                 Note that it has a few clock cycles of deadtime due to handshaking, while this module is dead busy_o is asserted high.
------------------------------------------------------------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cross_domain_pulse is
    port(
        reset_i     : in  std_logic;
        in_clk_i    : in  std_logic; -- clock of the input pulse
        pulse_i     : in  std_logic; -- input pulse
        out_clk_i   : in  std_logic; -- clock of the output pulse
        pulse_o     : out std_logic; -- output pulse
        busy_o      : out std_logic  -- this module is dead right now (any input pulses will be ignored while this is high), this signal operates on the in_clk_i
    );
end cross_domain_pulse;

architecture cross_domain_pulse_arch of cross_domain_pulse is
    
    signal pulse_in_last    : std_logic := '0';
    signal pulse_req        : std_logic := '0';
    signal pulse_ack        : std_logic := '0';
    signal pulse_req_sync   : std_logic := '0';
    signal pulse_ack_sync   : std_logic := '0';
    signal pulse_sent       : std_logic := '0';
    
begin

    -- register the last value of the input pulse
    process (in_clk_i) is
    begin
        if rising_edge(in_clk_i) then
            pulse_in_last <= pulse_i;
        end if;
    end process;

    -- monitor for incoming pulses and request output pulses
    process (in_clk_i) is
    begin
        if rising_edge(in_clk_i) then
            if reset_i = '1' then
                pulse_req <= '0';
                busy_o <= '0';
            else
                if (pulse_req = '0') then
                    if (pulse_in_last = '0' and pulse_i = '1') then
                        pulse_req <= '1';
                        busy_o <= '1';
                    else
                        pulse_req <= '0';
                        busy_o <= '0';
                    end if;
                elsif (pulse_ack_sync = '1') then
                    pulse_req <= '0';
                    busy_o <= '0';
                else
                    pulse_req <= pulse_req;
                    busy_o <= '1';
                end if;
            end if;
        end if;
    end process;
    
    -- monitor for pulse requests and output pulses as requested and acknowledge them
    process (out_clk_i) is
    begin
        if rising_edge(out_clk_i) then
            if reset_i = '1' then
                pulse_ack <= '0';
                pulse_sent <= '0';
                pulse_o <= '0';
            else
                if (pulse_req_sync = '1') then
                    pulse_ack <= '1';
                    if (pulse_sent = '0') then
                        pulse_o <= '1';
                        pulse_sent <= '1';
                    else
                        pulse_o <= '0';
                        pulse_sent <= '1';
                    end if;
                else
                    pulse_ack <= '0';
                    pulse_sent <= '0';
                    pulse_o <= '0';
                end if;
            end if;
        end if;
    end process;
    
    -- some synchronizers for the handshake signals
    i_pulse_req_sync : entity work.synch
        generic map(
            N_STAGES => 2
        )
        port map(
            async_i => pulse_req,
            clk_i   => out_clk_i,
            sync_o  => pulse_req_sync
        );

    i_pulse_ack_sync : entity work.synch
        generic map(
            N_STAGES => 2
        )
        port map(
            async_i => pulse_ack,
            clk_i   => out_clk_i,
            sync_o  => pulse_ack_sync
        );

end cross_domain_pulse_arch;
