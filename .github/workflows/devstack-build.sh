#!/bin/bash

set -euo pipefail


DATE=$(date +%Y%m%d-%H%M)

UBUNTU_VERSION="2004"

SHORT_SHA="$(git rev-parse --short HEAD)"
MAKE_VERSION="build-qemu-ubuntu-${UBUNTU_VERSION}"
BUILD_VERSION="${UBUNTU_VERSION}-${SHORT_SHA}-${DATE}"
BUILD_DIR=./output/devstack
IMAGE_NAME=devstack

echo "Install prerequisites"

sudo apt update && sudo apt-get install -y \
    unzip \
    wget \
    curl \
    make \
    python3 \
    qemu-system \
    git \
    jq \
    rsync
make deps-qemu

echo "Building image ubuntu-$BUILD_VERSION''"

# https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners
export PACKER_FLAGS="-debug -var 'accelerator=none' -var 'cpus=2' -var 'disk_size=10240' -var 'memory=6144'"
export PACKER_LOG=1
export PACKER_LOG_PATH=/tmp/packer.log
tail -F ${PACKER_LOG_PATH} &

make "${MAKE_VERSION}"

ls -la ${BUILD_DIR}

echo -e "[INFO] Version of image: ${BUILD_VERSION}\n"

# we have to cleanup files so we can upload all files in the build dir

# TODO: adjust to the manual build doc if it should be used

echo "Converting qcow2 to raw"
qemu-img convert -f qcow2 -O raw ${BUILD_DIR}/${IMAGE_NAME} ${BUILD_DIR}/disk.raw
pushd ${BUILD_DIR} || exit 1
tar --format=oldgnu -Sczf ${IMAGE_NAME}.raw.tar.gz disk.raw
popd || exit 1
split -b 1500M --numeric-suffixes ${BUILD_DIR}/${IMAGE_NAME}.raw.tar.gz "${BUILD_DIR}/${IMAGE_NAME}/${IMAGE_NAME}.raw.tar.gz.part"
rm -f ${BUILD_DIR}/disk.raw
rm -f ${BUILD_DIR}/${IMAGE_NAME}.raw.tar.gz

echo "Converting qcow2 to streamOptimized vmdk"
qemu-img convert -f qcow2 -O vmdk -o subformat=streamOptimized ${BUILD_DIR}/${IMAGE_NAME} ${BUILD_DIR}/${IMAGE_NAME}.vmdk
split -b 1500M --numeric-suffixes ${BUILD_DIR}/${IMAGE_NAME}.vmdk "${BUILD_DIR}/${IMAGE_NAME}/${IMAGE_NAME}.vmdk.part"
rm -f ${BUILD_DIR}/${IMAGE_NAME}.vmdk

echo "Compressing qcow2"
qemu-img convert -f qcow2 -O qcow2 -c ${BUILD_DIR}/${IMAGE_NAME} ${BUILD_DIR}/${IMAGE_NAME}.qcow2
split -b 1500M --numeric-suffixes ${BUILD_DIR}/${IMAGE_NAME}.qcow2 "${BUILD_DIR}/${IMAGE_NAME}/${IMAGE_NAME}.qcow2.part"
rm -f ${BUILD_DIR}/${IMAGE_NAME}.qcow2

rm -f ${BUILD_DIR}/${IMAGE_NAME}

ls -la ${BUILD_DIR}
