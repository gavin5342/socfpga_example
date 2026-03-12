#! /bin/bash

#
TOP_FOLDER=gsrd_build
# GSRD tag to build.  To see tags, cd gsrd_socfpga then git tag
GSRD_TAG='QPDS25.3.1_REL_AGILEX5_013B_GSRD_PR'
# use ssh url, https is commeneted out below if more convenient
GSRD_URL='git@github.com:altera-fpga/gsrd-socfpga.git'
# GSRD_URL='https://github.com/altera-fpga/gsrd-socfpga.git'
# ls gsrd_socfpga/*.sh to see possibilities for BOARD
BOARD=agilex5_dk_a5e013bm16aea

