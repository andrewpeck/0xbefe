from gem.me0_lpgbt.rw_reg_lpgbt import *
import sys
import argparse
from time import *
import array
import struct

def main(boss, oh_ver, gpio_light, gpio_sound, operation):

    piodirl = getNode("LPGBT.RWF.PIO.PIODIRL").address
    piodirh = getNode("LPGBT.RWF.PIO.PIODIRH").address
    piooutl = getNode("LPGBT.RWF.PIO.PIOOUTL").address
    pioouth = getNode("LPGBT.RWF.PIO.PIOOUTH").address
    piodirl_initial = mpeek(piodirl)
    piodirh_initial = mpeek(piodirh)
    piooutl_initial = mpeek(piooutl)
    pioouth_initial = mpeek(pioouth)

    piodirl_val = piodirl_initial
    piodirh_val = piodirh_initial
    piooutl_val = piooutl_initial
    pioouth_val = pioouth_initial
    for g in gpio_light:
        if g in range(0,8):
            piodirl_val |= convert_gpio_reg(g)
        elif g in range(8,16):
            piodirh_val |= convert_gpio_reg(g)
    if gpio_sound is not None:
        piodirh_val |= convert_gpio_reg(gpio_sound)
    mpoke(piodirl, piodirl_val)
    mpoke(piodirh, piodirh_val)

    if operation == "on":
        print ("Operation ON")
        for g in gpio_light:
            if g in range(0,8):
                if boss:
                    piooutl_val |= convert_gpio_reg(g)
                else:
                    piooutl_val &= ~convert_gpio_reg(g)
            elif g in range(8,16):
                if boss:
                    pioouth_val |= convert_gpio_reg(g)
                else:
                    pioouth_val &= ~convert_gpio_reg(g)
        mpoke(piooutl, piooutl_val)
        mpoke(pioouth, pioouth_val)

        stop = input(Colors.YELLOW + "Do you want to stop the show (y/n): " + Colors.ENDC)
        if stop=="y":
            print ("\nStopping LED show\n")

    elif operation == "off":
        print ("Operation OFF")
        for g in gpio_light:
            if g in range(0,8):
                if boss:
                    piooutl_val &= ~convert_gpio_reg(g)
                else:
                    piooutl_val |= convert_gpio_reg(g)
            elif g in range(8,16):
                if boss:
                    pioouth_val &= ~convert_gpio_reg(g)
                else:
                    pioouth_val |= convert_gpio_reg(g)
        mpoke(piooutl, piooutl_val)
        mpoke(pioouth, pioouth_val)

        stop = input(Colors.YELLOW + "Do you want to stop the show (y/n): " + Colors.ENDC)
        if stop=="y":
            print ("\nStopping LED show\n")

    elif operation == "show":
        print ("Operation SHOW")
        brightnessStart = 0
        t0 = time()
        time_passed = t0
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
                    piooutl_val = piooutl_initial
                    pioouth_val = pioouth_initial
                    for j in range(100): # generate a PWM waveform for one clock, setting the duty cycle according to the brightness
                        for g in gpio_light:
                            if j >= b:
                                if g in range(0,8):
                                    if boss:
                                        piooutl_val &= ~convert_gpio_reg(g)
                                    else:
                                        piooutl_val |= convert_gpio_reg(g)
                                elif g in range(8,16):
                                    if boss:
                                        pioouth_val &= ~convert_gpio_reg(g)
                                    else:
                                        pioouth_val |= convert_gpio_reg(g)
                            else:
                                if g in range(0,8):
                                    if boss:
                                        piooutl_val |= convert_gpio_reg(g)
                                    else:
                                        piooutl_val &= ~convert_gpio_reg(g)
                                elif g in range(8,16):
                                    if boss:
                                        pioouth_val |= convert_gpio_reg(g)
                                    else:
                                        pioouth_val &= ~convert_gpio_reg(g)
                        if gpio_sound is not None:
                            if j >= b:
                                pioouth_val |= convert_gpio_reg(gpio_sound)
                            else:
                                pioouth_val &= ~convert_gpio_reg(gpio_sound)
                        mpoke(piooutl, piooutl_val)
                        mpoke(pioouth, pioouth_val)

            if (time() - time_passed)>10:
                stop = input(Colors.YELLOW + "Do you want to stop the show (y/n): " + Colors.ENDC)
                if stop=="y":
                    print ("\nStopping LED show\n")
                    break
                time_passed = time()

    mpoke(piodirl, piodirl_initial)
    mpoke(piodirh, piodirh_initial)
    mpoke(piooutl, piooutl_initial)
    mpoke(pioouth, pioouth_initial)

def convert_gpio_reg(gpio):
    reg_data = 0
    if gpio <= 7:
        bit = gpio
    else:
        bit = gpio - 8
    reg_data |= (0x01 << bit)
    return reg_data


if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="LpGBT LED Show")
    parser.add_argument("-s", "--system", action="store", dest="system", help="system = chc or backend or dryrun")
    parser.add_argument("-q", "--gem", action="store", dest="gem", help="gem = ME0 only")
    parser.add_argument("-o", "--ohid", action="store", dest="ohid", help="ohid = OH number")
    parser.add_argument("-g", "--gbtid", action="store", dest="gbtid", help="gbtid = GBT number")
    parser.add_argument("-g_l", "--gpio_light", action="store", nargs="+", dest="gpio_light", help="gpio_light = [15 for boss in OHv1] or [5 for boss or {0,1,3,8} for sub in OHv2]")
    parser.add_argument("-g_s", "--gpio_sound", action="store", dest="gpio_sound", help="gpio_sound = 13 for sub in OHv2")
    parser.add_argument("-p", "--op", action="store", dest="op", help="op = on, off, show")
    args = parser.parse_args()

    if args.system == "chc":
        print ("Using Rpi CHeeseCake for LED Show")
    elif args.system == "backend":
        print ("Using Backend for LED Show")
    elif args.system == "dryrun":
        print ("Dry Run - not actually doing LED Show")
    else:
        print (Colors.YELLOW + "Only valid options: chc, backend, dryrun" + Colors.ENDC)
        sys.exit()

    if args.gem != "ME0":
        print(Colors.YELLOW + "Valid gem station: ME0" + Colors.ENDC)
        sys.exit()

    if args.ohid is None:
        print(Colors.YELLOW + "Need OHID" + Colors.ENDC)
        sys.exit()
    #if int(args.ohid) > 1:
    #    print(Colors.YELLOW + "Only OHID 0-1 allowed" + Colors.ENDC)
    #    sys.exit()

    if args.gbtid is None:
        print(Colors.YELLOW + "Need GBTID" + Colors.ENDC)
        sys.exit()
    if int(args.gbtid) > 7:
        print(Colors.YELLOW + "Only GBTID 0-7 allowed" + Colors.ENDC)
        sys.exit()

    oh_ver = get_oh_ver(args.ohid, args.gbtid)
    boss = None
    if int(args.gbtid)%2 == 0:
        boss = 1
    else:
        boss = 0

    if args.op not in ["on", "off", "show"]:
        print (Colors.YELLOW + "Only operations allowed are on, off and show" + Colors.ENDC)
        sys.exit()

    gpio_light = []
    gpio_sound = None
    if oh_ver == 1:
        print("Using OHv1")
        if boss:
            if args.gpio_light is None:
                print(Colors.YELLOW + "Select a LED GPIO for OHv1: 15" + Colors.ENDC)
                sys.exit()
            elif len(args.gpio_light)>1 or args.gpio_light[0]!="15":
                print(Colors.YELLOW + "Only GPIO15 connected to LED for OHv1" + Colors.ENDC)
                sys.exit()
            elif args.gpio_light[0]=="15":
                print("LED: GPIO 15 - Operation: %s"%args.op)
                gpio_light.append(int(args.gpio_light[0]))
            if args.gpio_sound is not None:
                print(Colors.YELLOW + "Sound not supported for OHv1" + Colors.ENDC)
                sys.exit()
        else:
            print (Colors.YELLOW + "Please select boss for OH v1" + Colors.ENDC)
            sys.exit()
    elif oh_ver == 2:
        print("Using OHv2")
        if boss:
            print("Boss lpGBT")
            if args.gpio_light is None:
                print(Colors.YELLOW + "Select a LED GPIO for OHv2: 5" + Colors.ENDC)
                sys.exit()
            elif len(args.gpio_light)>1 or args.gpio_light[0]!="5":
                print(Colors.YELLOW + "Only GPIO5 connected to LED for boss lpGBT in OHv2" + Colors.ENDC)
                sys.exit()
            elif args.gpio_light[0]=="5":
                print("LED: GPIO 5 - Operation: %s"%args.op)
                gpio_light.append(int(args.gpio_light[0]))
            if args.gpio_sound is not None:
                print(Colors.YELLOW + "Sound not supported for boss lpGBT in OHv2" + Colors.ENDC)
                sys.exit()
        else:
            if args.gpio_light is not None and args.gpio_sound is not None:
                print(Colors.YELLOW + "Select either LED GPIOs (0, 1, 3, 8) or sound GPIO (13) for OHv2, not both" + Colors.ENDC)
                sys.exit()
            if args.gpio_light is None and args.gpio_sound is None:
                print(Colors.YELLOW + "Select either of LED GPIOs (0, 1, 3, 8) or sound GPIO (13) for OHv2" + Colors.ENDC)
                sys.exit()
            if args.gpio_light is not None:
                for g in args.gpio_light:
                    if int(g) not in [0, 1, 3, 8]:
                        print(Colors.YELLOW + "Only GPIOs 0, 1, 3 and 8 connected to LED for sub lpGBT in OHv2" + Colors.ENDC)
                        sys.exit()
                    print("LED: GPIO %s - Operation: %s"%(g, args.op))
                    gpio_light.append(int(g))
            if args.gpio_sound is not None:
                if int(args.gpio_sound) != 13:
                    print(Colors.YELLOW + "Only GPIO 13 connected to Speaker for sub lpGBT in OHv2" + Colors.ENDC)
                    sys.exit()
                print("Speaker: GPIO 13 - Operation: %s"%args.op)
                gpio_sound = int(args.gpio_sound)

    if args.gpio_sound is not None:
        gpio_sound = int(args.gpio_sound)

    # Initialization
    rw_initialize(args.gem, args.system, oh_ver, boss, args.ohid, args.gbtid)
    print("Initialization Done\n")

    # Readback rom register to make sure communication is OK
    if args.system != "dryrun":
        check_rom_readback(args.ohid, args.gbtid)
        check_lpgbt_mode(boss, args.ohid, args.gbtid)

    # Check if GBT is READY
    if oh_ver == 1 and args.system == "backend":
        check_lpgbt_ready(args.ohid, args.gbtid)
       
    # LPGBT LED Show
    try:
        main(boss, oh_ver, gpio_light, gpio_sound, args.op)
    except KeyboardInterrupt:
        print (Colors.RED + "Keyboard Interrupt encountered" + Colors.ENDC)
        rw_terminate()
    except EOFError:
        print (Colors.RED + "\nEOF Error" + Colors.ENDC)
        rw_terminate()

    # Termination
    rw_terminate()

