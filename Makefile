#####################################################################################
# Description:  Top Makefile for Simulation, Synthesis and Physical Implementation
# Author:       Mingxuan Li <mingxuanli_siris@163.com> [Peking University]

# Copied and modified from: cv32e40p Makefile
#####################################################################################

export SRC_DIR = $(PWD)/rtl

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

# virtuoso:
# 	$(MAKE) -C layout virtuoso
