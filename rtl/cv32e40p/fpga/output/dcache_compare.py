# load all the lines in the file
with open('dcache_ref.hex', 'r') as f:
    lines_ref = f.readlines()

with open('sram_dump.hex', 'r') as f:
    lines_actual = f.readlines()

for i in range(1325):
    str1 = lines_ref[i].strip()
    str2 = lines_actual[i].strip()
    if i >= 270 and i <= 815 and i % 3 == 2:
        str1 = str1[0:4]
        str2 = str2[0:4]
    if str1 != str2:
        print(f"Mismatch at line {i}: expected {str1}, got {str2}")
        break
else:
    print("All lines match!")