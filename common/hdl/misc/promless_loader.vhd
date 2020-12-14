------------------------------------------------------------------------------------------------------------------------------------------------------
-- Company: TAMU
-- Engineer: Evaldas Juska (evaldas.juska@cern.ch, evka85@gmail.com)
-- 
-- Create Date:    15:03:00 2017-02-03
-- Module Name:    OH_FPGA_LOADER
-- Description:    This module controls the OH FPGA programming via GBT  
------------------------------------------------------------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ttc_pkg.all;
use work.gem_pkg.all;

entity oh_fpga_loader is
    generic(
        g_LOADER_CLK_80_MHZ : boolean := true -- if this is set to false then 40MHz operation is assumed and loader_clk_i must be supplied with 40MHz clock instead of 80MHz
    );    
    port (
        reset_i             : in  std_logic;
        
        gbt_clk_i           : in std_logic; -- 40MHz
        loader_clk_i        : in std_logic; -- 80MHz
        
        to_gem_loader_o     : out t_to_gem_loader;
        from_gem_loader_i   : in  t_from_gem_loader;
        
        elink_data_o        : out std_logic_vector(15 downto 0);
        hard_reset_i        : in std_logic;
        
        gem_loader_stats_o  : out t_gem_loader_stats
    );
end oh_fpga_loader;

architecture Behavioral of oh_fpga_loader is
    
    ------------- components -------------
    
    COMPONENT ila_gem_loader
        PORT(
            clk    : IN STD_LOGIC;
            probe0 : IN STD_LOGIC;
            probe1 : IN STD_LOGIC;
            probe2 : IN STD_LOGIC;
            probe3 : IN STD_LOGIC;
            probe4 : IN STD_LOGIC;
            probe5 : IN STD_LOGIC;
            probe6 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            probe7 : IN STD_LOGIC
        );
    END COMPONENT;
    
    COMPONENT vio_gem_loader
        PORT(
            clk        : IN  STD_LOGIC;
            probe_in0  : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
            probe_in1  : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
            probe_out0 : OUT STD_LOGIC
        );
    END COMPONENT;
    
    COMPONENT fifo_gemloader_gbt
        PORT(
            rst    : IN  STD_LOGIC;
            wr_clk : IN  STD_LOGIC;
            rd_clk : IN  STD_LOGIC;
            din    : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
            wr_en  : IN  STD_LOGIC;
            rd_en  : IN  STD_LOGIC;
            dout   : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
            full   : OUT STD_LOGIC;
            empty  : OUT STD_LOGIC;
            valid  : OUT STD_LOGIC
        );
    END COMPONENT;

    ------------- signals -------------

--    constant FIRMWARE_SIZE      : unsigned(31 downto 0) := x"0029b1f9"; -- 16bit words for 80MHz
--    constant FIRMWARE_SIZE      : unsigned(31 downto 0) := x"005363f2"; -- 8bit words for 40MHz
    --constant FIRMWARE_SIZE      : unsigned(31 downto 0) := x"00756767"; -- TODO: only need 32 bits for testing, in normal operation 24 bits should be fine, for 160T the size = x"536403", for 195T the size = x"756767"
--    constant FIRMWARE_SIZE      : unsigned(31 downto 0) := x"00947ab7"; -- 8bit words for 40MHz
    constant WAIT_DATA_TIMEOUT  : unsigned(31 downto 0) := x"00001f40"; -- TODO: should be around 100us
    constant WAIT_INIT_TIMEOUT  : unsigned(19 downto 0) := x"13880";    -- wait time for FPGA to initialize after PROG_B has been pulled low
    
    type t_state is (IDLE, RESET_OH, WAIT_FOR_INIT, PROGRAM);
    signal state            : t_state := IDLE;
    
    signal wait_init_timer  : unsigned(19 downto 0) := (others => '0');
    signal wait_data_timer  : unsigned(31 downto 0) := (others => '0');
    signal byte_cnt         : unsigned(31 downto 0) := (others => '0');
    signal last_byte_idx    : unsigned(31 downto 0) := (others => '0');
    signal loading_started  : std_logic := '0';
    signal gap_detected     : std_logic := '0';
    
    signal loader_en        : std_logic := '0';
    signal hard_reset_local : std_logic := '0';
    signal hard_reset       : std_logic := '0';
    signal hard_reset_prev  : std_logic := '0';
    
    signal loader_data      : std_logic_vector(15 downto 0);
    signal loader_empty     : std_logic;
    signal loader_valid     : std_logic;
    signal loader_rden      : std_logic;
    signal fifo_reset       : std_logic;
    signal loader_err_os    : std_logic;

    signal load_req_cnt     : unsigned(15 downto 0) := (others => '0');
    signal success_cnt      : unsigned(15 downto 0) := (others => '0');
    signal fail_cnt         : unsigned(15 downto 0) := (others => '0');
    signal gap_det_cnt      : unsigned(15 downto 0) := (others => '0');
    signal loader_err_cnt   : std_logic_vector(15 downto 0) := (others => '0');
    
begin

    hard_reset <= hard_reset_i or hard_reset_local;

    process(gbt_clk_i)
    begin
        if (rising_edge(gbt_clk_i)) then
            if (reset_i = '1') then
                state <= IDLE;
                elink_data_o <= (others => '1');
                loader_en <= '0';
                byte_cnt <= (others => '0');
                wait_data_timer <= (others => '0');
                wait_init_timer <= (others => '0');
                fail_cnt <= (others => '0');
                success_cnt <= (others => '0');
                loader_rden <= '0';
                loading_started <= '0';
                fifo_reset <= '1';
                load_req_cnt <= (others => '0');
                gap_det_cnt <= (others => '0');
                last_byte_idx <= (others => '0');
            else
                case state is
                    when IDLE =>
                        elink_data_o <= (others => '1');
                        loader_en <= '0';
                        loader_rden <= '0';
                        loading_started <= '0';
                        gap_detected <= '0';
                        fifo_reset <= '1';
                        byte_cnt <= (others => '0');
                        wait_data_timer <= (others => '0');
                        wait_init_timer <= (others => '0');
                        if (gap_detected = '1') then
                            gap_det_cnt <= gap_det_cnt + 1;
                        end if;
                        if (g_LOADER_CLK_80_MHZ) then
                            last_byte_idx <= unsigned(from_gem_loader_i.size and x"fffffffe") - 2;
                        else
                            last_byte_idx <= unsigned(from_gem_loader_i.size) - 1;
                        end if;
                        
                        hard_reset_prev <= hard_reset;
                        if ((hard_reset_prev = '0') and (hard_reset = '1')) then
                            state <= RESET_OH;
                        end if;
                        
                    -- reset the FPGA (pull PROG_B low)
                    -- not really used anymore since SCA controller resets the FPGA on TTC hard reset
                    when RESET_OH =>
                        elink_data_o <= (others => '1');
                        loader_en <= '0';
                        loader_rden <= '0';
                        loading_started <= '0';
                        gap_detected <= '0';
                        fifo_reset <= '0';
                        byte_cnt <= (others => '0');
                        wait_data_timer <= (others => '0');
                        wait_init_timer <= (others => '0');
                        load_req_cnt <= load_req_cnt + 1;
                        state <= WAIT_FOR_INIT; 
                        
                    -- wait for the FPGA to initialize (until INIT_B goes high)
                    -- we use a fixed timer of 2ms here for now (measured time for virtex6 is ~1ms)
                    when WAIT_FOR_INIT =>
                        elink_data_o <= (others => '1');
                        byte_cnt <= (others => '0');
                        loader_rden <= '0';
                        loading_started <= '0';
                        gap_detected <= '0';
                        fifo_reset <= '0';
                        wait_data_timer <= (others => '0');
                        wait_init_timer <= wait_init_timer + 1;
                        
                        if (wait_init_timer = WAIT_INIT_TIMEOUT) then
                            state <= PROGRAM;
                            loader_en <= '1';
                        else
                            state <= WAIT_FOR_INIT;
                            loader_en <= '0';
                        end if; 
                                                
                        
                    -- send the bitstream once the data becomes available from DDR3
                    when PROGRAM =>
                        if (loader_empty = '0') then
                            loader_rden <= '1';
                        end if;
                    
                        if (loader_valid = '0') then
                            wait_data_timer <= wait_data_timer + 1;
                            elink_data_o <= (others => '1');
                            byte_cnt <= (others => '0');
                        else
                            elink_data_o <= loader_data(7 downto 0) & loader_data(15 downto 8); -- unswap the bytes that got swapped by the FIFO
                            if (g_LOADER_CLK_80_MHZ) then
                                byte_cnt <= byte_cnt + 2;
                            else
                                byte_cnt <= byte_cnt + 1;
                            end if;
                            loading_started <= '1';
                        end if;

                        if ((loader_valid = '0') and (loading_started = '1')) then
                            gap_detected <= '1';
                        end if;
                        
                        if (wait_data_timer = WAIT_DATA_TIMEOUT) then
                            fail_cnt <= fail_cnt + 1;
                            state <= IDLE;
                        end if;
                        
                        if (byte_cnt = last_byte_idx) then
                            state <= IDLE;
                            success_cnt <= success_cnt + 1;
                        end if;
                        
                        loader_en <= '0';
                        wait_init_timer <= (others => '0');
                        fifo_reset <= '0';
                        
                    when others =>
                        state <= IDLE;
                        loader_en <= '0';
                        loader_rden <= '0';
                        loading_started <= '0';
                        gap_detected <= '0';
                        fifo_reset <= '0';                        
                        elink_data_o <= (others => '1');
                        byte_cnt <= (others => '0');
                        wait_data_timer <= (others => '0');
                        wait_init_timer <= (others => '0');
                end case;
            end if;
        end if;
    end process;
    
    to_gem_loader_o.en  <= loader_en;
    to_gem_loader_o.clk <= loader_clk_i;

    g_loader_fifo_80mhz: if g_LOADER_CLK_80_MHZ generate    
        i_fifo_gemloader : fifo_gemloader_gbt
            port map(
                rst    => fifo_reset,
                wr_clk => loader_clk_i,
                rd_clk => gbt_clk_i,
                din    => from_gem_loader_i.data,
                wr_en  => from_gem_loader_i.valid,
                rd_en  => loader_rden,
                dout   => loader_data,
                full   => open,
                empty  => loader_empty,
                valid  => loader_valid
            );
    end generate;
    
    g_loader_fifo_40mhz: if not g_LOADER_CLK_80_MHZ generate    
        loader_data <= from_gem_loader_i.data & from_gem_loader_i.data;
        loader_empty <= '0';
        loader_valid <= from_gem_loader_i.valid;
    end generate;

    i_gemloader_err_oneshot : entity work.oneshot
        port map(
            reset_i   => reset_i,
            clk_i     => loader_clk_i,
            input_i   => from_gem_loader_i.error,
            oneshot_o => loader_err_os
        );
        
    i_gemloader_err_cnt : entity work.counter
        generic map(
            g_COUNTER_WIDTH  => 16,
            g_ALLOW_ROLLOVER => true
        )
        port map(
            ref_clk_i => loader_clk_i,
            reset_i   => reset_i,
            en_i      => loader_err_os,
            count_o   => loader_err_cnt
        );

    gem_loader_stats_o.load_request_cnt <= std_logic_vector(load_req_cnt);
    gem_loader_stats_o.success_cnt <= std_logic_vector(success_cnt);
    gem_loader_stats_o.fail_cnt <= std_logic_vector(fail_cnt);
    gem_loader_stats_o.gap_detect_cnt <= std_logic_vector(gap_det_cnt);
    gem_loader_stats_o.loader_ovf_unf_cnt <= loader_err_cnt;

    i_ila : ila_gem_loader
        port map(
            clk    => loader_clk_i,
            probe0 => loader_en,
            probe1 => from_gem_loader_i.ready,
            probe2 => from_gem_loader_i.valid,
            probe3 => from_gem_loader_i.first,
            probe4 => from_gem_loader_i.last,
            probe5 => from_gem_loader_i.error,
            probe6 => from_gem_loader_i.data,
            probe7 => gap_detected
        );

    i_vio : vio_gem_loader
        port map(
            clk        => gbt_clk_i,
            probe_in0  => std_logic_vector(success_cnt(7 downto 0)),
            probe_in1  => std_logic_vector(fail_cnt(7 downto 0)),
            probe_out0 => hard_reset_local
        );

end Behavioral;
