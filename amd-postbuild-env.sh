export PATH=$PATH:~/openmc/build/install/openmc/llvm_mi300_mpi/bin
export OPENMC_CROSS_SECTIONS=~/endfb-vii.1-hdf5/cross_sections.xml

export OMP_TARGET_OFFLOAD=MANDATORY
export OMP_PROC_PLACES=cores
export OMP_PROC_BIND=close
export OMP_NUM_THREADS=16

