# 22.07.2021 (v5.0.0)

Major firmware updates:
* Official CSC builds for CVP13 and APEX added
* ME0 firmware reorganized to have 8 GBTs and 24 VFATs per "OH", which just refers to the whole layer. Please refer to ```doc/cvp13.md``` for fiber mapping.
* VFAT HDLC addresses are now set individually per slot (it is now also possible to mix VFAT hybrids and plugin cards on the same GEB)
* Using QPLLs on all links (noticeable link quality improvement on GBTX links)
* All sync ref clocks are now 160.32MHz, and all async ref clocks are now 150.25MHz (update your clock synthesizer configs accordingly)
* GbE Local DAQ link and features added to GEM and CSC CVP13 and APEX boards (will come to CTP7 soon too)
   * local daq allows readout through a GbE NIC
* GBTX RX sync fifos removed, and reset sequence updated
* AXI-IPB bridge can now accept async clocks for AXI and IPB and cross the domains (used in CVP13 in order to be able to use a slower 100MHz clock on the IPB domain instead of the 250MHz that comes out of the PCIe block). IPB slaves can now also adapt their timeouts based on the provided IPB clock frequency (passed in as generic)
* All board configuration (e.g. MGT configs, and mappings to links and OHs and DMBs) is now accessible through registers, which allows the scripts to be fully generic (specifically those which configure the links and check their status)
* Refclk frequency meters added (readable through registers)
* APEX migrated to the new Florida C2C framework (2 lanes at 3.125Gb/s, not using aurora IP)
* Trigger cluster format updated to use the eta/phi "address"
* Clock constraints reworked
* Compatible with vivado 2021.1 (required for CVP13)

Major software updates:
* gem_env.sh is now called env.sh, it requires an additional parameter, which is board_idx (refers to FPGA index in APEX)
   * so e.g. instead of ```source gem_env.sh ge21 cvp13```, you now have to do ```source env.sh ge21 cvp13 0```
* Address table was reorganized such that the top node is now ```BEFE```, and contains common things between GEM and CSC like ```SYSTEM```, ```MGTS```, ```PROMLESS```, ```SLINK```, and also ```GEM_AMC``` or ```CSC_FED```, depending on the build
   * NOTE: all register names that are normally used in user scripts now have to begin with ```BEFE```, so e.g. ```GEM_AMC.OH_LINKS.OH0.GBT0_READY``` now became ```BEFE.GEM_AMC.OH_LINKS.OH0.GBT0_READY```
   * I'm sorry for the longer register names, but this was necessary in order to implement generic, project and board agnostic scripts
* A master configuration file has been introduced, it is called ```befe_config.py```, and has to be created and maintained by the user. An example config is included called ```befe_config_example.py```, which will work in most setups, so for starters the user should just copy the ```befe_config_example.py``` to ```befe_config.py``` (the reason why ```befe_config.py``` is not included is to avoid git conflicts)
   * NOTE: the config file contains pointers to firmware and gbt config files, by default they are pointing to various filenames inside the ```scripts/resources``` directory: the best way to maintain these is not to change the pointers in the config file, but rather create symlinks in the ```scripts/resources``` directory to the desired bitstreams and gbt configs
   * GE2/1 GBT config files are included in the resources directory, but note that these are just the minimal GBTX configs, and don't have optimal elink phases. It is recommended that the user replaces them with optimized GBTX configs for a particular GEB. Phase optimized GBTX configs for each GEB type may be included in the future release.
   * Note: the ```befe_config.py``` also defines VFAT HDLC addresses -- these will work for the latest standard GEBs equipped with plugin cards, but if your setup is using older GEBs or VFAT hybrids that don't support addressing, the HDLC addresses in ```befe_config.py``` should be replaced with zeros. In case you are using a mixture of VFAT plugin cards and hybrids, set the HDLC address to 0 for the slots where you have hybrids installed.
* All board and flavor specific init scripts have been removed (e.g. cvp13_init_ge21.py, cvp13_init_me0.py, apex_init_me.py, etc), and replaced by generic initialization scripts that figure out all the link configuration from the registers:
   * for GEM there are two scripts: ```gem/init_backend.py``` and ```gem/init_frontend.py```. The backend init script only has to be called after loading firmware to the FPGA (this does also call the frontend init script, so it's not necessary to call the frontend init script after that). The frontend init script should be run after power cycling the OHs (it includes programming the OH FPGAs, configuring GBTs, resetting SCA and VFATs, and checking status).
   * for CSC call ```csc/init.py``` after reloading the FPGA firmware
* Command line scripts added to program the CVP13 and APEX FPGAs, so it no longer has to be done through the vivado GUI (writing flash to CVP13 is also not mandatory, except once for the new boards)
   * Note: the FPGA programming script for the CVP13 does require vivado or vivado lab tools to be installed on the machine, as well as a copy of a valid PCIe config
* Python3 should be used from this point forward (attempting to use python2 will result in errors)
* All python function names have been changed from cammelCase style to underscore_style
* rw_reg has been reworked:
   * ```read_reg()``` and ```write_reg()``` now also accept either a register name string or a ```Node```, so instead of ```read_reg(get_node("GEM_AMC.OH_LINKS.OH0.GBT0_READY"))``` one can just write ```read_reg("GEM_AMC.OH_LINKS.OH0.GBT0_READY")``` (in case a string is passed, the node is looked up internally). This is convenient for one off reads/writes, but if your code is reading/writing the same exact register many times, you should look up that register first by using the ```get_node()``` function, and then reuse that node in all the ```read_reg()``` and ```write_reg()``` calls for the same register -- the performance will be better this way.
   * ```read_reg()``` no longer returns a string, but rather an int object, so it's no longer necessary to call the ```parseInt()``` function on the returned result (please don't)
   * actually the result returned by the ```read_reg()``` is not a simple int, but rather a RegVal object, which is a subclass of int, so it behaves the same way as int does (can be used in any kind of math operations, etc), but in addition to that it is also able to print itself in a nice way when converted to string e.g. when using ```str(val)```, or ```"%s" % val```, or ```val.to_string(hex=False, hex_padded32=True, use_color=True, bool_use_yesno=True)```.
      * some registers in the address table are aware of what values are good or bad or should issue a warning, in which case they are printed in green/red/yellow color. In the XML sw_val_bad/sw_val_bad/sw_val_warn/sw_val_neutral attributes (python expressions) are used, please see the ```RegVal.get_state()``` function comments for more details on how they work.
      * some registers in the address table are aware of their units (e.g. MHz), and are printed in those units (the units are also indicated in the print). In the XML sw_units attribute is used for this. Arbitrary units can be used in the sw_units attribute, where the first letter determines if it's "kilo", "mega", or "giga" (in this case the value will be divided accordingly, if the first letter is not K, M, or G, then the value is not divided, but units are still stated). sw_unit also has a special value called "bool" which if used will print YES/NO (default) or TRUE/FALSE (if bool_use_yesno is set to False in the to_string()).
      * some registers are refering to enumerated values e.g. ```BEFE.SYSTEM.RELEASE.BOARD_TYPE``` is refering to ```CTP7```, ```CVP13```, ```APEX```, etc, and are printed in this way (also e.g. ```BEFE.GEM_AMC.OH_LINKS.OH0.GBT0_READY``` would print as ```READY``` or ```NOT_READY```). In the XML sw_enum attribute is used to define the enum values (python expression)
      * some registers have custom defined printout procedure in the XML, which will be used to print the value (e.g. release version, date, time will be printed in a human readable format). In the XML sw_to_string attribute (python expression) is used to define it.
      * if none of the above are defined in the XML, the value will print as an integer value, unless optional parameters are passed to the ```to_string()``` function
* A few libraries were added which are able to print nice tables (tableformatter and prettytable), an example of how to use them is located here: ```common/tables/table_example.py```. I prefer the tableformatter (also included in common.utils), but you are free to choose.. If python36-colorama package is installed, the tableformatter will be able to color the background slightly for alternating rows to make large tables more readable.
* gbt.py also supports ME0
* gbt.py now selects best phases after a phase scan
* gbt.py phase scans now are also using L1As and check the CRC on the returned data packets -- this dramatically improves statistics per phase since the DAQ path is much faster (using L1A rate of 1MHz)
* gbt.py is now able to scan the elinks connected to the FPGA, not only to the VFATs

Instructions for upgrading from a 4.x.x release:
   * CVP13 clock synthesizer Si5341-B (the second one in the GUI) has to be reprogrammed with the following file: ```boards/cvp13/resources/clock_configs/cvp13_synth_b_156p25.h```, please refer to the ```doc/cvp13.md``` section "Program the card" for instructions on how to do it.
   * Source the env.sh script (remember that you need to add an additional argument at the end indicating the index of the board/fpga that you want to use -- in most cases this should be 0)
   * Run ```make update_ge21_cvp13``` (replace ge21 and cvp13 with your flavor and board)
   * Make a copy of ```scripts/befe_config_example.py``` to ```scripts/befe_config.py```, review, and edit it if necessary to reflect your setup. Note, the pointers to bitfiles and gbt configs can be left as is, and instead just create symlinks in the ```scripts/resources``` directory to the appropriate bitfiles and gbt configs
   * Always use python3 instead of python2
   * If you want the CVP13 "remember" the new firmware across reboots, you can flash the PROM as explained in the ```doc/cvp13.md``` section "Program the card"
      * Alternatively you can now use the ```boards/cvp13/program_fpga.py``` script (no arguments are needed, it loads the firmware based on the flavor selection in env.sh, and looks up the bitfile using the befe_config.py). Note that for this to work you have to install Xilinx Vivado Lab Tools (recommended if you're not developing firmware, latest versions seem to be renamed to Vivado Lab Solutions) or Vivado (if you are a firmware developer) on your machine from https://www.xilinx.com/support/download.html. Note that you have to indicate the path to where you installed the vivado lab tools in the ```befe_config.py CONFIG_VIVADO_DIR```. You also need to make a copy of the PCIe config as explained in ```doc/cvp13.md``` "Hot reloading the FPGA" section, and indicate the location of this copy in ```befe_config.py CONFIG_CVP13_PCIE_CONFIG```, or create a symlink in the ```resources``` directory. Programming the FPGA this way is faster than flashing the PROM, but the firmware does not persist across computer power cycles.
   * For the APEX board you can now use ```boards/apex/program_fpga.py``` to load the firmware and configure clocks (no arguments are needed, it figures out the flavor and fpga based on the selection when sourcing the env.sh), also remember to update the symlinks in the ```resources``` dir or update the ```befe_config.py```
   * Use ```gem/init_backend.py``` script instead of ```boards/cvp13/cvp13_init_ge21.py``` and the like
   * Use ```gem/init_frontend.py``` after power cycling the OH
   * Have fun! :)
