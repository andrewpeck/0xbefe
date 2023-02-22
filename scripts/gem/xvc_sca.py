#!/usr/bin/env python3

from common.rw_reg import *
import socketserver
from math import ceil
import argparse
import importlib
import socket
from time import sleep

class xvc_sca_server(socketserver.BaseRequestHandler):

    def handle(self):
        global opts
        global has_client_connected
        global jtag

        if(has_client_connected):
            return
        has_client_connected = True

        while(True):

            try:
                data = self.request.recv(10)
            except ConnectionResetError:
                print('Connection reset by peer')
                break

            if len(data) == 0:
                print("Empty data received")
                break

            try:
                [cmd, params] = data.split(b':')
            except ValueError:
                print('Invalid data received: data = %s' % data)
                # self.finish()
                break

            max_bits = 16
            if cmd == b'getinfo':
                # resp = b'xvcServer_v1.0:' + max_bits.to_bytes(1, 'little') + b'\n'
                resp = b'xvcServer_v1.0:%d\n' % max_bits
                self.request.sendall(resp)
                print("Responded to getinfo command with max bits = %d (full response = %s)" % (max_bits, resp))
            elif cmd == b'settck':
                # read one more byte
                params += self.request.recv(1)
                print("Received settck command, full data:: %s" % data)
                period = int.from_bytes(params, 'little')
                freq_req = 1000 / period
                period_actual = 100
                freq_actual = 1000 / period_actual
                print("Received a settck command with a request to set the frequency to %dMHz, returning actual period = %dns (%dMHz)" % (freq_req, period_actual, freq_actual))
                self.request.sendall(period_actual.to_bytes(4, 'little'))
            elif cmd == b'shift':
                print("Received shift command, full data: %s" % data)
                len_bits = int.from_bytes(params[0:4], "little")
                if len_bits > max_bits:
                    print("ERROR: a request to shift %d bits, while our max is %d bits.. exiting..." % (len_bits, max_bits))
                    self.finish()
                    exit()
                len_bytes = ceil(len_bits / 8)
                params += self.request.recv(2 * len_bytes) # Read the TMS and TDI data bytes
                print("Data bytes read, the full data now is: %s" % params)
                tms = int.from_bytes(params[4:4+len_bytes], 'little')
                tdo = int.from_bytes(params[4+len_bytes:4+2*len_bytes], 'little')
                print("   *** Shift command for %d bits, tms = %s, tdi = %s" % (len_bits, hex(tms), hex(tdo)))
                tdi = jtag.shift(tms, tdo, len_bits)
                print("   *** Received TDO from OH: %s" % hex(tdi))
                self.request.sendall(tdi.to_bytes(len_bytes, 'little'))
            else:
                print('Unknown command: {} or bad format "{}"'.format(cmd, data))
                break


        # Allow a new client to connect
        has_client_connected = False

class jtag_sca:

    addr_jtag_length = 0
    addr_jtag_tms = 0
    addr_jtag_tdo = 0
    addr_jtag_tdi = 0

    oh = 0

    verbose = 0

    def __init__(self):
        parse_xml()

    def setVerbosity(self, verbosity):
        self.verbose = verbosity

    def setOh(self, oh):
        self.init_fw()
        self.initJtagRegAddrs(oh)
        self.oh = oh
        ohMask = 1 << oh
        self.enableJtag(ohMask, 2)
        if not self.checkStatus(oh):
            print("ERROR: OH SCA is not ready")
            exit()

    def init_fw(self):
        # pass
        # write_reg(get_node('BEFE.GEM.GEM_SYSTEM.CTRL.GLOBAL_RESET'), 1)
        # sleep(0.1)
        write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.CTRL.MODULE_RESET'), 1)
        sleep(0.1)

    def initJtagRegAddrs(self, oh):
        self.addr_jtag_length = get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.NUM_BITS').address
        self.addr_jtag_tms = get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TMS').address
        self.addr_jtag_tdo = get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TDO').address
        self.addr_jtag_tdi = get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TDI_OH%d' % oh).address

    # freqDiv -- JTAG frequency expressed as a divider of 20MHz, so e.g. a value of 2 would give 10MHz, value of 10 would give 2MHz
    def enableJtag(self, ohMask, freqDiv=None):
        print('Enable JTAG module with mask ' + hex(ohMask))
        write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.CTRL.ENABLE_MASK'), ohMask)
        write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.CTRL.SHIFT_MSB'), 0x0)
        write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.CTRL.EXPERT.EXEC_ON_EVERY_TDO'), 0x0)
        write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.CTRL.EXPERT.NO_SCA_LENGTH_UPDATE'), 0x0)
        write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.CTRL.EXPERT.SHIFT_TDO_ASYNC'), 0x0)

        if freqDiv is not None:
            print('Setting JTAG CLK frequency to ' + str(20 / (freqDiv)) + 'MHz (divider value = ' + hex((freqDiv - 1) << 24) + ')')
            ohList = []
            for i in range(0,12):
                if check_bit(ohMask, i):
                    ohList.append(i)
            self.sendScaCommand(ohList, 0x13, 0x90, 0x4, (freqDiv - 1) << 24, False)

    def sendScaCommand(self, ohList, sca_channel, sca_command, data_length, data, doRead):
        #print('fake send: channel ' + hex(sca_channel) + ', command ' + hex(sca_command) + ', length ' + hex(data_length) + ', data ' + hex(data) + ', doRead ' + str(doRead))
        #return

        d = data

        write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD.SCA_CMD_CHANNEL'), sca_channel)
        write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD.SCA_CMD_COMMAND'), sca_command)
        write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD.SCA_CMD_LENGTH'), data_length)
        write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD.SCA_CMD_DATA'), d)
        write_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_CMD.SCA_CMD_EXECUTE'), 0x1)
        reply = []
        if doRead:
            for i in ohList:
                reply.append(read_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.MANUAL_CONTROL.SCA_REPLY_OH%d.SCA_RPY_DATA' % i)))
        return reply

    def checkStatus(self, oh):
        rxReady       = read_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.STATUS.READY'))
        criticalError = read_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.STATUS.CRITICAL_ERROR'))

        if not check_bit(rxReady, oh):
            print("OH #%d is not ready: RX ready = %d, critical error = %d" % (oh, (rxReady >> oh) & 0x1, (criticalError >> oh) & 0x1))
            return False

        return True

    def shift(self, tms, tdo, num_bits):
        fw_len = num_bits if num_bits < 128 else 0 # in firmware 0 means 128 bits
        print("Setting length = %d" % fw_len)
        wReg(self.addr_jtag_length, fw_len)

        len_words = ceil(num_bits / 32)
        tdi = 0
        for i in range(len_words):
            wReg(self.addr_jtag_tms, tms & 0xffffffff)
            wReg(self.addr_jtag_tdo, tdo & 0xffffffff)
            tdi_word = read_reg(get_node('BEFE.GEM.SLOW_CONTROL.SCA.JTAG.TDI_OH%d' % self.oh)) # TODO: use rReg
            print("TDI word: %s" % hex(tdi_word))
            tdi |= tdi_word << (i * 32)
            tms = tms >> 32
            tdo = tdo >> 32

        tdi = tdi & (0xffffffffffffffffffffffffffffffff >> (128  - num_bits))

        return tdi

def check_bit(byteval,idx):
    return ((byteval&(1<<idx))!=0);

def hex(number):
    if number is None:
        return 'None'
    else:
        return "{0:#0x}".format(number)

if(__name__ == '__main__'):

    parser = argparse.ArgumentParser()
    parser.add_argument('--port', default=2542, type=int)
    parser.add_argument('--oh', default=0, type=int)
    parser.add_argument('--verbose', '-v', action='count', default=0, help='Increase verbosity level')

    global opts
    opts = parser.parse_args()

    # Single client for now, deny other requests
    global has_client_connected
    has_client_connected = False

    global jtag
    jtag = jtag_sca()
    jtag.setOh(opts.oh)
    jtag.setVerbosity(opts.verbose)

    hostname = socket.gethostname()
    print("=========== Starting an XVC server for OH%d on %s:%d ===========" % (opts.oh, hostname, opts.port))
    server = socketserver.TCPServer((hostname, opts.port), xvc_sca_server)
    server.serve_forever()
