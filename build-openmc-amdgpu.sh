#!/bin/bash
set -e
module purge

export OMPI_CC=amdclang
export OMPI_CXX=amdclang++

SCRIPT_DIR=$PWD

OPENMC_DIR=$WORKSPACE/openmc
PRESET=llvm_mi300_mpi
BUILD_DIR=build
JOBS=16
INSTALL_DIR=install/openmc/$PRESET
PRE_ENV=$SCRIPT_DIR/amd-prebuild-env.sh
POST_ENV=$SCRIPT_DIR/amd-postbuild-env.sh
XSEC_DIR=$WORKSPACE/endfb-vii.1-hdf5/
LIBOMPDIR=/opt/rocm/llvm/lib

if [ -d $XSEC_DIR ]; then
  echo "Cross-Sections data directory $CROSS_SECTIONS_DIR already exists..."
else
  echo "Downloading endfb-vii.1-hdf5 Cross Section Data..."
  wget -O endfb-vii.1-hdf5.tar.xz https://anl.box.com/shared/static/9igk353zpy8fn9ttvtrqgzvw1vtejoz6.xz
  tar -xf endfb-vii.1-hdf5.tar.xz -C $WORKSPACE/
  rm endfb-vii.1-hdf5.tar.xz
  echo "Data Downloaded and extracted to $XSEC_DIR."
fi

# Source environment setup
source $PRE_ENV

cd $WORKSPACE

if [ -d $OPENMC_DIR ]; then
  echo "OpenMC directory $OPENMC_DIR already exists."
else 
  git clone https://github.com/exasmr/openmc.git
fi

cd $OPENMC_DIR
git submodule update --init --recursive

cp $SCRIPT_DIR/CMakePresets.json $OPENMC_DIR

# Configure
if [ -d $BUILD_DIR ]; then
    rm -r $BUILD_DIR
fi
mkdir $BUILD_DIR
cd $BUILD_DIR
cmake --preset=$PRESET \
      -Dcuda_thrust_sort=off \
      -Dsycl_sort=off \
      -Dhip_thrust_sort=on \
      -Ddebug=off \
      -Ddevice_printf=off \
      -Doptimize=on \
      -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
      -DCMAKE_EXE_LINKER_FLAGS="-L$LIBOMPDIR -lomp -L$LIBOMPDIR -lomptarget" \
      -DCMAKE_LIBRARY_PATH="/opt/rocm/llvm/lib" \
      -DCMAKE_VERBOSE_MAKEFILE=ON \
      -DCMAKE_LIBRARY_PATH="/opt/rocm/llvm/lib" \
      ../

make -j$JOBS

# Install
make install

echo "Check OMP_NUM_THREADS is desired amount the $POST_ENV script"

source $POST_ENV

