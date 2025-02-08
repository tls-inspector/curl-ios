#!/bin/sh
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <CURL Version>"
    exit 1
fi

UA="github.com/tls-inspector/curl-ios"

VERSION=$1
shift
BUILD_ARGS="$@ --disable-shared --enable-static --without-libpsl"

############
# DOWNLOAD #
############

# Download curl
ARCHIVE="curl-${VERSION}.tar.gz"
if [ ! -f "${ARCHIVE}" ]; then
    echo "Downloading curl ${VERSION}"
    curl -A "${UA}" "https://curl.se/download/curl-${VERSION}.tar.gz" > "${ARCHIVE}"

    if [ ! -z "${VERIFY}" ]; then
        echo "Verifying signature for curl-${VERSION}.tar.gz"
        rm -f "${ARCHIVE}.asc"
        curl -A "${UA}" "https://curl.se/download/curl-${VERSION}.tar.gz.asc" > "${ARCHIVE}.asc"
        gpg --verify "${ARCHIVE}.asc" "${ARCHIVE}" >/dev/null
        echo "Verified signature for ${ARCHIVE} successfully!"
    fi
fi

# Download openssl
if [ -z ${OPENSSL_VERSION+x} ]; then
    OPENSSL_VERSION=$(curl -A "${UA}" -Ss https://api.github.com/repos/tls-inspector/openssl-ios/tags | jq -r '.[0].name')
fi
echo "Using OpenSSL ${OPENSSL_VERSION}"
OPENSSL_ARCHIVE="openssl-${OPENSSL_VERSION}.tar.xz"
if [ ! -f "${OPENSSL_ARCHIVE}" ]; then
    echo "Downloading openssl ${OPENSSL_VERSION}"
    curl -A "${UA}" -L "https://github.com/tls-inspector/openssl-ios/releases/download/${OPENSSL_VERSION}/openssl.tar.xz" > "${OPENSSL_ARCHIVE}"

    if [ ! -z "${VERIFY}" ]; then
        echo "Verifying signature for ${OPENSSL_ARCHIVE}"
        rm -f "${OPENSSL_ARCHIVE}.sig"
        curl -A "${UA}" -L "https://github.com/tls-inspector/openssl-ios/releases/download/${OPENSSL_VERSION}/openssl.tar.xz.sig" > "${OPENSSL_ARCHIVE}.sig"
        openssl dgst -sha256 -verify signingkey.pem -signature ${OPENSSL_ARCHIVE}.sig ${OPENSSL_ARCHIVE}
    fi
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

    OPENSSL_ARTIFACTS=$(readlink -f ../openssl/openssl_${ARCH}-${SDK}/artifacts)
    # Need to patch the pkgconfig in openssl
    perl -pi -e "s,/Users/runner/work/openssl-ios/openssl-ios/build/openssl_${ARCH}-${SDK}/artifacts,${OPENSSL_ARTIFACTS},g" ${OPENSSL_ARTIFACTS}/lib/pkgconfig/*.pc

    export CC=$(xcrun -find -sdk ${SDK} gcc)
    export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${SDKDIR} -m${SDK}-version-min=18.0"
    export LDFLAGS="-arch ${ARCH} -isysroot ${SDKDIR}"

    echo "build variables: CC=\"${CC}\" CFLAGS=\"${CFLAGS}\" CPPFLAGS=\"${CPPFLAGS}\" LDFLAGS=\"${LDFLAGS}\"" >> "${LOG}"
    echo "configure parameters: --host=\"${HOST}-apple-darwin\" ${BUILD_ARGS} --with-openssl=${OPENSSL_ARTIFACTS} --prefix $(pwd)/artifacts" >> "${LOG}"

    ./configure \
       --host="${HOST}-apple-darwin" \
       $BUILD_ARGS --with-openssl=${OPENSSL_ARTIFACTS} \
       --prefix $(pwd)/artifacts >> "${LOG}" 2>&1

    make -j`sysctl -n hw.logicalcpu_max` >> "${LOG}" 2>&1
    make install >> "${LOG}" 2>&1
    cd ../
}

rm -rf ${BUILDDIR}
mkdir ${BUILDDIR}
cp ${OPENSSL_ARCHIVE} ${BUILDDIR}
cd ${BUILDDIR}
tar -xf ${OPENSSL_ARCHIVE}
mv build openssl

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

if [ ! -z "${WITH_MODULE_MAP}" ]; then
    ./inject_module_map.sh iphoneos
    ./inject_module_map.sh iphonesimulator
fi

rm -rf curl.xcframework
xcodebuild -create-xcframework \
    -framework ${BUILDDIR}/iphoneos/curl.framework \
    -framework ${BUILDDIR}/iphonesimulator/curl.framework \
    -output curl.xcframework
plutil -insert CFBundleVersion -string ${VERSION} curl.xcframework/Info.plist
