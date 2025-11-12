#####################################################################################
# Description:  Top Makefile for Simulation, Synthesis and Physical Implementation
# Author:       Mingxuan Li <mingxuanli_siris@163.com> [Peking University]

# Copied and modified from: cv32e40p Makefile
#####################################################################################

export SRC_DIR = $(PWD)/rtl
export SRC_LIST

ifdef NPU_TB
SRC_LIST = -file ${SRC_DIR}/filelist_load.f
TOP = NPU_top_load_tb
else
SRC_LIST = -file ${SRC_DIR}/filelist.f
TOP = cv32e40p_xilinx_tb
endif


vcs:
	$(MAKE) -C sim vcs TOP=$(TOP)

verdi:
	$(MAKE) -C sim verdi TOP=$(TOP)

gate_vcs:
	$(MAKE) -C sim gate_vcs TOP=$(TOP)

gate_verdi:
	$(MAKE) -C sim gate_verdi TOP=$(TOP)

# genus:
# 	$(MAKE) -C syn genus TOP=$(TOP)

# restore_genus:
# 	$(MAKE) -C syn restore TOP=$(TOP)

# innovus:
# 	$(MAKE) -C pnr innovus TOP=$(TOP)

# restore_innovus:
# 	$(MAKE) -C pnr restore TOP=$(TOP) STAGE=$(STAGE)

SRAM_SRC_C1 = handout_new/data/conv1_weight.txt
SRAM_SRC_I = handout_new/data/sample_input.txt
SRAM_DST = rtl/cv32e40p/fpga/tb/icache.hex

gen_dcache:
	python3 genmci/SRAMhex_gen.py $(SRAM_SRC_C1) $(SRAM_SRC_I) $(SRAM_DST)
# virtuoso:
# 	$(MAKE) -C layout virtuoso
