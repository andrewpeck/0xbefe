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
    print(color + msg + Colors.ENDC)

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
        return "0x%x" % number

def hex32(number):
    if number is None:
        return 'None'
    else:
        return "0x%08x" % number

def hexPadded64(number):
    if number is None:
        return 'None'
    else:
        return "0x%016x" % number

def hexPadded(number, numBytes, include0x = True):
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

def parseInt(string):
    if string is None:
        return None
    elif string.startswith('0x'):
        return int(string, 16)
    elif string.startswith('0b'):
        return int(string, 2)
    else:
        return int(string)

def regNicePrint(regNode, printIfOk = True):
    val = parseInt(readReg(regNode))
    color = None
    if ((regNode.error_min_value is not None) and (val >= regNode.error_min_value)) or ((regNode.error_max_value is not None) and (val <= regNode.error_max_value)) or ((regNode.error_value is not None) and (val == regNode.error_value)):
        color = Colors.RED
    elif ((regNode.warn_min_value is not None) and (val >= regNode.warn_min_value)) or ((regNode.warn_max_value is not None) and (val <= regNode.warn_max_value)) or ((regNode.warn_value is not None) and (val == regNode.warn_value)):
        color = Colors.YELLOW

    s = "%-*s%s" % (90, regNode.name, hexPadded(val, 4, True))
    if color is not None:
        s = color + s + Colors.ENDC

    if color is not None or printIfOk:
        print(s)

def dumpRegs(pattern, printIfOk = True, caption = None, captionColor = Colors.CYAN):
    if caption is not None:
        totalWidth = 100
        if len(caption) + 6 > totalWidth:
            totalWidth = len(caption) + 6
        print(captionColor + "=" * totalWidth + Colors.ENDC)
        padding1Size = int(((totalWidth-2-len(caption)) / 2))
        padding2Size = padding1Size if padding1Size * 2 + len(caption) == totalWidth - 2 else padding1Size + 1
        print(captionColor + "%s %s %s" % ("=" * padding1Size, caption, "=" * padding2Size) + Colors.ENDC)
        print(captionColor + "=" * totalWidth + Colors.ENDC)

    nodes = getNodesContaining(pattern)
    for node in nodes:
        if node.permission is not None and 'r' in node.permission:
            regNicePrint(node, printIfOk)
