#!/bin/bash

set +e
set -x

NPROC=64
if [ "$1" = "N" ]; then
	NPROC=$2
	shift 2
fi

if [ "$1" = "generate" ]; then
	shift
	cd
	python3 -m venv .venv
	source .venv/bin/activate
	cd $HOME/work/llvm/unified-runtime/build
	make generate
fi

GITHUB_WORKSPACE=$HOME/work
CC=clang
CXX=clang++

# SOURCE_DIR=$GITHUB_WORKSPACE/intel-restricted/applications.compilers.llvm-project
# SOURCE_DIR=$GITHUB_WORKSPACE/llvm
SOURCE_DIR=$(pwd)/..
echo "SOURCE_DIR=$SOURCE_DIR"
[ ! -d $SOURCE_DIR/.git ] && exit 1

BUILD_DIR=$SOURCE_DIR/build
INSTALL_DIR=$BUILD_DIR/install
mkdir -p $BUILD_DIR
mkdir -p $INSTALL_DIR

cd $BUILD_DIR
python3 $GITHUB_WORKSPACE/llvm/buildbot/configure.py \
	-t Debug \
	-w $GITHUB_WORKSPACE \
	-s $SOURCE_DIR \
       	-o $BUILD_DIR \
	--native_cpu \
	-DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
	-DCMAKE_C_COMPILER_LAUNCHER=ccache \
	-DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
	-DLLVM_INSTALL_UTILS=ON
	# --ci-defaults --native_cpu \
	# --ci-defaults --hip --cuda --native_cpu \

cmake --build $GITHUB_WORKSPACE/llvm/build --target sycl-toolchain -j64 || cmake --build $GITHUB_WORKSPACE/llvm/build --target sycl-toolchain || ( echo RV=$? ; echo "Build FAILED (target sycl-toolchain)" ; exit 1 )
echo "Build PASSED (target sycl-toolchain)"

# check-sycl-unittests
cmake --build $GITHUB_WORKSPACE/llvm/build --target check-sycl-unittests -j64 || cmake --build $GITHUB_WORKSPACE/llvm/build --target check-sycl-unittests --verbose || ( echo RV=$? ; echo "Tests FAILED (target check-sycl-unittests)" ; exit 1 )
echo "Tests PASSED (target check-sycl-unittests)"

# check-unified-runtime-conformance
cmake --build . -j64 -- check-unified-runtime-conformance || cmake --build . -- check-unified-runtime-conformance || ( echo RV=$? ; echo "Tests FAILED (target check-unified-runtime-conformance)" ; exit 1 )
echo "Tests PASSED (target check-unified-runtime-conformance)"

exit 0

# check-sycl
cmake --build $GITHUB_WORKSPACE/llvm/build --target check-sycl -j64 || ( echo RV=$? ; echo "Tests FAILED (target check-sycl)" ; exit 1 )
echo "Tests PASSED (target check-sycl)"

# check-sycl-e2e
cd $GITHUB_WORKSPACE/llvm
cmake -GNinja -B./build-e2e -S./sycl/test-e2e -DCMAKE_CXX_COMPILER="$(pwd)/build/bin/clang++" -DLLVM_LIT="$(pwd)/llvm/utils/lit/lit.py"
ninja -C build-e2e check-sycl-e2e -j48
