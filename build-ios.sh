#!/bin/sh
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <CURL Version>"
    exit 1
fi

VERSION=$1
shift
BUILD_ARGS="$@"

############
# DOWNLOAD #
############

ARCHIVE=curl.tar.gz
if [ ! -f "${ARCHIVE}" ]; then
    echo "Downloading curl ${VERSION}"
    curl "https://curl.se/download/curl-${VERSION}.tar.gz" > "${ARCHIVE}"
fi

###########
# COMPILE #
###########

BUILDDIR=build

function build() {
    ARCH=$1
    HOST=$2
    SDK=$3
    SDKDIR=$(xcrun --sdk ${SDK} --show-sdk-path)
    LOG="../${ARCH}-${SDK}_build.log"
    echo "Building libcurl for ${ARCH}-${SDK}..."

    WORKDIR=curl_${ARCH}-${SDK}
    mkdir "${WORKDIR}"
    tar -xzf "../${ARCHIVE}" -C "${WORKDIR}" --strip-components 1
    cd "${WORKDIR}"

    for FILE in $(find ../../patches -name '*.patch' 2>/dev/null); do
        patch -p1 < ${FILE}
    done

    export CC=$(xcrun -find -sdk ${SDK} gcc)
    export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${SDKDIR} -m${SDK}-version-min=12.0"
    export LDFLAGS="-arch ${ARCH} -isysroot ${SDKDIR}"

    echo "configure parameters: ${BUILD_ARGS}" >> "${LOG}"

    ./configure \
       --host="${HOST}-apple-darwin" \
       --disable-shared \
       --enable-static \
       --with-secure-transport \
       $BUILD_ARGS \
       --prefix $(pwd)/artifacts > "${LOG}" 2>&1

    make -j`sysctl -n hw.logicalcpu_max` >> "${LOG}" 2>&1
    make install >> "${LOG}" 2>&1
    cd ../
}

rm -rf ${BUILDDIR}
mkdir ${BUILDDIR}
cd ${BUILDDIR}

build arm64   arm     iphoneos
build arm64   arm     iphonesimulator
build x86_64  x86_64  iphonesimulator

cd ../

###########
# PACKAGE #
###########

lipo \
   -arch arm64  ${BUILDDIR}/curl_arm64-iphonesimulator/artifacts/lib/libcurl.a \
   -arch x86_64 ${BUILDDIR}/curl_x86_64-iphonesimulator/artifacts/lib/libcurl.a \
   -create -output ${BUILDDIR}/libcurl.a

rm -rf ${BUILDDIR}/iphoneos/curl.framework ${BUILDDIR}/iphonesimulator/curl.framework
mkdir -p ${BUILDDIR}/iphoneos/curl.framework/Headers ${BUILDDIR}/iphonesimulator/curl.framework/Headers
libtool -no_warning_for_no_symbols -static -o ${BUILDDIR}/iphoneos/curl.framework/curl ${BUILDDIR}/curl_arm64-iphoneos/artifacts/lib/libcurl.a
cp -r ${BUILDDIR}/curl_arm64-iphoneos/artifacts/include/curl/*.h ${BUILDDIR}/iphoneos/curl.framework/Headers
libtool -no_warning_for_no_symbols -static -o ${BUILDDIR}/iphonesimulator/curl.framework/curl ${BUILDDIR}/libcurl.a
cp -r ${BUILDDIR}/curl_arm64-iphonesimulator/artifacts/include/curl/*.h ${BUILDDIR}/iphonesimulator/curl.framework/Headers

rm -rf curl.xcframework
xcodebuild -create-xcframework \
    -framework ${BUILDDIR}/iphoneos/curl.framework \
    -framework ${BUILDDIR}/iphonesimulator/curl.framework \
    -output curl.xcframework
plutil -insert CFBundleVersion -string ${VERSION} curl.xcframework/Info.plist
