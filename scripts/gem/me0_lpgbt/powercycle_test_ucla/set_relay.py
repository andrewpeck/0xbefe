import ethernet_relay
from time import sleep
import sys
import argparse

if __name__ == "__main__":

    # Parsing arguments
    parser = argparse.ArgumentParser(description="Set Relay")
    parser.add_argument("-r", "--relay_number", action="store", dest="relay_number", nargs="+", help="relay_number = Relay Number used")
    parser.add_argument("-s", "--state", action="store", dest="state", help="state = on or off")
    args = parser.parse_args()

    if args.state not in ["on", "off"]:
        print ("State can only be on or off")
        sys.exit()
    state = -9999
    if args.state == "on":
        state = 1
    elif args.state == "off":
        state = 0

    relay_number_list = []
    if args.relay_number is None:
        print (Colors.YELLOW + "Enter Relay Numbers" + Colors.ENDC)
        sys.exit()
    for r in args.relay_number:
        relay_number = int(r)
        if relay_number not in range(0,8):
            print (Colors.YELLOW + "Valid Relay Number: 0-7" + Colors.ENDC)
            sys.exit()
        relay_number_list.append(relay_number)

    if sys.version_info[0] < 3:
        raise Exception("Python version 3.x required")

    relay_object = ethernet_relay.ethernet_relay()
    connect_status = relay_object.connectToDevice()
    if not connect_status:
        print (Colors.RED + "ERROR: Exiting" + Colors.ENDC)
        sys.exit()

    for relay_number in relay_number_list:
        print ("Relay Number: %d"%relay_number)
        set_status = relay_object.relay_set(relay_number, state)
        if not set_status:
            print (Colors.RED + "ERROR: Exiting" + Colors.ENDC)
            sys.exit()
        read_status = relay_object.relay_read(relay_number)
        if not read_status:
            print (Colors.RED + "ERROR: Exiting" + Colors.ENDC)
            sys.exit()










