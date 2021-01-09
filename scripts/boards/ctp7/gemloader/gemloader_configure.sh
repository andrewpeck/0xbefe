#!/bin/sh

LOAD_BIT_FILE=/mnt/persistent/gemdaq/oh_fw/optohybrid_top.bit
SIZE_BIT_FILE=$(stat -c %s $(readlink -f /mnt/persistent/gemdaq/oh_fw/optohybrid_top.bit) )

echo "Loading $LOAD_BIT_FILE with size $SIZE_BIT_FILE bytes"
gemloader load $LOAD_BIT_FILE

mpoke 0x6a000000 1              #enable the loader fw core
mpoke 0x6a000004 $SIZE_BIT_FILE #number of bytes to load
