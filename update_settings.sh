#!/bin/bash

# Define configurations for each node
declare -A particles_per_batch
declare -A batches

particles_per_batch["1node"]=60000000
batches["1node"]=60

particles_per_batch["2node"]=120000000
batches["2node"]=30

particles_per_batch["3node"]=180000000
batches["3node"]=20

particles_per_batch["4node"]=240000000
batches["4node"]=15

particles_per_batch["5node"]=300000000
batches["5node"]=12

# Base directory containing the subdirectories
BASE_DIR=$PWD

# Loop through each subdirectory
for node in "${!particles_per_batch[@]}"; do
  SUBDIR="$BASE_DIR/$node"
  XML_FILE="$SUBDIR/settings.xml"

  # Check if settings.xml exists in the subdirectory
  if [[ -f "$XML_FILE" ]]; then
    echo "Updating $XML_FILE..."

    # Use sed to update particles and batches
    sed -i "s|<particles>.*</particles>|<particles>${particles_per_batch[$node]}</particles>|" "$XML_FILE"
    sed -i "s|<batches>.*</batches>|<batches>${batches[$node]}</batches>|" "$XML_FILE"

    echo "$XML_FILE updated successfully."
  else
    echo "Warning: $XML_FILE not found, skipping..."
  fi
done

echo "All settings.xml files updated."

