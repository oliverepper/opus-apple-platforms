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
CFLAGS="-O2 -fembed-bitcode -fPIC"
TARGETS="IOS_SIM_ARM64 IOS_SIM_X86_64 IOS_ARM64 MACOS_ARM64 MACOS_X86_64"

if [ -d opus ]
then
    pushd opus
    git reset --hard $OPUS_VERSION
    popd
else
    git -c advice.detachedHead=false clone --depth 1 --branch $OPUS_VERSION https://gitlab.xiph.org/xiph/opus
fi

#
# prepare
#
pushd opus
if [[ ! -f configure ]]
then
    ./autogen.sh
fi
popd

#
# build for iOS simulator running on arm64
#
OUT_IOS_SIM_ARM64=$PREFIX/iOS_simulator_arm64
if [[ $TARGETS =~ "IOS_SIM_ARM64" ]]; then
rm -rf "$OUT_IOS_SIM_ARM64"
pushd opus
./configure --prefix="$OUT_IOS_SIM_ARM64" --host=arm-apple-darwin \
    CFLAGS="-isysroot $(xcrun -sdk iphonesimulator --show-sdk-path) -miphonesimulator-version-min=13.0 $CFLAGS" 
make
make install
make clean
popd
fi

#
# build for iOS simulator running on x86_64
#
OUT_IOS_SIM_X86_64=$PREFIX/iOS_simulator_x86_64
if [[ $TARGETS =~ "IOS_SIM_X86_64" ]]; then
rm -rf "$OUT_IOS_SIM_X86_64"
pushd opus
arch -arch x86_64 ./configure --prefix="$OUT_IOS_SIM_X86_64" --host=x86_64-apple-darwin \
    CFLAGS="-isysroot $(xcrun -sdk iphonesimulator --show-sdk-path) -miphonesimulator-version-min=13.0 $CFLAGS"
arch -arch x86_64 make
arch -arch x86_64 make install
arch -arch x86_64 make clean
popd
fi

#
# build for iOS arm64
#
OUT_IOS_ARM64=$PREFIX/iOS_arm64
if [[ $TARGETS =~ "IOS_ARM64" ]]; then
rm -rf "$OUT_IOS_ARM64"
pushd opus
./configure --prefix="$OUT_IOS_ARM64" --host=arm-apple-darwin \
    CFLAGS="-isysroot $(xcrun -sdk iphoneos --show-sdk-path) -miphoneos-version-min=13.0 $CFLAGS"
make
make install
make clean
popd
fi

#
# build for macOS arm64
#
OUT_MACOS_ARM64=$PREFIX/macOS_arm64
if [[ $TARGETS =~ "MACOS_ARM64" ]]; then
rm -rf "$OUT_MACOS_ARM64"
pushd opus
make clean
./configure --prefix="$OUT_MACOS_ARM64" --host=arm-apple-darwin \
    CFLAGS="-isysroot $(xcrun -sdk macosx --show-sdk-path) -mmacosx-version-min=11 $CFLAGS"
make
make install
make clean
popd
fi

#
# build for macOS x86_64
#
OUT_MACOS_X86_64=$PREFIX/macOS_x86_64
if [[ $TARGETS =~ "MACOS_X86_64" ]]; then
rm -rf "$OUT_MACOS_X86_64"
CFLAGS=" $CFLAGS"
pushd opus
make clean
arch -arch x86_64 ./configure --prefix="$OUT_MACOS_X86_64" --host=x86_64-apple-darwin \
    CFLAGS="-isysroot $(xcrun -sdk macosx --show-sdk-path) -mmacosx-version-min=11 $CFLAGS"
arch -arch x86_64 make
arch -arch x86_64 make install
arch -arch x86_64 make clean
popd
fi

#
# create fat lib for the mac
#
if [ -f "$OUT_MACOS_ARM64"/lib/libopus.a ] && [ -f "$OUT_MACOS_X86_64"/lib/libopus.a ]; then
OUT_MACOS=$PREFIX/macOS
mkdir -p "$OUT_MACOS"/lib
lipo -create "$OUT_MACOS_ARM64"/lib/libopus.a "$OUT_MACOS_X86_64"/lib/libopus.a -output "$OUT_MACOS"/lib/libopus.a
fi

#
# create fat lib for the simulator
#
if [ -f "$OUT_IOS_SIM_ARM64"/lib/libopus.a ] && [ -f "$OUT_IOS_SIM_X86_64"/lib/libopus.a ]; then
OUT_IOS_SIM=$PREFIX/iOS_simulator
mkdir -p "$OUT_IOS_SIM"/lib
lipo -create "$OUT_IOS_SIM_ARM64"/lib/libopus.a "$OUT_IOS_SIM_X86_64"/lib/libopus.a -output "$OUT_IOS_SIM"/lib/libopus.a
fi

#
# create xcframework
#
mkdir -p "$PREFIX"/lib
XCFRAMEWORK="$PREFIX/lib/libopus.xcframework"
rm -rf "$XCFRAMEWORK"
xcodebuild -create-xcframework \
-library "$OUT_IOS_ARM64"/lib/libopus.a \
-library "$OUT_IOS_SIM"/lib/libopus.a \
-library "$OUT_MACOS"/lib/libopus.a \
-output "$XCFRAMEWORK"

mkdir -p "$XCFRAMEWORK"/Headers
cp -a "$OUT_MACOS_ARM64"/include/* "$XCFRAMEWORK"/Headers

/usr/libexec/PlistBuddy -c 'add:HeadersPath string Headers' "$XCFRAMEWORK"/Info.plist

rm -rf "$OUT_IOS_SIM"
rm -rf "$OUT_MACOS"

#
# don't just link lib & include
#
echo "HERE"
mkdir -p "$PREFIX"/{"lib/pkgconfig",include}
cp -a "$PREFIX"/"macOS_$(arch)"/include/* "$PREFIX"/include

#
# create pkgconfig for SPM
#
echo "HERE2"
sed -e /^libdir=/d -e 's/^Libs: .*$/Libs: -lopus/' < "$PREFIX"/"macOS_$(arch)"/lib/pkgconfig/opus.pc > "$PREFIX"/lib/pkgconfig/opus-SPM.pc
