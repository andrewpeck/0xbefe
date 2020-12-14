library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gem_board_config_package.CFG_NUM_OF_OHs;

package gem_pkg is

    --========================--
    --==  Firmware version  ==--
    --========================-- 

    constant C_FIRMWARE_DATE    : std_logic_vector(31 downto 0) := x"20200505";
    constant C_FIRMWARE_MAJOR   : integer range 0 to 255        := 3;
    constant C_FIRMWARE_MINOR   : integer range 0 to 255        := 11;
    constant C_FIRMWARE_BUILD   : integer range 0 to 255        := 0;
    
    ------ Change log ------
    -- 1.8.6 no gbt sync procedure with oh
    -- 1.8.7 advanced ILA trigger for gbt link
    -- 1.8.8 tied unused 8b10b or gbt links to 0
    -- 1.8.9 disable automatic phase shifting, just use unknown phase from 160MHz ref clock, also use bufg for the MMCM feedback clock
    -- 1.8.9 special version with 8b10b main link moved to OH2 and longer IPBusBridge timeout (comms with OH are perfect, but can't read VFATs at all)
    -- 1.9.0 fixed TX phase alignment, removed MMCM reset (was driven by the GTH startup FSM and messing things up).
    --       if 0 shifts are applied it's known to result in bad phase, so for now just made that if this happens, 
    --       then lock is never asserted, which will prevent GTH startup from completing and will be clearly visible during FPGA programming.
    -- 1.9.1 using TTC 120MHz as the GBT common RX clock instead of recovered clock from the main link (so all links should work even if link 1 is not connected)
    -- 1.9.2 separate SCA controlers for each channel implemented. There's also inbuilt ability to broadcast JTAG and custom SCA commands to any set of selected channels
    -- 1.9.3 Added SCA not ready counters (since last SCA reset). This will show if the SCA communication is stable (once established). 
    --       If yes, we could add an automatic SCA reset + configure after each time the SCA ready goes high after being low.
    -- 1.9.4 Swapped calpulse and bc0 bits in the GBT link because the OH was reading them backwards. Also re-enabled forwarding of resync and calpulse to OH.
    
    --=== v3 branch ===--
    -- 3.0.0  First version for v3 electronics  
    -- 3.0.1  Sketched all main VFAT3 TX and RX blocks, but no slow control yet. Implemented TX and RX SYNC and SYNC verify procedures, sync error counts and RX bitslipping
    -- 3.0.2  First implementation of VFAT3 slow control 
    -- 3.0.3  Added a selector (controled through VIO) for debug GBT link and debug VFAT link (on OH #0 only)
    -- 3.0.4  Changed RX bitslipping proceduce -- now looking for low bits (instead of high bits) in the top (instead of bottom) of the previous word
    -- 3.0.5  Revert back to the original bitshifting procedure.. duh.. but update the rx VFAT3 words to the correct ones, not the ones listed in the JINST paper...
    -- 3.0.6  Added missing assignment to prev_word in vfat3_rx_aligner... :)
    -- 3.0.7  Removed double assignment to sync_ok signal, plus added some extra probes to debug the rx_aligner
    -- 3.0.8  Fixed a mistake in VFAT register addressing
    -- 3.0.9  Fixed read and write frame lengths in the slow control TX FSM
    -- 3.0.10 Fix CRC word count issue in vfat3_sc_tx 
    -- 3.0.11 Fixed tx CRC - it has to be sent MSB and INVERTED!!
    -- 3.0.12 Added more debugging in VFAT3 slow control, and updated VFAT3 SC RX with a more robust start-of-frame detection
    -- 3.0.13 Fixed slow_ctrl_data_en_o flag bug in vfat3_rx_link.vhd - this was getting stuck high after the first SC character.. duh..
    -- 3.0.14 Delay tx_command_en and transfer from ipb_clk to ttc40 domain
    -- 3.0.15 Delay and sync the rx_valid and rx_error signals
    -- 3.0.16 Reset the ipb_ack when in IDLE state
    -- 3.0.17 Added a timeout in the slow_control state machine
    -- 3.0.18 Make SC_RX FSM robust against double frame start markers or any garbage before the real packet
    -- 3.0.19 Switched to Vivado 2017.2, also added a debug probe for SC RX CRC
    -- 3.0.20 Fixed VFAT3_SC_RX and SCA_RX CRC checking -- it was latching in the CRC 1 bit too early
    -- 3.1.0  Hopefully the first stable release for public use. All monitoring flags and counters are accessible through AXI registers. VFAT3 slow control CRC error is now a hard error.
    -- 3.1.1  Added VFAT3 DAQ data detection and handling (including CRC check, event counting, and error counting). Not yet wired up to DAQ module for event building.
    -- 3.1.2  Added VFAT3 channel activity monitoring (either a global OR of all channels or an individual channel can be selected), not yet routed out to axi registers
    -- 3.1.3  Added a TTC generator module which can be used to either issue single commands or setup cyclic generators for L1A and CalPulse
    -- 3.1.4  Routed the VFAT3 DAQ signals out to the top, and moved the VFAT3 DAQ channel monitoring to GEM_TESTS module and hooked up to AXI registers (24 such VFAT DAQMON modules are implemented with OH selection)
    -- 3.1.5  Changed VFAT order to be compatible with v2 ordering.. Fixed channel word order in VFAT DAQMON (VFAT3 sends the high channels first).
    -- 3.1.6  Added link select for GBT IC control
    -- 3.1.7  Include trigger links
    -- 3.2.0  OH FPGA slow control protocol implemented
    -- 3.2.1  Fix in OH FPGA link TX FSM
    -- 3.2.2  Increased delay of FPGA RX link valid signal w.r.t. data
    -- 3.2.3  Fixed a problem with rx_valid in the OH FPGA RX FSM
    -- 3.2.4  Implemented sbit monitor which latches on first valid sbit after reset on a selected link
    -- 3.2.5  ILA core in trigger RX link for debugging
    -- 3.2.6  ILA core removed
    -- 3.2.7  Added an sbit to L1A delay counter in sbit monitor
    -- 3.2.8  Changed the VFAT3_RUN_MODE register to SC_ONLY_MODE, the default is 0. Also explicitly send the comm port mode command during link reset corresponding to this value.
    -- 3.3.0  Preliminary quick-and-dirty DAQ module for VFAT3. It implements fake small fifos for all VFATs and a serializer which then feed to existing logic from v2.
    --        This was done as a quick measure to test the data throughput, and it should work mostly fine, but small possibilities exist for data to be mixed from different events.
    --        Should be redone such that each VFAT3 has it's own normal packet FIFO and then input processor would simply read all of them once they all have data (with a timeout also) -- this would eliminate the need for the current "input fifo" and make things much simpler and more robust against event mixing
    -- 3.3.1  Added DAQ input fanout for rate testing. Added TTC generator calpulse prescale. Added possibility to use only the calpulse from the TTC generator while using all other commands from the backplane.
    --        All of these features are meant for fake data rate testing.
    --        Also added a VFAT mask in OH_LINKS, which when set will completely shut off the DAQ and slow control RX of the given VFAT.
    -- 3.3.2  Added a control register to ignore daqlink signals (the daqlink_ready and daqlink_almost_full) -- useful for datarate tests without AMC13
    --        Changed the DAQLink data clock from 50MHz to 62.5MHz in order to reach the full AMC13 input capability of 4Gb/s
    -- 3.3.3  Fixed a bug in vfat_input_buffer, which caused it to miss all events.. Returned back to 50MHz clock for the DAQ due to timing errors with faster clocks
    -- 3.3.4  Fixed a bug in clocking the daq ILA (not really important for normal operation). Switched to 12 chambers.
    --        Fixed a bug in event size error checking in input processor (it was setting it right away whenever there was a zero suppressed event actually)
    --        Discovered a bug, not yet fixed. Global TTS state actually only takes the state of the last input, has to be done with a variable instead of a signal in the for loop there..
    -- 3.3.5  Using 62.5MHz clock again
    -- 3.3.6  Found out that the global event builder max throughput is ~2.8Gb/s because there were several places where a clock cycle was wasted for waiting for data from the FIFOs.
    --        So this version switched all FIFOs to First-Word-Fall-Through mode and removed most dead cycles
    -- 3.4.0  Added compatibility with OH v3b (only affects the GBT-OH_FPGA communication)
    -- 3.4.1  Changed the SCA GPIO direction and output defaults to only drive the PROG_B and those channels that go to the FPGA (also set that we do not drive INIT_B)
    -- 3.4.2  Added a possibility to bitslip the OH FPGA elinks 0 and 1 independently when in v3b mapping mode
    -- 3.4.3  Increased the PH FPGA TX elinks bitslip setting from 3 to 4 bits to allow 8 bit shift (whole clock cycle)
    -- 3.4.4  Set the default parameters for OH v3b FPGA elink bitslips that are working. Also ILA debugging OH index was changed from 0 to 1
    -- 3.4.5  Fix VFAT7 when using v3b (changed elink in v3b OH)
    -- 3.5.0  Merged with promless project. NOTE: this version needs updated Zynq firmware with AXI-full and AXI interrupt support!
    -- 3.5.1  Added flipflops for ipb_mosi inputs in the ipbus_slave.vhd to ease the timing on the ipbus path
    -- 3.5.2  Fixed OH GBT-FPGA communication bitslip settings defaults (the defaults were reset to 0 in 3.5.1 somehow, probably due to some merge activities)
    -- 3.5.3  Added an SCA reset enable mask register which defines which SCAs will get reset uppon a receipt of a module reset command
    --        Also updated the default GPIO direction and output value to drive the VFAT3 resets in OHv3c. The reset is lifted by default after SCA reset, but it is pulsed high when a hard reset command is received
    -- 3.6.0  Added a config blaster interface. RAMs for GBTs, VFATs, and OHs are implemented and writable/readable from IPbus, but the actual config blaster is not yet implemented
    -- 3.6.1  Trying to fix RAM size registers (were always reading 0 in 3.6.0)
    -- 3.7.0  Introduced MiniPOD links, and moved trigger inputs there, allowing to expand the number of OHs to 12
    -- 3.7.1  Made VFAT3 ADC0 and ADC1 reading async by returning a value from a local cache, and using a separate register to actually trigger the real read and update of the cache
    -- 3.7.2  Fixed a bug related to miniPOD links -- some config registers were missing, preventing the links from starting up correctly. Dummy trigger (EMTF) outputs added on miniPOD TX for easy loopback testing of the miniPOD trigger inputs
    -- 3.8.0  Switched to the new OH FPGA communication protocol from Andrew, which uses 6b8b encoding and only one elink. Also added some GE2/1 support.
    -- 3.8.1  Bugfix in the OH FPGA communication FSM 
    -- 3.8.2  Added BC0 and RESYNC markers to the trigger receivers (backwards compatible with older OH fw versions). For now it's not doing anything with those, but just doesn't count them as errors.
    -- 3.8.3  Fixed the trigger link missed comma counter so that it starts counting errors after 128 clock cycles after reset (previously it would only start counting after the first occurance of good frame marker, which sometimes made a link look good even if it was completely bad)
    -- 3.8.4  Added a possibility to switch to 40MHz promless programming mode; added VFAT-VFAT mixed BC and mixed EC flags in the data format; removed ADC monitoring from the SCA controller; SCA TTC_HARD_RESET_EN is now an OH mask instead of just one bit; BC now starts at 1 instead of 0 to match VFAT BC counting
    -- 3.8.5  Small fix in the TX FSM for the OH FPGA -- during link reset the send_idle and send_header signals were undefined, so could possibly send some false data for OH slow control during reset
    -- 3.8.6  Small fix in DAQ input processor: previously a condition existed for event word count to be lower by one VFAT if a new event came exactly at the clock cycle when the old one timed out. Hopefully this will solve the EC/BC mismatch problem seen at GE1/1 QC8 cosmic stand
    -- 3.9.0  Calibration mode data format added - it's a very aggressive bandwidth saving mode designed for calibration runs, which drops most of the VFAT data, except for the VFAT position, 2 bits of EC, and just one channel bit for the selected channel number, so each VFAT only takes up 8 bits. Note: addresses of existing DAQ registers have been changed in order to accomodate the new registers, so it's necessary to update the address table for this version
    -- 3.9.1  LpGBT and ME0 support added (no trigger data yet, but all other features should work)! The firmware has been restructured to better support different GEM stations.
    -- 3.9.2  Fixed a bug in LpGBT MGTs -- the data buses weren't actually connected before
    -- 3.9.3  Increased the I2C address range from 4 bits to 7 bits to support the LpGBT default address of 0x70
    -- 3.9.4  Fixed LpGBT downlink and uplink by setting the MULTICYCLE_DELAY to 0
    -- 3.9.5  Fixed VFAT elink inversions for ME0 (though note that positions 5 and 1 on the classic slot, and 1 and 2 on the spicy slot won't work since they are inverted in the asiago pizza differently than the VFATs that they share the connection to)
    -- 3.9.6  Fixed LpGBT header flag latency going into the rxGearbox; also updated the LpGBT ILA to split off the IC and EC
    -- 3.9.7  Reversed the IC and EC bits for LpGBT (possible cause for IC not working before). Also for ME0 VFATs 0 and 4 fixed for PIZZA classic slot, and VFAT 3 fixed for PIZZA spicy slot (were on the wrong LpGBT before)
    -- 3.9.8  GE2/1 OHv2 support added, and FPGA loader max firmware size increased to support 200T
    -- 3.9.9  Reworked loopback tester, now tests all elinks of a single selected OH with PRBS7 sequence    
    -- 3.9.10 Added a switch to choose the backplane TTC clock as the source for the main MMCM (the switch is called CFG_USE_BACKPLANE_CLK). Also made the OH loader use the bitstream size from the gemloader IP, and also added some registers reporting the loader statistics.
    -- 3.9.11 Came back to using the MGT refclk as the source for all fabric clocks
    -- 3.10.0 Reworked TTC clocking, added manual shifting possibility and phase monitoring (DMTD method used in TCDS), also bypassing the delay aligner in the GBT MGTs
    -- 3.10.1 Reworked the phase alignment FSM to use the DMTD phase measurement instead of the PLL lock signal, this also allows for a configurable lock target phase and tollerance
    -- 3.10.2 Trigger output links to EMTF added, using LpGBT ASIC TX encoding at 10.24Gb/s, and the protocol agreed with EMTF (note the RX side of these MGTs is still running at 3.2Gb/s to receive trigger data from OHs)
    -- 3.11.0 Restructured MGTs to allow for easier configuration between different bus widths and usrclks. Now all MGT interfaces at the top level use 64 bit bus, and are remapped to appropriate bus sizes before connecting to gem_amc. The trigger TX MGT now uses 64 bit bus and 160MHz txusrclk2 to ease the timing  

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
