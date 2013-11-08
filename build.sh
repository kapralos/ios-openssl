#!/bin/bash

# This script builds a static version of OpenSSL ${OPENSSL_VERSION}
# for the latest iOS containing binaries for armv7, armv7s, arm64 and i386.

set -x

# Setup 
OPENSSL_VERSION="1.0.1e"

ARCHS=("i386" "armv7" "armv7s" "arm64")
SDKS=("iphonesimulator" "iphoneos" "iphoneos" "iphoneos")
TMP_DIR="/tmp/openssl-${OPENSSL_VERSION}"
OUTPUT_INCLUDE_DIR "include"
OUTPUT_LIB_DIR "lib"


build()
{
   ARCH=$1
   GCC=$2
   SDK=$3
   
   pushd .
   cd "openssl-${OPENSSL_VERSION}"
   ./Configure BSD-generic32 --openssldir="${TMP_DIR}-${ARCH}" &> "${TMP_DIR}-${ARCH}.log"
   perl -i -pe 's|static volatile sig_atomic_t intr_signal|static volatile int intr_signal|' crypto/ui/ui_openssl.c
   perl -i -pe "s|^CC= gcc|CC= ${GCC} -arch ${ARCH}|g" Makefile
   perl -i -pe "s|^CFLAG= (.*)|CFLAG= -isysroot ${SDK} \$1|g" Makefile
   make &> "${TMP_DIR}-${ARCH}.log"
   make install &> "${TMP_DIR}-${ARCH}.log"
   popd
}

create_lib()
{
   LIB_SRC=$1;
   LIB_DST=$2;
   
   LIB_PATHS=( "${ARCHS[@]/#/${TMP_DIR}-}" )
   LIB_PATHS=( "${LIB_PATHS[@]/%//${LIB_SRC}}" )
   lipo ${LIB_PATHS[@]} -create -output "${LIB_DST}"
}


# Clean up whatever was left from previous build
rm -rf ${OUTPUT_INCLUDE_DIR} ${OUTPUT_LIB_DIR}
rm -rf "${TMP_DIR}-*"
rm -rf "${TMP_DIR}-*.log"
rm -rf "openssl-${OPENSSL_VERSION}"

# Extract openssl sources
tar xfz "openssl-${OPENSSL_VERSION}.tar.gz"

# Build
for ((i=0; i < ${#ARCHS[@]}; i++))
do
   SDK_PATH=$(xcrun -sdk ${SDKS[i]} --show-sdk-path)
   GCC=$(xcrun -sdk ${SDKS[i]} -find gcc)
   build "${ARCHS[i]}" "${GCC}" "${SDK_PATH}"
done

# Clean up openssl sources
rm -rf "openssl-${OPENSSL_VERSION}"

# Copy headers
mkdir ${OUTPUT_INCLUDE_DIR}
cp -r ${TMP_DIR}-${ARCHS[0]}/include/openssl ${OUTPUT_INCLUDE_DIR}

# Create lib
mkdir ${OUTPUT_LIB_DIR}
create_lib "lib/libcrypto.a" "${OUTPUT_LIB_DIR}/libcrypto.a"
create_lib "lib/libssl.a" "${OUTPUT_LIB_DIR}/libssl.a"

# If build succeeded, clean up tmp dir
if [ -f lib/libcrypto.a ];
then
	rm -rf "${TMP_DIR}-*"
	rm -rf "${TMP_DIR}-*.log"
else
	echo "Build failed, see the logs in /tmp for details"
fi

