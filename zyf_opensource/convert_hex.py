#!/usr/bin/env python3
"""
convert_hex.py

Usage:
    python3 convert_hex.py input_raw.verilog output.hex

Purpose:
    - Take the Verilog memory file produced by:
        riscv64-unknown-linux-gnu-objcopy -O verilog ...
      (or riscv32-...-objcopy)
    - Parse @address directives and byte values
    - Fill any gaps with 0x00
    - Pack bytes into 32-bit little-endian words
    - Write one 8-hex-digit word per line for $readmemh

This assumes:
    * RISC-V is little-endian (default)
    * Your memories are 32-bit word wide
If your memory is byte-wide, you can easily tweak write_hex_words() at the bottom.
"""

import sys
import re


def parse_verilog_mem(path):
    """
    Parse an objcopy -O verilog output file into a dict:
        addr (int byte index) -> byte value (0..255)
    """
    mem = {}
    current_addr = 0

    hex_re = re.compile(r'^[0-9a-fA-F]+$')

    with open(path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            # Skip obvious comments
            if line.startswith('//') or line.startswith('/*') or line.startswith('*') or line.startswith('#'):
                continue

            # Address directive (e.g. @00010000)
            if line.startswith('@'):
                addr_str = ''
                for ch in line[1:]:
                    if ch in '0123456789abcdefABCDEF':
                        addr_str += ch
                    else:
                        break
                if addr_str:
                    current_addr = int(addr_str, 16)
                continue

            # Data line: hex tokens separated by whitespace
            for token in line.split():
                if not hex_re.fullmatch(token):
                    continue

                # Ensure even number of hex digits so we can split into bytes
                if len(token) % 2 == 1:
                    token = '0' + token

                # Each pair of hex digits = 1 byte
                for i in range(0, len(token), 2):
                    byte_val = int(token[i:i + 2], 16) & 0xFF
                    mem[current_addr] = byte_val
                    current_addr += 1

    if not mem:
        raise ValueError(f"No data parsed from '{path}'. "
                         "Is it really an objcopy -O verilog output?")

    return mem


def write_hex_words(mem, out_path, bytes_per_word=4):
    """
    Write memory as 32-bit little-endian words, one per line:
        word = b0 | (b1<<8) | (b2<<16) | (b3<<24)
    where b0 is the lowest address byte.

    This produces a nice $readmemh-friendly format.
    """
    min_addr = min(mem.keys())
    max_addr = max(mem.keys())

    # We generally expect min_addr == 0 because of --change-addresses,
    # but we’ll start at 0 and zero-fill any gap.
    start_addr = 0
    last_addr = max_addr

    # Round up to a whole number of words
    total_bytes = (last_addr - start_addr + 1)
    if total_bytes % bytes_per_word != 0:
        total_bytes = ((total_bytes + bytes_per_word - 1) // bytes_per_word) * bytes_per_word
        last_addr = start_addr + total_bytes - 1

    with open(out_path, 'w') as out:
        addr = start_addr
        while addr <= last_addr:
            word = 0
            for i in range(bytes_per_word):
                b = mem.get(addr + i, 0)
                # Little-endian packing
                word |= (b & 0xFF) << (8 * i)
            out.write(f"{word:08x}\n")
            addr += bytes_per_word


def main():
    if len(sys.argv) != 3:
        print("Usage: python3 convert_hex.py <input_raw.hex> <output.hex>")
        sys.exit(1)

    in_path = sys.argv[1]
    out_path = sys.argv[2]

    try:
        mem = parse_verilog_mem(in_path)
        write_hex_words(mem, out_path)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
