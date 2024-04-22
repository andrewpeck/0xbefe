import sys
import argparse
import time
from pyHM310T import PowerSupply

ON = True
OFF = False
POWER = {'ON':ON,'OFF':OFF}

def main():
    # Parsing arguments
    parser = argparse.ArgumentParser(description="Programmable Power Supply")
    parser.add_argument('-i','--current',action='store',dest='current',help='current = Current limit to set power supply to.')
    parser.add_argument('-v','--voltage',action='store',dest='voltage',help='voltage = Voltage(s) to set power supply to. If multiple values are given, they will be set sequentially for power on/off. Values are taken to be in ascending order, and will be reversed for power-off sequence.')
    parser.add_argument('-p','--power',action='store',dest='power',help='power = \'ON\' = Run power up sequence, \'OFF\' = Run power down sequence.')
    parser.add_argument('-r','--read',action='store_true',dest='read',help='read = Read and print power supply output at the end of operations.')
    args = parser.parse_args()

    print('\nConfiguring power supply\n')
    # Create instance with default parameters
    # COM port, baudrate = 9600, slave=1, voltage_limit=30.0, current_limit=10.0):
    power_supply = PowerSupply(port='/dev/ttyUSB0')
    # Alternatively, create instance with custom parameters
    # power_supply = PowerSupply('COM4', 115200, 2, 10.0, 5.0)

    # configure power sequence
    if args.power:
        # Get boolean for power arg
        try:
            power = POWER[args.power.upper()]
        except KeyError:
            print('ERROR:-p/--power valid inputs are \'ON\'/\'OFF\'.')
            sys.exit()
    else:
        power = None

    # Set current limit if supplied
    if args.current:
        try:
            power_supply.set_current(float(args.current))
            # Get the set current
            set_current = power_supply.get_current()
            print(f"Successfully set current: {set_current}A")
        except TypeError:
            print('ERROR:Must provide float value for setting current limit.')
            sys.exit()

    # Set output voltage if supplied
    if args.voltage:
        try:
            power_supply.set_voltage(float(args.voltage))
            set_voltage = power_supply.get_voltage()
            print(f"Successfully set voltage: {set_voltage}V")
        except TypeError:
            print('ERROR:Must provide float value for setting output voltage.')
            sys.exit()
    
    print('Config Done\n')

    # Run power sequence
    if power!=None:
        if power:
            # Enable the output
            power_supply.enable_output()
            time.sleep(1)
            # Check if output is enabled
            if power_supply.is_output_enabled():
                print("Output is enabled")
        else:
            #disable power output
            power_supply.disable_output()
            time.sleep(1)
            # Check if output is disabled
            if not(power_supply.is_output_enabled()):
                print("Output is disabled")

    if args.read:
        print(f"Set voltage: {power_supply.get_voltage()}V")
        print(f"Set current: {power_supply.get_current()}A")
        print(f"Voltage display: {power_supply.get_voltage_display()}V")
        print(f"Current display: {power_supply.get_current_display()}A")
        print(f"Power display: {power_supply.get_power_display()}W")
        print(f"Communication address: {power_supply.get_comm_address()}")
        print(f"OVP status: {power_supply.get_ovp()}")
        print(f"OCP status: {power_supply.get_ocp()}")
        print(f"OPP status: {power_supply.get_opp()}")
        print(f"Protection status: {power_supply.get_protection_status()}")
        if power_supply.is_output_enabled():
            print("Output is enabled")
        else:
            print("Output is disabled")


if __name__ == "__main__":
    main()
