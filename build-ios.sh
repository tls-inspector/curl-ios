#!/bin/bash
set -e

################
# PROCESS ARGS #
################

VERIFY=0
CURL_VERSION=0
OPENSSL_VERSION=0
ROOTCA_VERSION=0
ROOTCA_BUNDLE_NAME="apple"
SWIFT=0
USE_GH_CLI=0

while getopts :c:o:r:n:vsg OPTION; do
    case $OPTION in
        c) CURL_VERSION=$OPTARG;;
        o) OPENSSL_VERSION=$OPTARG;;
        r) ROOTCA_VERSION=$OPTARG;;
        n) ROOTCA_BUNDLE_NAME=$OPTARG;;
        v) VERIFY=1;;
        s) SWIFT=1;;
        g) USE_GH_CLI=1;;
        ?) echo "Error: Invalid option was specified -$OPTARG";exit 1;;
    esac
done
if [ "$OPTIND" -ge 2 ]; then
    shift "$((OPTIND - 2))"
    shift 1
else
    shift "$((OPTIND - 1))"
fi

if ! command -v jq 2>&1 >/dev/null; then
    echo "The 'jq' utility must be installed, otherwise you must specify the curl and openssl versions to use."
    exit 1
fi

BUILD_ARGS="$*"
USERAGENT="github.com/tls-inspector/curl-ios"

function github_api() {
    API_PATH=$1

    if [[ $USE_GH_CLI == 1 ]]; then
        gh api $API_PATH
    else
        curl -Ss -A "${USERAGENT}" "https://api.github.com/$API_PATH"
    fi
}

if [[ $CURL_VERSION == 0 ]]; then
    CURL_VERSION=$(github_api repos/curl/curl/releases/latest | jq -r .name)
fi
echo "Using Curl ${CURL_VERSION}"

if [[ $OPENSSL_VERSION == 0 ]]; then
    OPENSSL_VERSION=$(github_api repos/tls-inspector/openssl-ios/releases/latest | jq -r .name)
fi
echo "Using OpenSSL ${OPENSSL_VERSION}"

if [[ $ROOTCA_VERSION == 0 ]]; then
    ROOTCA_VERSION=$(github_api repos/tls-inspector/rootca/releases/latest | jq -r .tag_name)
fi
echo "Using root CA certificates ${ROOTCA_VERSION}"

###############################
# DOWNLOAD & VERIFY ARTIFACTS #
###############################

# Download curl
ARCHIVE="curl-${CURL_VERSION}.tar.gz"
if [ ! -f "${ARCHIVE}" ]; then
    echo "Downloading curl ${CURL_VERSION}"
    curl -A "${USERAGENT}" "https://curl.se/download/curl-${CURL_VERSION}.tar.gz" > "${ARCHIVE}"
fi

# Verify curl
if [[ $VERIFY == 1 ]]; then
    echo "Verifying signature for curl-${CURL_VERSION}.tar.gz"
    if [ ! -f "${ARCHIVE}.asc" ]; then
        curl -A "${USERAGENT}" "https://curl.se/download/curl-${CURL_VERSION}.tar.gz.asc" > "${ARCHIVE}.asc"
    fi
    gpg --verify "${ARCHIVE}.asc" "${ARCHIVE}" >/dev/null
    echo "Verified signature for ${ARCHIVE} successfully!"
fi

# Download openssl
OPENSSL_ARCHIVE="openssl-${OPENSSL_VERSION}.tar.xz"
if [ ! -f "${OPENSSL_ARCHIVE}" ]; then
    echo "Downloading openssl ${OPENSSL_VERSION}"
    curl -A "${UA}" -L "https://github.com/tls-inspector/openssl-ios/releases/download/${OPENSSL_VERSION}/openssl.tar.xz" > "${OPENSSL_ARCHIVE}"
fi

# Verify openssl
if [[ $VERIFY == 1 ]]; then
    echo "Verifying signature for ${OPENSSL_ARCHIVE}"
    if [ ! -f "${OPENSSL_ARCHIVE}.sig" ]; then
        curl -A "${UA}" -L "https://github.com/tls-inspector/openssl-ios/releases/download/${OPENSSL_VERSION}/openssl.tar.xz.sig" > "${OPENSSL_ARCHIVE}.sig"
    fi
    openssl dgst -sha256 -verify signingkey.pem -signature ${OPENSSL_ARCHIVE}.sig ${OPENSSL_ARCHIVE}
fi

# Download rootca certs
ROOTCA_ARCHIVE="rootca-${ROOTCA_BUNDLE_NAME}-${ROOTCA_VERSION}.pem"
if [ ! -f "${ROOTCA_ARCHIVE}" ]; then
    curl -A "${UA}" -L "https://github.com/tls-inspector/rootca/releases/download/${ROOTCA_VERSION}/${ROOTCA_BUNDLE_NAME}_ca_bundle.pem" > "${ROOTCA_ARCHIVE}"
fi

# Verify rootca certs
if [[ $VERIFY == 1 ]]; then
    echo "Verifying signature for ${ROOTCA_ARCHIVE}"
    if [ ! -f "${ROOTCA_ARCHIVE}.sig" ]; then
        curl -A "${UA}" -L "https://github.com/tls-inspector/rootca/releases/download/${ROOTCA_VERSION}/${ROOTCA_BUNDLE_NAME}_ca_bundle.pem.sig" > "${ROOTCA_ARCHIVE}.sig"
    fi
    openssl dgst -sha256 -verify rootca_signing_key.pem -signature ${ROOTCA_ARCHIVE}.sig ${ROOTCA_ARCHIVE}
fi

###########
# COMPILE #
###########

BUILDDIR=build

function build() {
    ARCH=$1
    HOST=$2
    SDK=$3
    echo "Building libcurl for ${ARCH}-${SDK}..."
    SDKDIR=$(xcrun --sdk ${SDK} --show-sdk-path)
    LOG="../${ARCH}-${SDK}_build.log"

    WORKDIR=curl_${ARCH}-${SDK}
    mkdir "${WORKDIR}"
    tar -xzf "../${ARCHIVE}" -C "${WORKDIR}" --strip-components 1
    cd "${WORKDIR}"

    for FILE in $(find ../../patches -name '*.patch' 2>/dev/null); do
        patch -p1 < ${FILE}
    done

    OPENSSL_ARTIFACTS=$(readlink -f ../openssl/openssl_${ARCH}-${SDK}/artifacts)
    CA_EMBED=$(readlink -f ../../${ROOTCA_ARCHIVE})
    # Need to patch the pkgconfig in openssl
    perl -pi -e "s,/Users/runner/work/openssl-ios/openssl-ios/build/openssl_${ARCH}-${SDK}/artifacts,${OPENSSL_ARTIFACTS},g" ${OPENSSL_ARTIFACTS}/lib/pkgconfig/*.pc

    export CC=$(xcrun -find -sdk ${SDK} gcc)
    export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${SDKDIR} -m${SDK}-version-min=18.0"
    export LDFLAGS="-arch ${ARCH} -isysroot ${SDKDIR}"

    CONFIGURE_ARGS="${BUILD_ARGS} --disable-shared --enable-static --without-libpsl --with-ca-embed=${CA_EMBED} --with-openssl=${OPENSSL_ARTIFACTS}"

    echo "build variables: CC=\"${CC}\" CFLAGS=\"${CFLAGS}\" CPPFLAGS=\"${CPPFLAGS}\" LDFLAGS=\"${LDFLAGS}\"" >> "${LOG}"
    echo "configure parameters: --host=\"${HOST}-apple-darwin\" ${CONFIGURE_ARGS} --prefix $(pwd)/artifacts" >> "${LOG}"

    ./configure \
       --host="${HOST}-apple-darwin" \
       $CONFIGURE_ARGS \
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
plutil -insert CFBundleVersion -string ${CURL_VERSION} curl.xcframework/Info.plist

if [[ $SWIFT == 1 ]]; then
    ./inject_module_map.sh iphoneos
    ./inject_module_map.sh iphonesimulator
fi

rm -rf curl.xcframework
xcodebuild -create-xcframework \
    -framework ${BUILDDIR}/iphoneos/curl.framework \
    -framework ${BUILDDIR}/iphonesimulator/curl.framework \
    -output curl.xcframework
plutil -insert CFBundleVersion -string ${CURL_VERSION} curl.xcframework/Info.plist
