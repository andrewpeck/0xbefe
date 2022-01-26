from rw_reg_lpgbt import *
import sys
import argparse
from time import *
import array
import struct

DEBUG=False

class Colors:            
    WHITE   = "\033[97m"
    CYAN    = "\033[96m"
    MAGENTA = "\033[95m"
    BLUE    = "\033[94m"
    YELLOW  = "\033[93m"
    GREEN   = "\033[92m"
    RED     = "\033[91m"
    ENDC    = "\033[0m"

def main(boss, gpio_selected):

    sound_gpio = 13
    if sound_gpio in gpio_selected:
        print ("Starting LED show and turning speaker on\n")
    else:
        print("Starting LED show")

    brightnessStart = 0
    while True: # cycle brightness from on to off and off to on approx once per second (assuming 100kHz update rate)
        brightnessEnd = 100
        step = 1
        if brightnessStart == 0:
            brightnessStart = 100
            brightnessEnd = -1
            step = -1
        else:
            brightnessStart = 0
            brightnessEnd = 101
            step = 1

        for b in range(brightnessStart, brightnessEnd, step): # one brightness cycle from on to off or off to on (100 steps per cycle)
            for i in range(10): # generate 10 clocks at a specific brightness
                for j in range(100): # generate a PWM waveform for one clock, setting the duty cycle according to the brightness
                    gpio_list = gpio_selected
                    if j >= b:
                        gpio_list = []
                    set_pioout(gpio_list)

        stop = input(Colors.YELLOW + "Please type \"stop\" to stop the show: " + Colors.ENDC)
        if stop=="stop":
            gpio_list = []
            set_pioout(gpio_list)
            print ("\nStopping LED show\n")
            break

def set_pioout(gpio_list):
    value_l = 0
    value_h = 0
    for gpio in gpio_list:
        if gpio in range(0,8):
            value_l |= convert_gpio_reg(gpio)
        elif gpio in range(8,16):
            value_h |= convert_gpio_reg(gpio)

    mpoke(getNode("LPGBT.RWF.PIO.PIOOUTL").address, value_l)
    mpoke(getNode("LPGBT.RWF.PIO.PIOOUTH").address, value_h)

def convert_gpio_reg(gpio):
    reg_data = 0
    if gpio <= 7:
        bit = gpio
    else:
        bit = gpio - 8
    reg_data |= (0x01 << bit)
    return reg_data

def check_bit(byteval,idx):
    return ((byteval&(1<<idx))!=0);

def debug(string):
    if DEBUG:
        print("DEBUG: " + string)

def debugCyan(string):
    if DEBUG:
        printCyan("DEBUG: " + string)

def heading(string):                                                                    
    print (Colors.BLUE)
    print ("\n>>>>>>> "+str(string).upper()+" <<<<<<<")
    print (Colors.ENDC)
                                                      
def subheading(string):                         
    print (Colors.YELLOW)
    print ("---- "+str(string)+" ----",Colors.ENDC)
                                                                     
def printCyan(string):                                                
    print (Colors.CYAN)
    print (string, Colors.ENDC)
                                                                      
def printRed(string):                                                                                                                       
    print (Colors.RED)
    print (string, Colors.ENDC)

def hex(number):
    if number is None:
        return "None"
    else:
        return "{0:#0x}".format(number)

def binary(number, length):
    if number is None:
        return "None"
    else:
        return "{0:#0{1}b}".format(number, length + 2)

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="LpGBT LED Show")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = chc or backend or dongle or dryrun")
    parser.add_argument("-y", "--oh_v", action="store", dest="oh_v", help="oh_v = 1 or 2")
    parser.add_argument("-l", "--lpgbt", action="store", dest="lpgbt", help="lpgbt = boss or sub")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = 0-1 (only needed for backend)")
    parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = 0-7 (only needed for backend)")
    parser.add_argument("-g_l", "--gpio_light", action="store", nargs="+", dest="gpio_light", help="gpio_light = [15 for boss in OHv1] or [5 for boss or {0,1,3,8,13} for sub in OHv2]")
    parser.add_argument("-g_s", "--gpio_sound", action="store", dest="gpio_sound", help="gpio_sound = on, off")
    args = parser.parse_args()

    if args.system == "chc":
        print ("Using Rpi CHeeseCake for LED Show")
    elif args.system == "backend":
        print ("Using Backend for LED Show")
        #print ("Only chc (Rpi Cheesecake) or dryrun supported at the moment")
        #sys.exit()
    elif args.system == "dongle":
        #print ("Using USB Dongle for LED Show"")
        print (Colors.YELLOW + "Only chc (Rpi Cheesecake) or dryrun supported at the moment" + Colors.ENDC)
        sys.exit()
    elif args.system == "dryrun":
        print ("Dry Run - not actually doing the LED Show")
    else:
        print (Colors.YELLOW + "Only valid options: chc, backend, dongle, dryrun" + Colors.ENDC)
        sys.exit()

    boss = None
    gpio_selected = []
    oh_v = 0
    if args.oh_v == "1":
        oh_v = 1
        print("Using OHv1")
        if args.lpgbt is None or args.lpgbt!="boss":
            print (Colors.YELLOW + "Please select boss for OH v1" + Colors.ENDC)
            sys.exit()
        else:
            print ("Configuring LPGBT as boss")
            boss = 1
            if args.gpio_light is None or args.gpio_light[0] == "15":
                print("Enabling led")
                gpio_selected.append(int(args.gpio_light[0]))
            elif args.gpio_light[0] != "15":
                print(Colors.YELLOW + "Only gpio15 connected to led" + Colors.ENDC)
                sys.exit()
            if args.gpio_sound is not None:
                print(Colors.YELLOW + "Sound not supported for OHv1" + Colors.ENDC)
                sys.exit()
    elif args.oh_v == "2":
        print("Using OHv2")
        oh_v = 2
        if args.lpgbt is None:
            print (Colors.YELLOW + "Please select boss or sub for OH v2" + Colors.ENDC)
            sys.exit()
        elif args.lpgbt == "boss":
            print("Configuring LPGBT as boss")
            boss = 1
            if args.gpio_light is None or args.gpio_light[0] == "5":
                print("Enabling gpio5 for led")
                gpio_selected.append(int(args.gpio_light[0]))
            elif args.gpio_light[0] != "5":
                print(Colors.YELLOW + "Only gpio5 connected to led" + Colors.ENDC)
                sys.exit()
            if args.gpio_sound is not None or args.gpio_sound == "off":
                print(Colors.YELLOW + "Sound not supported for master in OHv2" + Colors.ENDC)
                sys.exit()
        elif args.lpgbt == "sub":
            print("Configuring LPGBT as sub")
            boss = 0
            if args.gpio_light is None:
                print(Colors.YELLOW + "Please select any of the following: {0, 1, 3, 8, 13}" + Colors.ENDC)
                sys.exit()
            for gpio_light in args.gpio_light:
                gpio_light = int(gpio_light)
                if gpio_light not in [0, 1, 3, 8, 13]:
                    print(Colors.YELLOW + "Invalid gpio, only allowed {0, 1, 3, 8, 13}" + Colors.ENDC)
                    sys.exit()
                gpio_selected.append(gpio_light)
            print("Enabling led(s)")
            if args.gpio_sound == "off" and 13 in gpio_selected:
                print(Colors.YELLOW + "No can do: gpio 13 enables both the led and the speaker" + Colors.ENDC)
                sys.exit()
            elif args.gpio_sound == "on":
                print("Enabling speaker")
                if 13 not in gpio_selected:
                    gpio_selected.append(13)
    else:
        print(Colors.YELLOW + "Please select either OH v1 or v2" + Colors.ENDC)
        sys.exit()
    if boss is None:
        sys.exit()
        
    if args.system == "backend":
        if args.ohid is None:
            print (Colors.YELLOW + "Need OHID for backend" + Colors.ENDC)
            sys.exit()
        if args.gbtid is None:
            print (Colors.YELLOW + "Need GBTID for backend" + Colors.ENDC)
            sys.exit()
        if int(args.ohid) > 1:
            print(Colors.YELLOW + "Only OHID 0-1 allowed" + Colors.ENDC)
            sys.exit()
        if int(args.gbtid) > 7:
            print(Colors.YELLOW + "Only GBTID 0-7 allowed" + Colors.ENDC)
            sys.exit()
    else:
        if args.ohid is not None or args.gbtid is not None:
            print (Colors.YELLOW + "OHID and GBTID only needed for backend" + Colors.ENDC)
            sys.exit()


    # Parsing Registers XML File
    print("Parsing xml file...")
    parseXML(oh_v)
    print("Parsing complete...")

    # Initialization (for CHeeseCake: reset and config_select)
    rw_initialize(args.system, oh_v, boss, args.ohid, args.gbtid)
    print("Initialization Done\n")
    
    # Readback rom register to make sure communication is OK
    if args.system!="dryrun" and args.system!="backend":
        check_rom_readback()
        check_lpgbt_mode(boss)

    # Check if lpGBT is READY
    if args.system=="backend":
        check_lpgbt_link_ready(args.ohid, args.gbtid)
       
    # LPGBT LED Show
    try:
        main(boss, gpio_selected)
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()

