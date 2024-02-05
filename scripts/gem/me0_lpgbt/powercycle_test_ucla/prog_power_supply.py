import sys
import time
import serial
import argparse

PORT_NAME = '/dev/ttyACM0'
BAUDRATE  = 115200

ON = True
OFF = False
POWER = {'ON':ON,'OFF':OFF}

class PowerSupply:
    def __init__(self,port,baudrate):
        try:
            self._ser = serial.Serial(
                port=PORT_NAME,
                baudrate=BAUDRATE
            )
            # Read in values from serial device
            self._ramp_time = self.get_ramp_time(read=True)
            self._output    = self.get_output(read=True)
            self._voltage   = self.get_voltage(read=True)
            self._current   = self.get_current(read=True)
            self.v_sequence = None
        except serial.SerialException:
            print(f'Failed to open serial device: {PORT_NAME}')
            sys.exit()

    @property
    def v_sequence(self):
        return self.v_sequence
    @v_sequence.setter
    def v_sequence(self,v_list):
        self.v_sequence = v_list

    def set_ramp_time(self,ramp:int):
        self.ser.write(f'RAMP {ramp:d}\r\n')
        self._ramp_time = ramp

    def get_ramp_time(self,read=False):
        if read:
            self.ser.write('RAMP\r\n')
            return self.read_serial()
        else:
            return self._ramp_time
        
    def set_voltage(self,voltage):
        self.ser.write(f'VSET {voltage}\r\n')
        self._voltage = voltage

    def get_voltage(self,read=False):
        if read:
            self.ser.write('VREAD\r\n')
            return self.read_serial()
        else:
            return self._voltage

    def set_current(self,current):
        self.ser.write(f'ISET {current}\r\n')
        self._current = current

    def get_current(self,read=False):
        if read:
            self.ser.write('IREAD\r\n')
            return self.read_serial()
        else:
            return self._current

    def set_output(self,output:bool):
        if output:
            self.ser.write('PWR ON\r\n')
        else:
            self.ser.write('PWR OFF\r\n')
        self._output = output

    def get_output(self,read=False):
        if read:
            self.ser.write('OUTPUT\r\n')
            # Cast to bool
            return POWER[self.read_serial()]
        else:
            return self._output

    def read_serial(self):
        out = ''
        time.sleep(0.1)
        while self.ser.inWaiting() > 0:
            out += self.ser.read(1)
        return out

    def power_sequence(self,power:bool):
        # Copy voltage sequence to not alter property
        voltages = self.v_sequence.copy()
        # Power on sequence
        if power:
            # Check if output is OFF and turn on
            if self.get_output() == 'OFF':
                if voltages[0]!=0:
                    self.set_voltage(0)
                self.set_output(ON)
            for voltage in voltages:
                self.set_voltage(voltage)
                time.sleep(self._ramp_time/1000)
        else:
            voltages = voltages[::-1]
            if voltages[-1]!=0:
                voltages.append(0)
            for voltage in voltages:
                self.set_voltage(voltage)
                time.sleep(self._ramp_time/1000)
    
    def close(self):
        self._ser.close()

def main():
    # Parsing arguments
    parser = argparse.ArgumentParser(description="Programmable Power Supply")
    parser.add_argument('-i','--current',action='store',dest='current',help='current = Current limit to set power supply to.')
    parser.add_argument('-t','--ramp_time',action='store',dest='ramp_time',help='ramp_time = ramp time in ms to configure power supply.')
    parser.add_argument('-v','--voltage',action='store',nargs='+',dest='voltage',help='voltage = Voltage(s) to set power supply to. If multiple values are given, they will be set sequentially for power on/off. Values are taken to be in ascending order, and will be reversed for power-off sequence.')
    parser.add_argument('-p','--power',action='store',dest='power',help='power = \'ON\' = Run power up sequence, \'OFF\' = Run power down sequence.')
    parser.add_argument('-o','--output',action='store',dest='output',help='output = Toggle OUTPUT \'ON\'/\'OFF\'. Use for debugging or configuring purposes only. Output is set last. Use \'-p\'/\'--power\' for power ON/OFF sequence.')
    args = parser.parse_args()

    pwr = PowerSupply()
    # configure power sequence
    if args.power:
        # Get boolean for power arg
        try:
            power = POWER[args.power.upper()]
        except KeyError:
            print('ERROR:-p/--power valid inputs are \'ON\'/\'OFF\'.')
            pwr.close()
            sys.exit()
        
        # Check power ON or OFF
        if power:
            # Check that output is off before configuring
            if pwr.get_output(read=True):
                pwr.set_output(OFF)
    else:
        power = None

    if args.output:
        # Get boolean for output arg
        try:
            output = POWER[args.output.upper()]
        except KeyError:
            print('ERROR:-o/--output valid inputs are \'ON\'/\'OFF\'.')
            pwr.close()
            sys.exit()
        if power!=None:
            print('Both output and power args used. Ignoring output arg and running power sequence.')
            output = None
    else:
        output = None

    # Set ramp time if supplied
    if args.ramp_time:
        try:
            pwr.set_ramp_time(int(args.ramp_time))
        except TypeError:
            print('ERROR:Must provide integer value for setting ramp time.')

    # Set current limit if supplied
    if args.current:
        try:
            pwr.set_current(float(args.current))
        except TypeError:
            print('ERROR:Must provide float value for setting current limit.')

    # save voltage sequence in PowerSupply attribute
    if (power != None) and args.voltage:
        try:
            voltages = [float(v) for v in args.voltage]
            pwr.v_sequence = voltages
        except TypeError:
            print('ERROR:Must provide float values for voltage sequence.')
    # Set max voltage given if no power arg
    elif args.voltage:
        if len(args.voltage) > 1:
            print('Power sequence arg not used. Setting max voltage value.')
            try:
                voltage = max(map(float,args.voltage))
                pwr.set_voltage(voltage)
            except TypeError:
                print('ERROR:Must provide float values for voltage arg.')
                pwr.close()
                sys.exit()
    elif args.power:
        print('Must provide at least one voltage w/ -v/--voltage for power sequence.')
        pwr.close()
        sys.exit()
    
    # Run power sequence
    if power!=None:
        pwr.power_sequence(power)
    # Or turn ON/OFF output
    elif output!=None:
        pwr.set_output(output)

if __name__ == "__main__":
    main()