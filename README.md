EMU 0xBEFE Project
========================

This repository contains firmware code for endcap muon systems (GEM and CSC)
backend and frontend electronics.

```
0xBEFE
├── Makefile
├── README.md
├── doc           ; documentation
├── regtools      ; XML to VHDL register tool
├── Hog           ; HOG build system (submodule)
├── Top           ; directory for HOG projects
├── address_table ; xml address tables
│   ├── boards    ;; board specific address tables
│   ├── common    ;; common address tables (ttc etc.)
│   └── gem       ;; GEM specific address tables
├── boards        ;; Board specific VHDL/BD/Constraints/IP
│   ├── apex
│   ├── ctp7
│   ├── cvp13
│   ├── ge11_oh
│   ├── ge21_oh
│   ├── glib
├── common        ; Common sources (GEM + CSC + OH)
│   ├── hdl
│   └── ip
├── gem           ; GEM specific sources
│   ├── hdl
│   └── ip
├── IP_repository ; Folder for packaged Xilinx IP
└── scripts       ; useful scripts
```

## Building the firmware
This firmware is using the HOG framework as a build system:
 - HOG Documentation: http://hog-user-docs.web.cern.ch
 - HOG Source Code: https://gitlab.cern.ch/hog/Hog
