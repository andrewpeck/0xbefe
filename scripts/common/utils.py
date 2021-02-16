class Colors:
    WHITE   = '\033[97m'
    CYAN    = '\033[96m'
    MAGENTA = '\033[95m'
    BLUE    = '\033[94m'
    YELLOW  = '\033[93m'
    GREEN   = '\033[92m'
    RED     = '\033[91m'
    ENDC    = '\033[0m'

def check_bit(byteval,idx):
    return ((byteval&(1<<idx))!=0);

def printColor(msg, color):
    print color, msg, Colors.ENDC

def heading(msg):
    printColor('\n>>>>>>> ' + str(msg).upper() + ' <<<<<<<', Colors.BLUE)

def subheading(msg):
    printColor('---- ' + str(msg) + ' ----', Colors.YELLOW)

def printCyan(msg):
    printColor(msg, Colors.CYAN)

def printRed(msg):
    printColor(msg, Colors.RED)

def printGreen(msg):
    printColor(msg, Colors.GREEN)

def printGreenRed(msg, controlValue, expectedValue):
    col = Colors.GREEN
    if controlValue != expectedValue:
        col = Colors.RED
    printColor(msg, col)

def hex(number):
    if number is None:
        return 'None'
    else:
        return "{0:#0x}".format(number)

def hexPadded64(number):
    if number is None:
        return 'None'
    else:
        return "{0:#0{1}x}".format(number, 18)

def hexPadded(number, numBytes):
    if number is None:
        return 'None'
    else:
        return "{0:#0{1}x}".format(number, int(numBytes * 2) + 2)

def binary(number, length):
    if number is None:
        return 'None'
    else:
        return "{0:#0{1}b}".format(number, length + 2)

def parseInt(string):
    if string is None:
        return None
    elif string.startswith('0x'):
        return int(string, 16)
    elif string.startswith('0b'):
        return int(string, 2)
    else:
        return int(string)
