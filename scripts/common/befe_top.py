#!/usr/bin/env python
"""
"""
from pygments.lexers.html import HtmlLexer

from prompt_toolkit.application import Application
from prompt_toolkit.application.current import get_app
from prompt_toolkit.completion import WordCompleter
from prompt_toolkit.key_binding import KeyBindings
from prompt_toolkit.key_binding.bindings.focus import focus_next, focus_previous
from prompt_toolkit.layout.containers import Float, HSplit, VSplit, Container, Window, FloatContainer, DynamicContainer, HorizontalAlign, VerticalAlign
from prompt_toolkit.layout.dimension import D
from prompt_toolkit.layout.layout import Layout
from prompt_toolkit.layout.menus import CompletionsMenu
from prompt_toolkit.lexers import PygmentsLexer
from prompt_toolkit.styles import Style
from prompt_toolkit.formatted_text import ANSI
from prompt_toolkit.shortcuts import message_dialog
from prompt_toolkit.widgets import (
    Box,
    Button,
    Checkbox,
    Dialog,
    Frame,
    Label,
    MenuContainer,
    MenuItem,
    ProgressBar,
    RadioList,
    TextArea,
)

from common.rw_reg import *
import common.fw_utils as befe

class TopScreen:

    app = None        # set by the pap
    screen_idx = None # set by the app

    gem_csc = None    # "GEM_AMC" or "CSC_FED"
    is_gem = None     # bool
    is_csc = None     # bool

    container = None
    title = None
    shortcut = None
    shortcut_label = None

    def __init__(self, gem_csc, container, title, shortcut, shortcut_label):
        self.gem_csc = gem_csc
        if "GEM" in self.gem_csc:
            self.is_gem = True
            self.is_csc = False
        elif "CSC" in self.gem_csc:
            self.is_gem = False
            self.is_csc = True
        else:
            raise ValueError("Cannot determine if the firmware flavor is GEM or CSC, fw flavor returned " + self.gem_csc)

        self.container = container
        self.title = title
        self.shortcut = shortcut
        self.shortcut_label = shortcut_label

    def screen_sel(self, event=None):
        self.app.screen_sel(self.screen_idx)

    def action(self):
        pass

class BefeTopApp(Application):

    top_screens = []
    top_screen = None
    screen_idx = 0
    sceen_sel_buttons = []

    lbl_screen = None
    top_layout = None

    def get_top_screen(self):
        return self.top_screens[self.screen_idx]

    def get_top_screen_container(self):
        return self.get_top_screen().container

    def screen_sel(self, screen_idx):
        self.screen_idx = screen_idx
        self.lbl_screen.text = self.top_screens[screen_idx].title
        self.top_layout.focus(self.sceen_sel_buttons[screen_idx])

    def f_exit(self, event=None):
        get_app().exit()

    def f_action(self, event=None):
        self.get_top_screen().action()

    def init_layout(self):
        for i in range(len(self.top_screens)):
            s = self.top_screens[i]
            s.app = self
            s.screen_idx = i
            self.sceen_sel_buttons.append(Button(text="%s %s" % (s.shortcut.upper(), s.shortcut_label), handler=s.screen_sel))

        self.lbl_screen = Label(text=self.top_screens[0].title)

        self.top_screen = DynamicContainer(self.get_top_screen_container)

        btn_action = Button(text="F8 Action", handler=self.f_action)
        btn_exit = Button(text="F10 Exit", handler=self.f_exit)

        self.root_container = HSplit(
            [
                Box(
                    body=VSplit([self.lbl_screen], align="CENTER", padding=3),
                    style="class:button-bar",
                    height=1,
                ),
                self.top_screen,
                Box(
                    body=VSplit(self.sceen_sel_buttons + [btn_action, btn_exit], align="CENTER", padding=3),
                    style="class:button-bar",
                    height=1,
                ),
            ]
        )
        self.top_layout = Layout(self.root_container, focused_element=self.sceen_sel_buttons[0])

    def init_bindings(self):
        self.top_bindings = KeyBindings()
        self.top_bindings.add("tab")(focus_next)
        self.top_bindings.add("s-tab")(focus_previous)
        self.top_bindings.add("f8")(self.f_action)
        self.top_bindings.add("f10")(self.f_exit)

        for s in self.top_screens:
            self.top_bindings.add(s.shortcut)(s.screen_sel)

    def init_style(self):
        self.top_style = Style.from_dict(
            {
                "window.border": "#888888",
                "shadow": "bg:#222222",
                "menu-bar": "bg:#aaaaaa #888888",
                "menu-bar.selected-item": "bg:#ffffff #000000",
                "menu": "bg:#888888 #ffffff",
                "menu.border": "#aaaaaa",
                "window.border shadow": "#444444",
                "focused  button": "bg:#880000 #ffffff noinherit",
                # Styling for Dialog widgets.
                "button-bar": "bg:#aaaaff",
            }
        )

    def __init__(self, top_screens):
        self.top_screens = top_screens
        self.init_bindings()
        self.init_style()
        self.init_layout()

        super().__init__(layout=self.top_layout,
                        key_bindings=self.top_bindings,
                        style=self.top_style,
                        mouse_support=True,
                        full_screen=True,
                    )

class TopStatusItemBase:
    name = None
    title_label = None
    value_label = None

    def __init__(self, title, const_value=None):
        self.name = title.lower().replace(" ", "_")
        self.title_label = Label(text=title + ": ", dont_extend_width=True, style="bold cyan")
        if const_value is not None:
            self.value_label = Label(text=ANSI(const_value))

    def update(self):
        pass

class TopStatusItem(TopStatusItemBase):
    regs = None
    value_format_str = None
    read_callback = None

    def __init__(self, title, regs, read_callback=None, value_format_str=None, reg_val_bad=None, reg_val_good=None, reg_val_warn=None, reg_val_enum=None, is_progress_bar=False, progress_bar_range=100):
        super().__init__(title)
        self.value_format_str = value_format_str
        self.read_callback = read_callback

        def my_get_node(reg_name, idx):
            node = get_node(reg_name)
            if reg_val_bad is not None:
                node.sw_val_bad = reg_val_bad[idx] if isinstance(reg_val_bad, list) else reg_val_bad
            if reg_val_good is not None:
                node.sw_val_good = reg_val_good[idx] if isinstance(reg_val_good, list) else reg_val_good
            if reg_val_warn is not None:
                node.sw_val_warn = reg_val_warn[idx] if isinstance(reg_val_warn, list) else reg_val_warn
            if reg_val_enum is not None:
                node.sw_enum = reg_val_enum[idx] if isinstance(reg_val_enum, list) else reg_val_enum

            return node

        if read_callback is None:
            if isinstance(regs, list):
                self.regs = []
                for i in range(len(regs)):
                    reg = regs[i]
                    self.regs.append(my_get_node(reg, i))
            elif isinstance(regs, str):
                self.regs = [my_get_node(regs, 0)]
            else:
                raise ValueError("reg must be either a list of strings or a string")

        self.value_label = Label(text="")

        self.is_progress_bar = is_progress_bar
        self.progress_bar_range = progress_bar_range
        if is_progress_bar:
            self.value_label = ProgressBar()

        self.update()

    def update(self):
        if self.read_callback is not None:
            val = self.read_callback()
            if self.is_progress_bar:
                val = int(val)
                self.value_label._percentage = (val / self.progress_bar_range) * 100
                self.value_label.label.text = "%d" % val
            else:
                self.value_label.text = ANSI(val)
        elif self.value_format_str is None:
            val = read_reg(self.regs[0])
            if self.is_progress_bar:
                self.value_label._percentage = (val / self.progress_bar_range) * 100
                self.value_label.label.text = "%d" % val
            else:
                self.value_label.text = ANSI(val.to_string())
        else:
            vals = []
            for reg in self.regs:
                vals.append(read_reg(reg))
            val_str = self.value_format_str % tuple(vals)
            self.value_label.text = ANSI(val_str)

class TopStatusSection:
    title = None
    items = None
    container = None

    def __init__(self, title, items, height=D()):
        self.title = title
        self.items = {}
        title_labels = []
        value_labels = []
        for item in items:
            self.items[item.name] = item
            title_labels.append(item.title_label)
            value_labels.append(item.value_label)

        cont = VSplit([HSplit(title_labels), HSplit(value_labels)], height=height)
        self.container = Frame(title=self.title, body=cont)

    def update(self):
        for item in self.items.values():
            item.update()

class TopScreenMain(TopScreen):

    def __init__(self, gem_csc, shortcut, shortcut_label):
        super().__init__(gem_csc, None, "BEFE Main", shortcut, shortcut_label)
        self.init_container()

    def init_container(self):

        # firmware info section
        fw_info = befe.befe_get_fw_info()
        st_fw_flavor = TopStatusItemBase("Flavor", "%s for %s" % (fw_info["fw_flavor_str"], fw_info["board_type"]))
        st_fw_version = TopStatusItemBase("Version", "%s (%s %s)" % (fw_info["fw_version"], fw_info["fw_date"], fw_info["fw_time"]))
        self.sec_fw_info = TopStatusSection("Firmware Info", [st_fw_flavor, st_fw_version])

        # TTC section
        self.sec_ttc_link = TopStatusSection("TTC Link",
                                        [
                                            TopStatusItem("MMCM Locked", "BEFE.%s.TTC.STATUS.CLK.MMCM_LOCKED" % self.gem_csc),
                                            TopStatusItem("MMCM Unlock Cnt", "BEFE.%s.TTC.STATUS.CLK.MMCM_UNLOCK_CNT" % self.gem_csc),
                                            TopStatusItem("Phase Sync Done", "BEFE.%s.TTC.STATUS.CLK.SYNC_DONE" % self.gem_csc),
                                            TopStatusItem("Phase Unlock Cnt", "BEFE.%s.TTC.STATUS.CLK.PHASE_UNLOCK_CNT" % self.gem_csc),
                                            TopStatusItem("TTC Double Err Cnt", "BEFE.%s.TTC.STATUS.TTC_DOUBLE_ERROR_CNT" % self.gem_csc),
                                        ]
                                    )
        self.sec_ttc = TopStatusSection("TTC",
                                        [
                                            TopStatusItem("BC0 Locked", "BEFE.%s.TTC.STATUS.BC0.LOCKED" % self.gem_csc),
                                            TopStatusItem("BC0 Unlock Cnt", "BEFE.%s.TTC.STATUS.BC0.UNLOCK_CNT" % self.gem_csc),
                                            TopStatusItem("L1A Enabled", "BEFE.%s.TTC.CTRL.L1A_ENABLE" % self.gem_csc),
                                            TopStatusItem("CMD Enabled", "BEFE.%s.TTC.CTRL.CMD_ENABLE" % self.gem_csc),
                                            TopStatusItem("Generator Enabled", "BEFE.%s.TTC.GENERATOR.ENABLE" % self.gem_csc),
                                            TopStatusItem("Generator Running", "BEFE.%s.TTC.GENERATOR.CYCLIC_RUNNING" % self.gem_csc),
                                            TopStatusItem("L1A Rate", "BEFE.%s.TTC.L1A_RATE" % self.gem_csc),
                                            TopStatusItem("L1A ID", "BEFE.%s.TTC.L1A_ID" % self.gem_csc),
                                        ]
                                    )

        col1 = [self.sec_fw_info.container]
        col2 = [self.sec_ttc_link.container]
        col3 = [self.sec_ttc.container]

        self.container = VSplit([HSplit(col1), HSplit(col2), HSplit(col3)])

    def action(self):
        pass
        # message_dialog(
        #     title="Example dialog window",
        #     text="Do you want to continue?\nPress ENTER to quit.",self.value_label.label.text = "%d" % val
        # ).run()

class TopScreenDaq(TopScreen):

    def __init__(self, gem_csc, shortcut, shortcut_label):
        super().__init__(gem_csc, None, "DAQ", shortcut, shortcut_label)

        self.cfg_input_en_mask   = get_config("CONFIG_DAQ_INPUT_EN_MASK")
        self.cfg_ignore_daqlink  = get_config("CONFIG_DAQ_IGNORE_DAQLINK")
        self.cfg_wait_for_resync = get_config("CONFIG_DAQ_WAIT_FOR_RESYNC")
        self.cfg_freeze_on_error = get_config("CONFIG_DAQ_FREEZE_ON_ERROR")
        self.cfg_gen_local_l1a   = get_config("CONFIG_DAQ_GEN_LOCAL_L1A")
        self.cfg_fed_id          = get_config("CONFIG_DAQ_FED_ID")
        self.cfg_board_id        = get_config("CONFIG_DAQ_BOARD_ID")
        self.cfg_spy_prescale    = get_config("CONFIG_DAQ_SPY_PRESCALE")
        self.cfg_spy_skip_empty  = get_config("CONFIG_DAQ_SPY_SKIP_EMPTY")

        self.init_container()

    def init_container(self):

        # configuration section
        input_en_mask = TopStatusItem("Input Enable Mask", "BEFE.%s.DAQ.CONTROL.INPUT_ENABLE_MASK" % self.gem_csc, reg_val_bad="self != %d" % self.cfg_input_en_mask)
        ignore_daqlink = TopStatusItem("Ignore DAQLink", "BEFE.%s.DAQ.CONTROL.IGNORE_DAQLINK" % self.gem_csc, reg_val_bad="self != %d" % self.cfg_ignore_daqlink)
        wait_for_resync = TopStatusItem("Wait For Resync", "BEFE.%s.DAQ.CONTROL.RESET_TILL_RESYNC" % self.gem_csc, reg_val_bad="self != %d" % self.cfg_wait_for_resync)
        freeze_on_error = TopStatusItem("Freeze on Error", "BEFE.%s.DAQ.CONTROL.FREEZE_ON_ERROR" % self.gem_csc, reg_val_bad="self != %d" % self.cfg_freeze_on_error)
        gen_local_l1a = TopStatusItem("Generate Internal L1A", "BEFE.%s.DAQ.CONTROL.L1A_REQUEST_EN" % self.gem_csc, reg_val_bad="self != %d" % self.cfg_gen_local_l1a)
        tts_override = TopStatusItem("TTS Override", "BEFE.%s.DAQ.CONTROL.TTS_OVERRIDE" % self.gem_csc)
        fed_id = TopStatusItem("FED ID", "BEFE.%s.DAQ.CONTROL.FED_ID" % self.gem_csc, reg_val_bad="self != %d" % self.cfg_fed_id)
        board_id = TopStatusItem("RUI ID" if self.is_csc else "Board ID", "BEFE.SYSTEM.CTRL.BOARD_ID", reg_val_bad="self != %d" % self.cfg_board_id)
        dav_timeout = TopStatusItem("DAV Timeout", "BEFE.%s.DAQ.CONTROL.DAV_TIMEOUT" % self.gem_csc)
        # spy_config = TopStatusItem("Local DAQ", ["BEFE.%s.DAQ.CONTROL.SPY.SPY_PRESCALE" % self.gem_csc, "BEFE.%s.DAQ.CONTROL.SPY.SPY_SKIP_EMPTY_EVENTS" % self.gem_csc],
        #                            reg_val_bad=["self != %d" % self.cfg_spy_prescale, "self != %d" % self.cfg_spy_skip_empty],
        #                            value_format_str="Prescale %s, %s")
        spy_prescale = TopStatusItem("Local DAQ Prescale", "BEFE.%s.DAQ.CONTROL.SPY.SPY_PRESCALE" % self.gem_csc, reg_val_bad="self != %d" % self.cfg_spy_prescale)
        spy_skip_empty = TopStatusItem("Local DAQ Skip Empty", "BEFE.%s.DAQ.CONTROL.SPY.SPY_SKIP_EMPTY_EVENTS" % self.gem_csc, reg_val_bad="self != %d" % self.cfg_spy_skip_empty)

        self.sec_config = TopStatusSection("Configuration", [
                                                                input_en_mask,
                                                                ignore_daqlink,
                                                                wait_for_resync,
                                                                freeze_on_error,
                                                                gen_local_l1a,
                                                                tts_override,
                                                                fed_id,
                                                                board_id,
                                                                dav_timeout,
                                                                # spy_config,
                                                                spy_prescale,
                                                                spy_skip_empty
                                                            ], height=None)

        # state section
        self.sec_state = TopStatusSection("State",
            [
                TopStatusItem("Reset", "BEFE.%s.DAQ.CONTROL.RESET" % self.gem_csc, reg_val_bad="self == 1"),
                TopStatusItem("Enabled", "BEFE.%s.DAQ.CONTROL.DAQ_ENABLE" % self.gem_csc, reg_val_bad="self == 0"),
                TopStatusItem("Events Sent", "BEFE.%s.DAQ.STATUS.EVT_SENT" % self.gem_csc),
                TopStatusItem("LDAQ Events Sent", "BEFE.%s.DAQ.STATUS.SPY.SPY_EVENTS_SENT" % self.gem_csc),
                TopStatusItem("L1A ID", "BEFE.%s.DAQ.STATUS.L1AID" % self.gem_csc),
                TopStatusItem("DAQLink Ready", "BEFE.%s.DAQ.STATUS.DAQ_LINK_RDY" % self.gem_csc),
                TopStatusItem("TTS State", "BEFE.%s.DAQ.STATUS.TTS_STATE" % self.gem_csc),
                TopStatusItem("TTS Warning Cnt", "BEFE.%s.DAQ.STATUS.TTS_WARN_CNT" % self.gem_csc),
                TopStatusItem("Backpressure", "BEFE.%s.DAQ.STATUS.DAQ_BACKPRESSURE" % self.gem_csc),
                TopStatusItem("Backpressure Cnt", "BEFE.%s.DAQ.STATUS.DAQ_BACKPRESSURE_CNT" % self.gem_csc),
                TopStatusItem("Max DAV Timer", "BEFE.%s.DAQ.STATUS.MAX_DAV_TIMER" % self.gem_csc),
                TopStatusItem("L1A FIFO Had Overflow", "BEFE.%s.DAQ.STATUS.L1A_FIFO_HAD_OVERFLOW" % self.gem_csc),
                TopStatusItem("L1A FIFO Had Underflow", "BEFE.%s.DAQ.STATUS.L1A_FIFO_HAD_OVERFLOW" % self.gem_csc),
                TopStatusItem("L1A FIFO Near Full Cnt", "BEFE.%s.DAQ.STATUS.L1A_FIFO_NEAR_FULL_CNT" % self.gem_csc),
                TopStatusItem("L1A FIFO Had Overflow", "BEFE.%s.DAQ.STATUS.L1A_FIFO_HAD_OVERFLOW" % self.gem_csc),
                TopStatusItem("Out FIFO Had Overflow", "BEFE.%s.DAQ.STATUS.DAQ_OUTPUT_FIFO_HAD_OVERFLOW" % self.gem_csc),
                TopStatusItem("Out FIFO Near Full Cnt", "BEFE.%s.DAQ.STATUS.DAQ_FIFO_NEAR_FULL_CNT" % self.gem_csc),
                TopStatusItem("LDAQ FIFO Had Overflow", "BEFE.%s.DAQ.STATUS.SPY.ERR_SPY_FIFO_HAD_OFLOW" % self.gem_csc),
                TopStatusItem("LDAQ FIFO Near Full Cnt", "BEFE.%s.DAQ.STATUS.SPY.SPY_FIFO_AFULL_CNT" % self.gem_csc),
                TopStatusItem("LDAQ Status", None, read_callback=self.get_ldaq_state),
                TopStatusItem("L1A Rate", "BEFE.%s.TTC.L1A_RATE" % self.gem_csc),
                TopStatusItem("Output Datarate", "BEFE.%s.DAQ.STATUS.DAQ_WORD_RATE" % self.gem_csc),
                TopStatusItem("Local DAQ Datarate", "BEFE.%s.DAQ.STATUS.SPY.SPY_WORD_RATE" % self.gem_csc),
                # TopStatusItem("L1A FIFO Status", None, read_callback=self.get_l1a_fifo_state),
                TopStatusItem("L1A Rate", "BEFE.%s.TTC.L1A_RATE" % self.gem_csc, is_progress_bar=True, progress_bar_range=100000),
                TopStatusItem("Output Datarate", "BEFE.%s.DAQ.STATUS.DAQ_WORD_RATE" % self.gem_csc, is_progress_bar=True, progress_bar_range=100000000),
                TopStatusItem("Local DAQ Datarate", "BEFE.%s.DAQ.STATUS.SPY.SPY_WORD_RATE" % self.gem_csc, is_progress_bar=True, progress_bar_range=62500000),
                TopStatusItem("L1A FIFO Data Cnt", "BEFE.%s.DAQ.STATUS.L1A_FIFO_DATA_CNT" % self.gem_csc, is_progress_bar=True, progress_bar_range=8192),
                TopStatusItem("DAQ FIFO Data Cnt", "BEFE.%s.DAQ.STATUS.DAQ_FIFO_DATA_CNT" % self.gem_csc, is_progress_bar=True, progress_bar_range=8192),
            ])

        # input section

        col1 = [self.sec_config.container, self.sec_state.container]
        col2 = [self.sec_state.container]
        # col3 = [self.sec_ttc.container]

        self.container = VSplit([HSplit(col1), HSplit(col2)]) #, HSplit(col3)])

    def action(self):
        pass

    def get_ldaq_state(self):
        big_evt = read_reg("BEFE.%s.DAQ.STATUS.SPY.ERR_BIG_EVENT" % self.gem_csc)
        eoe_not_found = read_reg("BEFE.%s.DAQ.STATUS.SPY.ERR_EOE_NOT_FOUND" % self.gem_csc)
        status = ""
        if big_evt == 1:
            status += color_string("EVENT_TOO_BIG", RegVal.STATE_BAD) + " "
        if eoe_not_found == 1:
            status += color_string("EOE_NOT_FOUND", RegVal.STATE_BAD) + " "
        if len(status) == 0:
            status = color_string("NORMAL", RegVal.STATE_GOOD)
        return status

    def get_l1a_fifo_state(self):
        data_cnt = read_reg("BEFE.%s.DAQ.STATUS.L1A_FIFO_DATA_CNT" % self.gem_csc)
        if read_reg("BEFE.%s.DAQ.STATUS.L1A_FIFO_IS_UNDERFLOW" % self.gem_csc) == 1:
            return color_string("%d UNDERFLOW" % data_cnt, RegVal.STATE_BAD)
        elif read_reg("BEFE.%s.DAQ.STATUS.L1A_FIFO_IS_FULL" % self.gem_csc) == 1:
            return color_string("%d FULL" % data_cnt, RegVal.STATE_BAD)
        elif read_reg("BEFE.%s.DAQ.STATUS.L1A_FIFO_IS_NEAR_FULL" % self.gem_csc) == 1:
            return color_string("%d NEAR FULL" % data_cnt, RegVal.STATE_WARN)
        elif read_reg("BEFE.%s.DAQ.STATUS.L1A_FIFO_IS_EMPTY" % self.gem_csc) == 1:
            return color_string("%d EMPTY" % data_cnt, RegVal.STATE_GOOD)
        else:
            return color_string("%d" % data_cnt, RegVal.STATE_GOOD)

if __name__ == "__main__":
    parse_xml()
    fw_flavor = read_reg("BEFE.SYSTEM.RELEASE.FW_FLAVOR")
    gem_csc = fw_flavor.to_string(use_color=False)

    cont_oh = HSplit(
                    [
                        Label(text="OH stuff")
                        # Frame(body=Label(text="Left frame\ncontent")),
                        # Dialog(title="The custom window", body=Label("hello\ntest")),
                        # textfield,
                    ],
                    height=D(),
                )

    cont_reg = HSplit(
                    [
                        Label(text="REG interface here")
                        # Frame(body=Label(text="Left frame\ncontent")),
                        # Dialog(title="The custom window", body=Label("hello\ntest")),
                        # textfield,
                    ],
                    height=D(),
                )

    screen_main = TopScreenMain(gem_csc, "f1", "Main")
    screen_daq = TopScreenDaq(gem_csc, "f2", "DAQ")
    screen_oh = TopScreen(gem_csc, cont_oh, "GEM OptoHybrid", "f3", "OH")
    screen_reg = TopScreen(gem_csc, cont_reg, "GEM Registers", "f7", "Reg")

    screens = [screen_main, screen_daq, screen_oh, screen_reg]

    app = BefeTopApp(screens)
    app.run()
