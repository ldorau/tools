#!/usr/bin/env bash
# Reproduces https://github.com/intel/llvm/issues/22095:
# sycl-cts/test_multi_ptr fails on Level Zero GPU with driver 26.18.38308.1
# (Old Offload Model).
#
# Prerequisites:
#   - A built DPC++ toolchain with "dpclang++" available on PATH
#     (e.g. `export PATH=/path/to/llvm/build/bin:$PATH`).
#   - cmake, ninja, and git installed.
#
# Usage:
#   ./reproduce_issue_22095.sh [device_selector]
#
#   device_selector defaults to "level_zero:gpu" (the failing configuration).

set -x
set -euo pipefail

DEVICE_SELECTOR="${1:-level_zero:gpu}"
WORK_DIR="$(mktemp -d /tmp/sycl_cts_repro_22095.XXXXXX)"
CTS_SRC_DIR="$WORK_DIR/khronos_sycl_cts"
CTS_BUILD_DIR="$WORK_DIR/build-cts"

echo "==> Working directory: $WORK_DIR"

if ! command -v dpclang++ >/dev/null 2>&1; then
  echo "error: dpclang++ not found on PATH. Build/export the DPC++ toolchain first." >&2
  exit 1
fi

echo "==> Cloning SYCL-CTS"
git clone --depth 1 https://github.com/KhronosGroup/SYCL-CTS.git "$CTS_SRC_DIR"
git -C "$CTS_SRC_DIR" submodule update --init

echo "==> Configuring SYCL-CTS build"
cmake -GNinja -B "$CTS_BUILD_DIR" -S "$CTS_SRC_DIR" \
  -DCMAKE_CXX_COMPILER="$(which dpclang++)" \
  -DSYCL_IMPLEMENTATION=DPCPP \
  -DSYCL_CTS_ENABLE_OPENCL_INTEROP_TESTS=OFF \
  -DDPCPP_INSTALL_DIR="$(dirname "$(which dpclang++)")/.." \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DDPCPP_ENABLE_PREVIEW_CHANGES=OFF

echo "==> Building test_multi_ptr"
ninja -C "$CTS_BUILD_DIR" test_multi_ptr

echo "==> Running test_multi_ptr on $DEVICE_SELECTOR"
ONEAPI_DEVICE_SELECTOR="$DEVICE_SELECTOR" "$CTS_BUILD_DIR/bin/test_multi_ptr"
