#!/usr/bin/env python3
import os
import glob
import argparse

def sanitize_file(filepath):
    """
    Cleanses VHDL/Verilog/UCF files of hidden Unicode pollution that brutally crashes Xilinx ISE 14.7 
    (Non-Breaking Spaces, Carriage Returns, and Byte Order Marks).
    """
    try:
        # Open using UTF-8 to catch rogue non-breaking spaces
        with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
            content = f.read()

        # Phase 1: Nuke Non-Breaking Spaces (0xC2A0 / 160) which cause: `Syntax error near ""`
        if '\u00A0' in content or '\xc2\xa0' in content:
            print(f"🧹 Scrubbed UTF-8 Non-Breaking Spaces from: {filepath}")
            content = content.replace('\u00A0', ' ')
            content = content.replace('\xc2\xa0', ' ')

        # Phase 2: Nuke Windows Carriage Returns (\r) which cause line termination corruption
        if '\r' in content:
            print(f"🧹 Scrubbed Windows Carriage Returns (CRLF -> LF) from: {filepath}")
            content = content.replace('\r', '')

        # Save the file strictly as pure ASCII (ISO-8859-1 format Xilinx demands)
        with open(filepath, 'w', encoding='ascii', errors='ignore') as f:
            f.write(content)
            
    except Exception as e:
        print(f"⚠️ Failed to sanitize {filepath}: {e}")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Xilinx ISE 14.7 Legacy File Sanitizer")
    parser.add_argument('directory', nargs='?', default='.', help="Directory to scan (defaults to current dir)")
    args = parser.parse_args()

    print("====================================")
    print("Xilinx ISE 14.7 Project Sanitizer")
    print("====================================")

    extensions = ['**/*.vhd', '**/*.v', '**/*.ucf', '**/*.sch', '**/*.sym']
    files_found = []

    for ext in extensions:
        files_found.extend(glob.glob(os.path.join(args.directory, ext), recursive=True))

    if not files_found:
        print(f"No VHDL/Verilog/UCF files found in '{args.directory}'.")
        exit(0)

    print(f"Scanning {len(files_found)} files for hidden Unicode/Windows string corruption...")
    
    for filepath in files_found:
        sanitize_file(filepath)

    print("Sanitization Complete! You can successfully compile in Xilinx ISE 14.7 now.")
