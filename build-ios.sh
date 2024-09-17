#!/bin/sh
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <CURL Version>"
    exit 1
fi

UA="github.com/tls-inspector/curl-ios"

VERSION=$1
shift
BUILD_ARGS="$@"

############
# DOWNLOAD #
############

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

OPENSSL_VERSION=$(curl -A "${UA}" -Ss https://api.github.com/repos/tls-inspector/openssl-ios/tags | jq -r '.[0].name')
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

CA_BUNDLE_FILE="apple_ca_bundle.pem"
if [ ! -f "${CA_BUNDLE_FILE}" ]; then
    echo "Downloading apple root ca bundle"
    BUNDLE_VERSION=$(curl -A "${UA}" -Ss https://api.github.com/repos/tls-inspector/rootca/tags | jq -r '.[0].name')
    curl -A "${UA}" -LSs "https://raw.githubusercontent.com/tls-inspector/rootca/${BUNDLE_VERSION}/bundles/${CA_BUNDLE_FILE}" > ${CA_BUNDLE_FILE}

    if [ ! -z "${VERIFY}" ]; then
        echo "Verifying signature for ${OPENSSL_ARCHIVE}"
        curl -A "${UA}" -LSs "https://raw.githubusercontent.com/tls-inspector/rootca/${BUNDLE_VERSION}/bundles/${CA_BUNDLE_FILE}.sig" > ${CA_BUNDLE_FILE}.sig
        openssl dgst -sha256 -verify rootca_signing_key.pem -signature ${CA_BUNDLE_FILE}.sig ${CA_BUNDLE_FILE}
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

    cp ../../apple_ca_bundle.pem .

    OPENSSL_ARTIFACTS=$(readlink -f ../openssl_${ARCH}-${SDK}/artifacts)

    export CC=$(xcrun -find -sdk ${SDK} gcc)
    export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${SDKDIR} -m${SDK}-version-min=12.0"
    export CPPFLAGS="-I${OPENSSL_ARTIFACTS}/include"
    export LDFLAGS="-arch ${ARCH} -isysroot ${SDKDIR} -L${OPENSSL_ARTIFACTS}/lib"
    BUILD_ARGS="--disable-shared --enable-static --with-openssl --without-libpsl --with-ca-bundle=apple_ca_bundle.pem ${BUILD_ARGS}"

    echo "build variables: CC=\"${CC}\" CFLAGS=\"${CFLAGS}\" LDFLAGS=\"${LDFLAGS}\"" >> "${LOG}"
    echo "configure parameters: ${BUILD_ARGS}" >> "${LOG}"

    ./configure \
       --host="${HOST}-apple-darwin" \
       $BUILD_ARGS \
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

# Inject a module map so Swift can consume this
function make_modulemap {
    PLATFORM=${1}
    mkdir -p ${BUILDDIR}/${PLATFORM}/curl.framework/Modules
    echo "framework module Curl {" > ${BUILDDIR}/${PLATFORM}/curl.framework/Modules/module.modulemap
    echo "    header \"shim.h\"" >> ${BUILDDIR}/${PLATFORM}/curl.framework/Modules/module.modulemap
    for HEADER in $(ls ${BUILDDIR}/${PLATFORM}/curl.framework/Headers); do
        echo "    header \"${HEADER}\"" >> ${BUILDDIR}/${PLATFORM}/curl.framework/Modules/module.modulemap
    done
    echo "    export *" >> ${BUILDDIR}/${PLATFORM}/curl.framework/Modules/module.modulemap
    echo "}" >> ${BUILDDIR}/${PLATFORM}/curl.framework/Modules/module.modulemap
    cp shim.h ${BUILDDIR}/${PLATFORM}/curl.framework/Headers
}

if [ ! -z "${WITH_MODULE_MAP}" ]; then
    make_modulemap iphoneos
    make_modulemap iphonesimulator
fi

rm -rf curl.xcframework
xcodebuild -create-xcframework \
    -framework ${BUILDDIR}/iphoneos/curl.framework \
    -framework ${BUILDDIR}/iphonesimulator/curl.framework \
    -output curl.xcframework
plutil -insert CFBundleVersion -string ${VERSION} curl.xcframework/Info.plist
