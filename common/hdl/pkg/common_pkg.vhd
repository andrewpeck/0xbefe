library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package common_pkg is

    --======================--
    --==      General     ==--
    --======================-- 
        
    function count_ones(s : std_logic_vector) return integer;
    function bool_to_std_logic(L : BOOLEAN) return std_logic;
    function log2ceil(arg : positive) return natural; -- returns the number of bits needed to encode the given number
    function up_to_power_of_2(arg : positive) return natural; -- "rounds" the given number up to the closest power of 2 number (e.g. if you give 6, it will say 8, which is 2^3)
    function div_ceil(numerator, denominator : positive) return natural; -- poor man's division, rounding up to the closest integer

    --============--
    --== Common ==--
    --============--   
    
    type t_std_array is array(integer range <>) of std_logic;

    type t_std234_array is array(integer range <>) of std_logic_vector(233 downto 0);

    type t_std33_array is array(integer range <>) of std_logic_vector(32 downto 0);

    type t_std256_array is array(integer range <>) of std_logic_vector(255 downto 0);
  
    type t_std64_array is array(integer range <>) of std_logic_vector(63 downto 0);

    type t_std32_array is array(integer range <>) of std_logic_vector(31 downto 0);

    type t_std40_array is array(integer range <>) of std_logic_vector(39 downto 0);
        
    type t_std24_array is array(integer range <>) of std_logic_vector(23 downto 0);

    type t_std16_array is array(integer range <>) of std_logic_vector(15 downto 0);

    type t_std14_array is array(integer range <>) of std_logic_vector(13 downto 0);

    type t_std10_array is array(integer range <>) of std_logic_vector(9 downto 0);

    type t_std8_array is array(integer range <>) of std_logic_vector(7 downto 0);

    type t_std6_array is array(integer range <>) of std_logic_vector(5 downto 0);

    type t_std4_array is array(integer range <>) of std_logic_vector(3 downto 0);

    type t_std3_array is array(integer range <>) of std_logic_vector(2 downto 0);

    type t_std2_array is array(integer range <>) of std_logic_vector(1 downto 0);

    type t_std176_array is array(integer range <>) of std_logic_vector(175 downto 0);

    --============--
    --==   GBT  ==--
    --============--   

    type t_gbt_frame_array is array(integer range <>) of std_logic_vector(83 downto 0);
    type t_gbt_wide_frame_array is array(integer range <>) of std_logic_vector(115 downto 0);

    --============--
    --==   LpGBT  ==--
    --============--   

    type t_lpgbt_tx_frame is record
        tx_data         : std_logic_vector(31 downto 0);
        tx_ec_data      : std_logic_vector(1 downto 0);
        tx_ic_data      : std_logic_vector(1 downto 0);
    end record;

    type t_lpgbt_rx_frame is record
        rx_data         : std_logic_vector(223 downto 0);
        rx_ec_data      : std_logic_vector(1 downto 0);
        rx_ic_data      : std_logic_vector(1 downto 0);
    end record;

    type t_lpgbt_tx_frame_array is array(integer range <>) of t_lpgbt_tx_frame;
    type t_lpgbt_rx_frame_array is array(integer range <>) of t_lpgbt_rx_frame;

    --========================--
    --==== MGT link types ====--
    --========================--

    type t_mgt_64b_tx_data is record
        txdata         : std_logic_vector(63 downto 0);
        txcharisk      : std_logic_vector(7 downto 0);
        txchardispmode : std_logic_vector(7 downto 0);
        txchardispval  : std_logic_vector(7 downto 0);
    end record;

    constant MGT_64B_TX_DATA_NULL : t_mgt_64b_tx_data := (txdata => (others => '0'), txcharisk => (others => '0'), txchardispmode => (others => '0'), txchardispval => (others => '0')); 

    type t_mgt_64b_rx_data is record
        rxdata          : std_logic_vector(63 downto 0);
        rxbyteisaligned : std_logic;
        rxbyterealign   : std_logic;
        rxcommadet      : std_logic;
        rxdisperr       : std_logic_vector(7 downto 0);
        rxnotintable    : std_logic_vector(7 downto 0);
        rxchariscomma   : std_logic_vector(7 downto 0);
        rxcharisk       : std_logic_vector(7 downto 0);
    end record;

    type t_mgt_64b_tx_data_arr is array(integer range <>) of t_mgt_64b_tx_data;
    type t_mgt_64b_rx_data_arr is array(integer range <>) of t_mgt_64b_rx_data;

    type t_mgt_32b_tx_data is record
        txdata         : std_logic_vector(31 downto 0);
        txcharisk      : std_logic_vector(3 downto 0);
        txchardispmode : std_logic_vector(3 downto 0);
        txchardispval  : std_logic_vector(3 downto 0);
    end record;

    type t_mgt_32b_rx_data is record
        rxdata          : std_logic_vector(31 downto 0);
        rxbyteisaligned : std_logic;
        rxbyterealign   : std_logic;
        rxcommadet      : std_logic;
        rxdisperr       : std_logic_vector(3 downto 0);
        rxnotintable    : std_logic_vector(3 downto 0);
        rxchariscomma   : std_logic_vector(3 downto 0);
        rxcharisk       : std_logic_vector(3 downto 0);
    end record;

    type t_mgt_32b_tx_data_arr is array(integer range <>) of t_mgt_32b_tx_data;
    type t_mgt_32b_rx_data_arr is array(integer range <>) of t_mgt_32b_rx_data;

    type t_mgt_16b_tx_data is record
        txdata         : std_logic_vector(15 downto 0);
        txcharisk      : std_logic_vector(1 downto 0);
        txchardispmode : std_logic_vector(1 downto 0);
        txchardispval  : std_logic_vector(1 downto 0);
    end record;

    type t_mgt_16b_rx_data is record
        rxdata          : std_logic_vector(15 downto 0);
        rxbyteisaligned : std_logic;
        rxbyterealign   : std_logic;
        rxcommadet      : std_logic;
        rxdisperr       : std_logic_vector(1 downto 0);
        rxnotintable    : std_logic_vector(1 downto 0);
        rxchariscomma   : std_logic_vector(1 downto 0);
        rxcharisk       : std_logic_vector(1 downto 0);
    end record;

    type t_mgt_16b_tx_data_arr is array(integer range <>) of t_mgt_16b_tx_data;
    type t_mgt_16b_rx_data_arr is array(integer range <>) of t_mgt_16b_rx_data;

    type t_mgt_ctrl is record
        txreset     : std_logic;
        rxreset     : std_logic;
        rxslide     : std_logic;
    end record;

    type t_mgt_ctrl_arr is array(integer range <>) of t_mgt_ctrl;

    type t_mgt_status is record
        tx_reset_done   : std_logic;
        rx_reset_done   : std_logic;
        tx_cpll_locked  : std_logic;
        rx_cpll_locked  : std_logic;
        qpll_locked     : std_logic;
    end record;

    type t_mgt_status_arr is array(integer range <>) of t_mgt_status;

    --====================--
    --==     DAQLink    ==--
    --====================--

    type t_daq_to_daqlink is record
        reset           : std_logic;
        ttc_clk         : std_logic;
        ttc_bc0         : std_logic;
        trig            : std_logic_vector(7 downto 0);
        tts_clk         : std_logic;
        tts_state       : std_logic_vector(3 downto 0);
        resync          : std_logic;
        event_clk       : std_logic;
        event_valid     : std_logic;
        event_header    : std_logic;
        event_trailer   : std_logic;
        event_data      : std_logic_vector(63 downto 0);
    end record;

    type t_daqlink_to_daq is record
        ready           : std_logic;
        almost_full     : std_logic;
        disperr_cnt     : std_logic_vector(15 downto 0);
        notintable_cnt  : std_logic_vector(15 downto 0);
    end record;

    --===============================--
    --== PROMless firmware loader ==--
    --===============================--
    
    type t_to_gem_loader is record
        clk     : std_logic;
        en      : std_logic;
    end record;

    type t_from_gem_loader is record
        ready   : std_logic;
        valid   : std_logic;
        data    : std_logic_vector(7 downto 0);
        first   : std_logic;
        last    : std_logic;
        error   : std_logic;
        size    : std_logic_vector(31 downto 0);  
    end record;
   
    type t_gem_loader_stats is record
        load_request_cnt    : std_logic_vector(15 downto 0);
        success_cnt         : std_logic_vector(15 downto 0);
        fail_cnt            : std_logic_vector(15 downto 0);
        gap_detect_cnt      : std_logic_vector(15 downto 0);
        loader_ovf_unf_cnt  : std_logic_vector(15 downto 0);
    end record;

    type t_gem_loader_cfg is record
        firmware_size       : std_logic_vector(31 downto 0);
    end record;

end common_pkg;
   
package body common_pkg is

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
        
end common_pkg;
