# Setting up CVP13
The setup process consists of these steps:
1. Install the card in the computer, connect cooling, and the micro USB cable
1. Install Bittworks Toolkit LITE software (requires access), we'll refer to it as BWTK
1. Download the firmware + software
1. Use the BWTK to program the clock synthesizers and the firmware PROM
	* Reboot if this was the first time you flashed the PROM (also might be necessary after after major firmware upgrades)
1. Figure out the PCIe bus that the card is sitting in, and start using the card

## Installing the hardware
TODO (but just follow the instructions provided with the CVP13 and the Koolance box)

## Program the card
To program the clocks and FPGA you will need the Bittworks Toolkit LITE software from Bittware. Please contact your Bittware representative or the retailer from which you bought the card and ask for the RHEL7 RPM package of Bittworks Toolkit LITE.

Download the latest firmware bitstream from the 0xBEFE repository releases page: https://gitlab.cern.ch/emu/0xbefe/-/releases

Ensure that you have connected the microUSB port (found on the back of the CVP13) to your computer.
Start the BWTK monitor GUI:
```
/opt/bwtk/2019.3L/bin/bwmonitor-gui
```
(update the version as needed)
Select the card and click connect. Scroll down to the "Programmable Clocks (PLL)" section, select Si5341-A, right click and select "Write clock program", and select the ```cvp13_synth_a_gem.h``` file (found in boards/cvp13/resources/clock_configs directory of the 0xBEFE repo). Repeat the same procedure for the Si5341-B synthesizer, but select the ```cvp13_synth_b_gem.h``` file. You can now close the monitor-gui application.

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

If you don't want to only load a bitstream for temporary use (e.g. for testing), you can just load it directly to the FPGA instead of writing the flash, but it will be lost after a power-cycle. This is faster, so it's nice for firmware developers, but regular users should just write flash. Note that FPGA programming seems to be only supported in the GUI mode :(

## Set up the software
This repository contains low level hardware access software as well as python scripts, which provide an interactive register access, and various communication testing procedures, and also makes it easy to write your own scripts for interacting the the hardware. Python tools are useful for debugging use, but high level routines like scurve scans, etc, are implemented in the official GEM software, which lives elsewhere (https://gitlab.cern.ch/cmsgemonline), and is not covered by this document.

You can use the scripts directly from this repo, all you have to do is:
1. Generate the XML address table file by running this command at the root of the repository: ```make update_me0_cvp13``` (replace me0 with ge21 or ge11 as appropriate). This step is only needed after cloning or updating the repository.
1. Compile the rwreg library that is used for hardware access: ```scripts/boards/cvp13/rwreg && make```. This step is only needed after cloning or updating the repository.
1. Initialize and configure the CVP13 firmware for the given station: ```cd scripts && python boards/cvp13/cvp13_init_me0.py```. This step is only needed after a CVP13 power cycle or CVP13 FPGA programming.
1. Set up the environment for your station and card combination: ```cd scripts && source env_gem.sh me0 cvp13``` (replace me0 with ge21 or ge11 as appropriate). This step is needed for every new terminal that you want to use the scripts in.
1. Use the scripts e.g.:
	1. start the interactive register access tool: ```python common/reg_interface.py```, once the tool is running e.g. to read the GBT link status registers of OH0 type ```readKW OH_LINKS.OH0.GBT``` (readKW means read all registers matching the substring), or check the CVP13 firmware version and configuration: ```readKW GEM_SYSTEM```. You can also write to registers using the write command. You can get some help by typing help. Refer to the address table XML file to find what registers exist and what they do (there's documentation for each register). At some point PDF document should also get generated from the XML when running make update_me0_cvp13, but that's not yet working..
	1. use gem/gbt.py to program your GBT or run a phase scan
	1.  write your own: a simple example of reading and writing registers from python can be found here: common/example_reg_access.py

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

Mapping to GE2/1 OHs is the following:
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

