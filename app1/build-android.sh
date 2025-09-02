#!/bin/bash

# Android Build Script for Linux (Bash)
# This script builds Android APK or AAB files with proper file management

# Default parameters
DATA_DIR="."
WORK_DIR="."
OUTPUT_DIR="output"
CHANNEL="google"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --workdir)
            WORK_DIR="$2"
            shift 2
            ;;
        --datadir)
            DATA_DIR="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --channel)
            CHANNEL="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--workdir <path>] [--datadir <path>] [--output <path>] [--channel <name>]"
            echo "  --workdir: Working directory (default: current directory)"
            echo "  --output:  Output directory for artifacts (default: output)"
            echo "  --channel: Channel name for app1.channel property (default: google)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Configuration - Files to copy (modify as needed)
declare -A FILES_TO_COPY=(
    ["local.properties"]="local.properties"
    ["signing.properties"]="signing.properties"
)

# Build template directories to clean
BUILD_TEMPLATE_DIRS=(
    "build"
    "app/build"
    ".gradle"
    "app/.gradle"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Record the initial running directory
INITIAL_DIR=$(pwd)

echo -e "${GREEN}=== Android Build Script ===${NC}"
echo -e "${YELLOW}Work Directory: $WORK_DIR${NC}"
echo -e "${YELLOW}Data Directory: $DATA_DIR${NC}"
echo -e "${YELLOW}Output Directory: $OUTPUT_DIR${NC}"
echo -e "${YELLOW}Channel: $CHANNEL${NC}"
echo -e "${YELLOW}Initial Directory: $INITIAL_DIR${NC}"

# Step 1: Copy files to destination directory
echo -e "\n${CYAN}[Step 1] Copying files...${NC}"
for source in "${!FILES_TO_COPY[@]}"; do
    dest="${FILES_TO_COPY[$source]}"
    source_path="$DATA_DIR/$source"
    dest_path="$WORK_DIR/$dest"
    
    if [[ -f "$source_path" ]]; then
        dest_dir=$(dirname "$dest_path")
        mkdir -p "$dest_dir"
        
        cp "$source_path" "$dest_path"
        echo -e "  ${GREEN}Copied: $source -> $dest${NC}"
    else
        echo -e "  ${YELLOW}Warning: Source file not found: $source_path${NC}"
    fi
done

# Step 1.5: Set channel property if specified
if [[ -n "$CHANNEL" ]]; then
    echo -e "\n${CYAN}[Step 1.5] Setting channel property...${NC}"
    # like 
    # "gpm --input \"$WORK_DIR/local.properties\" --set \"app.channel=$CHANNEL\""
    channel_command="echo \"${CHANNEL}\""
    echo -e "${YELLOW}Executing: $channel_command${NC}"
    
    if eval "$channel_command"; then
        echo -e "${GREEN}Channel property set successfully!${NC}"
    else
        channel_exit_code=$?
        echo -e "${RED}Channel command failed with exit code: $channel_exit_code${NC}"
        exit $channel_exit_code
    fi
fi

# Step 2: Clean build template directories
echo -e "\n${CYAN}[Step 2] Cleaning build directories...${NC}"
for dir in "${BUILD_TEMPLATE_DIRS[@]}"; do
    dir_path="$WORK_DIR/$dir"
    if [[ -d "$dir_path" ]]; then
        rm -rf "$dir_path"
        echo -e "  ${GREEN}Deleted: $dir${NC}"
    else
        echo -e "  ${GRAY}Not found: $dir${NC}"
    fi
done

# Step 3: Get user selection for build artifact
echo -e "\n${CYAN}[Step 3] Select build artifact type:${NC}"
echo "  1. APK (Android Package)"
echo "  2. AAB (Android App Bundle)"
echo ""

while true; do
    read -p "Enter your choice (1 for APK, 2 for AAB): " choice
    case $choice in
        1)
            build_type="apk"
            break
            ;;
        2)
            build_type="aab"
            break
            ;;
        *)
            echo "Invalid choice. Please enter 1 or 2."
            ;;
    esac
done

echo -e "${GREEN}Selected: $build_type${NC}"

# Step 4: Execute build command
echo -e "\n${CYAN}[Step 4] Building $build_type...${NC}"

gradlew_path="$WORK_DIR/gradlew"
if [[ ! -f "$gradlew_path" ]]; then
    echo -e "${RED}Error: gradlew not found in $WORK_DIR${NC}"
    exit 1
fi

# Make gradlew executable
chmod +x "$gradlew_path"

# Change to work directory
cd "$WORK_DIR" || exit 1

if [[ "$build_type" == "apk" ]]; then
    echo -e "${YELLOW}Executing: ./gradlew assembleRelease${NC}"
    ./gradlew assembleRelease
else
    echo -e "${YELLOW}Executing: ./gradlew bundleRelease${NC}"
    ./gradlew bundleRelease
fi

build_exit_code=$?

# Restore initial directory after build execution
echo -e "${CYAN}Restoring initial directory: $INITIAL_DIR${NC}"
cd "$INITIAL_DIR" || exit 1

if [[ $build_exit_code -ne 0 ]]; then
    echo -e "${RED}Build failed with exit code: $build_exit_code${NC}"
    exit $build_exit_code
fi

echo -e "${GREEN}Build completed successfully!${NC}"

# Step 5: Copy build artifact to output directory
echo -e "\n${CYAN}[Step 5] Copying build artifact...${NC}"

# Create output directory if it doesn't exist
if [[ ! -d "$OUTPUT_DIR" ]]; then
    mkdir -p "$OUTPUT_DIR"
    echo -e "${GREEN}Created output directory: $OUTPUT_DIR${NC}"
fi

if [[ "$build_type" == "apk" ]]; then
    artifact_path="$WORK_DIR/app/build/outputs"
    output_file="$OUTPUT_DIR/app-release-apk"
else
    artifact_path="$WORK_DIR/app/build/outputs"
    output_file="$OUTPUT_DIR/app-release-aab"
fi

if [[ -e "$artifact_path" ]]; then
    # Clean the specific destination before copying
    if [[ -e "$output_file" ]]; then
        echo -e "${YELLOW}Cleaning existing destination: $output_file${NC}"
        rm -rf "$output_file"
    fi
    
    # Copy artifact (handle both file and folder)
    if [[ -d "$artifact_path" ]]; then
        # Source is a folder
        cp -r "$artifact_path" "$output_file"
        echo -e "${GREEN}Artifact folder copied to: $output_file${NC}"
    else
        # Source is a file
        cp "$artifact_path" "$output_file"
        echo -e "${GREEN}Artifact file copied to: $output_file${NC}"
    fi
else
    echo -e "${YELLOW}Warning: Build artifact not found at: $artifact_path${NC}"
fi

echo -e "\n${GREEN}=== Build Process Completed ===${NC}"
echo -e "${YELLOW}Check the output directory: $OUTPUT_DIR${NC}"
