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
    def __init__(self,port=PORT_NAME,baudrate=BAUDRATE):
        try:
            self._ser = serial.Serial(
                port=port,
                baudrate=baudrate
            )
            self._ser.write('ECHO OFF\r\n'.encode())
            self.read_serial()
            # Read in values from serial device
            self._ramp_time = self.get_ramp_time(read=True)
            self._output    = self.get_output(read=True)
            self._voltage   = self.get_voltage(read=True)
            self._current   = self.get_current(read=True)
            self._v_sequence = None
        except serial.SerialException:
            print(f'Failed to open serial device: {PORT_NAME}')
            sys.exit()

    @property
    def v_sequence(self):
        return self._v_sequence
    @v_sequence.setter
    def v_sequence(self,v_list):
        self._v_sequence = v_list

    def set_ramp_time(self,ramp:int):
        self._ser.write(f'RAMP {ramp:d}\r\n'.encode())
        self._ramp_time = ramp

    def get_ramp_time(self,read=False):
        if read:
            self._ser.write('RAMP\r\n'.encode())
            ramp = self.read_serial()
            try:
                self._ramp_time = int(ramp.split()[0])
            except TypeError:
                print('ERROR:couldn\'t cast serial output to int')
        return self._ramp_time
        
    def set_voltage(self,voltage):
        self._ser.write(f'VSET {voltage}\r\n'.encode())
        self._voltage = voltage

    def get_voltage(self,read=False):
        if read:
            self._ser.write('VREAD\r\n'.encode())
            self._voltage = self.read_serial()
        return self._voltage

    def set_current(self,current):
        self._ser.write(f'ISET {current}\r\n'.encode())
        self._current = current

    def get_current(self,read=False):
        if read:
            self._ser.write('IREAD\r\n'.encode())
            self._current = self.read_serial()
        return self._current

    def set_output(self,output:bool):
        if output:
            self._ser.write('PWR ON\r\n'.encode())
        else:
            self._ser.write('PWR OFF\r\n'.encode())
        self._output = output

    def get_output(self,read=False):
        if read:
            self._ser.write('PWR\r\n'.encode())
            # Cast to bool
            self._output = POWER[self.read_serial()]
        return self._output

    def read_serial(self):
        out = ''
        time.sleep(1)
        while self._ser.inWaiting() > 0:
            out += self._ser.read(1).decode()
        out = out.removesuffix('\r\n')
        return out

    def power_sequence(self,power:bool):
        # Power on sequence
        if power:
            # Copy voltage sequence to not alter property
            voltages = self.v_sequence.copy()
            # Check if output is OFF and turn on
            if not self.get_output():
                self.set_voltage(0.001)
                self.set_output(ON)
                time.sleep(1)
            for voltage in voltages:
                self.set_voltage(voltage)
                time.sleep((self.get_ramp_time()+100)/1000)
        else:
            self.set_voltage(0.001)
    
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
            except TypeError:
                print('ERROR:Must provide float values for voltage arg.')
                pwr.close()
                sys.exit()
        else:
            try:
                voltage = float(args.voltage[0])
            except TypeError:
                print('ERROR:Must provide float values for voltage arg.')
                pwr.close()
                sys.exit()
        pwr.set_voltage(voltage)
    elif power:
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
