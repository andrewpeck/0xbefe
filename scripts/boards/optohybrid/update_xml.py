#/usr/env python3
from __future__ import unicode_literals
import sys
import math
import argparse

from polarity_swaps import *
from insert_code import *

from timing_constants_geb_v3b_short import *
from timing_constants_geb_v3a_short import *
from timing_constants_geb_v3c_long  import *
from timing_constants_geb_ge21_null  import *

num_vfats = 0
num_sbits = 0
use_inverted_numbering = True
station = ""
geb_version = "v3c"
geb_length = ""

def main():

    parser = argparse.ArgumentParser()

    parser.add_argument('-x',
                        '--xml',
                        dest='xml',
                        help="XML file to update")

    parser.add_argument('-s',
                        '--station',
                        dest='station',
                        help="Station (ge21, ge11)")

    parser.add_argument('-l',
                        '--length',
                        dest='length',
                        help="Length (long, short)")

    parser.add_argument('-v',
                        '--version',
                        dest='version',
                        help="Version (v3a, v3b, vrc)")

    args = parser.parse_args()

    if args.xml is None:
        print("You need to specify an XML file")
        sys.exit()

    if args.station is None:
        print("You need to specify a Station")
        sys.exit()

    if not args.station in ("ge11", "ge21"):
        print("You need to specify a valid Station")
        sys.exit()

    if args.station == ("ge11") and args.length is None:
        print("You need to specify a GEB length for GE11")
        sys.exit()

    if args.station == ("ge11"):
        global geb_length
        geb_length = args.length

    global geb_version
    if args.version is not None:
        geb_version = args.version
    else:
        geb_version = "v3c"

    global station
    global num_vfats
    global num_sbits
    global use_inverted_numbering

    xmlfile = args.xml
    station = args.station

    if (station == "ge21"):
        num_vfats = 12
        num_sbits = 8*num_vfats
        use_inverted_numbering = False

    elif (station == "ge11"):
        num_vfats = 24
        num_sbits = 8*num_vfats
        use_inverted_numbering = True


    trig_tap_delays = 0
    sot_tap_delays = 0

    MARKER_START='<!-- START: GLOBALS DO NOT EDIT -->'
    MARKER_END="<!-- END: GLOBALS DO NOT EDIT -->"
    insert_code (xmlfile, xmlfile, MARKER_START, MARKER_END, write_globals)

    MARKER_START='<!-- START: INVERT_REGS DO NOT EDIT -->'
    MARKER_END="<!-- END: INVERT_REGS DO NOT EDIT -->"
    insert_code (xmlfile, xmlfile, MARKER_START, MARKER_END, write_xml_invert_map)

    MARKER_START='<!-- START: TIMING_DELAYS DO NOT EDIT -->'
    MARKER_END="<!-- END: TIMING_DELAYS DO NOT EDIT -->"
    insert_code (xmlfile, xmlfile, MARKER_START, MARKER_END, write_timing_delays)

    MARKER_START='<!-- START: TU_MASK DO NOT EDIT -->'
    MARKER_END="<!-- END: TU_MASK DO NOT EDIT -->"
    insert_code (xmlfile, xmlfile, MARKER_START, MARKER_END, write_tu_mask)

def write_tu_mask (file_handle):

    f = file_handle

    ################################################################################
    # Trigger Units
    ################################################################################

    padding = "                " #spaces for indentation
    base_address = 0x0

    for vfat in range (0,num_vfats):

        address = base_address + vfat//4
        bitlow  = 8*vfat + 0
        bithi   = 8*vfat + 7
        mask    = 0xff << 8*(vfat%4)

        f.write('%s<node id="VFAT%d_TU_MASK" address="0x%X" permission="rw"\n' % (padding, vfat, address))
        f.write('%s    description="1 = mask the differential pair"\n' % (padding))
        f.write('%s    fw_signal="TU_MASK (%d downto %d)"\n' % (padding, bithi, bitlow))
        f.write('%s    mask="0x%08X"\n' % (padding, mask))
        f.write('%s    fw_default="0x0"/>\n' % (padding))

def write_timing_delays (file_handle):

    f=file_handle

    trig_tap_delays= []
    sot_tap_delays = []

    if (station=="ge21"):
        trig_tap_delays = ge21_null_trig_tap_delays
        sot_tap_delays = ge21_null_sot_tap_delays
    elif (geb_version=="v3a" and geb_length=="short" and station=="ge11"):
        trig_tap_delays = v3a_short_trig_tap_delays
        sot_tap_delays = v3a_short_sot_tap_delays
    elif (geb_version=="v3b" and geb_length=="short" and station=="ge11"):
        trig_tap_delays = v3b_short_trig_tap_delays
        sot_tap_delays = v3b_short_sot_tap_delays
    elif (geb_version=="v3c" and station=="ge11"): # same for long and short, finally
        trig_tap_delays = v3c_long_trig_tap_delays
        sot_tap_delays = v3c_long_sot_tap_delays
    else:
        trig_tap_delays = []
        sot_tap_delays = []
        print ("Unknown settings in update_timing_registers");
        return sys.exit(1)


    padding = "                    " # indent
    base_address = 0x0

    for vfat in range (num_vfats):

        geb_slot = 0

        if (use_inverted_numbering):
            geb_slot = (num_vfats-1)-vfat
        else:
            geb_slot = vfat

        for sbit in range (8):

            global_sbit                  = vfat*8+sbit
            global_sbit_in_geb_numbering = geb_slot*8+sbit

            address=math.floor((vfat*8+sbit) / 6) # 5 sbits per tap means 6 taps per 32 bit register
            mask=0x1f << 5*(global_sbit % 6)

            #print ( "VFAT #%s, Trigger Bit %s, Tap Delay=%s" % (vfat, sbit, trig_tap_delays[global_sbit]))

            f.write('%s<node id="TAP_DELAY_VFAT%s_BIT%s" address="0x%X" permission="rw"\n'                          %  (padding, vfat, sbit, address))
            f.write('%s    mask="0x%08X"\n'                                                                         %  (padding, mask))
            f.write('%s    description="VFAT %d S-bit %d tap delay"\n'  %  (padding, vfat, sbit))
            f.write('%s    fw_signal="trig_tap_delay(%d)"\n'                                                        %  (padding, global_sbit))
            f.write('%s    fw_default="%d"/>\n'                                                                     %  (padding, trig_tap_delays[global_sbit_in_geb_numbering]))

    for vfat in range (num_vfats):

        geb_slot = 0

        if (use_inverted_numbering):
            geb_slot = (num_vfats-1)-vfat
        else:
            geb_slot = vfat

        sot_base_address = (num_sbits-1) / 6 + 1
        address = sot_base_address + vfat/6
        mask=0x1f << 5*(vfat % 6) # 6 vfats per register

        #print ( "VFAT #%s SOT, Tap Delay=%s" % (vfat, sot_tap_delays[geb_slot]))

        f.write('%s<node id="SOT_TAP_DELAY_VFAT%s" address="0x%X" permission="rw"\n'                            %  (padding, vfat, int(address)))
        f.write('%s    mask="0x%08X"\n'                                                                         %  (padding, mask))
        f.write('%s    description="VFAT %d SOT tap delay"\n'                                                   %  (padding, vfat))
        f.write('%s    fw_signal="sot_tap_delay(%d)"\n'                                                         %  (padding, vfat))
        f.write('%s    fw_default="%d"/>\n'                                                                     %  (padding, sot_tap_delays[geb_slot]))

def ge21_old_to_new(old):
    if   (old == 2 ): new = 0
    elif (old == 0 ): new = 1
    elif (old == 4 ): new = 2
    elif (old == 10): new = 3
    elif (old == 6 ): new = 4
    elif (old == 8 ): new = 5
    elif (old == 9 ): new = 6
    elif (old == 11): new = 7
    elif (old == 7 ): new = 8
    elif (old == 1 ): new = 9
    elif (old == 5 ): new = 10
    elif (old == 3 ): new = 11

    if (station=="ge21"):
        return new
    else:
        return old

def write_globals (file_handle):

    f = file_handle

    mask = "0x0"
    if (num_vfats==12):
        mask = "0xfff"
    else:
        mask = "0xffffff"

    f.write('<!DOCTYPE node [\n')
    f.write('<!ENTITY NUM_VFATS_PER_OH "%d">\n' % (num_vfats))
    f.write('<!ENTITY VFAT_BITMASK  "%s">\n' % (mask))
    f.write(']>\n' % ())

def write_xml_invert_map (file_handle):

    f = file_handle

    ################################################################################
    # SOT
    ################################################################################

    sot_default = 0
    base_address = 0x0

    for j in reversed(range (num_vfats)):

        vfat = 0
        if (use_inverted_numbering):
            vfat = (num_vfats-j-1)
        else:
            vfat = j

        if (sot_polarity_swap(ge21_old_to_new(vfat), station)):
            swap = 1
        else:
            swap = 0

        sot_default = sot_default | (swap <<j)

    sot_mask="0x00000"
    if (num_vfats==12):
        sot_mask="0x00000fff"
    if (num_vfats==24):
        sot_mask="0x00ffffff"

    padding = "                " #spaces for indentation
    f.write('%s<node id="SOT_INVERT" address="0x%x" permission="rw"\n'  % (padding, base_address))
    f.write('%s    description="1=invert pair"\n' % (padding))
    f.write('%s    fw_signal="sot_invert"\n' % (padding))
    f.write('%s    mask="%s"\n' % (padding, sot_mask))
    f.write('%s    fw_default="0x%06X"/>\n' % (padding, sot_default))

    ################################################################################
    # Trigger Units
    ################################################################################

    base_address = base_address + 1

    for vfat in range (0,num_vfats):

        geb_slot   =  0
        fw_default =  0
        sbit       = -1

        if (use_inverted_numbering):
            geb_slot = (num_vfats-vfat-1)
        else:
            geb_slot = vfat

        # remap for new numbering
        geb_slot = ge21_old_to_new(geb_slot)

        for pair in range (0,8):

            if (sbit_polarity_swap(geb_slot, pair, station)):
                swap = 0x1
            else:
                swap = 0x0

            if (use_inverted_numbering):
                sbit = 8*(vfat) + (pair) # enumerate 0--191 instead of (1--24)+(0--7)
            else:
                sbit = 8*(vfat) + (pair) # enumerate 0--191 instead of (1--24)+(0--7)

            fw_default = fw_default | (swap<<pair)

        address = base_address + vfat//4
        bitlo  = (vfat%4) * 8
        bithi  = bitlo + 7
        mask   = 0xff << (bitlo)

        bithi = bithi + 32*(vfat//4)
        bitlo = bitlo + 32*(vfat//4)

        f.write('%s<node id="VFAT%d_TU_INVERT" address="0x%x" permission="rw"\n' % (padding, vfat, address) )
        f.write('%s    description="1=invert pair"\n' % (padding))
        f.write('%s    fw_signal="TU_INVERT (%d downto %d)"\n' % (padding, bithi, bitlo))
        f.write('%s    mask="0x%08X"\n' %(padding, mask))
        f.write('%s    fw_default="0x%02X"/>\n' % (padding, fw_default))

if __name__ == '__main__':
    main()
