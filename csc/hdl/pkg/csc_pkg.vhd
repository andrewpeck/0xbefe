library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.board_config_package.all;
--use work.project_config.CFG_NUM_SLRS;

package csc_pkg is

    --======================--
    --==      General     ==--
    --======================-- 
        
    constant C_LED_PULSE_LENGTH_TTC_CLK : std_logic_vector(20 downto 0) := std_logic_vector(to_unsigned(1_600_000, 21));
    
    --========================--
    --== Link configuration ==--
    --========================--

    type t_dmb_type is (NONE, DMB, ODMB, ODMB5, ODMB7);
    
    type t_dmb_rx_fiber_arr is array (0 to 3) of integer range 0 to CFG_BOARD_MAX_LINKS;
    
    type t_dmb_config is record
        dmb_type    : t_dmb_type;           -- type of DMB
        num_fibers  : integer range 0 to 4; -- number of downlink fibers to be used for this DMB (should be 1 for old DMBs/ODMBs, and greater than 1 for multilink ODMBs)
        tx_fiber    : integer range 0 to CFG_BOARD_MAX_LINKS; -- TX fiber number
        rx_fibers   : t_dmb_rx_fiber_arr;   -- RX fiber number(s) to be used for this DMB (only items [0 to num_fibers -1] will be used)  
    end record;

    constant DMB_CONFIG_NULL : t_dmb_config := (dmb_type => NONE, num_fibers => 0, tx_fiber => CFG_BOARD_MAX_LINKS, rx_fibers => (others => CFG_BOARD_MAX_LINKS));

    type t_dmb_config_arr is array (integer range <>) of t_dmb_config;
    type t_dmb_config_arr_per_slr is array (integer range <>) of t_dmb_config_arr;

    type t_gbt_link_config is record
        tx_fiber    : integer range 0 to CFG_BOARD_MAX_LINKS; -- TX fiber number
        rx_fiber    : integer range 0 to CFG_BOARD_MAX_LINKS; -- RX fiber number  
    end record;

    type t_gbt_link_config_arr is array (integer range <>) of t_gbt_link_config;
    type t_gbt_link_config_arr_per_slr is array (integer range <>) of t_gbt_link_config_arr;

    --======================--
    --== Config Constants ==--
    --======================-- 
    
    -- DAQ
    constant C_DAQ_FORMAT_VERSION     : std_logic_vector(3 downto 0)  := x"7";

    --====================--
    --== DAQ data input ==--
    --====================--
    
    type t_data_link is record
        clk        : std_logic;
        data_en    : std_logic;
        data       : std_logic_vector(15 downto 0);
    end record;
    
    type t_data_link_array is array(integer range <>) of t_data_link;    

    --=====================================--
    --==   DAQ input status and control  ==--
    --=====================================--
    
    type t_daq_input_status is record
        evtfifo_empty           : std_logic;
        evtfifo_near_full       : std_logic;
        evtfifo_full            : std_logic;
        evtfifo_underflow       : std_logic;
        evtfifo_near_full_cnt   : std_logic_vector(15 downto 0);
        evtfifo_wr_rate         : std_logic_vector(16 downto 0);
        infifo_empty            : std_logic;
        infifo_near_full        : std_logic;
        infifo_full             : std_logic;
        infifo_underflow        : std_logic;
        infifo_near_full_cnt    : std_logic_vector(15 downto 0);
        infifo_wr_rate          : std_logic_vector(14 downto 0);
        tts_state               : std_logic_vector(3 downto 0);
        err_event_too_big       : std_logic;
        err_evtfifo_full        : std_logic;
        err_infifo_underflow    : std_logic;
        err_infifo_full         : std_logic;
        err_64bit_misaligned    : std_logic;
        eb_event_num            : std_logic_vector(23 downto 0);
    end record;

    type t_daq_input_status_arr is array(integer range <>) of t_daq_input_status;

    type t_daq_input_control is record
        lalala        : std_logic_vector(23 downto 0);
    end record;
    
    type t_daq_input_control_arr is array(integer range <>) of t_daq_input_control;

    --====================--
    --==   DAQ other    ==--
    --====================--

    type t_chamber_infifo_rd is record
        dout          : std_logic_vector(63 downto 0);
        rd_en         : std_logic;
        empty         : std_logic;
        valid         : std_logic;
        underflow     : std_logic;
        data_cnt      : std_logic_vector(13 downto 0);
    end record;

    type t_chamber_infifo_rd_array is array(integer range <>) of t_chamber_infifo_rd;

    type t_chamber_evtfifo_rd is record
        dout          : std_logic_vector(59 downto 0);
        rd_en         : std_logic;
        empty         : std_logic;
        valid         : std_logic;
        underflow     : std_logic;
        data_cnt      : std_logic_vector(11 downto 0);
    end record;

    type t_chamber_evtfifo_rd_array is array(integer range <>) of t_chamber_evtfifo_rd;

    --====================--
    --==   PROMless     ==--
    --====================--

    type t_xdcfeb_switches is record
        ------ XDCFEB board switches ------
        prog_b          : std_logic; -- directly wired to FPGA PROG_B signal (active low reset)
        prog_en         : std_logic; -- when high enables the PROG_B through GBT
        gbt_override    : std_logic; -- when high overrides the switches
        sel_gbt         : std_logic; -- when high selects GBT as the programming source, when low PROMs are programming the FPGA
        sel_8bit        : std_logic; -- when high 8bit bus is used, when low 16bit bus is used
        sel_master      : std_logic; -- when high master mode is used, when low slave mode is used
        sel_cclk_src    : std_logic; -- when high GBT clock is used as CCLK, when low then PROM 31.25MHz clock is used as CCLK
        sel_gbt_cclk_src: std_logic; -- when high then GBT de-skew (phase-shiftable) clock is used for CCLK, when low then eport clock is used for CCLK
        ------ CTP7 configuration ------
        pattern_en      : std_logic; -- when high the GBT TX eports will be sending the data provided in pattern_data (and programming is disabled) 
        pattern_data    : std_logic_vector(31 downto 0); -- data to send to GBT TX eports when pattern_en is high
        rx_select       : integer range 0 to 11; -- selects the fiber to latch the XDCFEB RX data from
    end record;
	
end csc_pkg;