# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "GT_CLK_DIVIDER" -parent ${Page_0}
  ipgui::add_param $IPINST -name "GT_RX_POLARITY" -parent ${Page_0}
  ipgui::add_param $IPINST -name "GT_TX_POLARITY" -parent ${Page_0}


}

proc update_PARAM_VALUE.GT_CLK_DIVIDER { PARAM_VALUE.GT_CLK_DIVIDER } {
	# Procedure called to update GT_CLK_DIVIDER when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.GT_CLK_DIVIDER { PARAM_VALUE.GT_CLK_DIVIDER } {
	# Procedure called to validate GT_CLK_DIVIDER
	return true
}

proc update_PARAM_VALUE.GT_RX_POLARITY { PARAM_VALUE.GT_RX_POLARITY } {
	# Procedure called to update GT_RX_POLARITY when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.GT_RX_POLARITY { PARAM_VALUE.GT_RX_POLARITY } {
	# Procedure called to validate GT_RX_POLARITY
	return true
}

proc update_PARAM_VALUE.GT_TX_POLARITY { PARAM_VALUE.GT_TX_POLARITY } {
	# Procedure called to update GT_TX_POLARITY when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.GT_TX_POLARITY { PARAM_VALUE.GT_TX_POLARITY } {
	# Procedure called to validate GT_TX_POLARITY
	return true
}


proc update_MODELPARAM_VALUE.GT_TX_POLARITY { MODELPARAM_VALUE.GT_TX_POLARITY PARAM_VALUE.GT_TX_POLARITY } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.GT_TX_POLARITY}] ${MODELPARAM_VALUE.GT_TX_POLARITY}
}

proc update_MODELPARAM_VALUE.GT_RX_POLARITY { MODELPARAM_VALUE.GT_RX_POLARITY PARAM_VALUE.GT_RX_POLARITY } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.GT_RX_POLARITY}] ${MODELPARAM_VALUE.GT_RX_POLARITY}
}

proc update_MODELPARAM_VALUE.GT_CLK_DIVIDER { MODELPARAM_VALUE.GT_CLK_DIVIDER PARAM_VALUE.GT_CLK_DIVIDER } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.GT_CLK_DIVIDER}] ${MODELPARAM_VALUE.GT_CLK_DIVIDER}
}

