#!/bin/bash

# Define configurations for particles_per_batch and batches indexed by GPU count
declare -A particles_per_batch
declare -A batches

# Update these values as needed
particles_per_batch["1"]=120000000
batches["1"]=60

particles_per_batch["2"]=240000000
batches["2"]=30

particles_per_batch["3"]=360000000
batches["3"]=20

particles_per_batch["4"]=480000000
batches["4"]=15

particles_per_batch["5"]=600000000
batches["5"]=12

# Get the base directory (current directory where the script is called from)
BASE_DIR=$(pwd)

# Loop through all subdirectories in the base directory
for SUBDIR in "$BASE_DIR"/*/; do
  # Check if settings.xml exists in the subdirectory
  XML_FILE="${SUBDIR}settings.xml"
  if [[ -f "$XML_FILE" ]]; then
    # Extract GPU count from directory name (assume it starts with the GPU count)
    GPU_COUNT=$(basename "$SUBDIR" | grep -o '^[0-9]*')
    if [[ -n "$GPU_COUNT" && -n "${particles_per_batch[$GPU_COUNT]}" && -n "${batches[$GPU_COUNT]}" ]]; then
      echo "Updating $XML_FILE for $GPU_COUNT GPUs..."

      # Use sed to update particles and batches
      sed -i "s|<particles>.*</particles>|<particles>${particles_per_batch[$GPU_COUNT]}</particles>|" "$XML_FILE"
      sed -i "s|<batches>.*</batches>|<batches>${batches[$GPU_COUNT]}</batches>|" "$XML_FILE"

      echo "$XML_FILE updated successfully."
    else
      echo "Warning: No configuration found for $GPU_COUNT GPUs, skipping $XML_FILE..."
    fi
  else
    echo "Warning: No settings.xml found in $SUBDIR, skipping..."
  fi
done

echo "All settings.xml files processed."

