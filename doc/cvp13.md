
# Setting up CVP13
The setup process consists of these steps:
1. Install the card in the computer, connect cooling, and the micro USB cable
1. Install Bittworks Toolkit LITE software (requires access), we'll refer to it as BWTK
1. Download the firmware + software
1. Use the BWTK to program the clock synthesizers and the firmware PROM
	* Reboot if this was the first time you flashed the PROM (also might be necessary after after major firmware upgrades)
1. Figure out the PCIe bus that the card is sitting in, and start using the card

## Installing the hardware

This involves both installing the CVP13 card in the computer and setting up the liquid cooling system (following instructions for the Koolance system):
1. Connect tubes of appropriate length to the CVP13 card
1. Pass the tubes through the slots in the slot adapter (provided with the Koolance cooling box)
1. Install the CVP13 card in a vacant PCIe slot and simultaneously place the slot adapter in an appropriate slot at the back of the computer, such that sufficient lengths of both tubes come out of the computer. Note: you should install this card in a 16x capable slot, preferrably connected directly to the CPU for best performance (lowest latency), if you are installing this card on Dell Precision 5820 workstation, you should install it in either slot 2 or slot 4.
1. Place the Koolance cooling box at a higher level than the PCIe card, possibly on top of the chassis
1. Connect the 12V power cable from the slot adapter to the 4-pin molex plug inside the computer (need a SATA to molex adapter for the Dell 5820 tower)
1. Connect the power cable from the cooling box to the slot adapter
1. Connect the ATX pass through cable from the slot adapter to motherboard and chassis (only to the PWR_REMOTE pin on the motherboard for the Dell 5820 tower)
1. Connect the microUSB cable between CVP13 and the motherboard
1. Place the 3 temperature sensors from the slot adapter at appropriate places on the CVP13: near the power supply, FPGA cooling block, transceivers
1. Close the chassis
1. Connect the male and female disconnect couplings on the cooling box
1. Connect the tubes from the CVP13 to the disconnect couplings on the cooling box (remember to place the hose clamps on the tubes)
1. Fill liquid coolant into the reservoir of the cooling box (till around 0.25 inch from the top)
1. Turn on the computer which also turns on the cooling box
1. Select high settings for the fan and pump speed initially and run for some time to get rid of air bubbles (might need to add some more coolant as the air bubbles are removed)
1. When all air bubbles are gone, you can use lower settings: 1 for the pump speed and Auto for the fan speed
1. Turn OFF the computer and open the chassis. Connect the two 8-pin power cables inside the chassis to the CVP13. Close the chassis when done

Everything is now set up. You can now turn ON the computer to use the CVP13 and the cooling system. Keep an eye on the temperatures to make sure that they are stable.

## Setup the Bittware software
To program the clocks and FPGA you will need the Bittworks Toolkit LITE software from Bittware. Please contact your Bittware representative or the retailer from which you bought the card and ask for the RHEL7 RPM package of Bittworks Toolkit LITE.

Ensure that you have connected the microUSB port (found on the back of the CVP13) to your computer, and check if the Bittware software detects the card:
```
bwconfig --scan=usb
```
This should print something like this:
```
[result]: Board Type (Name),   Serial, VendorID, DeviceID, USB-Address
[0]:      0x63 (XUPVVP)        205973  0x2528    0x0004    0xc
```
If the card is detected, you should add it to the list of known cards like this:
```
bwconfig --add=usb
```
If the card is not detected, please check if you see a blinking green LED labeled D6 on the back of the card, close to the transceivers. If it's not blinking green, then look for a red blinking or lit LED (D2 or D4), if you see one of those, that indicates a power problem -- in this case check if both 8pin power cables are plugged in.
<br/>
The ```lsusb``` output should show 4 devices:
```
Bus 001 Device 013: ID 0403:6001 Future Technology Devices International, Ltd FT232 Serial (UART) IC
Bus 001 Device 012: ID 2528:0004
Bus 001 Device 011: ID 0403:6014 Future Technology Devices International, Ltd FT232H Single HS USB-UART/FIFO IC
Bus 001 Device 010: ID 04b4:6570 Cypress Semiconductor Corp. Unprogrammed CY7C65632/34 hub HX2VL
```
And /dev should contain a device called similar to bwusb1-3.2 (numbers can be different)

## Program the card

Download the latest firmware bitstream from the 0xBEFE repository releases page: https://gitlab.cern.ch/emu/0xbefe/-/releases

Start the BWTK monitor GUI:
```
/opt/bwtk/2019.3L/bin/bwmonitor-gui
```
(update the version as needed)
Select the card and click connect. Scroll down to the "Programmable Clocks (PLL)" section, select Si5341-A, right click and select "Write clock program", and select the ```cvp13_synth_a_gem.h``` file (found in boards/cvp13/resources/clock_configs directory of the 0xBEFE repo). Repeat the same procedure for the Si5341-B synthesizer, but select the ```cvp13_synth_b_156p25.h``` file. You can now close the monitor-gui application.

Write the firmware bitstream to the flash (note: this takes awhile):
```
bwconfig --erase --dev=0 --type=fpga
bwconfig --erase --dev=0 --type=flash --index=0
bwconfig --load=/full/path/to/your/favorite/0xbefe_bitstream.bit --dev=0 --type=flash
bwconfig --start --dev=0 --type=fpga
```
If this was the first time you programmed the card, you have to reboot the machine now. If this was just a firmware upgrade, you can follow the "Hot reloading the FPGA" section.

You can also use the GUI version:
```
/opt/bwtk/2019.3L/bin/bwconfig-gui
```
* Right click on the XUPVVP card and click and choose "open"
* Right click on the FPGA and choose "Erase"
* Right click on "Flash 0: User" and choose "Erase".. wait..
* Right click on the "Flash 0: User" again and choose "Load" and select your favorite CVP13 0xBEFE bitstream file (available in releases section).
* Right click on the FPGA and choose "Start: load from default boot source"
* Reboot the computer

If you want to only load a bitstream for temporary use (e.g. for testing), you can just load it directly to the FPGA instead of writing the flash, but it will be lost after a power-cycle. This is faster, so it's nice for firmware developers, but regular users should just write flash. Note that FPGA programming seems to be only supported in the GUI mode :(

## Set up the GEM/CSC software
This repository contains low level hardware access software as well as python scripts, which provide an interactive register access, and various communication testing procedures, and also makes it easy to write your own scripts for interacting the the hardware. Python tools are useful for debugging use, but high level routines like scurve scans, etc, are implemented in the official GEM software, which lives elsewhere (https://gitlab.cern.ch/cmsgemonline), and is not covered by this document.

You can use the scripts directly from this repo, all you have to do is:
1. Generate the XML address table file by running this command at the root of the repository: ```make update_me0_cvp13``` (replace me0 with ge21 or ge11 as appropriate). This step is only needed after cloning or updating the repository.
1. Compile the rwreg library that is used for hardware access: ```cd scripts/boards/cvp13/rwreg && make all```. This step is only needed after cloning or updating the repository.
1. Set up the environment for your station and card combination: ```cd scripts && source env.sh me0 cvp13``` (replace me0 with ge21 or ge11 as appropriate). This step is needed for every new terminal that you want to use the scripts in.
1. Initialize and configure the CVP13 firmware for the given station: ```cd scripts && python boards/cvp13/cvp13_init_me0.py```. This step is only needed after a CVP13 power cycle or CVP13 FPGA programming.
1. Use the scripts e.g.:
	1. start the interactive register access tool: ```python common/reg_interface.py```, once the tool is running e.g. to read the GBT link status registers of OH0 type ```readKW OH_LINKS.OH0.GBT``` (readKW means read all registers matching the substring), or check the CVP13 firmware version and configuration: ```readKW GEM_SYSTEM```. You can also write to registers using the write command. You can get some help by typing help. Refer to the address table XML file to find what registers exist and what they do (there's documentation for each register). At some point PDF document should also get generated from the XML when running make update_me0_cvp13, but that's not yet working..
	1. use gem/gbt.py to program your GBT or run a phase scan
	1.  write your own: a simple example of reading and writing registers from python can be found here: common/example_reg_access.py

NOTE: at the moment these python scripts require root privileges to access the hardware, so you should login as root before executing them: ```sudo su -```

## Hot reloading the FPGA
It's possible to reload the FPGA and continue using the card without a reboot if the PCIe configuration hasn't changed in the new firmware.
You do it like this:
1. ```sudo cat /sys/bus/pci/devices/0000\:XX\:00.0/config > ~/cvp13_pcie_config```
1. unload any drivers that are using the card (we don't have any yet, so skip this for now)
1. reload the FPGA: ```/opt/bwtk/2019.3L/bin/bwconfig --start --type=fpga```
1. ```sudo cp ~/cvp13_pcie_config /sys/bus/pci/devices/0000\:XX\:00.0/config```

Replace the XX with the bus number of where you installed the card. It shows up in lspci as a Xilinx 0xBEFE device (sorry, EMU doesn't have a PCI vendor ID yet, so using Xilinx here): ```sudo lspci | grep -i befe```, you should see something like: ```05:00.0 Memory controller: Xilinx Corporation Device befe``` (XX=05 in this case)

## Optics
The QSFP transceivers are counted starting from the one closest to the PCIe connector: QSFP0, QSFP1, QSFP2, QSFP3

QSFP transceivers are using a standard MTP12 interface (male on the transceiver side, female on the cable side). Each QSFP has 4 RX and 4 TX channels, where the RX are on fibers 1 to 4 and TX are going backwards from fiber 12 to 9, so matching TX/RX pairs are on fibers: 1&12, 2&11, 3&10, 4&9

Mapping to ME0 OHs is the following:
|          | QSFP0 | QSFP1 | QSFP2 | QSFP3 |
|----------|-------|-------|-------|-------|
| OH0 GBT0 | 1&12  |       |       |       |
| OH0 GBT1 | 2&11  |       |       |       |
| OH1 GBT0 | 3&10  |       |       |       |
| OH1 GBT1 | 4&9   |       |       |       |
| OH2 GBT0 |       | 1&12  |       |       |
| OH2 GBT1 |       | 2&11  |       |       |
| OH3 GBT0 |       | 3&10  |       |       |
| OH3 GBT1 |       | 4&9   |       |       |
| OH4 GBT0 |       |       | 1&12  |       |
| OH4 GBT1 |       |       | 2&11  |       |
| OH5 GBT0 |       |       | 3&10  |       |
| OH5 GBT1 |       |       | 4&9   |       |
| OH6 GBT0 |       |       |       | 1&12  |
| OH6 GBT1 |       |       |       | 2&11  |
| OH7 GBT0 |       |       |       | 3&10  |
| OH7 GBT1 |       |       |       | 4&9   |

Mapping to ME0 OHs is the following:
|             | QSFP0 | QSFP1 | QSFP2 | QSFP3 |
|-------------|-------|-------|-------|-------|
| OH0 GBT0 RX | 12    |       |       |       |
| OH0 GBT1 RX | --    |       |       |       |
| OH0 GBT2 RX | 11    |       |       |       |
| OH0 GBT3 RX | --    |       |       |       |
| OH0 GBT4 RX | 10    |       |       |       |
| OH0 GBT5 RX | --    |       |       |       |
| OH0 GBT6 RX | 9     |       |       |       |
| OH0 GBT7 RX | --    |       |       |       |
| OH0 GBT0 TX | 1     |       |       |       |
| OH0 GBT1 TX | 2     |       |       |       |
| OH0 GBT2 TX | 3     |       |       |       |
| OH0 GBT3 TX | 4     |       |       |       |
| OH0 GBT4 TX |       | 1     |       |       |
| OH0 GBT5 TX |       | 2     |       |       |
| OH0 GBT6 TX |       | 3     |       |       |
| OH0 GBT7 TX |       | 4     |       |       |

CSC Fiber mapping (for now only one QSFP is used):
|          | QSFP0 | QSFP1 | QSFP2 | QSFP3 |
|----------|-------|-------|-------|-------|
| DMB0     | 1&12  |       |       |       |
| DMB1     | 2&11  |       |       |       |
| Spy GbE  | 3&10  |       |       |       |

## PROMless
The frontend FPGAs are programmed by the backend on every TTC hard-reset command. For this to work the backend firmware has to have access to the frontend FPGA bitstream data, so you have to upload it to the CVP13 RAM, which is done by the ```common/promless.py``` script e.g.:
```
python3 common/promless.py ~/oh_fw/oh_ge21.200-v4.0.2-23-gf349814-dirty.bit
```
(this is equivalent to calling the gemloader_configure.sh script on CTP7)
To trigger the hard-reset manually in order to program the frontend you can use the built-in TTC generator module e.g. by running these commands using the ```common/reg_interface.py```:
```
write GEM_AMC.TTC.GENERATOR.ENABLE 1
write GEM_AMC.TTC.GENERATOR.SINGLE_HARD_RESET 1
```

## CSC operation
First of all, initialize the firmware by running: ```python3 csc/init.py```. This resets and configures the firmware, and also loads the frontend bitstream to the FPGA RAM to be used with PROMless loading (the path to the bitstream file is defined by the CONFIG_CSC_PROMLESS_BITFILE constant in the befe_config.py)
Then you can start the DAQ by running the ```csc/csc_daq.py``` application, which will ask a series of self explanatory questions for which for the most part defaults are going to be fine, but if no TCDS is used you have to make sure to answer "no" to "Should we keep the DAQ in reset until a resync" and "yes" to "Should we use local L1A generation based on DAQ data".
For now the readout through PCIe is not yet implemented, so one has to use the Spy GbE port connected to a compatible NIC and running the CSC DAQ driver + RUI application. The spy output is identical to the DDU output, except that it is sending fully ethernet compliant packets (a modification to the offset in the driver is needed when using the ethernet-compliant option which is normally meant for ODMB "PC" port readout).
There's also a script to send some dummy ethernet packets to the spy GbE port for testing the readout application on the DAQ machine: ```csc/csc_eth_packet_test.py```
