import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
from matplotlib.ticker import FuncFormatter
import os
import pandas as pd
import sh

# Format ticks as integers if possible, else float
def format_ticks_as_numbers(x, _):
    return f"{int(x)}" if x == int(x) else f"{x:.1f}"

# Extract data from slurm files
def get_openmc_output_from_slurm(batchDirectory, openmcRunData):
    if len(os.listdir(batchDirectory)) == 0:
        print("No files in directory provided")
        return

    for file in os.listdir(batchDirectory):
        if file.startswith("slurm"):
            print(f"{file} processing...")

            numberOfGPUs = int(sh.sed('-ne', r's/^.*MPI Processes |*//p', file))
            simulationTime = float(sh.sed('-ne', r's/.*Total time in simulation\s*=\s*\([0-9.e+-]*\) seconds/\1/p', file))
            calculationRate = float(sh.sed('-ne', r's/.*Calculation Rate (active)\s*=\s*\([0-9.e+-]*\) particles\/second/\1/p', file))
            particleMemoryBuffer = int(sh.sed('-ne', r's/.*size: \([0-9]*\) MB.*/\1/p', file))
            totalParticles = int(sh.sed('-ne', r's|.*<particles>\([0-9]*\)</particles>.*|\1|p', file))
            particlesInFlight = int(sh.sed('-ne', r's/.*-i \([0-9]\+\).*/\1/p', file))
            numberOfBatches = int(sh.sed('-ne', r's|.*<batches>\([0-9]*\)</batches>.*|\1|p', file))

            openmcRunData.loc[len(openmcRunData)] = [
                numberOfGPUs, simulationTime, calculationRate,
                particleMemoryBuffer, totalParticles, particlesInFlight, numberOfBatches
            ]

# Reusable dual-axis plot function
def plot_with_dual_axes(x, y1, y1_label, y2, y2_label, title, filename, x_label="x-axis", y1_color="b", y2_color="g"):
    fig, ax1 = plt.subplots(figsize=(10, 5))

    # Plot the primary y-axis data
    ax1.plot(x, y1, marker="o", linestyle="-", color=y1_color, label=y1_label)
    ax1.set_xlabel(x_label)
    ax1.set_ylabel(y1_label, color=y1_color)
    ax1.tick_params(axis="y", labelcolor=y1_color)
    ax1.grid(True)

    # Create the secondary y-axis
    ax2 = ax1.twinx()
    ax2.plot(x, y2, marker="s", linestyle="--", color=y2_color, label=y2_label)
    ax2.set_ylabel(y2_label, color=y2_color)
    ax2.tick_params(axis="y", labelcolor=y2_color)

    # Add title and legend
    fig.suptitle(title, fontsize=14)
    lines1, labels1 = ax1.get_legend_handles_labels()
    lines2, labels2 = ax2.get_legend_handles_labels()
    ax2.legend(lines1 + lines2, labels1 + labels2, loc="upper left")

    # Save and show plot
    fig.tight_layout(rect=[0, 0, 1, 0.95])
    plt.savefig(filename)
    plt.show()

# Plot scaling efficiency
def plot_scaling(plotType, openmcRunData, mi300Data):
    gpus = (1, 2, 3, 4, 5, 6, 7, 8)

    simTime_a100 = openmcRunData["Simulation Time (s)"].values
    calcRate_a100 = openmcRunData["Calculation Rate (Particles/s)"].values
    simTime_mi300 = mi300Data["Simulation_Time(s)"].values
    calcRate_mi300 = mi300Data["Calculation_Rate(particles/sec)"].values

    scaling_eff = "Speedup" if plotType == "strong" else "Efficiency"
    title = f"{'Strong' if plotType == 'strong' else 'Weak'} Scaling | Simple Tokamak"

    # Plot simulation time
    plot_with_dual_axes(
        gpus, simTime_a100, "Simulation Time (s)",
        simTime_mi300, "MI300 Simulation Time (s)",
        f"{title} (Simulation Time)",
        f"{plotType}_simulation_time.png",
        x_label="Number of GPUs"
    )

    # Plot calculation rate
    plot_with_dual_axes(
        gpus, calcRate_a100, "Calculation Rate (Particles/s)",
        calcRate_mi300, "MI300 Calculation Rate",
        f"{title} (Calculation Rate)",
        f"{plotType}_calculation_rate.png",
        x_label="Number of GPUs"
    )

# Plot in-flight particles
def plot_in_flight(plotType, openmcRunData, gpuName):
    simTime_a100 = openmcRunData["Simulation Time (s)"].values
    calcRate_a100 = openmcRunData["Calculation Rate (Particles/s)"].values
    inFlight_a100 = openmcRunData["Max Particles In Flight"].values
    particleMem_a100 = openmcRunData["Particle Memory Buffer (MB)"].values

    memoryUsage = [(i / 80e3) * 100 for i in particleMem_a100]

    title = f"Effect of Increasing Number of In-Flight Particles | Simple Tokamak - 1 ${gpuName}"

    # Plot simulation time vs in-flight particles
    plot_with_dual_axes(
        inFlight_a100, simTime_a100, "Simulation Time (s)",
        memoryUsage, "Memory Usage (%)",
        f"{title} (Simulation Time)",
        f"{plotType}_{gpuName}simulation_time.png",
        x_label="Number of Particles in Flight"
    )

    # Plot calculation rate vs in-flight particles
    plot_with_dual_axes(
        inFlight_a100, calcRate_a100, "Calculation Rate (Particles/s)",
        memoryUsage, "Memory Usage (%)",
        f"{title} (Calculation Rate)",
        f"{plotType}_{gpuName}_calculation_rate.png",
        x_label="Number of Particles in Flight"
    )

# Main program
plotType = input("Please input the type of plots to produce (<strong>, <weak>, <flight>): ").lower()
workingDir = input("Please input directory with slurm output files: ")

mi300DataStrong = pd.read_csv("mi300_strong.csv", sep=r'\s+')
mi300DataWeak = pd.read_csv("mi300_weak.csv", sep=r'\s+')

openmcRunData = pd.DataFrame(columns=[
    "Number of GPUs", "Simulation Time (s)", "Calculation Rate (Particles/s)",
    "Particle Memory Buffer (MB)", "Total Particles", "Max Particles In Flight",
    "Number Of Batches"
])

workingDir = f"{os.getcwd()}/{workingDir}"
os.chdir(workingDir)
get_openmc_output_from_slurm(workingDir, openmcRunData)

print(" \n Printing data that has been scraped from the files in the directory provided. Please ensure these are as expected: \n")
print(openmcRunData)
openmcRunData = openmcRunData.sort_values(by='Number of GPUs', ascending=True)

if plotType == "strong":    
    plot_scaling(plotType, openmcRunData, mi300DataStrong)
elif plotType == "weak":
    plot_scaling(plotType, openmcRunData, mi300DataWeak)
elif plotType == "flight":
    openmcRunData = openmcRunData.sort_values(by='Max Particles In Flight', ascending=True)
    plot_in_flight(plotType, openmcRunData, "NVIDIA A100")
else:
    print("Invalid plot type. Choose from <strong>, <weak>, <flight>.")
