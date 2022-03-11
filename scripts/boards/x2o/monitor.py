from board.manager import *

m=manager()
m.peripheral.autodetect_optics()
mon = m.peripheral.monitor()
print(mon)
