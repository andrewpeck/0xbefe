#!/bin/bash
#disable tx on all qsfps
for i in {0..29}
do
  python3 $BEFE_SCRIPT_DIR/boards/x2o/x2o_utils/optic_read.py -td $i > /dev/null
done
echo "QSFP tx disabled"

for i in {0..28}
do
  python3 $BEFE_SCRIPT_DIR/boards/x2o/x2o_utils/optic_read.py -te $i
  python3 $BEFE_SCRIPT_DIR/boards/x2o/x2o_utils/optic_read.py -vit100all
  python3 $BEFE_SCRIPT_DIR/boards/x2o/x2o_utils/prbs.py enable
done

#re-enable transmission on all qsfps
for i in {0..29}
do
  python3 $BEFE_SCRIPT_DIR/boards/x2o/x2o_utils/optic_read.py -te $i > /dev/null
done
echo "QSFP reset, goodbye"
