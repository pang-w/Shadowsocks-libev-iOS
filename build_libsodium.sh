#!/bin/sh
# A script to download and build libsodium for iOS, including arm64
# Adapted from https://raw2.github.com/seb-m/CryptoPill/master/libsodium.sh

mkdir -p build
cd build
mkdir -p libsodium
cd libsodium


SODIUM_VERSION='1.0.17'
rm -rf libsodium
set -e
if [ ! -e "libsodium-${SODIUM_VERSION}.tar.gz" ]
then
curl -O -L https://github.com/jedisct1/libsodium/releases/download/$SODIUM_VERSION/libsodium-$SODIUM_VERSION.tar.gz
fi

tar xzf libsodium-$SODIUM_VERSION.tar.gz

CURRENTPATH=`pwd`

mv libsodium-$SODIUM_VERSION libsodium

LIBNAME="libsodium.a"
ARCHS=${ARCHS:-"armv7 armv7s arm64 i386 x86_64"}
DEVELOPER=$(xcode-select -print-path)
LIPO=$(xcrun -sdk iphoneos -find lipo)
#LIPO=lipo
# Script's directory
SCRIPTDIR=$( (cd -P $(dirname $0) && pwd) )
# libsodium root directory
LIBDIR=$( (cd "${SCRIPTDIR}/libsodium"  && pwd) )
# Destination directory for build and install
DSTDIR=${SCRIPTDIR}
BUILDDIR="${DSTDIR}/libsodium_build"
DISTLIBDIR="${DSTDIR}/lib"
# http://libwebp.webm.googlecode.com/git/iosbuild.sh
# Extract the latest SDK version from the final field of the form: iphoneosX.Y
SDK=$(xcodebuild -showsdks \
    | grep iphoneos | sort | tail -n 1 | awk '{print substr($NF, 9)}'
    )

OTHER_CFLAGS="-Os -Qunused-arguments"

# Cleanup
if [ -d $BUILDDIR ]
then
    rm -rf $BUILDDIR
fi

mkdir -p $BUILDDIR

# Generate autoconf files
cd ${LIBDIR}; ./autogen.sh

# Iterate over archs and compile static libs
for ARCH in $ARCHS
do
    BUILDARCHDIR="$BUILDDIR/$ARCH"
    mkdir -p ${BUILDARCHDIR}

    case ${ARCH} in
        armv7)
	    PLATFORM="iPhoneOS"
	    HOST="${ARCH}-apple-darwin"
	    export BASEDIR="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	    export ISDKROOT="${BASEDIR}/SDKs/${PLATFORM}${SDK}.sdk"
	    export CFLAGS="-arch ${ARCH} -isysroot ${ISDKROOT} ${OTHER_CFLAGS} -miphoneos-version-min=8.0"
	    export LDFLAGS="-mthumb -arch ${ARCH} -isysroot ${ISDKROOT} -miphoneos-version-min=8.0"
            ;;
        armv7s)
	    PLATFORM="iPhoneOS"
	    HOST="${ARCH}-apple-darwin"
	    export BASEDIR="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	    export ISDKROOT="${BASEDIR}/SDKs/${PLATFORM}${SDK}.sdk"
	    export CFLAGS="-arch ${ARCH} -isysroot ${ISDKROOT} ${OTHER_CFLAGS} -miphoneos-version-min=8.0"
	    export LDFLAGS="-mthumb -arch ${ARCH} -isysroot ${ISDKROOT} -miphoneos-version-min=8.0"
            ;;
        arm64)
	    PLATFORM="iPhoneOS"
	    HOST="aarch64-apple-darwin"
	    export BASEDIR="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	    export ISDKROOT="${BASEDIR}/SDKs/${PLATFORM}${SDK}.sdk"
	    export CFLAGS="-arch ${ARCH} -isysroot ${ISDKROOT} ${OTHER_CFLAGS} -miphoneos-version-min=8.0"
	    export LDFLAGS="-mthumb -arch ${ARCH} -isysroot ${ISDKROOT} -miphoneos-version-min=8.0"
            ;;
        i386)
	    PLATFORM="iPhoneSimulator"
	    HOST="${ARCH}-apple-darwin"
	    export BASEDIR="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	    export ISDKROOT="${BASEDIR}/SDKs/${PLATFORM}${SDK}.sdk"
	    export CFLAGS="-arch ${ARCH} -isysroot ${ISDKROOT} ${OTHER_CFLAGS} -miphoneos-version-min=8.0"
	    export LDFLAGS="-m32 -arch ${ARCH} -miphoneos-version-min=8.0"
            ;;
        x86_64)
	    PLATFORM="iPhoneSimulator"
	    HOST="${ARCH}-apple-darwin"
	    export BASEDIR="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	    export ISDKROOT="${BASEDIR}/SDKs/${PLATFORM}${SDK}.sdk"
	    export CFLAGS="-arch ${ARCH} -isysroot ${ISDKROOT} ${OTHER_CFLAGS} -miphoneos-version-min=8.0"
	    export LDFLAGS="-arch ${ARCH} -miphoneos-version-min=8.0"
            ;;
        *)
            echo "Unsupported architecture ${ARCH}"
            exit 1
            ;;
    esac

    export PATH="${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin:${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/sbin:$PATH"

    echo "Configuring for ${ARCH}..."
    ${LIBDIR}/configure \
	--prefix=${BUILDARCHDIR} \
	--disable-shared \
	--enable-static \
	--host=${HOST}

    echo "Building ${LIBNAME} for ${ARCH}..."
    cd ${LIBDIR}
    make clean
    make -j8 V=0
    make install

    LIBLIST+="${BUILDARCHDIR}/lib/${LIBNAME} "
done

# Copy headers and generate a single fat library file
mkdir -p ${DISTLIBDIR}
${LIPO} -create ${LIBLIST} -output ${DISTLIBDIR}/${LIBNAME}
for ARCH in $ARCHS
do
    cp -R $BUILDDIR/$ARCH/include ${DSTDIR}
    break
done

cd $CURRENTPATH

mkdir -p ../../Shadowsocks-libev-iOS/include
mkdir -p ../../Shadowsocks-libev-iOS/lib

cp -f -r include/ ../../Shadowsocks-libev-iOS/include
cp -f -r lib/ ../../Shadowsocks-libev-iOS/lib

# Cleanup
rm -rf ${BUILDDIR}
rm -rf ${LIBDIR}
echo 'build LIBSODIUM SUCCESS'