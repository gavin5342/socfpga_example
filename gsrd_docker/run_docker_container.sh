#! /bin/bash
#
source ./set_env.sh

mkdir ./${TOP_FOLDER}
pushd ./${TOP_FOLDER}

git clone ${GSRD_URL}

docker run -v $PWD:$TOP_FOLDER  -it --user=$UID --name ${BOARD}_container -e BOARD -e TOP_FOLDER -d -t gsrd_image
