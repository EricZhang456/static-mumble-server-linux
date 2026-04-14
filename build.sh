#!/usr/bin/env bash

set -x
set -e

WORKING_DIR=$(pwd)
MUMBLE_TAG="1.6.870"
MUMBLE_BUILD_NUMBER="870"
MUMBLE_ENV_TAG="2026-02"
MUMBLE_ENV_NAME="mumble_env.x64-linux.b1fe4a4257"

sudo apt-get -y update
sudo apt-get -y upgrade

# https://github.com/mumble-voip/mumble/blob/master/.github/actions/install-dependencies/install_ubuntu_static_x86_64.sh
sudo apt-get -y install \
    build-essential \
    curl \
    zip \
    libtirpc-dev \
    unzip \
    tar \
    g++-multilib \
    `# Still required for qtbase vcpkg package` \
    '^libxcb.*-dev' libx11-xcb-dev libglu1-mesa-dev libxrender-dev libxi-dev libxkbcommon-dev libxkbcommon-x11-dev libegl1-mesa-dev \
    `# TODO: can we get rid of these by replacing with vcpkg packages?` \
    libsm-dev \
    libspeechd-dev \
    libavahi-compat-libdnssd-dev \
    libasound2-dev \
    linux-libc-dev \
    flex \
    libltdl-dev \
    autoconf-archive \
    libbluetooth-dev \
    libdbus-1-dev \
    libxtst-dev \
    libedit-dev

mkdir mumble-builddir

pushd mumble-builddir
wget -O mumble.tar.gz "https://github.com/mumble-voip/mumble/releases/download/v$MUMBLE_TAG/mumble-$MUMBLE_TAG.tar.gz"

tar xf mumble.tar.gz
rm mumble.tar.gz

wget -O vcpkg.tar.xz "https://github.com/mumble-voip/vcpkg/releases/download/$MUMBLE_ENV_TAG/$MUMBLE_ENV_NAME.tar.xz"
tar xf vcpkg.tar.xz
rm vcpkg.tar.xz

pushd "$MUMBLE_ENV_NAME"
MUMBLE_VCPKG_ROOT=$(pwd)
popd

pushd "mumble-$MUMBLE_TAG"
cmake -Bbuild -G "Unix Makefiles" \
    -DCMAKE_TOOLCHAIN_FILE="${MUMBLE_VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake" \
    -DIce_HOME="${MUMBLE_VCPKG_ROOT}/installed/x64-linux" \
    -DBUILD_NUMBER="$MUMBLE_BUILD_NUMBER" \
    -DVCPKG_TARGET_TRIPLET="x64-linux" \
    -Dstatic=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -Dclient=OFF \
    -Dserver=ON \
    -Dice=ON \
    -Dtests=OFF \
    -Dwarnings-as-errors=OFF \
    -Dzeroconf=OFF

cmake --build build -- -j $(nproc)
popd
popd

mkdir mumble-packagedir

mv "mumble-builddir/mumble-$MUMBLE_TAG/build/mumble-server" mumble-packagedir
strip mumble-packagedir/mumble-server

tar czf "mumble-server.tar.gz" -C mumble-packagedir .

rm -rf mumble-builddir
rm -rf mumble-packagedir

