#!/bin/bash
set -e

# Default values
ROOT_DIR="strong-scaling-data"
NUM_SUBDIRS=4
PARTICLES=20000000
BATCHES=10
SUBDIR_NAMES=()

# Parse command-line arguments using getopt
OPTIONS=$(getopt -o d:n:s:h --long directory:,number-of-subdirs:,subdir-names:,help -- "$@")
if [ $? -ne 0 ]; then
    echo "Failed to parse arguments" >&2
    exit 1
fi

# Evaluate the arguments
eval set -- "$OPTIONS"

# Process options
while true; do
    case "$1" in
        -d|--directory)
            ROOT_DIR="$2"
            shift 2
            ;;
        -n|--number-of-subdirs)
            NUM_SUBDIRS="$2"
            if ! [[ "$NUM_SUBDIRS" =~ ^[0-9]+$ ]]; then
                echo "Error: --number-of-subdirs must be an integer." >&2
                exit 1
            fi
            shift 2
            ;;
        -s|--subdir-names)
            # Parse the array of subdirectory names using IFS (Internal Field Separator)
            IFS=',' read -r -a SUBDIR_NAMES <<< "$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [-d|--directory <directory_name>] [-n|--number-of-subdirs <number>] [-s|--subdir-names <subdir1,subdir2,...>] [-h|--help]"
            echo "This script can be used to generate a root-dir which contains subdirectories for each point"
            echo "of a strong scaling study for OpenMC-GPU. It should be run in a directory with openmc .xml files."
            echo " "
            echo "  -d, --directory           Specify the root directory name (default: strong-scaling-data)"
            echo "  -n, --number-of-subdirs   Specify the number of subdirectories to create (default: 4)"
            echo "  -s, --subdir-names        Specify a comma-separated list of subdirectory names (overrides -n)"
            echo "  -h, --help                Display this help message"
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Unexpected option: $1" >&2
            exit 1
            ;;
    esac
done

# Function: Parse values from settings.xml
parse_settings_xml() {
    local xml_file="settings.xml"
    if [ ! -f "$xml_file" ]; then
        echo "Error: $xml_file not found in the current directory." >&2
        exit 1
    fi

    # Extract <particles> value
    PARTICLES=$(grep -oP '(?<=<particles>)[0-9]+(?=</particles>)' "$xml_file")
    # Extract <batches> value
    BATCHES=$(grep -oP '(?<=<batches>)[0-9]+(?=</batches>)' "$xml_file")

    if [[ -z "$PARTICLES" || -z "$BATCHES" ]]; then
        echo "Error: Could not extract <particles> or <batches> from $xml_file." >&2
        exit 1
    fi
}

# Function: Generate a configuration file
generate_config_file() {
    local config_file="$ROOT_DIR/node_config.sh"
    # Ensure the file is overwritten at the beginning with the initial lines
    echo "#!/bin/bash" > "$config_file"
    echo "# --------------------------------------------------------------------------------------" >> "$config_file"
    echo "# This script has been automatically generated via running setup-strong-scaling.sh." >> "$config_file"
    echo "# It acts as a convenience to change the settings for individual settings.xml files" >> "$config_file"
    echo "# when running a strong scaling study of OpenMC-GPU. You should change the values" >> "$config_file"
    echo "# that have been automatically populated as they are not representative of a strong" >> "$config_file"
    echo "# scaling study problem." >> "$config_file"
    echo "# --------------------------------------------------------------------------------------" >> "$config_file"
    echo " "
    echo "declare -A particles_per_batch" >> "$config_file"
    echo "declare -A batches" >> "$config_file"
    # If subdir names are passed, use them
    if [ ${#SUBDIR_NAMES[@]} -gt 0 ]; then
        NUM_SUBDIRS=${#SUBDIR_NAMES[@]}  # Update NUM_SUBDIRS to match the length of the array
        for ((i=0; i<NUM_SUBDIRS; i++)); do
            local subdir="${SUBDIR_NAMES[$i]}"
            local scaled_particles=$((PARTICLES * (i+1)))
            local scaled_batches=$((BATCHES / (i+1)))

            # Properly quote subdir names to avoid issues with special characters or spaces
            echo "particles_per_batch[\"$subdir\"]=$scaled_particles" >> "$config_file"
            echo "batches[\"$subdir\"]=$scaled_batches" >> "$config_file"
        done
    else
        # Default case if no subdir names are passed
        for ((i=1; i<=NUM_SUBDIRS; i++)); do
            local subdir="subdir-$i"
            local scaled_particles=$((PARTICLES * i))
            local scaled_batches=$((BATCHES / i))

            echo "particles_per_batch[\"$subdir\"]=$scaled_particles" >> "$config_file"
            echo "batches[\"$subdir\"]=$scaled_batches" >> "$config_file"
        done
    fi

    # Add XML update function to the config file
    cat << 'EOF' >> "$config_file"

# Function: Update XML files based on configurations
update_xml_files() {
    local base_dir=$PWD/$1

    for node in "${!particles_per_batch[@]}"; do
        local subdir="$base_dir/$node"
        local xml_file="$subdir/settings.xml"

        if [[ -f "$xml_file" ]]; then
            sed -i "s|<particles>.*</particles>|<particles>${particles_per_batch[$node]}</particles>|" "$xml_file"
            sed -i "s|<batches>.*</batches>|<batches>${batches[$node]}</batches>|" "$xml_file"
            echo "$xml_file updated successfully."
        else
            echo "Warning: $xml_file not found, skipping..."
        fi
    done

    echo "settings.xml files updated."
}
update_xml_files
EOF

    echo "Generated configuration file at $config_file."
}



## MAIN SCRIPT

# Parse the settings.xml file
parse_settings_xml

# Ensure ROOT_DIR has no trailing slash
ROOT_DIR="${ROOT_DIR%/}"

# Create the root directory
mkdir -p "$ROOT_DIR"

# Create subdirectories with user-defined names if provided
if [ ${#SUBDIR_NAMES[@]} -gt 0 ]; then
    for subdir in "${SUBDIR_NAMES[@]}"; do
        subdir_path="$ROOT_DIR/$subdir"
        mkdir -p "$subdir_path"
        cp *.xml "$subdir_path"
    done
    echo "${#SUBDIR_NAMES[@]} subdirectories created in '$ROOT_DIR'."
else
    for ((i=1; i<=NUM_SUBDIRS; i++)); do
        subdir_path="$ROOT_DIR/subdir-$i"
        mkdir -p "$subdir_path"
        cp *.xml "$subdir_path"
    done
    echo "$NUM_SUBDIRS subdirectories created in '$ROOT_DIR'."
fi


# Generate the configuration file
generate_config_file

echo "Directory structure and configuration setup complete."
