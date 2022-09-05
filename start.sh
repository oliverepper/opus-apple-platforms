#!/bin/sh
# Oliver Epper <oliver.epper@gmail.com>

export OPUS_VERSION=v1.3.1
CFLAGS="-O2 -fembed-bitcode"
TARGETS="IOS_SIM_ARM64 IOS_SIM_X86_64 IOS_ARM64 MACOS_ARM64 MACOS_X86_64"
BUILD_DIR=$PWD/build

function clean {
    echo "Cleaning"
    rm -rf opus build
    rm clean.sh .install.sh
}

function install {
    local PREFIX=$1
    
    mkdir -p $PREFIX/lib/pkgconfig

    # copy xcframework
    cp -a build/libopus.xcframework $PREFIX

    # link in lib
    pushd $PREFIX/lib
    ln -sf ../libopus.xcframework .
    popd

    # link in include
    pushd $PREFIX
    ln -sf libopus.xcframework/Headers include
    popd

    # create pkg-config files

    exit 0
}

me=`basename $0`
if [[ $me = "clean.sh" ]]
then
    clean
    exit 0
elif [[ $me = ".install.sh" ]]
then
    install $1
    exit 0
fi

if [[ ! -f clean.sh ]]
then
    ln -sf start.sh clean.sh
fi

if [[ ! -f .install.sh ]]
then
    ln -sf start.sh .install.sh
fi

git -c advice.detachedHead=false clone --depth 1 --branch $OPUS_VERSION https://gitlab.xiph.org/xiph/opus

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
OUT_IOS_SIM_ARM64=$BUILD_DIR/iOS_simulator_arm64
if [[ $TARGETS =~ "IOS_SIM_ARM64" ]]; then
rm -rf $OUT_IOS_SIM_ARM64
pushd opus
make clean
./configure --prefix=$OUT_IOS_SIM_ARM64 --host=arm-apple-darwin \
    CFLAGS="-isysroot `xcrun -sdk iphonesimulator --show-sdk-path` $CFLAGS" 
make
make install
popd
fi

#
# build for iOS simulator running on x86_64
#
OUT_IOS_SIM_X86_64=$BUILD_DIR/iOS_simulator_x86_64
if [[ $TARGETS =~ "IOS_SIM_X86_64" ]]; then
rm -rf $OUT_IOS_SIM_X86_64
pushd opus
make clean
arch -arch x86_64 ./configure --prefix=$OUT_IOS_SIM_X86_64 --host=x86_64-apple-darwin \
    CFLAGS="-isysroot `xcrun -sdk iphonesimulator --show-sdk-path` $CFLAGS"
arch -arch x86_64 make
arch -arch x86_64 make install
popd
fi

#
# build for iOS arm64
#
OUT_IOS_ARM64=$BUILD_DIR/iOS_arm64
if [[ $TARGETS =~ "IOS_ARM64" ]]; then
rm -rf $OUT_IOS_ARM64
pushd opus
make clean
./configure --prefix=$OUT_IOS_ARM64 --host=arm-apple-darwin \
    CFLAGS="-isysroot `xcrun -sdk iphoneos --show-sdk-path` $CFLAGS"
make
make install
popd
fi

#
# build for macOS arm64
#
OUT_MACOS_ARM64=$BUILD_DIR/macOS_arm64
if [[ $TARGETS =~ "MACOS_ARM64" ]]; then
rm -rf $OUT_MACOS_ARM64
pushd opus
make clean
./configure --prefix=$OUT_MACOS_ARM64 --host=arm-apple-darwin \
    CFLAGS="-isysroot `xcrun -sdk macosx --show-sdk-path` $CFLAGS"
make
make install
popd
fi

#
# build for macOS x86_64
#
OUT_MACOS_X86_64=$BUILD_DIR/macOS_x86_64
if [[ $TARGETS =~ "MACOS_X86_64" ]]; then
rm -rf $OUT_MACOS_X86_64
CFLAGS=" $CFLAGS"
pushd opus
make clean
arch -arch x86_64 ./configure --prefix=$OUT_MACOS_X86_64 --host=x86_64-apple-darwin \
    CFLAGS="-isysroot `xcrun -sdk macosx --show-sdk-path` $CFLAGS"
arch -arch x86_64 make
arch -arch x86_64 make install
popd
fi

#
# create fat lib for the mac
#
OUT_MACOS=$BUILD_DIR/macOS
mkdir -p $OUT_MACOS/lib
lipo -create $OUT_MACOS_ARM64/lib/libopus.a $OUT_MACOS_X86_64/lib/libopus.a -output $OUT_MACOS/lib/libopus.a

#
# create fat lib for the simulator
#
OUT_IOS_SIM=$BUILD_DIR/iOS_simulator
mkdir -p $OUT_IOS_SIM/lib
lipo -create $OUT_IOS_SIM_ARM64/lib/libopus.a $OUT_IOS_SIM_X86_64/lib/libopus.a -output $OUT_IOS_SIM/lib/libopus.a

#
# create xcframework
#
XCFRAMEWORK="$BUILD_DIR/libopus.xcframework"
rm -rf $XCFRAMEWORK
xcodebuild -create-xcframework \
-library $OUT_IOS_ARM64/lib/libopus.a \
-library $OUT_IOS_SIM/lib/libopus.a \
-library $OUT_MACOS/lib/libopus.a \
-output $XCFRAMEWORK

mkdir -p $XCFRAMEWORK/Headers
cp -a $OUT_MACOS_ARM64/include/* $XCFRAMEWORK/Headers

/usr/libexec/PlistBuddy -c 'add:HeadersPath string Headers' $XCFRAMEWORK/Info.plist