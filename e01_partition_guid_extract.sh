#!/bin/bash

################################################################################
# E01 Partition GUID Extractor
# Repository: raviheima/encase-imager-hex-guid-extractor
# Author: Ravi Heima
################################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}        E01 PARTITION GUID EXTRACTOR${NC}"
echo -e "${CYAN}            Created by RAVIHEIMA${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

E01_FILE="${1:-}"
[ -z "$E01_FILE" ] && echo -e "${RED}Usage:${NC} $0 <image.E01>" && exit 1
[ ! -f "$E01_FILE" ] && echo -e "${RED}File not found${NC}" && exit 1

echo -e "${CYAN}Analyzing:${NC} $(basename "$E01_FILE")"
echo ""

MOUNT_POINT=$(mktemp -d)
cleanup() {
    [ -e "$MOUNT_POINT/ewf1" ] && fusermount -u "$MOUNT_POINT" 2>/dev/null || true
    rmdir "$MOUNT_POINT" 2>/dev/null || true
}
trap cleanup EXIT

ewfmount "$E01_FILE" "$MOUNT_POINT" &>/dev/null
[ ! -e "$MOUNT_POINT/ewf1" ] && echo -e "${RED}Mount failed${NC}" && exit 1

export DISK_IMAGE="$MOUNT_POINT/ewf1"

python3 << 'EOF'
import os, subprocess, uuid, re

GREEN = '\033[0;32m'
BLUE = '\033[0;34m'
CYAN = '\033[0;36m'
NC = '\033[0m'

disk = os.environ.get('DISK_IMAGE')
result = subprocess.run(['gdisk', '-l', disk], capture_output=True, text=True)

partitions = []
in_section = False

for line in result.stdout.split('\n'):
    if 'Number' in line and 'Start' in line:
        in_section = True
        continue
    if in_section and line.strip():
        match = re.match(r'^\s*(\d+)\s+(\d+)\s+(\d+)\s+(.+)$', line)
        if match:
            partitions.append({
                'num': match.group(1),
                'start': match.group(2),
                'name': ' '.join(match.group(4).split()[3:]) if len(match.group(4).split()) > 3 else 'Unknown'
            })

print(f"{BLUE}═══════════���═══════════════════════════════════════════════════{NC}")
print(f"{CYAN}PARTITION ANALYSIS RESULTS{NC}")
print(f"{BLUE}═══════════════════════════════════════════════════════════════{NC}")
print()

for idx, p in enumerate(partitions, 1):
    print(f"{CYAN}Partition {p['num']}:{NC}")
    print(f"  Name: {p['name']}")
    
    try:
        fs = subprocess.run(['fsstat', '-o', p['start'], disk], capture_output=True, text=True, timeout=5)
        for line in fs.stdout.split('\n'):
            if 'Cluster Size:' in line:
                print(f"  Cluster Size: {line.split(':')[1].strip()} bytes")
                break
    except: pass
    
    detail = subprocess.run(['sgdisk', '-i', p['num'], disk], capture_output=True, text=True)
    for line in detail.stdout.split('\n'):
        if 'Partition unique GUID:' in line:
            guid_fmt = line.split(':')[1].strip()
            guid_hex = uuid.UUID(guid_fmt).bytes_le.hex().upper()
            print(f"  {GREEN}GUID (Formatted):{NC} {guid_fmt}")
            print(f"  {GREEN}GUID (Hex):      {NC} {guid_hex}")
            break
    print()

print(f"{BLUE}═══════════════════════════════════════════════════════════════{NC}")
print()
EOF

echo ""
