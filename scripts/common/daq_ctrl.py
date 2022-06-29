import sys
import common.utils as utils

# remote
if len(sys.argv) > 1 and "rpyc_classic.py" not in sys.argv[0]:
    hostname = sys.argv[1]
    utils.heading("Connecting to %s" % hostname)
    import rpyc
    conn = rpyc.classic.connect(hostname)
    conn._config["sync_request_timeout"] = 240
    rw = conn.modules["common.rw_reg"]
    befe = conn.modules["common.fw_utils"]

# local
else:
    utils.heading("Running locally")
    import common.rw_reg as rw
    import common.fw_utils as befe

class DaqCtrl:

    config_names = ["INPUT_EN_MASK", "IGNORE_DAQLINK", "WAIT_FOR_RESYNC", "FREEZE_ON_ERROR", "GEN_LOCAL_L1A", "FED_ID", "BOARD_ID", "SPY_PRESCALE", "SPY_SKIP_EMPTY", "USE_TCDS"]
    config = {}
    state = "Initial"
    is_csc = None
    gem_csc = None

    def __init__(self, config={}, verbose=False):
        # check if it's CSC or GEM firmware
        fw_flavor = rw.read_reg("BEFE.SYSTEM.RELEASE.FW_FLAVOR")
        if fw_flavor == 0xdeaddead:
            exit()

        self.gem_csc = fw_flavor.to_string(use_color=False)
        self.is_csc = True if "CSC" in self.gem_csc else False

        if verbose:
            print("%s DAQ configuration:" % self.gem_csc)

        for config_name in self.config_names:
            if config_name in config:
                self.config[config_name] = config[config_name]
            elif utils.config_exists("CONFIG_DAQ_" + config_name):
                self.config[config_name] = utils.get_config("CONFIG_DAQ_" + config_name)
            elif utils.config_exists("CONFIG_" + config_name):
                self.config[config_name] = utils.get_config("CONFIG_" + config_name)
            else:
                raise Exception("ERROR: config %s not found" % config_name)
            if verbose:
                print("    %s = %d" % (config_name, self.config[config_name]))

    def configure(self):
        if "Enabled" in self.state:
            self.stop()

        print("%s DAQ: Configuring..." % self.gem_csc)

        rw.write_reg('BEFE.%s.TTC.CTRL.MODULE_RESET' % self.gem_csc, 0x1)
        rw.write_reg('BEFE.%s.TTC.CTRL.L1A_ENABLE' % self.gem_csc, 0x0)
        if self.is_csc:
            rw.write_reg('BEFE.%s.TEST.GBE_TEST.ENABLE' % self.gem_csc, 0x0)
        rw.write_reg('BEFE.%s.DAQ.CONTROL.DAQ_ENABLE' % self.gem_csc, 0x0)

        if self.config["USE_TCDS"]:
            rw.write_reg('BEFE.%s.TTC.CTRL.CMD_ENABLE' % self.gem_csc, 1)
            rw.write_reg('BEFE.%s.TTC.GENERATOR.ENABLE' % self.gem_csc, 0)
            if self.is_csc:
                rw.write_reg('BEFE.%s.DAQ.CONTROL.L1A_REQUEST_EN' % self.gem_csc, 0)
        else:
            rw.write_reg('BEFE.%s.TTC.CTRL.CMD_ENABLE' % self.gem_csc, 0)
            rw.write_reg('BEFE.%s.TTC.GENERATOR.ENABLE' % self.gem_csc, 1)
            if self.is_csc:
                rw.write_reg('BEFE.%s.DAQ.CONTROL.L1A_REQUEST_EN' % self.gem_csc, 1)

        rw.write_reg('BEFE.SYSTEM.CTRL.BOARD_ID', self.config["BOARD_ID"])
        rw.write_reg('BEFE.%s.DAQ.CONTROL.FED_ID' % self.gem_csc, self.config["FED_ID"])
        rw.write_reg('BEFE.%s.DAQ.CONTROL.INPUT_ENABLE_MASK' % self.gem_csc, self.config["INPUT_EN_MASK"])
        rw.write_reg('BEFE.%s.DAQ.CONTROL.IGNORE_DAQLINK' % self.gem_csc, self.config["IGNORE_DAQLINK"])
        rw.write_reg('BEFE.%s.DAQ.CONTROL.FREEZE_ON_ERROR' % self.gem_csc, self.config["FREEZE_ON_ERROR"])
        rw.write_reg('BEFE.%s.DAQ.CONTROL.RESET_TILL_RESYNC' % self.gem_csc, self.config["WAIT_FOR_RESYNC"])
        if self.is_csc:
            rw.write_reg('BEFE.%s.DAQ.CONTROL.SPY.SPY_SKIP_EMPTY_EVENTS' % self.gem_csc, self.config["SPY_SKIP_EMPTY"])
            rw.write_reg('BEFE.%s.DAQ.CONTROL.L1A_REQUEST_EN' % self.gem_csc, self.config["GEN_LOCAL_L1A"])
        rw.write_reg('BEFE.%s.DAQ.CONTROL.SPY.SPY_PRESCALE' % self.gem_csc, self.config["SPY_PRESCALE"])
        rw.write_reg('BEFE.%s.DAQ.CONTROL.RESET' % self.gem_csc, 0x1)
        rw.write_reg('BEFE.%s.DAQ.LAST_EVENT_FIFO.DISABLE' % self.gem_csc, 0x0)

        self.set_state("Configured")

    def enable(self):
        if "Configured" not in self.state:
            self.configure()

        print("%s DAQ: Enabling..." % self.gem_csc)

        rw.write_reg('BEFE.%s.DAQ.CONTROL.RESET' % self.gem_csc, 0x1)
        rw.write_reg('BEFE.%s.DAQ.CONTROL.DAQ_ENABLE' % self.gem_csc, 0x1)
        rw.write_reg('BEFE.%s.TTC.CTRL.L1A_ENABLE' % self.gem_csc, 0x1)
        rw.write_reg('BEFE.%s.DAQ.CONTROL.RESET' % self.gem_csc, 0x0)

        self.set_state("Enabled")

    def stop(self):
        print("%s DAQ: Stopping..." % self.gem_csc)
        rw.write_reg('BEFE.%s.DAQ.CONTROL.DAQ_ENABLE' % self.gem_csc, 0x0)
        rw.write_reg('BEFE.%s.TTC.CTRL.L1A_ENABLE' % self.gem_csc, 0x0)

        if self.state in ["Enabled", "Configured"]:
            self.set_state("Configured")
        else:
            self.set_state("Halted")

    def halt(self):
        self.state = "Halted"
        self.stop()

    def set_state(self, state):
        self.state = state
        print("%s DAQ State: %s" % (self.gem_csc, self.state))


if __name__ == '__main__':
    rw.parse_xml()
    daq_ctrl = DaqCtrl(verbose=True)
    daq_ctrl.configure()
