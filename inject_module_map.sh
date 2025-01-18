#!/bin/sh
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <platform>"
    exit 1
fi

PLATFORM=${1}
mkdir -p build/${PLATFORM}/curl.framework/Modules
echo "framework module Curl {" > build/${PLATFORM}/curl.framework/Modules/module.modulemap
echo "    header \"shim.h\"" >> build/${PLATFORM}/curl.framework/Modules/module.modulemap
for HEADER in $(ls build/${PLATFORM}/curl.framework/Headers); do
    echo "    header \"${HEADER}\"" >> build/${PLATFORM}/curl.framework/Modules/module.modulemap
done
echo "    export *" >> build/${PLATFORM}/curl.framework/Modules/module.modulemap
echo "}" >> build/${PLATFORM}/curl.framework/Modules/module.modulemap
cp shim.h build/${PLATFORM}/curl.framework/Headers
