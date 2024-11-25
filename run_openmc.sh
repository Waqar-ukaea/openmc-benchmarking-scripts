#!/bin/bash


# Check if a GPU count is provided as a positional argument
if [[ $# -lt 1 ]]; then
    echo "Error: No GPU count specified."
    echo "Usage: $0 <number_of_gpus>"
    exit 1
fi
GPUS=$1
shift # Shift positional arguement to handle next one 

run_dir=$1
shift

if [ "$(ls -A "$run_dir")" ]; then
        RUN_DIR=$run_dir
    else
        RUN_DIR=$PWD
fi

OPENMC_PROFILE=/home/ir-butt2/rds/rds-ukaea-ap001/ir-butt2/openmc-gpu-work/profiles/ampere-profile-openmc.sh
RUN_DIR=$PWD

echo "Loading module files and exporting environment variables..."
echo
source $OPENMC_PROFILE
echo 

export OMP_NUM_THREADS=16
export OMP_PROC_PLACES=cores
export OMP_PROC_BIND=close

OMPI_STR="mpirun -np $GPUS --bind-to none"
echo OMPI_STR="${OMPI_STR}"

echo "Running OpenMC with GPU in directory: ${RUN_DIR}"

# RUN_STR="-i 25000000"

echo "OpenMC will be run on GPU"
RUN_STR="--event ${RUN_STR}"
MULTI_GPU_SCRIPT="run-multi-gpu.sh"
echo "MULTI_GPU_SCRIPT=${MULTI_GPU_SCRIPT}"

CMD="${OMPI_STR} ${MULTI_GPU_SCRIPT} openmc ${RUN_STR}"
# CMD="${OMPI_STR} openmc ${RUN_STR}"
CMD="openmc --event -i $((SLURM_ARRAY_TASK_ID*1000000))"
echo -e "\nExecuting command:\n------------------\n$CMD\n" 
eval $CMD

