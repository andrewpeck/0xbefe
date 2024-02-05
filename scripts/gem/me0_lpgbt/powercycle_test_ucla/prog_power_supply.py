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
        except serial.SerialException:
            print(f'Failed to open serial device: {PORT_NAME}')
            sys.exit()

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

    def power_sequence(self,voltages,power:bool):
        if type(voltages)!= list:
            voltages = [voltages]
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

def main():
    # Parsing arguments
    parser = argparse.ArgumentParser(description="Programmable Power Supply")
    parser.add_argument('-v','--voltage',action='store',nargs='+',dest='voltage',help='voltage = Voltage(s) to set power supply to. If multiple values are given, they will be set sequentially for power on/off.')
    parser.add_argument('-i','--current',action='store',dest='current',help='current = Current limit to set power supply to.')
    parser.add_argument('-t','--ramp_time',action='store',dest='ramp_time',help='ramp_time = ramp time in ms to configure power supply.')
    parser.add_argument('-p','--power',action='store',dest='power',help='power = \'ON\' = Run power up sequence, \'OFF\' = Run power down sequence.')
    parser.add_argument('-o','--output',action='store',dest='output',help='output = Toggle OUTPUT \'ON\'/\'OFF\'. Use for debugging or configuring purposes only. Use \'-p\'/\'--power\' for power ON/OFF sequence.')
    args = parser.parse_args()

    pwr = PowerSupply()
    # set ramp time
    if args.ramp_time:
        try:
            pwr.set_ramp_time(int(args.ramp_time))
        except TypeError:
            print('Must provide an integer value for -t/--ramp_time')
    # Set current limit
    if args.current:
        try:
            pwr.set_current(float(args.current))
        except TypeError:
            print('Must provide a float value for -i/--current')
    # Set voltage if output arg provided
    if args.output:
        try:
            if not POWER[args.output]:
                pwr.set_output(OFF)
            else:
                if len(args.voltages) > 1:
                    voltage = max(map(int,args.voltage))
                    print(f'Only 1 voltage allowed when setting output directly. Will use max voltage of {voltage:f}')
                pwr.set_voltage(voltage)
                pwr.set_output(ON)
        except KeyError:
            print('-o/--output only accepts values of \'ON\'/\OFF\'.')
            sys.exit()


if __name__ == "__main__":
    main()