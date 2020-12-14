# LpGBT-FPGA IP (vers. 1.0.0)

The LpGBT ASIC (Low Power GigaBit Transceiver) is a new 65nm-CMOS radiation tolerant serializer/deserializer 
device that can be used on the front-end electronics of the HL-LHC detectors. This component is foreseen to 
be used by CMS and ATLAS for their system upgrades and offers a set of encoding and decoding schemes specifically 
tailored to meet their needs in terms of radiation-hardness and data bandwidth.

The LpGBT-FPGA project started in 2018 as a natural evolution of the existing GBT-FPGA to provide a back-end 
counterpart to the future LpGBT ASIC. The new FPGA IP implements the encoding/decoding schemes supported by 
the front-end ASIC, meaning that it can be configured using 4 different combinations for the upstream link 
(from Front-end to Back-end): two decoding schemes (FEC5 or FEC12) based on Reed-Solomon techniques to configure 
the encoding robustness and two line rates (10.24 or 5.12Gbps) depending on the required bandwidth. Additionally, 
the LpGBT-FPGA core features an asymmetric architecture to match the LpGBT ASIC specificities: the transmitter 
part of the IP, as opposed to the configurable receiver part, proposes a single encoding scheme (FEC12) and a 
lower line rate of 2.56Gbps. Such an asymmetry prevents the IP to be used in loopback mode for self-testing.

<div style="border: 1px solid #faebcc; background:#fcf8e3; color:#8a6d3b; padding: .75rem 1.25rem; border-radius: .25rem;"><b>Warning:</b> Philosophy changed since the GBT-FPGA: the LpGBT-FPGA is not 
anymore given as a generic module that can be implemented in one block. It is now proposed as a set of modules with implementation example and reference notes 
to help the user in designing its own system in the most efficient way.</div>

## Links

- [Gitlab repo](https://gitlab.cern.ch/gbt-fpga/lpgbt-fpga)
- [Documentation](http://lpgbt-fpga.web.cern.ch)
- [LpGBT Sharepoint] (https://espace.cern.ch/GBT-Project/LpGBT/default.aspx)
- [Simulation testbench] (https://gitlab.cern.ch/gbt-fpga/lbgbt-fpga-simulation)

## Repository architecture

* **dataPath**: Contains the top files that interconnect the datapath modules (Encoder/Decoder, Scrambler/Descrambler)
* **fecCodec**: Contains the Reed-Solomon encoders/decoders (used by datapath modules)
* **scrDscr**: Contains the scramblers/descramblers modules
* **gearbox**: Contains the Tx and Rx gearboxes (configurables) used to pass from the datapath clock domain to the MGT clock domain
* **mgtFrameAligner**: Contains the Rx frame aligner module used to aligned the incoming frame using the header.

## Modules description

The LpGBT-FPGA provides a back-end counterpart to the LpGBT asic meaning that it implements the down and up link datapaths (scrambler, encoder, interleaver) 
and the SerDes to deal with the high speed side (5.12Gbps or 10.24Gbps). Because of the range of configurations available, and in order to avoid having a
too comprehensive and heavy IP to integrate, the LpGBT-FPGA core is made of several modules that can be easily configured and instantiated by the user. According to this philosophy, users can
optimize the use in term of resources and/or quality vs. versatility (e.g.: dynamic or fixed datarate mode). The block diagram below shows the interconnections
of the differents blocks available:

<div style="border: 1px solid #faebcc; background:#fcf8e3; color:#8a6d3b; padding: .75rem 1.25rem; border-radius: .25rem;"><b>Warning:</b> Mgt is not included in the LpGBT-FPGA folder as it is device and user dependant.
However, reference notes are provided to show the typical / recommended configuration for different FPGAs <a href="http://lpgbt-fpga.web.cern.ch/doc/user/refnotes.php">here</a>.</div>

<img src='http://lpgbt-fpga.web.cern.ch/img/globalBlockDiagram.png' />


### Downlink datapath

The downlink datapath encodes the data according to the LpGBT specification, using a specific implementation of the reed-solomon encoder.
It is designed to work at 40MHz, or using a multicycle path architectue with a clock enable signal at 320MHz (1 to 8). The frame size is 64bit (including the FEC). 
It provides a user bandwidth of 1.28Gbps and 2 additional fields for the slow control of 80Mbps are also available. The total line rate is 2.56Gbps.

Therefore, the downlink frame of the LpGBT-FPGA is made of:

* **Header (4bit)**: Used by the LpGBT to align the frame.
* **User data (32bit)**: sent to LpGBT e-links.
* **EC (2bit)**: used for the external slow control (e.g.: GBT-SCA).
* **IC (2bit)**: used for the internal slow control of the LpGBT (register configuration).
* **FEC (24bit)**: used to recover from transmission error (can correct up to 12 consecutives errors).

Additional details about the module (ports, architecture ...) are available on <a href="http://lpgbt-fpga.web.cern.ch/doc/html/class_lp_g_b_t___f_p_g_a___downlink__datapath.html">here</a>

### Uplink datapath

The uplink datapath decodes the data, according to the LpGBT specification, using a specific implementation of reed-solomon decoders.
It is designed to work at 40MHz, or using a multicycle path implementation with a clock enable signal at 320MHz (with a 1 to 8 ratio). The frame size is 128 or 256bit (including the FEC),
depending on the datarate (10.24 or 5.12Gbps).


This path is configurable as follow:

* **5.12Gbps / FEC5**:
    * **Header(2bit)**: Used by the LpGBT to align the frame.
    * **Slow control (4bit)**: IC (2bit) and EC (2bit).
    * **User bandwith (112bit)**: From LpGBT e-links.
    * **FEC (10bit)**: Can correct up to 5 consecutives errors.

* **5.12Gbps / FEC12**:
    * **Header(2bit)**: Used by the LpGBT to align the frame.
    * **Slow control (4bit)**: IC (2bit) and EC (2bit).
    * **User bandwith (98bit)**: From LpGBT e-links (2bit unconnected).
    * **FEC (24bit)**: Can correct up to 5 consecutives errors.

* **10.24Gbps / FEC5**:
    * **Header(2bit)**: Used by the LpGBT to align the frame.
    * **Slow control (4bit)**: IC (2bit) and EC (2bit).
    * **User bandwith (230bit)**: From LpGBT e-links (6bit unconnected).
    * **FEC (20bit)**: Can correct up to 5 consecutives errors.

* **10.24Gbps / FEC12**:
    * **Header(2bit)**: Used by the LpGBT to align the frame.
    * **Slow control (4bit)**: IC (2bit) and EC (2bit).
    * **User bandwith (202bit)**: From LpGBT e-links (10bit unconnected).
    * **FEC (48bit)**: Can correct up to 5 consecutives errors.

Additional details about the module (ports, architecture ...) are available on <a href="http://lpgbt-fpga.web.cern.ch/doc/html/class_lp_g_b_t___f_p_g_a___uplink__datapath.html">here</a>

### SerDes

The SerDes block is responsible for the serialization/deserialization of the high-speed link. According to the LpGBT-FPGA philosophy, 
this part of the design is not provided as a comprehensive entity, but shall be assembled and customized by the end user according to 
its requirements. Three implementation schemes can be implemented depending on the use case. They are mostly based on configuring 
LpGBT-FPGA generic entities, and on instantiating the MGT with a line rate selected as a common multiple of both down and up links:

* **Implementation scheme #1: Static 5.12Gbps**: The MGT is configured with a symmetric bidirectional serial stream @ 5.12Gbps.
    * **The Downlink** stream is oversampled by 2 by a specific Tx_Gearbox instantiation (each bit is duplicated to slow down the effective rate to 2.56Gbps)
    * **The Uplink** stream runs at the effective rate of 5.12 Gbps only.
    
    <img src="http://lpgbt-fpga.web.cern.ch/img/serdesBlockDiagram5g12.png" />
    
* **Implementation scheme #2: Static 10.24Gbps**: Mgt configured to work at 10.24Gbps (optimizes quality and resource usage when only 5.12Gbps links are used)
    * **The Downlink** stream is oversampled by 4 by a specific Tx_Gearbox instantiation (each bit is sent 4 times to slow down the rate to 2.56Gbps)
    * **The Uplink** stream runs at the effective rate of 10.24 Gbps only
    
    <img src="http://lpgbt-fpga.web.cern.ch/img/serdesBlockDiagram10g24.png" />
    
* **Implementation scheme #3: Dynamic uplink rate**: Mgt configured to work at 10.24Gbps (most versatile implementation but requires additional logic and can degrade the use of 5.12Gbps links)
    * **The Downlink** stream is oversampled by 4 by the Tx_gearbox (each bit is sent 4 times to slow down the rate to 2.56Gbps)
    * **The Uplink** stream is physically running at 10.24 Gpbs. However, it can be either directly decoded for an effective line rate of 10.24 Gbps, or ‘undersampled’ by 2 to reach an effective line rate of 5.12Gbps. The effective line rate is selected by a specific port, bringing the possibility to dynamically switch from 5.12 to 10.24 Gbps. At the cost of a less optimized implementation, of course.
    
    <img src="http://lpgbt-fpga.web.cern.ch/img/serdesBlockDiagramDynamic.png" />
    
Reference notes describing how to configure the gearboxes, pattern search and Mgt depending on the needed configuration are available here (<a href="http://lpgbt-fpga.web.cern.ch/doc/user/refnotes.php">link</a>)

**Note**: the static schemes are optimized for each effective uplink line rate. Once this uplink rate has been fixed by the front end, it is recommended to select a static implementation instead of the dynamic one to spare resources. 