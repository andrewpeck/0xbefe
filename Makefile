.PHONY = all clean

ifdef version
VER_ARG = -v $(version)
else
VER_ARG =
endif

CCZE := $(shell command -v ccze 2> /dev/null)
ifndef CCZE
COLORIZE =
else
COLORIZE = | ccze -A
endif

clean:
	@find . -name "*.jou" -exec rm {} \;

clean_projects:
	rm -rf VivadoProject/

all:  update create synth impl

################################################################################
# Update from XML
################################################################################

#### CVP13 ####
update_ge11_cvp13:
	@cd address_table/gem && python generate_xml.py
	@cd reg_tools && python generate_registers.py -p generated/ge11_cvp13/

update_ge21_cvp13:
	@cd address_table/gem && python generate_xml.py
	@cd reg_tools && python generate_registers.py -p generated/ge21_cvp13/

update_me0_cvp13:
	@cd address_table/gem && python generate_xml.py
	@cd reg_tools && python generate_registers.py -p generated/me0_cvp13/

update_cvp13_all: update_ge11_cvp13 update_ge21_cvp13 update_me0_cvp13

#### CTP7 ####
update_ge11_ctp7:
	@cd address_table/gem && python generate_xml.py
	@cd reg_tools && python generate_registers.py -p generated/ge11_ctp7/

update_ge21_ctp7:
	@cd address_table/gem && python generate_xml.py
	@cd reg_tools && python generate_registers.py -p generated/ge21_ctp7/

update_me0_ctp7:
	@cd address_table/gem && python generate_xml.py
	@cd reg_tools && python generate_registers.py -p generated/me0_ctp7/

update_ctp7: update_ge11_ctp7 update_ge21_ctp7 update_me0_ctp7

#### shortcuts ####
update_ge11: update_ge11_cvp13 update_ge11_ctp7
update_ge21: update_ge21_cvp13 update_ge21_ctp7
update_me0: update_me0_cvp13 update_me0_ctp7

update: update_ge11_all update_ge21_all update_me0_all
	
################################################################################
# Create
################################################################################

create_cvp13: create_ge11_cvp13 create_ge21_cvp13 create_me0_cvp13
create_ctp7: create_ge11_ctp7 create_ge21_ctp7 create_me0_ctp7

create_ge11: create_ge11_cvp13 create_ge11_ctp7
create_ge21: create_ge21_cvp13 create_ge21_ctp7
create_me0: create_me0_cvp13 create_me0_ctp7

create: create_ge11 create_ge21 create_me0

################################################################################
# Synth
################################################################################

synth_cvp13: synth_ge11_cvp13 synth_ge21_cvp13 synth_me0_cvp13
synth_ctp7: synth_ge11_ctp7 synth_ge21_ctp7 synth_me0_ctp7

synth_ge11: synth_ge11_cvp13 synth_ge11_ctp7
synth_ge21: synth_ge21_cvp13 synth_ge21_ctp7
synth_me0: synth_me0_cvp13 synth_me0_ctp7

synth: synth_ge11 synth_ge21 synth_me0

################################################################################
# Impl
################################################################################

impl_cvp13: impl_ge11_cvp13 impl_ge21_cvp13 impl_me0_cvp13
impl_ctp7: impl_ge11_ctp7 impl_ge21_ctp7 impl_me0_ctp7

impl_ge11: impl_ge11_cvp13 impl_ge11_ctp7
impl_ge21: impl_ge21_cvp13 impl_ge21_ctp7
impl_me0: impl_me0_cvp13 impl_me0_ctp7

impl: impl_ge11 impl_ge21 impl_me0

################################################################################
# Shortcuts
################################################################################

ge11: impl_ge11
ge21: impl_ge21
me0: impl_me0

cvp13: impl_cvp13
ctp7: impl_ctp7

################################################################################
# Generics
################################################################################

create_%: update_%
	@echo -------------------------------------------------------------------------------- $(COLORIZE)
	@echo Creating Project $(patsubst create_%,%,$@)                                       $(COLORIZE)
	@echo -------------------------------------------------------------------------------- $(COLORIZE)
	@time Hog/CreateProject.sh $(patsubst create_%,%,$@)                                   $(COLORIZE)

synth_%: create_%
	@echo -------------------------------------------------------------------------------  $(COLORIZE)
	@echo Launching Synthesis $(patsubst synth_%,%,$@)                                     $(COLORIZE)
	@echo -------------------------------------------------------------------------------- $(COLORIZE)
	@time Hog/LaunchSynthesis.sh $(patsubst synth_%,%,$@)                                  $(COLORIZE)

impl_%: create_% synth_%
	@echo -------------------------------------------------------------------------------- $(COLORIZE)
	@echo Launching Implementation $(patsubst impl_%,%,$@)                                 $(COLORIZE)
	@echo -------------------------------------------------------------------------------- $(COLORIZE)
	@time Hog/LaunchImplementation.sh $(patsubst impl_%,%,$@                               $(COLORIZE))
