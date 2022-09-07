#!/bin/sh
# Oliver Epper <oliver.epper@gmail.com>

# .install.sh cannot be named install.sh because of automake issues (libtoolize)

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
    local PC_FILE=opus-apple-platforms.pc
	local PC_FILE_MACOSX=opus-apple-platforms-MacOSX.pc
	local PC_FILE_IPHONEOS=opus-apple-platforms-iPhoneOS.pc
	local PC_FILE_IPHONESIMULATOR=opus-apple-platforms-iPhoneSimulator.pc
	local PC_FILE_SPM=opus-apple-platforms-SPM.pc
    
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
    # for macOS (arm64 and x86_64)
    cat << END > $PREFIX/lib/pkgconfig/$PC_FILE_MACOSX
prefix=$PREFIX

END

    cat << 'END' >> $PREFIX/lib/pkgconfig/$PC_FILE_MACOSX
exec_prefix=${prefix}
libdir=${exec_prefix}/libopus.xcframework/macos-arm64_x86_64
includedir=${prefix}/libopus.xcframework/Headers

Name: Opus
Description: Opus IETF audio codec
URL: https://opus-codec.org/
END

    echo "Version: ${OPUS_VERSION:1}" >> $PREFIX/lib/pkgconfig/$PC_FILE_MACOSX

    cat << 'END' >> $PREFIX/lib/pkgconfig/$PC_FILE_MACOSX
Libs: -L${libdir} -lopus
Cflags: -I${includedir}/opus
END

    # for iOS
    sed -e s/macos-arm64_x86_64/ios_arm64/ < $PREFIX/lib/pkgconfig/$PC_FILE_MACOSX > $PREFIX/lib/pkgconfig/$PC_FILE_IPHONEOS 

    # for iOS simulator
    sed -e s/macos-arm64_x86_64/ios-arm64_x86_64-simulator/ < $PREFIX/lib/pkgconfig/$PC_FILE_MACOSX > $PREFIX/lib/pkgconfig/$PC_FILE_IPHONESIMULATOR 

    # for SPM
    sed -e /^libdir=/d -e 's/^Libs: .*$/Libs: -lopus/' < $PREFIX/lib/pkgconfig/$PC_FILE_MACOSX > $PREFIX/lib/pkgconfig/$PC_FILE_SPM

    # link pjproject-apple-platforms.pc
	ln -sf $PREFIX/lib/pkgconfig/$PC_FILE_MACOSX $PREFIX/lib/pkgconfig/$PC_FILE

    # install build dir
    # for iOS simulator arm64 & x86_64
    cp -a $BUILD_DIR/iOS_simulator_arm64 $PREFIX
    cp -a $BUILD_DIR/iOS_simulator_x86_64 $PREFIX

    # for iOS
    cp -a $BUILD_DIR/iOS_arm64 $PREFIX

    # for macOS
    cp -a $BUILD_DIR/macOS_arm64 $PREFIX
    cp -a $BUILD_DIR/macOS_x86_64 $PREFIX

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
    CFLAGS="-isysroot `xcrun -sdk iphonesimulator --show-sdk-path` -miphonesimulator-version-min=13.0 $CFLAGS" 
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
    CFLAGS="-isysroot `xcrun -sdk iphonesimulator --show-sdk-path` -miphonesimulator-version-min=13.0 $CFLAGS"
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
    CFLAGS="-isysroot `xcrun -sdk iphoneos --show-sdk-path` -miphoneos-version-min=13.0 $CFLAGS"
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
    CFLAGS="-isysroot `xcrun -sdk macosx --show-sdk-path` -mmacosx-version-min=11 $CFLAGS"
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
    CFLAGS="-isysroot `xcrun -sdk macosx --show-sdk-path` -mmacosx-version-min=11 $CFLAGS"
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