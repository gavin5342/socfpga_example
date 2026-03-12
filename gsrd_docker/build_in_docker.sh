#! /bin/bash

source ./set_env.sh 

BOARD=agilex5_dk_a5e013bm16aea
docker exec -it ${BOARD}_container bash -c "pushd ${TOP_FOLDER}/gsrd_build; . ${BOARD}-gsrd-build.sh; build_default"
