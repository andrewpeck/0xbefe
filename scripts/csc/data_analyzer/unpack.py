#!/usr/bin/env python

import argparse

from common.utils import *
import signal
import sys
import os
import fnmatch
import struct
import zlib
import math
from enum import Enum

IS_LDAQ = True
IGNORE_DAQLINK = True
VERBOSE = False
DEBUG = False
IGNORE_DMB_FED_L1A_MISMATCH = False
IGNORE_FED_BX_ID = True
IGNORE_ALCT_BX_ID = True
CFEB_NUM_TIMESAMPLES = 8

class InfoType:
    ERROR = 1
    WARNING = 2
    INFO = 3
    DEBUG = 4
    ANNOTATION = 5

class EventInfo:
    type = None
    name = None
    description = None
    word_idx = None
    top_bit_idx = None
    bot_bit_idx = None

    def __init__(self, type, name, word_idx, top_bit_idx, bot_bit_idx, description=None, value=None, err_expr=None, warn_expr=None):
        self.type = type
        self.name = name
        self.word_idx = word_idx
        self.top_bit_idx = top_bit_idx
        self.bot_bit_idx = bot_bit_idx
        self.description = description
        self.value = value
        self.err_expr = err_expr
        self.warn_expr = warn_expr

        if self.warn_expr is not None:
            if eval(self.warn_expr):
                self.type = InfoType.WARNING

        if self.err_expr is not None:
            if eval(self.err_expr):
                self.type = InfoType.ERROR

    def __str__(self):
        if self.type == InfoType.ANNOTATION:
            return Colors.CYAN + "<<< " + self.name + Colors.ENDC

        ret = ""
        # determine color
        col = None
        if self.type == InfoType.ERROR:
            col = Colors.RED
        elif self.type == InfoType.WARNING:
            col = Colors.ORANGE
        elif self.err_expr is not None or self.warn_expr is not None: # color green if we do have a definition of error or warning and they did not trigger
            col = Colors.GREEN

        if col is not None:
            ret += col

        # if we don't have a value, just print name: description (normally used for explicitly defined errors and warning)
        if self.value is None:
            ret += self.name
            if self.description is not None and self.description != "":
                ret += ": " + self.description
        # if we do have a value, print description: value if description is available, and name: value if name is available
        else:
            if self.description is not None and self.description != "":
                ret += "%s: %d" % (self.description, self.value)
            else:
                ret += "%s: %d" % (self.name, self.value)

        if col is not None:
            ret += Colors.ENDC

        return ret

class EventFragment:

    info = None
    info_values = None
    children = None
    info_values = None
    start_idx = None
    end_idx = None
    evt_id = None
    verbose = None

    def __init__(self, words, start_idx, end_idx, evt_id, verbose):
        self.info = []
        self.children = []
        self.info_values = {}
        self.words = words
        self.start_idx = start_idx
        self.end_idx = end_idx
        self.evt_id = evt_id
        self.verbose = verbose

    def print_errors(self, include_warnings=True):
        errors = []
        for inf in self.info:
            if inf.type == InfoType.ERROR:
                errors.append(inf)
        warnings = []
        if include_warnings:
            for inf in self.info:
                if inf.type == InfoType.WARNING:
                    warnings.append(inf)

        if len(errors) > 0:
            print_red("--------------------------------------")
            print_red("%s ERRORS" % self.get_name())
            print_red("--------------------------------------")
            for err in errors:
                print(str(err))
        if include_warnings and len(warnings) > 0:
            print_orange("--------------------------------------")
            print_orange("%s WARNINGS" % self.get_name())
            print_orange("--------------------------------------")
            for warn in warnings:
                print(str(warn))

        for child in self.children:
            child.print_errors(include_warnings)

    def add_error(self, name, word_idx, top_bit_idx, bot_bit_idx, description=None, print_word=True):
        info = EventInfo(InfoType.ERROR, name, word_idx, top_bit_idx, bot_bit_idx, description)
        self.info.append(info)
        if self.verbose:
            if print_word:
                print("%s: %s" % (hex_padded(self.words[word_idx], 8), info))
            else:
                print(info)

    def add_warning(self, name, word_idx, top_bit_idx, bot_bit_idx, description=None, print_word=True):
        info = EventInfo(InfoType.WARNING, name, word_idx, top_bit_idx, bot_bit_idx, description)
        self.info.append(info)
        if self.verbose:
            if print_word:
                print("%s: %s" % (hex_padded(self.words[word_idx], 8), info))
            else:
                print(info)

    def add_info(self, name, word_idx, top_bit_idx, bot_bit_idx, description=None, value=None, err_expr=None, warn_expr=None, is_debug=False, extract_value=True, print_word=False, verbose=None):
        if extract_value and value is None:
            value = get_bits(self.words[word_idx], top_bit_idx, bot_bit_idx)
        type = InfoType.INFO if not is_debug else InfoType.DEBUG
        info = EventInfo(type, name, word_idx, top_bit_idx, bot_bit_idx, value=value, err_expr=err_expr, warn_expr=warn_expr)
        if value is not None:
            self.info_values[name] = value
        self.info.append(info)
        if self.verbose and (verbose is None or verbose) and (info.type != InfoType.DEBUG or DEBUG):
            if print_word:
                print("%s: %s" % (hex_padded(self.words[word_idx], 8), info))
            else:
                print(info)

    def add_debug(self, name, word_idx, top_bit_idx, bot_bit_idx, description=None, value=None, err_expr=None, warn_expr=None, extract_value=True, print_word=False, verbose=None):
        self.add_info(name, word_idx, top_bit_idx, bot_bit_idx, description=description, value=value, err_expr=err_expr, warn_expr=warn_expr, is_debug=True, extract_value=extract_value, print_word=print_word, verbose=verbose)

    def add_annotation(self, text, word_idx):
        self.info.append(EventInfo(InfoType.ANNOTATION, text, word_idx, None, None))

    def has_errors(self):
        if any(x.type == InfoType.ERROR for x in self.info):
            return True

        for child in self.children:
            if child.has_errors():
                return True

        return False

    def has_warnings(self):
        if any(x.type == InfoType.WARNING for x in self.info):
            return True

        for child in self.children:
            if child.has_warnings():
                return True

        return False

    def get_info_val(self, name):
        if name in self.info_values:
            return self.info_values[name]
        else:
            return None

    def get_info_on_word(self, word_idx):
        ret = []
        for info in self.info:
            if info.word_idx == word_idx:
                ret.append(info)
        return ret

    def get_all_event_info(self):
        ret = self.info
        for child in self.children:
            ret = ret + child.get_all_event_info()

        return ret

    def get_name(self):
        return "UNDEFINED NAME"

    def print_event(self):
        print_cyan("**********************************************************************")
        print_cyan("Event #%d" % self.evt_id)

        info = self.get_all_event_info()

        # make a word index to info elements map
        word_to_info = {}
        for inf in info:
            word_idx = inf.word_idx
            if word_idx not in word_to_info:
                word_to_info[word_idx] = [inf]
            else:
                word_to_info[word_idx].append(inf)

        for idx in range(len(self.words)):
            word = self.words[idx]
            line = "%d: %04x %04x %04x %04x" % (idx, (word >> 48), (word >> 32) & 0xffff, (word >> 16) & 0xffff, word & 0xffff)
            if idx in word_to_info:
                for inf in word_to_info[idx]:
                    line += " %s" % inf
            print(line)
        print_cyan("**********************************************************************")

        self.print_errors(include_warnings=True)

    def has_alct(self):
        if isinstance(self, Alct):
            return True
        for child in self.children:
            if child.has_alct():
                return True
        return False

    def has_tmb(self):
        if isinstance(self, Tmb):
            return True
        for child in self.children:
            if child.has_tmb():
                return True
        return False

    def has_cfeb(self):
        if isinstance(self, Cfeb):
            return True
        for child in self.children:
            if child.has_cfeb():
                return True
        return False

class Fed(EventFragment):

    # data
    dmbs = None

    def __init__(self, words, start_idx, end_idx, evt_id, verbose):
        super().__init__(words, start_idx, end_idx, evt_id, verbose)
        self.dmbs = []

    def get_name(self):
        return "FED %d" % self.get_info_val("BOARD_ID")

    def unpack(self):
        idx = self.unpack_header(self.start_idx)
        idx = self.unpack_dmbs(idx)
        idx = self.unpack_trailer(idx)

    def unpack_dmbs(self, idx):
        if self.verbose:
            print("DMB unpacking: starts at idx = %d" % idx)

        fed_trailer = False
        dmb_header_found = False
        dmb_header_idx = None
        dmb_trailer_idx = None
        while not fed_trailer:
            fed_trailer = self.words[idx] == 0x8000ffff80008000
            # dmb_header = (self.words[idx] & 0xf000) == 0x9000
            # dmb_trailer = (self.words[idx] & 0xf000) == 0xe000
            dmb_header = (self.words[idx] >> 60) == 0x9
            dmb_trailer = (self.words[idx] >> 60) == 0xe

            if not dmb_header_found and not dmb_header and not fed_trailer:
                self.add_error("EXTRA_DATA", idx, 63, 0, "Unexpected data between DMB/FED headers trailers")

            if dmb_header_found and (dmb_header or fed_trailer):
                self.add_error("DMB_TRAILER_MISSING", idx, 63, 0, "Found another DMB header before the trailer of the previous DMB event")

            if dmb_header:
                dmb_header_found = True
                dmb_header_idx = idx
                if self.verbose:
                    print("DMB unpacking: found header at idx %d: %s" % (idx, hex_padded(self.words[idx], 8)))

            if dmb_trailer or fed_trailer:
                if self.verbose:
                    print("DMB unpacking: found trailer at idx %d: %s" % (idx, hex_padded(self.words[idx], 8)))
                dmb_trailer_idx = idx
                if dmb_header_found:
                    dmb = Dmb(self, self.words, dmb_header_idx, dmb_trailer_idx, self.evt_id, self.verbose)
                    dmb.unpack()
                    self.dmbs.append(dmb)
                dmb_header_found = False

            idx += 1

        self.children = self.dmbs

        idx -= 1 # come back to the fed trailer position

        if self.verbose:
            print("DMB unpacking: ends at idx = %d" % idx)

        return idx

    def unpack_header(self, idx):

        if self.verbose:
            print_cyan("Event %d" % self.evt_id)
            print_cyan("--------------------------------------")
            print_cyan("FED Header")
            print_cyan("--------------------------------------")


        header_1_idx = idx
        header_2_idx = idx + 1
        header_3_idx = idx + 2
        idx += 3

        self.add_annotation("FED HEADER 1", header_1_idx)
        self.add_annotation("FED HEADER 2", header_2_idx)
        self.add_annotation("FED HEADER 3", header_3_idx)

        # header 1
        self.add_debug("HEADER_1_MARKER", header_1_idx, 63, 60, err_expr="self.value != 0x5") # [63:60] should be 5
        self.add_debug("EVENT_TYPE", header_1_idx, 59, 56, err_expr="self.value != 0x0") # [59:56] should be 0
        self.add_info("L1A_ID", header_1_idx, 55, 32, err_expr="self.value != %d" % (self.evt_id + 1)) # [55:32]
        self.add_info("BX_ID", header_1_idx, 31, 20) # [31:20]
        self.add_info("BOARD_ID", header_1_idx, 19, 8) # [19:8]
        self.add_info("FORMAT_VER", header_1_idx, 7, 4) # [7:4]
        self.add_debug("SLINK_STATUS", header_1_idx, 3, 0, warn_expr="self.value != 0") # [3:0] -- 0 for ATCA

        # header 2
        self.add_debug("HEADER_2_MARKER", header_2_idx, 63, 16, err_expr="self.value != 0x800000018000") # [63:16] should be 8000 0001 8000
        self.add_info("DMB_FULL_MASK", header_2_idx, 15, 0, err_expr="self.value != 0") # [15:0]

        # header 3
        self.add_info("INPUT_MASK", header_3_idx, 63, 48) # [63:48]
        self.add_info("DAQ_FIFO_FULL", header_3_idx, 47, 47, err_expr="self.value != 0") # [47]
        self.add_info("DAQ_BACKPRESSURE", header_3_idx, 46, 46, warn_expr="self.value != 0") # [46]
        self.add_debug("TTS_ERR_WITH_BACKPRESSURE", header_3_idx, 39, 39, err_expr="self.value != 0") # [39]
        self.add_debug("DAQLINK_NOT_READY", header_3_idx, 36, 36, err_expr="self.value != 0 and %r" % (not IGNORE_DAQLINK)) # [36]
        self.add_info("DAV_MASK", header_3_idx, 31, 16) # [31:16]
        self.add_debug("L1A_FIFO_FULL", header_3_idx, 13, 13, err_expr="self.value != 0") # [13]
        self.add_debug("TTS_ERROR", header_3_idx, 11, 11, err_expr="self.value != 0") # [11]
        self.add_debug("DAV_TIMEOUT", header_3_idx, 8, 8, warn_expr="self.value != 0") # [8]
        self.add_info("TTS_STATE", header_3_idx, 7, 4, err_expr="self.value == 0xc or self.value == 0", warn_expr="self.value != 8") # [7:4]
        self.add_info("DAV_COUNT", header_3_idx, 3, 0) # [3:0]

        return idx

    def unpack_trailer(self, idx):

        if self.verbose:
            print_cyan("--------------------------------------")
            print_cyan("FED Trailer")
            print_cyan("--------------------------------------")

        trail_1_idx = idx
        trail_2_idx = idx + 1
        trail_3_idx = idx + 2
        idx += 3

        self.add_annotation("FED TRAILER 1", trail_1_idx)
        self.add_annotation("FED TRAILER 2", trail_2_idx)
        self.add_annotation("FED TRAILER 3", trail_3_idx)

        # trailer 1

        self.add_debug("TRAIL_1_MARKER", trail_1_idx, 63, 0, err_expr="self.value != 0x8000ffff80008000") # [63:0] 8000 ffff 8000 8000
        # trailer 2
        self.add_debug("TRAIL_L1A_FIFO_FULL", trail_2_idx, 58, 58, err_expr="self.value != 0") # [58]
        self.add_debug("TRAIL_NO_INPUTS", trail_2_idx, 56, 56, err_expr="self.value != 0") # [56]
        self.add_debug("TRAIL_BACKPRESSURE", trail_2_idx, 53, 53, warn_expr="self.value != 0") # [53]
        self.add_debug("TRAIL_DAQLINK_NOT_READY", trail_2_idx, 52, 52, err_expr="self.value != 0 and %r" % (not IGNORE_DAQLINK)) # [52]
        self.add_debug("TRAIL_TTS_ERROR", trail_2_idx, 47, 47, err_expr="self.value != 0") # [47]
        self.add_debug("TRAIL_TTS_WARN_OR_BP", trail_2_idx, 44, 44, warn_expr="self.value != 0") # [44]
        self.add_debug("TRAIL_DAV_TIMEOUT", trail_2_idx, 41, 41, warn_expr="self.value != 0") # [41]
        self.add_debug("TRAIL_TTS_ERR_OR_OOS", trail_2_idx, 35, 35, err_expr="self.value != 0") # [35]
        self.add_info("CHAMBER_ERROR", trail_2_idx, 30, 16, err_expr="self.value != 0") # [30:16]
        self.add_info("CHAMBER_WARN", trail_2_idx, 14, 0, warn_expr="self.value != 0") # [14:0]

        # trailer 3
        self.add_debug("TRAIL_3_MARKER", trail_3_idx, 63, 60, err_expr="self.value != 0xA") # [63:60] should be A
        self.add_debug("DMB_64BIT_ALIGN_ERR", trail_3_idx, 59, 59, err_expr="self.value != 0") # [59]
        self.add_info("CLOSE_L1AS", trail_3_idx, 56, 56, warn_expr="self.value != 0") # [56]
        self.add_info("FED_WORD_CNT", trail_3_idx, 55, 32) # [55:32]
        self.add_info("FED_CRC", trail_3_idx, 31, 16) # [31:16] # TODO: implement CRC check!!!
        self.add_info("TRAIL_TTS_STATE", trail_3_idx, 7, 4, err_expr="self.value == 0xc or self.value == 0", warn_expr="self.value != 8") # [7:4]

        return idx

    def is_empty(self):
        if len(self.dmbs) == 0:
            return True
        if len(self.dmbs[0].cfebs) == 0:
            return True
        else:
            return False
        # return None

class Dmb(EventFragment):

    fed = None
    alct = None
    tmb = None
    cfebs = None

    def __init__(self, fed, words, start_idx, end_idx, evt_id, verbose):
        super().__init__(words, start_idx, end_idx, evt_id, verbose)
        self.fed = fed
        self.cfebs = []

    def get_name(self):
        return "DMB in crate %d slot %d" % (self.get_info_val("CRATE"), self.get_info_val("SLOT"))

    def unpack(self):
        idx = self.unpack_header(self.start_idx)
        idx = self.unpack_chamber(idx)
        idx = self.unpack_trailer(self.end_idx - 1)

    def unpack_header(self, idx):

        if self.verbose:
            print_cyan("--------------------------------------")
            print_cyan("DMB Header")
            print_cyan("--------------------------------------")

        header_1 = self.words[idx]
        header_2 = self.words[idx + 1]
        header_1_idx = idx
        header_2_idx = idx + 1
        idx += 2

        self.add_annotation("DMB HEADER 1", header_1_idx)
        self.add_annotation("DMB HEADER 2", header_2_idx)

        # markers
        header_1_marker = ((header_1 >> 60) << 12) + (((header_1 >> 44) & 0xf) << 8) + (((header_1 >> 28) & 0xf) << 4) + ((header_1 >> 12) & 0xf) # [63:60] + [47:44] + [31:28] + [15:12], should be 0x9999
        header_2_marker = ((header_2 >> 60) << 12) + (((header_2 >> 44) & 0xf) << 8) + (((header_2 >> 28) & 0xf) << 4) + ((header_2 >> 12) & 0xf) # [63:60] + [47:44] + [31:28] + [15:12], should be 0xAAAA
        self.add_debug("DMB_HEADER_1_MARKER", header_1_idx, 63, 0, value=header_1_marker, err_expr="self.value != 0x9999")
        self.add_debug("DMB_HEADER_2_MARKER", header_2_idx, 63, 0, value=header_2_marker, err_expr="self.value != 0xAAAA")

        # L1A ID
        l1a_id = (((header_1 >> 16) & 0xfff) << 12) + (header_1 & 0xfff) # header 1 [27:16] + [11:0] = header 2 [52:48] = trailer 1 [5:0]
        self.l1a_id = l1a_id
        fed_l1a_id = self.fed.get_info_val("L1A_ID")
        self.add_info("L1A_ID", header_1_idx, 11, 0, value=l1a_id, err_expr="(self.value != %d) and not IGNORE_DMB_FED_L1A_MISMATCH" % fed_l1a_id)
        self.add_debug("L1A_ID_HEAD_2_CHECK", header_2_idx, 52, 48, err_expr="self.value != %d & 0x1f" % l1a_id)

        if (l1a_id != fed_l1a_id) and not IGNORE_DMB_FED_L1A_MISMATCH:
            self.add_error("DMB_FED_L1A_ID_MISMATCH", header_1_idx, 11, 0, "FED L1A ID = %d, DMB L1A ID = %d" % (fed_l1a_id, l1a_id))

        # BX ID
        fed_bx_id = self.fed.get_info_val("BX_ID")
        bx_id = ((header_1 >> 48) & 0xfff)
        self.bx_id = bx_id
        self.add_info("BX_ID", header_1_idx, 59, 48, value=bx_id, err_expr="self.value != %d and not %r" % (fed_bx_id, IGNORE_FED_BX_ID)) # header 1 [59:48] = header 2 [36:32] = trailer 1 [10:6]
        self.add_debug("BX_ID_HEAD_2_CHECK", header_2_idx, 36, 32, err_expr="self.value != %d & 0x1f" % bx_id)
        if bx_id != fed_bx_id and not IGNORE_FED_BX_ID:
            self.add_error("DMB_FED_BX_ID_MISMATCH", header_1_idx, 59, 48, "FED BX ID = %d, DMB BX ID = %d" % (fed_bx_id, bx_id))

        alct_dav = (header_1 >> 43) & 1 # header 1 [43] = header 2 [11] = header 2 [43]
        alct_dav_check1 = (header_2 >> 11) & 1
        alct_dav_check2 = (header_2 >> 43) & 1
        self.add_info("ALCT_DAV", header_1_idx, 43, 43, value=alct_dav, err_expr="self.value != %d or self.value != %d" % (alct_dav_check1, alct_dav_check2))

        tmb_dav = (header_1 > 42) & 1 # header 1 [42] = header 2 [10] = header 2 [42]
        tmb_dav_check1 = (header_2 >> 10) & 1
        tmb_dav_check2 = (header_2 >> 42) & 1
        self.add_info("TMB_DAV", header_1_idx, 42, 42, value=tmb_dav, err_expr="self.value != %d or self.value != %d" % (tmb_dav_check1, tmb_dav_check2))

        format_ver = (header_1 >> 40) & 0x3 # header 1 [41:40] = header 2 [9:8] = header 2 [55:54]
        format_ver_check1 = (header_2 >> 8) & 0x3
        format_ver_check2 = (header_2 >> 54) & 0x3
        self.add_debug("FORMAT_VER", header_1_idx, 41, 40, value=format_ver, err_expr="self.value != %d or self.value != %d" % (format_ver_check1, format_ver_check2))

        clct_dav_mismatch = (header_1 >> 39) & 1 # header 1 [39] = header 2 [7] = header 2 [53]
        clct_dav_mismatch_check1 = (header_2 >> 7) & 1
        clct_dav_mismatch_check2 = (header_2 >> 53) & 1
        self.add_debug("CLCT_DAV_MISMATCH", header_1_idx, 39, 39, value=clct_dav_mismatch, err_expr="self.value != %d or self.value != %d" % (clct_dav_mismatch_check1, clct_dav_mismatch_check2), warn_expr="self.value != 0")

        self.add_info("CFEB_CLCT_SENT", header_1_idx, 38, 32, err_expr="False") # header 1 [38:32]
        self.add_info("CFEB_DAV", header_2_idx, 6, 0, err_expr="False") # header 2 [6:0]
        self.add_info("DMB_CFEB_SYNC", header_2_idx, 59, 56) # header 2 [59:56]
        self.add_info("CFEB_OVERLAPS", header_2_idx, 41, 37, err_expr="False") # header 2 [41:37] = trailer 1 [27:23]

        self.add_info("CRATE", header_2_idx, 27, 20, err_expr="False") # header 2 [27:20] = trailer 2 [27:20]
        self.add_info("SLOT", header_2_idx, 19, 16, err_expr="False") # header 2 [19:16] = trailer 2 [19:16]

        return idx

    def unpack_trailer(self, idx):

        if self.verbose:
            print_cyan("--------------------------------------")
            print_cyan("DMB Trailer")
            print_cyan("--------------------------------------")

        trail_1 = self.words[idx]
        trail_2 = self.words[idx + 1]
        trail_1_idx = idx
        trail_2_idx = idx + 1
        idx += 2

        self.add_annotation("DMB TRAILER 1", trail_1_idx)
        self.add_annotation("DMB TRAILER 2", trail_2_idx)

        # markers
        trail_1_marker = ((trail_1 >> 60) << 12) + (((trail_1 >> 44) & 0xf) << 8) + (((trail_1 >> 28) & 0xf) << 4) + ((trail_1 >> 12) & 0xf) # [63:60] + [47:44] + [31:28] + [15:12], should be 0xFFFF
        trail_2_marker = ((trail_2 >> 60) << 12) + (((trail_2 >> 44) & 0xf) << 8) + (((trail_2 >> 28) & 0xf) << 4) + ((trail_2 >> 12) & 0xf) # [63:60] + [47:44] + [31:28] + [15:12], should be 0xEEEE
        self.add_debug("DMB_TRAIL_1_MARKER", trail_1_idx, 63, 0, value=trail_1_marker, err_expr="self.value != 0xFFFF")
        self.add_debug("DMB_TRAIL_2_MARKER", trail_2_idx, 63, 0, value=trail_2_marker, err_expr="self.value != 0xEEEE")

        self.add_debug("DMB_TRAIL_L1A_ID_CHECK", trail_1_idx, 5, 0, err_expr="self.value != %d & 0x3f" % self.l1a_id)
        self.add_debug("DMB_TRAIL_BX_ID_CHECK", trail_1_idx, 10, 6, err_expr="self.value != %d & 0x1f" % self.bx_id)
        self.add_debug("DMB_TRAIL_CFEB_OVERLAPS_CHECK", trail_1_idx, 27, 23, err_expr="self.value != %d & 0x1f" % self.get_info_val("CFEB_OVERLAPS"))
        self.add_debug("DMB_TRAIL_CRATE_CHECK", trail_2_idx, 27, 20, err_expr="self.value != %d" % self.get_info_val("CRATE"))
        self.add_debug("DMB_TRAIL_SLOT_CHECK", trail_2_idx, 19, 16, err_expr="self.value != %d" % self.get_info_val("SLOT"))

        self.add_debug("ALCT_END_TIMEOUT", trail_1_idx, 11, 11, err_expr="self.value != 0") # trailer 1 [11]
        self.add_debug("CFEB_END_TIMEOUT", trail_1_idx, 22, 16, err_expr="self.value != 0") # trailer 1 [22:16]
        self.add_debug("TMB_END_TIMEOUT", trail_2_idx, 7, 7, err_expr="self.value != 0") # trailer 2 [7]

        self.add_debug("ALCT_START_TIMEOUT", trail_1_idx, 59, 59, err_expr="self.value != 0") # trailer 1 [59]
        self.add_debug("CFEB_START_TIMEOUT", trail_1_idx, 58, 52, err_expr="self.value != 0") # trailer 1 [58:52]
        self.add_debug("TMB_START_TIMEOUT", trail_1_idx, 40, 40, err_expr="self.value != 0") # trailer 1 [40]

        self.add_debug("ALCT_FULL", trail_2_idx, 11, 11, err_expr="self.value != 0") # trailer 2 [11]
        cfeb_full = (((trail_1 >> 48) & 0xf) << 3) + ((trail_1 >> 41) & 0x7) # trailer 1 [51:48] + [43:41]
        self.add_debug("CFEB_FULL", trail_1_idx, 51, 48, value=cfeb_full, err_expr="self.value != 0")
        self.add_debug("TMB_FULL", trail_2_idx, 10, 10, err_expr="self.value != 0") # trailer 2 [10]

        self.add_debug("ALCT_HALF_FULL", trail_2_idx, 9, 9) # warn_expr="self.value != 0") # trailer 2 [9]
        self.add_debug("CFEB_HALF_FULL", trail_2_idx, 6, 0) # warn_expr="self.value != 0") # trailer 2 [6:0]
        self.add_debug("TMB_HALF_FULL", trail_2_idx, 8, 8) # warn_expr="self.value != 0") # trailer 2 [8]

        self.add_info("DMB_L1A_FIFO_CNT", trail_1_idx, 39, 32, warn_expr="False") # trailer 1 [39:32]

        self.add_debug("DMB_CRC_LOW_PARITY", trail_2_idx, 43, 43) # trailer 2 [43]
        self.add_debug("DMB_CRC_HIGH_PARITY", trail_2_idx, 59, 59) # trailer 2 [59]
        crc = (((trail_2 >> 48) & 0x7ff) << 11) + ((trail_2 >> 32) & 0x7ff) # trailer 2 [58:48] + [42:32]
        self.add_debug("DMB_CRC", trail_2_idx, 58, 32, value=crc) # TODO: implement CRC check!!!

        return idx

    def unpack_chamber(self, idx):
        if self.verbose:
            print("Chamber unpacking: starts at idx = %d" % idx)

        fed_trailer = False
        dmb_trailer = False
        dmb_header = False
        alct_header_idx = None
        alct_trailer_idx = None
        tmb_header_idx = None
        tmb_trailer_idx = None
        sca_full_words = []
        status_words = []
        cfeb_start_idx = idx

        while not fed_trailer and not dmb_trailer and not dmb_header:
            word = self.words[idx]
            first_16bits = word & 0xffff
            fed_trailer = word == 0x8000ffff80008000
            dmb_header = (word >> 60) == 0x9
            dmb_trailer = (word >> 60) == 0xe

            if first_16bits == 0xdb0a:
                if alct_header_idx is not None:
                    self.add_error("MULTIPLE_ALCT_HEADERS", idx, 63, 0)
                alct_header_idx = idx

            if first_16bits == 0xdb0c:
                if tmb_header_idx is not None:
                    self.add_error("MULTIPLE_TMB_HEADERS", idx, 63, 0)
                tmb_header_idx = idx

            if first_16bits == 0xde0d:
                if alct_trailer_idx is not None:
                    self.add_error("MULTIPLE_ALCT_TRAILERS", idx, 63, 0)
                alct_trailer_idx = idx

            if first_16bits == 0xde0f:
                if tmb_trailer_idx is not None:
                    self.add_error("MULTIPLE_TMB_TRAILERS", idx, 63, 0)
                tmb_trailer_idx = idx

            if first_16bits & 0xf000 == 0xb000:
                self.add_annotation("CFEB SCA FULL", idx)
                sca_full_words.append(idx)

            if first_16bits & 0xf000 == 0xc000:
                self.add_annotation("STATUS WORD", idx)
                status_words.append(idx)

            idx += 1

        if alct_header_idx is not None and alct_trailer_idx is None:
            self.add_error("ALCT_TRAILER_MISSING", alct_header_idx, 63, 0)
            cfeb_start_idx = None

        if tmb_header_idx is not None and tmb_trailer_idx is None:
            self.add_error("TMB_TRAILER_MISSING", alct_header_idx, 63, 0)
            cfeb_start_idx = None

        if alct_header_idx is not None and alct_trailer_idx is not None:
            self.alct = Alct(self, self.words, alct_header_idx, alct_trailer_idx, self.evt_id, self.verbose)
            self.alct.unpack()
            self.children.append(self.alct)
            cfeb_start_idx = alct_trailer_idx + 1

        if tmb_header_idx is not None and tmb_trailer_idx is not None:
            self.tmb = Tmb(self, self.words, tmb_header_idx, tmb_trailer_idx, self.evt_id, self.verbose)
            self.tmb.unpack()
            self.children.append(self.tmb)
            cfeb_start_idx = tmb_trailer_idx + 1

        # CFEBs
        dmb_trail_idx = self.end_idx - 1
        while dmb_trail_idx - cfeb_start_idx >= 25 * CFEB_NUM_TIMESAMPLES:
            # take 25 words * CFEB_NUM_TIMESAMPLES
            cfeb = Cfeb(self, self.words, cfeb_start_idx, cfeb_start_idx + 25 * CFEB_NUM_TIMESAMPLES - 1, self.evt_id, self.verbose)
            cfeb.unpack()
            self.cfebs.append(cfeb)
            self.children.append(cfeb)
            cfeb_start_idx += 25 * CFEB_NUM_TIMESAMPLES

        if cfeb_start_idx != dmb_trail_idx:
            cfeb = Cfeb(self, self.words, cfeb_start_idx, dmb_trail_idx - 1, self.evt_id, self.verbose)
            cfeb.unpack()
            self.cfebs.append(cfeb)
            self.children.append(cfeb)
            self.add_error("CFEB_BLOCK_ENDS_AT_THE_WRONG_PLACE", dmb_trail_idx - 1, 63, 0)

        idx -= 1 # come back to the dmb trailer position

        if self.verbose:
            print("DMB unpacking: ends at idx = %d" % idx)

        return idx

class Alct(EventFragment):

    dmb = None

    def __init__(self, dmb, words, start_idx, end_idx, evt_id, verbose):
        super().__init__(words, start_idx, end_idx, evt_id, verbose)
        self.dmb = dmb

    def get_name(self):
        return "ALCT, crate %d slot %d" % (self.dmb.get_info_val("CRATE"), self.dmb.get_info_val("SLOT"))

    def unpack(self):
        idx = self.unpack_header(self.start_idx)
        idx = self.unpack_trailer(self.end_idx)

    def unpack_header(self, idx):

        if self.verbose:
            print_cyan("--------------------------------------")
            print_cyan("ALCT Header")
            print_cyan("--------------------------------------")

        header = self.words[idx]
        header_idx = idx
        idx += 1

        self.add_annotation("ALCT HEADER", header_idx)

        bx_id = (header >> 16) & 0xfff
        l1a_id = (header >> 32) & 0xfff
        self.bx_id = bx_id
        self.l1a_id = l1a_id

        self.add_info("BX_ID", header_idx, 27, 16, value=bx_id, err_expr="self.value != %d and not %r" % (self.dmb.bx_id, IGNORE_ALCT_BX_ID))
        self.add_info("L1A_ID", header_idx, 43, 32, value=l1a_id, err_expr="self.value != %d" % (self.dmb.l1a_id & 0xfff))
        self.add_info("READOUT_CNT", header_idx, 59, 48)

        if l1a_id != self.dmb.l1a_id & 0xfff:
            self.add_error("ALCT_DMB_L1A_ID_MISMATCH", header_idx, 43, 32, "DMB L1A ID = %d (24 bits), ALCT L1A ID = %d (12 bits)" % (self.dmb.l1a_id, l1a_id))

        if bx_id != self.dmb.bx_id and not IGNORE_ALCT_BX_ID:
            self.add_error("ALCT_DMB_BX_ID_MISMATCH", header_idx, 27, 16, "DMB BX ID = %d, ALCT BX ID = %d" % (self.dmb.bx_id, bx_id))

        return idx

    def unpack_trailer(self, idx):

        if self.verbose:
            print_cyan("--------------------------------------")
            print_cyan("ALCT Trailer")
            print_cyan("--------------------------------------")

        trailer = self.words[idx]
        trail_idx = idx
        idx += 1

        self.add_annotation("ALCT TRAILER", trail_idx)

        word_cnt = (trailer >> 48) & 0x7ff
        actual_word_cnt = (self.end_idx - self.start_idx + 1) * 4
        self.add_info("16BIT_WORD_CNT", trail_idx, 57, 48, value=word_cnt, err_expr="self.value != %d" % actual_word_cnt)
        self.add_debug("CRC_LOW", trail_idx, 27, 16) # TODO: implement CRC check!!!
        self.add_debug("CRC_HIGH", trail_idx, 43, 32) # TODO: implement CRC check!!!

        if word_cnt != actual_word_cnt:
            self.add_error("ALCT_WORD_CNT_ERR", trail_idx, 57, 48, "Reported ALCT word cnt = %d, actual = %d" % (word_cnt, actual_word_cnt))

        return idx

class Tmb(EventFragment):

    dmb = None

    def __init__(self, dmb, words, start_idx, end_idx, evt_id, verbose):
        super().__init__(words, start_idx, end_idx, evt_id, verbose)
        self.dmb = dmb

    def get_name(self):
        return "TMB, crate %d slot %d" % (self.dmb.get_info_val("CRATE"), self.dmb.get_info_val("SLOT"))

    def unpack(self):
        idx = self.unpack_header(self.start_idx)
        idx = self.unpack_trailer(self.end_idx)

    def unpack_header(self, idx):

        if self.verbose:
            print_cyan("--------------------------------------")
            print_cyan("TMB Header")
            print_cyan("--------------------------------------")

        header = self.words[idx]
        header_idx = idx
        idx += 1

        self.add_annotation("TMB HEADER", header_idx)

        bx_id = (header >> 16) & 0xfff
        l1a_id = (header >> 32) & 0xfff
        self.bx_id = bx_id
        self.l1a_id = l1a_id

        self.add_info("BX_ID", header_idx, 27, 16, value=bx_id, err_expr="self.value != %d" % self.dmb.bx_id)
        self.add_info("L1A_ID", header_idx, 43, 32, value=l1a_id, err_expr="self.value != %d" % (self.dmb.l1a_id & 0xfff))
        self.add_info("READOUT_CNT", header_idx, 59, 48)

        if l1a_id != self.dmb.l1a_id & 0xfff:
            self.add_error("TMB_DMB_L1A_ID_MISMATCH", header_idx, 43, 32, "DMB L1A ID = %d (24 bits), TMB L1A ID = %d (12 bits)" % (self.dmb.l1a_id, l1a_id))

        if bx_id != self.dmb.bx_id:
            self.add_error("TMB_DMB_BX_ID_MISMATCH", header_idx, 27, 16, "DMB BX ID = %d, TMB BX ID = %d" % (self.dmb.bx_id, bx_id))

        return idx

    def unpack_trailer(self, idx):

        if self.verbose:
            print_cyan("--------------------------------------")
            print_cyan("TMB Trailer")
            print_cyan("--------------------------------------")

        trailer = self.words[idx]
        trail_idx = idx
        idx += 1

        self.add_annotation("TMB TRAILER", trail_idx)

        word_cnt = (trailer >> 48) & 0x7ff
        actual_word_cnt = (self.end_idx - self.start_idx + 1) * 4
        self.add_info("16BIT_WORD_CNT", trail_idx, 58, 48, value=word_cnt, err_expr="self.value != %d" % actual_word_cnt)
        self.add_debug("CRC_LOW", trail_idx, 27, 16) # TODO: implement CRC check!!!
        self.add_debug("CRC_HIGH", trail_idx, 43, 32) # TODO: implement CRC check!!!

        if word_cnt != actual_word_cnt:
            self.add_error("TMB_WORD_CNT_ERR", trail_idx, 57, 48, "Reported TMB word cnt = %d, actual = %d" % (word_cnt, actual_word_cnt))

        return idx

class Cfeb(EventFragment):

    dmb = None

    def __init__(self, dmb, words, start_idx, end_idx, evt_id, verbose):
        super().__init__(words, start_idx, end_idx, evt_id, verbose)
        self.dmb = dmb

    def get_name(self):
        return "CFEB, crate %d slot %d" % (self.dmb.get_info_val("CRATE"), self.dmb.get_info_val("SLOT"))

    def unpack(self):
        idx = self.start_idx
        for i in range(CFEB_NUM_TIMESAMPLES):
            if idx <= self.end_idx:
                self.add_annotation("CFEB time sample #%d START" % i, idx)
            if idx + 24 <= self.end_idx:
                self.add_annotation("CFEB time sample #%d END" % i, idx + 24)
            idx += 25

def main():

    parser = argparse.ArgumentParser()

    parser.add_argument('-e',
                        '--error',
                        action="store_true",
                        dest='error',
                        help="Only count events with errors (uses OR logic when combined with --warning, uses AND logic when combining with --alct --cfeb --tmb)")

    parser.add_argument('-w',
                        '--warning',
                        action="store_true",
                        dest='warning',
                        help="Only count events with warnings (uses OR logic when combined with --error, uses AND logic when combining with --alct --cfeb --tmb)")

    parser.add_argument('-a',
                        '--alct',
                        action="store_true",
                        dest='alct',
                        help="Only count events that contain an ALCT block (uses AND logic when combining with --alct --cfeb --tmb --error --warning)")

    parser.add_argument('-c',
                        '--cfeb',
                        action="store_true",
                        dest='cfeb',
                        help="Only count events that contain at least one CFEB block (uses AND logic when combining with --alct --cfeb --tmb --error --warning)")

    parser.add_argument('-t',
                        '--tmb',
                        action="store_true",
                        dest='tmb',
                        help="Only count events that contain a TMB block (uses AND logic when combining with --alct --cfeb --tmb --error --warning)")

    parser.add_argument('-il',
                        '--ignore-dmb-fed-l1a',
                        action="store_true",
                        dest='ignore_dmb_fed_l1a',
                        help="Setting this flag will cause the error checker to ignore DMB-FED L1A mismatches (could be useful when starting the FED manually)")

    parser.add_argument('raw_file',
                        help="CSC raw file path")

    parser.add_argument('event_num',
                        help="Event number to print or start searching at")

    args = parser.parse_args()

    raw_filename = args.raw_file
    evt_num_to_print = int(args.event_num)
    req_err = args.error
    req_warn = args.warning
    req_alct = args.alct
    req_tmb = args.tmb
    req_cfeb = args.cfeb

    global IGNORE_DMB_FED_L1A_MISMATCH
    IGNORE_DMB_FED_L1A_MISMATCH = args.ignore_dmb_fed_l1a

    print("====================================================")
    print("Filename: %s" % raw_filename)
    print("Event number to print: %d" % evt_num_to_print)
    print("Require error: %r" % req_err)
    print("Require warning: %r" % req_warn)
    print("Require alct: %r" % req_alct)
    print("Require tmb: %r" % req_tmb)
    print("Require cfeb: %r" % req_cfeb)
    print("====================================================")
    print("")

    files = []

    # do regexp
    if ("*" in raw_filename or "?" in raw_filename or "[" in raw_filename):
        dir = os.path.expanduser(os.path.dirname(raw_filename))
        for file in sorted(os.listdir(dir)):
            if fnmatch.fnmatch(file, os.path.basename(raw_filename)):
                files.append(dir + "/" + file)
        if len(files) == 0:
            print_red("No files found..")
            return
    else:
        files.append(raw_filename)
        if not os.path.exists(raw_filename):
            print_red("Input file %s does not exist." % raw_filename)
            return

    events = []
    idx = 0
    alct_idx = 0
    tmb_idx = 0
    cfeb_idx = 0
    err_idx = 0

    for file in files:
        print_cyan("Opening file: %s" % file)
        f = open(file, 'rb')
        file_size = os.fstat(f.fileno()).st_size

        if not IS_LDAQ:
            evt_header_size = readInitRecord(f, VERBOSE)

        print("File size = %d bytes" % file_size)

        while True:
            if f.tell() >= file_size - 1:
                print_cyan("End of file reached")
                f.close()
                break

            event = None
            if not IS_LDAQ:
                event = readEvtRecord(f, file_size, evt_header_size, VERBOSE, DEBUG, idx)
            else:
                event = readFedEvt(f, file_size, VERBOSE, DEBUG, idx)

            if event is not None:
                #events.append(event)

                if (req_err and event.has_errors()) or (req_warn and event.has_warnings()):
                    err_idx += 1

                if req_alct and event.has_alct():
                    alct_idx += 1

                if req_tmb and event.has_tmb():
                    tmb_idx += 1

                if req_cfeb and event.has_cfeb():
                    cfeb_idx += 1

                if not req_err and not req_warn and not req_alct and not req_tmb and not req_cfeb:
                    if idx == evt_num_to_print:
                        ret = ask_to_print_event(event, idx, f.tell(), file)
                        if not ret:
                            return
                        else:
                            evt_num_to_print += 1

                elif (((req_err or req_warn) and err_idx > evt_num_to_print) or (not req_err and not req_warn)) and \
                     ((req_alct and alct_idx > evt_num_to_print) or not req_alct) and \
                     ((req_tmb and tmb_idx > evt_num_to_print) or not req_tmb) and \
                     ((req_cfeb and cfeb_idx > evt_num_to_print) or not req_cfeb):
                    ret = ask_to_print_event(event, idx, f.tell(), file)
                    if not ret:
                        return
                    else:
                        evt_num_to_print += 1

                idx += 1

            print("Read event #%d ending at byte %d (word %d)" % (idx, f.tell(), f.tell()/8))

        f.close()

        print_cyan("Summary")
        print("    Total number of events: %d" % idx)
        print("    Number of events with errors or warnings: %d" % err_idx)
        print("    Number of events with ALCT: %d" % alct_idx)
        print("    Number of events with TMB: %d" % tmb_idx)
        print("    Number of events with CFEBs: %d" % cfeb_idx)

    # # some quick and dirty analysis runs
    # if "analyze_bx_diff" in sys.argv:
    #     an.analyzeBxDiff(events)
    #
    # if "analyze_bx" in sys.argv:
    #     an.analyzeBx(events)
    #
    # if "analyze_num_chambers" in sys.argv:
    #     an.analyzeNumChambers(events)
    #
    # if "analyze_num_vfats" in sys.argv:
    #     an.analyzeNumVfats(events)
    #
    # if "analyze_vfat_bx_matching" in sys.argv:
    #     an.analyzeVfatBxMatching(events)

def ask_to_print_event(event, evt_num, pos_in_file, filename):
    print_cyan("Event #%d (ending at byte %d / word %d in file %s)" % (evt_num, pos_in_file, pos_in_file / 8, filename))
    print("Print the whole event? (y/n)")
    yn = input()
    if (yn == "y"):
        print("")
        print("")
        print("======================================================================================")
        print("")
        event.print_event()

    print("Do you want to continue? (y/n)")
    yn = input()
    return not (yn != "y")

def readInitRecord(f, verbose=False):
    code = readNumber(f, 1)
    initRecordSize = readNumber(f, 4)
    protocol = readNumber(f, 1)
    f.read(16)
    runNumber = readNumber(f, 4)
    initHeaderSize = readNumber(f, 4)
    evtHeaderSize = readNumber(f, 4)
    f.read(initRecordSize - 34) # finish reading the init block

    if verbose:
        print("")
        print("=====================================================")
        print("INIT MESSAGE")
        print("=====================================================")
        print("code = %s" % hex_padded(code, 1))
        print("size = %d" % initRecordSize)
        print("protocol = %s" % hex_padded(protocol, 1))
        print("run number = %d" % runNumber)
        print("init header size = %d" % initHeaderSize)
        print("event header size = %d" % evtHeaderSize)

    return evtHeaderSize

def readEvtRecord(f, fileSize, evtHeaderSize, verbose=False, debug=False, evtNum=-1):
    startIdx = f.tell()
    code = readNumber(f, 1)
    size = readNumber(f, 4)
    protocol = readNumber(f, 1)
    runNumber = readNumber(f, 4)
    evtNumber = readNumber(f, 4)
    f.read(evtHeaderSize - 14 - 4)
    fedBlockSizeCompressed = readNumber(f, 4)
    compressedEvtBlobIdx = f.tell()
    if compressedEvtBlobIdx + fedBlockSizeCompressed >= fileSize:
        f.read(fileSize - compressedEvtBlobIdx)
        if verbose:
            print_red("End of file reached")
        return None
    fedDataCompressed = f.read(fedBlockSizeCompressed)
    fedData = zlib.decompress(fedDataCompressed)[0x1c81:] #0x1c81 is a magic position inside this blob where I found the FED data to start totally emptyrically, so it may not be true for each file...
    fedBlockSize = len(fedData)

    if verbose:
        print("")
        print("=====================================================")
        print("EVENT MESSAGE (event #%d)" % evtNum)
        print("=====================================================")
        print("start idx = %s" % hex_padded(startIdx, 4))
        print("code = %s" % hex_padded(code, 1))
        print("size = %d" % size)
        print("protocol = %s" % hex_padded(protocol, 1))
        print("run number = %d" % runNumber)
        print("event number = %d" % evtNumber)

        print("compressed event blob size = %d" % fedBlockSizeCompressed)
        print("compressed event blob idx: %s" % hex_padded(compressedEvtBlobIdx, 4))

        print("decompressed event blob size = %d" % fedBlockSize)

        if debug:
            print("----------------------------------------------")
            print("FED data:")
            printHexBlock64BigEndian(fedData, fedBlockSize)
            print("----------------------------------------------")

        print_cyan("**********************************************")

    event = GemAmc(None)
    event.unpackGemAmcBlockStr(fedData, verbose)

    if verbose:
        print_cyan("**********************************************")

    return event

def readFedEvt(f, fileSize, verbose=False, debug=False, evtNum=-1, exit_on_marker_err=True):
    startIdx = f.tell()
    if (startIdx + 48 >= fileSize):
        print_red("Unexpected end of file, startIdx = %d, filesize = %d" % (startIdx, fileSize))

    fed_data = []

    # look for header 1
    extra_data_between_events = False
    header_good = False
    while not header_good:
        fed_header_1 = readNumber(f, 8)
        if fed_header_1 >> 60 == 5:
            header_good = True
            fed_data.append(fed_header_1)
            if verbose:
                print("Evt %d: Header found" % evtNum)
        else:
            print_red("ERROR: extra data before the header 1 of event %d" % evtNum)
            extra_data_between_events = True
            if exit_on_marker_err:
                sys.exit()

    # look for header 2
    header_good = False
    while not header_good:
        fed_header_2 = readNumber(f, 8)
        if fed_header_2 >> 16 == 0x800000018000:
            header_good = True
            fed_data.append(fed_header_2)
        else:
            print_red("ERROR: extra data before the header 2 of event %d" % evtNum)
            extra_data_between_events = True
            if exit_on_marker_err:
                sys.exit()

    # read header 3
    fed_header_3 = readNumber(f, 8)
    fed_data.append(fed_header_3)

    # read the payload until we see the trailer

    payload_idx = f.tell()
    trailer_found = False
    i = 0
    while not trailer_found:
        if payload_idx + i > fileSize:
            print_red("Unexpected end of file, startIdx = %d, payload_idx = %d, filesize = %d" % (startIdx, payload_idx, fileSize))

        # this can be optimized by looking at the DAV mask in the header and reading more data at a time
        word = readNumber(f, 8)
        fed_data.append(word)
        if word == 0x8000ffff80008000:
            trailer_found = True
            if verbose:
                print("Evt %d: Trailer found" % evtNum)
        i += 1

    fed_data.append(readNumber(f, 8)) # read trailer 2
    fed_data.append(readNumber(f, 8)) # read trailer 3

    fed_block_size = len(fed_data)

    if verbose:
        print("")
        print("=====================================================")
        print("EVENT MESSAGE (event #%d)" % evtNum)
        print("=====================================================")
        print("start idx = %s" % hex_padded(startIdx, 4))
        print("fed block size = %d" % fed_block_size)

        if debug:
            print("----------------------------------------------")
            print("FED data:")
            print_red("NOT IMPLEMENTED YET")
            # printHexBlock64BigEndian(fed_data, fed_block_size)
            print("----------------------------------------------")

        print_cyan("**********************************************")

    event = Fed(fed_data, 0, len(fed_data) - 1, evtNum, verbose)
    event.unpack()

    if verbose:
        print_cyan("**********************************************")

    return event

def readNumber(f, numBytes):
    formatStr = "<"
    if numBytes == 1:
        formatStr += "B"
    elif numBytes == 2:
        formatStr += "H"
    elif numBytes == 4:
        formatStr += "I"
    elif numBytes == 8:
        formatStr += "Q"
    else:
        raise "Unsupported number byte count of %d" % numBytes

    word = struct.unpack(formatStr, f.read(numBytes))[0]

    return word

def bytesToWords(str):
    return struct.unpack("%dQ" % int(len(str) / 8), str)

def printHexBlock64BigEndianStr(str, length):
    fedBytes = struct.unpack("%dB" % length, str)
    # print "length: %d, str length: %d, num of 8 byte words: %d" % (len(fedBytes), len(str), int(math.ceil(length / 8.0)))
    for i in range(0, int(math.ceil(length / 8.0))):
        idx = i * 8
        sys.stdout.write("{0:#0{1}x}: ".format(idx, 4 + 2))
        # sys.stdout.write("%d: " % idx)
        for j in range(0, 8):
            if (i+1) * 8 - (j + 1) >= length:
                sys.stdout.write("-- ")
            else:
                sys.stdout.write("%s " % (format(fedBytes[(i+1) * 8 - (j + 1)], '02x')))
        sys.stdout.write('\n')
    sys.stdout.flush()

if __name__ == '__main__':
    main()
