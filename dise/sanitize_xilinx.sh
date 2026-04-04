#!/bin/bash
# Xilinx ISE 14.7 Legacy File Sanitizer
# Strips non-breaking spaces and non-ASCII characters from HDL files
# that crash ISE's ancient VHDL/Verilog parser.

DIR="${1:-.}"

echo "===================================="
echo "Xilinx ISE 14.7 Project Sanitizer"
echo "===================================="

# Find all VHDL/Verilog/UCF/schematic files
mapfile -t FILES < <(find "$DIR" -type f \( -iname '*.vhd' -o -iname '*.v' -o -iname '*.ucf' -o -iname '*.sch' -o -iname '*.sym' \) 2>/dev/null)

if [ ${#FILES[@]} -eq 0 ]; then
    echo "No VHDL/Verilog/UCF files found in '$DIR'."
    exit 0
fi

echo "Scanning ${#FILES[@]} files..."

for filepath in "${FILES[@]}"; do
    changed=false

    # Check for UTF-8 non-breaking spaces (0xC2 0xA0)
    if grep -Plq '\xC2\xA0' "$filepath" 2>/dev/null; then
        echo "Found UTF-8 Non-Breaking Spaces in: $filepath, scrubbing..."
        sed -i 's/\xC2\xA0/ /g' "$filepath"
        changed=true
    fi

    # Check for bare NBSP bytes
    if grep -Plq '\xA0' "$filepath" 2>/dev/null; then
        sed -i 's/\xA0/ /g' "$filepath"
        changed=true
    fi

    # Check for any non-ASCII characters
    if LC_ALL=C grep -Pqn '[^\x00-\x7F]' "$filepath" 2>/dev/null; then
        echo "Found non-ASCII characters in: $filepath, stripping..."
        LC_ALL=C sed -i 's/[^\x00-\x7F]//g' "$filepath"
        changed=true
    fi

    if $changed; then
        echo "Cleaned: $filepath"
    fi
done

echo "Directory successfully sanitized for Xilinx ISE 14.7."
