GEM AMC Firmware Project
========================

This repository contains sources for common GEM AMC firmware logic as well as board specific implementations for GLIB (Virtex 6) and CTP7 (Virtex 7).
Note that this repository excludes ISE / Vivado project directories entirely to avoid generated files, although XISE / XPR files are included in directories called work_dir. Those XISE / XPR files are referencing the source code outside work_dir and once opened will generate an ISE / Vivado project in the work_dir. PLEASE DO NOT COMMIT ANY FILES FROM THE WORK_DIR OTHER THAN XISE / XPR!!! 

In scripts directory you'll find a python application which takes an address_table (provided) and inserts the necessary VHDL code to expose those registers in the firmware as well as uHAL address table, documentation and some bash scripts for quick CTP7 testing.

# CTP7 Optical Interface

CTP7 has 3 CXP transceivers (the ones that stick out of the board), and 3 MiniPOD receivers, and 1 MiniPOD transmitter, but all 4 MiniPODs are connected to a single MTP48 interface where each of them have a row of 12 fibers.

The CXP transceivers are numbered top to bottom starting at 0, so CXP0 is the top transceiver, and CXP2 is the bottom one. 

For the miniPOD channels we'll refer to them as MTP48 row 1-4 channel 1-12. Usually an MTP48-to-4xMTP12 cable is used on this interface, which breaks out each row into a separate MTP12 connector, and normally they are labeled 1-4, referring to the rows as counted from top to bottom, which should match our row numbering here.

Below are the connection tables for the different GEM stations:

**GE1/1 map:**

| OH   | GBT0       | GBT1       | GBT2       | Trig0             | Trig1             |
| ---- | ---------- | ---------- | ---------- | ----------------- | ----------------- |
| OH0  | CXP0 ch 1  | CXP0 ch 2  | CXP0 ch 3  | MTP48 row 3 ch 5  | MTP48 row 3 ch 6  |
| OH1  | CXP0 ch 4  | CXP0 ch 5  | CXP0 ch 6  | MTP48 row 3 ch 7  | MTP48 row 3 ch 8  |
| OH2  | CXP0 ch 7  | CXP0 ch 8  | CXP0 ch 9  | MTP48 row 3 ch 9  | MTP48 row 3 ch 10 |
| OH3  | CXP0 ch 10 | CXP0 ch 11 | CXP0 ch 12 | MTP48 row 3 ch 11 | MTP48 row 3 ch 12 |
| OH4  | CXP1 ch 1  | CXP1 ch 2  | CXP1 ch 3  | MTP48 row 2 ch 1  | MTP48 row 2 ch 2  |
| OH5  | CXP1 ch 4  | CXP1 ch 5  | CXP1 ch 6  | MTP48 row 2 ch 3  | MTP48 row 2 ch 4  |
| OH6  | CXP1 ch 7  | CXP1 ch 8  | CXP1 ch 9  | MTP48 row 2 ch 5  | MTP48 row 2 ch 6  |
| OH7  | CXP1 ch 10 | CXP1 ch 11 | CXP1 ch 12 | MTP48 row 2 ch 7  | MTP48 row 2 ch 8  |
| OH8  | CXP2 ch 1  | CXP2 ch 2  | CXP2 ch 3  | MTP48 row 2 ch 9  | MTP48 row 2 ch 10 |
| OH9  | CXP2 ch 4  | CXP2 ch 5  | CXP2 ch 6  | MTP48 row 2 ch 11 | MTP48 row 2 ch 12 |
| OH10 | CXP2 ch 7  | CXP2 ch 8  | CXP2 ch 9  | MTP48 row 1 ch 9  | MTP48 row 1 ch 10 |
| OH11 | CXP2 ch 10 | CXP2 ch 11 | CXP2 ch 12 | MTP48 row 1 ch 11 | MTP48 row 1 ch 12 |

**GE2/1 map (note that the trigger links are only used on the legacy v1 electronics):**

| OH   | GBT0       | GBT1       | Trig0             | Trig1             |
| ---- | ---------- | ---------- | ----------------- | ----------------- |
| OH0  | CXP0 ch 1  | CXP0 ch 2  | MTP48 row 3 ch 5  | MTP48 row 3 ch 6  |
| OH1  | CXP0 ch 3  | CXP0 ch 4  | MTP48 row 3 ch 7  | MTP48 row 3 ch 8  |
| OH2  | CXP0 ch 5  | CXP0 ch 6  | MTP48 row 3 ch 9  | MTP48 row 3 ch 10 |
| OH3  | CXP0 ch 7  | CXP0 ch 8  | MTP48 row 3 ch 11 | MTP48 row 3 ch 12 |
| OH4  | CXP0 ch 9  | CXP0 ch 10 | MTP48 row 2 ch 1  | MTP48 row 2 ch 2  |
| OH5  | CXP0 ch 11 | CXP0 ch 12 | MTP48 row 2 ch 3  | MTP48 row 2 ch 4  |
| OH6  | CXP1 ch 1  | CXP1 ch 2  | MTP48 row 2 ch 5  | MTP48 row 2 ch 6  |
| OH7  | CXP1 ch 3  | CXP1 ch 4  | MTP48 row 2 ch 7  | MTP48 row 2 ch 8  |
| OH8  | CXP1 ch 5  | CXP1 ch 6  | MTP48 row 2 ch 9  | MTP48 row 2 ch 10 |
| OH9  | CXP1 ch 7  | CXP1 ch 8  | MTP48 row 2 ch 11 | MTP48 row 2 ch 12 |
| OH10 | CXP1 ch 9  | CXP1 ch 10 | MTP48 row 1 ch 9  | MTP48 row 1 ch 10 |
| OH11 | CXP1 ch 11 | CXP1 ch 12 | MTP48 row 1 ch 11 | MTP48 row 1 ch 12 |

CTP7 Notes
==========

To run chipscope follow these steps:
   * SSH into CTP7 and run: xvc \<ip_of_the_machine_directly_talking_to_ctp7\>
   * If running Vivado on a machine that's not directly connected to the MCH, open a tunnel like so: ssh -L 2542:eagle34:2542 \<host_connected_to_ctp7\>
   * Open Vivado Hardware Manager, click Auto Connect
   * In TCL console run: open_hw_target -xvc_url localhost:2542 (if not using tunnel, just replace localhost with CTP7 IP or hostname)
   * Once you see the FPGA, click refresh device to get all the Chipscope cores in your design

CTP7 doesn't natively support IPbus, but it can be emulated. In this firmware the GEM_AMC IPbus registers are mapped to AXI address space 0x64000000-0x67ffffff using an AXI-IPbus bridge. IPbus address width is 24 bits wide and it's shifted left by two bits in AXI address space (in AXI the bottom 2 bits are used to refer to individual bytes, so they're not usable for 32bit word size). So to access a give IPbus register from Zynq, you should do: mpeek (0x64000000 + (\<ip_bus_reg_address\> \<\< 2)) for reading and mpoke (0x64000000 + (\<ip_bus_reg_address\> \<\< 2)) for writing. So e.g. to write 0x1 to IPbus reg 0x300001, you would run mpoke 0x64c00004 0x1 (or simply use the provided ipb_read.sh and ipb_write.sh which will do that for you. You can also use the provided ctp7_status.sh script (generated), which will read and print all the readable registers of a given firmware module. In IPbus address the top 4 bits [23:20] are dedicated to selecing a GEM_AMC module (see scripts/address_table for more info). Module 0x4 is OH reg forwarding where addressing is [19:16] - OH number, [15:12] - OH module, [11:0] - address within modulem (remember to shift 2 bits up when translating to AXI address space).
To read and write the IPbus registers using uHAL, you can use an application, developed by WU that can be run on Zynq linux and emulates IPBus master. Compiled binary is included in scripts directory here, the source repository is here: https://github.com/uwcms/uw-appnotes/  (see docs directory for instructions on compiling applications for the Zynq processor)
