#!/bin/bash

EXE=$1
ARGS="${@:2}"
APP="$EXE $ARGS"

echo "Args passed to run-multi-gpu.sh: $APP"

# This is the list of GPUs we have
GPUS=(0 1 2 3)

# This is the list of NICs we should use for each GPU
# e.g., associate GPUs 0,1 with MLX0, GPUs 2,3 with MLX1
NICS=(mlx5_0:1 mlx5_0:1 mlx5_1:1 mlx5_1:1)

# This is the list of CPU cores we should use for each GPU
# On the Ampere nodes we have 2x64 core CPUs, each organised into 4 NUMA domains
# We will use only a subset of the available NUMA domains, i.e. 1 NUMA domain per GPU
# The NUMA domain closest to each GPU can be extracted from nvidia-smi
CPUS=(48-63 16-31 112-127 80-95)

# This is the list of memory domains we should use for each GPU
MEMS=(3 1 7 5)

# Number of physical CPU cores per GPU (optional)
export OMP_NUM_THREADS=16

lrank=$OMPI_COMM_WORLD_LOCAL_RANK

export CUDA_VISIBLE_DEVICES=${GPUS[${lrank}]}
export UCX_NET_DEVICES=${NICS[${lrank}]}
numactl --physcpubind=${CPUS[${lrank}]} --membind=${MEMS[${lrank}]} $APP
