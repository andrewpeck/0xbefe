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
│   ├── befe      ;; common address tables (ttc etc.)
│   ├── csc       ;; CSC specific address tables
│   └── gem       ;; GEM specific address tables
├── boards        ;; Board specific VHDL/BD/Constraints/IP
│   ├── apex
│   ├── ctp7
│   ├── cvp13
│   ├── ge11_oh
│   ├── ge21_oh
│   ├── glib      ; GLIB support dropped
│   └── x2o
├── common        ; Common sources (GEM + CSC + OH)
│   ├── hdl
│   └── ip
├── gem           ; GEM specific sources
│   ├── hdl
│   └── ip
├── csc           ; CSC specific sources
│   ├── hdl
│   └── ip
├── IP_repository ; Folder for packaged Xilinx IP
└── scripts       ; useful scripts
```

## Building the firmware

This firmware is using the HOG framework as a build system:
 - HOG Documentation: http://hog-user-docs.web.cern.ch
 - HOG Source Code: https://gitlab.cern.ch/hog/Hog

HOG allows for multiple projects to happily coexist within a single repository,
allowing sharing of source code between OH + GEM backend + CSC FED, as well as
managing the deployment to the numerous hardware platforms that are supported.

In general, the process to build firmware from a fresh checkout consists of: 

``` sh
# shortcut to initialize git submodules
make init 
# creates a Vivado / ISE project 
make create_<project_name>
# Launch synthesis + implementation + bitstream generation
make impl_<project_name>

# Alternatively the above can be achieved by:
# creates a Vivado / ISE project 
Hog/CreateProject.sh <project name> 
# Launches synthesis + implementation 
Hog/LaunchWorkflow.sh <project name> 
```

The available projects can be seen as directories in the `Top/` folder. HOG will
also report a list of projects if you type `Hog/CreateProject.sh` without a
project name.
