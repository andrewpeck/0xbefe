#!/usr/bin/env python
"""
"""
from pygments.lexers.html import HtmlLexer

from prompt_toolkit.application import Application
from prompt_toolkit.application.current import get_app
from prompt_toolkit.completion import WordCompleter
from prompt_toolkit.key_binding import KeyBindings
from prompt_toolkit.key_binding.bindings.focus import focus_next, focus_previous
from prompt_toolkit.layout.containers import Float, HSplit, VSplit, Container, Window, FloatContainer, DynamicContainer, HorizontalAlign
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

    container = None
    title = None
    shortcut = None
    shortcut_label = None

    def __init__(self, container, title, shortcut, shortcut_label):
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

        btn_action = Button(text="F9 Action", handler=self.f_action)
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
        self.top_bindings.add("f9")(self.f_action)
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

    def __init__(self, title, regs, value_format_str=None):
        super().__init__(title)
        self.value_format_str = value_format_str
        if isinstance(regs, list):
            self.regs = []
            for reg in regs:
                self.regs.append(get_node(reg))
        elif isinstance(regs, str):
            self.regs = [get_node(regs)]
        else:
            raise ValueError("reg must be either a list of strings or a string")
        self.value_label = Label(text="")
        self.update()

    def update(self):
        if self.value_format_str is None:
            val = read_reg(self.regs[0])
            self.value_label.text = ANSI(val.to_string())
        else:
            vals = []
            for reg in regs:
                vals.append(read_reg(reg))
            val_str = self.value_format_str % tuple(vals)
            self.value_label.text = ANSI(val_str)

class TopStatusSection:
    title = None
    items = None
    container = None

    def __init__(self, title, items):
        self.title = title
        self.items = {}
        title_labels = []
        value_labels = []
        for item in items:
            self.items[item.name] = item
            title_labels.append(item.title_label)
            value_labels.append(item.value_label)

        cont = VSplit([HSplit(title_labels), HSplit(value_labels)], height=D())
        self.container = Frame(title=self.title, body=cont)

    def update(self):
        for item in self.items.values():
            item.update()

class TopScreenMain(TopScreen):
    container = None
    title = None
    shortcut = None
    shortcut_label = None

    def __init__(self, shortcut, shortcut_label):
        self.title = "BEFE Main"
        self.init_container()
        self.shortcut = shortcut
        self.shortcut_label = shortcut_label

    def init_container(self):

        # firmware info section
        fw_info = befe.befe_get_fw_info()
        st_fw_flavor = TopStatusItemBase("Flavor", "%s for %s" % (fw_info["fw_flavor_str"], fw_info["board_type"]))
        st_fw_version = TopStatusItemBase("Version", "%s (%s %s)" % (fw_info["fw_version"], fw_info["fw_date"], fw_info["fw_time"]))
        self.sec_fw_info = TopStatusSection("Firmware Info", [st_fw_flavor, st_fw_version])

        # TTC section
        self.sec_ttc_link = TopStatusSection("TTC Link",
                                        [
                                            TopStatusItem("MMCM Locked", "BEFE.GEM_AMC.TTC.STATUS.CLK.MMCM_LOCKED"),
                                            TopStatusItem("MMCM Unlock Cnt", "BEFE.GEM_AMC.TTC.STATUS.CLK.MMCM_UNLOCK_CNT"),
                                            TopStatusItem("Phase Sync Done", "BEFE.GEM_AMC.TTC.STATUS.CLK.SYNC_DONE"),
                                            TopStatusItem("Phase Unlock Cnt", "BEFE.GEM_AMC.TTC.STATUS.CLK.PHASE_UNLOCK_CNT"),
                                            TopStatusItem("TTC Double Err Cnt", "BEFE.GEM_AMC.TTC.STATUS.TTC_DOUBLE_ERROR_CNT"),
                                        ]
                                    )
        self.sec_ttc = TopStatusSection("TTC",
                                        [
                                            TopStatusItem("BC0 Locked", "BEFE.GEM_AMC.TTC.STATUS.BC0.LOCKED"),
                                            TopStatusItem("BC0 Unlock Cnt", "BEFE.GEM_AMC.TTC.STATUS.BC0.UNLOCK_CNT"),
                                            TopStatusItem("L1A Enabled", "BEFE.GEM_AMC.TTC.CTRL.L1A_ENABLE"),
                                            TopStatusItem("CMD Enabled", "BEFE.GEM_AMC.TTC.CTRL.CMD_ENABLE"),
                                            TopStatusItem("Generator Enabled", "BEFE.GEM_AMC.TTC.GENERATOR.ENABLE"),
                                            TopStatusItem("Generator Running", "BEFE.GEM_AMC.TTC.GENERATOR.CYCLIC_RUNNING"),
                                            TopStatusItem("L1A Rate", "BEFE.GEM_AMC.TTC.L1A_RATE"),
                                            TopStatusItem("L1A ID", "BEFE.GEM_AMC.TTC.L1A_ID"),
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
        #     text="Do you want to continue?\nPress ENTER to quit.",
        # ).run()


if __name__ == "__main__":
    parse_xml()

    cont_oh = HSplit(
                    [
                        Label(text="OH stuff")
                        # Frame(body=Label(text="Left frame\ncontent")),
                        # Dialog(title="The custom window", body=Label("hello\ntest")),
                        # textfield,
                    ],
                    height=D(),
                )

    cont_daq = HSplit(
                    [
                        Label(text="DAQ stuff here")
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

    screen_main = TopScreenMain("f1", "Main")
    screen_oh = TopScreen(cont_oh, "GEM OptoHybrid", "f2", "OH")
    screen_daq = TopScreen(cont_daq, "GEM DAQ", "f3", "DAQ")
    screen_reg = TopScreen(cont_reg, "GEM Registers", "f8", "Reg")

    screens = [screen_main, screen_oh, screen_daq, screen_reg]

    app = BefeTopApp(screens)
    app.run()
