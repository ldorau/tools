#!/bin/bash
#
# export DIR="$HOME/work/llvm"
# cd $DIR
# python3 ./buildbot/configure.py -t Debug -w .. -s . -o ./build --native_cpu -DCMAKE_INSTALL_PREFIX=$DIR/build/install -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache -DLLVM_INSTALL_UTILS=ON -DUR_BUILD_ADAPTER_L0=ON -DUR_BUILD_ADAPTER_L0_V2=ON -DUR_BUILD_ADAPTER_HIP=OFF -DUR_BUILD_ADAPTER_CUDA=OFF -DUR_BUILD_ADAPTER_OPENCL=ON -DUR_BUILD_ADAPTER_NATIVE_CPU=ON -DUR_USE_EXTERNAL_UMF=OFF
# python3 ./buildbot/compile.py -s . -o ./build -j 128
# python3 ./buildbot/compile.py -s . -o ./build -t sycl-toolchain -j 128
# python3 ./buildbot/compile.py -s . -o ./build -t FileCheck -j 128
# python3 ./buildbot/compile.py -s . -o ./build -t not -j 128
# python3 ./buildbot/compile.py -s . -o ./build -t check-sycl-unittests -j 128
#

export ZE_AFFINITY_MASK=1
export ZE_ENABLE_ALT_DRIVERS=~/workdir/compute-runtime-build/bin/libze_intel_gpu.so
export LD_LIBRARY_PATH=~/workdir/igc-install/lib/:~/workdir/level-zero-install/lib/:$LD_LIBRARY_PATH

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

SKIP_CONF=0
if [ "$1" = "skip_conf" ]; then
	shift
	SKIP_CONF=1
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

if [ $SKIP_CONF -eq 0 ]; then
	python3 $GITHUB_WORKSPACE/llvm/buildbot/configure.py \
		-t Debug \
		-w $GITHUB_WORKSPACE \
		-s $SOURCE_DIR \
		-o $BUILD_DIR \
		--native_cpu \
		-DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
		-DCMAKE_C_COMPILER_LAUNCHER=ccache \
		-DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
		-DLLVM_INSTALL_UTILS=ON \
		-DUR_BUILD_ADAPTER_L0=ON \
		-DUR_BUILD_ADAPTER_L0_V2=ON \
		-DUR_BUILD_ADAPTER_HIP=OFF \
		-DUR_BUILD_ADAPTER_CUDA=OFF \
		-DUR_BUILD_ADAPTER_OPENCL=ON \
		-DUR_BUILD_ADAPTER_NATIVE_CPU=OFF \
		-DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
		-DUR_USE_EXTERNAL_UMF=OFF
		# --ci-defaults --native_cpu \
		# --ci-defaults --hip --cuda --native_cpu \
		# -DLEVEL_ZERO_INCLUDE_DIR="" \
		# -DLEVEL_ZERO_INCLUDE_DIR=$HOME/work/llvm/build/content-exp-headers/level_zero/include \
fi

if [ "$1" = "cmake" ]; then
	cd $BUILD_DIR
	# cd $SOURCE_DIR
	cmake --build $GITHUB_WORKSPACE/llvm/build --target sycl-toolchain -j $NPROC || cmake --build $GITHUB_WORKSPACE/llvm/build --target sycl-toolchain || ( echo RV=$? ; echo "Build FAILED (target sycl-toolchain)" ; exit 1 )
	echo "Build PASSED (target sycl-toolchain)"

	# check-sycl-unittests
	cmake --build $GITHUB_WORKSPACE/llvm/build --target check-sycl-unittests -j $NPROC || cmake --build $GITHUB_WORKSPACE/llvm/build --target check-sycl-unittests --verbose || ( echo RV=$? ; echo "Tests FAILED (target check-sycl-unittests)" ; exit 1 )
	echo "Tests PASSED (target check-sycl-unittests)"

	# check-sycl
	cmake --build $GITHUB_WORKSPACE/llvm/build --target check-sycl -j $NPROC || ( echo RV=$? ; echo "Tests FAILED (target check-sycl)" ; exit 1 )
	echo "Tests PASSED (target check-sycl)"

	# check-sycl-e2e
	cd $GITHUB_WORKSPACE/llvm
	cmake -GNinja -B./build-e2e -S./sycl/test-e2e -DCMAKE_CXX_COMPILER="$(pwd)/build/bin/clang++" -DLLVM_LIT="$(pwd)/llvm/utils/lit/lit.py"
	ninja -C build-e2e check-sycl-e2e -j $NPROC

	exit 0 ############################################
fi

function build_target_j() {
	cd $SOURCE_DIR
	echo "$ python3 ./buildbot/compile.py -s . -o ./build $* ..."
	python3 ./buildbot/compile.py -s . -o ./build $*
}

function build_target() {
	TARGET=$2
	build_target_j $* -j $NPROC || build_target_j $* || ( echo RV=$? ; echo "Build FAILED (target $TARGET)" ; exit 1 )
	echo "Build PASSED (target $TARGET)"
}

build_target
build_target -t sycl-toolchain
build_target -t FileCheck
build_target -t not
build_target -t check-sycl-unittests

echo

# sycl/unittests
if [ "$1" != "skip" ]; then
	echo "TESTING: sycl/unittests/$1"
	echo "$ ./build/bin/llvm-lit -v -j $NPROC --param \"sycl_devices=level_zero_v2:gpu\" ./sycl/unittests/$1"
	cd $SOURCE_DIR
	env UR_LOADER_USE_LEVEL_ZERO_V2=1 ./build/bin/llvm-lit -v -j $NPROC --param "sycl_devices=level_zero_v2:gpu" ./sycl/unittests/$1
else
	echo "SKIPPED tests: sycl/unittests/"
fi

echo

# build_target -t check-sycl
if [ "$2" != "skip" ]; then
	echo "TESTING: sycl/test/$2"
	echo "$ ./build/bin/llvm-lit -v -j $NPROC --param \"sycl_devices=level_zero_v2:gpu\" ./sycl/test/$2"
	cd $SOURCE_DIR
	env UR_LOADER_USE_LEVEL_ZERO_V2=1 ./build/bin/llvm-lit -v -j $NPROC --param "sycl_devices=level_zero_v2:gpu" ./sycl/test/$2
else
	echo "SKIPPED tests: sycl/test/"
fi

echo

if [ "$3" != "skip" ]; then
	echo "TESTING: sycl/test-e2e/$3"
	echo "$ ./build/bin/llvm-lit -v -j $NPROC --param \"sycl_devices=level_zero_v2:gpu\" ./sycl/test-e2e/$3"
	cd $SOURCE_DIR
	env UR_LOADER_USE_LEVEL_ZERO_V2=1 ./build/bin/llvm-lit -v -j $NPROC --param "sycl_devices=level_zero_v2:gpu" ./sycl/test-e2e/$3
else
	echo "SKIPPED tests: sycl/test-e2e/"
fi

set +x
echo
echo ZE_AFFINITY_MASK=$ZE_AFFINITY_MASK
echo ZE_ENABLE_ALT_DRIVERS=$ZE_ENABLE_ALT_DRIVERS
echo LD_LIBRARY_PATH=$LD_LIBRARY_PATH
