# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "Clock_source" -parent ${Page_0}
  ipgui::add_param $IPINST -name "ref_clock" -parent ${Page_0}
  ipgui::add_param $IPINST -name "technology" -parent ${Page_0}
  ipgui::add_param $IPINST -name "throughput" -parent ${Page_0}
  #Adding Group
  set Differential_line_polarities [ipgui::add_group $IPINST -name "Differential line polarities" -parent ${Page_0}]
  set_property tooltip {Allows to swap the differential line porlariteis of Tx an Rx lines} ${Differential_line_polarities}
  set rxpolarity_in [ipgui::add_param $IPINST -name "rxpolarity_in" -parent ${Differential_line_polarities} -widget comboBox]
  set_property tooltip {1 means polarity of differential lines will be swapped} ${rxpolarity_in}
  set txpolarity_in [ipgui::add_param $IPINST -name "txpolarity_in" -parent ${Differential_line_polarities} -widget comboBox]
  set_property tooltip {1 means polarity of differential lines will be swapped} ${txpolarity_in}



}

proc update_PARAM_VALUE.Clock_source { PARAM_VALUE.Clock_source } {
	# Procedure called to update Clock_source when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.Clock_source { PARAM_VALUE.Clock_source } {
	# Procedure called to validate Clock_source
	return true
}

proc update_PARAM_VALUE.ref_clock { PARAM_VALUE.ref_clock } {
	# Procedure called to update ref_clock when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ref_clock { PARAM_VALUE.ref_clock } {
	# Procedure called to validate ref_clock
	return true
}

proc update_PARAM_VALUE.rxpolarity_in { PARAM_VALUE.rxpolarity_in } {
	# Procedure called to update rxpolarity_in when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.rxpolarity_in { PARAM_VALUE.rxpolarity_in } {
	# Procedure called to validate rxpolarity_in
	return true
}

proc update_PARAM_VALUE.technology { PARAM_VALUE.technology } {
	# Procedure called to update technology when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.technology { PARAM_VALUE.technology } {
	# Procedure called to validate technology
	return true
}

proc update_PARAM_VALUE.throughput { PARAM_VALUE.throughput } {
	# Procedure called to update throughput when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.throughput { PARAM_VALUE.throughput } {
	# Procedure called to validate throughput
	return true
}

proc update_PARAM_VALUE.txpolarity_in { PARAM_VALUE.txpolarity_in } {
	# Procedure called to update txpolarity_in when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.txpolarity_in { PARAM_VALUE.txpolarity_in } {
	# Procedure called to validate txpolarity_in
	return true
}


proc update_MODELPARAM_VALUE.txpolarity_in { MODELPARAM_VALUE.txpolarity_in PARAM_VALUE.txpolarity_in } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.txpolarity_in}] ${MODELPARAM_VALUE.txpolarity_in}
}

proc update_MODELPARAM_VALUE.rxpolarity_in { MODELPARAM_VALUE.rxpolarity_in PARAM_VALUE.rxpolarity_in } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.rxpolarity_in}] ${MODELPARAM_VALUE.rxpolarity_in}
}

proc update_MODELPARAM_VALUE.Clock_source { MODELPARAM_VALUE.Clock_source PARAM_VALUE.Clock_source } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.Clock_source}] ${MODELPARAM_VALUE.Clock_source}
}

proc update_MODELPARAM_VALUE.throughput { MODELPARAM_VALUE.throughput PARAM_VALUE.throughput } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.throughput}] ${MODELPARAM_VALUE.throughput}
}

proc update_MODELPARAM_VALUE.ref_clock { MODELPARAM_VALUE.ref_clock PARAM_VALUE.ref_clock } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ref_clock}] ${MODELPARAM_VALUE.ref_clock}
}

proc update_MODELPARAM_VALUE.technology { MODELPARAM_VALUE.technology PARAM_VALUE.technology } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.technology}] ${MODELPARAM_VALUE.technology}
}

