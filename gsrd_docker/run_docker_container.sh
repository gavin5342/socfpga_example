#! /bin/bash
#
source ./set_env.sh

mkdir -p ${TOP_FOLDER}
pushd ${TOP_FOLDER}

# only clone if the dir doesn't alrady exist
[ -d ${GSRD_REPO} ] || git clone ${GSRD_URL}
# checkout correct tag
pushd ${GSRD_REPO}
git checkout ${GSRD_TAG}
popd

docker run -v ${TOP_FOLDER}:${TOP_FOLDER}  -it --user=$UID --name ${BOARD}_container -e BOARD -e TOP_FOLDER -e GSRD_REPO -d -t gsrd_image

popd
