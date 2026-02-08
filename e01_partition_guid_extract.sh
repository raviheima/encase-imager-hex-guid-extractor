#!/bin/bash

################################################################################
# E01 Disk GUID Extractor
# Repository: raviheima/encase-imager-hex-guid-extractor
# Purpose: Extract disk GUID from E01 forensic images with endianness conversion
# Author: Ravi Heima
################################################################################

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Banner
clear
echo -e "${BLUE}═════════════════════════���═════════════════════════════════════${NC}"
echo -e "${CYAN}          E01 DISK GUID EXTRACTOR${NC}"
echo -e "${CYAN}            Created by RAVIHEIMA${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check arguments
E01_FILE="${1:-}"
if [ -z "$E01_FILE" ]; then
    echo -e "${RED}✗${NC} No E01 image file specified"
    echo -e "Usage: $0 <path_to_image.E01>"
    exit 1
fi

if [ ! -f "$E01_FILE" ]; then
    echo -e "${RED}✗${NC} File not found: $E01_FILE"
    exit 1
fi

# Create mount point
MOUNT_POINT=$(mktemp -d)

# Cleanup on exit
cleanup() {
    [ -e "$MOUNT_POINT/ewf1" ] && fusermount -u "$MOUNT_POINT" 2>/dev/null || true
    rmdir "$MOUNT_POINT" 2>/dev/null || true
}
trap cleanup EXIT

# Mount E01 (silent)
ewfmount "$E01_FILE" "$MOUNT_POINT" &>/dev/null
[ ! -e "$MOUNT_POINT/ewf1" ] && echo -e "${RED}✗${NC} Mount failed" && exit 1

# Extract and convert GUID
FORMATTED_GUID=$(gdisk -l "$MOUNT_POINT/ewf1" 2>/dev/null | grep -i "disk identifier" | awk '{print $NF}')

if [ -z "$FORMATTED_GUID" ]; then
    echo -e "${RED}✗${NC} Failed to extract disk GUID"
    exit 1
fi

RAW_HEX=$(dd if="$MOUNT_POINT/ewf1" bs=1 skip=568 count=16 2>/dev/null | xxd -p -c 16 | tr '[:lower:]' '[:upper:]')

python3 << EOF
import uuid

guid = uuid.UUID('$FORMATTED_GUID')
converted_hex = guid.bytes_le.hex().upper()

print(f"${GREEN}Formatted GUID:${NC}  {guid}")
print(f"${GREEN}Raw Hex:${NC}         {converted_hex}")
EOF

echo ""
