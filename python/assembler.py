import re
import sys

# Every word is 16 bits. Instruction word layout:
#   [15:8] opcode    [1] rb (0 = r1, 1 = r2)    [0] ra (0 = r1, 1 = r2)
# Instructions with a number/address operand are TWO words: the instruction,
# then the full 16-bit number. Memory holds code and data in the same words.
#
# operand formats:
#   none   : no operands                        1 word
#   r      : ra                                 1 word
#   r_r    : ra, rb                             1 word
#   imm    : number or label                    2 words
#   r_imm  : ra, number or label                2 words
INSTRUCTIONS = {
    "PASS":               (0x00, "none"),
    "LOAD_IMMEDIATE":     (0x01, "r_imm"),   # ra = n
    "ADD_IMMEDIATE":      (0x02, "r_imm"),   # ra = ra + n
    "SUBTRACT_IMMEDIATE": (0x03, "r_imm"),   # ra = ra - n
    "LOAD":               (0x04, "r_imm"),   # ra = mem[address]
    "STORE":              (0x05, "r_imm"),   # mem[address] = ra
    "JUMP":               (0x06, "imm"),
    "JUMP_IF_ZERO":       (0x07, "r_imm"),   # if ra == 0
    "OUTPUT_INT":         (0x08, "r"),       # sends 2 bytes: high, low
    "OUTPUT_CHAR":        (0x09, "r"),       # sends the low byte
    "GPU_SETX":           (0x0A, "r"),
    "GPU_SETY":           (0x0B, "r"),
    "GPU_PLOT":           (0x0C, "r"),       # pixel color = ra
    "GPU_CLEAR":          (0x0D, "r"),       # color = ra
    "GPU_PRESENT":        (0x0E, "none"),
    "HALT":               (0x0F, "none"),
    "JUMP_IF_NOT_ZERO":   (0x10, "r_imm"),   # if ra != 0
    "MOVE":               (0x11, "r_r"),     # ra = rb
    "ADD":                (0x12, "r_r"),     # ra = ra + rb
    "SUBTRACT":           (0x13, "r_r"),     # ra = ra - rb
    "LOAD_INDIRECT":      (0x14, "r_r"),     # ra = mem[rb]
    "STORE_INDIRECT":     (0x15, "r_r"),     # mem[rb] = ra
}

REGISTERS = {"R1": 0, "R2": 1}
SIZES = {"none": 1, "r": 1, "r_r": 1, "imm": 2, "r_imm": 2}
MAX_WORDS = 1024  # = 2^MEM_BITS in rutra_top.v; raise it together with MEM_BITS


def fail(lineno, message):
    sys.exit("line " + str(lineno) + ": " + message)


def strip_comment(line):
    # cut at ';' but not when it is the character literal ';'
    out = []
    i = 0
    while i < len(line):
        if line[i] == "'" and i + 2 < len(line) and line[i + 2] == "'":
            out.append(line[i:i + 3])
            i += 3
        elif line[i] == ";":
            break
        else:
            out.append(line[i])
            i += 1
    return "".join(out)


def parse_number(text, labels, lineno):
    if len(text) == 3 and text[0] == "'" and text[2] == "'":
        return ord(text[1])
    if text in labels:
        return labels[text]
    try:
        value = int(text, 0)
    except ValueError:
        fail(lineno, "bad number or unknown label: " + text)
    if not -0x8000 <= value <= 0xFFFF:
        fail(lineno, "number does not fit in 16 bits: " + text)
    return value & 0xFFFF


def is_register(text):
    return text.upper() in REGISTERS


def split_register(args, lineno, line):
    """ra is optional (defaults to r1, so old single-accumulator code still works)."""
    if args and is_register(args[0]):
        return REGISTERS[args[0].upper()], args[1:]
    return 0, args


def assemble(source):
    # pass 1: strip comments, collect labels, remember what each line is
    items = []                       # (lineno, tokens)
    labels = {}
    address = 0
    for lineno, line in enumerate(source.splitlines(), 1):
        line = strip_comment(line).strip()
        match = re.match(r"([A-Za-z_][A-Za-z0-9_]*)\s*:", line)
        if match:
            labels[match.group(1)] = address
            line = line[match.end():].strip()
        if not line:
            continue
        tokens = re.findall(r"'.'|[^\s,]+", line)
        name = tokens[0].upper()
        if name == ".WORD":
            address += len(tokens) - 1
        elif name == ".SPACE":
            address += parse_number(tokens[1], {}, lineno)
        elif name in INSTRUCTIONS:
            address += SIZES[INSTRUCTIONS[name][1]]
        else:
            fail(lineno, "unknown instruction: " + tokens[0])
        items.append((lineno, tokens))

    # pass 2: emit 16-bit words
    words = []
    for lineno, tokens in items:
        name = tokens[0].upper()
        args = tokens[1:]

        if name == ".WORD":
            for a in args:
                words.append(parse_number(a, labels, lineno))
            continue
        if name == ".SPACE":
            words.extend([0] * parse_number(args[0], {}, lineno))
            continue

        opcode, fmt = INSTRUCTIONS[name]
        ra = rb = 0
        number = None

        if fmt == "none":
            if args:
                fail(lineno, name + " takes no operands")
        elif fmt == "r":
            ra, rest = split_register(args, lineno, name)
            if rest:
                fail(lineno, name + " takes one register")
        elif fmt == "r_r":
            if len(args) != 2 or not is_register(args[0]) or not is_register(args[1]):
                fail(lineno, name + " needs two registers, e.g. " + name + " r1, r2")
            ra, rb = REGISTERS[args[0].upper()], REGISTERS[args[1].upper()]
        elif fmt == "imm":
            if len(args) != 1:
                fail(lineno, name + " needs one number or label")
            number = parse_number(args[0], labels, lineno)
        elif fmt == "r_imm":
            ra, rest = split_register(args, lineno, name)
            if len(rest) != 1:
                fail(lineno, name + " needs a register and a number or label")
            number = parse_number(rest[0], labels, lineno)

        words.append((opcode << 8) | (rb << 1) | ra)
        if number is not None:
            words.append(number)
    return words


if len(sys.argv) < 2:
    sys.exit("usage: python assembler.py program.asm")

asm_file = sys.argv[1]
words = assemble(open(asm_file).read())
if not 1 <= len(words) <= MAX_WORDS:
    sys.exit("Program must be 1 to " + str(MAX_WORDS) + " words (got " + str(len(words)) + ")")

for address, word in enumerate(words):
    print(address, format(word, "04X"))

data = b""
for word in words:
    data += bytes([word >> 8, word & 0xFF])

out_file = asm_file.rsplit(".", 1)[0] + ".bin"
open(out_file, "wb").write(data)
print("Wrote", out_file, "(" + str(len(words)) + " words)")