#!/bin/bash

# Function to get CUDA version from nvidia-smi command
get_cuda_version() {
    local version=$(nvidia-smi | grep "CUDA Version:" | grep -oP 'CUDA Version:\s+\K[\d.]+')
  echo "$version"
}


# Function to convert CUDA_VERSION to the desired format (e.g., 11.0 -> 11_0, 12.8 -> 12_8)
convert_cuda_version() {
  local version="$1"
  version=$(echo "$version" | tr '.' '_')
  echo "$version"
}

# Function to update or append the CUDA_VERSION entry to .env file
update_or_append_cuda_version() {
    local version="$1"
    local setup_line="##--- Setup Ubuntu?"
    local file="Dockerfile.jupyter"
    echo $file
    if grep -q "CUDA_VERSION=" $file; then
        echo "Already exists"
        # Update the existing CUDA_VERSION variable in .env
        sed -i "s/CUDA_VERSION=.*/CUDA_VERSION=$version/" "$file"

    else
        # Append the new CUDA_VERSION entry to .env
        sed -i "/$setup_line/a CUDA_VERSION=$version" $file 
        echo "-i /$setup_line/a CUDA_VERSION=$version $file "
    fi
}

get_cuda_img() {
  local version="$1"
  local cuda_file="environments/cuda_version.env"
  local cuda_var="CUDA_$version"
   if [ ! -f "$cuda_file" ]; then
    echo "Error: The CUDA version environment file ($cuda_file) does not exist."
    exit 1
  fi
  local cuda_img=$(grep -oP ${cuda_var}'=\K.*' "$cuda_file")
  echo "$cuda_img"
}

main() {
    echo "---> main"
    # Get CUDA version from nvidia-smi command
    local cuda_version=$(get_cuda_version)
    if [ -z "$cuda_version" ]; then
        echo "Error: Could not detect CUDA version from nvidia-smi command."
        exit 1
    fi
    echo "Cuda version $cuda_version"
    # Convert CUDA_VERSION to the desired format
    local converted_version=$(convert_cuda_version "$cuda_version")
    echo "Converted version $converted_version"
    local cuda_img=$(get_cuda_img "$converted_version")
    echo "Cuda img $cuda_img"
    # Update or append the CUDA_VERSION entry to .env file
    update_or_append_cuda_version "$cuda_img"
    # Print the final value of CUDA_VERSION
    echo "CUDA_VERSION=$cuda_img"
    echo "main --->"
}

    
# Call the main function
main
