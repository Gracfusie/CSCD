#####################################################################################
# Description:  Behavorial & Gate-level Simulation Script
# Author:     	Mingxuan Li <mingxuanli_siris@163.com> [Peking University]

# Copied and modified from: cv32e40p/sim Makefile
#####################################################################################

### check whether TOP is defined
ifndef TOP
$(error ERROR! TOP variable is not defined. Please define the top-level module name by TOP=<name>_tb)
endif

### check whether TOP is testbench
CHECK_SUFFIX = $(shell echo ${TOP} | grep -q "_tb" && echo "yes" || echo "no")
ifneq (${CHECK_SUFFIX}, yes)
$(error ERROR! TOP variable is not suffixed by "_tb". Please define the top-level module name by TOP=<name>_tb)
endif

### Makefile absolute dir
ifndef SRC_DIR
export SRC_DIR = $(PWD)/../rtl
endif

VCS_OPTIONS = -full64						### run under 64-bit mode
VCS_OPTIONS += +v2k							### enable new Verilog constructs in the 1364-2001 standard
VCS_OPTIONS += -sverilog					### enable systemberilog syntax
VCS_OPTIONS += -l compile.log				### name of log file
VCS_OPTIONS += -timescale=1ps/1ps			### timescale for all RTL
VCS_OPTIONS += +notimingcheck				### neglect timing
VCS_OPTIONS += -assert svaext				### enable systemverilog assertion
VCS_OPTIONS += +lint=TFIPC-L				### print out detailed information of unconnected ports
VCS_OPTIONS += +lint=PCWM					### details about port connection width mismatch
VCS_OPTIONS += +define+SIM					### test for this definition in RTL using the `ifdef compiler directive
VCS_OPTIONS += -debug_access+dmptf			### enable dumping of ports and internal nodes/memories
VCS_OPTIONS += -debug_region+cell+encrypt	### apply debug capabilities to modules, programs, packages, and interfaces

### may used in gate-level simulation, but LIB_SRC and IO_SRC is not found... (gate_vcs, gate_verdi)

# define stdlib, sram, macro verilog file for gate-level simulation
# use '\#' instead of '#' to prevent 'make' from interpreting '#' as the start of a comment
# STD_LIB = $(shell sed -n '/^[^\#]*set std_lib /s/.*set std_lib \([^]]*\).*/\1/p' ../config/user_define.tcl)
# LIB_SRC = /work/home/wumeng/pdks/tsmc/tsmc22ull/${STD_LIB}_110a/digital/Front_End/verilog/${STD_LIB}_110a/${STD_LIB}.v
# IO_SRC	= /work/home/wumeng/pdks/tsmc/tsmc22ull/tphn22ullgv2od3_c171206_110b/digital/Front_End/verilog/tphn22ullgv2od3_c171206_110b/tphn22ullgv2od3_c171206.v

# SRAM_NAME = $(shell sed -n '/^[^\#]*set sram_insts \[list /s/.*set sram_insts \[list \([^]]*\).*/\1/p' ../config/user_define.tcl)
# SRAM_SRC = $(foreach name,${SRAM_NAME},${SRC_DIR}/sram/${name}/${name}.v)

# MACRO_NAME = $(shell sed -n '/^[^\#]*set macro_insts \[list /s/.*set macro_insts \[list \([^]]*\).*/\1/p' ../config/user_define.tcl)
# MACRO_SRC = $(foreach name,${MACRO_NAME},${SRC_DIR}/macro/${name}/${name}.v)

# NETLIST_TOP = $(subst _tb,,${TOP})
# NETLIST_SRC = ${SRC_DIR}/../syn/${NETLIST_TOP}/${NETLIST_TOP}_postsyn.v

# GATE_SRC = ${LIB_SRC} ${IO_SRC} ${SRAM_SRC} ${MACRO_SRC} ${NETLIST_SRC} ${SRC_DIR}/../sim/${TOP}.sv

vcs: 
	rm -rf build/
	mkdir build/
	cd build && \
	vcs ${VCS_OPTIONS} ${SRC_LIST} -top ${TOP} -R

verdi: vcs
	cd build && \
	verdi -sv +define+SIM ${SRC_LIST} -top ${TOP} -ssf waveform.fsdb

# gate_vcs:
# 	rm -rf build/
# 	mkdir build/
# 	cd build && \
# 	vcs ${VCS_OPTIONS} +vcs+initreg+random ${GATE_SRC} -top ${TOP} -R

# gate_verdi: gate_vcs
# 	echo ${GATE_SRC} > build/gate_filelist.f
# 	cd build && \
# 	verdi -sv -f gate_filelist.f -top ${TOP} -ssf waveform.fsdb
