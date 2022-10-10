#!/bin/bash
# Oliver Epper <oliver.epper@gmail.com>

set -e

if [ $# -eq 0 ]
then
    echo "sh ./start.sh <absolute path>"
    exit 1
fi

PREFIX=$1
OPUS_VERSION=v1.3.1
IOS_TOOLCHAIN_VERSION=4.3.0

if [ -d opus ]
then
    pushd opus
    git clean -fxd
    git reset --hard $OPUS_VERSION
    popd
else
    git -c advice.detachedHead=false clone --depth 1 --branch $OPUS_VERSION https://gitlab.xiph.org/xiph/opus
fi

if [ -d ios-cmake ]
then
    pushd ios-cmake
    git clean -fxd
    git reset --hard $IOS_TOOLCHAIN_VERSION
    popd
else
    git -c advice.detachedHead=false clone --depth 1 --branch $IOS_TOOLCHAIN_VERSION https://github.com/leetal/ios-cmake.git
fi

function build {
    local TOOLCHAIN_PLATFORM_NAME=$1
    local INSTALL_PREFIX=$2
    local DEPLOYMENT_TARGET=$3

    echo "Building for platform ${TOOLCHAIN_PLATFORM_NAME} with deployment target ${DEPLOYMENT_TARGET}"
    echo "Installing to: ${INSTALL_PREFIX}"

    cmake -Bbuild/"${TOOLCHAIN_PLATFORM_NAME}" \
        -Sopus \
        -G Ninja \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
        -DCMAKE_TOOLCHAIN_FILE=../ios-cmake/ios.toolchain.cmake \
        -DPLATFORM="${TOOLCHAIN_PLATFORM_NAME}" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="${DEPLOYMENT_TARGET}" \
        -DENABLE_BITCODE=OFF &&

    cmake --build build/"${TOOLCHAIN_PLATFORM_NAME}" \
        --config Release \
        --target install
}


# build for iOS on arm64#
IOS_ARM64_INSTALL_PREFIX="${PREFIX}/ios-arm64"
build OS64 "${IOS_ARM64_INSTALL_PREFIX}" 13.0

# build for iOS simulator on arm64
IOS_ARM64_SIMULATOR_INSTALL_PREFIX="${PREFIX}/ios-arm64-simulator"
build SIMULATORARM64 "${IOS_ARM64_SIMULATOR_INSTALL_PREFIX}" 13.0

# build for iOS simulator on x86_64
IOS_X86_64_SIMULATOR_INSTALL_PREFIX="${PREFIX}/ios-x86_64-simulator"
build SIMULATOR64 "${IOS_X86_64_SIMULATOR_INSTALL_PREFIX}" 13.0

# build fat lib for simulator
IOS_ARM64_X86_64_SIMULATOR_INSTALL_PREFIX="${PREFIX}/ios-arm64_x86_64-simulator"
mkdir -p "${IOS_ARM64_X86_64_SIMULATOR_INSTALL_PREFIX}/lib"
lipo -create \
    "${IOS_ARM64_SIMULATOR_INSTALL_PREFIX}/lib/libopus.a" \
    "${IOS_X86_64_SIMULATOR_INSTALL_PREFIX}/lib/libopus.a" \
    -output \
    "${IOS_ARM64_X86_64_SIMULATOR_INSTALL_PREFIX}/lib/libopus.a"

# build for Catalyst on arm64
IOS_ARM64_MACCATALYST_INSTALL_PREFIX="${PREFIX}/ios-arm64-maccatalyst"
build MAC_CATALYST_ARM64 "${IOS_ARM64_MACCATALYST_INSTALL_PREFIX}" 13.1

# build for Catalyst on x86_64
IOS_X86_64_MACCATALYST_INSTALL_PREFIX="${PREFIX}/ios-x86_64-maccatalyst"
build MAC_CATALYST "${IOS_X86_64_MACCATALYST_INSTALL_PREFIX}" 13.1

# build fat lib for catalyst
IOS_ARM64_X86_64_MACCATALYST_INSTALL_PREFIX="${PREFIX}/ios-arm64_x86_64-maccatalyst"
mkdir -p "${IOS_ARM64_X86_64_MACCATALYST_INSTALL_PREFIX}/lib"
lipo -create \
    "${IOS_ARM64_MACCATALYST_INSTALL_PREFIX}/lib/libopus.a" \
    "${IOS_X86_64_MACCATALYST_INSTALL_PREFIX}/lib/libopus.a" \
    -output \
    "${IOS_ARM64_X86_64_MACCATALYST_INSTALL_PREFIX}/lib/libopus.a"

# build for macOS on arm64
MACOS_ARM64_INSTALL_PREFIX="${PREFIX}/macos-arm64"
build MAC_ARM64 "${MACOS_ARM64_INSTALL_PREFIX}" 11.0

# build for macOS on x86_64
MACOS_X86_64_INSTALL_PREFIX="${PREFIX}/macos-x86_64"
build MAC "${MACOS_X86_64_INSTALL_PREFIX}" 11.0

# build fat lib for macos
MACOS_ARM64_X86_64_INSTALL_PREFIX="${PREFIX}/macos-arm64_x86_64"
mkdir -p "${MACOS_ARM64_X86_64_INSTALL_PREFIX}/lib"
lipo -create \
    "${MACOS_ARM64_INSTALL_PREFIX}/lib/libopus.a" \
    "${MACOS_X86_64_INSTALL_PREFIX}/lib/libopus.a" \
    -output \
    "${MACOS_ARM64_X86_64_INSTALL_PREFIX}/lib/libopus.a"

# create xcframework
mkdir -p "$PREFIX"/lib
XCFRAMEWORK="$PREFIX/lib/libopus.xcframework"
rm -rf "$XCFRAMEWORK"
xcodebuild -create-xcframework \
-library "${IOS_ARM64_INSTALL_PREFIX}/lib/libopus.a" \
-headers "${IOS_ARM64_INSTALL_PREFIX}/include" \
-library "${IOS_ARM64_X86_64_SIMULATOR_INSTALL_PREFIX}/lib/libopus.a" \
-headers "${IOS_ARM64_SIMULATOR_INSTALL_PREFIX}/include" \
-library "${IOS_ARM64_X86_64_MACCATALYST_INSTALL_PREFIX}/lib/libopus.a" \
-headers "${IOS_ARM64_MACCATALYST_INSTALL_PREFIX}/include" \
-library "${MACOS_ARM64_X86_64_INSTALL_PREFIX}/lib/libopus.a" \
-headers "${MACOS_ARM64_INSTALL_PREFIX}/include" \
-output "${XCFRAMEWORK}"

# install the system version
cp -a "${PREFIX}/macOS-$(arch)/include" "${PREFIX}"
cp -a "${PREFIX}/macOS-$(arch)/lib" "${PREFIX}"

# clean-up for now
rm -rf "${IOS_ARM64_X86_64_SIMULATOR_INSTALL_PREFIX}"
rm -rf "${IOS_ARM64_X86_64_MACCATALYST_INSTALL_PREFIX}"
rm -rf "${MACOS_ARM64_X86_64_INSTALL_PREFIX}"