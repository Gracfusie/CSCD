import re

def dec_to_hex(n: int) -> str:
    if n == 0:
        return "0"
    sign = "-" if n < 0 else ""
    n = abs(n)
    digits = "0123456789ABCDEF"
    res = []
    while n > 0:
        n, r = divmod(n, 16)
        res.append(digits[r])
    return sign + "".join(reversed(res))


# 匹配整数（可带负号），避免把 3.14 这种小数拆开乱换
int_pattern = re.compile(r"(?<![\w.])-?\d+(?![\w.])")

def convert_file_replace_numbers(input_path: str, output_path: str):
    with open(input_path, "r", encoding="utf-8") as fin, \
         open(output_path, "w", encoding="utf-8") as fout:
        for line in fin:
            def repl(m):
                return dec_to_hex(int(m.group()))
            new_line = int_pattern.sub(repl, line)
            fout.write(new_line)

if __name__ == "__main__":
    convert_file_replace_numbers("input.txt", "output.txt")
    print("转换完成 -> output.txt")
