#!/bin/bash

if [ -z "$2" ]; then
    echo "Usage: source env_gem.sh <station> <board_name>"
    echo "    station: can be ge11, ge21, or me0"
    echo "    board_name: can be cvp13, apex, apd1, ctp7"
    echo "e.g.: env_gem.sh me0 cvp13"
else

    STATION=`echo "$1" | awk '{print tolower($0)}'`
    BOARD=`echo "$2" | awk '{print tolower($0)}'`
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
    LIBRWREG_FILE="$SCRIPT_DIR/boards/$BOARD/rwreg/librwreg.so"
    ADDR_TBL=$SCRIPT_DIR/../address_table/gem/generated/${STATION}_${BOARD}/gem_amc.xml

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
        export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$SCRIPT_DIR/boards/$BOARD/rwreg
        export PYTHONPATH=$PYTHONPATH:$SCRIPT_DIR/common:$SCRIPT_DIR/boards/$BOARD:$SCRIPT_DIR/gem
        export ADDRESS_TABLE=$ADDR_TBL
        echo "DONE!"
    fi

fi
