# Setting up GE21 testing environment for CVP13 
Clone the 0xBEFE repository, and setup the CVP13 as explained in this document: https://gitlab.cern.ch/emu/0xbefe/-/blob/devel/doc/cvp13.md

For now CVP13 software requires root privileges (this will change in the future), so always become root before using the CVP13 like this: ```sudo su -```

Copy-paste this into your ~root/.bash_profile file (edit the first line to reflect the directory where you have cloned the 0xBEFE repository on your system):
```
BEFE_DIR=~gem2rice/CVP-13/0xbefe
cd $BEFE_DIR/scripts/
source env_gem.sh ge21 cvp13
alias reg='python $BEFE_DIR/scripts/common/reg_interface.py'
```
This way the environment will be ready to use the CVP13 as soon as you become root. Note that it's necessary to log out and log back in for the .bash_profile changes to take effect (or source it manually).

From here on it is assumed that you have setup the bash_profile and had just became root, so you are in the scripts directory of the 0xBEFE.

Create directories for OH firmware and the GBT configs, and copy the appropriate files:
```
mkdir ../../oh_fw
mkdir ../../gbt_config
```
for the firmware files, you can create symlinks for convenience e.g.:
```
cd ../../oh_fw
ln -s OH_3_2_8_GE21v2.bit oh_full.bit
ln -s oh_ge21v2_loopback_120.bit oh_loopback.bit
```

NOTE: after OH power-cycle or fiber unplugging and re-plugging it's necessary to run the init script which resets the optical links on the CVP13: ```boards/cvp13/cvp13_init_ge21.py```

# Notes on the OH testing manual w.r.t. CVP13
## Section 8: Check communication with the CTP7
Instead of ssh texas@eagle42, you just ssh gem2rice@bonner-muon.rice.edu and run "sudo su -" as explained above
Resetting AMC13 does not apply
There is no need to run any kind of cold_boot scripts, because the firmware on the CVP13 is loaded from the PROM on boot of the computer

### Load the OH firmware to the CTP7 RAM
Instead of the gemloader_configure scripts you have to use ```python common/promless_load.py <bitstream_file>```
So instead of gemloader_configure_v2.sh do this:
```
python common/promless_load.py ../../oh_fw/oh_loopback.bit
```
And instead of gemloader_configure_v2_full.sh, do this:
```
python common/promless_load.py ../../oh_fw/oh_full.bit
```
### Configure the GBTs
The procedure is the same, but instead of using gbt_ge21_map.py, now just use gem/gbt.py:
```
export OH=0
python gem/gbt.py $OH 0 config ../../gbt_config/GBTX_GE21_OHv2_GBT_0_minimal_2020-01-17.txt
python gem/gbt.py $OH 1 config ../../gbt_config/GBTX_GE21_OHv2_GBT_1_minimal_2020-01-31.txt
```
### Check the GBTx transmission to CTP7 (VTRX)
No changes
### Check the SCA ASIC
No changes
## Section 11.3: Test of the VTTX optical links with the CTP7
OTMB trigger receivers are not implemented in CVP13, so have to use either method from 11.1 or 11.2
## Section 12: Load FPGA from GBT1
No changes, except that the ge21_promless_test.py is now in the gem directory, so execute like this:
```
python gem/ge21_promless_test.py 1 1000
```
# Other notes
## RSSI reading
You can read the RSSI currents by using ```gem/ge21_oh_rssi_monitor.py <oh_mask> [out_file]``` where the oh_mask is a bitmask indicating which OHs to read, so e.g. to only read OH0:
```
python gem/ge21_oh_rssi_monitor.py 1
```
The program reads every 1 second in an infinite loop, to exit use CTRL+C

