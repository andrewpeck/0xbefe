SHELL = /bin/bash

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

PROJECT_LIST = $(patsubst %/,%,$(patsubst Top/%,%,$(dir $(dir $(shell find Top/ -name hog.conf)))))
CREATE_LIST = $(addprefix create_,$(PROJECT_LIST))
IMPL_LIST = $(addprefix impl_,$(PROJECT_LIST))
OPEN_LIST = $(addprefix open_,$(PROJECT_LIST))
UPDATE_LIST = $(addprefix update_,$(PROJECT_LIST))

list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

$(CREATE_LIST):
	@echo -------------------------------------------------------------------------------- $(COLORIZE)
	@echo Creating Project $(patsubst create_%,%,$@)                                       $(COLORIZE)
	@echo -------------------------------------------------------------------------------- $(COLORIZE)
	@time Hog/CreateProject.sh $(patsubst create_%,%,$@)                                   $(COLORIZE)

$(IMPL_LIST):
	@echo -------------------------------------------------------------------------------- $(COLORIZE)
	@echo Launching Hog Workflow $(patsubst impl_%,%,$@) with njobs = $(NJOBS)             $(COLORIZE)
	@echo -------------------------------------------------------------------------------- $(COLORIZE)
	@time Hog/LaunchWorkflow.sh $(patsubst impl_%,%,$@) -njobs $(NJOBS)                    $(COLORIZE)

$(UPDATE_LIST): config

	@{ \
		set -e; \
			\
		`# OPTOHYBRID ` ; \
		if [[ $@ == *"oh_"* ]]; then \
			if [[ $@ == *"ge21"* ]] ; then \
				system="ge21" ; \
				type="" ; \
			elif [[ $@ == *"ge11"* ]] ; then \
				system="ge11" ; \
				type="-l long" ; \
			else \
				system="unknown" ; \
				type="" ; \
			fi ; \
			\
			mkdir -p address_table/gem/generated/oh_$$system/ && \
			cp address_table/gem/optohybrid_registers.xml address_table/gem/generated/oh_$$system/optohybrid_registers.xml && \
			python scripts/boards/optohybrid/update_xml.py -s $$system $$type -x address_table/gem/generated/oh_$$system/optohybrid_registers.xml && \
			cd regtools && python generate_registers.py -p generated/oh_$$system/ oh \
			\
		`# BACKEND ` ; \
			\
		else \
			`# GEM ` ; \
			if [[ $@ == *"me0"* ]] || [[ $@ == *"ge21"* ]] || [[ $@ == *"ge11"* ]] ; then \
				system="gem"; \
				module="gem_amc"; \
			`# CSC ` ; \
			elif [[ $@ == *"csc"* ]]; then \
				system="csc"; \
				module="csc_fed"; \
			`# unknown` ; \
			else \
				system="unknown"; \
			fi ; \
			\
			cd address_table/$$system && python generate_xml.py ; cd - ;\
			cd regtools && python generate_registers.py -p generated/$(patsubst update_%,%,$@)/ $$module ; cd - ;\
		fi ; \
	}

$(OPEN_LIST):
	vivado Projects/$(patsubst open_%,%,$@)/$(patsubst open_%,%,$@).xpr &

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

config: gitconfig

gitconfig:
	git config --local include.path ../.gitconfig

################################################################################
# Update from XML
################################################################################

update_cvp13: update_ge21_cvp13 update_me0_cvp13 update_csc_cvp13
update_ctp7: update_ge11_ctp7 update_ge21_ctp7 update_me0_ctp7 update_csc_ctp7
update_apex: update_ge21_apex update_me0_apex update_csc_apex

update_ge11: update_ge11_cvp13 update_ge11_ctp7 update_ge11_apex
update_ge21: update_ge21_cvp13 update_ge21_ctp7 update_ge21_apex
update_me0: update_me0_cvp13 update_me0_ctp7 update_me0_apex
update_csc: update_csc_cvp13 update_csc_ctp7 update_csc_apex

update: update_ge11 update_ge21 update_me0 update_csc

update_oh_base:
	@cd regtools && python generate_registers.py oh && cd -

update_oh: update_oh_base update_oh_ge21.200 update_oh_ge21.75 update_oh_ge11

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

all:  update create synth impl
#all: ge11 ge21 me0 csc
