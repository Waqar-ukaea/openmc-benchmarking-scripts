import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
from matplotlib.ticker import FuncFormatter
import os
import pandas as pd
import sh
import sys

# Format ticks as integers if possible, else float
def format_ticks_as_numbers(x, _):
    return f"{int(x)}" if x == int(x) else f"{x:.1f}"

# Try to use sed to extract data. Return a default value if an exception is raised (i.e no extractable data found)
def safe_sed_extract(flags, command, file, default_value=None):
    try:
        return int(sh.sed(flags, command, file)) if isinstance(default_value, int) else float(sh.sed(flags, command, file))
    except Exception:
        return default_value

# Extract data from slurm files
def get_openmc_output_from_slurm(batchDirectory, openmcRunData):
    if len(os.listdir(batchDirectory)) == 0:
        print("No files in directory provided")
        return

    for file in os.listdir(batchDirectory):
        if file.startswith("slurm"):
            print(f"{file} processing...")

            numberOfGPUs = safe_sed_extract("-ne", r's/^.*MPI Processes |*//p', file)
            simulationTime = safe_sed_extract("-ne", r's/.*Total time in simulation\s*=\s*\([0-9.e+-]*\) seconds/\1/p', file)
            calculationRate = safe_sed_extract("-ne", r's/.*Calculation Rate (active)\s*=\s*\([0-9.e+-]*\) particles\/second/\1/p', file)
            particleMemoryBuffer = safe_sed_extract("-ne", r's/.*size: \([0-9]*\) MB.*/\1/p', file)
            totalParticles = safe_sed_extract("-ne", r's|.*<particles>\([0-9]*\)</particles>.*|\1|p', file)
            particlesInFlight = safe_sed_extract("-ne", r's/.*-i \([0-9]\+\).*/\1/p', file, default_value=1000000)
            numberOfBatches = safe_sed_extract("-ne", r's|.*<batches>\([0-9]*\)</batches>.*|\1|p', file, default_value=1)

            openmcRunData.loc[len(openmcRunData)] = [
                numberOfGPUs, simulationTime, calculationRate,
                particleMemoryBuffer, totalParticles, particlesInFlight, numberOfBatches
            ]

# Reusable dual-axis plot function
def plot_data(x, y1, y1_label, y2=None, y2_label=None, title="", filename="", 
              x_label="x-axis", y_label="", y1_color="b", y2_color="g", 
              same_axis=False, log_axis=False):
    fig, ax1 = plt.subplots(figsize=(10, 5))

    # Apply base-2 logarithmic scaling if log_axis is True
    if log_axis:
        ax1.set_xscale("log", base=2)
        ax1.set_yscale("log", base=2)

    # Plot y1 on the primary axis
    ax1.plot(x, y1, marker="o", linestyle="-", color=y1_color, label=y1_label)
    ax1.set_xlabel(x_label)
    ax1.set_ylabel(y_label)
    ax1.grid(True, which="both", linestyle="-", linewidth=0.5)

    if y2 is not None:
        if same_axis:
            # Plot y2 on the same axis as y1
            ax1.plot(x, y2, marker="s", linestyle="--", color=y2_color, label=y2_label)
            ax1.legend(loc="upper left")  # Combine legends for y1 and y2
        else:
            # Create a secondary y-axis for y2
            ax2 = ax1.twinx()
            ax2.plot(x, y2, marker="s", linestyle="--", color=y2_color, label=y2_label)
            ax2.set_ylabel(y2_label, color=y2_color)
            ax2.tick_params(axis="y", labelcolor=y2_color)
            ax2.grid(False)  # Avoid duplicating the grid from ax1
            ax2.legend(loc="upper right")  # Separate legend for y2
    else:
        ax1.legend(loc="upper left")  # Legend for y1 only

    # Title and save
    fig.suptitle(title, fontsize=14)
    fig.tight_layout(rect=[0, 0, 1, 0.95])
    plt.savefig(filename)
    plt.show()

def plot_strong_scaling(gpus, title, y1, y1_label, *optional_lines):
    """
    Plots GPUs vs scaling data with optional additional lines.

    Parameters:
    - gpus: list of GPU counts (x-axis values).
    - title: str, the title of the plot.
    - y1: list of primary y-axis values to plot.
    - y1_label: str, label for the primary y-axis line.
    - *optional_lines: Optional additional lines in the format (y2, y2_label, y3, y3_label...).
    """
    fig, ax = plt.subplots(figsize=(10, 5))

    # Set scale types (logarithmic)
    ax.set_xscale('log', base=2)
    ax.set_yscale('log', base=2)

    # Ticks
    ax.grid(visible=True, which='both', linestyle='--', linewidth=0.5, alpha=0.7)
    ax.xaxis.set_major_formatter(FuncFormatter(lambda x, _: f"{int(x)}" if x == int(x) else f"{x:.1f}"))
    ax.yaxis.set_major_formatter(FuncFormatter(lambda x, _: f"{int(x)}" if x == int(x) else f"{x:.1f}"))
    ax.minorticks_on()

    # Plot primary line
    ax.plot(gpus, y1, marker="o", linestyle="-", label=y1_label)

    # Plot optional lines
    if len(optional_lines) % 2 != 0:
        raise ValueError("Optional arguments must be in pairs (data, label).")
    for i in range(0, len(optional_lines), 2):
        y_data = optional_lines[i]
        y_label = optional_lines[i + 1]
        ax.plot(gpus, y_data, marker="o", linestyle="-", label=y_label)

    # Add ideal scaling
    ax.plot(gpus, gpus, linestyle="--", color="red", label="Ideal Scaling")

    # Set labels, title, and grid
    ax.set_xlabel("No. of MI300X Compute Diess")
    ax.set_ylabel("Speedup")
    ax.set_title(title)
    ax.grid(True)

    # Add legend
    ax.legend()

    # Adjust layout and show the plot
    plt.tight_layout()
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

    speedup_a100 = []
    speedup_mi300 = []
    for i in range(0,8):
        speedup_a100.append(simTime_a100[0]/simTime_a100[i])
        speedup_mi300.append(simTime_mi300[0]/simTime_mi300[i])
    print(simTime_a100)
    print(simTime_mi300)

    # Plot simulation time
    plot_data(
        gpus, simTime_a100, "NVIDIA A100",
        y2=simTime_mi300, y2_label="AMD MI300",
        title=f"{title} (Simulation Time)",
        filename=f"{plotType}_simulation_time.png",
        x_label="Number of GPU Dies",
        y_label="Simulation Time (s)",
        same_axis=True
    )

    # Plot calculation rate
    plot_data(
        gpus, calcRate_a100, "NVIDIA A100",
        y2=calcRate_mi300, y2_label="AMD MI300",
        title=f"{title} (Calculation Rate)",
        filename=f"{plotType}_calculation_rate.png",
        x_label="Number of GPU Dies",
        y_label="Calculation Rate (Particle/Sec)",
        same_axis=True
    )

    plot_strong_scaling(gpus, f"{title} (Speedup)",
                        speedup_a100, "NVIDIA A100",
                        speedup_mi300, "AMD MI300X"
    )


# Plot in-flight particles
def plot_in_flight(plotType, openmcRunData, gpuName):
    simTime_a100 = openmcRunData["Simulation Time (s)"].values
    calcRate_a100 = openmcRunData["Calculation Rate (Particles/s)"].values
    inFlight_a100 = openmcRunData["Max Particles In Flight"].values/1e6
    particleMem_a100 = openmcRunData["Particle Memory Buffer (MB)"].values

    memoryUsage = [(i / 80e3) * 100 for i in particleMem_a100]

    title = f"Effect of Increasing Number of In-Flight Particles | Simple Tokamak - 1 ${gpuName}"

    # Plot simulation time vs in-flight particles
    plot_data(
        inFlight_a100, simTime_a100, "Simulation Time (s)",
        title=f"{title} (Simulation Time)",
        filename=f"{plotType}_{gpuName}simulation_time.png",
        x_label="Number of Particles in Flight (Million)",
        y_label="Simulation Time (s)"
    )

    # Plot calculation rate vs in-flight particles
    plot_data(
        inFlight_a100, calcRate_a100, "Calculation Rate (Particles/s)",
        y2=memoryUsage, y2_label="Memory Usage (%)",
        title=f"{title} (Calculation Rate)",
        filename=f"{plotType}_{gpuName}_calculation_rate.png",
        x_label="Number of Particles in Flight (Million)",
        y_label="Calculation Rate (Particles/Sec)"
    )

# Main program
plotType = input("Please input the type of plots to produce (<strong>, <weak>, <flight>): ").lower()
workingDir = input("Please input directory with slurm output files: ")

mi300DataStrong = pd.read_csv("mi300_strong.csv", sep=r'\s+')
mi300DataWeak = pd.read_csv("mi300_weak.csv", sep=r'\s+')

openmcRunData = pd.DataFrame(columns=[
    "Number of GPU Dies", "Simulation Time (s)", "Calculation Rate (Particles/s)",
    "Particle Memory Buffer (MB)", "Total Particles", "Max Particles In Flight",
    "Number Of Batches"
])

workingDir = f"{os.getcwd()}/{workingDir}"
os.chdir(workingDir)
get_openmc_output_from_slurm(workingDir, openmcRunData)

print(" \n Printing data that has been scraped from the files in the directory provided. Please ensure these are as expected: \n")
print(openmcRunData)

if openmcRunData.isna().any().any():
    print("Program has failed to acquire some data. Please check dataframe and fix any NaN issues in your data. Exiting...")
    sys.exit()

openmcRunData = openmcRunData.sort_values(by='Number of GPU Dies', ascending=True)

if plotType == "strong":    
    plot_scaling(plotType, openmcRunData, mi300DataStrong)
elif plotType == "weak":
    plot_scaling(plotType, openmcRunData, mi300DataWeak)
elif plotType == "flight":
    openmcRunData = openmcRunData.sort_values(by='Max Particles In Flight', ascending=True)
    plot_in_flight(plotType, openmcRunData, "NVIDIA A100")
else:
    print("Invalid plot type. Choose from <strong>, <weak>, <flight>.")
