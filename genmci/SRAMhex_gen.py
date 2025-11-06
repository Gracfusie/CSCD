import argparse
import pathlib
import sys

def read_tokens(path: pathlib.Path):
    toks = []
    with open(path, 'r') as f:
        for line in f:
            parts = line.strip().split()
            toks.extend(parts)
    return [t.upper().zfill(2) for t in toks]

def generate(src_c1_path: pathlib.Path, src_i_path: pathlib.Path, dst_path: pathlib.Path):
    # 读取所有 hex token（忽略空白）
    tokens = read_tokens(src_c1_path)

    # 每 3 个字节合成一行，格式为 00RRGGBB（高字节 00）
    lines = []
    for i in range(0, len(tokens), 3):
        line = ""
        line = tokens[i] + line
        line = tokens[i+1] + line
        line = tokens[i+2] + line
        line = "00" + line
        # chunk = tokens[i:i+3]
        # line = "00" + "".join(chunk)
        lines.append(line)

    tokens_fmap = read_tokens(src_i_path)
    for i in range(0, len(tokens_fmap)//5, 3):
        line = ""
        tokens_fmap[i] = format(int(tokens_fmap[i]), '02X')
        line = tokens_fmap[i] + line
        tokens_fmap[i+1] = format(int(tokens_fmap[i+1]), '02X')
        line = tokens_fmap[i+1] + line
        tokens_fmap[i+2] = format(int(tokens_fmap[i+2]), '02X')
        line = tokens_fmap[i+2] + line
        line = "00" + line
        lines.append(line)

    # 写入文件（每行一条，不带 0x，换行）
    dst_path.parent.mkdir(parents=True, exist_ok=True)
    with open(dst_path, 'w') as f:
        for ln in lines:
            f.write(ln + '\n')

    # print(f"Written {len(lines)} lines to {dst_path}")
    # print(f"Written {len(lines)} lines to {dst_path} (weights: {len(tokens)-len(fmap_tokens)} bytes -> { (len(tokens)-len(fmap_tokens)+2)//3 } lines, fmap: {len(fmap_tokens)} bytes -> { (len(fmap_tokens)+2)//3 } lines)")
    return 0

def main(argv):
    parser = argparse.ArgumentParser(description="Generate SRAM init hex from hex byte list and append feature-map bytes.")
    parser.add_argument("src_c1", type=pathlib.Path, help="Source txt file with hex byte tokens (weights)")
    parser.add_argument("src_i", type=pathlib.Path, help="Feature-map txt file with hex byte tokens to append")
    parser.add_argument("dst", type=pathlib.Path, help="Destination hex init file")
    args = parser.parse_args(argv)

    if not args.src_c1.exists():
        print(f"ERROR: source file not found: {args.src_c1}", file=sys.stderr)
        return 2
    if not args.src_i.exists():
        print(f"ERROR: feature-map file not found: {args.src_i}", file=sys.stderr)
        return 2

    return generate(args.src_c1, args.src_i, args.dst)

if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))