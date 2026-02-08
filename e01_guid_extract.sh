#!/bin/bash

################################################################################
# E01 GUID Extractor Script
# Purpose: Extract GPT Disk GUID from EnCase/E01 forensic images
# Author: Ravi Heima
# Usage: ./e01-guid-extract.sh <path_to_image.E01>
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}▸${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1" >&2; }

check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Needs sudo for dependency installation"
        exit 1
    fi
}

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        print_error "Cannot detect distro"
        exit 1
    fi
}

install_dependencies() {
    print_info "Installing dependencies..."
    
    case $DISTRO in
        ubuntu|debian|kali|linuxmint)
            apt-get update -qq
            command -v ewfmount &>/dev/null || apt-get install -y ewf-tools
            command -v gdisk &>/dev/null || apt-get install -y gdisk
            command -v python3 &>/dev/null || apt-get install -y python3
            ;;
        fedora|rhel|centos)
            command -v ewfmount &>/dev/null || dnf install -y libewf
            command -v gdisk &>/dev/null || dnf install -y gdisk
            command -v python3 &>/dev/null || dnf install -y python3
            ;;
        arch|manjaro)
            command -v ewfmount &>/dev/null || pacman -S --noconfirm libewf
            command -v gdisk &>/dev/null || pacman -S --noconfirm gptfdisk
            command -v python3 &>/dev/null || pacman -S --noconfirm python
            ;;
        *)
            print_error "Unsupported distro. Install: ewf-tools, gdisk, python3"
            exit 1
            ;;
    esac
    print_success "Dependencies ready"
}

validate_e01_file() {
    local file="$1"
    
    if [ -z "$file" ]; then
        print_error "No E01 image file specified"
        echo ""
        echo -e "${YELLOW}Usage:${NC}"
        echo -e "  $0 ${BLUE}<path_to_image.E01>${NC}"
        echo ""
        echo -e "${YELLOW}Example:${NC}"
        echo -e "  sudo $0 /path/to/2020JimmyWilson.E01"
        echo ""
        exit 1
    fi
    
    if [ ! -f "$file" ]; then
        print_error "File not found: $file"
        exit 1
    fi
    
    if [ ! -r "$file" ]; then
        print_error "File not readable: $file"
        exit 1
    fi
    print_success "File validated"
}

cleanup() {
    if [ -n "${MOUNT_POINT:-}" ] && [ -d "$MOUNT_POINT" ]; then
        if [ -e "$MOUNT_POINT/ewf1" ]; then
            print_info "Unmounting..."
            fusermount -u "$MOUNT_POINT" 2>/dev/null || umount "$MOUNT_POINT" 2>/dev/null || true
        fi
        rmdir "$MOUNT_POINT" 2>/dev/null || true
    fi
}

trap cleanup EXIT

# Main execution
clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}          E01 GPT DISK GUID EXTRACTOR${NC}"
echo -e "${BLUE}                 By RAVIHEIMA${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Command:${NC} $0 $*"
echo ""

# Validate input FIRST (before accessing $1)
E01_FILE="${1:-}"
validate_e01_file "$E01_FILE"

# Check dependencies
if ! command -v ewfmount &>/dev/null || ! command -v gdisk &>/dev/null || ! command -v python3 &>/dev/null; then
    print_info "Missing dependencies..."
    check_sudo
    detect_distro
    install_dependencies
    echo
fi

# Create mount point
MOUNT_POINT=$(mktemp -d -t e01_XXXXXX)
print_info "Created mount: $MOUNT_POINT"

# Mount E01
print_info "Mounting $(basename "$E01_FILE")..."
if ! ewfmount "$E01_FILE" "$MOUNT_POINT" 2>&1; then
    print_error "Failed to mount E01 file"
    exit 1
fi

if [ ! -e "$MOUNT_POINT/ewf1" ]; then
    print_error "Mount failed - ewf1 not found"
    exit 1
fi
print_success "Mounted successfully"

# Extract GUIDs
print_info "Extracting GUIDs..."

FORMATTED_GUID=$(gdisk -l "$MOUNT_POINT/ewf1" 2>/dev/null | grep -i "disk identifier" | awk '{print $NF}') || true
if [ -z "$FORMATTED_GUID" ]; then
    print_error "Failed to extract formatted GUID"
    exit 1
fi

RAW_HEX_GUID=$(dd if="$MOUNT_POINT/ewf1" bs=1 skip=568 count=16 2>/dev/null | xxd -p -c 16 | tr '[:lower:]' '[:upper:]') || true
if [ -z "$RAW_HEX_GUID" ]; then
    print_error "Failed to extract raw hex GUID"
    exit 1
fi

CONVERTED_HEX=$(python3 -c "import uuid; print(uuid.UUID('$FORMATTED_GUID').bytes_le.hex().upper())" 2>/dev/null) || true
if [ -z "$CONVERTED_HEX" ]; then
    print_error "Failed to convert GUID"
    exit 1
fi

# Display results
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}File:${NC} $(basename "$E01_FILE")"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Formatted GUID:${NC}  $FORMATTED_GUID"
echo -e "${GREEN}Raw Hex:${NC}         $RAW_HEX_GUID"
echo -e "${GREEN}Converted Hex:${NC}   $CONVERTED_HEX"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Verification
if [ "$RAW_HEX_GUID" == "$CONVERTED_HEX" ]; then
    echo -e "${GREEN}✓ Verified${NC}\n"
else
    echo -e "${YELLOW}⚠ Mismatch detected${NC}\n"
fi

print_success "Extraction complete"
