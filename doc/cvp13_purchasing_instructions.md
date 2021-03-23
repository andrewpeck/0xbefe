
Bittware CVP13 PCIe Card Purchasing and Setup Instructions
=========================

Purchasing the CVP13 card
=========================

This is the same card as Bittware XUP-VVP (identical hardware), but considerably cheaper due to it targeting the retail crypto mining market, and not including some of the software and firmware examples, which we do not use. For this reason this card is only sold through retailers, and not directly from Bittware.

The GEM backend firmware and software have been adapted to work with the CVP13 card, and has been validated using GE2/1 frontend hardware (GE2/1 Optohybrid v2 and GE2/1 VFAT plugin cards).

So far we’ve only purchased this card from a retailer called Comino (https://comino.com/), they are based in Europe, but also have an office in the U.S., the contact person is Ivan Telia ([itl@comino.com](mailto:itl@comino.com)).

Avnet seems to also have this card: https://www.avnet.com/shop/us/products/bittware/cvp-13-l-3074457345642014168

Additional parts
================

The CVP13 card requires these additional components:

1.  Computer, capable of hosting this card
1.  Liquid cooling system
1.  QSFP transceivers
1.  Optionally 2 DDR4 DIMM modules can be installed on the card (not used in GEMs)

You’ll also need a standard micro-USB cable to access JTAG and program or debug the FPGA, write flash, and configure the clocks (I forget if it was or was not included with the card).

Computer
--------

The computer hosting this card should have at least one free 16x PCIe slot, and enough space in the chassis to accommodate this dual slot, 3/4-length card. The CVP13 dimensions are: 10 x 4.37 inches (254 x
111.15 mm). It is not a small card, but it’s not bigger than an off-the-shelf high end video card (GPU), so most tower PCs will work (server chassis can be more tricky).

The power is supplied to the CVP13 via two 8-pin PCIe power connectors, thus the power supply of the PC must have two such cables available. Note that both cables \*must\* be plugged in. The manual states that for low power applications it’s possible to use two PCIe power cables with 6-pin connectors instead (note that both must be 6-pin in that case),
but this configuration has not been tested.

In terms of software, only the standard CERN linux distributions will be supported (current version is CC7).

Dell Precision 5820 Tower workstation is a good candidate. When configuring the 5820, make sure that 950W chassis is selected. The rest of the specs are up to you, but for best value it’s recommended to choose an i9 series CPU like 10900X instead of a Xeon (they are basically the same chips, but given the same core count, the i9 is cheaper while offering the same performance). Also keep in mind that these CPUs have quad channel memory controllers, so make sure to select
4 memory modules to be able to use full memory bandwidth (e.g. for 32GB select 4x8GB, and not 2x16GB or 1x32GB). Adding an NVMe SSD (and choosing it as a boot drive), even if it’s a small one like 256GB, will greatly improve the user experience. For the price, keep in mind that a significant university discount will be applied when you ask for a quote
(make sure to ask for the discount).

E.g. this is a reasonable configuration (cost is below \$2k with university discount):
-   CPU: 10900X or 10920X
-   OS: Ubuntu (this is free, will reinstall with CC7 anyway, so don’t choose windows or RedHat)
-   950W FlexBay Chassis
-   Nvidia Quadro P620
-   32GB 4x8GB DDR4 2666MHz UDIMM Non-ECC Memory (64GB 4x16GB even better)
-   Operating system drive: Intel NVMe PCIe SSD
-   Storage Drive Controllers: Intel Integrated Controller with FlexBay NVMe PCIe Drives
-   1st drive: M2. 256GB PCIe NVMe Class 40 SSD (feel free to choose a higher capacity or a faster drive)
-   2nd drive: 3.5” 2TB 7200rpm SATA Hard Drive

Liquid Cooling System
---------------------

The CVP13 has been shown to work well with the Koolance EXT-440CU liquid cooling system -- it’s an external box that contains all the liquid cooling components like radiator, fan, pump, reservoir, etc., which makes it easy to setup. You’ll want to order the cooling box, non-conductive cooling liquid, 3/8in polyurethane tubing, and quick-disconnect couplings from
https://koolance.com/:

1.  Part No. EXT-440CU (1 piece):  EXT-440CU Computer Liquid Cooling System, Rev2.0) --- [link
    here](https://koolance.com/ext-440cu-liquid-cooling-system-copper&sa=D&source=editors&ust=1615902880916000&usg=AOvVaw01B77ly_AVGfQ45H6m9yLO)
1.  Part No. LIQ-705CL-B (1 piece or more):  Koolance 705 Liquid Coolant, Electrically Insulative, Colorless, 700ml (24 fl oz) ---[link here](https://koolance.com/liq-705-liquid-coolant-bottle-low-conductivity-700ml-clear&sa=D&source=editors&ust=1615902880917000&usg=AOvVaw2rFiTBjBduhjqSiRXb_n9Q)
1.  Part No. HOS-10X13PU-CL-3M (1 piece or more):  Tubing, PU Clear, Dia: 10mm x 13mm (3/8in x 1/2in) - [Length 3m / 9.8ft] --- [link here](https://koolance.com/tubing-clear-pu-10mm-x-13mm-3-8in-x-1-2in-3m&sa=D&source=editors&ust=1615902880917000&usg=AOvVaw1T64NYdGlkx_EVUXVF1e5I)
1.  Part No. QD3H-MG4 (2 pieces):  QD3H Male Quick Disconnect No-Spill Coupling, Male Threaded G 1/4 BSPP --- [link
    here](https://koolance.com/qd3h-mg4-quick-disconnect-no-spill-coupling-male-threaded-g-1-4&sa=D&source=editors&ust=1615902880917000&usg=AOvVaw0Z_U_bdDRby6TZfg911-r1)
1.  Part No. QD3H-F10-P (2 pieces): QD3H Female Quick Disconnect No-Spill Coupling, Panel Barb for ID 10mm (3/8in) --- [link here](https://koolance.com/quick-disconnect-no-spill-coupling-female-panel-barb-for-id-10mm-3-8in-qd3h-f10-p&sa=D&source=editors&ust=1615902880918000&usg=AOvVaw17Asx4CSL0OJOJwFLu8KYk)

Note: it’s recommended to replace the cooling fluid every 2-3 years. To fill my system I used more or less one third of the LIQ-705CL-B bottle.

Carefully read the EXT-440CU instructions on how to set it up. Some key things to keep in mind: ideally place the cooling box above the computer; don’t fill the reservoir completely full.

It’s fine to run it at the minimum pump speed setting (although you’ll want to run it faster for a bit at the beginning to remove all the small bubbles out of the system so it stops making gurgling sounds).

You’ll have to run the tubes outside the PC through the PCIe bracket that is included with the EXT-440CU cooling box.

The quick disconnects are nice so that you can disconnect the cooling box from the computer without draining the system (e.g. if you want to move it around). The threaded male part screws directly into the cooling box, while the female part mates with the tube. You could add more quick disconnects if you want.

Optical Transceivers
--------------------

The CVP13 has 4 QSFP cages compatible with QSFP, QSFP+, and QSFP28 transceivers. The FPGA model is xcvu13p-figd2104-2-e, which supports line rates up to 28.21Gb/s. The QSFP transceivers have 4 transmitters and 4 receivers, and their model names often refer to the aggregate line rate of all 4 channels e.g. 40G QSFP means the 4 links go up to
\~10Gb/s, and 100G QSFP means the 4 links go up to \~25Gb/s. For GEM applications (GE1/1, GE2/1, and ME0) the 40G transceivers with 10Gb/s links are enough. Most faster 100G transceivers should also work, but some of them are designed to only work at 25Gb/s and don’t work at slower line rates, so it’s useful to check the datasheet and/or confirm
with the vendor that CDR can be disabled and slower line rates are supported. For CSC FED work the faster 100G transceivers are required. Below are descriptions of several models.

So far only one 40G transceiver model has been tested with GE2/1 (VTRX transceiver) and ME0 (VL+ transceiver) and verified to work: QSFP-SR4-40G from FS (https://www.fs.com/products/75298.html).
In their website make sure to select “Generic” type in the “compatibility” section -- these are very cheap, just \$39, and work very well at GBTX and LpGBT line rates. Since this is known to work, it is the recommended option for GEMs.

There’s also a 100G option from FS called QSFP28-SR4-100G (https://www.fs.com/products/75308.html), but the default version only supports 25Gb/s operation, but if you tell the vendor that slower than 25Gb/s operation is required, they will send the part with a different firmware, which also supports slower line rates. I didn’t know this, and received the parts that couldn’t run at slower rates, but told FS about it and they offered me to replace them (currently in shipping). Alex Madorsky has tested them at 16Gb/s operation, but they haven’t been tested with VTRX or VL+.

Formerica TQS-Q14H9-J83 has been tested by Alex Madorsky at 25.78Gb/s and works well. It hasn’t been tested at slower line rates or with CERN transceivers. It’s unknown if they support disabling of the CDR and thus slower than 25Gb/s line rate.

In summary:
-   For GEM work: buy QSFP-SR4-40G (4 pieces would let you connect a full GE2/1 super-chamber, or 2 layers of ME0)
-   For CSC work buy QSFP28-SR4-100G, but you must explicitly request the version that supports slower than 25Gb/s line rate (by disabling the CDR). This should also work for GEMs, but hasn’t been tested yet
-   For communication with DTH or future EMTF, buy the Formerica TQS-Q14H9-J83

Memory
------

There are two DDR4 DIMM sites on the CVP13 that can be populated with off the shelf RDIMM modules, but care has to be taken to get a model that is compatible with this FPGA (compatibility can be checked using vivado DDR4 IP wizard) e.g. this is a good option: MTA18ASF2G72PZ (https://memory.net/product/mta18asf2g72pz-2g3-micron-1x-16gb-ddr4-2400-rdimm-pc4-19200t-r-single-rank-x4-module/).
There’s also an option to buy special DIMMs from Bittware which have 2x288Mbit of QDR-II+ SRAM.

For GEM work these modules are not necessary, while for CSC FED (or other applications) it can be used to e.g. emulate the frontend sending pre-recorded data.

Connecting to External Copper Signals
=====================================

If you have a need to e.g. run this board on a common clock with other hardware, or use an external trigger signal from scintillators, you can use the special USB type C interface on the CVP13, which provides:

1.  External clock input (connected to the on-board synthesizers)
1.  FPGA GPIO
1.  two high speed serial lines connected to MGTs

Most sites won’t need this functionality. But if you do want to use it, keep in mind that most USB cables out there don’t actually connect all the conductors on the USB type C connector, so it’s necessary to shop around and get a nice cable rated for USB 3.2 Gen 2x2 (20Gb/s).

Other Notes
===========

There are crypto currency mining bitfiles out there for CVP13, but I would recommend to stay away from them since they can really stress the chip drawing a lot of power, and it’s unknown how this cooling solution and the card itself would handle it, especially long term (I haven’t tried).
