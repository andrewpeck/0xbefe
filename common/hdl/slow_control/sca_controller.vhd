------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    12:12 2016-10-19
-- Module Name:    SCA Controller
-- Description:    This module handles communication with SCA    
------------------------------------------------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.gem_pkg.all;
use work.sca_pkg.all;

entity sca_controller is
    port(
        -- reset
        reset_i                 : in  std_logic;

        -- clocks
        gbt_clk_40_i            : in  std_logic; -- 40MHz
        clk_80_i                : in  std_logic; -- 80MHz
        
        -- GBT serial ports
        gbt_rx_ready_i          : in  std_logic;
        gbt_rx_sca_elink_i      : in  std_logic_vector(1 downto 0);
        gbt_tx_sca_elink_o      : out std_logic_vector(1 downto 0);
        
        -- control signals
        hard_reset_i            : in  std_logic;     -- hard-reset request
        user_command_i          : in  t_sca_command; -- custom user command request
        user_command_en_i       : in  std_logic;     -- pulse this to execute the custom user command
        user_reply_o            : out t_sca_reply;   -- reply to the user custom command
        user_reply_valid_o      : out std_logic;     -- reply to the user custom command valid
        
        -- JTAG
        -- General use: first of all make sure jtag_enabled_i is high and set the number of bits for the JTAG command in jtag_cmd_length_i, then shift the TMS and TDO bits by setting the data
        -- on the jtag_tms_i or jtag_tdo_i and then pulse the jtag_shift_tms_en_i or jtag_shift_tdo_en_i to shift in these bits to the SCA (32 bits at a time).
        -- Once the number of *TDO* bits shifted reaches the jtag_cmd_length_i then JTAG_GO SCA instruction will be executed automatically and the TDO and TMS shift positions will be reset.
        -- Pulse the jtag_shift_tdi_en_i to shift in the 32 bit TDI values from the SCA to jtag_tdi_o. The TDI shift position is reset to 0 after JTAG_GO instruction is executed.
        -- After any shift you should wait for a pulse on the jtag_shift_done_o (typically the shifts take around 100 clk_40 cycles depending on fiber length, the done pulse is held for 1 clk_40 cycle).
        -- If jtag_enabled_i is low, then no SCA JTAG commands are executed and TDO/TMS/TDI shift positions are held at 0.
        -- All JTAG signals operate on the gbt_clk_40 clock.
        jtag_enabled_i          : in  std_logic;
        jtag_cmd_length_i       : in  unsigned(6 downto 0); -- number of bits to be shifted out during JTAG_GO command (0 means 128 bits)
        jtag_tdo_i              : in  std_logic_vector(31 downto 0);
        jtag_tms_i              : in  std_logic_vector(31 downto 0);
        jtag_tdi_o              : out std_logic_vector(31 downto 0);
        jtag_shift_tdo_en_i     : in  std_logic; 
        jtag_shift_tms_en_i     : in  std_logic;
        jtag_shift_tdi_en_i     : in  std_logic;
        jtag_shift_done_o       : out std_logic; 
        jtag_shift_msb_first_i  : in  std_logic; -- tell SCA to shift out MSB first instead of the default LSB first
        -- expert JTAG controller config signals
        jtag_exec_on_every_tdo_i: in  std_logic; -- EXPERT ONLY: used to optimize firmware downloading, when set high the controller will execute JTAG_GO after every TDO shift (even if length is higher than 32)
        jtag_no_length_update_i : in  std_logic; -- EXPERT ONLY: used to optimize firmware downloading, when set high the controller will assume that SCA already has the correct length and will not update it before each JTAG_GO
        jtag_shift_tdo_async_i  : in  std_logic; -- kindof expert: if this is set high then JTAG controller will assert jtag_shift_done_o immediately after TDO shift command, but if the second command is received while it's still busy it won't assert jtag_shift_done_o until the previous command is done
        
        -- controller monitoring
        ready_o                 : out std_logic;
        critical_error_o        : out std_logic;
        not_ready_cnt_o         : out std_logic_vector(15 downto 0);
        rx_err_cnt_o            : out std_logic_vector(15 downto 0);
        rx_seq_num_err_cnt_o    : out std_logic_vector(15 downto 0);
        rx_crc_err_cnt_o        : out std_logic_vector(15 downto 0);
        trans_timeout_cnt_o     : out std_logic_vector(15 downto 0);
        trans_fail_cnt_o        : out std_logic_vector(15 downto 0);
        trans_done_cnt_o        : out std_logic_vector(31 downto 0);
        last_sca_error_o        : out std_logic_vector(6 downto 0);
        
        -- debug
        tx_raw_last_cmd_o       : out std_logic_vector(95 downto 0);
        rx_raw_last_reply_o     : out std_logic_vector(95 downto 0);
        rx_last_calc_crc_o      : out std_logic_vector(15 downto 0)
        
    );
end sca_controller;

architecture sca_controller_arch of sca_controller is

    -------------- serdes fifos -------------- 

    COMPONENT sca_des_fifo
        PORT(
            rst    : IN  STD_LOGIC;
            wr_clk : IN  STD_LOGIC;
            rd_clk : IN  STD_LOGIC;
            din    : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
            wr_en  : IN  STD_LOGIC;
            rd_en  : IN  STD_LOGIC;
            dout   : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
            full   : OUT STD_LOGIC;
            empty  : OUT STD_LOGIC;
            valid  : OUT STD_LOGIC
        );
    END COMPONENT;
    
    COMPONENT sca_ser_fifo
        PORT(
            rst    : IN  STD_LOGIC;
            wr_clk : IN  STD_LOGIC;
            rd_clk : IN  STD_LOGIC;
            din    : IN  STD_LOGIC_VECTOR(0 DOWNTO 0);
            wr_en  : IN  STD_LOGIC;
            rd_en  : IN  STD_LOGIC;
            dout   : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
            full   : OUT STD_LOGIC;
            empty  : OUT STD_LOGIC;
            valid  : OUT STD_LOGIC
        );
    END COMPONENT;

    -------------- types and constants -------------- 

    type top_state_t is (SCA_RESET, SCA_CONFIGURE, IDLE, SET_HARD_RESET, UNSET_HARD_RESET, USER_COMMAND, JTAG_SHIFT, JTAG_SET_LENGTH, JTAG_GO, ERROR);
    type transaction_state_t is (INIT, IDLE, WAIT_FOR_TX, WAIT_FOR_REPLY, WAIT_FOR_SCA_RESET, CLOSE_TRANSACTION);

    constant TRANS_TIMEOUT        : unsigned(15 downto 0) := x"fa00"; -- transaction timeout (64000 clock cycles = 800us, this is required with some margin for ADC readout which takes 670us)
    constant TRANS_MAX_RETRIES    : unsigned(2 downto 0) := "101"; -- transaction retry count (max 5 retries)

    -------------- signals -------------- 

    -- top fsm signals
    signal top_state            : top_state_t;
    signal sca_config_idx       : integer range SCA_CONFIG_SEQUENCE'range;
    signal user_reply_valid     : std_logic;
    
    -- command request signals
    signal hard_reset_req       : std_logic;
    signal user_command_req     : std_logic;
        
    -- transaction fsm signals
    signal trans_state          : transaction_state_t;
    signal trans_en             : std_logic;
    signal trans_done           : std_logic; -- transaction done successfully
    signal trans_error          : std_logic; -- transaction failed (used up all retries)
    signal trans_tx_sending     : std_logic;
    signal sca_reset_req        : std_logic;
    signal sca_resetting        : std_logic;
    signal trans_timeout_err    : std_logic;
    signal trans_timer          : unsigned(15 downto 0) := x"0000";
    signal trans_retry_cnt      : unsigned(2 downto 0) := "000";
    signal trans_done_cnt       : unsigned(31 downto 0) := x"00000000";
    
    -- controller monitoring
    signal trans_timeout_cnt    : std_logic_vector(15 downto 0);
    signal trans_fail_cnt       : std_logic_vector(15 downto 0);
    signal last_sca_error       : std_logic_vector(6 downto 0);
       
    -- single bit elink data
    signal sd_rx_valid          : std_logic;
    signal sd_rx                : std_logic;
    signal sd_tx                : std_logic;
    
    -- sca rx
    signal rx_ready             : std_logic;
    signal rx_packet_valid      : std_logic;
    signal rx_seq_num           : std_logic_vector(2 downto 0);
    signal rx_sca_reply         : t_sca_reply;
    signal rx_transaction_id    : std_logic_vector(7 downto 0);
    signal rx_not_ready_pulse   : std_logic;

    -- sca tx
    signal tx_command_en        : std_logic;
    signal tx_sca_reset_en      : std_logic;
    signal tx_busy              : std_logic;
    signal tx_sca_command       : t_sca_command;
    signal tx_transaction_id    : std_logic_vector(7 downto 0);
    
    -- jtag
    signal jtag_shift_tdo_pos   : integer range 0 to 3 := 0; -- position of the 32bit TDO register to shift (SCA TDO0, TDO1, TDO2, TDO3)
    signal jtag_shift_tms_pos   : integer range 0 to 3 := 0; -- position of the 32bit TMS register to shift (SCA TMS0, TMS1, TMS2, TMS3)
    signal jtag_shift_tdi_pos   : integer range 0 to 3 := 0; -- position of the 32bit TDI register to shift (SCA TDI0, TDI1, TDI2, TDI3)
    signal jtag_sca_cmd         : t_sca_command;             -- command to be sent to the SCA
    signal jtag_sca_reply_data  : std_logic_vector(31 downto 0); -- SCA reply data
    signal jtag_sca_cmd_req     : std_logic;                 -- request to send out the SCA command
    signal jtag_sca_exec_go     : std_logic;                 -- when jtag_sca_cmd_req and this signal is set then SCA JTAG GO command should also be executed 
    signal jtag_sca_cmd_done    : std_logic;                 -- SCA command done
    signal jtag_async_ack_done  : std_logic;                 -- used to send a done pulse to the user when in async mode
    signal jtag_async_tdo_en    : std_logic;                 -- used to latch in a TDO shift command in async mode so that the command can be executed after the previous command is completed
    
    -- debug
    signal hard_reset_i_sync    : std_logic;
    signal user_command_en_i_sync  : std_logic;
    
begin

    --========= Wiring =========--

    ready_o <= rx_ready when top_state /= ERROR else '0';
    trans_timeout_cnt_o <= trans_timeout_cnt;
    trans_fail_cnt_o <= trans_fail_cnt;
    trans_done_cnt_o <= std_logic_vector(trans_done_cnt);
    last_sca_error_o <= last_sca_error;
    critical_error_o <= '1' when top_state = ERROR else '0'; 

    --========= RX =========--
    
    i_sca_rx : entity work.sca_rx
        port map(
            reset_i           => reset_i or (not gbt_rx_ready_i) or (not sd_rx_valid),
            clk_80_i          => clk_80_i,
            sd_rx_i           => sd_rx,
            ready_o           => rx_ready,
            seq_num_o         => rx_seq_num,
            rx_err_cnt_o      => rx_err_cnt_o,
            seq_num_err_cnt_o => rx_seq_num_err_cnt_o,
            crc_err_cnt_o     => rx_crc_err_cnt_o,
            sca_reply_o       => rx_sca_reply,
            transaction_id_o  => rx_transaction_id,
            packet_valid_o    => rx_packet_valid,
            raw_last_reply_o  => rx_raw_last_reply_o,
            calc_crc_o        => rx_last_calc_crc_o
        );
    
    --========= TX =========--
    
    i_sca_tx : entity work.sca_tx
        port map(
            reset_i           => reset_i,
            clk_80_i          => clk_80_i,
            sd_tx_o           => sd_tx,
            transaction_id_i  => tx_transaction_id,
            sca_command_i     => tx_sca_command,
            rx_ready_i        => rx_ready,
            rx_seq_num_i      => rx_seq_num,
            sca_reset_i       => tx_sca_reset_en,
            command_en_i      => tx_command_en,
            busy_o            => tx_busy,
            raw_last_cmd_o    => tx_raw_last_cmd_o
        );

    --========= Top level FSM =========--

    process(clk_80_i)
    begin
        if (rising_edge(clk_80_i)) then
            if (reset_i = '1') then
                top_state <= SCA_RESET;
                sca_reset_req <= '0';
                sca_config_idx <= 0;
                user_reply_valid <= '0';
                hard_reset_req <= '0';
                user_command_req <= '0';
                jtag_sca_cmd_done <= '0';
            else
                
                if (hard_reset_i_sync = '1') then
                    hard_reset_req <= '1';
                end if;
                if (user_command_en_i_sync = '1') then
                    user_command_req <= '1';
                end if;
                
                case top_state is
                    
                    -- reset the SCA chip
                    when SCA_RESET =>
                        if (trans_done = '0' and trans_error = '0') then
                            sca_reset_req <= '1';
                        elsif (trans_error = '1') then
                            top_state <= ERROR;
                            sca_reset_req <= '0';
                        else
                            top_state <= SCA_CONFIGURE;
                            sca_reset_req <= '0';
                        end if;
                    
                    when SCA_CONFIGURE =>
                        if (trans_done = '0') and (trans_error = '0') then
                            trans_en <= '1';
                            tx_sca_command <= SCA_CONFIG_SEQUENCE(sca_config_idx);
                        elsif (trans_error = '1') then
                            top_state <= ERROR;
                            trans_en <= '0';
                        elsif (sca_config_idx < SCA_CONFIG_SEQUENCE'right) then
                            trans_en <= '0';
                            if (trans_en = '1') then
                                sca_config_idx <= sca_config_idx + 1;
                            end if;
                        elsif (trans_en = '1') then
                            trans_en <= '0';
                            top_state <= IDLE;
                        end if;

                    when IDLE =>                        
                        if (hard_reset_req = '1') then
                            top_state <= SET_HARD_RESET;
                        elsif (user_command_req = '1') then
                            top_state <= USER_COMMAND;
                        elsif (jtag_sca_cmd_req = '1') then
                            top_state <= JTAG_SHIFT;
                        end if;
                        
                        user_reply_valid <= '0';
                        
                    when SET_HARD_RESET =>
                        if (trans_done = '0') and (trans_error = '0') then
                            trans_en <= '1';
                            tx_sca_command.channel <= SCA_CHANNEL_GPIO;
                            tx_sca_command.command <= SCA_CMD_GPIO_SET_OUT;
                            tx_sca_command.length <= x"04";
                            tx_sca_command.data <= SCA_DEFAULT_GPIO_OUT_HR;
                        elsif (trans_error = '1') then
                            top_state <= ERROR;
                            trans_en <= '0';
                        else
                            trans_en <= '0';
                            if (trans_en = '0') then
                                top_state <= UNSET_HARD_RESET;
                            end if;
                        end if;
                        
                    when UNSET_HARD_RESET =>
                        if (trans_done = '0') and (trans_error = '0') then
                            trans_en <= '1';
                            tx_sca_command.channel <= SCA_CHANNEL_GPIO;
                            tx_sca_command.command <= SCA_CMD_GPIO_SET_OUT;
                            tx_sca_command.length <= x"04";
                            tx_sca_command.data <= SCA_DEFAULT_GPIO_OUT;
                        elsif (trans_error = '1') then
                            top_state <= ERROR;
                            trans_en <= '0';
                        else
                            trans_en <= '0';
                            top_state <= IDLE;
                            hard_reset_req <= '0';
                        end if;
                        
                    when USER_COMMAND =>
                        if (trans_done = '0') and (trans_error = '0') then
                            trans_en <= '1';
                            tx_sca_command <= user_command_i;
                        elsif (trans_error = '1') then
                            top_state <= ERROR;
                            trans_en <= '0';
                        else
                            trans_en <= '0';
                            top_state <= IDLE;
                            user_reply_o <= rx_sca_reply;
                            user_reply_valid <= '1';
                            user_command_req <= '0';
                        end if;                        

                    when JTAG_SHIFT =>
                        if (trans_done = '0') and (trans_error = '0') then
                            trans_en <= '1';
                            tx_sca_command <= jtag_sca_cmd;
                        elsif (trans_error = '1') then
                            top_state <= ERROR;
                            trans_en <= '0';
                        else
                            jtag_sca_reply_data <= rx_sca_reply.data;

                            if (jtag_sca_exec_go = '1') then
                                trans_en <= '0';
                                if ((trans_en = '0') and (jtag_no_length_update_i = '0')) then
                                    top_state <= JTAG_SET_LENGTH;
                                elsif(trans_en = '0') then
                                    top_state <= JTAG_GO;
                                end if;
                            else
                                if (jtag_sca_cmd_req = '1') then
                                    jtag_sca_cmd_done <= '1';
                                else
                                    trans_en <= '0';
                                    jtag_sca_cmd_done <= '0';
                                    top_state <= IDLE;                                    
                                end if;
                            end if;
                            
--                            if ((jtag_sca_exec_go = '1') and (trans_en = '0')) then
--                                top_state <= JTAG_SET_LENGTH;
--                            elsif ((jtag_sca_exec_go = '0') and (jtag_sca_cmd_req = '1')) then
--                                jtag_sca_cmd_done <= '1';
--                            elsif ((jtag_sca_cmd_done = '1') and (jtag_sca_cmd_req = '0')) then
--                                trans_en <= '0';
--                                jtag_sca_cmd_done <= '0';
--                                top_state <= IDLE;
--                            end if;                            
                        end if;

                    when JTAG_SET_LENGTH =>
                        if (trans_done = '0') and (trans_error = '0') then
                            trans_en <= '1';
                            tx_sca_command.channel <= SCA_CHANNEL_JTAG;
                            tx_sca_command.command <= SCA_CMD_JTAG_SET_CTRL_REG;
                            tx_sca_command.length <= x"04";
                            tx_sca_command.data <= (SCA_CFG_JTAG_CTRL_REG and (x"fffff" & (not jtag_shift_msb_first_i) & "111" & x"ff")) or ("0" & std_logic_vector(jtag_cmd_length_i) & x"000000");
                        elsif (trans_error = '1') then
                            top_state <= ERROR;
                            trans_en <= '0';
                        else
                            trans_en <= '0';
                            if (trans_en = '0') then
                                top_state <= JTAG_GO;
                            end if;
                        end if;

                    when JTAG_GO =>
                        if (trans_done = '0') and (trans_error = '0') then
                            trans_en <= '1';
                            tx_sca_command.channel <= SCA_CHANNEL_JTAG;
                            tx_sca_command.command <= SCA_CMD_JTAG_GO;
                            tx_sca_command.length <= x"01";
                            tx_sca_command.data <= x"00000000";
                        elsif (trans_error = '1') then
                            top_state <= ERROR;
                            trans_en <= '0';
                        else
                            if (jtag_sca_cmd_req = '1') then
                                jtag_sca_cmd_done <= '1';
                            else
                                trans_en <= '0';
                                jtag_sca_cmd_done <= '0';
                                top_state <= IDLE;
                            end if;
                        end if;
                                                
                    -- stuck here until reset
                    when ERROR =>
                        top_state <= ERROR;
                        user_reply_valid <= '0';
                        
                    -- hmm, lets say error :)
                    when others =>
                        top_state <= ERROR;
                        
                end case;
                
            end if;
        end if;
    end process;

    --========= SCA transaction FSM =========--

    process(clk_80_i)
    begin
        if (rising_edge(clk_80_i)) then
            if (reset_i = '1') then
                trans_state <= INIT;
                tx_transaction_id <= x"01";
                trans_done <= '0';
                trans_error <= '0';
                trans_tx_sending <= '0';
                sca_resetting <= '0';
                last_sca_error <= (others => '0');
                trans_timer <= (others => '0');
                trans_retry_cnt <= (others => '0');
                trans_done_cnt <= (others => '0');
            else
                
                trans_timeout_err <= '0';
                
                case trans_state is
                    
                    -- make sure tx and rx are ready before going into idle
                    when INIT =>
                        tx_transaction_id <= x"01";
                        trans_done <= '0';
                        trans_error <= '0';
                        trans_tx_sending <= '0';
                        sca_resetting <= '0';
                        tx_command_en <= '0';
                        tx_sca_reset_en <= '0';
                        if ((rx_ready = '1') and (tx_busy = '0')) then
                            trans_state <= IDLE;
                        end if;
                        
                    -- wait for transaction requests from the top FSM
                    when IDLE =>
                        if (sca_reset_req = '1') then
                            trans_state <= WAIT_FOR_TX;
                            tx_command_en <= '0';
                            tx_sca_reset_en <= '1';
                        elsif (trans_en = '1') then
                            trans_state <= WAIT_FOR_TX;
                            tx_command_en <= '1';
                            tx_sca_reset_en <= '0';
                        end if;
                        
                    -- wait for TX to send out the command
                    when WAIT_FOR_TX =>
                        if (tx_busy = '1') then
                            trans_tx_sending <= '1';
                        elsif (trans_tx_sending = '1') then
                            trans_tx_sending <= '0';
                            if (sca_reset_req = '1') then
                                trans_state <= WAIT_FOR_SCA_RESET;
                            else
                                trans_state <= WAIT_FOR_REPLY;
                            end if;
                        end if;
                        
                        tx_command_en <= '0';
                        tx_sca_reset_en <= '0';

                    -- wait for SCA to reset (this will be seen as an unlock in rx and then relock)
                    when WAIT_FOR_SCA_RESET =>
                        if (rx_ready = '0') then
                            sca_resetting <= '1';
                        elsif (sca_resetting = '1') then
                            trans_state <= CLOSE_TRANSACTION;
                        end if;
                        
                        -- timeout logic
                        if (trans_timer /= TRANS_TIMEOUT) then
                            trans_timer <= trans_timer + 1;
                        elsif (trans_retry_cnt /= TRANS_MAX_RETRIES) then
                            trans_timer <= (others => '0');
                            trans_retry_cnt <= trans_retry_cnt + 1;
                            trans_timeout_err <= '1';
                            trans_state <= IDLE; -- sca_reset_req or trans_en should be still on since we didn't close the transaction so we'll retransmit the same command
                        else
                            trans_state <= CLOSE_TRANSACTION;
                            trans_error <= '1';
                        end if;
                        
                    -- wait for SCA response
                    when WAIT_FOR_REPLY =>
                        if ((rx_packet_valid = '1') and (rx_transaction_id = tx_transaction_id)) then
                            trans_state <= CLOSE_TRANSACTION;
                            if (rx_sca_reply.error(7 downto 1) /= "0000000") then
                                --trans_error <= '1'; -- not really critical, besides this field is not always refering to an error!.. (thanks SCA...)
                                last_sca_error <= rx_sca_reply.error(7 downto 1);
                            end if;
                        end if;
                        
                        -- timeout logic
                        if (trans_timer /= TRANS_TIMEOUT) then
                            trans_timer <= trans_timer + 1;
                        elsif (trans_retry_cnt /= TRANS_MAX_RETRIES) then
                            trans_timer <= (others => '0');
                            trans_retry_cnt <= trans_retry_cnt + 1;
                            trans_timeout_err <= '1';
                            trans_state <= IDLE; -- sca_reset_req or trans_en should be still on since we didn't close the transaction so we'll retransmit the same command
                        else
                            trans_state <= CLOSE_TRANSACTION;
                            trans_error <= '1';
                        end if;

                        tx_command_en <= '0';
                        tx_sca_reset_en <= '0';
                        
                    -- handshake with the top FSM
                    when CLOSE_TRANSACTION =>
                        if ((trans_en = '1') or (sca_reset_req = '1')) then
                            trans_done <= '1';
                        else
                            trans_state <= IDLE;
                            trans_done <= '0';
                            trans_error <= '0';
                            trans_done_cnt <= trans_done_cnt + 1;
                            -- increment the transaction ID
                            if (tx_transaction_id = x"fe") then
                                tx_transaction_id <= x"01";
                            else
                                tx_transaction_id <= std_logic_vector(unsigned(tx_transaction_id) + 1);
                            end if;
                        end if;
                        tx_command_en <= '0';
                        tx_sca_reset_en <= '0';
                        trans_timer <= (others => '0');
                        trans_retry_cnt <= (others => '0');
                        
                    when others =>
                        trans_state <= INIT;
                        
                end case;
            end if;
        end if;
    end process;

    --========= JTAG =========--
    
    process(gbt_clk_40_i)
    begin
        if (rising_edge(gbt_clk_40_i)) then
            if ((reset_i = '1') or (jtag_enabled_i = '0')) then
                jtag_shift_tdo_pos <= 0;
                jtag_shift_tms_pos <= 0;
                jtag_shift_tdi_pos <= 0;
                jtag_sca_cmd_req <= '0';
                jtag_sca_exec_go <= '0';
                jtag_async_ack_done <= '0';
                jtag_async_tdo_en <= '0';
                jtag_sca_cmd.channel <= SCA_CHANNEL_JTAG;
            else
                
                jtag_shift_done_o <= '0';
                
                if ((jtag_shift_tdo_async_i = '1') and (jtag_shift_tdo_en_i = '1') and (jtag_sca_cmd_req = '1')) then
                    jtag_async_tdo_en <= '1';
                end if;
                
                -- sorry, this can only do one shift at a time, so it's important that the user waits for the done pulse before doing another shift
                -- tdo shift
                if ((jtag_sca_cmd_req = '0') and ((jtag_shift_tdo_en_i = '1') or (jtag_async_tdo_en = '1'))) then
                    jtag_sca_cmd.command <= std_logic_vector(to_unsigned(jtag_shift_tdo_pos * 16, 8)); -- TDO0_W = 0x00, TDI1_W = 0x10, TDI2_W = 0x20, TDI3_W = 0x30
                    jtag_sca_cmd.length <= x"04";
                    jtag_sca_cmd.data <= jtag_tdo_i(7 downto 0) & jtag_tdo_i(15 downto 8) & jtag_tdo_i(23 downto 16) & jtag_tdo_i(31 downto 24);
                    jtag_sca_cmd_req <= '1';
                    jtag_async_tdo_en <= '0';
                    
                    -- if we've already shifted all necessary bits, then enable the JTAG GO request
                    if ((jtag_shift_tdo_pos = 3) or (jtag_exec_on_every_tdo_i = '1') or ((jtag_shift_tdo_pos + 1) * 32 >= to_integer(jtag_cmd_length_i))) then
                        jtag_sca_exec_go <= '1';
                    elsif (jtag_shift_tdo_pos < 3) then
                        jtag_shift_tdo_pos <= jtag_shift_tdo_pos + 1;
                    end if;

                -- shift TMS
                elsif ((jtag_sca_cmd_req = '0') and (jtag_shift_tms_en_i = '1')) then
                    jtag_sca_cmd.command <= std_logic_vector(to_unsigned((jtag_shift_tms_pos * 16) + 64, 8)); -- TMS0_W = 0x40, TMS1_W = 0x50, TMS2_W = 0x60, TMS3_W = 0x70
                    jtag_sca_cmd.length <= x"04";
                    jtag_sca_cmd.data <= jtag_tms_i(7 downto 0) & jtag_tms_i(15 downto 8) & jtag_tms_i(23 downto 16) & jtag_tms_i(31 downto 24);
                    jtag_sca_cmd_req <= '1';
                
                    if (jtag_shift_tms_pos < 3) then
                        jtag_shift_tms_pos <= jtag_shift_tms_pos + 1;
                    end if;
                
                -- shift TDI
                elsif ((jtag_sca_cmd_req = '0') and (jtag_shift_tdi_en_i = '1')) then
                    jtag_sca_cmd.command <= std_logic_vector(to_unsigned((jtag_shift_tdi_pos * 16) + 1, 8)); -- TDI0_R = 0x01, TDI1_R = 0x11, TDI2_R = 0x21, TDI3_R = 0x31
                    jtag_sca_cmd.length <= x"02";
                    jtag_sca_cmd.data <= x"00000000";
                    jtag_sca_cmd_req <= '1';
                
                    if (jtag_shift_tdi_pos < 3) then
                        jtag_shift_tdi_pos <= jtag_shift_tdi_pos + 1;
                    end if;
                
                elsif ((jtag_sca_cmd_req = '1') and (jtag_shift_tdo_async_i = '1') and (jtag_async_ack_done = '0')) then
                    jtag_shift_done_o <= '1';
                    jtag_async_ack_done <= '1';
                    
                -- command is done
                elsif (jtag_sca_cmd_done = '1') then
                    jtag_sca_cmd_req <= '0';
                    jtag_sca_exec_go <= '0';
                    jtag_async_ack_done <= '0';
                    if (jtag_shift_tdo_async_i = '0') then
                        jtag_shift_done_o <= '1';
                    end if;
                    
                    -- if JTAG GO was executed then reset all shift positions
                    if (jtag_sca_exec_go = '1') then
                        jtag_shift_tdo_pos <= 0;
                        jtag_shift_tms_pos <= 0;
                        jtag_shift_tdi_pos <= 0;
                    end if;
                    
                    -- if it was a read command (i.e. TDI_R) then set the reply data on the jtag_tdi_o
                    if (jtag_sca_cmd.command(0) = '1') then
                        jtag_tdi_o <= jtag_sca_reply_data(7 downto 0) & jtag_sca_reply_data(15 downto 8) & jtag_sca_reply_data(23 downto 16) & jtag_sca_reply_data(31 downto 24);
                    end if;
                
                end if;
            end if;
        end if;
    end process;

    --========= SERDES FIFOS =========--
    
    i_des_fifo : component sca_des_fifo
        port map(
            rst     => reset_i,
            wr_clk  => gbt_clk_40_i,
            rd_clk  => clk_80_i,
            din     => gbt_rx_sca_elink_i,
            wr_en   => '1',
            rd_en   => '1',
            dout(0) => sd_rx,
            full    => open,
            empty   => open,
            valid   => sd_rx_valid
        );

    i_ser_fifo : component sca_ser_fifo
        port map(
            rst    => reset_i,
            wr_clk => clk_80_i,
            rd_clk => gbt_clk_40_i,
            din(0) => sd_tx,
            wr_en  => '1',
            rd_en  => '1',
            dout   => gbt_tx_sca_elink_o,
            full   => open,
            empty  => open,
            valid  => open
        );

    --========= Error counters =========--

    i_trans_timeout_cnt : entity work.counter
        generic map(
            g_COUNTER_WIDTH  => 16,
            g_ALLOW_ROLLOVER => false
        )
        port map(
            ref_clk_i => clk_80_i,
            reset_i   => reset_i,
            en_i      => trans_timeout_err,
            count_o   => trans_timeout_cnt
        );

    i_trans_fail_cnt : entity work.counter
        generic map(
            g_COUNTER_WIDTH  => 16,
            g_ALLOW_ROLLOVER => false
        )
        port map(
            ref_clk_i => clk_80_i,
            reset_i   => reset_i,
            en_i      => trans_error,
            count_o   => trans_fail_cnt
        );

    i_rx_not_ready_pulse : entity work.oneshot
        port map(
            reset_i   => reset_i,
            clk_i     => clk_80_i,
            input_i   => not rx_ready,
            oneshot_o => rx_not_ready_pulse
        );

    i_rx_not_ready_cnt : entity work.counter
        generic map(
            g_COUNTER_WIDTH  => 16,
            g_ALLOW_ROLLOVER => false
        )
        port map(
            ref_clk_i => clk_80_i,
            reset_i   => reset_i,
            en_i      => rx_not_ready_pulse,
            count_o   => not_ready_cnt_o
        );

    --========= Pulse extend for the reply valid signal =========--

    i_user_reply_valid_pulse : entity work.pulse_extend
        generic map(
            DELAY_CNT_LENGTH => 3
        )
        port map(
            clk_i          => clk_80_i,
            rst_i          => reset_i,
            pulse_length_i => "100",
            pulse_i        => user_reply_valid,
            pulse_o        => user_reply_valid_o
        );

    --========= Synchronizers to cross from clk40 to clk80 =========--

    i_hard_reset_i_sync_clk_80: 
    entity work.synch
        generic map(
            N_STAGES => 2
        )
        port map(
            async_i => hard_reset_i,
            clk_i   => clk_80_i,
            sync_o  => hard_reset_i_sync
        );
        
    i_user_command_en_i_sync_clk_80: 
    entity work.synch
        generic map(
            N_STAGES => 2
        )
        port map(
            async_i => user_command_en_i,
            clk_i   => clk_80_i,
            sync_o  => user_command_en_i_sync
        );
end sca_controller_arch;
