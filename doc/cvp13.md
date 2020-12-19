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
## Download and install the software and firmware
TODO

## Program the card
First of all, ensure that you have connected the microUSB port (found on the back of the CVP13) to your computer.
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

## Hot reloading the FPGA
It's possible to reload the FPGA and continue using the card without a reboot if the PCIe configuration hasn't changed in the new firmware.
You do it like this:
1. ```sudo cat /sys/bus/pci/devices/0000\:XX\:00.0/config > ~/cvp13_pcie_config```
1. unload any drivers that are using the card (we don't have any yet, so skip this for now)
1. reload the FPGA: ```/opt/bwtk/2019.3L/bin/bwconfig --start --type=fpga```
1. ```sudo cp ~/cvp13_pcie_config /sys/bus/pci/devices/0000\:XX\:00.0/config```

Replace the XX with the bus number of where you installed the card. It shows up in lspci as a Xilinx 0xBEFE device (sorry, EMU doesn't have a PCI vendor ID yet, so using Xilinx here): ```sudo lspci | grep -i befe```, you should see something like: ```05:00.0 Memory controller: Xilinx Corporation Device befe``` (XX=05 in this case)


