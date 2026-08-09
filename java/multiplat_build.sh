#!/usr/bin/env bash

set -e

function do_build {
    mkdir build
    pushd build
    local java_root=$1
    local target=$2
    local output_path=$3
    echo "Building $target..."

    CXXFLAGS="-target $target" cmake -G Ninja $java_root/.. \
      -DPATHFINDER_TARGET=$target \
      -DCMAKE_C_COMPILER=$(realpath $java_root/zigcc.sh) -DCMAKE_CXX_COMPILER=$(realpath $java_root/zigcxx.sh) \
      -DCMAKE_AR=$(realpath $java_root/zigar.sh) \
      -DCMAKE_RANLIB=$(realpath $java_root/zigranlib.sh) \
      -DCMAKE_BUILD_TYPE=Release

    ninja -j `nproc`

    cp libnether_pathfinder.so ../$output_path
    popd
    rm -rf build
}

function do_build_android {
    local ndk_home="${ANDROID_NDK_HOME:-$ANDROID_SDK_ROOT/ndk/28.2.13676358}"
    if [ ! -f "$ndk_home/build/cmake/android.toolchain.cmake" ]; then
        echo "Skipping Android $3: NDK not found at $ndk_home"
        return 0
    fi
    local java_root=$1
    local abi=$2
    local api_level=$3
    local output_path=$4
    echo "Building Android $abi (API $api_level)..."

    local target
    case "$abi" in
        arm64-v8a) target="aarch64-none-linux-android${api_level}" ;;
        x86_64)    target="x86_64-none-linux-android${api_level}" ;;
    esac
    local ndk_sysroot="$ndk_home/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
    local arch_include="$ndk_sysroot/usr/include/${abi/-/_}"
    [ "$abi" = "arm64-v8a" ] && arch_include="$ndk_sysroot/usr/include/aarch64-linux-android"

    mkdir build
    pushd build
    cmake -G Ninja $java_root/.. \
      -DCMAKE_TOOLCHAIN_FILE="$ndk_home/build/cmake/android.toolchain.cmake" \
      -DANDROID_ABI=$abi \
      -DANDROID_NATIVE_API_LEVEL=$api_level \
      "-DCMAKE_C_FLAGS=--target=${target} -I${arch_include}" \
      "-DCMAKE_CXX_FLAGS=-I${arch_include}" \
      -DWITH_ACLE=OFF -DWITH_NEON=OFF \
      -DCMAKE_BUILD_TYPE=Release

    ninja -j `nproc`

    cp libnether_pathfinder.so ../$output_path
    popd
    rm -rf build
}

do_build $1 x86_64-linux-gnu libnether_pathfinder-x86_64.so
do_build $1 aarch64-linux-gnu libnether_pathfinder-aarch64.so

# Android targets require the NDK; zig does not ship Bionic libc
do_build_android $1 arm64-v8a 26 libnether_pathfinder-aarch64-android.so

# zig 0.9.1 requires macos-gnu
# zig 0.11.0 requires macos-none
do_build $1 x86_64-macos-none libnether_pathfinder-x86_64.dylib
do_build $1 aarch64-macos-none libnether_pathfinder-aarch64.dylib
do_build $1 x86_64-windows-gnu nether_pathfinder-x86_64.dll
do_build $1 aarch64-windows-gnu nether_pathfinder-aarch64.dll
