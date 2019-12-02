#!/bin/sh
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <CURL Version>"
    exit 1
fi

############
# DOWNLOAD #
############

VERSION=$1
ARCHIVE=curl.tar.gz
if [ ! -f "${ARCHIVE}" ]; then
    echo "Downloading curl ${VERSION}"
    curl "https://curl.haxx.se/download/curl-${VERSION}.tar.gz" > "${ARCHIVE}"
fi

###########
# COMPILE #
###########

export OUTDIR=output
export BUILDDIR=build
export IPHONEOS_DEPLOYMENT_TARGET="9.3"

function build() {
    ARCH=$1
    HOST=$2
    SDKDIR=$3
    LOG="../${ARCH}_build.log"
    echo "Building libcurl for ${ARCH}..."

    WORKDIR=curl_${ARCH}
    mkdir "${WORKDIR}"
    tar -xzf "../${ARCHIVE}" -C "${WORKDIR}" --strip-components 1
    cd "${WORKDIR}"

    unset CFLAGS
    unset LDFLAGS
    CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${SDKDIR} -I${SDKDIR}/usr/include -miphoneos-version-min=${IPHONEOS_DEPLOYMENT_TARGET} -fembed-bitcode"
    LDFLAGS="-arch ${ARCH} -isysroot ${SDKDIR}"
    export CFLAGS
    export LDFLAGS
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
       --with-darwinssl > "${LOG}" 2>&1
    make -j`sysctl -n hw.logicalcpu_max` >> "${LOG}" 2>&1
    cp lib/.libs/libcurl.a ../../$OUTDIR/libcurl-${ARCH}.a
    cd ../
}

rm -rf $OUTDIR $BUILDDIR
mkdir $OUTDIR
mkdir $BUILDDIR
cd $BUILDDIR

build armv7    armv7   `xcrun --sdk iphoneos --show-sdk-path`
build armv7s   armv7s  `xcrun --sdk iphoneos --show-sdk-path`
build arm64    arm     `xcrun --sdk iphoneos --show-sdk-path`
build x86_64   x86_64  `xcrun --sdk iphonesimulator --show-sdk-path`

cd ../

rm ${ARCHIVE}

lipo -arch armv7 $OUTDIR/libcurl-armv7.a \
   -arch armv7s $OUTDIR/libcurl-armv7s.a \
   -arch arm64 $OUTDIR/libcurl-arm64.a \
   -arch x86_64 $OUTDIR/libcurl-x86_64.a \
   -create -output $OUTDIR/libcurl_all.a

###########
# PACKAGE #
###########

FWNAME=curl

if [ -d $FWNAME.framework ]; then
    echo "Removing previous $FWNAME.framework copy"
    rm -rf $FWNAME.framework
fi

LIBTOOL_FLAGS="-static"

echo "Creating $FWNAME.framework"
mkdir -p $FWNAME.framework/Headers
libtool -no_warning_for_no_symbols $LIBTOOL_FLAGS -o $FWNAME.framework/$FWNAME $OUTDIR/libcurl_all.a
cp -r $BUILDDIR/curl_arm64/include/$FWNAME/*.h $FWNAME.framework/Headers/

rm -rf $BUILDDIR
rm -rf $OUTDIR

cp "Info.plist" $FWNAME.framework/Info.plist

set +e
check_bitcode=$(otool -arch arm64 -l $FWNAME.framework/$FWNAME | grep __bitcode)
if [ -z "$check_bitcode" ]
then
    echo "INFO: $FWNAME.framework doesn't contain Bitcode"
else
    echo "INFO: $FWNAME.framework contains Bitcode"
fi
