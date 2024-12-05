#!/bin/bash
set -e

module load cuda
module load hdf5
module load openmpi
export OMPI_CC=~/compilers/llvm-install/bin/clang
export OMPI_CXX=~/compilers/llvm-install/bin/clang++

OPENMC_DIR=~/openmc-gpu/openmc
PRESET=llvm_h100_mpi
BUILD_DIR=build
JOBS=16
XSEC_DIR=nndc_hdf5/
INSTALL_DIR=install/openmc/$PRESET
ENV=~/setup-env.sh

# Source
source $ENV

echo "Clang version:" $(which clang)

cd $OPENMC_DIR

# Configure
if [ -d $BUILD_DIR ]; then
    rm -r $BUILD_DIR
fi
mkdir $BUILD_DIR
cd $BUILD_DIR
LINKERSTR="-L{~}/compilers/llvm-install/lib/ -lomp  -L{~}/compilers/llvm-install/lib/ -lomptarget"
CXXFLAGS=-v cmake --preset=$PRESET -Dcuda_thrust_sort=on -Dsycl_sort=off -Dhip_thrust_sort=off -Ddebug=off -Ddevice_printf=off -Doptimize=on -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -Dldflags="$LINKERSTR" ../

make -j$JOBS

# Install
make install

export PATH=$PATH:~/openmc-gpu/openmc/build/bin
export OPENMC_CROSS_SECTIONS=~/nndc_hdf5/cross_sections.xml


