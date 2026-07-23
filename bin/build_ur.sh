#!/bin/bash

set -ex

[ "$VIRTUAL_ENV" = "" ] && cd ; python3 -m venv .venv ; source .venv/bin/activate ; cd -

NPROC=128
if [ "$1" = "N" ]; then
	NPROC=$2
	shift 2
fi

export GITHUB_WORKSPACE=$HOME/work
# export CC=clang
# export CXX=clang++

# export ZE_ENABLE_ALT_DRIVERS=$HOME/workdir/compute-runtime-build/bin/libze_intel_gpu.so
# UR_SOURCE=$GITHUB_WORKSPACE/llvm/unified-runtime
# UR_BUILD=$GITHUB_WORKSPACE/llvm/unified-runtime/build
# mkdir -p $UR_BUILD

UR_SOURCE=".."
UR_INSTALL=$GITHUB_WORKSPACE/unified-runtime-install
mkdir -p $UR_INSTALL

# cd $UR_BUILD
pwd

cmake -S $UR_SOURCE -B . -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ -DCMAKE_BUILD_TYPE=Debug -DUR_BUILD_ADAPTER_L0_V2=ON -DUR_DPCXX=$GITHUB_WORKSPACE/llvm/build/bin/clang++ -DCMAKE_INSTALL_PREFIX=$UR_INSTALL -DUR_FORMAT_CPP_STYLE=ON -DUR_ENABLE_TRACING=ON -DUR_DEVELOPER_MODE=ON -DUR_BUILD_TESTS=ON -DUR_BUILD_ADAPTER_L0_V2=ON  -DUR_STATIC_LOADER=OFF -DUR_STATIC_ADAPTER_L0_V2=OFF -DUR_SYCL_LIBRARY_DIR=$GITHUB_WORKSPACE/llvm/build/lib/

if [ "$1" = "generate" ]; then
	shift
	make generate || exit 1
fi

make -j $NPROC && make -j $NPROC install || make
make -j $NPROC install

cmake --build . -j $NPROC

# cmake --build . -j $NPROC -- check-unified-runtime-conformance
# echo ">>> conformance L0v1"
# $GITHUB_WORKSPACE/llvm/build/bin/llvm-lit -v -j $NPROC --param "selector=level_zero:*" ./test/conformance/
echo "#######################################################################################################"
echo ">>> conformance L0v2"
echo "+ LD_LIBRARY_PATH=$HOME/work/llvm/unified-runtime/build/lib:$LD_LIBRARY_PATH UR_LOADER_USE_LEVEL_ZERO_V2=1 ZES_ENABLE_SYSMAN=1 $GITHUB_WORKSPACE/llvm/build/bin/llvm-lit -v -j $NPROC --param selector=level_zero_v2:* ./test/conformance/"
LD_LIBRARY_PATH=$HOME/work/llvm/unified-runtime/build/lib:$LD_LIBRARY_PATH UR_LOADER_USE_LEVEL_ZERO_V2=1 ZES_ENABLE_SYSMAN=1 $GITHUB_WORKSPACE/llvm/build/bin/llvm-lit -v -j $NPROC --param selector=level_zero_v2:* ./test/conformance/
echo "#######################################################################################################"

# cmake --build . -j $NPROC -- check-unified-runtime-adapter
# echo ">>> adapters L0v1"
# $GITHUB_WORKSPACE/llvm/build/bin/llvm-lit -v -j $NPROC --param "selector=level_zero:*" ./test/adapters/
echo "#######################################################################################################"
echo ">>> adapters L0v2"
echo "+ LD_LIBRARY_PATH=$HOME/work/llvm/unified-runtime/build/lib:$LD_LIBRARY_PATH UR_LOADER_USE_LEVEL_ZERO_V2=1 ZES_ENABLE_SYSMAN=1 $GITHUB_WORKSPACE/llvm/build/bin/llvm-lit -v -j $NPROC --param selector=level_zero_v2:* ./test/adapters/"
LD_LIBRARY_PATH=$HOME/work/llvm/unified-runtime/build/lib:$LD_LIBRARY_PATH UR_LOADER_USE_LEVEL_ZERO_V2=1 ZES_ENABLE_SYSMAN=1 $GITHUB_WORKSPACE/llvm/build/bin/llvm-lit -v -j $NPROC --param selector=level_zero_v2:* ./test/adapters/
echo "#######################################################################################################"

exit 0

make -j $NPROC || make
echo "Done. RV=$?"
[ $? -eq 0 ] && ctest -V
echo "Done. RV=$?"
