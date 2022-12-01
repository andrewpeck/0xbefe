#!/bin/bash
echo "Welcome"
python3 /root/jessica/0xbefe/scripts/boards/x2o/physical_test.py ge21
cd /root/gem/0xbefe/scripts
source env.sh ge21 x2o 0
count=0
/root/jessica/0xbefe/scripts/boards/x2o/fan_level_3.sh
for i in {0..1}
do
  python3 $BEFE_SCRIPT_DIR/boards/x2o/program_fpga.py $BEFE_SCRIPT_DIR/resources/x2o_ge21.bit
  if [ $? -eq 0 ]; then
    ((count++))
  fi
done
echo "Successful FPGA Program Cycles: $count"
echo "Testing Reflck Frequencies"
python3 /root/jessica/0xbefe/scripts/boards/x2o/refclk_freq_monitor.py
/root/jessica/0xbefe/scripts/boards/x2o/fan_level_5.sh
sleep 30
python3 $BEFE_SCRIPT_DIR/boards/x2o/fpga_short.py $BEFE_SCRIPT_DIR/resources/hot_x2o.bit
python3 /root/jessica/0xbefe/scripts/boards/x2o/physical_test.py hot

python3 $BEFE_SCRIPT_DIR/boards/x2o/program_fpga.py $BEFE_SCRIPT_DIR/resources/x2o_ge21.bit
/root/jessica/0xbefe/scripts/boards/x2o/fan_level_3.sh
echo "Goodbye"
