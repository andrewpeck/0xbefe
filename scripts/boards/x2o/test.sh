#!/bin/bash
echo "Welcome"
JSDIR="/root/jessica/0xbefe/scripts/boards/x2o"
RUN_N=1
DATE=$(date +"%Y-%m-%d")

#Start physical baseline test
cd $JSDIR/../..
source env.sh csc x2o 0
python3 $JSDIR/physical_test.py csc
if [ $? -ne 0 ]; then
    /root/jessica/0xbefe/scripts/boards/x2o/fan_level_7.sh
    echo "High temperature, run aborting"
    exit 1
fi

#Get run number for future use
while [ -f $JSDIR/data/summary/$DATE/$DATE"_"$RUN_N.csv ]
do
    ((RUN_N++))
done


cd /root/gem/0xbefe_test_refclks/scripts
source env.sh csc x2o 0
count=0
/root/jessica/0xbefe/scripts/boards/x2o/fan_level_5.sh
for i in {0..1}
do
  python3 $JSDIR/fpga_short.py $BEFE_SCRIPT_DIR/resources/x2o_csc.bit
  if [ $? -eq 0 ]; then
    ((count++))
  fi
done
echo "Successful FPGA Program Cycles: $count"
echo "FPGA cycles: $count \n" >> $JSDIR/data/summary/$DATE/$DATE"_"$RUN_N.csv

#Test register access speed
python3 $JSDIR/reg_access_performance.py 10000

echo "Testing Reflck Frequencies"
python3 /root/jessica/0xbefe/scripts/boards/x2o/refclk_freq_monitor.py
/root/jessica/0xbefe/scripts/boards/x2o/fan_level_7.sh
sleep 30
python3 $JSDIR/fpga_short.py $BEFE_SCRIPT_DIR/resources/hot_x2o.bit
python3 /root/jessica/0xbefe/scripts/boards/x2o/physical_test.py hot
if [ $? -ne 0 ]; then
    /root/jessica/0xbefe/scripts/boards/x2o/fan_level_7.sh
    echo "High temperature, run aborting"
    exit 1
fi

python3 $BEFE_SCRIPT_DIR/boards/x2o/program_fpga.py $BEFE_SCRIPT_DIR/resources/x2o_csc.bit
/root/jessica/0xbefe/scripts/boards/x2o/fan_level_5.sh
echo "Goodbye"
