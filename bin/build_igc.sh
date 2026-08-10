#!/bin/bash

#
# Copyright (C) 2026 Intel Corporation
#
# SPDX-License-Identifier: MIT
#

#
# Build the Intel Graphics Compiler (IGC) and its required dependencies
# (LLVM/Clang, OpenCL-Clang, SPIRV-LLVM-Translator, vc-intrinsics,
# SPIRV-Tools, SPIRV-Headers) from source, and install the result to a
# local prefix (no sudo required).
#
# This follows the "Build from sources" procedure documented at:
#   https://github.com/intel/intel-graphics-compiler/blob/master/documentation/build_ubuntu.md
#
# Unlike using prebuilt IGC .deb release packages, building from source
# guarantees the resulting libraries (libigc.so, libigdfcl.so, libiga64.so)
# are linked against the *local* libstdc++/glibc, avoiding ABI mismatches
# such as:
#   "... version `GLIBCXX_3.4.31' not found (required by libigdfcl.so.2)"
# which occur when prebuilt releases are built with a newer GCC than what
# is installed locally.
#
# The LLVM version and matching OpenCL-Clang / SPIRV-LLVM-Translator
# branches are determined automatically by reading
# external/llvm/llvm_preferred_version.cmake from the checked-out IGC
# source (see the "Revision table" in the documentation linked above).
#
# Note: this script is Ubuntu-specific.
#
# Usage:
#   ./build_igc.sh <ref> [install_prefix] [build_type]
#
# <ref> is any git tag or branch of intel-graphics-compiler, e.g.:
#   - a release tag:  v2.38.5
#   - a release branch: releases/2.38.x
#
# Examples:
#   ./build_igc.sh v2.38.5
#   ./build_igc.sh releases/2.38.x $HOME/my_prefix
#   ./build_igc.sh v2.38.5 $HOME/my_prefix Debug
#
# Releases can be found at:
#   https://github.com/intel/intel-graphics-compiler/releases

# Exit immediately on error, treat unset variables as errors, and fail on
# any command in a pipeline that fails (not just the last one).
set -euo pipefail

# Parse arguments: the IGC git ref (tag or branch) is required, the install
# prefix and build type are optional.
# PREFIX is the directory IGC is installed into (no sudo needed). It must
# be readable at driver/ocloc load time (LD_LIBRARY_PATH=${PREFIX}/lib).
# Defaults to $HOME/local if not specified.
# BUILD_TYPE (CMAKE_BUILD_TYPE) defaults to Release if not specified.
IGC_REF="${1:?Usage: $0 <ref> [install_prefix] [build_type]}"
PREFIX="${2:-$HOME/local}"
BUILD_TYPE="${3:-Release}"
REPO_URL="https://github.com/intel/intel-graphics-compiler"

# Validate the build type: only Release, Debug and RelWithDebInfo are
# supported (these are CMake's own build type names).
case "${BUILD_TYPE}" in
    Release|Debug|RelWithDebInfo) ;;
    *)
        echo "ERROR: '${BUILD_TYPE}' is not a valid build type." >&2
        echo "       Expected one of: Release, Debug, RelWithDebInfo" >&2
        exit 1
        ;;
esac

# Verify the ref actually exists on the remote (as either a tag or a
# branch) before doing any work.
if ! git ls-remote "${REPO_URL}.git" "refs/tags/${IGC_REF}" "refs/heads/${IGC_REF}" 2>/dev/null | grep -q .; then
    echo "ERROR: ref '${IGC_REF}' not found in ${REPO_URL} (checked tags and branches)" >&2
    echo "       See: ${REPO_URL}/releases and ${REPO_URL}/branches" >&2
    exit 1
fi

# All intermediate build artifacts go into a temporary directory that is
# printed at the end so the user can clean it up manually if desired.
WORKDIR="$(mktemp -d)"
NPROC="$(nproc)"

echo "=== Building IGC ref: ${IGC_REF} ==="
echo "=== Install prefix: ${PREFIX} ==="
echo "=== Build type: ${BUILD_TYPE} ==="
echo "=== Work directory: ${WORKDIR} ==="
echo ""

# On exit, clean up the temporary work directory if the build succeeded
# (BUILD_OK is set to 1 right before the script exits normally). On failure,
# keep the work directory around so the user can inspect it / retry.
BUILD_OK=0
cleanup() {
    if [ "${BUILD_OK}" = "1" ]; then
        rm -rf "${WORKDIR}"
        echo ""
        echo "=== Removed temporary work directory: ${WORKDIR} ==="
    else
        echo ""
        echo "=== Build failed. Temporary files kept in: ${WORKDIR} ==="
        echo "    Remove with: rm -rf ${WORKDIR}"
    fi
}
trap cleanup EXIT

# --------------------------------------------------------------------------
# Step 1: Clone IGC at the requested ref
# --------------------------------------------------------------------------
# Shallow clone (--depth 1) is sufficient since we only need the source at
# this exact ref, not the full git history.
echo "=== [1/5] Cloning IGC (${IGC_REF}) ==="
git clone --quiet --depth 1 -b "${IGC_REF}" "${REPO_URL}.git" "${WORKDIR}/igc"

# --------------------------------------------------------------------------
# Step 2: Determine the required LLVM version
# --------------------------------------------------------------------------
# IGC pins its default/preferred LLVM version in
# external/llvm/llvm_preferred_version.cmake (DEFAULT_IGC_LLVM_VERSION,
# e.g. "17.0.6"). The matching OpenCL-Clang and SPIRV-LLVM-Translator
# branches follow the naming scheme "ocl-open-XX0" / "llvm_release_XX0"
# where XX is the LLVM major version (see the Revision table in
# documentation/build_ubuntu.md).
echo ""
echo "=== [2/5] Determining required LLVM version ==="
LLVM_VER_FILE="${WORKDIR}/igc/external/llvm/llvm_preferred_version.cmake"
if [ ! -f "${LLVM_VER_FILE}" ]; then
    echo "ERROR: ${LLVM_VER_FILE} not found; cannot determine required LLVM version." >&2
    exit 1
fi
LLVM_VERSION=$(sed -n 's/.*set(DEFAULT_IGC_LLVM_VERSION *"\([0-9.]*\)".*/\1/p' "${LLVM_VER_FILE}")
if [ -z "${LLVM_VERSION}" ]; then
    echo "ERROR: could not parse DEFAULT_IGC_LLVM_VERSION from ${LLVM_VER_FILE}." >&2
    exit 1
fi
LLVM_MAJOR="${LLVM_VERSION%%.*}"
echo "  Required LLVM version: ${LLVM_VERSION} (major: ${LLVM_MAJOR})"

# --------------------------------------------------------------------------
# Step 3: Clone build dependencies
# --------------------------------------------------------------------------
# vc-intrinsics, SPIRV-Tools and SPIRV-Headers track "master" (not version
# specific). llvm-project is cloned at the matching llvmorg-<version> tag.
# OpenCL-Clang and SPIRV-LLVM-Translator are cloned *inside* the llvm tree
# (llvm-project/llvm/projects/...) as expected by IGC's build system, at
# their version-specific branches (ocl-open-<major>0 /
# llvm_release_<major>0).
echo ""
echo "=== [3/5] Cloning build dependencies (LLVM ${LLVM_VERSION}) ==="
git clone --quiet --depth 1 https://github.com/intel/vc-intrinsics "${WORKDIR}/vc-intrinsics" &
git clone --quiet --depth 1 https://github.com/KhronosGroup/SPIRV-Tools.git "${WORKDIR}/SPIRV-Tools" &
git clone --quiet --depth 1 https://github.com/KhronosGroup/SPIRV-Headers.git "${WORKDIR}/SPIRV-Headers" &
git clone --quiet --depth 1 -b "llvmorg-${LLVM_VERSION}" https://github.com/llvm/llvm-project "${WORKDIR}/llvm-project" &
wait

mkdir -p "${WORKDIR}/llvm-project/llvm/projects"
git clone --quiet --depth 1 -b "ocl-open-${LLVM_MAJOR}0" https://github.com/intel/opencl-clang \
    "${WORKDIR}/llvm-project/llvm/projects/opencl-clang" &
git clone --quiet --depth 1 -b "llvm_release_${LLVM_MAJOR}0" https://github.com/KhronosGroup/SPIRV-LLVM-Translator \
    "${WORKDIR}/llvm-project/llvm/projects/llvm-spirv" &
wait

for d in vc-intrinsics SPIRV-Tools SPIRV-Headers llvm-project \
    llvm-project/llvm/projects/opencl-clang llvm-project/llvm/projects/llvm-spirv; do
    if [ ! -d "${WORKDIR}/${d}/.git" ]; then
        echo "ERROR: failed to clone dependency: ${d}" >&2
        exit 1
    fi
done
echo "  All dependencies cloned."

# --------------------------------------------------------------------------
# Step 4: Configure and build IGC
# --------------------------------------------------------------------------
# The workspace layout (igc, vc-intrinsics, SPIRV-Tools, SPIRV-Headers and
# llvm-project as siblings) lets IGC's cmake auto-discover the sources
# built from Step 3, and link everything statically. CMAKE_INSTALL_PREFIX
# is set to our local prefix so "make install" does not require sudo.
echo ""
echo "=== [4/5] Building IGC (this can take a while) ==="
mkdir -p "${WORKDIR}/build"
cd "${WORKDIR}/build"
cmake -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" -DCMAKE_INSTALL_PREFIX="${PREFIX}" "${WORKDIR}/igc"
make -j"${NPROC}"

# --------------------------------------------------------------------------
# Step 5: Install IGC
# --------------------------------------------------------------------------
echo ""
echo "=== [5/5] Installing IGC to ${PREFIX} ==="
make install

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "  IGC build complete!"
echo "=========================================="
echo ""
echo "  Ref:        ${IGC_REF}"
echo "  Build type: ${BUILD_TYPE}"
echo "  LLVM:       ${LLVM_VERSION}"
echo "  Prefix:     ${PREFIX}"
echo ""
echo "  Installed libraries:"
for lib in "${PREFIX}"/lib/libigc.so* "${PREFIX}"/lib/libigdfcl.so* "${PREFIX}"/lib/libiga64.so* "${PREFIX}"/lib/libopencl-clang*.so*; do
    if [ -e "${lib}" ] && [ ! -L "${lib}" ]; then
        echo "    ${lib}"
    fi
done
echo ""
echo "  To use: LD_LIBRARY_PATH=${PREFIX}/lib:\$LD_LIBRARY_PATH"
echo ""

# Mark the build as successful so the EXIT trap removes the temporary
# work directory instead of keeping it around for debugging.
BUILD_OK=1
