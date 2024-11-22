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
    echo "No name provided for slurm out files. Slurm out files will be of format = 'slurm-A100-weak-jobID.out'"
    job_name="A100-weak"
fi

# Set number of GPUs in an array for the specified partition
GPU_count=(1 2 3 4 5 6 7 8)

nodes=1  # Single node partial occupancy

# Reset to 20 mil particles
old_particles=`sed -n 's|.*<particles>\([0-9]*\)</particles>.*|\1|p' settings.xml`
sed -i "s|<particles>${old_particles}</particles>|<particles>20000000</particles>|" settings.xml


# Prepare directories for weak scaling
for nGPUS in "${GPU_count[@]}"; 
do  
    ((iteration++))
    working_dir="${job_name}/${nGPUS}gpus/"
    mkdir -p "${working_dir}"
    old_particles=`sed -n 's|.*<particles>\([0-9]*\)</particles>.*|\1|p' settings.xml`
    particles=$((20000000*nGPUS))
    sed -i "s|<particles>${old_particles}</particles>|<particles>${particles}</particles>|" settings.xml
    cp *.xml "${working_dir}"
    
    # Calculate the new value
    echo "Nodes: $nodes, GPUs: $nGPUS, Particles: $particles, Particles/GPU: $((particles/nGPUS))"
    sbatch --nodes=$nodes --ntasks=$nGPUS --job-name=$job_name --export=run_dir=$working_dir slurm_run_openmc-gpu 
    # Replace the value in the file
    
    # Increment nodes after every 4 iterations
    if ((iteration % 4 == 0)); then
        ((nodes++))
    fi
done


# Remember to clear up directories when finished!
