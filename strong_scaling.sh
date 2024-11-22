#!/bin/bash
#set -ue

# Remove machine* files
rm -f machine*

# Get command line arguments
while getopts o: flag; do
    case "${flag}" in
        o) job_name=${OPTARG} ;;
    esac
done

partition="ampere"

# Set default name of slurm outs
if [[ -z "${job_name}" ]]; then
    echo "No name provided for slurm out files. Slurm out files will be of format = 'slurm-$partition-jobID.out'"
    job_name=$partition
fi

# Set number of GPUs in an array for the specified partition
GPU_count=(1 2 3 4 5 6 7 8)

nodes=1  # Single node partial occupancy

input_file="settings.xml"
particles=160000000

# Loop over GPU counts
for nGPUS in "${GPU_count[@]}"; 
do  
    ((iteration++))
    echo "Nodes: $nodes, GPUs: $nGPUS, Particles: $particles, Particles/GPU: $((particles/nGPUS))"
    sbatch --nodes=$nodes --job-name=$job_name slurm_run_openmc-gpu 

    # Increment nodes after every 4 iterations
    if ((iteration % 4 == 0)); then
        ((nodes++))
    fi
done

