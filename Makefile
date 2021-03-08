.PHONY = all clean

ifdef version
VER_ARG = -v $(version)
else
VER_ARG =
endif

NJOBS = 12

CCZE := $(shell command -v ccze 2> /dev/null)
ifndef CCZE
COLORIZE =
else
COLORIZE = | ccze -A
endif

clean:
	@find . -name "*.jou" -exec rm {} \;

clean_bd:
	git clean -fdX boards/*/bd

clean_ip:
	git clean -dfX boards/*/ip
	git clean -dfX */ip

clean_projects: clean_bd clean_ip
	rm -rf Projects/

all:  update create synth impl

config: gitconfig

gitconfig:
	git config --local include.path ../.gitconfig

################################################################################
# Update from XML
################################################################################

#### CVP13 ####
update_ge11_cvp13: config
	@cd address_table/gem && python generate_xml.py
	@cd regtools && python generate_registers.py -p generated/ge11_cvp13/ cvp13

update_ge21_cvp13: config
	@cd address_table/gem && python generate_xml.py
	@cd regtools && python generate_registers.py -p generated/ge21_cvp13/ cvp13

update_me0_cvp13: config
	@cd address_table/gem && python generate_xml.py
	@cd regtools && python generate_registers.py -p generated/me0_cvp13/ cvp13

update_cvp13_all: update_ge11_cvp13 update_ge21_cvp13 update_me0_cvp13

#### CTP7 ####
update_ge11_ctp7: config
	@cd address_table/gem && python generate_xml.py
	@cd regtools && python generate_registers.py -p generated/ge11_ctp7/ ctp7

update_ge21_ctp7: config
	@cd address_table/gem && python generate_xml.py
	@cd regtools && python generate_registers.py -p generated/ge21_ctp7/ ctp7

update_me0_ctp7: config
	@cd address_table/gem && python generate_xml.py
	@cd regtools && python generate_registers.py -p generated/me0_ctp7/ ctp7

update_ctp7: update_ge11_ctp7 update_ge21_ctp7 update_me0_ctp7

#### APEX ####
update_ge11_apex: config
	@cd address_table/gem && python generate_xml.py
	@cd regtools && python generate_registers.py -p generated/ge11_apex/ apex

update_ge21_apex: config
	@cd address_table/gem && python generate_xml.py
	@cd regtools && python generate_registers.py -p generated/ge21_apex/ apex

update_me0_apex: config
	@cd address_table/gem && python generate_xml.py
	@cd regtools && python generate_registers.py -p generated/me0_apex/ apex

update_apex: update_ge11_apex update_ge21_apex update_me0_apex

#### shortcuts ####
update_ge11: update_ge11_cvp13 update_ge11_ctp7 update_ge11_apex
update_ge21: update_ge21_cvp13 update_ge21_ctp7 update_ge21_apex
update_me0: update_me0_cvp13 update_me0_ctp7 update_me0_apex

update: update_ge11 update_ge21 update_me0
	
################################################################################
# Create
################################################################################

create_cvp13: create_ge11_cvp13 create_ge21_cvp13 create_me0_cvp13
create_ctp7: create_ge11_ctp7 create_ge21_ctp7 create_me0_ctp7
create_apex: create_ge11_apex create_ge21_apex create_me0_apex

create_ge11: create_ge11_cvp13 create_ge11_ctp7 create_ge11_apex
create_ge21: create_ge21_cvp13 create_ge21_ctp7 create_ge21_apex
create_me0: create_me0_cvp13 create_me0_ctp7 create_me0_apex

create: create_ge11 create_ge21 create_me0

################################################################################
# compile (synth + impl)
################################################################################

cvp13: impl_ge11_cvp13 impl_ge21_cvp13 impl_me0_cvp13
ctp7: impl_ge11_ctp7 impl_ge21_ctp7 impl_me0_ctp7
apex: impl_ge11_apex impl_ge21_apex impl_me0_apex

ge11: impl_ge11_cvp13 impl_ge11_ctp7 impl_ge11_apex
ge21: impl_ge21_cvp13 impl_ge21_ctp7 impl_ge21_apex
me0: impl_me0_cvp13 impl_me0_ctp7 impl_me0_apex

all: ge11 ge21 me0

################################################################################
# Generics
################################################################################

create_%: #update_%
	@echo -------------------------------------------------------------------------------- $(COLORIZE)
	@echo Creating Project $(patsubst create_%,%,$@)                                       $(COLORIZE)
	@echo -------------------------------------------------------------------------------- $(COLORIZE)
	@time Hog/CreateProject.sh $(patsubst create_%,%,$@)                                   $(COLORIZE)

impl_%: #create_% synth_%
	@echo -------------------------------------------------------------------------------- $(COLORIZE)
	@echo Launching Hog Workflow $(patsubst impl_%,%,$@) with njobs = $(NJOBS)             $(COLORIZE)
	@echo -------------------------------------------------------------------------------- $(COLORIZE)
	@time Hog/LaunchWorkflow.sh $(patsubst impl_%,%,$@) -njobs $(NJOBS)                    $(COLORIZE)
