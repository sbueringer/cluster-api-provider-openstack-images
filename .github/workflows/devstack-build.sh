#!/bin/bash

set -euo pipefail


DATE=$(date +%Y%m%d-%H%M)

UBUNTU_VERSION="2004"

SHORT_SHA="$(git rev-parse --short HEAD)"
MAKE_VERSION="build-qemu-ubuntu-${UBUNTU_VERSION}"
BUILD_VERSION="${UBUNTU_VERSION}-${SHORT_SHA}-${DATE}"
BUILD_DIR=./output/devstack/
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

export PACKER_FLAGS="-debug -var 'accelerator=none' -var 'cpus=2' -var 'disk_size=10240' -var 'memory=6144'"
export PACKER_LOG=1
export PACKER_LOG_PATH=/tmp/packer.log
tail -F ${PACKER_LOG_PATH} &

make "${MAKE_VERSION}"

ls -la ${BUILD_DIR}

echo -e "[INFO] Version of image: ${BUILD_VERSION}\n"

echo "Converting qcow2 to streamOptimized vmdk"
qemu-img convert -f qcow2 -O vmdk -o subformat=streamOptimized ${BUILD_DIR}/${IMAGE_NAME} ${BUILD_DIR}/${IMAGE_NAME}.vmdk

echo "Compressing qcow2"
qemu-img convert -f qcow2 -O qcow2 -c ${BUILD_DIR}/${IMAGE_NAME} ${BUILD_DIR}/${IMAGE_NAME}.qcow2
