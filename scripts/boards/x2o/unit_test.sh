#!/bin/bash
echo "Welcome"
source config.sh
cd $BEFE_DIR/"scripts"
source env.sh ge21 x2o 0
UTIL_DIR=$BEFE_SCRIPT_DIR/boards/x2o/x2o_utils
RUN_N=1
DATE=$(date +"%Y-%m-%d")

#Get run number for future use
while [ -f $UTIL_DIR/../data/summary/$DATE/$DATE"_"$RUN_N.csv ]
do
    ((RUN_N++))
done

((RUN_N--))

#Safety Check for Temps
python3 $UTIL_DIR/check_temp.py
if [ $? -ne 0 ]; then
    $UTIL_DIR/fan_level_7.sh
    python3 $BEFE_SCRIPT_DIR/boards/x2o/power_down.py
    echo "High temperature, run aborting and powering down"
    exit 1
fi


#Start physical baseline test
echo "Testing baseline physical data"
python3 $UTIL_DIR/fpga_short.py $BEFE_SCRIPT_DIR/resources/x2o_$BEFE_FLAVOR.bit
python3 $UTIL_DIR/physical_test.py $BEFE_FLAVOR $RUN_N
if [ $? -ne 0 ]; then
    $UTIL_DIR/fan_level_7.sh
    python3 $BEFE_SCRIPT_DIR/boards/x2o/power_down.py
    echo "High temperature, run aborting and powering down"
    exit 1
fi


#cd /root/gem/0xbefe_test_refclks/scripts
#source env.sh csc x2o 0
count=0
$UTIL_DIR/fan_level_5.sh
for i in {1..$FPGA_CYCLES}
do
  python3 $UTIL_DIR/fpga_short.py $BEFE_SCRIPT_DIR/resources/x2o_$BEFE_FLAVOR.bit
  if [ $? -eq 0 ]; then
    ((count++))
  fi
done
echo "Successful FPGA Program Cycles: $count"
echo "FPGA cycles: $count \n" >> $UTIL_DIR/../data/summary/$DATE/$DATE"_"$RUN_N.csv

#Test register access speed
echo "Testing register access speed"
python3 $UTIL_DIR/reg_access_performance.py $REG_ACCESS_ITERS $RUN_N

#Link mapping
echo "Mapping links and testing connectivity"
python3 $BEFE_DIR/scripts/gem/init_backend.py
python3 $UTIL_DIR/optic_test.py

echo "Testing Reflck Frequencies"
python3 $UTIL_DIR/refclk_freq_monitor.py $RUN_N

echo "Preparing for stress test"
$UTIL_DIR/fan_level_7.sh
sleep 30
python3 $UTIL_DIR/fpga_short.py $BEFE_SCRIPT_DIR/resources/hot_x2o.bit

echo "Testing physical stress test"
python3 $UTIL_DIR/physical_test.py hot $RUN_N
if [ $? -ne 0 ]; then
    $UTIL_DIR/fan_level_7.sh
    python3 $BEFE_SCRIPT_DIR/boards/x2o/power_down.py
    echo "High temperature, run aborting and powering down"
    exit 1
fi

python3 $UTIL_DIR/fpga_short.py $BEFE_SCRIPT_DIR/resources/x2o_$BEFE_FLAVOR.bit
$UTIL_DIR/fan_level_5.sh
echo "Goodbye"
