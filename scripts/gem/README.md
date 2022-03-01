## General

Scripts for GE1/1, GE2/1, ME0

## Details of all scripts:

Use -h option for any script to check usage

```gbt.py```: configuration and phase scan for GE1/1, GE2/1 and ME0

```init_backend.py```: initialize backend

```init_frontend.py```: initialize frontend

```get_cal_info_vfat.py```: get calibration data for VFATs

```me0_adc_calibration_scan.py```: scans F factor across a range of DAC currents

```me0_asense_monitor.py```: monitor asense on ME0 GEB

```me0_eye_scan.py```: downlink eye diagram using lpGBT for ME0 Optohyrbid

```me0_eye_equalizer_scan.py```: scan equalizer settings using eye diagram using lpGBT for ME0 Optohyrbid

```me0_elink_scan.py```: scan VFAT vs elink for ME0 Optohyrbid 

```me0_lpgbt_config.py```: configure lpGBT for ME0 Optohyrbid

```me0_lpgbt_efuse.py```: fuse registers on lpGBT for ME0 Optohyrbid

```me0_lpgbt_elink_eq.py```: Set equalization settings for elinks on lpGBT for ME0 Optohyrbid

```me0_lpgbt_rw_register.py```: read/write to any register on lpGBT for ME0 Optohyrbid

```me0_lpgbt_status.py```: check status of lpGBT for ME0 Optohyrbid

```me0_lpgbt_sub_vtrx_reset.py```: resets sub lpGBT or VTRx+ using boss lpgbt in OHv2

```me0_lpgbt_vtrx.py```: enable/disable TX channels or registers on VTRX+ for ME0 Optohyrbid

```me0_optical_link_bert_fec.py```: bit error ratio tests for optical links (uplink/downlink) between lpGBT and backend using fec error rate counting for ME0 Optohyrbid

```me0_phase_scan.py```: phase scan for VFAT elinks and set optimal phase setting for ME0 Optohyrbid

```me0_rssi_monitor.py```: monitor for VTRX+ RSSI value for ME0 Optohyrbid

```me0_temp_monitor.py```: monitor for VTRX+ and OH temperatures

```me0_vfat_reset.py```: reset VFAT for ME0 Optohyrbid

```me0_vfat_sbit_crosstalk.py```: Scan for checking cross talk using S-bits for VFATs for ME0 Optohyrbid

```me0_vfat_sbit_mapping.py```: S-bit mapping for VFATs for ME0 Optohyrbid

```me0_vfat_sbit_noise_rate.py```: S-bit Noise rates for VFATs for ME0 Optohyrbid

```me0_vfat_sbit_phase_scan.py```: S-bit phase scan for VFATs for ME0 Optohyrbid

```me0_vfat_sbit_scurve.py```: S-bit SCurve for VFATs for ME0 Optohyrbid

```me0_vfat_sbit_test.py```: S-bit testing for VFATs for ME0 Optohyrbid

```vfat_config.py```: configure VFAT

```vfat_dac_scan.py```: VFAT DAC Scan

```vfat_daq_crosstalk.py```: Scan for checking cross talk using DAQ data for VFATs

```vfat_daq_scurve.py```: SCurve using DAQ data for VFATs

```vfat_daq_test.py```: bit error ratio tests by reading DAQ data packets from VFATs

```vfat_sbit_monitor_clustermap.py```: Cluster mapping of channel using S-bit monitor

```vfat_sbit_cluster_noise_rate.py```: S-bit Cluster Noise rates for VFATs

```vfat_sbit_cluster_scurve.py```: S-bit Cluster SCurve for VFATs

```vfat_slow_control_test.py```: error tests by read/write on VFAT registers using slow control

## Retrieving VFAT Calibrbation Data

To execute the script get_cal_info_vfat.py:
1. Install the `cx_Oracle` `python` module:
   ```
   $ pip3 install cx_Oracle
   ```
   `cx_Oracle` is an API used to interface with Oracle databases.
2. Define the following environment variables in your `.bash_profile`:
```
export GEM_ONLINE_DB_CONN="CMS_GEM_APPUSER_R/GEM_Reader_2015@"
export GEM_ONLINE_DB_NAME="INT2R_LB_LOCAL"
```
and source:
```
source ~/.bash_profile
```
3. Add the script `dbUtilities/tnsnames.ora` to `/etc`. This file specifies the connection information for the Oracle database.
4. Edit the last line of `DBconnect.sh` with your lxplus username.
5. In a separate shell session, open the tunnel to CERN's network with:
```
$ ./dbUtilities/DBconnect.sh .
```
and login using your CERN credentials. (To execute from any directory, place `DBconnectsh` in `/usr/local/bin`.)

6. Update the VFAT text file (example file provided at `../resources/vfatID.txt`) with your list of 24 plugin cards (for 1 layer) you want to retrieve calibration data for. Use -9999 as serial number for VFATs not connected
 
7. Execute the script:
```
python3 get_cal_info_vfat.py -s backend -o <oh_id> -t <input_type> -w
```
For more information on usage, run `# python3 get_cal_info_vfat.py -h`.



## Procedure for Channel Trimming

1. Run the SCurve script (DAQ or Sbit) wirth 3 different options for "-z": nominal, up, down to take SCurves at 3 different trim values

2. Run the SCurve analysis script to calculate the threshold for each channel for each VFAT

3. Run the trimming analysis script
```
python3 plotting_scripts/vfat_analysis_trimming.py -nd <nominal SCurve result directory> -ud <Trim up SCurve result directory> -dd <Trim down SCurve result directory>
```

This will generate text files in either directories - `results/vfat_data/vfat_daq_trimming_results` or `results/vfat_data/vfat_sbit_trimming_results` depending upon whether DAQ or Sbit SCurves were used

4. The trimming results can be used during VFAT configuration while using any of the scripts by using the additional option `-u daq` or `-u sbit` while running them, with daq or sbit indiciating whether you want to use the trimming results from the DAQ or SBit SCurves
