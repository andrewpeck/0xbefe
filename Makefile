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

IFTIME := $(shell command -v time 2> /dev/null)
ifndef IFTIME
TIMECMD =
else
TIMECMD = time -p
endif

list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

init:
	git submodule update --init --recursive

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
	@cd regtools && python generate_registers.py -p generated/ge11_cvp13/ gem_amc

update_ge21_cvp13: config
	@cd address_table/gem && python generate_xml.py
	@cd regtools && python generate_registers.py -p generated/ge21_cvp13/ gem_amc

update_me0_cvp13: config
	@cd address_table/gem && python generate_xml.py
	@cd regtools && python generate_registers.py -p generated/me0_cvp13/ gem_amc

update_csc_cvp13: config
	@cd address_table/csc && python generate_xml.py
	@cd regtools && python generate_registers.py -p generated/csc_cvp13/ csc_fed

update_cvp13_all: update_ge11_cvp13 update_ge21_cvp13 update_me0_cvp13 update_csc_cvp13

#### CTP7 ####
update_ge11_ctp7: config
	@cd address_table/gem && python generate_xml.py
	@cd regtools && python generate_registers.py -p generated/ge11_ctp7/ gem_amc

update_ge21_ctp7: config
	@cd address_table/gem && python generate_xml.py
	@cd regtools && python generate_registers.py -p generated/ge21_ctp7/ gem_amc

update_me0_ctp7: config
	@cd address_table/gem && python generate_xml.py
	@cd regtools && python generate_registers.py -p generated/me0_ctp7/ gem_amc

update_csc_ctp7: config
	@cd address_table/csc && python generate_xml.py
	@cd regtools && python generate_registers.py -p generated/csc_ctp7/ csc_fed

update_ctp7: update_ge11_ctp7 update_ge21_ctp7 update_me0_ctp7 update_csc_ctp7

#### APEX ####
update_ge11_apex: config
	@cd address_table/gem && python generate_xml.py
	@cd regtools && python generate_registers.py -p generated/ge11_apex/ gem_amc

update_ge21_apex: config
	@cd address_table/gem && python generate_xml.py
	@cd regtools && python generate_registers.py -p generated/ge21_apex/ gem_amc

update_me0_apex: config
	@cd address_table/gem && python generate_xml.py
	@cd regtools && python generate_registers.py -p generated/me0_apex/ gem_amc

update_csc_apex: config
	@cd address_table/csc && python generate_xml.py
	@cd regtools && python generate_registers.py -p generated/csc_apex/ csc_fed

update_apex: update_ge11_apex update_ge21_apex update_me0_apex update_csc_apex

#### Optohybrid ####

update_oh_base:
	@cd regtools && python generate_registers.py oh && cd -

update_oh_ge21:
	@mkdir -p address_table/gem/generated/oh_ge21/
	@cp address_table/gem/optohybrid_registers.xml address_table/gem/generated/oh_ge21/optohybrid_registers.xml
	@python scripts/boards/optohybrid/update_xml.py -s ge21 -x address_table/gem/generated/oh_ge21/optohybrid_registers.xml
	@cd regtools && python generate_registers.py -p generated/oh_ge21/ oh

update_oh_ge11:
	@mkdir -p address_table/gem/generated/oh_ge11/
	@cp address_table/gem/optohybrid_registers.xml address_table/gem/generated/oh_ge11/optohybrid_registers.xml
	@python scripts/boards/optohybrid/update_xml.py -s ge11 -l long -x address_table/gem/generated/oh_ge11/optohybrid_registers.xml
	@cd regtools && python generate_registers.py -p generated/oh_ge11/ oh

#### shortcuts ####
update_ge11: update_ge11_cvp13 update_ge11_ctp7 update_ge11_apex
update_ge21: update_ge21_cvp13 update_ge21_ctp7 update_ge21_apex
update_me0: update_me0_cvp13 update_me0_ctp7 update_me0_apex
update_csc: update_csc_cvp13 update_csc_ctp7 update_csc_apex

update: update_ge11 update_ge21 update_me0 update_csc

################################################################################
# Create
################################################################################

create_cvp13: create_ge11_cvp13 create_ge21_cvp13 create_me0_cvp13 create_csc_cvp13
create_ctp7: create_ge11_ctp7 create_ge21_ctp7 create_me0_ctp7
create_apex: create_ge11_apex create_ge21_apex create_me0_apex create_csc_apex

create_ge11: create_ge11_cvp13 create_ge11_ctp7 create_ge11_apex
create_ge21: create_ge21_cvp13 create_ge21_ctp7 create_ge21_apex
create_me0: create_me0_cvp13 create_me0_ctp7 create_me0_apex
create_csc: create_csc_cvp13 create_csc_apex

create: create_ge11 create_ge21 create_me0 create_csc

################################################################################
# compile (synth + impl)
################################################################################

cvp13: impl_ge11_cvp13 impl_ge21_cvp13 impl_me0_cvp13 impl_csc_cvp13
ctp7: impl_ge11_ctp7 impl_ge21_ctp7 impl_me0_ctp7
apex: impl_ge11_apex impl_ge21_apex impl_me0_apex impl_csc_apex

ge11: impl_ge11_cvp13 impl_ge11_ctp7 impl_ge11_apex
ge21: impl_ge21_cvp13 impl_ge21_ctp7 impl_ge21_apex
me0: impl_me0_cvp13 impl_me0_ctp7 impl_me0_apex
csc: impl_csc_cvp13 impl_csc_apex

all: ge11 ge21 me0 csc

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
