library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common_pkg.all;
use work.board_config_package.all;

package gem_pkg is

    --======================--
    --==     Functions    ==--
    --======================-- 

    function select_slv32_by_station(gem_station : integer; me0_slv32, ge11_slv32, ge21_slv32 : std_logic_vector(31 downto 0)) return std_logic_vector;

    --========================--
    --== Link configuration ==--
    --========================--

    constant TXRX_NULL : integer := CFG_BOARD_MAX_LINKS;
    
    -- this record represents a single link (TXRX_NULL can be used to represent an unused tx or rx)
    type t_link is record
        tx      : integer range 0 to CFG_BOARD_MAX_LINKS;
        rx      : integer range 0 to CFG_BOARD_MAX_LINKS;
    end record;

    -- this constant can be used to represent an unused link
    constant LINK_NULL : t_link := (tx => TXRX_NULL, rx => TXRX_NULL);

    -- defines the GT index for each type of OH link
    type t_link_arr is array(integer range <>) of t_link;
    
    type t_oh_link_config is record
        gbt_links       : t_link_arr(0 to 7); -- GBT links
        trig_rx_links   : t_link_arr(0 to 1); -- GE1/1 trigger RX links
    end record t_oh_link_config;
    
    type t_oh_link_config_arr is array (0 to CFG_BOARD_MAX_OHS - 1) of t_oh_link_config;
    type t_oh_link_config_arr_arr is array (0 to CFG_BOARD_MAX_SLRS - 1) of t_oh_link_config_arr;

    type t_trig_tx_link_config_arr is array (0 to 7) of integer range 0 to CFG_BOARD_MAX_LINKS;
    type t_trig_tx_link_config_arr_arr is array (0 to CFG_BOARD_MAX_SLRS - 1) of t_trig_tx_link_config_arr;

    type t_spy_link_enable_arr is array (0 to CFG_BOARD_MAX_SLRS - 1) of boolean;
    type t_spy_link_config is array (0 to CFG_BOARD_MAX_SLRS - 1) of integer range 0 to CFG_BOARD_MAX_LINKS;

    type t_oh_trig_link_type is (OH_TRIG_LINK_TYPE_3P2G, OH_TRIG_LINK_TYPE_4P0G, OH_TRIG_LINK_TYPE_GBT, OH_TRIG_LINK_TYPE_NONE);

    --=============--
    --==  VFAT3  ==--
    --=============--

    constant VFAT3_SC0_WORD         : std_logic_vector(7 downto 0) := x"96";
    constant VFAT3_SC1_WORD         : std_logic_vector(7 downto 0) := x"99";
    constant VFAT3_SYNC_WORD        : std_logic_vector(7 downto 0) := x"17";
    constant VFAT3_SYNC_VERIFY_WORD : std_logic_vector(7 downto 0) := x"e8";
    constant VFAT3_RESYNC_WORD      : std_logic_vector(7 downto 0) := x"55";
    constant VFAT3_L1A_WORD         : std_logic_vector(7 downto 0) := x"69";
    constant VFAT3_L1A_EC0_WORD     : std_logic_vector(7 downto 0) := x"aa";
    constant VFAT3_L1A_BC0_WORD     : std_logic_vector(7 downto 0) := x"c3";
    constant VFAT3_EC0_WORD         : std_logic_vector(7 downto 0) := x"0f";
    constant VFAT3_BC0_WORD         : std_logic_vector(7 downto 0) := x"33";
    constant VFAT3_CALPULSE_WORD    : std_logic_vector(7 downto 0) := x"3c";
    constant VFAT3_NORMAL_MODE_WORD : std_logic_vector(7 downto 0) := x"66";
    constant VFAT3_SC_ONLY_WORD     : std_logic_vector(7 downto 0) := x"5a";
    
    type t_vfat3_elinks_arr is array(integer range<>) of t_std8_array(23 downto 0);   
    type t_vfat3_sbits_arr is array(integer range<>) of t_std64_array(23 downto 0);
    
    constant VFAT3_HDLC_ADDRESSES_GE11 : t_std4_array(23 downto 0) := (x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0");
    constant VFAT3_HDLC_ADDRESSES_GE21 : t_std4_array(23 downto 0) := (x"0", x"1", x"2", x"3", x"4", x"5", x"6", x"7", x"8", x"9", x"a", x"b", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0");
    constant VFAT3_HDLC_ADDRESSES_ME0  : t_std4_array(23 downto 0) := (x"4", x"3", x"a", x"9", x"1", x"3", x"7", x"9", x"1", x"5", x"7", x"b", x"4", x"5", x"a", x"b", x"2", x"6", x"8", x"c", x"2", x"6", x"8", x"c");

    function get_vfat_hdlc_addresses(gem_station : integer) return t_std4_array;

    --========================--
    --== SBit cluster data  ==--
    --========================--

    type t_sbit_cluster is record
        size        : std_logic_vector(2 downto 0);
        address     : std_logic_vector(10 downto 0);
    end record;

    constant NULL_SBIT_CLUSTER : t_sbit_cluster := (size => (others => '1'), address => (others => '1')); 

    type t_oh_clusters is array(7 downto 0) of t_sbit_cluster;
    type t_oh_clusters_arr is array(integer range <>) of t_oh_clusters;

    type t_sbit_link_status is record
        bc0_marker      : std_logic;
        sbit_overflow   : std_logic;
        missed_comma    : std_logic;
        underflow       : std_logic;
        overflow        : std_logic;
        not_in_table    : std_logic;
    end record;

    constant NULL_SBIT_LINK : t_sbit_link_status := (bc0_marker => '0', sbit_overflow => '0', missed_comma => '1', underflow => '1', overflow => '1', not_in_table => '1');

    type t_oh_sbit_links is array(1 downto 0) of t_sbit_link_status;    
    type t_oh_sbit_links_arr is array(integer range <>) of t_oh_sbit_links;

    --===================--
    --==  ME0 trigger  ==--
    --===================--
    
    type t_vfat_trigger_cnt_arr is array(integer range<>) of t_std16_array(23 downto 0);
    type t_vfat_trigger_rate_arr is array(integer range<>) of t_std32_array(23 downto 0);

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
        vfat_fifo_ovf           : std_logic;
        vfat_fifo_unf           : std_logic;
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
        err_corrupted_vfat_data : std_logic;
        err_vfat_block_too_big  : std_logic;
        err_vfat_block_too_small: std_logic;
        err_event_bigger_than_24: std_logic;
        err_mixed_oh_bc         : std_logic;
        err_mixed_vfat_bc       : std_logic;
        err_mixed_vfat_ec       : std_logic;
        cnt_corrupted_vfat      : std_logic_vector(31 downto 0);
        eb_event_num            : std_logic_vector(23 downto 0);
        eb_max_timer            : std_logic_vector(23 downto 0);
        eb_last_timer           : std_logic_vector(23 downto 0);
    end record;

    type t_daq_input_status_arr is array(integer range <>) of t_daq_input_status;

    type t_daq_input_control is record
        eb_timeout_delay        : std_logic_vector(23 downto 0);
        eb_zero_supression_en   : std_logic;
        eb_calib_mode           : std_logic;
        eb_calib_channel        : std_logic_vector(6 downto 0);
    end record;
    
    type t_daq_input_control_arr is array(integer range <>) of t_daq_input_control;

    --====================--
    --==   DAQ other    ==--
    --====================--

    type t_chamber_infifo_rd is record
        dout          : std_logic_vector(191 downto 0);
        rd_en         : std_logic;
        empty         : std_logic;
        valid         : std_logic;
        underflow     : std_logic;
        data_cnt      : std_logic_vector(CFG_DAQ_INFIFO_DATA_CNT_WIDTH - 1 downto 0);
    end record;

    type t_chamber_infifo_rd_array is array(integer range <>) of t_chamber_infifo_rd;

    type t_chamber_evtfifo_rd is record
        dout          : std_logic_vector(83 downto 0);
        rd_en         : std_logic;
        empty         : std_logic;
        valid         : std_logic;
        underflow     : std_logic;
        data_cnt      : std_logic_vector(CFG_DAQ_EVTFIFO_DATA_CNT_WIDTH - 1 downto 0);
    end record;

    type t_chamber_evtfifo_rd_array is array(integer range <>) of t_chamber_evtfifo_rd;

    --====================--
    --==     OH Link    ==--
    --====================--
    
    type t_gt_status is record
        not_in_table    : std_logic;
        disperr         : std_logic;
    end record;

    type t_trig_link_status is record
        trig0_rx_sync_status    : t_sync_fifo_status;      
        trig1_rx_sync_status    : t_sync_fifo_status;
        trig0_rx_gt_status      : t_gt_status;     
        trig1_rx_gt_status      : t_gt_status;     
    end record;
    
    type t_vfat_link_status is record
        sync_good               : std_logic;
        sync_error_cnt          : std_logic_vector(3 downto 0);
        daq_event_cnt           : std_logic_vector(15 downto 0);
        daq_crc_err_cnt         : std_logic_vector(7 downto 0);
    end record;
    
    type t_trig_link_status_arr is array(integer range <>) of t_trig_link_status;    
    type t_vfat_link_status_arr is array(integer range <>) of t_vfat_link_status;    
    type t_oh_vfat_link_status_arr is array(integer range <>) of t_vfat_link_status_arr(23 downto 0);    

    --==================--
    --==   VFAT3 DAQ  ==--
    --==================--   

    type t_vfat_daq_link is record
        data_en         : std_logic;
        data            : std_logic_vector(7 downto 0);
        event_done      : std_logic;
        crc_error       : std_logic;
        link_enabled    : std_logic;
    end record;

    type t_vfat_daq_link_arr is array(integer range <>) of t_vfat_daq_link;
    type t_oh_vfat_daq_link_arr is array(integer range <>) of t_vfat_daq_link_arr(23 downto 0);    

    --==================--
    --== Slow control ==--
    --==================--   
        
    type t_vfat_slow_control_status is record
        crc_error_cnt           : std_logic_vector(15 downto 0);
        packet_error_cnt        : std_logic_vector(15 downto 0);
        bitstuff_error_cnt      : std_logic_vector(15 downto 0);
        timeout_error_cnt       : std_logic_vector(15 downto 0);
        axi_strobe_error_cnt    : std_logic_vector(15 downto 0);
        transaction_cnt         : std_logic_vector(15 downto 0);
    end record;

end gem_pkg;
   
package body gem_pkg is

    function count_ones(s : std_logic_vector) return integer is
        variable temp : natural := 0;
    begin
        for i in s'range loop
            if s(i) = '1' then
                temp := temp + 1;
            end if;
        end loop;

        return temp;
    end function count_ones;

    function bool_to_std_logic(L : BOOLEAN) return std_logic is
    begin
        if L then
            return ('1');
        else
            return ('0');
        end if;
    end function bool_to_std_logic;
    
    function log2ceil(arg : positive) return natural is
        variable tmp : positive     := 1;
        variable log : natural      := 0;
    begin
        if arg = 1 then return 1; end if;
        while arg >= tmp loop
            tmp := tmp * 2;
            log := log + 1;
        end loop;
        return log;
    end function;   

    function up_to_power_of_2(arg : positive) return natural is
        variable tmp : positive     := 1;
    begin
        while arg > tmp loop
            tmp := tmp * 2;
        end loop;
        return tmp;
    end function;   

    function div_ceil(numerator, denominator : positive) return natural is
        variable tmp : positive     := denominator;
        variable ret : positive     := 1;
    begin
        if numerator = 0 then return 0; end if;
        while numerator > tmp loop
            tmp := tmp + denominator;
            ret := ret + 1;
        end loop;
        return ret;
    end function;  
        
    function get_vfat_hdlc_addresses(gem_station : integer) return t_std4_array is
    begin
        if gem_station = 0 then
            return VFAT3_HDLC_ADDRESSES_ME0;
        elsif gem_station = 1 then
            return VFAT3_HDLC_ADDRESSES_GE11;
        elsif gem_station = 2 then
            return VFAT3_HDLC_ADDRESSES_GE21;
        else -- hmm whatever, lets say GE1/1
            return VFAT3_HDLC_ADDRESSES_GE11;  
        end if;
    end function get_vfat_hdlc_addresses;

    function select_slv32_by_station(gem_station : integer; me0_slv32, ge11_slv32, ge21_slv32 : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        if gem_station = 0 then
            return me0_slv32;
        elsif gem_station = 1 then
            return ge11_slv32;
        elsif gem_station = 2 then
            return ge21_slv32;
        else
            return x"00000000";  
        end if;
    end function select_slv32_by_station;
            
end gem_pkg;
