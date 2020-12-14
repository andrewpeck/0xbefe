Revisions:

2014-04-30  initial version with some bugs
2014-05-07  release_1.0
2014-05-28  updated (but as yet untested) version; works with Kintex 0x8104 and 0x204
2014-06-02  another update with various bug fixes; REQUIRES Kintex >= 0x8106
  or >= 0x207
2014-06-05  copy trunk as release-1.1
2014-09-09  FIFO change, update link version to 5
2014-10-18  Link version update to 6, other minor bug fixes

2015-03-19  Link version now 9
	    MGT moved out -- now the user's responsibility
	    Thus the top-level entity has changed significantly
	    Requires AMC13 firmware >= 0x401f / 0x224

2015-03-20  Link version 0xa
	    Bug fixes
	    Requires AMC13 firmware >= 0x4120, 0x225 and 0x811a

2015-03-29  Link version 0xb
	    Requires AMC13 firmware >= 0x4021, 0x226 and 0x811b

	    This new version fixed a bug in fifo66x512.vhd which sometime holds the
	    last word in its buffer.
	    The generic parameter USE_TRIGGER_PORT has been moved to an input port.
    	    There are three other new ports at the end of the port list.
	    During instantiation, connect '0' to port sysclk and assign open to ports
	    L1A_DATA_we and L1A_DATA. These ports are used in other designs and now
	    they can share the same code.

2015-04-02  Link version 0xd (13)
	    bug introduced in 0xc fixed
	    modules DAQ_Link_V6.vhd and TTS_TRIG_IF.vhd changed

	    CriticalTTS added to DAQ_Link_V6.vhd(bit 11-9 of reg 0x2e)
	    reset(Ready_i low) lengthened
	    Only module DAQ_Link_V6.vhd changed
	
2015-04-11  version 0x10 (release as 1.9)

	    fixed a bug which causes TTC-trigger data bit errors
	    modules hamming.vhd and DAQ_LINK_v6.vhd changed

In module's declaration or its instantiation, set the
generic parameter F_REFCLK as your design's frequency of the GTX reference
clock

If you are using amc13 firmware 0x4xxx, input port USE_TRIGGER_PORT
should be set to boolean value TRUE in your instantiation, otherwise
set it to FALSE

please include the following two lines in your UCF file:

NET "*/i_DAQ_Link_V6/usrclk" TNM_NET = "DAQ_usrclk";
TIMESPEC "TS_DAQ_usrclk" = PERIOD "DAQ_usrclk" 4.0;

where i_DAQ_Link_V6 is the instance name of the module DAQ_Link_V6
in its upper level module.

This zip file includes following files:

DAQ_Link_V6.vhd		top level module
EthernetCRCD32.vhd
CRC16D16.vhd
TTS_TRIG_if.vhd
RAM32x6Db.vhd
Hamming.vhd
DAQLINK_gtx.vhd
fifo66x512.vhd
