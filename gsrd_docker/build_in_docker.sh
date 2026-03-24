#! /bin/bash

source ./set_env.sh 

docker exec -it ${BOARD}_container bash -c "pushd ${TOP_FOLDER}/${GSRD_REPO}; . ${BOARD}-gsrd-build.sh; build_default"
