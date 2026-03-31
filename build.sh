#!/usr/bin/env bash

set -x
set -e

WORKING_DIR=$(pwd)
MUMBLE_TAG="1.5.857"
MUMBLE_BUILD_NUMBER="857"
MUMBLE_ENV_TAG="2025-07_qt5"

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
git clone --branch "$MUMBLE_ENV_TAG" --depth 1 https://github.com/mumble-voip/vcpkg
wget -O mumble.tar.gz "https://github.com/mumble-voip/mumble/releases/download/v$MUMBLE_TAG/mumble-$MUMBLE_TAG.tar.gz"

tar xf mumble.tar.gz
rm mumble.tar.gz

pushd vcpkg
# Fix for ICE hash
git apply "$WORKING_DIR/0001-fix-sha512-hash-for-zeroc-ice-mumble.patch"
# Use Qt5
git apply "$WORKING_DIR/0002-use-qt5-for-qt.patch"
MUMBLE_ENV_NAME="mumble_env.x64-linux.$( date +"%Y-%m-%d" ).$( git rev-parse --short --verify HEAD )"
./build_mumble_dependencies.sh
MUMBLE_VCPKG_ROOT=$(pwd)
popd

pushd "mumble-$MUMBLE_TAG"
cmake -Bbuild -G "Unix Makefiles" \
    -DCMAKE_TOOLCHAIN_FILE="${MUMBLE_VCPKG_ROOT}/${MUMBLE_ENV_NAME}/scripts/buildsystems/vcpkg.cmake" \
    -DIce_HOME="${MUMBLE_VCPKG_ROOT}/${MUMBLE_ENV_NAME}/installed/x64-linux" \
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

