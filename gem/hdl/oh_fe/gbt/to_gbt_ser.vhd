-- file: to_gbt_ser.vhd
-- (c) Copyright 2009 - 2011 Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
------------------------------------------------------------------------------
-- User entered comments
------------------------------------------------------------------------------
-- None
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity to_gbt_ser is
  generic (
    -- width of the data for the system
    sys_w : integer := 1;
    -- width of the data for the device
    dev_w : integer := 8);
  port (
    -- From the device out to the system
    DATA_OUT_FROM_DEVICE : in  std_logic_vector(dev_w-1 downto 0);
    DATA_OUT_TO_PINS_P   : out std_logic_vector(sys_w-1 downto 0);
    DATA_OUT_TO_PINS_N   : out std_logic_vector(sys_w-1 downto 0);
    -- Clock and reset signals
    CLK_IN               : in  std_logic;  -- Fast clock from PLL/MMCM
    CLK_DIV_IN           : in  std_logic;  -- Slow clock from PLL/MMCM
    IO_RESET             : in  std_logic   -- Reset signal for IO circuit
    );
end to_gbt_ser;

architecture xilinx of to_gbt_ser is
  attribute CORE_GENERATION_INFO           : string;
  attribute CORE_GENERATION_INFO of xilinx : architecture is "to_gbt_ser,selectio_wiz_v4_1,{component_name=to_gbt_ser,bus_dir=OUTPUTS,bus_sig_type=DIFF,bus_io_std=LVDS_25,use_serialization=true,use_phase_detector=false,serialization_factor=8,enable_bitslip=false,enable_train=false,system_data_width=1,bus_in_delay=NONE,bus_out_delay=NONE,clk_sig_type=DIFF,clk_io_std=LVCMOS18,clk_buf=BUFIO2,active_edge=RISING,clk_delay=NONE,v6_bus_in_delay=NONE,v6_bus_out_delay=NONE,v6_clk_buf=MMCM,v6_active_edge=DDR,v6_ddr_alignment=SAME_EDGE_PIPELINED,v6_oddr_alignment=SAME_EDGE,ddr_alignment=C0,v6_interface_type=NETWORKING,interface_type=NETWORKING,v6_bus_in_tap=0,v6_bus_out_tap=0,v6_clk_io_std=LVDS_25,v6_clk_sig_type=DIFF}";
  constant clock_enable                    : std_logic := '1';

  -- Before the buffer
  signal data_out_to_pins_int      : std_logic_vector(sys_w-1 downto 0);
  -- Between the delay and serdes
  signal data_out_to_pins_predelay : std_logic_vector(sys_w-1 downto 0);
  constant num_serial_bits         : integer := dev_w/sys_w;
  type serdarr is array (0 to 9) of std_logic_vector(sys_w-1 downto 0);
  -- Array to use intermediately from the serdes to the internal
  -- devices. bus "0" is the leftmost bus
  -- * fills in from higher order
  signal oserdes_d                 : serdarr := (others => (others => '0'));
  signal ocascade_sm_d             : std_logic_vector(sys_w-1 downto 0);
  signal ocascade_sm_t             : std_logic_vector(sys_w-1 downto 0);

begin
  -- Create the clock logic
  -- We have multiple bits- step over every bit, instantiating the required elements
  pins : for pin_count in 0 to sys_w-1 generate
  begin
    -- Instantiate the buffers
    ----------------------------------
    -- Instantiate a buffer for every bit of the data bus
    obufds_inst : OBUFDS
      generic map (
        IOSTANDARD => "LVDS_25")
      port map (
        O  => DATA_OUT_TO_PINS_P (pin_count),
        OB => DATA_OUT_TO_PINS_N (pin_count),
        I  => data_out_to_pins_int(pin_count));


    -- Pass through the delay
    -----------------------------------
    data_out_to_pins_int(pin_count) <= data_out_to_pins_predelay(pin_count);

    -- Instantiate the serdes primitive
    ----------------------------------

    -- declare the oserdes
    oserdese1_master : OSERDESE1
      generic map (
        DATA_RATE_OQ   => "DDR",
        DATA_RATE_TQ   => "SDR",
        DATA_WIDTH     => 8,
        INTERFACE_TYPE => "DEFAULT",

        TRISTATE_WIDTH => 1,
        SERDES_MODE    => "MASTER")
      port map (
        D1           => oserdes_d(9)(pin_count),
        D2           => oserdes_d(8)(pin_count),
        D3           => oserdes_d(7)(pin_count),
        D4           => oserdes_d(6)(pin_count),
        D5           => oserdes_d(5)(pin_count),
        D6           => oserdes_d(4)(pin_count),
        T1           => '0',
        T2           => '0',
        T3           => '0',
        T4           => '0',
        SHIFTIN1     => ocascade_sm_d(pin_count),
        SHIFTIN2     => ocascade_sm_t(pin_count),
        SHIFTOUT1    => open,
        SHIFTOUT2    => open,
        OCE          => clock_enable,
        CLK          => CLK_IN,
        CLKDIV       => CLK_DIV_IN,
        CLKPERF      => '0',            -- used only in DDR3 mode
        CLKPERFDELAY => '0',            -- used in DDR3 mode only
        WC           => '0',            -- DDR3 mode only
        ODV          => '0',            -- DDR3 mode only
        OQ           => data_out_to_pins_predelay(pin_count),
        TQ           => open,
        OCBEXTEND    => open,
        OFB          => open,
        TFB          => open,
        TCE          => '0',
        RST          => IO_RESET);

    oserdese1_slave : OSERDESE1
      generic map (
        DATA_RATE_OQ   => "DDR",
        DATA_RATE_TQ   => "SDR",
        DATA_WIDTH     => 8,
        TRISTATE_WIDTH => 1,
        INTERFACE_TYPE => "DEFAULT",
        SERDES_MODE    => "SLAVE")
      port map (
        D1           => '0',
        D2           => '0',
        D3           => oserdes_d(3)(pin_count),
        D4           => oserdes_d(2)(pin_count),
        D5           => oserdes_d(1)(pin_count),
        D6           => oserdes_d(0)(pin_count),
        T1           => '0',
        T2           => '0',
        T3           => '0',
        T4           => '0',
        SHIFTOUT1    => ocascade_sm_d(pin_count),
        SHIFTOUT2    => ocascade_sm_t(pin_count),
        SHIFTIN1     => '0',
        SHIFTIN2     => '0',
        OCE          => clock_enable,
        CLK          => CLK_IN,
        CLKDIV       => CLK_DIV_IN,
        CLKPERF      => '0',            -- used only in DDR3 mode
        CLKPERFDELAY => '0',            -- used in DDR3 mode only
        WC           => '0',            -- DDR3 mode only
        ODV          => '0',            -- DDR3 mode only
        OQ           => open,
        TQ           => open,
        OCBEXTEND    => open,
        OFB          => open,
        TFB          => open,
        TCE          => '0',
        RST          => IO_RESET);

    -- Concatenate the serdes outputs together. Keep the timesliced
    --   bits together, and placing the earliest bits on the right
    --   ie, if data comes in 0, 1, 2, 3, 4, 5, 6, 7, ...
    --       the output will be 3210, 7654, ...
    -------------------------------------------------------------


    out_slices : for slice_count in 0 to num_serial_bits-1 generate
    begin
      -- This places the first data in time on the right
      oserdes_d(10-slice_count-1)(0) <=
        DATA_OUT_FROM_DEVICE(slice_count);
      -- To place the first data in time on the left, use the
      --   following code, instead
      -- oserdes_d(slice_count) <=
      --    DATA_OUT_FROM_DEVICE(slice_count);

    end generate out_slices;

  end generate pins;

end xilinx;
