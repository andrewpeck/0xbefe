#!/usr/bin/env python
"""
"""
#from pygments.lexers.html import HtmlLexer

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

import sys
import asyncio

from utils import *

# remote
if len(sys.argv) > 1:
    hostname = sys.argv[1]
    heading("Connecting to %s" % hostname)
    import rpyc
    conn = rpyc.classic.connect(hostname)
    conn._config["sync_request_timeout"] = 240
    rw = conn.modules["common.rw_reg"]
    befe = conn.modules["common.fw_utils"]

# local
else:
    heading("Running locally")
    import common.rw_reg as rw
    import common.fw_utils as befe


SLEEP_BETWEEN_UPDATES = 0.001 # time to sleep between each item update to give time for the UI to do other things so it doesn't feel so sluggish

class TopScreen:

    app = None        # set by the pap
    screen_idx = None # set by the app

    gem_csc = None    # "GEM" or "CSC_FED"
    is_gem = None     # bool
    is_csc = None     # bool

    container = None
    title = None
    shortcut = None
    shortcut_label = None
    sections = None

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

        self.sections = []
        self.container = container
        self.title = title
        self.shortcut = shortcut
        self.shortcut_label = shortcut_label

    def screen_sel(self, event=None):
        self.app.screen_sel(self.screen_idx)

    async def update(self):
        for sec in self.sections:
            await sec.update()

    # should return a float to show, and also an element to focus
    def action(self):
        def btn_ok_handler():
            self.app.remove_floats()

        btn_ok = Button(text="OK", handler=btn_ok_handler)

        dialog = Dialog(
            title="%s Actions" % self.title,
            body=Label(text="No actions are supported on this screen", dont_extend_height=True),
            buttons=[btn_ok]
        )
        return Float(content=dialog), btn_ok

class BefeTopApp(Application):

    top_screens = []
    top_screen = None
    screen_idx = 0
    screen_sel_buttons = []
    floats = []
    update_task = None

    lbl_screen = None
    top_layout = None

    def get_top_screen(self):
        return self.top_screens[self.screen_idx]

    def get_top_screen_container(self):
        return self.get_top_screen().container

    def screen_sel(self, screen_idx):
        self.screen_idx = screen_idx
        self.lbl_screen.text = self.top_screens[screen_idx].title
        self.top_layout.focus(self.screen_sel_buttons[screen_idx])

    def f_exit(self, event=None):
        get_app().exit()

    def f_action(self, event=None):
        if len(self.floats) != 0:
            self.remove_floats()

        fl, item_to_focus = self.get_top_screen().action()
        if fl is not None:
            self.floats.append(fl)
            if item_to_focus is not None:
                self.top_layout.focus(item_to_focus)

    def remove_floats(self):
        self.floats.clear()

    def init_layout(self):
        for i in range(len(self.top_screens)):
            s = self.top_screens[i]
            s.app = self
            s.screen_idx = i
            self.screen_sel_buttons.append(Button(text="%s %s" % (s.shortcut.upper(), s.shortcut_label), handler=s.screen_sel))

        self.lbl_screen = Label(text=self.top_screens[0].title)

        self.top_screen = DynamicContainer(self.get_top_screen_container)

        btn_action = Button(text="F8 Action", handler=self.f_action)
        btn_exit = Button(text="F10 Exit", handler=self.f_exit)

        self.root_container = FloatContainer(
            HSplit(
                [
                    Box(
                        body=VSplit([self.lbl_screen], align="CENTER", padding=3),
                        style="class:button-bar",
                        height=1,
                    ),
                    self.top_screen,
                    Box(
                        body=VSplit(self.screen_sel_buttons + [btn_action, btn_exit], align="CENTER", padding=3),
                        style="class:button-bar",
                        height=1,
                    ),
                ]
            ),
            self.floats
        )
        self.top_layout = Layout(self.root_container, focused_element=self.screen_sel_buttons[0])

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

    def do_refresh(self, app):
        if self.update_task is None or self.update_task.done():
            self.update_task = self.create_background_task(self.update_contents())

    async def update_contents(self):
        await self.top_screens[self.screen_idx].update()

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
                        refresh_interval=1,
                        # before_render=self.do_refresh
                        after_render=self.do_refresh
                    )

class TopStatusItemBase:
    name = None
    title_label = None
    value_label = None

    def __init__(self, title, const_value=None, label_col="cyan", extend_label_width=False):
        if title is not None:
            self.name = title.lower().replace(" ", "_")
            self.title_label = Label(text=title + ": ", dont_extend_width=not extend_label_width, style="bold %s" % label_col)
        if const_value is not None:
            self.value_label = Label(text=ANSI(const_value))

    def update(self):
        pass

class TopStatusItem(TopStatusItemBase):
    regs = None
    value_format_str = None
    read_callback = None

    def __init__(self, title, regs, read_callback=None, read_callback_params=None, value_format_str=None, extend_label_width=False, label_col="cyan", reg_val_bad=None, reg_val_good=None, reg_val_warn=None, reg_val_enum=None, is_progress_bar=False, progress_bar_range=100):
        super().__init__(title, extend_label_width=extend_label_width, label_col=label_col)
        self.value_format_str = value_format_str
        self.read_callback = read_callback
        self.read_callback_params = read_callback_params

        def my_get_node(reg_name, idx):
            node = rw.get_node(reg_name)
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
            val = self.read_callback() if self.read_callback_params is None else self.read_callback(self.read_callback_params)
            if self.is_progress_bar:
                val = int(val)
                val_percent = (val / self.progress_bar_range) * 100
                self.value_label._percentage = val_percent if val_percent <= 100.0 else 100.0
                self.value_label.label.text = "%d" % val
            else:
                self.value_label.text = ANSI(val)
        elif self.value_format_str is None:
            val = rw.read_reg(self.regs[0], verbose=False)
            if self.is_progress_bar:
                val_percent = (val / self.progress_bar_range) * 100
                self.value_label._percentage = val_percent if val_percent <= 100.0 else 100.0
                self.value_label.label.text = "%d" % val
            else:
                self.value_label.text = ANSI(val.to_string())
        else:
            vals = []
            for reg in self.regs:
                vals.append(rw.read_reg(reg, verbose=False))
            val_str = self.value_format_str % tuple(vals)
            self.value_label.text = ANSI(val_str)

class TopInputTextItem(TopStatusItemBase):

    def __init__(self, title, default_value, extend_label_width=False, label_col="blue"):
        super().__init__(title, extend_label_width=extend_label_width, label_col=label_col)
        self.value_label = TextArea(text=str(default_value))

    def get_value(self):
        return self.value_label.text

    def get_int_value(self):
        return int(self.get_value())

class TopInputBoolItem(TopStatusItemBase):

    def __init__(self, title, default_value, extend_label_width=False, label_col="blue"):
        super().__init__(title, extend_label_width=extend_label_width, label_col=label_col)
        self.value_label = Checkbox(checked=default_value)

    def get_value(self):
        return self.value_label.checked

    def get_int_value(self):
        return int(self.get_value())

class TopSection:
    title = None
    items = None
    container = None

    def __init__(self, title, items, height=D(), use_frame=True):
        self.title = title
        self.items = {}
        title_labels = []
        value_labels = []
        for item in items:
            if item.name in self.items:
                item.name += "_1"
            self.items[item.name] = item
            title_labels.append(item.title_label)
            value_labels.append(item.value_label)

        cont = VSplit([HSplit(title_labels), HSplit(value_labels)], height=height, width=D())

        if use_frame:
            self.container = Frame(title=self.title, body=cont)
        else:
            title_label = Label(text="------- " + title + " -------", dont_extend_width=True, style="bold blue")
            self.container = HSplit([
                                        title_label,
                                        cont
                                    ])

    async def update(self):
        for item in self.items.values():
            item.update()
            await asyncio.sleep(SLEEP_BETWEEN_UPDATES) #give some time for the UI to do other things between the updates of each item

class TopTableSection:
    title = None
    col_titles = None
    row_items = None
    container = None

    def __init__(self, title, col_titles, row_items, height=D()):
        self.title = title
        self.col_titles
        self.row_items = row_items

        # add index column
        cols = []
        idx_col = [Label(text="Idx", dont_extend_width=True, style="bold cyan")]
        for row_idx in range(len(row_items)):
            idx_col.append(Label(text="%d" % row_idx, dont_extend_width=True, style="bold cyan"))
        cols.append(idx_col)

        # add value columns
        for col_idx in range(len(col_titles)):
            col = [Label(text=col_titles[col_idx], dont_extend_width=True, style="bold cyan")]
            for row in row_items:
                item = row[col_idx]
                col.append(item.value_label)
            cols.append(col)

        # create column containers
        col_conts = []
        for col in cols:
            col_cont = HSplit(col)
            col_conts.append(col_cont)

        # create the main container
        cont = VSplit(col_conts, height=height, width=D(), padding=3, padding_char=" ")
        self.container = Frame(title=self.title, body=cont)

    async def update(self):
        for row in self.row_items:
            for item in row:
                item.update()
                await asyncio.sleep(SLEEP_BETWEEN_UPDATES) #give some time for the UI to do other things between the updates of each item

class TopScreenMain(TopScreen):

    def __init__(self, gem_csc, shortcut, shortcut_label):
        super().__init__(gem_csc, None, "BEFE Main", shortcut, shortcut_label)
        self.cfg_use_tcds        = get_config("CONFIG_USE_TCDS")
        self.init_container()

    def init_container(self):

        # firmware info section
        fw_info = befe.befe_get_fw_info()
        st_fw_flavor = TopStatusItemBase("Flavor", "%s for %s" % (fw_info["fw_flavor_str"], fw_info["board_type"]))
        st_fw_version = TopStatusItemBase("Version", "%s (%s %s)" % (fw_info["fw_version"], fw_info["fw_date"], fw_info["fw_time"]))
        self.sec_fw_info = TopSection("Firmware Info", [st_fw_flavor, st_fw_version])

        # TTC section
        self.sec_ttc_link = TopSection("TTC Link",
                                        [
                                            TopStatusItem("MMCM Locked", "BEFE.%s.TTC.STATUS.CLK.MMCM_LOCKED" % self.gem_csc),
                                            TopStatusItem("MMCM Unlock Cnt", "BEFE.%s.TTC.STATUS.CLK.MMCM_UNLOCK_CNT" % self.gem_csc),
                                            TopStatusItem("Phase Sync Done", "BEFE.%s.TTC.STATUS.CLK.SYNC_DONE" % self.gem_csc),
                                            TopStatusItem("Phase Unlock Cnt", "BEFE.%s.TTC.STATUS.CLK.PHASE_UNLOCK_CNT" % self.gem_csc),
                                            TopStatusItem("TTC Double Err Cnt", "BEFE.%s.TTC.STATUS.TTC_DOUBLE_ERROR_CNT" % self.gem_csc),
                                        ]
                                    )
        self.sec_ttc = TopSection("TTC",
                                        [
                                            TopStatusItem("BC0 Locked", "BEFE.%s.TTC.STATUS.BC0.LOCKED" % self.gem_csc),
                                            TopStatusItem("BC0 Unlock Cnt", "BEFE.%s.TTC.STATUS.BC0.UNLOCK_CNT" % self.gem_csc),
                                            TopStatusItem("L1A Enabled", "BEFE.%s.TTC.CTRL.L1A_ENABLE" % self.gem_csc),
                                            TopStatusItem("CMD Enabled", "BEFE.%s.TTC.CTRL.CMD_ENABLE" % self.gem_csc, reg_val_warn="self != %d" % int(self.cfg_use_tcds)),
                                            TopStatusItem("Generator Enabled", "BEFE.%s.TTC.GENERATOR.ENABLE" % self.gem_csc),
                                            TopStatusItem("Generator Running", "BEFE.%s.TTC.GENERATOR.CYCLIC_RUNNING" % self.gem_csc),
                                            TopStatusItem("L1A Rate", "BEFE.%s.TTC.L1A_RATE" % self.gem_csc),
                                            TopStatusItem("L1A ID", "BEFE.%s.TTC.L1A_ID" % self.gem_csc),
                                        ]
                                    )

        # register sections
        self.sections = [self.sec_fw_info, self.sec_ttc_link, self.sec_ttc]

        # setup the overal layout
        col1 = [self.sec_fw_info.container]
        col2 = [self.sec_ttc_link.container]
        col3 = [self.sec_ttc.container]

        self.container = VSplit([HSplit(col1), HSplit(col2), HSplit(col3)])

    def action(self):
        return super().action()

class TopScreenDaq(TopScreen):

    dmb_oh = None
    state = color_string("Initial", rw.RegVal.STATE_BAD)

    def __init__(self, gem_csc, shortcut, shortcut_label):
        super().__init__(gem_csc, None, "DAQ", shortcut, shortcut_label)

        self.cfg_input_en_mask   = get_config("CONFIG_DAQ_INPUT_EN_MASK")
        self.cfg_ignore_daqlink  = get_config("CONFIG_DAQ_IGNORE_DAQLINK")
        self.cfg_wait_for_resync = get_config("CONFIG_DAQ_WAIT_FOR_RESYNC")
        self.cfg_freeze_on_error = get_config("CONFIG_DAQ_FREEZE_ON_ERROR")
        self.cfg_fed_id          = get_config("CONFIG_DAQ_FED_ID")
        self.cfg_board_id        = get_config("CONFIG_DAQ_BOARD_ID")
        self.cfg_spy_prescale    = get_config("CONFIG_DAQ_SPY_PRESCALE")
        self.cfg_spy_skip_empty  = get_config("CONFIG_DAQ_SPY_SKIP_EMPTY")
        self.cfg_use_tcds        = get_config("CONFIG_USE_TCDS")

        self.dmb_oh = "DMB" if self.is_csc else "OH" if self.is_gem else None

        self.init_container()

    def init_container(self):

        # configuration section
        state = TopStatusItem("State", None, read_callback=self.get_state)
        input_en_mask = TopStatusItem("Input Enable Mask", "BEFE.%s.DAQ.CONTROL.INPUT_ENABLE_MASK" % self.gem_csc, reg_val_bad="self != %d" % self.cfg_input_en_mask)
        ignore_daqlink = TopStatusItem("Ignore DAQLink", "BEFE.%s.DAQ.CONTROL.IGNORE_DAQLINK" % self.gem_csc, reg_val_bad="self != %d" % self.cfg_ignore_daqlink)
        wait_for_resync = TopStatusItem("Wait For Resync", "BEFE.%s.DAQ.CONTROL.RESET_TILL_RESYNC" % self.gem_csc, reg_val_bad="self != %d" % self.cfg_wait_for_resync)
        freeze_on_error = TopStatusItem("Freeze on Error", "BEFE.%s.DAQ.CONTROL.FREEZE_ON_ERROR" % self.gem_csc, reg_val_bad="self != %d" % self.cfg_freeze_on_error)
        if self.is_csc:
            gen_local_l1a = TopStatusItem("Generate Internal L1A", "BEFE.%s.DAQ.CONTROL.L1A_REQUEST_EN" % self.gem_csc, reg_val_bad="self != %d" % int(not self.cfg_use_tcds))
            spy_skip_empty = TopStatusItem("Local DAQ Skip Empty", "BEFE.%s.DAQ.CONTROL.SPY.SPY_SKIP_EMPTY_EVENTS" % self.gem_csc, reg_val_bad="self != %d" % self.cfg_spy_skip_empty)
        tts_override = TopStatusItem("TTS Override", "BEFE.%s.DAQ.CONTROL.TTS_OVERRIDE" % self.gem_csc)
        fed_id = TopStatusItem("FED ID", "BEFE.%s.DAQ.CONTROL.FED_ID" % self.gem_csc, reg_val_bad="self != %d" % self.cfg_fed_id)
        board_id = TopStatusItem("RUI ID" if self.is_csc else "Board ID", "BEFE.SYSTEM.CTRL.BOARD_ID", reg_val_bad="self != %d" % self.cfg_board_id)
        dav_timeout = TopStatusItem("DAV Timeout", "BEFE.%s.DAQ.CONTROL.DAV_TIMEOUT" % self.gem_csc)
        # spy_config = TopStatusItem("Local DAQ", ["BEFE.%s.DAQ.CONTROL.SPY.SPY_PRESCALE" % self.gem_csc, "BEFE.%s.DAQ.CONTROL.SPY.SPY_SKIP_EMPTY_EVENTS" % self.gem_csc],
        #                            reg_val_bad=["self != %d" % self.cfg_spy_prescale, "self != %d" % self.cfg_spy_skip_empty],
        #                            value_format_str="Prescale %s, %s")
        spy_prescale = TopStatusItem("Local DAQ Prescale", "BEFE.%s.DAQ.CONTROL.SPY.SPY_PRESCALE" % self.gem_csc, reg_val_bad="self != %d" % self.cfg_spy_prescale)


        config_items = []
        if self.is_csc:
            config_items = [state, input_en_mask, ignore_daqlink, wait_for_resync, freeze_on_error, gen_local_l1a, tts_override, fed_id, board_id, dav_timeout, spy_prescale, spy_skip_empty]
        if self.is_gem:
            config_items = [state, input_en_mask, ignore_daqlink, wait_for_resync, freeze_on_error, tts_override, fed_id, board_id, dav_timeout, spy_prescale]

        self.sec_config = TopSection("Configuration", config_items, height=None)

        # state section
        self.sec_state = TopSection("State",
            [
                TopStatusItem("Reset", "BEFE.%s.DAQ.CONTROL.RESET" % self.gem_csc, reg_val_bad="self == 1"),
                TopStatusItem("Enabled", "BEFE.%s.DAQ.CONTROL.DAQ_ENABLE" % self.gem_csc, reg_val_bad="self == 0"),
                TopStatusItem("L1A Enabled", "BEFE.%s.TTC.CTRL.L1A_ENABLE" % self.gem_csc),
                TopStatusItem("BC0 Locked", "BEFE.%s.TTC.STATUS.BC0.LOCKED" % self.gem_csc),
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
        num_inputs = 0
        if self.is_csc:
            num_inputs = rw.read_reg("BEFE.CSC_FED.CSC_SYSTEM.RELEASE.NUM_OF_DMBS", verbose=False)
        elif self.is_gem:
            num_inputs = rw.read_reg("BEFE.GEM.GEM_SYSTEM.RELEASE.NUM_OF_OH", verbose=False)
        else:
            raise ValueError("It's not GEM nor CSC hmm")

        if num_inputs == 0xdeaddead:
            num_inputs = 0

        col_titles = ["TTS State", "Status", "EvN", "Bitrate", "In Warn", "Evt Warn", "In FIFO", "Evt FIFO"]
        rows = []
        for input in range(num_inputs):
            si_tts_state = TopStatusItem(None, "BEFE.%s.DAQ.%s%d.STATUS.TTS_STATE" % (self.gem_csc, self.dmb_oh, input))
            si_input_status = TopStatusItem(None, None, read_callback=self.get_input_status, read_callback_params={"idx": input})
            si_evn = TopStatusItem(None, "BEFE.%s.DAQ.%s%d.COUNTERS.EVN" % (self.gem_csc, self.dmb_oh, input))
            if self.is_csc:
                si_data_rate = TopStatusItem(None, "BEFE.%s.DAQ.%s%d.COUNTERS.DATA_WORD_RATE" % (self.gem_csc, self.dmb_oh, input))
            elif self.is_gem:
                si_data_rate = TopStatusItem(None, "BEFE.%s.DAQ.%s%d.COUNTERS.VFAT_BLOCK_RATE" % (self.gem_csc, self.dmb_oh, input))
            si_infifo_warn_cnt = TopStatusItem(None, "BEFE.%s.DAQ.%s%d.COUNTERS.INPUT_FIFO_NEAR_FULL_CNT" % (self.gem_csc, self.dmb_oh, input))
            si_evtfifo_warn_cnt = TopStatusItem(None, "BEFE.%s.DAQ.%s%d.COUNTERS.EVT_FIFO_NEAR_FULL_CNT" % (self.gem_csc, self.dmb_oh, input))
            si_infifo_data_cnt = TopStatusItem(None, "BEFE.%s.DAQ.%s%d.COUNTERS.INPUT_FIFO_DATA_CNT" % (self.gem_csc, self.dmb_oh, input), is_progress_bar=True, progress_bar_range=16384)
            si_evtfifo_data_cnt = TopStatusItem(None, "BEFE.%s.DAQ.%s%d.COUNTERS.EVT_FIFO_DATA_CNT" % (self.gem_csc, self.dmb_oh, input), is_progress_bar=True, progress_bar_range=4096)

            row = [
                si_tts_state,
                si_input_status,
                si_evn,
                si_data_rate,
                si_infifo_warn_cnt,
                si_evtfifo_warn_cnt,
                si_infifo_data_cnt,
                si_evtfifo_data_cnt,
            ]
            rows.append(row)

        self.sec_inputs = TopTableSection("Inputs", col_titles, rows)

        # register sections
        self.sections = [self.sec_config, self.sec_state, self.sec_inputs]

        # setup the overal layout
        col1 = [self.sec_config.container, self.sec_state.container]
        col2 = [self.sec_inputs.container]
        # col3 = [self.sec_ttc.container]

        self.container = VSplit([HSplit(col1), HSplit(col2)]) #, HSplit(col3)])

    def action(self):
        input_mask = TopInputTextItem("Input Mask", self.cfg_input_en_mask, extend_label_width=True)
        fed_id = TopInputTextItem("FED ID", self.cfg_fed_id, extend_label_width=True)
        board_id = TopInputTextItem("Board ID", self.cfg_board_id, extend_label_width=True)
        ldaq_prescale = TopInputTextItem("LDAQ Prescale", self.cfg_spy_prescale, extend_label_width=True)
        ignore_daqlink = TopInputBoolItem("Ignore DAQLink", self.cfg_ignore_daqlink, extend_label_width=True)
        wait_for_resync = TopInputBoolItem("Reset till Resync", self.cfg_wait_for_resync, extend_label_width=True)
        freeze_on_error = TopInputBoolItem("Freeze on TTS Error", self.cfg_freeze_on_error, extend_label_width=True)
        ldaq_skip_empty = TopInputBoolItem("LDAQ skip empty", self.cfg_spy_skip_empty, extend_label_width=True)
        use_tcds = TopInputBoolItem("Use TCDS", self.cfg_use_tcds, extend_label_width=True)

        config_sec = TopSection("Configuration",
                                [
                                    input_mask,
                                    fed_id,
                                    board_id,
                                    ldaq_prescale,
                                    ignore_daqlink,
                                    wait_for_resync,
                                    freeze_on_error,
                                    ldaq_skip_empty,
                                    use_tcds,
                                ],
                                height=None,
                                use_frame=False)

        def btn_cancel_handler():
            self.app.remove_floats()

        def btn_config_handler():
            rw.write_reg('BEFE.%s.TTC.CTRL.MODULE_RESET' % self.gem_csc, 0x1)
            rw.write_reg('BEFE.%s.TTC.CTRL.L1A_ENABLE' % self.gem_csc, 0x0)
            if self.is_csc:
                rw.write_reg('BEFE.%s.TEST.GBE_TEST.ENABLE' % self.gem_csc, 0x0)
            rw.write_reg('BEFE.%s.DAQ.CONTROL.DAQ_ENABLE' % self.gem_csc, 0x0)

            if use_tcds.get_value():
                rw.write_reg('BEFE.%s.TTC.CTRL.CMD_ENABLE' % self.gem_csc, 1)
                rw.write_reg('BEFE.%s.TTC.GENERATOR.ENABLE' % self.gem_csc, 0)
                if self.is_csc:
                    rw.write_reg('BEFE.%s.DAQ.CONTROL.L1A_REQUEST_EN' % self.gem_csc, 0)
            else:
                rw.write_reg('BEFE.%s.TTC.CTRL.CMD_ENABLE' % self.gem_csc, 0)
                rw.write_reg('BEFE.%s.TTC.GENERATOR.ENABLE' % self.gem_csc, 1)
                if self.is_csc:
                    rw.write_reg('BEFE.%s.DAQ.CONTROL.L1A_REQUEST_EN' % self.gem_csc, 1)

            rw.write_reg('BEFE.SYSTEM.CTRL.BOARD_ID', board_id.get_int_value())
            rw.write_reg('BEFE.%s.DAQ.CONTROL.INPUT_ENABLE_MASK' % self.gem_csc, input_mask.get_int_value())
            rw.write_reg('BEFE.%s.DAQ.CONTROL.IGNORE_DAQLINK' % self.gem_csc, ignore_daqlink.get_int_value())
            rw.write_reg('BEFE.%s.DAQ.CONTROL.FREEZE_ON_ERROR' % self.gem_csc, freeze_on_error.get_int_value())
            rw.write_reg('BEFE.%s.DAQ.CONTROL.RESET_TILL_RESYNC' % self.gem_csc, wait_for_resync.get_int_value())
            if self.is_csc:
                rw.write_reg('BEFE.%s.DAQ.CONTROL.SPY.SPY_SKIP_EMPTY_EVENTS' % self.gem_csc, ldaq_skip_empty.get_int_value())
            rw.write_reg('BEFE.%s.DAQ.CONTROL.SPY.SPY_PRESCALE' % self.gem_csc, ldaq_prescale.get_int_value())
            rw.write_reg('BEFE.%s.DAQ.CONTROL.RESET' % self.gem_csc, 0x1)
            rw.write_reg('BEFE.%s.DAQ.LAST_EVENT_FIFO.DISABLE' % self.gem_csc, 0x0)

            self.state = color_string("Configured", rw.RegVal.STATE_WARN)
            self.app.remove_floats()

        def btn_start_handler():
            if "Configured" not in self.state:
                btn_config_handler()

            rw.write_reg('BEFE.%s.DAQ.CONTROL.RESET' % self.gem_csc, 0x1)
            rw.write_reg('BEFE.%s.DAQ.CONTROL.DAQ_ENABLE' % self.gem_csc, 0x1)
            rw.write_reg('BEFE.%s.TTC.CTRL.L1A_ENABLE' % self.gem_csc, 0x1)
            rw.write_reg('BEFE.%s.DAQ.CONTROL.RESET' % self.gem_csc, 0x0)

            self.state = color_string("Running", rw.RegVal.STATE_GOOD)
            self.app.remove_floats()

        def btn_stop_handler():
            rw.write_reg('BEFE.%s.DAQ.CONTROL.DAQ_ENABLE' % self.gem_csc, 0x0)
            rw.write_reg('BEFE.%s.TTC.CTRL.L1A_ENABLE' % self.gem_csc, 0x0)

            self.state = color_string("Configured", rw.RegVal.STATE_WARN)
            self.app.remove_floats()

        btn_cancel = Button(text="Cancel", handler=btn_cancel_handler)
        btn_config = Button(text="Configure", handler=btn_config_handler)
        btn_start = Button(text="Start", handler=btn_start_handler)
        btn_stop = Button(text="Stop", handler=btn_stop_handler)

        dialog = Dialog(
            title="DAQ Actions",
            body=config_sec.container,
            # body=Label(text="Please choose an action below", dont_extend_height=True),
            buttons=[btn_config, btn_start, btn_stop, btn_cancel]
        )
        return Float(content=dialog), btn_cancel

    # def action_configure(self):
    #     self.state = color_string("Configured", rw.RegVal.STATE_WARN)
    #
    # def action_start(self):
    #     if "Configured" not in self.state:
    #         action_configure()
    #     self.state = color_string("Running", rw.RegVal.STATE_GOOD)
    #
    # def action_stop(self):
    #     self.state = color_string("Configured", rw.RegVal.STATE_WARN)

    def get_state(self):
        return self.state

    def get_ldaq_state(self):
        big_evt = rw.read_reg("BEFE.%s.DAQ.STATUS.SPY.ERR_BIG_EVENT" % self.gem_csc, verbose=False)
        eoe_not_found = rw.read_reg("BEFE.%s.DAQ.STATUS.SPY.ERR_EOE_NOT_FOUND" % self.gem_csc, verbose=False)
        if 0xdeaddead in [big_evt, eoe_not_found]:
            return color_string("BUS_ERROR", rw.RegVal.STATE_BAD)

        status = ""
        if big_evt == 1:
            status += color_string("EVENT_TOO_BIG", rw.RegVal.STATE_BAD) + " "
        if eoe_not_found == 1:
            status += color_string("EOE_NOT_FOUND", rw.RegVal.STATE_BAD) + " "
        if len(status) == 0:
            status = color_string("NORMAL", rw.RegVal.STATE_GOOD)
        return status

    def get_l1a_fifo_state(self):
        data_cnt = rw.read_reg("BEFE.%s.DAQ.STATUS.L1A_FIFO_DATA_CNT" % self.gem_csc, verbose=False)
        unf = rw.read_reg("BEFE.%s.DAQ.STATUS.L1A_FIFO_IS_UNDERFLOW" % self.gem_csc, verbose=False)
        full = rw.read_reg("BEFE.%s.DAQ.STATUS.L1A_FIFO_IS_FULL" % self.gem_csc, verbose=False)
        afull = rw.read_reg("BEFE.%s.DAQ.STATUS.L1A_FIFO_IS_NEAR_FULL" % self.gem_csc, verbose=False)
        empty = rw.read_reg("BEFE.%s.DAQ.STATUS.L1A_FIFO_IS_EMPTY" % self.gem_csc, verbose=False)

        if 0xdeaddead in [data_cnt, unf, full, afull, empty]:
            return color_string("BUS_ERROR", rw.RegVal.STATE_BAD)

        if unf == 1:
            return color_string("%d UNDERFLOW" % data_cnt, rw.RegVal.STATE_BAD)
        elif full == 1:
            return color_string("%d FULL" % data_cnt, rw.RegVal.STATE_BAD)
        elif afull == 1:
            return color_string("%d NEAR FULL" % data_cnt, rw.RegVal.STATE_WARN)
        elif empty == 1:
            return color_string("%d EMPTY" % data_cnt, rw.RegVal.STATE_GOOD)
        else:
            return color_string("%d" % data_cnt, rw.RegVal.STATE_GOOD)

    def get_input_status(self, params):
        idx = params["idx"]

        in_mask = rw.read_reg('BEFE.%s.DAQ.CONTROL.INPUT_ENABLE_MASK' % self.gem_csc, verbose=False)
        in_ovf = rw.read_reg("BEFE.%s.DAQ.%s%d.STATUS.INPUT_FIFO_HAD_OFLOW" % (self.gem_csc, self.dmb_oh, idx), verbose=False)
        in_unf = rw.read_reg("BEFE.%s.DAQ.%s%d.STATUS.INPUT_FIFO_HAD_UFLOW" % (self.gem_csc, self.dmb_oh, idx), verbose=False)
        evt_ovf = rw.read_reg("BEFE.%s.DAQ.%s%d.STATUS.EVENT_FIFO_HAD_OFLOW" % (self.gem_csc, self.dmb_oh, idx), verbose=False)
        evt_size_err = rw.read_reg("BEFE.%s.DAQ.%s%d.STATUS.EVT_SIZE_ERR" % (self.gem_csc, self.dmb_oh, idx), verbose=False)
        evt_64b_err = rw.read_reg("BEFE.%s.DAQ.%s%d.STATUS.EVT_64BIT_ALIGN_ERR" % (self.gem_csc, self.dmb_oh, idx), verbose=False) if self.is_csc else 0

        if 0xdeaddead in [in_mask, in_ovf, in_unf, evt_ovf, evt_size_err, evt_64b_err]:
            return color_string("BUS_ERROR", rw.RegVal.STATE_BAD)

        if (in_mask >> idx) & 1 == 0:
            return "DISABLED"

        status = ""
        if in_ovf == 1:
            status += color_string("IN_OVF ", rw.RegVal.STATE_BAD)
        if in_unf == 1:
            status += color_string("IN_UNF ", rw.RegVal.STATE_BAD)
        if evt_ovf == 1:
            status += color_string("EVT_OVF ", rw.RegVal.STATE_BAD)
        if evt_size_err == 1:
            status += color_string("SIZE_ERR ", rw.RegVal.STATE_BAD)
        if evt_64b_err == 1:
            status += color_string("64BIT_ERR ", rw.RegVal.STATE_BAD)

        if len(status) == 0:
            status = color_string("OK", rw.RegVal.STATE_GOOD)

        return status

if __name__ == "__main__":
    rw.parse_xml()
    fw_flavor = rw.read_reg("BEFE.SYSTEM.RELEASE.FW_FLAVOR")
    if fw_flavor == 0xdeaddead:
        exit()

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
