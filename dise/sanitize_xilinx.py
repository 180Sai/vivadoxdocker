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
        # Open using UTF-8 to catch rogue non-breaking spaces, preserving original newlines
        with open(filepath, 'r', encoding='utf-8', errors='replace', newline='') as f:
            content = f.read()

        changed = False

        if '\u00A0' in content or '\xc2\xa0' in content:
            print(f"Found UTF-8 Non-Breaking Spaces from: {filepath}, scrubbing...")
            content = content.replace('\u00A0', ' ')
            content = content.replace('\xc2\xa0', ' ')
            changed = True

        if '\r' in content:
            print(f"Performing linefeed conversion (CRLF -> LF) on: {filepath}")
            content = content.replace('\r', '')
            changed = True

        # Check if there are non-ASCII characters that would be lost during write
        try:
            content.encode('ascii')
        except UnicodeEncodeError:
            print(f"Found non-ASCII characters in: {filepath}, stripping...")
            changed = True

        if changed:
            # Save the file strictly as pure ASCII (ISO-8859-1 format Xilinx demands)
            with open(filepath, 'w', encoding='ascii', errors='ignore', newline='') as f:
                print(f"Writing back to file: {filepath}")
                f.write(content)
            
    except Exception as e:
        print(f"Failed to sanitize {filepath}: {e}")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Xilinx ISE 14.7 Legacy File Sanitizer")
    parser.add_argument('directory', nargs='?', default='.', help="Directory to scan (default: current dir)")
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

    print(f"Scanning {len(files_found)} files...")
    
    for filepath in files_found:
        sanitize_file(filepath)

    print("Directory successfully sanitized for Xilinx ISE 14.7.")
