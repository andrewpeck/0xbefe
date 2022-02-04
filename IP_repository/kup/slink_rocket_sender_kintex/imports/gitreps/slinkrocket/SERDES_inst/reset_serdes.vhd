----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 19.01.2018 07:49:39
-- Design Name: 
-- Module Name: reset_serdes - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity reset_serdes is
  Generic (
		P_FREERUN_FREQUENCY    			: integer := 100;
		P_TX_TIMER_DURATION_US 			: integer := 30000;
		P_RX_TIMER_DURATION_US 			: integer := 130000
  );
  Port ( 
  		reset_free_run					: in std_logic;
  		clock_free_run					: in std_logic;
  		
  		tx_init_done					: in std_logic;
		rx_init_done					: in std_logic;
		rx_data_good					: in std_logic;
		
		reset_all_out					: out std_logic := '0';
		reset_rx_out					: out std_logic := '0';
		init_done_out					: out std_logic := '0';
		retry_cntr						: out std_logic_vector(3 downto 0) :="0000"
		
  		);
end reset_serdes;

architecture Behavioral of reset_serdes is


type sync_serdes_state is (	ST_START,
						ST_TX_WAIT,
						ST_RX_WAIT,
						ST_MONITOR 
							);
signal sync_serdes:sync_serdes_state;

component resync_sig_gen is 
port ( 
	clocko				: in std_logic;
	input				: in std_logic;
	output				: out std_logic
	);
end component; 

signal reset_timer				: std_logic := '1'; 
  
signal tx_init_done_sync		: std_logic;
signal rx_init_done_sync		: std_logic;
signal rx_data_good_sync		: std_logic;
signal sm_init_active			: std_logic := '1';
 
signal timer_ctr               : std_logic_vector(25 downto 0) := "00000000000000000000000000"; 
signal tx_timer_sat            : std_logic := '0'; 
signal rx_timer_sat            : std_logic := '0';  
signal p_tx_timer_term_cyc_int : std_logic_vector(24 downto 0);  
signal p_rx_timer_term_cyc_int : std_logic_vector(24 downto 0);  

signal retry_ctr_reg           : std_logic_vector(3 downto 0);  
 
 
signal retry_ctr_incr          : std_logic;   
  
attribute mark_debug                : string;
 
--attribute mark_debug of retry_ctr_reg 			:signal is "true"; 

--****************************************************************************************
--********************   CODE START HERE                  ********************************
--****************************************************************************************
begin

--resync input signal to clock_free_running

resync_sig_i1:resync_sig_gen 
port map( 
	clocko	=> clock_free_run,
	input	=> tx_init_done,
	output	=> tx_init_done_sync
	);

resync_sig_i2:resync_sig_gen 
port map( 
	clocko	=> clock_free_run,
	input	=> rx_init_done,
	output	=> rx_init_done_sync
	);

resync_sig_i3:resync_sig_gen 
port map( 
	clocko	=> clock_free_run,
	input	=> rx_data_good,
	output	=> rx_data_good_sync
	);

--******************************************************
-- Timer
-- Declare registers and local parameters used for the shared TX and RX initialization timer
-- The free-running clock frequency is specified by the P_FREERUN_FREQUENCY parameter. The TX initialization timer
-- duration is specified by the P_TX_TIMER_DURATION_US parameter (default 30,000us), and the resulting terminal count
-- is assigned to p_tx_timer_term_cyc_int. The RX initialization timer duration is specified by the
-- P_RX_TIMER_DURATION_US parameter (default 130,000us), and the resulting terminal count is assigned to
-- p_rx_timer_term_cyc_int.

p_tx_timer_term_cyc_int <= STD_LOGIC_VECTOR(TO_SIGNED(P_TX_TIMER_DURATION_US * P_FREERUN_FREQUENCY,25));
p_rx_timer_term_cyc_int <= STD_LOGIC_VECTOR(TO_SIGNED(P_RX_TIMER_DURATION_US * P_FREERUN_FREQUENCY,25));
  
  

-- When the timer is enabled by the initialization state machine, increment the timer_ctr counter until its value
-- reaches p_rx_timer_term_cyc_int RX terminal count and rx_timer_sat is asserted. Assert tx_timer_sat when the
-- counter value reaches the p_tx_timer_term_cyc_int TX terminal count. Clear the timer and remove assertions when the
-- timer is disabled by the initialization state machine.

process(clock_free_run)
begin
	if rising_edge(clock_free_run) then
		if reset_timer = '1' then
		    timer_ctr    <= (OTHERS => '0');
			tx_timer_sat <= '0';
			rx_timer_sat <= '0';
			
		else
			if (timer_ctr = p_tx_timer_term_cyc_int) then
				tx_timer_sat <= '1';
			end if;
			
			if (timer_ctr = p_rx_timer_term_cyc_int) then
				rx_timer_sat <= '1';
			else
				timer_ctr <= timer_ctr + '1';
			end if;
		end if;
	end if;
end process;


-- -------------------------------------------------------------------------------------------------------------------
-- Retry counter
-- -------------------------------------------------------------------------------------------------------------------
--
-- Increment the retry_ctr_out register for each TX or RX reset asserted by the initialization state machine until the
-- register saturates at 4'd15. This value, which is initialized on device programming and is never reset, could be
-- useful for debugging purposes. The initialization state machine will continue to retry as needed beyond the retry
-- register saturation point indicated, so 4'd15 should be interpreted as "15 or more attempts since programming."

process(reset_free_run,clock_free_run) 
begin
    if reset_free_run = '1' then
        retry_ctr_reg   <= (others => '0');
	elsif rising_edge(clock_free_run) then
		if (retry_ctr_incr = '1' ) and (retry_ctr_reg /= "1111" ) then
            retry_ctr_reg <= retry_ctr_reg + '1';
         end if;
	end if;
end process;
 
retry_cntr       <= retry_ctr_reg; 
-- -------------------------------------------------------------------------------------------------------------------
-- Initialization state machine
-- -------------------------------------------------------------------------------------------------------------------
Sync_SM:process(clock_free_run,reset_free_run)
begin 

	-- Implement the initialization state machine control and its outputs as a single sequential process. The state
	-- machine is reset by the synchronized reset_all_in input, and does not begin operating until its first use. Note
	-- that this state machine is designed to interact with and enhance the reset controller helper block.
	if reset_free_run = '1' then
	    reset_timer     <= '1';
		reset_all_out  	<= '0';
		reset_rx_out   	<= '0';
		retry_ctr_incr 	<= '0';
		init_done_out  	<= '0';
		sm_init_active 	<= '1';
		sync_serdes 	<= ST_START;
	elsif rising_edge(clock_free_run) then
	Case sync_serdes is
	
		-- When starting the initialization procedure, clear the timer and remove reset outputs, then proceed to wait
        -- for completion of TX initialization
        when ST_START =>
			if (sm_init_active = '1') then
				reset_timer    	<= '1';
				reset_all_out  	<= '0';
				reset_rx_out   	<= '0';
				retry_ctr_incr 	<= '0';
				sync_serdes 	<= ST_TX_WAIT;
			end if;
        

        -- Enable the timer. If TX initialization completes before the counter's TX terminal count, clear the timer and
        -- proceed to wait for RX initialization. If the TX terminal count is reached, clear the timer, assert the
        -- reset_all_out output (which in this example causes a master reset_all assertion), and increment the retry
        -- counter. Completion conditions for TX initialization are described above.
        when ST_TX_WAIT => 
          if (tx_init_done_sync = '1') then
            reset_timer 		<= '1';
            sync_serdes   		<= ST_RX_WAIT;
          else 
            if (tx_timer_sat = '1') then
              reset_timer    	<= '1';
              reset_all_out  	<= '1';
              retry_ctr_incr 	<= '1';
              sync_serdes       <= ST_START;
            else  
              reset_timer 	 	<= '0';
            end if;
          end if;
        

        -- Enable the timer. When the RX terminal count is reached, check whether RX initialization has completed and
        -- whether the data good indicator is high. If both conditions are met, transition to the MONITOR state. If
        -- either condition is not met, then clear the timer, assert the reset_rx_out output (which in this example
        -- either drives gtwiz_reset_rx_pll_and_datapath_in or gtwiz_reset_rx_datapath_in, depending on PLL sharing),
        -- and increnent the retry counter.
        when ST_RX_WAIT =>
          if (rx_timer_sat = '1') then
            if (rx_init_done_sync = '1' and rx_data_good_sync = '1') then
              init_done_out 	<= '1';
              sync_serdes       <= ST_MONITOR;
            else  
              reset_timer    	<= '1';
              reset_rx_out   	<= '1';
              retry_ctr_incr 	<= '1';
              sync_serdes       <= ST_START;
            end if;
          else 
            reset_timer 		<= '0';
          end if;
         

        -- In this MONITOR state, assert the init_done_out output for use as desired. If RX initialization or the data
        -- good indicator is lost while in this state, reset the RX components as described in the ST_RX_WAIT state.
        when ST_MONITOR =>
          if (rx_init_done_sync = '0' or rx_data_good_sync = '0') then
            init_done_out  		<= '0';
            reset_timer     	<= '1';
            reset_rx_out   		<= '1';
            retry_ctr_incr 		<= '1';
            sync_serdes        	<= ST_START;
          end if;
         

	  end case;
	 end if;
end process;


end Behavioral;
