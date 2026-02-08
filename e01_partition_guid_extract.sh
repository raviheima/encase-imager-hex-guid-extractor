#!/bin/bash

################################################################################
# E01 Partition Analyzer Script
# Purpose: Analyze partitions in E01 forensic images using sgdisk and Python
# Author: Ravi Heima
# Usage: ./e01_partition_analyzer.sh <path_to_image.E01>
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Banner
clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}          E01 PARTITION ANALYZER${NC}"
echo -e "${CYAN}            Created by RAVIHEIMA${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check arguments
E01_FILE="${1:-}"
if [ -z "$E01_FILE" ]; then
    echo -e "${RED}✗${NC} No E01 image file specified"
    echo -e "${YELLOW}Usage:${NC} $0 <path_to_image.E01>"
    exit 1
fi

# Validate file
if [ ! -f "$E01_FILE" ]; then
    echo -e "${RED}✗${NC} File not found: $E01_FILE"
    exit 1
fi

echo -e "${CYAN}File:${NC} $(basename "$E01_FILE")"

# Create mount point
MOUNT_POINT=$(mktemp -d)

# Cleanup on exit
cleanup() {
    [ -e "$MOUNT_POINT/ewf1" ] && fusermount -u "$MOUNT_POINT" 2>/dev/null || true
    rmdir "$MOUNT_POINT" 2>/dev/null || true
}
trap cleanup EXIT

# Mount E01
echo -e "${CYAN}Mounting...${NC}"
ewfmount "$E01_FILE" "$MOUNT_POINT" &>/dev/null
[ ! -e "$MOUNT_POINT/ewf1" ] && echo -e "${RED}✗${NC} Mount failed" && exit 1
echo ""

# Export disk image path for Python
export DISK_IMAGE="$MOUNT_POINT/ewf1"

# Run Python analysis
python3 << 'EOF'
import os
import subprocess
import uuid
import re

GREEN = '\033[0;32m'
BLUE = '\033[0;34m'
CYAN = '\033[0;36m'
NC = '\033[0m'

disk_image = os.environ.get('DISK_IMAGE')

# Get partition schema
gdisk_result = subprocess.run(['gdisk', '-l', disk_image], capture_output=True, text=True)

schema = "Unknown"
for line in gdisk_result.stdout.split('\n'):
    if 'Partition table scan:' in line or 'GPT: present' in line:
        schema = "GPT (GUID Partition Table)"
        break

print(f"{BLUE}Partition Schema:{NC} {schema}")
print()

# Parse partitions
partitions = []
in_partition_section = False

for line in gdisk_result.stdout.split('\n'):
    if 'Number' in line and 'Start' in line and 'End' in line:
        in_partition_section = True
        continue
    
    if in_partition_section and line.strip():
        match = re.match(r'^\s*(\d+)\s+(\d+)\s+(\d+)\s+(.+)$', line)
        if match:
            part_num = match.group(1)
            start = match.group(2)
            parts = match.group(4).strip().split()
            name = ' '.join(parts[3:]) if len(parts) > 3 else 'Unknown'
            
            partitions.append({'number': part_num, 'start': start, 'name': name})

# Analyze each partition
for idx, part in enumerate(partitions, 1):
    print(f"{CYAN}━━━ Partition {idx} (Number {part['number']}) ━━━{NC}")
    print(f"Name: {part['name']}")
    
    # Get cluster size
    try:
        fs_result = subprocess.run(
            ['fsstat', '-o', part['start'], disk_image],
            capture_output=True, text=True, timeout=5
        )
        for line in fs_result.stdout.split('\n'):
            if 'Cluster Size:' in line:
                cluster = line.split(':', 1)[1].strip()
                print(f"{GREEN}Cluster Size:{NC} {cluster} bytes")
                break
    except:
        pass
    
    # Get GUID
    detail = subprocess.run(
        ['sgdisk', '-i', part['number'], disk_image],
        capture_output=True, text=True
    )
    
    for line in detail.stdout.split('\n'):
        if 'Partition unique GUID:' in line:
            guid_formatted = line.split(':', 1)[1].strip()
            guid_obj = uuid.UUID(guid_formatted)
            raw_hex = guid_obj.bytes_le.hex().upper()
            
            print(f"{GREEN}GUID (formatted):{NC} {guid_formatted}")
            print(f"{GREEN}GUID (hex):{NC}       {raw_hex}")
            break
    
    print()

print(f"{GREEN}✓ Analysis complete ({len(partitions)} partitions){NC}")
print()
EOF
