#!/bin/sh

############
# DOWNLOAD #
############

VERSION=7.54.1
ARCHIVE=curl.tar.gz
echo "Downloading curl ${VERSION}"
curl "https://curl.haxx.se/download/curl-${VERSION}.tar.gz" > "${ARCHIVE}"

###########
# COMPILE #
###########

export OUTDIR=buildlib
export IPHONEOS_DEPLOYMENT_TARGET="9.3"
export CC=`xcrun -find -sdk iphoneos clang`

function build() {
    ARCH=$1
    HOST=$2
    SDKDIR=$3

    WORKDIR=curl_${ARCH}
    mkdir "${WORKDIR}"
    tar -xzf "${ARCHIVE}" -C "${WORKDIR}" --strip-components 1
    cd "${WORKDIR}"

    export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${SDKDIR} -miphoneos-version-min=${IPHONEOS_DEPLOYMENT_TARGET} -fembed-bitcode"

    export LDFLAGS="-arch ${ARCH} -isysroot ${SDKDIR}"

    ./configure --host="${HOST}-apple-darwin" \
       --disable-shared \
       --enable-static \
       --disable-smtp \
       --disable-pop3 \
       --disable-imap \
       --disable-ftp \
       --disable-tftp \
       --disable-telnet \
       --disable-rtsp \
       --disable-ldap \
       --with-darwinssl

    make -j `sysctl -n hw.logicalcpu_max`
    cp lib/.libs/libcurl.a ../$OUTDIR/libcurl-${ARCH}.a
    cd ../
    rm -rf "${WORKDIR}"
}

mkdir -p $OUTDIR

build armv7   armv7   `xcrun --sdk iphoneos --show-sdk-path`
build armv7s  armv7s  `xcrun --sdk iphoneos --show-sdk-path`
build arm64    arm    `xcrun --sdk iphoneos --show-sdk-path`
build i386    i386   `xcrun --sdk iphonesimulator --show-sdk-path`
build x86_64  x86_64  `xcrun --sdk iphonesimulator --show-sdk-path`

lipo -arch armv7 $OUTDIR/libcurl-armv7.a \
   -arch armv7s $OUTDIR/libcurl-armv7s.a \
   -arch arm64 $OUTDIR/libcurl-arm64.a \
   -arch i386 $OUTDIR/libcurl-i386.a \
   -arch x86_64 $OUTDIR/libcurl-x86_64.a \
   -create -output $OUTDIR/libcurl_all.a

###########
# PACKAGE #
###########

FWNAME=curl

if [ ! -d buildlib ]; then
    echo "Please run build-ios.sh first!"
    exit 1
fi

if [ -d $FWNAME.framework ]; then
    echo "Removing previous $FWNAME.framework copy"
    rm -rf $FWNAME.framework
fi

if [ "$1" == "dynamic" ]; then
    LIBTOOL_FLAGS="-dynamic -undefined dynamic_lookup -ios_version_min 9.3"
else
    LIBTOOL_FLAGS="-static"
fi

echo "Creating $FWNAME.framework"
mkdir -p $FWNAME.framework/Headers
libtool -no_warning_for_no_symbols $LIBTOOL_FLAGS -o $FWNAME.framework/$FWNAME buildlib/libcurl_all.a
cp -r curl_arm64/include/$FWNAME/*.h $FWNAME.framework/Headers/

cp "Info.plist" $FWNAME.framework/Info.plist
echo "Created $FWNAME.framework"

check_bitcode=`otool -arch arm64 -l $FWNAME.framework/$FWNAME | grep __bitcode`
if [ -z "$check_bitcode" ]
then
    echo "INFO: $FWNAME.framework doesn't contain Bitcode"
else
    echo "INFO: $FWNAME.framework contains Bitcode"
fi
