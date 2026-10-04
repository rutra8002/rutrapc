import sys

OPCODES = {
    "PASS": 0x00,
    "LOAD_IMMEDIATE": 0x01,
    "ADD_IMMEDIATE": 0x02,
    "SUBTRACT_IMMEDIATE": 0x03,
    "LOAD": 0x04,
    "STORE": 0x05,
    "JUMP": 0x06,
    "JUMP_IF_ZERO": 0x07,
    "OUTPUT_INT": 0x08,
    "OUTPUT_CHAR": 0x09,
    "GPU_SETX": 0x0A,
    "GPU_SETY": 0x0B,
    "GPU_PLOT": 0x0C,
    "GPU_CLEAR": 0x0D,
    "GPU_PRESENT": 0x0E,
    "HALT": 0x0F,
}

def parse_number(text, labels):
    if len(text) == 3 and text[0] == "'" and text[2] == "'":
        return ord(text[1])
    if text in labels:
        return labels[text]
    return int(text, 0)

def assemble(source):
    # strip comments, find labels
    instructions = []
    labels = {}
    for line in source.splitlines():
        line = line.split(";")[0].strip()
        if ":" in line:
            name, line = line.split(":", 1)
            labels[name.strip()] = len(instructions)
            line = line.strip()
        if line:
            instructions.append(line)

    # turn each line into a 16-bit word (opcode high byte, operand low byte)
    words = []
    for line in instructions:
        parts = line.split()
        name = parts[0].upper()
        if name not in OPCODES:
            sys.exit("Unknown instruction: " + line)
        operand = parse_number(parts[1], labels) if len(parts) > 1 else 0
        words.append((OPCODES[name] << 8) | operand)
    return words

if len(sys.argv) < 2:
    sys.exit("usage: python assembler.py program.asm")

asm_file = sys.argv[1]
words = assemble(open(asm_file).read())
if not 1 <= len(words) <= 256:
    sys.exit("Program must be 1 to 256 instructions")

for address, word in enumerate(words):
    print(address, format(word, "04X"))

data = b""
for word in words:
    data += bytes([word >> 8, word & 0xFF]) 

out_file = asm_file.rsplit(".", 1)[0] + ".bin"
open(out_file, "wb").write(data)
print("Wrote", out_file, "(" + str(len(words)) + " instructions)")