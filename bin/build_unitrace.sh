#!/bin/bash

#
# Copyright (C) 2026 Intel Corporation
#
# SPDX-License-Identifier: MIT
#

#
# Build the "unitrace" tool (Unified Tracing and Profiling Tool) from
# https://github.com/intel/pti-gpu/tree/master/tools/unitrace for a given
# release tag.
#
# unitrace traces and profiles host/device activities for Intel(R) oneAPI
# GPU applications (SYCL/Unified Runtime, Level Zero, OpenCL, OpenMP, ITT,
# oneCCL, MPI). It is invaluable for diagnosing device-timeline / kernel
# scheduling issues (e.g. multi-GPU dependency and profiling-timestamp bugs)
# without needing to instrument the application itself.
#
# This script auto-detects the build dependencies it can find in the current
# environment and disables the corresponding unitrace features when a
# dependency is missing, rather than failing outright:
#   - XPTI/XPTIFW (needed for --chrome-sycl-logging / --chrome-ur-logging):
#     looked up via ONEAPI_COMPILER_HOME, defaulting to this repo's own
#     llvm/build/install (which already ships libxptifw.so + xpti headers,
#     since XPTI/XPTIFW is built as part of the SYCL runtime here).
#   - Level Zero headers/library (needed for Level Zero tracing): looked up
#     via CPATH / LD_LIBRARY_PATH, falling back to $HOME/local (see
#     build_level_zero_loader.sh) and then the system install.
#   - Intel(R) MPI (needed for --chrome-mpi-logging): looked up via mpicxx;
#     disabled (-DBUILD_WITH_MPI=0) if not installed.
#   - OpenMP tooling (needed for --chrome-omp-logging): requires a full
#     oneAPI compiler install's omp-tools.h via CMPLR_ROOT; disabled
#     (-DBUILD_WITH_OMP=0) if CMPLR_ROOT is not set.
#   - OpenCL (needed for --opencl): looked up via the system OpenCL ICD
#     loader; disabled (-DBUILD_WITH_OPENCL=0) if not installed.
#
# Usage:
#   ./build_unitrace.sh <tag> [install_prefix] [build_type]
#
# Examples:
#   ./build_unitrace.sh pti-1.1.0-rc1
#   ./build_unitrace.sh pti-1.1.0-rc1 $HOME/my_prefix
#   ./build_unitrace.sh pti-1.1.0-rc1 $HOME/my_prefix Debug
#
# The latest release tag can be found at:
#   https://github.com/intel/pti-gpu/tags

# Exit immediately on error, treat unset variables as errors, and fail on
# any command in a pipeline that fails (not just the last one).
set -euo pipefail

# Parse arguments: the release tag is required, the install prefix and build
# type are optional.
# PREFIX is where the unitrace binary/libraries/scripts are installed (no
# sudo needed). Defaults to $HOME/local if not specified.
# BUILD_TYPE (CMAKE_BUILD_TYPE) defaults to Release if not specified.
TAG="${1:?Usage: $0 <tag> [install_prefix] [build_type]}"
PREFIX="${2:-$HOME/local}"
BUILD_TYPE="${3:-Release}"
REPO_URL="https://github.com/intel/pti-gpu"

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

# Validate the tag format: unitrace/pti-gpu release tags look like
# "pti-1.1.0" or "pti-1.1.0-rc1" (current), or "unitrace-2.0.2" (legacy,
# before the tool's history was merged into the combined pti-gpu tagging).
if ! echo "${TAG}" | grep -qE '^(pti|unitrace)-[0-9]+\.[0-9]+\.[0-9]+(-rc[0-9]+)?$'; then
    echo "ERROR: '${TAG}' is not a valid pti-gpu/unitrace tag." >&2
    echo "       Expected format: pti-MAJOR.MINOR.PATCH[-rcN] (e.g. pti-1.1.0-rc1)" >&2
    echo "       See: ${REPO_URL}/tags" >&2
    exit 1
fi

# Verify the tag actually exists on the remote before doing any work.
if ! git ls-remote --tags "${REPO_URL}.git" "refs/tags/${TAG}" 2>/dev/null | grep -q .; then
    echo "ERROR: tag '${TAG}' not found in ${REPO_URL}" >&2
    echo "       See: ${REPO_URL}/tags" >&2
    exit 1
fi

# All intermediate build artifacts go into a temporary directory that is
# printed at the end so the user can clean it up manually if desired.
WORKDIR="$(mktemp -d)"
NPROC="$(nproc)"

echo "=== Building unitrace tag: ${TAG} ==="
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
# Step 1: Clone pti-gpu at the requested tag
# --------------------------------------------------------------------------
# Shallow clone (--depth 1) is sufficient since we only need the source at
# this exact tag, not the full git history. The full repo (not just
# tools/unitrace) is needed because unitrace's CMakeLists.txt includes
# ../../build_utils/CMakeLists.txt as a sibling directory.
echo "=== [1/4] Cloning pti-gpu at tag ${TAG} ==="
SRCDIR="${WORKDIR}/pti-gpu"
git clone --depth 1 -b "${TAG}" "${REPO_URL}.git" "${SRCDIR}"
UNITRACE_DIR="${SRCDIR}/tools/unitrace"

# --------------------------------------------------------------------------
# Step 2: Detect optional build dependencies
# --------------------------------------------------------------------------
# unitrace's CMake build hard-requires XPTI/XPTIFW headers+library, but the
# Level Zero, MPI, OpenMP and OpenCL tracing backends can each be disabled
# individually if their dependency isn't available, rather than failing the
# whole build. Detect what's available and configure accordingly, printing
# what will be enabled/disabled so the summary at the end is not a surprise.
echo ""
echo "=== [2/4] Detecting build dependencies ==="

# XPTI/XPTIFW: required unconditionally by unitrace's CMakeLists.txt.
# ONEAPI_COMPILER_HOME must point at a directory with include/xpti/ and
# lib/libxptifw.so - this repo's own llvm/build/install already has both,
# since XPTI/XPTIFW is built as part of the SYCL runtime.
if [ -z "${ONEAPI_COMPILER_HOME:-}" ]; then
    LLVM_INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../llvm/build/install" 2>/dev/null && pwd || true)"
    if [ -n "${LLVM_INSTALL_DIR}" ] && [ -f "${LLVM_INSTALL_DIR}/include/xpti/xpti_trace_framework.h" ]; then
        ONEAPI_COMPILER_HOME="${LLVM_INSTALL_DIR}"
    fi
fi
if [ -z "${ONEAPI_COMPILER_HOME:-}" ] || [ ! -f "${ONEAPI_COMPILER_HOME}/include/xpti/xpti_trace_framework.h" ]; then
    echo "ERROR: XPTI headers not found via ONEAPI_COMPILER_HOME." >&2
    echo "       Set ONEAPI_COMPILER_HOME to a directory containing" >&2
    echo "       include/xpti/xpti_trace_framework.h and lib/libxptifw.so" >&2
    echo "       (e.g. a DPC++ build's install prefix, or set up the" >&2
    echo "       Intel(R) oneAPI Base Toolkit environment)." >&2
    exit 1
fi
echo "  XPTI:        found at ${ONEAPI_COMPILER_HOME} (BUILD_WITH_XPTI=1)"
export ONEAPI_COMPILER_HOME

# Level Zero headers/library: check whether CPATH/LD_LIBRARY_PATH already
# resolve them; if not, add $HOME/local (see build_level_zero_loader.sh)
# ahead of the current paths, since that's where this repo's sibling script
# installs a freshly-built loader.
BUILD_WITH_L0=1
L0_HEADERS_FOUND=false
for d in $(echo "${CPATH:-}" | tr ':' '\n'); do
    if [ -n "${d}" ] && [ -d "${d}/level_zero" ]; then
        L0_HEADERS_FOUND=true
        break
    fi
done
if [ "${L0_HEADERS_FOUND}" = false ] && [ -d "$HOME/local/include/level_zero" ]; then
    export CPATH="$HOME/local/include${CPATH:+:${CPATH}}"
fi

L0_LIB_FOUND=false
for d in $(echo "${LD_LIBRARY_PATH:-}" | tr ':' '\n'); do
    if [ -n "${d}" ] && compgen -G "${d}/libze_loader.so*" > /dev/null 2>&1; then
        L0_LIB_FOUND=true
        break
    fi
done
if [ "${L0_LIB_FOUND}" = false ] && compgen -G "$HOME/local/lib/libze_loader.so*" > /dev/null 2>&1; then
    export LD_LIBRARY_PATH="$HOME/local/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
fi
echo "  Level Zero:  CPATH=${CPATH:-<unset>} (BUILD_WITH_L0=1)"

# Intel(R) MPI: only enable MPI tracing support if mpicxx is on PATH.
if command -v mpicxx >/dev/null 2>&1; then
    BUILD_WITH_MPI=1
    echo "  MPI:         found ($(command -v mpicxx)) (BUILD_WITH_MPI=1)"
else
    BUILD_WITH_MPI=0
    echo "  MPI:         not found, disabling (BUILD_WITH_MPI=0)"
fi

# OpenMP tracing needs omp-tools.h from a full oneAPI compiler install,
# looked up via CMPLR_ROOT/opt/compiler/include - not shipped by a plain
# llvm/clang build, so only enable it if CMPLR_ROOT is already set up.
if [ -n "${CMPLR_ROOT:-}" ] && [ -f "${CMPLR_ROOT}/opt/compiler/include/omp-tools.h" ]; then
    BUILD_WITH_OMP=1
    echo "  OpenMP:      found via CMPLR_ROOT=${CMPLR_ROOT} (BUILD_WITH_OMP=1)"
else
    BUILD_WITH_OMP=0
    echo "  OpenMP:      CMPLR_ROOT not set up, disabling (BUILD_WITH_OMP=0)"
fi

# OpenCL: only enable if the ICD loader is installed system-wide.
if ldconfig -p 2>/dev/null | grep -q 'libOpenCL\.so'; then
    BUILD_WITH_OPENCL=1
    echo "  OpenCL:      found, enabling (BUILD_WITH_OPENCL=1)"
else
    BUILD_WITH_OPENCL=0
    echo "  OpenCL:      not found, disabling (BUILD_WITH_OPENCL=0)"
fi

# --------------------------------------------------------------------------
# Step 3: Configure and build
# --------------------------------------------------------------------------
echo ""
echo "=== [3/4] Configuring and building unitrace ==="
cd "${UNITRACE_DIR}"
mkdir -p build && cd build

cmake \
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -DBUILD_WITH_L0="${BUILD_WITH_L0}" \
    -DBUILD_WITH_MPI="${BUILD_WITH_MPI}" \
    -DBUILD_WITH_OMP="${BUILD_WITH_OMP}" \
    -DBUILD_WITH_OPENCL="${BUILD_WITH_OPENCL}" \
    ..
make -j"${NPROC}"

# --------------------------------------------------------------------------
# Step 4: Install built artifacts into the prefix directory
# --------------------------------------------------------------------------
# The build directory lives inside WORKDIR, which is a temporary directory
# removed once the script exits successfully, so we must "make install" into
# PREFIX (outside WORKDIR) for the artifacts to survive.
echo ""
echo "=== [4/4] Installing built artifacts to ${PREFIX} ==="
make install

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "  Build complete!"
echo "=========================================="
echo ""
echo "  Tag:        ${TAG}"
echo "  Build type: ${BUILD_TYPE}"
echo "  Prefix:     ${PREFIX}"
echo ""
echo "  Enabled features:"
echo "    XPTI (SYCL/UR tracing): 1 (via ${ONEAPI_COMPILER_HOME})"
echo "    Level Zero:             ${BUILD_WITH_L0}"
echo "    MPI:                    ${BUILD_WITH_MPI}"
echo "    OpenMP:                 ${BUILD_WITH_OMP}"
echo "    OpenCL:                 ${BUILD_WITH_OPENCL}"
echo ""
echo "  Built artifacts:"
for f in "${PREFIX}/bin/unitrace" "${PREFIX}"/lib*/libunitrace_tool.so*; do
    if [ -e "${f}" ] && [ ! -L "${f}" ]; then
        echo "    ${f}"
    fi
done
echo ""
echo "  To use unitrace:"
echo "    LD_LIBRARY_PATH=${PREFIX}/lib:${PREFIX}/lib64:\$LD_LIBRARY_PATH \\"
echo "      ${PREFIX}/bin/unitrace --chrome-sycl-logging --chrome-device-logging \\"
echo "      -o trace.json <application> [args]"
echo ""

# Mark the build as successful so the EXIT trap removes the temporary
# work directory instead of keeping it around for debugging.
BUILD_OK=1
