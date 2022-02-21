import sys
import os

# bright colors:
class Colors:
    WHITE   = '\033[97m'
    CYAN    = '\033[96m'
    MAGENTA = '\033[95m'
    BLUE    = '\033[94m'
    YELLOW  = '\033[93m'
    GREEN   = '\033[92m'
    RED     = '\033[91m'
    ORANGE  = '\033[38;5;208m'
    ENDC    = '\033[39m'

# normal colors:
# class Colors:
#     WHITE   = '\033[37m'
#     CYAN    = '\033[36m'
#     MAGENTA = '\033[35m'
#     BLUE    = '\033[34m'
#     YELLOW  = '\033[33m'
#     GREEN   = '\033[32m'
#     RED     = '\033[31m'
#     ENDC    = '\033[39m'

# check python version (python3 is needed for the tables generators)
if sys.version_info < (3, 6):
    print(Colors.RED + "Please use python 3.6 or higher (you are using python %d.%d)" % (sys.version_info[0], sys.version_info[1]) + Colors.ENDC)
    exit()

if sys.version_info >= (3, 6):
    def raw_input(s):
        return input(s)

import tableformatter as tf
import imp

try:
    imp.find_module('befe_config')
    import befe_config as befe_config
except ImportError:
    print(Colors.RED + "befe_config.py not found" + Colors.ENDC)
    print(Colors.RED + "Please make a copy of the befe_config_example.py and name it befe_config.py, and edit it as needed to reflect the configuration of your setup" + Colors.ENDC)
    print(Colors.RED + "In most cases the example config without modifications will work as a starting point" + Colors.ENDC)
    exit(1)


FULL_TABLE_GRID_STYLE = tf.FancyGrid()
DEFAULT_TABLE_GRID_STYLE = tf.AlternatingRowGrid()

def get_befe_scripts_dir():
    scripts_dir = os.environ.get('BEFE_SCRIPT_DIR')
    return scripts_dir

def get_config(config_name):
    return eval("befe_config." + config_name)

def check_bit(byteval, idx):
    return ((byteval & (1 << idx)) != 0)

def print_color(msg, color):
    print(color + msg + Colors.ENDC)

def color_string(msg, color):
    return color + msg + Colors.ENDC

def heading(msg):
    print_color('\n>>>>>>> ' + str(msg).upper() + ' <<<<<<<', Colors.BLUE)

def subheading(msg):
    print_color('---- ' + str(msg) + ' ----', Colors.YELLOW)

def print_cyan(msg):
    print_color(msg, Colors.CYAN)

def print_red(msg):
    print_color(msg, Colors.RED)

def print_green(msg):
    print_color(msg, Colors.GREEN)

def print_green_red(msg, controlValue, expectedValue):
    col = Colors.GREEN
    if controlValue != expectedValue:
        col = Colors.RED
    print_color(msg, col)

def hex(number):
    if number is None:
        return 'None'
    else:
        return "0x%x" % number

def hex32(number):
    if number is None:
        return 'None'
    else:
        return "0x%08x" % number

def hex_padded64(number):
    if number is None:
        return 'None'
    else:
        return "0x%016x" % number

def hex_padded(number, numBytes, include0x=True):
    if number is None:
        return 'None'
    else:
        length = 2 + numBytes * 2
        formatStr = "{0:#0{1}x}"
        if not include0x:
            length -= 2
            formatStr = "{0:0{1}x}"
        return formatStr.format(number, length)

def binary(number, length):
    if number is None:
        return 'None'
    else:
        return "{0:#0{1}b}".format(number, length + 2)

def parse_int(string):
    if string is None:
        return None
    elif isinstance(string, int):
        return string
    elif string.startswith('0x'):
        return int(string, 16)
    elif string.startswith('0b'):
        return int(string, 2)
    else:
        return int(string)

def array_to_string(arr):
    s = "["
    for i in range(len(arr)):
        if i != 0:
            s += ", "
        s += str(arr[i])
    s += "]"
    return s

def bitmask_to_array(bitmask):
    ids = []
    id = 0
    while bitmask != 0:
        if bitmask & 1 == 1:
            ids.append(id)
        bitmask = bitmask >> 1
        id += 1
    return ids
