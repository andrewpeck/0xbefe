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
IMPL_ONLY_LIST = $(addprefix impl_only_,$(PROJECT_LIST))
OPEN_LIST = $(addprefix open_,$(PROJECT_LIST))
UPDATE_LIST = $(addprefix update_,$(PROJECT_LIST))

list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

$(CREATE_LIST):
	@echo -------------------------------------------------------------------------------- $(COLORIZE)
	@echo Creating Project $(patsubst create_%,%,$@)                                       $(COLORIZE)
	@echo -------------------------------------------------------------------------------- $(COLORIZE)
	@time Hog/CreateProject.sh $(patsubst create_%,%,$@)                                   $(COLORIZE)

$(IMPL_ONLY_LIST):
	@echo -------------------------------------------------------------------------------- $(COLORIZE)
	@echo Launching Hog Workflow $(patsubst impl_only_%,%,$@) with njobs = $(NJOBS)        $(COLORIZE)
	@echo -------------------------------------------------------------------------------- $(COLORIZE)
	@time Hog/LaunchWorkflow.sh $(patsubst impl_only_%,%,$@) -njobs $(NJOBS)               $(COLORIZE)

$(IMPL_LIST):
	@make $(patsubst impl_%,create_%,$@)
	@make $(patsubst impl_%,impl_only_%,$@)

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
			flavor="$(patsubst update_%,%,$@)"; \
			# GEM \
			if [[ $${flavor} =~ ^(g|m)e ]]; then \
				system="gem"; \
				module="gem_amc"; \
			# CSC \
			elif [[ $${flavor} =~ ^csc ]]; then \
				system="csc"; \
				module="csc_fed"; \
			# Unknown \
			else \
				echo "==== ERROR: cannot determine system (GEM, CSC) for flavor $${flavor} ===="; \
				exit 1; \
			fi; \
			cd address_table/$${system} && python generate_xml.py; cd -; \
			do_update=false; \
			for d in address_table/$${system}/generated/$${flavor}*; do \
				if [[ ! -f $${d}/$${module}.xml ]]; then \
					# Could be an hard error, but regtools creates an empty directory for hybrid firmware \
					echo "==== WARNING: $${module}.xml does not exist in $${d}, skipping... ===="; \
					continue; \
				fi; \
				\
				table_name=$${d#address_table/$${system}/generated/}; \
				if [[ $${table_name} =~ ^$${flavor}_flavor_(.*)$$ ]]; then \
					station="$${BASH_REMATCH[1]}"; \
				elif [[ $${table_name} = $${flavor} ]]; then \
					station=$${flavor%%_*}; \
				else \
					# Only exact and flavored matches are used \
					continue; \
				fi; \
				\
				if [[ $${station} != "csc" ]]; then \
					extra_args="-f $${station}"; \
				else \
					extra_args=; \
				fi; \
				cd regtools && python generate_registers.py -p generated/$${flavor}/ $${extra_args} -a ../$${d}/$${module}.xml -u $${do_update} $${module}; cd - ;\
				do_update=true; \
			done; \
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
update_x2o: update_ge21_x2o update_me0_x2o update_csc_x2o

update_ge11: update_ge11_cvp13 update_ge11_ctp7 update_ge11_apex
update_ge21: update_ge21_cvp13 update_ge21_ctp7 update_ge21_apex update_ge21_x2o
update_me0: update_me0_cvp13 update_me0_ctp7 update_me0_apex update_me0_x2o
update_csc: update_csc_cvp13 update_csc_ctp7 update_csc_apex update_csc_x2o

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
create_x2o: create_ge11_x2o create_ge21_x2o create_me0_x2o create_csc_x2o

create_ge11: create_ge11_cvp13 create_ge11_ctp7 create_ge11_apex create_ge11_x2o
create_ge21: create_ge21_cvp13 create_ge21_ctp7 create_ge21_apex create_ge21_x2o
create_me0: create_me0_cvp13 create_me0_ctp7 create_me0_apex create_me0_x2o
create_csc: create_csc_cvp13 create_csc_apex create_csc_x2o

create: create_ge11 create_ge21 create_me0 create_csc

################################################################################
# compile (synth + impl)
################################################################################

cvp13: impl_ge11_cvp13 impl_ge21_cvp13 impl_me0_cvp13 impl_csc_cvp13
ctp7: impl_ge11_ctp7 impl_ge21_ctp7 impl_me0_ctp7
apex: impl_ge11_apex impl_ge21_apex impl_me0_apex impl_csc_apex
x2o: impl_ge11_x2o impl_ge21_x2o impl_me0_x2o impl_csc_x2o

ge11: impl_ge11_cvp13 impl_ge11_ctp7 impl_ge11_apex impl_ge11_x2o
ge21: impl_ge21_cvp13 impl_ge21_ctp7 impl_ge21_apex impl_ge21_x2o
me0: impl_me0_cvp13 impl_me0_ctp7 impl_me0_apex impl_me0_x2o
csc: impl_csc_cvp13 impl_csc_apex impl_csc_x2o

all:  update create synth impl
#all: ge11 ge21 me0 csc
