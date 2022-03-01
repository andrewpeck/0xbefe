#!/bin/bash

if [ -z "$3" ]; then
    echo "Usage: source env.sh <station> <board_name> <board_index>"
    echo "    station: can be ge11, ge21, me0, or csc"
    echo "    board_name: can be cvp13, apex, apd1, ctp7"
    echo "    board_index: the index of the board or FPGA that you want to use (e.g. in APEX providing 0 means top FPGA, and 1 means bottom FPGA, this can also be used in systems with multiple CVP13 boards, see common/config.py)"
    echo "e.g.: env_gem.sh me0 cvp13 0"
else

    STATION=`echo "$1" | awk '{print tolower($0)}'`
    BOARD=`echo "$2" | awk '{print tolower($0)}'`
    BOARD_IDX=$3
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
    LIBRWREG_FILE="$SCRIPT_DIR/boards/$BOARD/rwreg/librwreg.so"
    PROJECT="gem"
    ADDR_TBL_FILE="gem_amc.xml"
    if [ $STATION == "csc" ]; then
        PROJECT="csc"
	      ADDR_TBL_FILE="csc_fed.xml"
    fi
    ADDR_TBL=$SCRIPT_DIR/../address_table/${PROJECT}/generated/${STATION}_${BOARD}/${ADDR_TBL_FILE}

    if [ ! -f "$LIBRWREG_FILE" ]; then
        echo "ERROR: $LIBRWREG_FILE does not exist, please compile the librwreg by running these commands:"
        echo "cd boards/$BOARD/rwreg"
        echo "make"
        echo "cd ../../.."
    elif [ ! -f "$ADDR_TBL" ]; then
        echo "ERROR: Address table $ADDR_TBL does not exist"
        echo "Make sure you have generated the XMLs by running these commands:"
        echo "cd .. #go to the 0xBEFE root directory"
        echo "make update_${STATION}_${BOARD}"
    else
        echo "Setting up environment for $STATION on $BOARD"
        export LD_LIBRARY_PATH=$SCRIPT_DIR/boards/$BOARD/rwreg:$LD_LIBRARY_PATH
        export PYTHONPATH=$SCRIPT_DIR:$SCRIPT_DIR/ext/tables:$SCRIPT_DIR/ext/python-prompt-toolkit
        export ADDRESS_TABLE=$ADDR_TBL
        export BOARD_TYPE=$BOARD
        export BOARD_IDX
        export BEFE_FLAVOR=$STATION
        export BEFE_SCRIPT_DIR=$SCRIPT_DIR
        echo "0xBEFE GEM environment setup done!"
    fi

fi
