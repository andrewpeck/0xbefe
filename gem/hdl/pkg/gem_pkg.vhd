library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common_pkg.all;
use work.gem_board_config_package.CFG_NUM_OF_OHs;

package gem_pkg is

    --======================--
    --==      General     ==--
    --======================-- 
        
    constant C_LED_PULSE_LENGTH_TTC_CLK : std_logic_vector(20 downto 0) := std_logic_vector(to_unsigned(1_600_000, 21));

    --======================--
    --== Config Constants ==--
    --======================-- 
    
    -- DAQ
    constant C_DAQ_FORMAT_VERSION     : std_logic_vector(3 downto 0)  := x"0";

    --=============--
    --==  VFAT3  ==--
    --=============--
    
    type t_vfat3_elinks_arr is array(integer range<>) of t_std8_array(23 downto 0);   
    type t_vfat3_sbits_arr is array(integer range<>) of t_std64_array(5 downto 0);

    --========================--
    --== SBit cluster data  ==--
    --========================--

    type t_sbit_cluster is record
        size        : std_logic_vector(2 downto 0);
        address     : std_logic_vector(10 downto 0);
    end record;

    constant NULL_SBIT_CLUSTER : t_sbit_cluster := (size => (others => '1'), address => (others => '1')); 

    type t_oh_sbits is array(7 downto 0) of t_sbit_cluster;
    type t_oh_sbits_arr is array(integer range <>) of t_oh_sbits;

    type t_sbit_link_status is record
        sbit_overflow   : std_logic;
        sync_word       : std_logic;
        missed_comma    : std_logic;
        underflow       : std_logic;
        overflow        : std_logic;
    end record;

    type t_oh_sbit_links is array(1 downto 0) of t_sbit_link_status;    
    type t_oh_sbit_links_arr is array(integer range <>) of t_oh_sbit_links;

    --===================--
    --==  ME0 trigger  ==--
    --===================--
    
    type t_vfat_trigger_cnt_arr is array(integer range<>) of t_std16_array(5 downto 0);

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
        data_cnt      : std_logic_vector(11 downto 0);
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
    --==     OH Link    ==--
    --====================--

    type t_sync_fifo_status is record
        had_ovf         : std_logic;
        had_unf         : std_logic;
    end record;
    
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

    type t_gbt_link_status is record
        gbt_tx_ready                : std_logic;
        gbt_tx_had_not_ready        : std_logic;
        gbt_tx_gearbox_ready        : std_logic;
        gbt_rx_sync_status          : t_sync_fifo_status;
        gbt_rx_ready                : std_logic;
        gbt_rx_had_not_ready        : std_logic;
        gbt_rx_header_locked        : std_logic;
        gbt_rx_header_had_unlock    : std_logic;
        gbt_rx_gearbox_ready        : std_logic;
        gbt_rx_correction_cnt       : std_logic_vector(7 downto 0);
        gbt_rx_correction_flag      : std_logic;
    end record;
    
    type t_vfat_link_status is record
        sync_good               : std_logic;
        sync_error_cnt          : std_logic_vector(3 downto 0);
        daq_event_cnt           : std_logic_vector(7 downto 0);
        daq_crc_err_cnt         : std_logic_vector(7 downto 0);
    end record;
    
    type t_trig_link_status_arr is array(integer range <>) of t_trig_link_status;    
    type t_gbt_link_status_arr is array(integer range <>) of t_gbt_link_status;    
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
        
end gem_pkg;
