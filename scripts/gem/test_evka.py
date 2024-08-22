from common.rw_reg import *
from common.utils import *
from common.fw_utils import *
from common.promless import *
from gem.gbt import *
from gem.me0_phase_scan import getConfig
from gem.gem_utils import *
import time
from os import path
import os

LOCK_TIMEOUT = 10

parse_xml()
initGbtRegAddrs()
rdy = 1
was_not_rdy = 0
i = 0
t_lock_max = 0
t_lock_min = 999999
t_lock_accum = 0
while(rdy > 0):
    if (i % 100 == 0 and i > 0):
        print("iter: %d, rdy = %d" % (i, rdy))
        print("qpll lock time: min = %f, max = %f, avg = %f" % (t_lock_min, t_lock_max, (t_lock_accum / i)))
    write_reg("BEFE.MGTS.MGT0.CTRL.QPLL0_RESET", 1) # tx pll
    write_reg("BEFE.MGTS.MGT0.CTRL.QPLL0_RESET", 1) # rx pll
    t0 = time.time()
    tx_qpll_locked = read_reg("BEFE.MGTS.MGT0.STATUS.QPLL0_LOCKED")
    rx_qpll_locked = read_reg("BEFE.MGTS.MGT0.STATUS.QPLL0_LOCKED")
    while ((tx_qpll_locked == 0 or rx_qpll_locked == 0) and time.time() - t0 < LOCK_TIMEOUT):
        sleep(0.01)
        tx_qpll_locked = read_reg("BEFE.MGTS.MGT0.STATUS.QPLL0_LOCKED")
        rx_qpll_locked = read_reg("BEFE.MGTS.MGT0.STATUS.QPLL0_LOCKED")
    t_lock = time.time() - t0
    if (tx_qpll_locked > 0 and rx_qpll_locked > 0):
        if (t_lock > t_lock_max):
            t_lock_max = t_lock
        if (t_lock < t_lock_min):
            t_lock_min = t_lock
        t_lock_accum += t_lock
    #befe_config_links()
    write_reg("BEFE.MGTS.MGT0.CTRL.TX_RESET", 1)
    write_reg("BEFE.MGTS.MGT0.CTRL.RX_RESET", 1)
    sleep(0.01)
    #os.system("python3 init_frontend.py > out.txt")
    
    #selectGbt(1, 6)
    #writeGbtRegAddrs(0x128, 0x05)
    #sleep(2)
    #writeGbtRegAddrs(0x128, 0x00)
    #sleep(2)

    #write_reg("BEFE.MGTS.MGT0.CTRL.RX_LOW_POWER_MODE", 0)
    #write_reg("BEFE.MGTS.MGT0.CTRL.RX_RESET", 1)
    #sleep(0.01)
    #write_reg("BEFE.MGTS.MGT0.CTRL.RX_LOW_POWER_MODE", 1)
    #write_reg("BEFE.MGTS.MGT0.CTRL.RX_RESET", 1)
    #sleep(2)
    
    rdy = read_reg("BEFE.GEM.OH_LINKS.OH0.GBT0_READY")
    i += 1

print("iter: %d" % i)
print("rdy: %s" % rdy)
print("was_not_rdy: %s" % was_not_rdy)
sleep(1)
rdy = read_reg("BEFE.GEM.OH_LINKS.OH1.GBT6_READY")
print("rdy after sleep: %s" % rdy)

