----------------------------------------------------------------------------------
-- CMS Muon Endcap
-- GEM Collaboration (T. Lenzi, A. Peck)
-- Optohybrid v3 Firmware -- Wishbone Seitch
----------------------------------------------------------------------------------
-- Switching system for the Wishbone transactions between masters and slaves.
-- This module allows multiple masters to communicate with the slaves by forwarding
-- the requests and automatically route the reponses between masters and slaves.
----------------------------------------------------------------------------------
-- 2018/10/24 - Add flip-flops at input/output
-- 2018/10/24 - Refactor code to split state machine
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.types_pkg.all;
use work.ipbus_pkg.all;

entity wb_switch is
  port(

    ref_clk_i : in std_logic;
    reset_i   : in std_logic;

    -- Requests
    wb_req_i : in  wb_req_array_t((WB_MASTERS - 1) downto 0);  -- From masters requests
    wb_req_o : out wb_req_array_t((WB_SLAVES - 1) downto 0);  -- To slaves requests

    -- Responses
    wb_res_i : in  wb_res_array_t((WB_SLAVES - 1) downto 0);  -- From slaves responses
    wb_res_o : out wb_res_array_t((WB_MASTERS - 1) downto 0)  -- To masters responses
    );
end wb_switch;

architecture Behavioral of wb_switch is

  signal reset : std_logic;

  attribute EQUIVALENT_REGISTER_REMOVAL          : string;
  attribute EQUIVALENT_REGISTER_REMOVAL of reset : signal is "NO";
  attribute MAX_FANOUT                           : integer;
  attribute MAX_FANOUT of reset                  : signal is 128;

  type state_t is (IDLE, WAITING, ACK_WAIT);
  type state_array_t is array(integer range <>) of state_t;

  signal states : state_array_t((WB_MASTERS - 1) downto 0);

  signal wb_req   : wb_req_array_t((WB_MASTERS - 1) downto 0);
  signal timeouts : u32_array_t((WB_MASTERS - 1) downto 0);

  signal wb_req_i_reg : wb_req_array_t((WB_MASTERS - 1) downto 0);  -- From masters requests
  signal wb_req_o_reg : wb_req_array_t((WB_SLAVES - 1) downto 0);  -- To slaves requests

  signal wb_res_i_reg : wb_res_array_t((WB_SLAVES - 1) downto 0);  -- From slaves responses
  signal wb_res_o_reg : wb_res_array_t((WB_MASTERS - 1) downto 0);  -- To masters responses

  -- For each master, the slave it is addressing
  signal sel_slave : int_array_t((WB_MASTERS - 1) downto 0);

begin

  process(ref_clk_i)
  begin
    if (rising_edge(ref_clk_i)) then
      reset <= reset_i;
    end if;
  end process;

  process(ref_clk_i)
  begin
    if (rising_edge(ref_clk_i)) then
      wb_req_i_reg <= wb_req_i;
      wb_res_i_reg <= wb_res_i;
      wb_req_o     <= wb_req_o_reg;
      wb_res_o     <= wb_res_o_reg;
    end if;
  end process;

  --========================--
  --== Request forwarding ==--
  --========================--

  process(ref_clk_i)
    -- For each slave, the master that is controllign it
    variable sel_master : int_array_t((WB_SLAVES - 1) downto 0);
  begin
    if (rising_edge(ref_clk_i)) then
      -- Reset & default values
      if (reset = '1') then
        wb_req_o_reg <= (others => (stb => '0', we => '0', addr => (others => '0'), data => (others => '0')));
        wb_res_o_reg <= (others => (ack => '0', stat => (others => '0'), data => (others => '0')));
        states       <= (others => IDLE);
        wb_req       <= (others => (stb => '0', we => '0', addr => (others => '0'), data => (others => '0')));
        timeouts     <= (others => (others => '0'));
        sel_slave    <= (others => 99);
        sel_master   := (others => 99);
      else
        -- Loop over the masters
        for I in 0 to (WB_MASTERS - 1) loop
          -- Each master has its own state machine

          ----------------------------------------------------------------------------------------------------
          -- Sequential Logic
          ----------------------------------------------------------------------------------------------------
          case states(I) is

            -- Wait for a request
            when IDLE =>
              -- Incoming request
              if (wb_req_i_reg(I).stb = '1') then
                timeouts(I) <= to_unsigned(WB_TIMEOUT, 32);  -- Set the timeout
                states(I)   <= WAITING;                      -- Change state
              end if;

            -- Wait to transfer request
            when WAITING =>
              -- Check the timeout
              if (timeouts(I) = 0) then
                states(I) <= IDLE;
              else
                -- Decrement timeout
                timeouts(I) <= timeouts(I) - 1;
                -- Unknown slave
                if (sel_slave(I) = 99) then
                  -- Error
                  states(I) <= IDLE;
                -- Slave is free
                elsif (sel_master(sel_slave(I)) = 99) then
                  -- Send request to slave
                  states(I) <= ACK_WAIT;
                end if;
              end if;

            -- Wait for acknowledgment
            when ACK_WAIT =>
              -- Check the timeout
              if (timeouts(I) = 0) then
                -- Set error on timeout
                states(I) <= IDLE;
              else
                -- Decrement timeout
                timeouts(I) <= timeouts(I) - 1;
                -- Incoming response
                if (wb_res_i_reg(sel_slave(I)).ack = '1') then
                  -- Free the slave
                  states(I) <= IDLE;
                end if;
              end if;

            when others =>
              states(I)   <= IDLE;
              timeouts(I) <= (others => '0');
          end case;

          ----------------------------------------------------------------------------------------------------
          -- Behavioral Logic
          ----------------------------------------------------------------------------------------------------
          case states(I) is
            -- Wait for a request

            when IDLE =>
              -- Reset the acknowledgment
              wb_res_o_reg(I).ack <= '0';
              -- Incoming request
              if (wb_req_i_reg(I).stb = '1') then
                wb_req(I)    <= wb_req_i_reg(I);  -- Save the request
                sel_slave(I) <= wb_addr_sel(wb_req_i_reg(I).addr);  -- Select the slave to address
              end if;

            -- Wait to transfer request
            when WAITING =>
              -- Check the timeout
              if (timeouts(I) = 0) then
                wb_res_o_reg(I) <= (ack => '1', stat => WB_ERR_TIMEOUT, data => (others => '0'));  -- Set error on timeout
              else
                if (sel_slave(I) = 99) then                 -- Unknown slave
                  wb_res_o_reg(I) <= (ack => '1', stat => WB_ERR_SLAVE, data => (others => '0'));  -- Error
                elsif (sel_master(sel_slave(I)) = 99) then  -- Slave is free
                  wb_req_o_reg(sel_slave(I)) <= wb_req(I);  -- Send request to slave
                  sel_master(sel_slave(I))   := I;
                end if;
              end if;

            -- Wait for acknowledgment
            when ACK_WAIT =>
              wb_req_o_reg(sel_slave(I)).stb <= '0';  -- Reset the strobe
              if (timeouts(I) = 0) then               -- Check the timeout
                wb_res_o_reg(I) <= (ack => '1', stat => WB_ERR_TIMEOUT, data => (others => '0'));  -- Set error on timeout
              else                      -- Incoming response
                if (wb_res_i_reg(sel_slave(I)).ack = '1') then
                  wb_res_o_reg(I)          <= wb_res_i_reg(sel_slave(I));  -- Transfer the response
                  sel_master(sel_slave(I)) := 99;     -- Free the slave
                end if;
              end if;

            --
            when others =>
              wb_req_o_reg(I) <= (stb => '0', we => '0', addr => (others => '0'), data => (others => '0'));
              wb_res_o_reg(I) <= (ack => '0', stat => (others => '0'), data => (others => '0'));
              wb_req(I)       <= (stb => '0', we => '0', addr => (others => '0'), data => (others => '0'));
              sel_slave(I)    <= 99;
              sel_master(I)   := 99;
          end case;
        end loop;
      end if;
    end if;
  end process;

end Behavioral;
