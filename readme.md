# E01 GUID Extractor

A forensic tool for extracting GPT disk GUIDs from E01 (EnCase) image files and converting them to hex format.

## Overview

This Bash script extracts the GPT (GUID Partition Table) disk identifier from E01 forensic images and displays it in multiple formats:
- **Formatted GUID** (Standard UUID format)
- **Raw Hex** (Direct disk storage format)
- **Converted Hex** (Python UUID library conversion)

## Motivation

This script was created to solve a forensic analysis challenge where I needed to verify the disk GUID from the **2020JimmyWilson.E01** forensic image file. The specific question I needed to answer was:

> **The disk GUID (in hex) of the physical disk is: 6FAE8D386C441743AE3298C4BDE04830**  
> Select one: True / False

Since EnCase Imager is not readily available on Linux, I created this lightweight script using open-source tools to extract and verify the GUID directly from the E01 image.

## Purpose

- **Class Assignment**: Forensic analysis coursework
- **Educational**: Demonstration of E01 image handling on Linux
- **Time-saving**: AI-assisted development for rapid prototyping
- **Practical**: Alternative to commercial forensic tools

## Features

✅ Automatic dependency installation  
✅ Cross-distribution support (Debian/Ubuntu, Fedora/RHEL, Arch)  
✅ Multiple GUID format outputs  
✅ Automatic verification and validation  
✅ Clean, concise output  
✅ Error handling and cleanup  

## Dependencies

The script automatically installs these dependencies:
- **ewf-tools** / **libewf** - For mounting E01 images
- **gdisk** / **gptfdisk** - For reading GPT information
- **python3** - For GUID conversion

## Tested On

- ✅ Kali Linux
- ✅ Fedora

## Installation

```bash
# Clone or download the script
wget https://raw.githubusercontent.com/raviheima/encase-imager-hex-guid-extractor/refs/heads/main/e01_guid_extract.sh

# Make it executable
chmod +x e01-guid-extract.sh

```
# Extract GUID from forensic image
./e01_guid_extract.sh /path/to/2020JimmyWilson.E01
#Note: run with sudo to install dependencies (first usage)
sudo ./e01_guid_extract.sh /path/to/2020JimmyWilson.E01

