#!/bin/bash

PROJECT=$1
BASE_DIR=".."
VIVADO_VER="2021.1"

if [ -z "$PROJECT" ]; then
        echo Please provide a project name e.g. ge21_cvp13
	exit
fi

if [ "$2" ]; then
	VIVADO_VER=$2
fi

echo "Using Vivado $VIVADO_VER"

mkdir $BASE_DIR/sigasi
mkdir $BASE_DIR/sigasi/$PROJECT

#sorry, I hardcoded my paths here, you have to change these to point to your vivado instalation and the directory where you've cloned https://github.com/sigasi/SigasiProjectCreator.git

SCRIPTS_DIR=`pwd`
cd $BASE_DIR/sigasi/$PROJECT
source /opt/Xilinx/Vivado/$VIVADO_VER/settings64.sh
#generate a list of files in CSV format
vivado -mode batch -source $HOME/programs/dev/sigasi/SigasiProjectCreator/convertVivadoProjectToCsv.tcl $SCRIPTS_DIR/../Projects/$PROJECT/$PROJECT.xpr

#generate the sigasi project
python2 $HOME/programs/dev/sigasi/SigasiProjectCreator/convertCsvFileToTree.py $PROJECT vivado_files.csv

#remove all IP files
sed -i "/\/ip\//d" .library_mapping.xml

#add unisim libs
sed -i -e "/xmlns:com.sigasi/a"$'\\\n'"  <Mappings Location=\"Common Libraries/unisim\" Library=\"unisim\"/>"$'\n' .library_mapping.xml
sed -i -e "/xmlns:com.sigasi/a"$'\\\n'"  <Mappings Location=\"Common Libraries/unisim/unisim_VCOMP.vhd\" Library=\"unisim\"/>"$'\n' .library_mapping.xml
sed -i -e "/xmlns:com.sigasi/a"$'\\\n'"  <Mappings Location=\"Common Libraries/unisim/secureip\" Library=\"not mapped\"/>"$'\n' .library_mapping.xml
sed -i -e "/xmlns:com.sigasi/a"$'\\\n'"  <Mappings Location=\"Common Libraries/unisim/primitive\" Library=\"not mapped\"/>"$'\n' .library_mapping.xml
sed -i -e "/xmlns:com.sigasi/a"$'\\\n'"  <Mappings Location=\"Common Libraries/unimacro/unimacro_VCOMP.vhd\" Library=\"unimacro\"/>"$'\n' .library_mapping.xml
sed -i -e "/xmlns:com.sigasi/a"$'\\\n'"  <Mappings Location=\"Common Libraries/xpm/xpm_VCOMP.vhd\" Library=\"xpm\"/>"$'\n' .library_mapping.xml
sed -i -e "/<linkedResources>/a"$'\\\n'"		<link>\n			<name>Common Libraries/unisim</name>\n			<type>2</type>\n			<locationURI>SIGASI_TOOLCHAIN_XILINX_VIVADO/data/vhdl/src/unisims</locationURI>\n		</link>"$'\n' .project
sed -i -e "/<linkedResources>/a"$'\\\n'"		<link>\n			<name>Common Libraries/unimacro</name>\n			<type>2</type>\n			<locationURI>SIGASI_TOOLCHAIN_XILINX_VIVADO/data/vhdl/src/unimacro</locationURI>\n		</link>"$'\n' .project
sed -i -e "/<linkedResources>/a"$'\\\n'"		<link>\n			<name>Common Libraries/xpm</name>\n			<type>2</type>\n			<locationURI>SIGASI_TOOLCHAIN_XILINX_VIVADO/data/ip/xpm</locationURI>\n		</link>"$'\n' .project
