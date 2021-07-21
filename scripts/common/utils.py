import common.tables.tableformatter as tf
from common.rw_reg import *

# bright colors:
class Colors:
    WHITE   = '\033[97m'
    CYAN    = '\033[96m'
    MAGENTA = '\033[95m'
    BLUE    = '\033[94m'
    YELLOW  = '\033[93m'
    GREEN   = '\033[92m'
    RED     = '\033[91m'
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


FULL_TABLE_GRID_STYLE = tf.FancyGrid()
DEFAULT_TABLE_GRID_STYLE = tf.AlternatingRowGrid()

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

def reg_nice_print(regNode, printIfOk=True):
    val = read_reg(regNode)
    color = None
    if ((regNode.error_min_value is not None) and (val >= regNode.error_min_value)) or ((regNode.error_max_value is not None) and (val <= regNode.error_max_value)) or ((regNode.error_value is not None) and (val == regNode.error_value)):
        color = Colors.RED
    elif ((regNode.warn_min_value is not None) and (val >= regNode.warn_min_value)) or ((regNode.warn_max_value is not None) and (val <= regNode.warn_max_value)) or ((regNode.warn_value is not None) and (val == regNode.warn_value)):
        color = Colors.YELLOW

    s = "%-*s%s" % (90, regNode.name, hex_padded(val, 4, True))
    if color is not None:
        s = color + s + Colors.ENDC

    if color is not None or printIfOk:
        print(s)

def dump_regs(pattern, printIfOk=True, caption=None, captionColor=Colors.CYAN):
    if caption is not None:
        totalWidth = 100
        if len(caption) + 6 > totalWidth:
            totalWidth = len(caption) + 6
        print(captionColor + "=" * totalWidth + Colors.ENDC)
        padding1Size = int(((totalWidth - 2 - len(caption)) / 2))
        padding2Size = padding1Size if padding1Size * 2 + len(caption) == totalWidth - 2 else padding1Size + 1
        print(captionColor + "%s %s %s" % ("=" * padding1Size, caption, "=" * padding2Size) + Colors.ENDC)
        print(captionColor + "=" * totalWidth + Colors.ENDC)

    nodes = get_nodes_containing(pattern)
    for node in nodes:
        if node.permission is not None and 'r' in node.permission:
            reg_nice_print(node, printIfOk)
