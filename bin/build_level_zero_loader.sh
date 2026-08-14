#!/bin/bash

#
# Copyright (C) 2026 Intel Corporation
#
# SPDX-License-Identifier: MIT
#

#
# Build the oneAPI Level Zero Loader (libze_loader.so), Validation Layer and
# Tracing Layer from https://github.com/oneapi-src/level-zero for a given
# release tag.
#
# This is normally needed when a Level Zero driver build (e.g. a local
# compute-runtime checkout) doesn't ship/vendor its own libze_loader.so and
# ends up resolving an older system-installed one instead (e.g. the distro
# "libze1" package), which can be missing entry points that recently-added
# driver extensions rely on (e.g. zeCommandListAppendLaunchKernelWithArguments),
# causing them to fail at runtime with ZE_RESULT_ERROR_UNSUPPORTED_FEATURE
# even though the driver itself implements the function just fine.
#
# The build produces the DYNAMIC loader (libze_loader.so + friends), NOT the
# static loader (-DBUILD_STATIC=1 is intentionally not used): the goal is a
# shared object that can be dropped into a driver build's library directory
# (e.g. compute-runtime/build/bin or .../build/lib) so it is picked up via
# LD_LIBRARY_PATH ahead of any older system-installed loader.
#
# Usage:
#   ./build_level_zero_loader.sh <tag> [install_prefix] [build_type]
#
# Examples:
#   ./build_level_zero_loader.sh v1.24.1
#   ./build_level_zero_loader.sh v1.24.1 $HOME/my_prefix
#   ./build_level_zero_loader.sh v1.24.1 $HOME/my_prefix Debug
#
# The latest release tag can be found at:
#   https://github.com/oneapi-src/level-zero/releases/latest

# Exit immediately on error, treat unset variables as errors, and fail on
# any command in a pipeline that fails (not just the last one).
set -euo pipefail

# Parse arguments: the release tag is required, the install prefix and build
# type are optional.
# PREFIX is where the loader/layers are installed (no sudo needed). It must
# be readable at driver load time (LD_LIBRARY_PATH=${PREFIX}/lib).
# Defaults to $HOME/local if not specified.
# BUILD_TYPE (CMAKE_BUILD_TYPE) defaults to Release if not specified.
TAG="${1:?Usage: $0 <tag> [install_prefix] [build_type]}"
PREFIX="${2:-$HOME/local}"
BUILD_TYPE="${3:-Release}"
REPO_URL="https://github.com/oneapi-src/level-zero"

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

# Validate the tag format: level-zero tags look like "v1.24" or "v1.24.1".
if ! echo "${TAG}" | grep -qE '^v[0-9]+\.[0-9]+(\.[0-9]+)?$'; then
    echo "ERROR: '${TAG}' is not a valid level-zero tag." >&2
    echo "       Expected format: vMAJOR.MINOR[.PATCH] (e.g. v1.24.1)" >&2
    echo "       See: ${REPO_URL}/releases" >&2
    exit 1
fi

# Verify the tag actually exists on the remote before doing any work.
if ! git ls-remote --tags "${REPO_URL}.git" "refs/tags/${TAG}" 2>/dev/null | grep -q .; then
    echo "ERROR: tag '${TAG}' not found in ${REPO_URL}" >&2
    echo "       See: ${REPO_URL}/releases" >&2
    exit 1
fi

# All intermediate build artifacts go into a temporary directory that is
# printed at the end so the user can clean it up manually if desired.
WORKDIR="$(mktemp -d)"
NPROC="$(nproc)"

echo "=== Building level-zero loader tag: ${TAG} ==="
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
# Step 1: Clone level-zero at the requested tag
# --------------------------------------------------------------------------
# Shallow clone (--depth 1) is sufficient since we only need the source at
# this exact tag, not the full git history.
echo "=== [1/3] Cloning level-zero at tag ${TAG} ==="
SRCDIR="${WORKDIR}/level-zero"
git clone --depth 1 -b "${TAG}" "${REPO_URL}.git" "${SRCDIR}"

# --------------------------------------------------------------------------
# Step 2: Configure and build
# --------------------------------------------------------------------------
# BUILD_STATIC is intentionally left unset (defaults to off) so that the
# dynamic loader (libze_loader.so), validation layer and tracing layer are
# built, matching what a driver build's LD_LIBRARY_PATH needs to pick up.
echo ""
echo "=== [2/3] Configuring and building level-zero loader ==="
cd "${SRCDIR}"
mkdir -p build && cd build

cmake \
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    ..
make -j"${NPROC}"

# --------------------------------------------------------------------------
# Step 3: Install built artifacts into the prefix directory
# --------------------------------------------------------------------------
# The build directory lives inside WORKDIR, which is a temporary directory
# removed once the script exits successfully, so we must "make install" into
# PREFIX (outside WORKDIR) for the artifacts to survive.
echo ""
echo "=== [3/3] Installing built artifacts to ${PREFIX} ==="
make install

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
# Print the version used and the paths to the built loader libraries.
# Also show the exact command needed to make a driver build (e.g.
# compute-runtime) resolve this loader ahead of any system-installed one.
echo ""
echo "=========================================="
echo "  Build complete!"
echo "=========================================="
echo ""
echo "  Tag:        ${TAG}"
echo "  Build type: ${BUILD_TYPE}"
echo "  Prefix:     ${PREFIX}"
echo ""
echo "  Built artifacts:"
for lib in "${PREFIX}"/lib*/libze_loader.so* "${PREFIX}"/lib*/libze_validation_layer.so* "${PREFIX}"/lib*/libze_tracing_layer.so*; do
    if [ -e "${lib}" ] && [ ! -L "${lib}" ]; then
        echo "    ${lib}"
    fi
done
echo ""
echo "  To make a driver build (e.g. compute-runtime) use this loader"
echo "  instead of an older system-installed one, copy/symlink it into the"
echo "  driver's own library directory (searched via LD_LIBRARY_PATH before"
echo "  system paths), e.g.:"
echo "    cp -a ${PREFIX}/lib*/libze_loader.so* \\"
echo "          ${PREFIX}/lib*/libze_validation_layer.so* \\"
echo "          ${PREFIX}/lib*/libze_tracing_layer.so* \\"
echo "          <driver_build_dir>/bin/"
echo ""

# Mark the build as successful so the EXIT trap removes the temporary
# work directory instead of keeping it around for debugging.
BUILD_OK=1
